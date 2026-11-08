"""web-tools: search (Tavily) and fetch (Firecrawl)."""
from firecrawl_client import fetch
from tavily_client import ToolError, search

__all__ = ["ToolError", "fetch", "search"]
