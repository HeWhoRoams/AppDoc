# AppDoc Performance Plan — Large-Repo Optimization

> Deep technical implementation plan for the 6 large-repo optimizations.
> Grounded in the verified source at HEAD `bb86a08`. All line refs are to the git-tracked source.
> **Non-negotiable invariant: `facts.json` stays byte-identical across runs.** Every phase has a determinism guard + a test that proves it.

---

## 0. The bottleneck (verified)

AppDoc's only tool-side compute is the **extract phase**. The serial per-file loop is `extract.py:80-96` (`for sf in files:`). Per file: `scan.read_text` (full read, `scan.py:88-97`) → line count → `owners` → `generic.extract` + each matching `stack.extract` → `is_test_path`/`as_test` → append to `facts`. On a large repo (gitea: thousands of files) this is the wall.

Secondary costs:
- **Double read**: `walk` reads an 8192-byte head of *every* file (`scan.py:77-78`) for binary detection, then `read_text` reads the whole file (`scan.py:91`).
- **Git ownership**: `_ownership` (`extract.py:51-63`) runs one `git log` per top-level folder (O(top-level folders) subprocesses), gated only by full history. No per-file `git blame`.
- **Per-call regex**: some regexes are compiled per call (e.g., `generic.extract` L53/56, `generic._gradle` L215, `generic._csproj` L221).

**No caching, no concurrency, no hashing** exists anywhere in the extract path (verified by grep: zero `concurrent.futures`/`multiprocessing`/`threading`/`hashlib`/`lru_cache` in `appdoc/`).

---

## 1. The determinism invariant (the key fact)

`facts.dumps` (`facts.py:82-93`):

```python
unique = sorted(set(facts), key=lambda f: f.sort_key())   # L84
stacks = [f.to_json() for f in unique if f.kind == "stack"]
others = [f.to_json() for f in unique if f.kind != "stack"]
doc = {"schema": SCHEMA, "target": {...}, "stacks": stacks, "facts": others}
return json.dumps(doc, sort_keys=True, indent=1, ensure_ascii=False) + "\n"   # L93
```

**The output is a function of the *set* of Facts, not their order.** `set(facts)` dedupes (the `Fact` is a frozen dataclass, hashable over all 6 fields — `detail` is a hashable `tuple` of `(key,value)` pairs); `sort by sort_key` orders them canonically; `json.dumps(sort_keys=True)` serializes dict keys canonically.

**Consequence:** as long as the *same set* of Facts is produced, the output is byte-identical **regardless of the order they were produced in**. This is the invariant that makes the optimizations safe:

| Optimization | Why it's safe |
|---|---|
| **Parallelize** | Workers return Facts in any order; `dumps` erases the order. |
| **Cache** | Same content → same Facts (content-keyed). |
| **Prune (opt-in)** | User opts in → the output changes *deliberately*. Default unchanged. |
| **I/O + regex** | Same matches → same Facts. |

**Guardrail for every phase:** preserve the *set* of Facts for the default path. The existing byte-identity test (`test_two_runs_are_byte_identical_for_every_sample`, `tests/test_core.py:38-42`) must pass with each optimization on, and each new optimization adds its own byte-identity test.

---

## 2. Phase 0 — Shared refactor (prerequisite for parallelize + cache)

Extract the per-file work into a **pure, picklable** function so the loop body can run serially *or* in a process pool without duplication.

```python
# appdoc/extract.py  (new)
def _extract_file(root: str, sf: scan.SourceFile, detected: dict) -> list[F.Fact]:
    """Pure per-file extraction. No cross-file state. Picklable for the process pool.

    Returns exactly the facts the current serial loop appends for this file.
    """
    detail = {"size": sf.size, "ext": sf.ext}
    if sf.skipped:
        detail["skipped"] = sf.skipped
        return [F.Fact.make("file", "generic", sf.path, None, sf.path, **detail)]
    text, enc = scan.read_text(root, sf.path)
    detail.update(lines=text.count("\n") + (0 if text.endswith("\n") or not text else 1),
                  encoding=enc)
    owners = sorted(sid for sid, (st, _) in detected.items() if sf.ext in st.extensions)
    detail["stacks"] = owners
    facts = [F.Fact.make("file", "generic", sf.path, None, sf.path, **detail)]
    found = list(generic.extract(sf.path, text))
    for sid in owners:
        found.extend(detected[sid][0].extract(sf.path, text))
    if is_test_path(sf.path):
        found = [f.as_test() for f in found]
    facts.extend(found)
    return facts
```

