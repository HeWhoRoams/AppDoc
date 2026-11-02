"""Markdown subset -> HTML. Everything is escaped; unsupported syntax stays escaped text; never raises on input."""

from __future__ import annotations

import html
import re

from ..citations import parse_span

_FENCE_SPLIT = re.compile(r"(^[ \t]*(?:```|~~~).*?^[ \t]*(?:```|~~~)[ \t]*$)", re.M | re.S)
_COMMENT = re.compile(r"<!--.*?-->", re.S)
_FENCE_OPEN = re.compile(r"^\s*(```+|~~~+)\s*([^\s`]*)")
_HEADING = re.compile(r"^\s{0,3}(#{1,6})\s+(.*?)\s*#*\s*$")
_HR = re.compile(r"^\s{0,3}([-*_])(\s*\1){2,}\s*$")
_LIST = re.compile(r"^(\s*)([-*+]|\d+[.)])\s+(.*)$")
_TABLE_SEP = re.compile(r"^\s*\|?\s*:?-{1,}:?\s*(\|\s*:?-{1,}:?\s*)*\|?\s*$")
_CODE_SPAN = re.compile(r"`([^`\n]+)`")
_BOLD = re.compile(r"\*\*(.+?)\*\*")
_EM = re.compile(r"(?<![\*\w])\*(?!\s)([^*]+?)(?<!\s)\*(?![\*\w])")
_LINK = re.compile(r"\[([^\]]+)\]\(([^)\s]+)\)")
_SAFE_URL = re.compile(r"^(https?:|mailto:|#|[^:]*$)", re.I)
INFERRED = "**Inferred:**"


def _esc(s: str) -> str:
    return html.escape(s, quote=True)


def _strip_comments(text: str) -> str:
    parts = _FENCE_SPLIT.split(text)
    for i in range(0, len(parts), 2):
        parts[i] = _COMMENT.sub("", parts[i])
    return "".join(parts)


def _link(m: re.Match) -> str:
    label, url = m.group(1), m.group(2)
    if not _SAFE_URL.match(html.unescape(url).strip()):
        return m.group(0)
    return f'<a href="{url}">{label}</a>'


def _inline_plain(s: str) -> str:
    s = _esc(s)
    s = _BOLD.sub(r"<strong>\1</strong>", s)
    s = _EM.sub(r"<em>\1</em>", s)
    return _LINK.sub(_link, s)


def inline(text: str) -> str:
    out, pos = [], 0
    for m in _CODE_SPAN.finditer(text):
        out.append(_inline_plain(text[pos:m.start()]))
        cls = ' class="cite"' if parse_span(m.group(1)) else ""
        out.append(f"<code{cls}>{_esc(m.group(1))}</code>")
        pos = m.end()
    out.append(_inline_plain(text[pos:]))
    return "".join(out)


def _cls(text: str) -> str:
    return ' class="inferred"' if text.lstrip().startswith(INFERRED) else ""


def _slug(text: str, seen: dict) -> str:
    plain = re.sub(r"[`*_]|\[([^\]]*)\]\([^)]*\)", lambda m: m.group(1) or "", text)
    slug = re.sub(r"[^\w\- ]", "", plain.lower()).strip().replace(" ", "-")
    slug = re.sub(r"-+", "-", slug) or "section"
    n = seen.get(slug, 0)
    seen[slug] = n + 1
    return slug if n == 0 else f"{slug}-{n + 1}"


def _split_row(line: str) -> list[str]:
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


def _align(spec: str) -> str:
    spec = spec.strip()
    left, right = spec.startswith(":"), spec.endswith(":")
    return ' style="text-align:center"' if left and right else ' style="text-align:right"' if right else ""


def _table(lines: list[str]) -> str:
    head, aligns = _split_row(lines[0]), [_align(c) for c in _split_row(lines[1])]
    def cell(tag, i, text):
        a = aligns[i] if i < len(aligns) else ""
        return f"<{tag}{a}{_cls(text) if tag == 'td' else ''}>{inline(text)}</{tag}>"
    rows = ["<thead><tr>" + "".join(cell("th", i, c) for i, c in enumerate(head)) + "</tr></thead>"]
    body = ["<tr>" + "".join(cell("td", i, c) for i, c in enumerate(_split_row(r))) + "</tr>" for r in lines[2:]]
    if body:
        rows.append("<tbody>" + "".join(body) + "</tbody>")
    return "<table>" + "".join(rows) + "</table>"


