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

from . import aspnet_guards, configs, context, version
from . import facts as F
from . import scan, smells
from .citations import OWNER_CONTEXT
from .secrets import is_secret_ref
from .stacks import capabilities_of, generic, load
from .stacks import detect as detect_markers
from .summary import render_summary

PARALLEL_THRESHOLD = 50  # below this file count, the pool's overhead isn't worth it
CACHE_NAME = ".appdoc-cache.json"
_CACHE_MAX_ENTRIES = 10_000  # best-effort cap on cache entries (never prune, just bound growth)

is_test_path = F.is_test_path


def _git(root: str, *args: str) -> str | None:
    try:
        r = subprocess.run(["git", "-C", root, *args], capture_output=True, text=True, timeout=60)
    except (OSError, subprocess.SubprocessError):
        return None
    return r.stdout.strip() if r.returncode == 0 else None


def _is_repo_root(root: str) -> bool:
    """True only when the Target is itself the top of a git repo.

    A Target nested inside another repo (a sample, a subfolder) must not borrow that repo's
    commit or history.
    """
    top = _git(root, "rev-parse", "--show-toplevel")
    return bool(top) and os.path.normcase(os.path.realpath(top)) == os.path.normcase(os.path.realpath(root))


def _history(root: str) -> str:
    """"full", "shallow" or "none": how much git history the Target has (ownership needs full)."""
    if not _is_repo_root(root):
        return "none"
    return "shallow" if _git(root, "rev-parse", "--is-shallow-repository") == "true" else "full"


