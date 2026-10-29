import fcntl
import hashlib
import os
import re
import signal
import subprocess
import sys
from pathlib import Path

ROOT = Path(CFG["mount_root"])
MOUNT_IN = CFG["mount_in"]
BOT = CFG["bot_user"]
UNIT = CFG["unit"]
LOCKDIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hermesctl"

USAGE = """\
hermesctl [--rw|-W] [--yes] [DIR...] [hermes args...]
  DIR       leading path (., .., or anything containing a slash) to mount into the container
  --rw, -W  mount DIR writable (default: read-only)
  --yes     do not ask before mounting
  No args, or only flags: runs `hermes --tui` (the omh plugin loads from HERMES_HOME).
  A subcommand is passed through to hermes as is.

hermesctl [--rw|-W] [--yes] [DIR...] omh [omh args...]
  Runs oh-my-hermes inside the container with --hermes-home set.
  Bare `omh` opens Hermes with the OMH identity. Examples:
    hermesctl omh setup | doctor | model
    hermesctl --rw . omh          (omh writes .omh/ in the project: needs --rw)

hermesctl shell [cmd...]          shell (or command) in the container
hermesctl mounts                  list active mounts ([in use] = held by a session)
hermesctl umount --all | DIR...   force unmount
hermesctl host up|down|restart    start / stop / restart the container service
hermesctl host status             service state, mount root, mounts
hermesctl host logs [args]        journalctl of the service (default: last 200 lines)
hermesctl host doctor             host checks + `hermes doctor` + `omh doctor`
hermesctl host prune              unmount every mount no session is using
hermesctl -- args...              pass everything to hermes untouched
"""


def die(msg):
    print(f"hermesctl: {msg}", file=sys.stderr)
    sys.exit(1)


def sudo(*cmd, quiet=False):
    return subprocess.run(["sudo", *cmd], stderr=subprocess.DEVNULL if quiet else None)


def mountinfo():
    for line in Path("/proc/self/mountinfo").read_text().splitlines():
        left, _, right = line.partition(" - ")
        f, r = left.split(), right.split()
        yield f[4].replace("\\040", " "), f[5], r[1]


def is_mounted(path):
    return any(target == str(path) for target, _, _ in mountinfo())


def root_shared():
    for line in Path("/proc/self/mountinfo").read_text().splitlines():
        f = line.partition(" - ")[0].split()
        if f[4] == str(ROOT):
            return any(x.startswith("shared:") for x in f[6:])
    return False


def name_for(src, mode):
    base = re.sub(r"[^A-Za-z0-9._-]", "_", Path(src).name)
    digest = hashlib.sha1(str(src).encode()).hexdigest()[:6]
    return f"{base}-{digest}-{mode}"


def confirm(question, yes):
    if yes:
        return True
    if not sys.stdin.isatty():
        die("mounting needs confirmation, pass --yes")
    return input(f"{question} [y/N] ").strip().lower().startswith("y")


def unit_active():
    return subprocess.run(
        [CFG["systemctl"], "is-active", "--quiet", UNIT],
        stderr=subprocess.DEVNULL,
    ).returncode == 0


def require_up():
    if not unit_active():
        die(f"{UNIT} is not running (hermesctl host up)")


def omh_cmd(args):
    # --hermes-home is a global flag: it must come before the subcommand
    return [CFG["omh_bin"], "--hermes-home", CFG["hermes_home"], *args]


def run_in(workdir, cmd):
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
    argv = [
        "sudo", CFG["machinectl"], "-q", "shell", "hermes-host@",
        CFG["podman"], "exec", tty, "--user", BOT, "--workdir", workdir,
    ]
    for key, value in env.items():
        argv += ["-e", f"{key}={value}"]
    return subprocess.call([*argv, CFG["container"], *cmd])


def force_umount(target):
    if is_mounted(target):
        if sudo(CFG["umount"], str(target)).returncode != 0:
            print(f"hermesctl: failed to unmount {target}", file=sys.stderr)
            return
    sudo("rmdir", str(target), quiet=True)


def in_use(name):
    LOCKDIR.mkdir(parents=True, exist_ok=True)
    with open(LOCKDIR / f"{name}.lock", "a") as lock:
        try:
            fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        except BlockingIOError:
            return True
    return False


def try_release(name):
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
            print(f"hermesctl: {target} is still busy, left mounted (hermesctl umount --all)", file=sys.stderr)


def list_mounts():
    for target, opts, source in mountinfo():
        if target.startswith(f"{ROOT}/"):
            flag = "  [in use]" if in_use(Path(target).name) else ""
            print(target, source, opts + flag)


class Mounts:
    def __init__(self):
        self.held = {}

    def acquire(self, src, mode, yes):
        name = name_for(src, mode)
        target = ROOT / name
        if name not in self.held:
            LOCKDIR.mkdir(parents=True, exist_ok=True)
            lock = open(LOCKDIR / f"{name}.lock", "w")
            fcntl.flock(lock, fcntl.LOCK_SH)
            self.held[name] = lock
        if not is_mounted(target):
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
                die(f"bindfs failed for {src}")
        return f"{MOUNT_IN}/{name}"

    def release_all(self):
        names = list(self.held)
        for lock in self.held.values():
            lock.close()
        self.held.clear()
        for name in names:
            try_release(name)


