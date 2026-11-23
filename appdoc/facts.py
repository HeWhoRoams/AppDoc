"""The Fact record and the reproducible serialization of the Facts file."""

from __future__ import annotations

import json
import hashlib
import re
from dataclasses import dataclass, field

SCHEMA = "appdoc-facts/5"

_TEST_DIRS = {"test", "tests", "__tests__", "spec", "specs", "testing"}
_TEST_FILE_RE = re.compile(
    r"(^test_.*\.py$|_test\.py$|_test\.go$|(Tests?|IT)\.java$|Tests?\.cs$|\.(test|spec)\.[cm]?[jt]sx?$|^conftest\.py$)")


def is_test_path(path: str) -> bool:
    parts = path.split("/")
    return any(p.lower() in _TEST_DIRS for p in parts[:-1]) or bool(_TEST_FILE_RE.search(parts[-1]))

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
    "smell",          # finding candidate: detail pattern (id), fid (stable id)
    "schema_object",  # DDL: detail type = table|index|fk, dialect, columns/expression/unique
    "owner_file",     # CODEOWNERS, MAINTAINERS, ...: detail entries (count only, never names)
    "ui_page",        # XAML page or similar: detail x_class, route
)

# Allowed detail keys per kind (conformance guard, Phase 2.3).
DETAIL_KEYS = {
    "file": frozenset("encoding ext lines size stacks".split()),
    "stack": frozenset("capabilities file_count marker_files supported".split()),
    "entry_point": frozenset(
        "class codebehind controller enabled exists framework handler inherits inputs "
        "master method middleware page prefix_unresolved route_name schedule scheduler "
        "source type usage view".split()),
    "data_access": frozenset(
        "builder class entity namespace native operation orm property statement type via".split()),
    "connection": frozenset("class secret_location source type".split()),
    "config_key": frozenset("role secret_location source use via".split()),
    "dependency": frozenset("manager mode version".split()),
    "external_call": frozenset("call client method mode operation type via".split()),
    "auth_check": frozenset("applies_to mechanism policy roles scope".split()),
    "message": frozenset("context exception".split()),
    "ownership": frozenset("authors commits role source".split()),  # authors leave in 2.6 (Q32)
    "smell": frozenset("constant fid pattern".split()),
    "schema_object": frozenset("columns dialect expression type unique".split()),
    "owner_file": frozenset("entries kind".split()),
    "ui_page": frozenset("root route x_class".split()),
}


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

    def as_test(self) -> "Fact":
        """Copy of this Fact marked as coming from test code."""
        if any(k == "test" for k, _ in self.detail):
            return self
        return Fact(self.kind, self.stack, self.path, self.line, self.name,
                    tuple(sorted(self.detail + (("test", True),))))

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

    @classmethod
    def from_json(cls, d: dict) -> "Fact":
        """Reconstruct a Fact from its ``to_json()`` dict. Exact round-trip:
        ``from_json(f.to_json()) == f`` (detail collections come back as tuples, as in ``make``)."""
        detail = tuple(sorted((k, (tuple(v) if isinstance(v, list) else v))
                              for k, v in d["detail"].items()))
        return cls(d["kind"], d["stack"], d["path"], d["line"], d["name"], detail)


def fact_id(kind: str, pattern: str, path: str, line: int | None) -> str:
    """Stable 8-hex id for a Fact that other files refer to (smell/<id> in the register)."""
    return hashlib.sha1(f"{kind}|{pattern}|{path}|{line or 0}".encode("utf-8")).hexdigest()[:8]


def _freeze_list(values) -> tuple:
    try:
        return tuple(sorted(values))
    except TypeError:
        return tuple(values)


def dumps(target_name: str, commit: str | None, facts, history: str | None = None,
          scan: dict | None = None) -> str:
    """Serialize facts to the canonical Facts file text (sorted, de-duplicated, no timestamps)."""
    from . import __version__
    unique = sorted(set(facts), key=lambda f: f.sort_key())
    stacks = [f.to_json() for f in unique if f.kind == "stack"]
    others = [f.to_json() for f in unique if f.kind != "stack"]
    target = {"name": target_name, "commit": commit, "history": history or "none"}
    if scan is not None:
        target["scan"] = scan
    doc = {
        "schema": SCHEMA,
        "generator": __version__,
        "target": target,
        "stacks": stacks,
        "facts": others,
    }
    return json.dumps(doc, sort_keys=True, indent=1, ensure_ascii=False) + "\n"


def loads(text: str) -> dict:
    return json.loads(text)
