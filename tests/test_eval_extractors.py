"""Extractor answer keys (plan 7.1): every corpus case and sample stack has a key; scores never fall below
eval/baseline.json; no must-not-exist Fact appears. Update the baseline deliberately with
`python eval/extractor_checks.py --update-baseline` and say why in the commit."""
import importlib.util
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("eval_extractor_checks", os.path.join(ROOT, "eval", "extractor_checks.py"))
ec = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(ec)

CORPUS = os.path.join(ROOT, "tests", "corpus")
SAMPLES = os.path.join(ROOT, "tests", "samples")


def _dirs(path):
    return sorted(d for d in os.listdir(path) if os.path.isdir(os.path.join(path, d)) and d not in ("docs", "__pycache__"))


def doc(facts=(), stacks=(), scan=None):
    return {"facts": list(facts), "stacks": list(stacks), "target": {"scan": scan or {}}}


def fact(kind="entry_point", stack="go", path="a.go", line=1, name="/x", **detail):
    return {"kind": kind, "stack": stack, "path": path, "line": line, "name": name, "detail": detail}


def pat(**kw):
    kw.setdefault("kind", "entry_point")
    kw.setdefault("stack", "go")
    return kw


class Scoring(unittest.TestCase):
    def test_pattern_matches_named_fields_and_detail_subset(self):
        f = fact(type="route", method="GET")
        self.assertTrue(ec.matches(pat(path="a.go", detail={"type": "route"}), f))
        self.assertFalse(ec.matches(pat(path="b.go"), f))
        self.assertFalse(ec.matches(pat(detail={"type": "job"}), f))
        self.assertFalse(ec.matches(pat(detail={"absent": 1}), f))

    def test_list_in_a_pattern_is_a_subset_test(self):
        f = fact(kind="stack", capabilities=["a", "b", "c"])
        self.assertTrue(ec.matches(pat(kind="stack", detail={"capabilities": ["b"]}), f))
        self.assertFalse(ec.matches(pat(kind="stack", detail={"capabilities": ["z"]}), f))

    def test_missing_fact_lowers_recall(self):
        key = {"must_exist": [pat(name="/x"), pat(name="/gone")]}
        res = ec.score_key(key, doc([fact(name="/x")]))
        self.assertEqual(res["counts"]["go/entry_point"], {"expected": 2, "found": 1, "tp": 1, "fp": 0})
        self.assertEqual([p["name"] for p in res["missing"]], ["/gone"])

    def test_exhaustive_key_counts_unlisted_fact_as_false_positive(self):
        key = {"exhaustive": True, "must_exist": [pat(name="/x")]}
        res = ec.score_key(key, doc([fact(name="/x"), fact(name="/extra", line=2)]))
        self.assertEqual(res["counts"]["go/entry_point"]["fp"], 1)
        self.assertEqual([f["name"] for f in res["unexpected"]], ["/extra"])
        quiet = ec.score_key({"must_exist": [pat(name="/x")]}, doc([fact(name="/x"), fact(name="/extra", line=2)]))
        self.assertEqual(quiet["counts"]["go/entry_point"]["fp"], 0)

    def test_must_not_exist_fact_is_forbidden(self):
        key = {"must_exist": [], "must_not_exist": [pat(kind="config_key", name="MIN_PASSWORD_LENGTH",
                                                        detail={"secret_location": True})]}
        bad = fact(kind="config_key", name="MIN_PASSWORD_LENGTH", secret_location=True)
        ok = fact(kind="config_key", name="MIN_PASSWORD_LENGTH", secret_location=False)
        self.assertEqual(len(ec.score_key(key, doc([bad]))["forbidden"]), 1)
        self.assertEqual(ec.score_key(key, doc([ok]))["forbidden"], [])

    def test_scan_entries_are_pseudo_facts(self):
        d = doc(scan={"retired_candidates": [{"path": "old/", "signal": "name", "files": 2}],
                      "duplicate_folders": [{"a": "a/", "b": "b/", "files": 5}],
                      "pruned": [{"path": "docs/appdoc/", "rule": "AppDoc output", "files": 2}]})
        key = {"must_exist": [{"kind": "retired_candidate", "stack": "scan", "path": "old/"},
                              {"kind": "duplicate_folder", "stack": "scan", "path": "a/", "name": "b/"},
                              {"kind": "pruned", "stack": "scan", "path": "docs/appdoc/", "name": "AppDoc output"}],
               "must_not_exist": [{"kind": "retired_candidate", "stack": "scan", "path": "wwwroot/"}]}
        res = ec.score_key(key, d)
        self.assertEqual(res["missing"], [])
        self.assertEqual(res["forbidden"], [])

    def test_routes_imply_a_declared_capability(self):
        stack = {"kind": "stack", "stack": "go", "path": "go.mod", "line": None, "name": "go",
                 "detail": {"supported": True, "capabilities": ["entry_point.job"]}}
        gaps = ec.capability_gaps(doc([fact(type="route")], [stack]))
        self.assertEqual(len(gaps), 1)
        self.assertIn("entry_point.route", gaps[0])
        stack["detail"]["capabilities"].append("entry_point.route")
        self.assertEqual(ec.capability_gaps(doc([fact(type="route")], [stack])), [])

    def test_regression_check(self):
        base = {"go/entry_point": {"recall": 1.0, "precision": 0.9}, "go/job": {"recall": 0.5, "precision": None}}
        cur = {"go/entry_point": {"recall": 0.9, "precision": 1.0}}
        bad = ec.regressions(base, cur)
        self.assertEqual(len(bad), 2)
        self.assertTrue(any("recall 0.9 is below the baseline 1.0" in b for b in bad))
        self.assertTrue(any("go/job" in b for b in bad))
        self.assertEqual(ec.regressions(base, {"go/entry_point": {"recall": 1.0, "precision": 0.95},
                                               "go/job": {"recall": 0.5, "precision": None}}), [])