def doctor():
    bad = 0

    def check(label, ok, hint=""):
        nonlocal bad
        print(f"[{'ok' if ok else 'FAIL'}] {label}" + ("" if ok else f"  ({hint})"))
        if not ok:
            bad += 1

    up = unit_active()
    check(f"{UNIT} is active", up, "hermesctl host up")
    check(f"{ROOT} is a shared mount", is_mounted(ROOT) and root_shared(),
          "systemctl status hermes-mount-root")
    for key in ("podman", "machinectl", "bindfs", "umount", "systemctl", "journalctl"):
        check(f"{key} present", Path(CFG[key]).exists(), CFG[key])
    if up:
        for label, cmd in (
            ("hermes doctor", [CFG["hermes_bin"], "doctor"]),
            ("omh doctor", omh_cmd(["doctor"])),
        ):
            print(f"\n== {label} ==", flush=True)
            if run_in(CFG["default_workdir"], cmd) != 0:
                bad += 1
    return 1 if bad else 0


def host(argv):
    verb, rest = (argv[0] if argv else ""), argv[1:]
    if verb in ("up", "down", "restart"):
        action = {"up": "start", "down": "stop", "restart": "restart"}[verb]
        return sudo(CFG["systemctl"], action, UNIT).returncode
    if verb == "status":
        print(f"{UNIT}: {'active' if unit_active() else 'inactive'}")
        print(f"{ROOT}: {'shared mount' if is_mounted(ROOT) and root_shared() else 'NOT a shared mount'}")
        list_mounts()
        return 0
    if verb == "logs":
        return sudo(CFG["journalctl"], "-u", UNIT, *(rest or ["-n", "200", "--no-pager"])).returncode
    if verb == "doctor":
        return doctor()
    if verb == "prune":
        if ROOT.is_dir():
            for p in sorted(ROOT.iterdir()):
                if p.is_dir():
                    try_release(p.name)
        return 0
    die("usage: hermesctl host up|down|restart|status|logs|doctor|prune")


def parse(argv):
    rw = yes = False
    dirs = []
    i = 0
    while i < len(argv):
        a = argv[i]
        if a in ("--rw", "-W"):
            rw = True
        elif a == "--yes":
            yes = True
        elif not a.startswith("-") and (a in (".", "..") or "/" in a) and Path(a).is_dir():
            dirs.append(a)
        else:
            break
        i += 1
    return rw, yes, dirs, argv[i:]


def main():
    argv = sys.argv[1:]
    head = argv[0] if argv else ""

    if head == "--ctl-help":
        print(USAGE, end="")
        return 0
    if head == "mounts":
        list_mounts()
        return 0
    if head == "umount":
        targets = argv[1:]
        if not targets:
            die("usage: hermesctl umount --all | DIR...")
        if targets == ["--all"]:
            names = [p.name for p in ROOT.iterdir() if p.is_dir()]
        else:
            names = [name_for(Path(t).resolve(), m) for t in targets for m in ("ro", "rw")]
        for name in names:
            force_umount(ROOT / name)
        return 0
    if head == "host":
        return host(argv[1:])
    if head == "shell":
        require_up()
        return run_in(CFG["default_workdir"], argv[1:] or [CFG["shell"]])

    tool = "hermes"
    if head == "--":
        rw, yes, dirs, args = False, False, [], argv[1:]
        cmd = [CFG["hermes_bin"], *args]
    else:
        rw, yes, dirs, args = parse(argv)
        if args and args[0] == "omh":
            tool, args = "omh", args[1:]
            cmd = omh_cmd(args)
        else:
            inject = not any(a in ("--tui", "-h", "--help", "-V", "--version") for a in args)
            if args and not args[0].startswith("-"):
                inject = False
            if inject:
                args = ["--tui", *args]
            cmd = [CFG["hermes_bin"], *args]
    if rw and not dirs:
        print("hermesctl: --rw has no effect without a directory", file=sys.stderr)
    if tool == "omh" and dirs and not rw:
        print("hermesctl: note: mounted read-only, omh cannot write .omh/ "
              "(project memory, handoffs) in the project; use --rw", file=sys.stderr)

    require_up()
    mode = "rw" if rw else "ro"
    mounts = Mounts()
    workdir = CFG["default_workdir"]
    try:
        for n, d in enumerate(dirs):
            src = Path(d).resolve()
            if src == Path("/"):
                die("refusing to mount /")
            if rw and src == Path.home():
                die("refusing to mount $HOME writable")
            path = mounts.acquire(src, mode, yes)
            if n == 0:
                workdir = path
        return run_in(workdir, cmd)
    finally:
        mounts.release_all()


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
