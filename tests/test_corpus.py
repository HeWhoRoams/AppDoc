"""Failure corpus: small Targets under tests/corpus/<case>/ run through extract, fill and check.

Each case folder is a Target (a few source files, optionally appdoc-context.md) plus
docs/appdoc/ holding a Narrative (application-documentation.md) and a register (evidence.jsonl).
``run_case(name)`` copies the case to a temp dir, runs ``extract``, seals the register, runs
``fill`` and ``check`` in process, and returns a ``CaseResult`` (Facts, Check report, exit code).

PENDING registry (read this before editing)
-------------------------------------------
Cases for work that has not landed yet are written to the NEW behaviour, so they fail today.
They must not break the suite, so each is listed in ``PENDING`` below as
``{test method name: (task ID, reason)}``. ``_apply_pending()`` (bottom of this module) wraps every listed test in
``unittest.expectedFailure``:

* While the behaviour is missing the test fails, which is reported as "expected failure" (OK).
* When the task lands the test passes, which unittest reports as "unexpected success" and the
  suite goes RED on purpose. The agent finishing that task then DELETES the entry from
  ``PENDING`` (nothing else changes) and the case becomes an ordinary regression test.

Never weaken an assertion to make a pending case pass; fix the production code instead.
``test_pending_entries_name_real_tests`` fails when an entry names a test that does not exist.
"""
import contextlib
import io
import json
import os
import re
import shutil
import tempfile
import unittest
from dataclasses import dataclass, field

from appdoc import check, extract, fill, seal
from tests.template_pin import run_as_2_4, run_as_stamped

HERE = os.path.dirname(os.path.abspath(__file__))
CORPUS = os.path.join(HERE, "corpus")

# test method name -> (task ID, why it fails today). Delete the entry when the task lands.
PENDING: dict = {
}


# A generator stamp from an earlier build of the running major.minor (a dev build of its .0), whatever the release.
_EARLIER_PATCH = ".".join(__import__("appdoc").__version__.split(".")[:2]) + ".0.dev0"


@dataclass
class CaseResult:
    name: str
    target: str
    out: str
    facts: dict
    report: str
    code: "int | None"
    fill_code: "int | None"
    log: str = ""
    extra: dict = field(default_factory=dict)

    def facts_of(self, kind, **detail):
        """Facts of a kind whose detail contains all the given key/value pairs."""
        return [f for f in self.facts["facts"] if f["kind"] == kind
                and all(f.get("detail", {}).get(k) == v for k, v in detail.items())]

    def rules(self):
        return set(re.findall(r"^## (C\d+) ", self.report, re.M))

    @property
    def narrative(self):
        with open(os.path.join(self.out, check.NARRATIVE), encoding="utf-8") as fh:
            return fh.read()


def run_case(name, strict=False, require_audit=False, tmp=None):
    """Copy corpus/<name> to a temp dir, then extract, seal, fill and check. Returns CaseResult.

    The temp dir is removed by the caller through ``tmp`` (a TemporaryDirectory) or leaked to the
    OS temp cleaner when none is given; tests always pass ``tmp``.
    """
    src = os.path.join(CORPUS, name)
    if not os.path.isdir(src):
        raise FileNotFoundError(f"no corpus case {name!r} under {CORPUS}")
    tmp = tmp or tempfile.TemporaryDirectory()
    target = os.path.join(tmp.name, name)
    shutil.copytree(src, target, ignore=shutil.ignore_patterns("__pycache__"))
    out = os.path.join(target, "docs", "appdoc")
    log = io.StringIO()
    fill_code = code = None
    report = ""
    with contextlib.redirect_stdout(log):
        extract.write(target, out, workers=0, use_cache=False, no_ownership=True)
        if os.path.isfile(os.path.join(out, check.NARRATIVE)):  # extract-only cases carry no Narrative
            seal.seal_register(target, out)
            fill_code = fill.run(target, out)
            with open(os.path.join(out, check.NARRATIVE), encoding="utf-8") as fh:
                narrative = fh.read()   # a 2.4 case tests a rule as the 2.4-era Check (tests/template_pin.py)
            code = run_as_stamped(narrative, check.run, target, out, require_audit, strict)
    with open(os.path.join(out, "facts.json"), encoding="utf-8") as fh:
        facts = json.load(fh)
    if code is not None:
        with open(os.path.join(out, "check-report.md"), encoding="utf-8") as fh:
            report = fh.read()
    return CaseResult(name, target, out, facts, report, code, fill_code, log.getvalue())


class CorpusCase(unittest.TestCase):
    # Tests named in PENDING are wrapped with expectedFailure at the bottom of this module.
    def case(self, name, **kw):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        return run_case(name, tmp=tmp, **kw)


def _config_block(r):
    m = re.search(r"<!-- appdoc:generated config-reference -->(.*?)<!-- /appdoc:generated config-reference -->",
                  r.narrative, re.S)
    return m.group(1) if m else ""


class Scaffold(CorpusCase):
    def test_trivial_case_runs_end_to_end(self):
        r = self.case("trivial")
        self.assertEqual(r.fill_code, 0, r.log)
        self.assertEqual(r.code, 0, r.report)
        self.assertEqual(r.report.splitlines()[0], "# Check: PASS")
        self.assertTrue(r.facts_of("file", path="app/main.py") or r.facts_of("file"), "extract emitted no file Fact")

    def test_pending_entries_name_real_tests(self):
        for name, (task, reason) in PENDING.items():
            with self.subTest(test=name):
                self.assertTrue(hasattr(CorpusCase, name) or any(
                    hasattr(c, name) for c in CorpusCase.__subclasses__()), f"{name} ({task}) is not a test")
                self.assertTrue(re.fullmatch(r"T\d\d\.\d\d", task), task)
                self.assertTrue(reason.strip())


