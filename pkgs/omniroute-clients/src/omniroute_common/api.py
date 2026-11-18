"""API decorator and multi-item runner."""
import concurrent.futures as cf
import functools
import inspect
import json
import time

from .constants import MAX_ITEMS, DEFAULT_LIMIT, STATE, NOTICE
from .errors import ToolError, DryRun
from .rendering import render_outcome
from .text import norm_url


def unique_items(items, key):
    """Remove duplicate items."""
    seen, out = set(), []
    for it in items:
        sig = json.dumps(it, sort_keys=True, default=str)
        if sig in seen:
            if STATE["verbose"]:
                print(f"[runner] dropped duplicate {key}: {it.get(key)}", file=__import__("sys").stderr)
            continue
        seen.add(sig)
        out.append(it)
    return out


def apply_budget(items, key, run):
    """Apply total_chars budget across items."""
    if run.get("out"):
        if key == "url":
            for it in items:
                it.setdefault("max_chars", 10 ** 9)
        return
    total = run.get("total_chars")
    if not total:
        return
    per = max(500, total // len(items))
    for it in items:
        cap = per if key == "url" else max(200, per // max(1, it.get("limit", DEFAULT_LIMIT)))
        it["max_chars"] = min(it.get("max_chars", 10 ** 9), cap)


def dedupe_results(outcomes):
    """Remove duplicate URLs across outcomes."""
    seen = set()
    for o in outcomes:
        if o["kind"] != "ok" or "results" not in o["block"]:
            continue
        kept = []
        for attrs, body in o["block"]["results"]:
            k = norm_url(attrs.get("url") or "")
            if k and k in seen:
                continue
            seen.add(k)
            kept.append((attrs, body))
        o["block"]["results"] = kept


def configure(run):
    """Configure global state from run options."""
    import os
    STATE["verbose"] = bool(run.get("verbose")) or os.environ.get("WEB_TOOLS_VERBOSE") == "1"
    STATE["dry"] = bool(run.get("dry_run"))


def run_items(items, one, key, run, tool):
    """Run multiple items in parallel and return results."""
    from .errors import fail
    configure(run)
    if not items:
        fail(f"give at least one {key}.", 2)
    if len(items) > MAX_ITEMS:
        fail(f"at most {MAX_ITEMS} items per command, got {len(items)}. Split them into several commands.", 2)
    items = unique_items(items, key)
    total = run.get("total_timeout")
    STATE["deadline"] = time.monotonic() + total if total else None
    apply_budget(items, key, run)
    t0 = time.monotonic()

    def task(item):
        try:
            return {"kind": "ok", "block": one(**item), "tool": tool}
        except DryRun as e:
            return {"kind": "dry", "name": key, "key": item.get(key), "text": e.text}
        except ToolError as e:
            return {"kind": "error", "name": key, "key": item.get(key), "code": e.code, "msg": str(e)}
        except Exception as e:
            import os
            if os.environ.get("DEBUG"):
                raise
            return {"kind": "error", "name": key, "key": item.get(key), "code": 4,
                    "msg": f"unexpected failure ({type(e).__name__}: {e}). Retry; set DEBUG=1 for details."}

    workers = max(1, min(run.get("concurrency") or int(__import__("os").environ.get("WEB_TOOLS_CONCURRENCY", "4")), len(items)))
    if len(items) == 1:
        outcomes = [task(items[0])]
    else:
        with cf.ThreadPoolExecutor(max_workers=workers) as ex:
            outcomes = list(ex.map(task, items))
    STATE["deadline"] = None

    if run.get("dedupe") and key == "query":
        dedupe_results(outcomes)
    ok = sum(o["kind"] == "ok" for o in outcomes)
    failed = sum(o["kind"] == "error" for o in outcomes)
    dry = sum(o["kind"] == "dry" for o in outcomes)
    ms = int((time.monotonic() - t0) * 1000)

    parts = [NOTICE]
    many = len(outcomes) > 1
    if many:
        parts.append(f'<web_tools tool="{tool}" ok="{ok}" failed="{failed}" elapsed_ms="{ms}">')
    parts += [render_outcome(o) for o in outcomes]
    if many:
        parts.append("</web_tools>")
    code = 0
    if failed and not ok and not dry:
        code = next(o["code"] for o in outcomes if o["kind"] == "error")
    
    from types import SimpleNamespace
    return SimpleNamespace(text="\n".join(parts), code=code, outcomes=outcomes, ok=ok, failed=failed, run=run)


def api(key):
    """Decorator to make a function work with single or multiple items."""
    def deco(fn):
        @functools.wraps(fn)
        def wrapper(items, *, concurrency=None, total_timeout=None, total_chars=None, dedupe=False, **shared):
            many = isinstance(items, (list, tuple))
            norm = []
            for it in (items if many else [items]):
                if isinstance(it, str):
                    d = {key: it}
                elif isinstance(it, dict):
                    d = dict(it)
                else:
                    from .errors import fail
                    fail(f"{key} items must be strings or dicts, got {type(it).__name__}.", 2)
                if key not in d:
                    from .errors import fail
                    fail(f"each item needs a '{key}' field.", 2)
                norm.append({**shared, **d})
            run = {"concurrency": concurrency, "total_timeout": total_timeout,
                   "total_chars": total_chars, "dedupe": dedupe}
            # Extract TOOL from the calling module
            frame = inspect.currentframe().f_back.f_back
            tool = frame.f_globals.get("TOOL", "")
            res = run_items(norm, fn, key, run, tool)
            want_raw = any(n.get("raw") for n in norm)
            if not many:
                o = res.outcomes[0]
                if o["kind"] == "error":
                    raise ToolError(o["msg"], o["code"])
                return o["block"] if want_raw and o["kind"] == "ok" else res.text
            if res.failed and not res.ok:
                first = next(o for o in res.outcomes if o["kind"] == "error")
                raise ToolError(f"all {res.failed} items failed; first error: {first['msg']}", res.code)
            if want_raw:
                return [o.get("block") for o in res.outcomes]
            return res.text

        wrapper.one = fn
        wrapper.key = key
        return wrapper
    return deco
