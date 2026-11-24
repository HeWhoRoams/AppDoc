"""Stack registry. Order is fixed; every detected Stack runs, and ``generic`` always runs."""

from __future__ import annotations

import importlib
import os
import re

from .. import scan
from ..facts import is_test_data_path, is_test_path

# Every module exposes a module-level ``STACK`` instance.
MODULES = (
    "classic_asp",
    "aspnet",
    "aspnet_core",
    "java_spring",
    "python_flask",
    "node_express",
    "go",
)


def load() -> list:
    return [importlib.import_module(f"{__package__}.{name}").STACK for name in MODULES]


def capabilities_of(stack) -> frozenset:
    """The only capability lookup. ``stack`` is a Stack instance.

    Dotted detail capabilities (``entry_point.job``) are part of the set.
    """
    return frozenset(getattr(type(stack), "capabilities", frozenset()))


# --------------------------------------------------------------------------- marker filtering (T28.11)

_PROJECT_EXTS = (".csproj", ".vbproj")
_TEST_REF = re.compile(
    r'(?i)\b(?:Include|Update)\s*=\s*"(?:Microsoft\.NET\.Test\.Sdk|MSTest[\w.]*|xunit[\w.]*|NUnit[\w.]*|'
    r'Microsoft\.VisualStudio\.QualityTools\.UnitTestFramework[\w.,= ]*)"')
_MAX_PROJECT_BYTES = 1 << 20


def _dir_of(path: str) -> str:
    return path.rsplit("/", 1)[0] if "/" in path else ""


def test_project_dirs(files, root: str | None) -> frozenset:
    """Folders (Target-relative, ``""`` for the root) of projects that reference a test framework.

    Needs ``root`` to read the project files; without it no project is recognised as a test project.
    """
    if root is None:
        return frozenset()
    out = set()
    for p in files:
        if not p.lower().endswith(_PROJECT_EXTS):
            continue
        try:
            if os.path.getsize(os.path.join(root, p)) > _MAX_PROJECT_BYTES:
                continue
            text = scan.read_text(root, p)[0]
        except OSError:
            continue
        if _TEST_REF.search(text):
            out.add(_dir_of(p))
    return frozenset(out)


def _in_test_project(path: str, test_dirs: frozenset, project_dirs: frozenset) -> bool:
    """True when the nearest enclosing project of ``path`` is a test project."""
    d = _dir_of(path)
    while True:
        if d in project_dirs:
            return d in test_dirs
        if not d:
            return False
        d = _dir_of(d)


def drop_test_files(files, root: str | None = None) -> list:
    """``files`` without test paths, fixture folders and files inside test projects."""
    files = list(files)
    kept = [p for p in files if not is_test_path(p) and not is_test_data_path(p)]
    test_dirs = test_project_dirs(files, root)
    if test_dirs:
        project_dirs = frozenset(_dir_of(p) for p in files if p.lower().endswith(_PROJECT_EXTS))
        kept = [p for p in kept if not _in_test_project(p, test_dirs, project_dirs)]
    return kept


def detect(stack, files, root: str | None = None) -> tuple:
    """Run ``stack``'s detection over ``files`` with test markers dropped.

    Returns ``(markers, ignored_markers)``: the sorted marker files and how many markers that
    detection would have reported over the unfiltered list but for the drop. Nothing is stored on the
    Stack. A Stack that keeps the file list from detection (``aspnet_core``) is called last on the
    full list, so it sees every file, tests included.
    """
    run = (lambda fs: stack.detect_in(fs, root)) if root is not None and hasattr(stack, "detect_in") \
        else stack.detect
    files = list(files)
    kept = drop_test_files(files, root)
    if len(kept) == len(files):
        return sorted(run(files)), 0
    markers = sorted(run(kept))
    everything = set(run(files))
    return markers, len(everything - set(markers))
