"""Wrap rendered Markdown in the HTML shell and write application-documentation.html (one offline file)."""

from __future__ import annotations

import datetime
import html
import json
import os
import re
import sys

from .markdown import render_markdown

ASSETS = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "assets")
MD_NAME = "application-documentation.md"
HTML_NAME = "application-documentation.html"
_HEADING_RE = re.compile(r'<h([123]) id="([^"]+)">(.*?)</h\1>', re.S)


def _read(path: str) -> str:
    with open(path, encoding="utf-8-sig", newline="") as f:
        return f.read().replace("\r\n", "\n")


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


def _footer(target_name: str, out_dir: str) -> str:
    parts = [f"Target: {target_name}"]
    try:
        with open(os.path.join(out_dir, "facts.json"), encoding="utf-8") as f:
            commit = (json.load(f).get("target") or {}).get("commit")
        if commit:
            parts.append(f"Commit: {commit}")
    except (OSError, ValueError, AttributeError):
        pass
    parts.append(f"Generated: {datetime.date.today().isoformat()}")
    report = os.path.join(out_dir, "check-report.md")
    if os.path.isfile(report):
        first = (_read(report).split("\n", 1)[0]).strip()
        status = re.sub(r"^#\s*", "", first)
        if status:
            parts.append(status)
    return "".join(f"<span>{html.escape(p)}</span>" for p in parts)


def run(target: str, out_dir: str, css: str | None) -> int:
    md_path = os.path.join(out_dir, MD_NAME)
    if not os.path.isfile(md_path):
        print(f"appdoc: {md_path} not found; write the Narrative first", file=sys.stderr)
        return 1
    css_path = pick_css(out_dir, css)
    try:
        css_text = _read(css_path)
        shell = _read(os.path.join(ASSETS, "shell.html"))
        body = render_markdown(_read(md_path))
        script = ""
        if 'class="mermaid"' in body:
            lib = _read(os.path.join(ASSETS, "mermaid.min.js")).replace("</script", "<\\/script")
            script = ("<script>\n" + lib + "\nmermaid.initialize("
                      "{startOnLoad:true,securityLevel:'strict'});\n</script>")
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
