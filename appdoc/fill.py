"""Generated blocks: Narrative content written from facts.json, never by hand (`appdoc fill`).

A block is the text between `<!-- appdoc:generated NAME -->` and `<!-- /appdoc:generated NAME -->`.
`fill` rewrites it; the Check fails when it differs from what `fill` would write.
"""

from __future__ import annotations

import json
import os
import re
import sys

from . import notes as notes_mod
from . import template_spec as spec
from . import version
from .textutil import plural, read_text
from .stacks.generic import GENERIC_KINDS

BLOCK_RE = re.compile(r"(<!--\s*appdoc:generated\s+([\w-]+)\s*-->)(.*?)(<!--\s*/appdoc:generated\s+\2\s*-->)", re.S)
TOP_CAP = 25
PRUNED_CAP = 50
CONFIG_CAP = 150
ENTRY_CAP = 100
LIST_CAP = 10  # retired-by-name and duplicate-folder lists in scan coverage


def _cell(s: str) -> str:
    return str(s).replace("|", "\\|")


def _at(f: dict) -> str:
    return f"`{f['path']}:{f['line']}`" if f.get("line") else f"`{f['path']}`"


def _facts(doc: dict, kind: str) -> list[dict]:
    """Non-test Facts of one kind."""
    return [f for f in doc.get("facts", []) if f["kind"] == kind and not f["detail"].get("test")]


def _supported_stacks(doc: dict) -> list[dict]:
    return [s for s in doc.get("stacks", []) if (s.get("detail") or {}).get("supported")]


def _stacks_reporting(doc: dict, cap: str) -> list[str]:
    """Names of the supported Stacks whose stack Fact declares ``cap``, in document order.

    ``cap`` is a Fact kind or a dotted capability. A name without a dot (``entry_point``) matches the
    kind itself or any subtype of it (``entry_point.route``).
    """
    out = []
    for s in _supported_stacks(doc):
        caps = (s.get("detail") or {}).get("capabilities") or []
        if any(c == cap or (c.startswith(cap + ".") and "." not in cap) for c in caps):
            out.append(s["name"])
    return out


def none_phrase(kinds, noun: str | None = None) -> str:
    """Why a block has nothing to list: the generic reader feeds these kinds (no Stack is needed), else no Stack reports them."""
    kinds = tuple(kinds)
    if kinds and all(k.split(".", 1)[0] in GENERIC_KINDS for k in kinds):
        return "read by the generic reader"
    return f"No supported Stack reports {noun or ' and '.join(kinds)}"


def _names(stacks: list[str]) -> str:
    return ", ".join(f"`{n}`" for n in stacks)


COUNTED_ENTRY_TYPES = ("route", "page", "command", "job")
UNCOUNTED_ENTRY_TYPES = frozenset({"handler"})


def entry_point_counts(doc: dict) -> dict:
    """Totals the `entry-points` block states, from the non-test `entry_point` Facts of a facts.json document.

    Keys: `files` (distinct paths holding a type=route Fact), `routes`, `pages`, `commands`, `jobs`
    (Fact counts by detail type). Other types (such as handler) are not counted.
    """
    by_type: dict[str, list[dict]] = {}
    for f in _facts(doc, "entry_point"):
        by_type.setdefault(f["detail"].get("type"), []).append(f)
    return {"files": len({f["path"] for f in by_type.get("route", [])}), "routes": len(by_type.get("route", [])),
            "pages": len(by_type.get("page", [])), "commands": len(by_type.get("command", [])),
            "jobs": len(by_type.get("job", []))}


