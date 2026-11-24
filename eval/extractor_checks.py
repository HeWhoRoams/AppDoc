"""Extractor accuracy: answer keys for every corpus case and sample stack, scored per stack per kind.

    python eval/extractor_checks.py                      score the keys against eval/baseline.json (exit 1 on regression)
    python eval/extractor_checks.py --update-baseline    rewrite eval/baseline.json from the current scores
    python eval/extractor_checks.py --clones DIR         the older checks against Facts extracted from local clones

An extractor key is `eval/answer-keys/<case>.json`, a JSON object (the narrative keys read by score.py are lists):

    {"type": "extractor", "target": "tests/samples/go", "exhaustive": true,
     "must_exist":     [{"kind": "entry_point", "stack": "go", "path": "main.go", "line": 13, "name": "/health",
                         "detail": {"type": "route"}}, ...],
     "must_not_exist": [{"kind": "config_key", "stack": "...", "name": "MIN_PASSWORD_LENGTH",
                         "detail": {"secret_location": true}}, ...],
     "known_gaps":     [{... a must-exist pattern the extractor misses today, with a "why" ...}]}

A pattern matches a Fact when every field it names equals the Fact's (`detail` is a subset test). Besides the Facts,
the Scan coverage entries are matched as pseudo-Facts with stack "scan": kinds `retired_candidate` (path),
`duplicate_folder` (path = a, name = b) and `pruned` (path, name = rule).

Scoring, per (stack, kind) over all keys: recall = must-exist patterns found / must-exist patterns; precision =
Facts matched by a must-exist pattern / (those + false positives). A false positive is any Fact matching a
must-not-exist pattern and, when the key is `exhaustive`, any Fact (outside `file` and `ownership`) that no
must-exist pattern matches. Any Fact matching a must-not-exist pattern is also reported as forbidden, whatever the
baseline says.
"""

import argparse
import json
import os
import re
import sys
import tempfile

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, ROOT)

KEYS_DIR = os.path.join(HERE, "answer-keys")
BASELINE = os.path.join(HERE, "baseline.json")
UNSCORED_KINDS = {"file", "ownership"}
FIELDS = ("kind", "stack", "path", "line", "name")


def load_keys(keys_dir=KEYS_DIR):
    """{case: key} for every extractor key (a JSON object with type "extractor")."""
    keys = {}
    for fn in sorted(os.listdir(keys_dir)):
        if not fn.endswith(".json"):
            continue
        with open(os.path.join(keys_dir, fn), encoding="utf-8") as fh:
            data = json.load(fh)
        if isinstance(data, dict) and data.get("type") == "extractor":
            keys[fn[:-5]] = data
    return keys


def extract_doc(target):
    """The Facts document of a Target, extracted in memory (nothing is written under the Target)."""
    from appdoc import extract
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(target, out, workers=0, use_cache=False, no_ownership=True)
    return json.loads(text)


def facts_of(doc):
    """Facts plus stack Facts plus the Scan coverage entries as pseudo-Facts."""
    out = [dict(f) for f in doc["facts"]] + [dict(f) for f in doc.get("stacks", [])]
    scan = doc["target"].get("scan", {})
    for c in scan.get("retired_candidates", []):
        out.append({"kind": "retired_candidate", "stack": "scan", "path": c["path"], "line": None,
                    "name": c.get("signal", ""), "detail": {"files": c.get("files")}})
    for d in scan.get("duplicate_folders", []):
        out.append({"kind": "duplicate_folder", "stack": "scan", "path": d["a"], "line": None,
                    "name": d["b"], "detail": {"files": d.get("files")}})
    for p in scan.get("pruned", []):
        out.append({"kind": "pruned", "stack": "scan", "path": p["path"], "line": None,
                    "name": p.get("rule", ""), "detail": {"files": p.get("files")}})
    return out


def matches(pattern, fact):
    for k in FIELDS:
        if k in pattern and pattern[k] != fact.get(k):
            return False
    detail = fact.get("detail") or {}
    for k, v in (pattern.get("detail") or {}).items():
        if k not in detail:
            return False
        if isinstance(v, list) and isinstance(detail[k], list):  # a list in a pattern is a subset test
            if not set(v) <= set(detail[k]):
                return False
        elif detail[k] != v:
            return False
    return True


def capability_gaps(doc):
    """Facts a supported stack emitted without declaring the capability for them (routes imply a capability)."""
    caps = {s["name"]: set(s["detail"].get("capabilities", [])) for s in doc.get("stacks", [])
            if s["detail"].get("supported")}
    gaps = set()
    for f in doc["facts"]:
        if f["stack"] not in caps:
            continue
        need = f["kind"] if f["kind"] not in ("entry_point",) else f"entry_point.{f['detail'].get('type')}"
        if f["kind"] in ("file", "stack", "ownership", "owner_file", "dependency"):
            continue
        if need not in caps[f["stack"]]:
            gaps.add(f"{f['stack']} emits {need} Facts but does not declare it ({f['path']}:{f['line']})")
    return sorted(gaps)


