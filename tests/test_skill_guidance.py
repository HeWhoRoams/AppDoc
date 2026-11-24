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
        self.assertEqual(template_spec.OPAQUE_BLOCKS,
                         ("entry-points", "scheduled-jobs", "closed-questions", "appendix-a"))
        self.assertIn("Only the opaque generated blocks are not audited", skill)
        self.assertIn("Scan coverage and the configuration reference are audited text", skill)
        self.assertNotIn("Generated and opaque blocks are not audited", skill)

    def test_template_states_c17_digit_rule(self):
        tpl = _read("appdoc", "assets", "template.md")
        self.assertIn("any digit 0-9 at all", tpl)
        self.assertIn("exactly one backticked command", tpl)


if __name__ == "__main__":
    unittest.main()
