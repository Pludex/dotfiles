# omniroute-clients

Python clients for OmniRoute gateway: `context7`, `tavily`, `firecrawl`, and `web-tools`.

## Architecture

```
src/
├── omniroute_common/          # Shared library (replaces kit.py pattern)
│   ├── __init__.py           # Public API exports
│   ├── api.py                # @api decorator for single/multi-item dispatch
│   ├── cache.py              # Disk cache (TTL-based)
│   ├── constants.py          # Shared constants, defaults, env vars
│   ├── errors.py             # ToolError, DryRun exceptions
│   ├── http.py               # OmniRoute HTTP client with retries
│   ├── parser.py             # Custom ArgumentParser, common args
│   ├── rendering.py          # XML output rendering
│   ├── runner.py             # CLI execution, multi-item parallelism
│   ├── text.py               # Text processing (cut, grep, outline)
│   └── xml_help.py           # --help XML generation
│
├── context7_client/           # Library and Nix docs
│   ├── __init__.py
│   └── client.py             # search() and fetch() for Context7
│
├── tavily_client/             # Web search
│   ├── __init__.py
│   └── client.py             # search() and fetch() for Tavily
│
├── firecrawl_client/          # Page scraping
│   ├── __init__.py
│   └── client.py             # search() and fetch() for Firecrawl
│
└── web_tools/                 # Unified CLI
    ├── __init__.py
    └── cli.py                # search → Tavily, fetch → Firecrawl
```

## Shared Module Design

`omniroute_common` replaces the old `kit.py` + `kit_sync.py` pattern:

- **Before**: Each client had identical 900-line `kit.py` copied via regex sync
- **After**: Shared library imported as `from omniroute_common import api, call, ...`

**Benefits**:
- Single source of truth for HTTP, caching, parsing, rendering
- Type-checkable imports instead of regex marker injection
- Easier to test, debug, and extend
- No sync script needed

## Client Structure

Each client (`context7_client`, `tavily_client`, `firecrawl_client`) follows:

1. **Metadata** (`TOOL`, `SELF`, `DESCRIPTION`, `HELP`, `PY_DOCS`)
2. **API functions** decorated with `@api("query")` or `@api("url")`
3. **Parser builder** (`build_parser()` returns ArgumentParser and subcommands)
4. **Main entry point** (`main()` calls `execute()` from common)

The `@api` decorator handles:
- Single string → one result (raises ToolError on failure)
- List of strings/dicts → `<web_tools>` wrapper with parallel execution
- Shared defaults + per-item overrides
- Deduplication, budget splitting, dry-run

## Usage

### CLI

```bash
# Search library docs
context7 search "home-manager services.podman" --limit 3
context7 fetch /nix-community/home-manager --topic programs.git

# Web search
tavily search "nixos 25.11" --topic news --time-range week
web-tools search "nixos containers" --fetch-top 2

# Scrape pages
firecrawl fetch https://example.com --format outline
web-tools fetch https://a.com https://b.com --total-chars 8000
```

### Python

```python
from context7_client import search, fetch, ToolError
from tavily_client import search as tavily_search
from firecrawl_client import fetch as firecrawl_fetch

# Single item
result = search("home-manager services.podman", limit=5)

# Multiple items with per-item options
results = fetch([
    {"url": "/nix-community/home-manager", "topic": "programs.git"},
    "/Mic92/sops-nix"
], max_chars=6000)

# Returns XML string by default; pass raw=True for dict
data = search("query", raw=True)
```

## Environment

- `OMNIROUTE_API_KEY` (required)
- `OMNIROUTE_BASE_URL` (default: `http://localhost:20128`)
- `WEB_TOOLS_TIMEOUT` (default: 40s per request)
- `WEB_TOOLS_RETRIES` (default: 1)
- `WEB_TOOLS_CONCURRENCY` (default: 4 parallel requests)
- `WEB_TOOLS_CACHE_DIR` (default: `$XDG_CACHE_HOME/web-tools`)
- `WEB_TOOLS_CACHE_TTL` (override TTL for all kinds; 0 disables)
- `WEB_TOOLS_VERBOSE` (set to `1` for debug logs)

## Cache

Disk cache with per-kind TTL:
- News: 2 minutes
- Search: 10 minutes
- Fetch: 15 minutes
- Library docs: 1 hour

Use `--no-cache` for fresh data, or set `WEB_TOOLS_CACHE_TTL=0`.

## Development

### Adding a new client

1. Create `src/new_client/client.py`:
   ```python
   from omniroute_common import api, call, Parser, add_common, meta_attrs
   
   TOOL = "new-tool"
   SELF = "new-tool"
   DESCRIPTION = "..."
   HELP = {...}
   PY_DOCS = {...}
   
   @api("query")
   def search(query: str, limit: int = 5, **opts) -> dict:
       payload = {"query": query, "provider": TOOL, "max_results": limit}
       data, meta = call("/api/v1/search", payload, "hint", expect=TOOL)
       # ... process results
       return {"head": {...}, "results": [...], "truncated": False, "meta": meta_attrs(meta)}
   
   def build_parser():
       # ... build argparse
       return parser, subcommands
   
   def main():
       import sys
       from omniroute_common import emit, execute
       _, commands = build_parser()
       argv = sys.argv[1:]
       # ... handle --help, --help-python
       return emit(execute(argv, commands, tool_name=SELF))
   ```

2. Add to `pyproject.toml`:
   ```toml
   [project.scripts]
   new-tool = "new_client.cli:main"
   ```

3. Update `default.nix` `pythonImportsCheck`.

### Testing

```bash
# Dry run (shows what would be sent)
context7 search "query" --dry-run

# Verbose mode (logs timing, cache hits)
WEB_TOOLS_VERBOSE=1 tavily search "query"

# Debug errors
DEBUG=1 firecrawl fetch https://broken.url
```

## Migration Notes

**Old pattern** (kit.py sync):
- `kit_sync.py kit.py src/*/client.py` after every change
- Breaks if markers missing or file edited between markers
- No IDE autocomplete inside kit block

**New pattern** (omniroute_common):
- `from omniroute_common import api, call, emit, execute`
- Type hints work, imports are explicit
- Refactors propagate automatically

Files removed:
- `kit.py` (919 lines) → split into 10 focused modules
- `kit_sync.py` (16 lines) → no sync needed

## Packaging

- **Nix**: `nix build .#omniroute-clients`
- **pip**: `pip install -e .` (editable) or `pip install .`
- Scripts installed: `context7`, `tavily`, `firecrawl`, `web-tools`

## Conventions

1. **Error codes**: 2 (bad args), 3 (auth), 4 (network/HTTP), 5 (rate limit)
2. **Output format**: XML with `<search_results>`, `<result>`, `<search_error>`
3. **Multi-item**: max 8 per command, run in parallel, ordered results
4. **Options**: before first item = shared default; after item = applies to that item only
5. **Caching**: automatic, key = (API path, payload), age checked before use
6. **Retries**: exponential backoff on 429/5xx, respect `Retry-After`

## Related

- OmniRoute gateway: handles provider routing, API key management
- Skills using these tools: `data/search/context7-search-fetch`, `data/search/firecrawl-search-fetch`, etc.
