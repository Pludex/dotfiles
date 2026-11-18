"""Disk cache implementation."""
import hashlib
import json
import os
import tempfile
import time


def cache_dir():
    """Get cache directory path."""
    base = os.environ.get("WEB_TOOLS_CACHE_DIR")
    if base:
        return base
    root = os.environ.get("XDG_CACHE_HOME") or os.path.expanduser("~/.cache")
    return os.path.join(root, "web-tools")


def cache_key(path, payload):
    """Generate cache key from API path and payload."""
    blob = json.dumps([path, payload], sort_keys=True, ensure_ascii=False, default=str)
    return hashlib.sha256(blob.encode("utf-8")).hexdigest()


def cache_get(key, ttl):
    """Get cached response if not expired."""
    if ttl <= 0:
        return None
    try:
        with open(os.path.join(cache_dir(), key + ".json"), encoding="utf-8") as f:
            obj = json.load(f)
        age = time.time() - obj["t"]
        if age < 0 or age > ttl:
            return None
        return obj["data"], int(age)
    except (OSError, ValueError, KeyError, TypeError):
        return None


def cache_prune(d, max_age=86400):
    """Prune old cache files."""
    stamp = os.path.join(d, ".pruned")
    try:
        if time.time() - os.path.getmtime(stamp) < 3600:
            return
    except OSError:
        pass
    now = time.time()
    for name in os.listdir(d):
        if name.endswith((".json", ".tmp")):
            p = os.path.join(d, name)
            try:
                if now - os.path.getmtime(p) > max_age:
                    os.remove(p)
            except OSError:
                pass
    try:
        with open(stamp, "w"):
            pass
    except OSError:
        pass


def cache_put(key, data):
    """Save response to cache."""
    d = cache_dir()
    try:
        os.makedirs(d, mode=0o700, exist_ok=True)
        fd, tmp = tempfile.mkstemp(dir=d, suffix=".tmp")
        with os.fdopen(fd, "w", encoding="utf-8") as f:
            json.dump({"t": time.time(), "data": data}, f, ensure_ascii=False)
        os.replace(tmp, os.path.join(d, key + ".json"))
        cache_prune(d)
    except OSError as e:
        from .constants import STATE
        if STATE["verbose"]:
            print(f"[cache] write failed: {e}", file=__import__("sys").stderr)


def resolve_ttl(kind, ttl):
    """Resolve TTL from argument, env, or default."""
    from .constants import TTL
    if ttl is not None:
        return ttl
    env = os.environ.get("WEB_TOOLS_CACHE_TTL")
    if env not in (None, ""):
        try:
            return int(env)
        except ValueError:
            pass
    return TTL[kind]
