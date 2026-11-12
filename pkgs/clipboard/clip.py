import argparse
import os
import re
import shutil
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import quote, unquote

PROG = "clip"

EXT_TO_MIME = {
    "png": "image/png",
    "jpg": "image/jpeg",
    "jpeg": "image/jpeg",
    "gif": "image/gif",
    "webp": "image/webp",
    "svg": "image/svg+xml",
    "html": "text/html",
    "txt": "text/plain",
    "json": "application/json",
    "pdf": "application/pdf",
}

MIME_TO_EXT = {
    "image/png": "png",
    "image/jpeg": "jpg",
    "image/gif": "gif",
    "image/webp": "webp",
    "image/svg+xml": "svg",
    "text/html": "html",
    "application/json": "json",
    "application/pdf": "pdf",
}


def die(msg):
    print(f"{PROG}: {msg}", file=sys.stderr)
    sys.exit(1)


def file_output(*args, path=None, data=None):
    res = subprocess.run(
        ["file", "--brief", *args, "--", path or "-"],
        input=data,
        capture_output=True,
        check=True,
    )
    return res.stdout.decode().strip()


def classify(data):
    out = file_output("--mime", data=data)
    mime, _, enc = out.partition("; charset=")
    return mime if enc == "binary" else "text/plain"


def is_text(path):
    return file_output("--mime-encoding", path=path) != "binary"


def copy_main(argv):
    p = argparse.ArgumentParser(
        prog="c",
        description="Copy text, files or piped output to the Wayland clipboard.",
        epilog="Without -t/-f/-u, arguments that are all existing paths are copied "
        "as files (directories as file references); anything else is copied as text.",
    )
    p.add_argument("-t", "--text", dest="mode", action="store_const", const="text",
                   help="treat arguments as literal text")
    p.add_argument("-f", "--file", dest="mode", action="store_const", const="file",
                   help="treat arguments as files (copy content, text or image)")
    p.add_argument("-u", "--uri", dest="mode", action="store_const", const="uri",
                   help="copy files/dirs as file references (paste into file managers)")
    p.add_argument("-H", "--header", action="store_true",
                   help='prepend "==> name <==" before each file\'s content')
    p.add_argument("-a", "--append", action="store_true",
                   help="append to the current text clipboard")
    p.add_argument("-s", "--strip", action="store_true", help="strip the trailing newline")
    p.add_argument("-P", "--primary", action="store_true",
                   help="use the primary selection instead of the clipboard")
    p.add_argument("-o", "--once", action="store_true",
                   help="clear the clipboard after the first paste")
    p.add_argument("-x", "--clear", action="store_true", help="clear the clipboard")
    p.add_argument("args", nargs="*", metavar="text | file | dir")
    a = p.parse_args(argv)

    sel = ["--primary"] if a.primary else []

    if a.clear:
        os.execvp("wl-copy", ["wl-copy", *sel, "--clear"])

    mime = "text/plain"

    if not a.args:
        if sys.stdin.isatty():
            p.print_usage(sys.stderr)
            sys.exit(2)
        data = sys.stdin.buffer.read()
        mime = classify(data)
    else:
        mode = a.mode
        if mode is None:
            if all(os.path.exists(x) for x in a.args):
                mode = "uri" if any(os.path.isdir(x) for x in a.args) else "file"
            else:
                mode = "text"

        if mode == "text":
            data = " ".join(a.args).encode()
        elif mode == "uri":
            if not all(os.path.exists(x) for x in a.args):
                die("path not found")
            data = "".join(
                "file://" + quote(os.path.realpath(x), safe="/._~-") + "\n"
                for x in a.args
            ).encode()
            mime = "text/uri-list"
        else:
            for f in a.args:
                if not os.path.isfile(f):
                    die(f"{f}: not a regular file (use -u for directories)")
            if len(a.args) == 1 and not a.header:
                data = Path(a.args[0]).read_bytes()
                mime = classify(data)
            else:
                chunks = []
                for f in a.args:
                    if not is_text(f):
                        die(f"{f}: binary file, use -u to copy it as a file reference")
                    chunks += [f"==> {f} <==\n".encode(), Path(f).read_bytes(), b"\n"]
                data = b"".join(chunks)

    if not data:
        die("nothing to copy")

    if a.append:
        if mime != "text/plain":
            die("--append only works with text")
        res = subprocess.run(["wl-paste", *sel, "--no-newline"], capture_output=True)
        prev = res.stdout if res.returncode == 0 else b""
        if prev:
            data = prev + b"\n" + data

    cmd = ["wl-copy", *sel]
    if a.once:
        cmd.append("--paste-once")
    if a.strip:
        cmd.append("--trim-newline")
    cmd += ["--type", mime]
    subprocess.run(cmd, input=data, check=True)

    if sys.stderr.isatty():
        print(f"copied {mime} ({len(data)} bytes)", file=sys.stderr)


