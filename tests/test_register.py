import json
import os
import tempfile
import unittest

from appdoc import facts, register
from appdoc.register import appendix_markdown, locate, parse

AUDIT = {"type": "audit", "performed": True, "auditor": "independent", "scope": "sections 3-10"}


def make_target():
    """A temp Target with app/main.py whose lines are 'line 1'..'line 10'."""
    tmp = tempfile.TemporaryDirectory()
    target = os.path.join(tmp.name, "target")
    os.makedirs(os.path.join(target, "app"))
    with open(os.path.join(target, "app", "main.py"), "w") as fh:
        fh.write("\n".join(f"line {i}" for i in range(1, 11)) + "\n")
    return tmp, target


def row(n, result="Supported", anchor="x = 1", cites=("a.py:1",), ref="10.1/V-1", claim="c", limitation="none"):
    return {"id": f"E-{n}", "ref": ref, "claim": claim, "result": result, "cites": list(cites),
            "anchor": anchor, "limitation": limitation}


def reg_of(*rows, audit=AUDIT):
    return parse("\n".join(json.dumps(o) for o in (audit, *rows)))


def block(md, heading):
    """Text of one ### subsection."""
    after = md.split(f"### {heading}", 1)[1]
    return after.split("\n### ", 1)[0]


class AppendixMarkdownTests(unittest.TestCase):
    def test_structure_and_counts(self):
        md = appendix_markdown(reg_of(row(1), row(2, "Corrected", ref="7.1"), row(3, "Downgraded")), {})
        heads = [l for l in md.splitlines() if l.startswith("#")]
        self.assertEqual(heads, ["### A.1 Audit state", "### A.2 Coverage", "### A.3 Register",
                                 "### A.4 Verification commands"])
        self.assertIn("**Auditor:** independent. **Scope:** sections 3-10", block(md, "A.1 Audit state"))
        self.assertIn("3 rows: 1 Supported, 1 Corrected, 1 Downgraded.", md)
        self.assertNotIn("Dismissed", block(md, "A.2 Coverage"))

    def test_dismissed_and_answerable_parse_and_count(self):
        reg = reg_of(row(1), row(2, "Dismissed", ref="smell/ab12cd34", anchor="", cites=()),
                     row(3, "Answerable", ref="14/Q-1", anchor="", cites=()))
        self.assertEqual(reg.errors, [])
        self.assertEqual(register.RESULTS[-2:], ("Dismissed", "Answerable"))
        self.assertEqual(reg.counts()["Dismissed"], 1)
        self.assertEqual(reg.counts()["Answerable"], 1)
        md = appendix_markdown(reg, {})
        self.assertIn("3 rows: 1 Supported, 0 Corrected, 0 Downgraded, 1 Dismissed, 1 Answerable.", md)
        self.assertNotIn("E-2** (", md)  # no command for rows without an anchor

    def test_coverage_table_is_rendered_when_given(self):
        md = appendix_markdown(reg_of(row(1)), {}, coverage=[("10.1", 1, 2), ("7 (workflows)", 0, 3)])
        cov = block(md, "A.2 Coverage")
        self.assertIn("| Section | IDs with a register row |", cov)
        self.assertIn("| 10.1 | 1 of 2 |", cov)
        self.assertIn("| 7 (workflows) | 0 of 3 |", cov)
        self.assertNotIn("| Section |", appendix_markdown(reg_of(row(1)), {}))

    def test_no_register(self):
        md = appendix_markdown(None, {})
        self.assertEqual(md.splitlines()[0], "### A.1 Audit state")
        self.assertIn(f"> {register.AUDIT_NOT_PERFORMED}", md)
        self.assertNotIn("A.2", md)

    def test_audit_not_performed(self):
        reg = parse('{"type": "audit", "performed": false, "scope": "time-boxed run"}')
        md = appendix_markdown(reg, {})
        self.assertIn(f"> {register.AUDIT_NOT_PERFORMED} The source-to-claim audit was not performed.", md)
        self.assertIn("time-boxed run", md)
        self.assertNotIn("A.3", md)

    def test_register_table_escapes_cells(self):
        md = appendix_markdown(reg_of(row(1, claim="a|b\nc", limitation="x|y", cites=("a.py:1", "`b.py:2-3`"))), {})
        table = block(md, "A.3 Register")
        self.assertIn("| ID | Ref | Claim | Result | Cites | Limitation |", table)
        self.assertIn("| E-1 | 10.1/V-1 | a\\|b c | Supported | `a.py:1` `b.py:2-3` | x\\|y |", table)

    def test_empty_register_one_line(self):
        md = appendix_markdown(reg_of(), {})
        self.assertIn("### A.3 Register\n\nThe register has no rows.", md)
        self.assertIn("### A.4 Verification commands\n\nNo verification commands (no Target root).", md)

    def test_commands_plain(self):
        tmp, target = make_target()
        self.addCleanup(tmp.cleanup)
        md = appendix_markdown(reg_of(row(1, ref="7.1", anchor="line 8", cites=("app/main.py:8",))), {},
                               root=target)
        cmds = block(md, "A.4 Verification commands")
        self.assertIn("- **E-1** (section 7), expect `app/main.py:8`\n\n```text\n"
                      "Select-String -LiteralPath 'app/main.py' -SimpleMatch -CaseSensitive -Pattern 'line 8'\n"
                      "grep -nF -- 'line 8' 'app/main.py'\n```", cmds)

    def test_a4_label_section_and_location(self):
        tmp, target = make_target()
        self.addCleanup(tmp.cleanup)
        md = appendix_markdown(reg_of(row(1, ref="10.1/V-1", anchor="line 8", cites=("app/main.py:8",))), {},
                               root=target)
        self.assertIn("- **E-1** (section 10), expect `app/main.py:8`", block(md, "A.4 Verification commands"))
        self.assertNotIn("expect line", md)

    def test_one_row_is_singular(self):
        md = appendix_markdown(reg_of(row(1)), {})
        self.assertIn("1 row: ", block(md, "A.2 Coverage"))

    def test_command_uses_located_path_not_first_cite(self):
        tmp, target = make_target()
        self.addCleanup(tmp.cleanup)
        os.makedirs(os.path.join(target, "other"))
        with open(os.path.join(target, "other", "b.py"), "w") as fh:
            fh.write("alpha\nbeta\ngamma\n")
        md = appendix_markdown(reg_of(row(1, anchor="beta", cites=("app/main.py:1", "other/b.py:2"))), {},
                               root=target)
        cmds = block(md, "A.4 Verification commands")
        self.assertIn("expect `other/b.py:2`", cmds)
        self.assertIn("-LiteralPath 'other/b.py'", cmds)

    def test_command_quoting_special_characters(self):
        tmp, target = make_target()
        self.addCleanup(tmp.cleanup)
        with open(os.path.join(target, "app", "main.py"), "w") as fh:
            fh.write("it's (a) $x \"q\" `b`\n")
        anchor = "it's (a) $x \"q\" `b`"
        md = appendix_markdown(reg_of(row(1, anchor=anchor, cites=("app/main.py:1",))), {}, root=target)
        self.assertIn(f"Select-String -LiteralPath 'app/main.py' -SimpleMatch -CaseSensitive -Pattern 'it''s (a) $x \"q\" `b`'", md)
        self.assertIn("grep -nF -- 'it'\\''s (a) $x \"q\" `b`' 'app/main.py'", md)

    def test_powershell_curly_quotes_are_doubled(self):
        tmp, target = make_target()
        self.addCleanup(tmp.cleanup)
        with open(os.path.join(target, "app", "main.py"), "w") as fh:
            fh.write("\u2018a\u2019\n")
        md = appendix_markdown(reg_of(row(1, anchor="\u2018a\u2019", cites=("app/main.py:1",))), {}, root=target)
        self.assertIn("-Pattern '\u2018\u2018a\u2019\u2019'", md)

    def test_rows_skipped(self):
        tmp, target = make_target()
        self.addCleanup(tmp.cleanup)
        rows = [row(1, anchor="line 1", cites=("app/main.py:1",)),
                row(2, "Downgraded", anchor="dg", cites=("app/main.py:1",)),
                row(3, anchor="", cites=("app/main.py:1",)),
                row(4, anchor="   ", cites=("app/main.py:1",)),
                row(5, cites=()),
                row(6, anchor="two\nlines", cites=("app/main.py:1",)),
                row(7, anchor="x" * 201, cites=("app/main.py:1",)),
                row(8, "Corrected", anchor="line 2", cites=("app/main.py:2",))]
        cmds = block(appendix_markdown(reg_of(*rows), {}, root=target), "A.4 Verification commands")
        shown = [l for l in cmds.splitlines() if l.startswith("- **")]
        self.assertEqual([l.split("**")[1] for l in shown], ["E-1", "E-8"])

    def test_no_root_no_commands(self):
        md = appendix_markdown(reg_of(row(1)), {})
        self.assertIn("No verification commands (no Target root).", block(md, "A.4 Verification commands"))

    def test_locate_finds_anchor_on_correct_line(self):
        tmp, target = make_target()
        self.addCleanup(tmp.cleanup)
        self.assertEqual(locate(target, row(1, anchor="line 6", cites=("app/main.py:6",))), ("app/main.py", 6))
        self.assertIsNone(locate(target, row(1, anchor="line 99", cites=("app/main.py:6",))))
        self.assertIsNone(locate(target, row(1, anchor="line 6", cites=("app/nope.py:6",))))

    def test_deterministic(self):
        reg = reg_of(row(1), row(2, "Corrected"))
        self.assertEqual(appendix_markdown(reg, {}), appendix_markdown(reg, {}))
        self.assertNotRegex(appendix_markdown(reg, {}), r"\d{4}-\d{2}-\d{2}")

    def test_two_row_register_sample(self):
        tmp, target = make_target()
        self.addCleanup(tmp.cleanup)
        reg = reg_of(row(1, ref="10.1/V-1", claim="A password is set", cites=("app/main.py:6",), anchor="line 6"),
                     row(2, "Corrected", ref="7.1", claim="Operators launch it", cites=("app/main.py:2",),
                         anchor="line 2", limitation="behaviour at runtime not observed"))
        self.assertEqual(appendix_markdown(reg, {}, coverage=[("10.1", 1, 1)], root=target), "\n".join([
            "### A.1 Audit state", "",
            "**Auditor:** independent. **Scope:** sections 3-10", "",
            "### A.2 Coverage", "",
            "2 rows: 1 Supported, 1 Corrected, 0 Downgraded. "
            "Each Supported or Corrected row's anchor text was found in its cited lines by the Check.", "",
            "| Section | IDs with a register row |", "|---|---|", "| 10.1 | 1 of 1 |", "",
            "### A.3 Register", "",
            "| ID | Ref | Claim | Result | Cites | Limitation |", "|---|---|---|---|---|---|",
            "| E-1 | 10.1/V-1 | A password is set | Supported | `app/main.py:6` | none |",
            "| E-2 | 7.1 | Operators launch it | Corrected | `app/main.py:2` | behaviour at runtime not observed |", "",
            "### A.4 Verification commands", "",
            "Run from the Target root. Each block names the expected line, then a PowerShell command and a POSIX command.",
            "",
            "- **E-1** (section 10), expect `app/main.py:6`", "", "```text",
            "Select-String -LiteralPath 'app/main.py' -SimpleMatch -CaseSensitive -Pattern 'line 6'",
            "grep -nF -- 'line 6' 'app/main.py'", "```", "",
            "- **E-2** (section 7), expect `app/main.py:2`", "", "```text",
            "Select-String -LiteralPath 'app/main.py' -SimpleMatch -CaseSensitive -Pattern 'line 2'",
            "grep -nF -- 'line 2' 'app/main.py'", "```"]))


