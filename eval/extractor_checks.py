"""Extractor acceptance checks for v2.3 (plan Phase 8.2). Usage: python eval/extractor_checks.py [--base DIR] [--out docs/appdoc-2.3]"""

import argparse
import json
import os
import re
import sys


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


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--base", default=r"C:\Github\appdoc-test")
    ap.add_argument("--out", default=os.path.join("docs", "appdoc-2.3"))
    a = ap.parse_args()
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


if __name__ == "__main__":
    sys.exit(main())
