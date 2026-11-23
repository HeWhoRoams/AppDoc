"""The Evidence Register: the source-to-claim audit as data (docs/appdoc/evidence.jsonl).

Line 1 is the audit record: {"type": "audit", "performed": true, "auditor": "independent", "scope": "..."}.
Every other line is one claim:
  {"id": "E-1", "ref": "10.1/V-1", "claim": "...", "result": "Supported",
   "cites": ["src/app.py:80-83"], "anchor": "literal text in the cited lines", "limitation": "..."}
Counts, coverage and Appendix A are computed from it; nobody writes them by hand.
Refs: a section or ID ("10.1/V-1"); "smell/<id>" with result Dismissed; "14/Q-n" with result Answerable.
"""

from __future__ import annotations

import json
import os
import re

from .citations import parse_span
from .template_spec import version_tuple
from .textutil import plural

REGISTER = "evidence.jsonl"
RESULTS = ("Supported", "Corrected", "Downgraded", "Dismissed", "Answerable")
COUNTED_ALWAYS = ("Supported", "Corrected", "Downgraded")
VERIFIABLE = ("Supported", "Corrected")
APPENDIX_TITLE = "Appendix A. Evidence Register and Verification"
AUDIT_NOT_PERFORMED = "**Audit not performed.**"   # the render step styles a blockquote that starts with this
MAX_ANCHOR = 200
_SINGLE_QUOTES = "'\u2018\u2019\u201a\u201b"      # PowerShell treats the curly ones as quotes too
AUDITORS = ("independent", "same-session")
ROW_KEYS = ("id", "ref", "claim", "result", "cites", "anchor", "limitation")
OPTIONAL_KEYS = ("claim_sha", "supersedes", "sealed_by")
SEALED_BY = ("audit", "upgrade")
CLAIM_SHA_RE = re.compile(r"^[0-9a-f]{12}$")
ID_RE = re.compile(r"^E-\d+$")
AUDIT_DATE_RE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
AUDIT_RECORD_KEYS = ("audited_on", "audited_with", "audited_bundle", "doc_sha")   # required on 2.7 (C17)
REF_RE = re.compile(r"^(\d+(?:\.\d+)?)(?:/([A-Z]+-\d+))?$")
SMELL_REF_RE = re.compile(r"^smell/([0-9a-f]{8})$")      # only with result Dismissed
ANSWERABLE_REF_RE = re.compile(r"^14/(Q-\d+)$")         # only with result Answerable


class Register:
    def __init__(self):
        self.audit: dict | None = None
        self.rows: list[tuple[int, dict]] = []      # (1-based line, row)
        self.errors: list[tuple[int, str]] = []     # (1-based line, message)

    @property
    def performed(self) -> bool:
        return bool(self.audit and self.audit.get("performed"))

    @staticmethod
    def supersedes_of(row: dict) -> list[str]:
        """The ids a row supersedes, as a list ([] when the key is absent)."""
        v = row.get("supersedes")
        if v is None:
            return []
        return [v] if isinstance(v, str) else list(v)

    def superseded_ids(self) -> set[str]:
        return {t for _, row in self.rows for t in self.supersedes_of(row)}

    def superseded_by(self, rid: str) -> str | None:
        """The id of the first row (in file order) that supersedes `rid`, or None."""
        for _, row in self.rows:
            if rid in self.supersedes_of(row):
                return str(row["id"])
        return None

    def live_rows(self) -> list[tuple[int, dict]]:
        """The rows no other row supersedes. Everything computed from the register uses these."""
        gone = self.superseded_ids()
        return [(no, row) for no, row in self.rows if str(row.get("id")) not in gone]

    def counts(self, rows=None) -> dict[str, int]:
        c = {r: 0 for r in RESULTS}
        for _, row in (self.rows if rows is None else rows):
            if row.get("result") in c:
                c[row["result"]] += 1
        return c