class BlocksProvenanceTests(unittest.TestCase):
    BY = {"generator": "2.6.0", "bundle": "7c1e5a9b03d2"}

    def a1(self, audit=AUDIT, blocks_by=BY):
        md = appendix_markdown(reg_of(row(1), audit=audit), {}, blocks_by=blocks_by)
        return block(md, "A.1 Audit state")

    def test_a1_blocks_provenance_line(self):
        self.assertIn("Generated blocks written by AppDoc 2.6.0 (bundle 7c1e5a9b03d2).", self.a1())
        self.assertNotIn("regenerated after the audit", self.a1())

    def test_a1_line_absent_without_blocks_by(self):
        self.assertNotIn("Generated blocks", self.a1(blocks_by=None))

    def test_a1_regenerated_after_audit_line(self):
        line = "Generated blocks were regenerated after the audit and are not covered by it."
        self.assertIn(line, self.a1({**AUDIT, "audited_with": "2.5.0"}))
        self.assertIn(line, self.a1({**AUDIT, "audited_with": "2.5"}))
        self.assertNotIn(line, self.a1({**AUDIT, "audited_with": "2.6.3"}))   # same major.minor
        self.assertNotIn(line, self.a1({**AUDIT, "audited_with": "2.6.0.dev0"}))
        self.assertNotIn(line, self.a1())                                      # audited_with is optional

    def test_a1_line_when_audit_not_performed(self):
        md = appendix_markdown(reg_of(audit={"type": "audit", "performed": False, "scope": "x"}), {},
                               blocks_by=self.BY)
        self.assertIn("Generated blocks written by AppDoc 2.6.0", md)

    def test_fill_writes_the_line_and_blocks_by(self):
        from appdoc import fill, version
        tmp, target = make_target()
        self.addCleanup(tmp.cleanup)
        out = os.path.join(target, "docs", "appdoc")
        os.makedirs(out)
        with open(os.path.join(out, "facts.json"), "w") as fh:
            json.dump({"schema": facts.SCHEMA, "facts": [], "stacks": [], "target": {}}, fh)
        with open(os.path.join(out, "evidence.jsonl"), "w") as fh:
            fh.write(json.dumps({**AUDIT, "audited_with": "1.0.0"}) + "\n")
        with open(os.path.join(out, "application-documentation.md"), "w") as fh:
            fh.write("<!-- appdoc:generated appendix-a -->\n<!-- /appdoc:generated appendix-a -->\n")
        with open(os.path.join(out, "provenance.json"), "w") as fh:
            json.dump(version.provenance(), fh)
        import contextlib, io
        with contextlib.redirect_stdout(io.StringIO()):
            self.assertEqual(fill.run(target, out), 0)
        with open(os.path.join(out, "application-documentation.md"), encoding="utf-8") as fh:
            md = fh.read()
        p = version.provenance()
        self.assertIn(f"Generated blocks written by AppDoc {p['generator']} (bundle {p['bundle']}).", md)
        self.assertIn("were regenerated after the audit", md)
        with open(os.path.join(out, "provenance.json"), encoding="utf-8") as fh:
            prov = json.load(fh)
        self.assertEqual(prov["blocks_by"], {"generator": p["generator"], "bundle": p["bundle"]})
        self.assertEqual(prov["generator"], p["generator"])  # extract's keys are kept


