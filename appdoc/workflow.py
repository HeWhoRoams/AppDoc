"""The steps the AppDoc skill runs, as data (remediation plan 2.6, 6.3).

``SKILL_STEPS`` is the one description of the Run order. ``tools/gen_docs.py`` writes the command lines
into SKILL.md (block `run-commands`), so the commands there cannot drift from the CLI. A step without a
``command`` is work the AI does between commands.
"""

from __future__ import annotations

from dataclasses import dataclass

LAUNCHER = "python SKILL_DIR/run_appdoc.py"


@dataclass(frozen=True)
class Step:
    name: str
    command: str | None   # arguments after the launcher, e.g. "extract <target>"; None for AI work
    note: str


SKILL_STEPS = (
    Step("Upgrade", "upgrade <target>",
         "only when the existing document carries an older template stamp: adds what the template now requires, "
         "keeps every line of text, extracts and fills, and writes UPGRADE-TODO.md for the steps left to a person"),
    Step("Extract", "extract <target>",
         "writes facts.json, facts-summary.md and provenance.json; re-running gives identical output"),
    Step("Orient", None, "read facts-summary.md and appdoc-context.md, then drill into the Facts and the source"),
    Step("Write", None, "fill the template from the Facts and the source"),
    Step("Build", "build <target>",
         "seal, fill, check and render; repeat until it passes, and after 3 failures report the problems verbatim"),
    Step("Fix advisories", "check <target> --strict",
         "fix every advisory before the audit plan: the plan's sample is seeded by doc_sha, so a later Narrative "
         "edit reshuffles it"),
    Step("Audit plan", "audit-plan <target>",
         "writes audit-plan.json: the IDs and per-row keys (<section>/<slug>) the audit must cover, a sample chosen by the tool"),
    Step("Audit", None,
         "a fresh agent audits every planned ID and per-row key (more if useful) and writes evidence.jsonl; for every 10.1 finding "
         "it audits, it also checks that the cited finding-candidate id and line range support the claim; only the "
         "opaque generated blocks are not audited"),
    Step("Seal", "seal <target> --audit --date <YYYY-MM-DD>",
         "records the audit date and provenance and seals the new rows as audited; the date is given, never read "
         "from the clock"),
    Step("Build", "build <target> --require-audit", "the same command, now that the audit exists"),
    Step("Report", None, "tell the user where the files are, whether the Check passed, and who audited"),
)


def run_commands() -> list[tuple[str, str, str]]:
    """(step name, full command line, note) for every step that runs a command, in order."""
    return [(s.name, f"{LAUNCHER} {s.command}", s.note) for s in SKILL_STEPS if s.command]
