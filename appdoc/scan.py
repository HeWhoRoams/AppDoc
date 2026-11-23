"""Deterministic file walk and text loading."""

from __future__ import annotations

import fnmatch
import mmap
import os
import re
from dataclasses import dataclass

from . import facts as F

VCS_DIRS = {".git", ".svn", ".hg"}  # repository metadata: pruned and not counted as Target files
ALWAYS_IGNORE_DIRS = VCS_DIRS | {".vs", ".idea", "__pycache__", ".venv", "venv", ".gradle", "node_modules", ".mvn"}
MAX_BYTES = 2 * 1024 * 1024
_MMAP_THRESHOLD = 1024 * 1024  # use mmap (and skip the in-memory read) above 1MiB
# OS and authoring metadata (closed set, 1.4A.4): dropped in walk and counted, not scanned.
OS_METADATA_FILES = {"desktop.ini", "thumbs.db", ".ds_store"}
VTI_PREFIX = "_vti_"

_DOTNET_PROJECT = (".csproj", ".vbproj", ".sln")


def _has(names, *wanted) -> bool:
    return any(n in wanted for n in names)


def _has_ext(names, exts) -> bool:
    return any(n.lower().endswith(exts) for n in names)


def _child_names(path: str) -> list[str]:
    try:
        return os.listdir(path)
    except OSError:
        return []


def prune_rule(name: str, parent_files: list[str], full: str, dotnet_above: bool) -> str | None:
    """The rule that prunes folder `name`, or None to scan it. Uses the tree only, never git."""
    if name in ALWAYS_IGNORE_DIRS:
        return "always"
    if name in ("bin", "obj"):
        return ".NET build output" if dotnet_above or _has_ext(parent_files, _DOTNET_PROJECT) else None
    if name == "target":
        return "Maven/Cargo build output" if _has(parent_files, "pom.xml", "Cargo.toml") else None
    if name == "build":
        return "Gradle/CMake build output" if _has(
            parent_files, "build.gradle", "build.gradle.kts", "CMakeLists.txt") else None
    if name in ("dist", "out"):
        if _has(parent_files, "package.json", "tsconfig.json") or _has_ext(parent_files, (".csproj",)):
            return "JavaScript/.NET build output"
        return None
    if name == "packages":
        kids = _child_names(full)
        if _has_ext(kids, (".nupkg",)) or "repositories.config" in kids \
                or "packages.config" in parent_files or _has_ext(parent_files, (".sln",)):
            return "NuGet package cache"
        return None
    if name == "vendor":
        kids = _child_names(full)
        if "modules.txt" in kids:
            return "Go vendored modules"
        if "autoload.php" in kids:
            return "Composer vendored packages"
        if "Gemfile" in parent_files and "bundle" in kids:
            return "Bundler vendored gems"
    return None


def _count_files(path: str) -> int:
    n = 0
    for _, dirs, files in os.walk(path):
        dirs[:] = [d for d in dirs if d not in VCS_DIRS]
        n += len(files)
    return n


@dataclass(frozen=True)
class SourceFile:
    path: str          # Target-relative, forward slashes
    size: int
    skipped: str | None  # None, "size", "binary" or "test"
    encoding: str | None

    @property
    def ext(self) -> str:
        base = self.path.rsplit("/", 1)[-1]
        return base[base.rfind("."):].lower() if "." in base else ""


def _load_ignore(root: str) -> tuple[list[str], list[str]]:
    """(ignore patterns, `!` re-include patterns) from .appdocignore."""
    patterns, keep = [], []
    p = os.path.join(root, ".appdocignore")
    if os.path.isfile(p):
        with open(p, encoding="utf-8", errors="replace") as fh:
            for raw in fh:
                s = raw.strip()
                if s and not s.startswith("#"):
                    (keep if s.startswith("!") else patterns).append(s.lstrip("!").rstrip("/"))
    return patterns, keep


def _ignored(rel: str, patterns) -> bool:
    parts = rel.split("/")
    for pat in patterns:
        if fnmatch.fnmatch(rel, pat) or any(fnmatch.fnmatch(part, pat) for part in parts):
            return True
        # A pattern naming a directory excludes everything beneath it.
        if rel.startswith(pat + "/"):
            return True
    return False


