"""The template contract: the one description of application-documentation.md that the Check reads.

`assets/template.md` must agree with this module (a test enforces it). Change both together and
bump TEMPLATE_VERSION when a committed 2.x document would no longer pass.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

TEMPLATE_VERSION = "2.4"
STAMP = f"<!-- appdoc:template {TEMPLATE_VERSION} -->"


def version_tuple(s) -> tuple:
    """The leading numeric components of a dotted version: "2.10.1" -> (2, 10, 1); "2.6.0.dev0" -> (2, 6, 0).

    The only way versions are compared (a string compare puts 2.10 before 2.9). Anything that is not
    dotted numeric, including None, gives ().
    """
    out = []
    for part in str(s or "").strip().split("."):
        if not part.isdigit():
            break
        out.append(int(part))
    return tuple(out)


# A hand-written count the tool fills: <!-- appdoc:count V -->14<!-- /appdoc:count -->. The text between the
# two comments is the filled number; doc_sha masks the whole marker so fill never changes the fingerprint.
# Groups: 1 the opening comment, 2 the class, 3 the number, 4 the closing comment.
COUNT_MARKER_RE = re.compile(r"(<!--\s*appdoc:count\s+([^>]*?)\s*-->)([^<]*)(<!--\s*/appdoc:count\s*-->)")

# The closed list of count-marker classes, each with where the number comes from: "id" (the defined IDs of that
# prefix), "register" (rows of the Evidence Register) or "facts" (Facts, through fill.entry_point_counts and the
# config reference). The one place to extend it (template 2.8 adds more classes without changing the syntax).
COUNT_CLASSES = {
    **{c: "id" for c in ("V", "F", "UI", "C", "X", "Q", "R")},
    "rows": "register", "superseded": "register",
    **{c: "facts" for c in ("routes", "jobs", "pages", "commands", "config-keys")},
}

STAMP_RE = re.compile(r"<!--\s*appdoc:template\s+([\w.]+)\s*-->")
GUIDE_RE = re.compile(r"<!--\s*appdoc:guide\b")
UPGRADE_NOTES = ("CHANGELOG.md, 2.4.0 upgrade notes. 2.3 -> 2.4: per-claim C2 (security citations need a line); "
                 "binary-file rule in C1; claim_sha sealing in C11 (run `appdoc build`); `appdoc build` and "
                 "`appdoc seal` commands; render guard; evidence-based config role; retired candidates; "
                 "version-skew detection; re-run `extract` for facts schema appdoc-facts/5")

# The fixed line under the 5.3 table. Template text, not guidance: C9 fails when 5.3 lacks it.
RESTRICTION_LINE = ("**Restriction:** do not infer a permission from a visible control or a granted scope; "
                    "enforcement is the code cited in 5.2.")

# Optional hand table under the generated 16.6 block (a free table: the Table machinery checks only the first).
CONFIG_EFFECT_COLUMNS = ("Key", "Effect", "Evidence")

STATUS = ("Cited", "Inferred", "Unknown")
SEVERITY = ("Critical", "High", "Medium", "Low")
SEVERITY_ORDER = SEVERITY  # most severe first; a 10.1 or 15 row may not outrank the row above it
PRIORITY = ("High", "Medium", "Low")
EFFORT = ("S", "M", "L")
CONTROL_STATUS = ("Verified absent", "Not established", "Present")
CONTROL_STATUS_PRESENT = "Present"
RUNBOOK_STEPS = ("Build", "Test", "Deploy", "Upgrade", "Rollback", "Backup", "Restore", "Secret rotation")
OWNERSHIP_ROWS = ("Business owner", "Technical owner", "Process owner", "Data and integration owners",
                  "Documentation owner", "Release and change process")

SECTIONS = (
    "Application Index", "Coverage and Overview", "Architecture", "Functional Inventory",
    "Roles and Access Model", "UI Catalog", "Workflows", "Data and Integrations",
    "Troubleshooting Matrix", "Security and Operational Risks", "Ownership and Maintenance",
    "Architecture and Data-Flow Diagrams", "Glossary", "Open Questions and Documentation Gaps",
    "Recommendations", "Operations Runbook",
)

REQUIRED_SUBSECTIONS = {
    "4.1": "Subsystem inventory",
    "5.1": "Observed role concepts", "5.2": "Authorization enforcement", "5.3": "Role-to-capability matrix",
    "8.1": "Connections", "8.2": "Stored procedures and SQL", "8.3": "External calls",
    "8.4": "Data entities and sensitivity", "8.5": "Failure, fallback and observability",
    "10.1": "Verified findings", "10.2": "Unknowns that must not be treated as controls",
    "15.1": "Coverage summary",
    "16.1": "Platform requirements", "16.2": "Data stores", "16.3": "Session and authentication behavior",
    "16.4": "Known failure modes and operator responses", "16.5": "Deployment and change process",
    "16.6": "Configuration reference", "16.7": "Scheduled and background jobs",
}


@dataclass(frozen=True)
class Table:
    """The first table under a heading. Later tables in the same place are checked for shape only."""

    columns: tuple[str, ...]
    id_prefix: str | None = None                 # the ID column holds `<prefix><n>`, unique in the table
    values: dict = field(default_factory=dict)   # column -> allowed values
    required_rows: tuple[str, ...] = ()          # first-column labels that must be present
    keyed_by: tuple[str, ...] = ()               # ID column holds IDs defined elsewhere with these prefixes
    open_columns: bool = False                   # `columns` are the leading columns; more may follow (free names)

    def header_ok(self, header: list[str]) -> bool:
        got = [h.casefold() for h in header]
        want = [c.casefold() for c in self.columns]
        return got[:len(want)] == want if self.open_columns else got == want

    def row_fits(self, n_cells: int) -> bool:
        return n_cells >= len(self.columns) if self.open_columns else n_cells == len(self.columns)


TABLES = {
    "1": Table(("Support need", "Primary screen or file", "Workflow")),
    "4": Table(("ID", "Area", "Feature", "Entry point", "Inputs, outputs and rules", "Dependencies", "Status"),
               "F-", {"Status": STATUS}),
    "4.1": Table(("Subsystem", "Files", "Features", "Primary data and dependencies", "Purpose", "Status"),
                 values={"Status": STATUS}),
    "5.3": Table(("Capability",), open_columns=True),
    "6": Table(("ID", "Page", "Route or entry", "Reached from", "Visible controls and data",
                "States and effects", "Roles and evidence"), "UI-"),
    "8.1": Table(("ID", "Name", "Kind", "Configured at", "Used by"), "C-"),
    "8.3": Table(("ID", "Call", "Direction", "Caller", "Notes"), "X-"),
    "8.4": Table(("Entity", "Key fields", "Defined at", "Sensitivity")),
    "8.5": Table(("ID", "Timeout and retry", "On failure", "Observability"), keyed_by=("C-", "X-")),
    "9": Table(("Symptom", "Checks", "Known response", "Escalate when")),
    "10.1": Table(("ID", "Severity", "Finding", "Evidence", "Impact"), "V-", {"Severity": SEVERITY}),
    "10.2": Table(("Control", "Status", "Where looked"), values={"Status": CONTROL_STATUS}),
    "11": Table(("Area", "Evidence", "Status"), values={"Status": STATUS}, required_rows=OWNERSHIP_ROWS),
    "13": Table(("Term", "Meaning", "Citation")),
    "14": Table(("ID", "Question", "Why it matters", "How to close", "Owner", "Priority"), "Q-",
                {"Priority": PRIORITY}),
    "15": Table(("ID", "Severity", "Effort", "Recommendation", "Addresses"), "R-",
                {"Severity": SEVERITY, "Effort": EFFORT}),
    "16.4": Table(("Failure mode", "Signal", "Operator response")),
    "16.5": Table(("Step", "Procedure", "Evidence"), required_rows=RUNBOOK_STEPS),
    "16.6": Table(("Key", "Defined at", "Secret location")),
}

# Generated blocks: `appdoc fill` writes them from facts.json; the Check fails if they differ.
# The key is the section it sits in; "appendix" is the unnumbered Appendix A heading.
GENERATED = {"2.1": "scan-coverage", "4": "entry-points", "14": "closed-questions", "16.6": "config-reference",
             "16.7": "scheduled-jobs", "appendix": "appendix-a"}
# A block a template added after 2.4: name -> the first template version that carries it. An older document is
# not asked for it.
GENERATED_SINCE = {"closed-questions": (2, 7)}


def generated_blocks(version: tuple) -> dict:
    """The GENERATED blocks a document of this template version (a `version_tuple`) must carry."""
    return {key: name for key, name in GENERATED.items() if version >= GENERATED_SINCE.get(name, ())}


# Generated blocks the Check does not read as Narrative: their tables, IDs and Citations are not the
# writer's (a Citation inside one does not count as the document citing that file).
OPAQUE_BLOCKS = ("entry-points", "scheduled-jobs", "closed-questions", "appendix-a")

ID_PREFIXES = tuple(t.id_prefix for t in TABLES.values() if t.id_prefix)
REGISTER_PREFIX = "E-"