class DoneRules(CorpusCase):
    """Rules that already exist (C14, C15, C16); these cases pin them."""

    def test_unknowns_leak_fails_c14_twice(self):
        r = self.case("unknowns-leak")
        self.assertEqual(r.code, 2, r.report)
        self.assertIn("C14", r.rules())
        self.assertIn("section 14 lists Q-5 but the audit resolved it (E-7, Answerable); "
                      "remove it from section 14 or record the answer in the row", r.report)
        # the register carries 14 Q-refs, some not defined in section 14, so C11 also reports them
        self.assertRegex(r.report, r"Appendix A\.2 states 10 unknowns have a register row "
                                   r"but the register carries \d+ Q-refs")

    def test_stale_count_fails_c15(self):
        r = self.case("stale-count")
        self.assertEqual(r.code, 2, r.report)
        self.assertIn("C15", r.rules())
        self.assertIn("but the document has 13 recommendations", r.report)

    def test_quantifier_cite_is_advisory(self):
        r = self.case("quantifier-cite")
        self.assertEqual(r.code, 0, r.report)
        self.assertIn("## Universal claims cite single lines (advisory)", r.report)
        self.assertIn("All handlers are registered in `app/main.py:3`", r.report)
        self.assertNotIn("C16", r.rules())

    def test_quantifier_cite_fails_under_strict(self):
        r = self.case("quantifier-cite", strict=True)
        self.assertEqual(r.code, 2, r.report)
        self.assertIn("C16", r.rules())
        self.assertIn("a universal claim cites only single lines", r.report)


class OpenItems(CorpusCase):
    """Written to the NEW behaviour; each is listed in PENDING until its task lands."""

    def test_config_env_roles(self):
        r = self.case("config-env")
        env = {f["name"]: f for f in r.facts_of("config_key", source="code", use="read")}
        self.assertEqual(env["DATABASE_URL"]["detail"].get("role"), "env")
        self.assertEqual(env["API_TOKEN"]["detail"].get("role"), "env")
        self.assertEqual(env["DEBUG"]["detail"].get("role"), "app")
        self.assertFalse(env["API_TOKEN"]["detail"].get("secret_location"), "an env-var read is not an app secret")

    def test_config_env_reference_block(self):
        r = self.case("config-env")
        block = _config_block(r)
        self.assertIn("| DEBUG |", block)
        self.assertNotIn("DATABASE_URL", block.split("env-var keys")[0])
        self.assertNotIn("API_TOKEN", block.split("env-var keys")[0])
        self.assertIn("2 env-var keys and 0 CI keys are excluded from the application table", block)

    def test_owner_absent_advisory(self):
        r = self.case("owner-absent")
        self.assertEqual(r.code, 0, r.report)
        self.assertFalse(r.facts_of("owner_file"))
        self.assertIn("ownership is Unknown by absence", r.report)
        self.assertIn("deployment runbook is Unknown by absence", r.report)

    def test_razor_page_is_a_ui_page(self):
        r = self.case("razor-ui")
        pages = r.facts_of("ui_page", root="Pages/Orders.razor", route="/orders")
        self.assertEqual(len(pages), 1, r.facts_of("ui_page"))

    def test_ef_dbset_and_query_are_data_access(self):
        r = self.case("ef-data")
        sets = r.facts_of("data_access", type="ef", operation="set")
        queries = r.facts_of("data_access", type="ef", operation="query")
        self.assertEqual([f["path"] for f in sets], ["Data/ShopContext.cs"])
        self.assertEqual([f["path"] for f in queries], ["Services/OrderService.cs"])

    def test_go_sql_open_and_xorm_are_connections(self):
        r = self.case("go-conn")
        self.assertEqual(sorted((f["path"], f["line"]) for f in r.facts_of("connection")),
                         [("main.go", 9), ("main.go", 10)])

    def test_flask_sqlalchemy_is_a_connection(self):
        r = self.case("flask-sa")
        self.assertEqual([(f["path"], f["line"]) for f in r.facts_of("connection", type="sqlalchemy")],
                         [("app.py", 5)])


def _facts_scan(r):
    return (r.facts.get("target") or {}).get("scan") or {}


def _block(r, name):
    m = re.search(rf"<!-- appdoc:generated {name} -->(.*?)<!-- /appdoc:generated {name} -->", r.narrative, re.S)
    return m.group(1) if m else ""