def walk(root: str, out_dir: str | None = None, stats: dict | None = None,
         skip_tests: bool = False) -> list[SourceFile]:
    """Return every file under root in stable sorted order, with skip flags set.

    When `stats` is given it receives `ignored` (files dropped by .appdocignore), `pruned`
    (one {path, rule, files} per pruned folder that held files; VCS metadata is not counted),
    `metadata` and `retired_candidates`. With `skip_tests` a test file is flagged
    ``skipped="test"`` (never read or extracted); the default (``skip_tests=False``) is unchanged.
    """
    root = os.path.abspath(root)
    out_abs = os.path.abspath(out_dir) if out_dir else None
    patterns, keep = _load_ignore(root)
    found: list[SourceFile] = []
    pruned: list[dict] = []
    ignored = 0
    metadata = 0
    dotnet: dict[str, bool] = {}
    for dirpath, dirnames, filenames in os.walk(root):
        parent = os.path.dirname(dirpath)
        above = dotnet.get(parent, False) if dirpath != root else False
        dotnet[dirpath] = above or _has_ext(filenames, _DOTNET_PROJECT)
        kept = []
        for d in sorted(dirnames):
            full_d = os.path.join(dirpath, d)
            if out_abs and os.path.abspath(full_d) == out_abs:
                continue
            rel_d = os.path.relpath(full_d, root).replace(os.sep, "/")
            if d.lower().startswith(VTI_PREFIX):
                if stats is not None:
                    metadata += _count_files(full_d)
                continue
            rule = prune_rule(d, filenames, full_d, dotnet[dirpath])
            if rule and not _ignored(rel_d, keep):
                if stats is not None and d not in VCS_DIRS:
                    n = _count_files(full_d)
                    if n:
                        pruned.append({"path": rel_d + "/", "rule": rule, "files": n})
                continue
            kept.append(d)
        dirnames[:] = kept
        for name in sorted(filenames):
            full = os.path.join(dirpath, name)
            rel = os.path.relpath(full, root).replace(os.sep, "/")
            if _ignored(rel, patterns):
                ignored += 1
                continue
            if name.lower() in OS_METADATA_FILES:
                if stats is not None:
                    metadata += 1
                continue
            try:
                size = os.path.getsize(full)
            except OSError:
                continue
            skipped = None
            encoding = None
            if size > MAX_BYTES:
                skipped = "size"
            elif skip_tests and F.is_test_path(rel):
                skipped = "test"
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
    if stats is not None:
        stats["ignored"] = ignored
        stats["pruned"] = sorted(pruned, key=lambda p: p["path"])
        stats["metadata"] = metadata
        stats["retired_candidates"] = _retired_candidates(root, found)
    return found


def read_bytes(root: str, rel: str) -> bytes:
    """Read a file's raw bytes. Uses mmap for files above the 1MiB threshold."""
    full = os.path.join(root, rel)
    try:
        size = os.path.getsize(full)
    except OSError:
        return b""  # file deleted between getsize and open (TOCTOU)
    if size > _MMAP_THRESHOLD:
        with open(full, "rb") as fh:
            with mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ) as mm:
                return mm[:]
    with open(full, "rb") as fh:
        return fh.read()


def _decode(raw: bytes) -> tuple[str, str]:
    """Decode raw bytes. Returns (text, encoding). Never raises on decoding."""
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.decode("cp1252", errors="replace"), "cp1252"


def read_text(root: str, rel: str) -> tuple[str, str]:
    """Read a file as text. Returns (text, encoding). Never raises on decoding."""
    return _decode(read_bytes(root, rel))


# Folders that look retired by name (1.4B): a whole token from this set, or "to be deleted".
_RETIRED_TOKENS = {"old", "bak", "backup", "archive", "archived", "deprecated", "retired",
                   "obsolete", "unused", "copy", "trash", "deleteme"}
_RETIRED_PHRASES = ("tobedeleted", "to be deleted")


def _retired_name_signal(name: str) -> str | None:
    tokens = set(re.split(r"[^a-z0-9]+", name.lower()))
    if tokens & _RETIRED_TOKENS:
        return "name"
    if any(p in name.lower() for p in _RETIRED_PHRASES):
        return "name"
    return None


def _retired_candidates(root: str, files: list[SourceFile]) -> list[dict]:
    """Folders that look retired by name or by content (>=5 files, half byte-identical to a file outside).

    A folder is any prefix of a scanned file's path. The shallowest matching folder wins (so
    `To be deleted/Front Dev/x.asp` reports `To be deleted/`, not the nested folder).
    """
    folders: set[str] = set()
    for f in files:
        parts = f.path.split("/")[:-1]
        for i in range(1, len(parts) + 1):
            folders.add("/".join(parts[:i]))
    out = []
    for folder in sorted(folders):
        name = folder.rsplit("/", 1)[-1]
        signal = _retired_name_signal(name)
        if signal is None:
            fs = [f for f in files if f.path.startswith(folder + "/")]
            if len(fs) < 5:
                continue
            outside_hashes: set[bytes] = set()
            for f in files:
                if not f.path.startswith(folder + "/"):
                    try:
                        with open(os.path.join(root, f.path), "rb") as fh:
                            outside_hashes.add(fh.read())
                    except OSError:
                        continue
            dup = 0
            for f in fs:
                try:
                    with open(os.path.join(root, f.path), "rb") as fh:
                        if fh.read() in outside_hashes:
                            dup += 1
                except OSError:
                    continue
            if dup * 2 >= len(fs):
                signal = "content"
        if signal:
            fs = [f for f in files if f.path.startswith(folder + "/")]
            out.append({"path": folder + "/", "signal": signal, "files": len(fs)})
    return out


def is_binary(full: str) -> bool:
    """True if the file has a NUL byte in its first 8192 bytes (the same test walk uses)."""
    try:
        with open(full, "rb") as fh:
            return b"\0" in fh.read(8192)
    except OSError:
        return False
