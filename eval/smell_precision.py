"""Precision of finding-candidate (smell) patterns on hand-labelled sets, and the C12 obligation gate (plan 2.8 W11 part C).

    python eval/smell_precision.py <target> [<target> ...]   list every hit of both passes on a Target
    python eval/smell_precision.py --labels                  per pattern: class, pass, hits, precision, obligation status
    python eval/smell_precision.py --gate                    the same table; exit 1 when an obliging pattern breaks the rule

Both passes run: ``smells.extract`` (one file's text) and ``smells.from_facts`` (Facts only), through the same
``extract.extract`` the tool uses, so the Facts-level pass sees the Facts it sees in a real run.

A label set is ``eval/labels/<pattern>.json``::

    {"pattern": "...", "target": "targets/<name>", "labelled_by": "author", "second_labeller": null,
     "note": "...", "labels": [{"path": "...", "line": 12, "text": "<the source line, trimmed>", "label": "tp|fp",
                                "reason": "..."}]}

``tp`` means a hit at that site is right, ``fp`` that a hit there would be a false positive (a shape the spike found).
A hit with a ``controllers`` table (``post-without-antiforgery``) counts once per listed controller, at the controller's
line. Precision is hits on ``tp`` sites over hits on ``tp`` and ``fp`` sites. A hit on no labelled site is reported as
``unlabelled`` and counts for nothing.

The rule: a deterministic read of a declared value obliges from the release that ships it; a ``GRANDFATHERED`` heuristic
of 2.7 or earlier keeps its obligation unmeasured; every other pattern obliges only when its label set has at least
``MIN_POSITIVES`` positives and ``MIN_NEGATIVES`` negatives, a ``second_labeller`` (the author's labels alone do not count)
and a precision of at least ``PRECISION_BAR``.
"""

from __future__ import annotations

import collections
import json
import os
import re
import sys
import tempfile
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, os.path.join(HERE, ".."))

from appdoc import extract as extract_mod, smells  # noqa: E402

LABELS_DIR = os.path.join(HERE, "labels")
PRECISION_BAR = 0.8
MIN_POSITIVES = 5
MIN_NEGATIVES = 3
RULE = f"a heuristic obliges only at precision >= {PRECISION_BAR} on its labelled set"
_ROW = re.compile(r"^(.*):(\d+) \d+ of \d+$")


def smell_facts(root: str) -> list:
    """Every smell Fact of a Target as a dict, from one full extraction (the per-file and the Facts-level pass)."""
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract_mod.extract(root, out, workers=0, use_cache=False, no_ownership=True)
    return [f for f in json.loads(text)["facts"] if f["kind"] == "smell"]


def sites(fact: dict) -> list:
    """The ``(path, line)`` sites a hit stands for: one, or one per controller in a ``controllers`` table."""
    rows = fact["detail"].get("controllers")
    if rows:
        out = []
        for row in rows:
            m = _ROW.match(row)
            if m:
                out.append((m.group(1), int(m.group(2))))
        return out
    return [(fact["path"], fact["line"])]


def load_labels(labels_dir: str = LABELS_DIR) -> dict:
    out = {}
    if os.path.isdir(labels_dir):
        for name in sorted(os.listdir(labels_dir)):
            if name.endswith(".json"):
                with open(os.path.join(labels_dir, name), encoding="utf-8") as fh:
                    doc = json.load(fh)
                out[doc.get("pattern") or name[:-5]] = doc
    return out


def label_problems(doc: dict, labels_dir: str = LABELS_DIR) -> list:
    """Shape of one label set: counts, the author note and each label pointing at the line it describes."""
    pattern = doc.get("pattern", "?")
    bad = []
    labels = doc.get("labels", [])
    pos = sum(1 for x in labels if x.get("label") == "tp")
    neg = sum(1 for x in labels if x.get("label") == "fp")
    if pos < MIN_POSITIVES:
        bad.append(f"{pattern}: {pos} positives, at least {MIN_POSITIVES} needed")
    if neg < MIN_NEGATIVES:
        bad.append(f"{pattern}: {neg} negatives, at least {MIN_NEGATIVES} needed")
    if "labelled by the author" not in doc.get("note", "").lower() and "by the author" not in doc.get("note", "").lower():
        bad.append(f"{pattern}: the note must say the labels are by the author")
    if "second_labeller" not in doc:
        bad.append(f"{pattern}: second_labeller is missing (use null until a second person has re-labelled)")
    root = os.path.join(labels_dir, doc.get("target", ""))
    for x in labels:
        if x.get("label") not in ("tp", "fp") or not x.get("reason"):
            bad.append(f"{pattern}: {x.get('path')}:{x.get('line')} needs a label (tp|fp) and a reason")
            continue
        try:
            with open(os.path.join(root, x["path"]), encoding="utf-8") as fh:
                lines = fh.read().split("\n")
            ok = 1 <= x["line"] <= len(lines) and lines[x["line"] - 1].strip() == x.get("text")
        except OSError:
            ok = False
        if not ok:
            bad.append(f"{pattern}: {x.get('path')}:{x.get('line')} does not hold the labelled text")
    return bad


