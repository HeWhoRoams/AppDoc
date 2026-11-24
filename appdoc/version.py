"""The one place that knows which AppDoc is running: version, bundle hash and the provenance record.

``provenance()`` is what ``extract`` writes to docs/appdoc/provenance.json (no timestamps, so two
runs of the same build are byte-identical). ``facts.json`` carries no generator; an AppDoc patch
that changes no Facts therefore changes no Facts file.
"""

from __future__ import annotations

import hashlib
import json
import os

from . import facts
from .textnorm import normalize_newlines
from . import __version__  # the literal lives in appdoc/__init__.py (the release script edits it there)

BUNDLE_LEN = 12
PROVENANCE_FILE = "provenance.json"


def _bundle_files() -> list:
    pkg_dir = os.path.dirname(os.path.abspath(__file__))
    found = []
    for dirpath, dirnames, filenames in os.walk(pkg_dir):
        dirnames[:] = sorted(d for d in dirnames if d != "__pycache__")
        for fname in sorted(filenames):
            if not fname.endswith((".pyc", ".pyo")):
                full = os.path.join(dirpath, fname)
                found.append((os.path.relpath(full, pkg_dir).replace(os.sep, "/"), full))
    return found


_memo: dict = {}


def bundle_hash() -> str:
    """A deterministic SHA-1 over the appdoc package files (path + content).

    Bytecode and caches are skipped and CRLF is read as LF, so the hash is the same on every OS
    and whether or not the package has been imported before. The result is memoised per process
    against each file's (size, mtime), so editing a file still changes it.
    """
    files = _bundle_files()
    sig = tuple((rel, os.stat(full).st_size, os.stat(full).st_mtime_ns) for rel, full in files)
    if _memo.get("sig") == sig:
        return _memo["hash"]
    h = hashlib.sha1()
    for rel, full in files:
        h.update(rel.encode("utf-8"))
        h.update(b"\0")
        with open(full, "rb") as fh:
            h.update(normalize_newlines(fh.read()))
        h.update(b"\0")
    _memo.update(sig=sig, hash=h.hexdigest())
    return _memo["hash"]


def provenance() -> dict:
    """{"generator", "bundle" (12 hex), "schema"} for the running AppDoc."""
    return {"generator": __version__, "bundle": bundle_hash()[:BUNDLE_LEN], "schema": facts.SCHEMA}


def dumps_provenance(prov: dict) -> str:
    return json.dumps(prov, sort_keys=True, indent=1) + "\n"


def read_provenance(out_dir: str):
    """The parsed provenance.json beside facts.json, or None when it is missing or unreadable."""
    try:
        with open(os.path.join(out_dir, PROVENANCE_FILE), encoding="utf-8") as fh:
            doc = json.load(fh)
    except (OSError, ValueError):
        return None
    return doc if isinstance(doc, dict) else None


def write_blocks_by(out_dir: str) -> None:
    """Record which AppDoc wrote the generated blocks (fill). Keeps the keys extract wrote; no-op when absent."""
    prov = read_provenance(out_dir)
    if prov is None:
        return
    now = provenance()
    blocks_by = {"generator": now["generator"], "bundle": now["bundle"]}
    if prov.get("blocks_by") != blocks_by:
        prov["blocks_by"] = blocks_by
        with open(os.path.join(out_dir, PROVENANCE_FILE), "w", encoding="utf-8", newline="\n") as fh:
            fh.write(dumps_provenance(prov))
