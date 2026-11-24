"""The Check: pass/fail verification of a finished Narrative. No score, no warnings.

The module docstring is assigned below, after RULES, so the rule range it names is the constant.
"""

from __future__ import annotations

import json
import os
import re
import sys
from typing import NamedTuple

from . import __version__, version
from . import context
from . import docmodel as dm
from . import fill as fill_mod
from . import fingerprint
from . import notes as notes_mod
from . import register as reg_mod
from . import scan
from . import template_spec as spec
from .citations import KNOWN_BARE_FILES, OWNER_CONTEXT, Citation, find_citations, parse_span
from .facts import fact_id
from .secrets import find_secret_shapes
from .textnorm import normalize_newlines
from .textutil import plural, read_text

NARRATIVE = "application-documentation.md"
FACTS = "facts.json"
REPORT = "check-report.md"
REGISTER = reg_mod.REGISTER


SECTIONS = list(spec.sections(spec.version_tuple(spec.TEMPLATE_VERSION)))   # the running template's sections
REQUIRED_SUBSECTIONS = spec.REQUIRED_SUBSECTIONS


class Rule(NamedTuple):
    """One Check rule. ``flags``: "advisory" and/or "strict" (see tools/gen_docs.py). ``preview`` is the
    text of a 2.7 rule that is only an advisory on an older template ("" when there is none)."""
    id: str
    title: str
    summary: str   # one sentence: what makes it fail; tools/gen_docs.py writes it into the README
    flags: tuple = ()
    preview: str = ""


# The one rule registry (R5). Everything else about rules is derived from it below.
RULES = (
    Rule("C1", "Citations resolve",
         "a Citation points to a missing file or a line past the end (folders and unique bare filenames resolve; "
         "extensionless non-existent spans are not Citations)",
         preview="a bare file name (in the Narrative, a register row or a note) that resolves to a file in a folder: "
                 "cite the full path"),
    Rule("C2", "Security lines", "a Citation in section 10 has no line"),
    Rule("C3", "Sections complete",
         "a section is missing, out of order, empty or a placeholder, the stamp is not the running template, or an "
         "`appdoc:upgrade-orphan` comment from `appdoc upgrade` is left"),
    Rule("C4", "Gaps declared",
         "section 14 is empty while Unknowns exist, or Data and Integrations is empty though Facts exist"),
    Rule("C5", "Claims grounded",
         "a paragraph, list item or table row in sections 3 to 10 is neither cited, Inferred nor Unknown"),
    Rule("C6", "No secrets", "secret-shaped text, or a `never-mention` term, appears in a published file"),
    Rule("C7", "Coverage honest",
         "an unsupported Stack is not named in section 2; a count or a generated block differs from the Facts; "
         "facts.json was written by another major.minor of AppDoc", ("strict",)),
    Rule("C8", "Structure complete", "a required numbered subsection is missing, outside its section or empty"),
    Rule("C9", "Tables conform",
         "a table differs from the template (header, cell count, ID prefix, allowed value, required row), "
         "the 5.3 Restriction line is missing, a section 17 (2.7) Command cell is not a backticked command, Unknown or "
         "Not applicable or lacks a lined Citation, or a guidance comment remains",
         preview="a section 10.1 or 15 row that outranks the row before it (Critical, High, Medium, Low)"),
    Rule("C10", "References resolve",
         "an ID is defined twice or referenced but not defined, or a reference between sections does not resolve"),
    Rule("C11", "Register valid",
         "`evidence.jsonl` is missing, malformed or does not cover the document; an anchor is not in its cited lines",
         preview="an Answerable register row without `answered_in`, the section that answers the question"),
    Rule("C12", "Finding candidates addressed",
         "a finding candidate is neither cited in 10.1 nor Dismissed in the register"),
    Rule("C13", "Entry points not cited", "an entry point file is not cited anywhere in the document",
         ("advisory", "strict")),   # fails only under --strict
    Rule("C14", "Unknowns match the register",
         "section 14 lists a question the register resolved, or its unknown count disagrees with the register"),
    Rule("C15", "Register counts in prose",
         "a register count written in prose disagrees with the register; from template 2.7 a count marker holds a "
         "stale number or an unknown class (a hand-written \"N of M\" is then only an advisory: use a count marker)",
         preview="a count marker holds a stale number or an unknown class"),
    Rule("C16", "Universal claims cite single lines",
         "a universal claim (all, every, never) cites only single lines", ("advisory", "strict")),
    Rule("C17", "Audit scope names the method only",
         "the audit record's scope text holds an ID or a digit; with `--require-audit` the record lacks "
         "`audited_on`, `audited_with`, `audited_bundle` or `doc_sha`, and with `--strict` a row was sealed at "
         "upgrade (all fail from template 2.7)", ("advisory",),
         preview="the audit record's scope text holds an ID or a digit"),
    Rule("C18", "Notes match their block",
         "a note in `notes.jsonl` names an unknown block, was written about an older version of its block "
         "(`block_sha`), or cites a file that does not resolve; the label `Known extractor limitation:` is "
         "written in the Narrative outside a generated block (fails from template 2.7)", ("advisory",),
         preview="a note in `notes.jsonl` that does not match its block, or the reserved label written by hand"),
    Rule("C19", "Audit follows the plan",
         "with `--require-audit` on template 2.7, `audit-plan.json` is missing or differs from a fresh computation, "
         "or a planned id has no live register row (a section listed under `exclusions` is not required)"),
    Rule("C20", "Citation precision",
         "a range over 100 lines is a claim's only lined Citation in section 4, 7 or 10, "
         "or a section 4 or 10.1 table cell holds more than 5 Citations", ("advisory", "strict")),
)
RULE_TITLES = {r.id: r.title for r in RULES}
RULE_SUMMARIES = {r.id: r.summary for r in RULES}
# Rules that are advisory by default ("advisory") or fail only under --strict ("strict").
RULE_FLAGS = {r.id: r.flags for r in RULES if r.flags}
# Previews of template 2.7 rules: printed as "fails from template 2.7", never failing a 2.4 document.
PREVIEW_RULES = {r.id: r.preview for r in RULES if r.preview}
RULE_RANGE = f"C1-C{max(int(r.id[1:]) for r in RULES)}"
__doc__ = (f"The Check: pass/fail verification of a finished Narrative (rules {RULE_RANGE}). "
           "No score, no warnings.")
FAILS_FROM = (2, 7)
PREVIEW_HEADING = "## Template 2.7 previews (advisory)"
WIDE_RANGE = 100   # C20: a lined range spanning more lines than this is imprecise
CELL_CITES = 5     # C20: more Citations than this in one table cell is imprecise
C5_CAP = 30
C5_MIN_LEN = 40
RULE_CAP = 50  # C9-C13 on a large document: show the first problems, count the rest
FOLDER_CAP = 30  # folders listed under "Entry points not cited"
ENTRY_TYPES = ("route", "page", "command", "job")

_H2_RE = re.compile(r"^##\s+(\d+)\.\s*(.*?)\s*$")
_LIST_RE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
_SEP_RE = re.compile(r"^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$")
_PLACEHOLDER_RE = re.compile(r"<fill|TODO|\{\{", re.IGNORECASE)
_UNKNOWN_RE = re.compile(r"\bUnknown\b")
_ID_REF_RE = re.compile(r"(?<![\w-])((?:UI|F|C|X|V|Q|R|E)-\d+)(?![\w-])")
_ANCHOR_RE = re.compile(r"\]\(#([^)\s]+)\)")
APPENDIX_SLUG = "appendix-a-evidence-register-and-verification"

_NUMBER_WORDS = {w: n for n, w in enumerate(
    "one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen "
    "seventeen eighteen nineteen twenty".split(), 1)}
_NUM = r"(?<![\w,.])(\d{1,3}(?:,\d{3})+|\d+|" + "|".join(_NUMBER_WORDS) + r")"
_NOUNS = r"(controllers|route handlers|routes|endpoints|scheduled jobs|cron tasks|background jobs)\b"
_SUBSET_RE = re.compile(_NUM + r"\s+of\s+" + _NUM + r"\s+" + _NOUNS, re.I)      # N of M routes: M is the total
_NOUN_OF_RE = re.compile(_NUM + r"\s+" + _NOUNS + r"\s+of\s+" + _NUM + r"\b", re.I)  # N routes of M
_PLAIN_RE = re.compile(_NUM + r"\s+" + _NOUNS + r"(?!\s+of\s+(?:\d|" + "|".join(_NUMBER_WORDS) + r"))", re.I)
_PROSE_TOTAL = {  # noun -> (entry_point_counts key, what the Facts count)
    "controllers": ("files", "route handler files"), "route handlers": ("files", "route handler files"),
    "routes": ("routes", "routes"), "endpoints": ("routes", "routes"),
    "scheduled jobs": ("jobs", "jobs"), "cron tasks": ("jobs", "jobs"), "background jobs": ("jobs", "jobs"),
}


def _sections(lines: list[str]) -> list[dict]:
    """Level-2 numbered sections: {num, title, start (1-based heading line), end (exclusive line index)}."""
    heads, in_fence = [], False
    for i, line in enumerate(lines):
        if line.lstrip().startswith("```"):
            in_fence = not in_fence
        if in_fence:
            continue
        m = _H2_RE.match(line)
        if m:
            heads.append({"num": int(m.group(1)), "title": m.group(2), "start": i + 1, "idx": i})
    # a section runs to the next `## ` heading of any kind
    other = [i for i, l in enumerate(lines) if l.startswith("## ") and not _H2_RE.match(l)]
    bounds = sorted([h["idx"] for h in heads] + other + [len(lines)])
    for h in heads:
        h["end"] = min(b for b in bounds if b > h["idx"])
    return heads


def _content_lines(lines: list[str], sec: dict) -> list[tuple[int, str]]:
    """Real content lines of a section: not headings, blank, placeholders, or bare table header/separator."""
    out, in_fence = [], False
    body = lines[sec["idx"] + 1: sec["end"]]
    for off, line in enumerate(body):
        no = sec["idx"] + 2 + off
        s = line.strip()
        if s.startswith("```"):
            in_fence = not in_fence
            continue
        if in_fence:
            if s:
                out.append((no, s))
            continue
        if not s or s.startswith("#") or _PLACEHOLDER_RE.search(s):
            continue
        out.append((no, s))
    # drop table header rows (row directly followed by a separator) and separators
    keep = []
    for k, (no, s) in enumerate(out):
        if _SEP_RE.match(s) and "|" in s:
            continue
        nxt = out[k + 1][1] if k + 1 < len(out) else ""
        if s.startswith("|") and _SEP_RE.match(nxt) and "|" in nxt:
            continue
        keep.append((no, s))
    return keep


