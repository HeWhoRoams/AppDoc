"""The Check: pass/fail verification of a finished Narrative (rules C1-C7). No score, no warnings."""

from __future__ import annotations

import json
import os
import re
import sys

from .citations import OWNER_CONTEXT, find_citations
from . import scan
from .secrets import find_secret_shapes

NARRATIVE = "application-documentation.md"
FACTS = "facts.json"
REPORT = "check-report.md"
VERIFICATION = "verification.md"  # source-to-claim audit record, written by the AI (see SKILL.md)

SECTIONS = [
    "Application Index", "Coverage and Overview", "Architecture", "Functional Inventory",
    "Roles and Access Model", "UI Catalog", "Workflows", "Data and Integrations",
    "Troubleshooting Matrix", "Security and Operational Risks", "Ownership and Maintenance",
    "Architecture and Data-Flow Diagrams", "Glossary", "Open Questions and Documentation Gaps",
    "Recommendations", "Operations Runbook",
]
RULE_TITLES = {
    "C1": "Citations resolve", "C2": "Security lines", "C3": "Sections complete", "C4": "Gaps declared",
    "C5": "Claims grounded", "C6": "No secrets", "C7": "Coverage honest",
}
C5_CAP = 30
C5_MIN_LEN = 40

_COMMENT_RE = re.compile(r"<!--.*?-->", re.DOTALL)
_H2_RE = re.compile(r"^##\s+(\d+)\.\s*(.*?)\s*$")
_LIST_RE = re.compile(r"^\s*(?:[-*+]|\d+[.)])\s+")
_SEP_RE = re.compile(r"^\s*\|?\s*:?-{2,}:?\s*(\|\s*:?-{2,}:?\s*)*\|?\s*$")
_PLACEHOLDER_RE = re.compile(r"<fill|TODO|\{\{", re.IGNORECASE)
_UNKNOWN_RE = re.compile(r"\bUnknown\b")


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
        return False, f"line {c.raw.split(':', 1)[1]} is outside `{c.path}` ({n} lines)"
    return True, ""


def _never_mention(target: str) -> list[str]:
    path = os.path.join(target, OWNER_CONTEXT)
    if not os.path.isfile(path):
        return []
    terms, active = [], False
    for line in _read_text(path).splitlines():
        s = line.strip()
        if s.startswith("```"):
            active = (not active) and s[3:].strip() == "never-mention"
            continue
        if active and s:
            terms.append(s)
    return terms


