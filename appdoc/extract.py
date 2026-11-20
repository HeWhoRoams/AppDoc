"""Orchestrates detection and extraction and writes the Facts file and Facts summary.

The per-file work is factored into a pure, picklable ``_extract_file`` so the loop can run
serially or in a ``concurrent.futures.ProcessPoolExecutor`` (``--workers``) with a content-hash
cache (default on). All of this preserves the *set* of Facts, and ``facts.dumps`` sorts +
de-duplicates, so the default (no-flag) output stays byte-identical across runs.
"""

from __future__ import annotations

import hashlib
import json
import os
import subprocess
from collections import Counter
from concurrent.futures import ProcessPoolExecutor
from functools import partial

from . import facts as F
from . import scan
from .scan import is_test_path
from .stacks import generic, load
from .summary import render_summary

PARALLEL_THRESHOLD = 50  # below this file count, the pool's overhead isn't worth it
CACHE_NAME = ".appdoc-cache.json"
EXTRACTOR_VERSION = 1  # bump whenever a stack/catalog regex or extraction logic changes
_CACHE_MAX_ENTRIES = 10_000  # best-effort cap on cache entries (never prune, just bound growth)


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


def _history(root: str) -> str:
    """"full", "shallow" or "none": how much git history the Target has (ownership needs full)."""
    if not _is_repo_root(root):
        return "none"
    return "shallow" if _git(root, "rev-parse", "--is-shallow-repository") == "true" else "full"


def _ownership(root: str, files: list[scan.SourceFile], ownership_top: int | None = None):
    """Top authors per top-level folder (names only). Only with full git history.

    ``ownership_top``, when set, ranks folders by file count (stable: descending count then name)
    and runs ``git log`` only on the top-N, bounding the subprocess count on wide repos.
    """
    if _history(root) != "full":
        return
    folders = sorted({f.path.split("/", 1)[0] for f in files if "/" in f.path})
    if ownership_top is not None:
        counts = Counter(f.path.split("/", 1)[0] for f in files if "/" in f.path)
        folders = sorted(folders, key=lambda fo: (-counts[fo], fo))[:ownership_top]
    for folder in folders:
        out = _git(root, "log", "--format=%an", "--", folder)
        if not out:
            continue
        names = Counter(out.splitlines())
        top = sorted(names.items(), key=lambda kv: (-kv[1], kv[0]))[:3]
        yield F.Fact.make("ownership", "generic", folder, None, folder,
                          authors=[n for n, _ in top], commits=sum(names.values()))


# ------------------------------------------------------------------ caching

def _cache_key(raw: bytes, path: str, detected_ids) -> str:
    """Content-hash key, versioned so an AppDoc upgrade invalidates a stale cache.

    The leading bytes (schema + extractor version) change whenever the extraction logic
    changes, so a ``.appdoc-cache.json`` written by an older AppDoc build is never served
    to a newer one.
    """
    h = hashlib.sha256()
    h.update(str(F.SCHEMA).encode("utf-8")); h.update(b"\x00")
    h.update(str(EXTRACTOR_VERSION).encode("utf-8")); h.update(b"\x00")
    h.update(raw); h.update(b"\x00")
    h.update(path.encode("utf-8")); h.update(b"\x00")
    h.update("\x00".join(sorted(detected_ids)).encode("utf-8"))
    return h.hexdigest()


def _load_cache(out_dir: str) -> dict:
    """Load the content-hash cache (key -> list of Fact.to_json() dicts); best-effort."""
    p = os.path.join(out_dir, CACHE_NAME)
    if not os.path.isfile(p):
        return {}
    try:
        with open(p, encoding="utf-8") as fh:
            data = json.load(fh)
    except (OSError, ValueError):
        return {}
    return data if isinstance(data, dict) else {}


def _save_cache(out_dir: str, cache: dict) -> None:
    """Persist the cache; best-effort (a missing/unwritable out dir just means no cache next run)."""
    if len(cache) > _CACHE_MAX_ENTRIES:
        cache.clear()  # the cache is best-effort; a cleared cache just means a cold next run
    try:
        os.makedirs(out_dir, exist_ok=True)
        with open(os.path.join(out_dir, CACHE_NAME), "w", encoding="utf-8", newline="\n") as fh:
            json.dump(cache, fh, sort_keys=True, ensure_ascii=False)
    except OSError:
        pass


# ------------------------------------------------------------------ per-file extraction

