"""Secret detection, shared by extract (flag locations) and check (scan the Narrative).

Extractors must never record a secret value. They record the key name and location only.
"""

from __future__ import annotations

import math
import re

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
# A file path or Citation (`a/b/c.asp:12`): has a folder separator and a file extension, optional line or range.
_PATH_VALUE = re.compile(r"^[\w.\-@~$+/\\]*[/\\][\w.\-@~$+/\\]*\.[A-Za-z][A-Za-z0-9]{0,7}(?::\d+(?:-\d+)?)?$")
# A bare file name with a line (`appsettings.json:12`).
_FILE_LINE_VALUE = re.compile(r"^[\w.\-@~$+]+\.[A-Za-z][A-Za-z0-9]{0,7}:\d+(?:-\d+)?$")


def entropy(s: str) -> float:
    if not s:
        return 0.0
    n = len(s)
    return -sum((s.count(c) / n) * math.log2(s.count(c) / n) for c in set(s))


# Segment-aware key naming (Q6). A name is split on separators and camel case into lower-case words.
# It is a secret when a secret noun is present and no modifier from the closed set below is. The sets
# live here, are closed, and are not extended from a Target's names.
_SECRET_NOUNS = frozenset("password passwords passwd pwd secret secrets token tokens credential credentials sas".split())
_SECRET_PAIRS = frozenset({("api", "key"), ("api", "keys"), ("private", "key"), ("private", "keys"),
                           ("account", "key"), ("account", "keys"), ("connection", "string"),
                           ("connection", "strings")})
_SECRET_FUSED = frozenset("apikey privatekey accountkey connectionstring".split())
_FUSE_NOUNS = ("password", "passwd", "secret", "token", "credential", "pwd")
SECRET_MODIFIERS = frozenset(
    "length min max size count ttl lifetime expiry expires minutes seconds hours days algo algorithm hash "
    "complexity policy check pwn enable enabled disable disabled allow require required form cache uri url "
    "path file header name type mode scope scopes regex pattern".split())
_REF_MODIFIERS = frozenset(("uri", "path", "file"))  # the value names where a secret lives, it is not one
_WORD_SPLIT = re.compile(r"[^A-Za-z0-9]+")
_CAMEL_1 = re.compile(r"([a-z0-9])([A-Z])")
_CAMEL_2 = re.compile(r"([A-Z]+)([A-Z][a-z])")


def _words(name: str) -> list[str]:
    """Lower-case words of a key name: separators and camel case split it ("DBPassword" -> db, password).

    A lower-case word with a noun fused to one end is split once: "dbpassword" -> db, password and
    "passwordlength" -> password, length. A word that merely starts with a noun ("secretary") is kept whole.
    """
    out: list[str] = []
    for part in _WORD_SPLIT.split(_CAMEL_2.sub(r"\1 \2", _CAMEL_1.sub(r"\1 \2", name or ""))):
        w = part.lower()
        if not w:
            continue
        if w not in _SECRET_NOUNS and w not in SECRET_MODIFIERS and w not in _SECRET_FUSED:
            for noun in _FUSE_NOUNS:
                if w.endswith(noun) and len(w) > len(noun):
                    out += [w[:-len(noun)], noun]
                    break
                if w.startswith(noun) and w[len(noun):] in SECRET_MODIFIERS:
                    out += [noun, w[len(noun):]]
                    break
            else:
                out.append(w)
            continue
        out.append(w)
    return out


def _secret_kind(name: str) -> str | None:
    """"secret" (names a secret), "ref" (names where one lives: uri, path, file) or None."""
    words = _words(name)
    has_noun = any(w in _SECRET_NOUNS or w in _SECRET_FUSED for w in words) \
        or any(pair in _SECRET_PAIRS for pair in zip(words, words[1:]))
    if not has_noun:
        return None
    mods = {w for w in words if w in SECRET_MODIFIERS}
    if not mods:
        return "secret"
    return "ref" if mods <= _REF_MODIFIERS else None


def is_secret_key(name: str) -> bool:
    return _secret_kind(name) == "secret"


def is_secret_ref(name: str) -> bool:
    """True for a key that points at a secret held elsewhere (`SECRET_KEY_URI`, `DB_PASSWORD_FILE`)."""
    return _secret_kind(name) == "ref"


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
            val = m.group("val").lstrip("`").rstrip("`.)")
            if _HEX40.match(val) or _GUID.match(val) or _PATH_VALUE.match(val) or _FILE_LINE_VALUE.match(val):
                continue
            if len(val) >= 32 and entropy(val) >= 4.0:
                hits.append((lineno, "high-entropy-secret"))
    return sorted(set(hits))


def value_leaks(text: str, forbidden: list[str]) -> list[str]:
    """Return which of the forbidden strings (known secret values) appear in text."""
    return [f for f in forbidden if f and f in text]