def _subsection(lines: list[str], parent: dict, key: str) -> dict | None:
    """The `### <key>` subsection inside a section, shaped like a section for _content_lines, or None."""
    head = re.compile(r"^###\s+" + re.escape(key) + r"(?![\d])")
    in_fence, start = False, None
    for i in range(parent["idx"] + 1, parent["end"]):
        s = lines[i]
        if s.lstrip().startswith("```"):
            in_fence = not in_fence
        if in_fence:
            continue
        if start is None:
            if head.match(s):
                start = i
        elif s.startswith("### ") or s.startswith("## "):
            return {"idx": start, "start": start + 1, "end": i}
    return None if start is None else {"idx": start, "start": start + 1, "end": parent["end"]}


def _blocks(lines: list[str], first: int, last: int) -> list[tuple[int, str]]:
    """Paragraph / list item / table data row blocks for lines[first:last], as (line, text). Exempt kinds skipped."""
    blocks, cur, cur_start, in_fence, in_table = [], [], 0, False, False

    def flush():
        nonlocal cur
        if cur:
            blocks.append((cur_start, " ".join(cur)))
        cur = []

    for i in range(first, last):
        line, s = lines[i], lines[i].strip()
        if s.startswith("```"):
            flush()
            in_fence = not in_fence
            in_table = False
            continue
        if in_fence:
            continue
        if not s or s.startswith("#"):
            flush()
            in_table = False
            continue
        if s.startswith("|"):
            flush()
            nxt = lines[i + 1].strip() if i + 1 < last else ""
            if not in_table:
                in_table = True
                if _SEP_RE.match(nxt):      # header row
                    continue
            if _SEP_RE.match(s):
                continue
            blocks.append((i + 1, s))
            continue
        in_table = False
        if _LIST_RE.match(line):
            flush()
            cur, cur_start = [_LIST_RE.sub("", line, count=1).strip()], i + 1
        else:
            if not cur:
                cur_start = i + 1
            cur.append(s)
    flush()
    return blocks


def _basenames(target: str, cache: dict) -> dict:
    idx = cache.get("__basenames__")
    if idx is None:
        idx = {}
        for sf in scan.walk(os.path.realpath(target), cache.get("__out__")):
            idx.setdefault(sf.path.rsplit("/", 1)[-1], []).append(sf.path)
        cache["__basenames__"] = idx
    return idx


def _resolve(target: str, cache: dict, c) -> tuple[bool | None, str]:
    """(resolved, reason) for one Citation. resolved None means: not a Citation, ignore it."""
    root = os.path.realpath(target)
    full = os.path.realpath(os.path.join(root, c.path))
    if os.path.commonpath([root, full]) != root:
        return False, f"`{c.path}` escapes the Target"
    if os.path.isdir(full):
        if c.start is None:
            return True, ""
        return False, f"`{c.path}` is a folder; a line cannot apply"
    if not os.path.isfile(full):
        name = c.path.rsplit("/", 1)[-1]
        if "/" not in c.path:
            hits = _basenames(target, cache).get(name, [])
            if len(hits) == 1:
                full = os.path.join(root, hits[0])
            elif len(hits) > 1:
                return False, (f"`{c.path}` matches {len(hits)} files ({', '.join(hits[:3])}"
                               f"{', ...' if len(hits) > 3 else ''}); cite the full path")
        if not os.path.isfile(full):
            # No extension, no line and no trailing folder shape: inline code such as an image
            # name or a command, not a claim about a file.
            if "." not in name and c.start is None and not c.raw.endswith("/"):
                return None, ""
            return False, f"`{c.path}` does not exist in the Target"
    if c.start is None:
        return True, ""
    if full not in cache:
        cache[full] = len(read_text(full).splitlines())
    n = cache[full]
    if c.start < 1 or c.end < c.start or c.end > n:
        return False, f"line {c.raw.rsplit(':', 1)[1]} is outside `{c.path}` ({n} lines)"
    return True, ""


def _never_mention(target: str) -> list[str]:
    path = os.path.join(target, OWNER_CONTEXT)
    return context.parse(read_text(path) if os.path.isfile(path) else None).never_mention


def _rows_all_unknown(rows) -> bool:
    return bool(rows) and all(_UNKNOWN_RE.search(r) for _, r in rows)


def _absent_owner_advisories(lines, by_num, facts) -> list[str]:
    """C4 advisories (never failures): ownership / runbook Unknown by absence of an owner file.

    Needs the Facts file: without it, whether an owner file exists is not known, so say nothing.
    """
    if not facts or any(f.get("kind") == "owner_file" for f in facts.get("facts", [])):
        return []
    out = []
    s11 = by_num.get(11)
    if s11 and _rows_all_unknown([c for c in _content_lines(lines, s11) if c[1].startswith("|")]):
        out.append("ownership is Unknown by absence (no appdoc-context.md); add one to fill section 11")
    s16 = by_num.get(16)
    sub = _subsection(lines, s16, "16.5") if s16 else None
    if sub:
        rows = [(no, r) for no, r in _content_lines(lines, sub) if r.startswith("|")
                and r.strip("| ").split("|")[0].strip().lower() in ("rollback", "backup", "restore")]
        if _rows_all_unknown(rows):
            out.append("deployment runbook is Unknown by absence (no appdoc-context.md); "
                       "add one to fill section 16.5 Rollback, Backup and Restore")
    return out


def _spec_table(lines, heads, key):
    """The table under `key` if its header matches the template spec, else None (C9 reports it)."""
    h = heads.get(key)
    t = dm.first_table(lines, h) if h else None
    if t is None:
        return None
    return t if spec.TABLES[key].header_ok([dm.cell_text(c) for c in t.header]) else None


def _col(key, name):
    return spec.TABLES[key].columns.index(name)


def _c9_tables(lines, raw, heads, add):
    for t in dm.tables(lines):
        for no, cells in t.rows:
            if len(cells) != len(t.header):
                add("C9", no, f"table row has {len(cells)} cells but its header has {len(t.header)}",
                    "make the row match the header; write a literal pipe as \\|")
    for key, ts in spec.TABLES.items():
        h = heads.get(key)
        if not h:
            continue  # C3/C8 report the missing heading
        t = dm.first_table(lines, h)
        want = " | ".join(ts.columns)
        if t is None:
            add("C9", h.idx + 1, f"{key} has no table", f"add the table `| {want} |`")
            continue
        if not ts.header_ok([dm.cell_text(c) for c in t.header]):
            add("C9", t.line, f"{key} table header is `| {' | '.join(t.header)} |`", f"use `| {want} |`")
            continue
        for no, cells in t.rows:
            if not ts.row_fits(len(cells)):
                continue
            first = dm.cell_text(cells[0])
            if ts.id_prefix and not re.fullmatch(re.escape(ts.id_prefix) + r"\d+", first):
                add("C9", no, f"{key} ID '{first}' is not {ts.id_prefix}<number>", f"number the rows {ts.id_prefix}1, {ts.id_prefix}2, ...")
            if ts.keyed_by and not any(re.fullmatch(re.escape(p) + r"\d+", first) for p in ts.keyed_by):
                add("C9", no, f"{key} ID '{first}' is not a {' or '.join(ts.keyed_by)} ID", "key each row by an ID it explains")
            for name, allowed in ts.values.items():
                v = dm.cell_text(cells[_col(key, name)])
                if v not in allowed:
                    add("C9", no, f"{key} {name} '{v}' is not one of: {', '.join(allowed)}", f"use one of: {', '.join(allowed)}")
        labels = {dm.cell_text(c[0]).casefold() for _, c in t.rows if c}
        for label in ts.required_rows:
            if label.casefold() not in labels:
                add("C9", t.line, f"{key} has no '{label}' row",
                    "add the row; write Unknown if the repository does not show it")
    h53 = heads.get("5.3")
    if h53 and spec.RESTRICTION_LINE not in "\n".join(lines[h53.idx:h53.end]):
        add("C9", h53.idx + 1, "5.3 lacks the fixed Restriction line", f"add `{spec.RESTRICTION_LINE}` below the table")
    for i, line in enumerate(raw.splitlines(), 1):
        if spec.GUIDE_RE.search(line):
            add("C9", i, "template guidance comment left in the document", "delete the appdoc:guide comment")


# One or more backticked commands, joined by a comma, a semicolon, then, or or and (`npm ci`, then `npm start`).
_BUILD_COMMAND_RE = re.compile(r"^`[^`\n]+`(?:\s*(?:[,;]\s*)?(?:\b(?:then|or|and)\b\s*)?`[^`\n]+`)*$")


def _c9_build_rows(lines, heads, add):
    """C9, section 17: the Command cell is a backticked command, `Unknown - see Open questions.` or `Not applicable`;
    every row but an Unknown one cites its Evidence with a lined Citation (`path:line`)."""
    h = heads.get("17")
    t = dm.first_table(lines, h) if h else None
    if t is None or not spec.TABLES["17"].header_ok([dm.cell_text(c) for c in t.header]):
        return   # a missing table or a changed header is reported by the generic table rule
    ts = spec.TABLES["17"]
    cmd, ev = ts.columns.index("Command"), ts.columns.index("Evidence")
    for no, cells in t.rows:
        if not ts.row_fits(len(cells)):
            continue
        step = dm.cell_text(cells[0])
        value = cells[cmd].strip()
        if value == spec.BUILD_UNKNOWN:
            continue
        if value != spec.BUILD_NOT_APPLICABLE and not _BUILD_COMMAND_RE.match(value) and "`" in value:
            add("C9", no, f"17 {step}: the Command cell must hold exactly one backticked command and nothing else",
                "put the command alone in backticks in the Command cell; extra commands and prose go under the table")
        elif value != spec.BUILD_NOT_APPLICABLE and not _BUILD_COMMAND_RE.match(value):
            add("C9", no, f"17 {step}: the Command cell is not a backticked command, '{spec.BUILD_UNKNOWN}' "
                f"or '{spec.BUILD_NOT_APPLICABLE}'",
                f"write the command in backticks, or '{spec.BUILD_UNKNOWN}' when the repository does not show it, "
                f"or '{spec.BUILD_NOT_APPLICABLE}' with the evidence cited")
        elif not any(c.start is not None for c in find_citations(cells[ev])):
            add("C9", no, f"17 {step}: a {'command' if value != spec.BUILD_NOT_APPLICABLE else 'Not applicable row'} "
                "needs a Citation with a line in Evidence",
                "cite where it is defined (`path:line`), or write the Command as Unknown")


