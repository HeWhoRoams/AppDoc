"""appdoc/context.py: the single parser of appdoc-context.md (pure function of the file text)."""
import json
import os
import shutil
import tempfile
import unittest
from unittest import mock

from appdoc import context, extract
from appdoc import facts as F

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


DIRECTIVES = """# Context
Auth attributes: RolesGuard, [SiteAuthorize], RolesGuard
Auth attributes: Extra
Production config: Staging
Reference year: 2026
Record connection targets: Yes
Audit floor: 0.5, 8
Ownership: Business owner: Registrar's office

```never-mention
Reference year: 1999
Auth attributes: Hidden
```
"""


class DirectiveTests(unittest.TestCase):
    def test_directive_values(self):
        c = context.parse(DIRECTIVES)
        self.assertEqual([(a.line, a.names) for a in c.auth_attributes],
                         [(2, ("RolesGuard", "SiteAuthorize")), (3, ("Extra",))])
        self.assertEqual((c.production_config.name, c.production_config.line), ("Staging", 4))
        self.assertEqual((c.reference_year.year, c.reference_year.line), (2026, 5))
        self.assertTrue(c.record_connection_targets.enabled)

    def test_defaults_and_bad_values(self):
        c = context.parse("")
        self.assertEqual((c.auth_attributes, c.production_config, c.reference_year, c.record_connection_targets),
                         ([], None, None, None))
        c = context.parse("Reference year: 26\nReference year: soon\nRecord connection targets: maybe\n"
                          "Production config: \nAuth attributes: 1bad, ok_1\n")
        self.assertIsNone(c.reference_year)
        self.assertIsNone(c.record_connection_targets)
        self.assertIsNone(c.production_config)
        self.assertEqual(c.auth_attributes[0].names, ("ok_1",))
        self.assertFalse(context.parse("Record connection targets: no").record_connection_targets.enabled)
        # the last valid value wins
        self.assertEqual(context.parse("Reference year: 2025\nReference year: 2026").reference_year.year, 2026)

    def test_directive_list_in_line_order(self):
        ds = context.directives(context.parse(DIRECTIVES))
        self.assertEqual([(d.line, d.name) for d in ds],
                         [(2, "Auth attributes"), (3, "Auth attributes"), (4, "Production config"),
                          (5, "Reference year"), (6, "Record connection targets"), (7, "Audit floor"),
                          (8, "Ownership")])
        by = {d.line: d for d in ds}
        self.assertEqual(by[5].value, "2026")
        self.assertEqual(by[6].value, "yes")
        self.assertIsNone(by[8].value)  # an ownership value may name a person and is never recorded


def _target(text):
    root = tempfile.mkdtemp()
    out = tempfile.mkdtemp()
    for d in (root, out):
        pass
    with open(os.path.join(root, "appdoc-context.md"), "w", encoding="utf-8") as fh:
        fh.write(text)
    with open(os.path.join(root, "app.py"), "w") as fh:
        fh.write("print('x')\n")
    return root, out


class ExtractDirectiveTests(unittest.TestCase):
    def _run(self, text, workers=0):
        root, out = _target(text)
        self.addCleanup(shutil.rmtree, root, True)
        self.addCleanup(shutil.rmtree, out, True)
        return json.loads(extract.extract(root, out, workers=workers, use_cache=False)[0])

    def test_directives_parsed_once(self):
        root, out = _target(DIRECTIVES)
        self.addCleanup(shutil.rmtree, root, True)
        self.addCleanup(shutil.rmtree, out, True)
        with mock.patch.object(context, "parse", wraps=context.parse) as spy:
            doc = json.loads(extract.extract(root, out, workers=0, use_cache=False)[0])
        self.assertEqual(spy.call_count, 1)
        ds = [f for f in doc["facts"] if f["kind"] == "context_directive"]
        self.assertEqual(len(ds), 7)  # one Fact per directive line, none for the fenced block
        self.assertEqual({f["path"] for f in ds}, {"appdoc-context.md"})
        self.assertEqual({f["stack"] for f in ds}, {"generic"})
        year = next(f for f in ds if f["name"] == "Reference year")
        self.assertEqual((year["line"], year["detail"]), (5, {"directive": "reference_year", "value": "2026"}))
        auth = next(f for f in ds if f["line"] == 2)
        self.assertEqual(auth["detail"]["names"], ["RolesGuard", "SiteAuthorize"])
        # ownership value never reaches a Fact
        self.assertNotIn("Registrar", json.dumps(doc))
        self.assertTrue(all(k in F.DETAIL_KEYS["context_directive"] for f in ds for k in f["detail"]))

    def test_no_context_file_no_directive_facts(self):
        root = tempfile.mkdtemp()
        out = tempfile.mkdtemp()
        self.addCleanup(shutil.rmtree, root, True)
        self.addCleanup(shutil.rmtree, out, True)
        with open(os.path.join(root, "app.py"), "w") as fh:
            fh.write("x = 1\n")
        doc = json.loads(extract.extract(root, out, workers=0, use_cache=False)[0])
        self.assertEqual([f for f in doc["facts"] if f["kind"] == "context_directive"], [])

    def test_unmatched_directive_disclosed(self):
        guard = F.Fact.make("guard_use", "aspnet", "C.cs", 3, "RolesGuard", scope="class")
        cand = F.Fact.make("guard_candidate", "aspnet", "C.cs", 9, "SiteAuthorizeAttribute", uses=3)
        ds = [F.Fact.make("context_directive", "generic", "appdoc-context.md", 2, "Auth attributes",
                          directive="auth_attributes", names=["RolesGuard", "site_authorize", "Ghost"]),
              F.Fact.make("context_directive", "generic", "appdoc-context.md", 4, "Reference year",
                          directive="reference_year", value="2026")]
        out = extract._match_directives(ds + [guard, cand])
        d = {f.name: f.detail_dict() for f in out if f.kind == "context_directive"}
        # matched case-insensitively and with or without the Attribute suffix; the rest is disclosed, not an error
        self.assertEqual(d["Auth attributes"]["context_unmatched"], ["Ghost", "site_authorize"])
        self.assertNotIn("context_unmatched", d["Reference year"])
        self.assertEqual(len(out), 4)
        # with no guard evidence at all nothing is claimed (no detector has run, so absence proves nothing)
        quiet = extract._match_directives(ds)
        self.assertTrue(all("context_unmatched" not in f.detail_dict() for f in quiet))
        # everything matched: no key
        full = F.Fact.make("context_directive", "generic", "appdoc-context.md", 2, "Auth attributes",
                           directive="auth_attributes", names=["RolesGuard", "Ghost", "SiteAuthorize"])
        ok = extract._match_directives([full, guard, F.Fact.make("guard_use", "aspnet", "C.cs", 4, "Ghost"),
                                                  F.Fact.make("guard_use", "aspnet", "C.cs", 5, "SiteAuthorize")])
        self.assertTrue(all("context_unmatched" not in f.detail_dict() for f in ok if f.kind == "context_directive"))


if __name__ == "__main__":
    unittest.main()
