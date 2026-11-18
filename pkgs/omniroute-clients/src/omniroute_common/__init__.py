"""Shared utilities for OmniRoute client tools."""
from .api import api, run_items
from .cache import cache_dir, cache_get, cache_put, resolve_ttl
from .constants import NOTICE, DEFAULT_BASE_URL, MAX_ITEMS, DEFAULT_LIMIT, TTL, STATE
from .errors import ToolError, DryRun, fail, die
from .http import call, meta_attrs
from .parser import Parser, add_common, add_paging, choice
from .rendering import render_block, render_outcome, esc_text, esc_attr
from .runner import execute, emit, save_out
from .text import cut, grep_text, outline, shape, pick, short_date, csv, normalize_http_url
from .xml_help import help_xml, python_help_xml, text, attrs_str, section, command_xml, syntax_xml, run_options_xml, env_xml, function_xml

# Also expose constants module for direct access
from . import constants

__all__ = [
    "api",
    "run_items",
    "cache_dir",
    "cache_get",
    "cache_put",
    "resolve_ttl",
    "NOTICE",
    "DEFAULT_BASE_URL",
    "MAX_ITEMS",
    "DEFAULT_LIMIT",
    "TTL",
    "STATE",
    "constants",
    "ToolError",
    "DryRun",
    "fail",
    "die",
    "call",
    "meta_attrs",
    "Parser",
    "add_common",
    "add_paging",
    "choice",
    "render_block",
    "render_outcome",
    "esc_text",
    "esc_attr",
    "execute",
    "emit",
    "save_out",
    "cut",
    "grep_text",
    "outline",
    "shape",
    "pick",
    "short_date",
    "csv",
    "normalize_http_url",
    "help_xml",
    "python_help_xml",
    "text",
    "attrs_str",
    "section",
    "command_xml",
    "syntax_xml",
    "run_options_xml",
    "env_xml",
    "function_xml",
]