The `extract` loop (`extract.py:80-96`) becomes:

```python
facts: list[F.Fact] = []
for sf in files:
    facts.extend(_extract_file(root, sf, detected))
```

**Picklability (for the process pool):**
- `_extract_file` is a top-level function → picklable by reference.
- `sf` (`SourceFile`) is a frozen dataclass → picklable by value.
- `detected` is `dict[sid -> (Stack, markers)]`. `Stack` is a module-level singleton → picklable by reference (a child process re-imports `appdoc.stacks` and gets the same singleton). `markers` is a sorted `list[str]` → picklable by value.
- `root` is `str` → picklable by value.

**Determinism:** `_extract_file` is pure over `(root, sf, detected)`; it returns exactly the per-file facts the current loop appends. So the refactor is **behavior-preserving** (the set of Facts is unchanged). **Test:** existing byte-identity test passes after the refactor.

**Effort:** low. **Risk:** low.

---

## 3. Phase 1 — (4) I/O + regex fine-tuning (low effort, low risk)

**Hoist the per-call regexes to module level** (compile once). Targets (from the map):
- `generic.extract` L53 (`gem`), L56 (`go.mod`); `generic._gradle` L215; `generic._csproj` L221; `generic._packages_config` L226; `generic._pom` L205-208; `generic._properties` L143/147; `generic._requirements` L198; `generic._yaml` L157; `generic._dotenv` L170; `generic._json_config` L123.
- `python_flask._clean` L72 (once per `.py` file), `python_flask` L273; `java_spring` L459; `node_express` L262/279; `classic_asp` L187.

Move each `re.compile(...)` from the call site to a module-level `_NAME_RE = re.compile(...)`; the call site uses the module constant. Behavior is identical (the pattern string is unchanged) → the set of Facts is unchanged.

**`mmap` for large files in `read_text`** (`scan.py:88-97`):

```python
def read_text(root: str, rel: str) -> tuple[str, str]:
    """Read a file as text. Returns (text, encoding). Never raises on decoding."""
    full = os.path.join(root, rel)
    if os.path.getsize(full) > 1024 * 1024:        # mmap only above 1MiB
        import mmap
        with open(full, "rb") as fh:
            with mmap.mmap(fh.fileno(), 0, access=mmap.ACCESS_READ) as mm:
                raw = mm[:]
    else:
        with open(full, "rb") as fh:
            raw = fh.read()
    if raw.startswith(b"\xef\xbb\xbf"):
        raw = raw[3:]
    try:
        return raw.decode("utf-8"), "utf-8"
    except UnicodeDecodeError:
        return raw.decode("cp1252", errors="replace"), "cp1252"
```

**Optional (minor): avoid the double read.** `walk` already reads an 8192-byte head (`scan.py:77-78`); store it on `SourceFile` (new field `head: bytes`) and reuse it in `read_text`. Low value (the head is small) — do it only if profiling shows I/O is the bottleneck.

**Determinism:** regex hoisting + `mmap` produce the same matches → the set of Facts is unchanged. **Test:** byte-identity test passes.

**Effort:** low. **Risk:** low.

---

## 4. Phase 1 — (1) Pruning (low effort, opt-in, default unchanged)

