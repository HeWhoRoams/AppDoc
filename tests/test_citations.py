import os
import tempfile
import unittest

from appdoc.citations import find_citations, parse_span


class CitationTests(unittest.TestCase):
    def test_paths_with_optional_line_or_range(self):
        self.assertEqual(parse_span("portal/verify.asp:6"), ("portal/verify.asp", 6, 6))
        self.assertEqual(parse_span("src/App.java:40-52"), ("src/App.java", 40, 52))
        self.assertEqual(parse_span("search.asp"), ("search.asp", None, None))
        self.assertEqual(parse_span("appdoc-context.md"), ("appdoc-context.md", None, None))

    def test_routes_and_absolute_paths_are_not_citations(self):
        for span in ("/admin/users", "/api/tickets", "/usr/bin/backup", "/var/log/purge.log", "C:/logs/a.txt",
                     "GET /api/tickets", "https://x.example/a.js"):
            self.assertIsNone(parse_span(span), span)

    def test_identifiers_and_code_are_not_citations(self):
        for span in ("HelpDesk_ResetPwd", 'Session("Authenticated")', "System.Web", "x = 1", "SELECT * FROM t"):
            self.assertIsNone(parse_span(span), span)

    def test_parent_escapes_are_still_citations_so_check_can_reject_them(self):
        self.assertEqual(parse_span("../secret.txt")[0], "../secret.txt")

    def test_fenced_code_is_ignored_and_lines_are_numbered(self):
        text = "a `x/y.py:3`\n```\n`not/a/cite.py:1`\n```\nb `z.cs`\n"
        self.assertEqual([(c.doc_line, c.path) for c in find_citations(text)], [(1, "x/y.py"), (5, "z.cs")])

    def test_known_extensionless_files_are_citations(self):
        self.assertEqual(parse_span("Procfile:1"), ("Procfile", 1, 1))
        self.assertEqual(parse_span("docker/Dockerfile.rootless:3"), ("docker/Dockerfile.rootless", 3, 3))
        self.assertEqual(parse_span("Dockerfile.rootless"), ("Dockerfile.rootless", None, None))
        self.assertEqual(parse_span("api.Dockerfile:2"), ("api.Dockerfile", 2, 2))
        self.assertEqual(parse_span("MAINTAINERS"), ("MAINTAINERS", None, None))

    def test_bare_names_are_case_sensitive_and_single_token(self):
        for span in ("License", "procfile", "Makefile target", "Dockerfileish"):
            self.assertIsNone(parse_span(span), span)

    def test_dotfiles_and_data_files_with_a_line_are_citations(self):
        for span, want in ((".gitignore:5", (".gitignore", 5, 5)), (".dockerignore:2", (".dockerignore", 2, 2)),
                           (".editorconfig:1", (".editorconfig", 1, 1)), ("test.db:1", ("test.db", 1, 1)),
                           ("var/app.sqlite:3-4", ("var/app.sqlite", 3, 4)), ("poetry.lock:9", ("poetry.lock", 9, 9)),
                           ("setup.cfg:2", ("setup.cfg", 2, 2)), ("nginx.conf:7", ("nginx.conf", 7, 7)),
                           (".env.local:3", (".env.local", 3, 3)), (".eslintrc:1", (".eslintrc", 1, 1)),
                           ("docs/.gitignore:5", ("docs/.gitignore", 5, 5))):
            self.assertEqual(parse_span(span), want, span)

    def test_data_extensions_that_look_like_code_members_need_a_line(self):
        self.assertIsNone(parse_span("self.db"))
        self.assertIsNone(parse_span("console.log"))
        self.assertIsNone(parse_span("settings.conf"))
        self.assertEqual(parse_span("settings.conf:4"), ("settings.conf", 4, 4))
        self.assertEqual(parse_span(".gitignore"), (".gitignore", None, None))

    def test_code_members_with_a_line_are_not_citations(self):
        for span in ("Session.Timeout:20", "v1.2:3", "Math.max:2", "Foo.Db:3", "a.b:4", ".5:3", "..:2", "x:3", "obj.Lock:1"):
            self.assertIsNone(parse_span(span), span)

    def test_paths_with_spaces_are_citations_when_they_end_in_a_file(self):
        self.assertEqual(parse_span("To be deleted/FrontCounterDev/logcall.asp:212"),
                         ("To be deleted/FrontCounterDev/logcall.asp", 212, 212))
        self.assertEqual(parse_span("Blazor Template/Pages/x.razor:3-9"), ("Blazor Template/Pages/x.razor", 3, 9))
        self.assertEqual(parse_span("Blazor Template/Pages/x.razor"), ("Blazor Template/Pages/x.razor", None, None))
        self.assertEqual(parse_span("my docs\\Read Me.md:2"), ("my docs/Read Me.md", 2, 2))
        self.assertEqual(parse_span("Old Site/notes.db:1"), ("Old Site/notes.db", 1, 1))

    def test_spaced_spans_that_are_not_paths_are_rejected(self):
        for span in ("GET /api/x.json", "cat src/x.py", "Blazor Template/Pages/", "Blazor Template/x.cs, y.cs",
                     "see Old Site/x.foo", "a b", "To be deleted", "Old Site/notes.db", 'Old Site/x.asp"y',
                     "Old Site/x.asp = 1", "Old Site/f(x).asp", "Old Site /x.asp", "/Old Site/x.asp", "C:/Old Site/x.asp"):
            self.assertIsNone(parse_span(span), span)

    def test_spaced_paths_are_found_in_text(self):
        got = find_citations("Retired in `To be deleted/a b/logcall.asp:212`, see `x/y.py:1`.\n")
        self.assertEqual([c.path for c in got], ["To be deleted/a b/logcall.asp", "x/y.py"])

    def test_bare_file_citations_resolve_against_the_target(self):
        from appdoc import check

        with tempfile.TemporaryDirectory() as root:
            os.makedirs(os.path.join(root, "docker"))
            for rel, body in (("Procfile", "web: x\n"), ("docker/Dockerfile.rootless", "FROM a\nRUN b\nCMD c\n"),
                              ("MAINTAINERS", "x\n")):
                with open(os.path.join(root, rel), "w", encoding="utf-8") as fh:
                    fh.write(body)
            cites = find_citations("`Procfile:1` `docker/Dockerfile.rootless:3` `MAINTAINERS`\n")
            self.assertEqual(len(cites), 3)
            for c in cites:
                self.assertEqual(check._resolve(root, {}, c), (True, ""), c.raw)


if __name__ == "__main__":
    unittest.main()
