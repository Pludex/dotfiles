import argparse
import fcntl
import hashlib
import json
import os
import posixpath
import re
import signal
import subprocess
import sys
from pathlib import Path
from typing import NamedTuple

CFG = json.loads(Path(os.environ["HERMESCTL_CONFIG"]).read_text())

ROOT = Path(CFG["mount_root"])
MOUNT_IN = CFG["mount_in"]
BOT = CFG["bot_user"]
UNIT = CFG["unit"]
REFS = CFG.get("refs", {})  # declared in Nix, mounted at boot by REFS_UNIT
REFS_UNIT = CFG.get("refs_unit")
LOCKDIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hermesctl"
STATEDIR = Path(os.environ.get("XDG_STATE_HOME", Path.home() / ".local/state")) / "hermesctl"
PINDIR = STATEDIR / "pins"
USER_REFS = STATEDIR / "refs.json"  # refs added with `hermesctl ref add`
DESKTOP_LOG = STATEDIR / "desktop.log"
NAME_RE = re.compile(r"[A-Za-z0-9][A-Za-z0-9._-]*")

DENY_HOME = (".ssh", ".gnupg", ".config", ".aws", ".kube", ".local/share/keyrings")
DENY_ABS = ("/etc", "/root", "/proc", "/sys", "/dev", "/boot")

EPILOG = """\
MOUNT spec (-m/--mount, repeatable):  SRC[:NAME][:ro|rw]
  -m .                  mount cwd read-only under an auto name
  -m ~/proj:proj:rw     mount ~/proj writable as <mount_in>/proj
  The first -m is the working directory unless -C is given.

Examples:
  hermesctl                                  hermes --tui, no project mounted
  hermesctl -W -m .                          tui with cwd writable
  hermesctl hermes -m ./a:docs -- doctor     `hermes doctor` with ./a at .../docs
  hermesctl omh -W -m . -- setup             omh setup, project writable
  hermesctl shell -m ~/src:src -C sub -- ls  command in ~/src/sub
  hermesctl desktop -W -m ~/proj:proj        pin-mount and launch the desktop app
  hermesctl mount add -m ~/notes:notes       pinned mount, no session
  hermesctl mount ls --json
  hermesctl mount rm notes ~/proj            by name or by source dir
  hermesctl ref add vault ~/vault            auto-mount on every hermesctl run
  hermesctl host logs -f
Everything after `--` goes to the tool untouched.
"""


def die(msg):
    print(f"hermesctl: {msg}", file=sys.stderr)
    sys.exit(1)


def warn(msg):
    print(f"hermesctl: {msg}", file=sys.stderr)


def sudo(*cmd, quiet=False):
    return subprocess.run(["sudo", *cmd], stderr=subprocess.DEVNULL if quiet else None)


# ---------------------------------------------------------------- mount state

def unescape(s):
    return re.sub(r"\\([0-7]{3})", lambda m: chr(int(m[1], 8)), s)


def mountinfo():
    for line in Path("/proc/self/mountinfo").read_text().splitlines():
        left, _, right = line.partition(" - ")
        f, r = left.split(), right.split()
        yield unescape(f[4]), f[5], unescape(r[1])


def mount_entry(path):
    found = None
    for target, opts, source in mountinfo():
        if target == str(path):
            found = (source, opts)
    return found


def is_mounted(path):
    return mount_entry(path) is not None


def mount_mode(opts):
    return "ro" if "ro" in opts.split(",") else "rw"


def root_shared():
    for line in Path("/proc/self/mountinfo").read_text().splitlines():
        f = line.partition(" - ")[0].split()
        if unescape(f[4]) == str(ROOT):
            return any(x.startswith("shared:") for x in f[6:])
    return False


def ensure_root():
    if not (is_mounted(ROOT) and root_shared()):
        die(f"{ROOT} is not a shared mount (systemctl status hermes-mount-root)")


