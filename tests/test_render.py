import os
import re
import tempfile
import unittest

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
        self.assertRegex(h, r"Generated: \d{4}-\d{2}-\d{2}")
        self.assertEqual(h.count("<script>"), 1)  # only the Mermaid one
        self.assertIn("mermaid.initialize", h)
        self.assertNotIn("{{", h.split("<script>")[0])

    def test_no_mermaid_no_script(self):
        self.write("application-documentation.md", "# T\ntext\n")
        self.assertEqual(page.run(self.target, self.out, None), 0)
        self.assertNotIn("<script", self.html())

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