def _ownership(root: str, files: list[scan.SourceFile], ownership_top: int | None = None):
    """Commit activity per top-level folder: counts and dates, never a person's name. Only with full git history.

    Each Fact records `commits`, `contributors` (the number of distinct authors, counted and then
    forgotten) and the dates (`YYYY-MM-DD`) of the first and last commit, and ``source="git"`` (the gate ignores
    exactly these Facts; the ``Ownership:`` role Facts of appdoc-context.md carry that file's name). R18: no author
    name, no email.
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
        out = _git(root, "log", "--date=short", "--format=%an%x09%ad", "--", folder)
        if not out:
            continue
        rows = [line.split("\t") for line in out.splitlines() if "\t" in line]
        if not rows:
            continue
        dates = sorted(r[1] for r in rows)
        yield F.Fact.make("ownership", "generic", folder, None, folder,
                          commits=len(rows), contributors=len({r[0] for r in rows}),
                          first_commit=dates[0], last_commit=dates[-1], source="git")


def _owner_context(root: str):
    """Facts from `appdoc-context.md` at the Target root: one owner_file, one ownership per `Ownership:` line.

    Only the role (e.g. "Business owner") and line are recorded, never the value, which may name a person.
    """
    path = os.path.join(root, OWNER_CONTEXT)
    if not os.path.isfile(path):
        return
    with open(path, encoding="utf-8", errors="replace") as fh:
        ctx = context.parse(fh.read())
    # `kind` is a detail key and Fact.make's own first parameter, so build this Fact directly.
    yield F.Fact("owner_file", "generic", OWNER_CONTEXT, None, OWNER_CONTEXT,
                 (("entries", len(ctx.ownership) + len(ctx.never_mention)), ("kind", "context")))
    for o in ctx.ownership:
        yield F.Fact.make("ownership", "generic", OWNER_CONTEXT, o.line, o.role,
                          role=o.role, source=OWNER_CONTEXT)
    # one context_directive per directive line, from the same single parse; a value that may name a person is not carried
    for d in context.directives(ctx):
        detail = {"directive": d.key}
        if d.value is not None:
            detail["value"] = d.value
        if d.names:
            detail["names"] = list(d.names)
        yield F.Fact.make("context_directive", "generic", OWNER_CONTEXT, d.line, d.name, **detail)


_GUARD_EVIDENCE = ("guard_use", "guard_class", "guard_candidate")


def _attr_key(name: str) -> str:
    low = name.strip().lower()
    return low[:-9] if low.endswith("attribute") and len(low) > 9 else low


def _match_directives(facts: list) -> list:
    """Post-pass: disclose directive names that match nothing as ``context_unmatched`` (a note, never an error).

    ``Auth attributes`` names are compared, case-insensitively and with or without the ``Attribute`` suffix, with the
    names of guard_use, guard_class and guard_candidate Facts. Absence is only claimed when at least one such Fact
    exists: with none, no detector has run and absence proves nothing. Directives are rebuilt with ``Fact.make``.
    """
    known = {_attr_key(f.name) for f in facts if f.kind in _GUARD_EVIDENCE}
    if not known:
        return facts
    out = []
    for f in facts:
        if f.kind == "context_directive" and dict(f.detail).get("directive") == "auth_attributes":
            d = f.detail_dict()
            miss = sorted(n for n in d.get("names", []) if _attr_key(n) not in known)
            if miss:
                d["context_unmatched"] = miss
                f = F.Fact.make(f.kind, f.stack, f.path, f.line, f.name, **d)
        out.append(f)
    return out


# ------------------------------------------------------------------ caching

def _cache_key(raw: bytes, path: str, detected_ids, siblings=None, salt: str | None = None) -> str:
    """Content-hash key, salted so an AppDoc change invalidates a stale cache.

    The leading bytes are the Facts schema and the bundle hash (``version.bundle_hash()``, a hash of
    every file in the ``appdoc`` package), so a ``.appdoc-cache.json`` written by any other build of
    AppDoc is never served; nobody has to remember to bump a constant. ``salt`` lets a caller that
    keys many files compute the bundle hash once. ``siblings`` (the folder's file names) is folded in
    because i18n message-bundle detection depends on the folder's file set, not just this file's content.
    """
    h = hashlib.sha256()
    h.update(str(F.SCHEMA).encode("utf-8")); h.update(b"\x00")
    h.update((salt if salt is not None else version.bundle_hash()).encode("utf-8")); h.update(b"\x00")
    h.update(raw); h.update(b"\x00")
    h.update(path.encode("utf-8")); h.update(b"\x00")
    h.update("\x00".join(sorted(detected_ids)).encode("utf-8"))
    if siblings is not None:
        h.update(b"\x00")
        h.update("\x00".join(sorted(siblings)).encode("utf-8"))
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
                  cache: dict | None = None, siblings: dict | None = None,
                  salt: str | None = None) -> list[F.Fact]:
    """Pure per-file extraction. No cross-file state beyond the picklable ``siblings`` map.

    Returns exactly the facts the serial loop appends for this file. If ``cache`` is a dict, a
    content-hash hit returns the cached facts (no regex work) and a miss is stored back into it.
    """
    detail = {"size": sf.size, "ext": sf.ext}
    if sf.skipped:
        detail["skipped"] = sf.skipped
        return [F.Fact.make("file", "generic", sf.path, None, sf.path, **detail)]
    raw = scan.read_bytes(root, sf.path)
    folder = sf.path.rsplit("/", 1)[0] if "/" in sf.path else ""
    sib = siblings.get(folder) if siblings is not None else None
    key = None
    if cache is not None:
        key = _cache_key(raw, sf.path, sorted(detected), sib, salt)
        if key in cache:
            return [F.Fact.from_json(d) for d in cache[key]]
    text, enc = scan._decode(raw)
    detail.update(lines=text.count("\n") + (0 if text.endswith("\n") or not text else 1), encoding=enc)
    owners = sorted(sid for sid, (st, _) in detected.items() if sf.ext in st.extensions)
    detail["stacks"] = owners
    facts = [F.Fact.make("file", "generic", sf.path, None, sf.path, **detail)]
    found = list(generic.extract(sf.path, text, sib, raw))
    for sid in owners:
        found.extend(detected[sid][0].extract(sf.path, text))
    found.extend(smells.extract(sf.path, text, owners))
    if is_test_path(sf.path):
        found = [f.as_test() for f in found]
    facts.extend(found)
    if cache is not None:
        cache[key] = [f.to_json() for f in facts]
    return facts


def _worker_chunk(root: str, detected: dict, chunk: list[scan.SourceFile],
                  cache: dict | None = None, siblings: dict | None = None,
                  salt: str | None = None) -> tuple[list[F.Fact], dict]:
    """Process a chunk of files in a worker process; return (combined Facts, new cache entries).

    Each worker gets a pickled copy of the loaded cache; misses are computed locally and the new
    (key -> facts) entries are returned so the parent can fold them back without re-reading.
    """
    before = set(cache) if cache is not None else None
    out: list[F.Fact] = []
    for sf in chunk:
        out.extend(_extract_file(root, sf, detected, cache, siblings, salt))
    new = {k: cache[k] for k in cache if k not in before} if cache is not None else {}
    return out, new


def _extract_all(root: str, files: list[scan.SourceFile], detected: dict, workers: int,
                 cache: dict | None = None, siblings: dict | None = None) -> list[F.Fact]:
    """Run ``_extract_file`` over all files, serially or in a process pool.

    Completion order is irrelevant: ``facts.dumps`` sorts + de-duplicates the set of Facts.
    """
    salt = version.bundle_hash() if cache is not None else None
    if workers <= 1 or len(files) < PARALLEL_THRESHOLD:
        out: list[F.Fact] = []
        for sf in files:
            out.extend(_extract_file(root, sf, detected, cache, siblings, salt))
        return out
    nchunks = min(workers * 4, len(files))
    size = max(1, -(-len(files) // nchunks))            # ceil division
    chunks = [files[i:i + size] for i in range(0, len(files), size)]
    out: list[F.Fact] = []
    with ProcessPoolExecutor(max_workers=workers) as ex:
        for chunk_facts, new in ex.map(
                partial(_worker_chunk, root, detected, cache=cache, siblings=siblings, salt=salt), chunks):
            out.extend(chunk_facts)
            if cache is not None and new:
                cache.update(new)
    return out


def _key_variants(name: str) -> set:
    """The names a config-file key can be read under: the full name and its last dotted segment.

    `server.HTTP_PORT` in an INI file is read from code as `server.HTTP_PORT` or as `HTTP_PORT`.
    """
    return {name, name.rsplit(".", 1)[-1]}


def _config_roles(facts: list) -> list:
    """Post-pass over the combined Facts (1.4A, 1.5, 2.6 4.4). The cache stores pre-promotion per-file Facts,
    so warm == cold only while every role decision stays here and depends on per-file details.

    A code read of a config key (a config_key Fact with use="read", source="code") gets a role from
    how it reads: an environment variable (``read_kind`` env) is role ``env``; any read in a CI/build
    file path is ``ci``; any other code read is ``app``. Only ``app`` keys can be secret locations
    (an env var or CI variable is not an application secret). Promotion is per file: when any key of a
    config file that is ``unclassified`` matches a code-read key (through ``_key_variants``), every
    ``unclassified`` key of that file becomes ``app``. ``env`` and ``ci`` keys are never promoted.
    A key whose name points at a secret held elsewhere (``..._URI``, ``..._FILE``) gets ``secret_ref``.
    """
    def is_code(d):
        return d.get("source") == "code"
    read_keys = {f.name for f in facts if f.kind == "config_key"
                 and f.detail_dict().get("use") == "read" and is_code(f.detail_dict())}
    promoted = {f.path for f in facts if f.kind == "config_key" and not is_code(f.detail_dict())
                and f.detail_dict().get("role") == "unclassified" and _key_variants(f.name) & read_keys}
    out = []
    for f in facts:
        if f.kind != "config_key":
            out.append(f)
            continue
        d = f.detail_dict()
        before = dict(d)
        role = d.get("role")
        if is_code(d) and d.get("read_kind") and not d.get("test"):
            role = "ci" if generic.config_role(f.path) == "ci" else ("env" if d["read_kind"] == "env" else "app")
        elif role == "unclassified" and not is_code(d) and f.path in promoted:
            role = "app"
        if role in ("env", "ci") and d.get("secret_location"):
            d["secret_location"] = False
        if not d.get("secret_location") and is_secret_ref(f.name):
            d["secret_ref"] = True
        if role != before.get("role"):
            d["role"] = role
        if d != before:
            f = F.Fact.make(f.kind, f.stack, f.path, f.line, f.name, **d)
        out.append(f)
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
    stats: dict = {}
    files = scan.walk(root, out_dir, stats, skip_tests=skip_tests)
    paths = [f.path for f in files]
    stacks = load()

    detected = {}
    ignored: dict = {}   # stack id -> markers dropped because they sit under test paths or in test projects
    for st in stacks:
        markers, dropped = detect_markers(st, paths, root)
        if markers:
            detected[st.id] = (st, sorted(markers))
        if dropped:
            ignored[st.id] = dropped

    # folder -> set of file names, for i18n message-bundle detection (a sibling <base>_<ll>.<ext>)
    siblings: dict[str, set[str]] = {}
    for sf in files:
        folder = sf.path.rsplit("/", 1)[0] if "/" in sf.path else ""
        siblings.setdefault(folder, set()).add(sf.path.rsplit("/", 1)[-1])

    cache = _load_cache(out_dir) if use_cache else None
    if workers is None:
        workers = min(os.cpu_count() or 1, 8)
    facts = _extract_all(root, files, detected, workers, cache, siblings)

    facts.extend(_owner_context(root))   # one parse of appdoc-context.md; its Facts exist before every post-pass
    facts = _config_roles(facts)
    facts = configs.apply(facts)             # W1/W2: effective .config values per build configuration
    facts = aspnet_guards.promote(facts)     # W3: guard joins over the raw per-file Facts
    facts = _match_directives(facts)

    for sid, (st, markers) in sorted(detected.items()):
        count = sum(1 for sf in files if sf.ext in st.extensions)
        caps = sorted(capabilities_of(st))
        extra = {"ignored_markers": ignored[sid]} if sid in ignored else {}
        facts.append(F.Fact.make("stack", sid, markers[0], None, sid,
                                 marker_files=markers, file_count=count, supported=True,
                                 capabilities=caps, **extra))
    for eco, markers in generic.unsupported_stacks(paths, set(detected)):
        facts.append(F.Fact.make("stack", "generic", markers[0], None, eco,
                                 marker_files=markers, file_count=len(markers), supported=False))
    if not no_ownership:
        facts.extend(_ownership(root, files, ownership_top))

    name = os.path.basename(root.rstrip("\\/")) or "target"
    commit = _git(root, "rev-parse", "HEAD") if _is_repo_root(root) else None
    pruned_files = sum(p["files"] for p in stats["pruned"])
    coverage = {"scanned": len(files), "ignored": stats["ignored"], "pruned_files": pruned_files,
                "found": len(files) + stats["ignored"] + pruned_files, "pruned": stats["pruned"],
                "metadata": stats.get("metadata", 0), "retired_candidates": stats.get("retired_candidates", []),
                "duplicate_folders": stats.get("duplicate_folders", [])}
    if ignored:   # markers dropped under test paths and in test projects, also for Stacks that were then not detected
        coverage["ignored_markers"] = {k: ignored[k] for k in sorted(ignored)}
    facts_text = F.dumps(name, commit, facts, _history(root), coverage)
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
    for fname, text in (("facts.json", facts_text), ("facts-summary.md", summary_text),
                        (version.PROVENANCE_FILE, version.dumps_provenance(version.provenance()))):
        p = os.path.join(out_dir, fname)
        with open(p, "w", encoding="utf-8", newline="\n") as fh:
            fh.write(text)
        written.append(p)
    return written
