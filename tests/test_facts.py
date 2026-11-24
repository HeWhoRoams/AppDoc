"""Fact record rules: kinds, detail keys, flat scalar details."""
import unittest

from appdoc import facts as F

NEW_KINDS_2_8 = (
    "security_setting", "access_rule", "access_rule_unmatched", "config_transform", "config_external",
    "config_unparsed", "guard_class", "guard_use", "guard_candidate", "const_def", "project", "build_define",
    "publish_profile", "context_directive", "controller_class", "host_auth",
    "method_call",
)


class FactRulesTests(unittest.TestCase):
    def test_dict_detail_rejected(self):
        with self.assertRaises(ValueError):
            F.Fact.make("security_setting", "aspnet", "Web.config", 3, "x", value={"a": 1})
        with self.assertRaises(ValueError):
            F.Fact.make("access_rule", "aspnet", "Web.config", 3, "x", roles=[{"a": 1}])

    def test_scalars_and_lists_of_scalars_accepted(self):
        f = F.Fact.make("access_rule", "aspnet", "Web.config", 3, "x", roles=["b", "a"], anon=True, users_named=0)
        self.assertEqual(f.detail_dict()["roles"], ["a", "b"])

    def test_new_kinds_have_closed_detail_keys(self):
        for k in NEW_KINDS_2_8:
            with self.subTest(kind=k):
                self.assertIn(k, F.KINDS)
                self.assertIn(k, F.DETAIL_KEYS)
                self.assertTrue(F.DETAIL_KEYS[k])

    def test_every_kind_has_detail_keys(self):
        self.assertEqual(set(F.KINDS) - {"entry_point"} - set(F.DETAIL_KEYS), set())

    def test_schema_is_the_one_after_2_7(self):
        self.assertEqual(F.SCHEMA, "appdoc-facts/8")  # 2.7 wrote /7 (T28.C0)


if __name__ == "__main__":
    unittest.main()
