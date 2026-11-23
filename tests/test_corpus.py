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
    "test_config_env_roles": ("T25.21", "post-pass does not yet split code reads into env/ci/app; env keys flagged secret"),
    "test_config_env_reference_block": ("T25.23", "16.6 trailer does not yet report excluded env-var and CI keys"),
    "test_owner_absent_advisory": ("T25.13", "C4 has no Unknown-by-absence advisory for ownership or the runbook"),
    "test_razor_page_is_a_ui_page": ("T25.30", "aspnet_core emits ui_page for XAML only, not .razor"),
    "test_ef_dbset_and_query_are_data_access": ("T25.31", "aspnet_core emits no EF data_access Facts"),
    "test_go_sql_open_and_xorm_are_connections": ("T25.33", "go stack emits no connection Facts"),
    "test_flask_sqlalchemy_is_a_connection": ("T25.36", "python_flask only matches create_engine, not SQLAlchemy(app)"),
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


def _apply_pending():
    for cls in CorpusCase.__subclasses__():
        for name in PENDING:
            if name in vars(cls):
                setattr(cls, name, unittest.expectedFailure(vars(cls)[name]))


_apply_pending()


if __name__ == "__main__":
    unittest.main()