def score_key(key, doc):
    """Score one key against a Facts document.

    Returns {"counts": {"stack/kind": {"expected", "found", "tp", "fp"}}, "missing": [...], "forbidden": [...],
    "unexpected": [...], "capability_gaps": [...]}.
    """
    facts = [f for f in facts_of(doc) if f["kind"] not in UNSCORED_KINDS]
    exist = key.get("must_exist", [])
    forbid = key.get("must_not_exist", [])
    exhaustive = bool(key.get("exhaustive"))
    counts = {}

    def slot(stack, kind):
        return counts.setdefault(f"{stack}/{kind}", {"expected": 0, "found": 0, "tp": 0, "fp": 0})

    missing, forbidden, unexpected = [], [], []
    for pat in exist:
        s = slot(pat["stack"], pat["kind"])
        s["expected"] += 1
        if any(matches(pat, f) for f in facts):
            s["found"] += 1
        else:
            missing.append(pat)
    for f in facts:
        s = slot(f["stack"], f["kind"])
        if any(matches(p, f) for p in exist):
            s["tp"] += 1
        elif any(matches(p, f) for p in forbid):
            s["fp"] += 1
            forbidden.append(f)
        elif exhaustive:
            s["fp"] += 1
            unexpected.append(f)
    for f in facts:  # a forbidden Fact that a must-exist pattern also matches is still forbidden
        if any(matches(p, f) for p in forbid) and f not in forbidden:
            forbidden.append(f)
    for pat in forbid:  # a guard on a kind nobody extracts still gets a slot, so it is scored
        slot(pat["stack"], pat["kind"])
    return {"counts": counts, "missing": missing, "forbidden": forbidden, "unexpected": unexpected,
            "capability_gaps": capability_gaps(doc)}


def _ratio(n, d):
    return None if d == 0 else round(n / d, 4)


def aggregate(results):
    """Sum counts over cases; add recall and precision."""
    total = {}
    for res in results.values():
        for name, c in res["counts"].items():
            t = total.setdefault(name, {"expected": 0, "found": 0, "tp": 0, "fp": 0})
            for k in t:
                t[k] += c[k]
    for t in total.values():
        t["recall"] = _ratio(t["found"], t["expected"])
        t["precision"] = _ratio(t["tp"], t["tp"] + t["fp"])
    return dict(sorted(total.items()))


def score_all(keys=None, root=ROOT):
    keys = load_keys() if keys is None else keys
    return {case: score_key(key, extract_doc(os.path.join(root, *key["target"].split("/"))))
            for case, key in keys.items()}


def regressions(baseline, current):
    """Messages for every (stack/kind) whose recall or precision fell below the baseline, or that vanished."""
    bad = []
    for name, b in baseline.items():
        c = current.get(name)
        if c is None:
            bad.append(f"{name}: in the baseline but no key covers it any more")
            continue
        for metric in ("recall", "precision"):
            if b.get(metric) is not None and (c.get(metric) is None or c[metric] < b[metric]):
                bad.append(f"{name}: {metric} {c.get(metric)} is below the baseline {b[metric]}")
    return bad


def load_baseline():
    with open(BASELINE, encoding="utf-8") as fh:
        return json.load(fh)


def write_baseline(current):
    with open(BASELINE, "w", encoding="utf-8", newline="\n") as fh:
        json.dump(current, fh, indent=2, sort_keys=True)
        fh.write("\n")


def report(results, current, bad):
    for case, res in results.items():
        for pat in res["missing"]:
            print(f"MISSING    {case}: {json.dumps(pat, sort_keys=True)}")
        for f in res["forbidden"]:
            print(f"FORBIDDEN  {case}: {f['kind']} {f['path']}:{f['line']} {f['name']}")
        for g in res["capability_gaps"]:
            print(f"CAPABILITY {case}: {g}")
        for f in res["unexpected"]:
            print(f"UNEXPECTED {case}: {f['kind']} {f['path']}:{f['line']} {f['name']}")
    width = max([len(n) for n in current] + [10])
    print(f"\n{'stack/kind'.ljust(width)}  expected  found  recall  precision")
    for n, c in current.items():
        print(f"{n.ljust(width)}  {c['expected']:>8}  {c['found']:>5}  {str(c['recall']):>6}  {c['precision']}")
    for b in bad:
        print(f"REGRESSION {b}")


def run_keys(update=False):
    results = score_all()
    current = aggregate(results)
    if update:
        write_baseline(current)
        print(f"wrote {os.path.relpath(BASELINE, ROOT)}: {len(current)} stack/kind rows from {len(results)} keys")
        return 0
    bad = regressions(load_baseline(), current)
    forbidden = [c for c, r in results.items() if r["forbidden"] or r["capability_gaps"]]
    report(results, current, bad)
    if forbidden:
        print(f"Forbidden Facts or undeclared capabilities in: {', '.join(forbidden)}")
    print(f"\n{len(results)} keys, {len(current)} stack/kind rows, {len(bad)} regressions")
    return 1 if bad or forbidden else 0


