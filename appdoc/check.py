"""The Check: pass/fail verification of a finished Narrative (rules C1-C13). No score, no warnings."""

from __future__ import annotations

import hashlib
import json
import os
import re
import sys

from . import __version__
from . import context
from . import docmodel as dm
from . import fill as fill_mod
from . import register as reg_mod
from . import scan
from . import template_spec as spec
from .citations import OWNER_CONTEXT, Citation, find_citations, parse_span
from .facts import fact_id
from .secrets import find_secret_shapes

NARRATIVE = "application-documentation.md"
FACTS = "facts.json"
REPORT = "check-report.md"
REGISTER = reg_mod.REGISTER


def _major_minor(version: str) -> str | None:
    """The major.minor of a dotted version string, or None if it is not dotted numeric."""
    parts = version.split(".")
    if len(parts) >= 2 and parts[0].isdigit() and parts[1].isdigit():
        return f"{parts[0]}.{parts[1]}"
    return None

SECTIONS = list(spec.SECTIONS)
REQUIRED_SUBSECTIONS = spec.REQUIRED_SUBSECTIONS
RULE_TITLES = {
    "C1": "Citations resolve", "C2": "Security lines", "C3": "Sections complete", "C4": "Gaps declared",
    "C5": "Claims grounded", "C6": "No secrets", "C7": "Coverage honest", "C8": "Structure complete",
    "C9": "Tables conform", "C10": "References resolve", "C11": "Register valid",
    "C12": "Finding candidates addressed", "C13": "Entry points not cited",  # C13 fails only under --strict
    "C14": "Unknowns match the register", "C15": "Register counts in prose",
    "C16": "Universal claims cite single lines",  # C16 is advisory; fails only under --strict
}
C5_CAP = 30
C5_MIN_LEN = 40
RULE_CAP = 50  # C9-C13 on a large document: show the first problems, count the rest
FOLDER_CAP = 30  # folders listed under "Entry points not cited"
ENTRY_TYPES = ("route", "page", "command", "job")

_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
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


def _read_text(path: str) -> str:
    with open(path, "rb") as fh:
        raw = fh.read()
    try:
        return raw.decode("utf-8")
    except UnicodeDecodeError:
        return raw.decode("cp1252", errors="replace")


def _strip_comments(text: str) -> str:
    """Remove HTML comments but keep line numbering intact."""
    return _COMMENT_RE.sub(lambda m: "\n" * m.group(0).count("\n"), text)


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
        cache[full] = len(_read_text(full).splitlines())
    n = cache[full]
    if c.start < 1 or c.end < c.start or c.end > n:
        return False, f"line {c.raw.rsplit(':', 1)[1]} is outside `{c.path}` ({n} lines)"
    return True, ""


def _never_mention(target: str) -> list[str]:
    path = os.path.join(target, OWNER_CONTEXT)
    return context.parse(_read_text(path) if os.path.isfile(path) else None).never_mention


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


def _c10_refs(lines, heads, ids, register_ids, add):
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
            if vid.startswith("V-") and vid not in named:
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


_CONFIG_SHOWN_RE = re.compile(r"Shown \d+ of (\d+) application keys")


def _c7_config_count(body: str, line: int, facts, add):
    """The 16.6 block's "N of M application keys" must equal the Facts' application-role key count."""
    m = _CONFIG_SHOWN_RE.search(body)
    if m and facts is not None and int(m.group(1)) != (n := fill_mod.config_app_count(facts)):
        add("C7", line, f"16.6 states {m.group(1)} application keys but the Facts count {n} with role app",
            "run `appdoc fill <target>`; never edit a generated block by hand")


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


