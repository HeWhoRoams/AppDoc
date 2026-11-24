"""The template contract: the one description of application-documentation.md that the Check reads.

`assets/template.md` must agree with this module (a test enforces it). Change both together and
bump TEMPLATE_VERSION when a committed 2.x document would no longer pass.
"""

from __future__ import annotations

import re
from dataclasses import dataclass, field

TEMPLATE_VERSION = "2.7"
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


def stamp_version(text: str) -> tuple:
    """The `version_tuple` of the `appdoc:template` stamp in a Narrative; () when there is none."""
    m = STAMP_RE.search(text)
    return version_tuple(m.group(1) if m else "")


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
UPGRADE_NOTES = ("run `appdoc upgrade <target>` for the mechanical steps (it writes docs/appdoc/UPGRADE-TODO.md for the rest), or see CHANGELOG.md, 2.7.0 upgrade notes (and the 2.4.0 notes for a document older than 2.4). 2.4 -> 2.7: change the stamp to 2.7, add the "
                 "`closed-questions` markers under section 14 and section 17, replace hand-written counts with count "
                 "markers, move extractor limitations to `notes.jsonl`, shorten the audit `scope` to the method, "
                 "run `appdoc build --expand-citations`, then `appdoc audit-plan`, the audit, `appdoc seal --audit "
                 "--date` and `appdoc build`; re-run `extract` for facts schema appdoc-facts/7")

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
BUILD_STEPS = ("Prerequisites", "Restore dependencies", "Build", "Run", "Test")   # section 17, in order
UNKNOWN_TEXT = "Unknown - see Open questions."   # what a cell says when the repository does not show it
BUILD_UNKNOWN = UNKNOWN_TEXT   # the 17 Command cell values that are not a command
BUILD_NOT_APPLICABLE = "Not applicable"
OWNERSHIP_ROWS = ("Business owner", "Technical owner", "Process owner", "Data and integration owners",
                  "Documentation owner", "Release and change process")

SECTIONS = (
    "Application Index", "Coverage and Overview", "Architecture", "Functional Inventory",
    "Roles and Access Model", "UI Catalog", "Workflows", "Data and Integrations",
    "Troubleshooting Matrix", "Security and Operational Risks", "Ownership and Maintenance",
    "Architecture and Data-Flow Diagrams", "Glossary", "Open Questions and Documentation Gaps",
    "Recommendations", "Operations Runbook", "Build, Run and Test Locally",
)
# A section a template added after 2.4: its number -> the first template version that carries it. An older
# document is not asked for it.
SECTIONS_SINCE = {17: (2, 7)}


def sections(version: tuple) -> tuple:
    """The section titles a document of this template version (a `version_tuple`) must carry, in order."""
    return tuple(t for n, t in enumerate(SECTIONS, 1) if version >= SECTIONS_SINCE.get(n, ()))

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
    nouns: tuple[str, ...] = ()                  # singular words a C15 "N of M <noun>" sentence uses for this class
    sampled: bool = False                        # the audit plan samples this table's IDs (else it covers them all)
    cell_defaults: dict = field(default_factory=dict)   # column -> the cell an upgrade writes in a required row

    def unknown_cell(self, column: str) -> str:
        """What a required row says in `column` when the repository does not show it: the column's own default
        (e.g. "." for a working directory), "Unknown" where that is an allowed value, else UNKNOWN_TEXT."""
        if column in self.cell_defaults:
            return self.cell_defaults[column]
        return "Unknown" if "Unknown" in self.values.get(column, ()) else UNKNOWN_TEXT

    def header_ok(self, header: list[str]) -> bool:
        got = [h.casefold() for h in header]
        want = [c.casefold() for c in self.columns]
        return got[:len(want)] == want if self.open_columns else got == want

    def row_fits(self, n_cells: int) -> bool:
        return n_cells >= len(self.columns) if self.open_columns else n_cells == len(self.columns)


