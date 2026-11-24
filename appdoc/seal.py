"""Seal: write the hashes into the register and the notes, and the opt-in citation rewrite (`appdoc build`, `appdoc seal`).

A seal records what the Narrative said when a row was audited (`claim_sha`, `doc_sha`, `block_sha`); the Check
(appdoc/check.py) compares them. Nothing here reads the rules.
"""

from __future__ import annotations

import json
import os

from . import __version__, version
from . import docmodel as dm
from . import fill as fill_mod
from . import fingerprint
from . import notes as notes_mod
from . import register as reg_mod
from . import template_spec as spec
from .check import FACTS, FAILS_FROM, NARRATIVE, REGISTER, c1_bare_name, defined_ids
from .citations import Citation, expand_bare
from .textnorm import normalize_newlines
from .textutil import read_text


def seal_register(target, out_dir, audit: bool = False, date: str | None = None) -> int:
    """Write claim_sha into every ID, workflow and per-row (`10.2/<slug>`) register row that lacks one. Returns rows sealed.

    From template 2.7 the rows also get `sealed_by`: "audit" when line 1's doc_sha equals the Narrative's
    current fingerprint (the text was audited), else "upgrade". `audit` (with `date`, YYYY-MM-DD) is the
    auditor finishing the audit: line 1 gets audited_on/audited_with/audited_bundle/doc_sha and the rows
    sealed now are "audit". Superseded rows are never sealed, nor are Answerable and Dismissed rows or the other
    section-level rows (ADR 0015).
    """
    md_path = os.path.join(out_dir, NARRATIVE)
    reg_path = os.path.join(out_dir, REGISTER)
    if not os.path.isfile(md_path) or not os.path.isfile(reg_path):
        return 0
    if spec.stamp_version(read_text(md_path)) >= FAILS_FROM:
        fill_mod.fill_facts_blocks(target, out_dir)   # the fingerprint is that of the filled document (S6.1)
    raw = read_text(md_path)
    lines = fingerprint.document_text(raw).splitlines()
    heads = dm.headings(lines)
    ids = defined_ids(lines, heads, lambda *a: None)
    reg = reg_mod.parse(read_text(reg_path))
    current_sha = fingerprint.doc_sha(raw)
    audit_fields = sealed_by = None
    if audit:
        audit_fields = {"audited_on": date, "audited_with": __version__,
                        "audited_bundle": version.bundle_hash()[:version.BUNDLE_LEN], "doc_sha": current_sha}
        sealed_by = "audit"
    else:
        if spec.stamp_version(raw) >= FAILS_FROM:
            sealed_by = "audit" if (reg.audit or {}).get("doc_sha") == current_sha else "upgrade"
    claim_shas: dict[str, str] = {}
    for _, row in reg.live_rows():   # a superseded row records history and is never sealed
        if row["result"] in ("Dismissed", "Answerable"):
            continue
        m = reg_mod.REF_RE.match(str(row["ref"]))
        if not m:
            continue
        sec_key, id_part = m.group(1), m.group(2)
        if not (id_part or m.group(3) or sec_key.startswith("7.")):
            continue
        sha = fingerprint.claim_sha(lines, heads, ids, str(row["ref"]))
        if sha:
            claim_shas[str(row["id"])] = sha
    return reg_mod.seal(reg_path, claim_shas, sealed_by, audit_fields)


def expand_citations(target, out_dir) -> int:
    """Rewrite the unique bare-name Citations of the Narrative to their full path (opt-in, `build --expand-citations`).

    Same rule as the C1 2.7 check (_c1_bare_name): a name with one file outside the Target root, not a known bare
    file. Fenced code, comments and generated blocks are left alone. Returns the number of spans rewritten."""
    path = os.path.join(out_dir, NARRATIVE)
    if not os.path.isfile(path):
        return 0
    raw = normalize_newlines(read_text(path))
    cache: dict = {"__out__": out_dir}

    def full_of(name):
        return c1_bare_name(target, cache, Citation(0, name, None, None, name))

    parts, last, total = [], 0, 0
    for m in dm.BLOCK_RE.finditer(raw):
        new, n = expand_bare(raw[last:m.start()], full_of)
        parts += [new, m.group(0)]
        total += n
        last = m.end()
    new, n = expand_bare(raw[last:], full_of)
    total += n
    if total:
        with open(path, "w", encoding="utf-8", newline="\n") as fh:
            fh.write("".join(parts) + new)
    return total


def seal_notes(target, out_dir) -> int:
    """Write block_sha into every note of notes.jsonl that lacks one (the sha of its block's generated body, notes
    excluded). Never overwrites one. Returns notes sealed; 0 when there is no notes file or no Facts."""
    path = os.path.join(out_dir, notes_mod.NOTES)
    facts_path = os.path.join(out_dir, FACTS)
    if not os.path.isfile(path) or not os.path.isfile(facts_path):
        return 0
    facts = json.loads(read_text(facts_path))
    md = os.path.join(out_dir, NARRATIVE)
    ctx = {"out_dir": out_dir, "target": target, "text": read_text(md) if os.path.isfile(md) else None}
    shas = {}
    for _, note in notes_mod.parse(read_text(path)).notes:
        body = fill_mod.generated_body(note["block"], facts, ctx)
        if note["block_sha"] == "" and body is not None:
            shas[note["block"]] = notes_mod.body_sha(body)
    return notes_mod.seal(path, shas)
