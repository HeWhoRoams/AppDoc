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


if __name__ == "__main__":
    unittest.main()