def defined_ids(lines, heads, add) -> dict[str, int]:
    """ID -> 1-based line of the row that defines it."""
    ids: dict[str, int] = {}
    for key, ts in spec.TABLES.items():
        if not ts.id_prefix:
            continue
        t = _spec_table(lines, heads, key)
        if not t:
            continue
        for no, cells in t.rows:
            idv = dm.cell_text(cells[0]) if cells else ""
            if not re.fullmatch(re.escape(ts.id_prefix) + r"\d+", idv):
                continue
            if idv in ids:
                add("C10", no, f"{idv} is defined twice (first at line {ids[idv]})", "give each row its own ID")
            else:
                ids[idv] = no
    return ids


def _c10_refs(lines, heads, ids, register_ids, add, superseded=None):
    fence = dm.fenced(lines)
    slugs = dm.all_slugs(lines) | {APPENDIX_SLUG}
    for i, line in enumerate(lines):
        if fence[i]:
            continue
        text = dm.without_code(line)
        for m in _ID_REF_RE.finditer(text):
            ref = m.group(1)
            if ref.startswith("E-"):
                if register_ids is not None and ref not in register_ids:
                    if ref in (superseded or {}):
                        add("C10", i + 1, f"{ref} is superseded by {superseded[ref]}", f"cite {superseded[ref]}")
                    else:
                        add("C10", i + 1, f"{ref} is not a row of {REGISTER}", "cite an existing register ID")
            elif ref not in ids:
                add("C10", i + 1, f"{ref} is not defined in any table", "define the ID in its table or correct the reference")
        for m in _ANCHOR_RE.finditer(text):
            if m.group(1) not in slugs:
                add("C10", i + 1, f"link #{m.group(1)} matches no heading", "link to an existing heading anchor")

    t15 = _spec_table(lines, heads, "15")
    t14 = _spec_table(lines, heads, "14")
    addressed = " ".join(r[_col("15", "Addresses")] for _, r in t15.rows if len(r) == 5) if t15 else ""
    questions = " ".join(" ".join(r) for _, r in t14.rows) if t14 else ""
    if t15:
        named = set(_ID_REF_RE.findall(addressed))
        for vid, no in ids.items():
            if vid.startswith(spec.id_prefix_of("10.1")) and vid not in named:
                add("C10", no, f"finding {vid} is addressed by no recommendation in section 15",
                    f"add a section 15 row whose Addresses names {vid}")
    t102 = _spec_table(lines, heads, "10.2")
    if t102:
        pool = (addressed + " " + questions).casefold()
        for no, cells in t102.rows:
            if len(cells) != 3 or dm.cell_text(cells[1]) == spec.CONTROL_STATUS_PRESENT:
                continue
            control = dm.cell_text(cells[0])
            if control and control.casefold() not in pool:
                add("C10", no, f"10.2 control '{control}' is in neither section 15 nor section 14",
                    f"name '{control}' in a section 15 Addresses cell or a section 14 question")
    t85 = _spec_table(lines, heads, "8.5")
    if t85 is not None:
        explained = {dm.cell_text(c[0]) for _, c in t85.rows if c}
        for idv, no in ids.items():
            if idv.startswith(("C-", "X-")) and idv not in explained:
                add("C10", no, f"{idv} has no row in 8.5", f"add an 8.5 row for {idv} (none is a valid answer)")


def _c7_counts(target, lines, heads, facts, add):
    t = _spec_table(lines, heads, "4.1")
    if not t or not facts:
        return
    files = [f["path"] for f in facts.get("facts", []) if f.get("kind") == "file"]
    root = os.path.realpath(target)
    for no, cells in t.rows:
        if len(cells) != len(spec.TABLES["4.1"].columns):
            continue
        cites = [c for c in find_citations(cells[0]) if c.start is None]
        folder = next((c.path.rstrip("/") for c in cites if os.path.isdir(os.path.join(root, c.path))), None)
        if folder is None:
            continue
        stated = dm.cell_text(cells[1])
        n = sum(1 for p in files if p.startswith(folder + "/"))
        if stated.isdigit():
            if int(stated) != n:
                add("C7", no, f"4.1 states {stated} files for `{folder}/` but the Facts count {n}",
                    f"write {n}, or explain the difference in the Purpose cell")
        elif re.search(r"\d", stated):
            add("C7", no, f"4.1 Files '{stated}' is not a plain number", f"write the Facts count ({n})")


def _num(s: str) -> int:
    return _NUMBER_WORDS.get(s.lower()) or int(s.replace(",", ""))


def _prose_counts(line: str) -> list[tuple[int, str, str]]:
    """(stated number, noun, matched text) for every counted noun on a line; `N of M` states M."""
    out = []
    for rx, stated, noun in ((_SUBSET_RE, 2, 3), (_NOUN_OF_RE, 3, 2)):
        def blank(m, stated=stated, noun=noun):
            out.append((_num(m.group(stated)), m.group(noun).lower(), m.group(0)))
            return " " * len(m.group(0))
        line = rx.sub(blank, line)
    out += [(_num(m.group(1)), m.group(2).lower(), m.group(0)) for m in _PLAIN_RE.finditer(line)]
    return out


def _c7_prose(lines, by_num, facts, add):
    """Sections 2-4 may not state a count of controllers, routes or jobs that the Facts contradict."""
    if not facts:
        return
    totals = fill_mod.entry_point_counts(facts)
    fence = dm.fenced(lines)
    for n in (2, 3, 4):
        sec = by_num.get(n)
        for i in (range(sec["idx"], sec["end"]) if sec else ()):
            if fence[i]:
                continue
            for stated, noun, shown in _prose_counts(lines[i]):
                key, label = _PROSE_TOTAL[noun]
                if totals[key] > 0 and stated != totals[key]:
                    add("C7", i + 1, f'states "{shown}" but the Facts have {totals[key]} {label}',
                        f"write {totals[key]}, or write \"N of {totals[key]}\" for a subset")


def _c10_coverage(lines, heads, facts, add):
    """5.3 covers every section 4 Area; a 16.6 effect table names only real config keys."""
    t4, t53 = _spec_table(lines, heads, "4"), _spec_table(lines, heads, "5.3")
    if t4 and t53:
        h = heads["5.3"]
        caps = [dm.cell_text(r[0]).casefold() for _, r in t53.rows if r]
        mentioned = set(_ID_REF_RE.findall("\n".join(lines[h.idx:h.end])))
        width, a, i = len(spec.TABLES["4"].columns), _col("4", "Area"), _col("4", "ID")
        areas: dict[str, list[str]] = {}
        for _, r in t4.rows:
            if len(r) == width and dm.cell_text(r[a]):
                areas.setdefault(dm.cell_text(r[a]), []).append(dm.cell_text(r[i]))
        for area, fids in sorted(areas.items()):
            if any(area.casefold() in c for c in caps) or all(f in mentioned for f in fids):
                continue
            add("C10", t53.line, f"5.3 does not cover the section 4 Area '{area}' ({', '.join(fids[:5])}"
                f"{', ...' if len(fids) > 5 else ''})",
                f"add a Capability row that names '{area}', or mention each of its F-IDs in 5.3")
    h66 = heads.get("16.6")
    if h66 and facts is not None:
        names = {f["name"] for f in facts.get("facts", [])
                 if f.get("kind") == "config_key" and not (f.get("detail") or {}).get("test")}
        want = [c.casefold() for c in spec.CONFIG_EFFECT_COLUMNS]
        for t in dm.tables(lines, h66.idx + 1, h66.end):
            if [c.casefold() for c in t.header] != want:
                continue
            for no, cells in t.rows:
                key = cells[0].strip().strip("`").strip() if len(cells) == len(want) else None
                if key is not None and key not in names:
                    add("C10", no, f"16.6 effect table Key '{key}' is not a config_key Fact",
                        "use a key name from facts.json, or remove the row")


def _cited_paths(target, cache, cites) -> set[str]:
    """Every path some Citation names; a bare file name counts as the one file it resolves to."""
    out = set()
    for c in cites:
        out.add(c.path)
        if "/" not in c.path:
            hits = _basenames(target, cache).get(c.path, [])
            if len(hits) == 1:
                out.add(hits[0])
    return out


def uncited_smells(target, cache, lines, heads, facts) -> list[tuple[str, dict]]:
    """(fid, smell Fact) of every non-test smell Fact no 10.1 row cites (the path, and a line that covers it)."""
    smells = sorted((f for f in facts.get("facts", []) if f.get("kind") == "smell" and not f["detail"].get("test")),
                    key=lambda f: (f["path"], f.get("line") or 0, f["detail"].get("fid", "")))
    if not smells:
        return []
    spans: list[tuple[str, int | None, int | None]] = []
    t = _spec_table(lines, heads, "10.1")
    for _, cells in (t.rows if t else ()):
        for c in find_citations(" ".join(cells)):
            for p in _cited_paths(target, cache, [c]):
                spans.append((p, c.start, c.end))
    out = []
    for f in smells:
        d = f["detail"]
        fid = d.get("fid") or fact_id("smell", d.get("pattern", ""), f["path"], f.get("line"))
        ln = f.get("line")
        if not any(p == f["path"] and (ln is None or (s is not None and s <= ln <= e)) for p, s, e in spans):
            out.append((fid, f))
    return out


def _c12_smells(target, cache, lines, heads, facts, reg, add):
    """Every non-test smell Fact is cited in a 10.1 row (path and a line that covers it) or dismissed."""
    dismissed = set()
    for _, row in (reg.live_rows() if reg else ()):   # a superseded dismissal is history
        m = reg_mod.SMELL_REF_RE.match(str(row["ref"]))
        if m and row["result"] == "Dismissed" and str(row["limitation"]).strip():
            dismissed.add(m.group(1))
    h = heads.get("10.1")
    for fid, f in uncited_smells(target, cache, lines, heads, facts):
        d = f["detail"]
        ln = f.get("line")
        if fid in dismissed:
            continue
        at = f"{f['path']}:{ln}" if ln else f["path"]
        add("C12", h.idx + 1 if h else 1,
            f"smell {fid} ({d.get('pattern', '?')}) at {at} is not cited in 10.1 and not dismissed in "
            f"{REGISTER}: {f['name']}",
            f"cite `{at}` in a 10.1 row, or add "
            f'{{"id": "E-n", "ref": "smell/{fid}", "claim": "<why this is not a finding>", "result": "Dismissed", '
            f'"cites": [], "anchor": "", "limitation": "<why>"}} to {REGISTER}')


def _uncited_entry_points(target, cache, facts, cites) -> list[tuple[str, int, list[str]]]:
    """(top-level folder, files, first 5 paths) of entry point files no Citation names, largest folder first."""
    cited = _cited_paths(target, cache, cites)
    paths = sorted({f["path"] for f in facts.get("facts", []) if f.get("kind") == "entry_point"
                    and not f["detail"].get("test") and f["detail"].get("type") in ENTRY_TYPES} - cited)
    groups: dict[str, list[str]] = {}
    for p in paths:
        groups.setdefault(p.split("/", 1)[0] + "/" if "/" in p else "(root)", []).append(p)
    return sorted(((k, len(v), v[:5]) for k, v in groups.items()), key=lambda g: (-g[1], g[0]))


