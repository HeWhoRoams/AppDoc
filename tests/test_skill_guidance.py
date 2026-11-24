"""R71.B4: SKILL.md audit guidance (ADR 0015 scope, plan D2) and the template guide's C17 wording."""
import os
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def _read(*parts):
    with open(os.path.join(ROOT, *parts), encoding="utf-8") as fh:
        return fh.read()


class SkillGuidance(unittest.TestCase):
    def test_cited_candidate_check_is_a_step(self):
        skill = _read("SKILL.md")
        self.assertIn("cited finding-candidate id and line range support the claim", skill)

    def test_only_opaque_blocks_are_unaudited(self):
        from appdoc import template_spec
        skill = _read("SKILL.md")
        self.assertEqual(template_spec.opaque_blocks((2, 7)),
                         ("entry-points", "scheduled-jobs", "closed-questions", "appendix-a"))
        self.assertIn("Only the opaque generated blocks are not audited", skill)
        self.assertIn("Scan coverage and the configuration reference are audited text", skill)
        self.assertNotIn("Generated and opaque blocks are not audited", skill)

    def test_template_states_c17_digit_rule(self):
        tpl = _read("appdoc", "assets", "template.md")
        self.assertIn("any digit 0-9 at all", tpl)
        self.assertIn("exactly one backticked command", tpl)


class SkillRules(unittest.TestCase):
    """T28.B2: the 2.8 writing rules are data (`workflow.SKILL_RULES`), generated into SKILL.md, and say what the plan says."""

    @classmethod
    def setUpClass(cls):
        from appdoc import workflow
        cls.rules = {h: " ".join(" ".join(items).split()) for h, items in workflow.SKILL_RULES}
        cls.skill = " ".join(_read("SKILL.md").split())

    def test_rules_are_in_skill_md(self):
        for text in self.rules.values():
            self.assertIn(text.split(". ")[0][:60], self.skill)
        self.assertIn("appdoc-self:generated skill-rules", _read("SKILL.md"))

    def test_orient_reads_the_three_blocks_before_four_sections(self):
        orient = self.rules["Orient"]
        for needle in ("`access-model`", "`connections`", "`integrations`", "sections 3, 5, 8 and 10"):
            self.assertIn(needle, orient)

    def test_writing_rules(self):
        w = self.rules["Writing rules"]
        for needle in ("Never list a configuration file as not reviewed", "(R16)",
                       "Write \"Unknown\" only after you have checked the Facts summary",
                       "`no_app_restriction`, `signed_in_any` or `unknown` is a 10.1 finding or a dismissed",
                       "for each configuration", "application layer only",
                       "Do not write \"anonymous users can\" unless", "explicit anonymity"):
            self.assertIn(needle, w)

    def test_large_target_and_audit_checklist(self):
        self.assertIn("one subsystem per area", self.rules["Large Targets"])
        audit = self.rules["Audit checklist"]
        self.assertIn("Trace every Troubleshooting row and every fallback claim to its end", audit)
        self.assertIn("Check each generated block that says \"none\" against the reader the block names", audit)

    def test_run_step_zero_upgrades_before_check(self):
        from appdoc import workflow
        first = workflow.SKILL_STEPS[0]
        self.assertEqual(first.command, "upgrade <target>")
        self.assertIn("step 0", first.note)
        self.assertIn("older than the running template", first.note)
        self.assertIn("before `check`", first.note)
        self.assertIn("step 0 comes first", self.skill)


if __name__ == "__main__":
    unittest.main()
