#!/usr/bin/env python3
"""
Vaultwarden Secure Backup and Restoration Daemon

Manages Vaultwarden backups via two robust subcommands:

  export   Automated (daemon/timer-friendly) backup: Pulls latest Git
           changes, performs a safe SQLite hot-backup to a secure `/tmp`
           staging area, copies the RSA key, and hashes the raw content
           of these staged files. If the content differs from the stored
           hash, it packages the staging directory into an uncompressed
           tarball, encrypts it via `age`, and pushes the result into a
           Git-backed Nix configuration repository.

  import   Manual, interactive restore: Decrypts the archive from the
           Nix repository into a secure `/tmp` staging directory, extracts
           the files, and verifies their content hashes against the repository
           manifest. If valid, it safely stops the Vaultwarden systemd service,
           backs up existing state files, safely copies the restored files
           across partitions into the live state directory using `shutil.copy2`,
           enforces correct ownership/permissions, and restarts the service.

Required CLI tools:
  - python3: Core execution runtime.
  - tar (gnutar): For packaging and extracting the database and encryption key.
  - age: For client-side encryption and decryption of backup archives.
  - git: For repository synchronization.
  - systemctl: For managing the Vaultwarden systemd service state.
  - sqlite3: For performing safe hot-backups of the SQLite database.
  - su: For executing Git operations under a distinct unprivileged user context.

Required Environment Variables:
  NIX_CONFIG_DIR          Absolute path to the Nix configuration repo root.
  DATA_DIR                Path (relative to NIX_CONFIG_DIR) where encrypted backups live.
  AGE_PUBLIC_KEY          (Export) Public key (age1...) used to encrypt the archive.
  AGE_PRIVATE_KEY_PATH    (Import) Path to the private key used to decrypt the archive.
  VAULTWARDEN_STATE_DIR   Live runtime state directory of Vaultwarden (e.g., /var/lib/vaultwarden).
  VAULTWARDEN_USER        System user that must own the restored state files (e.g., vaultwarden).
  VAULTWARDEN_SERVICE     Systemd service name to stop/start safely during import.
  USER_MAIN               (Export) Unprivileged user context for executing Git operations.

This script must be executed as `root` to safely manage systemd, configure
locked-down temporary file ownership, read/write into Vaultwarden's secure
directories, and hand off privileges for Git operations.
"""

from __future__ import annotations

import argparse
import atexit
import contextlib
import datetime
import hashlib
import os
import pwd
import shlex
import shutil
import subprocess
import sys
import tempfile
import time
from pathlib import Path
from typing import Iterable, Optional

# --------------------------------------------------------------------------
# Constants
# --------------------------------------------------------------------------

TAR_NAME = "vaultwarden.tar.gz"
AGE_NAME = "vaultwarden.tar.gz.age"
HASH_NAME = "vaultwarden.tar.gz.sha256"
HASH_LABEL = "vaultwarden-source-content"
REQUIRED_SOURCE_FILES = ("db.sqlite3", "rsa_key.pem")

TMP_DIR = "/tmp"
CHUNK_SIZE = 1024 * 1024  # 1 MiB for hashing and secure wipe streams
SERVICE_STATE_TIMEOUT = 30  # Seconds to wait for systemd start/stop completion
SERVICE_POLL_INTERVAL = 1   # Seconds between systemctl is-active polls

# Paths that must be securely wiped on exit (success, failure, or signal).
_CLEANUP_PATHS: list[Path] = []


# --------------------------------------------------------------------------
# Logging Helpers
# --------------------------------------------------------------------------

def log_info(msg: str) -> None:
    """Prints standard informational messages to stdout."""
    print(f"[INFO] {msg}")


def log_warn(msg: str) -> None:
    """Prints warning messages to stderr."""
    print(f"[WARN] {msg}", file=sys.stderr)


def log_error(msg: str) -> None:
    """Prints critical error messages to stderr."""
    print(f"[ERROR] {msg}", file=sys.stderr)


def fail(msg: str, code: int = 1) -> None:
    """Logs a fatal error and exits the program immediately."""
    log_error(msg)
    sys.exit(code)


