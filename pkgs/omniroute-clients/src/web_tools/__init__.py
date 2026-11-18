"""web-tools: unified CLI for web search and page fetching."""
from .cli import search, fetch, ToolError, main

__all__ = ["search", "fetch", "ToolError", "main"]
