"""appdoc/context.py: the single parser of appdoc-context.md (pure function of the file text)."""
import unittest

from appdoc import context

TEXT = """# Context

Ownership: Business owner: Registrar's office
Ownership: Technical owner = App team
ownership: bogus line without separator

```never-mention
Project Falcon
  secret-codename

```

```python
Ownership: Fake: inside another fence
```
Some prose.
"""


class ContextTests(unittest.TestCase):
    def test_never_mention_block(self):
        self.assertEqual(context.parse(TEXT).never_mention, ["Project Falcon", "secret-codename"])

    def test_ownership_lines(self):
        o = context.parse(TEXT).ownership
        self.assertEqual([(x.role, x.value, x.line) for x in o],
                         [("Business owner", "Registrar's office", 3), ("Technical owner", "App team", 4)])

    def test_missing_file_is_empty(self):
        c = context.parse(None)
        self.assertEqual((c.never_mention, c.ownership), ([], []))
        c = context.parse("")
        self.assertEqual((c.never_mention, c.ownership), ([], []))


if __name__ == "__main__":
    unittest.main()