# --------------------------------------------------------------------------
# Environment & Configuration Handling
# --------------------------------------------------------------------------

class Config:
    """Parses, holds, and validates the environment variables for the application."""

    def __init__(self, mode: str) -> None:
        self.mode = mode

        # Shared configuration
        self.nix_config_dir = self._require_dir("NIX_CONFIG_DIR")
        data_dir_rel = self._require("DATA_DIR")
        self.data_dir = Path(os.path.join(self.nix_config_dir, data_dir_rel))
        self.hash_file_target = self.data_dir / HASH_NAME
        self.age_file_target = self.data_dir / AGE_NAME

        self.vaultwarden_state_dir = self._require_dir("VAULTWARDEN_STATE_DIR")

        vaultwarden_user_name = self._require("VAULTWARDEN_USER")
        try:
            self.vw_pw = pwd.getpwnam(vaultwarden_user_name)
        except KeyError:
            fail(f"VAULTWARDEN_USER '{vaultwarden_user_name}' does not exist on this system.")

        # Mode-specific configuration defaults
        self.age_public_key: Optional[str] = None
        self.user_main: Optional[str] = None
        self.user_pw: Optional[pwd.struct_passwd] = None
        self.age_private_key_path: Optional[str] = None
        self.vaultwarden_service: Optional[str] = None

        if mode == "export":
            self.age_public_key = self._require("AGE_PUBLIC_KEY")
            self.user_main = self._require("USER_MAIN")
            try:
                self.user_pw = pwd.getpwnam(self.user_main)
            except KeyError:
                fail(f"USER_MAIN '{self.user_main}' does not exist on this system.")
        elif mode == "import":
            self.age_private_key_path = self._require_file("AGE_PRIVATE_KEY_PATH")
            self.vaultwarden_service = self._require("VAULTWARDEN_SERVICE")
        else:
            fail(f"Unknown mode: {mode}")

    @staticmethod
    def _require(name: str) -> str:
        value = os.environ.get(name)
        if not value or not value.strip():
            fail(f"Required environment variable '{name}' is not set or empty.")
        return value.strip()

    @classmethod
    def _require_dir(cls, name: str) -> str:
        value = cls._require(name)
        if not os.path.isdir(value):
            fail(f"Environment variable '{name}' points to a non-existent directory: {value}")
        return value

    @classmethod
    def _require_file(cls, name: str) -> str:
        value = cls._require(name)
        if not os.path.isfile(value):
            fail(f"Environment variable '{name}' points to a non-existent file: {value}")
        return value


# --------------------------------------------------------------------------
# Privilege & Subprocess execution Helpers
# --------------------------------------------------------------------------

def require_root() -> None:
    """Enforces that the script must be run under the root uid."""
    if os.geteuid() != 0:
        fail("This script must be run as root (needs to manage systemd, own "
             "0600 temporary files, and switch identity for Git operations).")


def require_tools(tools: Iterable[str]) -> None:
    """Verifies that all required external binaries exist in the system PATH."""
    for tool in tools:
        if shutil.which(tool) is None:
            fail(f"Required executable '{tool}' was not found in PATH.")


def run_cmd(cmd: list[str], cwd: Optional[str] = None, check: bool = True) -> subprocess.CompletedProcess:
    """Executes a subprocess securely and captures stdout/stderr."""
    log_info(f"Running: {' '.join(shlex.quote(c) for c in cmd)}")
    try:
        result = subprocess.run(
            cmd,
            cwd=cwd,
            check=False,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            text=True,
        )
    except FileNotFoundError as exc:
        fail(f"Command not found: {cmd[0]} ({exc})")

    if check and result.returncode != 0:
        fail(
            f"Command failed ({result.returncode}): {' '.join(cmd)}\n"
            f"stdout: {result.stdout.strip()}\n"
            f"stderr: {result.stderr.strip()}"
        )
    return result