TABLES = {
    "1": Table(("Support need", "Primary screen or file", "Workflow")),
    "4": Table(("ID", "Area", "Feature", "Entry point", "Inputs, outputs and rules", "Dependencies", "Status"),
               "F-", {"Status": STATUS}, sampled=True),
    "4.1": Table(("Subsystem", "Files", "Features", "Primary data and dependencies", "Purpose", "Status"),
                 values={"Status": STATUS}),
    "5.3": Table(("Capability",), open_columns=True),
    "6": Table(("ID", "Page", "Route or entry", "Reached from", "Visible controls and data",
                "States and effects", "Roles and evidence"), "UI-", sampled=True),
    "8.1": Table(("ID", "Name", "Kind", "Configured at", "Used by"), "C-", sampled=True),
    "8.3": Table(("ID", "Call", "Direction", "Caller", "Notes"), "X-", sampled=True),
    "8.4": Table(("Entity", "Key fields", "Defined at", "Sensitivity")),
    "8.5": Table(("ID", "Timeout and retry", "On failure", "Observability"), keyed_by=("C-", "X-")),
    "9": Table(("Symptom", "Checks", "Known response", "Escalate when")),
    "10.1": Table(("ID", "Severity", "Finding", "Evidence", "Impact"), "V-", {"Severity": SEVERITY}, nouns=("finding", "v-finding")),
    "10.2": Table(("Control", "Status", "Where looked"), values={"Status": CONTROL_STATUS}),
    "11": Table(("Area", "Evidence", "Status"), values={"Status": STATUS}, required_rows=OWNERSHIP_ROWS),
    "13": Table(("Term", "Meaning", "Citation")),
    "14": Table(("ID", "Question", "Why it matters", "How to close", "Owner", "Priority"), "Q-",
                {"Priority": PRIORITY}, nouns=("unknown",)),
    "15": Table(("ID", "Severity", "Effort", "Recommendation", "Addresses"), "R-",
                {"Severity": SEVERITY, "Effort": EFFORT}, nouns=("recommendation",), sampled=True),
    "16.4": Table(("Failure mode", "Signal", "Operator response")),
    "16.5": Table(("Step", "Procedure", "Evidence"), required_rows=RUNBOOK_STEPS),
    "16.6": Table(("Key", "Defined at", "Secret location")),
    "17": Table(("Step", "Command", "Working directory", "Evidence"), required_rows=BUILD_STEPS,
                cell_defaults={"Working directory": "."}),
}
TABLES_SINCE = {"17": (2, 7)}   # a table of a section a later template added (see SECTIONS_SINCE)

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

# The tables whose rows have no IDs but are sampled by the audit plan (the symptom names the row).
ROW_SAMPLED = ("9",)


@dataclass(frozen=True)
class IdClass:
    """One class of defined IDs: its prefix, the section whose table defines it, the nouns C15 reads in prose, and
    whether the audit plan samples it."""

    prefix: str
    section: str
    nouns: tuple[str, ...]
    sampled: bool


def id_classes(tables: dict) -> dict:
    """prefix -> IdClass, in table order, derived from the `id_prefix` of `tables` (the one ID-class table)."""
    return {t.id_prefix: IdClass(t.id_prefix, key, t.nouns, t.sampled) for key, t in tables.items() if t.id_prefix}


ID_CLASSES = id_classes(TABLES)
ID_PREFIXES = tuple(ID_CLASSES)


def id_prefix_of(section: str):
    """The ID prefix of the table under `section` ("10.1" -> "V-"), or None."""
    return next((c.prefix for c in ID_CLASSES.values() if c.section == section), None)
REGISTER_PREFIX = "E-"


# --- helpers over TABLES for `appdoc upgrade` (it reads the tables only through these) ---------------------------

def table_columns(key: str) -> tuple:
    """The column names of the table under `key`."""
    return TABLES[key].columns


def table_header_ok(key: str, header: list[str]) -> bool:
    """Whether `header` (cell texts) is the header of the table under `key`."""
    return TABLES[key].header_ok(header)


def table_id_prefix(key: str) -> str:
    """The ID prefix of the table under `key`; "" when it has no ID column."""
    return TABLES[key].id_prefix or ""


def required_rows(key: str) -> tuple:
    """The first-column labels the table under `key` must carry; () when none."""
    t = TABLES.get(key)
    return t.required_rows if t else ()


