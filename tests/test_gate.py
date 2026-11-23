"""`appdoc gate`: exit 0 pass, 1 tool error, 2 Facts changed, 3 AppDoc upgraded (docs/remediation-plan-2.6.md 6.1)."""
import contextlib
import io
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import unittest
from unittest import mock

from appdoc import check, extract, fill, gate
from tests.test_corpus import run_case

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LAUNCHER = os.path.join(ROOT, "run_appdoc.py")
YAML = os.path.join(ROOT, "ci", "appdoc-docs-gate.yml")


def run_gate(target, *args):
    return subprocess.run([sys.executable, LAUNCHER, "gate", target, *args], capture_output=True, text=True)


def _text(res):
    return res.stdout + res.stderr


class GateTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.case = run_case("gate-layout", tmp=self.tmp)
        self.target, self.out = self.case.target, self.case.out
        self.regen = os.path.join(self.target, ".appdoc-regen")

    def main_py(self):
        return os.path.join(self.target, "app", "main.py")

    def set_facts(self, **top):
        path = os.path.join(self.out, "facts.json")
        with open(path, encoding="utf-8") as fh:
            doc = json.load(fh)
        doc.update(top)
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(doc, fh, indent=1, sort_keys=True)

    def refill(self):
        with contextlib.redirect_stdout(io.StringIO()):
            check.seal_register(self.target, self.out)
            self.assertEqual(fill.run(self.target, self.out), 0)

    def test_unchanged_target_passes_and_regen_folder_is_removed(self):
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 0, _text(res))
        self.assertFalse(os.path.exists(self.regen))

    def test_code_change_exits_2_with_a_short_diff(self):
        with open(self.main_py(), "a", encoding="utf-8") as fh:
            fh.write("# line 11\n")
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 2, _text(res))
        self.assertIn("Facts changed", _text(res))
        self.assertTrue(re.search(r"^[-+] ", res.stdout + res.stderr, re.M), "the diff must be printed")
        self.assertFalse(os.path.exists(self.regen))

    def test_diff_is_capped_at_200_lines(self):
        for i in range(120):
            with open(os.path.join(self.target, "app", f"m{i}.py"), "w", encoding="utf-8") as fh:
                fh.write("from flask import Flask\napp = Flask(__name__)\n\n@app.route('/r%d')\ndef r%d():\n    pass\n" % (i, i))
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 2, _text(res))
        diff_lines = [l for l in _text(res).splitlines() if l[:1] in "+-@ " and l.strip()]
        self.assertLessEqual(len(diff_lines), 200)
        self.assertRegex(_text(res), r"more diff lines")

    def test_schema_difference_exits_3(self):
        self.set_facts(schema="appdoc-facts/0")
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 3, _text(res))
        self.assertIn("AppDoc upgraded", _text(res))
        self.assertFalse(os.path.exists(self.regen))

    def test_schema_difference_wins_over_a_code_change(self):
        self.set_facts(schema="appdoc-facts/0")
        with open(self.main_py(), "a", encoding="utf-8") as fh:
            fh.write("# line 11\n")
        self.assertEqual(run_gate(self.target).returncode, 3)

    def test_missing_facts_exits_1(self):
        os.remove(os.path.join(self.out, "facts.json"))
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 1, _text(res))
        self.assertIn("facts.json", _text(res))
        self.assertFalse(os.path.exists(self.regen))

    def test_patch_only_provenance_change_passes(self):
        path = os.path.join(self.out, "provenance.json")
        with open(path, encoding="utf-8") as fh:
            prov = json.load(fh)
        prov.update(generator="2.6.0", bundle="0" * 12)
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(prov, fh, indent=1, sort_keys=True)
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 0, _text(res))
        self.assertIn("informational", _text(res))

    def test_check_failure_code_is_returned(self):
        narrative = os.path.join(self.out, "application-documentation.md")
        with open(narrative, encoding="utf-8") as fh:
            text = fh.read()
        with open(narrative, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text.replace("app/main.py:2", "app/nope.py:2", 1))
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 2, _text(res))
        self.assertNotIn("Facts changed", _text(res))

    def test_require_audit_is_passed_to_the_check(self):
        with open(os.path.join(self.out, "evidence.jsonl"), "w", encoding="utf-8") as fh:
            fh.write('{"type": "audit", "performed": false, "scope": "not yet"}\n')
        self.refill()
        self.assertEqual(run_gate(self.target).returncode, 0)
        self.assertEqual(run_gate(self.target, "--require-audit").returncode, 2)

    def test_skill_folder_inside_the_target_passes(self):
        skill = os.path.join(self.target, "tools", "appdoc-skill")
        shutil.copytree(os.path.join(ROOT, "appdoc"), os.path.join(skill, "appdoc"),
                        ignore=shutil.ignore_patterns("__pycache__"))
        shutil.copy(LAUNCHER, skill)
        with contextlib.redirect_stdout(io.StringIO()):
            extract.write(self.target, self.out, workers=0, use_cache=False, no_ownership=True)
        self.refill()
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 0, _text(res))
        self.assertFalse(os.path.exists(self.regen))

    def test_a_stale_regen_folder_is_not_scanned_and_is_removed(self):
        os.makedirs(self.regen)
        with open(os.path.join(self.regen, "facts.json"), "w", encoding="utf-8") as fh:
            fh.write("{}")
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 0, _text(res))
        self.assertFalse(os.path.exists(self.regen))

    def test_regen_folder_is_removed_when_the_run_fails(self):
        def boom(*a, **kw):
            os.makedirs(self.regen, exist_ok=True)
            raise RuntimeError("boom")
        with mock.patch.object(extract, "extract", boom), self.assertRaises(RuntimeError):
            gate.run(self.target, self.out)
        self.assertFalse(os.path.exists(self.regen))

    def test_gate_ignores_stale_cache(self):
        seen = {}
        real = extract.extract

        def spy(*a, **kw):
            seen.update(kw)
            return real(*a, **kw)
        with mock.patch.object(extract, "extract", spy), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(gate.run(self.target, self.out, workers=0), 0)
        self.assertIs(seen.get("use_cache"), False)

    def test_git_state_does_not_change_the_comparison(self):
        """target.commit, target.history and ownership Facts depend on the checkout, not the code."""
        with open(os.path.join(self.out, "facts.json"), encoding="utf-8") as fh:
            target = json.load(fh)["target"]
        self.set_facts(target={**target, "commit": "0" * 40, "history": "full"})
        res = run_gate(self.target)
        self.assertEqual(res.returncode, 0, _text(res))


class GateYamlTests(unittest.TestCase):
    def setUp(self):
        with open(YAML, encoding="utf-8") as fh:
            self.text = fh.read()

    def test_clones_the_skill_to_runner_temp_and_calls_gate_from_there(self):
        self.assertIn("$RUNNER_TEMP/appdoc-skill", self.text)
        self.assertRegex(self.text, r'python "\$RUNNER_TEMP/appdoc-skill/run_appdoc\.py" gate "\$GITHUB_WORKSPACE" --require-audit')

    def test_no_skill_clone_inside_the_workspace(self):
        self.assertNotRegex(self.text, r"^\s+path:\s*appdoc-skill", re.M)
        self.assertNotIn("working-directory: appdoc-skill", self.text)

    def test_no_hand_rolled_diff_logic(self):
        self.assertNotIn("diff -u", self.text)
        self.assertNotIn("--out \"$RUNNER_TEMP/appdoc-regen\"", self.text)

    def test_pins_a_tag(self):
        self.assertRegex(self.text, r"APPDOC_REF: v\d+\.\d+\.\d+\s")
        self.assertIn("git clone", self.text)
        self.assertIn("$APPDOC_REF", self.text)


if __name__ == "__main__":
    unittest.main()
