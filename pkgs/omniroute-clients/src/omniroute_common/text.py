"""Text processing utilities."""
import re
from urllib.parse import urlparse


def pick(item, *keys):
    """Return first non-empty value from item dict."""
    for k in keys:
        if item.get(k):
            return item[k]
    return ""


def short_date(s):
    """Truncate date to YYYY-MM-DD."""
    return str(s)[:10] if s else ""


def csv(v):
    """Convert comma-separated string or list to list."""
    if not v:
        return None
    if isinstance(v, str):
        v = v.split(",")
    return [str(x).strip() for x in v if str(x).strip()] or None


def normalize_http_url(u):
    """Normalize and validate HTTP(S) URL."""
    u = u.strip()
    if "://" not in u:
        u = "https://" + u
    p = urlparse(u)
    if p.scheme not in ("http", "https") or not p.netloc:
        from .errors import fail
        fail(f"not a valid http(s) URL: {u}. Pass a full URL such as https://example.com/page.", 2)
    return u


def cut(s, limit, offset=0, paged=False):
    """Cut string to limit chars, optionally with offset."""
    s = str(s)
    if offset == 0:
        s = s.strip()
    if offset and offset >= len(s):
        return f"[offset {offset} is past the end: the text has {len(s)} characters]", False
    end = offset + limit
    if len(s) <= end:
        return s[offset:], False
    chunk = s[offset:end].rstrip()
    marker = f"…[truncated at {end}, continue with --offset {end}]" if paged else "…[truncated]"
    return chunk + marker, True


def outline(page):
    """Extract markdown headings with character offsets."""
    pos, out = 0, []
    for line in page.split("\n"):
        m = re.match(r"(#{1,6})\s+(.*\S)", line)
        if m:
            out.append(f"{pos}\t{'  ' * (len(m.group(1)) - 1)}{m.group(2)}")
        pos += len(line) + 1
    return "\n".join(out) or "[no headings found: use --grep or --offset]"


def grep_text(page, pattern, around):
    """Grep lines matching pattern with context."""
    lines = page.splitlines()
    try:
        rx = re.compile(pattern, re.I)
    except re.error:
        rx = re.compile(re.escape(pattern), re.I)
    hits = [i for i, line in enumerate(lines) if rx.search(line)]
    if not hits:
        return f"[no match for {pattern!r} in {len(lines)} lines]"
    spans = []
    for i in hits:
        a, b = max(0, i - around), min(len(lines), i + around + 1)
        if spans and a <= spans[-1][1]:
            spans[-1][1] = max(spans[-1][1], b)
        else:
            spans.append([a, b])
    out = [f"[{len(hits)} matching lines in {len(spans)} sections, {len(lines)} lines total]"]
    for a, b in spans:
        out.append(f"[lines {a + 1}-{b}]\n" + "\n".join(lines[a:b]))
    return "\n\n".join(out)


def shape(page, fmt, grep, around, offset, limit):
    """Shape page text: outline, grep, offset, cut."""
    total = len(page)
    view = outline(page) if fmt == "outline" else page
    if grep:
        view = grep_text(view, grep, around)
    body, was_cut = cut(view, limit, offset, paged=True)
    return body, was_cut, total


def norm_url(u):
    """Normalize URL for deduplication."""
    return str(u).split("#")[0].rstrip("/").lower()


def link_url(item):
    """Extract URL from dict or return as string."""
    if isinstance(item, dict):
        import json
        return str(item.get("url") or item.get("href") or json.dumps(item, ensure_ascii=False))
    return str(item)
