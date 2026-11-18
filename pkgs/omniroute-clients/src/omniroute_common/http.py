"""HTTP client for OmniRoute API."""
import json
import os
import time

import requests

from .cache import cache_get, cache_key, cache_put, resolve_ttl
from .constants import DEFAULT_BASE_URL, STATE
from .errors import DryRun, ToolError


def env_num(name, default, cast):
    """Get numeric value from environment or default."""
    try:
        return cast(os.environ[name])
    except (KeyError, ValueError):
        return default


def log(msg):
    """Log message if verbose mode enabled."""
    if STATE["verbose"]:
        print(f"[web-tools] {msg}", file=__import__("sys").stderr)


def call(path, payload, hint, expect=None, kind="search", ttl=None, cache=True, timeout=None, retries=None):
    """Make HTTP POST request to OmniRoute API."""
    base = os.environ.get("OMNIROUTE_BASE_URL", DEFAULT_BASE_URL).rstrip("/")
    if STATE["dry"]:
        raise DryRun(f"POST {base}{path}\n" + json.dumps(payload, indent=2, ensure_ascii=False))
    
    key = os.environ.get("OMNIROUTE_API_KEY")
    if not key:
        raise ToolError("OMNIROUTE_API_KEY is not set. Export it or add it to the container environment, then retry.", 3)

    ttl = resolve_ttl(kind, ttl)
    ck = cache_key(path, payload)
    if cache and ttl > 0:
        hit = cache_get(ck, ttl)
        if hit:
            log(f"cache hit {path} age={hit[1]}s")
            return hit[0], {"cached": True, "age_s": hit[1], "elapsed_ms": 0}

    timeout = timeout or env_num("WEB_TOOLS_TIMEOUT", 40.0, float)
    retries = env_num("WEB_TOOLS_RETRIES", 1, int) if retries is None else max(0, retries)
    t0 = time.monotonic()
    data, last = None, None
    
    for attempt in range(retries + 1):
        t = timeout
        if STATE["deadline"] is not None:
            remaining = STATE["deadline"] - time.monotonic()
            if remaining <= 0:
                raise ToolError("total timeout reached. Raise --total-timeout or request fewer items.", 4)
            t = min(timeout, remaining)
        delay = 0.5
        
        try:
            r = requests.post(base + path, json=payload, headers={"Authorization": f"Bearer {key}"}, timeout=t)
        except requests.ConnectionError:
            last = ToolError(f"cannot reach OmniRoute at {base}. Check that the service is running.", 4)
            delay = 1 + attempt
        except requests.Timeout:
            last = ToolError(f"OmniRoute did not answer within {t:.0f}s. Raise --timeout or request less.", 4)
        else:
            if r.status_code in (401, 403):
                raise ToolError(
                    f"OmniRoute rejected the request (HTTP {r.status_code}). "
                    "Check OMNIROUTE_API_KEY and that the provider is enabled in the dashboard.",
                    3,
                )
            if r.status_code == 429 or r.status_code >= 500:
                try:
                    delay = min(float(r.headers.get("Retry-After", 2 ** attempt)), 15)
                except ValueError:
                    delay = 2 ** attempt
                if r.status_code == 429:
                    last = ToolError("rate limited (429). Wait ~30s and retry with fewer items or a smaller --limit.", 5)
                else:
                    detail = " ".join(r.text.split())[:200]
                    last = ToolError(f"OmniRoute returned HTTP {r.status_code}: {detail}. {hint}", 4)
            elif not r.ok:
                detail = " ".join(r.text.split())[:200]
                raise ToolError(f"OmniRoute returned HTTP {r.status_code}: {detail}. {hint}", 4)
            else:
                try:
                    data = r.json()
                except ValueError:
                    raise ToolError("OmniRoute returned a non-JSON response. Retry; if it persists, check the OmniRoute logs.", 4)
                break
        
        if attempt < retries:
            log(f"retry {attempt + 1}/{retries} in {delay:.1f}s: {last}")
            time.sleep(delay)
    
    if data is None:
        raise last
    if not isinstance(data, dict):
        raise ToolError("unexpected response shape from OmniRoute. Retry; if it persists, check the OmniRoute logs.", 4)
    
    provider = str(data.get("provider") or "")
    if expect and provider and expect not in provider.lower():
        raise ToolError(
            f"OmniRoute answered with provider '{provider}' instead of '{expect}'. "
            "Check provider credentials and rate limits in the OmniRoute dashboard.",
            4,
        )
    
    ms = int((time.monotonic() - t0) * 1000)
    log(f"POST {path} {ms}ms")
    if cache and ttl > 0 and (data.get("results") or data.get("content") or data.get("links")):
        cache_put(ck, data)
    return data, {"cached": False, "age_s": 0, "elapsed_ms": ms}


def meta_attrs(meta, via=""):
    """Build metadata attributes dict."""
    hit = meta["cached"]
    return {
        "elapsed_ms": "" if hit else meta["elapsed_ms"],
        "cached": "true" if hit else "",
        "age_s": meta["age_s"] if hit else "",
        "via": via,
    }
