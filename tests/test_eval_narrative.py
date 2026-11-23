"""Narrative answer keys (plan 7.1 item 3): every key scores against its committed example, never below
eval/narrative-baseline.json, and the release script calls the real eval scripts. The clone-backed run needs
APPDOC_EVAL_ROOT; without clones the eval skips with a message instead of failing."""
import contextlib
import importlib.util
import io
import json
import os
import tempfile
import unittest
from unittest import mock

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _load(name, *rel):
    spec = importlib.util.spec_from_file_location(name, os.path.join(ROOT, *rel))
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


score = _load("eval_score_all", "eval", "score.py")
release = _load("release_tool", "tools", "release.py")
EXAMPLE_KEYS = ("eShop", "flaskr-tdd", "gitea", "spring-petclinic")


def run_quiet(fn, *a, **kw):
    buf = io.StringIO()
    with contextlib.redirect_stdout(buf):
        code = fn(*a, **kw)
    return code, buf.getvalue()


class Keys(unittest.TestCase):
    def test_a_narrative_key_exists_for_every_example(self):
        keys = score.narrative_keys()
        for name in EXAMPLE_KEYS:
            with self.subTest(example=name):
                self.assertIn(name, keys)
                self.assertTrue(os.path.isfile(score.example_document(name)))

    def test_keys_are_not_trivially_small_and_ids_are_unique(self):
        for name, key in score.narrative_keys().items():
            with self.subTest(key=name):
                ids = [i["id"] for i in key]
                self.assertEqual(len(ids), len(set(ids)))
                self.assertGreaterEqual(len(key), 8, "a narrative key should hold at least 8 items")

    def test_every_item_states_what_it_verified(self):
        for name, key in score.narrative_keys().items():
            for item in key:
                with self.subTest(item=item["id"]):
                    self.assertTrue(item.get("note", "").strip())

    def test_extractor_keys_are_not_read_as_narrative_keys(self):
        self.assertFalse(any(k.startswith(("sample-", "corpus-")) for k in score.narrative_keys()))


class Baseline(unittest.TestCase):
    def test_examples_do_not_score_below_the_baseline(self):
        with open(score.NARRATIVE_BASELINE, encoding="utf-8") as fh:
            baseline = json.load(fh)
        current = score.score_examples()
        self.assertEqual(score.narrative_regressions(baseline, current), [])
        self.assertEqual(sorted(baseline), sorted(current))
        for repo in baseline:
            self.assertEqual(sorted(baseline[repo]), sorted(current[repo]), f"{repo}: re-baseline after changing a key")

    def test_regression_messages(self):
        base = {"r": {"A-1": "Present", "A-2": "Partial", "A-3": "Retired", "A-4": "Absent"}}
        cur = {"r": {"A-1": "Partial", "A-2": "Present", "A-3": "Retired"}}
        bad = score.narrative_regressions(base, cur)
        self.assertEqual(len(bad), 2, bad)
        self.assertTrue(any("A-1: Partial, was Present" in m for m in bad))
        self.assertTrue(any("A-4" in m and "no longer in the key" in m for m in bad))


class Clones(unittest.TestCase):
    def test_citation_problems(self):
        with tempfile.TemporaryDirectory() as clone:
            os.makedirs(os.path.join(clone, "src"))
            with open(os.path.join(clone, "src", "a.py"), "w", encoding="utf-8") as fh:
                fh.write("one\ntwo\nthree\n")
            key = [{"id": "X-1", "must_cite": "src/a.py:1-3"}, {"id": "X-2", "must_cite": "src/a.py:9"},
                   {"id": "X-3", "must_cite": "src/missing.py:1"}, {"id": "X-4", "must_contain": ["only terms"]}]
            bad = score.citation_problems(key, clone)
            self.assertEqual(len(bad), 2, bad)
            self.assertTrue(any("X-2" in m and "3 lines" in m for m in bad))
            self.assertTrue(any("X-3" in m and "not in the clone" in m for m in bad))

    def test_no_root_skips_with_a_message(self):
        code, out = run_quiet(score.run_all, None)
        self.assertEqual(code, 0)
        self.assertIn("narrative eval skipped", out)
        self.assertIn(score.EVAL_ROOT_ENV, out)

    def test_root_without_clones_skips_with_a_message(self):
        with tempfile.TemporaryDirectory() as empty:
            code, out = run_quiet(score.run_all, empty)
        self.assertEqual(code, 0)
        self.assertIn("narrative eval skipped", out)
        self.assertIn("no clone", out)

    def test_require_clones_fails_instead_of_skipping(self):
        code, out = run_quiet(lambda: score.run_all(None, require_clones=True))
        self.assertEqual(code, 1)
        self.assertIn(score.EVAL_ROOT_ENV, out)
        with tempfile.TemporaryDirectory() as empty:
            code, out = run_quiet(lambda: score.run_all(empty, require_clones=True))
        self.assertEqual(code, 1)
        self.assertIn("no clone of", out)

    @unittest.skipUnless(os.environ.get(score.EVAL_ROOT_ENV), "APPDOC_EVAL_ROOT is not set")
    def test_keys_hold_against_local_clones(self):
        code, out = run_quiet(score.run_all, os.environ[score.EVAL_ROOT_ENV])
        self.assertEqual(code, 0, out)


class ReleaseHooks(unittest.TestCase):
    def test_release_calls_the_real_eval_scripts(self):
        names = {label: argv[0] for label, argv in release.EVAL_HOOKS}
        self.assertEqual(names, {"extractor eval": "extractor_checks.py", "narrative eval": "score.py"})
        for script in names.values():
            self.assertTrue(os.path.isfile(os.path.join(ROOT, "eval", script)), script)
        self.assertFalse(os.path.exists(os.path.join(ROOT, "eval", "extractor_eval.py")))
        self.assertFalse(os.path.exists(os.path.join(ROOT, "eval", "narrative_eval.py")))

    def test_release_runs_both_evals_and_fails_on_either(self):
        calls = []
        real_run = release._run
        try:
            release._run = lambda label, argv: calls.append((label, argv)) or label != "narrative eval"
            old = os.environ.pop(release.EVAL_ROOT_ENV, None)
            os.environ[release.EVAL_ROOT_ENV] = "/clones"
            try:
                ok = release.run_checks()
            finally:
                os.environ.pop(release.EVAL_ROOT_ENV, None)
                if old is not None:
                    os.environ[release.EVAL_ROOT_ENV] = old
        finally:
            release._run = real_run
        labels = [c[0] for c in calls]
        self.assertIn("extractor eval", labels)
        self.assertIn("narrative eval", labels)
        self.assertFalse(ok)
        narrative = dict(calls)["narrative eval"]
        self.assertEqual(narrative[-2:], ["--root", "/clones"])
        self.assertIn("--all", narrative)

    def test_skip_narrative_eval_omits_only_that_eval_and_release_requires_clones(self):
        calls = []
        with mock.patch.object(release, "_run", lambda label, argv: calls.append((label, argv)) or True):
            self.assertTrue(release.run_checks(skip_narrative_eval=True))
            labels = [c[0] for c in calls]
            self.assertIn("extractor eval", labels)
            self.assertNotIn("narrative eval", labels)
            del calls[:]
            release.run_checks()
        self.assertIn("--require-clones", dict(calls)["narrative eval"])


if __name__ == "__main__":
    unittest.main()
