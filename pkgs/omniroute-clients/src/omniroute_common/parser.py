"""Argument parser utilities."""
import argparse


class Parser(argparse.ArgumentParser):
    """Custom ArgumentParser that raises ToolError instead of sys.exit."""
    
    def error(self, message):
        from .errors import fail
        fail(message, 2)


def add_common(sub):
    """Add common arguments to subparser."""
    sub.add_argument("--timeout", type=float, metavar="SEC", help="per-request timeout (default 40)")
    sub.add_argument("--retries", type=int, help="retries on 429, 5xx and network errors (default 1)")
    sub.add_argument("--no-cache", dest="cache", action="store_false", help="skip the disk cache for this item")
    sub.add_argument("--cache-ttl", type=int, metavar="SEC",
                     help="reuse a cached response only if younger than this, 0 disables "
                          "(defaults: news 120, search 600, pages 900, library docs 3600)")
    sub.add_argument("--raw", action="store_true", help=argparse.SUPPRESS)


def add_paging(sub):
    """Add paging arguments to subparser."""
    sub.add_argument("--offset", type=int, help="start at this character; use the value from the truncation marker")
    sub.add_argument("--grep", metavar="REGEX", help="keep only matching lines (case-insensitive) with --around context")
    sub.add_argument("--around", type=int, help="context lines around each --grep match (default 2)")


def choice(name, value, allowed):
    """Validate that value is in allowed choices."""
    if value is not None and value not in allowed:
        from .errors import fail
        fail(f"{name} must be one of {', '.join(map(str, allowed))}, got {value!r}.", 2)
