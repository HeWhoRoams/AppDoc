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

from appdoc import check, extract, fill

HERE = os.path.dirname(os.path.abspath(__file__))
CORPUS = os.path.join(HERE, "corpus")

# test method name -> (task ID, why it fails today). Delete the entry when the task lands.
PENDING: dict = {
}


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
            check.seal_register(target, out)
            fill_code = fill.run(target, out)
            code = check.run(target, out, require_audit, strict)
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
        prov.update(generator="2.6.0", bundle="0" * 12)   # committed by an older patch of the same major.minor
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
    """Template 2.7 documents (the running template is patched to 2.7 for the call)."""

    def case27(self, name, **kw):
        from unittest import mock
        from appdoc import template_spec as spec
        with mock.patch.object(spec, "TEMPLATE_VERSION", "2.7"):
            return self.case(name, **kw)

    def test_superseded_row_keeps_history_and_passes(self):
        r = self.case27("superseded")
        self.assertEqual(r.code, 0, r.report)
        with open(os.path.join(r.out, "evidence.jsonl"), encoding="utf-8") as fh:
            rows = [json.loads(l) for l in fh if l.strip()][1:]
        self.assertEqual([x["id"] for x in rows], ["E-1", "E-2", "E-3"])   # the older row is kept, not deleted
        self.assertNotIn("claim_sha", rows[0])
        self.assertIn("claim_sha", rows[2])

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
            check.seal_register(r.target, r.out, audit=True, date="2026-11-23")
            self.assertEqual(check.run(r.target, r.out), 0)
        audit, *rows = self._rows(r)
        self.assertEqual(audit["audited_on"], "2026-11-23")
        self.assertEqual([x["sealed_by"] for x in rows], ["audit", "audit"])


def _apply_pending():
    for cls in CorpusCase.__subclasses__():
        for name in PENDING:
            if name in vars(cls):
                setattr(cls, name, unittest.expectedFailure(vars(cls)[name]))


_apply_pending()


if __name__ == "__main__":
    unittest.main()