def run_as_user(user: str, cmd: Iterable[str], cwd: str) -> subprocess.CompletedProcess:
    """
    Executes a command as an unprivileged user using a login shell (`su -`).
    Ensures that git config and user-environment keys are fully loaded.
    """
    quoted_cmd = " ".join(shlex.quote(c) for c in cmd)
    shell_line = f"cd {shlex.quote(cwd)} && {quoted_cmd}"
    full_cmd = ["su", "-", user, "-c", shell_line]
    return run_cmd(full_cmd)


@contextlib.contextmanager
def restrictive_umask():
    """Context manager applying umask 0077 to ensure files are generated as 0600."""
    old_mask = os.umask(0o077)
    try:
        yield
    finally:
        os.umask(old_mask)


# --------------------------------------------------------------------------
# Hashing & File Security Wiping
# --------------------------------------------------------------------------

def _update_digest_with_named_content(digest: hashlib._Hash, name: str, size: int, chunks: Iterable[bytes]) -> None:
    """
    Folds a (name, size, content) signature into a running SHA256 digest
    in a self-delimiting manner (NUL-terminated) to guarantee collision
    resistance across different byte-stream splits.
    """
    digest.update(name.encode("utf-8"))
    digest.update(b"\0")
    digest.update(str(size).encode("ascii"))
    digest.update(b"\0")
    for chunk in chunks:
        digest.update(chunk)


def compute_manifest_hash(directory: Path) -> str:
    """
    Computes a deterministic, content-based SHA-256 digest over the raw
    uncompressed bytes of REQUIRED_SOURCE_FILES within a target directory.
    This effectively ignores all tar metadata like timestamps.
    """
    digest = hashlib.sha256()
    for name in sorted(REQUIRED_SOURCE_FILES):
        path = directory / name
        if not path.is_file():
            fail(f"Required staging file is missing for hash computation: {path}")

        size = path.stat().st_size

        def _read_chunks(p: Path = path):
            with open(p, "rb") as f:
                while True:
                    chunk = f.read(CHUNK_SIZE)
                    if not chunk:
                        break
                    yield chunk

        _update_digest_with_named_content(digest, name, size, _read_chunks())
    return digest.hexdigest()


def read_stored_hash(path: Path) -> Optional[str]:
    """Retrieves the previous manifest hash from the Nix repository safely."""
    if not path.is_file():
        return None
    try:
        content = path.read_text(encoding="utf-8").strip()
    except OSError as exc:
        log_warn(f"Could not read existing hash file '{path}': {exc}")
        return None
    # Support "hash  filename" standard format splitting
    return content.split()[0] if content else None


def secure_wipe_path(target: Path) -> None:
    """
    Securely wipes a file or directory. If it's a file, overwrites contents
    with random bits. If it's a directory, recursively wipes internal files
    before removing the directory structure.
    """
    if not target.exists():
        return

    if target.is_dir():
        for child in target.iterdir():
            secure_wipe_path(child)
        try:
            target.rmdir()
            log_info(f"Removed secure temporary directory: {target}")
        except OSError as exc:
            log_warn(f"Could not remove directory '{target}': {exc}")
    else:
        try:
            size = target.stat().st_size
            with open(target, "r+b") as f:
                remaining = size
                while remaining > 0:
                    n = min(CHUNK_SIZE, remaining)
                    f.write(os.urandom(n))
                    remaining -= n
                f.flush()
                os.fsync(f.fileno())
        except OSError as exc:
            log_warn(f"Could not overwrite '{target}' before deletion: {exc}")
        finally:
            try:
                target.unlink(missing_ok=True)
            except OSError as exc:
                log_warn(f"Could not remove temporary file '{target}': {exc}")


def cleanup_registered_paths() -> None:
    """atexit hook: Wipes any registered sensitive temporary files/directories on disk."""
    for path in reversed(_CLEANUP_PATHS):
        if path.exists():
            secure_wipe_path(path)


def register_for_cleanup(path: Path) -> None:
    """Registers a path for secure wiping on script termination."""
    if path not in _CLEANUP_PATHS:
        _CLEANUP_PATHS.append(path)


def unregister_from_cleanup(path: Path) -> None:
    """Removes a path from the cleanup registry (used after successful repository moves)."""
    if path in _CLEANUP_PATHS:
        _CLEANUP_PATHS.remove(path)