class Phase1Behaviour(CorpusCase):
    """Release 2.6.0 cases, written to the NEW behaviour; PENDING lists the task that makes each pass."""

    def test_caps_routes_stack_declares_route_capability(self):
        r = self.case("caps-routes")
        self.assertTrue(r.facts_of("entry_point", type="route"), "the case must extract a route")
        caps = r.facts["stacks"][0]["detail"]["capabilities"]
        self.assertIn("entry_point.route", caps)

    def test_caps_routes_16_7_never_says_no_capability(self):
        r = self.case("caps-routes")
        self.assertEqual(r.fill_code, 0, r.log)
        for name in ("scheduled-jobs", "entry-points"):
            self.assertNotIn("no entry-point capability", _block(r, name))
        self.assertTrue(_block(r, "scheduled-jobs").strip())

    def test_dup_twins_are_a_duplicate_pair_not_retired(self):
        sc = _facts_scan(self.case("dup-twins"))
        self.assertEqual(sc.get("retired_candidates"), [])
        pairs = sc.get("duplicate_folders")
        self.assertEqual(len(pairs or []), 1, pairs)
        a, b = pairs[0]["a"], pairs[0]["b"]
        self.assertEqual((a.rstrip("/"), b.rstrip("/"), pairs[0]["files"]), ("alpha", "beta", 5))

    def test_dup_tests_under_test_paths_are_ignored(self):
        sc = _facts_scan(self.case("dup-tests"))
        self.assertEqual(sc.get("retired_candidates"), [])
        self.assertEqual(sc.get("duplicate_folders", []), [])

    def test_dup_nested_reports_the_outer_folder_once(self):
        sc = _facts_scan(self.case("dup-nested"))
        retired = [c["path"] for c in sc.get("retired_candidates", [])]
        self.assertEqual(retired, ["old/"])
        for pair in sc.get("duplicate_folders", []):
            for side in (pair["a"], pair["b"]):
                self.assertFalse(side.startswith("old/sub"), pair)

    def test_prior_appdoc_output_is_pruned(self):
        r = self.case("prior-output")
        pruned = {p["path"]: p for p in _facts_scan(r).get("pruned", [])}
        self.assertEqual(pruned.get("previous-docs/", {}).get("rule"), "AppDoc output", pruned)
        self.assertFalse([f for f in r.facts_of("file") if f["path"].startswith("previous-docs/")])

    def test_prior_output_is_disclosed_in_scan_coverage(self):
        r = self.case("prior-output")
        text = fill.render_block("scan-coverage", r.facts)
        self.assertIn("AppDoc's own files were not scanned: `previous-docs/` (AppDoc output).", text)

    def test_dup_twins_are_listed_under_the_duplicate_heading(self):
        r = self.case("dup-twins")
        text = fill.render_block("scan-coverage", r.facts)
        self.assertIn("Folders that duplicate another folder (not excluded; say in 2.1 which copy is live):\n"
                      "- `alpha/` and `beta/` (5 files)", text)
        self.assertNotIn("look retired", text)

    def test_skill_bundle_in_target_is_pruned(self):
        r = self.case("skill-in-target")
        pruned = {p["path"]: p for p in _facts_scan(r).get("pruned", [])}
        self.assertEqual(pruned.get("tools/appdoc-skill/", {}).get("rule"), "AppDoc skill bundle", pruned)
        self.assertFalse([f for f in r.facts_of("file") if f["path"].startswith("tools/appdoc-skill/")])

    def test_ini_split_promotes_the_file(self):
        r = self.case("ini-split")
        ini = [f for f in r.facts_of("config_key") if f["path"] == "conf/app.ini"]
        self.assertEqual(sorted(f["name"] for f in ini),
                         ["MIN_PASSWORD_LENGTH", "SECRET_KEY", "server.DOMAIN", "server.HTTP_PORT"])
        self.assertEqual({f["detail"]["role"] for f in ini}, {"app"})

    def test_ini_split_secret_names_are_segment_aware(self):
        r = self.case("ini-split")
        by = {f["name"]: f["detail"] for f in r.facts_of("config_key") if f["path"] == "conf/app.ini"}
        self.assertFalse(by["MIN_PASSWORD_LENGTH"].get("secret_location"), "a length is not a secret")
        self.assertTrue(by["SECRET_KEY"].get("secret_location"))

    def test_wide_range_is_a_c20_advisory(self):
        r = self.case("wide-range")
        self.assertEqual(r.code, 0, r.report)
        self.assertNotIn("C20", r.rules())
        self.assertIn("## Citation precision (advisory)", r.report)
        self.assertIn("app/main.py:1-150", r.report.split("## Citation precision (advisory)")[1].split("\n## ")[0])

    def test_wide_range_fails_under_strict(self):
        r = self.case("wide-range", strict=True)
        self.assertEqual(r.code, 2, r.report)
        self.assertIn("C20", r.rules())


def _gate(target, *args):
    import subprocess
    import sys
    launcher = os.path.join(os.path.dirname(HERE), "run_appdoc.py")
    return subprocess.run([sys.executable, launcher, "gate", target, *args], capture_output=True, text=True)


