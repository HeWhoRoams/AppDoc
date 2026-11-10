import contextlib
import io
import json
import os
import re
import tempfile
import unittest

from appdoc import check

SECRET = "Xk9fQ2mZp7LwR4tYv8NbC3dHs6JgA1eU"

SECTION_BODY = {
    1: "- See [Architecture](#3-architecture) and `app/main.py:1`.",
    2: "The Target is a small Python service in `app/main.py:1`. Stack: python-flask, classic-asp (unsupported, not extracted).",
    3: "- The entry module wires the handlers in `app/main.py:3-5`.\n",
    4: "- The `run` entry point lives in `app/main.py:2` and starts the service.",
    5: "| Role | Capability |\n|---|---|\n| admin | Can change settings, see `app/main.py:4` |",
    6: "- The landing page is rendered by `app/main.py:5` for all visitors.",
    7: "### 7.1 Start the service\n1. Operators launch the entry point in `app/main.py:2` and wait.",
    8: "- Connection settings are read at `app/main.py:6`; the value is omitted.",
    9: "| Symptom | Checks | Known response | Escalate when |\n|---|---|---|---|\n"
       "| Service will not start | Look at `app/main.py:2` | Restart the process | Twice in a row |",
    10: "- A password is set at `app/main.py:6`; value omitted.",
    11: "- Owner context is in `appdoc-context.md:1`.",
    12: "```mermaid\nflowchart LR\n  A --> B\n```",
    13: "- Handler: a function in `app/main.py:3`.",
    14: "- Unknown: who deploys the service.",
    15: "- Move the password out of `app/main.py:6` into configuration.",
    16: "- **Inferred:** deployment is manual because no scripts exist (see `app/main.py:1`).",
}


def build_doc(override=None):
    override = override or {}
    parts = ["# Demo Documentation", "<!-- a comment `nope/missing.py:99` -->", ""]
    for n, title in enumerate(check.SECTIONS, 1):
        parts += [f"## {n}. {title}", "", override.get(n, SECTION_BODY[n]), ""]
    return "\n".join(parts)


class CheckTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.target = os.path.join(self.tmp.name, "target")
        self.out = os.path.join(self.target, "docs", "appdoc")
        os.makedirs(os.path.join(self.target, "app"))
        os.makedirs(self.out)
        with open(os.path.join(self.target, "app", "main.py"), "w") as fh:
            fh.write("\n".join(f"line {i}" for i in range(1, 11)) + "\n")
        self.write_context("# Context\nOwned by someone.\n")
        self.write_facts([{"name": "python-flask", "detail": {"supported": True}},
                          {"name": "classic-asp", "detail": {"supported": False}}],
                         [{"kind": "connection", "path": "app/main.py", "line": 6, "name": "db"}])

    def write_context(self, text):
        with open(os.path.join(self.target, "appdoc-context.md"), "w") as fh:
            fh.write(text)

    def write_facts(self, stacks, facts):
        with open(os.path.join(self.out, "facts.json"), "w") as fh:
            json.dump({"stacks": stacks, "facts": facts}, fh)

    def run_check(self, doc):
        with open(os.path.join(self.out, "application-documentation.md"), "w") as fh:
            fh.write(doc)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = check.run(self.target, self.out)
        with open(os.path.join(self.out, "check-report.md")) as fh:
            report = fh.read()
        return code, report, buf.getvalue()

    def fired(self, doc):
        code, report, _ = self.run_check(doc)
        rules = set(re.findall(r"^## (C\d) ", report, re.M))
        self.assertEqual(code, 2 if rules else 0)
        return rules

    def test_pass(self):
        code, report, out = self.run_check(build_doc())
        self.assertEqual(code, 0, report)
        self.assertEqual(report.splitlines()[0], "# Check: PASS")
        self.assertIn("## Citation register", report)
        self.assertIn("| yes |", report)

    def test_missing_narrative(self):
        os.remove(os.path.join(self.out, "facts.json"))
        self.assertEqual(check.run(self.target, os.path.join(self.tmp.name, "nowhere")), 1)

    def test_c1_missing_file(self):
        self.assertEqual(self.fired(build_doc().replace("`app/main.py:2` and starts", "`app/nope.py:2` and starts")), {"C1"})

    def test_c1_line_beyond(self):
        self.assertEqual(self.fired(build_doc().replace("`app/main.py:5` for all", "`app/main.py:500` for all")), {"C1"})

    def _swap(self, new):
        return build_doc().replace("`app/main.py:5` for all", new + " for all")

    def test_c1_folder_citation_resolves(self):
        self.assertEqual(self.fired(self._swap("`app/`")), set())

    def test_c1_folder_with_line_fails(self):
        self.assertEqual(self.fired(self._swap("`app/:3`")), {"C1"})

    def test_c1_unique_bare_filename_resolves(self):
        self.assertEqual(self.fired(self._swap("`main.py:5`")), set())

    def test_c1_ambiguous_bare_filename_fails(self):
        os.makedirs(os.path.join(self.target, "other"))
        with open(os.path.join(self.target, "other", "main.py"), "w") as fh:
            fh.write("x\n")
        code, report, _ = self.run_check(self._swap("`main.py:1`"))
        self.assertEqual(code, 2)
        self.assertIn("matches 2 files", report)

    def test_c1_extensionless_nonfile_span_is_not_a_citation(self):
        code, report, _ = self.run_check(self._swap("the `dsyer/petclinic` image"))
        self.assertEqual(code, 0, report)
        self.assertNotIn("dsyer/petclinic", report)

    def test_c1_missing_file_with_extension_still_fails(self):
        self.assertEqual(self.fired(self._swap("`ghost/image.yml`")), {"C1"})

    def test_c1_escape(self):
        self.assertEqual(self.fired(build_doc().replace("`app/main.py:5` for all", "`../outside.py:1` for all")), {"C1"})

    def test_c2(self):
        doc = build_doc().replace("`app/main.py:6`; value omitted.", "`app/main.py`; value omitted.")
        self.assertEqual(self.fired(doc), {"C2"})

    def test_c3_missing_section(self):
        doc = build_doc().replace("## 13. Glossary", "## 13. Terms")
        self.assertEqual(self.fired(doc), {"C3"})

    def test_c3_empty_and_placeholder(self):
        self.assertEqual(self.fired(build_doc().replace(SECTION_BODY[13], "")), {"C3"})
        self.assertEqual(self.fired(build_doc().replace(SECTION_BODY[13], "<fill me> TODO")), {"C3"})

    def test_c4_unknown_without_gaps(self):
        doc = build_doc().replace(SECTION_BODY[14], "").replace(
            SECTION_BODY[13], SECTION_BODY[13] + "\n- Unknown: the owner of `app/main.py:3`.")
        self.assertIn("C4", self.fired(doc))

    def test_c4_section8_empty(self):
        doc = build_doc().replace(SECTION_BODY[8], "")
        self.assertIn("C4", self.fired(doc))

    def test_c5(self):
        doc = build_doc().replace(SECTION_BODY[6], "- The landing page is rendered for every single visitor of the site.")
        self.assertEqual(self.fired(doc), {"C5"})

    def test_c5_exemptions(self):
        extra = ("Notes follow:\n\nShort line.\n\n```\nunfenced claim claim claim claim claim claim claim\n```\n\n"
                 "- **Inferred:** the service is tiny and has a single entry point module only.\n"
                 "- Unknown whether the service has any other entry point modules anywhere.")
        self.assertEqual(self.fired(build_doc({3: extra})), set())

    def test_c6_secret_shape_line_only(self):
        doc = build_doc().replace(SECTION_BODY[10], f"- Config uses password={SECRET} at `app/main.py:6`.")
        code, report, out = self.run_check(doc)
        self.assertEqual(code, 2)
        self.assertEqual(set(re.findall(r"^## (C\d) ", report, re.M)), {"C6"})
        self.assertNotIn(SECRET, report)
        self.assertNotIn(SECRET, out)
        self.assertRegex(report, r"- line \d+: secret-shaped value")

    def test_c6_never_mention(self):
        self.write_context("# Context\n\n```never-mention\ninternal-host-7\n```\n")
        doc = build_doc().replace(SECTION_BODY[4], "- Calls INTERNAL-HOST-7 from `app/main.py:2` at startup.")
        self.assertEqual(self.fired(doc), {"C6"})

    def test_c7(self):
        doc = build_doc().replace("classic-asp (unsupported, not extracted)", "nothing else")
        self.assertEqual(self.fired(doc), {"C7"})

    def test_c7_skipped_without_facts(self):
        os.remove(os.path.join(self.out, "facts.json"))
        doc = build_doc().replace("classic-asp (unsupported, not extracted)", "nothing else")
        self.assertEqual(self.fired(doc), set())

    def test_template_is_valid_shape(self):
        path = os.path.join(os.path.dirname(check.__file__), "assets", "template.md")
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        heads = re.findall(r"^## (\d+)\. (.+)$", text, re.M)
        self.assertEqual([int(n) for n, _ in heads], list(range(1, 17)))
        for (_, t), want in zip(heads, check.SECTIONS):
            self.assertTrue(t.startswith(want))
        # an unfilled template must fail C3
        with open(os.path.join(self.out, "application-documentation.md"), "w") as fh:
            fh.write(text)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check.run(self.target, self.out), 2)

    # --- Resolution vs support: the report must say the Check verifies resolution, not support,
    # and carry a Verification section that reflects the (optional) source-to-claim audit record. ---

    def _write_verification(self, text):
        with open(os.path.join(self.out, check.VERIFICATION), "w") as fh:
            fh.write(text)

    def test_report_scope_statement_and_verification_section_present(self):
        code, report, out = self.run_check(build_doc())
        self.assertEqual(code, 0, report)
        # honest statement: the Check verifies resolution, not support
        self.assertIn("**Scope.**", report)
        self.assertIn("does **not** verify **support**", report)
        self.assertIn("source-to-claim audit", report)
        # the Verification section is present and the register is untouched
        self.assertIn("## Verification", report)
        self.assertIn("## Citation register", report)
        self.assertNotIn(SECRET, out)

    def test_verification_absent_notes_gap_but_does_not_fail(self):
        code, report, _ = self.run_check(build_doc())
        # no verification.md -> the gap is noted, but the Check still passes (exit 0)
        self.assertEqual(code, 0, report)
        self.assertIn("## Verification", report)
        self.assertIn("not recorded", report)
        self.assertNotIn("recorded (from `verification.md`)", report)

    def test_verification_record_embedded_when_present(self):
        self._write_verification(
            "Source-to-claim audit: 3 claims re-verified; 1 corrected.\n"
            "- Section 7: corrected a line reference.\n")
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(code, 0, report)
        self.assertIn("## Verification", report)
        self.assertIn("recorded (from `verification.md`)", report)
        self.assertIn("Source-to-claim audit: 3 claims re-verified; 1 corrected.", report)
        self.assertIn("Section 7: corrected a line reference.", report)

    def test_verification_record_does_not_change_exit_code(self):
        failing = build_doc().replace("`app/main.py:2` and starts", "`app/nope.py:2` and starts")
        code, report, _ = self.run_check(failing)
        self.assertEqual(code, 2, report)  # fails on C1 with no record
        self.assertIn("## Verification", report)
        self.assertIn("not recorded", report)
        # a present record must NOT turn a fail into a pass
        self._write_verification("Source-to-claim audit: 1 claim corrected.\n")
        code2, report2, _ = self.run_check(failing)
        self.assertEqual(code2, 2, report2)
        self.assertIn("recorded (from `verification.md`)", report2)
        self.assertIn("Source-to-claim audit: 1 claim corrected.", report2)


if __name__ == "__main__":
    unittest.main()
