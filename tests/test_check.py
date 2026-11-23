import contextlib
import io
import json
import os
import re
import shutil
import tempfile
import unittest

from appdoc import check, fill
from appdoc import facts as facts_mod
from appdoc import template_spec as spec

HERE = os.path.dirname(os.path.abspath(__file__))
FIXTURES_21 = os.path.join(HERE, "fixtures", "docs-2.1")
SECRET = "Xk9fQ2mZp7LwR4tYv8NbC3dHs6JgA1eU"
STEPS = "\n".join(f"| {s} | Unknown | not in the repository |" for s in spec.RUNBOOK_STEPS)

SECTION_BODY = {
    1: "| Support need | Primary screen or file | Workflow |\n|---|---|---|\n"
       "| Service does not start | `app/main.py:2` | [7.1 Start the service](#71-start-the-service) |",
    2: "The Target is a small Python service in `app/main.py:1`. Stack: python-flask, classic-asp (unsupported, not extracted).\n\n"
       "### 2.1 What was inspected\n\n<!-- appdoc:generated scan-coverage -->\n<!-- /appdoc:generated scan-coverage -->",
    3: "- The entry module wires the handlers in `app/main.py:3-5`.\n",
    4: "<!-- appdoc:generated entry-points -->\n<!-- /appdoc:generated entry-points -->\n\n"
       "| ID | Area | Feature | Entry point | Inputs, outputs and rules | Dependencies | Status |\n"
       "|---|---|---|---|---|---|---|\n"
       "| F-1 | Service | Run | `app/main.py:2` | The `run` entry point lives in `app/main.py:2` and starts the service. | C-1 | Cited |\n\n"
       "### 4.1 Subsystem inventory\n\n"
       "| Subsystem | Files | Features | Primary data and dependencies | Purpose | Status |\n|---|---|---|---|---|---|\n"
       "| `app/` | 1 | F-1 | C-1 | Holds the service code in `app/main.py:1` | Cited |",
    5: "### 5.1 Observed role concepts\n\n- An admin role is named at `app/main.py:4`.\n\n"
       "### 5.2 Authorization enforcement\n\n- The admin check is made at `app/main.py:4`.\n\n"
       "### 5.3 Role-to-capability matrix\n\n| Capability | admin |\n|---|---|\n| Service: change settings, see `app/main.py:4` | Y |\n\n"
       + spec.RESTRICTION_LINE,
    6: "- The landing page is rendered by `app/main.py:5` for visitors.\n\n"
       "| ID | Page | Route or entry | Reached from | Visible controls and data | States and effects | Roles and evidence |\n"
       "|---|---|---|---|---|---|---|\n"
       "| UI-1 | Landing | / | direct | Welcome text | Static | everyone, `app/main.py:5` |",
    7: "### 7.1 Start the service\n1. Operators launch the entry point in `app/main.py:2` and wait.\n"
       "2. Failure and escalation: restart once, as `app/main.py:2` exits on error.",
    8: "### 8.1 Connections\n\n| ID | Name | Kind | Configured at | Used by |\n|---|---|---|---|---|\n"
       "| C-1 | db | database | `app/main.py:6`, value omitted | F-1 |\n\n"
       "### 8.2 Stored procedures and SQL\n\n- No SQL is used; the ORM call is at `app/main.py:7`.\n\n"
       "### 8.3 External calls\n\n| ID | Call | Direction | Caller | Notes |\n|---|---|---|---|---|\n"
       "| X-1 | Health ping | Outbound | `app/main.py:8` | none |\n\n"
       "### 8.4 Data entities and sensitivity\n\n| Entity | Key fields | Defined at | Sensitivity |\n|---|---|---|---|\n"
       "| Post | id | `app/main.py:9` | public |\n\n"
       "### 8.5 Failure, fallback and observability\n\n"
       "| ID | Timeout and retry | On failure | Observability |\n|---|---|---|---|\n"
       "| C-1 | none, see `app/main.py:6` | startup fails | none |\n"
       "| X-1 | none, see `app/main.py:8` | logged | none |",
    9: "| Symptom | Checks | Known response | Escalate when |\n|---|---|---|---|\n"
       "| Service will not start | Look at `app/main.py:2` | Restart the process | Twice in a row |",
    10: "### 10.1 Verified findings\n\n| ID | Severity | Finding | Evidence | Impact |\n|---|---|---|---|---|\n"
        "| V-1 | High | A password is set in code | `app/main.py:6`; value omitted. | Credential exposure |\n\n"
        "### 10.2 Unknowns that must not be treated as controls\n\n"
        "| Control | Status | Where looked |\n|---|---|---|\n| TLS | Not established | `app/main.py:7` |",
    11: "| Area | Evidence | Status |\n|---|---|---|\n| Business owner | `appdoc-context.md:1` | Cited |\n"
        + "\n".join(f"| {r} | not in the repository | Unknown |" for r in spec.OWNERSHIP_ROWS[1:]) + "\n"
        "| Test suite | none | Unknown |",
    12: "```mermaid\nflowchart LR\n  A --> B\n```",
    13: "| Term | Meaning | Citation |\n|---|---|---|\n| Handler | a function | `app/main.py:3` |",
    14: "| ID | Question | Why it matters | How to close | Owner | Priority |\n|---|---|---|---|---|---|\n"
        "| Q-1 | Unknown: who deploys the service | Releases | Ask the team | Unknown | Medium |",
    15: "| ID | Severity | Effort | Recommendation | Addresses |\n|---|---|---|---|---|\n"
        "| R-1 | High | S | Move the password out of `app/main.py:6` and enforce TLS | V-1, TLS |\n\n"
        "### 15.1 Coverage summary\n\n- Sections 3 to 10 were audited against `app/main.py:1`.",
    16: "### 16.1 Platform requirements\n\n- Python, see `app/main.py:1`.\n\n"
        "### 16.2 Data stores\n\n- The database configured at `app/main.py:6`.\n\n"
        "### 16.3 Session and authentication behavior\n\n- No sessions; see `app/main.py:4`.\n\n"
        "### 16.4 Known failure modes and operator responses\n\n"
        "| Failure mode | Signal | Operator response |\n|---|---|---|\n| Crash | exit | restart, `app/main.py:2` |\n\n"
        "### 16.5 Deployment and change process\n\n| Step | Procedure | Evidence |\n|---|---|---|\n" + STEPS + "\n\n"
        "### 16.6 Configuration reference\n\n"
        "<!-- appdoc:generated config-reference -->\n<!-- /appdoc:generated config-reference -->\n\n"
        "### 16.7 Scheduled and background jobs\n\n"
        "<!-- appdoc:generated scheduled-jobs -->\n<!-- /appdoc:generated scheduled-jobs -->",
}

APPENDIX = ("## Appendix A. Evidence Register and Verification\n\n"
            "<!-- appdoc:generated appendix-a -->\n<!-- /appdoc:generated appendix-a -->")

AUDIT = {"type": "audit", "performed": True, "auditor": "independent", "scope": "an independent read of the cited source"}
ROWS = [
    {"id": "E-1", "ref": "10.1/V-1", "claim": "A password is set in code", "result": "Supported",
     "cites": ["app/main.py:6"], "anchor": "line 6", "limitation": "value not shown"},
    {"id": "E-2", "ref": "7.1", "claim": "Operators launch the entry point", "result": "Supported",
     "cites": ["app/main.py:2"], "anchor": "line 2", "limitation": "none"},
]