class GateCases(CorpusCase):
    def test_gate_layout_exit_codes(self):
        r = self.case("gate-layout")
        self.assertEqual(r.code, 0, r.report)
        res = _gate(r.target)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)
        self.assertFalse(os.path.exists(os.path.join(r.target, ".appdoc-regen")), "the regen folder must be removed")
        with open(os.path.join(r.target, "app", "main.py"), "a", encoding="utf-8") as fh:
            fh.write("# line 11 a code change after the Facts were committed\n")
        res = _gate(r.target)
        self.assertEqual(res.returncode, 2, res.stdout + res.stderr)
        self.assertIn("Facts changed", res.stdout + res.stderr)
        with open(os.path.join(r.target, "app", "main.py"), encoding="utf-8") as fh:
            lines = fh.read().splitlines(True)
        with open(os.path.join(r.target, "app", "main.py"), "w", encoding="utf-8", newline="") as fh:
            fh.write("".join(lines[:-1]))
        facts_path = os.path.join(r.out, "facts.json")
        with open(facts_path, encoding="utf-8") as fh:
            doc = json.load(fh)
        doc["schema"] = "appdoc-facts/0"
        with open(facts_path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(doc, fh, indent=1, sort_keys=True)
        res = _gate(r.target)
        self.assertEqual(res.returncode, 3, res.stdout + res.stderr)
        self.assertIn("AppDoc upgraded", res.stdout + res.stderr)

    def test_patch_upgrade_gate_exits_0(self):
        r = self.case("patch-upgrade")
        prov_path = os.path.join(r.out, "provenance.json")
        with open(prov_path, encoding="utf-8") as fh:
            prov = json.load(fh)
        prov.update(generator=_EARLIER_PATCH, bundle="0" * 12)   # committed by an older patch of the same major.minor
        with open(prov_path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(prov, fh, indent=1, sort_keys=True)
        res = _gate(r.target)
        self.assertEqual(res.returncode, 0, res.stdout + res.stderr)

    def test_patch_upgrade_check_passes(self):
        """T26.06: a patch difference in provenance.json is not version skew (a regular test, not pending)."""
        r = self.case("patch-upgrade")
        prov_path = os.path.join(r.out, "provenance.json")
        with open(prov_path, encoding="utf-8") as fh:
            prov = json.load(fh)
        major_minor = ".".join(prov["generator"].split(".")[:2])
        prov.update(generator=major_minor + ".99", bundle="f" * 12)
        with open(prov_path, "w", encoding="utf-8", newline="\n") as fh:
            json.dump(prov, fh, indent=1, sort_keys=True)
        with contextlib.redirect_stdout(io.StringIO()):
            code = check.run(r.target, r.out)
        self.assertEqual(code, 0)


class RegisterHistory(CorpusCase):
    """Template 2.7 documents (the running template since 2.7.0)."""

    def case27(self, name, **kw):
        return self.case(name, **kw)

    def test_superseded_row_keeps_history_and_passes(self):
        r = self.case27("superseded")
        self.assertEqual(r.code, 0, r.report)
        with open(os.path.join(r.out, "evidence.jsonl"), encoding="utf-8") as fh:
            rows = [json.loads(l) for l in fh if l.strip()][1:]
        self.assertEqual([x["id"] for x in rows], ["E-1", "E-2", "E-3"])   # the older row is kept, not deleted
        self.assertNotIn("claim_sha", rows[0])
        self.assertIn("claim_sha", rows[2])
        self.assertIn("3 rows (1 superseded). Current: 1 Supported, 1 Corrected, 0 Downgraded.", r.narrative)
        self.assertIn("| E-1 | 10.1/V-1 | A password is set in code | Supported (superseded by E-3) |", r.narrative)

    def test_superseded_without_supersedes_fails_with_the_fix(self):
        from unittest import mock
        from appdoc import template_spec as spec
        r = self.case27("superseded")
        reg_path = os.path.join(r.out, "evidence.jsonl")
        with open(reg_path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
        lines[3] = json.dumps({k: v for k, v in json.loads(lines[3]).items() if k != "supersedes"})
        with open(reg_path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        with mock.patch.object(spec, "TEMPLATE_VERSION", "2.7"), contextlib.redirect_stdout(io.StringIO()):
            code = check.run(r.target, r.out)
        self.assertEqual(code, 2)
        with open(os.path.join(r.out, "check-report.md"), encoding="utf-8") as fh:
            report = fh.read()
        self.assertIn("two live rows for 10.1/V-1", report)
        self.assertIn('add "supersedes": "E-1" to the newer row; do not delete the older row', report)

    def _rows(self, r):
        with open(os.path.join(r.out, "evidence.jsonl"), encoding="utf-8") as fh:
            return [json.loads(l) for l in fh if l.strip()]

    def test_upgrade_seal_marks_rows_sealed_without_an_audit(self):
        """A 2.7 register whose line 1 has no doc_sha was not audited against this text: plain seal says so."""
        r = self.case27("upgrade-seal")
        self.assertEqual(r.code, 0, r.report)
        audit, *rows = self._rows(r)
        self.assertNotIn("doc_sha", audit)
        self.assertEqual([x["sealed_by"] for x in rows], ["upgrade", "upgrade"])
        self.assertIn("2 rows were sealed at upgrade; their text was not re-audited.", r.narrative)
        strict = self.case27("upgrade-seal", strict=True, require_audit=True)
        self.assertEqual(strict.code, 2, strict.report)
        self.assertIn("C17", strict.rules())
        self.assertIn("E-1 was sealed at upgrade; its text was not re-audited", strict.report)

    def test_seal_audit_turns_the_rows_into_audited_ones(self):
        from unittest import mock
        from appdoc import template_spec as spec
        r = self.case27("upgrade-seal")
        reg_path = os.path.join(r.out, "evidence.jsonl")
        with open(reg_path, encoding="utf-8") as fh:
            lines = fh.read().splitlines()
        # restore the rows to unsealed, as the register looked when the writer handed it to the auditor
        stripped = [lines[0]] + [json.dumps({k: v for k, v in json.loads(l).items()
                                             if k not in ("claim_sha", "sealed_by")}) for l in lines[1:]]
        with open(reg_path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(stripped) + "\n")
        with mock.patch.object(spec, "TEMPLATE_VERSION", "2.7"), contextlib.redirect_stdout(io.StringIO()):
            seal.seal_register(r.target, r.out, audit=True, date="2026-11-23")
            self.assertEqual(fill.run(r.target, r.out), 0)     # Appendix A.1 now prints the audit date
            self.assertEqual(check.run(r.target, r.out), 0)
        audit, *rows = self._rows(r)
        self.assertEqual(audit["audited_on"], "2026-11-23")
        self.assertEqual([x["sealed_by"] for x in rows], ["audit", "audit"])
        self.assertIn("Audited on 2026-11-23 with AppDoc", r.narrative)


    def test_note_stale_fails_c18_with_the_fix(self):
        r = self.case27("note-stale")
        self.assertEqual(r.code, 2, r.report)
        self.assertEqual(r.rules(), {"C18"})
        self.assertIn("notes.jsonl line 1: the entry-points block changed after this note was written. Fix: "
                      "re-read the block, rewrite or delete the note, and clear block_sha", r.report)
        # the note is rendered in its block; it does not make C7 differ
        self.assertIn("Known extractor limitation: Routes registered by decorator are not listed (`app/main.py:2`)",
                      r.narrative)

    def test_label_in_prose_fails_c18(self):
        r = self.case27("label-in-prose")
        self.assertEqual(r.code, 2, r.report)
        self.assertEqual(r.rules(), {"C18"})
        self.assertIn("the reserved label 'Known extractor limitation:' is written in the Narrative outside a "
                      "generated block. Fix: move this note to notes.jsonl", r.report)


    def test_audit_plan_followed_passes_under_require_audit(self):
        r = self.case27("audit-plan", require_audit=True)
        self.assertEqual(r.code, 0, r.report)
        self.assertIn("| Section | Planned | Audited | Extra |", r.narrative)
        self.assertIn("| 4 | 1 | 1 | 0 |", r.narrative)

    def test_per_row_coverage_names_each_uncovered_control(self):
        """R71.A1b: 10.2 lists three Present controls and the register audits one of them: C19 fails, naming the
        two uncovered rows by their text and the ref to use."""
        r = self.case27("audit-per-row-coverage", require_audit=True)
        self.assertEqual(r.code, 2, r.report)
        self.assertEqual(r.rules(), {"C19"})
        self.assertEqual(r.report.count("the audit plan names"), 2, r.report)
        self.assertIn('the audit plan names 10.2/audit-log (row "Audit log"), which has no live register row. '
                      "Fix: audit it and add a row with ref 10.2/audit-log", r.report)
        self.assertIn('the audit plan names 10.2/encrypted-backups (row "Encrypted backups"), which has no live '
                      "register row. Fix: audit it and add a row with ref 10.2/encrypted-backups", r.report)
        self.assertIn("| 10.2 | 3 | 1 | 0 |", r.narrative)        # A.2: planned, audited, extra per row key

    def _live_rows(self, out):
        from appdoc import register
        with open(os.path.join(out, "evidence.jsonl"), encoding="utf-8") as fh:
            return [row for _, row in register.parse(fh.read()).live_rows()]

    def test_seal_stamps_per_row_refs_and_leaves_the_other_rows_unsealed(self):
        """R71.A4b: `seal` writes claim_sha and sealed_by on ID rows, workflows and per-row keys; a section-level row,
        an Answerable row and a Dismissed row stay unsealed by design."""
        r = self.case27("audit-per-row-coverage")
        by_ref = {row["ref"]: row for row in self._live_rows(r.out)}
        for ref in ("10.1/V-1", "7.1", "10.2/tls", "9/service-will-not-start"):
            self.assertRegex(by_ref[ref]["claim_sha"], "^[0-9a-f]{12}$", ref)
            self.assertIn(by_ref[ref]["sealed_by"], ("audit", "upgrade"), ref)
        # the claim of a per-row key is the table row alone: another row's edit does not unseal it
        sha = by_ref["10.2/tls"]["claim_sha"]
        doc = os.path.join(r.out, "application-documentation.md")
        with open(doc, encoding="utf-8") as fh:
            text = fh.read()
        with open(doc, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text.replace("| Audit log | Present |", "| Audit log | Verified absent |"))
        reg_path = os.path.join(r.out, "evidence.jsonl")
        with open(reg_path, "a", encoding="utf-8", newline="\n") as fh:
            for n, (ref, result) in enumerate((("16.5", "Supported"), ("14/Q-2", "Answerable"),
                                               ("smell/aaaaaaaa", "Dismissed"), ("10.2", "Supported")), 20):
                fh.write(json.dumps({"id": f"E-{n}", "ref": ref, "claim": "c", "result": result, "cites": [],
                                     "anchor": "", "limitation": "none"}) + "\n")
        with contextlib.redirect_stdout(io.StringIO()):
            seal.seal_register(r.target, r.out)
        rows = {row["ref"]: row for row in self._live_rows(r.out)}
        self.assertEqual(rows["10.2/tls"]["claim_sha"], sha)
        for ref in ("16.5", "14/Q-2", "smell/aaaaaaaa", "10.2"):
            self.assertNotIn("claim_sha", rows[ref], ref)
            self.assertNotIn("sealed_by", rows[ref], ref)

    def test_c11_checks_a_row_key_against_the_table_and_seals_it_to_its_row(self):
        r = self.case27("audit-per-row-coverage")
        reg_path = os.path.join(r.out, "evidence.jsonl")
        with open(reg_path, "a", encoding="utf-8", newline="\n") as fh:
            for n, ref in enumerate(("10.2/no-such-control", "4/run"), 20):
                fh.write(json.dumps({"id": f"E-{n}", "ref": ref, "claim": "c", "result": "Supported",
                                     "cites": ["app/main.py:2"], "anchor": "line 2", "limitation": "none"}) + "\n")
        with contextlib.redirect_stdout(io.StringIO()):
            check.run(r.target, r.out)
        with open(os.path.join(r.out, "check-report.md"), encoding="utf-8") as fh:
            report = fh.read()
        self.assertIn("ref '10.2/no-such-control' names no row of section 10.2", report)
        self.assertIn("ref '4/run' is a row key, which only sections 9, 10.2, 16.5, 17 have", report)
        # changing the audited row re-opens its seal
        doc = os.path.join(r.out, "application-documentation.md")
        with open(doc, encoding="utf-8") as fh:
            text = fh.read()
        with open(doc, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text.replace("| TLS | Present | `app/main.py:7` |", "| TLS | Present | `app/main.py:6` |"))
        with contextlib.redirect_stdout(io.StringIO()):
            check.run(r.target, r.out)
        with open(os.path.join(r.out, "check-report.md"), encoding="utf-8") as fh:
            self.assertIn("the text of 10.2/tls changed after it was audited", fh.read())

    def test_examples_unsealed_live_rows_are_answerable_dismissed_or_section_level(self):
        """R71.A4b: every live row without sealed_by has no claim_sha and is an Answerable row, a Dismissed row or a
        section-level ref (10.2, 16.5, 17, 9, 16.1, ...); none was sealed `upgrade`."""
        from appdoc import register
        base = os.path.join(os.path.dirname(HERE), "examples", "current")
        names = sorted(n for n in os.listdir(base) if os.path.isfile(os.path.join(base, n, "evidence.jsonl")))
        self.assertTrue(names)
        for name in names:
            with self.subTest(example=name):
                with open(os.path.join(base, name, "evidence.jsonl"), encoding="utf-8") as fh:
                    live = [row for _, row in register.parse(fh.read()).live_rows()]
                self.assertEqual([row["id"] for row in live if row.get("sealed_by") == "upgrade"], [])
                for row in live:
                    if "sealed_by" in row:
                        continue
                    self.assertNotIn("claim_sha", row, row["id"])
                    ref = str(row["ref"])
                    self.assertTrue(row["result"] in ("Answerable", "Dismissed")
                                    or (re.fullmatch(r"\d+(?:\.\d+)?", ref) and not ref.startswith("7.")),
                                    f"{row['id']} ({row['result']}, {ref}) is unsealed and not by design")

    def test_audit_plan_missing_row_fails_c19(self):
        from unittest import mock
        from appdoc import template_spec as spec
        r = self.case27("audit-plan")
        reg_path = os.path.join(r.out, "evidence.jsonl")
        with open(reg_path, encoding="utf-8") as fh:
            lines = [l for l in fh.read().splitlines() if '"ref": "15/R-1"' not in l]
        with open(reg_path, "w", encoding="utf-8") as fh:
            fh.write("\n".join(lines) + "\n")
        with mock.patch.object(spec, "TEMPLATE_VERSION", "2.7"), contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check.run(r.target, r.out, True), 2)
        with open(os.path.join(r.out, "check-report.md"), encoding="utf-8") as fh:
            report = fh.read()
        self.assertIn("the audit plan names R-1, which has no live register row. Fix: audit it and add a row "
                      "with ref 15/R-1", report)

    def test_scope_ids_fails_c17(self):
        r = self.case27("scope-ids")
        self.assertEqual(r.code, 2, r.report)
        self.assertEqual(r.rules(), {"C17"})
        self.assertIn("evidence.jsonl line 1: the audit scope text holds an ID or a number. "
                      "Fix: describe only the method; coverage is computed", r.report)
        self.assertIn("the exclusion for 9 holds an ID or a number", r.report)
        # the computed coverage line, not the writer's scope, says what the register covers
        self.assertIn("10.1 V-1 (1 of 1)", r.narrative)

    def test_severity_order_fails_c9_on_10_1_and_15(self):
        r = self.case27("severity-order")
        self.assertEqual(r.code, 2, r.report)
        self.assertEqual(r.rules(), {"C9"})
        self.assertIn("10.1 row V-2 (High) outranks the row before it (V-1, Low)", r.report)
        self.assertIn("15 row R-1 (High) outranks the row before it (R-0, Low)", r.report)
        self.assertIn("move the row; keep its ID", r.report)

    def test_bare_cite_fails_c1_in_the_narrative_the_register_and_a_note(self):
        r = self.case27("bare-cite")
        self.assertEqual(r.code, 2, r.report)
        self.assertEqual(r.rules(), {"C1"})
        self.assertIn("line 72: `main.py` is a bare name; the file is `app/main.py`. Fix: cite the full path: "
                      "`app/main.py:5`", r.report)
        self.assertIn("evidence.jsonl line 2: `main.py` is a bare name; the file is `app/main.py`", r.report)
        self.assertIn("notes.jsonl line 1: `main.py` is a bare name; the file is `app/main.py`", r.report)

    def test_scope_ids_is_only_a_preview_on_2_4(self):
        """The same Target stamped 2.4, checked as the 2.4-era Check, passes: the scope finding is a preview that
        says it fails from template 2.7. On the running template (2.7.0) that 2.4 stamp is the one C3 upgrade
        problem and nothing else."""
        r = self.case("scope-ids")
        self.assertEqual(r.code, 2)                      # stamped 2.7 on disk: C17 fails
        path = os.path.join(r.out, check.NARRATIVE)
        with open(path, encoding="utf-8") as fh:
            text = fh.read()
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text.replace("<!-- appdoc:template 2.7 -->", "<!-- appdoc:template 2.4 -->"))
        with contextlib.redirect_stdout(io.StringIO()):
            code = run_as_2_4(check.run, r.target, r.out)
        with open(os.path.join(r.out, "check-report.md"), encoding="utf-8") as fh:
            report = fh.read()
        self.assertEqual(code, 0, report)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check.run(r.target, r.out), 2)
        with open(os.path.join(r.out, "check-report.md"), encoding="utf-8") as fh:
            self.assertEqual(set(re.findall(r"^## (C\d+) ", fh.read(), re.M)), {"C3"})
        self.assertIn("Template 2.7 previews (advisory)", report)
        self.assertIn("C17 line 1: evidence.jsonl line 1: the audit scope text holds an ID or a number", report)

class UpgradeCases(CorpusCase):
    """`appdoc upgrade` on documents of older templates (plan 2.7, 3.11 and the 5.1 upgrade steps)."""

    @staticmethod
    def main(*argv):
        from appdoc.__main__ import main
        with contextlib.redirect_stdout(io.StringIO()) as buf, contextlib.redirect_stderr(buf):
            rc = main(list(argv))
        return rc, buf.getvalue()

    @staticmethod
    def edit(path, old, new, count=1):
        with open(path, encoding="utf-8", newline="") as fh:
            text = fh.read()
        assert old in text, (path, old)
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(text.replace(old, new, count))

    def test_a_2_6_document_fails_c3_on_2_7_and_passes_after_exactly_the_5_1_steps(self):
        """Plan 2.7, 5.1 and Done means 2: the 2.6 document (stamp 2.4) passes on its own template, fails C3 alone on
        2.7.0, and passes `build --require-audit` after `appdoc upgrade` and the steps its UPGRADE-TODO.md lists."""
        r = self.case("upgrade-2-6-to-2-7")
        self.assertEqual(r.code, 0, r.report)                            # on template 2.4 (run_case pins it) it passes
        self.assertIn("Template 2.7 previews (advisory)", r.report)
        for rule in ("C1", "C9", "C11", "C17", "C18"):                     # the 2.7 rules it would fail
            self.assertRegex(r.report, rf"- {rule} line \d+:")
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(check.run(r.target, r.out), 2)              # the real, strict Check on 2.7.0
        with open(os.path.join(r.out, "check-report.md"), encoding="utf-8") as fh:
            self.assertEqual(set(re.findall(r"^## (C\d+) ", fh.read(), re.M)), {"C3"})
        doc = os.path.join(r.out, check.NARRATIVE)
        reg = os.path.join(r.out, "evidence.jsonl")
        # step 1: change the stamp, add the closed-questions markers and section 17
        rc, log = self.main("upgrade", r.target, "--no-ownership", "--workers", "0")
        self.assertEqual(rc, 0, log)
        self.assertIn("added the closed-questions block", log)
        self.assertIn("added section 17 Build, Run and Test Locally", log)
        with open(os.path.join(r.out, "UPGRADE-TODO.md"), encoding="utf-8") as fh:
            todo = fh.read()
        for what in ("C1 Citations resolve", "C9 Tables conform", "C11 Register valid", "C15 Register counts in prose (advisory)",
                     "C17 Audit scope", "C18 Notes match their block"):
            self.assertIn(what, todo, what)
        # step 1, by hand: section 17 (one cited command, the rest Unknown) and its guide comment
        with open(doc, encoding="utf-8", newline="") as fh:
            text = fh.read()
        text = re.sub(r"(## 17\. Build, Run and Test Locally\n)<!-- appdoc:guide .*?-->\n", r"\1", text, flags=re.S)
        text = text.replace("| Run | Unknown - see Open questions. | . | Unknown - see Open questions. |",
                            "| Run | `python app/main.py` | . | `app/main.py:2` |")
        with open(doc, "w", encoding="utf-8", newline="") as fh:
            fh.write(text)
        # step 2: the extractor limitation paragraph moves to notes.jsonl
        limitation = "Known extractor limitation: Routes registered by decorator are not listed (`app/main.py:2`).\n\n"
        self.edit(doc, limitation, "")
        with open(os.path.join(r.out, "notes.jsonl"), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(json.dumps({"block": "entry-points", "text": "Routes registered by decorator are not listed",
                                 "cites": ["app/main.py:2"], "block_sha": ""}) + "\n")
        # step 3: the hand-written count becomes a count marker
        self.edit(doc, "The audit covered 2 of 2 findings.",
                  "The audit covered <!-- appdoc:count V -->2<!-- /appdoc:count --> findings.")
        # step 4: the audit scope is the method
        self.edit(reg, '"scope": "sections 3-10"', '"scope": "an independent read of the cited source"')
        # step 5: build --expand-citations (the Narrative's bare name; the register's is step 6)
        rc, log = self.main("build", r.target, "--expand-citations")
        self.assertEqual(rc, 2, log)
        self.assertIn("expanded 1 citation(s)", log)
        # step 6: what the Check lists: severity order, the register's bare name, answered_in
        self.edit(doc, "| V-2 | Low | The health ping is not authenticated | `app/main.py:8` | Information disclosure |\n"
                       "| V-1 | High | A password is set in code | `app/main.py:6`; value omitted. | Credential exposure |",
                  "| V-1 | High | A password is set in code | `app/main.py:6`; value omitted. | Credential exposure |\n"
                  "| V-2 | Low | The health ping is not authenticated | `app/main.py:8` | Information disclosure |")
        self.edit(reg, '"cites": ["main.py:6"]', '"cites": ["app/main.py:6"]')
        self.edit(reg, '"result": "Answerable"', '"result": "Answerable", "answered_in": "3"')
        rc, log = self.main("build", r.target)
        self.assertEqual(rc, 2, log)                                     # step 5 rewrote the sealed text of 6/UI-1 ...
        self.assertIn("the text of 6/UI-1 changed after it was audited", self._report(r))
        rows = self._rows(reg)                                           # ... so that row is re-audited: rewritten
        for row in rows[1:]:                                             # without its claim_sha, which build reseals
            if row["ref"] == "6/UI-1":
                row.pop("claim_sha")
        with open(reg, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(json.dumps(x) for x in rows) + "\n")
        rc, log = self.main("build", r.target)
        self.assertEqual(rc, 0, log + self._report(r))                   # it passes without the audit record
        # step 7: audit-plan, the audit of the planned IDs, seal --audit --date
        rc, log = self.main("audit-plan", r.target)
        self.assertEqual(rc, 0, log)
        with open(os.path.join(r.out, "audit-plan.json"), encoding="utf-8") as fh:
            planned = {i for sec in json.load(fh)["sections"] for i in sec["ids"]}
        self.assertTrue({"V-1", "V-2", "Q-1", "7.1"} <= planned, planned)
        rows = self._rows(reg)
        have = {x["ref"].split("/")[-1] for x in rows[1:]} | {x["ref"] for x in rows[1:]}
        missing = sorted(i for i in planned if i not in have)
        self.assertEqual(missing, ["17/run", "9/service-will-not-start"],
                         "the register already audits every planned ID except the new section 17 and, per row (R71.A1a), "
                         "the section 9 row its old section-level row 9 stood for")
        rows.append({"id": "E-12", "ref": "17/run", "claim": "The Run command starts the service", "result": "Supported",
                     "cites": ["app/main.py:2"], "anchor": "line 2", "limitation": "none"})   # the audit itself
        rows.append({"id": "E-13", "ref": "9/service-will-not-start", "claim": "The troubleshooting row is accurate",
                     "result": "Supported", "cites": ["app/main.py:2"], "anchor": "line 2", "limitation": "none"})
        with open(reg, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("\n".join(json.dumps(x) for x in rows) + "\n")
        rc, log = self.main("seal", r.target, "--audit", "--date", "2026-11-23")
        self.assertEqual(rc, 0, log)
        # step 8: build
        rc, log = self.main("build", r.target, "--require-audit")
        self.assertEqual(rc, 0, self._report(r))
        self.assertEqual(self._report(r).splitlines()[0], "# Check: PASS")

    @staticmethod
    def _report(r):
        with open(os.path.join(r.out, "check-report.md"), encoding="utf-8") as fh:
            return fh.read()

    @staticmethod
    def _rows(path):
        with open(path, encoding="utf-8") as fh:
            return [json.loads(l) for l in fh if l.strip()]

    def test_upgrade_2_1_case_gets_the_mechanical_steps_and_a_todo(self):
        r = self.case("upgrade-2-1")
        self.assertEqual(r.code, 2)                                      # unstamped: fails C3 with the upgrade problem
        self.assertEqual(r.rules(), {"C3"})
        before = self._snapshot(os.path.join(r.out, "verification.md"))
        rc, log = self.main("upgrade", r.target, "--no-ownership", "--workers", "0")
        self.assertEqual(rc, 0, log)
        self.assertIn("template 2.1 -> 2.7", log)
        self.assertEqual(self._snapshot(os.path.join(r.out, "verification.md")), before)   # never converted
        for name in ("evidence.jsonl", "notes.jsonl", "audit-plan.json"):
            self.assertFalse(os.path.exists(os.path.join(r.out, name)), name)
        with open(os.path.join(r.out, "UPGRADE-TODO.md"), encoding="utf-8") as fh:
            todo = fh.read()
        self.assertIn("Convert `verification.md` to `evidence.jsonl`", todo)
        self.assertIn("appdoc:upgrade-orphan", todo)
        text = r.narrative
        self.assertIn("(the old text is kept under an orphan comment)", log)
        for kept in ("Who deploys the service? Unknown.", "| Section | Contents |", "Build and deploy steps are not in "
                     "the repository. Unknown."):
            self.assertIn(kept, text)                                    # the text that did not fit is still there

    @staticmethod
    def _snapshot(path):
        with open(path, "rb") as fh:
            return fh.read()


def _apply_pending():
    for cls in CorpusCase.__subclasses__():
        for name in PENDING:
            if name in vars(cls):
                setattr(cls, name, unittest.expectedFailure(vars(cls)[name]))


_apply_pending()


if __name__ == "__main__":
    unittest.main()
