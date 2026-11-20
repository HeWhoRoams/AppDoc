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

# Canonical display order: connection types (database + the 6 catalog additions) then the
# per-call outbound external_call types. Anything not listed sorts after these, alphabetically.
TYPE_ORDER = (
    "database", "cache", "queue", "object_storage", "grpc", "ldap", "search",
    "http", "email", "process", "file",
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
    "process": "Process",
    "file": "File",
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
        head += f", … +{len(names) - _DRIVER_CAP} more"
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
            "Facts in `facts.json` — a pure function of the Facts, byte-identical across runs. "
            "A group with no rows is not proof of absence; the extractors only recognise the "
            "patterns of the detected Stacks.", ""]

    # --- integration map ---------------------------------------------------
    out += ["### Integration map", ""]
    types = _sorted_types({f["detail"].get("type", "untyped") for f in conns})
    if types:
        out.append("app → { " + ", ".join(types) + " }")
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
            out.append(f"- **{_label(type_)}** — {len(of)} × {', '.join(f'`{n}`' for n in names[:_DRIVER_CAP])}"
                       + (f" (+{len(names) - _DRIVER_CAP} more)" if len(names) > _DRIVER_CAP else ""))
            locs = sorted({_cite(f) for f in of})
            for loc in locs[:_PROVEN_CAP]:
                out.append(f"  - `{loc}`")
            if len(locs) > _PROVEN_CAP:
                out.append(f"  - … {len(locs) - _PROVEN_CAP} more in `facts.json`")
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
                head += f", … +{len(names) - _DEP_EXAMPLE_CAP} more"
            out.append(f"| {mgr} | {len(ds)} | {head} |")
        out.append("")

    return "\n".join(out).rstrip() + "\n"
