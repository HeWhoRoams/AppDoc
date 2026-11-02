"""Deterministic file walk and text loading."""

from __future__ import annotations

import fnmatch
import os
from dataclasses import dataclass

ALWAYS_IGNORE_DIRS = {
    ".git", ".svn", ".hg", ".vs", ".idea", "node_modules", "bin", "obj", "target",
    "build", "dist", "out", "vendor", "packages", "__pycache__", ".venv", "venv",
    ".gradle", ".mvn",
}
MAX_BYTES = 2 * 1024 * 1024


@dataclass(frozen=True)
class SourceFile:
    path: str          # Target-relative, forward slashes
    size: int
    skipped: str | None  # None, "size" or "binary"
    encoding: str | None

    @property
    def ext(self) -> str:
        base = self.path.rsplit("/", 1)[-1]
        return base[base.rfind("."):].lower() if "." in base else ""


def _load_ignore(root: str):
    patterns = []
    p = os.path.join(root, ".appdocignore")
    if os.path.isfile(p):
        with open(p, encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                s = raw.strip()
                if s and not s.startswith("#"):
                    patterns.append(s.rstrip("/"))
    return patterns


def _ignored(rel: str, patterns) -> bool:
    parts = rel.split("/")
    for pat in patterns:
        if fnmatch.fnmatch(rel, pat) or any(fnmatch.fnmatch(part, pat) for part in parts):
            return True
    return False


def walk(root: str, out_dir: str | None = None) -> list[SourceFile]:
    """Return every file under root in stable sorted order, with skip flags set."""
    root = os.path.abspath(root)
    out_abs = os.path.abspath(out_dir) if out_dir else None
    patterns = _load_ignore(root)
    found: list[SourceFile] = []
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(
            d for d in dirnames
            if d not in ALWAYS_IGNORE_DIRS
            and not (out_abs and os.path.abspath(os.path.join(dirpath, d)) == out_abs)
        )
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            if _ignored(rel, patterns):
                continue
            try:
                size = os.path.getsize(full)
            except OSError:
                continue
            skipped = None
            encoding = None
            if size > MAX_BYTES:
                skipped = "size"
            else:
                try:
                    with open(full, "rb") as fh:
                        head = fh.read(8192)
                except OSError:
                    continue
                if b"\0" in head:
                    skipped = "binary"
            found.append(SourceFile(rel, size, skipped, encoding))
    found.sort(key=lambda f: f.path)
    return found


def read_text(root: str, rel: str) -> tuple[str, str]:
    """Read a file as text. Returns (text, encoding). Never raises on decoding."""
    with open(os.path.join(root, rel), "rb") as fh:
        raw = fh.read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.decode("cp1252", errors="replace"), "cp1252"
