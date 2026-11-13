"""Orchestrates detection and extraction and writes the Facts file and Facts summary."""

from __future__ import annotations

import os
import subprocess
from collections import Counter

from . import facts as F
from . import scan, smells
from .stacks import generic, load
from .summary import render_summary


def _git(root: str, *args: str) -> str | None:
    try:
        r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def _is_repo_root(root: str) -> bool:
    """True only when the Target is itself the top of a git repo.

    A Target nested inside another repo (a sample, a subfolder) must not borrow that repo's
    commit or authors.
    """
    top = _git(root, "rev-parse", "--show-toplevel")
    return bool(top) and os.path.normcase(os.path.realpath(top)) == os.path.normcase(os.path.realpath(root))


is_test_path = F.is_test_path


def _history(root: str) -> str:
    """"full", "shallow" or "none": how much git history the Target has (ownership needs full)."""
    if not _is_repo_root(root):
        return "none"
    return "shallow" if _git(root, "rev-parse", "--is-shallow-repository") == "true" else "full"


def _ownership(root: str, files: list[scan.SourceFile]):
    """Top authors per top-level folder (names only). Only with full git history."""
    if _history(root) != "full":
        return
    folders = sorted({f.path.split("/", 1)[0] for f in files if "/" in f.path})
    for folder in folders:
        out = _git(root, "log", "--format=%an", "--", folder)
        if not out:
            continue
        names = Counter(out.splitlines())
        top = sorted(names.items(), key=lambda kv: (-kv[1], kv[0]))[:3]
        yield F.Fact.make("ownership", "generic", folder, None, folder,
                          authors=[n for n, _ in top], commits=sum(names.values()))


def extract(root: str, out_dir: str) -> tuple[str, str]:
    """Return (facts_text, summary_text) for the Target at root. Pure with respect to the Target."""
    root = os.path.abspath(root)
    stats: dict = {}
    files = scan.walk(root, out_dir, stats)
    paths = [f.path for f in files]
    stacks = load()

    detected = {}
    for st in stacks:
        markers = st.detect_in(paths, root) if hasattr(st, "detect_in") else st.detect(paths)
        if markers:
            detected[st.id] = (st, sorted(markers))

    # folder -> set of file names, for i18n message-bundle detection (a sibling <base>_<ll>.<ext>)
    siblings: dict[str, set[str]] = {}
    for sf in files:
        folder = sf.path.rsplit("/", 1)[0] if "/" in sf.path else ""
        siblings.setdefault(folder, set()).add(sf.path.rsplit("/", 1)[-1])

    facts: list[F.Fact] = []
    for sf in files:
        detail = {"size": sf.size, "ext": sf.ext}
        if sf.skipped:
            detail["skipped"] = sf.skipped
            facts.append(F.Fact.make("file", "generic", sf.path, None, sf.path, **detail))
            continue
        text, enc = scan.read_text(root, sf.path)
        detail.update(lines=text.count("\n") + (0 if text.endswith("\n") or not text else 1), encoding=enc)
        owners = sorted(sid for sid, (st, _) in detected.items() if sf.ext in st.extensions)
        detail["stacks"] = owners
        facts.append(F.Fact.make("file", "generic", sf.path, None, sf.path, **detail))
        folder = sf.path.rsplit("/", 1)[0] if "/" in sf.path else ""
        found = list(generic.extract(sf.path, text, siblings.get(folder)))
        for sid in owners:
            found.extend(detected[sid][0].extract(sf.path, text))
        found.extend(smells.extract(sf.path, text, owners))
        if is_test_path(sf.path):
            found = [f.as_test() for f in found]
        facts.extend(found)

    # Post-pass (1.4A): a config file classified `unclassified` is promoted to `app` when one of its
    # keys is read from code (a config_key Fact with use="read", source="code").
    code_read_keys = {f.name for f in facts
                      if f.kind == "config_key" and f.detail_dict().get("use") == "read"
                      and f.detail_dict().get("source") == "code"}
    if code_read_keys:
        promoted = []
        for f in facts:
            if f.kind == "config_key" and f.detail_dict().get("role") == "unclassified" \
                    and f.name in code_read_keys:
                d = f.detail_dict()
                d["role"] = "app"
                promoted.append(F.Fact.make(f.kind, f.stack, f.path, f.line, f.name, **d))
            else:
                promoted.append(f)
        facts = promoted

    for sid, (st, markers) in sorted(detected.items()):
        count = sum(1 for sf in files if sf.ext in st.extensions)
        caps = sorted(getattr(st, "capabilities", frozenset()))
        facts.append(F.Fact.make("stack", sid, markers[0], None, sid,
                                 marker_files=markers, file_count=count, supported=True,
                                 capabilities=caps))
    for eco, markers in generic.unsupported_stacks(paths, set(detected)):
        facts.append(F.Fact.make("stack", "generic", markers[0], None, eco,
                                 marker_files=markers, file_count=len(markers), supported=False))
    facts.extend(_ownership(root, files))

    name = os.path.basename(root.rstrip("\\/")) or "target"
    commit = _git(root, "rev-parse", "HEAD") if _is_repo_root(root) else None
    pruned_files = sum(p["files"] for p in stats["pruned"])
    coverage = {"scanned": len(files), "ignored": stats["ignored"], "pruned_files": pruned_files,
                "found": len(files) + stats["ignored"] + pruned_files, "pruned": stats["pruned"],
                "metadata": stats.get("metadata", 0), "retired_candidates": stats.get("retired_candidates", [])}
    facts_text = F.dumps(name, commit, facts, _history(root), coverage)
    return facts_text, render_summary(F.loads(facts_text))


def write(root: str, out_dir: str) -> list[str]:
    facts_text, summary_text = extract(root, out_dir)
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for fname, text in (("facts.json", facts_text), ("facts-summary.md", summary_text)):
        p = os.path.join(out_dir, fname)
        with open(p, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        written.append(p)
    return written
