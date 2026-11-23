"""`appdoc upgrade <target>`: bring a Narrative written for an older template to the running one (plan 2.7, 3.11).

The steps are data (`template_spec.UPGRADE_STEPS`); this module applies them. It only adds and renames: a heading, a
marker pair, a table skeleton, a column, a row, the fixed 5.3 line, the stamp. Text that does not fit the template
(a table of another shape, a flat list where a table is now required) is never deleted: the template's skeleton is
added above it and the old text stays, under an `appdoc:upgrade-orphan` comment that C3 fails on until a person has
moved it. After the mechanical steps the Facts are extracted again and the generated blocks filled.

The command never writes `evidence.jsonl`, `notes.jsonl` or `audit-plan.json`, and never seals (P4: the register
is the audit's, not the tool's). What cannot be mechanical is for the person to do; `docs/appdoc/UPGRADE-TODO.md`
(written by `write_todo`) lists it with the Check rule that fails until it is done.
"""

from __future__ import annotations

import contextlib
import io
import os
import re
import sys

from . import __version__
from . import docmodel as dm
from . import template_spec as spec
from .textnorm import normalize_newlines
from .textutil import read_text

NARRATIVE = "application-documentation.md"
TODO = "UPGRADE-TODO.md"
TEMPLATE_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "assets", "template.md")
_BLOCK_NAMES = frozenset(spec.GENERATED.values())
_BLOCK_KEY = {name: key for key, name in spec.GENERATED.items()}


def infer_version(text: str) -> str:
    """The template version a Narrative is on: its stamp; with none, 2.1 when it carries the 2.1 subsections
    (`SUBSECTIONS_2_1`), else 2.0."""
    m = spec.STAMP_RE.search(text)
    if m:
        return m.group(1)
    heads = dm.headings(normalize_newlines(text).split("\n"))
    return "2.1" if all(k in heads for k in spec.SUBSECTIONS_2_1) else spec.UPGRADE_FROM


def steps_after(version: str, to: str = spec.TEMPLATE_VERSION) -> list[str]:
    """The versions in UPGRADE_STEPS that lie after `version` and up to `to`, oldest first."""
    vt = spec.version_tuple
    return sorted((v for v in spec.UPGRADE_STEPS if vt(version) < vt(v) <= vt(to)), key=vt)


# --- reading the text -------------------------------------------------------------------------------------------

def _view(lines: list[str]):
    """The lines with every generated block's content masked (so a table inside a block is not the section's table),
    and their headings. Line numbers are the same as `lines`."""
    from . import fill
    masked = fill.mask_blocks("\n".join(lines), _BLOCK_NAMES, pad=True).split("\n")
    return masked, dm.headings(masked)


def _appendix_idx(masked: list[str]) -> int | None:
    fence = dm.fenced(masked)
    for i, line in enumerate(masked):
        if not fence[i] and line.startswith("## Appendix A"):
            return i
    return None


def _heading(masked, heads, key):
    """A Heading-like (idx, end, own_end) for a numbered key or "appendix"; None when the document has none."""
    if key == "appendix":
        i = _appendix_idx(masked)
        return None if i is None else dm.Heading("appendix", "Appendix A", i, len(masked), len(masked))
    return heads.get(key)


def _after_guide(lines, h) -> int:
    """The line index right after the heading's blank lines and `appdoc:guide` comment (where a block or a skeleton
    goes); when the heading has no guide, the first line of its body."""
    i = h.idx + 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    if i < len(lines) and lines[i].lstrip().startswith("<!--") and spec.GUIDE_RE.search(lines[i]):
        while i < len(lines) and "-->" not in lines[i]:
            i += 1
        i += 1
    while i < len(lines) and not lines[i].strip():
        i += 1
    return i


def _skip_blocks(lines, at: int) -> int:
    """Move `at` past generated blocks that open right there (a table goes below the block that heads a section)."""
    while at < len(lines) and lines[at].lstrip().startswith("<!-- appdoc:generated"):
        while at < len(lines) and not lines[at].lstrip().startswith("<!-- /appdoc:generated"):
            at += 1
        at += 1
        while at < len(lines) and not lines[at].strip():
            at += 1
    return at


def _end_of_body(lines, end: int, floor: int) -> int:
    """The index after the last content line before `end` (not above `floor`)."""
    while end > floor and not lines[end - 1].strip():
        end -= 1
    return end


