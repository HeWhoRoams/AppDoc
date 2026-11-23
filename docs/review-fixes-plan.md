# AppDoc Review-Remediation Plan

> **Status (2026-11-23): done.** The fixes are on `main` and recorded in the CHANGELOG (`## Unreleased`: versioned cache key, `smtp` in the view vocabulary, ASCII view, `read_bytes` TOCTOU, cache cap, Windows CI, de-duplication, scratch exclusion in `conftest.py`). The cache-key part is superseded by 2.6 §4.6.

Fixes the findings from the pre-push code review (5 commits, `bb86a08 → main 5a9af09`).
The review found **no blockers / no HIGH** — determinism, default-neutrality, stdlib-only, and
redaction all hold with byte-level evidence. Two **MEDIUM** issues are worth fixing before
tagging; seven **LOW/nit** items are optional.

**Verified against source** (not the review's summary): every finding below was confirmed at the
cited line before planning.

---

## Prioritization

| # | Finding | Severity | Fix | Effort |
|---|---|---|---|---|
| 1 | Cache can serve stale Facts across an AppDoc upgrade | **MEDIUM** | Salt `_cache_key` with schema + extractor version | S |
| 2 | `smtp` outside the view vocabulary (orphan "Smtp" row) | **MEDIUM** | Add `smtp` to `TYPE_ORDER`/`TYPE_LABEL` | S |
| 3 | Redaction test is tautological (no embedded credential) | LOW | Add a credential-bearing line to the sample | S |
| 4 | Default run writes an unbounded, never-pruned cache | LOW | Cap the cache size | S |
| 5 | `pymp-` spawn temp-dir cleanup traceback (env artifact) | LOW | Suppress / let CI decide | XS |
| 6 | `read_bytes` TOCTOU (file deleted mid-scan) | LOW | Catch `OSError`, treat as skipped | XS |
| 7 | Windows spawn untested (structurally sound) | LOW | Add a `windows-latest` CI job | S |
| 8 | Intra-file de-dup inconsistency (`dict.fromkeys` vs as-is) | LOW | Standardize on `dict.fromkeys` | XS |
| 9 | Non-ASCII `×` / `…` in the view output | LOW | Use ASCII (`x` / `...`) | XS |

**Phase 1 (must-fix before tagging):** items 1–2.
**Phase 2 (worth fixing):** item 3.
**Phase 3 (optional nits, fix opportunistically):** items 4–9.

---

## Phase 1 — The 2 MEDIUM fixes

### Fix 1: Salt `_cache_key` with schema + extractor version

**Site:** `appdoc/extract.py:78-84` (`_cache_key`), called at `:126`.

**Problem:** The key is `sha256(raw + path + sorted(stack_ids))`. It omits any AppDoc version /
extractor fingerprint. Because the cache is **on by default** and written into the target's out
dir (`.appdoc-cache.json`), a cache file that survives an AppDoc upgrade re-serves Facts computed
by the *older* extractor for unchanged files — silently.

**Fix:**

1. Add a manually-maintained extractor version constant (top of `extract.py`, near the other
   constants):
   ```python
   EXTRACTOR_VERSION = 1  # bump whenever a stack/catalog regex or extraction logic changes
   ```
2. Include `F.SCHEMA` and `EXTRACTOR_VERSION` as the leading bytes of the key hash:
   ```python
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
   ```

**Why a constant and not a source hash:** Hashing the extractor source at runtime would read the
`stacks/*.py` + `integrations.py` files on every extraction (expensive + fragile). A
manually-bumped constant is the standard versioning approach (like a schema migration) — cheap,
explicit, and the reviewer's recommended alternative.

**Discipline:** Add a one-line note in `CHANGELOG.md` ("Unreleased") and a comment at the constant:
"bump `EXTRACTOR_VERSION` when a stack/catalog regex or extraction logic changes." Any worker
touching `stacks/` or `integrations.py` must bump it.

**Verification:**
- Unit test: two cache keys for the same `(raw, path, detected_ids)` but different
  `EXTRACTOR_VERSION` must differ; same version must match.
- Behavioral: write a cache with version 1, bump to 2, re-extract — the cache must miss (recompute).
- Byte-identity: the default run (no flags) must stay byte-identical to the current `main`
  (the version bytes are part of the *key*, not the output — `facts.json` is unchanged).

---

### Fix 2: Add `smtp` to the view vocabulary

**Site:** `appdoc/integration.py:18-36` (`TYPE_ORDER` / `TYPE_LABEL`).

**Problem:** `java_spring.py:729-730` emits `connection type="smtp"` for a Spring-XML
`<bean class="…MailSender…">`. The view's `TYPE_ORDER`/`TYPE_LABEL` has no `smtp`, so
`_label("smtp")` falls back to `"smtp".replace("_"," ").title()` = `"Smtp"` — an orphan row sorted
*after* the canonical list (via `_sorted_types`'s `extra` branch at `:60`), not grouped with
"Email".

**Fix:** Add `smtp` to both `TYPE_ORDER` and `TYPE_LABEL`:
```python
TYPE_ORDER = (
    "database", "cache", "queue", "object_storage", "grpc", "ldap", "search",
    "http", "email", "smtp", "process", "file",
)
TYPE_LABEL = {
    ...
    "email": "Email",
    "smtp": "Email (SMTP)",
    ...
}
```

**Why not normalize `smtp` → `email` in the extractor:** The `smtp` type is a distinct raw type
(a mail-sender *connection* bean vs. the `email` *external_call* variable). Changing the raw type
would alter the Facts (a determinism-affecting change to the `type` detail). Adding it to the view
vocabulary is the minimal, Facts-preserving fix.

**Verification:**
- Unit test: a `facts.json` containing a `connection type="smtp"` Fact renders "Email (SMTP)" in
  the view (not "Smtp"), and appears in the canonical group (not sorted after it).
- Existing samples: re-run all samples; the view is unchanged (no sample currently emits `smtp`).
- Byte-identity: the default run stays byte-identical (the vocabulary is a *display* concern; the
  raw `type="smtp"` Fact is unchanged).

---

## Phase 2 — The tautological redaction test

### Fix 3: Add a credential-bearing line to the integrations sample

**Site:** `tests/samples/integrations/` (the Python sample the catalog test runs) +
`tests/test_integration_catalog.py:54-58`.

**Problem:** `test_fixture_yields_no_secret_flag_or_value` asserts `Password=`/`Pwd=`/`fakepass`/
`user:pass@` are absent from the output. But the sample embeds **no** credential values (by
design), so the test passes trivially — it proves nothing about redacting *embedded* credentials.

**Fix:**
1. Add a line to the integrations sample that embeds a credential in a URL (e.g. a Redis URL with
   a password):
   ```python
   r2 = redis.Redis.from_url("redis://user:***@r2.internal:6379")
   ```
2. The existing test (`test_fixture_yields_no_secret_flag_or_value`) already asserts
   `user:pass@` is absent — it now has something to assert against.
3. Add an explicit assertion that the *driver name* is still present (proving the fact was
   extracted, not dropped):
   ```python
   def test_embedded_credential_is_redacted(self):
       self.assertIn("redis.from_url", self.text)   # the driver name is present
       self.assertNotIn("user:pass@", self.text)     # the credential is NOT
       self.assertNotIn("secretpw", self.text)       # the password value is NOT
   ```

**Verification:**
- The test now fails if the credential leaks (it can't pass trivially anymore).
- The catalog's `secret_location` flag: a `redis://user:***@…` URL should set
  `secret_location=True` on the Fact (the catalog already does this — verified by the reviewer).
- Byte-identity: the sample is a test fixture, not a target — it does not affect `facts.json`
  determinism for real targets.

---

## Phase 3 — The optional nits (fix opportunistically)

### Fix 4: Cap the cache size

**Site:** `appdoc/extract.py:100-107` (`_save_cache`) / `:141` (cache write-back).

**Problem:** The default run writes `.appdoc-cache.json` into the out dir. It's gitignored and
best-effort, but unbounded in growth and never pruned. On a large repo with many files, the cache
can grow large.

**Fix:** Cap the cache at a max entry count (e.g. 10,000). When the cap is exceeded, clear the
cache (simplest) or prune the oldest entries (LRU — more complex). The simplest correct fix:
```python
_CACHE_MAX_ENTRIES = 10_000
...
# in _save_cache, before the json.dump:
if len(cache) > _CACHE_MAX_ENTRIES:
    cache.clear()  # the cache is best-effort; a cleared cache just means a cold next run
```

**Verification:** The cache file size is bounded; a cold run after a cleared cache recomputes (no
correctness change).

### Fix 5: Suppress the `pymp-` spawn temp-dir traceback

**Site:** Environment artifact (the multiprocessing spawn temp-dir cleanup on the overlay fs).

**Problem:** `OSError: [Errno 39] Directory not empty: …/pymp-…` prints after the test run
(completed, exit 0). It does not affect results.

**Fix:** Optional. Only acts on it if it becomes CI-flaky. The `ProcessPoolExecutor` handles the
cleanup; the traceback is a finalizer artifact on the overlay fs. No code change needed unless CI
fails.

### Fix 6: Handle the `read_bytes` TOCTOU

**Site:** `appdoc/scan.py` (`read_bytes`, the `os.path.getsize` then `open`).

**Problem:** A file deleted between `getsize` and `open` raises `OSError`. Same failure mode as
the baseline `read_text` (no regression).

**Fix:** Optional. Catch the `OSError` and return `b""` (treat the file as empty/skipped):
```python
def read_bytes(root: str, path: str) -> bytes:
    full = os.path.join(root, path)
    try:
        size = os.path.getsize(full)
    except OSError:
        return b""  # file deleted mid-scan
    ...
```

**Verification:** A deleted-file test (create, delete, scan) returns empty + no crash.

### Fix 7: Add a `windows-latest` CI job

**Site:** `ci/appdoc-docs-gate.yml` (the CI workflow).

**Problem:** The Windows spawn is structurally sound (the `__main__` guard, the picklable worker
function) but not empirically tested (Linux only).

**Fix:** Add a `windows-latest` job to the CI workflow that runs the test suite. The
`ProcessPoolExecutor` spawn path is the only Windows-specific code; a passing Windows run proves
it.

**Verification:** The Windows CI job passes (the suite runs on `windows-latest`).

### Fix 8: Standardize the intra-file de-dup

**Site:** `appdoc/stacks/node_express.py:212` (`dict.fromkeys(out)`) vs.
`appdoc/stacks/python_flask.py:244` (returns the list as-is).

**Problem:** `node_express` de-dups its per-file Facts with `dict.fromkeys(out)` (order-preserving
de-dup); `python_flask` and others return the list as-is. The global `facts.dumps` de-dups
regardless (via `sorted(set(facts))`), so the output is identical — but the inconsistency is a
maintenance trap.

**Fix:** Standardize on `dict.fromkeys` (order-preserving de-dup) in all stack extractors. This
makes the per-file de-dup explicit + consistent, and the global `dumps` de-dup is the safety net.

**Verification:** All stack extractors use `dict.fromkeys`; the test suites pass; the output is
byte-identical (the global `dumps` de-dup is unchanged).

### Fix 9: Use ASCII in the view output

**Site:** `appdoc/integration.py:101,54` (the `×` U+00D7 and `…` U+2026).

**Problem:** The view emits `×` and `…` (non-ASCII) with `ensure_ascii=False`. Fine for UTF-8
consumers, but downstream ASCII-only consumers (some legacy tools) may choke.

**Fix:** Use ASCII: `×` → `x`, `…` → `...`. The output is still human-readable + deterministic.

**Verification:** The view output is pure ASCII; the test suites pass; the output is byte-identical
to the current view except for the ASCII substitutions.

---

## Phasing + commits

| Phase | Items | Commit message |
|---|---|---|
| 1 | Fixes 1–2 (the 2 MEDIUM) | `fix: version the cache key + add smtp to the view vocabulary` |
| 2 | Fix 3 (the redaction test) | `test: add a credential-bearing fixture to the redaction test` |
| 3 | Fixes 4–9 (the nits) | `fix: cache cap, TOCTOU, de-dup standardization, ASCII view` |

**Verification per phase:**
- Phase 1: the new unit tests (the cache-key version test + the `smtp` view test) pass; the full
  suite (154+) passes; the default run is byte-identical to the current `main`.
- Phase 2: the redaction test now has a credential to assert against; the full suite passes.
- Phase 3: the nits are fixed; the full suite passes; the default run is byte-identical.

**Stdlib guard:** No new imports (all fixes use existing stdlib: `hashlib`, `os`, `json`). The
AST guard stays green.

**Push policy:** Direct to `main` (no PR), after the user triggers.
