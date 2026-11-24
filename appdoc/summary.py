"""The Facts summary: a deterministic map of the Facts file, written from facts.json only."""

from __future__ import annotations

from collections import Counter, defaultdict

from .facts import fact_id
from .integration import render_integration_view
from .smells import OBLIGING, PATTERNS_BY_STACK

LIST_CAP = 50
FOLDER_CAP = 25
SCHEMA_CAP = 40
PATTERN_STACKS = ("python-flask", "java-spring", "aspnet", "aspnet-core", "node-express", "classic-asp")
LISTED_KINDS = (
    ("entry_point", "Entry points"),
    ("data_access", "Data access"),
    ("connection", "Connections (locations only)"),
    ("config_key", "Config keys flagged as secret locations"),
    ("external_call", "External calls"),
    ("auth_check", "Auth checks"),
)


def _cite(f: dict) -> str:
    return f"`{f['path']}:{f['line']}`" if f.get("line") else f"`{f['path']}`"


def _folder(path: str) -> str:
    return path.split("/", 1)[0] if "/" in path else "(root)"


def scan_coverage(target: dict) -> list[str]:
    """Reconciliation of files found vs scanned, and the folders pruned as build output or caches."""
    sc = target.get("scan")
    if not sc:
        return []
    out = ["## Scan coverage", "",
           f"Files found: {sc['found']} = scanned {sc['scanned']} + pruned {sc['pruned_files']} "
           f"+ ignored by `.appdocignore` {sc['ignored']}.", ""]
    if sc["pruned"]:
        out += ["| Folder not scanned | Rule | Files |", "|---|---|---|"]
        out += [f"| `{p['path']}` | {p['rule']} | {p['files']} |" for p in sc["pruned"][:LIST_CAP]]
        if len(sc["pruned"]) > LIST_CAP:
            out.append(f"| … {len(sc['pruned']) - LIST_CAP} more in `facts.json` | | |")
        out += ["", "Add `!name` to `.appdocignore` to scan a pruned folder."]
    else:
        out.append("No folders were pruned.")
    out.append("")
    return out


def config_files(facts: list[dict]) -> list[str]:
    """Application config sources first; build, CI and orchestration sources as one count line each."""
    keys = [f for f in facts if f["kind"] == "config_key" and not f["detail"].get("test")]
    if not keys:
        return []
    by_file: dict[str, Counter] = defaultdict(Counter)
    for f in keys:
        by_file[f["path"]][f["detail"].get("role", "app")] += 1
    app = sorted(((p, c["app"]) for p, c in by_file.items() if c["app"]), key=lambda kv: (-kv[1], kv[0]))
    out = ["## Config files", ""]
    if app:
        out += ["| Application config file | Keys |", "|---|---|"]
        out += [f"| `{p}` | {n} |" for p, n in app[:FOLDER_CAP]]
        if len(app) > FOLDER_CAP:
            out.append(f"| … {len(app) - FOLDER_CAP} more files | |")
    else:
        out.append("No application config keys extracted.")
    out.append("")
    for role in ("build", "ci", "orchestration"):
        files = [p for p, c in by_file.items() if c[role]]
        if files:
            n = sum(by_file[p][role] for p in files)
            out.append(f"- {role}: {len(files)} file{'s' if len(files) != 1 else ''}, {n} keys (not application settings)")
    out.append("")
    return out


def _shown(shown: int, total: int) -> list[str]:
    return [f"{shown} of {total} shown; the rest are in `facts.json`.", ""] if shown < total else []


