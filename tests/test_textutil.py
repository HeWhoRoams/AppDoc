"""textutil.plural lives in a neutral module; no module imports it from inside a function (F14)."""

import os
import re
import unittest

from appdoc import textutil

APPDOC = os.path.join(os.path.dirname(__file__), "..", "appdoc")


class TextutilTests(unittest.TestCase):
    def test_plural(self):
        self.assertEqual(textutil.plural(1, "file"), "1 file")
        self.assertEqual(textutil.plural(0, "file"), "0 files")
        self.assertEqual(textutil.plural(2, "entry", "entries"), "2 entries")

    def test_no_function_level_plural_import(self):
        for name in sorted(os.listdir(APPDOC)):
            if name.endswith(".py"):
                with open(os.path.join(APPDOC, name), encoding="utf-8") as fh:
                    text = fh.read()
                self.assertIsNone(re.search(r"^[ \t]+(from|import) .*\bplural\b", text, re.M), name)

    def test_one_definition(self):
        for name in sorted(os.listdir(APPDOC)):
            if name.endswith(".py") and name != "textutil.py":
                with open(os.path.join(APPDOC, name), encoding="utf-8") as fh:
                    self.assertNotIn("def plural(", fh.read(), name)


if __name__ == "__main__":
    unittest.main()
