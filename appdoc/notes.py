"""Notes about generated blocks: `docs/appdoc/notes.jsonl`, one JSON object per line.

    {"block": "entry-points", "text": "...", "cites": ["path:line"], "block_sha": ""}

A limitation of a generated block (what the extractor does not see) is data, not Narrative: `fill` renders
each note inside its block, after the generated rows, as `Known extractor limitation: <text> (<cites>)`.
`block_sha` is the 12-hex hash of the block's generated body (the notes are not part of it) when the note was
written; `appdoc build` fills an empty one and never overwrites one (check rule C18 fails a note whose block has
changed since). This module is the only reader and writer of the file. It is a Narrative-side file: Facts never
read it.
"""

from __future__ import annotations

import hashlib
import json
import os
import re

from .textnorm import normalize_text
from .textutil import read_text

NOTES = "notes.jsonl"
LABEL = "Known extractor limitation:"      # reserved: C18 fails it in hand-written Narrative
NOTE_KEYS = ("block", "text", "cites", "block_sha")
SHA_RE = re.compile(r"^[0-9a-f]{12}$")


class Notes:
    def __init__(self):
        self.notes: list[tuple[int, dict]] = []     # (1-based line, note) in file order
        self.errors: list[tuple[int, str]] = []     # (line, what is wrong)

    def for_block(self, name: str) -> list[dict]:
        return [n for _, n in self.notes if n["block"] == name]


def parse(text: "str | None") -> Notes:
    """Parse the text of notes.jsonl (None or "" for a missing file). Bad lines are reported, never skipped silently."""
    out = Notes()
    for no, line in enumerate((text or "").splitlines(), 1):
        if not line.strip():
            continue
        try:
            obj = json.loads(line)
        except ValueError:
            out.errors.append((no, "not valid JSON"))
            continue
        missing = [k for k in NOTE_KEYS if not isinstance(obj, dict) or k not in obj]
        if missing:
            out.errors.append((no, "a note needs " + ", ".join(missing) if isinstance(obj, dict)
                               else "a note must be a JSON object"))
        elif not (isinstance(obj["block"], str) and obj["block"]):
            out.errors.append((no, '"block" must be the name of a generated block'))
        elif not (isinstance(obj["text"], str) and obj["text"].strip()) or "\n" in obj["text"] or "\r" in obj["text"]:
            out.errors.append((no, '"text" must be one non-empty line'))
        elif not (isinstance(obj["cites"], list) and all(isinstance(c, str) and c.strip() for c in obj["cites"])):
            out.errors.append((no, '"cites" must be a list of Citations'))
        elif not (isinstance(obj["block_sha"], str) and (obj["block_sha"] == "" or SHA_RE.match(obj["block_sha"]))):
            out.errors.append((no, '"block_sha" must be empty or 12 lowercase hex characters'))
        else:
            out.notes.append((no, obj))
    return out


def load(out_dir: "str | None") -> Notes:
    """The notes beside facts.json (none when there is no out_dir or no file)."""
    path = os.path.join(out_dir, NOTES) if out_dir else None
    return parse(read_text(path) if path and os.path.isfile(path) else None)


def render(note: dict) -> str:
    """The Narrative line for one note."""
    cites = ", ".join(f"`{c.strip().strip('`')}`" for c in note["cites"])
    return f"{LABEL} {note['text'].strip()}" + (f" ({cites})" if cites else "")


def body_sha(body: str) -> str:
    """12-hex SHA-1 of a block's generated body, through the text normalization (R14)."""
    return hashlib.sha1(normalize_text(body).encode("utf-8")).hexdigest()[:12]


def seal(path: str, shas: dict[str, str]) -> int:
    """Write block_sha (shas maps block name to the sha of its body) into every note whose block_sha is empty.

    Never overwrites one. Keeps the file's line ending. Returns the number of notes sealed.
    """
    with open(path, encoding="utf-8-sig", newline="") as fh:
        raw = fh.read()
    nl = "\r\n" if "\r\n" in raw else "\n"
    out, sealed = [], 0
    for line in raw.splitlines():
        try:
            obj = json.loads(line)
        except ValueError:
            out.append(line)
            continue
        if isinstance(obj, dict) and obj.get("block_sha") == "" and obj.get("block") in shas:
            obj["block_sha"] = shas[obj["block"]]
            sealed += 1
            line = json.dumps(obj, ensure_ascii=False)
        out.append(line)
    if sealed:
        with open(path, "w", encoding="utf-8", newline="") as fh:
            fh.write(nl.join(out) + nl)
    return sealed
