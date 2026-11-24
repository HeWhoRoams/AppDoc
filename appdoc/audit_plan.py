"""The audit plan: which parts of the Narrative the independent audit must cover (`appdoc audit-plan`).

`docs/appdoc/audit-plan.json` is a pure function of the Narrative (its fingerprint, `fingerprint.doc_sha`), the Facts
(finding candidates) and the optional `Audit floor:` line of appdoc-context.md. The tool, not the auditor, picks
the sample.

* **Full coverage:** every 10.1 finding, every 7 workflow, every 14 question, every finding candidate no 10.1 row
  cites (it needs a Dismissed row; the cited ones are covered by their finding), the 10.2 section when a control is
  Present, and the 16.5 and 17 sections when a step is not Unknown (or Not applicable).
* **Sampled:** sections 4, 6, 8.1, 8.3, 9 and 15, `k = min(n, max(minimum, ceil(fraction * n)))` items, those
  with the smallest `sha1(doc_sha + id)`. Defaults 25% and 5. An organization may only raise either number.

Each section entry lists `ids`: the keys the Evidence Register must hold a live row for (an ID, a workflow ref,
`smell/<fid>`, or the section ref for a section that has no IDs). `items` names what a section-level row covers.
Generated and opaque blocks are not audited.
"""

from __future__ import annotations

import hashlib
import json
import os
import sys
from fractions import Fraction
from typing import NamedTuple

from . import check, context, fingerprint
from . import template_spec as spec
from . import docmodel as dm
from .textnorm import normalize_newlines
from .textutil import read_text

PLAN = "audit-plan.json"
SCHEMA = "appdoc-audit-plan/1"
DEFAULT_FRACTION = Fraction(1, 4)
DEFAULT_MINIMUM = 5
ABSENT = ("unknown", "not applicable")     # a status cell that is not a claim to audit


