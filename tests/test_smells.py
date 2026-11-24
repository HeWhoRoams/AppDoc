"""Finding candidates (smells): one positive and one negative case per pattern, comments ignored, 1-based lines."""

import json
import os
import unittest

from appdoc import facts, smells

SAMPLES = os.path.join(os.path.dirname(os.path.abspath(__file__)), "samples", "smells")


def read(rel: str) -> str:
    with open(os.path.join(SAMPLES, rel), encoding="utf-8", newline="") as fh:
        return fh.read()


def run(rel: str, stacks=None, path=None):
    return list(smells.extract(path or rel, read(rel), stacks or []))


def hits(found, pattern):
    return sorted((f.line, f.detail_dict()) for f in found if f.detail_dict()["pattern"] == pattern)


def line_of_text(rel: str, needle: str, nth: int = 1) -> int:
    seen = 0
    for i, line in enumerate(read(rel).splitlines(), 1):
        if needle in line:
            seen += 1
            if seen == nth:
                return i
    raise AssertionError(f"{needle!r} not in {rel}")


class ContractTests(unittest.TestCase):
    def test_fact_shape(self):
        found = run("flask_app.py", ["python-flask"], "project/app.py")
        self.assertTrue(found)
        for f in found:
            self.assertEqual(f.kind, "smell")
            self.assertEqual(f.stack, "python-flask")
            d = f.detail_dict()
            self.assertEqual(d["fid"], facts.fact_id("smell", d["pattern"], f.path, f.line))
            self.assertRegex(d["fid"], r"^[0-9a-f]{8}$")

    def test_generic_stack_when_no_stack_owns_the_file(self):
        found = run("actuator-all/application.properties", [], "application.properties")
        self.assertEqual({f.stack for f in found}, {"generic"})

    def test_first_stack_id_is_used(self):
        found = run("actuator-all/application.properties", ["java-spring", "other"], "application.properties")
        self.assertEqual({f.stack for f in found}, {"java-spring"})

    def test_non_source_and_oversized_files_are_skipped(self):
        self.assertEqual(list(smells.extract("notes.txt", "Invalid username Invalid password", [])), [])
        big = "x = 1\n" * 200_000 + 'PASSWORD = "admin"\n'
        self.assertGreater(len(big), smells.MAX_CHARS)
        self.assertEqual(list(smells.extract("big.py", big, [])), [])

    def test_crlf_files_work(self):
        text = read("flask_app.py").replace("\r\n", "\n").replace("\n", "\r\n")
        found = list(smells.extract("app.py", text, []))
        names = {d["constant"] for _, d in hits(found, "hardcoded-credential-constant")}
        self.assertIn("PASSWORD", names)


class LoggerTypeMismatchTests(unittest.TestCase):
    def test_primary_constructor_field_and_ctor_parameter(self):
        found = hits(run("LoggerSamples.cs"), "logger-type-mismatch")
        got = {(line, d["cls"], d["logger_type"]) for line, d in found}
        self.assertEqual(got, {
            (line_of_text("LoggerSamples.cs", "MismatchedHandler(ILogger<OtherHandler>"), "MismatchedHandler", "OtherHandler"),
            (line_of_text("LoggerSamples.cs", "private readonly ILogger<SomethingElse>"), "FieldMismatch", "SomethingElse"),
            (line_of_text("LoggerSamples.cs", "public FieldMismatch(ILogger<SomethingElse>"), "FieldMismatch", "SomethingElse"),
        })

    def test_matching_generic_object_commented_and_helper_params_are_ignored(self):
        text = "".join(f.name for f in run("LoggerSamples.cs"))
        for ok in ("Matching", "GenericOk", "ObjectOk", "CommentedOut", "Unrelated", "Nope"):
            self.assertNotIn(f"`{ok}`", text)


class FlashWithoutRedirectTests(unittest.TestCase):
    def test_flags_constant_and_literal_views(self):
        found = hits(run("FlashController.java"), "flash-without-redirect")
        self.assertEqual([(l, d["method"]) for l, d in found], [
            (line_of_text("FlashController.java", 'addFlashAttribute("error"'), "bad"),
            (line_of_text("FlashController.java", 'addFlashAttribute("message", "Saved")', 1), "badLiteral"),
        ])

    def test_redirect_and_commented_flash_are_ignored(self):
        methods = {d["method"] for _, d in hits(run("FlashController.java"), "flash-without-redirect")}
        self.assertNotIn("good", methods)
        self.assertNotIn("commented", methods)


class DistinctAuthErrorsTests(unittest.TestCase):
    def test_python_pair_is_reported_at_the_first_literal(self):
        found = hits(run("flask_app.py"), "distinct-auth-errors")
        self.assertEqual(len(found), 1)
        line, d = found[0]
        self.assertEqual(line, line_of_text("flask_app.py", 'error = "Invalid username"'))
        self.assertEqual(d["password_line"], line + 2)

    def test_javascript_pair(self):
        found = hits(run("routes.js"), "distinct-auth-errors")
        self.assertEqual([l for l, _ in found], [line_of_text("routes.js", "User not found")])

    def test_one_combined_message_and_far_apart_messages_are_not_reported(self):
        self.assertEqual(hits(list(smells.extract("a.py", 'x = "Invalid username or password"\n', [])),
                              "distinct-auth-errors"), [])
        far = 'a = "Invalid username"\n' + "\n" * 30 + 'b = "Invalid password"\n'
        self.assertEqual(hits(list(smells.extract("a.py", far, [])), "distinct-auth-errors"), [])

    def test_comments_are_ignored(self):
        text = '# a = "Invalid username"\nb = "Invalid password"\n'
        self.assertEqual(hits(list(smells.extract("a.py", text, [])), "distinct-auth-errors"), [])

    def test_classic_asp(self):
        text = "<%\nIf u = \"\" Then err = \"Unknown user\"\nIf p = \"\" Then err = \"Wrong password\"\n%>\n"
        found = hits(list(smells.extract("login.asp", text, [])), "distinct-auth-errors")
        self.assertEqual([l for l, _ in found], [2])


class UnescapedTemplateOutputTests(unittest.TestCase):
    def test_jinja_safe_and_thymeleaf_utext(self):
        found = hits(run("page.html"), "unescaped-template-output")
        self.assertEqual([(l, d["expression"], d["variable"]) for l, d in found], [
            (line_of_text("page.html", "entry.text|safe"), "jinja-safe-filter", "entry.text"),
            (line_of_text("page.html", 'th:utext="${page.bio}"'), "thymeleaf-utext", "page.bio"),
        ])

    def test_escaped_literal_commented_and_i18n_forms_are_ignored(self):
        names = " ".join(f.name for f in run("page.html"))
        for ignored in ("commented", "html_commented", "data", "message", "hidden", "title", "page.name"):
            self.assertNotIn(f"`{ignored}`", names)

    def test_ejs_raw_output(self):
        found = hits(run("view.ejs"), "unescaped-template-output")
        self.assertEqual([(l, d["variable"]) for l, d in found], [(line_of_text("view.ejs", "article.body"), "article.body")])

    def test_razor_html_raw(self):
        found = hits(run("Page.cshtml"), "unescaped-template-output")
        self.assertEqual([(l, d["variable"]) for l, d in found],
                         [(line_of_text("Page.cshtml", "Html.Raw(Model.Description)"), "Model.Description")])

    def test_markup_call_with_variable_but_not_literal(self):
        found = hits(run("flask_app.py"), "unescaped-template-output")
        self.assertEqual([(l, d["variable"]) for l, d in found],
                         [(line_of_text("flask_app.py", "Markup(request.args"), "request.args")])

    def test_values_are_not_recorded(self):
        for f in run("page.html") + run("view.ejs"):
            self.assertNotIn("<b>", f.name)


class StateChangeOnGetTests(unittest.TestCase):
    def test_flask_get_only_and_default_routes(self):
        found = hits(run("flask_app.py"), "state-change-on-get")
        self.assertEqual([(l, d["handler"]) for l, d in found], [
            (line_of_text("flask_app.py", '@app.route("/delete/<int:post_id>"'), "delete_entry"),
            (line_of_text("flask_app.py", '@app.route("/purge")'), "purge"),
        ])
        self.assertEqual(found[0][1]["route"], "/delete/<int:post_id>")

    def test_flask_post_routes_docstrings_and_set_add_are_ignored(self):
        handlers = {d["handler"] for _, d in hits(run("flask_app.py"), "state-change-on-get")}
        self.assertFalse(handlers & {"remove_entry", "remove_entry_post", "index", "login"})

    def test_spring_get_mapping(self):
        found = hits(run("StateController.java"), "state-change-on-get")
        self.assertEqual([(l, d["handler"]) for l, d in found],
                         [(line_of_text("StateController.java", '@GetMapping("/owners/{id}/delete")'), "deleteOwner")])

    def test_aspnet_http_get(self):
        found = hits(run("ItemsController.cs"), "state-change-on-get")
        self.assertEqual([(l, d["handler"]) for l, d in found],
                         [(line_of_text("ItemsController.cs", '[HttpGet("items/{id}/remove")]'), "Remove")])

    def test_express_get(self):
        found = hits(run("routes.js"), "state-change-on-get")
        self.assertEqual([(l, d["route"]) for l, d in found],
                         [(line_of_text("routes.js", 'router.get("/users/:id/delete"'), "/users/:id/delete")])


class ActuatorExposedTests(unittest.TestCase):
    def test_properties_wildcard(self):
        found = hits(run("actuator-all/application.properties", path="application.properties"), "actuator-exposed")
        self.assertEqual([l for l, _ in found], [3])

    def test_yaml_nested_wildcard_only_in_first_document(self):
        found = hits(run("actuator-all/application.yml", path="application.yml"), "actuator-exposed")
        self.assertEqual([l for l, _ in found], [8])

    def test_limited_exposure_and_commented_wildcard(self):
        for rel in ("actuator-limited/application.properties", "actuator-limited/application.yml"):
            self.assertEqual(hits(run(rel, path=os.path.basename(rel)), "actuator-exposed"), [], rel)

    def test_other_file_names_are_ignored(self):
        text = read("actuator-all/application.properties")
        self.assertEqual(list(smells.extract("config.properties", text, [])), [])


