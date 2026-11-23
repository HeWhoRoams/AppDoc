# AppDoc v2.5.0 → v2.6.0 Remediation Plan: Tooling and Facts release

**Date:** 2026-11-13 (rev 2, 2026-11-23: status and amendments below)
**Status:** Next phase. Starts after **2.5.0 ships as written** in `docs/remediation-plan-2.5.md`, which another agent is executing now. Nothing in this plan changes 2.5's scope, files or tests.
**Basis:**
- the 2.4 example audit (`AppDoc-v2.4-Examples-Audit-2026-11-13.md`, AppDoc project);
- a line-level read of `appdoc/` at `db2589e`;
- ADR 0016 (principles P1–P6, binding);
- the decision session Q1–Q21 (2026-11-13).

**Release sequence:**

| Release | Plan | Template | Schema | What it is |
|---|---|---|---|---|
| 2.5.0 | `remediation-plan-2.5.md` (in flight, unchanged) | 2.4 | `/6` | C14/C15/C16, owner advisory, env/CI config roles, extractor coverage, examples regenerated |
| **2.6.0** | **this plan** | **2.4** | **`/7`** | Tooling and Facts: tags, provenance sidecar, determinism, capabilities, scan fixes, config/secret naming, `appdoc gate`, generated AppDoc docs, release script, answer keys, example rotation |
| 2.7.0 | `remediation-plan-2.7.md` | **2.7** | `/7` (unless a 2.7 item changes Facts) | Template: append-only register, audit provenance and plan, notes, computed scope, count markers, severity order, full paths, closed questions, §17 |

**Rule of this release (Q19):** a new rule that would fail a committed template-2.4 document runs here as an **advisory labelled "fails from template 2.7"**. It is enforced only on documents stamped 2.7. C14 and C15 already fail in 2.5.0, because the 2.5 plan was written before Q19. That is a recorded R6 exception and is not reversed here (R2). 2.7 replaces C15's English matching with count markers.

**Format:** house convention. Every item has a failing test (TDD), a corpus case where a Target is needed, and a "why this is not a weakening" line.

---

## Status and amendments (rev 2, 2026-11-23)

**Not started.** Baseline is `origin/main` at `2e59393`: version 2.4.0, schema `/5`, with C14–C16 done and the rest of 2.5 open (`remediation-plan-2.5.md`, "Status and amendments"). There is no `tools/` directory, no `tests/corpus/`, no `tests/test_determinism.py` and no tag after `v2.0.0`. Everything below the line-by-line plan still applies, with these amendments. Findings verified on `main` on 2026-11-23: CRIT-01 (capabilities recorded as `[]`) and NEW-03 (`scan._retired_candidates` re-reads every outside file for every candidate folder) are still present.

