"""Error handling for OmniRoute clients."""
import os
import sys


class ToolError(Exception):
    """Raised when a tool operation fails."""

    def __init__(self, message, code):
        super().__init__(message)
        self.code = code


class DryRun(Exception):
    """Raised in dry-run mode to show what would be sent."""

    def __init__(self, text):
        super().__init__(text)
        self.text = text


def fail(msg, code):
    """Raise a ToolError with message and exit code."""
    raise ToolError(msg, code)


def die(msg, code):
    """Print error to stderr and exit with code."""
    tag = "error:"
    if sys.stderr.isatty() and "NO_COLOR" not in os.environ:
        tag = "\x1b[31merror:\x1b[0m"
    print(f"{tag} {msg}", file=sys.stderr)
    sys.exit(code)