def parse(text: str) -> Register:
    reg = Register()
    lines = [(i, l) for i, l in enumerate(text.splitlines(), 1) if l.strip()]
    if not lines:
        reg.errors.append((1, "the register is empty; line 1 must be the audit record"))
        return reg
    for n, (no, line) in enumerate(lines):
        try:
            obj = json.loads(line)
        except ValueError as exc:
            reg.errors.append((no, f"line is not valid JSON ({exc.msg})"))
            continue
        if not isinstance(obj, dict):
            reg.errors.append((no, "line is not a JSON object"))
            continue
        if n == 0:
            if obj.get("type") != "audit":
                reg.errors.append((no, 'line 1 must be the audit record {"type": "audit", ...}'))
                continue
            reg.audit = obj
            if not isinstance(obj.get("performed"), bool):
                reg.errors.append((no, '"performed" must be true or false'))
            elif obj["performed"] and obj.get("auditor") not in AUDITORS:
                reg.errors.append((no, f'"auditor" must be one of {", ".join(AUDITORS)}'))
            for key, rx in (("audited_on", AUDIT_DATE_RE), ("audited_bundle", CLAIM_SHA_RE), ("doc_sha", CLAIM_SHA_RE)):
                if key in obj and not rx.match(str(obj[key])):
                    what = "YYYY-MM-DD" if rx is AUDIT_DATE_RE else "12 lowercase hex characters"
                    reg.errors.append((no, f'"{key}" must be {what}'))
            if "audited_with" in obj and not version_tuple(obj["audited_with"]):
                reg.errors.append((no, '"audited_with" must be an AppDoc version such as 2.7.0'))
            continue
        missing = [k for k in ROW_KEYS if k not in obj]
        if missing:
            reg.errors.append((no, f"row is missing {', '.join(missing)}"))
            continue
        if not isinstance(obj["cites"], list) or not all(isinstance(c, str) for c in obj["cites"]):
            reg.errors.append((no, '"cites" must be a list of path:line strings'))
            continue
        if "claim_sha" in obj and not CLAIM_SHA_RE.match(str(obj["claim_sha"])):
            reg.errors.append((no, '"claim_sha" must be 12 lowercase hex characters'))
            continue
        if "supersedes" in obj:
            sup = obj["supersedes"]
            ids = [sup] if isinstance(sup, str) else sup
            if (not isinstance(ids, list) or not ids
                    or not all(isinstance(i, str) and ID_RE.match(i) for i in ids)):
                reg.errors.append((no, '"supersedes" must be an E-<n> id or a non-empty list of them'))
                continue
        if "sealed_by" in obj and obj["sealed_by"] not in SEALED_BY:
            reg.errors.append((no, f'"sealed_by" must be one of {", ".join(SEALED_BY)}'))
            continue
        reg.rows.append((no, obj))
    return reg


def _cell(s) -> str:
    return " ".join(str(s).split()).replace("|", "\\|")


def _ps(s: str) -> str:
    return "'" + "".join(ch * 2 if ch in _SINGLE_QUOTES else ch for ch in s) + "'"


def _sh(s: str) -> str:
    return "'" + s.replace("'", "'\\''") + "'"


def _first_path(row: dict) -> str | None:
    for raw in row.get("cites") or []:
        parsed = parse_span(str(raw).strip("`"))
        if parsed:
            return parsed[0]
    return None


def _build_basenames(root: str) -> dict[str, list[str]]:
    """Build a basename -> [Target-relative paths] index for the target."""
    from . import scan
    idx: dict[str, list[str]] = {}
    for sf in scan.walk(root):
        idx.setdefault(sf.path.rsplit("/", 1)[-1], []).append(sf.path)
    return idx


def _resolve_path(root: str, path: str, basenames: dict[str, list[str]]) -> str | None:
    """Resolve a Target-relative path to a full file path. Returns None if not found."""
    full = os.path.realpath(os.path.join(root, path))
    if os.path.commonpath([root, full]) != root:
        return None
    if os.path.isfile(full):
        return full
    if os.path.isdir(full):
        return None
    name = path.rsplit("/", 1)[-1]
    if "/" not in path:
        hits = basenames.get(name, [])
        if len(hits) == 1:
            return os.path.join(root, hits[0])
    return None