| # | Amendment |
|---|---|
| **B-1 Cache salt** | `main` carries a content-hash cache (`.appdoc-cache.json`, salted with `SCHEMA` and a hand-bumped `extract.EXTRACTOR_VERSION`). A stack change that nobody remembers to bump silently serves stale Facts. New **§4.6**: the cache salt becomes `schema` plus `version.bundle_hash()` (12 hex), so every AppDoc build invalidates the cache and the manual constant is deleted. Cost: a cold run after any AppDoc patch. Tests: `test_cache::test_bundle_change_invalidates`, `::test_same_bundle_hits`; `test_version::test_no_manual_extractor_version`. 2.5's R21 holds until this lands. |
| **B-2 Determinism harness covers the new paths** | §3.3 adds: `--workers 1` vs `--workers 2` byte-identical; cold vs warm cache byte-identical; `--no-cache`; `--skip-tests` off by default and a different output when on (documented); `facts-summary.md` including the `System Connections` view; the cache file and `provenance.json` excluded from artifact hashes and from the Target scan (the out dir is already excluded). The ambient-input scan (R13) allow-lists `os.cpu_count()` in `extract.py` (the worker count; it cannot change output) and `APPDOC_CI`. |
| **B-3 Prune rules live in `scan.prune_rule`** | §4.3's two new prunes (`AppDoc output`, `AppDoc skill bundle`) are added as rules in the existing `scan.prune_rule(name, parent_files, full, dotnet_above)`, which today returns a rule name for build output, vendored packages and so on. They need a bounded read of a folder's files (first 4 KiB), so update that function's "tree only" docstring and keep the rule deterministic. Disclosure and `.appdocignore !name` re-inclusion are unchanged. |
| **B-4 One hash pass** | §4.2's `_content_index` also replaces the per-folder reads in `_retired_candidates`. `extract._extract_file` already reads each file's bytes for its cache key; the scan should compute one SHA-1 per scanned file (streaming) and hand it to both. Test: `test_core::test_content_index_reads_each_file_once` (exists in the plan); add the 10,000-file scale test from §7.1 with `--workers 2`. |
| **B-5 Capabilities and shared emitters** | The integration catalog (`stacks/integrations.py`) is called from five stacks and emits `connection` and `external_call` Facts on their behalf. §4.1 states the rule: **a Fact is attributed to the Stack that called the emitter** (the `stack` field of the Fact), and conformance counts by that field. Kinds that `generic.extract` emits (it is not a registered Stack and emits no `stack` Fact) are listed once in `tests/test_conformance.py::GENERIC_KINDS` and exempt from per-stack capability checks. `capabilities_of` accepts dotted detail capabilities beyond subtypes (2.8 declares `entry_point.guard_mechanism`, `entry_point.guard_reach`, `entry_point.desktop`). Blocks fed by generic kinds say "read by the generic reader", not "no supported Stack". |
| **B-6 Gate** | §6.1: the gate extracts with `--no-cache` into `.appdoc-regen/` so a stale cache can never mask a code change, and `appdoc gate` accepts `--workers`. Test: `test_gate::test_gate_ignores_stale_cache`. |
| **B-7 Tags first** | §3.0.1 is unchanged and urgent: `git tag -a v2.4.0 9241c2f`. `v2.5.0` is created at the 2.5 release commit, which now also contains the performance and integration work (see 2.5 A-1). |
| **B-8 Effort** | +0.5 d (§4.6 and the wider harness): about **8.5 d**. |

---

## 1. Decision log (2026-11-13)

| Q | Decision | Effect here |
|---|---|---|
| Q1 | P1–P6 binding (ADR 0016) | All items |
| Q2 | Hand-written counts go through generated count markers; English "N of M" matching becomes advisory | Markers in 2.7; C15 stays as 2.5 ships it until then |
| Q3 / Q11 | Non-template work first, then one template release | This plan = 2.6.0; 2.7.0 = template. **Amended 2026-11-13:** 2.5.0 was already in flight, so the tooling release is 2.6.0 and the template release is 2.7.0 |
| Q4 | `generator` leaves `facts.json` for `provenance.json` | §3.2 |
| Q5 | Byte-identical folders are "duplicate folders", never "retired" | §4.2 |
| Q6 | Secret-name modifiers are a closed set in code | §4.4 |
| Q10 | Narrative answer keys enforced by `tools/release.py` on local clones | §6.3 |
| Q16 / Q18 | `examples/current/` + `examples/previous/`, rotated by `tools/release.py` | §7.2 |
| Q19 | New failing rules are advisories until the template release | §5 |
| Q20 | Examples regenerated mechanically in this release, disclosed by provenance | §7.2 |
| Q7–Q9, Q12–Q15, Q17 | Template-release decisions | `remediation-plan-2.7.md` |

### Scope boundary with the in-flight 2.5.0

- **2.5.0 owns** C14, C15, C16, the owner-absent advisory, env/CI config roles (2.5 §1.5), extractor coverage (2.5 Phase 2: razor, EF, HttpClient, Go connection/schema/templates, Flask SQLAlchemy), schema `/6`, and its own example regeneration. This plan does not touch those items, their tests or their ADRs (0011, 0012).
- **Built on 2.5's output:**
  - 4.1 moves the capabilities 2.5 adds at module level onto the class.
  - 4.4 extends the post-pass 2.5 §1.5 rewrites.
  - 7.2 rotates whatever example layout 2.5.0 commits.
