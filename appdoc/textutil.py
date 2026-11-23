"""Small text helpers shared by fill, register and check (a neutral module: no AppDoc imports)."""

from __future__ import annotations


def plural(n: int, singular: str, plural_form: str | None = None) -> str:
    """"1 file", "0 files", "2 entries": the count and the noun in the right number (no "(s)")."""
    return f"{n} {singular if n == 1 else (plural_form or singular + 's')}"
