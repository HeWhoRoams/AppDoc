import unittest

from appdoc import notes


class NotesParseTests(unittest.TestCase):
    def test_parse_keeps_valid_notes_in_file_order_and_reports_bad_lines(self):
        text = "\n".join([
            '{"block": "entry-points", "text": "a", "cites": ["x.py:1"], "block_sha": ""}',
            "",
            "not json",
            '{"block": "entry-points", "text": "", "cites": [], "block_sha": ""}',
            '{"block": "entry-points", "text": "two\\nlines", "cites": [], "block_sha": ""}',
            '{"block": "entry-points", "text": "b", "cites": "x.py", "block_sha": ""}',
            '{"block": "entry-points", "text": "c", "cites": [], "block_sha": "XYZ"}',
            '{"text": "no block", "cites": [], "block_sha": ""}',
            '{"block": "scheduled-jobs", "text": "d", "cites": [], "block_sha": "0123456789ab"}',
        ])
        r = notes.parse(text)
        self.assertEqual([(no, n["text"]) for no, n in r.notes], [(1, "a"), (9, "d")])
        self.assertEqual([no for no, _ in r.errors], [3, 4, 5, 6, 7, 8])
        self.assertEqual([n["text"] for n in r.for_block("scheduled-jobs")], ["d"])

    def test_missing_text_is_empty(self):
        self.assertEqual(notes.parse(None).notes, [])
        self.assertEqual(notes.parse("").errors, [])

    def test_body_sha_ignores_trailing_whitespace_and_newlines(self):
        self.assertEqual(notes.body_sha("a  \nb\n"), notes.body_sha("a\r\nb"))
        self.assertNotEqual(notes.body_sha("a"), notes.body_sha("b"))


if __name__ == "__main__":
    unittest.main()