atexit.register(cleanup_registered_paths)


def chown_path(path: Path, uid: int, gid: int) -> None:
    """Changes file ownership and halts execution on failure."""
    try:
        os.chown(path, uid, gid)
    except OSError as exc:
        fail(f"Failed to chown '{path}' to uid={uid}, gid={gid}: {exc}")


# --------------------------------------------------------------------------
# Systemd Service State Helpers
# --------------------------------------------------------------------------

def service_is_active(service: str) -> bool:
    """Checks if a systemd unit is actively running."""
    result = run_cmd(["systemctl", "is-active", service], check=False)
    return result.stdout.strip() == "active"


def wait_for_service_state(service: str, desired_active: bool, timeout: int) -> None:
    """Polls systemd until the target service achieves the requested active/inactive state."""
    deadline = time.monotonic() + timeout
    state_name = "active" if desired_active else "inactive"
    while time.monotonic() < deadline:
        if service_is_active(service) == desired_active:
            log_info(f"Service '{service}' is now {state_name}.")
            return
        time.sleep(SERVICE_POLL_INTERVAL)
    fail(f"Timed out after {timeout}s waiting for service '{service}' to become {state_name}.")


def stop_service(service: str) -> None:
    """Safely issues a stop command to a systemd service."""
    log_info(f"Stopping service '{service}'...")
    run_cmd(["systemctl", "stop", service])
    wait_for_service_state(service, desired_active=False, timeout=SERVICE_STATE_TIMEOUT)


def start_service(service: str) -> None:
    """Safely issues a start command to a systemd service."""
    log_info(f"Starting service '{service}'...")
    run_cmd(["systemctl", "start", service])
    wait_for_service_state(service, desired_active=True, timeout=SERVICE_STATE_TIMEOUT)


# --------------------------------------------------------------------------
# Subcommand workflows: EXPORT
# --------------------------------------------------------------------------

def export_git_pull(cfg: Config) -> None:
    """Synchronizes the Nix configuration directory before executing backups."""
    log_info(f"Pulling latest changes in '{cfg.nix_config_dir}' as user '{cfg.user_main}'...")
    run_as_user(cfg.user_main, ["git", "pull"], cwd=str(cfg.nix_config_dir))
    log_info("Git pull completed successfully.")


def export_stage_files(cfg: Config) -> Path:
    """
    Creates a secure staging directory in /tmp. Directly utilizes `sqlite3 .backup`
    to safely copy the live database without locks, and copies the RSA key.
    """
    tmp_dir_path = Path(tempfile.mkdtemp(prefix="vw_export_", dir=TMP_DIR))
    os.chmod(tmp_dir_path, 0o700)
    register_for_cleanup(tmp_dir_path)

    live_db = Path(cfg.vaultwarden_state_dir) / "db.sqlite3"
    staged_db = tmp_dir_path / "db.sqlite3"

    live_rsa = Path(cfg.vaultwarden_state_dir) / "rsa_key.pem"
    staged_rsa = tmp_dir_path / "rsa_key.pem"

    log_info("Executing hot-backup of Vaultwarden SQLite database...")
    if not live_db.exists():
        fail(f"Live database not found: {live_db}")

    run_cmd(["sqlite3", str(live_db), f".backup '{staged_db}'"])
    os.chmod(staged_db, 0o600)

    log_info("Copying Vaultwarden RSA private key...")
    if not live_rsa.exists():
        fail(f"Live RSA key not found: {live_rsa}")

    shutil.copy2(live_rsa, staged_rsa)
    os.chmod(staged_rsa, 0o600)

    log_info(f"Files securely staged in '{tmp_dir_path}'.")
    return tmp_dir_path


def export_check_hash(cfg: Config, staging_dir: Path) -> tuple[str, bool]:
    """
    Computes the content-based hash of the staged raw files and compares it
    to the repo hash. Returns the hash string and a boolean indicating if changes occurred.
    """
    new_hash = compute_manifest_hash(staging_dir)
    old_hash = read_stored_hash(cfg.hash_file_target)

    if old_hash is None:
        log_info("No previous checksum found; treating this as a new backup.")
        return new_hash, True

    if old_hash == new_hash:
        log_info("Content hash unchanged; Vaultwarden data has not been modified.")
        return new_hash, False

    log_info("Content hash differs from the stored value; an update is required.")
    return new_hash, True


