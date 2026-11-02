"""Citation syntax, shared by check and render.

A Citation is an inline-code span holding a Target-relative path with an optional line or range:
    `portal/verify.asp:6`    `portal/HelpWeb/search.asp`    `src/App.java:40-52`    `appdoc-context.md`
Inline code that is not a path (identifiers, SQL, `Session("Authenticated")`) is not a Citation.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

OWNER_CONTEXT = "appdoc-context.md"

SOURCE_EXTENSIONS = frozenset(
    "asp aspx ascx asax asa inc master cshtml razor vb cs csproj sln config java jsp xml xsl xslt json "
    "properties yml yaml toml ini env py js jsx ts tsx mjs cjs html htm css sql md txt gradle sh ps1 bat cmd "
    "edmx resx svc ashx asmx dll gif png".split()
)

_SPAN_RE = re.compile(r"`([^`\n]+)`")
_PATH_RE = re.compile(r"^([A-Za-z0-9_.\-@ /\\{}\[\]()$+~]+?)(?::(\d+)(?:-(\d+))?)?$")


@dataclass(frozen=True)
class Citation:
    doc_line: int          # 1-based line in the Narrative
    path: str              # Target-relative, forward slashes
    start: int | None
    end: int | None
    raw: str


def _looks_like_path(p: str) -> bool:
    if p.startswith(("http://", "https://")) or "(" in p or '"' in p or "=" in p:
        return False
    if " " in p.strip():
        return False
    if p.startswith("/") or (len(p) > 1 and p[1] == ":"):
        return False  # URL routes and absolute filesystem paths are not Target-relative Citations
    if "/" in p or "\\" in p:
        return True
    base = p.rsplit(".", 1)
    return len(base) == 2 and base[1].lower() in SOURCE_EXTENSIONS


def parse_span(span: str):
    """Return (path, start, end) if span is a Citation, else None."""
    m = _PATH_RE.match(span.strip())
    if not m:
        return None
    path = m.group(1).replace("\\", "/")
    if not _looks_like_path(path):
        return None
    start = int(m.group(2)) if m.group(2) else None
    end = int(m.group(3)) if m.group(3) else start
    return path, start, end


def find_citations(text: str) -> list[Citation]:
    """Every Citation in a Markdown document, ignoring fenced code blocks."""
    out: list[Citation] = []
    in_fence = False
    for lineno, line in enumerate(text.splitlines(), 1):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            continue
        for m in _SPAN_RE.finditer(line):
            parsed = parse_span(m.group(1))
            if parsed:
                out.append(Citation(lineno, parsed[0], parsed[1], parsed[2], m.group(1)))
    return out
