"""The Facts summary: a deterministic map of the Facts file, written from facts.json only."""

from __future__ import annotations

from collections import Counter, defaultdict

LIST_CAP = 50
FOLDER_CAP = 25
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


def render_summary(doc: dict) -> str:
    facts = doc["facts"]
    stacks = doc["stacks"]
    out = ["# Facts summary", ""]
    t = doc["target"]
    out += [f"- Target: `{t['name']}`", f"- Commit: `{t['commit'] or 'none'}`", f"- Schema: `{doc['schema']}`", ""]

    out += ["## Stacks", ""]
    if stacks:
        out += ["| Stack | Supported | Files | Marker files |", "|---|---|---|---|"]
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
        items = [f for f in facts if f["kind"] == kind]
        if kind == "config_key":
            items = [f for f in items if f["detail"].get("secret_location")]
        out += [f"## {title}", ""]
        if not items:
            out += ["None found.", ""]
            continue
        for f in items[:LIST_CAP]:
            out.append(f"- `{f['name']}` — {_cite(f)}")
        if len(items) > LIST_CAP:
            out.append(f"- … {len(items) - LIST_CAP} more in `facts.json`")
        out.append("")

    return "\n".join(out).rstrip() + "\n"