def _scan_coverage(doc: dict, ctx: dict | None = None) -> str:
    out = ["| Stack | Supported | Files read |", "|---|---|---|"]
    for s in doc.get("stacks", []):
        d = s.get("detail", {})
        out.append(f"| {_cell(s['name'])} | {'yes' if d.get('supported') else 'no (generic only)'} | {d.get('file_count', 0)} |")
    if len(out) == 2:
        out = ["No Stack was detected; only generic Facts were extracted."]
    sc = (doc.get("target") or {}).get("scan")
    if sc and "found" in sc:
        out += ["", f"Files found: {sc['found']} = scanned {sc['scanned']} + pruned {sc['pruned_files']} "
                    f"+ ignored by .appdocignore {sc['ignored']}."]
    files = [f for f in doc.get("facts", []) if f["kind"] == "file"]
    counts: dict[str, int] = {}
    for f in files:
        if "/" in f["path"]:
            top = f["path"].split("/", 1)[0] + "/"
            counts[top] = counts.get(top, 0) + 1
    if counts:
        top = sorted(counts.items(), key=lambda kv: (-kv[1], kv[0]))[:TOP_CAP]
        out += ["", "| Top folder | Files scanned |", "|---|---|"]
        out += [f"| `{p}` | {n} |" for p, n in top]
        if len(counts) > TOP_CAP:
            out.append(f"| {plural(len(counts) - TOP_CAP, 'more folder')} | "
                       f"{sum(n for p, n in counts.items()) - sum(n for _, n in top)} |")
    if sc and sc.get("pruned"):
        out += ["", "| Folder not scanned | Rule | Files |", "|---|---|---|"]
        out += [f"| `{p['path']}` | {_cell(p['rule'])} | {p['files']} |" for p in sc["pruned"][:PRUNED_CAP]]
        if len(sc["pruned"]) > PRUNED_CAP:
            out.append(f"| {plural(len(sc['pruned']) - PRUNED_CAP, 'more folder')} | see facts.json | |")
        own = [p for p in sc["pruned"] if str(p["rule"]).startswith("AppDoc ")]
        if own:
            out += ["", "AppDoc's own files were not scanned: "
                    + ", ".join(f"`{p['path']}` ({p['rule']})" for p in own[:PRUNED_CAP])
                    + ". Add `!name` to .appdocignore to scan one."]
    elif sc:
        out += ["", "No folders were pruned."]
    if sc and sc.get("metadata"):
        out += ["", f"OS and authoring metadata: {plural(sc['metadata'], 'file')} dropped."]
    named = sorted((c for c in (sc or {}).get("retired_candidates", []) if c.get("signal") == "name"),
                   key=lambda c: c["path"])
    if named:
        out += ["", "Folders that look retired by name (not excluded):"]
        out += [f"- `{c['path']}` ({plural(c['files'], 'file')})" for c in named[:LIST_CAP]]
        if len(named) > LIST_CAP:
            out.append(f"- {plural(len(named) - LIST_CAP, 'more folder')}; see facts.json")
    dups = sorted((sc or {}).get("duplicate_folders", []), key=lambda d: (d["a"], d["b"]))
    if dups:
        out += ["", "Folders that duplicate another folder (not excluded; say in 2.1 which copy is live):"]
        out += [f"- `{d['a']}` and `{d['b']}` ({plural(d['files'], 'file')})" for d in dups[:LIST_CAP]]
        if len(dups) > LIST_CAP:
            out.append(f"- {plural(len(dups) - LIST_CAP, 'more pair')}; see facts.json")
    return "\n".join(out)


def _entry_points(doc: dict, ctx: dict | None = None) -> str:
    entries = _facts(doc, "entry_point")
    if not entries:
        can = _stacks_reporting(doc, "entry_point")
        cannot = [s["name"] for s in _supported_stacks(doc) if s["name"] not in can]
        msg = "No entry points were extracted."
        if can:
            msg += f" Stacks that report them: {_names(can)}."
        if cannot:
            msg += f" These supported Stacks report none: {_names(cannot)}; read the source for entry points."
        return msg
    n = entry_point_counts(doc)
    rows: dict[str, dict] = {}
    for f in entries:
        r = rows.setdefault(f["path"], {"kinds": set(), "route": 0, "page": 0, "job": 0, "command": 0})
        t = f["detail"].get("type") or "other"
        r["kinds"].add(t)
        if t in r:
            r[t] += 1
    ordered = sorted(rows.items(), key=lambda kv: (-kv[1]["route"], kv[0]))
    retired = {c["path"].rstrip("/") for c in (doc.get("target") or {}).get("scan", {}).get("retired_candidates", [])
               if c.get("signal") == "name"}
    under_retired = sum(1 for p in rows if any(p.startswith(r + "/") for r in retired)) if retired else 0
    headline = plural(n["files"], "route handler file")
    if under_retired:
        headline += f" ({under_retired} under folders that look retired)"
    out = [f"{headline}; {plural(n['routes'], 'route')}; {plural(n['pages'], 'page')}; "
           f"{plural(n['commands'], 'command')}; {plural(n['jobs'], 'job')}.", "",
           "| Handler file | Kinds | Routes | Pages | Jobs | Commands |", "|---|---|---|---|---|---|"]
    for path, r in ordered[:ENTRY_CAP]:
        out.append(f"| `{path}` | {', '.join(sorted(r['kinds']))} | {r['route']} | {r['page']} | {r['job']} | {r['command']} |")
    if len(ordered) > ENTRY_CAP:
        out += ["", f"Shown {ENTRY_CAP} of {plural(len(ordered), 'handler file')}."]
    return "\n".join(out)