def _extract_file(root: str, sf: scan.SourceFile, detected: dict,
                  cache: dict | None = None) -> list[F.Fact]:
    """Pure per-file extraction. No cross-file state. Picklable for the process pool.

    Returns exactly the facts the serial loop appends for this file. If ``cache`` is a dict, a
    content-hash hit returns the cached facts (no regex work) and a miss is stored back into it.
    """
    detail = {"size": sf.size, "ext": sf.ext}
    if sf.skipped:
        detail["skipped"] = sf.skipped
        return [F.Fact.make("file", "generic", sf.path, None, sf.path, **detail)]
    raw = scan.read_bytes(root, sf.path)
    key = None
    if cache is not None:
        key = _cache_key(raw, sf.path, sorted(detected))
        if key in cache:
            return [F.Fact.from_json(d) for d in cache[key]]
    text, enc = scan._decode(raw)
    detail.update(lines=text.count("\n") + (0 if text.endswith("\n") or not text else 1), encoding=enc)
    owners = sorted(sid for sid, (st, _) in detected.items() if sf.ext in st.extensions)
    detail["stacks"] = owners
    facts = [F.Fact.make("file", "generic", sf.path, None, sf.path, **detail)]
    found = list(generic.extract(sf.path, text))
    for sid in owners:
        found.extend(detected[sid][0].extract(sf.path, text))
    if is_test_path(sf.path):
        found = [f.as_test() for f in found]
    facts.extend(found)
    if cache is not None:
        cache[key] = [f.to_json() for f in facts]
    return facts


def _worker_chunk(root: str, detected: dict, chunk: list[scan.SourceFile],
                  cache: dict | None = None) -> tuple[list[F.Fact], dict]:
    """Process a chunk of files in a worker process; return (combined Facts, new cache entries).

    Each worker gets a pickled copy of the loaded cache; misses are computed locally and the new
    (key -> facts) entries are returned so the parent can fold them back without re-reading.
    """
    before = set(cache) if cache is not None else None
    out: list[F.Fact] = []
    for sf in chunk:
        out.extend(_extract_file(root, sf, detected, cache))
    new = {k: cache[k] for k in cache if k not in before} if cache is not None else {}
    return out, new


def _extract_all(root: str, files: list[scan.SourceFile], detected: dict, workers: int,
                 cache: dict | None = None) -> list[F.Fact]:
    """Run ``_extract_file`` over all files, serially or in a process pool.

    Completion order is irrelevant: ``facts.dumps`` sorts + de-duplicates the set of Facts.
    """
    if workers <= 1 or len(files) < PARALLEL_THRESHOLD:
        out: list[F.Fact] = []
        for sf in files:
            out.extend(_extract_file(root, sf, detected, cache))
        return out
    nchunks = min(workers * 4, len(files))
    size = max(1, -(-len(files) // nchunks))            # ceil division
    chunks = [files[i:i + size] for i in range(0, len(files), size)]
    out: list[F.Fact] = []
    with ProcessPoolExecutor(max_workers=workers) as ex:
        for chunk_facts, new in ex.map(partial(_worker_chunk, root, detected, cache=cache), chunks):
            out.extend(chunk_facts)
            if cache is not None and new:
                cache.update(new)
    return out


def extract(root: str, out_dir: str, workers: int | None = None, skip_tests: bool = False,
            use_cache: bool = True, no_ownership: bool = False,
            ownership_top: int | None = None) -> tuple[str, str]:
    """Return (facts_text, summary_text) for the Target at root.

    All keyword args default to the no-flag behavior: ``workers=None`` means
    ``min(os.cpu_count() or 1, 8)`` (0 forces serial); caching is on by default. The default
    (no flags) output is byte-identical to the pre-optimization build.
    """
    root = os.path.abspath(root)
    files = scan.walk(root, out_dir, skip_tests=skip_tests)
    paths = [f.path for f in files]
    stacks = load()

    detected = {}
    for st in stacks:
        markers = st.detect(paths)
        if markers:
            detected[st.id] = (st, sorted(markers))

    cache = _load_cache(out_dir) if use_cache else None
    if workers is None:
        workers = min(os.cpu_count() or 1, 8)
    facts = _extract_all(root, files, detected, workers, cache)

    for sid, (st, markers) in sorted(detected.items()):
        count = sum(1 for sf in files if sf.ext in st.extensions)
        facts.append(F.Fact.make("stack", sid, markers[0], None, sid,
                                 marker_files=markers, file_count=count, supported=True))
    for eco, markers in generic.unsupported_stacks(paths, set(detected)):
        facts.append(F.Fact.make("stack", "generic", markers[0], None, eco,
                                 marker_files=markers, file_count=len(markers), supported=False))
    if not no_ownership:
        facts.extend(_ownership(root, files, ownership_top))

    name = os.path.basename(root.rstrip("\\/")) or "target"
    commit = _git(root, "rev-parse", "HEAD") if _is_repo_root(root) else None
    facts_text = F.dumps(name, commit, facts, _history(root))
    if use_cache and cache is not None:
        _save_cache(out_dir, cache)
    return facts_text, render_summary(F.loads(facts_text))


def write(root: str, out_dir: str, workers: int | None = None, skip_tests: bool = False,
          use_cache: bool = True, no_ownership: bool = False,
          ownership_top: int | None = None) -> list[str]:
    facts_text, summary_text = extract(root, out_dir, workers=workers, skip_tests=skip_tests,
                                       use_cache=use_cache, no_ownership=no_ownership,
                                       ownership_top=ownership_top)
    os.makedirs(out_dir, exist_ok=True)
    written = []
    for fname, text in (("facts.json", facts_text), ("facts-summary.md", summary_text)):
        p = os.path.join(out_dir, fname)
        with open(p, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        written.append(p)
    return written