def _block_detail(name, body, facts) -> str:
    """Which count differs, for the 16.6 block (the exact comparison above is the check; this is its message)."""
    if name != "config-reference":
        return ""
    rows = [ln for ln in body.splitlines() if ln.startswith("|")][2:]
    return (f" (the Facts expect {fill_mod.config_shown_count(facts)} of {fill_mod.config_app_count(facts)} "
            f"application keys; the block has {len(rows)} shown)")


def _c7_blocks(raw, heads, facts, out_dir, target, add, doc_ver=()):
    ctx = {"out_dir": out_dir, "text": raw, "target": target}
    found = {name: (body, line) for name, body, line in fill_mod.blocks(normalize_newlines(raw))}
    for key, name in spec.generated_blocks(doc_ver).items():
        h = heads.get(key)
        line = h.idx + 1 if h else 1
        if name not in found:
            add("C7", line, f"generated block '{name}' is missing from {key}",
                "copy its appdoc:generated markers from the template, then run `appdoc fill`")
            continue
        if facts is not None and found[name][0] != (fill_mod.render_block(name, facts, ctx) or "").strip():
            add("C7", found[name][1], f"generated block '{name}' differs from the Facts{_block_detail(name, found[name][0], facts)}",
                "run `appdoc fill <target>`; never edit a generated block by hand")


def _c2_per_claim(lines, s10, add):
    """C2: each security claim in section 10 must carry at least one lined Citation.

    A bare mention (no line) is still a resolved Citation (C1) but does not satisfy C2.
    10.1 rows: the Evidence cell needs a lined Citation.
    10.2 rows: only a 'Present' status needs a lined Citation (other statuses record where
    someone looked, which is a file). Any other block in section 10 that holds a Citation
    needs one with a line.
    """
    fix = "cite the exact line, e.g. `path:12` (dotfiles and data files take a line too: `.gitignore:5`)"
    heads = dm.headings(lines)
    for key, status_col, cite_col in (("10.1", None, 3), ("10.2", 1, 2)):
        h = heads.get(key)
        if not h:
            continue
        t = dm.first_table(lines, h)
        if not t:
            continue
        for no, cells in t.rows:
            if len(cells) <= max(cite_col, status_col or 0):
                continue
            if status_col is not None and dm.cell_text(cells[status_col]).strip() != spec.CONTROL_STATUS_PRESENT:
                continue  # a non-Present 10.2 row records where someone looked: a file is enough
            cites = find_citations(cells[cite_col])
            if cites and all(c.start is None for c in cites):
                add("C2", no, "security claim has no lined Citation", fix)
    for no, blk in _blocks(lines, s10["idx"] + 1, s10["end"]):
        if blk.startswith("|"):
            continue  # table rows handled above
        cites = find_citations(blk)
        if cites and all(c.start is None for c in cites):
            add("C2", no, "security claim has no lined Citation", fix)


def _c11_supersedes(reg, all_ids, add):
    """A `supersedes` target must be a row of this register with the same ref, and the links may not cycle."""
    for no, row in reg.rows:
        where = f"{REGISTER} line {no}"
        for t in reg.supersedes_of(row):
            if t not in all_ids:
                add("C11", no, f"{where}: {row['id']} supersedes {t}, which is not a row of this register",
                    "name an existing E-<n> row, or remove \"supersedes\"")
            elif str(all_ids[t]["ref"]) != str(row["ref"]):
                add("C11", no, f"{where}: {row['id']} supersedes {t}, which has the ref {all_ids[t]['ref']}, "
                    f"not {row['ref']}", "a row may supersede only a row of the same ref")
    edges = {str(r["id"]): [t for t in reg.supersedes_of(r) if t in all_ids] for _, r in reg.rows}
    state: dict[str, int] = {}   # 1 = on the current path, 2 = finished

    def visit(rid, path):
        state[rid] = 1
        for t in edges.get(rid, ()):
            if state.get(t) == 1:
                cyc = path[path.index(t):] + [t] if t in path else [rid, t]
                return cyc
            if t not in state:
                found = visit(t, path + [t])
                if found:
                    return found
        state[rid] = 2
        return None

    line_of = {str(r["id"]): no for no, r in reg.rows}
    for rid in list(edges):
        if rid not in state:
            cyc = visit(rid, [rid])
            if cyc:
                add("C11", line_of[cyc[0]], f"{REGISTER} line {line_of[cyc[0]]}: supersedes form a cycle "
                    f"({' -> '.join(cyc)})", "a superseded row cannot supersede the row that replaced it")


def _c11_register(target, out_dir, lines, heads, ids, cache, require_audit, smell_fids, add,
                  doc_ver=(), add27=None):
    """Validate evidence.jsonl. Returns (Register or None, coverage rows)."""
    path = os.path.join(out_dir, REGISTER)
    if not os.path.isfile(path):
        add("C11", 1, "the audit state is not declared",
            f'write {REGISTER}: the audit record, then one row per audited claim; or line 1 '
            '{"type": "audit", "performed": false, "scope": "<why>"}')
        return None, []
    reg = reg_mod.parse(read_text(path))
    for no, msg in reg.errors:
        add("C11", no, f"{REGISTER} line {no}: {msg}", "fix the record; see SKILL.md, Evidence Register")
    if not reg.performed:
        if reg.rows:
            add("C11", reg.rows[0][0], f"{REGISTER} says the audit was not performed but has rows",
                'set "performed": true or remove the rows')
        if require_audit:
            add("C11", 1, "the source-to-claim audit was not performed and --require-audit is set",
                "run the audit and record it")
        return reg, []
    seen: dict[str, int] = {}
    covered: set[str] = set()
    all_ids = {str(r["id"]): r for _, r in reg.rows}
    live_ids = {str(r["id"]) for _, r in reg.live_rows()}
    _c11_supersedes(reg, all_ids, add)
    for no, row in reg.rows:
        where = f"{REGISTER} line {no}"
        rid = str(row["id"])
        live = rid in live_ids
        if not reg_mod.ID_RE.match(rid):
            add("C11", no, f"{where}: id '{rid}' is not E-<number>", "number rows E-1, E-2, ...")
        elif rid in seen:
            add("C11", no, f"{where}: id {rid} repeats line {seen[rid]}", "give each row its own ID")
        else:
            seen[rid] = no
        if row["result"] not in reg_mod.RESULTS:
            add("C11", no, f"{where}: result '{row['result']}' is not one of {', '.join(reg_mod.RESULTS)}",
                "use one of: " + ", ".join(reg_mod.RESULTS))
        ref, result = str(row["ref"]), row["result"]
        sm, am = reg_mod.SMELL_REF_RE.match(ref), reg_mod.ANSWERABLE_REF_RE.match(ref)
        m = reg_mod.REF_RE.match(ref)
        if sm:
            if result != "Dismissed":
                add("C11", no, f"{where}: ref '{ref}' is for a Dismissed row only", "use result Dismissed, or a section ref")
            elif smell_fids is not None and sm.group(1) not in smell_fids:
                add("C11", no, f"{where}: dismisses a candidate that does not exist ({ref})",
                    "use the fid printed in facts-summary.md or check-report.md, or remove the row")
        elif result == "Dismissed":
            add("C11", no, f"{where}: a Dismissed row needs ref smell/<fid>, not '{ref}'", "use ref smell/<fid>")
        elif result == "Answerable" and not am:
            add("C11", no, f"{where}: an Answerable row needs ref 14/Q-<n>, not '{ref}'", "use ref 14/Q-<n>")
        elif result == "Answerable":
            if live and am.group(1) in ids:   # a question that was closed and removed is no longer a problem
                shown = ", ".join(str(c).strip("`") for c in row["cites"]) or "no citation recorded"
                add("C11", no, f"{where}: {am.group(1)} can be closed from source ({shown}); "
                    "close it and remove the question", f"answer {am.group(1)} in the document, then delete it from section 14")
            if live and add27:   # 2.7: the row says where the document answers the question
                where_in = row.get("answered_in")
                if not where_in:
                    add27("C11", no, f"{where}: an Answerable row needs answered_in, the section that answers {am.group(1)}",
                          'add "answered_in": "<section>" (for example 16.3)')
                elif where_in not in heads:
                    add27("C11", no, f"{where}: answered_in {where_in} names no section of the document",
                          "name the section or subsection (for example 16.3) that answers the question")
        elif not m or m.group(1) not in heads:
            add("C11", no, f"{where}: ref '{row['ref']}' names no section or subsection",
                "use a heading number such as 7.3, optionally with an ID: 10.1/V-2")
        elif m.group(2) and m.group(2) not in ids:
            add("C11", no, f"{where}: ref '{row['ref']}' names an ID that is not defined", "use an ID from the document")
        else:
            if live:
                covered.add(m.group(2) or m.group(1))
        for raw_cite in row["cites"]:
            parsed = parse_span(raw_cite.strip("`"))
            if not parsed:
                add("C11", no, f"{where}: '{raw_cite}' is not a path:line Citation", "cite `path:line` or `path:start-end`")
                continue
            c = Citation(no, parsed[0], parsed[1], parsed[2], raw_cite)
            ok, why = _resolve(target, cache, c)
            if not ok:
                add("C11", no, f"{where}: citation does not resolve: {why}", "cite an existing file and line")
            elif add27 and (finding := _c1_bare_finding(target, cache, c)):
                add27("C1", no, f"{where}: {finding[0]}", finding[1])
        anchor = " ".join(str(row["anchor"]).split())
        one_line = str(row["anchor"]).strip()
        if "\n" in one_line or "\r" in one_line or len(one_line) > reg_mod.MAX_ANCHOR:
            add("C11", no, f"{where}: anchor must be one line of at most {reg_mod.MAX_ANCHOR} characters",
                "copy a short literal string that sits on one line of the cited lines")
        if row["result"] == "Dismissed" and not str(row["limitation"]).strip():
            add("C11", no, f"{where}: a Dismissed row needs a limitation", "say why the candidate is not a finding")
        if row["result"] in ("Supported", "Corrected"):
            if not row["cites"]:
                add("C11", no, f"{where}: a {row['result']} row needs at least one citation", "cite the lines that support it")
            if not anchor:
                add("C11", no, f"{where}: a {row['result']} row needs an anchor",
                    "copy a short literal string from the cited lines into anchor")
        if live and anchor and row["result"] in ("Supported", "Corrected"):   # a superseded row's text is history
            loc = reg_mod.locate(target, row)
            if loc is None:
                add("C11", no, f"{where}: anchor not found on a single cited line (exact, case-sensitive)",
                    "copy the anchor exactly from one line of the cited lines")
    # claim_sha checks (1.2): ID and workflow rows must be sealed; Dismissed/Answerable are exempt.
    # Activates when the template version reaches 2.4 (Phase 3).
    if doc_ver >= (2, 4):
        id_ref_rows: dict[str, list[tuple[int, dict]]] = {}
        for no, row in reg.live_rows():
            if row["result"] in ("Dismissed", "Answerable"):
                continue
            m = reg_mod.REF_RE.match(str(row["ref"]))
            if not m:
                continue
            sec_key, id_part = m.group(1), m.group(2)
            if not (id_part or sec_key.startswith("7.")):
                continue
            ref_key = str(row["ref"])
            id_ref_rows.setdefault(ref_key, []).append((no, row))
        for ref_key, rows in id_ref_rows.items():
            if len(rows) > 1:
                for no, row in rows[1:]:
                    if doc_ver >= FAILS_FROM:
                        add("C11", no, f"{REGISTER} line {no}: two live rows for {ref_key}",
                            f'add "supersedes": "{rows[0][1]["id"]}" to the newer row; do not delete the older row')
                    else:
                        add("C11", no, f"{REGISTER} line {no}: two rows for the same ID ref {ref_key}",
                            "keep the row that describes the current text")
            no, row = rows[0]
            where = f"{REGISTER} line {no}"
            expected = fingerprint.claim_sha(lines, heads, ids, ref_key)
            if expected is None:
                continue
            if "claim_sha" not in row:
                add("C11", no, f"{where}: not sealed; run `appdoc build`",
                    "run `appdoc build <target>` to seal the register")
            elif row["claim_sha"] != expected:
                add("C11", no, f"{where}: the text of {ref_key} changed after it was audited; re-audit it and replace the row",
                    "re-audit the claim and rewrite the row without claim_sha, then run `appdoc build`")
    for vid, no in ids.items():
        if vid.startswith(spec.id_prefix_of("10.1")) and vid not in covered:
            add("C11", no, f"finding {vid} has no register row", f"audit {vid} and add a row with ref 10.1/{vid}")
    workflows = sorted((k for k in heads if k.startswith("7.")), key=lambda k: int(k.split(".")[1]))
    for k in workflows:
        if k not in covered and not any(str(r["ref"]).startswith(k + "/") for _, r in reg.live_rows()):
            add("C11", heads[k].idx + 1, f"workflow {k} has no register row", f"audit it and add a row with ref {k}")
    return reg, coverage(heads, ids, reg, workflows)


