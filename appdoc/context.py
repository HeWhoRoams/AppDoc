"""The single parser of ``appdoc-context.md`` (the owner-supplied context file at the Target root).

``parse`` is a pure function of the file text: no file access, no environment, no clock. Callers
read the file and pass its text (``None`` or ``""`` for a missing file). Directives:

* a fenced ```` ```never-mention ```` block: one term per non-blank line;
* ``Ownership: <role>: <value>`` lines (``=`` also separates role from value), outside any fence;
* ``Audit floor: <fraction>, <minimum>`` (for example ``0.4, 8`` or ``40%, 8``), outside any fence: the
  organization's audit sampling floor, applied by ``audit-plan`` only where it is stricter than the default.

* ``Auth attributes: A, B`` (one or more lines, brackets and duplicates dropped): attribute names the owner declares to be
  authorization guards;
* ``Production config: <name>``: the build configuration that is production (default ``Release``, applied by callers);
* ``Reference year: <YYYY>``: the year the owner declares as "now" (no clock is ever read, P3/P5);
* ``Record connection targets: yes|no``: whether per-configuration connection targets may be recorded (default no).

A repeated single-valued directive keeps its last valid line; an invalid value is ignored. ``directives`` lists every
directive line once, in line order, for the ``context_directive`` Facts. Keep this the only reader of the file.
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
class AuthAttributes:
    line: int
    names: tuple   # attribute names as written (brackets removed), first occurrence order


@dataclass(frozen=True)
class ProductionConfig:
    line: int
    name: str


@dataclass(frozen=True)
class ReferenceYear:
    line: int
    year: int


@dataclass(frozen=True)
class RecordTargets:
    line: int
    enabled: bool


@dataclass(frozen=True)
class Context:
    never_mention: list = field(default_factory=list)
    ownership: list = field(default_factory=list)
    audit_floor: "AuditFloor | None" = None
    auth_attributes: list = field(default_factory=list)
    production_config: "ProductionConfig | None" = None
    reference_year: "ReferenceYear | None" = None
    record_connection_targets: "RecordTargets | None" = None


@dataclass(frozen=True)
class Directive:
    """One directive line, for a ``context_directive`` Fact. ``value`` is a scalar string or ``None``; ``names`` a
    tuple of identifiers. An ownership value may name a person and is never carried."""
    line: int
    name: str        # display name, e.g. "Reference year"
    key: str         # machine key, e.g. "reference_year"
    value: "str | None" = None
    names: tuple = ()


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


_IDENT_RE = re.compile(r"^[A-Za-z_][A-Za-z0-9_.]*$")
_CONFIG_NAME_RE = re.compile(r"^[A-Za-z0-9_][A-Za-z0-9_. -]{0,63}$")
_YEAR_RE = re.compile(r"^\d{4}$")


def _auth_names(rest: str) -> tuple:
    seen = []
    for tok in rest.split(","):
        tok = tok.strip().strip("[]").strip()
        if _IDENT_RE.match(tok) and tok not in seen:
            seen.append(tok)
    return tuple(seen)


def parse(text: "str | None") -> Context:
    terms, owners, floor = [], [], None
    auth, prod, year, rec = [], None, None, None
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
        low = s.lower()
        if low.startswith("auth attributes:"):
            names = _auth_names(s[16:])
            if names:
                auth.append(AuthAttributes(no, names))
        elif low.startswith("production config:"):
            v = s[18:].strip()
            if _CONFIG_NAME_RE.match(v):
                prod = ProductionConfig(no, v)
        elif low.startswith("reference year:"):
            v = s[15:].strip()
            if _YEAR_RE.match(v):
                year = ReferenceYear(no, int(v))
        elif low.startswith("record connection targets:"):
            v = s[26:].strip().lower()
            if v in ("yes", "no"):
                rec = RecordTargets(no, v == "yes")
    return Context(terms, owners, floor, auth, prod, year, rec)


def directives(ctx: Context) -> list:
    """Every parsed directive line, once, in line order."""
    out = [Directive(a.line, "Auth attributes", "auth_attributes", names=a.names) for a in ctx.auth_attributes]
    out += [Directive(o.line, "Ownership", "ownership") for o in ctx.ownership]
    if ctx.audit_floor:
        out.append(Directive(ctx.audit_floor.line, "Audit floor", "audit_floor",
                             f"{ctx.audit_floor.fraction},{ctx.audit_floor.minimum}"))
    if ctx.production_config:
        out.append(Directive(ctx.production_config.line, "Production config", "production_config",
                             ctx.production_config.name))
    if ctx.reference_year:
        out.append(Directive(ctx.reference_year.line, "Reference year", "reference_year", str(ctx.reference_year.year)))
    if ctx.record_connection_targets:
        r = ctx.record_connection_targets
        out.append(Directive(r.line, "Record connection targets", "record_connection_targets",
                             "yes" if r.enabled else "no"))
    return sorted(out, key=lambda d: (d.line, d.name))
