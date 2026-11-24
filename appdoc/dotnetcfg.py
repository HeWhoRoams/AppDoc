"""Hardened reader for .NET XML configuration: ``Web*.config``, transforms, ``app.config``, ``.csproj``, ``.pubxml``.

Stdlib only; imports nothing from appdoc (it returns plain data, callers build Facts). Rules (plan 2.8, W13):

* **bytes in** to ``xml.parsers.expat`` with ``namespace_separator=" "``; the BOM and the XML declaration choose the
  encoding. ``CurrentLineNumber`` is recorded in the start handler, so a Fact line is the line of the start tag's
  ``<`` (for a missing attribute, the element's line).
* a file whose raw bytes contain ``<!DOCTYPE`` or ``<!ENTITY`` (also in UTF-16) is rejected with reason ``dtd``; the
  parser's own DOCTYPE and ENTITY handlers are a second line, so no entity is ever expanded. No ``minidom``, no ``lxml``.
* size cap ``SOFT_CAP`` (2 MiB; a caller may raise it, never past ``HARD_CAP``, 8 MiB) and depth cap ``MAX_DEPTH``;
  both give reason ``oversize``. Malformed XML gives one reason (``malformed``, or ``encoding`` for an unknown or wrong
  declared encoding) and **no partial tree**.
* element names are returned without their namespace (legacy ``xmlns=".NetConfiguration/v2.0"``). XDT attributes are
  recognised by **namespace URI** (``http`` and ``https`` forms), never by the prefix ``xdt``.
* comments and CDATA never become elements (a commented-out rule is not a Fact).
* file names are matched case-insensitively.
* ``enum_value`` lower-cases a value and tests it against the **per-attribute** closed enumeration; anything else is
  ``other``, so an arbitrary string never reaches a Fact.
"""
from __future__ import annotations

import os
import re
import xml.parsers.expat as _expat
from dataclasses import dataclass, field

SOFT_CAP = 2 * 1024 * 1024
HARD_CAP = 8 * 1024 * 1024
MAX_DEPTH = 100
MAX_ELEMENTS = 200_000

REASONS = ("dtd", "oversize", "malformed", "encoding")
_XDT_URIS = frozenset({"http://schemas.microsoft.com/XML-Document-Transform",
                       "https://schemas.microsoft.com/XML-Document-Transform"})


@dataclass
class Node:
    """One element: local ``name``, non-namespaced ``attrs``, XDT attributes by local name, start-tag ``line``."""
    name: str
    attrs: dict
    xdt: dict
    line: int
    children: list = field(default_factory=list)
    text: str = ""   # the element's own character data (CDATA included), stripped; a leaf value such as <OutputType>
    text: str = ""   # the element's own character data (CDATA included), stripped; a leaf value such as <OutputType>

    def find(self, *path: str) -> "Node | None":
        """First descendant reached by following ``path`` names through first matching children."""
        node = self
        for name in path:
            node = next((c for c in node.children if c.name == name), None)
            if node is None:
                return None
        return node

    def findall(self, name: str) -> list:
        return [c for c in self.children if c.name == name]

    def iter(self):
        yield self
        for c in self.children:
            yield from c.iter()


@dataclass(frozen=True)
class Doc:
    """Result of ``parse``: either a tree (``root``) or one ``unparsed`` reason, never both."""
    root: "Node | None"
    unparsed: "str | None" = None


class _Reject(Exception):
    def __init__(self, reason: str):
        self.reason = reason


_DTD_MARKS = tuple(m for s in ("<!DOCTYPE", "<!ENTITY")
                   for m in (s.encode("ascii"), s.encode("utf-16-le"), s.encode("utf-16-be")))


