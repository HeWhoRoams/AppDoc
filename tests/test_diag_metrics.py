"""Pins the example metrics as a regression baseline.

The 2.4 numbers are pinned against docs/diagnostic-2.4-comparison.md only (the 2.4 example folders are gone, they
remain in git history). Since 2.7.0 examples/previous holds the 2.6.0 examples and examples/current the fresh 2.7.0
run (T27.42); the 2.6.0 numbers (POST_2_6, FACTS_2_6) pin previous and the 2.7.0 numbers (POST_2_7, FACTS_2_7) pin
current. The 2.5.0 values are in docs/diagnostic-2.4-comparison.md and docs/diagnostic-2.6.0-comparison.md.
"""
import os
import unittest

from tests import diag_metrics

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
EXAMPLES = os.path.join(ROOT, "examples")
PREVIOUS = os.path.join(EXAMPLES, "previous")
CURRENT = os.path.join(EXAMPLES, "current")

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


# 2.6.0 examples (docs/diagnostic-2.6.0-comparison.md); since 2.7.0 they are examples/previous.
# name -> (check, citations, pct_cites_with_line, audit_rows, pct_supported, facts_total)
POST_2_6 = {
    "flaskr-tdd": ("PASS", 356, 86.0, 91, 87.9, 84),
    "spring-petclinic": ("PASS", 650, 95.5, 123, 83.7, 409),
    "eShop": ("PASS", 1301, 94.7, 113, 83.2, 1765),
    "gitea": ("PASS", 1284, 89.8, 141, 85.8, 19536),
}
# 2.7.0 examples (T27.42): a fresh run with a new Narrative and a new audit, so citations, audit rows and Supported %
# move; the Facts totals do not (the extractor is unchanged).
POST_2_7 = {
    "flaskr-tdd": ("PASS", 381, 86.1, 53, 79.2, 84),
    "spring-petclinic": ("PASS", 463, 91.1, 87, 86.2, 409),
    "eShop": ("PASS", 713, 90.6, 147, 93.2, 1765),
    "gitea": ("PASS", 1246, 88.7, 174, 81.6, 19536),
}
POST_2_5 = POST_2_6   # the artifact-reading test iterates the names


class DiagMetricsPost25(unittest.TestCase):
    def _m(self, name, base=PREVIOUS):
        if not os.path.isdir(os.path.join(base, name)):
            self.skipTest(f"example {name} not present under {base}")
        return diag_metrics.analyze(base, name)

    def test_reads_all_six_artifacts(self):
        for base in (PREVIOUS, CURRENT):
            for name in POST_2_5:
                with self.subTest(base=os.path.basename(base), example=name):
                    d = os.path.join(base, name)
                    if not os.path.isdir(d):
                        self.skipTest(f"example {name} not present under {base}")
                    for art in ARTIFACTS:
                        self.assertTrue(os.path.isfile(os.path.join(d, art)), art)
                    m = diag_metrics.analyze(base, name)
                    for k in KEYS:
                        self.assertIn(k, m)
                    self.assertGreater(m["words"], 0)
                    self.assertIsNotNone(m["scan"])

    def test_pinned_post_2_6_and_2_7(self):
        for pins, base in ((POST_2_6, PREVIOUS), (POST_2_7, CURRENT)):
            for name, want in pins.items():
                with self.subTest(base=os.path.basename(base), example=name):
                    m = self._m(name, base)
                    got = (m["check"], m["citations"], m["pct_cites_with_line"],
                           m["audit_rows"], m["pct_supported"], m["facts_total"])
                    self.assertEqual(got, want)

    def test_no_regression_against_previous(self):
        """examples/current (2.7.0, a fresh run) against examples/previous (2.6.0). The 2.6.0 check held Supported % and
        audit rows equal because only the generated blocks moved; a fresh Narrative and audit legitimately change
        them (a smaller, sampled audit), so those two are bounded instead of pinned equal: the Check passes, the Facts
        are the same, Supported % stays within 10 points and above 75, citations with a line within 5 points."""
        for name in POST_2_7:
            with self.subTest(example=name):
                old = self._m(name, PREVIOUS)
                new = self._m(name, CURRENT)
                self.assertEqual(new["check"], "PASS")
                self.assertEqual(new["facts_total"], old["facts_total"])
                self.assertGreaterEqual(new["pct_supported"], old["pct_supported"] - 10.0)
                self.assertGreaterEqual(new["pct_supported"], 75.0)
                self.assertGreater(new["audit_rows"], 0)
                self.assertGreaterEqual(new["pct_cites_with_line"], old["pct_cites_with_line"] - 5.0)


