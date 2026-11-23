"""CI self-test of `appdoc gate` on a temp copy of tests/samples/java-spring (stdlib only, any OS).

    python tools/gate_selftest.py

Extracts the Facts, then checks the gate's exit codes: Facts unchanged -> the gate reaches the Check
(the sample has no Narrative, so the Check reports a tool error, exit 1, and prints that it ran), a code
change -> 2 "Facts changed", a different schema -> 3 "AppDoc upgraded". The gate writes nothing
in the Target. Exits 0 when all hold, 1 with the failing step otherwise.
"""

from __future__ import annotations

import json
import os
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAUNCHER = os.path.join(ROOT, "run_appdoc.py")
SAMPLE = os.path.join(ROOT, "tests", "samples", "java-spring")


def _run(*args):
    res = subprocess.run([sys.executable, LAUNCHER, *args], capture_output=True, text=True)
    return res.returncode, res.stdout + res.stderr


def main() -> int:
    failures = []

    def expect(step, got, want, text, needle):
        ok = got == want and needle in text
        print(f"{'ok' if ok else 'FAIL'}: {step} (exit {got}, want {want})")
        if not ok:
            failures.append(step)
            print(text)

    with tempfile.TemporaryDirectory() as tmp:
        target = os.path.join(tmp, "java-spring")
        shutil.copytree(SAMPLE, target, ignore=shutil.ignore_patterns("__pycache__"))
        rc, text = _run("extract", target, "--no-cache", "--no-ownership")
        if rc != 0:
            print(text)
            return 1
        rc, text = _run("gate", target)
        expect("facts unchanged reaches the Check", rc, 1, text, "running the Check")
        with open(os.path.join(target, "pom.xml"), "a", encoding="utf-8") as fh:
            fh.write("<!-- changed after the Facts were committed -->\n")
        added = os.path.join(target, "src", "main", "java", "SelfTestAdded.java")
        os.makedirs(os.path.dirname(added), exist_ok=True)
        with open(added, "w", encoding="utf-8") as fh:
            fh.write("public class SelfTestAdded {}\n")
        rc, text = _run("gate", target)
        expect("a code change", rc, 2, text, "Facts changed")
        os.remove(added)
        facts = os.path.join(target, "docs", "appdoc", "facts.json")
        with open(facts, encoding="utf-8") as fh:
            doc = json.load(fh)
        doc["schema"] = "appdoc-facts/0"
        with open(facts, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(doc, fh, indent=1, sort_keys=True)
        rc, text = _run("gate", target)
        expect("a different schema", rc, 3, text, "AppDoc upgraded")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
