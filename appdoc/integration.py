"""The integration view: a deterministic ``System Connections`` section.

A **post-pass** (not the AI Narrative) that aggregates the raw ``connection``, ``external_call``
and ``dependency`` Facts into a system-to-system summary: per-type distinct drivers/targets, the
count, file/line provenance, a compact integration map, and the manifest dependencies.

``render_integration_view(doc)`` is a **pure function of the Facts doc** (``facts.json``):
given the same Facts it always produces byte-identical Markdown. The Facts serializer sorts and
de-duplicates the raw Facts, so the view is stable across runs. It is rendered into the Facts
summary (:mod:`appdoc.summary`) and, when a Narrative is present, into the HTML page
(:mod:`appdoc.render.page`). Standard library only.
"""

from __future__ import annotations

from urllib.parse import urlsplit

# Canonical display order: connection types (database + the 6 catalog additions) then the
# per-call outbound external_call types. Anything not listed sorts after these, alphabetically.
TYPE_ORDER = (
    "database", "cache", "queue", "object_storage", "grpc", "ldap", "search",
    "service", "file_drop", "share", "http", "email", "smtp", "process", "file",
)

TYPE_LABEL = {
    "database": "Database",
    "cache": "Cache",
    "queue": "Queue",
    "object_storage": "Object storage",
    "grpc": "gRPC",
    "ldap": "LDAP",
    "search": "Search",
    "http": "Outbound HTTP",
    "email": "Email",
    "smtp": "Email (SMTP)",
    "process": "Process",
    "file": "File",
    "service": "Service endpoint",
    "file_drop": "File drop",
    "share": "Share",
    "untyped": "Unspecified",
}

_DRIVER_CAP = 5     # distinct drivers shown per system in the map table
_PROVEN_CAP = 3     # file:line examples shown per system in provenance
_DEP_EXAMPLE_CAP = 5


def _label(type_: str) -> str:
    return TYPE_LABEL.get(type_, type_.replace("_", " ").title())


def _cite(f: dict) -> str:
    return f"{f['path']}:{f['line']}" if f.get("line") else f["path"]


def _drivers_cell(names: list[str]) -> str:
    head = ", ".join(f"`{n}`" for n in names[:_DRIVER_CAP])
    if len(names) > _DRIVER_CAP:
        head += f", ... +{len(names) - _DRIVER_CAP} more"
    return head


def _sorted_types(types) -> list[str]:
    known = [t for t in TYPE_ORDER if t in types]
    extra = sorted(t for t in types if t not in TYPE_ORDER)
    return known + extra


def render_integration_view(doc: dict) -> str:
    """Return the deterministic ``System Connections`` Markdown section, or ``""`` if there is
    nothing to report. A pure function of ``doc`` (the ``facts.json`` dict)."""
    facts = doc.get("facts") or []
    # Consistent with the Facts summary: test-code Facts are left out of the aggregate lists.
    conns = [f for f in facts if f["kind"] in ("connection", "external_call") and not f["detail"].get("test")]
    deps = [f for f in facts if f["kind"] == "dependency" and not f["detail"].get("test")]
    if not conns and not deps:
        return ""

    out = ["## System Connections", ""]
    out += ["> Derived deterministically from the `connection`, `external_call` and `dependency` "
            "Facts in `facts.json` - a pure function of the Facts, byte-identical across runs. "
            "A group with no rows is not proof of absence; the extractors only recognise the "
            "patterns of the detected Stacks.", ""]

    # --- integration map ---------------------------------------------------
    out += ["### Integration map", ""]
    types = _sorted_types({f["detail"].get("type", "untyped") for f in conns})
    if types:
        out.append("app -> { " + ", ".join(types) + " }")
        out += ["", "| System | Kind | Count | Drivers / targets |", "|---|---|---:|---|"]
        for type_ in types:
            of = [f for f in conns if f["detail"].get("type", "untyped") == type_]
            kind = "connection" if any(f["kind"] == "connection" for f in of) else "external call"
            names = sorted({f["name"] for f in of})
            out.append(f"| {_label(type_)} | {kind} | {len(of)} | {_drivers_cell(names)} |")
    else:
        out.append("_No system connections extracted._")
    out.append("")

    # --- provenance per system --------------------------------------------
    if types:
        out += ["### Provenance", ""]
        for type_ in types:
            of = [f for f in conns if f["detail"].get("type", "untyped") == type_]
            names = sorted({f["name"] for f in of})
            out.append(f"- **{_label(type_)}** - {len(of)} x {', '.join(f'`{n}`' for n in names[:_DRIVER_CAP])}"
                       + (f" (+{len(names) - _DRIVER_CAP} more)" if len(names) > _DRIVER_CAP else ""))
            locs = sorted({_cite(f) for f in of})
            for loc in locs[:_PROVEN_CAP]:
                out.append(f"  - `{loc}`")
            if len(locs) > _PROVEN_CAP:
                out.append(f"  - ... {len(locs) - _PROVEN_CAP} more in `facts.json`")
        out.append("")

    # --- dependencies ------------------------------------------------------
    if deps:
        by_mgr: dict[str, list[dict]] = {}
        for f in deps:
            by_mgr.setdefault(f["detail"].get("manager") or "(unknown)", []).append(f)
        out += ["### Dependencies", "", "| Manager | Count | Examples |", "|---|---:|---|"]
        for mgr in sorted(by_mgr):
            ds = by_mgr[mgr]
            names = sorted({f["name"] for f in ds})
            head = ", ".join(f"`{n}`" for n in names[:_DEP_EXAMPLE_CAP])
            if len(names) > _DEP_EXAMPLE_CAP:
                head += f", ... +{len(names) - _DEP_EXAMPLE_CAP} more"
            out.append(f"| {mgr} | {len(ds)} | {head} |")
        out.append("")

    return "\n".join(out).rstrip() + "\n"


