"""README for omniroute-clients package."""

# omniroute-clients

Python clients for OmniRoute gateway: search and fetch library docs, web content, and scraped pages.

## Quick Start

```bash
# Install
pip install -e .

# Search library docs
context7 search "home-manager services.podman" --limit 3

# Web search
tavily search "nixos 25.11" --topic news

# Scrape pages
firecrawl fetch https://example.com

# Unified CLI
web-tools search "query" --fetch-top 2
```

See [AGENTS.md](./AGENTS.md) for architecture and development guide.

## Tools

- **context7**: Library, framework, and Nix option docs
- **tavily**: Web search for news, prices, current events
- **firecrawl**: Page scraping with JavaScript rendering
- **web-tools**: Unified CLI (search → Tavily, fetch → Firecrawl)

## Environment

Set `OMNIROUTE_API_KEY` before use:

```bash
export OMNIROUTE_API_KEY="your-key"
export OMNIROUTE_BASE_URL="http://localhost:20128"  # optional
```

## Development

```bash
# Build with Nix
nix build .#omniroute-clients

# Or with pip
pip install -e .

# Run tests
context7 search "test" --dry-run
WEB_TOOLS_VERBOSE=1 tavily search "test"
```
