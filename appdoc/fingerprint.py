"""The fingerprint of a Narrative: the text the Check and the audit read, and the hashes over it.

`document_text` is the one reading of the Narrative (newlines normalized, opaque generated blocks masked, comments
stripped); `doc_sha` fingerprints it (the audit's seed and line 1 of the register); `claim_sha` fingerprints the text
one register row points to. The seal (appdoc/seal.py) writes them; the Check (appdoc/check.py) compares them.
"""

from __future__ import annotations

import hashlib
import re

from . import docmodel as dm
from . import register as reg_mod
from . import template_spec as spec
from .textnorm import normalize_newlines, normalize_text


_NON_ALNUM = re.compile(r"[^a-z0-9]+")


def row_slug(first_cell: str) -> str:
    """The slug of a table row (R71.A1a): its first cell, lower-cased, runs of non-alphanumerics to `-`, trimmed
    (`row` when nothing is left)."""
    return _NON_ALNUM.sub("-", first_cell.lower()).strip("-") or "row"


def row_keys(lines, heads, section: str) -> list[tuple[str, list[str], int]]:
    """(key, cells, 1-based line) of every row of the first table under `section`: `<section>/<slug>`, a repeated
    slug suffixed `-2`, `-3` in row order. All rows count, so a row's key does not move when another row's status
    changes; renaming the first cell re-keys the row (a changed claim)."""
    h = heads.get(section)
    t = dm.first_table(lines, h) if h else None
    if t is None:
        return []
    seen: dict[str, int] = {}
    out = []
    for no, cells in t.rows:
        slug = row_slug(dm.cell_text(cells[0])) if cells else "row"
        seen[slug] = seen.get(slug, 0) + 1
        out.append((f"{section}/{slug}" + (f"-{seen[slug]}" if seen[slug] > 1 else ""), cells, no))
    return out


def claim_sha(lines, heads, ids, ref):
    """12-hex-char SHA-1 over the normalised text a ref points to. None if the ref is unresolvable."""
    m = reg_mod.REF_RE.match(ref)
    if not m:
        return None
    sec_key, id_part = m.group(1), m.group(2)
    if m.group(3):
        if sec_key not in spec.ROW_KEY_SECTIONS:
            return None
        # per-row key: the table row it names
        row = next((no for key, _, no in row_keys(lines, heads, sec_key) if key == ref), None)
        if row is None:
            return None
        text = lines[row - 1]
    elif id_part and id_part in ids:
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
        text = dm.mask_blocks("\n".join(lines[h.idx: h.end]), spec.OPAQUE_BLOCKS)
    else:
        return None
    text = " ".join(normalize_text(dm.strip_comments(text)).split())
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:12]


def document_text(raw: str, mask_counts: bool = False, pad: bool = True) -> str:
    """The Narrative text the Check reads (C11, claim_sha) and the audit fingerprint hashes: newlines
    normalized, opaque generated blocks masked, comments stripped, line numbering kept. With
    `mask_counts` the count markers are removed too (their number is filled by `fill`, not written). Without `pad`
    the line numbering is not kept (a masked block and a multi-line comment each leave a fixed number of lines), so
    what `fill` writes into a block cannot move a fingerprint."""
    text = dm.mask_blocks(normalize_newlines(raw), spec.OPAQUE_BLOCKS, pad)
    if mask_counts:
        text = spec.COUNT_MARKER_RE.sub(lambda m: "\n" * m.group(0).count("\n") if pad else "", text)
    return dm.strip_comments(text) if pad else dm.COMMENT_RE.sub(lambda m: "\n" if "\n" in m.group(0) else "", text)


def doc_sha(raw: str) -> str:
    """12-hex SHA-1 fingerprint of the Narrative as the auditor read it (line 1 `doc_sha` of the register)."""
    text = normalize_text(document_text(raw, mask_counts=True, pad=False))
    return hashlib.sha1(text.encode("utf-8")).hexdigest()[:12]
