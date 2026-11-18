"""CLI runner and execution utilities."""
import json
import os
import sys
from types import SimpleNamespace

from .constants import NEG, RUN_OPTIONS
from .errors import ToolError, die
from .rendering import esc_attr


def want_color(mode):
    """Determine if colored output should be used.
    
    Priority: CLI argument > WEB_TOOLS_COLOR env var > auto detection
    """
    # mode is the --color CLI argument (highest priority)
    if mode is not None:
        mode = mode.lower()
        if mode == "always":
            return True
        if mode == "never":
            return False
        # mode == "auto" falls through to auto-detection
    
    # Check WEB_TOOLS_COLOR env var (second priority)
    env_color = os.environ.get("WEB_TOOLS_COLOR")
    if env_color:
        env_color = env_color.lower()
        if env_color == "always":
            return True
        if env_color == "never":
            return False
        # env_color == "auto" falls through
    
    # Auto-detection (lowest priority)
    return sys.stdout.isatty() and "NO_COLOR" not in os.environ and os.environ.get("TERM") != "dumb"


def colorize(s):
    """Add ANSI color codes to XML output."""
    import re
    out = []
    _TAGLINE = re.compile(r"^</?(search_results|result|answer|web_tools|dry_run|saved)\b")
    for line in s.split("\n"):
        st = line.lstrip()
        if st.startswith("<!--"):
            out.append(f"\x1b[90m{line}\x1b[0m")
        elif st.startswith("<search_error"):
            out.append(f"\x1b[31m{line}\x1b[0m")
        elif _TAGLINE.match(st):
            line = re.sub(r'(\w+)=("([^"])*")', "\x1b[2m\\1\x1b[0m=\x1b[32m\\2\x1b[0m", line)
            line = re.sub(r"^(\s*</?\w+)", "\x1b[1;36m\\1\x1b[0m", line)
            out.append(line)
        else:
            out.append(re.sub(r"…\[truncated[^\]]*\]", lambda m: f"\x1b[33m{m.group(0)}\x1b[0m", line))
    return "\n".join(out)


def save_out(res):
    """Save full output to file and replace with preview."""
    from xml.sax.saxutils import quoteattr
    from .text import cut
    path = os.path.abspath(os.path.expanduser(res.run["out"]))
    try:
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8") as f:
            f.write(res.text + "\n")
    except OSError as e:
        from .errors import fail
        fail(f"cannot write {path}: {e}", 2)
    preview, _ = cut(res.text, 1500)
    res.text = (
        f'<saved path={quoteattr(path)} bytes="{os.path.getsize(path)}" ok="{res.ok}" failed="{res.failed}" />\n'
        f"<!-- preview; the full output is in the file -->\n{preview}"
    )


def emit(res):
    """Emit result to stdout with appropriate coloring and error handling."""
    if res.code and len(res.outcomes) == 1:
        die(res.outcomes[0]["msg"], res.code)
    out = res.text
    if want_color(res.run.get("color")):
        out = colorize(out)
    if out:
        print(out)
    if res.code:
        print(f"error: all {res.failed} items failed, see <search_error>.", file=sys.stderr)
    elif res.failed:
        print(f"warning: {res.failed} of {len(res.outcomes)} items failed, see <search_error>.", file=sys.stderr)
    return res.code


def parse_flags(sub, flags, value="_"):
    """Parse flags into dict."""
    ns = vars(sub.parse_args([*flags, "--", value]))
    ns.pop("command", None)
    ns.pop("func", None)
    return ns


def split_tokens(tokens, sub, key):
    """Split command line tokens into run options, global flags, and per-item segments."""
    from .errors import fail
    run, glob, segs, cur, only_pos, i = {}, [], [], None, False, 0
    takes = {o: a.nargs != 0 for a in sub._actions for o in a.option_strings}

    def need(name, i):
        if i >= len(tokens):
            fail(f"{name} needs a value.", 2)
        return tokens[i]

    self_name = sub.prog if hasattr(sub, "prog") else "tool"
    while i < len(tokens):
        t = tokens[i]
        if only_pos or t == "-" or not t.startswith("-") or NEG.match(t):
            cur = {"value": t, "flags": []}
            segs.append(cur)
            i += 1
            continue
        if t == "--":
            only_pos = True
            i += 1
            continue
        name, eq, val = t.partition("=")
        if name in RUN_OPTIONS:
            dest, typ = RUN_OPTIONS[name][:2]
            if typ is None:
                run[dest] = True
            else:
                if not eq:
                    i += 1
                    val = need(name, i)
                try:
                    run[dest] = typ(val)
                except ValueError:
                    fail(f"{name} expects {typ.__name__}, got {val!r}.", 2)
        elif name == "--" + key:
            if not eq:
                i += 1
                val = need(name, i)
            cur = {"value": val, "flags": []}
            segs.append(cur)
        elif name in takes:
            if takes[name] and not eq:
                i += 1
                t = f"{name}={need(name, i)}"
            (glob if cur is None else cur["flags"]).append(t)
        else:
            fail(f"unknown option {name}. Run `{self_name} --help`.", 2)
        i += 1
    return run, glob, segs


def execute(argv, commands, tool_name="tool"):
    """Execute CLI command with argument parsing."""
    import inspect
    from .errors import fail
    from .api import run_items as do_run_items
    
    cmd = argv[0]
    if cmd not in commands:
        fail(f"unknown command '{cmd}'. Use {' or '.join(commands)}.", 2)
    sub = commands[cmd]
    func = sub.get_default("func")
    one, key = func.one, func.key
    run, glob, segs = split_tokens(argv[1:], sub, key)
    if run.get("color") is not None and run["color"] not in ("auto", "always", "never"):
        fail("--color must be auto, always or never.", 2)

    if run.get("json") is not None:
        if segs:
            fail("use positional items or --json, not both.", 2)
        src = sys.stdin.read() if run["json"] == "-" else run["json"]
        try:
            data = json.loads(src)
        except ValueError as e:
            fail(f"--json is not valid JSON: {e}.", 2)
        if isinstance(data, (str, dict)):
            data = [data]
        if not isinstance(data, list):
            fail("--json must be an array of items.", 2)
        base = parse_flags(sub, glob)
        base.pop(key)
        allowed = set(inspect.signature(one).parameters) - {"raw"}
        items = []
        for it in data:
            d = {key: it} if isinstance(it, str) else it
            if not isinstance(d, dict):
                fail("each --json item must be a string or an object.", 2)
            d = {k.replace("-", "_"): v for k, v in d.items()}
            bad = sorted(set(d) - allowed)
            if bad:
                fail(f"unknown option(s) {', '.join(bad)} in --json item. Allowed: {', '.join(sorted(allowed))}.", 2)
            if key not in d:
                fail(f"each --json item needs a '{key}' field.", 2)
            items.append({**base, **d})
    else:
        if not segs:
            fail(f"give at least one {key}. Example: {tool_name} {cmd} <{key}> [options]", 2)
        items = [parse_flags(sub, glob + s["flags"], s["value"]) for s in segs]
    
    return do_run_items(items, one, key, run, tool_name)
