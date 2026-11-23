"""The single parser of ``appdoc-context.md`` (the owner-supplied context file at the Target root).

``parse`` is a pure function of the file text: no file access, no environment, no clock. Callers
read the file and pass its text (``None`` or ``""`` for a missing file). Directives:

* a fenced ```` ```never-mention ```` block: one term per non-blank line;
* ``Ownership: <role>: <value>`` lines (``=`` also separates role from value), outside any fence.

Later releases extend ``Context`` with further directives; keep this the only reader of the file.
"""
from dataclasses import dataclass, field


@dataclass(frozen=True)
class OwnershipLine:
    line: int      # 1-based line number in the file
    role: str      # e.g. "Business owner"
    value: str     # free text, may name a person or team; callers must not copy it into Facts


@dataclass(frozen=True)
class Context:
    never_mention: list = field(default_factory=list)
    ownership: list = field(default_factory=list)


def _split_role(rest: str):
    cuts = [i for i in (rest.find(":"), rest.find("=")) if i > 0]
    if not cuts:
        return None
    i = min(cuts)
    role, value = rest[:i].strip(), rest[i + 1:].strip()
    return (role, value) if role and value else None


def parse(text: "str | None") -> Context:
    terms, owners = [], []
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
        if s[:10].lower() == "ownership:":
            rv = _split_role(s[10:])
            if rv:
                owners.append(OwnershipLine(no, rv[0], rv[1]))
    return Context(terms, owners)