def _insert(lines, at: int, new: list[str]) -> None:
    """Insert `new` at `at`, one blank line from what is before and after it."""
    pre = [""] if at > 0 and lines[at - 1].strip() else []
    post = [""] if at < len(lines) and lines[at].strip() else []
    lines[at:at] = pre + new + post


def _bars(line: str) -> list[int]:
    """Indexes of the `|` that delimit cells (the quoting of docmodel.split_row: not escaped, not in a code span)."""
    out, in_code, i = [], False, 0
    while i < len(line):
        c = line[i]
        if c == "\\" and i + 1 < len(line) and line[i + 1] == "|":
            i += 2
            continue
        if c == "`":
            in_code = not in_code
        elif c == "|" and not in_code:
            out.append(i)
        i += 1
    return out


def _first_table(masked, heads, key):
    h = heads.get(key)
    return dm.first_table(masked, h) if h else None


def _header(t) -> list[str]:
    return [dm.cell_text(c).casefold() for c in t.header]


# --- the template's own text (skeletons) ------------------------------------------------------------------------

def unknown_row(key: str, label: str) -> str:
    """A required row for table `key` that says the repository does not show it (spec.UNKNOWN_TEXT)."""
    ts = spec.TABLES[key]
    cells = [label]
    for col in ts.columns[1:]:
        if col == "Working directory":
            cells.append(".")
        elif "Unknown" in ts.values.get(col, ()):
            cells.append("Unknown")
        else:
            cells.append(spec.UNKNOWN_TEXT)
    return "| " + " | ".join(cells) + " |"


class _Template:
    """The units of the running template (assets/template.md): a heading, its guide comment and skeleton."""

    def __init__(self):
        self.lines = normalize_newlines(read_text(TEMPLATE_PATH)).split("\n")
        self.heads = dm.headings(self.lines)

    def unit(self, key: str) -> list[str]:
        if key == "appendix":
            i = next(n for n, l in enumerate(self.lines) if l.startswith("## Appendix A"))
            h = dm.Heading("appendix", "Appendix A", i, len(self.lines), len(self.lines))
        else:
            h = self.heads[key]
        out = list(self.lines[h.idx:h.own_end])
        while out and not out[-1].strip():
            out.pop()
        return self._with_required_rows(key, out)

    def table(self, key: str) -> list[str]:
        """The skeleton of the first table under `key`: header, separator, and the required rows as Unknown rows."""
        h = self.heads[key]
        t = dm.first_table(self.lines, h)
        out = list(self.lines[t.line - 1:t.line + 1]) + [self.lines[no - 1] for no, _ in t.rows]
        return self._with_required_rows(key, out, first=0)

    @staticmethod
    def _with_required_rows(key: str, lines: list[str], first: int | None = None) -> list[str]:
        ts = spec.TABLES.get(key)
        if not ts or not ts.required_rows:
            return lines
        t = dm.first_table(lines, dm.Heading(key, "", -1, len(lines), len(lines)))
        if t is None:
            return lines
        lines = list(lines)
        for no, cells in t.rows:
            label = dm.cell_text(cells[0]) if cells else ""
            if label in ts.required_rows and not any(c.strip() for c in cells[1:]):
                lines[no - 1] = unknown_row(key, label)
        return lines


_TEMPLATE: _Template | None = None


def _template() -> _Template:
    global _TEMPLATE
    if _TEMPLATE is None:
        _TEMPLATE = _Template()
    return _TEMPLATE


# --- the operations ---------------------------------------------------------------------------------------------

def _op_stamp(lines, version, log):
    new = f"<!-- appdoc:template {version} -->"
    for i, line in enumerate(lines):
        if spec.STAMP_RE.search(line):
            if spec.STAMP_RE.search(line).group(1) != version:
                lines[i] = spec.STAMP_RE.sub(new, line, count=1)
                log.append(f"stamp {version}")
            return
    title = next((i for i, l in enumerate(lines[:20]) if l.startswith("# ")), None)
    lines.insert(0 if title is None else title + 1, new)
    log.append(f"stamp {version}")


