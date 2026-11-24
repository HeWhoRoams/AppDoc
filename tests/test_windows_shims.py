"""LF vs CRLF and backslash vs slash: what the readers and the fingerprint promise on any OS (R71.A5)."""

import importlib
import json
import os
import tempfile
import unittest

from appdoc import citations, notes, register
from appdoc.textutil import read_text


def _fp():
    """doc_sha and document_text from appdoc.fingerprint when it exists, else appdoc.check."""
    for name in ("appdoc.fingerprint", "appdoc.check"):
        try:
            mod = importlib.import_module(name)
        except ImportError:
            continue
        if hasattr(mod, "doc_sha") and hasattr(mod, "document_text"):
            return mod.doc_sha, mod.document_text
    raise ImportError("doc_sha/document_text not found")


NARRATIVE = (
    "# Title\n\n"
    "Intro with `portal/verify.asp:6` and <!-- a comment\nspanning lines -->\n\n"
    "<!-- appdoc:generated entry-points -->\n| a | b |\n| c | d |\n<!-- /appdoc:generated entry-points -->\n\n"
    "Count <!-- appdoc:count x -->7<!-- /appdoc:count --> items.\n"
)
REGISTER = "\n".join([
    json.dumps({"type": "audit", "performed": False}),
    json.dumps({"id": "E-1", "ref": "1", "claim": "c", "result": "confirmed",
                "cites": ["portal\\verify.asp:6"], "anchor": "x", "limitation": ""}),
]) + "\n"
NOTES = json.dumps({"block": "entry-points", "text": "t", "cites": ["a/b.py:1"], "block_sha": ""}) + "\n"


def crlf(s):
    return s.replace("\n", "\r\n")


class NewlineTests(unittest.TestCase):
    def test_fingerprint_same_for_lf_and_crlf(self):
        doc_sha, document_text = _fp()
        self.assertEqual(doc_sha(NARRATIVE), doc_sha(crlf(NARRATIVE)))
        self.assertEqual(document_text(NARRATIVE), document_text(crlf(NARRATIVE)))
        self.assertEqual(document_text(NARRATIVE, mask_counts=True, pad=False),
                         document_text(crlf(NARRATIVE), mask_counts=True, pad=False))

    def test_fingerprint_ignores_lone_cr(self):
        doc_sha, _ = _fp()
        self.assertEqual(doc_sha(NARRATIVE), doc_sha(NARRATIVE.replace("\n", "\r")))

    def test_fingerprint_still_sees_prose_edits(self):
        doc_sha, _ = _fp()
        self.assertNotEqual(doc_sha(NARRATIVE), doc_sha(NARRATIVE.replace("Intro", "Outro")))

    def test_register_parse_same_for_lf_and_crlf(self):
        a, b = register.parse(REGISTER), register.parse(crlf(REGISTER))
        self.assertEqual((a.errors, a.audit, a.rows), (b.errors, b.audit, b.rows))
        self.assertEqual(len(a.rows), 1)

    def test_notes_parse_same_for_lf_and_crlf(self):
        a, b = notes.parse(NOTES), notes.parse(crlf(NOTES))
        self.assertEqual((a.errors, a.notes), (b.errors, b.notes))
        self.assertEqual(a.errors, [])

    def test_read_text_keeps_bytes_and_decodes_utf8_with_crlf(self):
        with tempfile.TemporaryDirectory() as d:
            p = os.path.join(d, "n.md")
            with open(p, "wb") as fh:
                fh.write(crlf("café\nline\n").encode("utf-8"))
            self.assertEqual(read_text(p), "café\r\nline\r\n")


class CitationPathTests(unittest.TestCase):
    def test_backslash_and_slash_parse_alike(self):
        for slash, back in (("portal/verify.asp:6", "portal\\verify.asp:6"),
                            ("src/App.java:40-52", "src\\App.java:40-52"),
                            ("Old Site/a.asp:3", "Old Site\\a.asp:3"),
                            ("a/b/c.py", "a\\b\\c.py")):
            self.assertEqual(citations.parse_span(slash), citations.parse_span(back), back)
            self.assertNotIn("\\", citations.parse_span(back)[0])

    def test_find_citations_same_for_lf_crlf_and_backslash(self):
        text = "one `a/b.py:2`\n\n```\n`skip/me.py:1`\n```\ntwo `c\\d.py:3-4`\n"
        want = [(c.doc_line, c.path, c.start, c.end) for c in citations.find_citations(text)]
        got = [(c.doc_line, c.path, c.start, c.end) for c in citations.find_citations(crlf(text))]
        self.assertEqual(want, got)
        self.assertEqual(want, [(1, "a/b.py", 2, 2), (6, "c/d.py", 3, 4)])

    def test_register_row_cite_path_normalized(self):
        row = register.parse(REGISTER).rows[0][1]
        self.assertEqual(register._first_path(row), "portal/verify.asp")


if __name__ == "__main__":
    unittest.main()
