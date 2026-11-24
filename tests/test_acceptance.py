"""tools/acceptance.py (T28.04): the private acceptance runner, exercised with an invented toy key."""
import contextlib
import io
import json
import os
import subprocess
import sys
import tempfile
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
sys.path.insert(0, os.path.join(ROOT, "tools"))
import acceptance  # noqa: E402

TARGET = os.path.join(HERE, "corpus", "_targets", "mvc5-classic")
TOY = os.path.join(HERE, "acceptance", "toy-key.json")
SCRIPT = os.path.join(ROOT, "tools", "acceptance.py")


def _toy_text():
    with open(TOY, encoding="utf-8") as fh:
        return fh.read()


def _env():
    env = dict(os.environ)
    env.pop(acceptance.KEYS_ENV, None)
    return env


def _main(*argv, env=None):
    out = io.StringIO()
    err = io.StringIO()
    with contextlib.redirect_stderr(err):
        code = acceptance.main(list(argv), env=_env() if env is None else env, out=out)
    return code, out.getvalue(), err.getvalue()


class Acceptance(unittest.TestCase):
    def write_key(self, tmp, rows, name="key.json"):
        path = os.path.join(tmp, name)
        with open(path, "w", encoding="utf-8") as fh:
            json.dump({"type": "acceptance", "rows": rows}, fh)
        return path

    def test_toy_key_all_rows_pass(self):
        res = subprocess.run([sys.executable, SCRIPT, "--key", TOY, "--target", TARGET], capture_output=True,
                             text=True, env=_env())
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        lines = res.stdout.strip().splitlines()
        rows = json.loads(_toy_text())["rows"]
        self.assertEqual(len(lines), len(rows) + 1, "one line per row, then a total")
        self.assertTrue(all(l.startswith("PASS TOY-") for l in lines[:-1]), res.stdout)
        self.assertIn(f"{len(rows)} of {len(rows)} rows passed or skipped; 0 failed", lines[-1])

    def test_missing_key_exits_1_with_message(self):
        code, out, err = _main("--target", TARGET)
        self.assertEqual(code, 1)
        self.assertIn("APPDOC_ACCEPTANCE_KEYS is not set", err)
        self.assertEqual(out, "")
        with tempfile.TemporaryDirectory() as tmp:
            code, out, err = _main("--target", TARGET, "--name", "nope", env={acceptance.KEYS_ENV: tmp})
        self.assertEqual(code, 1)
        self.assertIn("no answer key at", err)
        self.assertIn("nope.json", err)
        res = subprocess.run([sys.executable, SCRIPT, "--target", TARGET], capture_output=True, text=True, env=_env())
        self.assertEqual(res.returncode, 1)
        self.assertIn("APPDOC_ACCEPTANCE_KEYS", res.stderr)

    def test_key_is_read_from_the_keys_folder_by_target_name(self):
        with tempfile.TemporaryDirectory() as tmp:
            with open(os.path.join(tmp, "mvc5-classic.json"), "w", encoding="utf-8") as fh:
                fh.write(_toy_text())
            code, out, err = _main("--target", TARGET, env={acceptance.KEYS_ENV: tmp})
        self.assertEqual(code, 0, out + err)
        self.assertIn("PASS TOY-1", out)

    def test_a_failing_row_exits_1_and_prints_counts_only(self):
        with tempfile.TemporaryDirectory() as tmp:
            key = self.write_key(tmp, [
                {"id": "R-1", "desc": "present", "fact": {"kind": "stack", "name": "aspnet"}},
                {"id": "R-2", "desc": "too many", "fact": {"kind": "stack", "name": "aspnet"}, "count": 5},
                {"id": "R-3", "desc": "absent but there", "fact": {"kind": "stack", "name": "aspnet"}, "max": 0}])
            code, out, err = _main("--key", key, "--target", TARGET)
        self.assertEqual(code, 1)
        lines = out.strip().splitlines()
        self.assertTrue(lines[0].startswith("PASS R-1"), out)
        self.assertTrue(lines[1].startswith("FAIL R-2") and "expected exactly 5" in lines[1], out)
        self.assertTrue(lines[2].startswith("FAIL R-3") and "at most 0" in lines[2], out)
        self.assertIn("2 failed", lines[-1])

    def test_detail_operators_and_distinct(self):
        facts = [{"kind": "stack", "stack": "x", "path": "a", "line": None, "name": "s", "detail": {"ignored_markers": 3, "caps": ["a", "b"]}},
                 {"kind": "e", "stack": "x", "path": "p1", "line": 1, "name": "n", "detail": {"area": "A"}},
                 {"kind": "e", "stack": "x", "path": "p2", "line": 2, "name": "n", "detail": {"area": "A"}},
                 {"kind": "e", "stack": "x", "path": "p3", "line": 3, "name": "n", "detail": {}}]
        ok = lambda row: acceptance.run_row(dict(row, id="x"), facts, None)[0]   # noqa: E731
        self.assertEqual(ok({"fact": {"kind": "stack", "detail": {"ignored_markers": {"ge": 1}}}}), "PASS")
        self.assertEqual(ok({"fact": {"kind": "stack", "detail": {"ignored_markers": {"ge": 4}}}}), "FAIL")
        self.assertEqual(ok({"fact": {"kind": "stack", "detail": {"caps": ["b"]}}}), "PASS")
        self.assertEqual(ok({"fact": {"kind": "stack", "detail": {"caps": {"contains": "c"}}}}), "FAIL")
        self.assertEqual(ok({"fact": {"kind": "e", "detail": {"area": {"absent": True}}}, "count": 1}), "PASS")
        self.assertEqual(ok({"fact": {"kind": "e"}, "distinct": "detail.area", "count": 1}), "PASS")
        self.assertEqual(ok({"fact": {"kind": "e"}, "distinct": "path", "count": 3}), "PASS")
        with self.assertRaises(acceptance.KeyError_):
            acceptance.run_row({"id": "x", "fact": {"kind": "e", "detail": {"area": {"bogus": 1}}}}, facts, None)

    def test_check_rows_read_a_report_and_skip_without_one(self):
        with tempfile.TemporaryDirectory() as tmp:
            key = self.write_key(tmp, [
                {"id": "C-1", "desc": "C21 fails", "check": {"rule": "C21", "expect": "fail"}},
                {"id": "C-2", "desc": "C22 passes", "check": {"rule": "C22", "expect": "pass"}}])
            report = os.path.join(tmp, "check-report.md")
            with open(report, "w", encoding="utf-8") as fh:
                fh.write("# Check: FAIL\n\n## C21 Mandatory inputs cited\n\nsomething\n")
            code, out, _ = _main("--key", key, "--target", TARGET, "--report", report)
            self.assertEqual(code, 0, out)
            self.assertIn("PASS C-1", out)
            self.assertIn("PASS C-2", out)
            code, out, _ = _main("--key", key, "--target", TARGET)
            self.assertEqual(code, 0, out)
            self.assertEqual(sum(l.startswith("SKIP ") for l in out.splitlines()), 2)

    def test_invalid_keys_exit_1(self):
        bad = ([], {"rows": []}, {"rows": [{"desc": "no id", "fact": {}}]},
               {"rows": [{"id": "A", "fact": {}}, {"id": "A", "fact": {}}]},
               {"rows": [{"id": "A", "fact": {}, "check": {}}]})
        with tempfile.TemporaryDirectory() as tmp:
            for n, data in enumerate(bad):
                path = os.path.join(tmp, f"k{n}.json")
                with open(path, "w", encoding="utf-8") as fh:
                    json.dump(data, fh)
                code, _, err = _main("--key", path, "--target", TARGET)
                self.assertEqual(code, 1, data)
                self.assertIn("acceptance:", err)
            code, _, err = _main("--key", os.path.join(tmp, "k0.json"), "--target", os.path.join(tmp, "no-such-folder"))
            self.assertEqual(code, 1)

    def test_nothing_is_written_under_the_target(self):
        before = sorted(os.path.relpath(os.path.join(d, f), TARGET) for d, _, fs in os.walk(TARGET) for f in fs)
        code, out, err = _main("--key", TOY, "--target", TARGET)
        self.assertEqual(code, 0, out + err)
        after = sorted(os.path.relpath(os.path.join(d, f), TARGET) for d, _, fs in os.walk(TARGET) for f in fs)
        self.assertEqual(before, after)

    def test_prints_no_fact_values(self):
        code, out, _ = _main("--key", TOY, "--target", TARGET)
        for secret in ("not-a-real-password-0002", "PortalAdmins", "svcuser"):
            self.assertNotIn(secret, out)


if __name__ == "__main__":
    unittest.main()
