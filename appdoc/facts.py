"""The Fact record and the reproducible serialization of the Facts file."""

from __future__ import annotations

import json
from dataclasses import dataclass, field

SCHEMA = "appdoc-facts/2"

KINDS = (
    "file",
    "stack",
    "entry_point",
    "data_access",
    "connection",
    "config_key",
    "dependency",
    "external_call",
    "auth_check",
    "message",
    "ownership",
)


@dataclass(frozen=True)
class Fact:
    """One observation about the Target, with the file and line it came from.

    ``detail`` must be flat and JSON-serializable and must never contain a secret value.
    """

    kind: str
    stack: str
    path: str
    line: int | None
    name: str
    detail: tuple = field(default_factory=tuple)  # sorted (key, value) pairs; use make()

    @staticmethod
    def make(kind, stack, path, line, name, **detail) -> "Fact":
        if kind not in KINDS:
            raise ValueError(f"unknown fact kind: {kind}")
        items = []
        for k in sorted(detail):
            v = detail[k]
            if isinstance(v, (list, set, tuple)):
                v = _freeze_list(v)
            items.append((k, v))
        return Fact(kind, stack, path.replace("\\", "/"), line, str(name), tuple(items))

    def detail_dict(self) -> dict:
        return {k: (list(v) if isinstance(v, tuple) else v) for k, v in self.detail}

    def sort_key(self):
        return (self.path, self.line or 0, self.kind, self.name, repr(self.detail))

    def to_json(self) -> dict:
        return {
            "kind": self.kind,
            "stack": self.stack,
            "path": self.path,
            "line": self.line,
            "name": self.name,
            "detail": self.detail_dict(),
        }


def _freeze_list(values) -> tuple:
    try:
        return tuple(sorted(values))
    except TypeError:
        return tuple(values)


def dumps(target_name: str, commit: str | None, facts) -> str:
    """Serialize facts to the canonical Facts file text (sorted, de-duplicated, no timestamps)."""
    unique = sorted(set(facts), key=lambda f: f.sort_key())
    stacks = [f.to_json() for f in unique if f.kind == "stack"]
    others = [f.to_json() for f in unique if f.kind != "stack"]
    doc = {
        "schema": SCHEMA,
        "target": {"name": target_name, "commit": commit},
        "stacks": stacks,
        "facts": others,
    }
    return json.dumps(doc, sort_keys=True, indent=1, ensure_ascii=False) + "\n"


def loads(text: str) -> dict:
    return json.loads(text)