def _list(lines: list[str]) -> str:
    """lines: consecutive list lines; indent >= 2 (or deeper than the first) = nested level."""
    base = len(_LIST.match(lines[0]).group(1))
    items: list[list] = []  # [text, [(marker, text)]]
    for ln in lines:
        m = _LIST.match(ln)
        if not m:  # continuation line
            target = items[-1][1][-1] if items and items[-1][1] else None
            if target is not None:
                target[1] += " " + ln.strip()
            elif items:
                items[-1][0] += " " + ln.strip()
            continue
        indent, marker, text = len(m.group(1)), m.group(2), m.group(3)
        if indent > base and items:
            items[-1][1].append([marker, text])
        else:
            items.append([text, [], marker])
    def tag(marker): return "ol" if marker[0].isdigit() else "ul"
    def wrap(marker, inner): return f"<{tag(marker)}>{inner}</{tag(marker)}>"
    html_items = []
    for text, subs, *rest in items:
        li = f"<li{_cls(text)}>{inline(text)}"
        if subs:
            li += wrap(subs[0][0], "".join(f"<li{_cls(t)}>{inline(t)}</li>" for _, t in subs))
        html_items.append(li + "</li>")
    first = _LIST.match(lines[0]).group(2)
    return wrap(first, "".join(html_items))


def _starts_block(line: str) -> bool:
    return bool(_FENCE_OPEN.match(line) or _HEADING.match(line) or _HR.match(line)
                or _LIST.match(line) or line.lstrip().startswith(">"))


def _blocks(text: str, seen: dict) -> str:
    lines = text.replace("\r\n", "\n").replace("\r", "\n").split("\n")
    out, i, n = [], 0, len(lines)
    while i < n:
        line = lines[i]
        if not line.strip():
            i += 1
            continue
        m = _FENCE_OPEN.match(line)
        if m:
            fence, lang, buf = m.group(1), m.group(2).lower(), []
            i += 1
            while i < n and not lines[i].strip().startswith(fence[:3]):
                buf.append(lines[i])
                i += 1
            i += 1
            src = _esc("\n".join(buf))
            if lang == "mermaid":
                out.append(f'<pre class="mermaid">{src}</pre>')
            else:
                c = f' class="language-{_esc(lang)}"' if lang else ""
                out.append(f"<pre><code{c}>{src}</code></pre>")
            continue
        m = _HEADING.match(line)
        if m:
            lvl, txt = len(m.group(1)), m.group(2)
            out.append(f'<h{lvl} id="{_slug(txt, seen)}">{inline(txt)}</h{lvl}>')
            i += 1
            continue
        if _HR.match(line):
            out.append("<hr>")
            i += 1
            continue
        if line.lstrip().startswith(">"):
            buf = []
            while i < n and lines[i].lstrip().startswith(">"):
                buf.append(re.sub(r"^\s*>\s?", "", lines[i]))
                i += 1
            out.append(f"<blockquote>{_blocks(chr(10).join(buf), seen)}</blockquote>")
            continue
        if "|" in line and i + 1 < n and "|" in lines[i + 1] and _TABLE_SEP.match(lines[i + 1]):
            buf = [line, lines[i + 1]]
            i += 2
            while i < n and lines[i].strip() and "|" in lines[i]:
                buf.append(lines[i])
                i += 1
            out.append(_table(buf))
            continue
        if _LIST.match(line):
            buf = []
            while i < n and lines[i].strip() and not _FENCE_OPEN.match(lines[i]) and not _HEADING.match(lines[i]):
                buf.append(lines[i])
                i += 1
            out.append(_list(buf))
            continue
        buf = [line]
        i += 1
        while i < n and lines[i].strip() and not _starts_block(lines[i]):
            buf.append(lines[i])
            i += 1
        para = " ".join(s.strip() for s in buf)
        out.append(f"<p{_cls(para)}>{inline(para)}</p>")
    return "\n".join(out)


def render_markdown(text: str) -> str:
    try:
        return _blocks(_strip_comments(text or ""), {})
    except Exception:  # never fail: fall back to escaped text
        return f"<pre>{_esc(text or '')}</pre>"
