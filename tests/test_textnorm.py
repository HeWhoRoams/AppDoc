"""textnorm: the two normalizations (R14), newlines and text."""
import unittest

from appdoc import textnorm


class Newlines(unittest.TestCase):
    def test_bytes_and_str_agree(self):
        for s in ("a\r\nb", "a\rb", "a\nb", "a\r\n\r\nb\r", "", "\r", "é\r\n"):
            as_str = textnorm.normalize_newlines(s)
            as_bytes = textnorm.normalize_newlines(s.encode("utf-8"))
            self.assertIsInstance(as_str, str)
            self.assertIsInstance(as_bytes, bytes)
            self.assertEqual(as_str.encode("utf-8"), as_bytes)

    def test_only_newlines_change(self):
        n = textnorm.normalize_newlines
        self.assertEqual(n("a \r\nb\t\rc\n\n"), "a \nb\t\nc\n\n")   # no trailing-space or final-newline work
        self.assertEqual(n("e\u0301"), "e\u0301")                          # no NFC

    def test_normalize_text_is_built_on_it(self):
        self.assertEqual(textnorm.normalize_text("a  \r\nb\rc\n"), "a\nb\nc")


if __name__ == "__main__":
    unittest.main()
