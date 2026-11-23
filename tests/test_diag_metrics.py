"""Pins the 2.4 example metrics (docs/diagnostic-2.4-comparison.md §1) as a regression baseline."""
import os
import unittest

from tests import diag_metrics

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXAMPLES = os.path.join(ROOT, "examples")

ARTIFACTS = (
    "application-documentation.md", "check-report.md", "evidence.jsonl",
    "facts.json", "facts-summary.md", "application-documentation.html",
)
KEYS = ("check", "citations", "audit_rows", "facts_total", "words", "scan",
        "retired_candidates")

# name -> (check, citations, pct_cites_with_line, audit_rows, pct_supported, facts_total)
BASELINE = {
    "flaskr-tdd-2.4": ("PASS", 363, 84.6, 91, 87.9, 107),
    "spring-petclinic-2.4": ("PASS", 656, 94.8, 123, 83.7, 431),
    "eShop-2.4": ("PASS", 1304, 94.2, 114, 82.5, 1707),
    "gitea-2.4": ("PASS", 1300, 88.9, 140, 85.7, 19440),
}


class DiagMetricsBaseline(unittest.TestCase):
    def _analyze(self, name):
        if not os.path.isdir(os.path.join(EXAMPLES, name)):
            self.skipTest(f"example {name} not present")
        return diag_metrics.analyze(EXAMPLES, name)

    def test_reads_all_six_artifacts(self):
        for name in BASELINE:
            with self.subTest(example=name):
                d = os.path.join(EXAMPLES, name)
                if not os.path.isdir(d):
                    self.skipTest(f"example {name} not present")
                for art in ARTIFACTS:
                    self.assertTrue(os.path.isfile(os.path.join(d, art)), art)
                m = diag_metrics.analyze(EXAMPLES, name)
                for k in KEYS:
                    self.assertIn(k, m)
                self.assertGreater(m["words"], 0)
                self.assertIsNotNone(m["scan"])

    def test_pinned_baseline(self):
        for name, want in BASELINE.items():
            with self.subTest(example=name):
                m = self._analyze(name)
                got = (m["check"], m["citations"], m["pct_cites_with_line"],
                       m["audit_rows"], m["pct_supported"], m["facts_total"])
                self.assertEqual(got, want)

    def test_baseline_matches_diagnostic_doc(self):
        """BASELINE equals docs/diagnostic-2.4-comparison.md section 1 (the doc is the source of truth)."""
        import re
        with open(os.path.join(ROOT, "docs", "diagnostic-2.4-comparison.md"), encoding="utf-8") as fh:
            text = fh.read()
        sec = text.split("## 1. Objective metrics", 1)[1].split("###", 1)[0]
        rows = {}
        for line in sec.splitlines():
            cells = [c.strip().replace("**", "") for c in line.strip().strip("|").split("|")]
            if len(cells) == 5:
                rows[cells[0]] = cells[1:]
        order = ("flaskr-tdd", "spring-petclinic", "eShop", "gitea")
        num = lambda c: int(re.sub(r"\D", "", c.split("(")[0]))
        pct = lambda c: float(re.search(r"\(([\d.]+)%\)", c).group(1))
        for i, ex in enumerate(order):
            with self.subTest(example=ex):
                got = (rows["Check"][i], num(rows["Citations (total)"][i]), pct(rows["Citations with a line"][i]),
                       num(rows["Audit rows"][i]), pct(rows["**Supported**".replace("**", "")][i]),
                       num(rows["Facts (total)"][i]))
                self.assertEqual(got, BASELINE[ex + "-2.4"])


if __name__ == "__main__":
    unittest.main()


# 2.5.0 regeneration (docs/diagnostic-2.4-comparison.md "Post-remediation (2.5.0)")
# name -> (check, citations, pct_cites_with_line, audit_rows, pct_supported, facts_total)
POST_2_5 = {
    "flaskr-tdd": ("PASS", 356, 86.0, 91, 87.9, 84),
    "spring-petclinic": ("PASS", 650, 95.5, 123, 83.7, 409),
    "eShop": ("PASS", 1298, 94.6, 113, 83.2, 1765),
    "gitea": ("PASS", 1299, 88.9, 141, 85.8, 19536),
}