def export_create_archive(staging_dir: Path) -> Path:
    """Creates a raw tarball out of the securely staged Vaultwarden files."""
    tar_path = staging_dir / TAR_NAME

    log_info(f"Packaging archive '{tar_path}' (mode 0600, owner root:root)...")
    run_cmd([
        "tar", "-czf", str(tar_path),
        "-C", str(staging_dir)
    ] + list(REQUIRED_SOURCE_FILES))

    os.chmod(tar_path, 0o600)
    os.chown(tar_path, 0, 0)
    return tar_path


def export_encrypt(cfg: Config, tar_path: Path) -> Path:
    """Encrypts the uncompressed tarball using the `age` public key."""
    age_tmp_path = tar_path.with_name(AGE_NAME)

    log_info(f"Encrypting archive with age (recipient: {cfg.age_public_key})...")
    with restrictive_umask():
        run_cmd([
            "age",
            "--recipient", cfg.age_public_key,
            "--output", str(age_tmp_path),
            str(tar_path),
        ])

    if not age_tmp_path.is_file() or age_tmp_path.stat().st_size == 0:
        fail(f"age encryption did not produce a valid output file at '{age_tmp_path}'.")

    os.chmod(age_tmp_path, 0o600)
    os.chown(age_tmp_path, 0, 0)
    log_info("Encryption completed successfully.")
    return age_tmp_path


def export_place_in_repo(cfg: Config, age_tmp_path: Path, new_hash: str) -> None:
    """Moves the encrypted archive and manifest hash into the git-backed directory structure."""
    cfg.data_dir.mkdir(parents=True, exist_ok=True)

    log_info(f"Writing updated content hash to '{cfg.hash_file_target}'...")
    cfg.hash_file_target.write_text(f"{new_hash}  {HASH_LABEL}\n", encoding="utf-8")

    log_info(f"Moving encrypted archive to '{cfg.age_file_target}'...")
    shutil.move(str(age_tmp_path), str(cfg.age_file_target))

    for target in (cfg.age_file_target, cfg.hash_file_target):
        os.chmod(target, 0o640)
        chown_path(target, cfg.user_pw.pw_uid, cfg.user_pw.pw_gid)

    log_info("Encrypted backup and checksum placed in the repository with correct ownership.")


def export_git_commit_and_push(cfg: Config) -> None:
    """
    Stages the encrypted archive and hash manifest, commits with a chore message,
    and pushes to the remote Nix repository under the context of USER_MAIN.
    The git index is reset first to ensure unrelated changes are not committed.
    """
    rel_age = os.path.relpath(cfg.age_file_target, cfg.nix_config_dir)
    rel_hash = os.path.relpath(cfg.hash_file_target, cfg.nix_config_dir)

    log_info("Resetting any pre-existing staged changes...")
    run_as_user(cfg.user_main, ["git", "reset"], cwd=str(cfg.nix_config_dir))

    log_info(f"Staging '{rel_age}' and '{rel_hash}'...")
    run_as_user(cfg.user_main, ["git", "add", rel_age, rel_hash], cwd=str(cfg.nix_config_dir))

    status = run_as_user(cfg.user_main, ["git", "status", "--porcelain"], cwd=str(cfg.nix_config_dir))
    if not status.stdout.strip():
        log_info("Nothing staged for commit; skipping commit and push.")
        return

    log_info("Committing changes...")
    run_as_user(
        cfg.user_main,
        ["git", "commit", "-m", "chore(vaultwarden): update secure backup"],
        cwd=str(cfg.nix_config_dir),
    )

    log_info("Pushing changes to remote...")
    run_as_user(cfg.user_main, ["git", "push"], cwd=str(cfg.nix_config_dir))
    log_info("Git commit and push completed successfully.")


