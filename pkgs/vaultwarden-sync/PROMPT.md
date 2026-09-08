**Required CLI Tools (for Nix Packaging)**

- `python3`: The core runtime executing the script.
- `gnutar` (`tar`): For packaging the database and encryption key.
- `age`: For client-side encryption and decryption of backup archives.
- `git`: For repository synchronization (`git pull`, `git add`, `git commit`, `git push`).
- `systemctl`: For managing the Vaultwarden systemd service state during imports.
- `sqlite3`: For performing hot-backups of the SQLite database safely without locking errors.

---

**Prompt for Claude**

Write a robust, Linux-optimized Python (`.py`) script to manage Vaultwarden backup `export` and `import` operations, integrating direct hot-backup handling via `sqlite3`, `age` encryption, content-based hashing, data integrity verification, and a Git-backed Nix configuration repository. All code, comments, terminal messages, and documentation must be written strictly in **English**, using standard Python docstrings (`"""`) for all classes, functions, and modules.

### Environment Variables & Naming Structure

- `$env.NIX_CONFIG_DIR`: The absolute path to the root of the Nix configuration repository.
- `$env.DATA_DIR`: The relative path inside `$env.NIX_CONFIG_DIR` where encrypted configuration files are stored. The full path is computed via `path join`.
- `$env.AGE_PUBLIC_KEY`: The public key string used for encrypting files during export.
- `$env.AGE_PRIVATE_KEY_PATH`: The file path to the private key used for decrypting files during import.
- `$env.VAULTWARDEN_STATE_DIR`: The active runtime state directory of Vaultwarden (e.g., `/var/lib/vaultwarden`), containing live files like `db.sqlite3` and `rsa_key.pem`.
- `$env.VAULTWARDEN_USER`: The system user/owner of Vaultwarden state files (e.g., `vaultwarden`) to handle file permissions correctly during backups.
- `$env.VAULTWARDEN_SERVICE`: The systemd service name for Vaultwarden (e.g., `vaultwarden.service`) that must be stopped/restarted safely during imports.
- `$env.USER_MAIN`: The regular user account under whose context all Git operations must run.

### Subcommands & Detailed Workflow

- **Subcommand: `export` (Unified Backup & Encryption Daemon)**
  1. **Pre-Git Synchronization:** Execute `git pull` inside `$env.NIX_CONFIG_DIR` under the identity of `$env.USER_MAIN` to fetch latest remote changes and prevent conflicts.
  2. **Direct Hot-Backup Generation (Replacing Intermediate Backups):**
     - Avoid permission errors and intermediate copy scripts by directly reading from `$env.VAULTWARDEN_STATE_DIR`.
     - Securely perform an online SQLite hot-backup of `db.sqlite3` to a secure temporary staging folder in `/tmp` using the `sqlite3` CLI tool.
     - Copy `rsa_key.pem` from `$env.VAULTWARDEN_STATE_DIR` to the same temporary folder in `/tmp`, enforcing strict file permissions set to `0600`.
  3. **Hash Checking & Diff Comparison (Content-Based):**
     - Compute a combined `sha256` checksum directly from the raw content of the newly staged `db.sqlite3` and `rsa_key.pem` files in `/tmp`.
     - Compare it against the existing hash file located at `($env.NIX_CONFIG_DIR | path join $env.DATA_DIR "vaultwarden.tar.gz.sha256")`.
  4. **If unchanged:** Clean up `/tmp` via secure cleanup routines and exit gracefully without creating archives or triggering Git.
  5. **If changed:**
     - Pack the staged files into an unencrypted archive named `vaultwarden.tar.gz` strictly inside `/tmp` with permissions set to `0600`.
     - Encrypt the temporary archive using `age` (via `$env.AGE_PUBLIC_KEY`) to generate `vaultwarden.tar.gz.age`.
     - Move `vaultwarden.tar.gz.age` and the updated `.sha256` file to `($env.NIX_CONFIG_DIR | path join $env.DATA_DIR)` and update their ownership to match `$env.USER_MAIN`.
     - Clean up unencrypted temporary files from `/tmp`.
  6. **Git Version Control:** Change working directory to `$env.NIX_CONFIG_DIR` and run `git add`, `git reset`, `git commit -m "chore(vaultwarden): update secure backup"`, and `git push` under `$env.USER_MAIN`.

- **Subcommand: `import` (Manual execution by user via CLI)**
  1. **Decryption & Extraction:** Locate `vaultwarden.tar.gz.age` inside `($env.NIX_CONFIG_DIR | path join $env.DATA_DIR)` and decrypt it using `age` and `$env.AGE_PRIVATE_KEY_PATH`, extracting the plaintext archive into a secure temporary directory in `/tmp` with `0600` permissions.
  2. **Integrity Validation (Pre-Restore Check):**
     - Compute the combined `sha256` checksum of the freshly extracted `db.sqlite3` and `rsa_key.pem` files inside `/tmp`.
     - Read the reference hash file `vaultwarden.tar.gz.sha256` from `($env.NIX_CONFIG_DIR | path join $env.DATA_DIR)`.
     - **If hashes do not match:** Abort the import immediately, print a clear security/integrity error, clean up `/tmp`, and exit without touching the running service or state files.
     - **If hashes match:** Proceed safely to the next step.
  3. **Service Protection & Restoration:**
     - Safely stop the Vaultwarden systemd service (`$env.VAULTWARDEN_SERVICE`).
     - Safely copy the validated files from `/tmp` into `$env.VAULTWARDEN_STATE_DIR` using **`shutil.copy2`** (instead of `shutil.move` or OS rename) to cleanly handle potential cross-partition/cross-mount boundary constraints between `/tmp` and `/var/lib/vaultwarden`.
     - Enforce correct file ownership/permissions matching `$env.VAULTWARDEN_USER`.
  4. **Service Resume & Cleanup:** Restart the Vaultwarden systemd service and securely wipe temporary unencrypted files from `/tmp`.

### Implementation Guidelines

- **Code Documentation:** Every module, class, and function must feature descriptive triple-quoted docstrings (`"""`) explaining parameters, return types, and logical execution behavior.
- **Error Handling & Cleanup:** Implement robust exception handling combined with resource management (e.g., `try...finally` blocks) to guarantee that all unencrypted staging files inside `/tmp` are wiped out securely under any failure condition.
- **Permission Boundaries & Partitions:** Gracefully manage root vs. service user contexts, and use `shutil.copy2` for file placement across different partition mounts (such as `/tmp` to `/var/lib/vaultwarden`).