_Q_REF_RE = re.compile(r"^(?:14/)?(Q-\d+)$")
_A2_UNKNOWNS_RE = re.compile(r"\|\s*14\s*\|\s*(\d+)\s+of\s+(\d+)\s*\|")


def _c14_unknowns(lines, heads, ids, reg, appendix, add):
    """Section 14 and the register must agree: no resolved Q-row left in 14, A.2 counts the register's Q-refs.

    `appendix` is the appendix-a block text; `lines` has it masked, so the caller passes it from the raw Narrative.
    """
    if reg is None or not reg.performed:
        return
    q_rows = [(no, row, m.group(1)) for no, row in reg.live_rows() if (m := _Q_REF_RE.match(str(row.get("ref", ""))))]
    t14 = _spec_table(lines, heads, "14")
    in14 = {dm.cell_text(cells[0]): no for no, cells in t14.rows if cells} if t14 else {}
    for no, row, qid in q_rows:
        if row.get("result") in ("Answerable", "Dismissed") and qid in in14:
            add("C14", in14[qid], f"section 14 lists {qid} but the audit resolved it ({row['id']}, {row['result']}); "
                "remove it from section 14 or record the answer in the row",
                f"delete the {qid} row from section 14, or change the register result")
    m = _A2_UNKNOWNS_RE.search(appendix or "")
    actual = len({qid for _, row, qid in q_rows if row.get("result") not in ("Answerable", "Dismissed")})  # resolved Qs leave section 14
    if m and actual and int(m.group(1)) != actual:  # A.2 counts IDs with a register row; no Q rows at all: nothing to reconcile
        add("C14", 1, f"Appendix A.2 states {m.group(1)} unknowns have a register row but the register carries {actual} Q-refs",
            "run `appdoc fill` after reconciling section 14 and the register")


# C15: a hand-written "N of M <noun>" sentence states two counts the tool can verify:
# M is the total rows of the doc's table for that ID class, N is how many of them have a
# register row. A sentence that disagrees with either is stale prose (RC-A). Only ID-class
# nouns are checked; "control" and "row" are not single ID classes, so they are skipped.
# The nouns are `template_spec.ID_CLASSES[prefix].nouns`.
_C15_RE = re.compile(r"\b(\d+) of (\d+)\s+([A-Za-z-]+)")


def _c15_sentences(lines, ids):
    """(line, text, noun, ID prefix, N, M) of every hand-written 'N of M <noun>' sentence about an ID class."""
    nouns = {n: c.prefix for c in spec.ID_CLASSES.values() for n in c.nouns}
    for i, line in enumerate(lines):
        for m in _C15_RE.finditer(line):
            noun = m.group(3).lower().rstrip("s")
            prefix = nouns.get(noun)
            if prefix:
                yield i + 1, m.group(0).strip(), noun, prefix, int(m.group(1)), int(m.group(2))


def _c15_register_counts(lines, ids, reg, add):
    """Every 'N of M <noun>' sentence must agree with the doc's table total and the register (template 2.4)."""
    if reg is None or not reg.performed:
        return
    refs = set()
    for _, row in reg.live_rows():
        m = reg_mod.REF_RE.match(str(row.get("ref", "")))
        if m:
            refs.add(m.group(2) or m.group(1))
    for no, text, noun, prefix, n, total in _c15_sentences(lines, ids):
        doc_total = sum(1 for k in ids if k.startswith(prefix))
        if doc_total and total != doc_total:
            add("C15", no, f'states "{text}" but the document has {doc_total} {noun}s',
                "reword the sentence to the current table total, or run `appdoc fill`")
            continue
        reg_count = sum(1 for k in refs if k.startswith(prefix))
        if reg_count and n != reg_count:
            add("C15", no, f'states "{text}" but the register has {reg_count} {noun}s with a row',
                "reword the sentence to the current register count, or run `appdoc fill`")


def _c15_markers(raw, facts, ids, reg, add):
    """C15, 2.7 rule: a count marker holds the number `fill` would write, and its class is a known one.

    Reads the raw Narrative (the marker is an HTML comment) with the generated blocks masked."""
    text = dm.mask_blocks(normalize_newlines(raw), tuple(spec.GENERATED.values()))
    for m in spec.COUNT_MARKER_RE.finditer(text):
        cls, shown = m.group(2).strip(), m.group(3).strip()
        no = text.count("\n", 0, m.start()) + 1
        if cls not in spec.COUNT_CLASSES:
            add("C15", no, f"count marker class '{cls}' is not one of {', '.join(spec.COUNT_CLASSES)}",
                "use one of those classes")
            continue
        kind = spec.COUNT_CLASSES[cls]
        if kind == "facts" and facts is None:
            continue
        want = fill_mod.count_marker_value(cls, facts or {}, ids, reg)
        if want is not None and shown != str(want):
            source = {"id": "document has", "register": "register has", "facts": "Facts have"}[kind]
            add("C15", no, f"count marker {cls} says {shown} but the {source} {want}",
                "run `appdoc fill`, which writes the number")


# C16: a universal claim ("all handlers …") whose only citations are single lines is under-evidenced
# (F1). Advisory by default; fails under --strict (R8). A range citation covers the claim, so it is
# not flagged. Only prose lines (not headings or table rows) are considered; fenced lines carry no
# citations and are therefore skipped.
_C16_QUANTIFIERS = re.compile(r"\b(all|every|any|whole|entire|always|never|each)\b", re.I)


def _c16_quantifier(lines, cites, add, strict):
    """Return the (line, text) of universal claims whose only citations are single lines."""
    by_line: dict[int, list] = {}
    for c in cites:
        if c.start is not None:
            by_line.setdefault(c.doc_line, []).append(c)
    hits = []
    for i, line in enumerate(lines):
        if line.lstrip().startswith(("#", "|")):
            continue
        cites_here = by_line.get(i + 1)
        if not cites_here or not _C16_QUANTIFIERS.search(line):
            continue
        if any(c.start != c.end for c in cites_here):
            continue  # a range citation covers the claim
        hits.append((i + 1, line.strip()))
    for no, _ in hits:
        if strict:
            add("C16", no, "a universal claim cites only single lines; cite the covering range or mark it Inferred",
                "cite the covering range (`path:start-end`) or prefix the claim with **Inferred:**")
    return hits


def _c20_precision(lines, heads):
    """(line, message) for imprecise Citations in sections 4, 7 and 10 (C20).

    A claim (paragraph, list item or table row) whose only lined Citation is a range over WIDE_RANGE
    lines; and a section 4 or 10.1 table cell with more than CELL_CITES Citations.
    """
    hits = []
    for key in ("4", "7", "10"):
        h = heads.get(key)
        if not h:
            continue
        for no, blk in _blocks(lines, h.idx + 1, h.end):
            lined = [c for c in find_citations(blk) if c.start is not None]
            if len(lined) == 1 and lined[0].end - lined[0].start + 1 > WIDE_RANGE:
                c = lined[0]
                hits.append((no, f"`{c.path}:{c.start}-{c.end}` spans {c.end - c.start + 1} lines "
                                 f"(more than {WIDE_RANGE}) and is this claim's only lined Citation"))
    for key in ("4", "10.1"):
        h = heads.get(key)
        if not h:
            continue
        for t in dm.tables(lines, h.idx + 1, h.end):
            for no, cells in t.rows:
                for col, cell in enumerate(cells):
                    n = len(find_citations(cell))
                    if n > CELL_CITES:
                        name = dm.cell_text(t.header[col]) if col < len(t.header) else str(col + 1)
                        hits.append((no, f"the {name} cell cites {n} sources (more than {CELL_CITES})"))
    return sorted(set(hits))


_C20_FIX = ("cite the specific lines the claim rests on (`path:start-end`, at most "
            f"{WIDE_RANGE} lines), and split a cell that cites many sources")