def run_export(cfg: Config) -> int:
    """Main execution orchestrator for the EXPORT daemon mode."""
    export_git_pull(cfg)

    staging_dir = export_stage_files(cfg)
    new_hash, changed = export_check_hash(cfg, staging_dir)

    if not changed:
        log_info("No changes detected. Nothing to do. Exiting cleanly.")
        return 0

    tar_path = export_create_archive(staging_dir)
    age_tmp_path = export_encrypt(cfg, tar_path)

    # Securely wipe the unencrypted staging files locally before git operations
    secure_wipe_path(tar_path)

    export_place_in_repo(cfg, age_tmp_path, new_hash)
    export_git_commit_and_push(cfg)

    log_info("Vaultwarden export completed successfully.")
    return 0


# --------------------------------------------------------------------------
# Subcommand workflows: IMPORT
# --------------------------------------------------------------------------

def import_confirm(cfg: Config, assume_yes: bool) -> None:
    """Ensures destructive file restores are explicitly authorized by the user."""
    if assume_yes:
        return
    print()
    print("=" * 70)
    print("WARNING: This will STOP the Vaultwarden service and OVERWRITE")
    print(f"the live database and RSA key in '{cfg.vaultwarden_state_dir}'")
    print(f"with the contents of '{cfg.age_file_target}'.")
    print("This action cannot be undone (existing files will be backed up")
    print("alongside the originals, but are not kept indefinitely).")
    print("=" * 70)
    try:
        answer = input("Type 'yes' to continue: ").strip().lower()
    except EOFError:
        answer = ""
    if answer != "yes":
        fail("Import aborted by user (confirmation not received).", code=2)


def import_stage_and_decrypt(cfg: Config) -> Path:
    """
    Creates a secure staging directory in /tmp, decrypts the backup archive
    into it using `age`, and extracts the contents via `tar`.
    """
    if not cfg.age_file_target.is_file():
        fail(f"Encrypted backup not found at '{cfg.age_file_target}'.")

    tmp_dir_path = Path(tempfile.mkdtemp(prefix="vw_import_", dir=TMP_DIR))
    os.chmod(tmp_dir_path, 0o700)
    register_for_cleanup(tmp_dir_path)

    tar_path = tmp_dir_path / TAR_NAME

    log_info(f"Decrypting '{cfg.age_file_target}' to '{tar_path}'...")
    with restrictive_umask():
        run_cmd([
            "age",
            "--decrypt",
            "--identity", cfg.age_private_key_path,
            "--output", str(tar_path),
            str(cfg.age_file_target),
        ])

    if not tar_path.is_file() or tar_path.stat().st_size == 0:
        fail(f"age decryption did not produce a valid output file at '{tar_path}'.")

    os.chmod(tar_path, 0o600)

    log_info("Extracting tarball contents into temporary staging directory...")
    run_cmd(["tar", "-xzf", str(tar_path), "-C", str(tmp_dir_path)])

    for filename in REQUIRED_SOURCE_FILES:
        target = tmp_dir_path / filename
        if not target.exists():
            fail(f"Corrupted backup: required file '{filename}' missing from archive.")
        os.chmod(target, 0o600)

    # Clean up the decrypted tarball immediately to save space
    secure_wipe_path(tar_path)
    return tmp_dir_path


def import_verify_hash(cfg: Config, staging_dir: Path) -> None:
    """
    Hashes the freshly extracted bytes inside the staging directory and
    compares against the repository manifest hash file.
    """
    stored_hash = read_stored_hash(cfg.hash_file_target)
    if stored_hash is None:
        log_warn(f"No checksum file found at '{cfg.hash_file_target}'; "
                  f"skipping integrity verification.")
        return

    actual_hash = compute_manifest_hash(staging_dir)

    if actual_hash != stored_hash:
        fail(
            "CRITICAL SECURITY/INTEGRITY ERROR: the extracted content hash does not "
            "match the checksum stored in the repository. Aborting import to "
            "avoid restoring corrupted or tampered data.\n"
            f"expected: {stored_hash}\n"
            f"actual:   {actual_hash}"
        )
    log_info("Integrity check passed: extracted content matches the stored hash.")