def _op_heading(lines, key, log, level):
    """Add `## n. Title` (level 2) or `### ref Title` (level 3) from the template unless it is there."""
    masked, heads = _view(lines)
    if key in heads:
        return
    unit = _template().unit(key)
    if level == 3:
        parent = heads.get(key.split(".")[0])
        if parent is None:
            log.append(f"skipped {key}: the document has no section {key.split('.')[0]}")
            return
        order = lambda k: tuple(int(p) for p in k.split("."))
        later = [h for k, h in heads.items() if "." in k and k.startswith(key.split(".")[0] + ".")
                 and order(k) > order(key)]
        at = min(h.idx for h in later) if later else _end_of_body(lines, parent.end, parent.idx + 1)
    else:
        later = [h for k, h in heads.items() if "." not in k and int(k) > int(key)]
        appendix = _appendix_idx(masked)
        if later:
            at = min(h.idx for h in later)
        else:
            at = appendix if appendix is not None else _end_of_body(lines, len(lines), 0)
    _insert(lines, at, unit)
    log.append(f"added {'section' if level == 2 else 'subsection'} {key} {unit[0].lstrip('#').strip().split(' ', 1)[-1]}")


def _op_appendix(lines, log):
    masked, _ = _view(lines)
    if _appendix_idx(masked) is None:
        _insert(lines, _end_of_body(lines, len(lines), 0), _template().unit("appendix"))
        log.append("added the Appendix A heading")


def _op_block(lines, name, log):
    from . import fill
    if any(m.group(2) == name for m in fill.BLOCK_RE.finditer("\n".join(lines))):
        return
    masked, heads = _view(lines)
    key = _BLOCK_KEY[name]
    h = _heading(masked, heads, key) or heads.get(key.split(".")[0])
    if h is None:
        log.append(f"skipped block {name}: the document has no section {key}")
        return
    pair = [f"<!-- appdoc:generated {name} -->", f"<!-- /appdoc:generated {name} -->"]
    if spec.BLOCK_AT.get(name, "top") == "end":
        at = _end_of_body(lines, h.own_end, h.idx + 1)
    else:
        at = _after_guide(lines, h)
    _insert(lines, at, pair)
    log.append(f"added the {name} block")


def _op_rename(lines, key, old, new, log):
    masked, heads = _view(lines)
    t = _first_table(masked, heads, key)
    if t is None:
        return
    head = _header(t)
    if old.casefold() not in head or new.casefold() in head:
        return
    i = t.line - 1
    bars = _bars(lines[i])
    j = head.index(old.casefold())
    if len(bars) != len(head) + 1:
        return
    lines[i] = lines[i][:bars[j] + 1] + f" {new} " + lines[i][bars[j + 1]:]
    log.append(f"renamed the {key} column {old} to {new}")


def _op_column(lines, key, name, after, fill_kind, log):
    masked, heads = _view(lines)
    t = _first_table(masked, heads, key)
    if t is None:
        return
    head = _header(t)
    if name.casefold() in head or (after is not None and after.casefold() not in head):
        return
    at = -1 if after is None else head.index(after.casefold())
    rows = [t.line - 1, t.line] + [no - 1 for no, _ in t.rows]
    if any(len(_bars(lines[i])) != len(head) + 1 or not lines[i].rstrip().endswith("|") for i in rows):
        return   # a ragged table is left as it is; reshape reports it
    prefix = spec.TABLES[key].id_prefix or ""
    for n, i in enumerate(rows):
        if n == 0:
            cell = name
        elif n == 1:
            cell = "---"
        else:
            cell = f"{prefix}{n - 1}" if fill_kind == "ids" else spec.UNKNOWN_TEXT
        pos = _bars(lines[i])[at + 1] + 1
        lines[i] = lines[i][:pos] + (f"{cell}|" if n == 1 else f" {cell} |") + lines[i][pos:]
    log.append(f"added the {key} column {name}")


def _op_rows(lines, key, log):
    masked, heads = _view(lines)
    t = _first_table(masked, heads, key)
    ts = spec.TABLES[key]
    if t is None or not ts.header_ok([dm.cell_text(c) for c in t.header]):
        return
    have = {dm.cell_text(cells[0]) for _, cells in t.rows if cells}
    missing = [label for label in ts.required_rows if label not in have]
    if not missing:
        return
    at = t.rows[-1][0] if t.rows else t.line + 1
    lines[at:at] = [unknown_row(key, label) for label in missing]
    log.append(f"added the {key} rows {', '.join(missing)}")