- **Known carry-overs from 2.5.0, fixed here:** 2.5 ships with stack `capabilities` still recorded as `[]` (CRIT-01), its conformance test passing against module-level sets. It also pins the gate to `v2.5.0`, but the gate's extract step cannot run (NEW-01/02) and no tagging step exists (CRIT-02). If 2.5.0 adopts the optional amendments in §10, drop the matching items here.

---

## 2. Findings addressed in 2.6.0

| ID | Finding | Item |
|---|---|---|
| CRIT-01 | Stack `capabilities` always `[]`; docs say "no entry-point capability" while listing routes | 4.1 |
| CRIT-02 | Gate pins a version with no tag | 3.0, 6.3 |
| NEW-01 | Gate extract always exits 1 (`--out` outside the Target; reproduced) | 6.1 |
| NEW-02 | Gate checks the skill out inside the Target; AppDoc scans itself | 6.1, 4.3 |
| NEW-03 | Retired scan re-reads the tree per folder (gitea ≈ 2.47 M reads) | 4.2 |
| NEW-05 | `generator` in `facts.json` makes every AppDoc patch look like a code change | 3.2 |
| NEW-06 | Template gating compares the running version as a string (`check.py:717`) | 3.1 |
| MAJ-02 | Content signal labels live and test folders "retired"; nesting not collapsed | 4.2 |
| MAJ-03 | Prior AppDoc output scanned as source | 4.3 |
| MAJ-06 | SKILL/README/docstrings drift from the code | 6.3, 6.4 |
| MAJ-07 | One version string covers different code; no bundle in reports | 3.2, 6.3 |
| MAJ-08 | Config split per key; substring secret naming | 4.4 |
| MIN-02 / MIN-06 | Wide citation ranges; crowded cells | 5.1 |
| MIN-04 / MIN-07 | Generated copy | 4.7 |
| Systemic | Determinism and accuracy unmeasured | 3.3, 7.1 |

---

## 3. Phase 0 — Guardrails

### 3.0 Tags and version

1. **Now, independent of both releases:** `git tag -a v2.4.0 9241c2f -m "AppDoc 2.4.0"` (and `v2.3.0` at its release commit if it was ever pinned). Push the tags.
2. When 2.5.0 is committed: `git tag -a v2.5.0 <commit>`, unless 2.5 adopts amendment A1 (§10).
3. Start this release by setting `__version__ = "2.6.0.dev0"` and adding `## Unreleased` to the CHANGELOG.

### 3.1 One version comparison (NEW-06)