class DiagMetricsPost25(unittest.TestCase):
    def _m(self, name):
        if not os.path.isdir(os.path.join(EXAMPLES, name)):
            self.skipTest(f"example {name} not present")
        return diag_metrics.analyze(EXAMPLES, name)

    def test_pinned_post_2_5(self):
        for name, want in POST_2_5.items():
            with self.subTest(example=name):
                m = self._m(name)
                got = (m["check"], m["citations"], m["pct_cites_with_line"],
                       m["audit_rows"], m["pct_supported"], m["facts_total"])
                self.assertEqual(got, want)

    def test_no_regression_against_2_4(self):
        for name in POST_2_5:
            with self.subTest(example=name):
                new = self._m(name)
                old = self._m(name + "-2.4")
                self.assertGreaterEqual(new["pct_supported"], old["pct_supported"])
                self.assertGreaterEqual(new["pct_cites_with_line"], old["pct_cites_with_line"])



# Facts-level baselines the 2.6.0 work must move, read from the committed 2.5.0 examples (T26.13).
# The 2.4 values were retired 2/9/40/0, 569 unclassified keys, bare-name cites 504/1,013 (other layout).
# Each T26.x task that moves one of these re-pins its row when the examples are regenerated (T26.64).
FACTS_2_5 = {
    "flaskr-tdd": dict(retired_name=0, retired_content=0, duplicate_pairs=0, capabilities=[], stacks=1,
                       secret_locations=8, not_classified=None, bare_name_cites=67, cites_total=356),
    "spring-petclinic": dict(retired_name=0, retired_content=0, duplicate_pairs=0, capabilities=[], stacks=1,
                             secret_locations=9, not_classified=None, bare_name_cites=481, cites_total=650),
    "eShop": dict(retired_name=0, retired_content=9, duplicate_pairs=0, capabilities=[], stacks=2,
                  secret_locations=11, not_classified=(22, 2), bare_name_cites=64, cites_total=1298),
    "gitea": dict(retired_name=0, retired_content=40, duplicate_pairs=0, capabilities=[], stacks=3,
                  secret_locations=276, not_classified=(569, 4), bare_name_cites=101, cites_total=1299),
}


class DiagMetricsFactsBaseline(unittest.TestCase):
    def _b(self, name):
        if not os.path.isdir(os.path.join(EXAMPLES, name)):
            self.skipTest(f"example {name} not present")
        return diag_metrics.baselines(EXAMPLES, name)

    def test_pinned_facts_level_baselines(self):
        for name, want in FACTS_2_5.items():
            with self.subTest(example=name):
                got = self._b(name)
                self.assertEqual({k: got[k] for k in want}, want)

    def test_reads_both_example_layouts(self):
        """2.5.0 examples carry `generator` in facts.json; 2.6.0 examples carry provenance.json instead."""
        import json
        import shutil
        import tempfile
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp, True)
        for name in ("flaskr-tdd",):
            if not os.path.isdir(os.path.join(EXAMPLES, name)):
                self.skipTest("example not present")
            dst = os.path.join(tmp, name)
            shutil.copytree(os.path.join(EXAMPLES, name), dst)
            old = diag_metrics.baselines(tmp, name)
            self.assertEqual(old["generator"], "2.5.0")
            fp = os.path.join(dst, "facts.json")
            with open(fp, encoding="utf-8") as fh:
                doc = json.load(fh)
            doc.pop("generator")
            with open(fp, "w", encoding="utf-8") as fh:
                json.dump(doc, fh)
            with open(os.path.join(dst, "provenance.json"), "w", encoding="utf-8") as fh:
                json.dump({"generator": "2.6.0", "bundle": "0" * 12, "schema": "appdoc-facts/7"}, fh)
            new = diag_metrics.baselines(tmp, name)
            self.assertEqual(new["generator"], "2.6.0")
            self.assertEqual({k: v for k, v in new.items() if k != "generator"},
                             {k: v for k, v in old.items() if k != "generator"})