def locate(root: str, row: dict, basenames: dict[str, list[str]] | None = None) -> tuple[str, int] | None:
    """Find the (Target-relative path, 1-based line) where the anchor appears exactly.

    For each cite in order, resolve the path, read the cited lines, and check for an
    exact case-sensitive substring match of the anchor on a single line.
    Returns the first match, or None.
    """
    anchor = str(row.get("anchor") or "").strip()
    if not anchor:
        return None
    root = os.path.realpath(root)
    if basenames is None:
        basenames = _build_basenames(root)
    for raw_cite in row.get("cites") or []:
        parsed = parse_span(str(raw_cite).strip("`"))
        if not parsed:
            continue
        path, start, end = parsed
        full = _resolve_path(root, path, basenames)
        if full is None or not os.path.isfile(full):
            continue
        try:
            with open(full, "rb") as fh:
                raw = fh.read()
        except OSError:
            continue
        if b"\0" in raw[:8192]:
            continue  # binary file
        try:
            text = raw.decode("utf-8")
        except UnicodeDecodeError:
            try:
                text = raw.decode("cp1252")
            except UnicodeDecodeError:
                continue
        lines = text.splitlines()
        lo = (start or 1) - 1
        hi = end or lo + 1
        for i in range(lo, min(hi, len(lines))):
            if anchor in lines[i]:
                return path, i + 1
    return None


def _audit_state(reg: Register | None) -> list[str]:
    if reg is None:
        return [f"> {AUDIT_NOT_PERFORMED} No Evidence Register was found, so nothing records whether the cited "
                "lines support the claims. The Citations in this document resolve to real files and lines."]
    if not reg.performed:
        scope = _cell((reg.audit or {}).get("scope") or "No reason was given.")
        return [f"> {AUDIT_NOT_PERFORMED} The source-to-claim audit was not performed. The Citations in this "
                f"document resolve to real files and lines, but no one has verified that the cited lines support "
                f"the claims. {scope}"]
    return [f"**Auditor:** {_cell(reg.audit.get('auditor'))}. **Scope:** {_cell(reg.audit.get('scope') or 'not stated')}"]


def _result_parts(c: dict) -> str:
    return ", ".join(f"{c[r]} {r}" for r in RESULTS if r in COUNTED_ALWAYS or c[r])


def _coverage(reg: Register, coverage) -> list[str]:
    live = reg.live_rows()
    anchors = "Each Supported or Corrected row's anchor text was found in its cited lines by the Check."
    if len(live) == len(reg.rows):
        out = [f"{plural(len(reg.rows), 'row')}: {_result_parts(reg.counts())}. {anchors}"]
    else:
        first = [(no, r) for no, r in reg.rows if not Register.supersedes_of(r)]   # the rows that replace none
        out = [f"{plural(len(reg.rows), 'row')} ({len(reg.rows) - len(live)} superseded). "
               f"Current: {_result_parts(reg.counts(live))}. As first audited: {_result_parts(reg.counts(first))}. "
               f"{anchors}"]
    if coverage:
        out += ["", "| Section | IDs with a register row |", "|---|---|"]
        out += [f"| {_cell(sec)} | {hit} of {n} |" for sec, hit, n in coverage]
    return out


def _table(reg: Register) -> list[str]:
    if not reg.rows:
        return ["The register has no rows."]
    out = ["| ID | Ref | Claim | Result | Cites | Limitation |", "|---|---|---|---|---|---|"]
    for _, row in reg.rows:
        cites = " ".join(f"`{str(c).strip('`')}`" for c in row["cites"])
        by = reg.superseded_by(str(row["id"]))
        result = _cell(row["result"]) + (f" (superseded by {by})" if by else "")
        out.append(f"| {_cell(row['id'])} | {_cell(row['ref'])} | {_cell(row['claim'])} | {result} | "
                   f"{cites} | {_cell(row['limitation'])} |")
    return out


def _commands(reg: Register, root: str | None = None) -> list[str]:
    if root is None:
        return ["No verification commands (no Target root)."]
    root = os.path.realpath(root)
    basenames = _build_basenames(root)
    out = []
    for _, row in reg.live_rows():
        anchor = str(row.get("anchor") or "")
        if (row.get("result") not in VERIFIABLE or not anchor.strip()
                or "\n" in anchor or "\r" in anchor or len(anchor) > MAX_ANCHOR):
            continue
        loc = locate(root, row, basenames)
        if loc is None:
            continue
        path, line = loc
        sec = re.match(r"\d+", str(row["ref"]).strip())
        label = f"section {sec.group(0)}" if sec else f"`{_cell(row['ref'])}`"
        out += [f"- **{_cell(row['id'])}** ({label}), expect `{path}:{line}`", "", "```text",
                f"Select-String -LiteralPath {_ps(path)} -SimpleMatch -CaseSensitive -Pattern {_ps(anchor)}",
                f"grep -nF -- {_sh(anchor)} {_sh(path)}", "```", ""]
    if not out:
        return ["No row has an anchor to re-check."]
    return ["Run from the Target root. Each block names the expected line, then a PowerShell command and a POSIX command.",
            ""] + out[:-1]


