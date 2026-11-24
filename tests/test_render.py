import json
import os
import re
import tempfile
import unittest

from appdoc import check, fill, register
from appdoc.render import page
from appdoc.render.markdown import render_markdown as md


class MarkdownTests(unittest.TestCase):
    def test_headings_and_ids_deduped(self):
        out = md("# Title\n## Setup\n## Setup\n### A `b` c")
        self.assertIn('<h1 id="title">Title</h1>', out)
        self.assertIn('<h2 id="setup">Setup</h2>', out)
        self.assertIn('<h2 id="setup-2">Setup</h2>', out)
        self.assertIn('<h3 id="a-b-c">', out)

    def test_inline(self):
        out = md("a **bold** and *em* and [x](https://e.com/?a=1&b=2)")
        self.assertIn("<strong>bold</strong>", out)
        self.assertIn("<em>em</em>", out)
        self.assertIn('<a href="https://e.com/?a=1&amp;b=2">x</a>', out)

    def test_javascript_link_not_linked(self):
        self.assertNotIn("<a ", md("[x](javascript:alert(1))"))

    def test_table(self):
        out = md("| A | B |\n|---|--:|\n| 1 | `x\\|y` |\n| 2 | 3 |")
        self.assertIn("<table>", out)
        self.assertEqual(out.count("<tr>"), 3)
        self.assertIn("<th>A</th>", out)
        self.assertIn('<th style="text-align:right">B</th>', out)

    def test_lists(self):
        out = md("- a\n- b\n  - c\n\n1. one\n2. two")
        self.assertIn("<ul><li>a</li><li>b<ul><li>c</li></ul></li></ul>", out)
        self.assertIn("<ol><li>one</li><li>two</li></ol>", out)

    def test_code_fence_escaped(self):
        out = md("```python\nif a < b:\n    pass\n```")
        self.assertIn('<pre><code class="language-python">if a &lt; b:\n    pass</code></pre>', out)

    def test_mermaid(self):
        out = md("```mermaid\ngraph TD; A-->B\n```")
        self.assertIn('<pre class="mermaid">graph TD; A--&gt;B</pre>', out)

    def test_blockquote_and_hr(self):
        out = md("> quoted\n\n---\n")
        self.assertIn("<blockquote><p>quoted</p></blockquote>", out)
        self.assertIn("<hr>", out)

    def test_escaping(self):
        out = md("<script>alert(1)</script>\n\n- <b>x</b>\n\n`<i>`")
        self.assertNotIn("<script", out)
        self.assertNotIn("<b>", out)
        self.assertIn("&lt;script&gt;alert(1)&lt;/script&gt;", out)
        self.assertIn("<code>&lt;i&gt;</code>", out)

    def test_citation_class(self):
        out = md("See `portal/verify.asp:6` and `Session(\"x\")`.")
        self.assertIn('<code class="cite">portal/verify.asp:6</code>', out)
        self.assertIn("<code>Session(&quot;x&quot;)</code>", out)

    def test_inferred_class(self):
        self.assertIn('<p class="inferred">', md("**Inferred:** it probably caches."))
        self.assertIn('<li class="inferred">', md("- **Inferred:** x"))
        self.assertIn('<td class="inferred">', md("| a |\n|---|\n| **Inferred:** y |"))
        self.assertNotIn("inferred", md("plain **Inferred:** later"))

    def test_comments_stripped(self):
        out = md("a <!-- hidden\nmulti --> b\n\n```\n<!-- keep -->\n```")
        self.assertNotIn("hidden", out)
        self.assertIn("&lt;!-- keep --&gt;", out)

    def test_unsupported_does_not_raise(self):
        for s in ["", "| broken | table", "```unterminated", "**unclosed", "[a](", "> > > x", "- ", "<!-- open",
                  "![img](x.png)", "\x00\ufffd", "#" * 20 + " x", "|---|\n|---|"]:
            self.assertIsInstance(md(s), str)