def sample_size(n: int, fraction: Fraction = DEFAULT_FRACTION, minimum: int = DEFAULT_MINIMUM) -> int:
    """k = min(n, max(minimum, ceil(fraction * n)))."""
    ceil = -((-fraction.numerator * n) // fraction.denominator)
    return min(n, max(minimum, ceil))


def _num(i: str) -> int:
    return int(i.split("-")[-1])


def pick(items: list[str], k: int, doc_sha: str) -> list[str]:
    """The k items with the smallest sha1(doc_sha + item) (ties by item), in their original order."""
    ranked = sorted(items, key=lambda i: (hashlib.sha1((doc_sha + i).encode("utf-8")).hexdigest(), i))[:k]
    return [i for i in items if i in set(ranked)]


class Floor(NamedTuple):
    """The sampling floor in force: the fraction and minimum used, what the plan records (`display`), and the
    advisories for a context line that tried to lower it."""

    fraction: Fraction
    minimum: int
    display: dict
    advisories: list


def _floor(target: str) -> Floor:
    path = os.path.join(target, check.OWNER_CONTEXT)
    ctx = context.parse(read_text(path) if os.path.isfile(path) else None)
    fraction, minimum, advisories = DEFAULT_FRACTION, DEFAULT_MINIMUM, []
    shown = "0.25"
    f = ctx.audit_floor
    if f:
        if Fraction(f.fraction) > fraction:
            fraction, shown = Fraction(f.fraction), f.fraction
        elif Fraction(f.fraction) < fraction:
            advisories.append(f"{check.OWNER_CONTEXT} line {f.line}: the audit floor fraction {f.fraction} is below "
                              f"the default {DEFAULT_FRACTION.numerator / DEFAULT_FRACTION.denominator:g}; "
                              "the default applies (an organization may only raise the floor)")
        if f.minimum > minimum:
            minimum = f.minimum
        elif f.minimum < minimum:
            advisories.append(f"{check.OWNER_CONTEXT} line {f.line}: the audit floor minimum {f.minimum} is below "
                              f"the default {DEFAULT_MINIMUM}; the default applies "
                              "(an organization may only raise the floor)")
    return Floor(fraction, minimum, {"fraction": shown, "minimum": minimum}, advisories)


def _rows_all(lines, heads, key, col_name):
    """(total rows, first-cell names) of the first table under `key`: every row whose `col_name` cell exists."""
    return _rows(lines, heads, key, col_name, lambda value: True)


def _rows_present(lines, heads, key, col_name, status):
    """Like `_rows_all`, only the rows whose `col_name` cell is exactly `status` (10.2 controls with Status Present)."""
    return _rows(lines, heads, key, col_name, lambda value: value == status)


def _rows_claimed(lines, heads, key, col_name):
    """Like `_rows_all`, without the rows whose `col_name` cell says Unknown or Not applicable (no claim to audit)."""
    return _rows(lines, heads, key, col_name, lambda value: not value.casefold().startswith(ABSENT))


def _rows(lines, heads, key, col_name, keep):
    """(total rows, first-cell names) of the first table under `key`; `keep(cell value)` picks the named rows."""
    h = heads.get(key)
    t = dm.first_table(lines, h) if h else None
    if t is None:
        return 0, []
    header = [dm.cell_text(c).casefold() for c in t.header]
    if col_name.casefold() not in header:
        return len(t.rows), []
    col = header.index(col_name.casefold())
    names = []
    for _, cells in t.rows:
        if len(cells) <= col:
            continue
        if keep(dm.cell_text(cells[col])):
            names.append(dm.cell_text(cells[0]))
    return len(t.rows), names


def compute(target: str, out_dir: str) -> dict:
    """The audit plan of the Narrative in `out_dir` (a dict; `render` writes it)."""
    raw = read_text(os.path.join(out_dir, check.NARRATIVE))
    lines = fingerprint.document_text(raw).splitlines()
    heads = dm.headings(lines)
    ids = check.defined_ids(lines, heads, lambda *a: None)
    sha = fingerprint.doc_sha(raw)
    floor = _floor(target)

    def by_prefix(prefix):
        return sorted((i for i in ids if i.startswith(prefix)), key=_num)

    def by_section(section):
        return by_prefix(spec.id_prefix_of(section))

    sections = []

    def full(section, total, keys, items=None):
        entry = {"section": section, "mode": "full", "total": total, "ids": keys}
        if items is not None:
            entry["items"] = items
        sections.append(entry)

    v = by_section("10.1")
    full("10.1", len(v), v)
    workflows = sorted((k for k in heads if k.startswith("7.")), key=lambda k: int(k.split(".")[1]))
    full("7", len(workflows), workflows)
    q = by_section("14")
    full("14", len(q), q)
    facts_path = os.path.join(out_dir, check.FACTS)
    smells = []
    if os.path.isfile(facts_path):
        smells = [f"smell/{fid}" for fid, _ in check.uncited_smells(
            target, {"__out__": out_dir}, lines, heads, json.loads(read_text(facts_path)))]
    full("candidates", len(smells), smells)
    for key, rows in (("10.2", lambda: _rows_present(lines, heads, "10.2", "Status", spec.CONTROL_STATUS_PRESENT)),
                      ("16.5", lambda: _rows_claimed(lines, heads, "16.5", "Procedure")),
                      ("17", lambda: _rows_claimed(lines, heads, "17", "Command"))):
        total, items = rows()
        full(key, total, [key] if items else [], items)
    for key, ts in spec.TABLES.items():     # sampled sections, in template order
        prefix = ts.id_prefix if ts.sampled else None
        if not prefix and key not in spec.ROW_SAMPLED:
            continue
        if prefix:
            items = by_prefix(prefix)
            k = sample_size(len(items), floor.fraction, floor.minimum)
            chosen = pick(items, k, sha)
            sections.append({"section": key, "mode": "sampled", "total": len(items), "k": k, "ids": chosen})
        else:   # section 9 rows have no IDs: the symptom names the row, the register row is the section's
            total, items = _rows_all(lines, heads, key, "Symptom")
            k = sample_size(total, floor.fraction, floor.minimum)
            chosen = pick(items, k, sha)
            sections.append({"section": key, "mode": "sampled", "total": total, "k": k,
                             "ids": [key] if chosen else [], "items": chosen})
    return {"schema": SCHEMA, "doc_sha": sha, "floor": floor.display, "sections": sections,
            "advisories": floor.advisories}


def render(plan: dict) -> str:
    return json.dumps(plan, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


# The register ref of an ID class (a row's `ref` is `<section>/<id>`; the classes are template_spec.ID_CLASSES);
# other keys are their own ref.


def ref_for(key: str) -> str:
    """The register `ref` that covers a planned key."""
    for prefix, cls in spec.ID_CLASSES.items():
        if key.startswith(prefix):
            return f"{cls.section}/{key}"
    return key


def _in_section(key: str, section: str) -> bool:
    if section == "candidates":
        return key.startswith("smell/")
    if section == "7":
        return key.startswith("7.")
    prefix = spec.id_prefix_of(section)
    return key.startswith(prefix) if prefix else key == section


def progress(plan: dict, live_keys: set) -> list[tuple[str, int, int, int]]:
    """(section, planned, audited, extra) per plan section: the keys planned, those with a live row, and live rows
    in the section the plan did not ask for."""
    out = []
    for s in plan["sections"]:
        done = sum(1 for i in s["ids"] if i in live_keys)
        extra = sum(1 for k in live_keys if _in_section(k, s["section"]) and k not in s["ids"])
        out.append((s["section"], len(s["ids"]), done, extra))
    return out


def planned_ids(plan: dict) -> list[str]:
    return [i for s in plan["sections"] for i in s["ids"]]


def _disk_plan(out_dir: str):
    """(text, plan dict or None) of the plan on disk; (None, None) when the file is missing."""
    path = os.path.join(out_dir, PLAN)
    if not os.path.isfile(path):
        return None, None
    text = normalize_newlines(read_text(path))
    try:
        plan = json.loads(text)
    except ValueError:
        return text, None
    return text, plan if isinstance(plan, dict) else None


def _require_narrative(out_dir: str) -> bool:
    """True when the Narrative exists; otherwise say so on stderr (the caller exits 1)."""
    path = os.path.join(out_dir, check.NARRATIVE)
    if os.path.isfile(path):
        return True
    print(f"appdoc audit-plan: {path} not found; write the Narrative first", file=sys.stderr)
    return False


def check_plan(target: str, out_dir: str) -> int:
    """`audit-plan --check`: compare the plan on disk with a fresh computation, writing nothing.
    Exit 0 when equal (the text C19 compares), 2 when stale or missing, 1 when there is no Narrative."""
    if not _require_narrative(out_dir):
        return 1
    fresh = compute(target, out_dir)
    text, disk = _disk_plan(out_dir)
    if text == render(fresh):
        print(f"{PLAN} is current: {len(planned_ids(fresh))} register keys to audit")
        return 0
    try:
        disk_ids = planned_ids(disk) if disk else []
    except (KeyError, TypeError):
        disk, disk_ids = None, []
    state = "missing" if text is None else ("unreadable" if disk is None else "stale")
    print(f"{PLAN} is {state}: it is not what `appdoc audit-plan` computes now (nothing was written)")
    print(f"on disk: {', '.join(disk_ids) if disk_ids else '(none)'}")
    print(f"fresh:   {', '.join(planned_ids(fresh)) if planned_ids(fresh) else '(none)'}")
    if disk and disk.get("doc_sha") != fresh["doc_sha"]:
        print(f"doc_sha: on disk {disk.get('doc_sha')}, fresh {fresh['doc_sha']} (the sample is seeded by it)")
    if disk_ids == planned_ids(fresh):
        print("the planned ids are the same; the fingerprint, the sample's seed or a count differs")
    return 2


def run(target: str, out_dir: str) -> int:
    if not _require_narrative(out_dir):
        return 1
    plan = compute(target, out_dir)
    with open(os.path.join(out_dir, PLAN), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(render(plan))
    print(f"wrote {PLAN}: {len(planned_ids(plan))} register keys to audit "
          f"({sum(1 for s in plan['sections'] if s['mode'] == 'full')} full sections, "
          f"{sum(1 for s in plan['sections'] if s['mode'] == 'sampled')} sampled)")
    for a in plan["advisories"]:
        print(f"advisory: {a}")
    return 0