def build_doc(override=None):
    override = override or {}
    parts = ["# Demo Documentation", spec.STAMP, "<!-- a comment `nope/missing.py:99` -->", ""]
    for n, title in enumerate(check.SECTIONS, 1):
        parts += [f"## {n}. {title}", "", override.get(n, SECTION_BODY[n]), ""]
    parts += [APPENDIX, ""]
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
                         [{"kind": "connection", "path": "app/main.py", "line": 6, "name": "db", "detail": {}},
                          {"kind": "file", "path": "app/main.py", "line": None, "name": "app/main.py", "detail": {}},
                          {"kind": "entry_point", "stack": "python-flask", "path": "app/main.py", "line": 2,
                           "name": "run", "detail": {"type": "route", "method": "GET"}},
                          {"kind": "entry_point", "stack": "python-flask", "path": "app/main.py", "line": 8,
                           "name": "nightly", "detail": {"type": "job", "schedule": "0 2 * * *", "enabled": True}}])
        self.write_register(AUDIT, ROWS)
        self.write_provenance()
        self.base_facts = list(self.facts["facts"])

    def with_facts(self, *extra):
        """facts.json = the base Facts plus these."""
        self.write_facts(self.facts["stacks"], self.base_facts + list(extra))

    @staticmethod
    def smell(fid, line, path="app/main.py", **detail):
        return {"kind": "smell", "stack": "python-flask", "path": path, "line": line, "name": f"candidate {fid}",
                "detail": {"pattern": "hardcoded-credential-constant", "fid": fid, **detail}}

    @staticmethod
    def entry(path, kind="route", line=1, **detail):
        return {"kind": "entry_point", "stack": "python-flask", "path": path, "line": line,
                "name": f"{kind}@{line}", "detail": {"type": kind, **detail}}

    @staticmethod
    def rules(report):
        return set(re.findall(r"^## (C\d+) ", report, re.M))

    def write_context(self, text):
        with open(os.path.join(self.target, "appdoc-context.md"), "w") as fh:
            fh.write(text)

    def write_facts(self, stacks, facts):
        self.facts = {"stacks": stacks, "facts": facts}
        with open(os.path.join(self.out, "facts.json"), "w") as fh:
            json.dump(self.facts, fh)

    def write_register(self, audit, rows):
        with open(os.path.join(self.out, check.REGISTER), "w") as fh:
            fh.write("\n".join(json.dumps(r) for r in [audit] + list(rows)) + "\n")

    def fill_doc(self, doc):
        return fill.fill_text(doc, self.facts, {"out_dir": self.out, "target": self.target})[0]

    def run_check(self, doc, filled=True, require_audit=False, strict=False, seal=True):
        if filled:
            doc = self.fill_doc(doc)
        with open(os.path.join(self.out, "application-documentation.md"), "w") as fh:
            fh.write(doc)
        if seal:
            # strip existing claim_sha so each call gets a fresh seal against the current doc
            reg_path = os.path.join(self.out, check.REGISTER)
            if os.path.isfile(reg_path):
                with open(reg_path, encoding="utf-8") as fh:
                    lines = fh.readlines()
                with open(reg_path, "w", encoding="utf-8") as fh:
                    for line in lines:
                        try:
                            obj = json.loads(line)
                            if isinstance(obj, dict) and obj.get("type") != "audit":
                                obj.pop("claim_sha", None)
                                line = json.dumps(obj, ensure_ascii=False) + "\n"
                        except (ValueError, TypeError):
                            pass
                        fh.write(line)
            check.seal_register(self.target, self.out)
        buf = io.StringIO()
        with contextlib.redirect_stdout(buf):
            code = check.run(self.target, self.out, require_audit, strict)
        with open(os.path.join(self.out, "check-report.md")) as fh:
            report = fh.read()
        return code, report, buf.getvalue()

    def fired(self, doc, **kw):
        code, report, _ = self.run_check(doc, **kw)
        rules = set(re.findall(r"^## (C\d+) ", report, re.M))
        self.assertEqual(code, 2 if rules else 0, report)
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
        self.assertEqual(self.fired(build_doc().replace("`app/main.py:5` for visitors", "`app/main.py:500` for visitors")), {"C1"})

    def _swap(self, new):
        return build_doc().replace("`app/main.py:5` for visitors", new + " for visitors")

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

    def _spaced_file(self):
        os.makedirs(os.path.join(self.target, "To be deleted", "Front Dev"))
        with open(os.path.join(self.target, "To be deleted", "Front Dev", "logcall.asp"), "w") as fh:
            fh.write("\n".join(f"call {i}" for i in range(1, 21)) + "\n")

    def test_c1_spaced_path_with_a_line_resolves(self):
        self._spaced_file()
        self.assertEqual(self.fired(self._swap("`To be deleted/Front Dev/logcall.asp:12`")), set())

    def test_c1_spaced_path_that_is_missing_or_out_of_range_fails(self):
        self._spaced_file()
        code, report, _ = self.run_check(self._swap("`To be deleted/Front Dev/nope.asp:12`"))
        self.assertEqual(code, 2)
        self.assertIn("does not exist in the Target", report)
        code, report, _ = self.run_check(self._swap("`To be deleted/Front Dev/logcall.asp:99`"))
        self.assertEqual(code, 2)
        self.assertIn("line 99 is outside", report)

    def test_c1_dotfile_and_data_file_citations_resolve(self):
        for name in (".gitignore", "test.db"):
            with open(os.path.join(self.target, name), "w") as fh:
                fh.write("a\nb\nc\n")
        self.assertEqual(self.fired(self._swap("`.gitignore:2` and `test.db:3`")), set())
        self.assertEqual(self.fired(self._swap("`.dockerignore:2`")), {"C1"})

    def test_c1_lined_citation_into_binary_file_fails(self):
        with open(os.path.join(self.target, "blob.png"), "wb") as fh:
            fh.write(b"\x00\x01\x02\x03")
        code, report, _ = self.run_check(self._swap("`blob.png:1`"))
        self.assertEqual(code, 2)
        self.assertIn("binary file", report)

    def test_c1_bare_citation_into_binary_file_resolves(self):
        with open(os.path.join(self.target, "blob.png"), "wb") as fh:
            fh.write(b"\x00\x01\x02\x03")
        self.assertEqual(self.fired(self._swap("`blob.png`")), set())

    def test_c11_anchor_in_a_spaced_path(self):
        self._spaced_file()
        row = dict(ROWS[0], cites=["To be deleted/Front Dev/logcall.asp:3-4"], anchor="call 3")
        self.write_register(AUDIT, [row, ROWS[1]])
        self.assertEqual(self.fired(build_doc()), set())
        self.write_register(AUDIT, [dict(row, anchor="call 9"), ROWS[1]])
        code, report, _ = self.run_check(build_doc())
        self.assertIn("anchor not found", report)
        self.write_register(AUDIT, [dict(row, cites=["To be deleted/Front Dev/missing.asp:3"]), ROWS[1]])
        code, report, _ = self.run_check(build_doc())
        self.assertIn("does not resolve", report)

    def test_c1_escape(self):
        self.assertEqual(self.fired(build_doc().replace("`app/main.py:5` for visitors", "`../outside.py:1` for visitors")), {"C1"})

    def test_c2(self):
        doc = build_doc().replace("`app/main.py:6`; value omitted.", "`app/main.py`; value omitted.")
        self.assertEqual(self.fired(doc), {"C2"})

    def _write_narrative(self, doc):
        with open(os.path.join(self.out, "application-documentation.md"), "w") as fh:
            fh.write(doc)

    def test_c11_claim_sha_unsealed_fails(self):
        code, report, _ = self.run_check(build_doc(), seal=False)
        self.assertEqual(code, 2)
        self.assertIn("not sealed", report)

    def test_c11_claim_sha_sealed_passes(self):
        self._write_narrative(build_doc())
        self.assertEqual(check.seal_register(self.target, self.out), 2)
        self.assertEqual(self.fired(build_doc()), set())

    def test_c11_claim_sha_stale_fails(self):
        self._write_narrative(build_doc())
        self.assertEqual(check.seal_register(self.target, self.out), 2)
        # change the text of the V-1 finding row so the sealed sha no longer matches
        doc = build_doc().replace("A password is set in code", "A secret is set in code")
        code, report, _ = self.run_check(doc, seal=False)
        self.assertEqual(code, 2)
        self.assertIn("changed after it was audited", report)

    # --- 2.7: superseded rows (append-only register)

    def run27(self, doc=None, **kw):
        """Check a document stamped 2.7 (the running template patched to 2.7 for the call)."""
        from unittest import mock
        doc = (doc or build_doc()).replace(spec.STAMP, "<!-- appdoc:template 2.7 -->")
        with mock.patch.object(spec, "TEMPLATE_VERSION", "2.7"):
            self.run_check(doc, **kw)                        # seals the register (sealed_by is printed in A.1) ...
            return self.run_check(doc, seal=False, **kw)     # ... so fill again, as `build` does, and check

    SECOND_V1 = {"id": "E-3", "ref": "10.1/V-1", "claim": "A password is set in code (re-read)",
                 "result": "Corrected", "cites": ["app/main.py:6"], "anchor": "line 6", "limitation": "none"}

    def test_c11_two_live_rows_fail_with_supersedes_fix(self):
        self.write_register(AUDIT, ROWS + [self.SECOND_V1])
        code, report, _ = self.run27()
        self.assertEqual(code, 2, report)
        self.assertIn("C11", self.rules(report))
        self.assertIn("two live rows for 10.1/V-1. Fix: "
                      'add "supersedes": "E-1" to the newer row; do not delete the older row', report)
        # the same register passes once the newer row supersedes the older one
        self.write_register(AUDIT, ROWS + [dict(self.SECOND_V1, supersedes="E-1")])
        code, report, _ = self.run27()
        self.assertEqual(code, 0, report)

    def test_c11_superseded_row_is_not_sealed_anchored_or_counted_for_coverage(self):
        old = dict(ROWS[0], anchor="text that is gone now")   # would fail the anchor rule were it live
        self.write_register(AUDIT, [old, ROWS[1], dict(self.SECOND_V1, supersedes=["E-1"])])
        code, report, _ = self.run27()
        self.assertEqual(code, 0, report)
        with open(os.path.join(self.out, check.REGISTER), encoding="utf-8") as fh:
            rows = {json.loads(l).get("id"): json.loads(l) for l in fh if l.strip()}
        self.assertNotIn("claim_sha", rows["E-1"])           # a superseded row is not sealed
        self.assertIn("claim_sha", rows["E-3"])

    def test_c11_superseded_rows_keep_id_ref_result_and_cites_validation(self):
        old = dict(ROWS[0], result="Fine", cites=["app/nope.py:1"])
        self.write_register(AUDIT, [old, ROWS[1], dict(self.SECOND_V1, supersedes="E-1")])
        code, report, _ = self.run27()
        self.assertEqual(code, 2, report)
        self.assertIn("result 'Fine' is not one of", report)
        self.assertIn("citation does not resolve", report)

    def test_c11_supersedes_unknown_or_cycle_fails(self):
        cases = {
            "E-9": "supersedes E-9, which is not a row of this register",
            "E-2": "supersedes E-2, which has the ref 7.1, not 10.1/V-1",
        }
        for target_id, msg in cases.items():
            self.write_register(AUDIT, ROWS + [dict(self.SECOND_V1, supersedes=target_id)])
            code, report, _ = self.run27()
            self.assertEqual(code, 2, report)
            self.assertIn(msg, report)
        # a cycle: E-1 and E-3 supersede each other
        self.write_register(AUDIT, [dict(ROWS[0], supersedes="E-3"), ROWS[1], dict(self.SECOND_V1, supersedes="E-1")])
        code, report, _ = self.run27()
        self.assertEqual(code, 2, report)
        self.assertIn("supersedes form a cycle", report)
        # a row may not supersede itself
        self.write_register(AUDIT, [dict(ROWS[0], supersedes="E-1"), ROWS[1]])
        self.assertIn("supersedes form a cycle", self.run27()[1])

    def _audited(self, **extra):
        """A register whose line 1 carries the full audit provenance for the document under test."""
        doc27 = build_doc().replace(spec.STAMP, "<!-- appdoc:template 2.7 -->")
        rec = dict(AUDIT, audited_on="2026-11-23", audited_with="2.7.0", audited_bundle="0123456789ab",
                   doc_sha=check.doc_sha(self.fill_doc(doc27)), **extra)
        self.write_register(rec, ROWS)

    def test_c17_require_audit_needs_provenance(self):
        code, report, _ = self.run27(require_audit=True)           # line 1 has none of the four fields
        self.assertEqual(code, 2, report)
        self.assertIn("C17", self.rules(report))
        self.assertIn("the audit record lacks audited_on, audited_with, audited_bundle, doc_sha", report)
        self.assertIn("appdoc seal --audit --date YYYY-MM-DD", report)
        self.write_register(dict(AUDIT, audited_on="2026-11-23", doc_sha="0" * 12), ROWS)
        self.assertIn("lacks audited_with, audited_bundle.", self.run27(require_audit=True)[1])
        self._audited()
        code, report, _ = self.run27(require_audit=True)
        self.assertEqual(code, 0, report)
        # without --require-audit the fields are not demanded, and a 2.4 document is never asked for them
        self.write_register(AUDIT, ROWS)
        self.assertEqual(self.run27()[0], 0)
        self.assertEqual(self.run_check(build_doc(), require_audit=True)[0], 0)

    def test_c17_strict_fails_on_upgrade_seal(self):
        self.write_register(dict(AUDIT, audited_on="2026-11-23", audited_with="2.7.0",
                                 audited_bundle="0123456789ab", doc_sha="0" * 12), ROWS)   # a doc_sha for other text
        code, report, _ = self.run27(require_audit=True, strict=True)
        self.assertEqual(code, 2, report)
        self.assertIn("C17", self.rules(report))
        self.assertIn("E-1 was sealed at upgrade; its text was not re-audited", report)
        self.assertIn("E-2 was sealed at upgrade", report)
        self.assertIn("appdoc seal --audit", report)
        # not strict: the upgrade seal is reported in Appendix A, not failed
        self.assertEqual(self.run27(require_audit=True)[0], 0)
        # audited rows pass under strict
        self._audited()
        code, report, _ = self.run27(require_audit=True, strict=True)
        self.assertEqual(code, 0, report)

    def test_c12_c10_and_verification_read_live_rows(self):
        """T27.19: a superseded row is history; it no longer dismisses a candidate, names a register id or counts."""
        self.with_facts(self.smell("aaaa0009", 9))
        old = {"id": "E-3", "ref": "smell/aaaa0009", "claim": "A fixture constant, not a credential",
               "result": "Dismissed", "cites": ["app/main.py:9"], "anchor": "line 9", "limitation": "test fixture"}
        self.write_register(AUDIT, ROWS + [old])
        self.assertEqual(self.run27()[0], 0)                       # live: the dismissal counts
        # E-4 replaces the dismissal with one that gives no reason: the candidate is no longer dismissed
        self.write_register(AUDIT, ROWS + [old, dict(old, id="E-4", limitation="", supersedes="E-3")])
        code, report, _ = self.run27()
        self.assertEqual(code, 2, report)
        self.assertIn("C12", self.rules(report))
        self.assertIn("smell aaaa0009", report)
        # prose may not cite a superseded row, and says what replaced it
        self.with_facts()
        self.write_register(AUDIT, ROWS + [dict(self.SECOND_V1, supersedes="E-1")])
        doc = build_doc().replace("- The entry module wires", "- See E-1 for the first audit. The entry module wires")
        code, report, _ = self.run27(doc)
        self.assertEqual(code, 2, report)
        self.assertIn("C10", self.rules(report))
        self.assertIn("E-1 is superseded by E-3", report)
        code, report, _ = self.run27()
        self.assertEqual(code, 0, report)
        self.assertIn("2 rows (1 superseded):", report.split("## Verification")[1])

    def test_c11_2_4_document_keeps_the_old_duplicate_message(self):
        self.write_register(AUDIT, ROWS + [self.SECOND_V1])
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(code, 2, report)
        self.assertIn("two rows for the same ID ref 10.1/V-1", report)
        self.assertIn("keep the row that describes the current text", report)

    def test_c3_missing_section(self):
        doc = build_doc().replace("## 13. Glossary", "## 13. Terms")
        self.assertEqual(self.fired(doc), {"C3"})

    def test_c3_empty_and_placeholder(self):
        self.assertIn("C3", self.fired(build_doc({12: ""})))
        self.assertEqual(self.fired(build_doc({12: "<fill me> TODO"})), {"C3"})

    def test_c3_missing_stamp_is_one_upgrade_problem(self):
        code, report, _ = self.run_check(build_doc().replace(spec.STAMP, ""))
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C3"})
        self.assertIn("not on template 2.4", report)
        code, report, _ = self.run_check(build_doc().replace(spec.STAMP, "<!-- appdoc:template 2.1 -->"))
        self.assertIn("(stamp: 2.1)", report)

    def test_c4_unknown_without_gaps(self):
        doc = build_doc({14: ""}).replace(
            SECTION_BODY[13], SECTION_BODY[13] + "\n\n- Unknown: the owner of `app/main.py:3`.")
        self.assertIn("C4", self.fired(doc))

    def test_c4_section8_empty(self):
        self.assertIn("C4", self.fired(build_doc({8: ""})))

    def test_c8_missing_subsection(self):
        doc = build_doc().replace("### 15.1 Coverage summary", "### Coverage summary")
        code, report, _ = self.run_check(doc)
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C8"})
        self.assertIn("subsection 15.1", report)

    def test_c8_empty_subsection(self):
        doc = build_doc().replace("- No SQL is used; the ORM call is at `app/main.py:7`.", "")
        code, report, _ = self.run_check(doc)
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C8"})
        self.assertIn("subsection 8.2", report)

    def test_c8_subsection_outside_parent_does_not_count(self):
        doc = build_doc().replace("### 15.1 Coverage summary", "### 14.9 Coverage summary")
        self.assertEqual(self.fired(doc), {"C8"})

    def test_c8_ignores_fenced_heading(self):
        doc = build_doc().replace("### 8.2 Stored procedures and SQL", "```\n### 8.2 x\n```\n### 8.9 other")
        self.assertEqual(self.fired(doc), {"C8"})

    def test_c5(self):
        doc = build_doc().replace("- The landing page is rendered by `app/main.py:5` for visitors.",
                                  "- The landing page is rendered for every single visitor of the site.")
        self.assertEqual(self.fired(doc), {"C5"})

    def test_c5_exemptions(self):
        extra = ("Notes follow:\n\nShort line.\n\n```\nunfenced claim claim claim claim claim claim claim\n```\n\n"
                 "- **Inferred:** the service is tiny and has a single entry point module only.\n"
                 "- Unknown whether the service has any other entry point modules anywhere.")
        self.assertEqual(self.fired(build_doc({3: extra})), set())

    def test_c6_secret_shape_line_only(self):
        doc = build_doc().replace("A password is set in code", f"Config uses password={SECRET}")
        code, report, out = self.run_check(doc)
        self.assertEqual(code, 2)
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C6"})
        self.assertNotIn(SECRET, report)
        self.assertNotIn(SECRET, out)
        self.assertRegex(report, r"- line \d+: secret-shaped value")

    def test_c6_scans_the_register(self):
        rows = [dict(ROWS[0], limitation=f"password={SECRET}"), ROWS[1]]
        self.write_register(AUDIT, rows)
        code, report, out = self.run_check(build_doc())
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C6"})
        self.assertIn("evidence.jsonl secret-shaped value", report)
        self.assertNotIn(SECRET, report + out)

    def test_c6_never_mention(self):
        self.write_context("# Context\n\n```never-mention\ninternal-host-7\n```\n")
        doc = build_doc().replace("- The entry module wires", "- INTERNAL-HOST-7: the entry module wires")
        self.assertEqual(self.fired(doc), {"C6"})

    def test_c7(self):
        doc = self.fill_doc(build_doc().replace("classic-asp (unsupported, not extracted)", "nothing else"))
        self.write_facts(self.facts["stacks"] + [{"name": "go", "detail": {"supported": False}}], self.facts["facts"])
        code, report, _ = self.run_check(doc, filled=False)
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C7"})
        self.assertIn("unsupported stack 'go'", report)
        self.assertEqual(self.fired(doc), set())  # the refreshed block names every Stack

    def test_c7_retired_candidate_must_be_named_in_section_2(self):
        doc = self.fill_doc(build_doc())
        self.write_facts(self.facts["stacks"], self.facts["facts"])
        self.facts["target"] = {"scan": {"retired_candidates": [{"path": "old/", "signal": "name", "files": 3}]}}
        with open(os.path.join(self.out, "facts.json"), "w") as fh:
            json.dump(self.facts, fh)
        code, report, _ = self.run_check(doc, filled=False)
        self.assertIn("C7", set(re.findall(r"^## (C\d+) ", report, re.M)))
        self.assertIn("folder 'old' looks retired", report)
        # naming it in section 2 clears the problem
        doc2 = self.fill_doc(build_doc().replace("### 2.1 What was inspected",
                                                 "The `old/` folder looks retired and is documented as live.\n\n### 2.1 What was inspected"))
        self.write_facts(self.facts["stacks"], self.facts["facts"])
        self.facts["target"] = {"scan": {"retired_candidates": [{"path": "old/", "signal": "name", "files": 3}]}}
        with open(os.path.join(self.out, "facts.json"), "w") as fh:
            json.dump(self.facts, fh)
        self.assertNotIn("looks retired", self.run_check(doc2, filled=False)[1])

    def _dup_facts(self):
        for d in ("alpha", "beta"):
            os.makedirs(os.path.join(self.target, d), exist_ok=True)
        self.write_facts(self.facts["stacks"], self.facts["facts"])
        self.facts["target"] = {"scan": {"duplicate_folders": [{"a": "alpha/", "b": "beta/", "files": 5}]}}
        with open(os.path.join(self.out, "facts.json"), "w") as fh:
            json.dump(self.facts, fh)

    def test_c7_duplicate_pair_advisory(self):
        self._dup_facts()
        doc = self.fill_doc(build_doc())
        code, report, out = self.run_check(doc, filled=False)
        self.assertEqual(code, 0, report)
        self.assertNotIn("C7", self.rules(report))
        self.assertIn("## Duplicate folders not named in section 2 (advisory)", report)
        self.assertIn("`alpha/` and `beta/` (5 files)", report)
        self.assertIn("Advisory: 1 duplicate folder pair is not named in section 2", out)
        # strict fails it as C7
        code, report, _ = self.run_check(doc, filled=False, strict=True)
        self.assertEqual(code, 2, report)
        self.assertIn("C7", self.rules(report))
        self.assertIn("folders 'alpha' and 'beta' duplicate each other but are not both named in section 2", report)
        # naming both folders in section 2 clears it, advisory and strict
        named = self.fill_doc(build_doc().replace(
            "### 2.1 What was inspected",
            "The `alpha/` and `beta/` folders are byte-identical; `beta/` is the live copy.\n\n### 2.1 What was inspected"))
        code, report, _ = self.run_check(named, filled=False, strict=True)
        self.assertNotIn("duplicate", report.lower().replace("duplicate defined", ""))
        self.assertEqual(self.rules(report) & {"C7"}, set(), report)

    def test_c7_content_signal_retired_is_advisory_only(self):
        doc = self.fill_doc(build_doc())
        self.write_facts(self.facts["stacks"], self.facts["facts"])
        self.facts["target"] = {"scan": {"retired_candidates": [{"path": "images/", "signal": "content", "files": 9}]}}
        with open(os.path.join(self.out, "facts.json"), "w") as fh:
            json.dump(self.facts, fh)
        code, report, _ = self.run_check(doc, filled=False)
        self.assertNotIn("looks retired", report)

    def test_c7_skipped_without_facts(self):
        doc = self.fill_doc(build_doc())
        os.remove(os.path.join(self.out, "facts.json"))
        self.assertEqual(self.fired(doc, filled=False), set())

    def write_provenance(self, **over):
        from appdoc import version
        prov = {**version.provenance(), **over}
        with open(os.path.join(self.out, "provenance.json"), "w") as fh:
            json.dump(prov, fh)
        return prov

    def test_c7_skew_reads_provenance(self):
        from appdoc import __version__
        doc = self.fill_doc(build_doc())
        major, minor, *_ = __version__.split(".")
        gen = f"{int(major) + 1}.{minor}.0"
        self.write_provenance(generator=gen)
        code, report, _ = self.run_check(doc, filled=False)
        self.assertIn("C7", self.rules(report))
        self.assertIn(f"facts.json was written by AppDoc {gen}; re-run extract", report)
        self.assertEqual(code, 2)

    def test_c7_skew_compares_numerically(self):
        # 2.10 is newer than 2.9: a string compare of major.minor must not matter, only equality does
        doc = self.fill_doc(build_doc())
        self.write_provenance(generator="2.10.0")
        self.assertIn("C7", self.rules(self.run_check(doc, filled=False)[1]))

    def test_c7_version_skew_ignores_patch_difference(self):
        from appdoc import __version__
        doc = self.fill_doc(build_doc())
        major, minor, *_ = __version__.split(".")
        self.write_provenance(generator=f"{major}.{minor}.99", bundle="0" * 12)
        code, report, _ = self.run_check(doc, filled=False)
        self.assertNotIn("re-run extract", report)
        self.assertNotIn("C7", self.rules(report))
        self.assertEqual(code, 0, report)

    def test_c7_missing_provenance_is_an_advisory(self):
        doc = self.fill_doc(build_doc())
        os.remove(os.path.join(self.out, "provenance.json"))
        code, report, _ = self.run_check(doc, filled=False)
        self.assertEqual(code, 0, report)
        self.assertNotIn("C7", self.rules(report))
        self.assertIn("## Provenance missing (advisory)", report)
        self.assertIn("provenance.json", report.split("## Provenance missing (advisory)")[1])

    def test_c7_provenance_schema_mismatch_fails(self):
        doc = self.fill_doc(build_doc())
        self.write_facts(self.facts["stacks"], self.facts["facts"])
        self.facts["schema"] = facts_mod.SCHEMA
        with open(os.path.join(self.out, "facts.json"), "w") as fh:
            json.dump(self.facts, fh)
        self.write_provenance(schema="appdoc-facts/5")
        code, report, _ = self.run_check(doc, filled=False)
        self.assertIn("C7", self.rules(report))
        self.assertIn(f"provenance.json schema appdoc-facts/5 does not match facts.json schema {facts_mod.SCHEMA}", report)
        self.assertEqual(code, 2)
        self.write_provenance(schema=facts_mod.SCHEMA)
        code, report, _ = self.run_check(doc, filled=False)
        self.assertEqual(code, 0, report)

    def test_check_report_prints_running_version(self):
        from appdoc import __version__
        code, report, _ = self.run_check(build_doc())
        self.assertIn(f"Run by AppDoc {__version__}", report)

    def test_c7_stale_and_missing_generated_block(self):
        doc = self.fill_doc(build_doc())
        self.write_facts(self.facts["stacks"], self.facts["facts"] + [
            {"kind": "file", "path": "lib/x.py", "line": None, "name": "lib/x.py", "detail": {}}])
        code, report, _ = self.run_check(doc, filled=False)
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C7"})
        self.assertIn("'scan-coverage' differs from the Facts", report)
        doc = build_doc().replace("<!-- appdoc:generated scan-coverage -->\n<!-- /appdoc:generated scan-coverage -->", "x")
        self.assertIn("C7", self.fired(doc))

    def test_c7_subsystem_count_must_match_facts(self):
        doc = build_doc().replace("| `app/` | 1 |", "| `app/` | 3 |")
        code, report, _ = self.run_check(doc)
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C7"})
        self.assertIn("the Facts count 1", report)
        self.assertEqual(self.fired(build_doc().replace("| `app/` | 1 |", "| `app/` | 13 (9) |")), {"C7"})

    # --- C9 Tables conform

    def test_c9_row_cell_count(self):
        doc = build_doc().replace("| Handler | a function | `app/main.py:3` |", "| Handler | a function | `app/main.py:3` | extra |")
        self.assertEqual(self.fired(doc), {"C9"})

    def test_c9_pipes_in_code_and_escaped_do_not_split(self):
        doc = build_doc().replace("| Handler | a function |", "| Handler | a `x|y` function \\| more |")
        self.assertEqual(self.fired(doc), set())

    def test_c9_header_must_match_spec(self):
        doc = build_doc().replace("| Symptom | Checks | Known response | Escalate when |",
                                  "| Symptom | Checks | Response | Escalate when |")
        self.assertEqual(self.fired(doc), {"C9"})

    def test_c9_enumerated_values(self):
        self.assertEqual(self.fired(build_doc().replace("| V-1 | High |", "| V-1 | Severe |")), {"C9"})
        self.assertEqual(self.fired(build_doc().replace("| TLS | Not established |", "| TLS | Missing |")), {"C9"})

    def test_c9_id_format(self):
        self.assertIn("C9", self.fired(build_doc().replace("| UI-1 |", "| S1 |")))

    def test_c9_required_runbook_rows(self):
        doc = build_doc().replace("| Rollback | Unknown | not in the repository |\n", "")
        code, report, _ = self.run_check(doc)
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C9"})
        self.assertIn("16.5 has no 'Rollback' row", report)

    def test_c9_guidance_comment_left(self):
        doc = build_doc().replace("## 9. Troubleshooting Matrix", "## 9. Troubleshooting Matrix\n<!-- appdoc:guide fill this -->")
        self.assertEqual(self.fired(doc), {"C9"})

    def test_c9_ignores_tables_in_fences(self):
        doc = build_doc({12: "```\n| a | b |\n|---|---|\n| 1 | 2 | 3 |\n```"})
        self.assertEqual(self.fired(doc), set())

    # --- C10 References resolve

    def test_c10_undefined_id(self):
        doc = build_doc().replace("wires the handlers in", "wires the handlers (see X-9) in")
        self.assertEqual(self.fired(doc), {"C10"})

    def test_c10_ids_in_code_are_not_references(self):
        doc = build_doc().replace("wires the handlers in", "wires the `X-9` handlers in")
        self.assertEqual(self.fired(doc), set())

    def test_c10_broken_anchor(self):
        doc = build_doc().replace("(#71-start-the-service)", "(#72-stop)")
        self.assertEqual(self.fired(doc), {"C10"})

    def test_c10_duplicate_id(self):
        doc = build_doc().replace("| Q-1 | Unknown: who deploys the service | Releases | Ask the team | Unknown | Medium |",
                                  "| Q-1 | Unknown: who deploys the service | Releases | Ask the team | Unknown | Medium |\n"
                                  "| Q-1 | Unknown: who owns it | Support | Ask | Unknown | Low |")
        self.assertEqual(self.fired(doc), {"C10"})

    def test_c10_finding_without_recommendation(self):
        self.assertEqual(self.fired(build_doc().replace("| V-1, TLS |", "| TLS |")), {"C10"})

    def test_c10_control_not_addressed(self):
        self.assertEqual(self.fired(build_doc().replace("| V-1, TLS |", "| V-1 |")), {"C10"})
        doc = build_doc().replace("| V-1, TLS |", "| V-1 |").replace("who deploys the service", "who configures TLS")
        self.assertEqual(self.fired(doc), set())

    def test_c10_dependency_without_failure_row(self):
        doc = build_doc().replace("| X-1 | none, see `app/main.py:8` | logged | none |", "")
        self.assertEqual(self.fired(doc), {"C10"})

    # --- C11 Register valid

    def test_c11_missing_register_fails(self):
        os.remove(os.path.join(self.out, check.REGISTER))
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C11"})
        self.assertIn("audit state is not declared", report)

    def test_c11_declared_not_performed(self):
        self.write_register({"type": "audit", "performed": False, "scope": "time-boxed"}, [])
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(code, 0, report)
        self.assertIn("not performed (time-boxed)", report)
        self.assertEqual(self.fired(build_doc(), require_audit=True), {"C11"})

    def test_c11_anchor_must_be_in_cited_lines(self):
        self.write_register(AUDIT, [dict(ROWS[0], anchor="line 7"), ROWS[1]])
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C11"})
        self.assertIn("anchor not found", report)
        # an anchor that spans two lines is not on a single cited line: it fails
        self.write_register(AUDIT, [dict(ROWS[0], anchor="line 5 line 6", cites=["app/main.py:5-6"]), ROWS[1]])
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C11"})
        self.assertIn("anchor not found", report)
        # an anchor that is exactly one cited line passes
        self.write_register(AUDIT, [dict(ROWS[0], anchor="line 5", cites=["app/main.py:5-6"]), ROWS[1]])
        self.assertEqual(self.fired(build_doc()), set())

    def test_c11_row_rules(self):
        bad = [dict(ROWS[0], result="Fine"), dict(ROWS[1], id="E-1"),
               dict(ROWS[1], id="E-3", ref="99"), dict(ROWS[1], id="E-4", ref="10.1/V-7"),
               dict(ROWS[1], id="E-5", cites=["app/nope.py:1"]), dict(ROWS[1], id="E-6", anchor="")]
        self.write_register(AUDIT, bad)
        code, report, _ = self.run_check(build_doc())
        for needle in ("result 'Fine'", "id E-1 repeats", "ref '99'", "ref '10.1/V-7'",
                       "does not resolve", "needs an anchor"):
            self.assertIn(needle, report)

    def test_c11_mandatory_rows(self):
        self.write_register(AUDIT, [ROWS[1]])
        code, report, _ = self.run_check(build_doc())
        self.assertIn("finding V-1 has no register row", report)
        self.write_register(AUDIT, [ROWS[0]])
        code, report, _ = self.run_check(build_doc())
        self.assertIn("workflow 7.1 has no register row", report)

    def test_c11_bad_json_and_header(self):
        with open(os.path.join(self.out, check.REGISTER), "w") as fh:
            fh.write('{"id": "E-1"}\nnot json\n')
        code, report, _ = self.run_check(build_doc())
        self.assertIn("line 1 must be the audit record", report)
        self.assertIn("not valid JSON", report)

    def test_c10_register_ids(self):
        doc = build_doc().replace("wires the handlers in", "wires the handlers (E-2) in")
        self.assertEqual(self.fired(doc), set())
        self.assertEqual(self.fired(doc.replace("(E-2)", "(E-9)")), {"C10"})

    # --- template and upgrade fixtures

    def test_template_matches_spec(self):
        from appdoc import docmodel as dm
        path = os.path.join(os.path.dirname(check.__file__), "assets", "template.md")
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        self.assertIn(spec.STAMP, text)
        heads = re.findall(r"^## (\d+)\. (.+)$", text, re.M)
        self.assertEqual([int(n) for n, _ in heads], list(range(1, 17)))
        for (_, t), want in zip(heads, check.SECTIONS):
            self.assertTrue(t.startswith(want))
        for key, title in check.REQUIRED_SUBSECTIONS.items():
            self.assertRegex(text, rf"(?m)^### {re.escape(key)} {re.escape(title)}$")
        lines = dm.strip_comments(text).splitlines()
        heads = dm.headings(lines)
        for key, ts in spec.TABLES.items():
            if spec.GENERATED.get(key) not in (None, *spec.OPAQUE_BLOCKS):
                continue  # its first table is the generated one
            t = dm.first_table(lines, heads[key])
            self.assertIsNotNone(t, key)
            self.assertEqual(t.header[:len(ts.columns)], list(ts.columns), key)
        for name in spec.GENERATED.values():
            self.assertIn(f"<!-- appdoc:generated {name} -->", text)
        self.assertIn(spec.RESTRICTION_LINE, text)
        self.assertIn("## Appendix A. Evidence Register and Verification", text)
        for label in spec.OWNERSHIP_ROWS:
            self.assertIn(f"| {label} |", text)
        for c in re.findall(r"<!--.*?-->", text, re.S):
            self.assertRegex(c, r"^<!--\s*(/?appdoc:(guide|generated|template))", c[:60])
        with open(os.path.join(self.out, "application-documentation.md"), "w") as fh:
            fh.write(text)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check.run(self.target, self.out), 2)

    def test_2_1_documents_get_one_upgrade_problem(self):
        for repo in ("flaskr-tdd", "eShop"):
            with open(os.path.join(FIXTURES_21, repo, "application-documentation.md"), encoding="utf-8") as fh:
                doc = fh.read()
            code, report, _ = self.run_check(doc, filled=False)
            self.assertEqual(code, 2)
            self.assertIn("not on template 2.4 (stamp: none)", report)
            self.assertNotRegex(report, r"(?m)^## C(8|9|10|11) ")

    def test_new_rules_catch_the_2_1_defects(self):
        """Stamped as 2.4, the frozen 2.1 outputs fail on the defects the comparison found."""
        os.remove(os.path.join(self.out, check.REGISTER))
        for repo in ("flaskr-tdd", "eShop"):
            with open(os.path.join(FIXTURES_21, repo, "application-documentation.md"), encoding="utf-8") as fh:
                doc = fh.read()
            doc = doc.replace("\n", "\n" + spec.STAMP + "\n", 1)
            code, report, _ = self.run_check(doc, filled=False)
            rules = set(re.findall(r"^## (C\d+) ", report, re.M))
            self.assertTrue({"C7", "C9", "C11"} <= rules, (repo, rules))
            self.assertIn("4 table header is", report)
            self.assertIn("audit state is not declared", report)
            if repo == "flaskr-tdd":  # the malformed glossary `safe` row
                self.assertIn("table row has 4 cells but its header has 3", report)

    # --- template 2.4: entry points, 5.3 Restriction, section 11 owners, 16.7

    def test_c9_restriction_line_required(self):
        code, report, _ = self.run_check(build_doc().replace(spec.RESTRICTION_LINE, ""))
        self.assertEqual(set(re.findall(r"^## (C\d+) ", report, re.M)), {"C9"})
        self.assertIn("5.3 lacks the fixed Restriction line", report)

    def test_c9_5_3_first_column_is_capability_and_role_columns_are_free(self):
        doc = build_doc().replace("| Capability | admin |\n|---|---|\n| Service: change settings, see `app/main.py:4` | Y |",
                                  "| Capability | admin | guest |\n|---|---|---|\n| Service: change settings, see `app/main.py:4` | Y | |")
        self.assertEqual(self.fired(doc), set())
        self.assertEqual(self.fired(build_doc().replace("| Capability | admin |", "| Area | admin |")), {"C9"})

    def test_c9_required_ownership_rows(self):
        for label in spec.OWNERSHIP_ROWS:
            doc = build_doc({11: SECTION_BODY[11].replace(f"| {label} | not in the repository | Unknown |\n", "")
                             .replace(f"| {label} | `appdoc-context.md:1` | Cited |\n", "")})
            code, report, _ = self.run_check(doc)
            self.assertIn(f"11 has no '{label}' row", report)

    def test_c7_generated_block_missing_for_each_new_block(self):
        for name in ("entry-points", "scheduled-jobs", "appendix-a"):
            marks = f"<!-- appdoc:generated {name} -->\n<!-- /appdoc:generated {name} -->"
            code, report, _ = self.run_check(build_doc().replace(marks, ""))
            self.assertIn(f"generated block '{name}' is missing", report)

    def test_generated_entry_points_do_not_disturb_the_section_4_table_or_c5(self):
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(code, 0, report)
        with open(os.path.join(self.out, "application-documentation.md")) as fh:
            text = fh.read()
        self.assertIn("1 route handler file; 1 route; 0 pages; 0 commands; 1 job.", text)
        self.assertIn("| `app/main.py` | job, route | 1 | 0 | 1 | 0 |", text)

    def test_appendix_is_generated_from_the_register_in_out_dir(self):
        self.write_register({"type": "audit", "performed": False, "scope": "time-boxed"}, [])
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(code, 0, report)
        with open(os.path.join(self.out, "application-documentation.md")) as fh:
            text = fh.read()
        self.assertIn("time-boxed", text.split("## Appendix A.")[1])
        # an edit to the register after fill makes the block stale
        self.write_register(AUDIT, ROWS)
        code, report, _ = self.run_check(text, filled=False)
        self.assertIn("generated block 'appendix-a' differs from the Facts", report)

    def test_appendix_heading_is_not_a_numbered_section(self):
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(code, 0, report)
        self.assertNotIn("C3", report)

    # --- the report states what a PASS means and summarizes the audit

    def test_report_scope_and_verification_summary(self):
        code, report, out = self.run_check(build_doc())
        self.assertEqual(code, 0, report)
        self.assertIn("**Scope.**", report)
        self.assertIn("anchor text appears in the lines it cites", report)
        self.assertIn("## Verification", report)
        self.assertIn("2 rows: 2 Supported, 0 Corrected, 0 Downgraded", report)
        self.assertIn("| 10.1 | 1 of 1 |", report)
        self.assertIn("| 7 (workflows) | 1 of 1 |", report)
        self.assertIn("| 4 | 0 of 1 |", report)
        self.assertIn("## Citation register", report)
        self.assertIn("Source-to-claim audit: 2 rows (independent).", out)

    def test_register_does_not_turn_a_fail_into_a_pass(self):
        failing = build_doc().replace("`app/main.py:2` and starts", "`app/nope.py:2` and starts")
        self.assertEqual(self.fired(failing), {"C1"})

    def test_fill_command_is_idempotent(self):
        path = os.path.join(self.out, "application-documentation.md")
        with open(path, "w") as fh:
            fh.write(build_doc())
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(fill.run(self.target, self.out), 0)
            with open(path) as fh:
                once = fh.read()
            self.assertEqual(fill.run(self.target, self.out), 0)
        with open(path) as fh:
            self.assertEqual(fh.read(), once)
        self.assertIn("| python-flask | yes | 0 |", once)
        self.assertIn("| `app/` | 1 |", once)
        self.assertIn("| `app/main.py` | job, route | 1 | 0 | 1 | 0 |", once)
        self.assertIn("| nightly | `0 2 * * *` | yes | `app/main.py:8` | python-flask |", once)
        self.assertIn("### A.1 Audit state", once)
        with contextlib.redirect_stdout(io.StringIO()):
            check.seal_register(self.target, self.out)
            self.assertEqual(check.run(self.target, self.out), 0)  # what `fill` wrote is what the Check expects

    # --- C7 prose counts

    def _with_prose(self, sentence):
        return build_doc({3: SECTION_BODY[3] + f"\n- {sentence} in `app/main.py:3`."})

    def _routes(self, extra_files):
        """6 route handler files (app/main.py plus these) and 11 routes."""
        return [self.entry(f"app/h{i}.py", line=j, method="GET") for i in range(extra_files) for j in (1, 2)]

    def test_c7_prose_counts_must_match_the_facts(self):
        self.with_facts(*self._routes(5))
        code, report, _ = self.run_check(self._with_prose("The service has five controllers"))
        self.assertEqual(self.rules(report), {"C7"})
        self.assertRegex(report, r'line \d+: states "five controllers" but the Facts have 6 route handler files')
        for ok in ("six controllers", "6 route handlers", "Six Controllers", "11 routes and 11 endpoints",
                   "17 route-and-method combinations in six controllers", "1 cron tasks", "1 background jobs"):
            self.assertEqual(self.fired(self._with_prose(ok)), set(), ok)
        for bad in ("twelve endpoints", "2 cron tasks", "4 scheduled jobs", "7 routes"):
            code, report, _ = self.run_check(self._with_prose(bad))
            self.assertEqual(self.rules(report), {"C7"}, bad)
            self.assertIn(f'states "{bad}" but the Facts have', report)

    def test_c7_prose_n_of_m_passes_when_m_is_the_total(self):
        self.with_facts(*self._routes(5))
        for ok in ("3 of 11 routes shown", "3 routes of 11", "three of six controllers"):
            self.assertEqual(self.fired(self._with_prose(ok)), set(), ok)
        code, report, _ = self.run_check(self._with_prose("3 of 12 routes shown"))
        self.assertEqual(self.rules(report), {"C7"})
        self.assertIn('states "3 of 12 routes" but the Facts have 11 routes', report)
        self.assertEqual(report.count("but the Facts have"), 1)

    def test_c7_prose_counts_skip_nouns_the_facts_do_not_have(self):
        self.write_facts(self.facts["stacks"], [f for f in self.base_facts if f["name"] != "nightly"])
        self.assertEqual(self.fired(self._with_prose("Four scheduled jobs run nightly")), set())
        self.write_facts(self.facts["stacks"], [f for f in self.base_facts if f["kind"] != "entry_point"])
        self.assertEqual(self.fired(self._with_prose("Five controllers and 40 routes")), set())

    def test_c7_prose_counts_ignore_fences_other_sections_and_generated_blocks(self):
        self.with_facts(*self._routes(5))
        fenced = build_doc({3: SECTION_BODY[3] + "\n```\nfive controllers\n```"})
        self.assertEqual(self.fired(fenced), set())
        self.assertEqual(self.fired(build_doc({12: SECTION_BODY[12] + "\n\nThe diagram shows five controllers."})), set())
        code, report, _ = self.run_check(build_doc({2: SECTION_BODY[2].replace(
            "The Target is", "The Target has two controllers and is")}))
        self.assertEqual(self.rules(report), {"C7"})

    # --- C10: 5.3 coverage and the 16.6 effect table

    def test_c10_5_3_must_cover_every_section_4_area(self):
        doc = build_doc().replace("| Service: change settings,", "| Change settings,")
        code, report, _ = self.run_check(doc)
        self.assertEqual(self.rules(report), {"C10"})
        self.assertIn("5.3 does not cover the section 4 Area 'Service' (F-1)", report)
        self.assertEqual(self.fired(doc.replace("| Change settings,", "| the SERVICE settings,")), set())
        self.assertEqual(self.fired(doc.replace(spec.RESTRICTION_LINE,
                                                spec.RESTRICTION_LINE + "\n\nF-1 is the admin row.")), set())

    def test_c10_16_6_effect_table_keys_must_be_config_key_facts(self):
        self.with_facts({"kind": "config_key", "stack": "python-flask", "path": "app/main.py", "line": 3,
                         "name": "app_mode", "detail": {"role": "app"}})
        marks = "<!-- /appdoc:generated config-reference -->"
        table = "\n\n| Key | Effect | Evidence |\n|---|---|---|\n| `{}` | Switches debug output | `app/main.py:3` |"
        self.assertEqual(self.fired(build_doc().replace(marks, marks + table.format("app_mode"))), set())
        code, report, _ = self.run_check(build_doc().replace(marks, marks + table.format("app_modes")))
        self.assertEqual(self.rules(report), {"C10"})
        self.assertIn("16.6 effect table Key 'app_modes' is not a config_key Fact", report)

    # --- C11: Answerable, Dismissed, anchors

    ANSWER = {"id": "E-3", "ref": "14/Q-1", "claim": "The pipeline file names the deployer", "result": "Answerable",
              "cites": ["app/main.py:3"], "anchor": "", "limitation": ""}

    def test_c11_answerable_question_fails_until_it_is_removed(self):
        self.write_register(AUDIT, ROWS + [self.ANSWER])
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(self.rules(report), {"C11", "C14"})
        self.assertIn("Q-1 can be closed from source (app/main.py:3); close it and remove the question", report)
        closed = build_doc().replace("| Q-1 | Unknown: who deploys the service |", "| Q-2 | Unknown: who owns the service |")
        self.assertEqual(self.fired(closed), set())
        counts = self.run_check(closed)[1]
        self.assertIn("3 rows: 2 Supported, 0 Corrected, 0 Downgraded, 1 Answerable.", counts)

    def test_c11_result_and_ref_must_agree(self):
        self.with_facts(self.smell("aaaa0009", 9))
        bad = [dict(self.ANSWER, id="E-3", ref="7.1"),
               dict(self.ANSWER, id="E-4", result="Dismissed", ref="10.1/V-1", limitation="why"),
               dict(self.ANSWER, id="E-5", result="Dismissed", ref="smell/aaaa0009", limitation="  "),
               dict(self.ANSWER, id="E-6", result="Supported", ref="smell/aaaa0009", anchor="line 3")]
        self.write_register(AUDIT, ROWS + bad)
        code, report, _ = self.run_check(build_doc())
        for needle in ("an Answerable row needs ref 14/Q-<n>, not '7.1'",
                       "a Dismissed row needs ref smell/<fid>, not '10.1/V-1'",
                       "a Dismissed row needs a limitation",
                       "ref 'smell/aaaa0009' is for a Dismissed row only"):
            self.assertIn(needle, report)
        self.assertIn("one of: Supported, Corrected, Downgraded, Dismissed, Answerable",
                      self._bad_result_report())

    # --- C14: section 14 vs the register

    @staticmethod
    def _q_doc(n):
        rows = "\n".join(f"| Q-{i} | Unknown: question {i} | Why | Ask | Unknown | Medium |" for i in range(1, n + 1))
        return build_doc({14: "| ID | Question | Why it matters | How to close | Owner | Priority |\n"
                              "|---|---|---|---|---|---|\n" + rows})

    @staticmethod
    def _q_row(n, result="Supported"):
        return {"id": f"E-{n + 2}", "ref": f"14/Q-{n}", "claim": f"question {n}", "result": result,
                "cites": ["app/main.py:3"], "anchor": "line 3", "limitation": "needs owner"}

    def test_c14_answerable_in_14_fails(self):
        self.write_register(AUDIT, ROWS + [self._q_row(1, "Answerable"), self._q_row(5, "Answerable")])
        code, report, _ = self.run_check(self._q_doc(5))
        self.assertIn("C14", self.rules(report))
        self.assertIn("section 14 lists Q-5 but the audit resolved it (E-7, Answerable); "
                      "remove it from section 14 or record the answer in the row", report)

    def test_c14_a2_count_mismatch(self):
        self.write_register(AUDIT, ROWS + [self._q_row(n) for n in range(1, 15)])
        code, report, _ = self.run_check(self._q_doc(10))
        self.assertIn("| 14 | 10 of 10 |", report)
        self.assertIn("C14", self.rules(report))
        self.assertIn("Appendix A.2 states 10 unknowns have a register row but the register carries 14 Q-refs", report)

    def test_c14_uses_live_rows(self):
        # E-3 said Q-1 was answerable; E-4 supersedes it (the question needs an owner after all) and Q-1 stays
        old = self._q_row(1, "Answerable")
        new = dict(self._q_row(1), id="E-4", supersedes="E-3")
        self.write_register(AUDIT, ROWS + [old, new])
        code, report, _ = self.run_check(self._q_doc(1))
        self.assertNotIn("C14", self.rules(report), report)
        self.assertNotIn("C11", self.rules(report), report)
        # without the supersedes link the Answerable row is live and fails as before
        self.write_register(AUDIT, ROWS + [old, {k: v for k, v in new.items() if k != "supersedes"}])
        self.assertIn("C14", self.rules(self.run_check(self._q_doc(1))[1]))
        # superseded Q rows are not counted against Appendix A.2
        self.write_register(AUDIT, ROWS + [self._q_row(1), dict(self._q_row(2), id="E-9"),
                                           dict(self._q_row(2), id="E-10", supersedes="E-9")])
        self.assertNotIn("C14", self.rules(self.run_check(self._q_doc(2))[1]))

    def test_c14_partial_audit_no_false_positive(self):
        self.write_register(AUDIT, ROWS + [self._q_row(n) for n in range(1, 6)])
        code, report, _ = self.run_check(self._q_doc(10))
        self.assertIn("| 14 | 5 of 10 |", report)
        self.assertNotIn("C14", self.rules(report), report)

    def test_c14_supported_q_stays(self):
        self.write_register(AUDIT, ROWS + [self._q_row(1)])
        code, report, _ = self.run_check(self._q_doc(1))
        self.assertNotIn("C14", self.rules(report), report)

    def test_c14_clean(self):
        self.write_register(AUDIT, ROWS + [self._q_row(1), self._q_row(2)])
        code, report, _ = self.run_check(self._q_doc(2))
        self.assertNotIn("C14", self.rules(report), report)

    # --- C15: register counts in prose

    @staticmethod
    def _r_doc(n, sentence):
        rows = "\n".join(f"| R-{i} | High | S | Recommendation {i} | V-1 |" for i in range(1, n + 1))
        return build_doc({15: "| ID | Severity | Effort | Recommendation | Addresses |\n"
                              "|---|---|---|---|---|\n" + rows + "\n\n"
                              "### 15.1 Coverage summary\n\n" + sentence})

    @staticmethod
    def _r_row(n):
        return {"id": f"E-{n + 2}", "ref": f"15/R-{n}", "claim": f"recommendation {n}", "result": "Supported",
                "cites": ["app/main.py:3"], "anchor": "line 3", "limitation": "none"}

    def test_c15_stale_count_fails(self):
        # 13 R-rows in the doc, 7 R-refs in the register; the sentence is stale on both counts.
        self.write_register(AUDIT, ROWS + [self._r_row(n) for n in range(1, 8)])
        code, report, _ = self.run_check(self._r_doc(13, "The audit covered 5 of 12 recommendations."))
        self.assertIn("C15", self.rules(report))
        self.assertIn("but the document has 13 recommendations", report)

    def test_c15_correct_count_passes(self):
        # 13 R-rows, 7 R-refs; the sentence matches both the table total and the register.
        self.write_register(AUDIT, ROWS + [self._r_row(n) for n in range(1, 8)])
        code, report, _ = self.run_check(self._r_doc(13, "The audit covered 7 of 13 recommendations."))
        self.assertNotIn("C15", self.rules(report), report)

    def test_c15_base_doc_no_false_positive(self):
        # The base document has no "N of M <noun>" sentence, so C15 must not fire.
        self.write_register(AUDIT, ROWS)
        code, report, _ = self.run_check(build_doc())
        self.assertNotIn("C15", self.rules(report), report)

    # --- C16: universal claims that cite only single lines

    @staticmethod
    def _q16_doc(cite):
        return build_doc({3: SECTION_BODY[3] + f"\n- All handlers are registered in `{cite}`."})

    def test_c16_advisory_present(self):
        # A universal claim whose only citation is a single line is advisory, not a failure.
        code, report, out = self.run_check(self._q16_doc("app/main.py:3"))
        self.assertEqual(code, 0, report)
        self.assertEqual(report.splitlines()[0], "# Check: PASS")
        self.assertIn("## Universal claims cite single lines (advisory)", report)
        self.assertIn("All handlers are registered in `app/main.py:3`", report)
        self.assertNotRegex(report, r"(?m)^## C16")
        self.assertIn("Advisory: 1 universal claim cites only single lines", out)

    def test_c16_fails_under_strict(self):
        code, report, _ = self.run_check(self._q16_doc("app/main.py:3"), strict=True)
        self.assertEqual(code, 2, report)
        self.assertIn("C16", self.rules(report))
        self.assertIn("a universal claim cites only single lines", report)
        self.assertNotIn("(advisory)", report)

    def test_c16_range_cite_not_flagged(self):
        # A range citation covers the universal claim, so it is not flagged.
        code, report, out = self.run_check(self._q16_doc("app/main.py:3-5"))
        self.assertEqual(code, 0, report)
        self.assertNotIn("Universal claims cite single lines", report)
        self.assertNotIn("universal claim", out)

    # --- C20: citation precision (advisory; fails under --strict)

    def _big(self, n=200):
        with open(os.path.join(self.target, "app", "big.py"), "w") as fh:
            fh.write("\n".join(f"line {i}" for i in range(1, n + 1)) + "\n")

    def _wide_doc(self, cite, section=7):
        bodies = {
            7: "### 7.1 Start the service\n1. Operators launch the entry point in `%s` and wait.\n"
               "2. Failure and escalation: restart once, as `app/main.py:2` exits on error." % cite,
            3: "- The entry module wires the handlers in `%s`.\n" % cite,
            10: SECTION_BODY[10].replace("`app/main.py:6`; value omitted.", "`%s`; value omitted." % cite),
            4: SECTION_BODY[4].replace("| `app/main.py:2` | The `run` entry point lives in `app/main.py:2` and starts",
                                       "| run | The `run` entry point lives in `%s` and starts" % cite),
        }
        return build_doc({section: bodies[section]})

    def test_c20_constants(self):
        self.assertEqual((check.WIDE_RANGE, check.CELL_CITES), (100, 5))
        self.assertEqual(check.RULE_TITLES["C20"], "Citation precision")

    def test_c20_wide_range_is_an_advisory(self):
        self._big()
        code, report, out = self.run_check(self._wide_doc("app/big.py:1-150"))
        self.assertEqual(code, 0, report)
        self.assertEqual(report.splitlines()[0], "# Check: PASS")
        self.assertIn("## Citation precision (advisory)", report)
        self.assertIn("app/big.py:1-150", report.split("## Citation precision (advisory)")[1])
        self.assertNotIn("C20", self.rules(report))
        self.assertIn("Advisory: 1 wide range", out)

    def test_c20_range_threshold_is_over_100_lines(self):
        self._big()
        for cite, flagged in (("app/big.py:1-100", False), ("app/big.py:50-150", True),
                              ("app/big.py:1-101", True), ("app/big.py:7", False)):
            report = self.run_check(self._wide_doc(cite))[1]
            self.assertEqual("## Citation precision (advisory)" in report, flagged, cite)

    def test_c20_applies_to_sections_4_7_and_10_only(self):
        self._big()
        for section, flagged in ((3, False), (4, True), (7, True), (10, True)):
            report = self.run_check(self._wide_doc("app/big.py:1-150", section))[1]
            self.assertEqual("## Citation precision (advisory)" in report, flagged, section)

    def test_c20_a_second_lined_citation_covers_the_claim(self):
        self._big()
        doc = self._wide_doc("app/big.py:1-150").replace(
            "launch the entry point in", "launch the entry point (see `app/main.py:2`) in")
        self.assertNotIn("Citation precision", self.run_check(doc)[1])

    def test_c20_generated_blocks_are_not_flagged(self):
        self._big()
        self.with_facts(self.entry("app/big.py", line=1))
        report = self.run_check(build_doc())[1]
        self.assertNotIn("Citation precision", report)

    def test_c20_fails_under_strict(self):
        self._big()
        code, report, _ = self.run_check(self._wide_doc("app/big.py:1-150"), strict=True)
        self.assertEqual(code, 2, report)
        self.assertIn("C20", self.rules(report))
        self.assertNotIn("(advisory)", report.split("## Citation register")[0].split("C20")[0])

    def test_c20_cell_with_more_than_five_citations(self):
        cites = lambda n: ", ".join(f"`app/main.py:{i}`" for i in range(1, n + 1))
        for n, flagged in ((5, False), (6, True)):
            doc = build_doc({4: SECTION_BODY[4].replace("| C-1 | Cited |\n\n### 4.1",
                                                        f"| C-1, {cites(n)} | Cited |\n\n### 4.1")})
            report = self.run_check(doc)[1]
            self.assertEqual("## Citation precision (advisory)" in report, flagged, n)
        self.assertIn("cites 6 sources", report)
        doc = build_doc({10: SECTION_BODY[10].replace("`app/main.py:6`; value omitted.", cites(6))})
        self.assertIn("## Citation precision (advisory)", self.run_check(doc)[1])

    def test_c20_cell_limit_does_not_apply_to_other_sections(self):
        cites = ", ".join(f"`app/main.py:{i}`" for i in range(1, 8))
        doc = build_doc({9: SECTION_BODY[9].replace("Look at `app/main.py:2`", f"Look at {cites}")})
        self.assertNotIn("Citation precision", self.run_check(doc)[1])

    def test_c20_cell_fails_under_strict(self):
        cites = ", ".join(f"`app/main.py:{i}`" for i in range(1, 7))
        doc = build_doc({10: SECTION_BODY[10].replace("`app/main.py:6`; value omitted.", cites)})
        code, report, _ = self.run_check(doc, strict=True)
        self.assertEqual(code, 2, report)
        self.assertIn("C20", self.rules(report))

    # --- previews of template 2.7 rules (advisory, never a failure on 2.4)

    PREVIEW = "## Template 2.7 previews (advisory)"

    def _sev_doc(self):
        return build_doc({15: SECTION_BODY[15].replace(
            "| R-1 | High | S |", "| R-0 | Low | S | Tidy the module | V-1 |\n| R-1 | High | S |")})

    def test_preview_c9_severity_order(self):
        code, report, out = self.run_check(self._sev_doc())
        self.assertEqual(code, 0, report)
        part = report.split(self.PREVIEW)[1]
        self.assertIn("C9", part)
        self.assertIn("R-1", part)
        self.assertIn("fails from template 2.7", part)
        self.assertIn("move the row; keep its ID", part)
        self.assertNotIn("C9", self.rules(report))
        self.assertIn("fail from template 2.7", out)

    def test_preview_c9_10_1_severity_order(self):
        doc = build_doc({10: SECTION_BODY[10].replace(
            "| V-1 | High |", "| V-1 | Low |").replace(
            "\n\n### 10.2", "\n| V-2 | High | Another | `app/main.py:6` | Exposure |\n\n### 10.2")})
        rows = [ROWS[0], ROWS[1], dict(ROWS[0], id="E-3", ref="10.1/V-2")]
        self.write_register(AUDIT, rows)
        doc = doc.replace("| V-1, TLS |", "| V-1, V-2, TLS |")
        code, report, _ = self.run_check(doc)
        self.assertIn("V-2", report.split(self.PREVIEW)[1])
        self.assertNotIn("C9", self.rules(report))

    def test_preview_in_order_clean_document_has_no_preview_section(self):
        self.write_register(dict(AUDIT, scope="the cited source"), ROWS)
        self.assertNotIn(self.PREVIEW, self.run_check(build_doc())[1])

    def test_preview_c1_bare_name_prints_the_full_path(self):
        doc = build_doc().replace("`app/main.py:5` for visitors", "`main.py:5` for visitors")
        code, report, _ = self.run_check(doc)
        self.assertEqual(code, 0, report)
        part = report.split(self.PREVIEW)[1]
        self.assertIn("C1", part)
        self.assertIn("`main.py` is a bare name", part)
        self.assertIn("`app/main.py`", part)
        self.assertIn("fails from template 2.7", part)
        self.assertNotIn("C1", self.rules(report))

    def test_preview_c1_root_and_known_bare_files_are_allowed(self):
        with open(os.path.join(self.target, "app", "Procfile"), "w") as fh:
            fh.write("web: run\n")
        doc = build_doc().replace("`app/main.py:5` for visitors", "`Procfile` and `appdoc-context.md:1` for visitors")
        report = self.run_check(doc)[1]
        self.assertNotIn("bare name", report)

    def test_preview_c17_scope_with_ids_or_digits(self):
        for scope, flagged in (("sections 3-10", True), ("covers E-4 only", True),
                               ("an independent read of the cited source", False)):
            self.write_register(dict(AUDIT, scope=scope), ROWS)
            report = self.run_check(build_doc())[1]
            self.assertEqual(self.PREVIEW in report and "C17" in report.split(self.PREVIEW)[1], flagged, scope)
            if flagged:
                self.assertIn("describe only the method; coverage is computed", report)
                self.assertIn("fails from template 2.7", report)

    def test_previews_never_fail_a_2_4_document_even_under_strict(self):
        doc = self._sev_doc().replace("`app/main.py:5` for visitors", "`main.py:5` for visitors")
        self.write_register(dict(AUDIT, scope="sections 3-10"), ROWS)
        code, report, _ = self.run_check(doc, strict=True)
        self.assertEqual(code, 0, report)
        part = report.split(self.PREVIEW)[1]
        for rule in ("C1", "C9", "C17"):
            self.assertIn(rule, part)

    def test_previews_are_enforced_when_the_stamp_is_2_7(self):
        from unittest import mock
        doc = self._sev_doc().replace(spec.STAMP, "<!-- appdoc:template 2.7 -->")
        with mock.patch.object(spec, "TEMPLATE_VERSION", "2.7"):
            code, report, _ = self.run_check(doc)
        self.assertEqual(code, 2, report)
        self.assertIn("C9", self.rules(report))
        self.assertNotIn(self.PREVIEW, report)

    def _bad_result_report(self):
        self.write_register(AUDIT, [ROWS[0], dict(ROWS[1], result="Fine")])
        return self.run_check(build_doc())[1]

    def test_c11_supported_and_corrected_still_need_an_anchor(self):
        for result in ("Supported", "Corrected"):
            self.write_register(AUDIT, [ROWS[0], dict(ROWS[1], result=result, anchor="")])
            self.assertIn("needs an anchor", self.run_check(build_doc())[1])

    def test_c11_anchor_must_be_one_short_line(self):
        for anchor in ("line 6\nline 7", "line 6\r\nline 7", "line 6 " + "x" * 200):
            self.write_register(AUDIT, [dict(ROWS[0], anchor=anchor, cites=["app/main.py:6-7"]), ROWS[1]])
            report = self.run_check(build_doc())[1]
            self.assertIn("anchor must be one line of at most 200 characters", report, repr(anchor))
        self.write_register(AUDIT, [dict(ROWS[0], anchor="line 6\n", cites=["app/main.py:6"]), ROWS[1]])
        self.assertEqual(self.fired(build_doc()), set())  # a trailing newline is not a second line

    # --- C12: finding candidates

    def test_c12_candidate_cited_by_line_or_range(self):
        self.with_facts(self.smell("aaaa0006", 6))
        self.assertEqual(self.fired(build_doc()), set())
        self.with_facts(self.smell("aaaa0007", 7))
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(self.rules(report), {"C12"})
        ranged = build_doc().replace("`app/main.py:6`; value omitted.", "`app/main.py:5-7`; value omitted.")
        self.assertEqual(self.fired(ranged), set())
        self.with_facts(self.smell("aaaa0008", 8))
        self.assertEqual(self.fired(ranged), {"C12"})

    def test_c12_message_prints_the_fid_pattern_location_and_fix(self):
        self.with_facts(self.smell("aaaa0009", 9))
        code, report, out = self.run_check(build_doc())
        self.assertEqual(code, 2)
        line = ("smell aaaa0009 (hardcoded-credential-constant) at app/main.py:9 is not cited in 10.1 "
                "and not dismissed in evidence.jsonl: candidate aaaa0009")
        self.assertIn(line, report)
        self.assertIn('"ref": "smell/aaaa0009", "claim": "<why this is not a finding>", "result": "Dismissed"', report)
        self.assertIn(line, out)

    def test_c12_candidate_dismissed_in_the_register(self):
        self.with_facts(self.smell("aaaa0009", 9))
        row = {"id": "E-3", "ref": "smell/aaaa0009", "claim": "A fixture constant, not a credential",
               "result": "Dismissed", "cites": ["app/main.py:9"], "anchor": "line 9", "limitation": "test fixture"}
        self.write_register(AUDIT, ROWS + [row])
        self.assertEqual(self.fired(build_doc()), set())
        self.write_register(AUDIT, ROWS + [dict(row, limitation="")])
        self.assertEqual(self.fired(build_doc()), {"C11", "C12"})  # an unexplained dismissal does not count

    def test_c12_dismissal_of_a_candidate_that_does_not_exist(self):
        row = {"id": "E-3", "ref": "smell/ffffffff", "claim": "x", "result": "Dismissed", "cites": [],
               "anchor": "", "limitation": "why"}
        self.write_register(AUDIT, ROWS + [row])
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(self.rules(report), {"C11"})
        self.assertIn("dismisses a candidate that does not exist (smell/ffffffff)", report)

    def test_c12_without_a_register_candidates_must_still_be_cited(self):
        os.remove(os.path.join(self.out, check.REGISTER))
        self.with_facts(self.smell("aaaa0009", 9))
        self.assertEqual(self.fired(build_doc()), {"C11", "C12"})
        self.with_facts(self.smell("aaaa0006", 6))
        self.assertEqual(self.fired(build_doc()), {"C11"})

    def test_c12_ignores_candidates_in_test_files(self):
        self.with_facts(self.smell("aaaa0009", 9, path="tests/t.py", test=True), self.smell("aaaa0010", 10, test=True))
        self.assertEqual(self.fired(build_doc()), set())

    def test_c12_is_capped(self):
        self.with_facts(*[self.smell(f"{i:08x}", 1, path=f"app/s{i:02d}.py") for i in range(60)])
        report = self.run_check(build_doc())[1]
        self.assertEqual(len(re.findall(r"^- line \d+: smell ", report, re.M)), 50)
        self.assertIn("... 10 more", report)

    # --- entry points not cited: advisory and --strict

    def _entry_facts(self):
        for name in ("a.py", "b.py"):
            os.makedirs(os.path.join(self.target, "svc"), exist_ok=True)
            with open(os.path.join(self.target, "svc", name), "w") as fh:
                fh.write("pass\n")
        self.with_facts(
            self.entry("svc/a.py"), self.entry("svc/b.py", "page"), self.entry("run.py", "command"),
            *[self.entry(f"big/f{i}.py", "job") for i in range(7)],
            self.entry("tests/t.py", test=True), self.entry("svc/c.py", "handler"))

    def test_advisory_lists_uncited_entry_point_files_by_folder_without_failing(self):
        self._entry_facts()
        code, report, out = self.run_check(build_doc())
        self.assertEqual(code, 0, report)
        self.assertEqual(report.splitlines()[0], "# Check: PASS")
        self.assertIn("## Entry points not cited (advisory)", report)
        self.assertIn("10 entry point files in 3 folders not cited", report)
        self.assertIn("| `big/` | 7 | `big/f0.py`, `big/f1.py`, `big/f2.py`, `big/f3.py`, `big/f4.py` |", report)
        self.assertIn("| `svc/` | 2 | `svc/a.py`, `svc/b.py` |", report)
        self.assertIn("| `(root)` | 1 | `run.py` |", report)
        for absent in ("f5.py", "tests/t.py", "svc/c.py"):
            self.assertNotIn(absent, report)
        self.assertIn("Advisory: 10 entry point files are not cited", out)
        self.assertNotRegex(report, r"(?m)^## C13")

    def test_advisory_omits_cited_files_and_is_absent_when_empty(self):
        self._entry_facts()
        doc = build_doc({3: SECTION_BODY[3] + "\n- Both pages are served from `svc/a.py:1` and `svc/b.py:1`."})
        report = self.run_check(doc)[1]
        self.assertNotIn("`svc/`", report)
        self.assertIn("| `big/` | 7 |", report)
        self.with_facts(self.entry("svc/a.py"), self.entry("svc/b.py"))
        code, report, out = self.run_check(doc)
        self.assertNotIn("advisory", report)
        self.assertNotIn("Advisory", out)

    def test_advisory_caps_folders(self):
        self.with_facts(*[self.entry(f"d{i:02d}/x.py") for i in range(35)])
        report = self.run_check(build_doc())[1]
        self.assertEqual(len(re.findall(r"^\| `d\d\d/` \|", report, re.M)), check.FOLDER_CAP)
        self.assertIn("| 5 more folders | | |", report)

    def test_strict_fails_on_uncited_entry_points(self):
        self._entry_facts()
        code, report, out = self.run_check(build_doc(), strict=True)
        self.assertEqual(code, 2, report)
        self.assertEqual(self.rules(report), {"C13"})
        self.assertIn("## C13 Entry points not cited", report)
        self.assertIn("7 entry point files under big/ not cited (first 5: `big/f0.py`, `big/f1.py`, `big/f2.py`, "
                      "`big/f3.py`, `big/f4.py`)", report)
        self.assertIn("1 entry point file under (root) not cited", report)
        self.assertNotIn("(advisory)", report)
        self.with_facts(self.entry("svc/a.py"), self.entry("svc/b.py"))
        cited = build_doc({3: SECTION_BODY[3] + "\n- Handlers: `svc/a.py:1` and `svc/b.py:1`."})
        self.assertEqual(self.run_check(cited, strict=True)[0], 0)

    def test_check_command_has_a_strict_flag(self):
        from appdoc.__main__ import main
        self._entry_facts()
        self.run_check(build_doc())
        args = ["check", self.target, "--out", self.out]
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(main(args), 0)
            self.assertEqual(main(args + ["--strict"]), 2)

    # --- appendix-a coverage

    def test_fill_text_does_not_leak_its_text_into_the_caller_ctx(self):
        ctx = {"out_dir": self.out}
        fill.fill_text(build_doc(), self.facts, ctx)
        self.assertEqual(ctx, {"out_dir": self.out})

    def test_appendix_coverage_is_generated_idempotent_and_what_the_check_expects(self):
        path = os.path.join(self.out, "application-documentation.md")
        with open(path, "w") as fh:
            fh.write(build_doc())
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(fill.run(self.target, self.out), 0)
            with open(path) as fh:
                once = fh.read()
            self.assertEqual(fill.run(self.target, self.out), 0)
            with open(path) as fh:
                self.assertEqual(fh.read(), once)
            check.seal_register(self.target, self.out)
            self.assertEqual(check.run(self.target, self.out), 0)
        appendix = once.split("### A.2 Coverage")[1].split("### A.3")[0]
        for row in ("| 10.1 | 1 of 1 |", "| 7 (workflows) | 1 of 1 |", "| 4 | 0 of 1 |"):
            self.assertIn(row, appendix)
        # a new row changes the table; the Check demands a re-fill, and fill produces what it accepts
        self.write_register(AUDIT, ROWS + [{"id": "E-3", "ref": "4/F-1", "claim": "Run is an entry point",
                                            "result": "Supported", "cites": ["app/main.py:2"], "anchor": "line 2",
                                            "limitation": "none"}])
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check.run(self.target, self.out), 2)
            self.assertEqual(fill.run(self.target, self.out), 0)
            check.seal_register(self.target, self.out)
            self.assertEqual(check.run(self.target, self.out), 0)
        with open(path) as fh:
            self.assertIn("| 4 | 1 of 1 |", fh.read())

    # --- a Target built from the smell samples

    def test_smells_extracted_from_the_sample_files_fire_c12_until_cited_or_dismissed(self):
        from appdoc import extract
        for rel, dest in (("actuator-all/application.properties", "config/application.properties"),
                          ("flask_app.py", "app/flask_app.py")):
            os.makedirs(os.path.dirname(os.path.join(self.target, dest)), exist_ok=True)
            shutil.copyfile(os.path.join(HERE, "samples", "smells", rel), os.path.join(self.target, dest))
        found = [f for f in json.loads(extract.extract(self.target, self.out)[0])["facts"]
                 if f["kind"] == "smell" and not f["detail"].get("test")]
        patterns = {f["detail"]["pattern"] for f in found}
        self.assertTrue({"actuator-exposed", "hardcoded-credential-constant"} <= patterns, patterns)
        self.with_facts(*found)
        code, report, _ = self.run_check(build_doc())
        self.assertEqual(self.rules(report), {"C12"})
        self.assertEqual(report.count(" is not cited in 10.1 and not dismissed"), len(found))
        for f in found:
            self.assertIn(f"smell {f['detail']['fid']} ({f['detail']['pattern']}) at {f['path']}:{f['line']}", report)
        with open(os.path.join(self.target, "app", "flask_app.py")) as fh:
            n = len(fh.read().splitlines())
        cited = build_doc().replace("`app/main.py:6`; value omitted.",
                                    f"`app/main.py:6`; value omitted. See `config/application.properties:1-3` "
                                    f"and `app/flask_app.py:1-{n}`.")
        self.assertEqual(self.fired(cited), set())
        rows = [{"id": f"E-{i + 3}", "ref": f"smell/{f['detail']['fid']}", "claim": "sample value",
                 "result": "Dismissed", "cites": [f"{f['path']}:{f['line']}"], "anchor": "",
                 "limitation": "sample file"} for i, f in enumerate(found)]
        self.write_register(AUDIT, ROWS + rows)
        self.assertEqual(self.fired(build_doc()), set())