# Facts-level baselines the 2.6.0 work moved. Since 2.7.0 examples/previous holds the 2.6.0 examples, so FACTS_2_6
# (below) pins previous/ and FACTS_2_7 pins current/. The 2.5.0 values (retired 0/9/40/0 by content, 569 unclassified
# gitea keys, no capabilities) are in docs/diagnostic-2.6.0-comparison.md.


class DiagMetricsFactsBaseline(unittest.TestCase):

    def _b(self, name, base=PREVIOUS):
        if not os.path.isdir(os.path.join(base, name)):
            self.skipTest(f"example {name} not present under {base}")
        return diag_metrics.baselines(base, name)

    def test_pinned_facts_level_baselines(self):
        for name, want in FACTS_2_6.items():
            with self.subTest(example=name):
                got = self._b(name)
                self.assertEqual({k: got[k] for k in want}, want)

    def test_reads_both_example_layouts(self):
        """2.5.0 examples carried `generator` in facts.json; 2.6.0 and later carry provenance.json instead. The 2.5.0
        layout is rebuilt from the 2.6.0 example in a temp folder (the 2.5.0 examples are in git history)."""
        import json
        import shutil
        import tempfile
        tmp = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, tmp, True)
        for name in ("flaskr-tdd",):
            if not os.path.isdir(os.path.join(PREVIOUS, name)):
                self.skipTest("example not present")
            dst = os.path.join(tmp, name)
            shutil.copytree(os.path.join(PREVIOUS, name), dst)
            fp = os.path.join(dst, "facts.json")
            with open(fp, encoding="utf-8") as fh:
                doc = json.load(fh)
            os.remove(os.path.join(dst, "provenance.json"))
            doc["generator"] = "2.5.0"
            with open(fp, "w", encoding="utf-8") as fh:
                json.dump(doc, fh)
            old = diag_metrics.baselines(tmp, name)
            self.assertEqual(old["generator"], "2.5.0")
            doc.pop("generator")
            with open(fp, "w", encoding="utf-8") as fh:
                json.dump(doc, fh)
            with open(os.path.join(dst, "provenance.json"), "w", encoding="utf-8") as fh:
                json.dump({"generator": "2.7.0", "bundle": "0" * 12, "schema": "appdoc-facts/7"}, fh)
            new = diag_metrics.baselines(tmp, name)
            self.assertEqual(new["generator"], "2.7.0")
            self.assertEqual({k: v for k, v in new.items() if k != "generator"},
                             {k: v for k, v in old.items() if k != "generator"})


# 2.6.0 values (T26.64; examples/previous since 2.7.0): the movement the 2.6.0 plan expected against 2.5.0.
# name-signal-only retired 0; the content-signal "retired" folders of 2.5.0 became duplicate_folders pairs (eShop 4) or
# vanished (gitea 40 -> 0); capabilities non-empty; the gitea trailer dropped app.example.ini (569 keys in 4 files -> 62 in 1)
# and its secret-location count fell 276 -> 190.
FACTS_2_6 = {
    "flaskr-tdd": dict(retired_name=0, retired_content=0, duplicate_pairs=0, stacks=1,
                       secret_locations=8, not_classified=None, bare_name_cites=67, cites_total=356),
    "spring-petclinic": dict(retired_name=0, retired_content=0, duplicate_pairs=0, stacks=1,
                             secret_locations=6, not_classified=None, bare_name_cites=481, cites_total=650),
    "eShop": dict(retired_name=0, retired_content=0, duplicate_pairs=4, stacks=2,
                  secret_locations=9, not_classified=(22, 2), bare_name_cites=64, cites_total=1301),
    "gitea": dict(retired_name=0, retired_content=0, duplicate_pairs=0, stacks=3,
                  secret_locations=190, not_classified=(62, 1), bare_name_cites=101, cites_total=1284),
}

