"""The ID-class table (template_spec.ID_CLASSES) is the one source for audit-plan sampling, register refs and C15 nouns."""
import contextlib
import io
import os
import shutil
import tempfile
import unittest
from unittest import mock

from appdoc import audit_plan, check, fill
from appdoc import template_spec as spec

HERE = os.path.dirname(os.path.abspath(__file__))
CASE = os.path.join(HERE, "corpus", "audit-plan")

WIDGETS = "\n## 99. Widgets\n\n| ID | Name |\n|---|---|\n" + "".join(f"| ZZ-{i} | w{i} |\n" for i in range(1, 8))


def _with_widget_table():
    tables = {**spec.TABLES, "99": spec.Table(("ID", "Name"), "ZZ-", nouns=("widget",), sampled=True)}
    return mock.patch.multiple(spec, TABLES=tables, ID_CLASSES=spec.id_classes(tables))


class GeneratedRegistry(unittest.TestCase):
    def test_generated_keys_unique(self):
        names = list(spec.GENERATED.values())
        self.assertEqual(len(names), len(set(names)), "one block name per key, no name twice")
        self.assertEqual(len(spec.GENERATED), len(set(spec.GENERATED)))
        # the five 2.8 blocks have their own subsection each (section number -> name)
        self.assertEqual(spec.GENERATED_2_8, {"2.4": "repo-docs", "5.4": "access-model", "8.1": "connections",
                                              "8.3": "integrations", "16.8": "pipeline"})
        for key, name in spec.GENERATED_2_8.items():
            self.assertEqual(spec.GENERATED[key], name)
        self.assertEqual(sorted(n for n in names if n not in spec.GENERATED_2_8.values()),
                         sorted(["scan-coverage", "entry-points", "closed-questions", "config-reference",
                                 "scheduled-jobs", "appendix-a"]))

    def test_2_8_blocks_are_required_and_listed_only_from_2_8(self):
        self.assertEqual(set(spec.generated_blocks((2, 7)).values()) & set(spec.GENERATED_2_8.values()), set())
        self.assertEqual(spec.generated_blocks((2, 8)), spec.GENERATED)
        self.assertEqual(spec.opaque_blocks((2, 7)), spec.OPAQUE_BLOCKS[:4])
        self.assertEqual(spec.opaque_blocks((2, 8)), spec.OPAQUE_BLOCKS)


class IdClassTable(unittest.TestCase):
    def test_derived_from_the_tables(self):
        self.assertEqual(list(spec.ID_CLASSES), ["F-", "UI-", "C-", "X-", "V-", "Q-", "R-"])
        self.assertEqual(spec.ID_PREFIXES, tuple(spec.ID_CLASSES))
        self.assertEqual({p: c.section for p, c in spec.ID_CLASSES.items()},
                         {"F-": "4", "UI-": "6", "C-": "8.1", "X-": "8.3", "V-": "10.1", "Q-": "14", "R-": "15"})
        self.assertEqual([c.prefix for c in spec.ID_CLASSES.values() if c.sampled], ["F-", "UI-", "C-", "X-", "R-"])
        self.assertEqual(spec.id_prefix_of("10.1"), "V-")
        self.assertIsNone(spec.id_prefix_of("9"))

    def test_every_count_class_has_a_renderer_and_every_noun_names_an_id_class(self):
        reg = mock.Mock(performed=True)
        reg.live_rows.return_value = []
        reg.rows = []
        for cls, kind in spec.COUNT_CLASSES.items():
            with self.subTest(cls=cls):
                self.assertIn(kind, ("id", "register", "facts"))
                self.assertIsNotNone(fill.count_marker_value(cls, {}, {}, reg))
                if kind == "id":
                    self.assertIn(cls + "-", spec.ID_CLASSES)
        for cls in spec.ID_CLASSES.values():
            self.assertTrue(all(n == n.lower() and not n.endswith("s") for n in cls.nouns), cls.nouns)

    def test_count_marker_classes_2_8(self):
        from appdoc import access_model
        new = ["areas", "access-rules", "role-constants", "guard-shapes", "secret-location-files", "configurations"]
        new += [f"state-changing-{l}" for l in access_model.LABELS]
        self.assertEqual(spec.ACCESS_LABELS, access_model.LABELS)
        for cls in new:
            with self.subTest(cls=cls):
                self.assertEqual(spec.COUNT_CLASSES[cls], "facts")
                self.assertTrue(spec.COUNT_NOUNS[cls])
                zero = 1 if cls == "configurations" else 0     # no configuration named reads as `base`
                self.assertEqual(access_model.count(cls, {}), zero)
                self.assertEqual(fill.count_marker_value(cls, {}, {}, None), zero)
        self.assertIsNone(access_model.count("routes", {}))
        self.assertIsNone(access_model.count("state-changing-bogus", {}))

    def test_a_new_table_prefix_is_picked_up_with_no_other_edit(self):
        with _with_widget_table():
            self.assertEqual(audit_plan.ref_for("ZZ-3"), "99/ZZ-3")
            self.assertTrue(audit_plan._in_section("ZZ-3", "99"))
            # C15 reads the noun from the table
            found = list(check._c15_sentences(["2 of 7 widgets are audited"], {"ZZ-1": 1}))
            self.assertEqual([(f[2], f[3], f[4], f[5]) for f in found], [("widget", "ZZ-", 2, 7)])
            # the audit plan samples the new section like the others
            with tempfile.TemporaryDirectory() as tmp:
                target = os.path.join(tmp, "t")
                shutil.copytree(CASE, target, ignore=shutil.ignore_patterns("__pycache__"))
                out = os.path.join(target, "docs", "appdoc")
                path = os.path.join(out, check.NARRATIVE)
                with open(path, encoding="utf-8") as fh:
                    text = fh.read()
                with open(path, "w", encoding="utf-8", newline="\n") as fh:
                    fh.write(text.rstrip("\n") + "\n" + WIDGETS)
                with contextlib.redirect_stdout(io.StringIO()):
                    plan = audit_plan.compute(target, out)
        sec = [s for s in plan["sections"] if s["section"] == "99"]
        self.assertEqual(len(sec), 1)
        self.assertEqual((sec[0]["mode"], sec[0]["total"], sec[0]["k"]), ("sampled", 7, 5))
        self.assertTrue(set(sec[0]["ids"]) <= {f"ZZ-{i}" for i in range(1, 8)})
        # outside the patch the class is gone again
        self.assertEqual(audit_plan.ref_for("ZZ-3"), "ZZ-3")


if __name__ == "__main__":
    unittest.main()