class Frozen22Tests(unittest.TestCase):
    """The v2.2 outputs of two Targets, kept as they were written."""

    def test_2_2_documents_get_one_upgrade_problem(self):
        for repo in ("flaskr-tdd", "spring-petclinic"):
            with tempfile.TemporaryDirectory() as tmp:
                out = self._copy(repo, tmp)
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(check.run(os.path.join(tmp, "target"), out), 2)
                with open(os.path.join(out, "check-report.md")) as fh:
                    report = fh.read()
            self.assertIn("not on template 2.4 (stamp: 2.2)", report)
            self.assertNotRegex(report, r"(?m)^## C(8|9|10|11) ")

    def test_restamped_2_4_still_fails_on_the_missing_blocks_sections_and_line(self):
        for repo in ("flaskr-tdd", "spring-petclinic"):
            with tempfile.TemporaryDirectory() as tmp:
                out = self._copy(repo, tmp, restamp=True)
                with contextlib.redirect_stdout(io.StringIO()):
                    self.assertEqual(check.run(os.path.join(tmp, "target"), out), 2)
                with open(os.path.join(out, "check-report.md")) as fh:
                    report = fh.read()
            rules = set(re.findall(r"^## (C\d+) ", report, re.M))
            self.assertTrue({"C7", "C8", "C9"} <= rules, (repo, rules))
            for name in ("entry-points", "scheduled-jobs", "appendix-a"):
                self.assertIn(f"generated block '{name}' is missing", report)
            self.assertIn("subsection 16.7 'Scheduled and background jobs' is missing", report)
            self.assertIn("5.3 lacks the fixed Restriction line", report)

    @staticmethod
    def _copy(repo, tmp, restamp=False):
        out = os.path.join(tmp, "target", "docs", "appdoc")
        os.makedirs(out)
        for name in ("application-documentation.md", "evidence.jsonl", "facts.json"):
            with open(os.path.join(HERE, "fixtures", "docs-2.2", repo, name), encoding="utf-8", newline="") as fh:
                text = fh.read()
            if restamp and name.endswith(".md"):
                text = text.replace("<!-- appdoc:template 2.2 -->", spec.STAMP)
            with open(os.path.join(out, name), "w", encoding="utf-8", newline="") as fh:
                fh.write(text)
        return out