def _c9_severity_order(lines, heads, add):
    """C9, 2.7 rule: a 10.1 or 15 row may not outrank the row before it. Skips values C9 reports itself."""
    rank = {v: i for i, v in enumerate(spec.SEVERITY_ORDER)}
    for key in ("10.1", "15"):
        h = heads.get(key)
        t = dm.first_table(lines, h) if h else None
        if not t or "Severity" not in t.header:
            continue
        col = t.header.index("Severity")
        prev = None
        for no, cells in t.rows:
            if len(cells) <= col:
                continue
            sev = dm.cell_text(cells[col])
            if sev not in rank:
                continue
            rid = dm.cell_text(cells[0])
            if prev is not None and rank[sev] < rank[prev[1]]:
                add("C9", no, f"{key} row {rid} ({sev}) outranks the row before it ({prev[0]}, {prev[1]})",
                    "move the row; keep its ID")
            prev = (rid, sev)


def c1_bare_name(target, cache, c):
    """The unique full path of a bare-name Citation that resolves outside the Target root, else None (C1, 2.7 rule)."""
    if "/" in c.path or c.path in KNOWN_BARE_FILES:
        return None
    if os.path.isfile(os.path.join(os.path.realpath(target), c.path)):
        return None  # a root file
    hits = _basenames(target, cache).get(c.path, [])
    return hits[0] if len(hits) == 1 else None


def _c1_bare_finding(target, cache, c):
    """(message, fix) for a bare-name Citation that has one full path, else None. One wording for the Narrative,
    the register's cites and a note's cites."""
    full = c1_bare_name(target, cache, c)
    if not full:
        return None
    span = "" if c.start is None else f":{c.start}" + ("" if c.end in (None, c.start) else f"-{c.end}")
    return f"`{c.path}` is a bare name; the file is `{full}`", f"cite the full path: `{full}{span}`"


def _c17_scope(reg, heads, add):
    """C17, 2.7 rule: the audit record's scope describes the method only, with no ID token or digit; `exclusions`
    is {section: reason}, its keys are sections of the document and its reasons follow the same token rule."""
    if reg is None or not reg.performed:
        return
    audit = reg.audit or {}
    scope = str(audit.get("scope") or "")
    if _ID_REF_RE.search(scope) or re.search(r"\d", scope):
        add("C17", 1, f"{REGISTER} line 1: the audit scope text holds an ID or a number",
            "describe only the method; coverage is computed")
    exclusions = audit.get("exclusions")
    if exclusions is None:
        return
    if not isinstance(exclusions, dict):
        add("C17", 1, f"{REGISTER} line 1: exclusions must be an object of section: reason",
            'write "exclusions": {"9": "reason"}')
        return
    for key, why in exclusions.items():
        if key not in heads or not re.fullmatch(r"\d+(?:\.\d+)?", str(key)):
            add("C17", 1, f"{REGISTER} line 1: exclusions key '{key}' is not a section of the document",
                "use a section number such as 8.3")
        why = str(why)
        if _ID_REF_RE.search(why) or re.search(r"\d", why):
            add("C17", 1, f"{REGISTER} line 1: the exclusion for {key} holds an ID or a number",
                "state the reason without IDs or numbers; coverage is computed")


def _c17_provenance(reg, require_audit, strict, add):
    """C17, template 2.7: under --require-audit line 1 carries the audit provenance; with --strict no live row
    was sealed at upgrade (its text was never re-audited). Callers gate this on the document's stamp."""
    if reg is None or not reg.performed or not require_audit:
        return
    missing = [k for k in reg_mod.AUDIT_RECORD_KEYS if not (reg.audit or {}).get(k)]
    if missing:
        add("C17", 1, f"{REGISTER} line 1: the audit record lacks {', '.join(missing)}",
            "run `appdoc seal --audit --date YYYY-MM-DD` when the audit is finished")
    if strict:
        for no, row in reg.live_rows():
            if row.get("sealed_by") == "upgrade":
                add("C17", no, f"{REGISTER} line {no}: {row['id']} was sealed at upgrade; its text was not re-audited",
                    "audit the row, then run `appdoc seal --audit --date YYYY-MM-DD`")


def _c18_notes(target, out_dir, raw, facts, cache, add):
    """C18, 2.7 rule: notes.jsonl notes match their block, and the reserved label is not hand-written.

    A note names a generated block, carries a `block_sha` equal to the hash of that block's current generated
    body (so a note written about an older block fails), and cites files that resolve by their full path (a bare
    name is C1, 2.7 rule). `add` is the stamp-gated adder. The label
    `Known extractor limitation:` may appear in the Narrative only inside a generated block (where `fill` put it).
    """
    path = os.path.join(out_dir, notes_mod.NOTES)
    where = f"{notes_mod.NOTES} line"
    if os.path.isfile(path):
        parsed = notes_mod.parse(read_text(path))
        for no, why in parsed.errors:
            add("C18", no, f"{where} {no}: {why}", f"fix the note in {notes_mod.NOTES}")
        known = tuple(spec.GENERATED.values())
        ctx = {"out_dir": out_dir, "target": target, "text": raw}
        for no, note in parsed.notes:
            name = note["block"]
            if name not in known:
                add("C18", no, f"{where} {no}: '{name}' is not a generated block", "use one of " + ", ".join(known))
            elif facts is not None and note["block_sha"] == "":
                add("C18", no, f"{where} {no}: the note is not sealed", "run `appdoc build`")
            elif facts is not None:
                body = fill_mod.generated_body(name, facts, ctx)
                if body is not None and note["block_sha"] != notes_mod.body_sha(body):
                    add("C18", no, f"{where} {no}: the {name} block changed after this note was written",
                        "re-read the block, rewrite or delete the note, and clear block_sha")
            for raw_cite in note["cites"]:
                p = parse_span(raw_cite.strip("`"))
                if not p:
                    add("C18", no, f"{where} {no}: '{raw_cite}' is not a path:line Citation",
                        "cite `path:line` or `path:start-end`")
                    continue
                ok, why = _resolve(target, cache, Citation(no, p[0], p[1], p[2], raw_cite))
                if not ok:
                    add("C18", no, f"{where} {no}: citation does not resolve: {why}", "cite an existing file and line")
                elif finding := _c1_bare_finding(target, cache, Citation(no, p[0], p[1], p[2], raw_cite)):
                    add("C1", no, f"{where} {no}: {finding[0]}", finding[1])
    prose = dm.strip_comments(dm.mask_blocks(normalize_newlines(raw), tuple(spec.GENERATED.values())))
    for i, line in enumerate(prose.splitlines(), 1):
        if notes_mod.LABEL.casefold() in line.casefold():
            add("C18", i, f"the reserved label '{notes_mod.LABEL}' is written in the Narrative outside a generated block",
                f"move this note to {notes_mod.NOTES}")


def _c19_plan(target, out_dir, reg, add):
    """C19, 2.7 rule under --require-audit: audit-plan.json equals a fresh computation and every planned key has a
    live register row. A section the audit record lists under `exclusions` is not required (and is printed).
    Returns the plan's advisories."""
    from . import audit_plan
    path = os.path.join(out_dir, audit_plan.PLAN)
    if not os.path.isfile(path):
        add("C19", 1, f"{audit_plan.PLAN} is missing", "run `appdoc audit-plan`")
        return []
    fresh = audit_plan.compute(target, out_dir)
    if normalize_newlines(read_text(path)) != audit_plan.render(fresh):
        add("C19", 1, f"{audit_plan.PLAN} is not what `appdoc audit-plan` computes now "
            "(the Narrative, the Facts or the audit floor changed)", "run `appdoc audit-plan`, then audit the ids it names")
        return fresh["advisories"]
    if reg is None or not reg.performed:
        return fresh["advisories"]
    ex = (reg.audit or {}).get("exclusions")
    excluded = set(ex) if isinstance(ex, dict) else set()
    live = reg.live_keys()
    for s in fresh["sections"]:
        if s["section"] in excluded:
            continue
        for key in s["ids"]:
            if key not in live:
                add("C19", 1, f"the audit plan names {key}, which has no live register row",
                    f"audit it and add a row with ref {audit_plan.ref_for(key)}")
    return fresh["advisories"]


def coverage_detail(heads, ids, reg, workflows) -> list[tuple[str, list[str], list[str]]]:
    """(section, IDs with a live register row, all IDs) for every ID-bearing section, and workflows."""
    live = reg.live_rows()
    refs = set()
    for _, r in live:
        m = reg_mod.REF_RE.match(str(r["ref"]))
        if m:
            refs.add(m.group(2) or m.group(1))
    out = []
    for key, ts in spec.TABLES.items():
        if ts.id_prefix:
            mine = [i for i in ids if i.startswith(ts.id_prefix)]
            if mine:
                out.append((key, [i for i in mine if i in refs], mine))
    if workflows:
        out.append(("7 (workflows)", [k for k in workflows if k in refs or any(
            str(r["ref"]).startswith(k + "/") for _, r in live)], list(workflows)))
    return out


def coverage(heads, ids, reg, workflows) -> list[tuple[str, int, int]]:
    """(section, IDs with a register row, IDs) for every ID-bearing section, and workflows."""
    return [(key, len(hit), len(mine)) for key, hit, mine in coverage_detail(heads, ids, reg, workflows)]


