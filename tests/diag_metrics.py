"""Objective metrics for AppDoc example docs. Reads the 6 artifacts per example and
emits a comparable metric table. Stdlib only.

Usage: python tests/diag_metrics.py <base_dir> <name1> <name2> ...
  where each <name> is a folder under <base_dir> (e.g. examples/previous or examples/current).
"""
from __future__ import annotations
import json, os, re, sys, collections

CITE_LINE = re.compile(r"\| (\d+) \| `([^`]+)` \| ([^|]*) \| (yes|no) \|")

def _read(p):
    try:
        with open(p, encoding="utf-8", errors="replace") as fh:
            return fh.read()
    except OSError:
        return ""

def citations(text):
    rows = CITE_LINE.findall(text)
    total = len(rows)
    with_line = sum(1 for _, _, lr, _ in rows if lr.strip())
    resolved = sum(1 for *_, r in rows if r == "yes")
    return total, with_line, resolved

def audit(text):
    rows = []
    for line in text.splitlines():
        line = line.strip()
        if not line.startswith("{"):
            continue
        try:
            o = json.loads(line)
        except Exception:
            continue
        if o.get("type") == "audit":
            continue
        rows.append(o)
    results = collections.Counter(o.get("result", "?") for o in rows)
    with_limit = sum(1 for o in rows if o.get("limitation"))
    return len(rows), results, with_limit

def facts(text):
    try:
        d = json.loads(text)
    except Exception:
        return None
    fs = d.get("facts", [])
    by_kind = collections.Counter(f.get("kind", "?") for f in fs)
    by_stack = collections.Counter(f.get("stack", "?") for f in fs)
    return {"total": len(fs), "by_kind": dict(by_kind), "by_stack": dict(by_stack),
            "generator": d.get("generator"), "schema": d.get("schema")}

def doc_stats(text):
    words = len(text.split())
    # section headers like "## 1." or "### 2.1"
    sections = len(re.findall(r"^#{2,3} \d", text, re.M))
    unknown = len(re.findall(r"\bQ-\d+\b", text))
    vuln = len(re.findall(r"\bV-\d+\b", text))
    smells = len(re.findall(r"\bS-\d+\b", text))
    return words, sections, unknown, vuln, smells

def scan_coverage(text):
    m = re.search(r"Files found: (\d+) = scanned (\d+) \+ pruned (\d+) \+ ignored[^\d]*(\d+)", text)
    if m:
        return tuple(int(x) for x in m.groups())
    return None

def retired(text):
    # count lines under "Folders that look retired"
    n = 0
    inblk = False
    for line in text.splitlines():
        if "look retired" in line:
            inblk = True
            continue
        if inblk:
            if line.startswith("- "):
                n += 1
            elif line.strip() and not line.startswith("-"):
                inblk = False
    return n

def analyze(base, name):
    d = os.path.join(base, name)
    doc = _read(os.path.join(d, "application-documentation.md"))
    chk = _read(os.path.join(d, "check-report.md"))
    ev = _read(os.path.join(d, "evidence.jsonl"))
    fj = _read(os.path.join(d, "facts.json"))
    fs = _read(os.path.join(d, "facts-summary.md"))
    check = "PASS" if chk.startswith("# Check: PASS") else ("FAIL" if chk.startswith("# Check: FAIL") else "?")
    ct, wl, res = citations(chk)
    at, ar, al = audit(ev)
    f = facts(fj)
    words, secs, unk, vul, sm = doc_stats(doc)
    cov = scan_coverage(fs)
    ret = retired(doc)
    supported = ar.get("Supported", 0)
    pct_sup = round(100 * supported / at, 1) if at else 0
    pct_line = round(100 * wl / ct, 1) if ct else 0
    return {
        "name": name, "check": check,
        "citations": ct, "cites_with_line": wl, "pct_cites_with_line": pct_line,
        "cites_resolved": res,
        "audit_rows": at, "audit_supported": supported, "pct_supported": pct_sup,
        "audit_results": dict(ar), "audit_with_limitation": al,
        "facts_total": f["total"] if f else 0,
        "facts_by_kind": f["by_kind"] if f else {},
        "facts_by_stack": f["by_stack"] if f else {},
        "generator": f["generator"] if f else None,
        "words": words, "sections": secs, "unknown_Q": unk, "vuln_V": vul, "smells_S": sm,
        "scan": cov, "retired_candidates": ret,
    }

def _json(path):
    try:
        return json.loads(_read(path))
    except ValueError:
        return {}

def baselines(base, name):
    """Facts-level numbers the 2.6.0 work must move, read from one example folder.

    Tolerant of both layouts: 2.5.0 examples carry `generator` in facts.json and no provenance.json;
    2.6.0 examples carry provenance.json instead.
    """
    d = os.path.join(base, name)
    doc = _json(os.path.join(d, "facts.json"))
    narrative = _read(os.path.join(d, "application-documentation.md"))
    report = _read(os.path.join(d, "check-report.md"))
    scan = (doc.get("target") or {}).get("scan") or {}
    retired = scan.get("retired_candidates") or []
    cites = CITE_LINE.findall(report)
    prov = _json(os.path.join(d, "provenance.json"))
    m = re.search(r"(\d+) keys? in (\d+) file\S* were not classified", narrative)
    return {
        "retired_name": sum(1 for c in retired if c.get("signal") == "name"),
        "retired_content": sum(1 for c in retired if c.get("signal") == "content"),
        "duplicate_pairs": len(scan.get("duplicate_folders") or []),
        "capabilities": sorted({c for st in doc.get("stacks", []) for c in (st.get("detail") or {}).get("capabilities") or []}),
        "stacks": len(doc.get("stacks", [])),
        "secret_locations": sum(1 for f in doc.get("facts", [])
                                if f.get("kind") == "config_key" and (f.get("detail") or {}).get("secret_location")),
        "not_classified": (int(m.group(1)), int(m.group(2))) if m else None,
        "bare_name_cites": sum(1 for _, path, _, _ in cites if "/" not in path.strip("/")),
        "cites_total": len(cites),
        "generator": doc.get("generator") or prov.get("generator"),
    }

def config_reference(base, name):
    """(application keys shown, application keys total, (keys, files) not classified or None) from section 16.6."""
    narrative = _read(os.path.join(base, name, "application-documentation.md"))
    m = re.search(r"Shown (\d+) of (\d+) application keys", narrative)
    nc = re.search(r"(\d+) keys? in (\d+) file\S* were not classified", narrative)
    return (int(m.group(1)) if m else 0, int(m.group(2)) if m else 0,
            (int(nc.group(1)), int(nc.group(2))) if nc else None)

def main():
    base = sys.argv[1]
    names = sys.argv[2:]
    out = [analyze(base, n) for n in names]
    print(json.dumps(out, indent=1))

if __name__ == "__main__":
    main()