def import_backup_existing_files(state_dir: Path) -> None:
    """Safeguards current live state files with a timestamped backup before restoration."""
    timestamp = datetime.datetime.now().strftime("%Y%m%dT%H%M%S")
    for name in REQUIRED_SOURCE_FILES:
        existing = state_dir / name
        if existing.is_file():
            backup_path = state_dir / f"{name}.bak-{timestamp}"
            try:
                shutil.copy2(existing, backup_path)
                os.chmod(backup_path, 0o600)
                log_info(f"Backed up existing '{existing}' to '{backup_path}'.")
            except OSError as exc:
                fail(f"Could not back up existing file '{existing}' before overwrite: {exc}")


def import_restore_files(cfg: Config, staging_dir: Path) -> None:
    """
    Safely copies the verified extracted files from /tmp into the live Vaultwarden
    state directory using `shutil.copy2`. This method natively supports transfers
    across different partitions or mount boundaries, effectively preventing `EXDEV` errors.
    Applies strict ownership parameters after placement.
    """
    state_dir = Path(cfg.vaultwarden_state_dir)
    uid = cfg.vw_pw.pw_uid
    gid = cfg.vw_pw.pw_gid

    for name in REQUIRED_SOURCE_FILES:
        staged_source = staging_dir / name
        final_path = state_dir / name

        try:
            # shutil.copy2 cleanly spans partition boundaries while preserving metadata
            shutil.copy2(staged_source, final_path)

            # Explicitly enforce correct service ownership and locking permissions
            chown_path(final_path, uid, gid)
            os.chmod(final_path, 0o600)
        except OSError as exc:
            fail(f"Failed to copy restored file '{final_path}': {exc}")

        log_info(f"Restored '{final_path}' (owner uid={uid}, gid={gid}, mode=0600).")


def run_import(cfg: Config, assume_yes: bool) -> int:
    """Main execution orchestrator for the IMPORT manual restore mode."""
    import_confirm(cfg, assume_yes)

    staging_dir = import_stage_and_decrypt(cfg)
    import_verify_hash(cfg, staging_dir)

    stop_service(cfg.vaultwarden_service)
    try:
        import_backup_existing_files(Path(cfg.vaultwarden_state_dir))
        import_restore_files(cfg, staging_dir)
    finally:
        # Always attempt to bring the service back up, even if restoration
        # failed partway through, so Vaultwarden is not left offline.
        try:
            start_service(cfg.vaultwarden_service)
        except SystemExit:
            log_error(
                f"Failed to restart service '{cfg.vaultwarden_service}' after import. "
                f"Manual intervention required."
            )
            raise

    log_info("Vaultwarden import completed successfully.")
    return 0


# --------------------------------------------------------------------------
# Entry Point & CLI Parsing
# --------------------------------------------------------------------------

def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="Manage Vaultwarden backups: export (automated) and import (manual restore)."
    )
    subparsers = parser.add_subparsers(dest="command", required=True)

    subparsers.add_parser(
        "export",
        help="Pack, hash-check, encrypt, and sync a Vaultwarden backup into the Nix config repo.",
    )

    import_parser = subparsers.add_parser(
        "import",
        help="Decrypt and restore a Vaultwarden backup into the live state directory.",
    )
    import_parser.add_argument(
        "--yes", "-y",
        action="store_true",
        help="Skip the interactive confirmation prompt (for non-interactive use).",
    )

    return parser


def main() -> int:
    parser = build_arg_parser()
    args = parser.parse_args()

    require_root()

    if args.command == "export":
        require_tools(("git", "age", "su", "sqlite3", "tar"))
        cfg = Config(mode="export")
        return run_export(cfg)
    elif args.command == "import":
        require_tools(("age", "systemctl", "tar"))
        cfg = Config(mode="import")
        return run_import(cfg, assume_yes=args.yes)
    else:
        fail(f"Unknown command: {args.command}")
        return 1


if __name__ == "__main__":
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        log_error("Interrupted by user.")
        sys.exit(130)
    except SystemExit:
        raise
    except Exception as exc:  # noqa: BLE001
        log_error(f"Unexpected error: {exc}")
        sys.exit(1)
