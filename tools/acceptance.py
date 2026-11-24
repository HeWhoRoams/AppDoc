"""Private acceptance run: assert an answer key against the Facts (and Check output) AppDoc produces for a Target.

    python tools/acceptance.py --target <checkout> [--name <key name>] [--report <check-report.md>]
    python tools/acceptance.py --target <checkout> --key <key.json>

The key is read from ``$APPDOC_ACCEPTANCE_KEYS/<name>.json`` (``<name>`` defaults to the Target folder's name), or
from ``--key``. ``APPDOC_ACCEPTANCE_KEYS`` is a folder outside this repository that holds the private answer keys
(and the ``denylist.txt`` that ``tests/test_corpus.py`` uses to keep the invented Targets free of private names).
It is a tooling switch of this script and of those tests only: nothing under ``appdoc/`` reads it (R13). This script
is not part of CI and the keys are never committed; the committed toy key and test use an invented Target.

What it asserts: **Facts and Check output only**. The Target is extracted in memory (nothing is written under it)
and every row of the key is matched against the Facts (stack Facts included). A row never reads the Target's
source, and the script prints only row ids, descriptions and counts, never a Fact value.

Key format (a JSON object)::

    {"type": "acceptance",
     "rows": [
       {"id": "A-1", "desc": "Windows authentication is a setting",
        "fact": {"kind": "security_setting", "name": "system.web/authentication@mode",
                 "detail": {"value": "windows"}},
        "min": 1},
       {"id": "A-2", "desc": "no false stack", "fact": {"kind": "stack", "name": "aspnet-core"}, "max": 0},
       {"id": "A-3", "desc": "every area is a distinct mvc_area_path",
        "fact": {"kind": "entry_point"}, "distinct": "detail.mvc_area_path", "count": 4},
       {"id": "A-4", "desc": "the mandatory-input rule fails the document",
        "check": {"rule": "C21", "expect": "fail"}}
     ]}

* ``fact`` is a pattern: ``kind``, ``stack``, ``path``, ``name``, ``line`` must equal the Fact's, and every
  ``detail`` entry must match. A detail value is an exact scalar, a list (a subset test against a list detail),
  or an operator object: ``{"ge": n}``, ``{"le": n}``, ``{"in": [...]}``, ``{"contains": x}``, ``{"absent": true}``.
* The matching Facts are counted (or, with ``distinct``, the distinct non-empty values of one dotted field such as
  ``path`` or ``detail.mvc_area_path``). ``count`` is exact; ``min`` defaults to 1 unless ``count`` or ``max`` is given;
  ``max`` is an upper bound (``"max": 0`` means no such Fact).
* ``check`` rows read a Check report (``--report``, the ``check-report.md`` a Check run wrote): ``expect`` is ``fail``
  (the rule has a section in the report) or ``pass``. Without ``--report`` a ``check`` row is ``SKIP`` (not a failure).

Exit codes: 0 every row passed (or was skipped), 1 a row failed, the key is missing or invalid, or the Target is not a
folder. Stdlib only.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
KEYS_ENV = "APPDOC_ACCEPTANCE_KEYS"
FIELDS = ("kind", "stack", "path", "line", "name")
OPERATORS = ("ge", "le", "in", "contains", "absent")


class KeyError_(Exception):
    """The key is missing or malformed (a message for the person running the script, exit 1)."""


def load_key(name: str | None, key_path: str | None, env: "dict | None" = None) -> dict:
    env = os.environ if env is None else env
    if key_path is None:
        folder = env.get(KEYS_ENV)
        if not folder:
            raise KeyError_(f"{KEYS_ENV} is not set; point it at the folder holding <target>.json answer keys "
                            f"(or pass --key FILE)")
        key_path = os.path.join(folder, f"{name}.json")
    if not os.path.isfile(key_path):
        raise KeyError_(f"no answer key at {key_path}")
    try:
        with open(key_path, encoding="utf-8") as fh:
            key = json.load(fh)
    except (OSError, ValueError) as exc:
        raise KeyError_(f"cannot read the answer key {key_path}: {exc}") from None
    rows = key.get("rows") if isinstance(key, dict) else None
    if not isinstance(rows, list) or not rows:
        raise KeyError_(f"{key_path}: the key must be an object with a non-empty list \"rows\"")
    seen = set()
    for n, row in enumerate(rows, 1):
        if not isinstance(row, dict) or not row.get("id"):
            raise KeyError_(f"{key_path}: row {n} has no \"id\"")
        if row["id"] in seen:
            raise KeyError_(f"{key_path}: duplicate row id {row['id']}")
        seen.add(row["id"])
        if ("fact" in row) == ("check" in row):
            raise KeyError_(f"{key_path}: row {row['id']} needs exactly one of \"fact\" or \"check\"")
    return key


def extract_facts(target: str) -> list:
    """Every Fact (stack Facts included) of ``target``, extracted in memory."""
    sys.path.insert(0, ROOT)
    from appdoc import extract
    with tempfile.TemporaryDirectory() as out:
        text, _ = extract.extract(target, out, workers=0, use_cache=False, no_ownership=True)
    doc = json.loads(text)
    return [dict(f) for f in doc["facts"]] + [dict(f) for f in doc.get("stacks", [])]


def _detail_ok(want, have, present: bool) -> bool:
    if isinstance(want, dict):
        if set(want) - set(OPERATORS):
            raise KeyError_(f"unknown detail operator in {sorted(want)}")
        if want.get("absent"):
            return not present
        if not present:
            return False
        if "ge" in want and not (isinstance(have, (int, float)) and have >= want["ge"]):
            return False
        if "le" in want and not (isinstance(have, (int, float)) and have <= want["le"]):
            return False
        if "in" in want and have not in want["in"]:
            return False
        if "contains" in want and not (isinstance(have, list) and want["contains"] in have):
            return False
        return True
    if not present:
        return False
    if isinstance(want, list) and isinstance(have, list):
        return set(want) <= set(have)
    return have == want


def matches(pattern: dict, fact: dict) -> bool:
    for k in FIELDS:
        if k in pattern and pattern[k] != fact.get(k):
            return False
    detail = fact.get("detail") or {}
    return all(_detail_ok(want, detail.get(k), k in detail) for k, want in (pattern.get("detail") or {}).items())


def _field(fact: dict, dotted: str):
    cur = fact
    for part in dotted.split("."):
        if not isinstance(cur, dict) or part not in cur:
            return None
        cur = cur[part]
    return cur


def check_rules(report_text: str) -> set:
    """Rule ids that have a section in a check-report.md (``## C21 ...``)."""
    return set(re.findall(r"(?m)^## (C\d+) ", report_text))


def run_row(row: dict, facts: list, report: "str | None") -> tuple:
    """(status, detail) for one row; status is PASS, FAIL or SKIP. The detail is counts only."""
    if "check" in row:
        spec = row["check"]
        if report is None:
            return "SKIP", "no --report"
        if spec.get("expect") not in ("fail", "pass") or not spec.get("rule"):
            raise KeyError_(f"row {row['id']}: check needs \"rule\" and \"expect\" of fail or pass")
        failing = spec["rule"] in check_rules(report)
        ok = failing == (spec["expect"] == "fail")
        return ("PASS" if ok else "FAIL"), f"{spec['rule']} {'fails' if failing else 'does not fail'}, expected {spec['expect']}"
    matched = [f for f in facts if matches(row["fact"], f)]
    if "distinct" in row:
        got = len({json.dumps(v, sort_keys=True) for v in (_field(f, row["distinct"]) for f in matched)
                   if v not in (None, "", [])})
        what = f"{got} distinct {row['distinct']}"
    else:
        got = len(matched)
        what = f"{got} matching Facts"
    if "count" in row:
        ok, want = got == row["count"], f"exactly {row['count']}"
    else:
        low = row.get("min", 0 if "max" in row else 1)
        high = row.get("max")
        ok = got >= low and (high is None or got <= high)
        want = f"at least {low}" + (f" and at most {high}" if high is not None else "")
    return ("PASS" if ok else "FAIL"), f"{what}, expected {want}"


def main(argv: "list | None" = None, env: "dict | None" = None, out=None) -> int:
    out = out or sys.stdout
    ap = argparse.ArgumentParser(description="Assert a private answer key against the Facts and Check output of a Target.")
    ap.add_argument("--target", required=True, help="the Target folder (a local checkout)")
    ap.add_argument("--name", help=f"key name under ${KEYS_ENV} (default: the Target folder's name)")
    ap.add_argument("--key", help=f"a key file; overrides ${KEYS_ENV}")
    ap.add_argument("--report", help="a check-report.md, for the key's check rows")
    args = ap.parse_args(argv)
    target = os.path.abspath(args.target)
    name = args.name or os.path.basename(target.rstrip("\\/"))
    try:
        key = load_key(name, args.key, env)
        if not os.path.isdir(target):
            raise KeyError_(f"the Target is not a folder: {target}")
        report = None
        if args.report:
            if not os.path.isfile(args.report):
                raise KeyError_(f"no check report at {args.report}")
            with open(args.report, encoding="utf-8") as fh:
                report = fh.read()
        facts = extract_facts(target)
        failed = 0
        for row in key["rows"]:
            status, detail = run_row(row, facts, report)
            failed += status == "FAIL"
            print(f"{status} {row['id']} {row.get('desc', '')} ({detail})".replace("  ", " "), file=out)
    except KeyError_ as exc:
        print(f"acceptance: {exc}", file=sys.stderr)
        return 1
    print(f"{len(key['rows']) - failed} of {len(key['rows'])} rows passed or skipped; {failed} failed", file=out)
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
