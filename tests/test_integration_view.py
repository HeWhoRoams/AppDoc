"""Phase 6b: the integration view is a deterministic post-pass.

``render_integration_view(doc)`` is a pure function of the raw Facts (``facts.json``): given the
same Facts it produces byte-identical Markdown. It is rendered near the top of the Facts summary
and, when a Narrative is present, of the HTML page — but it never mutates the raw Facts.
"""
import json
import os
import tempfile
import unittest

from appdoc import extract
from appdoc.integration import render_integration_view
from appdoc.render import page

HERE = os.path.dirname(os.path.abspath(__file__))
SAMPLE = os.path.join(HERE, "samples", "integrations")


def _run():
    with tempfile.TemporaryDirectory() as out:
        return extract.extract(SAMPLE, out)


class IntegrationViewDeterminism(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text_a, cls.summary_a = _run()
        cls.text_b, cls.summary_b = _run()
        cls.doc = json.loads(cls.text_a)
        cls.view = render_integration_view(cls.doc)

    def test_view_is_byte_identical_across_two_runs(self):
        # The Facts are byte-identical across runs (6a is additive but still deterministic), and the
        # view — a pure function of the Facts — is therefore byte-identical too.
        self.assertEqual(self.text_a, self.text_b)
        self.assertEqual(self.summary_a, self.summary_b)
        self.assertEqual(render_integration_view(json.loads(self.text_a)),
                         render_integration_view(json.loads(self.text_b)))

    def test_view_is_pure_over_a_single_doc(self):
        self.assertEqual(self.view, render_integration_view(self.doc))

    def test_view_is_nonempty_and_typed(self):
        self.assertIn("## System Connections", self.view)
        # Two cache connections: the plain host (get_cache) and the credential-bearing
        # URL (get_cache_cred) — the catalog redacts the credential, not the connection.
        self.assertIn("| Cache | connection | 2 | `redis.from_url` |", self.view)
        self.assertIn("| Queue | connection | 1 | `kafka.KafkaProducer` |", self.view)
        self.assertIn("| Object storage | connection | 1 | `boto3.s3` |", self.view)
        self.assertIn("app → { cache, queue, object_storage, grpc, ldap, search }", self.view)

    def test_view_appears_in_summary_before_stacks(self):
        self.assertIn("## System Connections", self.summary_a)
        self.assertLess(self.summary_a.index("## System Connections"), self.summary_a.index("## Stacks"))

    def test_view_renders_into_html(self):
        with tempfile.TemporaryDirectory() as d:
            target = os.path.join(d, "app")
            outd = os.path.join(target, "docs", "appdoc")
            os.makedirs(outd)
            with open(os.path.join(outd, "application-documentation.md"), "w", encoding="utf-8") as f:
                f.write("# My App\n## Overview\nSome text.\n")
            with open(os.path.join(outd, "facts.json"), "w", encoding="utf-8") as f:
                f.write(self.text_a)
            self.assertEqual(page.run(target, outd, None), 0)
            with open(os.path.join(outd, "application-documentation.html"), encoding="utf-8") as f:
                html = f.read()
            self.assertIn('<h2 id="system-connections">', html)
            self.assertIn('href="#system-connections"', html)  # listed in the TOC near the top
            # The Narrative title (h1) stays first; the view is injected after it.
            self.assertLess(html.index("<h1"), html.index('<h2 id="system-connections"'))

    def test_view_is_empty_without_integration_facts(self):
        self.assertEqual(render_integration_view({"facts": []}), "")
        # A doc with only entry_point/data_access facts yields no integration view.
        self.assertEqual(render_integration_view(
            {"facts": [{"kind": "entry_point", "stack": "python-flask", "path": "a.py", "line": 1,
                        "name": "/x", "detail": {}}]}), "")

    def test_view_excludes_test_code_facts(self):
        doc = {"facts": [
            {"kind": "connection", "stack": "python-flask", "path": "a.py", "line": 1,
             "name": "redis.Redis", "detail": {"type": "cache", "test": True}},
            {"kind": "connection", "stack": "python-flask", "path": "b.py", "line": 2,
             "name": "redis.Redis", "detail": {"type": "cache"}},
        ]}
        view = render_integration_view(doc)
        self.assertNotIn("a.py:1", view)   # test-code location is excluded
        self.assertIn("b.py:2", view)

    def test_smtp_renders_in_canonical_group(self):
        # smtp is a canonical TYPE_ORDER type (after email, before process). With `file`
        # (the last canonical type), smtp must sort BEFORE file — NOT after it via the
        # `extra` branch (which would yield `app → { file, smtp }`).
        doc = {"facts": [
            {"kind": "connection", "stack": "python-flask", "path": "a.py", "line": 1,
             "name": "open", "detail": {"type": "file"}},
            {"kind": "connection", "stack": "python-flask", "path": "b.py", "line": 2,
             "name": "SmtpClient", "detail": {"type": "smtp"}},
        ]}
        view = render_integration_view(doc)
        self.assertIn("Email (SMTP)", view)           # canonical label, not the "Smtp" fallback
        self.assertNotIn("| Smtp |", view)            # the fallback label is NOT used in the map...
        self.assertNotIn("**Smtp**", view)            # ...or the provenance
        self.assertIn("app → { smtp, file }", view)   # smtp before file (canonical order)
        self.assertIn("| Email (SMTP) | connection | 1 | `SmtpClient` |", view)


if __name__ == "__main__":
    unittest.main()