# 2.7.0 values of examples/current (T27.42). The Facts-level numbers are the 2.6.0 ones (the extractor did not move);
# only the Narrative-dependent bare_name_cites and cites_total changed with the fresh Narratives.
FACTS_2_7 = {
    "flaskr-tdd": dict(retired_name=0, retired_content=0, duplicate_pairs=0, stacks=1,
                       secret_locations=8, not_classified=None, bare_name_cites=74, cites_total=381),
    "spring-petclinic": dict(retired_name=0, retired_content=0, duplicate_pairs=0, stacks=1,
                             secret_locations=6, not_classified=None, bare_name_cites=85, cites_total=463),
    "eShop": dict(retired_name=0, retired_content=0, duplicate_pairs=4, stacks=2,
                  secret_locations=9, not_classified=(22, 2), bare_name_cites=47, cites_total=713),
    "gitea": dict(retired_name=0, retired_content=0, duplicate_pairs=0, stacks=3,
                  secret_locations=190, not_classified=(62, 1), bare_name_cites=134, cites_total=1246),
}


class DiagMetricsFacts26(unittest.TestCase):
    def _b(self, name, base=CURRENT):
        if not os.path.isdir(os.path.join(base, name)):
            self.skipTest(f"example {name} not present under {base}")
        return diag_metrics.baselines(base, name)

    def test_pinned_facts_level_baselines_2_7(self):
        for name, want in FACTS_2_7.items():
            with self.subTest(example=name):
                got = self._b(name)
                self.assertEqual({k: got[k] for k in want}, want)

    def test_expected_movement_against_previous(self):
        """2.6.0 -> 2.7.0: the extractor did not move, so every Facts-level number holds; only the Narrative-side
        counts (bare-name cites, citations) differ."""
        for name in FACTS_2_7:
            with self.subTest(example=name):
                old, new = self._b(name, PREVIOUS), self._b(name)
                self.assertEqual(new["retired_name"], 0)
                self.assertTrue(new["capabilities"], "capabilities are non-empty")
                self.assertEqual(old["capabilities"], new["capabilities"])
                for k in ("retired_content", "duplicate_pairs", "stacks", "secret_locations", "not_classified"):
                    self.assertEqual(new[k], old[k], k)

    def test_trailer_no_longer_lists_example_ini_and_nothing_scans_appdoc_output(self):
        import json
        for name in FACTS_2_6:
            with self.subTest(example=name):
                d = os.path.join(CURRENT, name)
                if not os.path.isdir(d):
                    self.skipTest("example not present")
                with open(os.path.join(d, "application-documentation.md"), encoding="utf-8") as fh:
                    text = fh.read()
                trailer = [l for l in text.splitlines() if "were not classified as application configuration" in l]
                self.assertFalse(any("app.example.ini" in l or "templates/app.ini" in l for l in trailer), trailer)
                with open(os.path.join(d, "facts.json"), encoding="utf-8") as fh:
                    doc = json.load(fh)
                self.assertFalse([f for f in doc["facts"] if f["path"].startswith("docs/appdoc")])
                self.assertFalse([f for f in doc["facts"] if f["kind"] == "ownership"
                                  and set(f.get("detail", {})) & {"author", "authors", "name", "email"}])


class CurrentExamplesAreStrictClean(unittest.TestCase):
    """examples/current is a fresh 2.7.0 run (T27.42): strict-clean provenance and a passing Check."""

    def test_register_line_1_is_an_audit_record_with_provenance_and_no_upgrade_seal(self):
        import json
        from appdoc import register
        for name in POST_2_7:
            with self.subTest(example=name):
                with open(os.path.join(CURRENT, name, "evidence.jsonl"), encoding="utf-8") as fh:
                    text = fh.read()
                first = json.loads(text.splitlines()[0])
                self.assertEqual(first.get("type"), "audit")
                self.assertIs(first.get("performed"), True)
                for key in register.AUDIT_RECORD_KEYS:       # audited_on, audited_with, audited_bundle, doc_sha
                    self.assertTrue(first.get(key), key)
                reg = register.parse(text)
                self.assertEqual(reg.errors, [])
                live = reg.live_rows()
                self.assertTrue(live)
                self.assertEqual([r["id"] for _, r in live if r.get("sealed_by") == "upgrade"], [])

    def test_check_report_says_pass(self):
        for name in POST_2_7:
            with self.subTest(example=name):
                with open(os.path.join(CURRENT, name, "check-report.md"), encoding="utf-8") as fh:
                    self.assertEqual(fh.readline().strip(), "# Check: PASS")


if __name__ == "__main__":
    unittest.main()
