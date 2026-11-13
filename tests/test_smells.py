"""Finding candidates (smells): one positive and one negative case per pattern, comments ignored, 1-based lines."""

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


if __name__ == "__main__":
    unittest.main()