def _c12_smells(target, cache, lines, heads, facts, reg, add):
    """Every non-test smell Fact is cited in a 10.1 row (path and a line that covers it) or dismissed."""
    smells = sorted((f for f in facts.get("facts", []) if f.get("kind") == "smell" and not f["detail"].get("test")),
                    key=lambda f: (f["path"], f.get("line") or 0, f["detail"].get("fid", "")))
    if not smells:
        return
    spans: list[tuple[str, int | None, int | None]] = []
    t = _spec_table(lines, heads, "10.1")
    for _, cells in (t.rows if t else ()):
        for c in find_citations(" ".join(cells)):
            for p in _cited_paths(target, cache, [c]):
                spans.append((p, c.start, c.end))
    dismissed = set()
    for _, row in (reg.rows if reg else ()):
        m = reg_mod.SMELL_REF_RE.match(str(row["ref"]))
        if m and row["result"] == "Dismissed" and str(row["limitation"]).strip():
            dismissed.add(m.group(1))
    h = heads.get("10.1")
    for f in smells:
        d = f["detail"]
        fid = d.get("fid") or fact_id("smell", d.get("pattern", ""), f["path"], f.get("line"))
        ln = f.get("line")
        if fid in dismissed or any(p == f["path"] and (ln is None or (s is not None and s <= ln <= e))
                                   for p, s, e in spans):
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


def _c7_blocks(raw, heads, facts, out_dir, target, add):
    ctx = {"out_dir": out_dir, "text": raw, "target": target}
    found = {name: (body, line) for name, body, line in fill_mod.blocks(raw.replace("\r\n", "\n"))}
    for key, name in spec.GENERATED.items():
        h = heads.get(key)
        line = h.idx + 1 if h else 1
        if name not in found:
            add("C7", line, f"generated block '{name}' is missing from {key}",
                "copy its appdoc:generated markers from the template, then run `appdoc fill`")
            continue
        if name == "config-reference":
            _c7_config_count(found[name][0], found[name][1], facts, add)
        if facts is not None and found[name][0] != (fill_mod.render_block(name, facts, ctx) or "").strip():
            add("C7", found[name][1], f"generated block '{name}' differs from the Facts",
                "run `appdoc fill <target>`; never edit a generated block by hand")


def _claim_sha(lines, heads, ids, ref):
    """12-hex-char SHA-1 over the normalised text a ref points to. None if the ref is unresolvable."""
    m = reg_mod.REF_RE.match(ref)
    if not m:
        return None
    sec_key, id_part = m.group(1), m.group(2)
    if id_part and id_part in ids:
        # ID ref: the table row that defines the ID
        no = ids[id_part]
        text = lines[no - 1]
    elif sec_key.startswith("7.") and sec_key in heads:
        # workflow: the subsection
        h = heads[sec_key]
        text = "\n".join(lines[h.idx + 1: h.own_end])
    elif sec_key in heads:
        # section-level: the section with generated blocks masked
        h = heads[sec_key]
        text = fill_mod.mask_blocks("\n".join(lines[h.idx: h.end]), spec.OPAQUE_BLOCKS)
    else:
        return None
    text = dm.strip_comments(text)
    text = " ".join(text.split())
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:12]


def seal_register(target, out_dir) -> int:
    """Write claim_sha into every ID/workflow register row that lacks one. Returns rows sealed."""
    md_path = os.path.join(out_dir, NARRATIVE)
    reg_path = os.path.join(out_dir, REGISTER)
    if not os.path.isfile(md_path) or not os.path.isfile(reg_path):
        return 0
    raw = _read_text(md_path)
    lines = _strip_comments(fill_mod.mask_blocks(raw.replace("\r\n", "\n"), spec.OPAQUE_BLOCKS)).splitlines()
    heads = dm.headings(lines)
    ids = defined_ids(lines, heads, lambda *a: None)
    reg = reg_mod.parse(_read_text(reg_path))
    claim_shas: dict[str, str] = {}
    for _, row in reg.rows:
        if row["result"] in ("Dismissed", "Answerable"):
            continue
        m = reg_mod.REF_RE.match(str(row["ref"]))
        if not m:
            continue
        sec_key, id_part = m.group(1), m.group(2)
        if not (id_part or sec_key.startswith("7.")):
            continue
        sha = _claim_sha(lines, heads, ids, str(row["ref"]))
        if sha:
            claim_shas[str(row["id"])] = sha
    return reg_mod.seal(reg_path, claim_shas)


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


