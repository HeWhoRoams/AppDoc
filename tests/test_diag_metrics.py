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


if __name__ == "__main__":
    unittest.main()