def schema_objects(facts: list[dict]) -> list[str]:
    items = [f for f in facts if f["kind"] == "schema_object" and not f["detail"].get("test")]
    out = ["## Schema objects", ""]
    if not items:
        return out + ["None extracted. This is not proof of absence.", ""]
    counts = Counter((f["detail"].get("type", "?"), f["detail"].get("dialect") or "unspecified") for f in items)
    out += ["| Type | Dialect | Count |", "|---|---|---|"]
    out += [f"| {t} | {d} | {n} |" for (t, d), n in sorted(counts.items())]
    out.append("")
    tables = sorted((f for f in items if f["detail"].get("type") == "table"),
                    key=lambda f: (f["name"], f["detail"].get("dialect") or "", f["path"]))
    if tables:
        out += ["| Table | Dialect | Columns | Defined at |", "|---|---|---|---|"]
        for f in tables[:SCHEMA_CAP]:
            cols = f["detail"].get("column_count", len(f["detail"].get("columns", [])))
            out.append(f"| `{f['name']}` | {f['detail'].get('dialect') or 'unspecified'} | {cols} | {_cite(f)} |")
        out += [""] + _shown(min(len(tables), SCHEMA_CAP), len(tables))
    indexes = sorted((f for f in items if f["detail"].get("type") == "index"),
                     key=lambda f: (f["detail"].get("table", ""), f["name"], f["path"]))
    if indexes:
        out += ["| Index | Table | Unique | Expression | Defined at |", "|---|---|---|---|---|"]
        for f in indexes[:SCHEMA_CAP]:
            d = f["detail"]
            expr = d.get("expression", "").replace("|", "\\|")
            out.append(f"| `{f['name']}` | `{d.get('table', '')}` | {'yes' if d.get('unique') else 'no'} | `{expr}` | {_cite(f)} |")
        out += [""] + _shown(min(len(indexes), SCHEMA_CAP), len(indexes))
    return out


def ownership_files(facts: list[dict]) -> list[str]:
    items = sorted((f for f in facts if f["kind"] == "owner_file" and not f["detail"].get("test")),
                   key=lambda f: f["path"])
    out = ["## Ownership files", ""]
    if not items:
        return out + ["None extracted. This is not proof of absence.", ""]
    out += ["| File | Kind | Entries |", "|---|---|---|"]
    out += [f"| `{f['path']}` | {f['detail'].get('kind', '')} | {f['detail'].get('entries', 0)} |" for f in items[:LIST_CAP]]
    return out + [""] + _shown(min(len(items), LIST_CAP), len(items))


def ui_pages(facts: list[dict]) -> list[str]:
    items = sorted((f for f in facts if f["kind"] == "ui_page" and not f["detail"].get("test")),
                   key=lambda f: (f["path"], f["line"] or 0, f["name"]))
    out = ["## UI pages", ""]
    if not items:
        return out + ["None extracted. This is not proof of absence.", ""]
    for f in items[:LIST_CAP]:
        extra = ", ".join(str(f["detail"][k]) for k in ("x_class", "route") if f["detail"].get(k))
        out.append(f"- {_cite(f)}" + (f" — {extra}" if extra else ""))
    return out + [""] + _shown(min(len(items), LIST_CAP), len(items))


NOT_OBLIGING = "candidate (not an obligation)"


def finding_candidates(facts: list[dict], stacks: list[dict]) -> list[str]:
    smells = [f for f in facts if f["kind"] == "smell" and not f["detail"].get("test")]
    ran = sorted({p for s in stacks for p in PATTERNS_BY_STACK.get(s["name"], ())})
    notes = _year_notice(facts) if any(s["name"] in PATTERNS_BY_STACK for s in stacks) else []
    if not smells:
        if any(s["name"] in PATTERN_STACKS for s in stacks):
            return ["## Finding candidates", "", "Finding candidates: none extracted. This is not proof of absence.", ""] + (
                [f"Patterns that ran with no hit: {', '.join(f'`{p}`' for p in ran)}.", ""] if ran else []) + notes
        return []
    by_pattern: dict[str, list[dict]] = defaultdict(list)
    for f in smells:
        by_pattern[f["detail"].get("pattern", f["name"])].append(f)
    out = ["## Finding candidates", "", "| Pattern | Count | First locations | id |", "|---|---|---|---|"]
    for pattern in sorted(by_pattern):
        group = sorted(by_pattern[pattern], key=lambda f: (f["path"], f["line"] or 0))
        first = group[:3]
        ids = [f["detail"].get("fid") or fact_id("smell", pattern, f["path"], f["line"]) for f in first]
        label = "" if pattern in OBLIGING else f" {NOT_OBLIGING}"
        out.append(f"| `{pattern}`{label} | {len(group)} | " + ", ".join(_cite(f) for f in first)
                   + " | " + ", ".join(f"`{i}`" for i in ids) + " |")
    out.append("")
    quiet = [p for p in ran if p not in by_pattern]
    if quiet:
        out += [f"Patterns that ran with no hit: {', '.join(f'`{p}`' for p in quiet)}.", ""]
    return out + notes