def _op_line(lines, key, text, log):
    masked, heads = _view(lines)
    h = heads.get(key)
    if h is None or text in "\n".join(lines[h.idx:h.own_end]):
        return
    t = dm.first_table(masked, h)
    at = (t.rows[-1][0] if t.rows else t.line + 1) if t else _end_of_body(lines, h.own_end, h.idx + 1)
    _insert(lines, at, [text])
    log.append(f"added the fixed line under {key}")


def _op_reshape(lines, key, log):
    from . import fill
    masked, heads = _view(lines)
    h = heads.get(key)
    if h is None:
        return
    ts = spec.TABLES[key]
    t = dm.first_table(masked, h)
    if t is not None and ts.header_ok([dm.cell_text(c) for c in t.header]):
        return
    at = _skip_blocks(lines, _after_guide(lines, h))
    body = dm.strip_comments(fill.BLOCK_RE.sub("", "\n".join(lines[at:h.own_end])))
    new = _template().table(key)
    if body.strip():
        new += ["", f"<!-- {spec.ORPHAN_MARK} {key}: the text below did not fit the template {spec.TEMPLATE_VERSION} "
                    f"table ({', '.join(ts.columns)}); move what still applies into the table above, then delete the "
                    "text and this comment -->"]
    _insert(lines, at, new)
    log.append(f"added the {key} table skeleton" + (" (the old text is kept under an orphan comment)" if body.strip() else ""))


def _apply(lines: list[str], op: tuple, version: str, log: list[str]) -> None:
    name, args = op[0], op[1:]
    if name == "stamp":
        _op_stamp(lines, version, log)
    elif name == "section":
        _op_heading(lines, args[0], log, 2)
    elif name == "subsection":
        _op_heading(lines, args[0], log, 3)
    elif name == "appendix":
        _op_appendix(lines, log)
    elif name == "block":
        _op_block(lines, args[0], log)
    elif name == "reshape":
        _op_reshape(lines, args[0], log)
    elif name == "rows":
        _op_rows(lines, args[0], log)
    elif name == "rename":
        _op_rename(lines, *args, log)
    elif name == "column":
        _op_column(lines, *args, log)
    elif name == "line":
        _op_line(lines, *args, log)
    else:
        raise ValueError(f"unknown upgrade operation {name!r}")


def upgrade_text(text: str, from_version: str, to_version: str = spec.TEMPLATE_VERSION) -> tuple[str, list[str]]:
    """Apply every step after `from_version` up to `to_version` to a Narrative. Returns the new text (the line
    ending the text had is kept) and a log of what was added or renamed. Pure; running it again on its own output
    changes nothing."""
    eol = "\r\n" if "\r\n" in text else "\n"
    body = normalize_newlines(text)
    final_nl = body.endswith("\n")
    lines = body.rstrip("\n").split("\n")
    log: list[str] = []
    versions = steps_after(from_version, to_version)
    for version in versions:
        for op in spec.UPGRADE_STEPS[version]:
            if op == ("stamp",) and version != versions[-1]:
                continue   # the document is stamped once, with the version it ends on
            _apply(lines, op, version, log)
    out = "\n".join(lines) + ("\n" if final_nl else "")
    return (out.replace("\n", eol) if eol != "\n" else out), log


def run(target: str, out_dir: str, workers: int | None = None, no_ownership: bool = False) -> int:
    """`appdoc upgrade`: mechanical steps on the Narrative, then `extract` and `fill`. Exit 0 done (or nothing to do),
    1 tool error. Writes the Narrative, facts.json, facts-summary.md, provenance.json and UPGRADE-TODO.md, and nothing
    of the register."""
    from . import check, extract, fill
    path = os.path.join(out_dir, NARRATIVE)
    if not os.path.isfile(path):
        print(f"appdoc upgrade: {path} not found; there is no document to upgrade", file=sys.stderr)
        return 1
    text = read_text(path)
    found = infer_version(text)
    vt = spec.version_tuple
    if vt(found) > vt(spec.TEMPLATE_VERSION):
        print(f"appdoc upgrade: the document is on template {found}, newer than this AppDoc's "
              f"{spec.TEMPLATE_VERSION}; nothing was changed", file=sys.stderr)
        return 1
    if vt(found) == vt(spec.TEMPLATE_VERSION):
        print(f"appdoc upgrade: the document is already on template {spec.TEMPLATE_VERSION}; nothing to do")
        return 0
    new, log = upgrade_text(text, found)
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(new)
    print(f"appdoc upgrade: template {found} -> {spec.TEMPLATE_VERSION}")
    for entry in log:
        print(f"  {entry}")
    for p in extract.write(target, out_dir, workers=workers, no_ownership=no_ownership):
        print(f"wrote {p}")
    rc = fill.run(target, out_dir)
    if rc != 0:
        return rc
    with contextlib.redirect_stdout(io.StringIO()):
        check.run(target, out_dir)   # once, to list what fails; it writes check-report.md
    todo = write_todo(out_dir, found, log)
    print(f"wrote {todo}")
    print(f"appdoc upgrade: the mechanical steps are done; {os.path.basename(todo)} lists what a person must do next")
    return 0