The default walk already prunes: `ALWAYS_IGNORE_DIRS` (`scan.py:9-13`), `.appdocignore` globs (`scan.py:42-47`), size skip >2MiB (`scan.py:73-74`), binary skip (null-byte in first 8k, `scan.py:81-82`). The gaps a new filter fills are **test files** and **generated code** — but pruning them *changes the output*, so they are **opt-in** (the user owns the coverage/speed tradeoff). The default is untouched → determinism preserved by default.

**`--skip-tests` flag** (default OFF):
- Thread a `skip_tests: bool` parameter from the CLI → `extract` → `scan.walk`.
- In `walk`, when `skip_tests` is set and `is_test_path(rel)` (hoist `is_test_path` into `scan.py`, or import it), set `skipped = "test"` and skip the 8k head-read (the file is never read/extracted; the test-code Facts are gone).
- `SourceFile.skipped` gains the value `"test"` (the existing `skipped: str | None` field already carries `"size"`/`"binary"`; add `"test"`).
- **Output changes** (test-code Facts removed) — but only when the user opts in.

**Generated-code pruning** (via the existing `.appdocignore`): the user adds patterns (e.g., `*.pb.go`, `*_generated.go`, `*.min.js`, `*.lock`). No code change needed — the mechanism exists. Document it in the README.

**Determinism:** the default (no `--skip-tests`, no new patterns) is byte-identical to today. **Test:** new `test_skip_tests_changes_output` — with `--skip-tests`, the output differs from the default (test-code Facts absent); without it, byte-identical.

**Effort:** low. **Risk:** low (default unchanged; opt-in is deliberate).

---

## 5. Phase 2 — (2) Parallelize per-file extraction (medium effort, medium risk)

The per-file unit of work is independent (depends only on `sf`, its text, and the precomputed `detected`). Use `concurrent.futures.ProcessPoolExecutor` (regex is CPU-bound → the GIL serializes *threads*; *processes* scale).

```python
# appdoc/extract.py  (new)
from concurrent.futures import ProcessPoolExecutor
from functools import partial

PARALLEL_THRESHOLD = 50  # below this file count, the pool's overhead isn't worth it

def _worker_chunk(root: str, detected: dict, chunk: list[scan.SourceFile]) -> list[F.Fact]:
    """Process a chunk of files in a worker process; return the combined Facts."""
    out: list[F.Fact] = []
    for sf in chunk:
        out.extend(_extract_file(root, sf, detected))
    return out

def _extract_all(root: str, files: list[scan.SourceFile], detected: dict, workers: int) -> list[F.Fact]:
    """Run _extract_file over all files, serially or in a process pool."""
    if workers <= 1 or len(files) < PARALLEL_THRESHOLD:
        out: list[F.Fact] = []
        for sf in files:
            out.extend(_extract_file(root, sf, detected))
        return out
    nchunks = min(workers * 4, len(files))
    size = max(1, -(-len(files) // nchunks))            # ceil division
    chunks = [files[i:i + size] for i in range(0, len(files), size)]
    out = []
    with ProcessPoolExecutor(max_workers=workers) as ex:
        for chunk_facts in ex.map(partial(_worker_chunk, root, detected), chunks):
            out.extend(chunk_facts)
    return out
```

`extract` calls `facts = _extract_all(root, files, detected, workers)` in place of the serial loop.

