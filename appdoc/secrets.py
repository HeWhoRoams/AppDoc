"""Secret detection, shared by extract (flag locations) and check (scan the Narrative).

Extractors must never record a secret value. They record the key name and location only.
"""

from __future__ import annotations

import math
import re

SECRET_KEY_RE = re.compile(
    r"(password|passwd|pwd|secret|token|api[_-]?key|connection[_-]?string|credential|"
    r"private[_-]?key|client[_-]?secret|account[_-]?key|\bsas\b)",
    re.IGNORECASE,
)

# (name, regex) pairs for secret-shaped values.
SHAPES = [
    ("connection-string-password", re.compile(r"(?i)\b(?:password|pwd)\s*=\s*[^;\s\"'<>]{3,}")),
    ("uri-credentials", re.compile(r"\b[a-z][a-z0-9+.-]*://[^/\s:@]+:[^/\s:@]{3,}@")),
    ("aws-access-key", re.compile(r"\bAKIA[0-9A-Z]{16}\b")),
    ("private-key-block", re.compile(r"-----BEGIN [A-Z ]*PRIVATE KEY-----")),
    ("jwt", re.compile(r"\beyJ[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\.[A-Za-z0-9_-]{8,}\b")),
    ("azure-account-key", re.compile(r"(?i)\baccountkey\s*=\s*[A-Za-z0-9+/=]{20,}")),
]

_ASSIGN_RE = re.compile(
    r"""(?ix)
    (?P<key>[A-Za-z0-9_.\-]*(?:password|passwd|pwd|secret|token|api[_-]?key|credential|private[_-]?key|account[_-]?key)[A-Za-z0-9_.\-]*)
    \s*[:=]\s*
    ["']?(?P<val>[^\s"';,<>]{8,})
    """
)
_HEX40 = re.compile(r"^[0-9a-f]{40}$", re.IGNORECASE)
_GUID = re.compile(r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$", re.IGNORECASE)


def entropy(s: str) -> float:
    if not s:
        return 0.0
    n = len(s)
    return -sum((s.count(c) / n) * math.log2(s.count(c) / n) for c in set(s))


def is_secret_key(name: str) -> bool:
    return bool(SECRET_KEY_RE.search(name or ""))


def find_secret_shapes(text: str) -> list[tuple[int, str]]:
    """Return (1-based line, shape name) for every secret-shaped string in text.

    Never returns the matched value.
    """
    hits: list[tuple[int, str]] = []
    for lineno, line in enumerate(text.splitlines(), 1):
        for name, rx in SHAPES:
            if rx.search(line):
                hits.append((lineno, name))
        for m in _ASSIGN_RE.finditer(line):
            val = m.group("val")
            if _HEX40.match(val) or _GUID.match(val):
                continue
            if len(val) >= 32 and entropy(val) >= 4.0:
                hits.append((lineno, "high-entropy-secret"))
    return sorted(set(hits))


def value_leaks(text: str, forbidden: list[str]) -> list[str]:
    """Return which of the forbidden strings (known secret values) appear in text."""
    return [f for f in forbidden if f and f in text]