class SealTests(unittest.TestCase):
    def _write(self, text):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = os.path.join(self.tmp.name, "evidence.jsonl")
        with open(self.path, "w", encoding="utf-8", newline="") as fh:
            fh.write(text)
        return self.path

    def _read(self):
        with open(self.path, encoding="utf-8", newline="") as fh:
            return fh.read()

    def test_seal_writes_missing_and_never_overwrites(self):
        self._write("\n".join([
            json.dumps(AUDIT),
            json.dumps(row(1)),
            json.dumps({**row(2), "claim_sha": "deadbeef0000"}),
        ]) + "\n")
        n = register.seal(self.path, {"E-1": "abcdef123456", "E-2": "111111111111"})
        self.assertEqual(n, 1)
        objs = [json.loads(l) for l in self._read().splitlines() if l.strip()]
        self.assertEqual(objs[1]["claim_sha"], "abcdef123456")
        self.assertEqual(objs[2]["claim_sha"], "deadbeef0000")  # not overwritten

    def test_seal_preserves_key_order_and_crlf(self):
        self._write("\r\n".join([json.dumps(AUDIT), json.dumps(row(1))]) + "\r\n")
        register.seal(self.path, {"E-1": "abcdef123456"})
        raw = self._read()
        self.assertIn("\r\n", raw)
        obj = json.loads(raw.splitlines()[1])
        self.assertEqual(list(obj.keys()), ["id", "ref", "claim", "result", "cites", "anchor", "limitation", "claim_sha"])

    def test_seal_idempotent(self):
        self._write("\n".join([json.dumps(AUDIT), json.dumps(row(1))]) + "\n")
        register.seal(self.path, {"E-1": "abcdef123456"})
        self.assertEqual(register.seal(self.path, {"E-1": "abcdef123456"}), 0)

    def test_parse_rejects_bad_claim_sha(self):
        reg = parse("\n".join([json.dumps(AUDIT), json.dumps({**row(1), "claim_sha": "XYZ"})]))
        self.assertTrue(any("claim_sha" in e[1] for e in reg.errors))


