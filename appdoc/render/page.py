"""Wrap rendered Markdown in the HTML shell and write application-documentation.html (one offline file)."""

from __future__ import annotations

import html
import json
import os
import re
import sys

from .. import docmodel as dm
from .. import fill as fill_mod
from .. import template_spec as spec
from .markdown import render_markdown
from ..textnorm import normalize_newlines
from ..integration import render_integration_view

ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")
MD_NAME = "application-documentation.md"
HTML_NAME = "application-documentation.html"
_HEADING_RE = re.compile(r'<h([123]) id="([^"]+)">(.*?)</h\1>', re.S)


def _read(path: str) -> str:
    with open(path, encoding="utf-8-sig", newline="") as f:
        return normalize_newlines(f.read())


def pick_css(out_dir: str, css: str | None) -> str:
    if css:
        return css
    theme = os.path.join(out_dir, "theme.css")
    return theme if os.path.isfile(theme) else os.path.join(ASSETS, "theme-cmu.css")


def _toc(body: str) -> str:
    items = []
    for lvl, hid, inner in _HEADING_RE.findall(body):
        if lvl == "1":
            continue
        text = html.unescape(re.sub(r"<[^>]+>", "", inner))
        items.append(f'<li class="l{lvl}"><a href="#{hid}">{html.escape(text)}</a></li>')
    return "<ul>" + "".join(items) + "</ul>" if items else ""


def _title(body: str, target_name: str) -> str:
    m = re.search(r'<h1 id="[^"]+">(.*?)</h1>', body, re.S)
    return html.unescape(re.sub(r"<[^>]+>", "", m.group(1))) if m else f"{target_name} documentation"


def _integration_html(out_dir: str) -> str:
    """Deterministic ``System Connections`` section as HTML, or ``""`` if there is nothing to show.

    A pure function of ``facts.json`` (never fails): a missing/corrupt ``facts.json`` yields ``""``.
    """
    try:
        with open(os.path.join(out_dir, "facts.json"), encoding="utf-8") as f:
            doc = json.load(f)
        view_md = render_integration_view(doc)
    except (OSError, ValueError, TypeError, AttributeError):
        return ""
    return render_markdown(view_md) if view_md.strip() else ""


def _footer(target_name: str, out_dir: str) -> str:
    parts = [f"Target: {target_name}"]
    try:
        with open(os.path.join(out_dir, "facts.json"), encoding="utf-8") as f:
            commit = (json.load(f).get("target") or {}).get("commit")
        if commit:
            parts.append(f"Commit: {commit}")
    except (OSError, ValueError, AttributeError):
        pass
    report = os.path.join(out_dir, "check-report.md")
    if os.path.isfile(report):
        first = (_read(report).split("\n", 1)[0]).strip()
        status = re.sub(r"^#\s*", "", first)
        if status:
            parts.append(status)
    return "".join(f"<span>{html.escape(p)}</span>" for p in parts)


def _stale_block(target: str, md_path: str, out_dir: str) -> str | None:
    """The name of a generated block that differs from what fill would write, or None."""
    with open(os.path.join(out_dir, "facts.json"), encoding="utf-8") as fh:
        facts = json.load(fh)
    raw = _read(md_path)
    lines = dm.strip_comments(dm.mask_blocks(normalize_newlines(raw), spec.OPAQUE_BLOCKS)).splitlines()
    heads = dm.headings(lines)
    ctx = {"out_dir": out_dir, "text": raw, "target": os.path.abspath(target)}
    found = {name: body for name, body, _ in fill_mod.blocks(normalize_newlines(raw))}
    for key, name in spec.GENERATED.items():
        if name not in found:
            continue
        expected = (fill_mod.render_block(name, facts, ctx) or "").strip()
        if found[name] != expected:
            return name
    return None


MERMAID_MODES = ("inline", "sibling")
MERMAID_FILE = "mermaid.min.js"
_MERMAID_INIT = "mermaid.initialize({startOnLoad:true,securityLevel:'strict'});"


def _mermaid_script(out_dir: str, mode: str) -> str:
    """The script element(s) of a page that has a diagram. `inline` (the default) embeds the library, so the page is one
    self-contained file. `sibling` links `mermaid.min.js` beside the HTML and copies it there once (T28.B3): the
    page stays small and the browser caches the library; the folder must be kept together."""
    src = os.path.join(ASSETS, MERMAID_FILE)
    if mode == "sibling":
        dest = os.path.join(out_dir, MERMAID_FILE)
        with open(src, "rb") as f:
            lib = f.read()
        try:
            with open(dest, "rb") as f:
                same = f.read() == lib
        except OSError:
            same = False
        if not same:   # written once; a file with the packaged bytes is left alone
            with open(dest, "wb") as f:
                f.write(lib)
        return f'<script src="{MERMAID_FILE}"></script>\n<script>\n{_MERMAID_INIT}\n</script>'
    return "<script>\n" + _read(src).replace("</script", "<\\/script") + "\n" + _MERMAID_INIT + "\n</script>"


def run(target: str, out_dir: str, css: str | None, mermaid: str = "inline") -> int:
    md_path = os.path.join(out_dir, MD_NAME)
    if not os.path.isfile(md_path):
        print(f"appdoc: {md_path} not found; write the Narrative first", file=sys.stderr)
        return 1
    if os.path.isfile(os.path.join(out_dir, "facts.json")):
        stale = _stale_block(target, md_path, out_dir)
        if stale:
            print(f"appdoc render: generated block '{stale}' is stale; run `appdoc fill` first", file=sys.stderr)
            return 2
    css_path = pick_css(out_dir, css)
    try:
        css_text = _read(css_path)
        shell = _read(os.path.join(ASSETS, "shell.html"))
        body = render_markdown(_read(md_path))
        view_html = _integration_html(out_dir)
        if view_html:
            m = re.search(r"</h1>", body)
            body = (body[:m.end()] + "\n" + view_html + body[m.end():]) if m else view_html + body
        script = ""
        if 'class="mermaid"' in body:
            script = _mermaid_script(out_dir, mermaid)
    except OSError as exc:
        print(f"appdoc: cannot read render input: {exc}", file=sys.stderr)
        return 1
    name = os.path.basename(os.path.abspath(target))
    values = {"title": html.escape(_title(body, name)), "css": css_text.replace("</style", "<\\/style"),
              "toc": _toc(body), "body": body, "footer": _footer(name, out_dir), "mermaid_script": script}
    page = re.sub(r"\{\{(\w+)\}\}", lambda m: values.get(m.group(1), m.group(0)), shell)
    with open(os.path.join(out_dir, HTML_NAME), "w", encoding="utf-8", newline="\n") as f:
        f.write(page)
    return 0
