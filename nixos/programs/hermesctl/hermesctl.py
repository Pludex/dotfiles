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
LOCKDIR = Path(os.environ.get("XDG_RUNTIME_DIR", "/tmp")) / "hermesctl"

USAGE = """\
hermesctl [--rw|-W] [--yes] [DIR...] [hermes args...]
  DIR       leading path (., .., or anything containing a slash) to mount into the container
  --rw, -W  mount DIR writable (default: read-only)
  --yes     do not ask before mounting
  No args, or only flags: runs `hermes --tui`. A subcommand is passed through as is.
hermesctl mounts
hermesctl umount --all | DIR...
hermesctl shell [cmd...]
hermesctl -- args...    pass everything to hermes untouched
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


def try_release(name):
    target = ROOT / name
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
        for target, opts, source in mountinfo():
            if target.startswith(f"{ROOT}/"):
                print(target, source, opts)
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
    if head == "shell":
        return run_in(CFG["default_workdir"], argv[1:] or [CFG["shell"]])

    if head == "--":
        rw, yes, dirs, args = False, False, [], argv[1:]
    else:
        rw, yes, dirs, args = parse(argv)
    if rw and not dirs:
        print("hermesctl: --rw has no effect without a directory", file=sys.stderr)

    inject = not any(a in ("--tui", "-h", "--help", "-V", "--version") for a in args)
    if args and not args[0].startswith("-"):
        inject = False
    if inject:
        args = ["--tui", *args]

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
        return run_in(workdir, [CFG["hermes_bin"], *args])
    finally:
        mounts.release_all()


if __name__ == "__main__":
    signal.signal(signal.SIGTERM, lambda *_: sys.exit(143))
    try:
        sys.exit(main())
    except KeyboardInterrupt:
        sys.exit(130)