class SupersedesTests(unittest.TestCase):
    def test_supersedes_parsed(self):
        reg = reg_of(row(1), {**row(2), "supersedes": "E-1"}, {**row(3), "supersedes": ["E-1", "E-2"], "sealed_by": "audit"},
                     {**row(4), "sealed_by": "upgrade"})
        self.assertEqual(reg.errors, [])
        self.assertEqual(register.OPTIONAL_KEYS, ("claim_sha", "supersedes", "sealed_by"))
        self.assertEqual(reg.supersedes_of(reg.rows[1][1]), ["E-1"])
        self.assertEqual(reg.supersedes_of(reg.rows[2][1]), ["E-1", "E-2"])
        self.assertEqual(reg.supersedes_of(reg.rows[0][1]), [])
        self.assertEqual({r["id"] for _, r in reg.live_rows()}, {"E-3", "E-4"})
        self.assertEqual(reg.superseded_by("E-1"), "E-2")   # the first (lowest) superseding row

    def test_supersedes_rejects_bad_shapes(self):
        for bad in ("E-x", 3, ["E-1", 2], [], ""):
            reg = reg_of(row(1), {**row(2), "supersedes": bad})
            self.assertTrue(any("supersedes" in e[1] for e in reg.errors), bad)
        reg = reg_of({**row(1), "sealed_by": "me"})
        self.assertTrue(any("sealed_by" in e[1] for e in reg.errors))


if __name__ == "__main__":
    unittest.main()
