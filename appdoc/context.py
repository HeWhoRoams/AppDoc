"""The single parser of ``appdoc-context.md`` (the owner-supplied context file at the Target root).

``parse`` is a pure function of the file text: no file access, no environment, no clock. Callers
read the file and pass its text (``None`` or ``""`` for a missing file). Directives:

* a fenced ```` ```never-mention ```` block: one term per non-blank line;
* ``Ownership: <role>: <value>`` lines (``=`` also separates role from value), outside any fence;
* ``Audit floor: <fraction>, <minimum>`` (for example ``0.4, 8`` or ``40%, 8``), outside any fence: the
  organization's audit sampling floor, applied by ``audit-plan`` only where it is stricter than the default.

Later releases extend ``Context`` with further directives; keep this the only reader of the file.
"""
import re
from dataclasses import dataclass, field
from decimal import Decimal, InvalidOperation


@dataclass(frozen=True)
class OwnershipLine:
    line: int      # 1-based line number in the file
    role: str      # e.g. "Business owner"
    value: str     # free text, may name a person or team; callers must not copy it into Facts


@dataclass(frozen=True)
class AuditFloor:
    line: int
    fraction: str  # a decimal in (0, 1], normalized ("0.5"); a string so no float reaches an artifact
    minimum: int


@dataclass(frozen=True)
class Context:
    never_mention: list = field(default_factory=list)
    ownership: list = field(default_factory=list)
    audit_floor: "AuditFloor | None" = None


_FLOOR_RE = re.compile(r"^\s*([0-9.]+)\s*(%?)\s*,\s*(\d+)\s*$")


def _audit_floor(no: int, rest: str):
    m = _FLOOR_RE.match(rest)
    if not m:
        return None
    try:
        d = Decimal(m.group(1))
    except InvalidOperation:
        return None
    if m.group(2):
        d = d / 100
    if not 0 < d <= 1:
        return None
    return AuditFloor(no, format(d.normalize(), "f"), int(m.group(3)))


def _split_role(rest: str):
    cuts = [i for i in (rest.find(":"), rest.find("=")) if i > 0]
    if not cuts:
        return None
    i = min(cuts)
    role, value = rest[:i].strip(), rest[i + 1:].strip()
    return (role, value) if role and value else None


def parse(text: "str | None") -> Context:
    terms, owners, floor = [], [], None
    fence = None  # None outside a fence, else the fence's info string
    for no, raw in enumerate((text or "").splitlines(), 1):
        s = raw.strip()
        if s.startswith("```"):
            fence = None if fence is not None else s[3:].strip()
            continue
        if fence is not None:
            if fence == "never-mention" and s:
                terms.append(s)
            continue
        if s[:12].lower() == "audit floor:":
            floor = _audit_floor(no, s[12:]) or floor
        if s[:10].lower() == "ownership:":
            rv = _split_role(s[10:])
            if rv:
                owners.append(OwnershipLine(no, rv[0], rv[1]))
    return Context(terms, owners, floor)
