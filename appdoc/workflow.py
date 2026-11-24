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
         "step 0: if the document exists and its stamp is older than the running template, run this before `check`; "
         "it adds what the template now requires, keeps every line of text, extracts and fills, and writes "
         "UPGRADE-TODO.md for the steps left to a person"),
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


# The writing rules and checklists of remediation plan 2.8, 8.3, as data: ``tools/gen_docs.py`` writes them into SKILL.md
# (block `skill-rules`), so the guidance cannot drift from the tests that pin it (`test_skill_guidance`). Each entry is
# (heading, items); an item is one paragraph of Markdown.
SKILL_RULES = (
    ("Orient", (
        "Before writing template sections 3, 5, 8 and 10, read the `access-model` (5.4), `connections` (8.1) and "
        "`integrations` (8.3) blocks of the filled document, or the same Facts in `facts-summary.md` if the blocks are "
        "not filled yet. They are opaque and unaudited: they tell you where to look, and the prose you write about "
        "access, connections and integrations is yours to verify against the source.",
    )),
    ("Writing rules", (
        "Never list a configuration file as not reviewed. Read it, redact the values and cite what it shows (R16); a "
        "file that holds a security setting, access rule, external-config reference or secret-bearing application key "
        "must be cited with a line outside the generated blocks (C21).",
        "Write \"Unknown\" only after you have checked the Facts summary for the answer.",
        "Every `state_changing` handler whose reach label is `no_app_restriction`, `signed_in_any` or `unknown` is a "
        "10.1 finding or a dismissed finding candidate; the handler file must be cited (C22).",
        "State behaviour that differs per build configuration for each configuration (the production configuration "
        "first); never describe one configuration's value as the Target's.",
        "Say \"application layer only\" wherever you describe who can reach something: the repository does not show IIS "
        "authentication, server settings, network exposure or group membership.",
        "Do not write \"anonymous users can\" unless the handler's `reasons` include explicit anonymity; an open "
        "application layer is `no_app_restriction`, not proof that anonymous callers get in.",
    )),
    ("Large Targets", (
        "On a Target with MVC areas, give each area its own subsystem (one subsystem per area): a row in 4.1 whose "
        "Subsystem cell cites the area folder (C22), and its own part of sections 4 to 8.",
    )),
    ("Audit checklist", (
        "Trace every Troubleshooting row and every fallback claim to its end: follow null guards and factories that "
        "never return null before accepting that a fallback or a message can happen.",
        "Check each generated block that says \"none\" against the reader the block names (the Stacks that report "
        "protection, the detector accountability line): \"none\" from a Stack that does not report is not an absence.",
    )),
)


def run_commands() -> list[tuple[str, str, str]]:
    """(step name, full command line, note) for every step that runs a command, in order."""
    return [(s.name, f"{LAUNCHER} {s.command}", s.note) for s in SKILL_STEPS if s.command]