# ---------------------------------------------------------------------------------------------------------------
# Rows for the `connections` (8.1) and `integrations` (8.3) generated blocks (T28.92). Pure functions of the Facts,
# sorted, never holding a value: a target is `scheme://host[:port]` at most (R18, R19).

# The order of external-call types in the `integrations` block: the closed list of plan 2.8 section 6.2 first
# (convention calls arrive in 2.9 with the same types), any other type after it, alphabetically.
CALL_TYPE_ORDER = ("service", "file_drop", "smtp", "http", "file")

_NAME_CAP = 120
_CONFIG_ORDER = lambda c: (c.casefold(), c)   # noqa: E731  (case-insensitive, then exact: a total order)


def safe_target(name: str) -> str:
    """A name or address as a block may print it: a URL is cut to `scheme://host[:port]` (no userinfo, path, query or
    fragment); anything else is capped and its line breaks and pipes made harmless. Never raises."""
    s = " ".join(str(name).split())
    if "://" in s:
        try:
            u = urlsplit(s)
            host, port = u.hostname, u.port
        except ValueError:
            return "(unparsable address)"
        if u.scheme and host:
            host = f"[{host}]" if ":" in host else host
            return f"{u.scheme.lower()}://{host}" + (f":{port}" if port else "")
        return "(unparsable address)"
    s = s.replace("`", "'").replace("|", "/")
    return s if len(s) <= _NAME_CAP else s[:_NAME_CAP - 3] + "..."


def _where(f: dict) -> str:
    return _cite(f) + (" (test)" if f["detail"].get("test") else "")


def connection_rows(doc: dict) -> list[dict]:
    """One row per `connection` name across base, transform and test configuration files, sorted by name.

    Each row: `name`, `types` (sorted), `at` (every definition as `path:line`, test code marked), `overridden_in`
    (the union over the definitions, case-insensitively sorted), `secret_location` (in any definition). Facts of
    test code are included here, marked: the block lists every name the repository defines.
    """
    by_name: dict[str, list[dict]] = {}
    for f in doc.get("facts") or []:
        if f["kind"] == "connection":
            by_name.setdefault(safe_target(f["name"]), []).append(f)
    rows = []
    for name in sorted(by_name):
        fs = sorted(by_name[name], key=lambda f: (bool(f["detail"].get("test")), f["path"], f.get("line") or 0))
        over = {c for f in fs for c in (f["detail"].get("overridden_in") or [])}
        rows.append({"name": name,
                     "types": sorted({str(f["detail"].get("type") or "untyped") for f in fs}),
                     "at": [_where(f) for f in fs],
                     "overridden_in": sorted(over, key=_CONFIG_ORDER),
                     "secret_location": any(f["detail"].get("secret_location") for f in fs)})
    return rows


def _call_type_key(t: str):
    return (CALL_TYPE_ORDER.index(t), "") if t in CALL_TYPE_ORDER else (len(CALL_TYPE_ORDER), t)


def external_call_rows(doc: dict) -> list[dict]:
    """One row per (type, target) over the non-test `external_call` Facts, in `CALL_TYPE_ORDER` then by target.

    Each row: `type`, `target` (`safe_target`), `config_keys` and `via` (sorted, as recorded), `at` (call sites as
    `path:line`).
    """
    groups: dict[tuple, list[dict]] = {}
    for f in doc.get("facts") or []:
        if f["kind"] == "external_call" and not f["detail"].get("test"):
            groups.setdefault((str(f["detail"].get("type") or "untyped"), safe_target(f["name"])), []).append(f)
    rows = []
    for (type_, target) in sorted(groups, key=lambda k: (_call_type_key(k[0]), k[1])):
        fs = sorted(groups[(type_, target)], key=lambda f: (f["path"], f.get("line") or 0))
        rows.append({"type": type_, "target": target,
                     "config_keys": sorted({safe_target(f["detail"]["config_key"]) for f in fs if f["detail"].get("config_key")}),
                     "via": sorted({safe_target(f["detail"]["via"]) for f in fs if f["detail"].get("via")}),
                     "at": [_cite(f) for f in fs]})
    return rows


def share_rows(doc: dict) -> list[dict]:
    """The `share` Facts (a config key whose value is a UNC path; the value is never recorded): one row per key with
    `at` (where it is defined) and `reads` (the `config_key` Facts that read it, by name). Sorted by key."""
    reads: dict[str, int] = {}
    for f in doc.get("facts") or []:
        if f["kind"] == "config_key" and f["detail"].get("use") == "read" and not f["detail"].get("test"):
            reads[f["name"]] = reads.get(f["name"], 0) + 1
    out: dict[str, dict] = {}
    for f in sorted((f for f in doc.get("facts") or [] if f["kind"] == "share" and not f["detail"].get("test")),
                    key=lambda f: (f["path"], f.get("line") or 0)):
        key = safe_target(f["detail"].get("key") or f["name"])
        out.setdefault(key, {"key": key, "at": [], "reads": reads.get(f["detail"].get("key") or f["name"], 0)})["at"].append(_cite(f))
    return [out[k] for k in sorted(out)]