def _c11_register(target, out_dir, lines, heads, ids, cache, require_audit, smell_fids, add,
                  doc_ver=()):
    """Validate evidence.jsonl. Returns (Register or None, coverage rows)."""
    path = os.path.join(out_dir, REGISTER)
    if not os.path.isfile(path):
        add("C11", 1, "the audit state is not declared",
            f'write {REGISTER}: the audit record, then one row per audited claim; or line 1 '
            '{"type": "audit", "performed": false, "scope": "<why>"}')
        return None, []
    reg = reg_mod.parse(_read_text(path))
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
    for no, row in reg.rows:
        where = f"{REGISTER} line {no}"
        rid = str(row["id"])
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
            if am.group(1) in ids:   # a question that was closed and removed is no longer a problem
                shown = ", ".join(str(c).strip("`") for c in row["cites"]) or "no citation recorded"
                add("C11", no, f"{where}: {am.group(1)} can be closed from source ({shown}); "
                    "close it and remove the question", f"answer {am.group(1)} in the document, then delete it from section 14")
        elif not m or m.group(1) not in heads:
            add("C11", no, f"{where}: ref '{row['ref']}' names no section or subsection",
                "use a heading number such as 7.3, optionally with an ID: 10.1/V-2")
        elif m.group(2) and m.group(2) not in ids:
            add("C11", no, f"{where}: ref '{row['ref']}' names an ID that is not defined", "use an ID from the document")
        else:
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
        if anchor and row["result"] in ("Supported", "Corrected"):
            loc = reg_mod.locate(target, row)
            if loc is None:
                add("C11", no, f"{where}: anchor not found on a single cited line (exact, case-sensitive)",
                    "copy the anchor exactly from one line of the cited lines")
    # claim_sha checks (1.2): ID and workflow rows must be sealed; Dismissed/Answerable are exempt.
    # Activates when the template version reaches 2.4 (Phase 3).
    if doc_ver >= (2, 4):
        id_ref_rows: dict[str, list[tuple[int, dict]]] = {}
        for no, row in reg.rows:
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
                    add("C11", no, f"{REGISTER} line {no}: two rows for the same ID ref {ref_key}",
                        "keep the row that describes the current text")
            no, row = rows[0]
            where = f"{REGISTER} line {no}"
            expected = _claim_sha(lines, heads, ids, ref_key)
            if expected is None:
                continue
            if "claim_sha" not in row:
                add("C11", no, f"{where}: not sealed; run `appdoc build`",
                    "run `appdoc build <target>` to seal the register")
            elif row["claim_sha"] != expected:
                add("C11", no, f"{where}: the text of {ref_key} changed after it was audited; re-audit it and replace the row",
                    "re-audit the claim and rewrite the row without claim_sha, then run `appdoc build`")
    for vid, no in ids.items():
        if vid.startswith("V-") and vid not in covered:
            add("C11", no, f"finding {vid} has no register row", f"audit {vid} and add a row with ref 10.1/{vid}")
    workflows = sorted((k for k in heads if k.startswith("7.")), key=lambda k: int(k.split(".")[1]))
    for k in workflows:
        if k not in covered and not any(str(r["ref"]).startswith(k + "/") for _, r in reg.rows):
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
    q_rows = [(no, row, m.group(1)) for no, row in reg.rows if (m := _Q_REF_RE.match(str(row.get("ref", ""))))]
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
_C15_NOUNS = {"recommendation": "R-", "finding": "V-", "v-finding": "V-", "unknown": "Q-"}
_C15_RE = re.compile(r"\b(\d+) of (\d+)\s+([A-Za-z-]+)")


def _c15_register_counts(lines, ids, reg, add):
    """Every 'N of M <noun>' sentence must agree with the doc's table total and the register."""
    if reg is None or not reg.performed:
        return
    refs = set()
    for _, row in reg.rows:
        m = reg_mod.REF_RE.match(str(row.get("ref", "")))
        if m:
            refs.add(m.group(2) or m.group(1))
    for i, line in enumerate(lines):
        for m in _C15_RE.finditer(line):
            noun = m.group(3).lower().rstrip("s")
            prefix = _C15_NOUNS.get(noun)
            if not prefix:
                continue
            n, total = int(m.group(1)), int(m.group(2))
            doc_total = sum(1 for k in ids if k.startswith(prefix))
            if doc_total and total != doc_total:
                add("C15", i + 1, f'states "{m.group(0).strip()}" but the document has {doc_total} {noun}s',
                    "reword the sentence to the current table total, or run `appdoc fill`")
                continue
            reg_count = sum(1 for k in refs if k.startswith(prefix))
            if reg_count and n != reg_count:
                add("C15", i + 1, f'states "{m.group(0).strip()}" but the register has {reg_count} {noun}s with a row',
                    "reword the sentence to the current register count, or run `appdoc fill`")


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


