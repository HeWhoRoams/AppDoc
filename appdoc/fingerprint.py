"""The fingerprint of a Narrative: the text the Check and the audit read, and the hashes over it.

`document_text` is the one reading of the Narrative (newlines normalized, opaque generated blocks masked, comments
stripped); `doc_sha` fingerprints it (the audit's seed and line 1 of the register); `claim_sha` fingerprints the text
one register row points to. The seal (appdoc/seal.py) writes them; the Check (appdoc/check.py) compares them.
"""

from __future__ import annotations

import hashlib

from . import docmodel as dm
from . import register as reg_mod
from . import template_spec as spec
from .textnorm import normalize_newlines, normalize_text


def claim_sha(lines, heads, ids, ref):
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
