"""Read the structure of a Narrative: headings, tables, IDs and anchors. Shared by fingerprint, check, fill and render (the lowest layer, with textutil)."""

from __future__ import annotations

import re
from dataclasses import dataclass

COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
BLOCK_RE = re.compile(r"(<!--\s*appdoc:generated\s+([\w-]+)\s*-->)(.*?)(<!--\s*/appdoc:generated\s+\2\s*-->)", re.S)
_H2_RE = re.compile(r"^##\s+(\d+)\.\s*(.*?)\s*$")
_H3_RE = re.compile(r"^###\s+(\d+\.\d+)(?![\d])\s*(.*?)\s*$")
_HEADING_RE = re.compile(r"^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$")
SEP_RE = re.compile(r"^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$")
_CODE_SPAN_RE = re.compile(r"`[^`\n]*`")


def strip_comments(text: str) -> str:
    """Remove HTML comments but keep line numbering intact."""
    return COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)


def mask_blocks(text: str, names, pad: bool = True) -> str:
    """Replace the content of the named generated blocks with one placeholder line. With `pad` (the default) the
    line count is kept; without it a block is always the same three lines however long its content, so a
    fingerprint does not move when `fill` rewrites a block."""
    def repl(m):
        if m.group(2) not in names:
            return m.group(0)
        k = m.group(3).count("\n") if pad else 2
        return m.group(1) + ("\n" if k else "") + f"generated block {m.group(2)}" + "\n" * max(k - 1, 0) + m.group(4)
    return BLOCK_RE.sub(repl, text)


def split_row(line: str) -> list[str]:
    """Cells of a Markdown table row. `\\|` and pipes inside backticks do not split."""
    line = line.strip()
    cells, cur, in_code, i = [], [], False, 0
    while i < len(line):
        c = line[i]
        if c == "\\" and i + 1 < len(line) and line[i + 1] == "|":
            cur.append("|")
            i += 2
            continue
        if c == "`":
            in_code = not in_code
        if c == "|" and not in_code:
            cells.append("".join(cur).strip())
            cur = []
        else:
            cur.append(c)
        i += 1
    cells.append("".join(cur).strip())
    if line.startswith("|"):
        cells = cells[1:]
    if line.endswith("|") and not line.endswith("\\|") and cells:
        cells = cells[:-1]
    return cells


def slug(text: str, seen: dict) -> str:
    plain = re.sub(r"[`*_]|\[([^\]]*)\]\([^)]*\)", lambda m: m.group(1) or "", text)
    s = re.sub(r"[^\w\- ]", "", plain.lower()).strip().replace(" ", "-")
    s = re.sub(r"-+", "-", s) or "section"
    n = seen.get(s, 0)
    seen[s] = n + 1
    return s if n == 0 else f"{s}-{n + 1}"


def cell_text(cell: str) -> str:
    """A cell's plain value for comparison: no emphasis, code ticks or surrounding space."""
    return re.sub(r"[*_`]", "", cell).strip()


def without_code(line: str) -> str:
    return _CODE_SPAN_RE.sub("", line)


def fenced(lines: list[str]) -> list[bool]:
    """Per line: True inside (or on) a code fence."""
    out, in_fence = [], False
    for line in lines:
        if line.lstrip().startswith(("```", "~~~")):
            out.append(True)
            in_fence = not in_fence
            continue
        out.append(in_fence)
    return out


@dataclass
class Heading:
    key: str        # "4" for `## 4. ...`, "4.1" for `### 4.1 ...`
    title: str
    idx: int        # 0-based line index
    end: int        # exclusive: next heading at the same or a higher level
    own_end: int    # exclusive: next heading of any level


def headings(lines: list[str]) -> dict[str, Heading]:
    """Numbered `##` sections and `###` subsections, by key. The first occurrence of a key wins."""
    fence = fenced(lines)
    marks = []  # (idx, level, key, title)
    for i, line in enumerate(lines):
        if fence[i]:
            continue
        m = _H2_RE.match(line)
        if m:
            marks.append((i, 2, m.group(1), m.group(2)))
            continue
        m = _H3_RE.match(line)
        if m:
            marks.append((i, 3, m.group(1), m.group(2)))
            continue
        if line.startswith("#"):
            hm = _HEADING_RE.match(line)
            if hm:
                marks.append((i, len(hm.group(1)), None, hm.group(2)))
    out: dict[str, Heading] = {}
    for n, (i, lvl, key, title) in enumerate(marks):
        if key is None or key in out:
            continue
        own_end = marks[n + 1][0] if n + 1 < len(marks) else len(lines)
        end = next((j for j, l2, _, _ in marks[n + 1:] if l2 <= lvl), len(lines))
        if lvl == 3 and not key.startswith(_parent_of(marks, n)):
            continue  # a ### outside its parent section does not count
        out[key] = Heading(key, title, i, end, own_end)
    return out


def _parent_of(marks, n) -> str:
    for i, lvl, key, _ in reversed(marks[:n]):
        if lvl == 2:
            return (key or "") + "."
    return "\0"


def all_slugs(lines: list[str]) -> set[str]:
    """Anchors render will give every heading, in document order."""
    fence, seen, out = fenced(lines), {}, set()
    for i, line in enumerate(lines):
        if fence[i]:
            continue
        m = _HEADING_RE.match(line)
        if m:
            out.add(slug(m.group(2), seen))
    return out


@dataclass
class Table:
    line: int                         # 1-based line of the header row
    header: list[str]
    rows: list[tuple[int, list[str]]]  # (1-based line, cells)


def tables(lines: list[str], first: int = 0, last: int | None = None) -> list[Table]:
    """Tables in lines[first:last], outside code fences."""
    last = len(lines) if last is None else last
    fence = fenced(lines)
    out, i = [], first
    while i < last:
        s = lines[i].strip()
        if not fence[i] and s.startswith("|") and i + 1 < last and SEP_RE.match(lines[i + 1].strip()) \
                and "|" in lines[i + 1]:
            t = Table(i + 1, split_row(s), [])
            i += 2
            while i < last and not fence[i] and lines[i].strip().startswith("|"):
                t.rows.append((i + 1, split_row(lines[i])))
                i += 1
            out.append(t)
            continue
        i += 1
    return out


def first_table(lines: list[str], h: Heading) -> Table | None:
    found = tables(lines, h.idx + 1, h.own_end)
    return found[0] if found else None