def coverage(heads, ids, reg, workflows) -> list[tuple[str, int, int]]:
    """(section, IDs with a register row, IDs) for every ID-bearing section, and workflows."""
    refs = set()
    for _, r in reg.rows:
        m = reg_mod.REF_RE.match(str(r["ref"]))
        if m:
            refs.add(m.group(2) or m.group(1))
    out = []
    for key, ts in spec.TABLES.items():
        if ts.id_prefix:
            mine = [i for i in ids if i.startswith(ts.id_prefix)]
            if mine:
                out.append((key, sum(1 for i in mine if i in refs), len(mine)))
    if workflows:
        out.append(("7 (workflows)", sum(1 for k in workflows if k in refs or any(
            str(r["ref"]).startswith(k + "/") for _, r in reg.rows)), len(workflows)))
    return out


def run(target: str, out_dir: str, require_audit: bool = False, strict: bool = False) -> int:
    narrative_path = os.path.join(out_dir, NARRATIVE)
    if not os.path.isfile(narrative_path):
        print(f"appdoc check: narrative not found: {narrative_path}", file=sys.stderr)
        return 1
    raw = _read_text(narrative_path)
    facts_path = os.path.join(out_dir, FACTS)
    facts = None
    if os.path.isfile(facts_path):
        try:
            facts = json.loads(_read_text(facts_path))
        except ValueError as exc:
            print(f"appdoc check: facts.json is not valid JSON: {exc}", file=sys.stderr)
            return 1

    text = _strip_comments(fill_mod.mask_blocks(raw.replace("\r\n", "\n"), spec.OPAQUE_BLOCKS))
    lines = text.splitlines()
    secs = _sections(lines)
    by_num = {s["num"]: s for s in secs}
    problems: dict[str, list[tuple[int, str, str]]] = {k: [] for k in RULE_TITLES}

    def add(rule, line, msg, fix):
        problems[rule].append((line, msg, fix))

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
        if not ok:
            add("C1", c.doc_line, f"citation does not resolve: {why}",
                "cite an existing Target-relative path and a line within the file")

    # C2: per-claim. A security claim must carry at least one lined Citation; a bare
    # mention (no line) is still a resolved Citation (C1) but does not satisfy C2.
    s10 = by_num.get(10)
    if s10:
        _c2_per_claim(lines, s10, add)

    # C3
    stamp = spec.STAMP_RE.search(raw)
    current = bool(stamp) and stamp.group(1) == spec.TEMPLATE_VERSION
    if not current:
        found_v = stamp.group(1) if stamp else "none"
        add("C3", 1, f"the document is not on template {spec.TEMPLATE_VERSION} (stamp: {found_v}); "
                      "structure rules C8-C13 were not run",
            f"upgrade it to the current template ({spec.UPGRADE_NOTES}) and keep `{spec.STAMP}`")
    found = [s["num"] for s in secs]
    for n, title in enumerate(SECTIONS, 1):
        s = by_num.get(n)
        if not s or not s["title"].lower().startswith(title.lower()):
            add("C3", s["start"] if s else 1, f"section {n} '{title}' is missing or renamed",
                f"add the heading `## {n}. {title}`")
        elif not _content_lines(lines, s):
            add("C3", s["start"], f"section {n} '{title}' has no content",
                "fill it from the Facts file and source, or write Unknown - see Open questions")
    if found != sorted(found) or len(found) != len(set(found)):
        add("C3", 1, "sections are out of order or duplicated", "keep sections 1-16 once each, in template order")

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
        published.append((f"{REGISTER} ", _read_text(reg_path)))
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
        # Version skew: facts.json records the AppDoc version that wrote it (generator).
        # A missing generator (older Facts) is treated as no skew. Only a major.minor
        # difference fails, so a patch bump (2.3.0 vs 2.3.1) is fine.
        gen = facts.get("generator")
        if gen:
            gen_mm = _major_minor(gen)
            if gen_mm and _major_minor(__version__) != gen_mm:
                add("C7", 1, f"facts.json was written by AppDoc {gen}; re-run extract",
                    f"re-run `appdoc extract` with AppDoc {__version__}")
        for st in facts.get("stacks", []):
            if (st.get("detail") or {}).get("supported") is False and st.get("name", "").lower() not in sec2:
                add("C7", s2["start"] if s2 else 1, f"unsupported stack '{st.get('name')}' is not named in section 2",
                    "name it in 2.1 and say it was not extracted")
        # A name-signal candidate (a folder literally named old/To be deleted/...) must be addressed
        # in section 2 prose. Content-signal candidates are advisory only (rendered in scan-coverage).
        # Generated blocks are masked so the scan-coverage list of candidates does not count as naming.
        if s2:
            masked = _strip_comments(fill_mod.mask_blocks(raw.replace("\r\n", "\n"),
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

    # C7 (counts and generated blocks), C9, C10, C11: template-2.2 structure
    reg, cov, uncited, quant_hits = None, [], [], []
    if current:
        heads = dm.headings(lines)
        _c7_counts(target, lines, heads, facts, add)
        _c7_prose(lines, by_num, facts, add)
        _c7_blocks(raw, heads, facts, out_dir, target, add)
        _c9_tables(lines, raw, heads, add)
        ids = defined_ids(lines, heads, add)
        smell_fids = None if facts is None else {
            f["detail"].get("fid") for f in facts.get("facts", []) if f.get("kind") == "smell"}
        reg, cov = _c11_register(target, out_dir, lines, heads, ids, cache, require_audit, smell_fids, add,
                                 doc_ver=spec.version_tuple(stamp.group(1) if stamp else ""))
        appendix = next((body for name, body, _ in fill_mod.blocks(raw) if name == "appendix-a"), "")
        _c14_unknowns(lines, heads, ids, reg, appendix, add)
        _c15_register_counts(lines, ids, reg, add)
        quant_hits = _c16_quantifier(lines, cites, add, strict)
        reg_ids = {str(r["id"]) for _, r in reg.rows} if reg else None
        _c10_refs(lines, heads, ids, reg_ids, add)
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
        if k in ("C9", "C10", "C11", "C12", "C13") and len(items) > RULE_CAP:
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
    if absent:
        advisory += ["## Gaps declared: Unknown by absence", "Advisory only; this is not a problem.", ""] + [f"- {m}" for m in absent] + [""]
    head = "# Check: PASS" if total == 0 else f"# Check: FAIL ({total} problem{'s' if total != 1 else ''})"
    cite_reg = ["## Citation register", "", "| Doc line | Cited path | Line/range | Resolved |", "|---|---|---|---|"]
    for c, ok in sorted(register, key=lambda r: (r[0].doc_line, r[0].raw)):
        rng = "" if c.start is None else (str(c.start) if c.start == c.end else f"{c.start}-{c.end}")
        cite_reg.append(f"| {c.doc_line} | `{c.path}` | {rng} | {'yes' if ok else 'no'} |")

    scope = [
        f"**Scope.** Run by AppDoc {__version__}. This Check verifies **resolution and structure**: "
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
        c = reg.counts()
        verification += [
            f"**Source-to-claim audit:** performed (auditor: {reg.audit.get('auditor')}). "
            f"{len(reg.rows)} rows: {c['Supported']} Supported, {c['Corrected']} Corrected, "
            f"{c['Downgraded']} Downgraded"
            + "".join(f", {c[r]} {r}" for r in ("Dismissed", "Answerable") if c[r]) + ".", "",
            "| Section | IDs with a register row |", "|---|---|",
        ] + [f"| {s} | {hit} of {n} |" for s, hit, n in cov]
        verification_status = f"Source-to-claim audit: {len(reg.rows)} rows ({reg.audit.get('auditor')})."

    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, REPORT), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join([head, ""] + scope + body + advisory + cite_reg + [""] + verification) + "\n")
    note = []
    if uncited and not strict:
        note.append(f"Advisory: {sum(n for _, n, _ in uncited)} entry point files are not cited (see {REPORT}).")
    if quant_hits and not strict:
        note.append(f"Advisory: {len(quant_hits)} universal claim{'s' if len(quant_hits) != 1 else ''} "
                    f"{'cite' if len(quant_hits) != 1 else 'cites'} only single lines (see {REPORT}).")
    print("\n".join([head] + [b for b in body if b] + note + [verification_status]))
    return 0 if total == 0 else 2
