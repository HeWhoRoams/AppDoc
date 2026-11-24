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
SHARED = os.path.join(CORPUS, "_targets")     # shared Targets (T28.00); never run as cases (names start with "_")
TARGET_FILE = "_target"                       # a case folder holding this file runs against a shared Target

# test method name -> (task ID, why it fails today). Delete the entry when the task lands.
PENDING: dict = {
    # --- 4C: shared config reader, settings, transforms, rules
    "test_webconfig_security_settings_per_configuration": ("T28.30", "missing security_setting: no .config setting Facts yet"),
    "test_webconfig_malformed_file_is_one_config_unparsed": ("T28.30", "missing config_unparsed: .config files are not read by a Stack yet"),
    "test_webconfig_security_machinekey_class_no_value": ("T28.30", "missing security_setting: no machineKey class Fact yet"),
    "test_xdt_supported_transforms_effective": ("T28.34", "missing security_setting: no per-configuration effective values yet"),
    "test_xdt_odd_transform_is_flagged_unsupported": ("T28.35", "missing config_transform: no transform Facts yet"),
    "test_xdt_overridden_in_recorded_without_values": ("T28.36", "missing overridden_in: base keys carry no overridden_in yet"),
    "test_windows_auth_iis_anonymous_is_unknown_and_disclosed": ("T28.38", "missing host_auth: no host_auth Fact yet"),
    "test_owin_none_is_disclosed": ("T28.38", "missing host_auth: no host_auth Fact yet"),
    "test_xdt_transformed_access_rules": ("T28.40", "missing access_rule: no access_rule Facts yet"),
    "test_secrets_never_recorded_named_users_counted_not_recorded": ("T28.40", "missing users_named: access rules carry no users_named count"),
    "test_location_path_forms": ("T28.41", "missing access_rule: no access_rule Facts yet"),
    "test_nested_webconfig_scope_paths": ("T28.41", "missing access_rule: no access_rule Facts yet"),
    "test_location_allow_override_and_system_webserver_only": ("T28.42", "missing access_rule: no access_rule Facts yet"),
    "test_secrets_never_recorded_wcf_address_is_scheme_and_host": ("T28.37", "missing external_call: WCF client endpoints are not read yet"),
    # --- 4B: classification and route fidelity
    "test_stack_markers_in_fixtures_and_tooling_are_ignored": ("T28.11", "missing ignored_markers: no stack records dropped markers yet"),
    # --- 4C: project and publish Facts
    # --- 4D: guards
    "test_custom_guard_external_attribute_is_a_candidate": ("T28.51", "missing guard_candidate: no guard_candidate Facts yet"),
    "test_custom_guard_declared_in_context_is_auth_check_declared": ("T28.52", "missing auth_check: no declared auth_check yet"),
    "test_custom_guard_arguments_arity_and_credential_constant": ("T28.53", "missing guard_use: no guard_use Facts yet"),
    "test_custom_guard_auth_method_promotion_lists_constants": ("T28.54", "missing auth_check: no promoted auth_check via=call yet"),
    "test_secrets_never_recorded_secret_constant_is_not_resolved": ("T28.53", "missing const_def: no const_def Facts yet"),
    # --- 4E: effective protection (after the first slice)
    "test_core_fallback_policy_mechanism_only_no_reach": ("T28.60", "missing guard_mechanism: entry_points carry no guard_mechanism yet"),
    "test_core_absence_claim_only_without_auth_services": ("T28.60", "missing guard_mechanism: entry_points carry no guard_mechanism yet"),
    "test_route_aliases_all_checked_and_open_route_is_unknown": ("T28.61", "missing reach_anon: entry_points carry no reach yet"),
    "test_url_auth_chain_merge": ("T28.62", "missing reach_anon: entry_points carry no reach yet"),
    "test_nested_webconfig_applies_by_url_prefix_not_area_folder": ("T28.62", "missing reach_anon: entry_points carry no reach yet"),
    "test_filter_composition": ("T28.63", "missing reach_anon: entry_points carry no reach yet"),
    "test_owin_with_mode_none_is_unknown": ("T28.65", "missing reach: entry_points carry no reach yet"),
    "test_verbless_actions_are_any_and_state_changing_is_tristate": ("T28.66", "missing verbs_declared: entry_points carry no verbs_declared yet"),
    "test_verbless_web_api_verb_from_name_convention": ("T28.66", "missing verbs: entry_points carry no verbs yet"),
    # --- 4H: Check rules
    "test_config_not_reviewed_c21_fails_without_a_lined_citation": ("T28.A0", "missing C21: no rule requires Web.config to be cited"),
    "test_config_not_reviewed_c21_passes_with_a_lined_citation_outside_blocks": ("T28.A0", "missing C21: no rule requires Web.config to be cited"),
    "test_area_coverage_c22_fails_when_an_area_is_missing_from_4_1": ("T28.A1", "missing C22: the Check does not require every area in 4.1"),
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


def materialize_shared_target(spec, dest):
    """Copy the shared Target ``spec`` into ``dest``: ``<base>`` or ``<base>+<overlay>[+<overlay>...]``.

    The base is ``_targets/<base>/``; each overlay is ``_targets/<base>+<overlay>/`` and holds only its delta (new
    files, and changed files whole). Overlays are copied over the base in the order given; the shared folders are
    only read, never changed.
    """
    base, *overlays = spec.strip().split("+")
    for folder in [base] + [f"{base}+{o}" for o in overlays]:
        src = os.path.join(SHARED, folder)
        if not os.path.isdir(src):
            raise FileNotFoundError(f"no shared Target folder {folder!r} under {SHARED}")
        shutil.copytree(src, dest, ignore=shutil.ignore_patterns("__pycache__"), dirs_exist_ok=True)


def run_case(name, strict=False, require_audit=False, tmp=None, files=None):
    """Copy corpus/<name> to a temp dir, then extract, seal, fill and check. Returns CaseResult.

    A case folder holding a ``_target`` file (one line, e.g. ``mvc5-classic+owin``) is the delta over that shared
    Target: the shared Target is copied first and the case folder's own files go on top. ``files`` maps a relative
    path to text written into the copy before extraction (a case variant without a second case folder).

    The temp dir is removed by the caller through ``tmp`` (a TemporaryDirectory) or leaked to the
    OS temp cleaner when none is given; tests always pass ``tmp``.
    """
    src = os.path.join(CORPUS, name)
    if not os.path.isdir(src):
        raise FileNotFoundError(f"no corpus case {name!r} under {CORPUS}")
    tmp = tmp or tempfile.TemporaryDirectory()
    target = os.path.join(tmp.name, name)
    marker = os.path.join(src, TARGET_FILE)
    ignore = shutil.ignore_patterns("__pycache__", TARGET_FILE)
    if os.path.isfile(marker):
        with open(marker, encoding="utf-8") as fh:
            materialize_shared_target(fh.read(), target)
    shutil.copytree(src, target, ignore=ignore, dirs_exist_ok=True)
    for rel, text in (files or {}).items():
        path = os.path.join(target, *rel.split("/"))
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
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
                self.assertTrue(re.fullmatch(r"T\d\d\.[A-Z0-9]\d", task), task)
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

    def test_build_command_chain_fails_c9_with_one_command_or_wrapper_script(self):
        r = self.case27("build-command-chain")
        self.assertEqual(r.code, 2, r.report)
        self.assertEqual(r.rules(), {"C9"})
        self.assertIn("17 Run: the Command cell holds more than one command; it must hold exactly one backticked "
                      "command and nothing else", r.report)
        self.assertIn("use one command or one wrapper script", r.report)

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


# ---------------------------------------------------------------------------------------------------------------
# Release 2.8.0, stream 4A (Phase 0): shared Targets (T28.00-T28.02) and the slice-1 corpus cases (T28.03).
#
# New-behaviour cases fail today with ``Missing`` (an AssertionError subclass raised by ``need``/``need_fact``) and
# are listed in PENDING with the task that makes them pass. ``test_new_cases_fail_for_their_stated_reason`` runs every
# such test and checks that it fails with ``Missing`` naming the token the PENDING reason starts with ("missing X:"),
# so a case that fails for another reason (a crash, a bad Target, a typo) turns the suite red.
# Assertions read Facts and Check output only. Every Target name here is invented (Contoso.*).
# ---------------------------------------------------------------------------------------------------------------

class Missing(AssertionError):
    """The 2.8 behaviour a case pins is not there yet (the stated reason a PENDING case fails)."""


def need(cond, token, text=""):
    if not cond:
        raise Missing(f"missing {token}" + (f": {text}" if text else ""))


def need_fact(r, kind, **detail):
    found = r.facts_of(kind, **detail)
    need(found, kind, f"no {kind} Fact with {detail}")
    return found


def dtl(f):
    return f.get("detail") or {}


def facts_at(r, kind, path=None, name=None, **detail):
    """Facts of a kind, optionally at a path and/or with a name, whose detail holds the given pairs."""
    return [f for f in r.facts_of(kind, **detail)
            if (path is None or f["path"] == path) and (name is None or f["name"] == name)]


def as_list(v):
    return [] if v is None else (list(v) if isinstance(v, (list, tuple)) else [v])


def lower_set(v):
    return {str(x).lower() for x in as_list(v)}


def entries_of(r, handler):
    return sorted((f for f in r.facts_of("entry_point") if dtl(f).get("handler") == handler),
                  key=lambda f: (f["path"], f["line"] or 0, f["name"]))


def need_entry(r, handler, key):
    """The detail of the first entry_point of ``handler``; ``Missing`` (token ``key``) when it lacks ``key``."""
    found = entries_of(r, handler)
    need(found, "entry_point", f"no entry_point for handler {handler}")
    need(key in dtl(found[0]), key, f"entry_point {handler} has no {key}")
    return dtl(found[0])


def scope_of(f):
    """An access_rule's scope_path relative to the web project root, lower-cased, no slashes at the ends."""
    s = str(dtl(f).get("scope_path") or "").replace("\\", "/").strip("/").lower()
    if s == "contoso.portal" or s == ".":
        return ""
    return s[len("contoso.portal/"):] if s.startswith("contoso.portal/") else s


def rules_of(r, path, config="base", scope=""):
    got = [f for f in r.facts_of("access_rule", config=config) if f["path"] == path and scope_of(f) == scope]
    return sorted(got, key=lambda f: dtl(f).get("order") or 0)


def case_text(r):
    """Everything a run wrote for the reader: facts.json plus facts-summary.md (R18/R19 scans)."""
    parts = [json.dumps(r.facts, sort_keys=True)]
    summary = os.path.join(r.out, "facts-summary.md")
    if os.path.isfile(summary):
        with open(summary, encoding="utf-8") as fh:
            parts.append(fh.read())
    return "\n".join(parts)


def target_lines(r, rel):
    with open(os.path.join(r.target, *rel.split("/")), "rb") as fh:
        raw = fh.read()
    return raw.decode("utf-8-sig").replace("\r\n", "\n").split("\n")


def line_of(r, rel, needle):
    """1-based line of the first line of a Target file that contains ``needle`` (BOM and CRLF aware)."""
    for n, text in enumerate(target_lines(r, rel), 1):
        if needle in text:
            return n
    raise AssertionError(f"{needle!r} not in {rel}")


def tree_bytes(root):
    out = {}
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = [d for d in dirnames if d != "__pycache__"]
        for n in filenames:
            full = os.path.join(dirpath, n)
            with open(full, "rb") as fh:
                out[os.path.relpath(full, root).replace(os.sep, "/")] = fh.read()
    return out


PORTAL = "Contoso.Portal/"
WEB_CONFIG = PORTAL + "Web.config"
MINI_CASES = ("location-paths", "url-auth-merge", "nested-webconfig", "route-aliases", "filter-composition",
              "config-not-reviewed", "area-coverage")
# Every made-up secret the shared Target carries; none may appear in any Fact or summary (R18, R19).
TARGET_SECRETS = ("not-a-real-credential-0001", "not-a-real-password-0002", "not-a-real-token-0003",
                  "not-a-real-password-0004", "not-a-real-password-0005", "not-a-real-password-0006",
                  "not-a-real-pw", "0123456789ABCDEF0123456789ABCDEF", "FEDCBA9876543210FEDCBA9876543210",
                  "InventedEncryptedBlobMarker0001", "svcuser", "token=abc", "deploy-stg-user")


class SharedTargets(CorpusCase):
    """T28.00-T28.02: the shared-Target helper and the invented ``mvc5-classic`` Target."""

    def _case_dirs(self):
        return [os.path.join(SHARED, d) for d in sorted(os.listdir(SHARED))] + \
               [os.path.join(CORPUS, d) for d in MINI_CASES]

    # --- T28.00
    def test_shared_target_overlay_copies_only_delta(self):
        base_dir = os.path.join(SHARED, "mvc5-classic")
        base = tree_bytes(base_dir)
        for overlay in ("owin", "core", "webapi"):
            with self.subTest(overlay=overlay):
                delta = tree_bytes(os.path.join(SHARED, f"mvc5-classic+{overlay}"))
                self.assertTrue(delta, "an overlay holds at least its delta")
                self.assertLess(len(delta), len(base) // 4, "an overlay is a delta, not a second copy of the Target")
                for rel, data in delta.items():          # a delta file is new or changed, never a verbatim copy
                    self.assertNotEqual(base.get(rel), data, f"{rel} is unchanged from the base")
                with tempfile.TemporaryDirectory() as tmp:
                    dest = os.path.join(tmp, "t")
                    materialize_shared_target(f"mvc5-classic+{overlay}", dest)
                    got = tree_bytes(dest)
                self.assertEqual(set(got), set(base) | set(delta))
                for rel in base:
                    self.assertEqual(got[rel], delta.get(rel, base[rel]), rel)
                self.assertEqual(tree_bytes(base_dir), base, "the shared base must not change")
        with tempfile.TemporaryDirectory() as tmp:       # two overlays stack
            materialize_shared_target("mvc5-classic+owin+core", os.path.join(tmp, "t"))
            self.assertTrue(os.path.isfile(os.path.join(tmp, "t", "Contoso.Portal.Core", "Program.cs")))
            self.assertTrue(os.path.isfile(os.path.join(tmp, "t", "Contoso.Portal", "Startup.cs")))
        with self.assertRaises(FileNotFoundError):
            materialize_shared_target("mvc5-classic+nope", tempfile.mkdtemp())

    def test_case_runs_against_the_owin_overlay(self):
        r = self.case("owin-none")
        self.assertTrue(facts_at(r, "file", PORTAL + "Startup.cs"), "an overlay file is in the run")
        self.assertTrue(facts_at(r, "file", PORTAL + "Controllers/HomeController.cs"), "a base file is in the run")
        self.assertFalse(facts_at(r, "file", "_target"), "the marker file is not part of the Target")
        self.assertIn('<authentication mode="None" />', "\n".join(target_lines(r, WEB_CONFIG)))
        with open(os.path.join(SHARED, "mvc5-classic", "Contoso.Portal", "Web.config"), "rb") as fh:
            self.assertIn(b'<authentication mode="Windows" />', fh.read(), "the base stays Windows")

    def test_case_variant_files_are_written_before_extraction(self):
        r = self.case("verbless-actions", files={"Extra/note.txt": "hello\n"})
        self.assertTrue(facts_at(r, "file", "Extra/note.txt"))

    # --- T28.01
    def test_invented_target_uses_invented_names(self):
        ns = re.compile(r"(?m)^\s*namespace\s+([\w.]+)")
        seen = 0
        for root in self._case_dirs():
            for rel, data in tree_bytes(root).items():
                text = data.decode("utf-8", "replace")
                if rel.endswith(".cs"):
                    for m in ns.finditer(text):
                        seen += 1
                        self.assertTrue(m.group(1).startswith("Contoso."), f"{rel}: namespace {m.group(1)}")
                if rel.endswith(".csproj"):
                    for m in re.finditer(r"<RootNamespace>([^<]+)<", text):
                        self.assertTrue(m.group(1).startswith("Contoso."), f"{rel}: {m.group(1)}")
        self.assertGreater(seen, 20)

    @unittest.skipUnless(os.environ.get("APPDOC_ACCEPTANCE_KEYS"), "APPDOC_ACCEPTANCE_KEYS is not set (local check)")
    def test_invented_target_has_no_denylisted_token(self):
        deny = os.path.join(os.environ["APPDOC_ACCEPTANCE_KEYS"], "denylist.txt")
        if not os.path.isfile(deny):
            self.skipTest("no denylist.txt in APPDOC_ACCEPTANCE_KEYS")
        with open(deny, encoding="utf-8") as fh:
            tokens = [t.strip().lower() for t in fh if t.strip() and not t.startswith("#")]
        for root in self._case_dirs():
            for rel, data in tree_bytes(root).items():
                text = (rel + "\n" + data.decode("utf-8", "replace")).lower()
                for t in tokens:
                    self.assertNotIn(t, text, f"{root}/{rel}")

    def test_invented_target_shapes_in_code(self):
        code = {rel: data.decode("utf-8") for rel, data in tree_bytes(os.path.join(SHARED, "mvc5-classic")).items()
                if rel.endswith(".cs")}
        joined = "\n".join(code.values())
        for needle in ('[RouteArea("Billing", AreaPrefix = "billing")]', "[RouteArea(AreaPrefix = \"uploads\")]",
                       '[RouteArea("", AreaPrefix = "")]', "[ RouteArea ( AreaPrefix=", "[AllowAnonymous]",
                       "HasRole(IPrincipal user, string roleA, string groupB)", "#if DEBUG", "#elif STAGING",
                       "SharedControllerBase", "Accounts.ServicePassword", 'MvcApplication.Mode == "Production"'):
            self.assertIn(needle, joined, needle)
        guard = re.findall(r"\[ContosoGuard\(([^\]]*)\)\]", joined)
        self.assertEqual(sorted(g.count(",") + 1 for g in guard), [4, 4, 4, 5])
        self.assertEqual(len(re.findall(r"\[ContosoLayout\(", joined)), 3)    # a non-guard external attribute, three uses
        self.assertIn("Contoso.Portal.Areas.Archive.Controllers",
                      code[PORTAL + "Areas/Reports/Controllers/ExportController.cs"])   # namespace names another area
        self.assertIn("filters.Add(new HandleErrorAttribute());", joined)
        self.assertNotIn("Authorize", code[PORTAL + "App_Start/FilterConfig.cs"])

    # --- T28.02
    def test_invented_target_config_shape(self):
        from appdoc import dotnetcfg
        files = tree_bytes(os.path.join(SHARED, "mvc5-classic"))
        raw = files[WEB_CONFIG]
        self.assertTrue(raw.startswith(b"\xef\xbb\xbf"), "Web.config is UTF-8 with a BOM")
        self.assertIn(b"\r\n", raw)
        self.assertNotIn(b"\n", raw.replace(b"\r\n", b""), "CRLF throughout")
        root = dotnetcfg.parse(raw).root
        self.assertEqual(len(root.findall("location")), 15)
        paths = [n.attrs.get("path") for n in root.findall("location")]
        self.assertEqual(sorted(paths), sorted(
            ["Content", "Scripts", "OldPrintJobs", "Archive2019", "Health", "Info/Welcome", "Account/Login",
             "Unsubscribe.aspx", "Account", "Profile", "Orders", "Dashboard", "Billing", "Admin/Tools",
             "Billing/Refunds"]))
        self.assertEqual(sorted(dotnetcfg.transform_config_name(p) for p in files if p.startswith(PORTAL)
                                and dotnetcfg.transform_config_name(p)), ["Debug", "Odd", "Release", "Staging"])
        self.assertIn(PORTAL + "Areas/Reports/Web.config", files)
        self.assertIn(PORTAL + "Areas/Public/web.config", files, "one lower-case web.config")
        self.assertIn(PORTAL + "Properties/PublishProfiles/Staging.pubxml.user", files)
        self.assertIn("Training|AnyCPU", files[PORTAL + "Contoso.Portal.csproj"].decode())
        self.assertNotIn(b"Web.Training.config", files[PORTAL + "Contoso.Portal.csproj"], "a configuration with no transform")
        win = [p for p in files if p.endswith(".csproj") and not p.startswith(("fixtures/", "tests/"))]
        core_dir = os.path.join(SHARED, "mvc5-classic+core")
        self.assertIn("<OutputType>WinExe</OutputType>", files["Contoso.Portal.Harness/Contoso.Portal.Harness.csproj"].decode())
        self.assertIn("Microsoft.NET.Sdk.Web", tree_bytes(core_dir)["Contoso.Portal.Core/Contoso.Portal.Core.csproj"].decode())
        self.assertEqual(len(win), 3)
        self.assertIn("[TestMethod]", files["Contoso.Portal.Tests/HomeControllerTests.cs"].decode())
        for rel in ("fixtures/sample-core-app/Program.cs", "tests/powershell/fixtures/sample-app/Program.cs",
                    "tooling/package.json"):
            self.assertIn(rel, files)
        pkg = json.loads(files["tooling/package.json"])
        self.assertTrue(all(k.startswith("@types/") or k == "typescript" for k in pkg["devDependencies"]))

    def test_invented_target_config_parses(self):
        from appdoc import dotnetcfg
        files = tree_bytes(os.path.join(SHARED, "mvc5-classic"))
        unparsed = {}
        for rel, data in files.items():
            if dotnetcfg.is_config_name(rel) or dotnetcfg.transform_config_name(rel):
                doc = dotnetcfg.parse(data)
                if doc.unparsed:
                    unparsed[rel] = doc.unparsed
        # Deviation from the breakdown's wording (plan 4.2 wins): Web.Odd.config is well formed (XPath and
        # InsertAfter, to prove "unknown"); the one deliberately malformed file is Areas/Legacy/Web.config.
        self.assertEqual(unparsed, {PORTAL + "Areas/Legacy/Web.config": "malformed"})
        self.assertFalse(dotnetcfg.is_pubxml_name(PORTAL + "Properties/PublishProfiles/Staging.pubxml.user"))
        self.assertTrue(dotnetcfg.is_pubxml_name(PORTAL + "Properties/PublishProfiles/Staging.pubxml"))

    def test_invented_target_extracts_and_skips_pubxml_user(self):
        r = self.case("webconfig-security")
        self.assertEqual([f for f in r.facts["facts"] if f["path"].endswith(".pubxml.user") and f["kind"] != "file"], [])
        self.assertNotIn("InventedEncryptedBlobMarker0001", case_text(r), "a .pubxml.user is never read")



class Slice1Config(CorpusCase):
    """Shared-Target cases for W13/W1/W2 (4C). PENDING names the task whose landing makes each pass."""

    # --- webconfig-security
    def test_webconfig_security_settings_per_configuration(self):
        r = self.case("webconfig-security")
        auth = need_fact(r, "security_setting", name="system.web/authentication@mode", value="windows", config="base")
        self.assertEqual(auth[0]["path"], WEB_CONFIG)
        self.assertEqual(auth[0]["line"], line_of(r, WEB_CONFIG, "<authentication"), "BOM and CRLF keep line numbers")
        want = [("system.web/compilation@debug", "base", "true", "base"), ("system.web/compilation@debug", "Debug", "true", None),
                ("system.web/compilation@debug", "Staging", "absent", "transformed"),
                ("system.web/compilation@debug", "Release", "absent", "transformed"),
                ("system.web/compilation@debug", "Training", "true", "base"),
                ("system.web/customErrors@mode", "base", "off", "base"),
                ("system.web/customErrors@mode", "Staging", "off", None),
                ("system.web/customErrors@mode", "Release", "remoteonly", "transformed"),
                ("system.web/forms@requireSSL", "base", "absent", "base"),
                ("system.web/identity@impersonate", "base", "absent", "base")]
        for name, config, value, status in want:
            kw = {"name": name, "config": config, "value": value}
            if status:
                kw["config_status"] = status
            need_fact(r, "security_setting", **kw)
        trace = need_fact(r, "security_setting", name="system.web/trace@enabled", config="base")
        self.assertTrue(dtl(trace[0]).get("local_only"), "trace localOnly is recorded")

    def test_webconfig_malformed_file_is_one_config_unparsed(self):
        r = self.case("webconfig-security")
        bad = need_fact(r, "config_unparsed")
        self.assertEqual([(f["path"], dtl(f).get("reason")) for f in bad],
                         [(PORTAL + "Areas/Legacy/Web.config", "malformed")], "one Fact, no partial tree")
        self.assertFalse([f for f in r.facts_of("access_rule") if f["path"] == PORTAL + "Areas/Legacy/Web.config"])

    def test_webconfig_security_machinekey_class_no_value(self):
        r = self.case("webconfig-security")
        key = need_fact(r, "security_setting", name="system.web/machineKey", value="literal_hex", config="base")
        self.assertTrue(dtl(key[0]).get("secret_location"))
        self.assertEqual(key[0]["line"], line_of(r, WEB_CONFIG, "<machineKey"))
        text = case_text(r)
        for hexkey in ("0123456789ABCDEF0123456789ABCDEF", "FEDCBA9876543210FEDCBA9876543210"):
            self.assertNotIn(hexkey, text, "no key value is ever recorded")

    # --- xdt-effective
    def test_xdt_supported_transforms_effective(self):
        r = self.case("xdt-effective")
        need_fact(r, "security_setting", name="system.web/compilation@debug", config="Staging", value="absent",
                  config_status="transformed")       # RemoveAttributes, under a namespace prefix other than xdt
        need_fact(r, "security_setting", name="system.web/compilation@debug", config="Release", value="absent")
        need_fact(r, "security_setting", name="system.web/compilation@debug", config="base", value="true")
        need_fact(r, "security_setting", name="system.web/compilation@debug", config="Training", value="true",
                  config_status="base")              # a configuration with no transform is the base
        need_fact(r, "security_setting", name="system.web/customErrors@mode", config="Release", value="remoteonly",
                  config_status="transformed")       # SetAttributes without an attribute list sets all of them
        need_fact(r, "security_setting", name="system.web/customErrors@mode", config="base", value="off")
        need_fact(r, "security_setting", name="system.web/trace@enabled", config="Release", value="absent",
                  config_status="transformed")       # RemoveAll with no locator
        need_fact(r, "security_setting", name="system.web/httpCookies@requireSSL", config="Release", value="true")
        need_fact(r, "security_setting", name="system.web/httpCookies@httpOnlyCookies", config="Release", value="true")
        # SetAttributes(requireSSL) lists one attribute: httpOnlyCookies="false" in the transform is not applied

    def test_xdt_transformed_access_rules(self):
        r = self.case("xdt-effective")
        rel = rules_of(r, WEB_CONFIG, "Release")
        need(rel, "access_rule", "no Release rules at the project root")
        self.assertEqual([(dtl(f)["effect"], bool(dtl(f).get("anon")), bool(dtl(f).get("all"))) for f in rel],
                         [("deny", True, False), ("allow", False, True)], "Replace swaps the root authorization")
        self.assertTrue(all(dtl(f).get("config_status") == "transformed" for f in rel))
        base = rules_of(r, WEB_CONFIG, "base")
        self.assertEqual([dtl(f)["effect"] for f in base], ["allow", "allow", "deny"])
        self.assertEqual(lower_set(dtl(base[0]).get("roles")), {"portalusers", "portaladmins"})
        self.assertEqual(dtl(base[1]).get("users_named"), 2)
        for config in ("Staging", "Training"):     # a transform that leaves authorization alone, and no transform at all
            self.assertEqual([dtl(f)["effect"] for f in rules_of(r, WEB_CONFIG, config)], ["allow", "allow", "deny"], config)
        self.assertEqual(dtl(rules_of(r, WEB_CONFIG, "Training")[0]).get("config_status"), "base")
        billing = rules_of(r, WEB_CONFIG, "Release", "billing")
        self.assertEqual([dtl(f)["effect"] for f in billing], ["allow", "allow", "deny", "allow"])
        self.assertEqual(lower_set(dtl(billing[-1]).get("roles")), {"interns"}, "Insert appends after deny *")
        self.assertGreater(dtl(billing[-1])["order"], dtl(billing[2])["order"])
        odd = rules_of(r, WEB_CONFIG, "Odd")
        self.assertTrue(odd and all(dtl(f).get("config_status") == "unknown_transform" for f in odd),
                        "everything derived from an unsupported transform is unknown for that configuration")

    def test_xdt_odd_transform_is_flagged_unsupported(self):
        r = self.case("xdt-effective")
        odd = need_fact(r, "config_transform", config="Odd")
        by_op = {dtl(f).get("operation"): dtl(f) for f in odd}
        self.assertIn("InsertAfter", by_op)
        self.assertIs(by_op["InsertAfter"].get("supported"), False)
        self.assertTrue(any(dtl(f).get("locator") == "XPath" and dtl(f).get("supported") is False for f in odd))
        for f in r.facts_of("config_transform", config="Release"):
            self.assertIs(dtl(f).get("supported"), True)

    def test_xdt_overridden_in_recorded_without_values(self):
        r = self.case("xdt-effective")
        env = facts_at(r, "config_key", WEB_CONFIG, "Environment")
        need(env and "overridden_in" in dtl(env[0]), "overridden_in", "Environment is overridden per configuration")
        self.assertEqual(as_list(dtl(env[0])["overridden_in"]), ["Debug", "Release", "Staging"])
        ids = facts_at(r, "config_key", WEB_CONFIG, "TesterIds")
        self.assertEqual(as_list(dtl(ids[0]).get("overridden_in")), ["Release"])
        conn = facts_at(r, "connection", WEB_CONFIG, "PortalDb")
        self.assertEqual(as_list(dtl(conn[0]).get("overridden_in")), ["Release", "Staging"])
        self.assertNotIn("E1001", json.dumps([dtl(f) for f in env + ids]), "no values")

    # --- location-paths / nested-webconfig (access_rule only)
    def test_location_path_forms(self):
        r = self.case("location-paths")
        need_fact(r, "access_rule", config="base")
        by_role = {}
        for f in r.facts_of("access_rule", config="base"):
            for role in lower_set(dtl(f).get("roles")):
                by_role[role] = f
        for role in ("dot", "empty", "absent"):    # ".", "" and no path all mean "this folder and below"
            self.assertEqual(scope_of(by_role[role]), "", role)
        self.assertEqual(scope_of(by_role["tilde"]), "admin", "a leading ~/ is stripped")
        self.assertEqual(scope_of(by_role["mixedcase"]), "admintools", "paths are case-insensitive")
        self.assertNotEqual(scope_of(by_role["mixedcase"]), scope_of(by_role["tilde"]), "segment boundary")

    def test_location_allow_override_and_system_webserver_only(self):
        r = self.case("location-paths")
        need_fact(r, "access_rule", config="base")
        locked = [f for f in r.facts_of("access_rule", config="base") if dtl(f).get("effect") == "deny" and scope_of(f) == "locked"]
        need(locked and "allow_override" in dtl(locked[0]), "allow_override", "allowOverride is not recorded")
        self.assertIs(dtl(locked[0]).get("allow_override"), False)
        private = [f for f in r.facts_of("access_rule", config="base") if scope_of(f) == "private"]
        self.assertIs(dtl(private[0]).get("inherit_in_child_apps"), False, "disclosed, not evaluated")
        self.assertEqual([f for f in r.facts_of("access_rule") if scope_of(f) == "legacy"], [],
                         "a <location> with only system.webServer is not ASP.NET authorization")

    def test_nested_webconfig_scope_paths(self):
        r = self.case("nested-webconfig")
        admin = need_fact(r, "access_rule", config="base", scope_path="Admin")
        self.assertEqual(sorted(dtl(f)["effect"] for f in admin), ["allow", "deny"])
        self.assertEqual({f["path"] for f in admin}, {"Admin/Web.config"})
        area = [f for f in r.facts_of("access_rule") if f["path"] == "Areas/Reports/Web.config"]
        self.assertEqual({scope_of(f) for f in area}, {"areas/reports"}, "the folder of the file, not the routed URL")

    # --- windows-auth-iis / owin-none
    def test_windows_auth_iis_anonymous_is_unknown_and_disclosed(self):
        r = self.case("windows-auth-iis")
        host = need_fact(r, "host_auth")
        self.assertEqual(dtl(host[0]).get("iis_anonymous"), "unknown")
        self.assertNotEqual(dtl(host[0]).get("source"), "config", "no read file sets anonymousAuthentication")
        self.assertIs(dtl(host[0]).get("owin_auth"), False)
        self.assertIs(dtl(host[0]).get("iis_authorization_present"), False)
        legacy = self.case("location-paths")
        self.assertTrue(legacy.facts_of("host_auth", iis_authorization_present=True),
                        "system.webServer authorization is recorded as IIS rules, not evaluated")

    def test_owin_none_is_disclosed(self):
        r = self.case("owin-none")
        need_fact(r, "host_auth", owin_auth=True)
        need_fact(r, "security_setting", name="system.web/authentication@mode", value="none", config="base")


class Slice1Code(CorpusCase):
    """Shared-Target cases for W3, W5, W6 (4B, 4D)."""

    # --- core-false-positive / stack-markers / winforms-handlers
    def _stack_ids(self, r):
        return [s.get("name") for s in r.facts["stacks"]]

    def test_core_false_positive_old_style_projects_are_aspnet(self):
        r = self.case("core-false-positive")
        ids = self._stack_ids(r)
        need("aspnet-core" not in ids, "classification", f"aspnet-core is detected from sample projects: {ids}")
        self.assertIn("aspnet", ids)

    def test_core_false_positive_old_style_project_files_are_not_core_markers(self):
        r = self.case("core-false-positive")
        markers = [m for s in r.facts["stacks"] if s.get("name") == "aspnet-core"
                   for m in as_list(dtl(s).get("marker_files"))]
        self.assertEqual([m for m in markers if m.startswith("Contoso.Portal")], [],
                         "a .csproj plus Program.cs (WinForms, test project) is not ASP.NET Core")
        aspnet = [s for s in r.facts["stacks"] if s.get("name") == "aspnet"]
        self.assertTrue(aspnet and any(m.startswith("Contoso.Portal/") for m in dtl(aspnet[0]).get("marker_files", [])))

    def test_stack_markers_in_fixtures_and_tooling_are_ignored(self):
        r = self.case("stack-markers")
        ignored = sum(int(dtl(s).get("ignored_markers") or 0) for s in r.facts["stacks"])
        need(ignored >= 1, "ignored_markers", "no stack records the markers it dropped")
        ids = self._stack_ids(r)
        self.assertNotIn("aspnet-core", ids)
        self.assertNotIn("node-express", ids)
        stray = [f for f in r.facts["facts"] if f["kind"] != "file" and f["path"].startswith(("fixtures/", "tests/"))]
        self.assertEqual(stray, [], "fixture projects contribute no Facts")

    def test_winforms_handlers_are_not_web_entry_points(self):
        r = self.case("winforms-handlers")
        web = [f for f in r.facts_of("entry_point") if f["path"].startswith("Contoso.Portal.Harness/")
               and dtl(f).get("type") != "desktop"]
        need(not web, "classification", f"WinForms code produces web entry points: {[f['name'] for f in web]}")
        self.assertEqual([f for f in r.facts_of("entry_point") if dtl(f).get("class") == "HarnessController"], [])
        self.assertTrue(r.facts_of("entry_point", handler="HomeController.Index"), "MVC controllers still found")

    def test_winforms_harness_is_one_desktop_entry_point(self):
        r = self.case("winforms-handlers")
        desktop = need_fact(r, "entry_point", type="desktop")
        self.assertEqual([f["path"] for f in desktop], ["Contoso.Portal.Harness/Program.cs"])
        self.assertEqual(desktop[0]["line"], line_of(r, "Contoso.Portal.Harness/Program.cs", "static void Main"))
        self.assertTrue(facts_at(r, "ui_page", "Contoso.Portal.Harness/HarnessForm.cs"), "the form is a page")
        core = [f for f in r.facts_of("entry_point", type="desktop") if f["path"].startswith("Contoso.Portal.Core/")]
        self.assertEqual(core, [], "a Core web Exe is not desktop")
        caps = [c for s in r.facts["stacks"] for c in as_list(dtl(s).get("capabilities"))]
        self.assertIn("entry_point.desktop", caps)

    # --- build-defines / publish-profile
    def test_build_defines_per_configuration(self):
        r = self.case("build-defines")
        csproj = PORTAL + "Contoso.Portal.csproj"
        want = {"Debug": ["DEBUG", "TRACE"], "Staging": ["STAGING", "TRACE"], "Release": ["TRACE"],
                "Odd": ["ODD", "TRACE"], "Training": ["TRAINING"]}
        got = {dtl(f)["config"]: f for f in need_fact(r, "build_define") if f["path"] == csproj}
        self.assertEqual(sorted(got), sorted(want))
        for config, symbols in want.items():
            self.assertEqual(as_list(dtl(got[config]).get("symbols")), symbols, config)
        self.assertIs(dtl(got["Training"]).get("inherits"), True, "$(DefineConstants) is inherited")
        self.assertFalse(dtl(got["Debug"]).get("inherits"))

    def test_project_facts_from_csproj(self):
        r = self.case("build-defines")
        need_fact(r, "build_define")
        kinds = {f["path"]: dtl(f) for f in r.facts_of("project")}
        self.assertEqual(kinds[PORTAL + "Contoso.Portal.csproj"].get("kind"), "web")
        self.assertEqual(str(kinds["Contoso.Portal.Harness/Contoso.Portal.Harness.csproj"].get("output_type")).lower(), "winexe")
        self.assertEqual(kinds["Contoso.Portal.Harness/Contoso.Portal.Harness.csproj"].get("kind"), "winforms")
        self.assertEqual(kinds["Contoso.Portal.Tests/Contoso.Portal.Tests.csproj"].get("kind"), "test")
        self.assertIs(kinds["Contoso.Portal.Tests/Contoso.Portal.Tests.csproj"].get("test"), True)

    def test_publish_profile_host_only(self):
        r = self.case("publish-profile")
        prof = {f["name"]: dtl(f) for f in need_fact(r, "publish_profile")}
        self.assertEqual(sorted(prof), ["Production", "Staging"])
        self.assertEqual((prof["Staging"].get("build_config"), prof["Staging"].get("method"), prof["Staging"].get("host")),
                         ("Staging", "MSDeploy", "deploy-stg.contoso.test"))
        self.assertEqual((prof["Production"].get("build_config"), prof["Production"].get("method"),
                          prof["Production"].get("host")), ("Release", "FileSystem", "deploy.contoso.test"))
        text = case_text(r)
        for leak in ("deploy-stg-user", "InventedEncryptedBlobMarker0001", "msdeploy.axd", "launch=1"):
            self.assertNotIn(leak, text)
        self.assertEqual([f for f in r.facts_of("publish_profile") if f["path"].endswith(".pubxml.user")], [])

    # --- route-area
    def _route(self, r, handler):
        found = entries_of(r, handler)
        need(found, "entry_point", handler)
        return found

    def test_route_area_three_styles_and_prefixes(self):
        r = self.case("route-area")
        inv = self._route(r, "InvoicesController.Index")[0]
        need("mvc_area" in dtl(inv), "mvc_area", "no mvc_area on an MVC entry_point")
        self.assertEqual((inv["name"], dtl(inv)["mvc_area"], dtl(inv).get("mvc_area_path")),
                         ("/billing/invoices/{id:int?}", "Billing", "Areas/Billing"))          # name plus AreaPrefix
        batch = self._route(r, "BatchController.Run")[0]
        self.assertEqual((batch["name"], dtl(batch).get("mvc_area"), dtl(batch).get("mvc_area_path")),
                         ("/uploads/batch/run", "Uploads", "Areas/Uploads"))                   # prefix only, spaced attributes
        root = self._route(r, "RootController.Index")[0]
        self.assertEqual(root["name"], "/about")
        self.assertNotIn("mvc_area_path", dtl(root), "an empty RouteArea is the root: no area_path")
        self.assertIn(dtl(root).get("mvc_area", ""), ("", None))

    def test_route_area_registration_literal_and_folder_win(self):
        r = self.case("route-area")
        regs = {f["path"].split("/")[-1]: f for f in r.facts_of("entry_point", type="route") if "handler" not in dtl(f)}
        self.assertEqual(regs["PublicAreaRegistration.cs"]["name"], "/info/{controller}/{action}/{id}",
                         "the area URL is the registration literal, not the folder name")
        self.assertEqual(dtl(regs["PublicAreaRegistration.cs"]).get("mvc_area_path"), "Areas/Public")
        self.assertEqual(regs["ReportsAreaRegistration.cs"]["name"], "/reports/{controller}/{action}/{id}")
        self.assertFalse([f for f in r.facts_of("entry_point") if f["name"].lower().startswith("/public/")])
        export = self._route(r, "ExportController.Index")[0]
        self.assertEqual((dtl(export).get("mvc_area"), dtl(export).get("mvc_area_path")), ("Reports", "Areas/Reports"),
                         "the folder wins over a namespace that names another area")

    def test_route_area_tilde_and_attribute_routes_exclude_conventional(self):
        r = self.case("route-area")
        self.assertEqual([f["name"] for f in self._route(r, "RootController.Status")], ["/status"], "~/ ignores the prefix")
        self.assertEqual([f["name"] for f in self._route(r, "AccountController.Login")], ["/signin"],
                         "an action with [Route] is not reachable by the conventional route")
        home = self._route(r, "HomeController.Index")[0]
        self.assertNotIn("mvc_area_path", dtl(home))
        self.assertEqual([f["name"] for f in self._route(r, "RootController.Team")], ["/about/team/{name?}"],
                         "no duplicate, optional parameter kept")
        in_areas = [f for f in r.facts_of("entry_point", type="route") if "/Areas/" in f["path"] and "handler" in dtl(f)]
        self.assertTrue(in_areas)
        self.assertTrue(all(dtl(f).get("mvc_area") and dtl(f).get("mvc_area_path") for f in in_areas),
                        "every MVC entry_point under Areas/ carries mvc_area and mvc_area_path")

    # --- custom-guard / secrets-never-recorded
    def test_custom_guard_external_attribute_is_a_candidate(self):
        r = self.case("custom-guard")
        cands = {dtl(f)["attribute"]: dtl(f) for f in need_fact(r, "guard_candidate")}
        self.assertGreaterEqual(int(cands["ContosoGuard"]["uses"]), 3)
        self.assertEqual(as_list(cands["ContosoGuard"]["arity_set"]), [4, 5])
        self.assertIn("ContosoLayout", cands, "a non-guard attribute used three times is listed too (layout injection)")
        self.assertEqual(as_list(cands["ContosoLayout"]["arity_set"]), [1])

    def test_custom_guard_declared_in_context_is_auth_check_declared(self):
        r = self.case("custom-guard", files={"appdoc-context.md": "Auth attributes: ContosoGuard\n"})
        declared = need_fact(r, "auth_check", via="declared")
        self.assertTrue(all("ContosoGuard" in f["name"] for f in declared))
        self.assertEqual([f for f in r.facts_of("guard_candidate") if dtl(f).get("attribute") == "ContosoGuard"], [],
                         "a declared attribute is no longer a candidate")
        need_fact(r, "context_directive", directive="Auth attributes")

    def test_custom_guard_arguments_arity_and_credential_constant(self):
        r = self.case("custom-guard")
        uses = [dtl(f) | {"path": f["path"]} for f in need_fact(r, "guard_use", attribute="ContosoGuard")]
        inv = [u for u in uses if u["path"].endswith("InvoicesController.cs")]
        self.assertEqual(sorted((u["scope"], u["arity"]) for u in inv), [("class", 5), ("method", 4)],
                         "the method-level use overrides the class-level use with a different arity")
        cls = next(u for u in inv if u["scope"] == "class")
        self.assertEqual(as_list(cls["arg_kinds"])[-1], "secret", "the credential constant is a secret argument")
        self.assertEqual((cls.get("role_ref"), cls.get("role")), ("Roles.Finance", "FinanceStaff"))
        self.assertNotIn("not-a-real-credential-0001", case_text(r))

    def test_custom_guard_auth_method_promotion_lists_constants(self):
        r = self.case("custom-guard")
        calls = need_fact(r, "auth_check", via="call")
        roles = set()
        for f in calls:
            roles |= lower_set(dtl(f).get("roles"))
        self.assertTrue({"portaladmins", "financestaff"} <= roles, roles)
        self.assertTrue(all("HasRole" in f["name"] for f in calls))

    def test_secrets_never_recorded_secret_constant_is_not_resolved(self):
        r = self.case("secrets-never-recorded")
        secret = need_fact(r, "const_def", qualified="Accounts.ServicePassword")
        self.assertIs(dtl(secret[0]).get("secret"), True)
        self.assertNotIn("value", dtl(secret[0]), "R19: a secret constant is never value-resolved")
        role = need_fact(r, "const_def", qualified="Roles.Admin")
        self.assertEqual(dtl(role[0]).get("value"), "PortalAdmins")
        modes = [as_list(dtl(f).get("under_if")) for f in r.facts_of("const_def", qualified="MvcApplication.Mode")]
        self.assertIn(["DEBUG"], modes)
        self.assertIn(["STAGING"], modes)

    def test_secrets_never_recorded_wcf_address_is_scheme_and_host(self):
        r = self.case("secrets-never-recorded")
        svc = need_fact(r, "external_call", type="service", via="Contoso.Portal.IReportService")
        self.assertEqual(svc[0]["name"], "https://reports.contoso.test:8443")
        text = case_text(r)
        for leak in ("svcuser", "not-a-real-pw", "token=abc", "frag"):
            self.assertNotIn(leak, text)

    def test_secrets_never_recorded_named_users_counted_not_recorded(self):
        r = self.case("secrets-never-recorded")
        root = [f for f in rules_of(r, WEB_CONFIG, "base") if dtl(f).get("users_named")]
        need(root, "users_named", "access_rule has no users_named count")
        self.assertEqual([dtl(f)["users_named"] for f in root], [2])
        billing = [dtl(f).get("users_named") for f in rules_of(r, WEB_CONFIG, "base", "billing") if dtl(f).get("users_named")]
        self.assertEqual(billing, [2], "CONTOSO\\pat and contoso\\PAT are one user")
        self.assertNotRegex(case_text(r).lower(), r"contoso\\+(pat|sam)\b")

    def test_secrets_never_recorded_no_secret_value_in_any_fact_or_summary(self):
        r = self.case("secrets-never-recorded")
        text = case_text(r)
        self.assertEqual([s for s in TARGET_SECRETS if s in text], [])
        self.assertTrue(facts_at(r, "config_key", name="ReportServerPassword"), "the secret's location is still recorded")
        pw = facts_at(r, "config_key", name="ReportServerPassword")[0]
        self.assertTrue(dtl(pw).get("secret_location"))


class Slice1Protection(CorpusCase):
    """W4 cases (effective protection per handler, 4E). Own tiny Targets give crisp chains; they land after the
    first slice, so PENDING names T28.6x tasks."""

    def _reach(self, r, handler):
        d = need_entry(r, handler, "reach_anon")
        return d

    def test_url_auth_chain_merge(self):
        r = self.case("url-auth-merge")
        want = {"FallThroughController.Index": ("deny", "deny"),      # allow roles only falls through
                "WinsController.Index": ("allow", "allow"),             # first match wins
                "ChildController.Index": ("allow", "deny"),            # a child folder's file before the parent
                "ClearedController.Index": ("allow", "allow"),         # <clear/> then the implicit allow *
                "RemovedController.Index": ("allow", "allow"),         # <remove users="*"/> drops the inherited deny
                "TieController.Index": ("allow", "allow"),             # same segment count: document order
                "VerbsController.List": ("allow", "allow"),
                "VerbsController.Save": ("deny", "deny"),              # deny verbs="POST"
                "HomeController.Index": ("deny", "deny")}
        for handler, (anon, auth) in want.items():
            d = self._reach(r, handler)
            self.assertEqual((handler, d["reach_anon"], d.get("reach_auth")), (handler, anon, auth))
        self.assertEqual(self._reach(r, "NamedController.Index")["reach_anon"], "unknown", "a named user before the decision")
        self.assertEqual(self._reach(r, "FallThroughController.Index")["reach"], "role_restricted")
        self.assertEqual(lower_set(self._reach(r, "FallThroughController.Index")["reach_roles"]), {"admins", "staff"})
        self.assertEqual(self._reach(r, "WinsController.Index")["reach"], "no_app_restriction")

    def test_nested_webconfig_applies_by_url_prefix_not_area_folder(self):
        r = self.case("nested-webconfig")
        admin = self._reach(r, "AdminController.Index")
        self.assertEqual((admin["reach_anon"], admin["reach"]), ("deny", "role_restricted"))
        self.assertEqual(lower_set(admin["reach_roles"]), {"admins"})
        export = self._reach(r, "ExportController.Index")      # URL /reports/Export/Index: Areas/Reports/Web.config does not apply
        self.assertEqual((export["reach_anon"], export["reach"]), ("allow", "no_app_restriction"))

    def test_route_aliases_all_checked_and_open_route_is_unknown(self):
        r = self.case("route-aliases")
        home = self._reach(r, "HomeController.Index")
        urls = {("/" + str(u).strip("/")).lower() for u in as_list(home.get("url_set"))}
        self.assertTrue({"/", "/home", "/home/index"} <= urls, urls)
        self.assertEqual(home["reach_anon"], "allow", "a rule on Home/Index does not protect / or /Home")
        docs = self._reach(r, "DocsController.Show")
        self.assertEqual(docs.get("url_set"), "open")
        self.assertEqual(docs["reach_anon"], "unknown")
        self.assertIn("url_set_open", as_list(docs.get("reasons")))

    def test_filter_composition(self):
        r = self.case("filter-composition")
        got = {h: (self._reach(r, h)["reach_anon"], self._reach(r, h).get("reach_auth")) for h in (
            "PlainController.Index", "OpenController.Index", "LockedController.Index", "OverrideController.Index",
            "BothController.Index", "OrphanController.Index")}
        self.assertEqual(got["PlainController.Index"], ("deny", "allow"), "the global AuthorizeAttribute applies")
        self.assertEqual(got["OpenController.Index"][0], "allow", "[AllowAnonymous] on the controller disables Authorize")
        self.assertEqual(got["LockedController.Index"][0], "deny", "...but not a URL deny")
        self.assertEqual(got["OverrideController.Index"][0], "allow", "[OverrideAuthorization] clears outer filters")
        self.assertEqual(got["BothController.Index"], ("deny", "deny"), "Roles and Users on one attribute are ANDed")
        self.assertEqual(got["OrphanController.Index"][0], "unknown", "an unresolved base type is unknown")
        orphan = dtl(entries_of(r, "OrphanController.Index")[0])
        self.assertIn("unknown", as_list(orphan.get("guard_mechanism")))

    def test_core_fallback_policy_mechanism_only_no_reach(self):
        r = self.case("core-fallback-policy")
        d = need_entry(r, "StatusController.Get", "guard_mechanism")
        self.assertNotIn("reach", d)
        self.assertNotIn("reach_anon", d)
        self.assertNotEqual(as_list(d["guard_mechanism"]), ["none"], "AddAuthorization is registered: no absence claim")

    def test_core_absence_claim_only_without_auth_services(self):
        bare = ("var builder = WebApplication.CreateBuilder(args);\nbuilder.Services.AddControllers();\n"
                "var app = builder.Build();\napp.MapControllers();\napp.Run();\n")
        r = self.case("core-fallback-policy", files={"Contoso.Portal.Core/Program.cs": bare})
        d = need_entry(r, "StatusController.Get", "guard_mechanism")
        self.assertEqual(as_list(d["guard_mechanism"]), ["none"], "no auth service of any kind is registered")
        reset = dtl(entries_of(r, "StatusController.Reset")[0])
        self.assertNotEqual(as_list(reset["guard_mechanism"]), ["none"])

    def test_owin_with_mode_none_is_unknown(self):
        r = self.case("owin-none")
        d = need_entry(r, "UploadsController.Save", "reach")
        self.assertEqual(d["reach"], "unknown")
        self.assertIn("owin", as_list(d.get("reasons")))

    def test_verbless_actions_are_any_and_state_changing_is_tristate(self):
        r = self.case("verbless-actions")
        sub = need_entry(r, "HomeController.Subscribe", "verbs_declared")
        self.assertIs(sub["verbs_declared"], False)
        self.assertEqual(as_list(sub["verbs"]), ["any"], "a verb-less MVC 5 action accepts every verb")
        self.assertEqual((str(sub["state_changing"]).lower(), sub.get("writes")), ("true", True), "any verb with a write hit")
        contact = dtl(entries_of(r, "HomeController.Contact")[0])
        self.assertEqual(str(contact["state_changing"]).lower(), "unknown", "verb-less with no write hit")
        self.assertEqual(str(dtl(entries_of(r, "AccountController.Details")[0])["state_changing"]).lower(), "false")
        self.assertEqual(str(dtl(entries_of(r, "AccountController.Manage")[0])["state_changing"]).lower(), "true")

    def test_verbless_web_api_verb_from_name_convention(self):
        r = self.case("verbless-actions")
        post = need_entry(r, "ItemsController.PostItem", "verbs")
        self.assertEqual(as_list(post["verbs"]), ["POST"])
        self.assertIs(post.get("verbs_declared"), False)
        self.assertEqual(str(post["state_changing"]).lower(), "true")
        self.assertEqual(as_list(dtl(entries_of(r, "ItemsController.GetItems")[0])["verbs"]), ["GET"])


# ---- Check cases (their own docs/appdoc): C21 and C22 are written to the new rules.

def _recheck(r, narrative):
    """Write ``narrative`` over the case's Narrative and run the Check again in process."""
    with open(os.path.join(r.out, check.NARRATIVE), "w", encoding="utf-8", newline="\n") as fh:
        fh.write(narrative)
    with contextlib.redirect_stdout(io.StringIO()):
        seal.seal_register(r.target, r.out)
        code = run_as_stamped(narrative, check.run, r.target, r.out, False, False)
    with open(os.path.join(r.out, "check-report.md"), encoding="utf-8") as fh:
        return code, fh.read()


class Slice1CheckRules(CorpusCase):
    def test_config_not_reviewed_c21_fails_without_a_lined_citation(self):
        r = self.case("config-not-reviewed")
        self.assertEqual(r.code, 0, "today's rules pass this document: only the new rule can fail it\n" + r.report)
        need("C21" in r.rules(), "C21", "the Check does not require Web.config to be cited")
        self.assertEqual(r.code, 2, r.report)
        self.assertIn("this file is mandatory input (R16); read it and cite what it shows, redacting values", r.report)
        self.assertIn("Web.config", r.report)

    def test_config_not_reviewed_c21_passes_with_a_lined_citation_outside_blocks(self):
        r = self.case("config-not-reviewed")
        need("C21" in r.rules(), "C21", "the Check does not require Web.config to be cited")
        text = r.narrative
        marker = "- The admin check is made at `app/main.py:4`."
        self.assertIn(marker, text)
        bare = text.replace(marker, marker + "\n- Windows authentication is set in `Web.config`.")
        code, report = _recheck(r, bare)
        self.assertIn("C21", re.findall(r"^## (C\d+) ", report, re.M), "a bare file name is not a lined citation")
        lined = text.replace(marker, marker + "\n- Windows authentication is set at `Web.config:4`, and only role Staff is allowed at `Web.config:6`.")
        code, report = _recheck(r, lined)
        self.assertNotIn("C21", re.findall(r"^## (C\d+) ", report, re.M), report)
        self.assertEqual(code, 0, report)

    def test_area_coverage_c22_fails_when_an_area_is_missing_from_4_1(self):
        r = self.case("area-coverage")
        self.assertEqual(r.code, 0, "today's rules pass this document: only the new rule can fail it\n" + r.report)
        areas = [dtl(f).get("mvc_area_path") for f in r.facts_of("entry_point") if dtl(f).get("mvc_area_path")]
        need(areas, "mvc_area_path", "the area's entry points carry no mvc_area_path")
        need("C22" in r.rules(), "C22", "the Check does not require every area in 4.1")
        self.assertEqual(r.code, 2, r.report)
        self.assertIn("Areas/Billing", r.report)
        self.assertEqual(areas, ["Areas/Billing"])


class Slice1Registry(unittest.TestCase):
    def test_new_cases_fail_for_their_stated_reason(self):
        """Every PENDING test of these classes fails today with ``Missing`` naming the token its reason starts with
        ("missing <token>: ..."): not a crash, a bad Target or an unrelated assertion (T28.03)."""
        checked = 0
        for cls in (Slice1Config, Slice1Code, Slice1Protection, Slice1CheckRules):
            for name, (task, reason) in sorted(PENDING.items()):
                if name not in vars(cls):
                    continue
                m = re.match(r"missing (\S+?):", reason)
                self.assertTrue(m, f"{name}: the PENDING reason must start with 'missing <token>:'")
                result = unittest.TestResult()
                cls(name).run(result)
                self.assertEqual(result.unexpectedSuccesses, [], f"{name} ({task}) passes: delete its PENDING entry")
                self.assertEqual(result.errors, [], name)
                self.assertEqual(len(result.expectedFailures), 1, f"{name}: {result.skipped}")
                tb = result.expectedFailures[0][1].strip().splitlines()[-1]
                self.assertRegex(tb, r"^(tests\.test_corpus\.)?Missing: missing " + re.escape(m.group(1)),
                                 f"{name} ({task}) fails for another reason: {tb}")
                checked += 1
        self.assertGreaterEqual(checked, 1)


def _apply_pending():
    for cls in CorpusCase.__subclasses__():
        for name in PENDING:
            if name in vars(cls):
                setattr(cls, name, unittest.expectedFailure(vars(cls)[name]))


_apply_pending()


if __name__ == "__main__":
    unittest.main()