def seal(path: str, claim_shas: dict[str, str], sealed_by: str | None = None,
         audit_fields: dict | None = None) -> int:
    """Write claim_sha into every row that lacks one. Never overwrites an existing one.

    claim_shas maps row id ("E-1") to the 12-hex-char SHA. Returns the number of rows sealed.
    `sealed_by` ("audit" | "upgrade") is written beside each claim_sha this call adds; None writes none.
    `audit_fields` (audited_on, audited_with, audited_bundle, doc_sha) replaces those keys on line 1.
    Preserves the file's existing line ending and key order.
    """
    with open(path, encoding="utf-8-sig", newline="") as fh:
        raw = fh.read()
    eol = "\r\n" if "\r\n" in raw else "\n"
    lines = raw.splitlines()
    out, sealed = [], 0
    for line in lines:
        if not line.strip():
            out.append(line)
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            out.append(line)
            continue
        if isinstance(obj, dict) and obj.get("type") == "audit" and audit_fields:
            obj.update(audit_fields)
            out.append(json.dumps(obj, ensure_ascii=False))
            continue
        if not isinstance(obj, dict) or obj.get("type") == "audit":
            out.append(line)
            continue
        rid = str(obj.get("id", ""))
        if rid in claim_shas and "claim_sha" not in obj:
            obj["claim_sha"] = claim_shas[rid]
            if sealed_by:
                obj["sealed_by"] = sealed_by
            sealed += 1
        out.append(json.dumps(obj, ensure_ascii=False))
    with open(path, "w", encoding="utf-8", newline="") as fh:
        fh.write(eol.join(out) + eol)
    return sealed


def _blocks_lines(reg: Register | None, blocks_by: dict | None) -> list[str]:
    """A.1 lines naming the AppDoc that wrote the generated blocks (empty when blocks_by is None)."""
    if not blocks_by:
        return []
    out = ["", f"Generated blocks written by AppDoc {blocks_by['generator']} (bundle {blocks_by['bundle']})."]
    audited = str((reg.audit or {}).get("audited_with") or "") if reg is not None else ""
    if audited and version_tuple(audited)[:2] != version_tuple(blocks_by["generator"])[:2]:
        out.append("Generated blocks were regenerated after the audit and are not covered by it.")
    return out


def _provenance_lines(reg: Register | None) -> list[str]:
    """A.1 lines from the audit record: when and with what the audit was sealed, and any upgrade-sealed rows."""
    if reg is None or not reg.performed:
        return []
    out = []
    a = reg.audit or {}
    if a.get("audited_on"):
        line = f"Audited on {a['audited_on']}"
        if a.get("audited_with"):
            line += f" with AppDoc {a['audited_with']}"
        if a.get("audited_bundle"):
            line += f" (bundle {a['audited_bundle']})"
        out += ["", line + "."]
    n = sum(1 for _, r in reg.live_rows() if r.get("sealed_by") == "upgrade")
    if n:
        out += ["", f"{n} rows were sealed at upgrade; their text was not re-audited." if n != 1
                else "1 row was sealed at upgrade; its text was not re-audited."]
    return out


def appendix_markdown(reg: Register | None, facts: dict | None = None, coverage=None,
                      root: str | None = None, blocks_by: dict | None = None) -> str:
    """Body of Appendix A (the `appendix-a` generated block), computed from the register.

    reg is None when evidence.jsonl does not exist. coverage is check.coverage() output, or None to omit it.
    facts is the facts.json dict; nothing in the appendix reads it yet.
    root is the Target directory; when given, A.4 commands are generated from locate().
    blocks_by is {"generator", "bundle"} of the running AppDoc; when given, A.1 says who wrote the blocks.
    """
    out = ["### A.1 Audit state", "", *_audit_state(reg), *_blocks_lines(reg, blocks_by), *_provenance_lines(reg)]
    if reg is not None and reg.performed:
        out += ["", "### A.2 Coverage", "", *_coverage(reg, coverage),
                "", "### A.3 Register", "", *_table(reg),
                "", "### A.4 Verification commands", "", *_commands(reg, root)]
    return "\n".join(out)