class HardcodedCredentialTests(unittest.TestCase):
    def names(self, rel, path=None):
        return [(l, d["constant"]) for l, d in hits(run(rel, path=path), "hardcoded-credential-constant")]

    def test_python_module_constants(self):
        self.assertEqual(self.names("flask_app.py"), [
            (line_of_text("flask_app.py", "PASSWORD = "), "PASSWORD"),
            (line_of_text("flask_app.py", "SECRET_KEY = "), "SECRET_KEY"),
            (line_of_text("flask_app.py", "API_TOKEN = "), "API_TOKEN"),
        ])

    def test_java_static_final(self):
        self.assertEqual([n for _, n in self.names("Settings.java")], ["ADMIN_PASSWORD", "API_KEY"])

    def test_csharp_const_and_static_readonly(self):
        self.assertEqual([n for _, n in self.names("ItemsController.cs")], ["ConnectionPassword", "ApiKey"])

    def test_javascript_top_level_const(self):
        self.assertEqual([n for _, n in self.names("routes.js")], ["API_KEY"])

    def test_secret_values_never_appear_in_facts(self):
        for rel in ("flask_app.py", "Settings.java", "ItemsController.cs", "routes.js"):
            for f in run(rel):
                blob = f.name + repr(f.detail)
                for value in ("admin", "change_me", "abc123", "changeit", "k-123", "p@ssw0rd!", "k-12345", "sk-example-123"):
                    self.assertNotIn(f'"{value}"', blob)
                    if f.detail_dict()["pattern"] == "hardcoded-credential-constant":
                        self.assertNotIn(value, blob)

    def test_test_files_are_skipped(self):
        text = read("flask_app.py")
        self.assertEqual(hits(list(smells.extract("tests/test_app.py", text, [])), "hardcoded-credential-constant"), [])
        self.assertEqual(hits(list(smells.extract("src/test/java/AppTest.java", read("Settings.java"), [])),
                              "hardcoded-credential-constant"), [])

    def test_env_references_and_url_values_are_not_constants_to_report(self):
        text = 'A_PASSWORD = "${APP_PASSWORD}"\nB_TOKEN = "https://x.test/t"\nC_SECRET = ""\nD_TOKEN = "csrf-token"\n'
        self.assertEqual(hits(list(smells.extract("a.py", text, [])), "hardcoded-credential-constant"), [])


class LineNumberTests(unittest.TestCase):
    def test_lines_are_one_based_with_leading_blank_lines(self):
        text = "\n\n\nPASSWORD = 'x1'\n"
        self.assertEqual([f.line for f in smells.extract("a.py", text, [])], [4])

    def test_first_line_hit(self):
        self.assertEqual([f.line for f in smells.extract("a.py", "PASSWORD = 'x1'\n", [])], [1])


# ---------------------------------------------------------------------------------------------------------------
# 2.8 W11 (4F): the Facts-level pass, the .config patterns, the null patterns, the obligation gate
# ---------------------------------------------------------------------------------------------------------------

from appdoc import dotnetcfg                                  # noqa: E402
from appdoc import dotnetsec as S                             # noqa: E402
from tests.test_dotnetsec import GLOBAL, cfg, of, run as run_target  # noqa: E402
from tests.test_configs import transform                      # noqa: E402

Fact = facts.Fact


def cs(body: str) -> str:
    return "using System;\nnamespace Contoso.Web\n{\n" + body + "\n}\n"


def null_hits(text, pattern, stacks=("aspnet",)):
    return [(f.line, f.name) for f in smells.extract("Code/A.cs", text, list(stacks))
            if f.detail_dict()["pattern"] == pattern]


def setting(path, line, name, value, config="base", status="base", secret=False):
    return S.setting_fact(path, line, name, value, config, status, secret)


def rule(path, line, named, config="base"):
    return Fact.make("access_rule", "aspnet", path, line, "allow /", effect="allow", scope_path="", order=1,
                     config=config, config_status="base", file=path, users_named=named)


def key(path, line, name, **detail):
    return Fact.make("config_key", "generic", path, line, name, source="Web.config", role="app", use="define",
                     secret_location=False, **detail)


def by_pattern(found, pattern):
    return [f for f in found if f.detail_dict()["pattern"] == pattern]


class FromFactsTests(unittest.TestCase):
    def sample(self):
        return [setting("Web.config", 4, "system.web/machineKey", "literal_hex", secret=True),
                setting("Web.config", 4, "system.web/machineKey", "literal_hex", "Release", secret=True),
                rule("Web.config", 6, 2), rule("Web.config", 7, 0),
                key("Web.config", 9, "AdminUsers", list_count=4, overridden_in=["Release"]),
                setting("Web.config", 12, "system.web/customErrors@mode", "off")]

    def test_from_facts_deterministic_fid(self):
        a = smells.from_facts(self.sample())
        b = smells.from_facts(list(reversed(self.sample())))
        self.assertEqual(a, b)
        self.assertTrue(a)
        for f in a:
            d = f.detail_dict()
            self.assertEqual(f.kind, "smell")
            self.assertEqual(d["fid"], facts.fact_id("smell", d["pattern"], f.path, f.line))
            for src in d["sources"]:
                self.assertEqual(len(src), 4)
                self.assertEqual(src[:2], (f.path, f.line)) if f.kind == "smell" and d["pattern"] != "config-year-horizon" else None

    def test_smell_facts_round_trip_through_json(self):
        for f in smells.from_facts(self.sample()):
            self.assertEqual(Fact.from_json(json.loads(json.dumps(f.to_json()))), f)
            hash(f)

    def test_from_facts_reads_no_source(self):
        import builtins
        real = builtins.open

        def refuse(*a, **k):
            raise AssertionError("from_facts opened a file")
        builtins.open = refuse
        try:
            found = smells.from_facts(self.sample())
        finally:
            builtins.open = real
        self.assertTrue(found)

    def test_sources_are_path_line_kind_name_tuples(self):
        f = by_pattern(smells.from_facts(self.sample()), "machinekey-in-config")[0]
        self.assertEqual(f.detail_dict()["sources"], [("Web.config", 4, "security_setting", "system.web/machineKey")])

    def test_messages_never_echo_names_or_values(self):
        for f in smells.from_facts(self.sample()):
            for word in ("AdminUsers", "machineKey", "customErrors", "literal_hex"):
                self.assertNotIn(word, f.name)

    def test_machinekey_positive_and_negative(self):
        pos = smells.from_facts([setting("Web.config", 4, "system.web/machineKey", "literal_hex", secret=True)])
        self.assertEqual([(f.path, f.line) for f in by_pattern(pos, "machinekey-in-config")], [("Web.config", 4)])
        for value in ("autogenerate", "placeholder", "absent_keys", "absent", "other"):
            self.assertEqual(smells.from_facts([setting("Web.config", 4, "system.web/machineKey", value)]), [], value)

    def test_machinekey_once_across_configurations(self):
        found = by_pattern(smells.from_facts(self.sample()), "machinekey-in-config")
        self.assertEqual(len(found), 1)

    def test_named_user_access_rule_positive_and_negative(self):
        found = by_pattern(smells.from_facts(self.sample()), "named-user-access-rule")
        self.assertEqual([(f.line, f.detail_dict()["count"]) for f in found], [(6, 2)])
        self.assertEqual(smells.from_facts([rule("Web.config", 3, 0)]), [])

    def test_debug_pattern_positive_and_negative(self):
        pos = smells.from_facts([setting("Web.config", 5, "system.web/compilation@debug", "true")])
        self.assertEqual([f.detail_dict()["configs"] for f in by_pattern(pos, "debug-setting-in-nondebug-config")],
                         [["base"]])
        for name, value in (("system.web/compilation@debug", "false"), ("system.web/customErrors@mode", "remoteonly"),
                            ("system.web/compilation@debug", "absent"), ("system.web/customErrors@mode", "on")):
            self.assertEqual(smells.from_facts([setting("Web.config", 5, name, value)]), [], (name, value))

    def test_debug_pattern_uses_effective_config(self):
        n = "system.web/compilation@debug"
        removed = [setting("Web.config", 5, n, "true"), setting("Web.config", 5, n, "absent", "Release", "transformed")]
        self.assertEqual(by_pattern(smells.from_facts(removed), "debug-setting-in-nondebug-config"), [],
                         "the base value is not the effective Release value")
        unknown = [setting("Web.config", 5, n, "true"), setting("Web.config", 5, n, "unknown", "Release",
                                                                "unknown_transform")]
        self.assertEqual(smells.from_facts(unknown), [], "an unevaluable transform is unknown, never the base value")
        inherited = [setting("Web.config", 5, n, "true"), setting("Web.config", 5, n, "true", "Release", "base")]
        found = by_pattern(smells.from_facts(inherited), "debug-setting-in-nondebug-config")
        self.assertEqual([f.detail_dict()["configs"] for f in found], [["Release"]])
        turned_on = [setting("Web.config", 5, n, "false"), setting("Web.config", 5, n, "true", "Staging", "transformed")]
        found = by_pattern(smells.from_facts(turned_on), "debug-setting-in-nondebug-config")
        self.assertEqual([f.detail_dict()["configs"] for f in found], [["Staging"]])

    def test_debug_pattern_lists_debug_config_summary_only(self):
        n = "system.web/compilation@debug"
        group = [setting("Web.config", 5, n, "true"), setting("Web.config", 5, n, "true", "Debug", "base"),
                 setting("Web.config", 5, n, "false", "Release", "transformed")]
        found = smells.from_facts(group)
        self.assertEqual(by_pattern(found, "debug-setting-in-nondebug-config"), [])
        listed = by_pattern(found, "debug-setting-in-debug-config")
        self.assertEqual(len(listed), 1)
        self.assertNotIn("debug-setting-in-debug-config", smells.OBLIGING)

    def test_unlisted_config_name_not_special_cased(self):
        n = "system.web/customErrors@mode"
        for name in ("Staging", "QA", "Dev", "Test", "Local"):
            found = smells.from_facts([setting("Web.config", 5, n, "off", name, "base")])
            self.assertEqual(len(by_pattern(found, "debug-setting-in-nondebug-config")), 1, name)

    def test_identifier_list_positive_and_negative(self):
        found = by_pattern(smells.from_facts(self.sample()), "identifier-list-in-config")
        self.assertEqual([(f.line, f.detail_dict()["count"], f.detail_dict()["overridden_in"]) for f in found],
                         [(9, 4, ["Release"])])
        self.assertEqual(smells.from_facts([key("Web.config", 9, "AdminUsers")]), [])

    def test_year_horizon_needs_reference_year(self):
        k = key("Web.config", 3, "FiscalYear", year=2026)
        self.assertEqual(smells.from_facts([k]), [], "no Reference year: the pattern is off")
        ref = Fact.make("context_directive", "generic", "appdoc-context.md", 1, "Reference year",
                        directive="reference_year", value="2026")
        found = smells.from_facts([k, ref])
        self.assertEqual([f.detail_dict()["pattern"] for f in found], ["config-year-horizon"])
        self.assertNotIn("config-year-horizon", smells.OBLIGING)

    def test_year_horizon_window(self):
        ref = Fact.make("context_directive", "generic", "appdoc-context.md", 1, "Reference year",
                        directive="reference_year", value="2026")
        for y, hit in ((2024, False), (2025, True), (2026, True), (2027, True), (2028, False)):
            found = smells.from_facts([key("Web.config", 3, "FiscalYear", year=y), ref])
            self.assertEqual(bool(found), hit, y)

    def test_year_horizon_requires_key_token(self):
        self.assertIsNone(dotnetcfg.year_value("SiteName", "2026"))
        self.assertIsNone(dotnetcfg.year_value("Weekend", "2026"), "a token, not a substring")
        self.assertEqual(dotnetcfg.year_value("FiscalYearEnd", "2026"), 2026)
        self.assertEqual(dotnetcfg.year_value("FY", "2026"), 2026)
        self.assertEqual(dotnetcfg.year_value("ContractExpiry", "2026"), 2026)
        self.assertIsNone(dotnetcfg.year_value("FiscalYear", "20260"))
        self.assertIsNone(dotnetcfg.year_value("FiscalYear", "FY2026"))

    def test_year_horizon_ignores_ports_and_timeouts(self):
        for k in ("MaxPort", "MaxTimeout", "MaxRetries", "MaxSize", "SmtpPort"):
            self.assertIsNone(dotnetcfg.year_value(k, "2025"), k)

    def test_test_paths_mark_the_smell_as_test(self):
        found = smells.from_facts([setting("Tests/Web.config", 4, "system.web/machineKey", "literal_hex", secret=True)])
        self.assertTrue(found[0].detail_dict().get("test"))


