"""Stack interface and shared helpers.

Adding a Stack: one module in this package, one entry in ``stacks/__init__.py``,
a sample Target in ``tests/samples/<stack>/`` and a ``tests/test_facts_<stack>.py``.
"""

from __future__ import annotations

import re
from typing import Iterable

from ..facts import Fact


class Stack:
    id: str = ""
    extensions: frozenset = frozenset()   # lowercase, with dot; files this Stack reads
    supported: bool = True

    def detect(self, files: list[str]) -> list[str]:
        """Return the marker files (sorted, Target-relative) that show this Stack is present."""
        return []

    def extract(self, path: str, text: str) -> Iterable[Fact]:
        """Yield Facts for one file. ``text`` is the decoded file content. Never record secret values."""
        return ()


def line_of(text: str, offset: int) -> int:
    return text.count("\n", 0, offset) + 1


def iter_matches(rx: "re.Pattern", text: str):
    """Yield (1-based line, match) for each regex match in text."""
    for m in rx.finditer(text):
        yield line_of(text, m.start()), m


def strip_comments(text: str, style: str) -> str:
    """Blank out comments but keep newlines, so line numbers stay correct.

    style: "c" (// and /* */), "hash" (#), "asp" (' and REM line comments, <!-- -->), "xml" (<!-- -->)
    """
    def blank(m):
        return re.sub(r"[^\n]", " ", m.group(0))

    if style == "c":
        return _strip_c(text)
    elif style == "hash":
        text = re.sub(r"(?m)^\s*#[^\n]*", blank, text)
    elif style == "asp":
        text = re.sub(r"<!--.*?-->", blank, text, flags=re.S)
        text = re.sub(r"(?im)^\s*(?:'|rem\b)[^\n]*", blank, text)
    elif style == "xml":
        text = re.sub(r"<!--.*?-->", blank, text, flags=re.S)
    return text


def _strip_c(text: str) -> str:
    """Blank // and /* */ comments, leaving string and char literals (and newlines) untouched."""
    out = []
    i, n = 0, len(text)
    while i < n:
        c = text[i]
        two = text[i:i + 2]
        if c in "\"'`":
            j = i + 1
            while j < n and text[j] != c:
                if text[j] == "\\":
                    j += 1
                if c != "`" and j < n and text[j] == "\n":
                    break  # unterminated single-line literal: stop at end of line
                j += 1
            out.append(text[i:j + 1])
            i = j + 1
        elif two == "//":
            j = text.find("\n", i)
            j = n if j < 0 else j
            out.append(" " * (j - i))
            i = j
        elif two == "/*":
            j = text.find("*/", i + 2)
            j = n if j < 0 else j + 2
            out.append(re.sub(r"[^\n]", " ", text[i:j]))
            i = j
        else:
            out.append(c)
            i += 1
    return "".join(out)
