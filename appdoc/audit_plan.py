"""The audit plan: which parts of the Narrative the independent audit must cover (`appdoc audit-plan`).

`docs/appdoc/audit-plan.json` is a pure function of the Narrative (its fingerprint, `check.doc_sha`), the Facts
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
from fractions import Fraction

from . import check, context
from . import docmodel as dm
from .textutil import read_text

PLAN = "audit-plan.json"
SCHEMA = "appdoc-audit-plan/1"
DEFAULT_FRACTION = Fraction(1, 4)
DEFAULT_MINIMUM = 5
SAMPLED = (("4", "F-"), ("6", "UI-"), ("8.1", "C-"), ("8.3", "X-"), ("9", None), ("15", "R-"))
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


def _floor(target: str):
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
    return fraction, minimum, {"fraction": shown, "minimum": minimum}, advisories


def _rows(lines, heads, key, col_name, skip_absent=False, status_value=None):
    """(total rows, first-cell names) of the first table under `key`: rows whose `col_name` cell is a claim."""
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
        value = dm.cell_text(cells[col])
        if status_value is not None and value != status_value:
            continue
        if skip_absent and value.casefold().startswith(ABSENT):
            continue
        names.append(dm.cell_text(cells[0]))
    return len(t.rows), names


def compute(target: str, out_dir: str) -> dict:
    """The audit plan of the Narrative in `out_dir` (a dict; `render` writes it)."""
    raw = read_text(os.path.join(out_dir, check.NARRATIVE))
    lines = check.document_text(raw).splitlines()
    heads = dm.headings(lines)
    ids = check.defined_ids(lines, heads, lambda *a: None)
    sha = check.doc_sha(raw)
    fraction, minimum, floor, advisories = _floor(target)

    def by_prefix(prefix):
        return sorted((i for i in ids if i.startswith(prefix)), key=_num)

    sections = []

    def full(section, total, keys, items=None):
        entry = {"section": section, "mode": "full", "total": total, "ids": keys}
        if items is not None:
            entry["items"] = items
        sections.append(entry)

    v = by_prefix("V-")
    full("10.1", len(v), v)
    workflows = sorted((k for k in heads if k.startswith("7.")), key=lambda k: int(k.split(".")[1]))
    full("7", len(workflows), workflows)
    q = by_prefix("Q-")
    full("14", len(q), q)
    facts_path = os.path.join(out_dir, check.FACTS)
    smells = []
    if os.path.isfile(facts_path):
        smells = [f"smell/{fid}" for fid, _ in check.uncited_smells(
            target, {"__out__": out_dir}, lines, heads, json.loads(read_text(facts_path)))]
    full("candidates", len(smells), smells)
    for key, col, status in (("10.2", "Status", "Present"), ("16.5", "Procedure", None), ("17", "Command", None)):
        total, items = _rows(lines, heads, key, col, skip_absent=status is None, status_value=status)
        full(key, total, [key] if items else [], items)
    for key, prefix in SAMPLED:
        if prefix:
            items = by_prefix(prefix)
            k = sample_size(len(items), fraction, minimum)
            chosen = pick(items, k, sha)
            sections.append({"section": key, "mode": "sampled", "total": len(items), "k": k, "ids": chosen})
        else:   # section 9 rows have no IDs: the symptom names the row, the register row is the section's
            total, items = _rows(lines, heads, key, "Symptom")
            k = sample_size(total, fraction, minimum)
            chosen = pick(items, k, sha)
            sections.append({"section": key, "mode": "sampled", "total": total, "k": k,
                             "ids": [key] if chosen else [], "items": chosen})
    return {"schema": SCHEMA, "doc_sha": sha, "floor": floor, "sections": sections, "advisories": advisories}


def render(plan: dict) -> str:
    return json.dumps(plan, indent=1, sort_keys=True, ensure_ascii=False) + "\n"


def planned_ids(plan: dict) -> list[str]:
    return [i for s in plan["sections"] for i in s["ids"]]


def run(target: str, out_dir: str) -> int:
    import sys
    if not os.path.isfile(os.path.join(out_dir, check.NARRATIVE)):
        print(f"appdoc audit-plan: {os.path.join(out_dir, check.NARRATIVE)} not found; write the Narrative first",
              file=sys.stderr)
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
