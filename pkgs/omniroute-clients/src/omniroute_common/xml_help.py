"""XML help generation utilities."""
import inspect
from xml.sax.saxutils import quoteattr

from .constants import SYNTAX, RUN_OPTIONS, EXTRA_ENV, COMMON_PARAMS


def text(s):
    """Escape text for XML CDATA."""
    s = str(s)
    if "<" in s or "&" in s:
        return "<![CDATA[" + s.replace("]]>", "]]]]><![CDATA[>") + "]]>"
    return s


def attrs_str(attrs):
    """Convert dict to XML attribute string."""
    return "".join(f" {k}={quoteattr(str(v))}" for k, v in attrs.items() if v not in (None, ""))


def section(name, tag, items, numbered=False):
    """Create XML section with items."""
    lines = [f"  <{name}>"]
    for i, item in enumerate(items, 1):
        n = f' n="{i}"' if numbered else ""
        lines.append(f"    <{tag}{n}>{text(item)}</{tag}>")
    lines.append(f"  </{name}>")
    return lines


def syntax_xml(self_name):
    """Generate syntax XML section."""
    return section("syntax", "rule", [s.replace("{self}", self_name) for s in SYNTAX])


def run_options_xml(extra=()):
    """Generate run_options XML section."""
    o = ["  <run_options>"]
    for name, (dest, typ, meta, desc) in RUN_OPTIONS.items():
        if name == "-v":
            continue
        attrs = {"name": name, "type": "flag" if typ is None else typ.__name__, "metavar": meta}
        o.append(f"    <option{attrs_str(attrs)}>{text(desc)}</option>")
    for name, meta, desc in extra:
        o.append(f"    <option{attrs_str({'name': name, 'type': 'string', 'metavar': meta})}>{text(desc)}</option>")
    o.append("  </run_options>")
    return o


def env_xml(env):
    """Generate environment XML section."""
    o = ["  <environment>"]
    for var in [*env, *EXTRA_ENV]:
        extra = {k: v for k, v in var.items() if k != "description"}
        o.append(f"    <variable{attrs_str(extra)}>{text(var.get('description', ''))}</variable>")
    o.append("  </environment>")
    return o


def command_xml(name, sub):
    """Generate command XML section."""
    params = inspect.signature(sub.get_default("func")).parameters
    lines = [f"    <command{attrs_str({'name': name, 'summary': sub.description})}>"]
    for act in sub._actions:
        if act.help == __import__("argparse").SUPPRESS:
            continue
        attrs = {}
        if act.option_strings:
            tag = "option"
            attrs["name"] = act.option_strings[0]
            attrs["aliases"] = ", ".join(act.option_strings[1:])
            attrs["type"] = "flag" if act.nargs == 0 else (
                "int" if act.type is int else "float" if act.type is float else "string")
            attrs["choices"] = "|".join(map(str, act.choices)) if act.choices else ""
            p = params.get(act.dest)
            if act.nargs != 0 and p is not None and p.default is not inspect.Parameter.empty:
                attrs["default"] = p.default
            attrs["metavar"] = act.metavar
        else:
            tag = "argument"
            attrs["name"] = act.dest
            attrs["required"] = "true"
        lines.append(f"      <{tag}{attrs_str(attrs)}>{text(act.help)}</{tag}>")
    lines.append("    </command>")
    return lines


def help_xml(tool, self_name, description, help_dict, commands):
    """Generate full help XML."""
    o = [f"<help{attrs_str({'tool': tool, 'command': self_name})}>", f"  <description>{text(description)}</description>"]
    for name, tag, numbered in (("use_when", "case", False), ("avoid_when", "case", False), ("workflow", "step", True)):
        if help_dict.get(name):
            o += section(name, tag, help_dict[name], numbered)
    o += syntax_xml(self_name)
    o.append("  <commands>")
    for name, sub in commands.items():
        o += command_xml(name, sub)
    o.append("  </commands>")
    o += run_options_xml()
    for name, tag in (("examples", "example"), ("notes", "note"), ("answering", "rule")):
        if help_dict.get(name):
            o += section(name, tag, help_dict[name])
    o.append(f"  <output>{text(help_dict['output'])}</output>")
    o.append("  <errors>")
    for code, desc in help_dict["errors"].items():
        o.append(f"    <error code={quoteattr(code)}>{text(desc)}</error>")
    o.append("  </errors>")
    o += env_xml(help_dict["environment"])
    o.append(f"  <python_api>Run `{self_name} --help-python` for search() and fetch() usable directly from Python.</python_api>")
    o.append("</help>")
    return "\n".join(o)


def function_xml(name, fn, py_docs):
    """Generate function XML for Python API help."""
    doc = py_docs[name]
    sig = inspect.signature(fn)
    parts = []
    for i, p in enumerate(sig.parameters.values()):
        ann = "str | list[str | dict]" if i == 0 else p.annotation
        s = f"{p.name}: {ann}"
        if p.default is not p.empty:
            s += f" = {p.default!r}"
        parts.append(s)
    signature = f"{fn.__name__}({', '.join(parts)}, *, concurrency=None, total_timeout=None, total_chars=None, dedupe=False) -> str | dict | list"
    
    o = [f"    <function{attrs_str({'name': name, 'signature': signature})}>"]
    o.append(f"      <summary>{text(doc['summary'])}</summary>")
    o.append("      <params>")
    docs = {**COMMON_PARAMS, **doc["params"]}
    for p in sig.parameters.values():
        required = p.default is p.empty
        attrs = {"name": p.name, "type": p.annotation, "required": "true" if required else "",
                 "default": "" if required else repr(p.default)}
        o.append(f"        <param{attrs_str(attrs)}>{text(docs.get(p.name, ''))}</param>")
    o.append("      </params>")
    o.append(f"      <returns>{text(doc['returns'])}</returns>")
    o.append(f"      <example>{text(doc['example'])}</example>")
    o.append("    </function>")
    return o


def python_help_xml(tool, import_stmt, py_docs, search_fn, fetch_fn):
    """Generate Python API help XML."""
    multi_doc = (
        "Pass one string for a single item (returns one block, raises ToolError on failure). "
        "Pass a list of strings or dicts for several items: a dict holds that item's own options, keyword arguments "
        "are shared defaults, an item's own option wins. Several items return one <web_tools> string with "
        "<search_error> for failed items and raise only when all fail. Extra keyword arguments: concurrency, "
        "total_timeout, total_chars, dedupe."
    )
    
    o = [f"<python_api{attrs_str({'tool': tool})}>"]
    o.append("  <requirements>The requests package, OMNIROUTE_API_KEY in the environment.</requirements>")
    o.append(f"  <import>{text(import_stmt)}</import>")
    o.append(f"  <multi>{text(multi_doc)}</multi>")
    o.append("  <functions>")
    o += function_xml("search", search_fn, py_docs)
    o += function_xml("fetch", fetch_fn, py_docs)
    o.append("  </functions>")
    o.append("  <raises>ToolError(message, code): same values as the CLI exit codes "
             "(2 bad arguments, 3 missing or rejected API key, 4 network or HTTP error, 5 rate limited). "
             "Read it from the .code attribute.</raises>")
    o.append("</python_api>")
    return "\n".join(o)
