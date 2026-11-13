"""The Facts summary: a deterministic map of the Facts file, written from facts.json only."""

from __future__ import annotations

from collections import Counter, defaultdict

from .facts import fact_id

LIST_CAP = 50
FOLDER_CAP = 25
SCHEMA_CAP = 40
PATTERN_STACKS = ("python-flask", "java-spring", "aspnet-core", "node-express", "classic-asp")
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


def finding_candidates(facts: list[dict], stacks: list[dict]) -> list[str]:
    smells = [f for f in facts if f["kind"] == "smell" and not f["detail"].get("test")]
    if not smells:
        if any(s["name"] in PATTERN_STACKS for s in stacks):
            return ["## Finding candidates", "", "Finding candidates: none extracted. This is not proof of absence.", ""]
        return []
    by_pattern: dict[str, list[dict]] = defaultdict(list)
    for f in smells:
        by_pattern[f["detail"].get("pattern", f["name"])].append(f)
    out = ["## Finding candidates", "", "| Pattern | Count | First locations | id |", "|---|---|---|---|"]
    for pattern in sorted(by_pattern):
        group = sorted(by_pattern[pattern], key=lambda f: (f["path"], f["line"] or 0))
        first = group[:3]
        ids = [f["detail"].get("fid") or fact_id("smell", pattern, f["path"], f["line"]) for f in first]
        out.append(f"| `{pattern}` | {len(group)} | " + ", ".join(_cite(f) for f in first)
                   + " | " + ", ".join(f"`{i}`" for i in ids) + " |")
    out.append("")
    return out


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
    out += finding_candidates(facts, stacks)

    return "\n".join(out).rstrip() + "\n"