def _scheduled_jobs(doc: dict, ctx: dict | None = None) -> str:
    jobs = [f for f in _facts(doc, "entry_point") if f["detail"].get("type") == "job"]
    if not jobs:
        can = _stacks_reporting(doc, "entry_point.job")
        if can:
            return f"No scheduled or background jobs were extracted. Stacks that report jobs: {_names(can)}."
        detected = [s["name"] for s in _supported_stacks(doc)]
        if detected:
            return f"{none_phrase(('entry_point.job',), 'jobs')} ({_names(detected)}); read the source for job runners."
        return "No scheduled or background jobs were extracted."
    jobs.sort(key=lambda f: (f["path"], f["line"] or 0, f["name"]))
    out = ["| Job | Schedule | Enabled by default | Defined at | Stack |", "|---|---|---|---|---|"]
    for f in jobs:
        d = f["detail"]
        sched = f"`{_cell(str(d['schedule']).replace('`', chr(39)))}`" if d.get("schedule") else "Unknown"
        enabled = "Unknown" if d.get("enabled") is None else ("yes" if d["enabled"] else "no")
        out.append(f"| {_cell(f['name'])} | {sched} | {enabled} | {_at(f)} | {_cell(f.get('stack') or '')} |")
    return "\n".join(out)


def _app_config(doc: dict) -> tuple[list, list]:
    """(application-role config_key Facts, those among them that are commented defaults)."""
    app = [f for f in _facts(doc, "config_key") if f["detail"].get("role", "app") == "app"]
    return app, [f for f in app if f["detail"].get("commented")]


def config_app_count(doc: dict) -> int:
    """Distinct application-role key names that are not commented defaults: the M in the 16.6 "N of M"."""
    app, _ = _app_config(doc)
    return len({f["name"] for f in app if not f["detail"].get("commented")})


def config_shown_count(doc: dict) -> int:
    """The N in the 16.6 "Shown N of M": the application keys the table lists (capped)."""
    return min(config_app_count(doc), CONFIG_CAP)


def _config_reference(doc: dict, ctx: dict | None = None) -> str:
    """Application keys that are not commented defaults: one row per key, its definition when it has one."""
    app, commented = _app_config(doc)
    by_key: dict[str, list[dict]] = {}
    for f in sorted((f for f in app if not f["detail"].get("commented")),
                    key=lambda f: (f["path"], f["line"] or 0)):
        by_key.setdefault(f["name"], []).append(f)
    keys = [next((f for f in fs if f["detail"].get("use") != "read"), fs[0]) for fs in by_key.values()]
    keys.sort(key=lambda f: (not f["detail"].get("secret_location"), f["path"], f["line"] or 0, f["name"]))
    n_cf = len({f["path"] for f in commented})
    skipped = (f"{plural(len(commented), 'commented default')} in {plural(n_cf, 'file')} "
               f"{'is' if len(commented) == 1 else 'are'} not listed (see facts.json).") if commented else ""
    unclassified = [f for f in _facts(doc, "config_key") if f["detail"].get("role") == "unclassified"]
    uncl_files = sorted({f["path"] for f in unclassified})
    both = sorted(set(uncl_files) & {f["path"] for f in app})
    # extract._config_roles (plan 2.6 4.4.3) promotes per file: it turns every `unclassified` key of a file into
    # `app` or none of them, so a file is never both. tests/test_fill proves this over every sample and corpus Target.
    if both:  # stop rather than print a false trailer
        raise RuntimeError("internal error: config file is both application and not classified: " + ", ".join(both))
    uncl_note = (f"{plural(len(unclassified), 'key')} in {plural(len(uncl_files), 'file')} "
                 f"{'was' if len(unclassified) == 1 else 'were'} not classified as application "
                 f"configuration: {', '.join(f'`{p}`' for p in uncl_files[:5])}"
                 + (f" (+{len(uncl_files) - 5} more)" if len(uncl_files) > 5 else "")
                 + " (see facts.json).") if unclassified else ""
    excluded = {r: len({f["name"] for f in _facts(doc, "config_key") if f["detail"].get("role") == r})
                for r in ("env", "ci")}
    excl_note = (f"{plural(excluded['env'], 'env-var key')} and {plural(excluded['ci'], 'CI key')} "
                 "are excluded from the application table "
                 "(see facts.json).") if any(excluded.values()) else ""
    head = ["| Key | Defined at | Secret location |", "|---|---|---|"]
    if not keys:
        return "\n".join(head + ["", " ".join(("No application config keys were extracted.", skipped, uncl_note)).strip()]
                         + (["", excl_note] if excl_note else []))
    out = list(head)
    for f in keys[:CONFIG_CAP]:
        out.append(f"| {_cell(f['name'])} | {_at(f)} | {'yes' if f['detail'].get('secret_location') else 'no'} |")
    out += ["", f"Shown {min(len(keys), CONFIG_CAP)} of {plural(len(keys), 'application key')}"
                + (f"; {skipped}" if skipped else ".")]
    if uncl_note:
        out += ["", uncl_note]
    if excl_note:
        out += ["", excl_note]
    return "\n".join(out)