def measure(doc: dict, facts: list) -> dict:
    """One label set against the smell Facts of its Target."""
    pattern = doc["pattern"]
    hit_sites = {s for f in facts if f["detail"].get("pattern") == pattern for s in sites(f)}
    labelled = {(x["path"], x["line"]): x["label"] for x in doc.get("labels", [])}
    tp = sum(1 for s, lab in labelled.items() if lab == "tp" and s in hit_sites)
    fp = sum(1 for s, lab in labelled.items() if lab == "fp" and s in hit_sites)
    return {"hits": len(hit_sites), "tp": tp, "fp": fp,
            "missed": sum(1 for lab in labelled.values() if lab == "tp") - tp,
            "unlabelled": len(hit_sites - set(labelled)),
            "positives": sum(1 for lab in labelled.values() if lab == "tp"),
            "negatives": sum(1 for lab in labelled.values() if lab == "fp"),
            "precision": (tp / (tp + fp)) if tp + fp else None,
            "second_labeller": doc.get("second_labeller")}


def measure_all(labels_dir: str = LABELS_DIR) -> dict:
    """``{pattern: measure(...)}`` for every label set; each Target is extracted once."""
    by_target: dict = {}
    out = {}
    for pattern, doc in load_labels(labels_dir).items():
        target = os.path.normpath(os.path.join(labels_dir, doc["target"]))
        if target not in by_target:
            by_target[target] = smell_facts(target)
        out[pattern] = measure(doc, by_target[target])
    return out


def status(pattern: str, row: dict | None, obliging=None) -> str:
    """The obligation status of a pattern: whether it obliges C12, and why."""
    obliging = smells.OBLIGING if obliging is None else obliging
    cls = smells.pattern_class(pattern)
    if pattern in obliging:
        if cls == "deterministic":
            return "obliges (deterministic)"
        if pattern in smells.GRANDFATHERED:
            return "obliges (grandfathered, unmeasured)"
        why = gate_problem(pattern, row)
        return "obliges (measured)" if why is None else f"VIOLATION: {why}"
    if cls == "summary-only":
        return "summary-only"
    why = gate_problem(pattern, row)
    return "summary-only (" + (why or "meets the bar; not yet in smells.OBLIGING") + ")"


def gate_problem(pattern: str, row: dict | None):
    """Why a heuristic may not oblige; None when it meets the whole rule."""
    if row is None:
        return "no labelled set"
    if row["positives"] < MIN_POSITIVES or row["negatives"] < MIN_NEGATIVES:
        return f"labelled set too small ({row['positives']} positives, {row['negatives']} negatives)"
    if not row.get("second_labeller"):
        return "labels not yet re-labelled by a second person"
    if row["precision"] is None or row["precision"] < PRECISION_BAR:
        p = "no hit on a labelled site" if row["precision"] is None else f"precision {row['precision']:.2f}"
        return f"{p}, below {PRECISION_BAR}"
    return None


def problems(rows: dict, obliging=None) -> list:
    """Rule violations: an obliging heuristic (not deterministic, not grandfathered) that fails ``gate_problem``."""
    obliging = smells.OBLIGING if obliging is None else obliging
    out = []
    for p in sorted(obliging):
        if smells.pattern_class(p) == "deterministic" or p in smells.GRANDFATHERED:
            continue
        why = gate_problem(p, rows.get(p))
        if why:
            out.append(f"{p} obliges but {why}")
    return out


def table(rows: dict, obliging=None) -> list:
    """The release table: pattern, class, pass, hits on its labelled set, precision, obligation status."""
    names = sorted(smells.DETERMINISTIC | smells.HEURISTIC | smells.SUMMARY_ONLY)
    out = ["| pattern | class | pass | hits (labelled set) | precision | obligation |", "|---|---|---|---|---|---|"]
    for p in names:
        row = rows.get(p)
        hits = str(row["hits"]) if row else "-"
        prec = "-" if not row or row["precision"] is None else f"{row['precision']:.2f}"
        out.append(f"| {p} | {smells.pattern_class(p)} | {'from_facts' if p in smells.FACTS_PATTERNS else 'extract'} "
                   f"| {hits} | {prec} | {status(p, row, obliging)} |")
    return out


def report(labels_dir: str = LABELS_DIR) -> tuple:
    """``(lines, problems)`` for the release: the table, the rule and every violation."""
    rows = measure_all(labels_dir)
    bad = problems(rows)
    for doc in load_labels(labels_dir).values():
        bad += label_problems(doc, labels_dir)
    lines = ["smell patterns: class, hits and precision on the hand-labelled sets, obligation status", *table(rows),
             f"rule: {RULE}; a label set also needs a second labeller (the author's labels alone do not count)."]
    return lines, bad


def list_hits(root: str) -> list:
    t0 = time.perf_counter()
    found = sorted(smell_facts(root), key=lambda f: (f["detail"]["pattern"], f["path"], f["line"] or 0))
    print(f"== {root}  ({time.perf_counter() - t0:.2f}s)")
    return found


def main(argv: list[str]) -> int:
    if not argv:
        print(__doc__)
        return 2
    if argv[0] in ("--labels", "--gate"):
        lines, bad = report()
        print("\n".join(lines))
        for b in bad:
            print(f"VIOLATION: {b}", file=sys.stderr)
        return 1 if bad and argv[0] == "--gate" else 0
    for root in argv:
        hits = list_hits(root)
        counts = collections.Counter(h["detail"]["pattern"] for h in hits)
        for pattern, n in sorted(counts.items()):
            print(f"{pattern}: {n}")
        for h in hits:
            print(f"{h['path']}:{h['line']} [{h['detail']['pattern']}] {h['name']}")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
