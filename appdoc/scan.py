"""Deterministic file walk and text loading."""

from __future__ import annotations

import fnmatch
import hashlib
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
    `metadata`, `retired_candidates` (by name) and `duplicate_folders`. With `skip_tests` a test file is flagged
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
        by_path, by_hash = _content_index(root, found)
        stats["retired_candidates"] = _retired_candidates(found)
        stats["duplicate_folders"] = _duplicate_folders(found, by_path, by_hash)
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


def _under(path: str, folder: str) -> bool:
    """True when `path` (a file or a folder) is `folder` or lies beneath it; both end without a slash."""
    return path == folder or path.startswith(folder + "/")


def _folders_of(files: list[SourceFile]) -> list[str]:
    """Every folder that is a prefix of a scanned file's path, sorted."""
    folders: set[str] = set()
    for f in files:
        parts = f.path.split("/")[:-1]
        for i in range(1, len(parts) + 1):
            folders.add("/".join(parts[:i]))
    return sorted(folders)


def _collapse_nested(paths: list[str]) -> list[str]:
    """Drop every folder that lies beneath another folder in the list (input sorted, trailing slashes)."""
    kept: list[str] = []
    for p in sorted(paths):
        if not any(p.startswith(k) for k in kept):
            kept.append(p)
    return kept


def _retired_candidates(files: list[SourceFile]) -> list[dict]:
    """Folders that look retired by name; a folder beneath another candidate is not listed again.

    A folder is any prefix of a scanned file's path. The shallowest matching folder wins (so
    `To be deleted/Front Dev/x.asp` reports `To be deleted/`, not the nested folder). Byte-identical
    folders are not retired candidates; they are `duplicate_folders`.
    """
    count: dict[str, int] = {}
    for folder in _folders_of(files):
        if _retired_name_signal(folder.rsplit("/", 1)[-1]):
            count[folder + "/"] = sum(1 for f in files if f.path.startswith(folder + "/"))
    return [{"path": p, "signal": "name", "files": count[p]} for p in _collapse_nested(list(count))]


def _sha1_file(full: str) -> str:
    """SHA-1 of a file's bytes, read in 64 KiB chunks."""
    h = hashlib.sha1()
    with open(full, "rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def _content_index(root: str, files: list[SourceFile]) -> tuple[dict, dict]:
    """(path -> SHA-1, SHA-1 -> sorted paths): one streaming read per scanned non-test file.

    Skipped files (oversize, binary, test) are never read, and files under test paths are left out
    (R5). An empty file is not indexed: every empty file is byte-identical to every other, which is
    not evidence of a copy.
    """
    by_path: dict[str, str] = {}
    by_hash: dict[str, list[str]] = {}
    for f in files:
        if f.skipped or f.size == 0 or F.is_test_path(f.path):
            continue
        try:
            digest = _sha1_file(os.path.join(root, f.path))
        except OSError:
            continue
        by_path[f.path] = digest
        by_hash.setdefault(digest, []).append(f.path)
    for paths in by_hash.values():
        paths.sort()
    return by_path, by_hash


DUPLICATE_MIN_FILES = 5


def _duplicate_folders(files: list[SourceFile], by_path: dict, by_hash: dict) -> list[dict]:
    """Pairs of folders where one is mostly a byte-identical copy of another: `{a, b, files}`.

    A folder A with at least 5 non-test files qualifies when at least half of its files have a
    byte-identical file outside A. It pairs with the folder B (outside A, neither above nor below it)
    that holds the most of those matches; a tie goes to the smallest path. `files` is how many of A's
    files have a match in B. A pair found from both sides is stored once with `a < b` (the larger
    `files`), a pair nested inside another pair is dropped, and the list is sorted.
    """
    mine: dict[str, list[str]] = {}
    for f in files:
        if not f.skipped and not F.is_test_path(f.path):
            parts = f.path.split("/")[:-1]
            for i in range(1, len(parts) + 1):
                mine.setdefault("/".join(parts[:i]), []).append(f.path)
    holders: dict[str, set] = {}   # hash -> every folder that holds or contains a file with it

    def folders_with(digest):
        got = holders.get(digest)
        if got is None:
            got = holders[digest] = {"/".join(p.split("/")[:i]) for p in by_hash[digest]
                                     for i in range(1, len(p.split("/")))}
        return got

    pairs: dict[tuple, int] = {}
    for a in sorted(mine):
        fs = mine[a]
        if len(fs) < DUPLICATE_MIN_FILES:
            continue
        own: dict[str, int] = {}
        for p in fs:
            if p in by_path:
                own[by_path[p]] = own.get(by_path[p], 0) + 1
        matched = 0
        score: dict[str, int] = {}
        for p in fs:
            digest = by_path.get(p)
            if digest is None or len(by_hash[digest]) <= own[digest]:
                continue
            matched += 1
            for b in folders_with(digest):
                if not _under(b, a) and not _under(a, b):
                    score[b] = score.get(b, 0) + 1
        if not score or matched * 2 < len(fs):
            continue
        best = max(score.values())
        b = min(k for k, v in score.items() if v == best)
        key = (a + "/", b + "/") if a < b else (b + "/", a + "/")
        pairs[key] = max(pairs.get(key, 0), best)
    def inside(k, o):
        return (k[0].startswith(o[0]) and k[1].startswith(o[1])) or (k[0].startswith(o[1]) and k[1].startswith(o[0]))
    kept = [k for k in pairs if not any(o != k and inside(k, o) for o in pairs)]
    return [{"a": a, "b": b, "files": pairs[(a, b)]} for a, b in sorted(kept)]


def is_binary(full: str) -> bool:
    """True if the file has a NUL byte in its first 8192 bytes (the same test walk uses)."""
    try:
        with open(full, "rb") as fh:
            return b"\0" in fh.read(8192)
    except OSError:
        return False