class IdentifierListTests(unittest.TestCase):
    def test_identifier_list_counts_only(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg('<appSettings><add key="AdminUsers" value="u1001,u1002,u1003" />\n'
                                  '<add key="TesterIds" value="1001, 1002, 1003, 1004" /></appSettings>')
        files["Web.Release.config"] = transform('<appSettings><add key="AdminUsers" value="u9,u8,u7,u6" '
                                                'xdt:Transform="SetAttributes" xdt:Locator="Match(key)" /></appSettings>')
        doc = run_target(files)
        found = of(doc, "smell", pattern="identifier-list-in-config")
        self.assertEqual(sorted((f["path"], f["detail"]["count"]) for f in found),
                         [("Web.Release.config", 4), ("Web.config", 3), ("Web.config", 4)])
        blob = json.dumps(doc["facts"])
        for value in ("u1001", "u1002", "1003", "u9", "u6"):
            self.assertNotIn(value, blob)
        base = [f for f in found if f["path"] == "Web.config" and f["detail"]["count"] == 3][0]
        self.assertEqual(base["detail"]["overridden_in"], ["Release"], "reports the overriding configurations")

    def test_identifier_list_shape_rules(self):
        n = dotnetcfg.id_list_count
        self.assertEqual(n("AdminUsers", "1,2,3"), 3)
        self.assertEqual(n("Exempt_Ids", "ab1,cd2,ef3,gh4"), 4)
        self.assertEqual(n("EmployeeIDs", "1001,1002,1003"), 3)
        self.assertEqual(n("ALLOWED", "a1,b2,c3"), 3)
        self.assertEqual(n("AdminUsers", "1,2"), 0, "fewer than 3")
        self.assertEqual(n("AdminUsers", "1,a,3"), 0, "mixed shapes")
        self.assertEqual(n("AdminUsers", "Ann,Bob,Cy"), 0, "not lower-case alphanumerics")
        self.assertEqual(n("AdminUsers", "1,,3"), 0, "an empty token")
        self.assertEqual(n("SiteName", "1,2,3"), 0, "the key's last word is not a list word")
        self.assertEqual(n("UsersCache", "1,2,3"), 0, "only the last word counts")


class ConfigDispatchTests(unittest.TestCase):
    def dup(self, text, path="Web.config"):
        return [(f.line, f.name) for f in smells.extract(path, text, ["aspnet"])
                if f.detail_dict()["pattern"] == "duplicate-config-key"]

    def test_config_dispatch_for_duplicate_key(self):
        text = cfg('<appSettings>\n<add key="A" value="1" />\n<add key="B" value="2" />\n<add key="A" value="3" />\n'
                   '</appSettings>')
        got = self.dup(text)
        self.assertEqual([ln for ln, _ in got], [6])

    def test_duplicate_key_negative(self):
        text = cfg('<appSettings><add key="A" value="1" /><add key="B" value="2" /></appSettings>')
        self.assertEqual(self.dup(text), [])

    def test_duplicate_key_skips_transform_and_external(self):
        body = '<appSettings><add key="A" value="1" /><add key="A" value="2" /></appSettings>'
        self.assertEqual(len(self.dup(cfg(body))), 1)
        self.assertEqual(self.dup(cfg(body), "Web.Release.config"), [], "a transform file by name")
        self.assertEqual(self.dup(cfg(body), "Web.Qa.config"), [], "any name between Web. and .config")
        self.assertEqual(self.dup(cfg(body), "app.Staging.config"), [])
        xdt = transform(body)
        self.assertEqual(self.dup(xdt, "Settings.config"), [], "a transform by its XDT namespace")
        self.assertEqual(self.dup(cfg(body.replace("<appSettings>", '<appSettings file="local.config">'))), [],
                         "an external file may override")
        self.assertEqual(self.dup(cfg(body.replace("<appSettings>", '<appSettings configSource="a.config">'))), [])

    def test_duplicate_key_remove_and_clear_make_the_second_add_legal(self):
        legal = cfg('<appSettings><add key="A" value="1" /><remove key="A" /><add key="A" value="2" /></appSettings>')
        self.assertEqual(self.dup(legal), [])
        cleared = cfg('<appSettings><add key="A" value="1" /><clear /><add key="A" value="2" /></appSettings>')
        self.assertEqual(self.dup(cleared), [])

    def test_duplicate_key_sections_and_comments_are_separate(self):
        text = cfg('<appSettings><add key="A" value="1" /></appSettings>\n<!-- <appSettings><add key="A" /><add key="A" />'
                   '</appSettings> -->\n<location path="x"><appSettings><add key="A" value="2" /></appSettings></location>')
        self.assertEqual(self.dup(text), [])

    def test_duplicate_key_message_names_nothing(self):
        text = cfg('<appSettings><add key="SecretishName" value="1" /><add key="SecretishName" value="2" /></appSettings>')
        got = self.dup(text)
        self.assertNotIn("SecretishName", got[0][1])

    def test_duplicate_key_end_to_end(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg('<appSettings><add key="A" value="1" /><add key="A" value="2" /></appSettings>')
        files["Web.Release.config"] = transform('<appSettings><add key="A" value="1" xdt:Transform="Insert" />'
                                                '<add key="A" value="2" xdt:Transform="Insert" /></appSettings>')
        doc = run_target(files)
        self.assertEqual([f["path"] for f in of(doc, "smell", pattern="duplicate-config-key")], ["Web.config"])


class DebugEndToEndTests(unittest.TestCase):
    def test_debug_pattern_from_a_transform_chain(self):
        files = dict(GLOBAL)
        files["Web.config"] = cfg('<system.web><compilation debug="true" /><customErrors mode="Off" /></system.web>')
        files["Web.Release.config"] = transform(
            '<system.web><compilation xdt:Transform="RemoveAttributes(debug)" />'
            '<customErrors mode="RemoteOnly" xdt:Transform="SetAttributes" /></system.web>')
        files["Web.Staging.config"] = transform('<system.web><customErrors mode="Off" xdt:Transform="SetAttributes" />'
                                                '</system.web>')
        doc = run_target(files)
        found = of(doc, "smell", pattern="debug-setting-in-nondebug-config")
        names = {c for f in found for c in f["detail"]["configs"]}
        self.assertEqual(names, {"Staging"})


class NullPatternTests(unittest.TestCase):
    def test_deref_before_null_check_positive(self):
        text = cs("""class A {
  void M(Customer c) {
    var n = c.Name;
    Log(n);
    if (c == null) { return; }
  }
}""")
        got = null_hits(text, "deref-before-null-check")
        self.assertEqual([ln for ln, _ in got], [6])
        self.assertIn("line 8", got[0][1])
        self.assertNotIn("c.", got[0][1])
        for form in ("c is null", "null == c"):
            self.assertEqual(len(null_hits(text.replace("c == null", form), "deref-before-null-check")), 1, form)

    def test_deref_before_null_check_local_variable_and_index_and_object_method(self):
        text = cs("""class A { void M() {
    Customer c = Find();
    var t = c.ToString();
    if (c == null) { Fail(); }
} }""")
        self.assertEqual(len(null_hits(text, "deref-before-null-check")), 1)
        index = text.replace("c.ToString()", "c[0]")
        self.assertEqual(len(null_hits(index, "deref-before-null-check")), 1)

    def test_deref_before_null_check_negative_checked_first(self):
        text = cs("""class A { void M(Customer c) {
    if (c == null) { return; }
    var n = c.Name;
} }""")
        self.assertEqual(null_hits(text, "deref-before-null-check"), [])

    def test_deref_before_null_check_short_circuit_condition_not_flagged(self):
        for stmt in ("var ok = c == null || c.Name == \"x\";", "var ok = c != null && c.Name == \"x\";",
                     "var n = c != null ? c.Name : \"\";", "var n = c ?? other;"):
            text = cs("class A { void M(Customer c, Customer other) {\n    " + stmt + "\n    if (c == null) { Fail(); }\n} }")
            self.assertEqual(null_hits(text, "deref-before-null-check"), [], stmt)

    def test_deref_in_inner_block_not_flagged(self):
        text = cs("""class A { void M(Customer c, bool flag) {
    if (flag) { var n = c.Name; }
    if (c == null) { Fail(); }
} }""")
        self.assertEqual(null_hits(text, "deref-before-null-check"), [])

    def test_deref_extension_method_not_flagged(self):
        text = cs("""class A { void M(Customer c) {
    var n = c.ToDisplay();
    var m = c.Items.Count();
    if (c == null) { Fail(); }
} }""".replace("c.Items.Count()", "c.Describe(1)"))
        self.assertEqual(null_hits(text, "deref-before-null-check"), [])
        generic = text.replace("c.ToDisplay()", "c.Convert<int>()")
        self.assertEqual(null_hits(generic, "deref-before-null-check"), [])

    def test_deref_conditional_access_not_flagged(self):
        text = cs("""class A { void M(Customer c) {
    var n = c?.Name;
    if (c == null) { Fail(); }
} }""")
        self.assertEqual(null_hits(text, "deref-before-null-check"), [])

    def test_deref_in_branch_not_flagged(self):
        text = cs("""class A { void M(Customer c) {
    if (c != null) c.Touch = 1;
    if (c == null) { Fail(); }
} }""")
        self.assertEqual(null_hits(text, "deref-before-null-check"), [])

    def test_deref_field_not_flagged(self):
        text = cs("""class A {
  Customer c;
  void M() {
    var n = c.Name;
    if (c == null) { Fail(); }
  }
}""")
        self.assertEqual(null_hits(text, "deref-before-null-check"), [], "a field is not a local or a parameter")

    def test_deref_comment_and_string_not_flagged(self):
        text = cs('''class A { void M(Customer c) {
    // var n = c.Name;
    var s = "c.Name";
    /* c.Name */
    var v = @"c.Name ""c.Id""";
    if (c == null) { Fail(); }
} }''')
        self.assertEqual(null_hits(text, "deref-before-null-check"), [])

    def test_deref_reassigned_between_not_flagged(self):
        for between in ("c = Reload();", "c ??= Reload();", "Load(out c);", "c = c.Next;"):
            text = cs("class A { void M(Customer c) {\n    var n = c.Name;\n    " + between
                      + "\n    if (c == null) { Fail(); }\n} }")
            self.assertEqual(null_hits(text, "deref-before-null-check"), [], between)

    def test_deref_short_circuit_not_flagged(self):
        text = cs("""class A { void M(Customer c) {
    var n = c == null || c.Name == "";
    if (c == null) { Fail(); }
} }""")
        self.assertEqual(null_hits(text, "deref-before-null-check"), [])

    def test_deref_before_null_check_control_flow_between_not_flagged(self):
        for between in ("if (x) return;", "throw new Exception();", "goto done;", "done: Touch();", "break;", "continue;"):
            text = cs("class A { void M(Customer c, bool x) {\n    var n = c.Name;\n    " + between
                      + "\n    if (c == null) { Fail(); }\n} }")
            self.assertEqual(null_hits(text, "deref-before-null-check"), [], between)

    def test_deref_before_null_check_lambda_and_nameof_not_flagged(self):
        for stmt in ("Run(() => c.Name);", "var n = nameof(c.Name);"):
            text = cs("class A { void M(Customer c) {\n    " + stmt + "\n    if (c == null) { Fail(); }\n} }")
            self.assertEqual(null_hits(text, "deref-before-null-check"), [], stmt)

    def test_deref_before_null_check_needs_exact_condition(self):
        for cond in ("c == null || d", "c != null", "c == null && d", "!(c == null)", "c == other"):
            text = cs("class A { void M(Customer c, bool d, Customer other) {\n    var n = c.Name;\n    if (" + cond
                      + ") { Fail(); }\n} }")
            self.assertEqual(null_hits(text, "deref-before-null-check"), [], cond)

    def test_deref_before_null_check_only_for_classic_aspnet_files(self):
        text = cs("class A { void M(Customer c) {\n    var n = c.Name;\n    if (c == null) { Fail(); }\n} }")
        self.assertEqual(len(null_hits(text, "deref-before-null-check", ["aspnet"])), 1)
        self.assertEqual(null_hits(text, "deref-before-null-check", ["aspnet-core"]), [])
        self.assertEqual(null_hits(text, "deref-before-null-check", []), [])

    def test_deref_in_null_branch_positive_and_negative(self):
        pos = cs("""class A { void M(Customer c) {
    if (c == null) {
        Log("missing");
        Log(c.Id);
    }
} }""")
        got = null_hits(pos, "deref-in-null-branch")
        self.assertEqual([ln for ln, _ in got], [7])
        single = cs("class A { void M(Customer c) {\n    if (c == null) Log(c.Id);\n} }")
        self.assertEqual(len(null_hits(single, "deref-in-null-branch")), 1)
        for neg in ("if (c != null) { Log(c.Id); }",
                    "if (c == null) { c = new Customer(); Log(c.Id); }",
                    "if (c == null) { return; }",
                    "if (c == null) { Log(c?.Id); }",
                    "if (c == null) { Log(c.Describe()); }",
                    "if (c == null) { if (z) { Log(c.Id); } }",
                    "if (c == null) { Log(1); } else { Log(c.Id); }",
                    "if (c == null) { throw new Exception(c.Id); }"):
            text = cs("class A { void M(Customer c, bool z) {\n    " + neg + "\n} }")
            self.assertEqual(null_hits(text, "deref-in-null-branch"), [], neg)

    def test_deref_in_null_branch_needs_a_local_or_parameter(self):
        text = cs("class A {\n  Customer c;\n  void M() {\n    if (c == null) { Log(c.Id); }\n  }\n}")
        self.assertEqual(null_hits(text, "deref-in-null-branch"), [])

    LOG = """using log4net;
namespace Contoso.Web
{
class A {
  %s
  void M() {
    %s
    if (log == null) { SendMail("fallback"); }
  }
}
}
"""

    def dead(self, text, stacks=("aspnet",)):
        return [f.line for f in smells.extract("Code/A.cs", text, list(stacks))
                if f.detail_dict()["pattern"] == "dead-null-fallback"]

    def test_dead_null_fallback_unqualified_typed_local(self):
        text = self.LOG % ("", "ILog log = LogManager.GetLogger(typeof(A));")
        self.assertEqual(self.dead(text), [8])
        nlog = text.replace("using log4net;", "using NLog;").replace("ILog log", "Logger log").replace(
            "GetLogger(typeof(A))", "GetCurrentClassLogger()")
        self.assertEqual(self.dead(nlog), [8])
        fq = text.replace("using log4net;", "").replace("LogManager.GetLogger", "log4net.LogManager.GetLogger")
        self.assertEqual(self.dead(fq), [8])
        self.assertEqual(self.dead(text.replace("log == null", "null == log")), [8])
        self.assertEqual(self.dead(text.replace("log == null", "log is null")), [8])

    def test_dead_null_fallback_negative_var_is_not_typed(self):
        self.assertEqual(self.dead(self.LOG % ("", "var log = LogManager.GetLogger(typeof(A));")), [])

    def test_dead_null_fallback_requires_using(self):
        text = (self.LOG % ("", "ILog log = LogManager.GetLogger(typeof(A));")).replace("using log4net;", "using System;")
        self.assertEqual(self.dead(text), [])

    def test_dead_null_fallback_unqualified_call(self):
        for call in ("factory.GetLogger(typeof(A))", "this.Factory.LogManager.GetLogger(typeof(A))",
                     "Extensions.LogManager.GetLogger(typeof(A))", "LogManager.Create(typeof(A))"):
            self.assertEqual(self.dead(self.LOG % ("", f"ILog log = {call};")), [], call)

    def test_dead_null_fallback_extension_method_excluded(self):
        text = self.LOG % ("", "ILog log = typeof(A).GetLogger();")
        self.assertEqual(self.dead(text), [])
        text = self.LOG % ("", "ILog log = A.LogManager.GetLogger(typeof(A));")
        self.assertEqual(self.dead(text), [])

    def test_dead_null_fallback_target_declared_logmanager_not_flagged(self):
        for decl in ("class LogManager { }", "interface ILog { }", "class Logger { }"):
            text = self.LOG % (decl, "ILog log = LogManager.GetLogger(typeof(A));")
            self.assertEqual(self.dead(text), [], decl)

    def test_dead_null_fallback_nonreadonly_field_not_flagged(self):
        field = "private static ILog log = LogManager.GetLogger(typeof(A));"
        self.assertEqual(self.dead(self.LOG % (field, "")), [])
        ro = "private static readonly ILog log = LogManager.GetLogger(typeof(A));"
        self.assertEqual(self.dead(self.LOG % (ro, "")), [8])
        ro2 = "private readonly ILog log = LogManager.GetLogger(typeof(A));"
        self.assertEqual(self.dead(self.LOG % (ro2, "")), [8])

    def test_dead_null_fallback_second_assignment_not_flagged(self):
        text = self.LOG % ("", "ILog log = LogManager.GetLogger(typeof(A));\n    log = Other();")
        self.assertEqual(self.dead(text), [])
        text = self.LOG % ("", "ILog log = LogManager.GetLogger(typeof(A));\n    Fill(out log);")
        self.assertEqual(self.dead(text), [])

    def test_dead_null_fallback_other_variable_not_flagged(self):
        text = (self.LOG % ("", "ILog log = LogManager.GetLogger(typeof(A));\n    ILog other = null;")).replace(
            "log == null", "other == null")
        self.assertEqual(self.dead(text), [])

    def test_dead_null_fallback_only_for_classic_aspnet_files(self):
        text = self.LOG % ("", "ILog log = LogManager.GetLogger(typeof(A));")
        self.assertEqual(self.dead(text, ["aspnet-core"]), [])


class HardcodedModeTests(unittest.TestCase):
    PROGRAM = cs("""static class Program {
  [STAThread]
  static void Main() {
    Settings.Mode = AppMode.Production;
    Application.Run(new MainForm());
  }
}""")

    def facts_for(self, kind, output, program_path="Harness/Program.cs", csproj="Harness/Harness.csproj", test=False):
        proj = Fact.make("project", "generic", csproj, 1, "Harness", output_type=output, test=test, web=kind == "web",
                         kind=kind) if False else Fact(
            "project", "generic", csproj, 1, "Harness",
            tuple(sorted({"kind": kind, "output_type": output, "test": test, "web": kind == "web"}.items())))
        return [proj] + list(smells.extract(program_path, self.PROGRAM, ["aspnet"]))

    def modes(self, found):
        return [f.line for f in smells.from_facts(found) if f.detail_dict()["pattern"] == "hardcoded-production-mode"]

    def test_hardcoded_production_mode_winexe_positive(self):
        self.assertEqual(self.modes(self.facts_for("winforms", "winexe")), [7])
        self.assertEqual(self.modes(self.facts_for("console", "exe")), [7])

    def test_hardcoded_production_mode_web_project_negative(self):
        self.assertEqual(self.modes(self.facts_for("web", "exe")), [])
        self.assertEqual(self.modes(self.facts_for("library", "library")), [])
        self.assertEqual(self.modes(self.facts_for("test", "exe", test=True)), [])

    def test_provisional_hit_is_dropped_when_unconfirmed(self):
        found = self.facts_for("web", "exe")
        self.assertTrue(any(f.kind == "smell" for f in found))
        after = smells.apply(found)
        self.assertFalse(any(f.kind == "smell" for f in after))
        confirmed = smells.apply(self.facts_for("winforms", "winexe"))
        self.assertEqual(sum(1 for f in confirmed if f.kind == "smell"), 1)

    def test_nearest_project_decides(self):
        found = self.facts_for("winforms", "winexe", "Src/Tool/Program.cs", "Src/Tool/Tool.csproj")
        outer = Fact("project", "generic", "Src/App.csproj", 1, "App",
                     tuple(sorted({"kind": "web", "output_type": "exe", "test": False, "web": True}.items())))
        self.assertEqual(self.modes(found + [outer]), [7])
        inner_web = self.facts_for("web", "exe", "Src/Tool/Program.cs", "Src/Tool/Tool.csproj")
        outer_win = Fact("project", "generic", "Src/App.csproj", 1, "App",
                         tuple(sorted({"kind": "winforms", "output_type": "winexe", "test": False, "web": False}.items())))
        self.assertEqual(self.modes(inner_web + [outer_win]), [])

    def test_mode_assigned_outside_main_file_negative(self):
        other = cs("class Helper { void Init() { Settings.Mode = AppMode.Production; } }")
        self.assertEqual(list(smells.extract("Harness/Helper.cs", other, ["aspnet"])), [])

    def test_hardcoded_production_mode_in_main_file(self):
        found = list(smells.extract("Harness/Program.cs", self.PROGRAM, []))
        self.assertEqual([f.detail_dict()["pattern"] for f in found], ["hardcoded-production-mode"])
        self.assertNotIn("Production", found[0].name.replace("the Production member", ""))

    def test_mode_assignment_forms(self):
        for stmt, hit in (("Mode = AppMode.Production;", True), ("this.RunMode = Env.Production;", True),
                          ("var o = new Opts { Mode = AppMode.Production };", True),
                          ("Mode = AppMode.Test;", False), ("Mode = Production;", False),
                          ("if (Mode == AppMode.Production) { Go(); }", False),
                          ("Name = AppMode.Production;", False), ("// Mode = AppMode.Production;", False),
                          ('var s = "Mode = AppMode.Production;";', False)):
            text = cs("class P { static void Main() {\n    " + stmt + "\n} }")
            self.assertEqual(bool(list(smells.extract("P.cs", text, []))), hit, stmt)


class ObligationTests(unittest.TestCase):
    def test_obliging_constant_filters_c12(self):
        self.assertIsInstance(smells.OBLIGING, frozenset)
        for p in ("machinekey-in-config", "named-user-access-rule", "duplicate-config-key",
                  "debug-setting-in-nondebug-config", "identifier-list-in-config"):
            self.assertIn(p, smells.OBLIGING)
        for p in ("deref-before-null-check", "deref-in-null-branch", "dead-null-fallback",
                  "hardcoded-production-mode", "config-year-horizon", "debug-setting-in-debug-config"):
            self.assertNotIn(p, smells.OBLIGING)

    def test_new_heuristics_are_not_obliging_until_measured(self):
        for p in ("handler-without-guard", "state-change-authenticated-only", "post-without-antiforgery"):
            self.assertNotIn(p, smells.OBLIGING)
            self.assertIn(p, smells.HEURISTIC)
            self.assertEqual(smells.pattern_class(p), "heuristic")
        self.assertEqual(smells.HEURISTIC & smells.SUMMARY_ONLY, frozenset())
        self.assertEqual(smells.HEURISTIC & smells.DETERMINISTIC, frozenset())
        self.assertTrue(smells.OBLIGING <= smells.DETERMINISTIC | smells.HEURISTIC)

    def test_every_emitted_pattern_is_classified(self):
        emitted = {"machinekey-in-config", "named-user-access-rule", "duplicate-config-key",
                   "debug-setting-in-nondebug-config", "identifier-list-in-config"}
        self.assertTrue(emitted <= smells.DETERMINISTIC)
        self.assertEqual(smells.OBLIGING, smells.DETERMINISTIC | smells.GRANDFATHERED)

    def test_summary_labels_non_obliging(self):
        from appdoc.summary import render_summary
        doc = {"schema": facts.SCHEMA, "target": {"name": "t", "commit": None, "history": "none"},
               "stacks": [{"kind": "stack", "stack": "aspnet", "path": "Web.config", "line": None, "name": "aspnet",
                           "detail": {"supported": True}}],
               "facts": [
                   {"kind": "smell", "stack": "aspnet", "path": "Web.config", "line": 4, "name": "x",
                    "detail": {"pattern": "machinekey-in-config", "fid": "aaaaaaaa"}},
                   {"kind": "smell", "stack": "aspnet", "path": "A.cs", "line": 9, "name": "y",
                    "detail": {"pattern": "dead-null-fallback", "fid": "bbbbbbbb"}}]}
        text = render_summary(doc)
        row = lambda p: [ln for ln in text.splitlines() if ln.startswith(f"| `{p}`")][0]  # noqa: E731
        self.assertNotIn("not an obligation", row("machinekey-in-config"))
        self.assertIn("candidate (not an obligation)", row("dead-null-fallback"))

    def test_summary_prints_none_for_patterns_that_ran_without_a_hit(self):
        from appdoc.summary import render_summary
        stacks = [{"kind": "stack", "stack": "aspnet", "path": "Web.config", "line": None, "name": "aspnet",
                   "detail": {"supported": True}}]
        doc = {"schema": facts.SCHEMA, "target": {"name": "t", "commit": None, "history": "none"}, "stacks": stacks,
               "facts": [{"kind": "smell", "stack": "aspnet", "path": "Web.config", "line": 4, "name": "x",
                          "detail": {"pattern": "machinekey-in-config", "fid": "aaaaaaaa"}}]}
        text = render_summary(doc)
        self.assertIn("Patterns that ran with no hit:", text)
        self.assertIn("`duplicate-config-key`", text.split("Patterns that ran with no hit:")[1])
        self.assertNotIn("`machinekey-in-config`", text.split("Patterns that ran with no hit:")[1])
        doc["facts"] = []
        text = render_summary(doc)
        self.assertIn("Finding candidates: none extracted", text)
        self.assertIn("Patterns that ran with no hit:", text)

    def test_summary_says_year_horizon_is_off_without_a_reference_year(self):
        from appdoc.summary import render_summary
        stacks = [{"kind": "stack", "stack": "aspnet", "path": "Web.config", "line": None, "name": "aspnet",
                   "detail": {"supported": True}}]
        k = {"kind": "config_key", "stack": "generic", "path": "Web.config", "line": 3, "name": "FiscalYear",
             "detail": {"year": 2026, "role": "app", "source": "Web.config", "use": "define"}}
        doc = {"schema": facts.SCHEMA, "target": {"name": "t", "commit": None, "history": "none"}, "stacks": stacks,
               "facts": [k]}
        self.assertIn("`config-year-horizon` is off", render_summary(doc))
        doc["facts"].append({"kind": "context_directive", "stack": "generic", "path": "appdoc-context.md", "line": 1,
                             "name": "Reference year", "detail": {"directive": "reference_year", "value": "2026"}})
        self.assertNotIn("is off", render_summary(doc))


class DeterminismTests(unittest.TestCase):
    def test_smell_facts_identical_serial_pool_and_cached(self):
        import tempfile
        from appdoc import extract
        files = dict(GLOBAL)
        files["Web.config"] = cfg('<appSettings><add key="AdminUsers" value="1,2,3" /><add key="A" value="1" />'
                                  '<add key="A" value="2" /></appSettings><system.web>'
                                  '<machineKey validationKey="AABBCCDDEEFF00112233445566778899AABBCCDD" '
                                  'decryptionKey="AABBCCDDEEFF00112233445566778899" />'
                                  '<authorization><allow users="jdoe" /><deny users="*" /></authorization>'
                                  '<compilation debug="true" /></system.web>')
        files["Code/A.cs"] = cs("class A { void M(Customer c) {\n    var n = c.Name;\n    if (c == null) { Fail(); }\n} }")
        for i in range(60):
            files[f"Code/F{i}.cs"] = cs(f"class F{i} {{ }}")
        with tempfile.TemporaryDirectory() as tmp:
            import os
            root = os.path.join(tmp, "t")
            for rel, text in files.items():
                full = os.path.join(root, *rel.split("/"))
                os.makedirs(os.path.dirname(full), exist_ok=True)
                with open(full, "w", encoding="utf-8", newline="") as fh:
                    fh.write(text)
            out = os.path.join(tmp, "out")
            serial = extract.extract(root, out, workers=0, use_cache=False, no_ownership=True)[0]
            pool = extract.extract(root, out, workers=2, use_cache=False, no_ownership=True)[0]
            cold = extract.extract(root, out, workers=0, use_cache=True, no_ownership=True)[0]
            warm = extract.extract(root, out, workers=0, use_cache=True, no_ownership=True)[0]
        self.assertGreaterEqual(len(files), 50, "above the pool threshold")
        self.assertEqual(serial, pool)
        self.assertEqual(serial, cold)
        self.assertEqual(serial, warm)
        found = {f["detail"]["pattern"] for f in json.loads(serial)["facts"] if f["kind"] == "smell"}
        self.assertTrue({"machinekey-in-config", "named-user-access-rule", "duplicate-config-key",
                         "debug-setting-in-nondebug-config", "identifier-list-in-config",
                         "deref-before-null-check"} <= found, found)


facts_mod = facts


# ---------------------------------------------------------------------------------------------------------------
# 2.8 W11 (T28.72): handler-without-guard, state-change-authenticated-only, post-without-antiforgery
# ---------------------------------------------------------------------------------------------------------------

def entry(path, line, handler, verbs=("POST",), state="true", writes=True, reach="no_app_restriction",
          anon="allow", area=None, reasons=None, stack="aspnet", **extra):
    d = dict(type="route", handler=handler, verbs=list(verbs), state_changing=state, writes=writes, reach=reach,
             reach_anon=anon, reach_auth="allow" if reach != "denied" else "deny", **extra)
    if area:
        d["mvc_area"] = area
    if reasons:
        d["reasons"] = list(reasons)
    return Fact.make("entry_point", stack, path, line, "/" + handler.replace(".", "/"), **d)


def controller(path, line, name, bases=("Controller",), external=False):
    return Fact.make("controller_class", "aspnet", path, line, name, base_list=list(bases), base_external=external)


def check(path, line, scope, applies_to, name="ValidateAntiForgeryToken"):
    return Fact.make("antiforgery_check", "aspnet", path, line, name, scope=scope, applies_to=applies_to)


def hits_of(found, pattern):
    return [(f.path, f.line) for f in smells.from_facts(found) if f.detail_dict()["pattern"] == pattern]


class HandlerWithoutGuardTests(unittest.TestCase):
    def test_handler_without_guard_positive(self):
        found = [entry("Controllers/A.cs", 12, "AController.Save", reasons=["host_auth_set"])]
        got = by_pattern(smells.from_facts(found), "handler-without-guard")
        self.assertEqual([(f.path, f.line) for f in got], [("Controllers/A.cs", 12)])
        d = got[0].detail_dict()
        self.assertEqual(d["reasons"], ["host_auth_set"])
        self.assertIn("no application-layer restriction", got[0].name)
        self.assertNotIn("Save", got[0].name)
        self.assertEqual(d["sources"], [("Controllers/A.cs", 12, "entry_point", "/AController/Save")])

    def test_read_only_post_is_not_flagged(self):
        self.assertEqual(hits_of([entry("C/A.cs", 12, "A.Show", writes=False)], "handler-without-guard"), [])

    def test_redirect_only_stub_is_not_flagged(self):
        self.assertEqual(hits_of([entry("C/A.cs", 12, "A.Go", writes=False, state="true")], "handler-without-guard"), [])

    def test_restricted_or_unknown_reach_is_not_flagged(self):
        for reach, anon in (("signed_in_any", "deny"), ("role_restricted", "deny"), ("denied", "deny"),
                            ("unknown", "unknown")):
            self.assertEqual(hits_of([entry("C/A.cs", 12, "A.Save", reach=reach, anon=anon)],
                                     "handler-without-guard"), [], reach)

    def test_not_state_changing_is_not_flagged(self):
        for state in ("false", "unknown"):
            self.assertEqual(hits_of([entry("C/A.cs", 12, "A.Save", state=state)], "handler-without-guard"), [], state)

    def test_allow_star_data_api_read_is_not_flagged(self):
        api = entry("Controllers/ApiDataController.cs", 9, "ApiDataController.Get", verbs=("GET",), state="false",
                    writes=False, reasons=["iis_anonymous_unknown"])
        self.assertEqual(hits_of([api], "handler-without-guard"), [])

    def test_core_entry_points_have_no_reach_and_no_hit(self):
        e = Fact.make("entry_point", "aspnet-core", "C/A.cs", 3, "/a", type="route", handler="A.Save",
                      guard_mechanism=["none"])
        self.assertEqual(hits_of([e], "handler-without-guard"), [])

    def test_attribute_routes_of_one_action_are_one_hit(self):
        a = entry("C/A.cs", 12, "A.Save")
        b = Fact.make("entry_point", "aspnet", "C/A.cs", 12, "/other", **a.detail_dict())
        self.assertEqual(hits_of([a, b], "handler-without-guard"), [("C/A.cs", 12)])


class AuthenticatedOnlyTests(unittest.TestCase):
    def sample(self, **kw):
        return [entry("Areas/Admin/C/UsersController.cs", 10, "UsersController.Save", reach="signed_in_any",
                      anon="deny", area="Admin", **kw),
                entry("Areas/Admin/C/RolesController.cs", 10, "RolesController.Save", reach="role_restricted",
                      anon="deny", area="Admin")]

    def test_authenticated_only_requires_role_sibling_in_same_area(self):
        pos = by_pattern(smells.from_facts(self.sample()), "state-change-authenticated-only")
        self.assertEqual([(f.path, f.line) for f in pos], [("Areas/Admin/C/UsersController.cs", 10)])
        self.assertEqual(pos[0].detail_dict()["count"], 1)
        other_area = self.sample()
        other_area[1] = entry("Areas/Ops/C/RolesController.cs", 10, "RolesController.Save", reach="role_restricted",
                              anon="deny", area="Ops")
        self.assertEqual(hits_of(other_area, "state-change-authenticated-only"), [])
        self.assertEqual(hits_of(self.sample()[:1], "state-change-authenticated-only"), [])

    def test_root_area_siblings_count_as_one_area(self):
        a = entry("C/UsersController.cs", 10, "UsersController.Save", reach="signed_in_any", anon="deny")
        b = entry("C/RolesController.cs", 10, "RolesController.Save", reach="role_restricted", anon="deny")
        self.assertEqual(hits_of([a, b], "state-change-authenticated-only"), [("C/UsersController.cs", 10)])

    def test_authenticated_only_needs_a_writing_state_change(self):
        a = self.sample(writes=False)
        self.assertEqual(hits_of(a, "state-change-authenticated-only"), [])

    def test_role_restricted_handler_is_not_flagged_itself(self):
        self.assertEqual([p for p, _ in hits_of(self.sample(), "state-change-authenticated-only")
                          if "Roles" in p], [])

    def test_no_name_in_message(self):
        for f in by_pattern(smells.from_facts(self.sample()), "state-change-authenticated-only"):
            self.assertNotIn("Users", f.name)
            self.assertNotIn("Admin", f.name)


class AntiforgeryTests(unittest.TestCase):
    A = "Controllers/AController.cs"
    B = "Controllers/BController.cs"

    def base(self):
        return [controller(self.A, 5, "AController"), controller(self.B, 5, "BController"),
                entry(self.A, 10, "AController.Save"), entry(self.A, 20, "AController.Drop"),
                entry(self.B, 10, "BController.Save")]

    def table(self, found):
        got = by_pattern(smells.from_facts(found), "post-without-antiforgery")
        return got

    def test_antiforgery_one_target_level_hit_with_per_controller_table(self):
        got = self.table(self.base())
        self.assertEqual(len(got), 1)
        f = got[0]
        self.assertEqual((f.path, f.line), (self.A, 5))
        d = f.detail_dict()
        self.assertEqual((d["unprotected"], d["total"]), (3, 3))
        self.assertEqual(d["controllers"], [f"{self.A}:5 2 of 2", f"{self.B}:5 1 of 1"])
        self.assertEqual([s[2] for s in d["sources"]], ["controller_class", "controller_class"])
        for word in ("AController", "Save"):
            self.assertNotIn(word, f.name)

    def test_antiforgery_own_attribute_protects(self):
        found = self.base() + [check(self.A, 10, "method", "AController.Save"),
                               check(self.A, 20, "method", "AController.Drop"),
                               check(self.B, 10, "method", "BController.Save")]
        self.assertEqual(self.table(found), [])

    def test_antiforgery_partial_table_counts_n_of_m(self):
        found = self.base() + [check(self.A, 10, "method", "AController.Save"), check(self.B, 10, "body", "BController.Save", "AntiForgery.Validate")]
        got = self.table(found)
        self.assertEqual(got[0].detail_dict()["controllers"], [f"{self.A}:5 1 of 2"])
        self.assertEqual((got[0].detail_dict()["unprotected"], got[0].detail_dict()["total"]), (1, 3))   # Target-wide M

    def test_antiforgery_class_level_protects(self):
        found = self.base() + [check(self.A, 5, "class", "AController")]
        self.assertEqual(hits_of(found, "post-without-antiforgery"), [(self.B, 5)])

    def test_antiforgery_inherited_from_in_target_base_protects(self):
        found = [controller("Base.cs", 3, "SecureBase"), check("Base.cs", 3, "class", "SecureBase"),
                 controller(self.A, 5, "AController", bases=("SecureBase",)), entry(self.A, 10, "AController.Save")]
        self.assertEqual(hits_of(found, "post-without-antiforgery"), [])
        unsafe = [controller("Base.cs", 3, "SecureBase")] + found[2:]
        self.assertEqual(hits_of(unsafe, "post-without-antiforgery"), [(self.A, 5)])

    def test_antiforgery_target_attribute_calling_validate_protects(self):
        validator = Fact.make("antiforgery_check", "aspnet", "Filters/F.cs", 4, "SiteForgeryAttribute",
                              scope="validator", applies_to="SiteForgeryAttribute")
        use = Fact.make("guard_use", "aspnet", self.A, 9, "SiteForgery", attribute="SiteForgery", scope="method",
                        applies_to="AController.Save", arity=0, arg_kinds=[])
        found = self.base() + [validator, use]
        self.assertEqual(sorted(hits_of(found, "post-without-antiforgery")), [(self.A, 5)])
        got = self.table(found)[0].detail_dict()
        self.assertEqual((got["unprotected"], got["total"]), (2, 3))
        cls_use = Fact.make("guard_use", "aspnet", self.A, 4, "SiteForgery", attribute="SiteForgery", scope="class",
                            applies_to="AController", arity=0, arg_kinds=[])
        self.assertEqual(hits_of(self.base() + [validator, cls_use], "post-without-antiforgery"), [(self.B, 5)])

    def test_antiforgery_attribute_without_validate_call_is_not_a_protection(self):
        use = Fact.make("guard_use", "aspnet", self.A, 9, "SiteForgery", attribute="SiteForgery", scope="method",
                        applies_to="AController.Save", arity=0, arg_kinds=[])
        self.assertEqual(len(self.table(self.base() + [use])[0].detail_dict()["controllers"]), 2)
        self.assertEqual(self.table(self.base() + [use])[0].detail_dict()["unprotected"], 3)

    def test_antiforgery_global_filter_of_that_class_protects_everything(self):
        validator = Fact.make("antiforgery_check", "aspnet", "Filters/F.cs", 4, "SiteForgeryAttribute",
                              scope="validator", applies_to="SiteForgeryAttribute")
        glob = Fact.make("auth_check", "aspnet", "App_Start/FilterConfig.cs", 8, "SiteForgeryAttribute",
                         mechanism="global-filter", scope="global")
        self.assertEqual(self.table(self.base() + [validator, glob]), [])
        other = Fact.make("auth_check", "aspnet", "App_Start/FilterConfig.cs", 8, "OtherAttribute",
                          mechanism="global-filter", scope="global")
        self.assertEqual(len(self.table(self.base() + [validator, other])), 1)

    def test_antiforgery_global_validate_token_filter_protects(self):
        glob = check("App_Start/FilterConfig.cs", 8, "global", "", "ValidateAntiForgeryToken")
        self.assertEqual(self.table(self.base() + [glob]), [])

    def test_antiforgery_in_body_validate_protects(self):
        found = self.base() + [check(self.A, 10, "body", "AController.Save", "AntiForgery.Validate")]
        self.assertEqual(self.table(found)[0].detail_dict()["unprotected"], 2)

    def test_antiforgery_api_controller_is_excluded(self):
        found = [controller(self.A, 5, "AController", bases=("ApiController",)), entry(self.A, 10, "AController.Post")]
        self.assertEqual(self.table(found), [])
        via_base = [controller("B.cs", 2, "BaseApi", bases=("ApiController",)),
                    controller(self.A, 5, "AController", bases=("BaseApi",)), entry(self.A, 10, "AController.Post")]
        self.assertEqual(self.table(via_base), [])

    def test_antiforgery_unresolved_external_base_gives_no_hit(self):
        found = [controller(self.A, 5, "AController", bases=("VendorBase",), external=True),
                 entry(self.A, 10, "AController.Save")]
        self.assertEqual(self.table(found), [])

    def test_antiforgery_only_state_changing_posts_count(self):
        found = [controller(self.A, 5, "AController"),
                 entry(self.A, 10, "AController.Show", writes=False, state="true"),
                 entry(self.A, 20, "AController.List", verbs=("GET",), state="false", writes=False),
                 entry(self.A, 30, "AController.Any", verbs=("any",), state="unknown", writes=False)]
        # a POST is state_changing by its verb (the write test is separate), a GET and a verb-less read are not
        got = self.table(found)[0].detail_dict()
        self.assertEqual((got["unprotected"], got["total"]), (1, 1))

    def test_antiforgery_web_forms_and_core_are_not_in_scope(self):
        page = Fact.make("entry_point", "aspnet", "Admin/users.aspx", 1, "/Admin/users.aspx", type="page")
        core = entry(self.A, 10, "AController.Save", stack="aspnet-core")
        self.assertEqual(self.table([page, core, controller(self.A, 5, "AController")]), [])

    def test_per_controller_anchor_stable_when_action_added(self):
        before = self.table(self.base())[0]
        after = self.table(self.base() + [entry(self.A, 30, "AController.Extra")])[0]
        self.assertEqual((before.path, before.line), (after.path, after.line))
        self.assertEqual(before.detail_dict()["fid"], after.detail_dict()["fid"])
        self.assertNotEqual(before.detail_dict()["total"], after.detail_dict()["total"])

    def test_antiforgery_test_controllers_are_left_out(self):
        found = [controller("Tests/AControllerTests.cs", 5, "AController"),
                 entry("Tests/AControllerTests.cs", 10, "AController.Save")]
        self.assertEqual(self.table(found), [])


# ---------------------------------------------------------------------------------------------------------------
# End to end: the raw antiforgery_check Facts, conditional_const and mode_branch, on invented Targets
# ---------------------------------------------------------------------------------------------------------------

MVC_USING = "using System.Web.Mvc;\n"


def mvc(path_body: dict) -> dict:
    files = dict(GLOBAL)
    files.update(path_body)
    return files


def kinds_at(doc, kind, **detail):
    return sorted((f["path"], f["line"], f["name"], f["detail"]) for f in of(doc, kind, **detail))


class AntiforgeryRawFactTests(unittest.TestCase):
    FILTER = (MVC_USING + "namespace Contoso.Web {\n"
              "  public class SiteForgeryAttribute : FilterAttribute, IAuthorizationFilter {\n"
              "    public void OnAuthorization(AuthorizationContext c) {\n"
              "      AntiForgery.Validate();\n    }\n  }\n}\n")
    CTRL = (MVC_USING + "namespace Contoso.Web {\n"
            "  public class OrdersController : Controller {\n"                       # 3
            "    [HttpPost]\n    [ValidateAntiForgeryToken]\n    public ActionResult Save(Order o) { Db.SaveChanges(); return View(); }\n"   # 4,5,6
            "    [HttpPost]\n    public ActionResult Drop(int id) { Db.SaveChanges(); return View(); }\n"    # 7,8
            "    [HttpPost]\n    public ActionResult Check(int id) {\n      AntiForgery.Validate();\n      return View();\n    }\n"   # 9..13
            "    [SiteForgery]\n    [HttpPost]\n    public ActionResult Merge(int id) { return View(); }\n"       # 14..16
            "  }\n"
            "  [ValidateAntiForgeryToken]\n  public class SafeController : Controller {\n"                          # 18,19
            "    [HttpPost]\n    public ActionResult Edit(int id) { return View(); }\n  }\n}\n")
    FILTERS = (MVC_USING + "public static class FilterConfig {\n"
               "  public static void RegisterGlobalFilters(GlobalFilterCollection filters) {\n"
               "    filters.Add(new ValidateAntiForgeryTokenAttribute());\n  }\n}\n")

    def doc(self, **extra):
        files = mvc({"Controllers/OrdersController.cs": self.CTRL, "Filters/SiteForgeryAttribute.cs": self.FILTER})
        files.update(extra)
        return run_target(files)

    def test_raw_antiforgery_check_facts(self):
        got = {(f["path"], f["line"], f["detail"]["scope"], f["detail"]["applies_to"])
               for f in of(self.doc(), "antiforgery_check")}
        scopes = {(s, a) for _, _, s, a in got}
        self.assertIn(("method", "OrdersController.Save"), scopes)
        self.assertIn(("body", "OrdersController.Check"), scopes)
        self.assertIn(("class", "SafeController"), scopes)
        self.assertIn(("validator", "SiteForgeryAttribute"), scopes)
        self.assertNotIn(("method", "OrdersController.Drop"), scopes)
        for path, line, scope, applies in got:
            if scope in ("method", "body"):
                entries = [e for e in of(self.doc(), "entry_point", handler=applies)]
                self.assertIn(line, {e["line"] for e in entries}, "joined to the entry point by its line")

    def test_raw_facts_join_to_one_target_level_smell(self):
        doc = self.doc()
        hit = [f for f in doc["facts"] if f["kind"] == "smell" and f["detail"]["pattern"] == "post-without-antiforgery"]
        self.assertEqual(len(hit), 1)
        d = hit[0]["detail"]
        self.assertEqual(hit[0]["path"], "Controllers/OrdersController.cs")
        self.assertEqual(hit[0]["line"], 3)                        # the class line
        self.assertEqual((d["unprotected"], d["total"]), (1, 5))   # Drop only: Save, Check, Merge and Edit are protected
        self.assertEqual(d["controllers"], ["Controllers/OrdersController.cs:3 1 of 4"])

    def test_global_validate_filter_protects_every_post(self):
        doc = self.doc(**{"App_Start/FilterConfig.cs": self.FILTERS})
        self.assertEqual([f for f in doc["facts"] if f["kind"] == "smell"
                          and f["detail"]["pattern"] == "post-without-antiforgery"], [])

    def test_api_controller_and_core_are_out_of_scope(self):
        api = (MVC_USING + "using System.Web.Http;\nnamespace Contoso.Web {\n  public class ItemsController : ApiController {\n"
               "    [HttpPost] public IHttpActionResult Post(int id) { Db.SaveChanges(); return Ok(); }\n  }\n}\n")
        doc = run_target(mvc({"Controllers/ItemsController.cs": api}))
        self.assertEqual([f for f in doc["facts"] if f["kind"] == "smell"
                          and f["detail"]["pattern"] == "post-without-antiforgery"], [])

    def test_unresolved_external_base_gives_no_hit(self):
        text = (MVC_USING + "namespace Contoso.Web {\n  public class OrdersController : VendorController {\n"
                "    [HttpPost] public ActionResult Save(int id) { Db.SaveChanges(); return View(); }\n  }\n}\n")
        doc = run_target(mvc({"Controllers/OrdersController.cs": text}))
        self.assertEqual([f for f in doc["facts"] if f["kind"] == "smell"
                          and f["detail"]["pattern"] == "post-without-antiforgery"], [])

    def test_adding_an_action_keeps_the_fid(self):
        a = self.doc()
        extra = self.CTRL.replace("  }\n  [ValidateAntiForgeryToken]",
                                  "    [HttpPost]\n    public ActionResult Extra(int id) { Db.SaveChanges(); return View(); }\n  }\n"
                                  "  [ValidateAntiForgeryToken]")
        b = run_target(mvc({"Controllers/OrdersController.cs": extra, "Filters/SiteForgeryAttribute.cs": self.FILTER}))
        fid = lambda doc: [f["detail"]["fid"] for f in doc["facts"] if f["kind"] == "smell"          # noqa: E731
                           and f["detail"]["pattern"] == "post-without-antiforgery"]
        self.assertEqual(fid(a), fid(b))
        self.assertEqual(len(fid(a)), 1)


class ConditionalConstTests(unittest.TestCase):
    CONSTS = ("namespace Contoso.Web {\n  public static class Roles {\n"
              "#if DEBUG\n    public const string Admin = \"Everyone\";\n#else\n    public const string Admin = \"Admins\";\n#endif\n"
              "    public const string Clerk = \"Clerks\";\n"
              "#if DEBUG\n    public const string Unused = \"U\";\n#endif\n  }\n}\n")
    CTRL = (MVC_USING + "namespace Contoso.Web {\n  public class OrdersController : Controller {\n"
            "    [Authorize(Roles = Roles.Admin)]\n    public ActionResult Index() { return View(); }\n"
            "    [Authorize(Roles = Roles.Clerk)]\n    public ActionResult Other() { return View(); }\n  }\n}\n")

    def doc(self, ctrl=None, **extra):
        files = mvc({"Infra/Roles.cs": self.CONSTS, "Controllers/OrdersController.cs": ctrl or self.CTRL})
        files.update(extra)
        return run_target(files)

    def test_conditional_const_fact(self):
        got = of(self.doc(), "conditional_const")
        self.assertEqual([(f["path"], f["line"], f["name"]) for f in got], [("Infra/Roles.cs", 4, "Roles.Admin")])
        self.assertEqual(got[0]["detail"], {"under_if": ["DEBUG"], "uses": 1})
        self.assertEqual(got[0]["stack"], "aspnet")

    def test_conditional_const_joined_to_guard_argument(self):
        no_use = self.CTRL.replace("Roles.Admin", "Roles.Clerk")
        self.assertEqual(of(self.doc(ctrl=no_use), "conditional_const"), [])

    def test_conditional_const_never_records_a_value(self):
        for f in of(self.doc(), "conditional_const"):
            self.assertNotIn("value", f["detail"])

    def test_secret_constant_under_if_is_not_a_conditional_const(self):
        consts = self.CONSTS.replace("Admin = \"Everyone\"", "AdminPassword = \"hunter2hunter2\"").replace(
            "Admin = \"Admins\"", "AdminPassword = \"x\"")
        ctrl = self.CTRL.replace("Roles.Admin", "Roles.AdminPassword")
        doc = run_target(mvc({"Infra/Roles.cs": consts, "Controllers/OrdersController.cs": ctrl}))
        self.assertEqual(of(doc, "conditional_const"), [])
        self.assertNotIn("hunter2hunter2", json.dumps(doc))


class ModeBranchTests(unittest.TestCase):
    CONSTS = ("namespace Contoso.Web {\n  public static class Roles {\n    public const string Admin = \"Admins\";\n"
              "    public const string Clerk = \"Clerks\";\n  }\n  public enum Mode { Test, Production }\n}\n")
    GUARDED = ("[Authorize(Roles = Roles.Admin)]\n")
    CTRL = (MVC_USING + "namespace Contoso.Web {\n  public class OrdersController : Controller {\n"
            "    [Authorize(Roles = Roles.Admin)]\n    public ActionResult Index() { return View(); }\n"
            "    [Authorize(Roles = Roles.Clerk)]\n    public ActionResult Other() { return View(); }\n"
            "    public ActionResult Save() {\n"                                                           # 8
            "      if (Settings.Mode == Mode.Production) { return View(); }\n"
            "      if (Mode.Production == Settings.Mode) { Log(); }\n"
            "      if (!CheckAuth(Roles.Admin, Roles.Clerk)) { return new HttpUnauthorizedResult(); }\n"
            "      return View();\n    }\n"
            "    public ActionResult Show() {\n      if (Settings.Mode == Mode.Production) { return View(); }\n      return View();\n    }\n"
            "  }\n}\n")

    def doc(self):
        return run_target(mvc({"Infra/Roles.cs": self.CONSTS, "Controllers/OrdersController.cs": self.CTRL}))

    def test_mode_branch_counts(self):
        got = of(self.doc(), "mode_branch")
        self.assertEqual([(f["path"], f["name"], f["detail"]["count"], f["detail"]["applies_to"]) for f in got],
                         [("Controllers/OrdersController.cs", "OrdersController.Save", 2, "OrdersController.Save")])

    def test_mode_branch_only_for_a_handler_that_calls_an_auth_method(self):
        got = {f["name"] for f in of(self.doc(), "mode_branch")}
        self.assertNotIn("OrdersController.Show", got)

    def test_no_mode_branch_without_any_auth_method(self):
        doc = run_target(mvc({"Controllers/OrdersController.cs": self.CTRL.replace("CheckAuth(Roles.Admin, Roles.Clerk)", "Ok()")}))
        self.assertEqual(of(doc, "mode_branch"), [])


class DebugBlockTests(unittest.TestCase):
    PATTERN = "debug-block-assigns-local"

    def hits(self, body, stacks=("aspnet",), path="Controllers/A.cs"):
        text = cs("public class AController : Controller {\n" + body + "\n}") if "class " not in body else cs(body)
        return [(f.line, f.detail_dict()) for f in smells.extract(path, text, list(stacks))
                if f.detail_dict()["pattern"] == self.PATTERN]

    def test_debug_block_assigning_a_local_in_a_handler_file(self):
        got = self.hits("  public ActionResult Index() {\n    var who = User.Name;\n#if DEBUG\n    who = \"tester\";\n#endif\n"
                        "    return View();\n  }")
        self.assertEqual([line for line, _ in got], [7])
        self.assertEqual(got[0][1]["symbols"], ["DEBUG"])

    def test_typed_declaration_counts_as_a_local_assignment(self):
        got = self.hits("  public ActionResult Index() {\n#if DEBUG\n    string who = \"tester\";\n#endif\n    return View();\n  }")
        self.assertEqual(len(got), 1)

    def test_block_without_assignment_is_not_flagged(self):
        self.assertEqual(self.hits("  public ActionResult Index() {\n#if DEBUG\n    Trace.WriteLine(1);\n#endif\n    return View();\n  }"), [])

    def test_assignment_in_the_else_branch_is_not_flagged(self):
        self.assertEqual(self.hits("  public ActionResult Index() {\n#if DEBUG\n    Trace.WriteLine(1);\n#else\n    who = 1;\n#endif\n    return View();\n  }"), [])

    def test_file_without_handlers_is_not_flagged(self):
        text = cs("public class Helper {\n  void M() {\n#if DEBUG\n    var x = 1;\n#endif\n  }\n}")
        self.assertEqual([f for f in smells.extract("Code/H.cs", text, ["aspnet"])
                          if f.detail_dict()["pattern"] == self.PATTERN], [])

    def test_other_stacks_are_unchanged(self):
        self.assertEqual(self.hits("  public ActionResult Index() {\n#if DEBUG\n    var x = 1;\n#endif\n    return View();\n  }",
                                   stacks=("aspnet-core",)), [])

    def test_summary_only(self):
        self.assertNotIn(self.PATTERN, smells.OBLIGING)
        self.assertNotIn(self.PATTERN, smells.HEURISTIC)
        self.assertIn(self.PATTERN, smells.SUMMARY_ONLY)


class SummaryAccountabilityTests(unittest.TestCase):
    STACKS = [{"kind": "stack", "stack": "aspnet", "path": "Web.config", "line": None, "name": "aspnet",
               "detail": {"supported": True}}]

    def doc(self, facts):
        return {"schema": facts_mod.SCHEMA, "target": {"name": "t", "commit": None, "history": "none"},
                "stacks": self.STACKS, "facts": facts}

    @staticmethod
    def f(kind, path, line, name, stack="aspnet", **detail):
        return {"kind": kind, "stack": stack, "path": path, "line": line, "name": name, "detail": detail}

    def test_accountability_counts_for_guard_attributes(self):
        from appdoc import summary
        facts = [self.f("guard_use", "A.cs", 3, "Authorize", attribute="Authorize", applies_to="A"),
                 self.f("guard_use", "A.cs", 9, "SiteGuard", attribute="SiteGuard", applies_to="A.Save"),
                 self.f("guard_use", "A.cs", 12, "Ui", attribute="Ui", applies_to="A.Show"),
                 self.f("auth_check", "A.cs", 9, "[SiteGuard]", mechanism="attribute", via="custom", applies_to="A.Save")]
        c = summary.accountability_counts(facts)
        self.assertEqual(c["guard_attributes"], {"seen": 3, "recognised": 2, "unrecognised": 1})

    def test_accountability_counts_for_config_reads(self):
        from appdoc import summary
        facts = [self.f("config_key", "Web.config", 3, "Site", source="Web.config", role="app", use="define"),
                 self.f("config_key", "A.cs", 9, "Site", source="code", role="app", use="read", read_kind="file"),
                 self.f("config_key", "A.cs", 10, "Other", source="code", role="app", use="read", read_kind="file"),
                 self.f("config_key", "A.cs", 11, "Path", source="code", role="env", use="read", read_kind="env")]
        c = summary.accountability_counts(facts)
        self.assertEqual(c["config_reads"], {"seen": 3, "recognised": 1, "unrecognised": 2})

    def test_accountability_section_is_printed_for_supported_stacks(self):
        from appdoc import summary
        text = summary.render_summary(self.doc([
            self.f("guard_use", "A.cs", 3, "Authorize", attribute="Authorize", applies_to="A")]))
        self.assertIn("## Detector accountability", text)
        self.assertIn("Guard attributes: seen 1, recognised 1, unrecognised 0.", text)

    def test_zero_recognised_reads_say_ran_found_no_match(self):
        from appdoc import summary
        text = summary.render_summary(self.doc([
            self.f("config_key", "A.cs", 9, "Other", source="code", role="app", use="read", read_kind="file")]))
        self.assertIn("Config reads: seen 1, recognised 0, unrecognised 1 (ran, found no match).", text)
        text = summary.render_summary(self.doc([]))
        self.assertIn("Config reads: seen 0, recognised 0, unrecognised 0 (ran, found no match).", text)

    def test_no_accountability_section_without_a_supported_stack(self):
        from appdoc import summary
        d = self.doc([])
        d["stacks"] = []
        self.assertNotIn("## Detector accountability", summary.render_summary(d))

    def test_conditional_compilation_names_the_defining_configurations(self):
        from appdoc import summary
        facts = [self.f("conditional_const", "Infra/Roles.cs", 4, "Roles.Admin", under_if=["DEBUG"], uses=2),
                 self.f("build_define", "Infra/Infra.csproj", 9, "Debug", stack="generic", config="Debug",
                        symbols=["DEBUG", "TRACE"], inherits=False),
                 self.f("build_define", "Infra/Infra.csproj", 12, "Release", stack="generic", config="Release",
                        symbols=["TRACE"], inherits=False),
                 self.f("build_define", "Other/Other.csproj", 9, "Staging", stack="generic", config="Staging",
                        symbols=["DEBUG"], inherits=False)]
        text = summary.render_summary(self.doc(facts))
        self.assertIn("## Conditional compilation", text)
        row = [ln for ln in text.splitlines() if "Infra/Roles.cs:4" in ln][0]
        self.assertIn("`DEBUG`", row)
        self.assertIn("Debug", row)
        self.assertNotIn("Release", row)
        self.assertNotIn("Staging", row)

    def test_antiforgery_table_is_printed_in_the_summary(self):
        from appdoc import summary
        facts = [self.f("smell", "C/A.cs", 5, "x", pattern="post-without-antiforgery", fid="aaaaaaaa", unprotected=3,
                        total=7, controllers=["C/A.cs:5 2 of 4", "C/B.cs:6 1 of 1"])]
        text = summary.render_summary(self.doc(facts))
        self.assertIn("3 of 7 state-changing POST actions", text)
        self.assertIn("- `C/B.cs:6 1 of 1`", text)
        row = [ln for ln in text.splitlines() if ln.startswith("| `post-without-antiforgery`")][0]
        self.assertIn("candidate (not an obligation)", row)

    def test_symbol_defined_nowhere_is_said_so(self):
        from appdoc import summary
        facts = [self.f("conditional_const", "Infra/Roles.cs", 4, "Roles.Admin", under_if=["DEBUG"], uses=1)]
        text = summary.render_summary(self.doc(facts))
        row = [ln for ln in text.splitlines() if "Infra/Roles.cs:4" in ln][0]
        self.assertIn("no configuration defines it", row)

    def test_mode_branch_rows_in_the_summary(self):
        from appdoc import summary
        facts = [self.f("mode_branch", "C/A.cs", 8, "A.Save", count=3, applies_to="A.Save")]
        text = summary.render_summary(self.doc(facts))
        self.assertIn("## Conditional compilation", text)
        self.assertIn("C/A.cs:8", text)
        self.assertIn("3", [ln for ln in text.splitlines() if "C/A.cs:8" in ln][0])


if __name__ == "__main__":
    unittest.main()
