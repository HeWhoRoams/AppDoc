"""The one text normalization (R14): what two spellings of the same document must agree on.

Used by ``check._claim_sha`` and therefore by the seal, so a Narrative checked out with LF on Linux
and CRLF on Windows (or saved with a combining accent) keeps the same ``claim_sha``.
"""

from __future__ import annotations

import unicodedata


def normalize_text(text: str) -> str:
    """CRLF and CR become LF, trailing whitespace is stripped from every line, the final newline
    is dropped, and the result is NFC. Pure and idempotent."""
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = "\n".join(line.rstrip() for line in text.split("\n"))
    return unicodedata.normalize("NFC", text.rstrip("\n"))