def unknown_row(key: str, label: str) -> str:
    """A required row for table `key` that says the repository does not show it (UNKNOWN_TEXT, or the column's own
    default: see `Table.cell_defaults`)."""
    t = TABLES[key]
    return "| " + " | ".join([label] + [t.unknown_cell(c) for c in t.columns[1:]]) + " |"


# --- `appdoc upgrade`: the steps that bring a document of an older template to the running one -------------------
#
# UPGRADE_STEPS[version] is the list of operations that take a document from the template before `version` to
# `version`, applied in version order. Only the template versions that changed what a document holds have an
# entry (AppDoc 2.5 and 2.6 kept template 2.4). Each operation is a tuple, from this closed vocabulary (appdoc/
# upgrade.py applies it; every operation adds or renames and never removes text):
#   ("section", n)                    add `## n. Title` with its guide comment and skeleton table, from the template
#   ("subsection", ref)               add `### ref Title` likewise
#   ("appendix",)                     add the Appendix A heading
#   ("block", name)                   add the marker pair of the generated block `name` at its position (BLOCK_AT)
#   ("reshape", key)                  the first table under heading `key` must match TABLES[key]; when it does not,
#                                     add the template's skeleton and leave the old text under an
#                                     `appdoc:upgrade-orphan` comment (C3 fails until it is moved and deleted)
#   ("rows", key)                     add the required rows of TABLES[key] that are missing, as Unknown skeletons
#   ("rename", key, old, new)         rename a header cell of the first table under `key`
#   ("column", key, name, after, fill)  insert column `name` after column `after` (None = first), its cells `fill`:
#                                     "ids" (sequential IDs of the table's prefix) or "unknown" (UNKNOWN_TEXT)
#   ("line", key, text)               add a fixed line after the first table under `key`
#   ("stamp",)                        write this step's version as the template stamp (always the last operation)
ORPHAN_MARK = "appdoc:upgrade-orphan"   # the comment `appdoc upgrade` leaves above text it could not map; C3 fails on it
ORPHAN_RE = re.compile(r"<!--\s*" + re.escape(ORPHAN_MARK) + r"\b.*?-->", re.S)
UPGRADE_FROM = "2.0"   # a document with no stamp and without the 2.1 subsections
SUBSECTIONS_2_1 = ("4.1", "5.1", "5.2", "5.3", "8.4", "8.5", "10.1", "10.2", "15.1",
                   "16.1", "16.2", "16.3", "16.4", "16.5")   # a document with no stamp that has them is a 2.1 document

# Where a block sits under its heading: "top" right after the heading's guide comment, "end" after the last
# content of the heading's own body. The key is GENERATED's (the section the block lives in).
BLOCK_AT = {"closed-questions": "end"}   # every other block is "top"

UPGRADE_STEPS = {
    "2.1": (
        *(("subsection", k) for k in SUBSECTIONS_2_1 + ("8.1", "8.2", "8.3")),
        *(("reshape", k) for k in ("1", "4", "4.1", "5.3", "6", "8.1", "8.3", "8.4", "9", "11", "13", "15", "16.4")),
        ("stamp",),
    ),
    "2.2": (
        ("subsection", "16.6"),
        ("block", "scan-coverage"), ("block", "config-reference"),
        ("column", "4", "Area", "ID", "unknown"),
        ("column", "4.1", "Features", "Files", "unknown"),
        ("rename", "6", "Route", "Route or entry"),
        ("column", "6", "Reached from", "Route or entry", "unknown"),
        ("column", "6", "ID", None, "ids"),
        ("column", "8.1", "ID", None, "ids"),
        *(("reshape", k) for k in ("1", "8.5", "10.1", "10.2", "14", "16.5")),
        ("rows", "16.5"),
        ("stamp",),
    ),
    "2.3": (
        ("subsection", "16.7"), ("appendix",),
        ("block", "entry-points"), ("block", "scheduled-jobs"), ("block", "appendix-a"),
        ("rename", "5.3", "Area", "Capability"),
        ("line", "5.3", RESTRICTION_LINE),
        ("reshape", "11"), ("rows", "11"),
        ("stamp",),
    ),
    "2.4": (("stamp",),),   # the tool changed (claim_sha, build, Facts schema 5); no heading, marker or header did
    "2.7": (
        ("block", "closed-questions"),
        ("section", "17"),
        ("stamp",),
    ),
}