def run(target: str, out_dir: str, require_audit: bool = False, strict: bool = False) -> int:
    narrative_path = os.path.join(out_dir, NARRATIVE)
    if not os.path.isfile(narrative_path):
        print(f"appdoc check: narrative not found: {narrative_path}", file=sys.stderr)
        return 1
    raw = read_text(narrative_path)
    facts_path = os.path.join(out_dir, FACTS)
    facts = None
    if os.path.isfile(facts_path):
        try:
            facts = json.loads(read_text(facts_path))
        except ValueError as exc:
            print(f"appdoc check: facts.json is not valid JSON: {exc}", file=sys.stderr)
            return 1

    prov = version.read_provenance(out_dir) if facts is not None else None
    text = fingerprint.document_text(raw)
    lines = text.splitlines()
    secs = _sections(lines)
    by_num = {s["num"]: s for s in secs}
    problems: dict[str, list[tuple[int, str, str]]] = {k: [] for k in RULE_TITLES}
    dup_missing: list[dict] = []  # duplicate-folder pairs section 2 does not name (advisory unless --strict)

    def add(rule, line, msg, fix):
        problems[rule].append((line, msg, fix))

    previews: list[tuple[str, int, str, str]] = []  # 2.7 rules on a document older than 2.7: advisory only
    bare: list = []                                  # (line, message, fix) bare names, a C1 2.7 rule

    # C1 + register
    cites = find_citations(text)
    cache: dict = {"__out__": out_dir}
    register = []
    for c in cites:
        ok, why = _resolve(target, cache, c)
        if ok is None:
            continue
        if ok and c.start is not None:
            full = os.path.realpath(os.path.join(os.path.realpath(target), c.path))
            if os.path.isfile(full) and scan.is_binary(full):
                ok = False
                why = f"`{c.path}` is a binary file; cite it without a line"
        register.append((c, ok))
        if ok:
            finding = _c1_bare_finding(target, cache, c)
            if finding:
                bare.append((c.doc_line, *finding))
        if not ok:
            fix = "cite an existing Target-relative path and a line within the file"
            if "does not exist in the Target" in why:
                fix += "; a backticked file name is a Citation; write it without backticks if it does not exist"
            add("C1", c.doc_line, f"citation does not resolve: {why}", fix)

    # C2: per-claim. A security claim must carry at least one lined Citation; a bare
    # mention (no line) is still a resolved Citation (C1) but does not satisfy C2.
    s10 = by_num.get(10)
    if s10:
        _c2_per_claim(lines, s10, add)

    # C3
    stamp = spec.STAMP_RE.search(raw)
    current = bool(stamp) and stamp.group(1) == spec.TEMPLATE_VERSION
    doc_ver = spec.stamp_version(raw)
    # The 2.7 rules are written once. Below the stamp gate they are printed as previews; from 2.7 they fail.
    add27 = add if doc_ver >= FAILS_FROM else (lambda rule, line, msg, fix: previews.append((rule, line, msg, fix)))
    if not current:
        found_v = stamp.group(1) if stamp else "none"
        add("C3", 1, f"the document is not on template {spec.TEMPLATE_VERSION} (stamp: {found_v}); "
                      "structure rules C8-C13 were not run",
            f"upgrade it to the current template ({spec.UPGRADE_NOTES}) and keep `{spec.STAMP}`")
    for m in spec.ORPHAN_RE.finditer(raw):
        add("C3", raw.count("\n", 0, m.start()) + 1, "`appdoc upgrade` left text it could not map to the template "
            f"(an `{spec.ORPHAN_MARK}` comment)",
            "move what still applies into the template's table or section, then delete the leftover text and the comment")
    found = [s["num"] for s in secs]
    doc_sections = spec.sections(doc_ver)
    for n, title in enumerate(doc_sections, 1):
        s = by_num.get(n)
        if not s or not s["title"].lower().startswith(title.lower()):
            add("C3", s["start"] if s else 1, f"section {n} '{title}' is missing or renamed",
                f"add the heading `## {n}. {title}`")
        elif not _content_lines(lines, s):
            add("C3", s["start"], f"section {n} '{title}' has no content",
                "fill it from the Facts file and source, or write Unknown - see Open questions")
    if found != sorted(found) or len(found) != len(set(found)):
        add("C3", 1, "sections are out of order or duplicated",
            f"keep sections 1-{len(doc_sections)} once each, in template order")

    # C8
    for key, title in (REQUIRED_SUBSECTIONS.items() if current else ()):
        parent = by_num.get(int(key.split(".")[0]))
        if not parent:
            continue  # C3 already reports the missing section
        sub = _subsection(lines, parent, key)
        if sub is None:
            add("C8", parent["start"], f"subsection {key} '{title}' is missing",
                f"add `### {key} {title}` inside section {parent['num']}")
        elif not _content_lines(lines, sub):
            add("C8", sub["start"], f"subsection {key} '{title}' has no content",
                "fill it from source, or write Unknown - see Open questions")

    # C4
    s14 = by_num.get(14)
    if s14 and not _content_lines(lines, s14):
        outside = [i + 1 for i, l in enumerate(lines)
                   if _UNKNOWN_RE.search(l) and not (s14["idx"] <= i < s14["end"]) and not l.lstrip().startswith("#")]
        if outside:
            add("C4", s14["start"], f"section 14 is empty but Unknown appears at line {outside[0]}"
                + (f" (and {len(outside) - 1} more)" if len(outside) > 1 else ""),
                "list every Unknown as a row of section 14")
    s8 = by_num.get(8)
    if facts and s8 and not _content_lines(lines, s8):
        kinds = sorted({f.get("kind") for f in facts.get("facts", [])} & {"connection", "data_access", "external_call"})
        if kinds:
            add("C4", s8["start"], f"section 8 is empty but facts.json has {', '.join(kinds)} facts",
                "document the connections, SQL and external calls, or state Unknown")

    absent = _absent_owner_advisories(lines, by_num, facts)

    # C5
    c5 = []
    for n in range(3, 11):
        s = by_num.get(n)
        if not s:
            continue
        for no, blk in _blocks(lines, s["idx"] + 1, s["end"]):
            if len(blk) < C5_MIN_LEN or blk.endswith(":") or blk == spec.RESTRICTION_LINE:
                continue
            if find_citations(blk) or "**Inferred:**" in blk or _UNKNOWN_RE.search(blk):
                continue
            c5.append((no, f"section {n} claim has no Citation, **Inferred:** marker or Unknown",
                       "add a Citation (`path:line`), prefix with **Inferred:**, or mark Unknown"))
    problems["C5"] = c5[:C5_CAP]
    if len(c5) > C5_CAP:
        problems["C5"].append((c5[C5_CAP][0], f"... {len(c5) - C5_CAP} more", "fix the above, then rerun"))

    # C6: every published file (the Narrative and the Evidence Register)
    published = [("", raw)]
    reg_path = os.path.join(out_dir, REGISTER)
    if os.path.isfile(reg_path):
        published.append((f"{REGISTER} ", read_text(reg_path)))
    terms = _never_mention(target)
    for label, body in published:
        for no, shape in find_secret_shapes(body):
            add("C6", no, f"{label}secret-shaped value ({shape}); value not shown".strip(),
                'remove it, write "value omitted" and cite the location')
        body_lower = body.lower()
        for term in terms:
            t = term.lower()
            for i, l in enumerate(body_lower.splitlines(), 1):
                if t in l:
                    add("C6", i, f"{label}never-mention term '{term}' appears".strip(), "remove or generalize the term")

    # C7
    s2 = by_num.get(2)
    if facts:
        sec2 = "\n".join(lines[s2["idx"]: s2["end"]]).lower() if s2 else ""
        # Version skew: provenance.json (written by extract) records the AppDoc that wrote the Facts.
        # Only a major.minor difference fails, so a patch bump (2.6.0 vs 2.6.1) is fine. A missing
        # file (Facts from before 2.6) is an advisory, never a failure.
        if prov is not None:
            gen = str(prov.get("generator") or "")
            if gen and spec.version_tuple(gen)[:2] != spec.version_tuple(__version__)[:2]:
                add("C7", 1, f"facts.json was written by AppDoc {gen}; re-run extract",
                    f"re-run `appdoc extract` with AppDoc {__version__}")
            if prov.get("schema") and facts.get("schema") and prov["schema"] != facts["schema"]:
                add("C7", 1, f"provenance.json schema {prov['schema']} does not match facts.json schema "
                    f"{facts['schema']}; re-run extract", "re-run `appdoc extract` so both files come from one run")
        for st in facts.get("stacks", []):
            if (st.get("detail") or {}).get("supported") is False and st.get("name", "").lower() not in sec2:
                add("C7", s2["start"] if s2 else 1, f"unsupported stack '{st.get('name')}' is not named in section 2",
                    "name it in 2.1 and say it was not extracted")
        # A name-signal candidate (a folder literally named old/To be deleted/...) must be addressed
        # in section 2 prose. Content-signal candidates are advisory only (rendered in scan-coverage).
        # Generated blocks are masked so the scan-coverage list of candidates does not count as naming.
        if s2:
            masked = dm.strip_comments(dm.mask_blocks(normalize_newlines(raw),
                                                          tuple(spec.GENERATED.values()))).splitlines()
            msecs = _sections(masked)
            ms2 = next((s for s in msecs if s["num"] == 2), None)
            sec2_prose = "\n".join(masked[ms2["idx"]: ms2["end"]]).lower() if ms2 else ""
            for cand in (facts.get("target") or {}).get("scan", {}).get("retired_candidates", []):
                if cand.get("signal") != "name":
                    continue
                name = cand["path"].rstrip("/").rsplit("/", 1)[-1]
                if not re.search(r"(?<!\w)" + re.escape(name.lower()) + r"(?!\w)", sec2_prose):
                    add("C7", s2["start"],
                        f"folder '{name}' looks retired but is not named in section 2",
                        "name it in 2.1 and record the decision: documented as live, or excluded via .appdocignore")
            # A duplicate pair (byte-identical folders) should be named in section 2 too, saying which copy is
            # live: an advisory, and a C7 failure under --strict.
            for pair in (facts.get("target") or {}).get("scan", {}).get("duplicate_folders", []):
                sides = [pair[k].rstrip("/") for k in ("a", "b")]
                if all(re.search(r"(?<!\w)" + re.escape(x.rsplit("/", 1)[-1].lower()) + r"(?!\w)", sec2_prose)
                       for x in sides):
                    continue
                if strict:
                    add("C7", s2["start"],
                        f"folders '{sides[0]}' and '{sides[1]}' duplicate each other but are not both named in section 2",
                        "name both in 2.1 and say which copy is live")
                else:
                    dup_missing.append(pair)

    # C7 (counts and generated blocks), C9, C10, C11: template-2.2 structure
    reg, cov, uncited, quant_hits, wide_hits, count_advice = None, [], [], [], [], []
    floor_advice, exclusions = [], {}
    if current:
        heads = dm.headings(lines)
        _c7_counts(target, lines, heads, facts, add)
        _c7_prose(lines, by_num, facts, add)
        _c7_blocks(raw, heads, facts, out_dir, target, add, doc_ver)
        _c9_tables(lines, raw, heads, add)
        _c9_build_rows(lines, heads, add)
        ids = defined_ids(lines, heads, add)
        smell_fids = None if facts is None else {
            f["detail"].get("fid") for f in facts.get("facts", []) if f.get("kind") == "smell"}
        reg, cov = _c11_register(target, out_dir, lines, heads, ids, cache, require_audit, smell_fids, add,
                                 doc_ver=doc_ver, add27=add27)
        appendix = next((body for name, body, _ in fill_mod.blocks(raw) if name == "appendix-a"), "")
        _c14_unknowns(lines, heads, ids, reg, appendix, add)
        count_advice: list = []
        if doc_ver >= FAILS_FROM:   # a stronger structural rule replaces the English one (P2, Q2)
            count_advice = [(no, text) for no, text, *_ in _c15_sentences(
                fingerprint.document_text(raw, mask_counts=True).splitlines(), ids)]
        else:
            _c15_register_counts(lines, ids, reg, add)
        _c15_markers(raw, facts, ids, reg, add27)
        quant_hits = _c16_quantifier(lines, cites, add, strict)
        generated = tuple(spec.GENERATED.values())
        glines = dm.strip_comments(dm.mask_blocks(normalize_newlines(raw), generated)).splitlines()
        wide_hits = _c20_precision(glines, dm.headings(glines))
        for no, msg in wide_hits:
            if strict:
                add("C20", no, msg, _C20_FIX)
        _c9_severity_order(lines, heads, add27)
        for no, msg, fix in bare:
            add27("C1", no, msg, fix)
        _c17_scope(reg, heads, add27)
        _c18_notes(target, out_dir, raw, facts, cache, add27)
        if doc_ver >= FAILS_FROM:
            _c17_provenance(reg, require_audit, strict, add)
            if require_audit:
                floor_advice = _c19_plan(target, out_dir, reg, add)
            if reg is not None and reg.performed:
                exclusions = (reg.audit or {}).get("exclusions")
                exclusions = exclusions if isinstance(exclusions, dict) else {}
        reg_ids = {str(r["id"]) for _, r in reg.live_rows()} if reg else None   # a superseded row is history
        gone = {t: reg.superseded_by(t) for t in reg.superseded_ids()} if reg else None
        _c10_refs(lines, heads, ids, reg_ids, add, gone)
        _c10_coverage(lines, heads, facts, add)
        if facts is not None:
            _c12_smells(target, cache, lines, heads, facts, reg, add)
            uncited = _uncited_entry_points(target, cache, facts, cites)
            if strict:
                h4 = heads.get("4")
                at = h4.idx + 1 if h4 else 1
                for folder, n, first in uncited[:FOLDER_CAP]:
                    add("C13", at, f"{n} entry point file{'s' if n != 1 else ''} under {folder} not cited "
                        f"(first {len(first)}: {', '.join(f'`{p}`' for p in first)})",
                        "cite the handler file with `path:line` where the document describes it")
                if len(uncited) > FOLDER_CAP:
                    add("C13", at, f"... {len(uncited) - FOLDER_CAP} more folders", "fix the above, then rerun")

    for k in problems:
        items = problems[k] if k == "C5" else sorted(set(problems[k]), key=lambda p: (p[0], p[1]))
        if k in ("C9", "C10", "C11", "C12", "C13", "C19") and len(items) > RULE_CAP:
            items = items[:RULE_CAP] + [(items[RULE_CAP][0], f"... {len(items) - RULE_CAP} more", "fix the above, then rerun")]
        problems[k] = items
    total = sum(len(v) for v in problems.values())

    body = []
    for rule, items in problems.items():
        if items:
            body.append(f"## {rule} {RULE_TITLES[rule]}")
            body += [f"- line {no}: {msg}. Fix: {fix}" for no, msg, fix in items]
            body.append("")
    advisory = []
    if uncited and not strict:
        files = sum(n for _, n, _ in uncited)
        advisory = ["## Entry points not cited (advisory)", "",
                    f"{files} entry point file{'s' if files != 1 else ''} in {len(uncited)} folder"
                    f"{'s' if len(uncited) != 1 else ''} not cited anywhere in the document. This is not a problem; "
                    "`appdoc check --strict` fails on it.", "", "| Folder | Files | First paths |", "|---|---|---|"]
        advisory += [f"| `{folder}` | {n} | {', '.join(f'`{p}`' for p in first)} |" for folder, n, first in uncited[:FOLDER_CAP]]
        if len(uncited) > FOLDER_CAP:
            advisory.append(f"| {len(uncited) - FOLDER_CAP} more folders | | |")
        advisory.append("")
    if quant_hits and not strict:
        advisory += ["## Universal claims cite single lines (advisory)", "",
                     f"{len(quant_hits)} universal claim{'s' if len(quant_hits) != 1 else ''} "
                     f"{'cite' if len(quant_hits) != 1 else 'cites'} only single lines. "
                     "This is not a problem; `appdoc check --strict` fails on it.", ""]
        advisory += [f"- line {no}: `{text}`" for no, text in quant_hits[:RULE_CAP]]
        advisory.append("")
    if wide_hits and not strict:
        advisory += ["## Citation precision (advisory)", "",
                     f"{len(wide_hits)} citation{'s are' if len(wide_hits) != 1 else ' is'} broader than the claim "
                     f"needs. This is not a problem; `appdoc check --strict` fails on it. Fix: {_C20_FIX}.", ""]
        advisory += [f"- line {no}: {msg}" for no, msg in wide_hits[:RULE_CAP]]
        if len(wide_hits) > RULE_CAP:
            advisory.append(f"- ... {len(wide_hits) - RULE_CAP} more")
        advisory.append("")
    if exclusions:
        advisory += ["## Audit exclusions", "", "The audit record declares sections the audit did not cover:", ""]
        advisory += [f"- {sec}: {why}" for sec, why in sorted(exclusions.items())] + [""]
    if floor_advice:
        advisory += ["## Audit floor (advisory)", ""] + [f"- {a}" for a in floor_advice] + [""]
    if count_advice:
        advisory += ["## Hand-written counts (advisory)", "",
                     f"{plural(len(count_advice), 'count')} written by hand. This is not a problem; a count marker "
                     "(`<!-- appdoc:count R -->13<!-- /appdoc:count -->`) is filled by `appdoc fill`, so it cannot "
                     "go stale. Fix: use a count marker.", ""]
        advisory += [f"- line {no}: `{text}` is a hand-written count; use a count marker" for no, text in count_advice[:RULE_CAP]]
        advisory.append("")
    if previews:
        previews = sorted(set(previews), key=lambda p: (p[0], p[1], p[2]))
        advisory += [PREVIEW_HEADING, "",
                     f"{len(previews)} finding{'s' if len(previews) != 1 else ''} would fail a template "
                     f"{'.'.join(map(str, FAILS_FROM))} document. This document is on template {stamp.group(1)}, "
                     "so none of them fails it; they need no action yet.", ""]
        advisory += [f"- {rule} line {no}: {msg}. Fix: {fix} (fails from template {'.'.join(map(str, FAILS_FROM))})"
                     for rule, no, msg, fix in previews[:RULE_CAP]]
        if len(previews) > RULE_CAP:
            advisory.append(f"- ... {len(previews) - RULE_CAP} more")
        advisory.append("")
    if dup_missing:
        advisory += ["## Duplicate folders not named in section 2 (advisory)", "",
                     f"{plural(len(dup_missing), 'pair')} of byte-identical folders "
                     f"{'is' if len(dup_missing) == 1 else 'are'} not named in section 2. This is not a problem; "
                     "name both in 2.1 and say which copy is live. `appdoc check --strict` fails on it.", ""]
        advisory += [f"- `{d['a']}` and `{d['b']}` ({plural(d['files'], 'file')})" for d in dup_missing[:RULE_CAP]]
        advisory.append("")
    if facts is not None and prov is None:
        advisory += ["## Provenance missing (advisory)", "",
                     f"`{version.PROVENANCE_FILE}` is not beside facts.json, so the AppDoc version that wrote the "
                     "Facts is unknown and version skew was not checked. Re-run `appdoc extract` to write it.", ""]
    if absent:
        advisory += ["## Gaps declared: Unknown by absence", "Advisory only; this is not a problem.", ""] + [f"- {m}" for m in absent] + [""]
    head = "# Check: PASS" if total == 0 else f"# Check: FAIL ({total} problem{'s' if total != 1 else ''})"
    cite_reg = ["## Citation register", "", "| Doc line | Cited path | Line/range | Resolved |", "|---|---|---|---|"]
    for c, ok in sorted(register, key=lambda r: (r[0].doc_line, r[0].raw)):
        rng = "" if c.start is None else (str(c.start) if c.start == c.end else f"{c.start}-{c.end}")
        cite_reg.append(f"| {c.doc_line} | `{c.path}` | {rng} | {'yes' if ok else 'no'} |")

    scope = [
        f"**Scope.** Run by AppDoc {__version__} (bundle {version.bundle_hash()[:version.BUNDLE_LEN]}). This Check verifies **resolution and structure**: "
        "every Citation points to a real file and line inside the Target (see the Citation register), "
        "and every Evidence Register row's anchor text appears in the lines it cites. It does **not** "
        "judge whether a claim's wording follows from those lines; that is the source-to-claim audit, "
        f"recorded in `{REGISTER}`. A PASS is not an accuracy certification.",
        "",
    ]

    verification = ["## Verification", ""]
    if reg is None:
        verification.append(f"**Source-to-claim audit:** not declared (`{REGISTER}` missing or not checked).")
        verification_status = "Source-to-claim audit: not declared."
    elif not reg.performed:
        why = (reg.audit or {}).get("scope") or "no reason given"
        verification.append(f"**Source-to-claim audit:** not performed ({why}). The HTML shows a banner.")
        verification_status = "Source-to-claim audit: declared not performed."
    else:
        live = reg.live_rows()
        c = reg.counts(live)
        n_old = len(reg.rows) - len(live)
        verification += [
            f"**Source-to-claim audit:** performed (auditor: {reg.audit.get('auditor')}). "
            f"{len(live)} rows{f' ({n_old} superseded)' if n_old else ''}: {c['Supported']} Supported, {c['Corrected']} Corrected, "
            f"{c['Downgraded']} Downgraded"
            + "".join(f", {c[r]} {r}" for r in ("Dismissed", "Answerable") if c[r]) + ".", "",
            "| Section | IDs with a register row |", "|---|---|",
        ] + [f"| {s} | {hit} of {n} |" for s, hit, n in cov]
        verification_status = f"Source-to-claim audit: {len(live)} rows ({reg.audit.get('auditor')})."

    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, REPORT), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join([head, ""] + scope + body + advisory + cite_reg + [""] + verification) + "\n")
    note = []
    if uncited and not strict:
        note.append(f"Advisory: {sum(n for _, n, _ in uncited)} entry point files are not cited (see {REPORT}).")
    if dup_missing:
        note.append(f"Advisory: {plural(len(dup_missing), 'duplicate folder pair')} "
                    f"{'is' if len(dup_missing) == 1 else 'are'} not named in section 2 (see {REPORT}).")
    if quant_hits and not strict:
        note.append(f"Advisory: {len(quant_hits)} universal claim{'s' if len(quant_hits) != 1 else ''} "
                    f"{'cite' if len(quant_hits) != 1 else 'cites'} only single lines (see {REPORT}).")
    if wide_hits and not strict:
        note.append(f"Advisory: {len(wide_hits)} wide range or crowded cell{'s' if len(wide_hits) != 1 else ''} "
                    f"(citation precision, see {REPORT}).")
    if count_advice:
        note.append(f"Advisory: {plural(len(count_advice), 'hand-written count')}; use a count marker (see {REPORT}).")
    if previews:
        note.append(f"Advisory: {len(previews)} finding{'s' if len(previews) != 1 else ''} fail from template "
                    f"{'.'.join(map(str, FAILS_FROM))} (see {REPORT}).")
    print("\n".join([head] + [b for b in body if b] + note + [verification_status]))
    return 0 if total == 0 else 2