class PageTests(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.target = os.path.join(self.tmp.name, "my-app")
        self.out = os.path.join(self.target, "docs", "appdoc")
        os.makedirs(self.out)

    def write(self, name, text):
        with open(os.path.join(self.out, name), "w", encoding="utf-8", newline="\n") as f:
            f.write(text)

    def html(self):
        with open(os.path.join(self.out, page.HTML_NAME), encoding="utf-8") as f:
            return f.read()

    def test_missing_markdown(self):
        self.assertEqual(page.run(self.target, self.out, None), 1)

    def test_end_to_end(self):
        self.write("application-documentation.md",
                   "# My App\n## Overview\ntext `a/b.py:1` <script>alert(1)</script>\n### Detail\n"
                   "```mermaid\ngraph TD; A-->B\n```\n")
        self.write("facts.json", '{"target": {"commit": "abc1234"}}')
        self.write("check-report.md", "# Check: FAIL (3 problems)\n\nbody")
        self.assertEqual(page.run(self.target, self.out, None), 0)
        h = self.html()
        self.assertNotIn("\r", h)
        self.assertFalse(h.startswith("\ufeff"))
        for needle in ("my-app", "abc1234", "Check: FAIL (3 problems)", 'href="#overview"', 'href="#detail"',
                       "--brand: #6a0032", "&lt;script&gt;alert(1)&lt;/script&gt;"):
            self.assertIn(needle, h)
        self.assertNotIn("Generated:", h)  # R13: the page reads no clock, so rendering twice gives the same bytes
        self.assertEqual(h.count("<script>"), 1)  # only the Mermaid one
        self.assertIn("mermaid.initialize", h)
        self.assertNotIn("{{", h.split("<script>")[0])

    MD_WITH_DIAGRAM = "# My App\n## Overview\n### Detail\n```mermaid\ngraph TD; A-->B\n```\n"

    def test_inline_default_unchanged(self):
        """T28.B3: with no option (and with `inline`) the page carries the library in one inline script and no
        file is written beside it."""
        self.write("application-documentation.md", self.MD_WITH_DIAGRAM)
        self.assertEqual(page.run(self.target, self.out, None), 0)
        default = self.html()
        self.assertEqual(page.run(self.target, self.out, None, "inline"), 0)
        self.assertEqual(self.html(), default)
        self.assertEqual(default.count("<script"), 1)
        self.assertNotIn('<script src=', default)
        self.assertIn("mermaid.initialize", default)
        self.assertGreater(len(default), 100_000)                                  # the library is inline
        self.assertFalse(os.path.exists(os.path.join(self.out, "mermaid.min.js")))

    def test_mermaid_sibling_mode(self):
        """T28.B3: `sibling` writes mermaid.min.js once beside the HTML and the page links it instead of inlining it."""
        self.write("application-documentation.md", self.MD_WITH_DIAGRAM)
        self.assertEqual(page.run(self.target, self.out, None, "sibling"), 0)
        h = self.html()
        lib = os.path.join(self.out, "mermaid.min.js")
        self.assertTrue(os.path.isfile(lib))
        with open(os.path.join(page.ASSETS, "mermaid.min.js"), "rb") as fh:
            asset = fh.read()
        with open(lib, "rb") as fh:
            self.assertEqual(fh.read(), asset)                                      # byte-identical to the packaged library
        self.assertIn('<script src="mermaid.min.js"></script>', h)
        self.assertIn("mermaid.initialize", h)
        self.assertLess(len(h), 20_000)                                             # the page itself stays small
        self.assertNotIn("mermaid.min.js\n", h)
        # once: a second render leaves the file (same bytes, same mtime) and the page identical
        before = os.stat(lib).st_mtime_ns
        self.assertEqual(page.run(self.target, self.out, None, "sibling"), 0)
        self.assertEqual((os.stat(lib).st_mtime_ns, self.html()), (before, h))
        # a document with no diagram needs no library: no file, no script
        os.remove(lib)
        self.write("application-documentation.md", "# T\ntext\n")
        self.assertEqual(page.run(self.target, self.out, None, "sibling"), 0)
        self.assertFalse(os.path.exists(lib))
        self.assertNotIn("<script", self.html())

    def test_mermaid_option_on_the_command_line(self):
        from appdoc.__main__ import main
        import contextlib, io
        self.write("application-documentation.md", self.MD_WITH_DIAGRAM)
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(main(["render", self.target, "--mermaid", "sibling"]), 0)
        self.assertTrue(os.path.isfile(os.path.join(self.out, "mermaid.min.js")))
        with self.assertRaises(SystemExit):
            with contextlib.redirect_stderr(io.StringIO()):
                main(["render", self.target, "--mermaid", "cdn"])

    def test_no_mermaid_no_script(self):
        self.write("application-documentation.md", "# T\ntext\n")
        self.assertEqual(page.run(self.target, self.out, None), 0)
        self.assertNotIn("<script", self.html())

    def test_appendix_block_renders_once(self):
        title = register.APPENDIX_TITLE
        self.write("application-documentation.md", "# T\n## 1. Index\ntext\n")
        self.assertEqual(page.run(self.target, self.out, None), 0)
        h = self.html()
        self.assertNotIn(title, h)
        self.assertNotIn("Audit not performed", h)
        evidence = '{"type": "audit", "performed": true, "auditor": "independent", "scope": "s"}\n' \
                   '{"id": "E-1", "ref": "1", "claim": "a|b", "result": "Supported", "cites": ["a.py:1"], ' \
                   '"anchor": "x = 1", "limitation": "none"}\n'
        reg = register.parse(evidence)
        self.write("application-documentation.md",
                   f"# T\n## 1. Index\ntext\n## {title}\n\n{register.appendix_markdown(reg, {})}\n")
        self.assertEqual(page.run(self.target, self.out, None), 0)
        h = self.html()
        self.assertEqual(h.count(f'<h2 id="appendix-a-evidence-register-and-verification">{title}</h2>'), 1)
        self.assertEqual(h.count("E-1"), 1)  # the register row only (no root, so no verification bullet)
        self.assertIn('href="#appendix-a-evidence-register-and-verification"', h)
        self.assertIn('href="#a1-audit-state"', h)
        self.assertIn("<td>a|b</td>", h)
        self.assertNotIn("audit-banner", h.split("</style>", 1)[1])
        self.assertLess(h.index("1. Index"), h.index(title))

    def test_audit_not_performed_banner(self):
        title = register.APPENDIX_TITLE
        reg = register.parse('{"type": "audit", "performed": false, "scope": "time-boxed run"}\n')
        self.write("application-documentation.md",
                   f"# T\n## 1. Index\ntext\n## {title}\n\n{register.appendix_markdown(reg, {})}\n")
        self.assertEqual(page.run(self.target, self.out, None), 0)
        h = self.html()
        body = h.split("</style>", 1)[1]
        self.assertIn('<blockquote class="audit-banner"><p><strong>Audit not performed.</strong>', body)
        self.assertIn("time-boxed run", h)

    def test_plain_blockquote_has_no_banner_class(self):
        self.write("application-documentation.md", "# T\n> a note\n")
        self.assertEqual(page.run(self.target, self.out, None), 0)
        self.assertNotIn("audit-banner", self.html().split("</style>", 1)[1])

    def test_old_document_without_appendix_has_no_appendix_even_with_register(self):
        self.write("application-documentation.md", "# T\n## 1. Index\ntext\n")
        self.write("evidence.jsonl", '{"type": "audit", "performed": false, "scope": "x"}\n')
        self.assertEqual(page.run(self.target, self.out, None), 0)
        h = self.html()
        self.assertNotIn("Appendix A", h)
        self.assertNotIn("Audit not performed", h)

    def test_render_refuses_stale_generated_block(self):
        self.write("application-documentation.md",
                   "# T\n## 2. Coverage\n### 2.1 What was inspected\n"
                   "<!-- appdoc:generated scan-coverage -->\nstale content\n<!-- /appdoc:generated scan-coverage -->\n")
        self.write("facts.json", '{"stacks": [], "facts": []}')
        self.assertEqual(page.run(self.target, self.out, None), 2)

    def test_render_allows_fresh_generated_block(self):
        from appdoc import fill
        facts = {"stacks": [], "facts": []}
        body = fill.render_block("scan-coverage", facts, {"out_dir": self.out, "target": self.target})
        self.write("application-documentation.md",
                   f"# T\n## 2. Coverage\n### 2.1 What was inspected\n"
                   f"<!-- appdoc:generated scan-coverage -->\n{body}\n<!-- /appdoc:generated scan-coverage -->\n")
        self.write("facts.json", '{"stacks": [], "facts": []}')
        self.assertEqual(page.run(self.target, self.out, None), 0)

    def test_generated_block_table_reaches_html(self):
        """Phase 2.6: a generated block's table rows must appear in the rendered HTML."""
        from appdoc import fill
        facts = {
            "stacks": [{"name": "python-flask", "detail": {"supported": True, "file_count": 3,
                        "capabilities": ["entry_point", "config_key"]}}],
            "facts": [
                {"kind": "entry_point", "stack": "python-flask", "path": "app.py", "line": 10,
                 "name": "index", "detail": {"type": "route", "handler": "index"}},
                {"kind": "entry_point", "stack": "python-flask", "path": "app.py", "line": 20,
                 "name": "login", "detail": {"type": "route", "handler": "login"}},
            ],
        }
        body = fill.render_block("entry-points", facts, {"out_dir": self.out, "target": self.target})
        self.assertIn("| Handler file |", body)
        self.write("application-documentation.md",
                   f"# T\n## 4. Features\n### 4.1 Entry points\n"
                   f"<!-- appdoc:generated entry-points -->\n{body}\n<!-- /appdoc:generated entry-points -->\n")
        self.write("facts.json", json.dumps(facts))
        self.assertEqual(page.run(self.target, self.out, None), 0)
        h = self.html()
        self.assertIn("Handler file", h)
        self.assertIn("app.py", h)
        self.assertIn("route", h)
        self.assertIn("<td>2</td>", h)  # 2 routes

    def test_css_fallback_order(self):
        self.write("application-documentation.md", "# T\n")
        page.run(self.target, self.out, None)
        self.assertIn("--brand: #6a0032", self.html())
        self.write("theme.css", ":root{--brand:#111111;} /*local*/")
        page.run(self.target, self.out, None)
        self.assertIn("/*local*/", self.html())
        explicit = os.path.join(self.tmp.name, "x.css")
        with open(explicit, "w") as f:
            f.write("/*explicit*/")
        page.run(self.target, self.out, explicit)
        h = self.html()
        self.assertIn("/*explicit*/", h)
        self.assertNotIn("/*local*/", h)


if __name__ == "__main__":
    unittest.main()


class ConfigTrailerTests(unittest.TestCase):
    @staticmethod
    def _doc(*specs):
        return {"stacks": [], "facts": [{"kind": "config_key", "stack": "s", "path": p, "line": 1, "name": n,
                                         "detail": {"role": r}} for p, n, r in specs]}

    def test_config_trailer_counts(self):
        d = self._doc(("a.py", "K", "app"), ("a.py", "E1", "env"), ("b.py", "E1", "env"), ("b.py", "E2", "env"),
                      (".github/workflows/ci.yml", "C1", "ci"))
        out = fill.render_block("config-reference", d)
        self.assertIn("Shown 1 of 1 application key.", out)
        self.assertEqual(out.splitlines()[-1],
                         "2 env-var keys and 1 CI key are excluded from the application table (see facts.json).")

    def test_trailer_absent_without_env_or_ci_keys(self):
        self.assertNotIn("excluded", fill.render_block("config-reference", self._doc(("a.py", "K", "app"))))

    def test_trailer_when_no_application_keys(self):
        out = fill.render_block("config-reference", self._doc(("a.py", "E", "env")))
        self.assertIn("No application config keys were extracted.", out)
        self.assertIn("1 env-var key and 0 CI keys are excluded", out)

    def test_app_key_count_is_distinct_uncommented_app_names(self):
        d = self._doc(("a.py", "K", "app"), ("b.py", "K", "app"), ("a.py", "E", "env"))
        self.assertEqual(fill.config_app_count(d), 1)

    def test_c7_flags_a_16_6_block_count_that_is_not_the_app_role_count(self):
        """F3: the exact block comparison replaces the prose parser; it flags the same count mismatch."""
        d = self._doc(("a.py", "K", "app"), ("a.py", "E", "env"))
        found = []
        add = lambda *a: found.append(a)

        def run(body):
            raw = "<!-- appdoc:generated config-reference -->\n" + body + "\n<!-- /appdoc:generated config-reference -->\n"
            del found[:]
            check._c7_blocks(raw, {}, d, None, None, add)
            return [f for f in found if "config-reference" in f[2]]

        self.assertEqual(run(fill.render_block("config-reference", d)), [])
        bad = fill.render_block("config-reference", d).replace("Shown 1 of 1 application key", "Shown 2 of 2 application keys")
        got = run(bad)
        self.assertEqual(len(got), 1)
        self.assertIn("1", got[0][2])