**`--workers` flag** (default `min(os.cpu_count() or 1, 8)`): threaded CLI → `extract`/`write` → `_extract_all`. `0` = serial (today's behavior, the safe fallback).

**Determinism:** `dumps` does `set(facts)` + `sort by sort_key` (`facts.py:84`), so completion order is erased. As long as each file produces the same Facts (it does — `_extract_file` is pure), the set is identical → the output is byte-identical. **Tests:**
- `test_parallel_matches_serial` — `extract(..., workers=4) == extract(..., workers=0)` byte-for-byte (the `(facts_text, summary_text)` tuple).
- Existing `test_two_runs_are_byte_identical_for_every_sample` passes with the default `--workers`.
- `test_parallel_determinism_across_worker_counts` — `workers=1 == workers=2 == workers=8` on a sample sized above `PARALLEL_THRESHOLD`.

**Edge cases:**
- `detected` pickles cleanly (Stack singletons by reference; a child re-imports `appdoc.stacks`). Verified: the singletons are module-level (`stacks/__init__.py`, `STACK` per stack module).
- `SourceFile` is a frozen dataclass → pickles by value.
- Windows: `ProcessPoolExecutor` requires the `if __name__ == "__main__"` guard in `__main__.py` (it's already the entry point — confirm the guard; `run_appdoc.py` calls `appdoc.__main__.main`, so the spawn-safe entry is `python -m appdoc`).
- **CI:** the GitHub matrix runs on Linux + Windows (3.10/3.13). The process pool must pass on both; the `test_parallel_*` tests run in CI.

**Effort:** medium. **Risk:** medium (pickling + cross-platform). **Mitigation:** the three byte-identity tests above + CI on both OSes.

---

## 6. Phase 3 — (3) Cache Facts by content-hash (medium effort, medium risk)

No caching exists. Add a content-keyed cache so re-runs (and the docs-as-code gate) skip unchanged files.

**Cache key** = `sha256(raw_bytes ‖ path ‖ sorted(detected_stack_ids))`. It must include `detected`'s stack ids because the per-file `owners` (and thus the per-file Facts) depend on which stacks were detected; and the path because a `file` Fact's `path` is a Fact field.

```python
# appdoc/extract.py  (new)
import hashlib

def _cache_key(raw: bytes, path: str, detected_ids: list[str]) -> str:
    h = hashlib.sha256()
    h.update(raw); h.update(b"\x00")
    h.update(path.encode("utf-8")); h.update(b"\x00")
    h.update("\x00".join(sorted(detected_ids)).encode("utf-8"))
    return h.hexdigest()
```

**Plumbing the raw bytes:** `scan.read_text` currently returns `(text, encoding)`. Extend it to return the raw bytes too — either a new function `scan.read_bytes(root, rel) -> bytes` that `read_text` uses internally, or change `read_text` to `(text, encoding, raw)`. Prefer a separate `read_bytes` so the existing `read_text` callers are untouched. The 8192-byte head that `walk` already reads is *not* the full hash input (files can be up to 2MiB), so the key must hash the full bytes.

**Cache storage:** a JSON file in the output dir (e.g., `out_dir/.appdoc-cache.json`, gitignored). Keys = cache-key hex; values = the per-file `list[Fact.to_json()]`. Loaded once at the start of `extract`, written at the end (best-effort; a missing/corrupt cache falls back to a cold run).

**In `_extract_file`** (add an optional `cache: dict | None` parameter):
- After reading `raw`, if `cache` is not None: `key = _cache_key(raw, sf.path, sorted(detected))`; on a hit, return `[F.Fact(**fact_json) for fact_json in cache[key]]` (skip the regex work entirely).
- On a miss, compute the Facts (current path) and store `cache[key] = [f.to_json() for f in facts]`.

**`Fact` reconstruction:** `to_json` (facts.py:64-72) produces `{kind, stack, path, line, name, detail(dict)}`. Reconstruct via `Fact(kind, stack, path, line, name, tuple(sorted(detail.items())))` — or add a `Fact.from_json(d)` classmethod that does exactly that (keeps the round-trip explicit + testable). The round-trip must be exact: `Fact.from_json(f.to_json()) == f` for every Fact (frozen dataclass equality).

**`--no-cache` flag** (default: cache ON). The cache is a *cache*, not a semantic change: it must produce byte-identical output to a cold run.

**Determinism:** the cache is content-keyed (same content → same Facts). A warm run and a cold run produce the same set of Facts → the output is byte-identical. **Tests:**
- `test_cache_round_trip` — `Fact.from_json(f.to_json()) == f` for a battery of Facts (incl. `as_test`, multi-value detail, `None` line).
- `test_cache_warm_equals_cold` — a warm run (cache present) and a cold run (`--no-cache`) produce byte-identical `facts.json`.
- `test_cache_invalidates_on_content_change` — mutate a file's content, re-run; the output reflects the new content (the old cache entry is not used).
- Existing byte-identity test passes with the cache on (default).

**Effort:** medium. **Risk:** medium (key correctness + the round-trip). **Mitigation:** the three tests above.

---

## 7. Phase 4 — (5) Git ownership isolation (low effort, opt-in, default unchanged)

`_ownership` (`extract.py:51-63`) runs one `git log` per top-level folder. It's already gated by full history (`_history`), but not by a flag or a size cap.

**`--no-ownership` flag** (default OFF): threaded CLI → `extract`. When set, skip the `facts.extend(_ownership(...))` call (`extract.py:105`) → the ownership Facts are gone. Output changes only when opted in.

**`--ownership-top N` flag** (default: all folders): thread `ownership_top: int | None` → `_ownership`. Rank top-level folders by file count, keep the top-N, run `git log` only on those. This bounds the subprocess count on repos with many top-level folders. Determinism: the ranking is by a stable `(count, folder)` sort (descending count, then folder name), so the selected set is deterministic.

**Optional `_git` result cache:** an in-memory `dict[tuple[str, ...], str]` memo on `_git`'s args. Low value (the args are mostly unique per folder) — skip it unless profiling shows git is a bottleneck.

**Determinism:** default (no flags) is byte-identical. **Test:** `test_no_ownership_removes_ownership_facts` (the ownership Facts are absent when `--no-ownership`; present by default).

**Effort:** low. **Risk:** low.

---

## 8. Phase 5 — (6) Two-pass scan + bounded sampling (high effort, opt-in, last resort)

For *very* large repos, bound the work by extracting a representative subset and recording the sampling honestly in the Facts (consistent with the "Unknown / honest gap" discipline).

**Two-pass:** pass 1 = metadata only (the existing `walk` minus the 8k head-read → cheap). Budget from the metadata (file count, total size, per-stack counts). Pass 2 = full read + extract only for the selected subset. Reuse `SourceFile` (it already carries `size`, `skipped`, `.ext`) — pass 1 builds the `SourceFile` list without the head-read; pass 2 runs `_extract_all` on the selected subset.

**Bounded sampling:** `--sample N` (default: all). Select the top-N files by a deterministic priority (e.g., size desc, then path) among the in-scope, non-skipped files. Add a `sampling` record to the `target` block in `dumps` (e.g., `{"sampled": N, "total": M, "strategy": "size_desc"}`) so the doc is honest about coverage. **This changes the output** (the Facts cover a subset + the sampling record) — only when opted in.

**Determinism:** the selection is deterministic (stable priority sort). Default (`--sample` unset) is byte-identical. **Test:** `test_sample_changes_output` (the sampling record is present + the Facts cover a subset when `--sample N`; absent by default).

**Effort:** high. **Risk:** high (changes the output; the `dumps` `target` block gains a field). **Mitigation:** opt-in only; the default is unchanged; a dedicated test pins the sampling record.

> **Recommendation:** defer Phase 5 until Phases 0-4 are in. Prune + parallelize + cache will likely make gitea-class repos tractable without sampling. Revisit only if a target still overruns.

---

## 9. Phasing, effort, dependencies

| Phase | Optimization | Effort | Risk | Depends on | Default output |
|---|---|---|---|---|---|
| 0 | Refactor `_extract_file` (pure, picklable) | low | low | — | unchanged |
| 1 | (4) I/O + regex (hoist regexes, `mmap`) | low | low | — | unchanged |
| 1 | (1) Prune (`--skip-tests`, `.appdocignore` docs) | low | low | — | unchanged |
| 2 | (2) Parallelize (process pool, `--workers`) | medium | medium | 0 | unchanged |
| 3 | (3) Cache (`--no-cache`, content-hash) | medium | medium | 0 | unchanged |
| 4 | (5) Git ownership (`--no-ownership`, `--ownership-top`) | low | low | — | unchanged |
| 5 | (6) Two-pass + sampling (`--sample N`) | high | high | 0 | unchanged (opt-in) |

**Recommended order:** 0 → 1 → 2 → 3 → 4 → (5). Phases 0-2 deliver the biggest speedup (the refactor + fine-tuning + parallelization); Phase 3 pays off on every re-run (and the docs-as-code gate); Phases 4-5 are opt-in fine-tuning.

**Expected effect on gitea (thousands of files):**
- Phase 1 (prune tests/generated): file count −30-50% → proportional speedup.
- Phase 2 (parallelize, 8 workers): up to ~8× on the extract loop (I/O + CPU), minus pool overhead.
- Phase 3 (cache): re-runs on an unchanged repo ≈ near-instant (only changed files re-extract).

---

## 10. Validation

**Existing tests must stay green** (the determinism core, `tests/test_core.py`):
- `test_two_runs_are_byte_identical_for_every_sample` (L38-42) — the byte-identity assertion.
- `test_walk_order_does_not_matter` (L44-56) — walk-order invariance.
- `test_facts_are_sorted_and_unique` (L70-74) — sorted + unique.
- Per-stack `test_byte_identical_two_runs` (e.g., `tests/test_facts_python_flask.py:109-110`).
- `tests/check_stdlib_only.py` — the AST guard (the new imports: `concurrent.futures`, `functools`, `hashlib`, `mmap` are all stdlib → the guard stays green).

**New tests (one determinism guard per optimization):**
- `test_refactor_preserves_output` (Phase 0): output identical before/after the `_extract_file` refactor.
- `test_parallel_matches_serial` (Phase 2): `workers=4 == workers=0`.
- `test_parallel_determinism_across_worker_counts` (Phase 2): `1 == 2 == 8`.
- `test_skip_tests_changes_output` (Phase 1): `--skip-tests` differs; default unchanged.
- `test_cache_round_trip` (Phase 3): `Fact.from_json(f.to_json()) == f`.
- `test_cache_warm_equals_cold` (Phase 3): warm == cold byte-for-byte.
- `test_cache_invalidates_on_content_change` (Phase 3).
- `test_no_ownership_removes_ownership_facts` (Phase 4).
- `test_sample_changes_output` (Phase 5).

**Benchmark (the speedup):** run `appdoc extract` on a large target (e.g., a gitea clone or the KFS repo) with default vs. optimizations on; record wall-clock. Use `time` (or `--workers` sweep) to show the extract-phase speedup. Keep the benchmark out of the committed test suite (it's a one-off measurement).

---

## 11. CLI changes (the new flags)

`appdoc/__main__.py::main` (L20-48) adds, threaded through `extract`/`write` (new parameters):

| Flag | Default | Effect |
|---|---|---|
| `--workers N` | `min(cpu, 8)` | process-pool workers; `0` = serial |
| `--skip-tests` | off | prune test files (test-code Facts removed) |
| `--no-cache` | off | disable the content-hash cache |
| `--no-ownership` | off | skip git ownership Facts |
| `--ownership-top N` | all | cap ownership to top-N top-level folders |
| `--sample N` | all | extract a bounded subset + record sampling |

All flags are **default-neutral**: with no flags, `appdoc extract <target>` produces byte-identical output to today. That's the contract the docs-as-code gate and the determinism tests rely on.

---

## 12. What this does NOT change

- **The Check** (`check.py`), **the render** (`render/`), **the summary** (`summary.py`) — untouched. The optimizations are all in the extract path.
- **The `Fact` schema** (`facts.py`) — `Fact.from_json` is *added* (a new classmethod); the `KINDS`, `SCHEMA`, and `sort_key` are unchanged. (Phase 5 adds a `sampling` field to the `target` block — the only schema touch.)
- **The Narrative** — AI/session-side, not a tool concern. The optimizations make the Facts (the Narrative's input) faster to produce, not the Narrative itself.

---

## 13. Content gap — Dependencies & System Connections (the integration picture)

> A separate concern from the performance phases (0-5): this is about the *quality* of what AppDoc documents, not how fast. Question: "Does AppDoc properly document dependencies and system connections? We can derive all that from the code." Assessment below, with the gap + the plan addition.

### 13.1 What AppDoc captures today (verified)

**Dependencies — well-covered** (manifest-based, `generic.py`): Maven (`pom.xml` L203-211), Gradle (`build.gradle`/`.kts` L214-217), NuGet (`.csproj` `PackageReference` L220-222, `packages.config` L225-227), npm (`package.json` `dependencies`/`devDependencies` L189-190), pip (`requirements*.txt` L193-200), Ruby (`Gemfile` L52-54), Go (`go.mod` L55-57), PHP (`composer.json` L58-59). Each yields a `dependency` Fact (`name`, `version`, `manager`). **Direct dependencies only** (manifests declare direct deps; transitive/lockfile deps are not parsed).

**System connections — captured as individual Facts, per-stack** (code-based):
- `python_flask` (read in full) captures:
  - **`connection`** (`_connections`, L363-372): DB connections via a **hardcoded driver list** (L359-360): `create_engine` (SQLAlchemy), `pyodbc.connect`, `psycopg2.connect`, `sqlite3.connect`, `pymysql.connect`, `mysql.connector.connect`, `MySQLdb.connect`, `pymssql.connect`. All `type="database"`.
  - **`external_call`** (`_external`, L390-428): HTTP (`requests.*`, `httpx.*`, `urllib.request.urlopen` → `type="http"`), email (`smtplib.SMTP*` → `type="email"`), process (`subprocess.*`, `os.system`, `os.popen` → `type="process"`), file (`open()`, `os.remove/unlink/...`, `shutil.*` → `type="file"`).
  - **`data_access`** (`_sql`, `_models`): SQL ops (SELECT/INSERT/UPDATE/DELETE, stored procs), ORM entities.
  - **`config_key`** (`_config`): config reads (`app.config`, `os.environ`, `os.getenv`) → `source="code"`.
- The **generic extractor** captures config-file connections (`generic.py`): `web.config`/`app.config` `connectionStrings` (L100-103), `appsettings*.json` `ConnectionStrings` (L130-131), `.properties` `datasource.url`/`jdbc.url`/`.url` (L147-148). **All hardcoded `type="database"`** (`generic.py:78`).

### 13.2 The gaps (why the integration picture is incomplete)

1. **Non-DB system connections are not detected.** No regexes for cache (Redis/Memcached), message queues (Kafka/RabbitMQ/SQS/ActiveMQ), object storage (S3/Azure Blob/GCS), gRPC, or LDAP/AD. `external_call.type` is only `{http, email, process, file}`; `connection.type` is only `database`.
2. **The connection-type vocabulary is too narrow.** A modern integration map needs `cache`, `queue`, `object_storage`, `grpc`, `ldap`, `search`, etc.
3. **DB detection is hardcoded by driver** (the per-stack `_CONNECT` regex). Newer/async drivers (`asyncpg`, `oracledb`, `cx_Oracle`, SQLAlchemy-async, `databases`) and other stacks' drivers are missed unless each stack's regex is extended. Incomplete by construction.
4. **The connection TARGET is not recorded (by design — it's a secret).** The `connection` Fact's `name` is the *driver* (`pyodbc.connect`), not the target (the DB host/database). The actual target (the connection string value) is deliberately not recorded (redaction). The config *key name* is captured (`config_key`), so "the app reads a `DATABASE_URL`-style key" is known, but "which DB, at which host" is not. Correct for redaction, but it means the integration map shows *that* a DB is used, not *which one*.
5. **No integration VIEW is produced.** AppDoc emits the *raw* Facts (one `connection`/`external_call`/`dependency` per observation). It does NOT produce a derived **System Connections** section — a system-to-system summary ("this app: 1 × database (pyodbc), 3 × outbound HTTP (api.x, api.y, ...), 1 × Redis, 1 × Kafka") with per-connection file/line provenance. The reader has to mentally aggregate hundreds of raw Facts into the integration picture. *That aggregation is the missing "proper documentation."*
6. **Dependencies are direct-only** (no transitive/lockfile). Usually acceptable; noted for completeness.

### 13.3 The plan addition (two sub-phases)

**Phase 6a — Expand connection types + detection (the raw Facts).**
- Widen the type vocabulary: `connection.type` ∈ `{database, cache, queue, object_storage, grpc, ldap, search, ...}`; `external_call.type` ∈ `{http, email, process, file, grpc, ...}`. The `Fact.detail` is free-form, so this is a **convention change, not a schema change** — `KINDS` and `SCHEMA` are untouched.
- Add per-stack detection for common non-DB integrations. Python (`python_flask` `_connections`/`_external`): `redis`/`aioredis` (cache), `pika`/`kafka`/`boto3.sqs`/`kombu` (queue), `boto3.s3`/`azure.storage`/`google.cloud.storage` (object storage), `grpc`/`grpcio` (grpc), `ldap3`/`python-ldap` (ldap), `elasticsearch`/`opensearch` (search). Each yields a `connection`/`external_call` Fact with the correct `type`. Same extension per stack (Java: `Jedis`/`Lettuce`, Spring Kafka, AWS SDK; .NET: `StackExchange.Redis`, `MassTransit`, `Azure.Storage.Blobs`; Node: `ioredis`, `kafkajs`, `aws-sdk`).
- Drive it from a **shared integration catalog** (`stacks/integrations.py`: `type -> {language: [driver-regexes]}`), maintained once and referenced by each stack — rather than 6 ad-hoc regex lists.
- **Determinism:** new Facts are *additive* (the raw Facts gain entries; existing Facts unchanged). The output is **NOT** byte-identical to today (new Facts appear) — a *content* change. Gate it behind a documented extraction changelog (not a silent default). **Test:** `test_integration_catalog_facts` (a fixture with a Redis + Kafka + S3 call yields the 3 typed Facts).

**Phase 6b — Produce the integration VIEW (the derived section).**
- A **deterministic** `System Connections` section, derived from the raw `connection` + `external_call` + `dependency` Facts (a post-pass in render/`summary`, **not** the AI Narrative). It aggregates the raw Facts into a system-to-system summary:
  - Group by `type` (database, cache, queue, object_storage, grpc, http, ...).
  - Per type: distinct targets/drivers, the count, and file/line provenance (a few examples + "N more").
  - A compact integration map (a table or a Mermaid/ASCII diagram: `app → {DB, Redis, Kafka, api.x, ...}`).
- This section is **deterministic** (a pure function of the Facts) → it belongs in the render/`summary`, **not** the AI Narrative. The AI Narrative can still *describe* it in prose, but the *map* itself is derived (byte-identical across runs).
- **Determinism:** the integration view is a pure function of the raw Facts → byte-identical across runs (the existing byte-identity test passes; a new `test_integration_view_is_deterministic` pins it).
- **Presentation:** render it as a top-level "System Connections" / "Dependencies" section in the HTML (and Markdown), near the top — the integration picture the reader wants first.

### 13.4 Answer to the question

- **Dependencies:** properly documented today (manifest-based, 8 ecosystems, direct deps). Direct-only is the one caveat.
- **System connections:** *raw* connections are captured (DB via driver list, HTTP/email/process/file), but the integration picture is **not** properly documented: (a) non-DB integrations (cache/queue/storage/grpc/ldap) are not detected, (b) the type vocabulary is too narrow, (c) DB detection is hardcoded by driver, (d) **no derived integration VIEW is produced**. **Phases 6a + 6b close this gap.**

> **Recommendation:** this is a *content* improvement (not a performance one). Do **6a** (expand detection + types) first — additive, unblocks the richer map. Then **6b** (the derived System Connections section) — the "proper documentation" the reader actually wants. Both are independent of the performance phases (0-5) and can run in parallel.