def _register(ctx: dict | None):
    """The Evidence Register beside facts.json (`ctx["out_dir"]`), or None when there is none."""
    from . import register
    out_dir = (ctx or {}).get("out_dir")
    path = os.path.join(out_dir, register.REGISTER) if out_dir else None
    return register.parse(read_text(path)) if path and os.path.isfile(path) else None


def _appendix_a(doc: dict, ctx: dict | None = None) -> str:
    """Appendix A from the Evidence Register beside facts.json (None when the file is missing)."""
    from . import check, register
    from . import docmodel as dm
    reg = _register(ctx)
    coverage = detail = None
    text = (ctx or {}).get("text")
    if reg is not None and reg.performed and text is not None:
        # the same masking the Check applies, so the appendix never reads itself
        lines = check.document_text(text).splitlines()
        heads = dm.headings(lines)
        ids = check.defined_ids(lines, heads, lambda *a: None)
        workflows = sorted((k for k in heads if k.startswith("7.")), key=lambda k: int(k.split(".")[1]))
        detail = check.coverage_detail(heads, ids, reg, workflows)
        coverage = [(k, len(h), len(a)) for k, h, a in detail]
    plan_path = os.path.join((ctx or {}).get("out_dir") or "", "audit-plan.json")
    plan = json.loads(read_text(plan_path)) if (ctx or {}).get("out_dir") and os.path.isfile(plan_path) else None
    prov = version.provenance()
    return register.appendix_markdown(reg, doc, coverage, root=(ctx or {}).get("target"),
                                      blocks_by={"generator": prov["generator"], "bundle": prov["bundle"]}, plan=plan,
                                      coverage_ids=detail,
                                      list_missing=spec.stamp_version(text or "") >= (2, 7))


def _closed_questions(doc: dict, ctx: dict | None = None) -> str:
    """The closed-questions block under section 14: the questions the audit closed (live Answerable rows) and the
    section that answers each; a register with none, or no register, says so."""
    reg = _register(ctx)
    closed = reg.closed_questions() if reg is not None and reg.performed else []
    if not closed:
        return "No questions were closed by the audit."
    return ("Closed by the audit and answered in the body: "
            + ", ".join(f"Q-{n} ({where})" if where else f"Q-{n}" for n, where in closed) + ".")


RENDERERS = {"scan-coverage": _scan_coverage, "entry-points": _entry_points, "config-reference": _config_reference,
             "scheduled-jobs": _scheduled_jobs, "closed-questions": _closed_questions, "appendix-a": _appendix_a}


def generated_body(name: str, doc: dict, ctx: dict | None = None) -> str | None:
    """A block as the renderer writes it from the Facts, without notes (what a note's `block_sha` hashes)."""
    fn = RENDERERS.get(name)
    return fn(doc, ctx) if fn else None


def render_block(name: str, doc: dict, ctx: dict | None = None) -> str | None:
    """The text `fill` writes for a block: the generated body, then the block's notes from notes.jsonl in
    `ctx["out_dir"]` (one paragraph each). `ctx` is {"out_dir": ..., "text": Narrative}; appendix-a reads the rest."""
    body = generated_body(name, doc, ctx)
    if body is None:
        return None
    mine = notes_mod.load((ctx or {}).get("out_dir")).for_block(name)
    return "\n\n".join([body] + [notes_mod.render(n) for n in mine])


_ENTRY_COUNT = {"routes": "routes", "jobs": "jobs", "pages": "pages", "commands": "commands"}


def count_marker_value(cls: str, doc: dict, ids: dict | None, reg) -> int | None:
    """The number a count marker of this class holds, or None when it cannot be computed (an unknown class, no
    register, no document text). Classes are `template_spec.COUNT_CLASSES`.

    `ids` maps the document's defined IDs (check.defined_ids); `reg` is the Evidence Register. `rows` counts live
    rows (see CONTEXT: Register count) and `superseded` the rows another row supersedes.
    """
    kind = spec.COUNT_CLASSES.get(cls)
    if kind == "id":
        return None if ids is None else sum(1 for k in ids if k.startswith(cls + "-"))
    if kind == "register":
        if reg is None or not reg.performed:
            return None
        return len(reg.live_rows()) if cls == "rows" else len(reg.rows) - len(reg.live_rows())
    if kind == "facts":
        return config_app_count(doc) if cls == "config-keys" else entry_point_counts(doc)[_ENTRY_COUNT[cls]]
    return None