def _year_notice(facts: list[dict]) -> list[str]:
    """``config-year-horizon`` needs ``Reference year:`` in ``appdoc-context.md`` (no clock, P3); say so when it matters."""
    declared = any(f["kind"] == "context_directive" and f["detail"].get("directive") == "reference_year" for f in facts)
    if declared or not any(f["kind"] == "config_key" and f["detail"].get("year") for f in facts):
        return []
    return ["`config-year-horizon` is off: a configuration key holds a year and no `Reference year:` is declared in "
            "`appdoc-context.md`.", ""]


def unclassified_attributes(facts: list[dict], stacks: list[dict]) -> list[str]:
    """External attributes used on three or more controllers or actions (guard or not): the owner decides which are guards."""
    cands = sorted((f for f in facts if f["kind"] == "guard_candidate" and not f["detail"].get("test")),
                   key=lambda f: (-f["detail"].get("uses", 0), f["name"], f["path"]))
    if not cands:
        if any(s["name"] in ("aspnet", "aspnet-core") for s in stacks):
            return ["## Unclassified controller attributes", "", "None extracted. This is not proof of absence.", ""]
        return []
    out = ["## Unclassified controller attributes", "",
           "Attributes that are not defined in the Target and not declared, used at least three times on controllers or "
           "actions. Each may be an authorization guard or an unrelated one (a layout attribute): ask the owner, then "
           "declare guards with `Auth attributes:` in `appdoc-context.md`.", "",
           "| Attribute | Uses | Argument counts | First use |", "|---|---|---|---|"]
    for f in cands[:LIST_CAP]:
        d = f["detail"]
        out.append(f"| `{f['name']}` | {d.get('uses', 0)} | {', '.join(str(a) for a in d.get('arity_set', []))} | {_cite(f)} |")
    return out + [""] + _shown(min(len(cands), LIST_CAP), len(cands))


def _dirname(path: str) -> str:
    return path.rsplit("/", 1)[0] if "/" in path else ""


def _inside(path: str, folder: str) -> bool:
    return folder == "" or path == folder or path.startswith(folder + "/")


def unmatched_rules(facts: list[dict]) -> list[dict]:
    """Access rules whose ``scope_path`` names no route prefix and no folder or file of the Target (stale rules).

    ``facts`` are the Facts file's dicts. Only base rules are listed, once each, as ``{path, line, scope_path, effect}``
    sorted by path and line. A rule for the application root (empty scope) is never unmatched. The scope is relative to
    the web application root (the outermost folder holding a ``Web.config``); matching is case-insensitive on whole
    path segments, so ``Admin`` does not match the folder ``AdminTools``. Summary only: this is not a Fact kind.
    """
    files = [f["path"] for f in facts if f["kind"] == "file"]
    web_dirs = sorted({_dirname(p) for p in files if p.rsplit("/", 1)[-1].lower() == "web.config"})
    roots = [d for d in web_dirs if not any(o != d and _inside(d, o) for o in web_dirs)]
    routes = [tuple(s for s in str(f["name"]).lower().split("/") if s)
              for f in facts if f["kind"] == "entry_point" and str(f["name"]).startswith("/")]
    out = []
    for f in facts:
        d = f.get("detail", {})
        if f["kind"] != "access_rule" or d.get("config") != "base" or not d.get("scope_path"):
            continue
        segs = tuple(s for s in d["scope_path"].lower().split("/") if s)
        root = max((r for r in roots if _inside(f["path"], r)), key=len, default="")
        wanted = ((root + "/" if root else "") + d["scope_path"]).lower().rstrip("/")
        if any(p.lower() == wanted or p.lower().startswith(wanted + "/") for p in files) \
                or any(r[:len(segs)] == segs for r in routes):
            continue
        out.append({"path": f["path"], "line": f.get("line"), "scope_path": d["scope_path"], "effect": d.get("effect")})
    return sorted(out, key=lambda x: (x["path"], x["line"] or 0, x["effect"] or ""))


def access_rules_matching_nothing(facts: list[dict]) -> list[str]:
    """Summary section for ``unmatched_rules``; nothing when the Target has no access rules."""
    if not any(f["kind"] == "access_rule" for f in facts):
        return []
    rows = unmatched_rules(facts)
    if not rows:
        return ["## Access rules matching nothing", "", "None: every rule path names a route prefix, a folder or a file.", ""]
    out = ["## Access rules matching nothing", "",
           "Rules whose path matches no route prefix and no folder or file in the Target: stale rules, or routes the "
           "extractors do not see. Confirm with the owner before calling the path protected or open.", "",
           "| Rule | Scope | Location |", "|---|---|---|"]
    for r in rows[:LIST_CAP]:
        out.append(f"| {r['effect']} | `{r['scope_path']}` | {_cite(r)} |")
    return out + [""] + _shown(min(len(rows), LIST_CAP), len(rows))


