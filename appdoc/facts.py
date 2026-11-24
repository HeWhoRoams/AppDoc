"""The Fact record and the reproducible serialization of the Facts file."""

from __future__ import annotations

import json
import hashlib
import re
from dataclasses import dataclass, field

SCHEMA = "appdoc-facts/7"

_TEST_DIRS = {"test", "tests", "__tests__", "spec", "specs", "testing"}
_TEST_FILE_RE = re.compile(
    r"(^test_.*\.py$|_test\.py$|_test\.go$|(Tests?|IT)\.java$|Tests?\.cs$|\.(test|spec)\.[cm]?[jt]sx?$|^conftest\.py$)")


def is_test_path(path: str) -> bool:
    parts = path.split("/")
    return any(p.lower() in _TEST_DIRS for p in parts[:-1]) or bool(_TEST_FILE_RE.search(parts[-1]))


_TEST_DATA_DIRS = {"fixtures", "__fixtures__", "testdata", "e2e"}


def is_test_data_path(path: str) -> bool:
    """A folder of test fixtures or end-to-end data: ``fixtures``, ``__fixtures__``, ``e2e``, ``*testdata``."""
    return any(p.lower() in _TEST_DATA_DIRS or p.lower().endswith("testdata") for p in path.split("/")[:-1])

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
    # 2.8 raw per-file kinds (stream 4C/4D foundation); each is emitted per file and joined only in post-passes
    "security_setting",       # .config security element/attribute (closed set), value from a closed enumeration
    "access_rule",           # <allow>/<deny>/<clear/>/<remove> in <authorization>
    "access_rule_unmatched", # a rule whose scope_path matches no route prefix and no folder (summary-only)
    "config_transform",      # one XDT transform element
    "config_external",       # configSource / appSettings file=
    "config_unparsed",       # a config file the hardened reader refused (reason dtd|oversize|malformed|encoding)
    "guard_class",           # Target class deriving from an authorization-capable type
    "guard_use",             # one use of a guard attribute
    "guard_candidate",       # external attribute used on >=3 controllers/actions
    "const_def",             # const / static readonly string
    "project",               # .csproj: output type, sdk, kind
    "build_define",          # per-configuration DefineConstants tokens
    "publish_profile",       # .pubxml: name, build_config, method, host only
    "context_directive",     # one appdoc-context.md directive
    "controller_class",      # MVC/Web API controller class marker (class line, base list)
    "host_auth",             # IIS/OWIN authentication disclosure
    "method_call",           # a call whose arguments hold >= 2 constant references (auth_method candidates)
)

# Allowed detail keys per kind (conformance guard, Phase 2.3).
DETAIL_KEYS = {
    "file": frozenset("encoding ext lines size stacks".split()),
    "stack": frozenset("capabilities file_count ignored_markers marker_files supported".split()),
    "entry_point": frozenset(
        "attr_route base_external child_action class codebehind component controller enabled end_line exists framework "
        "guard_mechanism handler http_route inherits inputs listener master method middleware mvc_area mvc_area_path "
        "override_authorization page prefix_unresolved reach reach_anon reach_auth reach_by_config reach_roles "
        "reasons route_name schedule scheduler source state_changing type url_set usage verb_convention verbs "
        "verbs_declared view writes".split()),
    "data_access": frozenset(
        "builder class entity namespace native operation orm property statement type via".split()),
    "connection": frozenset("class overridden_in secret_location source type".split()),
    "config_key": frozenset("list_count overridden_in read_kind role secret_location secret_ref source use via year".split()),
    "dependency": frozenset("manager mode version".split()),
    "external_call": frozenset("call client config_key method mode operation type via".split()),
    "auth_check": frozenset(
        "api_pipeline applies_to arity mechanism namespace overrides_authorization policy role_guard role_refs roles "
        "scope users_named via".split()),
    "message": frozenset("context exception".split()),
    "ownership": frozenset("commits contributors first_commit last_commit role source".split()),  # counts and dates, no names (R18)
    "smell": frozenset("configs constant count fid overridden_in pattern sources".split()),
    "schema_object": frozenset("columns dialect expression type unique".split()),
    "owner_file": frozenset("entries kind".split()),
    "ui_page": frozenset("root route type x_class".split()),
    "security_setting": frozenset(
        "config config_status count local_only name overridden_in reason secret_location value".split()),
    "access_rule": frozenset(
        "all allow_override anon config config_status domain_qualified effect file inherit_in_child_apps location "
        "order reason_codes roles scope_path users_named verbs".split()),
    "access_rule_unmatched": frozenset("effect file order scope_path".split()),
    "config_transform": frozenset(
        "arglist attributes config locator locator_attrs match operation recognised rules supported target_path "
        "unsupported_reason".split()),
    "config_external": frozenset("element resolved target".split()),
    "config_unparsed": frozenset("reason".split()),
    "guard_class": frozenset("authorization_capable base_list base_external overrides_authorization".split()),
    "guard_use": frozenset(
        "api_pipeline applies_to arg_kinds arg_refs arity arity_override attribute namespace role role_arg role_ref "
        "scope users_named users_ref".split()),
    "guard_candidate": frozenset("arity_set attribute uses".split()),
    "const_def": frozenset("qualified secret under_if value".split()),
    "project": frozenset("configs iis_express kind output_type sdk test transform_lookup web".split()),
    "build_define": frozenset("config inherits symbols".split()),
    "publish_profile": frozenset("build_config host method".split()),
    "context_directive": frozenset("context_unmatched directive names value".split()),
    "controller_class": frozenset("base_external base_list filter_hooks override_authorization".split()),
    "host_auth": frozenset("iis_anonymous iis_authorization_present owin_auth source".split()),
    "method_call": frozenset("applies_to arg_refs arity".split()),
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
            if isinstance(v, dict) or (isinstance(v, (list, set, tuple)) and any(isinstance(x, (dict, list, set)) for x in v)):
                raise ValueError(f"Fact detail {k!r} must be a scalar or a list of scalars, not a dict or nested list")
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
        detail = tuple(sorted((k, (tuple(tuple(x) if isinstance(x, list) else x for x in v)
                                   if isinstance(v, list) else v))
                              for k, v in d["detail"].items()))   # ``sources`` is a list of tuples: freeze both levels
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
    unique = sorted(set(facts), key=lambda f: f.sort_key())
    stacks = [f.to_json() for f in unique if f.kind == "stack"]
    others = [f.to_json() for f in unique if f.kind != "stack"]
    target = {"name": target_name, "commit": commit, "history": history or "none"}
    if scan is not None:
        target["scan"] = scan
    doc = {
        "schema": SCHEMA,
        "target": target,
        "stacks": stacks,
        "facts": others,
    }
    return json.dumps(doc, sort_keys=True, indent=1, ensure_ascii=False) + "\n"


def loads(text: str) -> dict:
    return json.loads(text)
