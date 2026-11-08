"""Firecrawl web search and page reader via OmniRoute (CLI + library)."""
from .client import ToolError, fetch, search

__all__ = ["ToolError", "fetch", "search"]
