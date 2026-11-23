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

    def test_audit_floor_directive(self):
        c = context.parse("# Context\nAudit floor: 0.5, 8\n")
        self.assertEqual((c.audit_floor.fraction, c.audit_floor.minimum, c.audit_floor.line), ("0.5", 8, 2))
        self.assertEqual(context.parse("audit floor: 40%, 6").audit_floor.fraction, "0.4")
        self.assertIsNone(context.parse("Audit floor: lots, 3").audit_floor)
        self.assertIsNone(context.parse("Audit floor: 1.5, 3").audit_floor)
        self.assertIsNone(context.parse("```\nAudit floor: 0.5, 8\n```").audit_floor)
        self.assertIsNone(context.parse(None).audit_floor)


if __name__ == "__main__":
    unittest.main()