def fill_counts(text: str, doc: dict, ctx: dict | None = None) -> str:
    """Write the current number between every count marker's comments (the marker stays). Idempotent; a marker
    whose number cannot be computed is left as written, and C15 reports an unknown class."""
    from . import check
    from . import docmodel as dm
    if not spec.COUNT_MARKER_RE.search(text):
        return text
    lines = check.document_text(text).splitlines()
    ids = check.defined_ids(lines, dm.headings(lines), lambda *a: None)
    reg = _register(ctx)

    def repl(m):
        n = count_marker_value(m.group(2).strip(), doc, ids, reg)
        return m.group(0) if n is None else f"{m.group(1)}{n}{m.group(4)}"
    return spec.COUNT_MARKER_RE.sub(repl, text)


def mask_blocks(text: str, names, pad: bool = True) -> str:
    """Replace the content of the named blocks with one placeholder line. With `pad` (the default) the line count
    is kept; without it a block is always the same three lines however long its content, so a fingerprint does
    not move when `fill` rewrites a block."""
    def repl(m):
        if m.group(2) not in names:
            return m.group(0)
        k = m.group(3).count("\n") if pad else 2
        return m.group(1) + ("\n" if k else "") + f"generated block {m.group(2)}" + "\n" * max(k - 1, 0) + m.group(4)
    return BLOCK_RE.sub(repl, text)


def blocks(text: str) -> list[tuple[str, str, int]]:
    """(name, current content stripped, 1-based line of the opening marker) for every block."""
    return [(m.group(2), m.group(3).strip(), text.count("\n", 0, m.start()) + 1) for m in BLOCK_RE.finditer(text)]


def fill_text(text: str, doc: dict, ctx: dict | None = None, only=None) -> tuple[str, list[str]]:
    """Fill the generated blocks (and count markers) of `text`; with `only` (block names) fill just those blocks and
    leave the count markers alone."""
    filled = []
    ctx = {**(ctx or {}), "text": text}

    def repl(m):
        if only is not None and m.group(2) not in only:
            return m.group(0)
        body = render_block(m.group(2), doc, ctx)
        if body is None:
            return m.group(0)
        filled.append(m.group(2))
        return f"{m.group(1)}\n{body}\n{m.group(4)}"
    new = BLOCK_RE.sub(repl, text)
    return (new if only is not None else fill_counts(new, doc, ctx)), filled


def fill_facts_blocks(target: str, out_dir: str) -> bool:
    """Fill the non-opaque generated blocks (scan-coverage, config-reference) from the Facts alone, before a seal.
    `doc_sha` and the row seals read those blocks as Narrative, so the fingerprint must be that of the filled
    document: a later `fill` then reproduces it (S6.1). Returns True when the file changed; no Facts or no
    document means nothing to do."""
    md = os.path.join(out_dir, "application-documentation.md")
    facts_path = os.path.join(out_dir, "facts.json")
    if not (os.path.isfile(md) and os.path.isfile(facts_path)):
        return False
    with open(facts_path, encoding="utf-8") as fh:
        doc = json.load(fh)
    with open(md, encoding="utf-8", newline="") as fh:
        text = fh.read()
    only = tuple(n for n in RENDERERS if n not in spec.OPAQUE_BLOCKS)
    new, _ = fill_text(text, doc, {"out_dir": out_dir, "target": target}, only=only)
    if new == text:
        return False
    with open(md, "w", encoding="utf-8", newline="") as fh:
        fh.write(new)
    return True


def run(target: str, out_dir: str) -> int:
    md = os.path.join(out_dir, "application-documentation.md")
    facts_path = os.path.join(out_dir, "facts.json")
    for p in (md, facts_path):
        if not os.path.isfile(p):
            print(f"appdoc fill: {p} not found", file=sys.stderr)
            return 1
    with open(facts_path, encoding="utf-8") as fh:
        doc = json.load(fh)
    with open(md, encoding="utf-8", newline="") as fh:
        text = fh.read()
    new, filled = fill_text(text, doc, {"out_dir": out_dir, "target": target})
    if not filled:
        print("appdoc fill: no appdoc:generated blocks found; copy them from the template", file=sys.stderr)
        return 1
    if new != text:
        with open(md, "w", encoding="utf-8", newline="") as fh:
            fh.write(new)
    version.write_blocks_by(out_dir)
    print("filled: " + ", ".join(filled))
    return 0