class RuleRegistryTests(unittest.TestCase):
    """F2: one registry; every rule check.py can raise is in it."""

    def test_every_raised_rule_is_registered(self):
        with open(check.__file__, encoding="utf-8") as fh:
            src = fh.read()
        raised = set(re.findall(r'\badd(?:27)?\(\s*"(C\d+)"', src)) | set(re.findall(r'problems\["(C\d+)"\]', src))
        self.assertIn("C17", raised)
        self.assertEqual(sorted(raised - {r.id for r in check.RULES}), [])

    def test_rule_range_matches_registry(self):
        ids = [r.id for r in check.RULES]
        self.assertEqual(len(ids), len(set(ids)))
        self.assertEqual(check.RULE_RANGE, "C1-C" + str(max(int(i[1:]) for i in ids)))
        self.assertEqual(list(check.RULE_TITLES), ids)
        self.assertEqual(list(check.RULE_SUMMARIES), ids)
        self.assertTrue(all(r.title and r.summary for r in check.RULES))
        self.assertEqual(set(check.RULE_FLAGS), {r.id for r in check.RULES if r.flags})
        self.assertEqual(check.PREVIEW_RULES, {r.id: r.preview for r in check.RULES if r.preview})

    def test_c17_is_titled_and_summarised(self):
        self.assertTrue(check.RULE_TITLES["C17"])
        self.assertIn("C17", check.RULE_SUMMARIES)