def render_summary(doc: dict) -> str:
    facts = doc["facts"]
    stacks = doc["stacks"]
    out = ["# Facts summary", ""]
    t = doc["target"]
    out += [f"- Target: `{t['name']}`", f"- Commit: `{t['commit'] or 'none'}`",
            f"- Git history: {t.get('history', 'none')}", f"- Schema: `{doc['schema']}`", "",
            "> Facts show what the extractors found. An empty list is not proof that something is absent: "
            "the extractors only recognise the patterns of the Stacks below, so read the source before "
            "writing \"none\". Facts from test code are marked `test` in `facts.json` and left out of the lists.", ""]

    view = render_integration_view(doc)
    if view:
        out.extend(view.split("\n"))
        out.append("")

    out += ["## Stacks", ""]
    if stacks:
        out += ["| Stack | Supported | Files read | Marker files |", "|---|---|---|---|"]
        for s in stacks:
            d = s["detail"]
            out.append(f"| {s['name']} | {'yes' if d.get('supported') else 'no (generic only)'} | {d.get('file_count', 0)} | "
                       + ", ".join(f"`{m}`" for m in d.get("marker_files", [])[:5]) + " |")
    else:
        out.append("No Stack detected; only generic facts are available.")
    out.append("")

    by_kind = Counter(f["kind"] for f in facts)
    by_stack = Counter(f["stack"] for f in facts)
    out += ["## Counts", "", "| Kind | Count |", "|---|---|"]
    out += [f"| {k} | {by_kind[k]} |" for k in sorted(by_kind)]
    out += ["", "| Stack | Facts |", "|---|---|"]
    out += [f"| {k} | {by_stack[k]} |" for k in sorted(by_stack)]
    out.append("")

    out += scan_coverage(t)
    out += config_files(facts)

    folders: dict[str, Counter] = defaultdict(Counter)
    file_counts: Counter = Counter()
    for f in facts:
        folders[_folder(f["path"])][f["kind"]] += 1
        if f["kind"] == "file":
            file_counts[_folder(f["path"])] += 1
    top = sorted(file_counts.items(), key=lambda kv: (-kv[1], kv[0]))[:FOLDER_CAP]
    out += ["## Top folders by file count", "", "| Folder | Files | Entry points | Data access | External calls |", "|---|---|---|---|---|"]
    for name, n in top:
        c = folders[name]
        out.append(f"| `{name}` | {n} | {c['entry_point']} | {c['data_access']} | {c['external_call']} |")
    out.append("")

    big = sorted((f for f in facts if f["kind"] == "file" and f["detail"].get("lines")),
                 key=lambda f: (-f["detail"]["lines"], f["path"]))[:FOLDER_CAP]
    out += ["## Largest source files", "", "| File | Lines |", "|---|---|"]
    out += [f"| `{f['path']}` | {f['detail']['lines']} |" for f in big]
    out.append("")

    for kind, title in LISTED_KINDS:
        all_items = [f for f in facts if f["kind"] == kind]
        items = [f for f in all_items if not f["detail"].get("test")]
        tests = len(all_items) - len(items)
        if kind == "config_key":
            items = [f for f in items if f["detail"].get("secret_location")]
        out += [f"## {title}", ""]
        if not items:
            out += [f"None extracted ({tests} in test code, not listed)." if tests else
                    "None extracted. This is not proof of absence.", ""]
            continue
        for f in items[:LIST_CAP]:
            out.append(f"- `{f['name']}` — {_cite(f)}")
        if len(items) > LIST_CAP:
            out.append(f"- … {len(items) - LIST_CAP} more in `facts.json`")
        if tests:
            out.append(f"- ({tests} more in test code, not listed)")
        out.append("")

    out += schema_objects(facts)
    out += ownership_files(facts)
    out += ui_pages(facts)
    out += unclassified_attributes(facts, stacks)
    out += access_rules_matching_nothing(facts)
    out += finding_candidates(facts, stacks)

    return "\n".join(out).rstrip() + "\n"
