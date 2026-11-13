"""Citation syntax, shared by check and render.

A Citation is an inline-code span holding a Target-relative path with an optional line or range:
    `portal/verify.asp:6`    `portal/HelpWeb/search.asp`    `src/App.java:40-52`    `appdoc-context.md`
Inline code that is not a path (identifiers, SQL, `Session("Authenticated")`) is not a Citation.
A path may hold spaces (`Old Site/a.asp:3`) when it has a folder and ends in a file name.
"""

from __future__ import annotations

import re
from dataclasses import dataclass

OWNER_CONTEXT = "appdoc-context.md"

# File-ish extensions a bare name (no folder) may carry, with or without a line. Dotfile names such as
# `.gitignore` count through their last segment.
SOURCE_EXTENSIONS = frozenset(
    "asp aspx ascx asax asa inc master cshtml razor vb cs csproj sln config java jsp xml xsl xslt json "
    "properties yml yaml toml ini env py js jsx ts tsx mjs cjs html htm css sql md txt gradle sh ps1 bat cmd "
    "edmx resx svc ashx asmx dll gif png sqlite sqlite3 csv tsv pem plist "
    "dockerfile gitignore gitattributes dockerignore editorconfig npmrc nvmrc".split()
)

# Lowercase extensions that are also common code members (`self.db`, `console.log`): a Citation only with a line.
LINE_ONLY_EXTENSIONS = frozenset("db lock log key cfg conf crt cer".split())

# Leading words that make a spaced span a command or HTTP request, not a path.
_NOT_PATH_FIRST_WORDS = frozenset(
    "GET POST PUT PATCH DELETE HEAD OPTIONS cat cd ls git python python3 node npm npx dotnet docker sudo rm cp mv".split()
)

KNOWN_BARE_FILES = frozenset(
    "Procfile Dockerfile Containerfile Makefile Jenkinsfile Vagrantfile Gemfile Rakefile "
    "CODEOWNERS MAINTAINERS OWNERS LICENSE NOTICE AUTHORS".split()
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


def _is_dotfile(name: str) -> bool:
    return bool(re.fullmatch(r"\.[A-Za-z][A-Za-z0-9_-]*(\.[A-Za-z0-9_-]+)*", name))


def _file_like(name: str, has_line: bool) -> bool:
    """Is this last path segment a file name? With a line, dotfiles and data extensions count too."""
    if name in KNOWN_BARE_FILES or name.startswith("Dockerfile.") or name.endswith(".Dockerfile"):
        return True
    if has_line and _is_dotfile(name):
        return True
    parts = name.rsplit(".", 1)
    if len(parts) != 2:
        return False
    return parts[1].lower() in SOURCE_EXTENSIONS or (has_line and parts[1] in LINE_ONLY_EXTENSIONS)


def _looks_like_path(p: str, has_line: bool = False) -> bool:
    if p.startswith(("http://", "https://")) or "(" in p or '"' in p or "=" in p:
        return False
    if p.startswith("/") or (len(p) > 1 and p[1] == ":"):
        return False  # URL routes and absolute filesystem paths are not Target-relative Citations
    if " " in p:
        # A folder or file name may hold spaces (`Old Site/a.asp:3`); a sentence or command may not pass.
        segs = p.split("/")
        return (len(segs) > 1 and p.split(" ", 1)[0] not in _NOT_PATH_FIRST_WORDS
                and all(s and s == s.strip() for s in segs) and _file_like(segs[-1], has_line))
    if "/" in p:
        return True
    return _file_like(p, has_line)


def parse_span(span: str):
    """Return (path, start, end) if span is a Citation, else None."""
    m = _PATH_RE.match(span.strip())
    if not m:
        return None
    path = m.group(1).replace("\\", "/")
    if not _looks_like_path(path, m.group(2) is not None):
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
