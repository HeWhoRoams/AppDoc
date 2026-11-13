import importlib.util
import contextlib
import io
import json
import os
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_spec = importlib.util.spec_from_file_location("eval_score", os.path.join(ROOT, "eval", "score.py"))
score = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(score)

DOC = """# Doc

## 10. Security

### 10.1 Verified findings

| ID | Finding | Evidence |
|---|---|---|
| V-1 | Distinct login errors allow username enumeration | `app.py:80-83` |
| V-2 | Cite only | `lib/a.py:5` |

### 10.2 Unknowns

Nothing.

## 16. Operations

### 16.6 Configuration reference

The KEY_ONLY_HERE setting is read at `conf/app.ini:479`.
"""


def item(**kw):
    base = {"id": "X-1", "section": "10.1", "alt_sections": [], "must_cite": "", "must_contain": [], "note": ""}
    base.update(kw)
    return base


def status(it, doc=DOC):
    return score.score_item(it, score.Document(doc))["status"]


class ScoreTests(unittest.TestCase):
    def test_present_needs_cite_and_terms_in_one_section(self):
        self.assertEqual(status(item(must_cite="app.py:81", must_contain=["enumerat"])), "Present")

    def test_partial_when_only_the_citation_holds(self):
        self.assertEqual(status(item(must_cite="lib/a.py:5", must_contain=["no such words"])), "Partial")
        self.assertEqual(status(item(must_cite="lib/a.py:5", must_contain=["KEY_ONLY_HERE"])), "Partial")

    def test_partial_when_only_the_terms_hold(self):
        self.assertEqual(status(item(must_cite="other.py:1", must_contain=["enumerat"])), "Partial")

    def test_absent_when_neither_holds(self):
        self.assertEqual(status(item(must_cite="other.py:1", must_contain=["nothing like it"])), "Absent")

    def test_line_must_be_inside_the_cited_range(self):
        self.assertEqual(status(item(must_cite="app.py:90")), "Absent")
        self.assertEqual(status(item(must_cite="app.py:80")), "Present")

    def test_key_only_in_16_6_is_not_present_for_a_10_1_item(self):
        it = item(must_cite="conf/app.ini:479", must_contain=["KEY_ONLY_HERE"])
        self.assertEqual(status(it), "Partial")
        self.assertEqual(status(dict(it, section="16.6")), "Present")
        self.assertEqual(status(dict(it, alt_sections=["16.6"])), "Present")

    def test_alternatives_and_terms_are_case_insensitive(self):
        self.assertEqual(status(item(must_contain=["nothing OR USERNAME enumeration"])), "Present")

    def test_must_not_contain_vetoes_present(self):
        self.assertNotEqual(status(item(must_contain=["enumeration"], must_not_contain=["distinct login"])), "Present")

    def test_retired_items_are_skipped_in_the_summary(self):
        res = score.score([item(must_contain=["enumeration"]), item(id="X-2", status="retired")], DOC)
        self.assertEqual(res["summary"], {"Present": 1, "Partial": 0, "Absent": 0, "Retired": 1, "scorable": 1})

    def test_answer_keys_are_well_formed(self):
        keys = os.path.join(ROOT, "eval", "answer-keys")
        for name in ("flaskr-tdd", "spring-petclinic", "eShop", "gitea"):
            with open(os.path.join(keys, name + ".json"), encoding="utf-8") as fh:
                data = json.load(fh)
            ids = [i["id"] for i in data]
            self.assertEqual(len(ids), len(set(ids)), name)
            for i in data:
                self.assertTrue({"id", "section", "alt_sections", "must_cite", "must_contain", "note"} <= set(i), i["id"])

    def test_cli_writes_result_json(self):
        with tempfile.TemporaryDirectory() as tmp:
            doc = os.path.join(tmp, "doc.md")
            with open(doc, "w", encoding="utf-8") as fh:
                fh.write(DOC)
            with contextlib.redirect_stdout(io.StringIO()):
                self.assertEqual(score.main(["flaskr-tdd", doc, "--out", tmp]), 0)
            files = [f for f in os.listdir(tmp) if f.endswith("-flaskr-tdd.json")]
            self.assertEqual(len(files), 1)


if __name__ == "__main__":
    unittest.main()
