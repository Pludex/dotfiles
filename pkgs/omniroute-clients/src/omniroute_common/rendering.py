"""Output rendering utilities."""
import json
import re


_TAG = re.compile(r"</?(result|search_results|answer|search_error|web_tools|dry_run|saved)\b", re.I)


def esc_text(s):
    """Escape text for XML output."""
    return _TAG.sub(lambda m: "&lt;" + m.group(0)[1:], str(s))


def esc_attr(s):
    """Escape attribute value for XML."""
    return str(s).replace("&", "&amp;").replace('"', "&quot;").replace("<", "&lt;").replace("\n", " ")


def render_block(b, tool):
    """Render a result block as XML."""
    if "head" not in b:
        return json.dumps(b, indent=1, ensure_ascii=False)
    head = " ".join(f'{k}="{esc_attr(v)}"' for k, v in b["head"].items())
    extra = "".join(f' {k}="{esc_attr(v)}"' for k, v in (b.get("meta") or {}).items() if v not in (None, ""))
    lines = [
        f'<search_results tool="{tool}" {head} count="{len(b["results"])}" '
        f'truncated="{str(b["truncated"]).lower()}"{extra}>'
    ]
    if b.get("answer"):
        lines += ["  <answer>", esc_text(b["answer"]), "  </answer>"]
    for rank, (attrs, body) in enumerate(b["results"], 1):
        ra = "".join(f' {k}="{esc_attr(v)}"' for k, v in attrs.items() if v not in (None, "", 0))
        lines += [f'  <result rank="{rank}"{ra}>', esc_text(body), "  </result>"]
    lines.append("</search_results>")
    if b.get("note"):
        lines.append(b["note"])
    return "\n".join(lines)


def render_outcome(o):
    """Render an outcome (ok/dry/error) as XML."""
    if o["kind"] == "ok":
        return render_block(o["block"], o.get("tool", ""))
    if o["kind"] == "dry":
        return f'<dry_run {o["name"]}="{esc_attr(o["key"])}">\\n{esc_text(o["text"])}\\n</dry_run>'
    msg = " ".join(str(o["msg"]).split())
    return f'<search_error {o["name"]}="{esc_attr(o["key"])}" code="{o["code"]}">{esc_text(msg)}</search_error>'