def parse(data: bytes, max_bytes: int = SOFT_CAP, encoding: "str | None" = None) -> Doc:
    """Parse configuration XML from raw bytes. ``encoding`` overrides the declaration (callers holding only
    already-decoded text pass ``"utf-8"``)."""
    limit = min(max_bytes, HARD_CAP)
    if len(data) > limit:
        return Doc(None, "oversize")
    if any(m in data for m in _DTD_MARKS):
        return Doc(None, "dtd")

    state = {"depth": 0, "count": 0}
    stack: list = []
    top: list = []

    def start(name, attrs):
        state["depth"] += 1
        state["count"] += 1
        if state["depth"] > MAX_DEPTH or state["count"] > MAX_ELEMENTS:
            raise _Reject("oversize")
        plain, xdt = {}, {}
        for k, v in attrs.items():
            if " " in k:
                uri, local = k.rsplit(" ", 1)
                if uri in _XDT_URIS:
                    xdt[local] = v
            else:
                plain[k] = v
        node = Node(name.rsplit(" ", 1)[-1], plain, xdt, parser.CurrentLineNumber)
        (stack[-1].children if stack else top).append(node)
        stack.append(node)

    def chars(data):
        if stack:
            stack[-1].text += data

    def end(_name):
        state["depth"] -= 1
        node = stack.pop()
        node.text = node.text.strip()

    def reject_dtd(*_a):
        raise _Reject("dtd")

    parser = _expat.ParserCreate(encoding, namespace_separator=" ")
    parser.StartElementHandler = start
    parser.EndElementHandler = end
    parser.CharacterDataHandler = chars
    parser.StartDoctypeDeclHandler = reject_dtd
    parser.EntityDeclHandler = reject_dtd
    parser.SetParamEntityParsing(_expat.XML_PARAM_ENTITY_PARSING_NEVER)
    try:
        parser.Parse(data, True)
    except _Reject as r:
        return Doc(None, r.reason)
    except _expat.ExpatError as e:
        if e.code in (_expat.errors.codes.get(_expat.errors.XML_ERROR_UNKNOWN_ENCODING),
                      _expat.errors.codes.get(_expat.errors.XML_ERROR_INCORRECT_ENCODING)):
            return Doc(None, "encoding")
        return Doc(None, "malformed")
    except (ValueError, LookupError):
        return Doc(None, "encoding")
    if len(top) != 1:
        return Doc(None, "malformed")
    return Doc(top[0])


# ---------------------------------------------------------------- file names (case-insensitive)

_TRANSFORM_RE = re.compile(r"(?i)^(?:web|app)\.(.+)\.config$")


def _base(path: str) -> str:
    return path.replace("\\", "/").rsplit("/", 1)[-1].lower()


def is_config_name(path: str) -> bool:
    """``web.config`` or ``app.config`` in any case."""
    return _base(path) in ("web.config", "app.config")


def transform_config_name(path: str) -> "str | None":
    """The configuration name of a transform file (``Web.Release.config`` gives ``Release``), else ``None``."""
    m = _TRANSFORM_RE.match(path.replace("\\", "/").rsplit("/", 1)[-1])
    return m.group(1) if m else None


def is_project_name(path: str) -> bool:
    return _base(path).endswith(".csproj")


def is_pubxml_name(path: str) -> bool:
    """A publish profile. ``*.pubxml.user`` holds per-user secrets and is never read."""
    return _base(path).endswith(".pubxml")


# ---------------------------------------------------------------- per-attribute closed enumerations

_BOOL = ("true", "false")
ENUMS = {
    ("authentication", "mode"): ("windows", "forms", "passport", "none"),
    ("forms", "requireSSL"): _BOOL,
    ("customErrors", "mode"): ("on", "off", "remoteonly"),
    ("compilation", "debug"): _BOOL,
    ("httpCookies", "requireSSL"): _BOOL,
    ("httpCookies", "httpOnlyCookies"): _BOOL,
    ("sessionState", "mode"): ("off", "inproc", "stateserver", "sqlserver", "custom"),
    ("sessionState", "cookieless"): ("usecookies", "useuri", "autodetect", "usedeviceprofile", "true", "false"),
    ("trace", "enabled"): _BOOL,
    ("trace", "localOnly"): _BOOL,
    ("httpRuntime", "requestValidationMode"): ("2.0", "4.0", "4.5"),
    ("identity", "impersonate"): _BOOL,
    ("httpErrors", "errorMode"): ("detailedlocalonly", "custom", "detailed"),
}


def enum_value(element: str, attr: str, value: "str | None") -> str:
    """Lower-cased value if it is in the closed enumeration for ``element@attr``, else ``other``."""
    allowed = ENUMS.get((element, attr))
    v = (value or "").strip().lower()
    return v if allowed and v in allowed else "other"