def load(base, repo, out):
    with open(os.path.join(base, repo, out, "facts.json"), encoding="utf-8") as fh:
        return json.load(fh)


def facts(doc, kind, **want):
    for f in doc["facts"]:
        if f["kind"] != kind or f["detail"].get("test"):
            continue
        d = f["detail"]
        if all(d.get(k) == v for k, v in want.items()):
            yield f


def count_task_literals(base):
    n = 0
    d = os.path.join(base, "gitea", "services", "cron")
    for name in os.listdir(d):
        if name.startswith("tasks") and name.endswith(".go") and not name.endswith("_test.go"):
            with open(os.path.join(d, name), encoding="utf-8") as fh:
                n += len(re.findall(r'RegisterTask\w*\(\s*"', fh.read()))
    return n


def clone_checks(argv):
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", required=True, help="folder holding the clones")
    ap.add_argument("--out", default=os.path.join("docs", "appdoc-2.3"))
    a = ap.parse_args(argv)
    results = []

    def check(name, ok, detail=""):
        results.append((name, bool(ok), detail))

    g = load(a.base, "gitea", a.out)
    stacks = {s["name"]: s["detail"].get("supported") for s in g["stacks"]}
    check("gitea: go supported", stacks.get("go") is True)
    check("gitea: node-express not supported", stacks.get("node-express") is not True, str(stacks.get("node-express")))
    routes = [f for f in facts(g, "entry_point", type="route") if f["path"] == "routers/web/web.go"]
    check("gitea: routes in routers/web/web.go", len(routes) > 0, str(len(routes)))
    jobs = list(facts(g, "entry_point", type="job"))
    lit = count_task_literals(a.base)
    check("gitea: job count equals RegisterTask literals", len(jobs) == lit, f"{len(jobs)} vs {lit}")

    f = load(a.base, "flaskr-tdd", a.out)
    sk = [x for x in facts(f, "config_key", use="define") if x["name"] == "SECRET_KEY" and x["path"] == "project/app.py"]
    check("flaskr: SECRET_KEY defined at project/app.py:25", sk and sk[0]["line"] == 25, str([x["line"] for x in sk]))
    pats = {}
    for x in facts(f, "smell"):
        pats[x["detail"]["pattern"]] = pats.get(x["detail"]["pattern"], 0) + 1
    for p, n in (("distinct-auth-errors", 1), ("unescaped-template-output", 2), ("state-change-on-get", 1),
                 ("hardcoded-credential-constant", 2)):
        check(f"flaskr: smell {p} x{n}", pats.get(p, 0) == n, str(pats.get(p, 0)))

    s = load(a.base, "spring-petclinic", a.out)
    idx = [x for x in facts(s, "schema_object", type="index") if "LOWER(name)" in x["detail"].get("expression", "")]
    check("spring: index expression has LOWER(name)", idx, str(len(idx)))
    sp = {}
    for x in facts(s, "smell"):
        sp[x["detail"]["pattern"]] = sp.get(x["detail"]["pattern"], 0) + 1
    check("spring: flash-without-redirect x2", sp.get("flash-without-redirect") == 2, str(sp.get("flash-without-redirect")))
    check("spring: actuator-exposed", sp.get("actuator-exposed", 0) >= 1)
    ctrl = {x["path"] for x in facts(s, "entry_point", type="route")}
    check("spring: 6 controller files", len(ctrl) == 6, str(len(ctrl)))

    e = load(a.base, "eShop", a.out)
    paid = [x for x in facts(e, "smell", pattern="logger-type-mismatch") if "Paid" in x["path"]]
    check("eShop: logger-type-mismatch on Paid handler", paid, str(len(paid)))
    idp = [x for x in facts(e, "entry_point", type="page") if x["path"].startswith("src/Identity.API")]
    check("eShop: Identity.API page Facts", idp, str(len(idp)))
    ui = [x for x in facts(e, "ui_page") if x["path"].startswith("src/ClientApp")]
    check("eShop: ClientApp ui_page Facts", ui, str(len(ui)))

    width = max(len(n) for n, _, _ in results)
    for n, ok, d in results:
        print(f"{'PASS' if ok else 'FAIL'}  {n.ljust(width)}  {d}")
    bad = [n for n, ok, _ in results if not ok]
    print(f"\n{len(results) - len(bad)}/{len(results)} passed")
    return 1 if bad else 0


def main(argv=None):
    argv = sys.argv[1:] if argv is None else argv
    if "--clones" in argv:
        i = argv.index("--clones")
        return clone_checks(["--base", argv[i + 1]] + argv[i + 2:])
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--update-baseline", action="store_true")
    ap.add_argument("--root", help="accepted and ignored: the keys run against tests/ in this repository")
    a = ap.parse_args(argv)
    return run_keys(a.update_baseline)


if __name__ == "__main__":
    sys.exit(main())