class ConfigBlockCountTests(unittest.TestCase):
    """F3: the 16.6 count is checked by the exact block comparison; its message says which count differs."""

    @staticmethod
    def _doc(*names):
        return {"stacks": [], "facts": [{"kind": "config_key", "stack": "s", "path": "a.py", "line": i + 1, "name": n,
                                         "detail": {"role": "app"}} for i, n in enumerate(names)]}

    @staticmethod
    def _raw(body):
        return ("<!-- appdoc:generated config-reference -->\n" + body + "\n<!-- /appdoc:generated config-reference -->\n")

    def _problems(self, doc_blocks_from, facts):
        found = []
        body = fill.render_block("config-reference", doc_blocks_from)
        check._c7_blocks(self._raw(body), {}, facts, None, None, lambda *a: found.append(a))
        return [f for f in found if "config-reference" in f[2]]

    def test_c7_config_block_count_message(self):
        got = self._problems(self._doc("A"), self._doc("A", "B"))
        self.assertEqual(len(got), 1, got)
        rule, _line, msg, fix = got[0]
        self.assertEqual(rule, "C7")
        self.assertIn("2 application keys", msg)       # what the Facts expect
        self.assertIn("1 shown", msg)                  # what the block holds
        self.assertIn("appdoc fill", fix)

    def test_equal_block_raises_nothing(self):
        self.assertEqual(self._problems(self._doc("A", "B"), self._doc("A", "B")), [])

    def test_no_prose_parser_remains(self):
        self.assertFalse(hasattr(check, "_c7_config_count"))
        self.assertFalse(hasattr(check, "_CONFIG_SHOWN_RE"))


if __name__ == "__main__":
    unittest.main()