Add `template_spec.version_tuple(s) -> tuple[int, ...]` and use it for every version comparison:
- the template gate (`check.py:717`: `doc_ver >= (2, 4)`, using the **document's** stamp);
- C7 version skew;
- the gate's schema comparison.

`tests/test_core.py::test_no_string_version_compares` greps `appdoc/` for `>= "2.`/`<= "2.`; `::test_version_tuple`.

### 3.2 Provenance sidecar (P5 → NEW-05, MAJ-07)

1. **`appdoc/version.py`:** `__version__`, `bundle_hash()` (moved from `__main__.py`), and `provenance() -> dict`. There is one implementation (R5).
2. **`extract`** writes `docs/appdoc/provenance.json`: `{"generator", "bundle" (12-hex), "schema"}`. There are no timestamps.
3. **`facts.json` drops `generator`.** It keeps `schema`.
4. **`fill`** adds `blocks_by` (version and bundle) to `provenance.json`. Appendix A A.1 prints: `Generated blocks written by AppDoc 2.6.0 (bundle 7c1e…).` When the register's audit record carries `audited_with` (optional in 2.6, required in 2.7) and its major.minor differs, A.1 adds `Generated blocks were regenerated after the audit and are not covered by it.` This line is generated content, so it ships in 2.6.0 (Q20).
5. **`check`:**
   - The scope line becomes `Run by AppDoc 2.6.0 (bundle …)`.
   - C7 version skew reads `provenance.json`; if it is missing, this is an advisory.
   - A `provenance.json` whose `schema` disagrees with `facts.json` fails C7.

**Tests:** `test_version::test_facts_has_no_generator`, `::test_provenance_written`, `::test_check_report_prints_bundle`, `::test_bundle_single_implementation`; `test_check::test_c7_skew_reads_provenance`; `test_register::test_a1_blocks_provenance_line`. Corpus `patch-upgrade`.

### 3.3 Determinism harness (P3, R13, R14)

`tests/test_determinism.py` lands before Phase 1 and guards it:

1. **Run twice:** for every sample and corpus Target, `facts.json` and `facts-summary.md` are byte-identical.
2. **Idempotence:** `fill(fill(x)) == fill(x)`; `seal` twice is a no-op; `build` on a passing doc changes no file; `render` twice gives identical HTML.
3. **Order independence:** files created in reverse order give the same Facts.
4. **Location independence:** two absolute paths give the same Facts.
5. **No ambient inputs (R13):** scan `appdoc/**/*.py` for `datetime.now`, `date.today`, `time.time`, `getpid`, `uuid`, `random` and `os.environ`, with an allow-list (`APPDOC_CI`).
6. **One normalization (R14):** `appdoc/textnorm.py::normalize_text` (CRLF/CR→LF, strip trailing whitespace per line and the final newline, NFC). `claim_sha` and the seal use it. Test: LF vs CRLF gives equal seals.
7. **Cross-OS bytes:** `tools/artifact_hashes.py` runs in every CI matrix job, and a final job fails if any hash differs.

### 3.4 Corpus and baselines

**Corpus** under `tests/corpus/<case>/`, added to the `tests/test_corpus.py` module 2.5 creates. Every case is red on `v2.5.0`.

| Case | Asserts |
|---|---|
| `caps-routes` | `capabilities` ⊇ `entry_point.route`; 16.7 never says "no entry-point capability" |
| `dup-twins` | No retired candidate; one `duplicate_folders` pair |
| `dup-tests` | Duplicates under test paths ignored |
| `dup-nested` | `old/` reported once, not `old/sub/` |
| `prior-output` | A folder with AppDoc-stamped output is pruned (`AppDoc output`) |
| `skill-in-target` | A skill bundle inside the Target is pruned (`AppDoc skill bundle`) |
| `ini-split` | File-level promotion; `MIN_PASSWORD_LENGTH` is not a secret; `SECRET_KEY` is |
| `wide-range` | C20 advisory; fails under `--strict` |
| `patch-upgrade` | Gate exits 0 on a same-schema AppDoc patch with unchanged code |
| `gate-layout` | Gate 0 / 2 / 3 for unchanged / code change / schema change |

**Baselines:** `tests/test_diag_metrics.py` pins the 2.5.0 example values this release must move: retired counts, capabilities `[]`, the gitea "not classified" trailer and its secret-location count, and bare-name counts. Read the actual values from the 2.5.0 examples when this phase starts; the 2.4 values were 2/9/40/0, 569 keys, and 504/1,013.

---

## 4. Phase 1 — Extractor and scan

### 4.1 Capabilities on the class, typed, one lookup (CRIT-01)

1. `stacks/base.py`: add `capabilities: frozenset = frozenset()`. Move each module-level set into its class:
   - `aspnet.py:680`, `aspnet_core.py:537`, `classic_asp.py:470`, `go.py:653`, `java_spring.py:894`, `node_express.py:632`, `python_flask.py:689`.

   Include the kinds 2.5.0 added (Phase 2: `ui_page`, `data_access`, `external_call`, `connection`, `schema_object`). Keep a module alias for one release.
2. Replace `entry_point` with the emitted subtypes `entry_point.route|page|command|job`, derived from each stack's code paths.
3. `stacks.capabilities_of(stack)` is the only lookup. It is used by `extract.py:118` and by `tests/test_conformance.py:53-56` (that test read the module while production read the instance, which is why it missed the bug).
4. **Conformance:**
   - `test_supported_stack_declares_capabilities`;
   - `test_extract_records_capabilities` (the stack Fact equals `capabilities_of`);
   - `test_entry_point_type_needs_capability`;
   - "sample exercises every capability", extended to subtypes.
5. `fill._stacks_reporting(doc, cap)` replaces `_stack_capabilities`. 16.7 names the stacks with `entry_point.job`, or says "No supported Stack reports jobs (`python-flask`); read the source for job runners".

**Why this is not a weakening:** the printed statements become true, and the test now uses production's lookup.

### 4.2 Retired by name only; duplicate folders; one hash pass (MAJ-02, NEW-03, Q4)

1. **`_content_index`:** one streaming SHA-1 per scanned file (respecting `MAX_BYTES`/`skipped`), and `by_hash`.
2. **Exclude test paths** through `facts.is_test_path` (R5).
3. `retired_candidates` holds name signals only (token set unchanged).
4. New `target.scan.duplicate_folders`: `{a, b, files}`. Folder `A` (≥5 files, not a test path) pairs with the folder `B` holding most of its matches when ≥50% of its hashes match. Ties break to the smallest path (R15). Pairs are stored once with `a < b`, and the list is sorted.
5. **Collapse nested** entries in both lists (as the `scan.py:201-205` docstring already promises).
6. **Render:**
   - "Folders that look retired by name (not excluded)";
   - "Folders that duplicate another folder (not excluded; say in 2.1 which copy is live)".

   Each list is capped at 10.
7. **C7:** name candidates must be named in §2 (unchanged). A duplicate pair absent from §2 is an advisory, and fails under `--strict`.
8. The entry-points headline counts name candidates only.
9. Amend ADR 0010; update the CONTEXT.md terms.

**Tests:** `test_core::test_retired_name_signal_only`, `::test_duplicate_pair_reported_once`, `::test_duplicate_tie_break_sorted`, `::test_duplicates_under_test_paths_ignored`, `::test_nested_candidates_collapsed`, `::test_content_index_reads_each_file_once`; `test_fill::test_scan_coverage_duplicate_heading`; `test_check::test_c7_duplicate_pair_advisory`.

### 4.3 Prune AppDoc's own artifacts (MAJ-03, NEW-02)

1. **`AppDoc output`:** a folder holding `facts.json` with `"schema": "appdoc-facts/` in its first 4 KiB, or `application-documentation.md` with `<!-- appdoc:template ` in its first 4 KiB.
2. **`AppDoc skill bundle`:** `run_appdoc.py` plus `appdoc/assets/template.md`.
3. Both are recorded in `target.scan.pruned` and disclosed in 2.1. `.appdocignore` `!name` re-includes them.

**Tests:** `test_core::test_prune_prior_appdoc_output`, `::test_prune_skill_bundle`, `::test_appdocignore_reincludes_appdoc_output`, `::test_plain_docs_folder_not_pruned`.

### 4.4 File-level promotion and segment-aware secret names (MAJ-08)

Builds on 2.5 §1.5, which adds `env`/`ci` roles in the same post-pass (`extract.py`). File promotion applies after the read-kind split, and never promotes `env` or `ci` keys.

1. **Promote files:** any unclassified key in a file with at least one code-read key (matched through `_key_variants`: the full name and the last dotted segment) becomes `app`.
2. **`secrets.is_secret_key`:** tokenize on separators and camel case.
   - It is a secret when a secret noun is present and none of the closed-set modifiers is: `length min max size count ttl lifetime expiry expires minutes seconds hours days algo algorithm hash complexity policy check pwn enable enabled disable disabled allow require required form cache uri url path file header name type mode scope scopes regex pattern`.
   - `uri`/`path`/`file` set `secret_ref: true` (a new `DETAIL_KEYS` entry) instead.
   - The set is closed and lives in code (Q6).
3. The `fill._config_reference` guard raises an internal error if a file is both `app` and "not classified".
4. C6 is untouched (it uses `find_secret_shapes`), and a test proves it.

**Tests:** `test_generic_facts::test_file_level_promotion`, `::test_ini_section_key_variants`; `test_core::test_secret_key_segments` (≥20 positive, ≥25 negative names, including gitea's), `::test_secret_ref_flag`, `::test_c6_unaffected_by_key_naming`; `test_fill::test_config_trailer_never_lists_app_file`.

### 4.5 Generated copy (MIN-04, MIN-07)

`fill.plural()` is used everywhere (no `(s)`); omit "(0 under folders that look retired)"; the A.4 label becomes `**E-1** (section 1), expect \`path:line\``. `test_fill::test_generated_copy` and `test_register::test_a4_label_section_and_location` cover them.

---

### 4.6 Cache salt from the bundle hash (B-1)

Replace `extract.EXTRACTOR_VERSION` with `version.bundle_hash()` in `_cache_key`. Delete the constant and the CHANGELOG instruction "bump `EXTRACTOR_VERSION`". The cache is best-effort, so a cold run after an AppDoc patch is the only cost. **Why this is not a weakening:** the cache can only miss more often.

---

## 5. Phase 2 — Advisories (template 2.4) and previews of 2.7

Every rule here is advisory on template 2.4: printed under "Advisories" in `check-report.md`, and failing only under `--strict` where noted. C14 and C15 keep the behaviour 2.5.0 ships.

### 5.1 C20 Citation precision (MIN-02, MIN-06)

- A range over `WIDE_RANGE = 100` lines that is a claim's only lined citation, in §4, §7 or §10.
- More than `CELL_CITES = 5` citations in a §4 or §10.1 cell.

Advisory; fails under `--strict`. This stays advisory in 2.7 too.

### 5.2 Previews of 2.7 rules

Where the 2.7 rule needs no new data file, 2.6.0 prints it as "fails from template 2.7":
- C9 severity order (§10.1, §15);
- C1 bare-name citations, with the full path in the message;
- C17 scope text containing ID tokens or digits.

The same functions implement them in 2.7 (R5); only the gate on the document's stamp changes.

---

## 6. Phase 3 — Gate, release and AppDoc's own docs

### 6.1 `appdoc gate` (NEW-01, NEW-02, CRIT-02)

1. `appdoc gate <target> [--require-audit] [--strict]` (`appdoc/gate.py`):
   - Read the committed `facts.json`; missing → exit 1.
   - Extract into a fixed `<target>/.appdoc-regen/`, which is excluded from the scan as the out dir and removed in `finally`.
   - Schema differs → exit 3 "AppDoc upgraded". Bytes differ → exit 2 "Facts changed", with a diff of at most 200 lines.
   - Otherwise run the Check and return its code. The version difference from `provenance.json` is informational only.
2. **YAML:** clone the skill to `$RUNNER_TEMP/appdoc-skill`, then run `python "$RUNNER_TEMP/appdoc-skill/run_appdoc.py" gate "$GITHUB_WORKSPACE" --require-audit`. ADR 0014 (gate as a command).
3. **`tests/test_gate.py`** executes it:
   - 0 / 2 / 3;
   - a patch-only provenance change → 0;
   - a skill folder inside the Target → 0;
   - the regen folder is removed;
   - the YAML calls `gate` from `$RUNNER_TEMP`.
4. AppDoc's own CI runs `gate` on a temp copy of `tests/samples/java-spring`.

### 6.2 CI jobs

Add to `.github/workflows/ci.yml`:
- the cross-OS hash comparison (3.3);
- the gate self-test;
- `tests/test_release.py`;
- the extractor eval (7.1).

### 6.3 Generated AppDoc docs and the release script (P6 → MAJ-06, MAJ-07, CRIT-02)

1. **`tools/gen_docs.py`** writes `<!-- appdoc-self:generated NAME -->` blocks from code:
   - README `commands` (from `__main__.build_parser()`);
   - README `rules` (`check.RULE_TITLES` and `RULE_SUMMARIES`, with advisory/strict/"fails from 2.7" flags);
   - README `facts-schema`;
   - SKILL.md `run-commands` (from `appdoc/workflow.py::SKILL_STEPS`);
   - the gate YAML header and pin.

   A test asserts that the `__main__`/`check.py` docstrings use the same constants.
2. **`tests/test_release.py`:**
   - `test_generated_docs_current` (`gen_docs --check` is clean);
   - `test_changelog_top_heading_matches_version` (`## X`, or `## Unreleased` with `.dev0`);
   - `test_gate_pin_matches_version` (release versions);
   - `test_release_script_dry_run`.
3. **`tools/release.py VERSION [--dry-run]`:**
   1. Clean tree on `main`.
   2. Set the version, rename `## Unreleased`, run `gen_docs`.
   3. Run the tests, the determinism job, the extractor eval and the **narrative answer-key eval** against local clones (`APPDOC_EVAL_ROOT`; refuses on regression, Q10).
   4. Rotate the examples (7.2).
   5. Commit, then `git tag -a`.
   6. Print the push command.
   7. Follow-up commit: `X.Y.(Z+1).dev0` and `## Unreleased`.

### 6.4 Hand-written doc updates

- **SKILL.md Run:** match whatever 2.5.0 leaves, plus `build` as the mechanical tail if 2.5 has not already made that change.
  1. Extract.
  2. Orient.
  3. Write.
  4. **Build** until it passes (3 failures → report verbatim).
  5. Audit in a fresh agent.
  6. **Build**.
  7. Report, including the A.1 provenance line.

  The command lines are generated (6.3). Writing rules: name each name-signal candidate in 2.1, and say which copy of each duplicate pair is live.
- **CONTEXT.md:** Retired candidate (name only), Duplicate folders, Provenance sidecar; fix line 96.
- **`docs/docs-as-code.md`:** the new gate; remove the "v2.3.0" wording.
- **ADRs:** 0013 (provenance sidecar), 0014 (gate as a command); amend 0009 (file promotion, secret naming) and 0010 (duplicate folders, AppDoc-artifact pruning). ADR 0016 (principles) is already written. 2.5 owns 0011 and 0012.

---

## 7. Phase 4 — Measurement, release and examples

### 7.1 Extractor answer keys (accuracy)

1. `eval/answer-keys/<case>.json` for every corpus case and every `tests/samples/<stack>`. Each key lists Facts that must exist and Facts that must not exist (false-positive guards: `MIN_PASSWORD_LENGTH` not secret, `wwwroot` not retired, routes ⇒ capability).
2. `eval/extractor_checks.py` scores precision/recall per stack per kind. `tests/test_eval_extractors.py` fails on any regression from `eval/baseline.json`.
3. Narrative answer keys extend from eShop to flaskr-tdd, gitea and spring-petclinic, enforced by `tools/release.py` (Q10). Baseline: the 2.5.0 examples.
4. `tests/test_scale.py`: a synthetic tree of 10,000 files; `extract` stays within budget, and the content index reads each file once.

### 7.2 Example layout, rotation and the 2.6.0 regeneration (Q16, Q18, Q20)

1. **Layout:** `examples/current/<app>/` and `examples/previous/<app>/`, each with a `VERSION` file. `examples/helpweb/` stays gitignored and is untouched by rotation.
2. **Rotation** (`tools/release.py`, on every release that changes Facts or the template):
   1. Delete `previous`.
   2. Move `current` to `previous`.
   3. Write the new `current`.
   4. Generate `docs/diagnostic-<version>-comparison.md` from the two folders.

   `tests/test_release.py::test_examples_current_and_previous` asserts both exist and `previous/VERSION < current/VERSION`.
3. **First rotation, at 2.6.0 (migration):**
   - `previous` = the four examples 2.5.0 commits, in whatever layout 2.5 uses, with `VERSION 2.5.0`.
   - All older example folders are deleted: the unsuffixed 2.3 baselines and the `*-2.4` runs. They remain in git history and in `docs/diagnostic-2.4-comparison.md` and 2.5's diagnostic.
4. **2.6.0 `current`:** mechanical (Q20). Clean clones at each `target.commit` (assert no `docs/appdoc*`), copy the 2.5.0 Narrative and register, then `extract` and `build`. No new audit. The A.1 provenance line discloses that the generated blocks were regenerated after the audit. A fresh run and fresh audit happen at 2.7.0.
5. **Expected movement vs `previous`:**
   - name-signal-only retired candidates (0 for the four examples), plus `duplicate_folders` pairs;
   - capabilities non-empty;
   - the gitea "not classified" trailer drops `app.example.ini`;
   - the gitea secret-location count falls;
   - no AppDoc output scanned;
   - cross-OS hashes equal.

### 7.3 Versioning

- `facts.SCHEMA = "appdoc-facts/7"`. The changes behind it: typed capabilities, the `generator` removal, `duplicate_folders`, new prunes, file-level promotion, `secret_ref`.
- `TEMPLATE_VERSION = "2.4"`, unchanged.
- **Upgrade notes 2.5 → 2.6:** re-extract (this also writes `provenance.json`); `build`. Expect advisories marked "fails from template 2.7"; they need no action yet. The gate exits 3 ("AppDoc upgraded") until `facts.json` is re-extracted and committed. From 2.6.0 on, an AppDoc patch release with the same schema never trips the gate.
- `CHANGELOG 2.6.0`; then `tools/release.py 2.6.0`.

---

## 8. Order and effort

```
Phase 0  tags (now) 15 min · version_tuple 1 h · provenance sidecar 4 h ·
         determinism harness 6 h · corpus + baselines 4 h                       2 d
Phase 3  appdoc gate + YAML + tests 5 h · gen_docs + test_release + release.py 6 h 1.5 d
Phase 1  capabilities 4 h · prune 2 h · duplicates 5 h · config/secrets 4 h ·
         copy 2 h                                                              2.1 d
Phase 2  C20 + previews of 2.7 rules                                             4 h
Phase 4  answer keys + eval gate + scale test 1 d · rotation migration +
         mechanical regen, diagnostic, release 1 d                              2 d
§4.6     cache salt from the bundle hash, wider determinism harness (B-1, B-2)  0.5 d
                                                                    Total about 8.5 d
```

**Order:**
1. 2.5.0 merged and tagged.
2. Phase 0.
3. Phase 3. The release tests and gate catch drift from everything after them.
4. Phase 1, with 4.1 first, because duplicates and copy tests read capabilities.
5. Phase 2.
6. Phase 4.

---

## 9. Done means

1. Every corpus case is red on `v2.5.0` and green on the release commit; CI is green on ubuntu and windows with Python 3.10 and 3.13; cross-OS artifact hashes are equal.
2. `v2.4.0`, `v2.5.0` and `v2.6.0` tags exist. The gate pins `v2.6.0`, passes an unchanged Target, exits 2/3 correctly, and passes a same-schema patch upgrade.
3. `gen_docs --check` is clean; README, SKILL, docstrings and CHANGELOG agree on version, schema, commands and rules.
4. Extractor precision/recall show no regression from the 2.5.0 baseline and improve on capabilities, duplicate folders, prunes, config promotion and secret naming. Narrative answer keys for the four examples are ≥ the 2.5.0 baseline.
5. `examples/current` (2.6.0) and `examples/previous` (2.5.0) exist, every older example folder is gone, and `docs/diagnostic-2.6.0-comparison.md` shows the movement in 7.2.5.
6. A template-2.4 document that passes 2.5.0 passes 2.6.0 after re-extract and build; every rule that will fail from 2.7 is listed in its report as an advisory.

---

## 10. Optional amendments to the in-flight 2.5.0 (decide before 2.5 releases)

These are proposed, not applied. `docs/remediation-plan-2.5.md` is unchanged. Each one is small, touches no file the 2.5 agent is editing for its own items, and removes a defect 2.5.0 would otherwise ship.

| # | Amendment | Why | If adopted, drop from 2.6 |
|---|---|---|---|
| A1 | 2.5 Phase 3: create the `v2.5.0` tag (and backfill `v2.4.0`) as part of the release | The gate pins `v2.5.0`; without a tag every adopter fails at checkout | 3.0 step 2 |
| A2 | Fix the gate YAML only: clone the skill to `$RUNNER_TEMP/appdoc-skill` and extract with `--out .appdoc-regen` (inside the Target) | Today the gate's extract step always exits 1 and scans the skill folder | Nothing; 6.1 still replaces the YAML logic with `appdoc gate` |
| A3 | Make 2.5's new C15 an advisory instead of a failure | Q2/P2: English noun matching should not fail a document, and a failing C15 shipped in 2.5 will be demoted in 2.7 anyway | Nothing; 2.7 adds markers |