def run(target: str, out_dir: str) -> int:
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

    text = _strip_comments(raw)
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
        register.append((c, ok))
        if not ok:
            add("C1", c.doc_line, f"citation does not resolve: {why}",
                "cite an existing Target-relative path and a line within the file")

    # C2
    s10 = by_num.get(10)
    if s10:
        for c, _ in register:
            if s10["start"] < c.doc_line <= s10["end"] and c.start is None:
                add("C2", c.doc_line, f"security citation `{c.path}` has no line number",
                    "cite the exact line, e.g. `path:12`")

    # C3
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

    # C4
    s14 = by_num.get(14)
    if s14 and not _content_lines(lines, s14):
        outside = [i + 1 for i, l in enumerate(lines)
                   if _UNKNOWN_RE.search(l) and not (s14["idx"] <= i < s14["end"]) and not l.lstrip().startswith("#")]
        if outside:
            add("C4", s14["start"], f"section 14 is empty but Unknown appears at line {outside[0]}"
                + (f" (and {len(outside) - 1} more)" if len(outside) > 1 else ""),
                "list every Unknown as a bullet in section 14")
    s8 = by_num.get(8)
    if facts and s8 and not _content_lines(lines, s8):
        kinds = sorted({f.get("kind") for f in facts.get("facts", [])} & {"connection", "data_access", "external_call"})
        if kinds:
            add("C4", s8["start"], f"section 8 is empty but facts.json has {', '.join(kinds)} facts",
                "document the connections, SQL and external calls, or state Unknown")

    # C5
    c5 = []
    for n in range(3, 11):
        s = by_num.get(n)
        if not s:
            continue
        for no, blk in _blocks(lines, s["idx"] + 1, s["end"]):
            if len(blk) < C5_MIN_LEN or blk.endswith(":"):
                continue
            if find_citations(blk) or "**Inferred:**" in blk or _UNKNOWN_RE.search(blk):
                continue
            c5.append((no, f"section {n} claim has no Citation, **Inferred:** marker or Unknown",
                       "add a Citation (`path:line`), prefix with **Inferred:**, or mark Unknown"))
    problems["C5"] = c5[:C5_CAP]
    if len(c5) > C5_CAP:
        problems["C5"].append((c5[C5_CAP][0], f"... {len(c5) - C5_CAP} more", "fix the above, then rerun"))

    # C6
    for no, shape in find_secret_shapes(raw):
        add("C6", no, f"secret-shaped value ({shape}); value not shown",
            'remove it, write "value omitted" and cite the location')
    raw_lower = raw.lower()
    for term in _never_mention(target):
        t = term.lower()
        for i, l in enumerate(raw_lower.splitlines(), 1):
            if t in l:
                add("C6", i, f"never-mention term '{term}' appears", "remove or generalize the term")

    # C7
    s2 = by_num.get(2)
    if facts:
        sec2 = "\n".join(lines[s2["idx"]: s2["end"]]).lower() if s2 else ""
        for st in facts.get("stacks", []):
            if (st.get("detail") or {}).get("supported") is False and st.get("name", "").lower() not in sec2:
                add("C7", s2["start"] if s2 else 1, f"unsupported stack '{st.get('name')}' is not named in section 2",
                    "name it in 2.1 and say it was not extracted")

    for k in problems:
        problems[k] = sorted(set(problems[k]), key=lambda p: (p[0], p[1])) if k != "C5" else problems[k]
    total = sum(len(v) for v in problems.values())

    body = []
    for rule, items in problems.items():
        if items:
            body.append(f"## {rule} {RULE_TITLES[rule]}")
            body += [f"- line {no}: {msg}. Fix: {fix}" for no, msg, fix in items]
            body.append("")
    head = "# Check: PASS" if total == 0 else f"# Check: FAIL ({total} problem{'s' if total != 1 else ''})"
    reg = ["## Citation register", "", "| Doc line | Cited path | Line/range | Resolved |", "|---|---|---|---|"]
    for c, ok in sorted(register, key=lambda r: (r[0].doc_line, r[0].raw)):
        rng = "" if c.start is None else (str(c.start) if c.start == c.end else f"{c.start}-{c.end}")
        reg.append(f"| {c.doc_line} | `{c.path}` | {rng} | {'yes' if ok else 'no'} |")

    # Resolution vs support: an honest, additive statement. The Check verifies resolution and
    # structure only (the register above); it does not verify that a cited line supports its
    # claim. Support is the source-to-claim audit, recorded separately by the AI.
    scope = [
        "**Scope.** This Check verifies **resolution and structure**: every Citation points to a "
        "real file and line inside the Target (see the Citation register). It does **not** verify "
        "**support** -- whether the cited line actually backs the claim it is attached to. Support "
        "is established by the source-to-claim audit, a separate review recorded in the "
        "Verification section below. A PASS means the citations resolve and the structure holds; "
        "it is not an accuracy certification.",
        "",
    ]

    verification_path = os.path.join(out_dir, VERIFICATION)
    if os.path.isfile(verification_path):
        record = _read_text(verification_path).strip()
        verification = [
            "## Verification",
            "",
            "**Source-to-claim audit:** recorded (from `verification.md`). The Check above "
            "verifies resolution only; the audit below records whether the cited lines support "
            "the claims.",
            "",
            record,
        ]
        verification_status = "Source-to-claim audit: recorded in verification.md"
    else:
        verification = [
            "## Verification",
            "",
            "**Source-to-claim audit:** not recorded. This report covers resolution and "
            "structure only; it does not confirm that the cited lines support the claims. "
            "Run the source-to-claim audit (see the skill workflow) and write "
            "`docs/appdoc/verification.md` to record it.",
        ]
        verification_status = (
            "Source-to-claim audit: not recorded -- resolution only; support not confirmed."
        )

    os.makedirs(out_dir, exist_ok=True)
    with open(os.path.join(out_dir, REPORT), "w", encoding="utf-8", newline="\n") as fh:
        fh.write("\n".join([head, ""] + scope + body + reg + [""] + verification) + "\n")
    print("\n".join([head] + [b for b in body if b] + [verification_status]))
    return 0 if total == 0 else 2