class Keys(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.keys = ec.load_keys()

    def test_every_corpus_case_and_sample_has_a_key(self):
        targets = {k["target"] for k in self.keys.values()}
        for d in _dirs(CORPUS):
            with self.subTest(corpus=d):
                self.assertIn(f"tests/corpus/{d}", targets)
        for d in _dirs(SAMPLES):
            with self.subTest(sample=d):
                self.assertIn(f"tests/samples/{d}", targets)

    def test_every_key_names_a_real_target_and_both_lists(self):
        for case, key in self.keys.items():
            with self.subTest(case=case):
                self.assertTrue(os.path.isdir(os.path.join(ROOT, *key["target"].split("/"))), key["target"])
                self.assertIn("must_exist", key)
                self.assertIn("must_not_exist", key)
                for p in key["must_exist"] + key["must_not_exist"]:
                    self.assertIn("kind", p)
                    self.assertIn("stack", p)

    def test_false_positive_guards_are_present(self):
        text = {c: k["must_not_exist"] for c, k in self.keys.items()}
        self.assertTrue(any(p.get("name") == "MIN_PASSWORD_LENGTH" and p["detail"] == {"secret_location": True}
                            for p in text["corpus-ini-split"]))
        self.assertTrue(any(p["kind"] == "retired_candidate" and p["path"] == "wwwroot/"
                            for p in text["corpus-static-assets"]))
        caps = [p for p in self.keys["corpus-caps-routes"]["must_exist"] if p["kind"] == "stack"]
        self.assertTrue(caps and "entry_point.route" in caps[0]["detail"]["capabilities"])


class Baseline(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.results = ec.score_all()
        cls.current = ec.aggregate(cls.results)

    def test_no_regression_from_baseline(self):
        self.assertEqual(ec.regressions(ec.load_baseline(), self.current), [])

    def test_no_forbidden_facts_and_no_undeclared_capabilities(self):
        for case, res in self.results.items():
            with self.subTest(case=case):
                self.assertEqual(res["forbidden"], [])
                self.assertEqual(res["capability_gaps"], [])

    def test_baseline_covers_every_scored_row(self):
        self.assertEqual(sorted(ec.load_baseline()), sorted(self.current))

    def test_main_exits_zero_on_a_clean_tree(self):
        import contextlib
        import io
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(ec.main([]), 0)


if __name__ == "__main__":
    unittest.main()