# --- UPGRADE-TODO.md ----------------------------------------------------------------------------------------------

_RULE_HEAD = re.compile(r"^## (C\d+) ")
_ADVISORY_COUNTS = "## Hand-written counts (advisory)"
_SHOWN = 8   # problems quoted per rule


def _report_problems(report: str) -> tuple[dict[str, list[str]], list[str]]:
    """The Check report's problems by rule (`- line N: ...` bullets under `## C<n> <title>`), and the lines of its
    hand-written-count advisory."""
    problems: dict[str, list[str]] = {}
    counts: list[str] = []
    cur = None
    for line in report.splitlines():
        m = _RULE_HEAD.match(line)
        if m:
            cur = problems.setdefault(m.group(1), [])
        elif line.startswith("## "):
            cur = counts if line.startswith(_ADVISORY_COUNTS) else None
        elif cur is not None and line.startswith("- "):
            cur.append(line[2:])
    return problems, counts


def write_todo(out_dir: str, from_version: str, log: list[str]) -> str:
    """Write docs/appdoc/UPGRADE-TODO.md: what the upgrade did, and every step left for a person, each with the
    Check rule that fails (or advises) until it is done. The steps come from the Check's own report of the upgraded
    document, plus the ones no rule can see (convert `verification.md`, the audit). Deterministic: no date."""
    from . import check
    report_path = os.path.join(out_dir, check.REPORT)
    report = read_text(report_path) if os.path.isfile(report_path) else ""
    problems, counts = _report_problems(report)
    titles = {r.id: r.title for r in check.RULES}
    claimed: set[str] = set()
    items: list[tuple[str, str, list[str]]] = []   # (what to do, the rules, the problems quoted)

    def label(rule: str) -> str:
        return f"{rule} {titles.get(rule, '')}".strip()

    def add(rules: tuple[str, ...], what: str, quoted: list[str], rule_text: str | None = None) -> None:
        items.append((what, rule_text or ", ".join(label(r) for r in rules), quoted))
        claimed.update(rules)

    def of(rule: str, keep=lambda p: True) -> list[str]:
        return [p for p in problems.get(rule, ()) if keep(p)]

    orphan = lambda p: spec.ORPHAN_MARK in p
    if os.path.isfile(os.path.join(out_dir, "verification.md")):
        add(("C11",), "Convert `verification.md` to `evidence.jsonl`: one row per claim, with a literal anchor copied "
            "from the lines it cites (the register needs source anchors, so the tool does not convert it). Delete "
            "`verification.md` afterwards.", of("C11"), label("C11"))
    if of("C3", orphan):
        add((), "Move the text under each `appdoc:upgrade-orphan` comment into the table or section the upgrade added "
            "above it, then delete the leftover text and the comment.",
            [f"{p.split(':', 1)[0]}: an `{spec.ORPHAN_MARK}` comment" for p in of("C3", orphan)], label("C3"))
    guide = lambda p: "guidance comment" in p
    fills = {"C3": of("C3", lambda p: not orphan(p)), "C8": of("C8"), "C9": of("C9", guide)}
    if any(fills.values()):
        add((), "Fill what the upgrade added: sections, subsections and tables carry a template guide comment, and "
            "cells say `Unknown - see Open questions.` until the repository is read. Delete each `appdoc:guide` "
            "comment and add a row to section 14 for every Unknown you leave.",
            [p for ps in fills.values() for p in ps], ", ".join(label(r) for r, ps in fills.items() if ps))
        claimed.update(r for r in ("C3", "C8") if fills[r])
    if of("C9", lambda p: not guide(p)):
        add(("C9",), "Fix the tables the Check lists (a header, a cell, an ID, a value, a required row; section 10.1 and "
            "15 rows go in severity order, most severe first: move the row and keep its ID).",
            of("C9", lambda p: not guide(p)))
    elif fills["C9"]:
        claimed.add("C9")
    if "C12" in problems:
        add(("C12",), "Write register rows for the finding candidates: cite each in section 10.1 (a V- row and an "
            "`evidence.jsonl` row) or add a `Dismissed` row with ref `smell/<id>` and a reason.", of("C12"))
    if counts:
        add((), "Replace each hand-written count with a count marker (`<!-- appdoc:count V -->3<!-- /appdoc:count -->`; "
            "`appdoc fill` writes the number). C15 only advises on these; it fails on a marker with a stale number "
            "or an unknown class.", counts, f"{label('C15')} (advisory)")
    if "C1" in problems:
        add(("C1",), "Fix the Citations the Check lists. `appdoc build --expand-citations` rewrites the bare names in "
            "the Narrative only; a bare name in `evidence.jsonl` or `notes.jsonl` is fixed by hand (write the full "
            "path the message names).", of("C1"))
    if "C18" in problems:
        add(("C18",), "Move each \"Known extractor limitation:\" paragraph out of the Narrative into `notes.jsonl` "
            "(`{\"block\", \"text\", \"cites\", \"block_sha\"}`, leave `block_sha` empty); `appdoc build` seals it.",
            of("C18"))
    if "C17" in problems:
        add(("C17",), "Shorten the audit record's `scope` to the method (no IDs, no numbers) and move per-section "
            "caveats to `exclusions`.", of("C17"))
    unsealed = lambda p: "not sealed" in p
    if of("C11", unsealed) and "C11" not in claimed:
        add(("C11",), "Run `appdoc build <target>`: it seals the register rows and notes that have no seal yet. Do it after "
            "the steps above, so a seal is written against the final text.", [], label("C11"))
    if of("C11", lambda p: not unsealed(p)) and not any(w.startswith("Convert `verification.md`") for w, _, _ in items):
        add(("C11",), "Fix the register: two live rows on one ref need `\"supersedes\"` on the newer one (never "
            "delete a row; restore deleted rows from git history); an `Answerable` row needs `answered_in`; a row "
            "whose text changed after it was sealed (`build --expand-citations` rewrites sealed text) is re-audited "
            "and rewritten without `claim_sha`, which `appdoc build` writes again.", of("C11", lambda p: not unsealed(p)))
    for rule in sorted(problems, key=lambda r: int(r[1:])):   # any other failing rule, so none is missing from this file
        if rule not in claimed:
            add((rule,), f"Fix what rule {rule} reports (see check-report.md).", of(rule))
    add((), "After the steps above, run the audit and rebuild: `appdoc audit-plan <target>`, audit every planned ID in "
        "a fresh agent, `appdoc seal <target> --audit --date YYYY-MM-DD`, `appdoc build <target> --require-audit`. "
        "The tool never writes `evidence.jsonl`, `notes.jsonl` or `audit-plan.json` for you.", [],
        f"{label('C17')} and {label('C19')} (with `--require-audit`)")

    out = [f"# Upgrade TODO: template {from_version} to {spec.TEMPLATE_VERSION}", "",
           f"Written by `appdoc upgrade` (AppDoc {__version__}). The mechanical steps are done; the steps below need a "
           "person. Each names the Check rule that fails (or advises) until it is done. Run `appdoc build <target>` "
           "until it passes, then delete this file (the Check does not read it).", "",
           "## Done by the tool", ""]
    out += [f"- {entry}" for entry in log] or ["- nothing to add"]
    out += ["- re-ran `extract` and `fill` (facts.json, facts-summary.md, provenance.json and the generated blocks)",
            "- did not write `evidence.jsonl`, `notes.jsonl` or `audit-plan.json`, and did not seal the register", "",
            "## Steps for a person", ""]
    for n, (what, rules, quoted) in enumerate(items, 1):
        out.append(f"{n}. [ ] {what}")
        out.append(f"   - Rule: {rules}")
        out += [f"   - {q}" for q in quoted[:_SHOWN]]
        if len(quoted) > _SHOWN:
            out.append(f"   - ... {len(quoted) - _SHOWN} more in check-report.md")
    path = os.path.join(out_dir, TODO)
    with open(path, "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join(out) + "\n")
    return path
