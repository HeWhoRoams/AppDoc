"""Small text helpers shared by fill, notes, register and check (a neutral module: no AppDoc imports)."""

from __future__ import annotations


def plural(n: int, singular: str, plural_form: str | None = None) -> str:
    """"1 file", "0 files", "2 entries": the count and the noun in the right number (no "(s)")."""
    return f"{n} {singular if n == 1 else (plural_form or singular + 's')}"


def read_text(path: str) -> str:
    """The text of a file the writer edits: UTF-8, else Windows-1252 (the one decoder every module shares)."""
    with open(path, "rb") as fh:
        raw = fh.read()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp1252", errors="replace")