def svc_active(unit):
    return subprocess.run(
        [CFG["systemctl"], "is-active", "--quiet", unit],
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def unit_active():
    return svc_active(UNIT)


def require_up():
    if not unit_active():
        die(f"{UNIT} is not running (hermesctl host up)")


# ----------------------------------------------------------------------- refs

def user_refs():
    try:
        return json.loads(USER_REFS.read_text())
    except (FileNotFoundError, json.JSONDecodeError):
        return {}


def save_user_refs(refs):
    USER_REFS.parent.mkdir(parents=True, exist_ok=True)
    USER_REFS.write_text(json.dumps(refs, indent=2) + "\n")


def all_refs():
    return {**user_refs(), **REFS}  # Nix-declared wins


def ensure_refs():
    """Self-heal: mount any ref that is missing (boot normally does this via REFS_UNIT)."""
    ensure_root()
    for name, ref in all_refs().items():
        src = Path(ref["src"]).expanduser()
        if not src.is_dir():
            warn(f"ref {name}: {src} is not a directory, skipped")
            continue
        try:
            mount_dir(src.resolve(), ref.get("mode", "ro"), True, name)
        except SystemExit:
            warn(f"ref {name} skipped")


# ---------------------------------------------------------------- pins / locks

def is_pinned(name):
    if name in all_refs():
        return True
    return (PINDIR / name).exists() and is_mounted(ROOT / name)


def pin(name):
    PINDIR.mkdir(parents=True, exist_ok=True)
    (PINDIR / name).touch()


def unpin(name):
    (PINDIR / name).unlink(missing_ok=True)


def in_use(name):
    LOCKDIR.mkdir(parents=True, exist_ok=True)
    with open(LOCKDIR / f"{name}.lock", "a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
    return False


def force_umount(target):
    if is_mounted(target) and sudo(CFG["umount"], str(target)).returncode != 0:
        warn(f"failed to unmount {target}")
        return
    unpin(target.name)
    sudo("rmdir", str(target), quiet=True)


def try_release(name):
    if is_pinned(name):
        return
    target = ROOT / name
    LOCKDIR.mkdir(parents=True, exist_ok=True)
    with open(LOCKDIR / f"{name}.lock", "w") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return
        if not is_mounted(target):
            return
        if sudo(CFG["umount"], str(target), quiet=True).returncode == 0:
            sudo("rmdir", str(target), quiet=True)
        else:
            warn(f"{target} is still busy, left mounted (hermesctl mount rm -f {name})")


# ---------------------------------------------------------------- mount specs

class Spec(NamedTuple):
    src: Path
    mode: str
    name: str


def name_for(src, mode):
    base = re.sub(r"[^A-Za-z0-9._-]", "_", Path(src).name).lstrip(".-_") or "root"
    digest = hashlib.sha1(str(src).encode()).hexdigest()[:6]
    return f"{base}-{digest}-{mode}"


def check_src(path, rw):
    src = Path(path).expanduser().resolve()
    home = Path.home().resolve()
    if src == Path("/"):
        die("refusing to mount /")
    if src == home:
        die("refusing to mount $HOME, pick a subdirectory")
    for d in [home / p for p in DENY_HOME] + [Path(p) for p in DENY_ABS]:
        if src == d or d in src.parents:
            die(f"refusing to mount {src} (inside {d})")
    return src


def make_spec(text, default_rw):
    parts = text.split(":")
    mode = "rw" if default_rw else "ro"
    if len(parts) > 1 and parts[-1] in ("ro", "rw"):
        mode = parts.pop()
    name = None
    if len(parts) > 1:
        name = parts.pop()
        if not NAME_RE.fullmatch(name):
            die(f"invalid mount name {name!r} (allowed: letters, digits, . _ -)")
    raw = ":".join(parts)
    if not Path(raw).expanduser().is_dir():
        die(f"not a directory: {raw}")
    src = check_src(raw, mode == "rw")
    return Spec(src, mode, name or name_for(src, mode))


def confirm(question, yes):
    if yes:
        return True
    if not sys.stdin.isatty():
        die("mounting needs confirmation, pass --yes")
    return input(f"{question} [y/N] ").strip().lower().startswith("y")


def mount_dir(src, mode, yes, name):
    target = ROOT / name
    entry = mount_entry(target)
    if entry:
        cur_src, opts = entry
        if Path(cur_src) != src:
            die(f"name '{name}' is already mounted from {cur_src} "
                f"(pick another name or `hermesctl mount rm {name}`)")
        if mount_mode(opts) != mode:
            die(f"'{name}' is already mounted {mount_mode(opts)} (`hermesctl mount rm {name}` first)")
        return
    label = "READ-WRITE" if mode == "rw" else "read-only"
    if not confirm(f"Mount {src} into the container at {MOUNT_IN}/{name} ({label})?", yes):
        die("aborted")
    opts = "allow_other" + (",ro" if mode == "ro" else "")
    sudo("mkdir", "-p", str(target))
    result = sudo(
        CFG["bindfs"], "-o", opts,
        f"--force-user={CFG['bot_host_uid']}",
        f"--force-group={CFG['coding_gid']}",
        f"--create-for-user={os.getuid()}",
        f"--create-for-group={os.getgid()}",
        "--chown-ignore", "--chgrp-ignore",
        str(src), str(target),
    )
    if result.returncode != 0:
        sudo("rmdir", str(target), quiet=True)
        die(f"bindfs failed for {src}")


class Mounts:
    """Session-scoped mounts: shared-locked while the session runs, released after."""

    def __init__(self):
        self.held = {}

    def acquire(self, spec, yes):
        if spec.name not in self.held:
            LOCKDIR.mkdir(parents=True, exist_ok=True)
            lock = open(LOCKDIR / f"{spec.name}.lock", "w")
            fcntl.flock(lock, fcntl.LOCK_SH)
            self.held[spec.name] = lock
        if not is_mounted(ROOT / spec.name):
            unpin(spec.name)  # stale pin left over from before a reboot
        mount_dir(spec.src, spec.mode, yes, spec.name)
        return f"{MOUNT_IN}/{spec.name}"

    def release_all(self):
        names = list(self.held)
        for lock in self.held.values():
            lock.close()
        self.held.clear()
        for name in names:
            try_release(name)


def pin_specs(specs, yes):
    ensure_root()
    for s in specs:
        mount_dir(s.src, s.mode, yes, s.name)
        pin(s.name)
        print(f"{s.src} -> {MOUNT_IN}/{s.name} ({s.mode})")


# ------------------------------------------------------------------ container

def omh_cmd(args):
    # --hermes-home is a global flag: it must come before the subcommand
    return [CFG["omh_bin"], "--hermes-home", CFG["hermes_home"], *args]


def parse_env(items):
    env = {}
    for item in items:
        key, sep, value = item.partition("=")
        if not sep or not key:
            die(f"bad --env {item!r}, expected KEY=VALUE")
        env[key] = value
    return env


def run_in(workdir, cmd, extra_env=None):
    tty = "-it" if sys.stdin.isatty() and sys.stdout.isatty() else "-i"
    env = {
        "HERMES_HOME": CFG["hermes_home"],
        "HOME": f"/home/{BOT}",
        "PATH": CFG["container_path"],
        "LANG": "C.UTF-8",
        "TERM": os.environ.get("TERM", "xterm-256color"),
    }
    if "COLORTERM" in os.environ:
        env["COLORTERM"] = os.environ["COLORTERM"]
    env.update(extra_env or {})
    argv = [
        "sudo", CFG["machinectl"], "-q", "shell", "hermes-host@",
        CFG["podman"], "exec", tty, "--user", BOT, "--workdir", workdir,
    ]
    for key, value in env.items():
        argv += ["-e", f"{key}={value}"]
    return subprocess.call([*argv, CFG["container"], *cmd])


def resolve_workdir(workdir, paths):
    base = paths[0] if paths else CFG["default_workdir"]
    if not workdir:
        return base
    if workdir.startswith("/"):
        return posixpath.normpath(workdir)
    path = posixpath.normpath(f"{base}/{workdir}")
    if posixpath.commonpath([base, path]) != base:
        die(f"workdir escapes the mount: {workdir}")
    return path


def session(ns, build_cmd):
    specs = [make_spec(m, ns.rw) for m in ns.mount]
    if ns.rw and not specs:
        warn("--rw has no effect without -m")
    require_up()
    ensure_refs()
    mounts = Mounts()
    try:
        paths = [mounts.acquire(s, ns.yes) for s in specs]
        return run_in(resolve_workdir(ns.workdir, paths), build_cmd(specs), parse_env(ns.env))
    finally:
        mounts.release_all()


# ------------------------------------------------------------ session commands

def cmd_tui(ns):
    return session(ns, lambda specs: [CFG["hermes_bin"], "--tui", *ns.rest])


def cmd_hermes(ns):
    return session(ns, lambda specs: [CFG["hermes_bin"], *ns.rest])


def cmd_omh(ns):
    def build(specs):
        if specs and specs[0].mode == "ro":
            warn("note: project mounted read-only, omh cannot write .omh/ "
                 "(project memory, handoffs); use -W")
        return omh_cmd(ns.rest)
    return session(ns, build)


def cmd_shell(ns):
    return session(ns, lambda specs: ns.rest or [CFG["shell"]])


def cmd_desktop(ns):
    specs = [make_spec(m, ns.rw) for m in ns.mount]
    ensure_refs()
    if not unit_active() and sudo(CFG["systemctl"], "start", UNIT).returncode != 0:
        die(f"failed to start {UNIT}")
    if specs:
        pin_specs(specs, ns.yes)
    DESKTOP_LOG.parent.mkdir(parents=True, exist_ok=True)
    log = open(DESKTOP_LOG, "ab")
    subprocess.Popen(
        [CFG["desktop_bin"], *ns.rest],
        stdin=subprocess.DEVNULL,
        stdout=log,
        stderr=log,
        start_new_session=True,
        close_fds=True,
    )
    return 0


# --------------------------------------------------------------- mount group

def list_mounts(as_json=False):
    refs = all_refs()
    rows = []
    for target, opts, source in mountinfo():
        if not target.startswith(f"{ROOT}/"):
            continue
        name = Path(target).name
        rows.append({
            "name": name,
            "mode": mount_mode(opts),
            "source": source,
            "path": f"{MOUNT_IN}/{name}",
            "in_use": in_use(name),
            "pinned": is_pinned(name),
            "ref": name in refs,
        })
    if as_json:
        print(json.dumps(rows, indent=2))
        return
    if not rows:
        print("(no mounts)")
        return
    width = max(len(r["name"]) for r in rows)
    for r in rows:
        flags = "".join(f"  [{k}]" for k, v in (
            ("in use", r["in_use"]), ("pinned", r["pinned"] and not r["ref"]), ("ref", r["ref"])) if v)
        print(f"{r['name']:<{width}}  {r['mode']}  {r['source']} -> {r['path']}{flags}")


def cmd_mount_add(ns):
    specs = [make_spec(m, ns.rw) for m in ns.mount]
    if not specs:
        die("usage: hermesctl mount add [-W] [-y] -m SRC[:NAME][:ro|rw] ...")
    pin_specs(specs, ns.yes)
    if not unit_active():
        warn(f"note: {UNIT} is not running, mounts appear once it starts")
    return 0


def cmd_mount_ls(ns):
    list_mounts(ns.json)
    return 0


def resolve_targets(targets):
    mounted = {Path(t).name: s for t, _, s in mountinfo() if t.startswith(f"{ROOT}/")}
    names = []
    for t in targets:
        if t in mounted:
            names.append(t)
            continue
        p = Path(t).expanduser()
        hits = []
        if p.exists():
            rp = str(p.resolve())
            hits = [n for n, s in mounted.items() if s == rp]
        if hits:
            names += hits
        else:
            warn(f"no mount matches {t}")
    return list(dict.fromkeys(names))


def cmd_mount_rm(ns):
    if ns.all:
        names = [p.name for p in ROOT.iterdir() if p.is_dir()] if ROOT.is_dir() else []
    elif ns.targets:
        names = resolve_targets(ns.targets)
    else:
        die("usage: hermesctl mount rm [-f] --all | NAME|DIR...")
    refs = all_refs()
    for name in names:
        if name in refs and not ns.force:
            warn(f"{name} is a ref, skipped (use -f, or `hermesctl ref rm {name}`)")
            continue
        if in_use(name) and not ns.force:
            warn(f"{name} is in use by a session, skipped (use -f)")
            continue
        force_umount(ROOT / name)
    return 0


def cmd_mount_prune(ns):
    if ROOT.is_dir():
        for p in sorted(ROOT.iterdir()):
            if p.is_dir():
                try_release(p.name)
    return 0


# ----------------------------------------------------------------- ref group

def cmd_ref_ls(ns):
    mine = user_refs()
    for name, ref in sorted(all_refs().items()):
        origin = "nix" if name in REFS else "user"
        state = "mounted" if is_mounted(ROOT / name) else "NOT mounted"
        print(f"{name}  {ref.get('mode', 'ro')}  {ref['src']}  [{origin}] [{state}]")
    if not REFS and not mine:
        print("(no refs)")
    return 0


def cmd_ref_add(ns):
    if not NAME_RE.fullmatch(ns.name):
        die(f"invalid ref name {ns.name!r}")
    if ns.name in REFS:
        die(f"{ns.name} is defined in the Nix config")
    if not Path(ns.src).expanduser().is_dir():
        die(f"not a directory: {ns.src}")
    src = check_src(ns.src, ns.rw)
    mode = "rw" if ns.rw else "ro"
    ensure_root()
    mount_dir(src, mode, True, ns.name)
    refs = user_refs()
    refs[ns.name] = {"src": str(src), "mode": mode}
    save_user_refs(refs)
    print(f"{src} -> {MOUNT_IN}/{ns.name} ({mode}), remounted on every hermesctl run")
    return 0


def cmd_ref_rm(ns):
    if ns.name in REFS:
        die(f"{ns.name} is defined in the Nix config, remove it there")
    refs = user_refs()
    if ns.name not in refs:
        die(f"no such ref: {ns.name}")
    if in_use(ns.name) and not ns.force:
        die(f"{ns.name} is in use by a session (use -f)")
    del refs[ns.name]
    save_user_refs(refs)
    force_umount(ROOT / ns.name)
    return 0


# ---------------------------------------------------------------- host group

def cmd_host_up(ns):
    if sudo(CFG["systemctl"], "start", UNIT).returncode != 0:
        return 1
    ensure_refs()
    return 0


def cmd_host_down(ns):
    return sudo(CFG["systemctl"], "stop", UNIT).returncode


def cmd_host_restart(ns):
    if sudo(CFG["systemctl"], "restart", UNIT).returncode != 0:
        return 1
    ensure_refs()
    return 0


def cmd_host_status(ns):
    print(f"{UNIT}: {'active' if unit_active() else 'inactive'}")
    if REFS_UNIT:
        print(f"{REFS_UNIT}: {'active' if svc_active(REFS_UNIT) else 'inactive'}")
    print(f"{ROOT}: {'shared mount' if is_mounted(ROOT) and root_shared() else 'NOT a shared mount'}")
    list_mounts()
    return 0


def cmd_host_logs(ns):
    args = ["-u", UNIT, "-n", str(ns.lines)]
    args += ["-f"] if ns.follow else ["--no-pager"]
    if ns.since:
        args += ["--since", ns.since]
    return sudo(CFG["journalctl"], *args, *ns.rest).returncode


def cmd_host_doctor(ns):
    bad = 0

    def check(label, ok, hint=""):
        nonlocal bad
        print(f"[{'ok' if ok else 'FAIL'}] {label}" + ("" if ok else f"  ({hint})"))
        if not ok:
            bad += 1

    up = unit_active()
    check(f"{UNIT} is active", up, "hermesctl host up")
    if REFS_UNIT:
        check(f"{REFS_UNIT} is active", svc_active(REFS_UNIT), f"systemctl status {REFS_UNIT}")
    check(f"{ROOT} is a shared mount", is_mounted(ROOT) and root_shared(),
          "systemctl status hermes-mount-root")
    for key in ("podman", "machinectl", "bindfs", "umount", "systemctl", "journalctl", "desktop_bin"):
        check(f"{key} present", Path(CFG[key]).exists(), CFG[key])
    for name, ref in all_refs().items():
        check(f"ref {name} mounted", is_mounted(ROOT / name), f"hermesctl host up (src: {ref['src']})")
    if up:
        for label, cmd in (
            ("hermes doctor", [CFG["hermes_bin"], "doctor"]),
            ("omh doctor", omh_cmd(["doctor"])),
        ):
            print(f"\n== {label} ==", flush=True)
            if run_in(CFG["default_workdir"], cmd) != 0:
                bad += 1
    return 1 if bad else 0


# --------------------------------------------------------------------- parser

def session_opts():
    p = argparse.ArgumentParser(add_help=False)
    p.add_argument("-m", "--mount", action="append", default=[], metavar="SRC[:NAME][:ro|rw]",
                   help="mount a directory (repeatable)")
    p.add_argument("-W", "--rw", action="store_true", help="default to writable for -m specs without :ro/:rw")
    p.add_argument("-y", "--yes", action="store_true", help="do not ask before mounting")
    return p


def build_parser():
    fmt = argparse.RawDescriptionHelpFormatter
    top = argparse.ArgumentParser(
        prog="hermesctl", formatter_class=fmt, epilog=EPILOG,
        description="Run Hermes in its container with host directories mounted in.\n"
                    "No command = `tui`.")
    sub = top.add_subparsers(dest="cmd", metavar="COMMAND")

    def session_cmd(name, func, help_, workdir=True, env=True):
        p = sub.add_parser(name, parents=[session_opts()], help=help_, description=help_)
        if workdir:
            p.add_argument("-C", "--workdir", metavar="PATH",
                           help="container workdir; relative = inside the first mount")
        if env:
            p.add_argument("-e", "--env", action="append", default=[], metavar="KEY=VALUE",
                           help="extra environment variable (repeatable)")
        p.set_defaults(func=func, passthrough=True)
        return p

    session_cmd("tui", cmd_tui, "hermes --tui (default); args after -- go to hermes")
    session_cmd("hermes", cmd_hermes, "run any hermes command: hermesctl hermes -- doctor")
    session_cmd("omh", cmd_omh, "run oh-my-hermes: hermesctl omh -W -m . -- setup")
    session_cmd("shell", cmd_shell, "shell, or `-- CMD...`, in the container")
    d = session_cmd("desktop", cmd_desktop, "pin-mount, start the container if needed, launch Hermes Desktop",
                    workdir=False, env=False)
    d.set_defaults(passthrough=True)

    mount = sub.add_parser("mount", help="manage mounts without a session")
    ms = mount.add_subparsers(dest="sub", metavar="ACTION")
    ms.required = True
    p = ms.add_parser("add", parents=[session_opts()], help="pin a mount (survives sessions and prune)")
    p.set_defaults(func=cmd_mount_add)
    p = ms.add_parser("ls", help="list mounts")
    p.add_argument("--json", action="store_true")
    p.set_defaults(func=cmd_mount_ls)
    p = ms.add_parser("rm", help="unmount by name or source dir (also unpins)")
    p.add_argument("targets", nargs="*", metavar="NAME|DIR")
    p.add_argument("--all", action="store_true", help="every mount except refs")
    p.add_argument("-f", "--force", action="store_true", help="also refs and mounts in use")
    p.set_defaults(func=cmd_mount_rm)
    p = ms.add_parser("prune", help="unmount everything unused and unpinned")
    p.set_defaults(func=cmd_mount_prune)

    ref = sub.add_parser("ref", help="fixed-name mounts that are always present")
    rs = ref.add_subparsers(dest="sub", metavar="ACTION")
    rs.required = True
    p = rs.add_parser("ls", help="list refs (nix + user)")
    p.set_defaults(func=cmd_ref_ls)
    p = rs.add_parser("add", help="add a user ref, remounted on every hermesctl run")
    p.add_argument("name")
    p.add_argument("src")
    p.add_argument("-W", "--rw", action="store_true")
    p.set_defaults(func=cmd_ref_add)
    p = rs.add_parser("rm", help="remove a user ref")
    p.add_argument("name")
    p.add_argument("-f", "--force", action="store_true", help="even if in use by a session")
    p.set_defaults(func=cmd_ref_rm)

    host = sub.add_parser("host", help="container service control")
    hs = host.add_subparsers(dest="sub", metavar="ACTION")
    hs.required = True
    for name, func, help_ in (
        ("up", cmd_host_up, "start the container"),
        ("down", cmd_host_down, "stop the container"),
        ("restart", cmd_host_restart, "restart the container"),
        ("status", cmd_host_status, "service state, refs, mounts"),
        ("doctor", cmd_host_doctor, "host checks + hermes doctor + omh doctor"),
    ):
        hs.add_parser(name, help=help_).set_defaults(func=func)
    p = hs.add_parser("logs", help="journalctl of the service; extra args after --")
    p.add_argument("-f", "--follow", action="store_true")
    p.add_argument("-n", "--lines", type=int, default=200)
    p.add_argument("--since", metavar="TIME")
    p.set_defaults(func=cmd_host_logs, passthrough=True)
    return top, sub


def split_dd(argv):
    if "--" in argv:
        i = argv.index("--")
        return argv[:i], argv[i + 1:]
    return argv, []


def main():
    parser, sub = build_parser()
    argv, rest = split_dd(sys.argv[1:])
    if argv == ["--ctl-help"]:
        parser.print_help()
        return 0
    if not argv or (argv[0] not in sub.choices and argv[0] not in ("-h", "--help")):
        argv.insert(0, "tui")
    ns = parser.parse_args(argv)
    ns.rest = rest
    if rest and not getattr(ns, "passthrough", False):
        die("this command takes no arguments after --")
    return ns.func(ns)


if __name__ == "__main__":
    for sig in (signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, lambda n, _: sys.exit(128 + n))
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