def mime_to_ext(mime):
    if mime in MIME_TO_EXT:
        return MIME_TO_EXT[mime]
    return "txt" if mime.startswith("text/") else "bin"


def stamp():
    return "clip-" + time.strftime("%Y%m%d-%H%M%S")


def save_uris(sel, dest):
    res = subprocess.run(
        ["wl-paste", *sel, "--type", "text/uri-list"], capture_output=True, text=True
    )
    n = 0
    for line in res.stdout.splitlines():
        line = line.rstrip("\r")
        if not line.startswith("file://"):
            continue
        src = Path(unquote(line[len("file://"):]))
        target = Path(dest) / src.name
        if src.is_dir():
            shutil.copytree(src, target, dirs_exist_ok=True)
        else:
            shutil.copy2(src, target)
        n += 1
    if n == 0:
        die("no file found in clipboard")
    if sys.stderr.isatty():
        print(f"saved {n} file(s) to {dest}", file=sys.stderr)


def paste_main(argv):
    p = argparse.ArgumentParser(
        prog="p",
        description="Print the Wayland clipboard, or save it to a file.",
        epilog="Binary content (images...) is never dumped to the terminal; "
        "use -o or a pipe. The MIME type is guessed from the output extension "
        "(p -o shot.png).",
    )
    p.add_argument("-o", "--output", nargs="?", const="", default=None, metavar="PATH",
                   help="save to PATH; with no PATH, auto-name it in the current dir; "
                   "if PATH is a directory, save there (copied files are restored "
                   "with their original names)")
    p.add_argument("-a", "--append", action="store_true",
                   help="append to the output file instead of refusing to overwrite")
    p.add_argument("-f", "--force", action="store_true", help="overwrite the output file")
    p.add_argument("-t", "--type", dest="mime", default="", metavar="MIME",
                   help="pick a specific MIME type (e.g. image/png)")
    p.add_argument("-l", "--list", action="store_true",
                   help="list the MIME types in the clipboard")
    p.add_argument("-n", "--no-newline", action="store_true",
                   help="strip the trailing newline")
    p.add_argument("-P", "--primary", action="store_true",
                   help="use the primary selection instead of the clipboard")
    a = p.parse_args(argv)

    sel = ["--primary"] if a.primary else []
    paste_opts = ["--no-newline"] if a.no_newline else []

    res = subprocess.run(["wl-paste", *sel, "--list-types"], capture_output=True, text=True)
    if res.returncode != 0:
        die("clipboard is empty")
    types = res.stdout.splitlines()

    if a.list:
        print("\n".join(types))
        return

    dest_set = a.output is not None
    dest = a.output or ""
    mime = a.mime

    if dest_set and not mime and dest and not os.path.isdir(dest):
        base = dest.rsplit("/", 1)[-1]
        ext = base.rpartition(".")[2].lower()
        if "." in base and EXT_TO_MIME.get(ext) in types:
            mime = EXT_TO_MIME[ext]

    if mime:
        eff = mime
    elif any(re.match(r"(text/|UTF8_STRING$|STRING$|TEXT$)", t) for t in types):
        eff = "text/plain"
    else:
        eff = types[0]

    type_opt = ["--type", mime] if mime else []

    if not dest_set:
        if sys.stdout.isatty() and not eff.startswith("text/"):
            die(f"clipboard holds {eff} (binary); use -o FILE or pipe it")
        os.execvp("wl-paste", ["wl-paste", *sel, *paste_opts, *type_opt])

    if dest and os.path.isdir(dest) and not mime and "text/uri-list" in types:
        save_uris(sel, dest)
        return

    if not dest:
        dest = f"{stamp()}.{mime_to_ext(eff)}"
    elif os.path.isdir(dest):
        dest = f"{dest.rstrip('/')}/{stamp()}.{mime_to_ext(eff)}"

    if os.path.exists(dest) and not a.append and not a.force:
        die(f"{dest} already exists (use -f to overwrite, -a to append)")

    res = subprocess.run(["wl-paste", *sel, *paste_opts, *type_opt], capture_output=True)
    if res.returncode != 0:
        die(res.stderr.decode().strip() or "wl-paste failed")

    with open(dest, "ab" if a.append else "wb") as fh:
        fh.write(res.stdout)

    if sys.stderr.isatty():
        print(f"saved to {dest} ({os.path.getsize(dest)} bytes)", file=sys.stderr)


def main():
    global PROG
    commands = {"c": copy_main, "p": paste_main}
    if len(sys.argv) < 2 or sys.argv[1] not in commands:
        print("usage: clip.py {c|p} [options]", file=sys.stderr)
        sys.exit(2)
    PROG = sys.argv[1]
    commands[PROG](sys.argv[2:])


if __name__ == "__main__":
    main()
