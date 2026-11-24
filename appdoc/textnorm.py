"""The two normalizations (R14): *newlines* for every hash of file content, *text* for claims and seals.

Used by ``fingerprint.claim_sha`` and therefore by the seal, so a Narrative checked out with LF on Linux
and CRLF on Windows (or saved with a combining accent) keeps the same ``claim_sha``.
"""

from __future__ import annotations

import unicodedata


def normalize_newlines(data):
    """The newline normalization (R14): CRLF and lone CR become LF, nothing else. Takes ``str`` or
    ``bytes`` and returns the same type. Every hash of file content goes through this."""
    if isinstance(data, (bytes, bytearray)):
        return bytes(data).replace(b"\r\n", b"\n").replace(b"\r", b"\n")
    return data.replace("\r\n", "\n").replace("\r", "\n")


def normalize_text(text: str) -> str:
    """The text normalization (R14): newlines, trailing whitespace stripped from every line, the
    final newline dropped, and the result NFC. Pure and idempotent."""
    text = normalize_newlines(text)
    text = "\n".join(line.rstrip() for line in text.split("\n"))
    return unicodedata.normalize("NFC", text.rstrip("\n"))
