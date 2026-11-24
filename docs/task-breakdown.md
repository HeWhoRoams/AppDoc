# AppDoc: unfinished plans broken into technical tasks

**Date:** 2026-11-23. **Base:** `origin/main` at `2e59393` (version 2.4.0, schema `/5`, C1–C16, perf and integration work merged, no tag after `v2.0.0`).
**Sources:** `docs/remediation-plan-2.5.md` (rev 2), `-2.6.md` (rev 2), `-2.7.md` (rev 2), `-2.8.md` (rev 4, covers 2.8.0 and 2.9.0), `docs/performance-plan.md` §8 (Phase 5).

**How to read this.** One row per task that one person can finish and review in a sitting. Columns: **ID**; **Task** (what changes); **Where** (files and functions; locate by function name, line numbers have drifted); **Done when** (the failing test that goes green, or the check); **Needs** (task IDs that must land first); **h** (estimate in hours, one engineer, including tests). Until T26.41 lands, every task that changes what a Stack emits for a file also bumps `extract.EXTRACTOR_VERSION` (rule R21); T26.41 deletes the constant and the rule (the cache salt is `version.bundle_hash()`). Every task follows the house rules: test first, failing on the previous tag, stdlib only, Python 3.10+, Windows and Linux.

**Totals (hours), summed bottom-up from the rows below:** 2.5 remainder ≈ 66; 2.6 ≈ 128; 2.7 ≈ 87 (≈ 103 if `appdoc upgrade` ships there, T27.30–32); 2.8 ≈ 175; 2.9 ≈ 59; §0 ≈ 1. About **500 h (roughly 62 working days)**. The plans' own figures (6 + 8.5 + 6.5 + 20 + 7.75 days, about 28 d for 2.8 and 2.9 together, 49 d overall) are lower for 2.5–2.7 because these rows each carry their tests, docs, ADRs and four-example regeneration and audits as separate lines. 2.8 and 2.9 match their plan. Treat the bottom-up figure as the planning number and the plans' figures as the optimistic bound.

---

## Decisions taken 2026-11-23

| Q | Decision | Effect on the tasks |
|---|---|---|
| Q23 | `appdoc upgrade` ships in **2.7.0** | T27.30–32 are in scope; T28.B0 is dropped; 2.7 ≈ 103 h |
| Q24 | Synthetic `mvc5-classic` Target now; real public repository later | T90.03 stays deferred |
| Q31 | Record connection targets: **yes**, behind `Record connection targets: yes` in `appdoc-context.md`, off by default | T28.22 parses the directive; T29.04 builds the matrix |
| Q32 | Remove git author names from `ownership` Facts in **2.6.0** (same schema bump); R18 carried a written exemption naming `ownership` until T26.66 removed it (done: counts and dates only) | new task T26.66 (≈ 4 h) |
| Tag | Tag `v2.4.0` at `9241c2f`; push the tag with the next push to `main` | T00.1 |
| Order | 2.5 → 2.6 → 2.7 → 2.8 → 2.9; the 2.8 `.config` slice is not pulled forward | — |
| Process | Parallel subagent streams in isolated worktrees, merged by the integrator | — |

---

## Revision 2026-11-24 (after 2.7.1)

Release 2.7.1 (tag `v2.7.1`) changed names and rules that the 2.8 rows rely on. This revision refreshes the rows; the plan text in `docs/remediation-plan-2.8.md` is updated to match where it quoted the same names.

**Refreshed references.** `fill.mask_blocks` is `docmodel.mask_blocks` (T28.A0); `check._claim_sha` masking is `fingerprint.claim_sha` and `fingerprint.document_text` (T28.90); `check.py` no longer holds sealing (`seal.py`) or fingerprinting (`fingerprint.py`); the prefix-to-section maps are `template_spec.ID_CLASSES`. `check._uncited_entry_points`, `check._c7_counts` and `check._c7_blocks` still exist under those names. T28.B0 is dropped (Q23 shipped `appdoc upgrade` in 2.7.0).

**Audit plan for the new blocks (settled).**
1. The five new blocks (`access-model` 5.4, `connections` 8.1, `integrations` 8.3, `pipeline` 16.8, `repo-docs` 2.2) are opaque and unaudited, as plan 2.8 §6 says. 2.7.1 prints the unaudited block list in A.1 from `OPAQUE_BLOCKS`, so the new blocks appear there with no extra code; T28.A4 adds the test. Opacity also keeps `doc_sha` and sealed rows stable when 2.9 fills the blocks (`test_seal_survives_block_content_change`).
2. Section 5.3 (role-to-capability matrix) is the one security table in the Narrative. It was outside the 2.7 plan, which sampled 4, 6, 8.1, 8.3, 9 and 15. T28.A5 plans every 5.3 row per row (`5.3/<slug>`), the same way 10.2 is planned.
3. Prose in 5.1 and 5.2 has no rows to key, so it stays outside the plan. This is an accepted residual risk, recorded in ADR 0019 (T28.C1) and mitigated by C21 and C22, which check that the mandatory inputs and every unprotected or unknown handler are cited.
4. Blocks inside planned sections (8.1 and 8.3) need no special handling: audit exclusions are whole-section only, and the block is masked as opaque while the section's C- and X- rows stay planned.

**Weak "done when" cells.** A recount with a correct table parse (the earlier count split on escaped pipes) found 13 rows without a named test or measurable check: T28.00, 01, 02, 03, 04, 05, 23, 25, 73, 77, 94, T28.B0 and T29.04. All now name tests (or, for T28.05, a private-notes check). The other eight rows listed earlier were a parsing error, not weak rows.

**Re-estimates and their basis.** There are no human-hour actuals; the runs were agent-executed. The adjustments use observed overruns.
- **T28.C2 16 → 24 h.** The 2.7.1 delta audit of four examples needed three auditor passes per app because every Narrative edit reseeded the sample (first pass; second pass for the reseeded section 9 rows; third where a pass edited again). The row now carries the ordering that avoids the loop (fix advisories, make all Narrative edits, then audit planned keys and every row of the sampled sections once) and 1.5× the one-pass estimate.
- **4E 20 → 24 h** via a reserved 4 h row (T28.68): 9 of the 42 commits in 2.7 (21%) were unplanned follow-ups (S6.1–S6.5, S7.1–S7.4), and the 2.7.1 review found five spec gaps. The new `guard.py` has the most cross-module logic in 2.8, so 20% is held for defects found by the first real-shaped audit; unspent hours are released.
- **4I 31 → 39 h:** the C2 change (+8). **4H 10 → 11.5 h:** T28.A5 (+1.5). **2.8 total ≈ 160 → ≈ 175 h.** 2.9 is unchanged (≈ 59 h; its audits are mechanical regeneration, T29.20).

**Private-material dependencies.**
| Work | Needs private material? | State here |
|---|---|---|
| All detectors (W1–W13 and the 2.9 readers) | No. The shapes are encoded in plan 2.8 and the invented `mvc5-classic` Target (T28.01, T28.02); the private spike notes are their provenance and are not committed | buildable and testable in the repository |
| T28.04 harness | No (invented toy key) | buildable |
| T28.05 spike re-run | Yes: the real DegreeAudit code shape, private notes | not runnable in this workspace (no DegreeAudit checkout; `$APPDOC_ACCEPTANCE_KEYS` unset; the spike notes file is present locally and stays uncommitted) |
| T28.C3, T29.21 acceptance runs | Yes: DegreeAudit checkout at `33168dd` and the private key | cannot run in this workspace; the owner runs `tools/acceptance.py` locally, or provides the checkout and key |
The residual risk is a detector that matches the invented Target but misses the real shape. The acceptance run is the only guard, so run it at the first-slice release rather than at the end of 2.8.

---

## 0. Do first (independent of everything)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T00.1 | Tag `v2.4.0` at `9241c2f` and push the tag | git | `git ls-remote --tags origin` lists `v2.4.0`; the gate YAML's pin has a target | — | 0.25 |
| T00.2 | **Done 2026-11-23** (see Decisions): Q23 (`appdoc upgrade` in 2.7 or 2.8), Q24 (public MVC example), Q31 (record connection targets?), Q32 (`ownership` author names) | plans | decisions written into the plans' tables | — | 0.5 |
| T00.3 | Confirm `ws1/foundation-standardize-output` is not wanted, or merge it | git | branch deleted or merged | — | 0.5 |

---

## 1. Release 2.5.0 — what is left (plan 2.5 rev 2)

### 1A. Corpus and baselines (Phase 0)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T25.01 | Corpus scaffold: `tests/corpus/<case>/` (a few Target files plus `docs/appdoc/` with Narrative and register), and `tests/test_corpus.py` with one helper that copies a case to a temp dir, runs `extract`, `fill` and `check`, and returns Facts and the Check report | `tests/corpus/`, `tests/test_corpus.py` | a trivial case runs end to end on Windows and Linux | — | 3 |
| T25.02 | Cases for the already-done rules: `unknowns-leak` (C14 twice), `stale-count` (C15), `quantifier-cite` (C16, advisory and `--strict`) | `tests/corpus/*` | cases green (these rules exist; the cases pin them) | T25.01 | 2 |
| T25.03 | Cases for open items: `config-env`, `owner-absent`, `razor-ui`, `ef-data`, `go-conn`, `flask-sa` written to the **new** behaviour | `tests/corpus/*` | all six red on `main` | T25.01 | 3 |
| T25.04 | Verify `tests/test_diag_metrics.py::test_pinned_baseline` still matches `docs/diagnostic-2.4-comparison.md` §1; add the finding to test traceability table (F1–F6) in the plan | `tests/test_diag_metrics.py`, plan §4 | table complete, test green | — | 1 |

### 1B. Owner context (1.4)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T25.10 | New `appdoc/context.py`: parse `appdoc-context.md` once and return all directives (the existing fenced ```` ```never-mention ```` block, `Ownership:` lines). Pure function of file text, no ambient input | `appdoc/context.py`, `citations.OWNER_CONTEXT` | `test_context::test_never_mention_block`, `::test_ownership_lines`, `::test_missing_file_is_empty` | — | 3 |
| T25.11 | Replace `check._never_mention` with a call to `context.py` (same behaviour) | `check._never_mention` | existing never-mention tests green | T25.10 | 1 |
| T25.12 | `extract.extract`: when the file exists emit one `owner_file` Fact and one `ownership` Fact per `Ownership:` line; add the needed keys to `DETAIL_KEYS["ownership"]` (today empty); no personal names in Facts beyond what the existing `ownership` rule already allows | `extract.py`, `facts.DETAIL_KEYS` | `test_core::test_owner_context_detected` | T25.10 | 3 |
| T25.13 | Advisory (not failure) in the gaps-declared rule C4: §11 all `Unknown` and no `owner_file` → "ownership is Unknown by absence"; same for §16.5 Rollback, Backup, Restore | `check.py` (C4) | `test_core::test_owner_absent_advisory`; corpus `owner-absent` green | T25.12 | 3 |

### 1C. Config role split (1.5)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T25.20 | Make the read kind a **per-file** detail: confirm what `config_key.via` carries per stack; if it does not name `os.getenv`, `os.environ`, `os.Getenv`, `os.lookupenv`, `Environment.GetEnvironmentVariable`, `getenv`, add `read_kind` (`env`, `file`) to `DETAIL_KEYS["config_key"]` and emit it from each stack's config-read code | `stacks/*.py`, `facts.DETAIL_KEYS` | per-stack unit tests for `read_kind`; cache stays correct | — | 5 |
| T25.21 | Post-pass split: `unclassified` promoted to `env` (env-var read), `ci` (read from CI/build file paths), `app` (any other code read). Keep it in the post-pass because the cache stores pre-promotion Facts | `extract.extract` post-pass | `test_generic_facts::test_env_key_role_env`, `::test_ci_key_role_ci` | T25.20 | 3 |
| T25.22 | `secret_location` never set on `env` or `ci` keys (kept on `app` and `unclassified`); remove the `GO`/`SSH_ORIGINAL_COMMAND` mis-flags | post-pass | `::test_env_key_not_secret` | T25.21 | 1 |
| T25.23 | `fill._config_reference` trailer: "N env-var keys and M CI keys are excluded from the application table"; `check._c7_counts` compares the 16.6 block with the `app`-role count | `fill.py`, `check.py` | `test_render::test_config_trailer_counts`; corpus `config-env` green | T25.21 | 2 |

### 1D. Extractor coverage (Phase 2)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T25.30 | aspnet_core: emit `ui_page` for `.razor` (`root` = path, `route` = `@page`) beside the existing page entry point (today `ui_page` is XAML only) | `aspnet_core._razor_pages` | `test_razor_ui_page` | T25.03 | 2 |
| T25.31 | aspnet_core: `DbSet<T>` properties → `data_access type=ef operation=set`; `.Where(`, `.ToListAsync(`, `.FirstOrDefaultAsync(`, `ExecuteSqlRaw(` → `operation=query` | `aspnet_core._data_and_calls` | `test_ef_dbset_data_access` | T25.03 | 3 |
| T25.32 | aspnet_core: HttpClient `.SendAsync(`, `.PostAsync(`, `.GetAsync(`, `.GetStringAsync(` → `external_call via=HttpClient` with the URL literal when present | `aspnet_core._data_and_calls` | `test_httpclient_external_call` | T25.03 | 2 |
| T25.33 | Go: `sql.Open(`, `xorm.NewEngine(`, `sqlx.Open(` → `connection`; add `connection` to capabilities | `stacks/go.py` | `test_go_connection` | T25.03 | 2 |
| T25.34 | Go: xorm `RegisterModel(` → `schema_object type=table`; add `schema_object` to capabilities | `stacks/go.py` | `test_go_register_model_schema` | T25.33 | 1.5 |
| T25.35 | Go: count `templates/**/*.html` as `ui_page` (`root` = path, shallow, decision D2); add `ui_page` to capabilities | `stacks/go.py` | `test_go_template_ui_page` | T25.33 | 1.5 |
| T25.36 | Flask: `SQLAlchemy(app)` and `db = SQLAlchemy(...)` → `connection type=sqlalchemy` (keep `create_engine`) | `python_flask._connections` | `test_sqlalchemy_connection`; corpus `flask-sa` | T25.03 | 1.5 |
| T25.37 | Sample files that exercise every new capability (`tests/samples/aspnet-core`, `go`, `python-flask`); extend `test_conformance` to assert sample coverage and `DETAIL_KEYS` subset for each | `tests/samples/*`, `tests/test_conformance.py` | conformance green | T25.30–T25.36 | 3 |
| T25.38 | Per new capability: assert byte-identical `facts.json` for serial, `--workers 2` and warm cache | `tests/test_core.py`, `tests/test_parallel.py` | green | T25.37 | 2 |

### 1E. Release (Phase 3)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T25.40 | Bump `extract.EXTRACTOR_VERSION`; `facts.SCHEMA = "appdoc-facts/6"`; fix every test and fixture that pins `/5` | `extract.py`, `facts.py`, tests | suite green | T25.20–T25.38 | 3 |
| T25.41 | ADRs: new 0011 (register is the single source of truth for unknowns), 0012 (extractor coverage); amend 0009 (config role split by read kind). CONTEXT.md: **Register count**, **Unknown by absence** | `docs/adr/`, `CONTEXT.md` | merged | T25.23 | 3 |
| T25.42 | Regenerate the four public examples with 2.5.0 (clean clone at each recorded commit, `extract`, update Narrative as needed, `build`); confirm no §14 row has an Answerable/Dismissed register row, no "N of M" contradicts the register, 16.6 holds only `app` keys | `examples/*` | `build --require-audit` passes for all four | T25.40 | 8 |
| T25.43 | Append the post-remediation section to `docs/diagnostic-2.4-comparison.md` (Supported %, citations-with-line, §14/register agreement, 16.6 key count); update the pinned metrics | docs, `tests/test_diag_metrics.py` | no regression vs baseline | T25.42 | 2 |
| T25.44 | `CHANGELOG 2.5.0` absorbing `## Unreleased` (perf, integration, cache key); set `__version__ = "2.5.0"`; pin the gate YAML; tag `v2.5.0`; CI green on ubuntu and windows, Python 3.10 and 3.13 | `CHANGELOG.md`, `appdoc/__init__.py`, `ci/appdoc-docs-gate.yml` | tag exists | all of 2.5 | 2 |

**2.5 critical path:** T25.01 → T25.03 → T25.30–36 → T25.37 → T25.40 → T25.42 → T25.44. 1B and 1C run in parallel with 1D.

---
## 2. Release 2.6.0 — tooling and Facts (plan 2.6 rev 2)

Start: set `__version__ = "2.6.0.dev0"`, add `## Unreleased` to the CHANGELOG (T26.01). Schema becomes `/7`; template stays 2.4.

### 2A. Guardrails (Phase 0)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T26.01 | Dev version and CHANGELOG heading | `appdoc/__init__.py`, `CHANGELOG.md` | `test_release::test_changelog_top_heading_matches_version` (added in T26.43) accepts `## Unreleased` with `.dev0` | T25.44 | 0.25 |
| T26.02 | `template_spec.version_tuple(s) -> tuple[int, ...]`; use it for the template gate (document's stamp), C7 version skew and the gate's schema comparison | `template_spec.py`, `check.py` (template gate, C7) | `test_core::test_version_tuple`, `::test_no_string_version_compares` (greps `appdoc/` for `>= "2.`) | T26.01 | 1 |
| T26.03 | `appdoc/version.py`: `__version__`, `bundle_hash()` (moved from `__main__.py`), `provenance() -> dict`; one implementation | `appdoc/version.py`, `__main__.py` | `test_version::test_bundle_single_implementation` | T26.01 | 1.5 |
| T26.04 | `extract` writes `docs/appdoc/provenance.json` `{generator, bundle, schema}`, no timestamps; `facts.json` drops `generator` | `extract.py`, `facts.dumps` | `test_version::test_provenance_written`, `::test_facts_has_no_generator` | T26.03 | 2 |
| T26.05 | `fill` adds `blocks_by` to `provenance.json`; Appendix A.1 prints "Generated blocks written by AppDoc X (bundle …)", plus the "regenerated after the audit" line when the register's `audited_with` differs in major.minor | `fill.py`, register A.1 | `test_register::test_a1_blocks_provenance_line` | T26.04 | 3 |
| T26.06 | `check`: scope line "Run by AppDoc X (bundle …)"; C7 skew reads `provenance.json` (missing → advisory; schema mismatch with `facts.json` → fail) | `check.py` | `test_version::test_check_report_prints_bundle`; `test_check::test_c7_skew_reads_provenance`; corpus `patch-upgrade` | T26.04 | 2 |
| T26.07 | `appdoc/textnorm.py::normalize_text` (CRLF/CR→LF, trailing whitespace per line, final newline, NFC); use it in `claim_sha` and the seal | `textnorm.py`, `citations.py`, `seal` | `test_determinism::test_lf_vs_crlf_equal_seals` | — | 2 |
| T26.08 | `tests/test_determinism.py` parts 1–4: run twice, idempotence (`fill(fill(x))`, `seal` twice, `build` no change, `render` twice), reverse creation order, two absolute paths — over every sample and corpus Target | `tests/test_determinism.py` | green on the current tree (it guards Phase 1) | T26.07 | 4 |
| T26.09 | Same file, R13 ambient-input scan of `appdoc/**/*.py` for `datetime.now`, `date.today`, `time.time`, `getpid`, `uuid`, `random`, `os.environ`; allow-list `APPDOC_CI`; `os.cpu_count` only in the `--workers` default | `tests/test_determinism.py` | red until any offender is fixed or allow-listed, then green | T26.08 | 2 |
| T26.10 | `tools/artifact_hashes.py` (hash of each generated artifact, LF-normalized) and a CI step that uploads it per matrix job; final job fails when hashes differ | `tools/`, `.github/workflows/ci.yml` | CI green on ubuntu and windows | T26.08 | 3 |
| T26.11 | Determinism extras: `--workers 1` vs `2`, and cold vs warm cache, byte-identical | `tests/test_determinism.py` | green | T26.08 | 1.5 |
| T26.12 | Corpus cases `caps-routes`, `dup-twins`, `dup-tests`, `dup-nested`, `prior-output`, `skill-in-target`, `ini-split`, `wide-range`, `patch-upgrade`, `gate-layout`, each red on `v2.5.0` | `tests/corpus/*` | each fails on `v2.5.0` for the stated reason | T25.44 | 4 |
| T26.12a | Two further corpus cases written during 2.6: `owner-present` (an `appdoc-context.md` with `Ownership:` lines and a Narrative: no "Unknown by absence" advisory, the counterpart of `owner-absent`) and `static-assets` (a .NET Target whose `wwwroot` and names such as `copyright`, `holder` and `oldest` must not be retired candidates) | `tests/corpus/owner-present`, `tests/corpus/static-assets` | cases green; `static-assets` is also an extractor answer key (T26.60) | T26.12 | 2 |
| T26.13 | Re-pin `test_diag_metrics` baselines from the committed 2.5.0 examples (retired counts, capabilities `[]`, gitea trailer and secret-location counts, bare-name counts); the 2.4 values were 2/9/40/0, 569 keys, 504/1,013 | `tests/test_diag_metrics.py` | test green on 2.5.0 values | T25.44 | 1 |

### 2B. Extractor capabilities (4.1)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T26.20 | `Stack.capabilities: frozenset = frozenset()` in `stacks/base.py`; move the module-level sets into the seven classes (aspnet, aspnet_core, classic_asp, go, java_spring, node_express, python_flask) including 2.5's new kinds; keep a module alias for one release | `stacks/base.py`, `stacks/*.py` | existing conformance green | T25.40 | 2 |
| T26.21 | Replace `entry_point` with `entry_point.route\|page\|command\|job` derived from each stack's code paths | `stacks/*.py` | `test_conformance::test_entry_point_type_needs_capability` | T26.20 | 3 |
| T26.22 | `stacks.capabilities_of(stack)` as the only lookup; use it in `extract.py` (stack Fact) and `tests/test_conformance.py` | `stacks/__init__.py`, `extract.py`, `tests/test_conformance.py` | `test_supported_stack_declares_capabilities`, `::test_extract_records_capabilities`; corpus `caps-routes` | T26.20 | 2 |
| T26.23 | Conformance: "sample exercises every capability" extended to subtypes | `tests/test_conformance.py`, `tests/samples/*` | green (add sample lines for any subtype not exercised) | T26.21 | 2 |
| T26.24 | `fill._stacks_reporting(doc, cap)` replaces `_stack_capabilities`; 16.7 names stacks with `entry_point.job` or says "No supported Stack reports jobs (…); read the source for job runners" | `fill.py` | `test_render` 16.7 case; corpus `caps-routes` | T26.22 | 2 |

### 2C. Scan, duplicates, pruning, config (4.2–4.5)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T26.30 | `scan._content_index`: one streaming SHA-1 per scanned file (honour `MAX_BYTES`/`skipped`), build `by_hash`; exclude test paths via `facts.is_test_path` | `scan.py` | `test_core::test_content_index_reads_each_file_once`, `::test_duplicates_under_test_paths_ignored` | T26.12 | 3 |
| T26.31 | `retired_candidates` keeps name signals only; add `target.scan.duplicate_folders` `{a, b, files}` (folder with ≥5 non-test files pairs with the folder holding most of its matches at ≥50% of hashes; tie → smallest path; pair stored once with `a < b`; list sorted) | `scan.py` | `::test_retired_name_signal_only`, `::test_duplicate_pair_reported_once`, `::test_duplicate_tie_break_sorted` (fixes NEW-03) | T26.30 | 4 |
| T26.32 | Collapse nested entries in both lists (as the `scan.py` docstring promises) | `scan.py` | `::test_nested_candidates_collapsed` | T26.31 | 1 |
| T26.33 | Render both lists (cap 10 each) with the new headings; the entry-points headline counts name candidates only | `fill.py` | `test_fill::test_scan_coverage_duplicate_heading` | T26.31 | 2 |
| T26.34 | C7: name candidates must be named in §2 (unchanged); a duplicate pair absent from §2 is an advisory, failing under `--strict` | `check.py` | `test_check::test_c7_duplicate_pair_advisory` | T26.33 | 2 |
| T26.35 | `scan.prune_rule`: prune `AppDoc output` (first 4 KiB of `facts.json` has `"schema": "appdoc-facts/`, or of `application-documentation.md` has `<!-- appdoc:template `) and `AppDoc skill bundle` (`run_appdoc.py` + `appdoc/assets/template.md`); record in `target.scan.pruned`; `.appdocignore` `!name` re-includes | `scan.py` | `::test_prune_prior_appdoc_output`, `::test_prune_skill_bundle`, `::test_appdocignore_reincludes_appdoc_output`, `::test_plain_docs_folder_not_pruned`; corpus `prior-output`, `skill-in-target` | T26.12 | 3 |
| T26.36 | Disclose pruned items in 2.1 (generated copy) | `fill.py` | corpus `prior-output` shows the line | T26.35 | 1 |
| T26.37 | File-level promotion in the post-pass: any unclassified key in a file with ≥1 code-read key (matched via `_key_variants`) becomes `app`; never promotes `env`/`ci` | `extract.py` post-pass | `test_generic_facts::test_file_level_promotion`, `::test_ini_section_key_variants` | T25.21 | 3 |
| T26.38 | `secrets.is_secret_key`: tokenize on separators and camel case; secret noun present and no closed-set modifier; `uri`/`path`/`file` set `secret_ref: true` (new `DETAIL_KEYS` entry); closed set in code | `secrets.py`, `facts.DETAIL_KEYS` | `test_core::test_secret_key_segments` (≥20 positive, ≥25 negative incl. gitea's), `::test_secret_ref_flag`; corpus `ini-split` | T26.37 | 4 |
| T26.39 | `fill._config_reference` guard raises if a file is both `app` and "not classified"; test that C6 (`find_secret_shapes`) is unaffected by key naming | `fill.py`, `check.py` | `test_fill::test_config_trailer_never_lists_app_file`, `test_core::test_c6_unaffected_by_key_naming` | T26.37 | 1.5 |
| T26.40 | Generated copy: `fill.plural()` everywhere (no `(s)`), omit "(0 under folders that look retired)", A.4 label `**E-1** (section 1), expect \`path:line\`` | `fill.py`, register | `test_fill::test_generated_copy`, `test_register::test_a4_label_section_and_location` | — | 1.5 |
| T26.41 | **Cache salt from the bundle hash (4.6):** `_cache_key` uses `version.bundle_hash()`; delete `EXTRACTOR_VERSION`, the R21 CHANGELOG instruction and the bump tests (rewrite `test_cache` to bundle-hash form) | `extract.py`, `tests/test_cache.py`, CHANGELOG | cache test: changing bundle content changes the key; R21 text removed from plans/docs | T26.03 | 2 |

### 2D. Advisories, gate, release tooling (Phases 2–3)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T26.50 | **C20** citation precision: a range > `WIDE_RANGE = 100` lines as a claim's only lined citation in §4/§7/§10; > `CELL_CITES = 5` citations in a §4 or §10.1 cell. Advisory, `--strict` fails | `check.py`, `RULE_TITLES` | corpus `wide-range`; unit tests for both thresholds | T26.12 | 3 |
| T26.51 | 2.7-rule previews printed as "fails from template 2.7": C9 severity order, C1 bare-name citations (full path in message), C17 scope text with ID tokens/digits; same functions, gated on the document stamp | `check.py` | `test_check` preview cases; no preview fails a 2.4 document | T26.50 | 4 |
| T26.52 | `appdoc/gate.py` + `gate` subcommand `[--require-audit] [--strict]`: read committed `facts.json` (missing → 1); extract to `<target>/.appdoc-regen/` (excluded from scan, removed in `finally`); schema differs → 3; bytes differ → 2 with ≤200-line diff; else run Check; version difference informational | `gate.py`, `__main__.py` | `test_gate` 0/2/3; patch-only provenance change → 0; regen folder removed; corpus `gate-layout`, `patch-upgrade` | T26.04, T26.35 | 6 |
| T26.53 | `test_gate`: skill folder inside the Target → 0 (`--no-cache` where needed); rewrite `ci/appdoc-docs-gate.yml` to clone to `$RUNNER_TEMP/appdoc-skill` and call `gate` from there; test asserts this | `ci/appdoc-docs-gate.yml`, `tests/test_gate.py` | green | T26.52 | 2 |
| T26.54 | AppDoc's own CI: add gate self-test on a temp copy of `tests/samples/java-spring`, the cross-OS hash job, `test_release`, extractor eval | `.github/workflows/ci.yml` | CI green | T26.10, T26.52 | 2 |
| T26.55 | `tools/gen_docs.py` writing `<!-- appdoc-self:generated NAME -->` blocks: README `commands` (from `build_parser()`), `rules` (`RULE_TITLES`/`RULE_SUMMARIES` with advisory/strict/"fails from 2.7" flags), `facts-schema`; SKILL.md `run-commands` (from `workflow.SKILL_STEPS`); gate YAML header and pin; test that `__main__`/`check.py` docstrings use the same constants | `tools/gen_docs.py`, README, SKILL.md | `gen_docs --check` clean | T26.50, T26.52 | 6 |
| T26.56 | `tests/test_release.py`: `test_generated_docs_current`, `test_changelog_top_heading_matches_version`, `test_gate_pin_matches_version` (release versions), `test_release_script_dry_run`, `test_examples_current_and_previous` | `tests/test_release.py` | green | T26.55, T26.61 | 2 |
| T26.57 | `tools/release.py VERSION [--dry-run]`: clean tree on `main`; set version, rename `## Unreleased`, run `gen_docs`; run tests, determinism job, extractor eval, narrative eval (`APPDOC_EVAL_ROOT`; refuse on regression); rotate examples; commit and tag; print push command; follow-up commit `X.Y.(Z+1).dev0` | `tools/release.py` | dry-run test green | T26.55, T26.60, T26.61 | 6 |

### 2E. Docs, measurement, examples, release

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T26.58 | Hand-written docs: SKILL.md Run steps (extract, orient, write, build until pass (3 failures → report verbatim), audit in a fresh agent, build, report incl. A.1 line; name each name-signal candidate in 2.1; say which copy of each duplicate pair is live); CONTEXT.md terms (Retired candidate, Duplicate folders, Provenance sidecar; fix line 96); `docs/docs-as-code.md` (new gate, drop "v2.3.0") | docs | `test_release` generated-docs check still green | T26.55 | 3 |
| T26.59 | ADRs 0013 (provenance sidecar), 0014 (gate as a command); amend 0009 (file promotion, secret naming), 0010 (duplicate folders, AppDoc-artifact pruning) | `docs/adr/` | merged | T26.52 | 2 |
| T26.60 | Extractor answer keys: `eval/answer-keys/<case>.json` for every corpus case and `tests/samples/<stack>` (must-exist and must-not-exist Facts, e.g. `MIN_PASSWORD_LENGTH` not secret, `wwwroot` not retired, routes ⇒ capability); `eval/extractor_checks.py` precision/recall per stack per kind; `eval/baseline.json`; `tests/test_eval_extractors.py` fails on regression | `eval/`, `tests/` | green | T26.24, T26.38 | 8 |
| T26.61 | Narrative answer keys extended from eShop to flaskr-tdd, gitea, spring-petclinic; enforced by `release.py`; baseline = 2.5.0 examples | `eval/answer-keys/` | eval runs locally against clones | T26.60 | 4 |
| T26.62 | `tests/test_scale.py`: 10,000-file synthetic tree within time budget; content index reads each file once | `tests/test_scale.py` | green on both OSes | T26.30 | 2 |
| T26.63 | Example layout migration: `examples/current/<app>/` and `examples/previous/<app>/` with `VERSION`; previous = 2.5.0 examples; delete older folders (unsuffixed 2.3, `*-2.4`); `examples/helpweb/` stays gitignored | `examples/` | `test_release::test_examples_current_and_previous` | T26.57 | 2 |
| T26.64 | Mechanical regeneration of `current` (clean clone at each `target.commit`, assert no `docs/appdoc*`, copy 2.5.0 Narrative and register, `extract`, `build`); A.1 discloses regeneration after the audit; generate `docs/diagnostic-2.6.0-comparison.md`; confirm expected movement (name-only retired 0, duplicate pairs, capabilities non-empty, gitea trailer drops `app.example.ini`, secret-location count falls, no AppDoc output scanned, cross-OS hashes equal) | `examples/`, docs | `build` passes for all four | T26.63, all Phase 1 | 8 |
| T26.66 | Remove git author names from `ownership` Facts (keep counts and dates); update R18 text, `facts.DETAIL_KEYS["ownership"]`, summary, examples | `extract.py`, `facts.py`, docs | `test_core::test_ownership_has_no_author_names` | T26.20 | 4 |
| T26.65 | `facts.SCHEMA = "appdoc-facts/7"`; fix pinned `/6` tests; `CHANGELOG 2.6.0` with upgrade notes (re-extract; expect "fails from template 2.7" advisories; gate exits 3 until `facts.json` re-extracted); run `tools/release.py 2.6.0`; tag | `facts.py`, CHANGELOG | tag exists, CI green | all of 2.6 | 2 |

**2.6 critical path:** T26.03 → T26.04 → T26.52 → T26.55 → T26.57 → T26.63 → T26.64 → T26.65. Streams that run in parallel after T26.12: capabilities (2B), scan and config (2C), C20 (T26.50).

---
## 3. Release 2.7.0 — template 2.7 (plan 2.7 rev 2)

Schema stays `/7` unless a task changes Facts output (none planned; if one does, `/8` and 2.8 renumbers). Template becomes 2.7. Audit-question rows are named AQ5/AQ6 (amendment C-1).

**Status (2026-11-24).** 2.7.0 is complete (tag `v2.7.0` at `cf10eb5`, local). The two-axis review of 2.7.0 was remediated as release 2.7.1 (branch `impl/2.7.1`, `docs/` plan: `AppDoc-2.7-Code-Review-Remediation-Plan-2026-11-24`): per-row audit keys and C19 coverage, the A.1 not-audited line, one-command section 17, the seven standards refactors, ADR 0015 amendments, and an independent delta audit of the four examples. T27.42 to T27.44 are done.

### 3A. Register history and provenance (3.1)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T27.01 | `register.OPTIONAL_KEYS`: `supersedes` (id or list) and `sealed_by` (`audit`\|`upgrade`); parse and validate | `register.py` | `test_register::test_supersedes_parsed` | T26.65 | 2 |
| T27.02 | Audit record (line 1) fields on 2.7: `audited_on`, `audited_with`, `audited_bundle`, `doc_sha` (12-hex SHA-1 of `normalize_text` of the Narrative with generated blocks and count markers masked and comments stripped — the same text C11 uses; share one helper, R5) | `register.py`, `check.py` | `test_core::test_doc_sha_matches_c11_text` | T27.01 | 3 |
| T27.03 | C11 live-row duplicate rule: only live rows counted; two live rows on one ref fail with the `supersedes` fix text; a `supersedes` target must exist, share `ref`, no cycle; seals, anchors, `locate`, coverage use live rows; superseded rows still fully validated | `check.py` (C11) | `test_check::test_c11_two_live_rows_fail_with_supersedes_fix`, `::test_c11_supersedes_unknown_or_cycle_fails`; corpus `superseded` | T27.01 | 4 |
| T27.04 | `appdoc seal --audit --date YYYY-MM-DD` (`--date` required): writes line-1 provenance, seals unsealed rows `sealed_by: audit`; plain `seal`/`build` seals `audit` only when `doc_sha` matches, else `upgrade` | `__main__.py`, `seal` | `test_core::test_seal_audit_requires_date`, `::test_seal_marks_upgrade_without_matching_doc_sha`; corpus `upgrade-seal` | T27.02 | 3 |
| T27.05 | Appendix A (generated): A.1 audit-provenance line and "N rows were sealed at upgrade…"; A.2 `{total} rows ({superseded} superseded)…`; A.3 marks `superseded by E-n`; A.4 skips superseded | `register.py` appendix render | `test_register::test_a1_audit_provenance_line`, `::test_a1_upgrade_sealed_note`, `::test_superseded_rows_counted_separately`, `::test_a3_marks_superseded`, `::test_a4_skips_superseded` | T27.03, T27.04 | 3 |
| T27.06 | **C17 provenance:** `--require-audit` needs the line-1 fields; `--require-audit --strict` fails on any `sealed_by: upgrade` row | `check.py` | `test_check::test_c17_require_audit_needs_provenance`, `::test_c17_strict_fails_on_upgrade_seal` | T27.04 | 2 |
| T27.07 | C14 reads live rows | `check.py` (C14) | `test_check::test_c14_uses_live_rows` | T27.03 | 1 |

### 3B. Notes, scope, plan, counts (3.2–3.5)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T27.10 | Block registry: add `closed-questions` (key `"14"`) to `template_spec.GENERATED` **and** `OPAQUE_BLOCKS` (amendment C-2) | `template_spec.py` | `test_check::test_closed_questions_is_opaque` | T26.65 | 1 |
| T27.11 | `docs/appdoc/notes.jsonl` reader; `fill` renders `Known extractor limitation: <text> (<cites>)` inside the block after generated rows; `build` fills an empty `block_sha` with the hash of the block's generated body (notes excluded), never overwrites | `notes.py` (new), `fill.py`, `__main__.py` | `test_fill::test_notes_rendered_in_block`; `test_check::test_c18_build_seals_empty_sha` | T27.10 | 4 |
| T27.12 | **C18:** unknown block fails; stale `block_sha` fails with the fix text; note cites resolve (C1); reserved label in hand-written Narrative outside a block fails | `check.py` | `test_check::test_c18_stale_note_fails`, `::test_c18_unknown_block_fails`, `::test_c18_label_in_prose_fails`; corpus `note-stale`, `label-in-prose`; `test_determinism::test_notes_seal_idempotent` | T27.11 | 3 |
| T27.13 | Computed scope: A.1 prints the coverage line from `coverage(...)` and the audit plan; **C17 scope** — `scope` may not contain an ID token (`_ID_REF_RE`) or digits; `exclusions` `{section: reason}` with the same token rule, printed verbatim | `check.py`, `register.py` | `test_check::test_c17_scope_ids_fail`, `::test_c17_scope_digits_fail`, `::test_c17_method_only_passes`, `::test_c17_exclusions_keys_are_sections`; `test_register::test_a1_computed_scope_line`; corpus `scope-ids` | T27.05 | 3 |
| T27.14 | `appdoc audit-plan <target>` → `docs/appdoc/audit-plan.json`: full coverage (V-IDs, §7 workflows, Q-IDs, finding candidates, 10.2 Present controls, non-Unknown 16.5/§17 rows); sampled sections 4, 6, 8.1, 8.3, 9, 15 with `k = min(n, max(5, ceil(0.25·n)))` chosen by `sha1(doc_sha + id)`; `Audit floor:` override only when stricter (looser → advisory) | `audit_plan.py` (new), `__main__.py`, `context.py` | `test_core::test_audit_plan_deterministic`, `::test_audit_plan_changes_with_doc`, `::test_audit_plan_floor_math`, `::test_audit_floor_override_only_raises` | T27.02, T25.10 | 5 |
| T27.15 | **C19:** plan equals a fresh computation; every planned ID has a live row; exclusions printed; A.2 shows planned / audited / extra per section | `check.py`, `register.py` | `test_check::test_c19_missing_planned_row_fails`, `::test_c19_stale_plan_fails`, `::test_c19_exclusion_printed`; corpus `audit-plan` | T27.14 | 3 |
| T27.16 | Count-marker classes as **one constant** in `template_spec` (`V F UI C X Q R`, `rows superseded`, `routes jobs pages commands config-keys`), extensible by 2.8 (amendment C-3) | `template_spec.py` | unit test lists the constant | T26.65 | 1 |
| T27.17 | `fill` writes marker `N` from Facts via `fill.entry_point_counts` and the config reference; idempotent | `fill.py` | `test_fill::test_count_marker_filled`, `::test_count_marker_idempotent` | T27.16 | 3 |
| T27.18 | **C15 on 2.7:** stale marker fails; unknown class fails; hand-written "N of M <noun>" becomes an advisory "use a count marker" (record the R2 exception in ADR 0017) | `check.py` (C15) | `test_check::test_c15_stale_marker_fails`, `::test_c15_unknown_class_fails`, `::test_c15_handwritten_count_advisory` | T27.17 | 3 |

### 3C. Rule items and template (3.6–3.9)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T27.20 | `SEVERITY_ORDER`; C9 fails an out-of-order §10.1 or §15 row from template 2.7 (same function as the 2.6 preview) | `template_spec.py`, `check.py` | `test_check::test_c9_10_1_severity_order`, `::test_c9_15_severity_order`; corpus `severity-order` | T26.51 | 1.5 |
| T27.21 | C1 bare-name rule enforced on 2.7 with the full path in the message; same for register and note cites | `check.py` | `test_check::test_c1_bare_name_fails_on_2_7`, `::test_c1_root_and_known_bare_allowed`; corpus `bare-cite` | T26.51 | 1.5 |
| T27.22 | `appdoc build --expand-citations`: rewrite unique bare names outside fences and generated blocks; deterministic, idempotent | `__main__.py`, `citations.py` | `test_core::test_expand_citations_unique_only`, `::test_expand_citations_idempotent` | T27.21 | 3 |
| T27.23 | `closed-questions` block under §14 (rendered by `fill`); Answerable rows require `answered_in`; A.2 lists missing E-IDs | `fill.py`, `check.py`, `register.py` | `test_fill::test_closed_questions_block`; `test_check::test_c11_answerable_needs_answered_in`; `test_register::test_a2_lists_missing_ids` | T27.10, T27.03 | 3 |
| T27.24 | §17 Build, Run and Test Locally: add to `SECTIONS`, `REQUIRED_ROWS["17"]` (5 steps); C9 accepts only a backticked command, `Unknown - see Open questions.`, or `Not applicable`; non-Unknown rows need a lined Citation | `template_spec.py`, `check.py`, `assets/template.md` | `test_check::test_c9_section_17_rows`, `::test_c9_17_not_applicable_needs_citation`, `::test_template_2_7_sections` | T26.65 | 4 |
| T27.25 | C17 scope text, C9 severity and C1 bare-name **gates** flip from preview to failure keyed on the document stamp (no new logic) | `check.py` | 2.4 document still passes; 2.7 fails | T27.20, T27.21, T27.13 | 1 |
| T27.26 | `TEMPLATE_VERSION = "2.7"`; CONVENTIONS text (handles, count markers, notes, reserved labels, §17 status values) | `template_spec.py`, template | `test_core` template-version tests | T27.24 | 1.5 |

### 3D. `appdoc upgrade` (accepted as Q23, ships in 2.7.0)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T27.30 | `template_spec.UPGRADE_STEPS[version]`: machine-readable operations (add block markers at a `GENERATED` position, add headings with `appdoc:guide`, add required-row skeletons with `Unknown - see Open questions.`, rename headers); supply 2.4→2.7 including the 2.2→2.4 renames | `template_spec.py` | `test_core::test_upgrade_step_table_covers_every_version` | T27.26 | 4 |
| T27.31 | `appdoc upgrade <target>`: infer version (no stamp: 2.1 if it has the 2.1 subsections, else 2.0), apply steps, re-run `extract` and `fill`, never delete Narrative (unmappable text under an `appdoc:upgrade-orphan` comment that C3 fails on), never write `evidence.jsonl`/`notes.jsonl`/`audit-plan.json` | `upgrade.py` (new), `__main__.py` | `::test_upgrade_2_1_to_current_mechanical`, `::test_upgrade_2_0_adds_2_1_subsections`, `::test_upgrade_idempotent`, `::test_upgrade_never_drops_text`, `::test_upgrade_never_touches_register` | T27.30 | 8 |
| T27.32 | Write `docs/appdoc/UPGRADE-TODO.md` listing non-mechanical steps (convert `verification.md`, register rows for finding candidates, count markers) with the failing rule per item; corpus `upgrade-2-1`, `upgrade-2-6-to-2-7` | `upgrade.py`, `tests/corpus/` | `::test_upgrade_todo_lists_failing_rules` | T27.31 | 4 |

### 3E. Docs, examples, release

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T27.40 | SKILL.md: Run steps (…, **audit-plan**, audit every planned ID in a fresh agent, `seal --audit --date`, build) and writing rules (counts only via markers; limitations in `notes.jsonl`; severity order; full paths; `answered_in`; never delete rows, use `supersedes`; scope = method only; fill §17); state that generated/opaque blocks are not audited (amendment C-4); regenerate via `gen_docs` | SKILL.md, `workflow.SKILL_STEPS` | `test_release::test_generated_docs_current` | T27.15, T27.26 | 3 |
| T27.41 | CONTEXT.md (Superseded row, Seal provenance, Note, Audit plan, Count marker); ADR 0015, ADR 0017; amend 0007 | docs | merged | T27.18 | 3 |
| T27.42 | Fresh run (not upgrade) of each of the four examples from a clean clone at the recorded commit: template 2.7, write Narrative, `build`, `audit-plan`, independent audit in a fresh agent, `seal --audit --date`, `build`; per-app items: eShop chatbot PII flow (AQ5) as a V-finding or a 10.2 control row, gitea says which duplicate copy is live, flaskr and gitea ordered by severity | `examples/current/*` | `build --require-audit --strict` passes | T27.40 | 16 |
| T27.43 | Determinism proof on Windows and Linux; `docs/diagnostic-2.7.0-comparison.md` (planned vs audited per section, superseded/upgrade-sealed counts, markers, bare names 0, severity order, §17 fill rate, answer-key scores, extractor P/R) | `docs/` | hashes equal across OSes | T27.42 | 3 |
| T27.44 | `CHANGELOG 2.7.0` with the 8-step upgrade notes; `tools/release.py 2.7.0` (rotation: 2.6.0 → `previous`); tag | CHANGELOG | tag exists, CI green | T27.43 | 2 |

**2.7 critical path:** T27.01 → T27.02 → T27.04 → T27.14 → T27.15 → T27.40 → T27.42 → T27.44. Count markers (T27.16–18) and notes (T27.10–12) are parallel to the register chain.

---
## 4. Release 2.8.0 — security and access, template 2.8 (plan 2.8 rev 4)

Schema = the next after 2.7's (expected `/8`; re-check at start). Template 2.8. Rules R16–R21 apply. Every new Fact kind goes in `facts.KINDS` **and** `facts.DETAIL_KEYS`; detail values are scalars or sorted lists (`Fact.make` rejects dicts). Raw Facts are emitted per file; joins happen only in post-passes (the cache stores pre-promotion Facts). The `.config` reader is shared by `aspnet` and `aspnet_core`. Confidentiality: committed tests use invented names only; DegreeAudit specifics stay in the private key.

**First slice (patch release, ≈ 9 d / 72 h of this section):** Phase 0 minimal + 4A + 4B + 4C (W13, W1, W2) + 4D (W3) + T28.A0 (C21). It ships settings, rules, guards, route fidelity and the mandatory-input check; W4, patterns and blocks follow.

### 4A. Phase 0 — corpus, targets, harness (12 h) and spike re-run (2 h)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T28.00 | Shared-Target helper in `tests/test_corpus.py` (`_targets/<name>` + overlays `+owin`, `+core`, `+webapi`; copies only the overlay delta) | `tests/test_corpus.py` | `test_corpus::test_shared_target_overlay_copies_only_delta` (the `+owin` overlay holds the base files plus only its delta; the base is unchanged); a case runs against `mvc5-classic+owin` | T27.44 | 2 |
| T28.01 | `mvc5-classic` Target, part 1 (code): areas in three `RouteArea` styles plus conventional registration; one unguarded writing area, one `<location>` role-gated area, one class-level `[AllowAnonymous]`, one controller whose namespace names another area; external guard attribute with 5/4 positional arguments (incl. a credential constant) stacked with `[Authorize]`; `HasRole(user, roleA, groupB)` helper; non-guard external attribute used ≥3 times; `#if DEBUG/STAGING` mode constant; `BaseController` deriving from an external base. **Invented names only** | `tests/corpus/_targets/mvc5-classic/` | `test_corpus::test_invented_target_uses_invented_names`: every namespace starts with `Contoso.`, and no file contains a token from `$APPDOC_ACCEPTANCE_KEYS/denylist.txt` (skipped when unset, so it is a local check); reviewer sign-off in the commit message | T28.00 | 3 |
| T28.02 | `mvc5-classic` Target, part 2 (config): BOM `Web.config` with `authentication mode="Windows"`, root authorization, 15 `<location>` blocks in the shapes listed in plan §4.2, literal `machineKey`, `customErrors Off`, `compilation debug`, duplicate key, 7 identifier-list keys, expiry-year key, connection string with literal credentials; `Web.Debug/Staging/Release/Odd.config`; `Areas/Reports/Web.config`; csproj with per-configuration `DefineConstants`; `*.pubxml` and `*.pubxml.user`; WinForms `WinExe`, Core web `Exe`, test project; `fixtures/` and `tests/powershell/fixtures/` decoys; tooling `package.json` | same | `test_corpus::test_invented_target_config_parses`: `dotnetcfg` reads every config file with 0 `config_unparsed` except the deliberately malformed `Web.Odd.config` (exactly 1, reason `malformed`); 15 `<location>` blocks, 4 transform files and the `*.pubxml.user` skip are asserted | T28.01 | 4 |
| T28.03 | Corpus cases for the 2.8 list (`webconfig-security` … `upgrade-2-1`), written to the **new** behaviour; all red on the 2.7 tag | `tests/corpus/*` | `test_corpus::test_new_cases_fail_on_2_7_1_for_their_stated_reason`: each new case's expected file names the missing Fact kind or Check problem id; against `v2.7.1` every case fails with exactly that reason and no other (a crash fails the harness) | T28.02 | 2 |
| T28.04 | `tools/acceptance.py` (stdlib, private, not in CI): reads `$APPDOC_ACCEPTANCE_KEYS/<target>.json`, asserts on Facts and Check output only; document `APPDOC_ACCEPTANCE_KEYS` with the other switches (R13) | `tools/acceptance.py` | `test_acceptance::test_toy_key_all_rows_pass` and `::test_missing_key_exits_1_with_message`; `python tools/acceptance.py --key tests/acceptance/toy-key.json --target tests/corpus/_targets/mvc5-classic` prints one line per row and exits 0 (the toy key is invented and committed) | T28.03 | 1 |
| T28.05 | Spike re-run for any detector whose spec changed since rev 4 (private notes only) | private | private notes gain one line per re-run detector (`matches` or `redesigned`, date); `git status` shows no private file in any repository and no private specific in a commit | T28.01 | 2 |

### 4B. W6 / W5 — classification and route fidelity (8 h)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T28.10 | `aspnet_core.detect_in` (project-based): `Sdk="Microsoft.NET.Sdk.Web"`/`.Razor`, `Microsoft.AspNetCore.*` package or framework reference; `.csproj` + `Program.cs` no longer qualifies; classic markers → `aspnet` | `stacks/aspnet_core.py` | `test_facts_aspnet_core::test_no_core_without_web_sdk`; corpus `core-false-positive` | T28.02 | 1.5 |
| T28.11 | Drop markers under test paths and inside test projects (`Microsoft.NET.Test.Sdk`/`MSTest.TestFramework`/`xunit`/`NUnit`) in every `detect()`; record `ignored_markers`, returned explicitly (no state on `self`) | `stacks/*.py`, `stacks/__init__.py` | `::test_test_path_markers_ignored`, `::test_fixture_markers_outside_tests_ignored`, `::test_marker_in_test_project_ignored` | T28.10 | 1 |
| T28.12 | Regression only: tooling manifest with type-definition dev dependencies yields no `node-express` stack (`node_express.detect_in` already requires `express` declared and used); widen to fastify, koa, hapi if cheap | `tests/test_facts_node_express.py` | `::test_no_express_from_tooling_manifest` | — | 0.5 |
| T28.13 | `aspnet._handlers`: Web Forms handlers only for code-behind of `.aspx/.ascx/.master` or classes deriving `Page`/`UserControl`/`MasterPage`; a `Controller`-named class needs `using System.Web.Mvc\|Microsoft.AspNetCore.Mvc` or a resolvable base; disclose that VB classes are not parsed | `stacks/aspnet.py` | `test_facts_aspnet::test_winforms_handlers_not_entry_points` | T28.02 | 1 |
| T28.14 | Desktop rule: `WinExe`, or `Exe` + `Form`/`Window` subclass + no web SDK; forms → `ui_page type=form`; one `entry_point type=desktop` from `static void Main`; Core web `Exe` is not desktop; `entry_point.desktop` capability | `stacks/aspnet.py` | corpus `winforms-handlers` | T28.13 | 1 |
| T28.15 | `[RouteArea]` three shapes (positional + `AreaPrefix`; prefix only; empty name and prefix = root, no `area_path`), spacing variants; conventional area routes from the `AreaRegistration` `url:` literal; folder beats namespace | `stacks/aspnet.py` `_controller_actions`, `_route_tables` | `test_facts_aspnet::test_routearea_prefix_applied`, `::test_routearea_prefix_only`, `::test_routearea_empty_is_root`, `::test_area_url_from_registration_literal`, `::test_area_from_folder_not_namespace` | T28.02 | 1.5 |
| T28.16 | Normalise `[RoutePrefix]`, `[Route("~/x")]` (tilde overrides), optional/constrained params; any `[Route]` excludes conventional reach; `[ActionName]`; emit `mvc_area`, `mvc_area_path` on every MVC `entry_point`; collapse exact duplicates | same | `::test_tilde_route_ignores_prefix`, `::test_attribute_route_excludes_conventional`, `::test_actionname_rename`, `::test_duplicate_route_collapsed`; corpus `route-area` | T28.15 | 1.5 |

### 4C. W13 / W1 / W2 — shared config reader, settings, transforms, rules

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T28.20 | New kinds (`security_setting`, `access_rule`, `config_transform`, `config_external`, `config_unparsed`, `guard_class`, `guard_use`, `const_def`, `project`, `build_define`, `publish_profile`, `context_directive`, `guard_candidate`, …) in `KINDS` and `DETAIL_KEYS`; `GENERIC_KINDS` in conformance; dict detail rejected | `facts.py`, `tests/test_conformance.py` | `test_facts::test_dict_detail_rejected`; conformance green | T27.44 | 0.5 |
| T28.21 | `appdoc/dotnetcfg.py`: bytes into `xml.parsers.expat` (`namespace_separator=" "`), BOM and declaration honoured, start-tag `CurrentLineNumber`; reject `<!DOCTYPE`/`<!ENTITY` (`config_unparsed reason=dtd`); size caps 2 MiB/8 MiB and depth cap; malformed → one `config_unparsed`, no partial tree; strip legacy `xmlns`; XDT matched by namespace URI (http and https), not prefix; comments/CDATA never elements; case-insensitive file names; per-attribute closed enumerations | `appdoc/dotnetcfg.py` | `test_dotnetcfg::test_doctype_rejected`, `::test_entity_bomb_not_expanded`, `::test_oversize_skipped_with_reason`, `::test_line_number_of_multiline_start_tag`, `::test_commented_rule_not_a_fact`, `::test_line_numbers_survive_crlf_and_bom`, `::test_namespaced_config_read`, `::test_xdt_namespace_not_prefix`, `::test_filename_case_insensitive`, `::test_malformed_gives_one_unparsed` | T28.20 | 2.5 |
| T28.22 | Extend `appdoc/context.py` (from T25.10) with `Auth attributes:`, `Production config:`, `Reference year:`, `Record connection targets:` (if Q31), and the `Audit floor:` directive 2.7 added; emit `context_directive` Facts before the post-pass; unmatched directive → disclosed `context_unmatched`, not an error | `context.py`, `extract.py` | `test_context::test_directives_parsed_once`, `::test_unmatched_directive_disclosed` | T25.10, T28.20 | 1 |
| T28.23 | Raw per-file Facts in `aspnet`/`aspnet_core`: `controller_class` + `entry_point.inherits` (base list, `base_external`), `auth_check mechanism=global-filter` (`filters.Add`, `GlobalFilters.Filters.Add`, Web API `config.Filters.Add`), `method_call` for promoted helpers | `stacks/aspnet.py`, `stacks/aspnet_core.py` | `test_facts_aspnet::test_controller_class_inherits_base_external`, `::test_global_filter_auth_check`, `::test_promoted_helper_method_call`; `test_parallel::test_aspnet_raw_facts_serial_equals_pool`; `test_core::test_raw_facts_warm_equals_cold` | T28.20 | 2 |
| T28.24 | `generic._csproj` emits `project` (path, `output_type`, `sdk`, kind web/winforms/console/test/library, test and web flags), `build_define` (per-configuration `DefineConstants`, `inherits`), `publish_profile` (name, `build_config`, method, **host only**; `*.pubxml.user` never read) | `stacks/generic.py` | corpus `build-defines`, `publish-profile` | T28.20, T28.21 | 1 |
| T28.25 | `aspnet.detect_in(paths, root)` so a Web.config-only or Web API-only classic project is detected; detect state returned explicitly (process pool safe) | `stacks/aspnet.py` | `test_facts_aspnet::test_detect_in_webconfig_only_project`, `::test_detect_in_webapi_only_project`, `::test_detect_in_keeps_no_state_between_calls` (two interleaved targets give the results of two separate runs) | T28.11, T28.21 | 1 |
| T28.30 | `security_setting` over the closed element set (authentication, forms, machineKey, customErrors, compilation, httpCookies, sessionState, trace, httpRuntime, identity, httpErrors, smtp password, processModel); missing element = `value: absent`; `machineKey` class (`autogenerate\|literal_hex\|placeholder\|absent_keys\|other`), no value ever recorded | `stacks/aspnet.py` (calls `dotnetcfg`) | `test_system_web_settings`, `::test_machinekey_classes`, `::test_machinekey_literal_no_value`, `::test_missing_element_is_absent_not_default`; corpus `webconfig-security` | T28.21 | 3 |
| T28.31 | Credential carriers: `secret_location: true` with no value; connection strings with literal `Password=`/`User ID=` counted per file (base and transform files); `clientCredentials` | same | `::test_secret_carriers_no_value`; corpus `secrets-never-recorded` | T28.30 | 1.5 |
| T28.32 | `config_external` for `configSource` and `appSettings file=`: read when inside the Target and relative, else `unknown_external`; external wins over inline (suppresses `duplicate-config-key`) | same | `::test_config_source_resolved`, `::test_external_outside_target_unknown` | T28.30 | 1.5 |
| T28.33 | Configurations set (R17): transform file names, csproj `Condition="'$(Configuration)\|$(Platform)'==…"` groups, sln `SolutionConfigurationPlatforms`; production config defaults to Release (overridable by `Production config:`); no-transform configuration = `base` | `appdoc/configs.py` (new) or `dotnetcfg.py` | `::test_configurations_from_transforms_csproj_sln` | T28.24, T28.30 | 2 |
| T28.34 | Transform engine for supported operations: `Replace` and `Remove` first match, `RemoveAll` all, `RemoveAttributes`, `SetAttributes` with and without attribute list, `Insert` appended after existing siblings; locator-less transform targets the same path | `dotnetcfg.py` / post-pass | `::test_transform_release_sets_customerrors`, `::test_transform_remove_debug`, `::test_setattributes_no_arglist`, `::test_removeall_no_locator`, `::test_insert_appends_after_existing_rules`, `::test_replace_first_match_only`; corpus `xdt-effective` | T28.33 | 2.5 |
| T28.35 | Unsupported transforms → `unknown_transform` (`InsertBefore/After`, `InsertIfMissing`, locators other than none, `Match(a,b)`, compound `Condition`, any `XPath`) and everything derived is unknown for that configuration; `ProjectConfigTransformFileName` → lookup unknown; nested `Web.config` gets no transform; "effective on publish or package only" | same | `::test_unsupported_transform_makes_effective_unknown`, `::test_insertbefore_after_unknown`; `Web.Odd.config` case | T28.34 | 1.5 |
| T28.36 | `overridden_in: [configs]` (no values) on base `config_key`/`connection` for every `Match(key)`/`Match(name)` target | same | `::test_overridden_in_recorded` | T28.34 | 1 |
| T28.37 | WCF client endpoints → `external_call type=service via=<contract> config_key=<endpoint>`; address as `scheme://host[:port]` only | same | `::test_wcf_endpoint_no_userinfo` | T28.30 | 1.5 |
| T28.38 | `host_auth` (`iis_anonymous: unknown\|enabled\|disabled`, `source: none\|config\|csproj_dev_only`), `owin_auth` (packages or `Use*Authentication`), `iis_authorization_present`; csproj IIS Express values never used for reach | same | corpus `windows-auth-iis`, `owin-none` | T28.30 | 1.5 |
| T28.40 | `access_rule` per `<allow>/<deny>/<clear/>/<remove>`: `scope_path`, `effect`, `order`, `verbs`, `roles`, `anon`/`all` flags, `users_named` (count, deduped case-insensitively), `config`, `config_status`, `allow_override`, `inherit_in_child_apps` | `stacks/aspnet.py` | `test_location_rules`, `::test_rule_order_recorded`, `::test_verbs_recorded`, `::test_clear_and_remove_recorded`, `::test_users_flags_set`, `::test_root_rule_transformed` | T28.35 | 2.5 |
| T28.41 | `location@path` forms (`.`, empty, absent, `~/`, case, segment boundary, folder/file/route-like); nested `Web.config` applies to URLs by prefix, `Areas/X/Web.config` does not apply to the routed area URL | same | corpus `location-paths`, `nested-webconfig` | T28.40 | 2 |
| T28.42 | `allowOverride="false"` → `unknown` if a nested rule exists below; `inheritInChildApplications` disclosed; `<location>` with only `system.webServer` not read as ASP.NET authorization | same | `::test_allow_override_false_marks_unknown`, `::test_location_system_webserver_not_read_as_authorization` | T28.40 | 1.5 |
| T28.43 | `access_rule_unmatched` (rule whose `scope_path` matches no route prefix or folder); summary-only | `guard.py`/summary | `::test_unmatched_rule_listed` | T28.41 | 1 |
| T28.44 | R18 hygiene: role strings containing `@` or SID shape counted as users, not recorded; `DOMAIN\X` kept with `domain_qualified: true`; `users_named` is a count only | same | `::test_named_users_counted_not_recorded`, `::test_roles_email_or_sid_counted_not_recorded` | T28.40 | 1 |

### 4D. W3 — guards (12 h)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T28.50 | In-Target guards: class deriving `AuthorizeAttribute`/`AuthorizationFilterAttribute` or implementing `IAuthorizationFilter` → `guard_class`; its uses are `auth_check via=custom`; a role guard only with literal `Roles=`/`Users=` **and** no override of `AuthorizeCore`/`OnAuthorization` (else filter result `unknown`) | `stacks/aspnet.py`, `stacks/aspnet_core.py` | `::test_in_target_authorize_subclass`, `::test_subclass_overriding_authorizecore_is_unknown` | T28.23 | 2.5 |
| T28.51 | `guard_candidate`: external attribute on ≥3 controllers/actions, not framework-known or declared; includes non-guard (layout) attributes; summary "Unclassified controller attributes" | `stacks/aspnet.py`, `summary.py` | `::test_guard_candidate_threshold`, `::test_nonguard_attribute_listed_as_candidate` | T28.50 | 1.5 |
| T28.52 | `Auth attributes:` declaration promotes names to `auth_check via=declared`; a declared guard with no args has unknown reach | `stacks/aspnet.py` | `::test_declared_auth_attribute`, `::test_declared_guard_without_args_is_unknown_reach` | T28.22, T28.50 | 1 |
| T28.53 | Guard arguments: literal → `role` (only from `Roles=`/positional role); `Users=` → `users_named: N`; `const` → `role_ref` + `role` value only if a Target string literal, not a `secret_location`, and `secrets.never_record_value(name)` false; secret constant → `arg_kind: secret`, **no value** (R19); else `role_ref: expression`; record arity and kinds | same | `::test_const_role_argument_name_and_value`, `::test_secret_constant_not_resolved`, `::test_users_argument_counted_only`, `::test_arity_recorded`, `::test_non_literal_role_argument`; corpus `custom-guard`, `secrets-never-recorded` | T28.50 | 2.5 |
| T28.54 | `auth_method` promotion: a method called with ≥2 constants that are also guard-attribute arguments; all its calls `auth_check via=call`; list **every** referenced constant; in-body checks count as `inbody` | post-pass | `::test_auth_method_promotion_lists_all_constants` | T28.53 | 2 |
| T28.55 | Guard argument shapes data: distinct `(attribute, arg-kind tuple)` with counts; mark method-level uses that override a class-level use with a different arity | post-pass | `::test_guard_shapes_table`, `::test_method_overrides_class_arity_marked` | T28.53 | 1 |
| T28.56 | `System.Web.Http.AuthorizeAttribute` vs `System.Web.Mvc.AuthorizeAttribute` by `using`; `api_pipeline: true` for `ApiController` under bearer auth, not mixed with MVC | `stacks/aspnet.py` | `::test_web_api_authorize_separate_pipeline` | T28.50 | 1.5 |

### 4E. W4 — effective protection per handler (`appdoc/guard.py`, 24 h)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T28.60 | `guard.py` entry point and scope: mechanism list for `aspnet` and `aspnet_core`, `guard_reach` for `aspnet` only; `aspnet_core` absence claim only when none of `AddAuthorization\|AddAuthentication\|UseAuthorization\|UseAuthentication\|RequireAuthorization\|…` exists; evaluate only entries whose handler resolves to a Target class (skip `[NonAction]`, `[ChildActionOnly]`, non-public) | `appdoc/guard.py`, `extract.py` post-pass | corpus `core-fallback-policy` | T28.25, T28.54 | 2.5 |
| T28.61 | URL set per action: default-route aliases (`/`, `/Home`, `/Home/Index`), attribute routes only when any `[Route]`, extra segments; non-expandable leading segment (`{*path}`, `{culture}`, regex constraint, custom `IRouteConstraint`) → `url_set_open`; most permissive result wins | `guard.py` | corpus `route-aliases`; `::test_url_set_open_on_nonliteral_segment` | T28.60, T28.16 | 3 |
| T28.62 | URL authorization chain for archetypes `anon`/`auth`/`role:<R>` (cap N of M): deepest folder first, `<location>` by segment count then document order (R15), then the file's own authorization, `<clear/>`/`<remove>`, verbs, `?`/`*`, role match case-insensitive, named user ⇒ `unknown` if before a decisive rule, implicit `allow *`, `unknown` on unsupported transform/external/locked/unparsed | `guard.py` | `::test_url_auth_allow_roles_only_falls_through`, `::test_url_auth_first_match_wins`, `::test_url_auth_child_before_parent`, `::test_url_auth_location_before_own_authorization`, `::test_url_auth_tie_break_document_order`, `::test_url_auth_verbs`, `::test_url_auth_clear_remove`; corpus `url-auth-merge` | T28.41, T28.42 | 4 |
| T28.63 | Filters ANDed: method, class, every in-Target base, global filters (`HandleErrorAttribute` is not a guard); `[AllowAnonymous]` on a controller disables action `Authorize` but not a URL deny; `[OverrideAuthorization]`; `Roles` + `Users` on one attribute | `guard.py` | corpus `filter-composition` | T28.60 | 3 |
| T28.64 | Unknowns (R20): unresolved base type not declared (`base_external`), guard class that overrides authorization, unreadable config → `guard_mechanism` gains `unknown` with a reason and filter result `unknown` | `guard.py` | `::test_unresolved_base_is_unknown`, `::test_unknown_never_collapses_to_none` | T28.63 | 2 |
| T28.65 | Reach per principal (`allow` only if URL and filter both allow), closed labels `no_app_restriction\|signed_in_any\|role_restricted\|denied\|unknown`; OWIN present with mode `None` → `unknown (reason: owin)`; `host_auth_set`/`iis_anonymous_unknown` in `reasons`; `reach_by_config` only when >1 configuration evaluable | `guard.py` | `::test_reach_labels`, `::test_owin_none_is_unknown`, `::test_reach_by_config_only_when_multiple` | T28.62, T28.38 | 2.5 |
| T28.66 | Verbs: closed list + `verbs_declared`; verb-less MVC 5 action = `any`; `state_changing` tri-state (`true`, `false`, `unknown`); `writes`; Web API name convention | `guard.py` | corpus `verbless-actions`, `antiforgery-variants` (data part) | T28.60 | 2 |
| T28.67 | Detail keys (`guard_mechanism`, `reach`, `reach_anon`, `reach_auth`, `reach_roles`, `reach_by_config`, `reasons`, `state_changing`, `verbs`, `verbs_declared`, `writes`, `url_set`); capabilities `entry_point.guard_mechanism` (both stacks), `guard_reach` (`aspnet` only); byte-identity serial/pool/warm cache | `facts.py`, stacks, `tests/test_parallel.py` | conformance and parallel identity green | T28.65, T28.66 | 1 |
| T28.68 | Reserved follow-up hardening for `guard.py`: 2.7 needed nine unplanned follow-up commits on 42 (S6.1–S6.5, S7.1–S7.4, 21%), and the 2.7.1 review found five spec gaps on 42, so 20% of the stream is held for fixes found by the first fresh audit of a real-shaped Target; spent only against named defects, each with a failing test first | `guard.py`, tests | every defect found by T28.C2/T28.C3 has a test and a commit; unspent hours are released | T28.67 | 4 |

### 4F. W11 and spike items — finding candidates (≈ 24 h)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T28.70 | `smells.from_facts(facts) -> list[Fact]` after the W4 post-pass; `fid = fact_id("smell", pattern, path, line)`; `sources` as `(path, line, kind, name)` tuples; messages never echo names or values | `smells.py`, `extract.py` | `test_smells::test_from_facts_deterministic_fid`, `::test_from_facts_reads_no_source` | T28.67 | 2 |
| T28.71 | Deterministic config patterns: `machinekey-in-config`, `named-user-access-rule`, `duplicate-config-key` (text; transform files excluded; skipped if an external `file=` may override), `debug-setting-in-nondebug-config` (effective value per configuration; `Debug` listed summary-only) | `smells.py` | one positive and one negative per pattern; `::test_duplicate_key_skips_transform_and_external` | T28.70, T28.35 | 2.5 |
| T28.72 | Heuristic Facts patterns: `handler-without-guard`, `state-change-authenticated-only` (same-area sibling `role_restricted`, ranked by `writes`), `post-without-antiforgery` (one Target-level hit with a per-controller table; own/class/inherited `[ValidateAntiForgeryToken]`, or a Target attribute calling `AntiForgery.Validate`, `ApiController` excluded) | `smells.py` | positives and spike false-positive negatives (read-only POST, redirect-only stub, `allow *` data API); `::test_per_controller_anchor_stable_when_action_added` | T28.70, T28.65 | 4 |
| T28.73 | Null patterns with the soundness rules: `deref-before-null-check`, `deref-in-null-branch`, `dead-null-fallback` (unqualified call, typed local) | `smells.py` | `test_smells::test_deref_before_null_check_positive`, `::test_deref_before_null_check_short_circuit_condition_not_flagged`, `::test_deref_in_inner_block_not_flagged`, `::test_deref_in_null_branch_positive_and_negative`, `::test_dead_null_fallback_unqualified_typed_local`, `::test_dead_null_fallback_extension_method_excluded` | T28.70 | 3 |
| T28.74 | `smells.OBLIGING` frozenset; `check._c12_smells` filters on it; `summary.finding_candidates` labels all others "candidate (not an obligation)"; prints "none" for patterns of a stack whose detector ran with no hits; deterministic config reads oblige on shipping | `smells.py`, `check.py`, `summary.py` | `test_check::test_c12_only_obliging_patterns`; summary test | T28.71 | 2 |
| T28.75 | Labelled set and gate: `eval/labels/<pattern>.json` (≥5 positives, ≥3 negatives, labelled by someone other than the author, incl. spike false-positive shapes); rework `eval/smell_precision.py`; `tools/release.py` prints class, hits, precision, obligation status; a heuristic obliges only at precision ≥ 0.8 | `eval/`, `tools/release.py` | precision test green; unlabelled heuristic stays summary-only | T28.72, T28.73 | 2.5 |
| T28.76 | `identifier-list-in-config`: appSettings value that is a comma list of ≥3 same-shape tokens under key last-words `Users\|Admins\|Testers\|Owners\|Allowed\|Exempt\|Ignore\|Ids\|Positions`; counts only (R18); reports overriding configurations | `smells.py` | corpus case; `::test_identifier_list_counts_only` | T28.71, T28.36 | 1.5 |
| T28.77 | `hardcoded-production-mode` in a `WinExe`/`Exe` project (mode assigned an enum member named `Production` in `Main`'s file) | `smells.py` | `test_smells::test_hardcoded_production_mode_winexe_positive`, `::test_hardcoded_production_mode_web_project_negative`, `::test_mode_assigned_outside_main_file_negative` | T28.14, T28.70 | 1.5 |
| T28.78 | `conditional_const` (const under `#if` referenced by a guard argument) and `mode_branch` Facts; the `#if DEBUG` pattern widens to local assignments in files with handlers (summary-only); summary names the configurations whose `DefineConstants` define the symbol | `aspnet.py`, `smells.py`, `summary.py` | `::test_conditional_const_fact`, `::test_mode_branch_counts` | T28.24, T28.53 | 2.5 |
| T28.79 | `config-year-horizon` with `Reference year:` from `appdoc-context.md`; summary-only without a declared year | `smells.py` | `::test_year_horizon_needs_reference_year` | T28.22, T28.70 | 1 |
| T28.80 | Stale-rule and config-reader accountability counts in the summary ("seen / recognised / unrecognised" for guard attributes and config reads; zero-recognised reads "ran, found no match") | `summary.py` | summary test | T28.43, T28.51 | 1.5 |

### 4G. Generated blocks (template 2.8, 10 h)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T28.90 | Register five blocks: `access-model` (5.4), `connections` (8.1), `integrations` (8.3), `pipeline` (16.8), `repo-docs` (**2.2**, verify it is free first); all added to `OPAQUE_BLOCKS`; update `check._c7_blocks`, `fingerprint.claim_sha` masking, `fill.RENDERERS`, 2.7's `doc_sha`; one block per key | `template_spec.py`, `check.py`, `fill.py`, `assets/template.md` | `test_check::test_new_blocks_are_opaque`; sealed row survives a block content change | T27.44 | 2 |
| T28.91 | `access-model` renderer: disclosure line (C7-covered), per configuration columns, access-rule matrix (first 40, N of M) and unmatched rules, per-area counts with the three archetype results, **all** `no_app_restriction` handlers and every `state_changing` handler not `role_restricted` (first 60, N of M), guard attributes and shapes, all role constants, secret-location table (counts only), Defaults note, stacks-that-report note (`aspnet_core` mechanism-only) | `fill.py`, `integration.py` | `test_fill::test_access_model_block`, `::test_access_model_disclosure_line`, `::test_access_model_archetype_triple`, `::test_access_model_config_columns`, `::test_unguarded_handlers_listed`, `::test_all_no_app_restriction_listed`, `::test_access_model_caps_n_of_m` | T28.90, T28.67 | 3 |
| T28.92 | `connections` (one row per name across base/transform/test configs) and `integrations` (external calls only; WCF now, convention calls in 2.9) renderers built on `appdoc/integration.py`; vocabulary extended with `file_drop`, `share`, `service` | `integration.py`, `fill.py` | `::test_connections_all_listed_grouped_by_name`, `::test_integrations_block`, `::test_integrations_none_phrase_stable` | T28.90, T28.37 | 2 |
| T28.93 | `pipeline` and `repo-docs` markers and R4 capability-aware "none" text ("read by the generic reader" vs "no supported Stack") | `fill.py` | `::test_pipeline_block_none_in_2_8`, `::test_repo_docs_block_none_in_2_8` | T28.90 | 1 |
| T28.94 | `summary.py`: accountability line, "Unclassified controller attributes", extend count-marker `CLASS` constant (areas, state-changing handlers by label, access rules, role constants, guard shapes, secret-location files, configurations) | `summary.py`, `template_spec.py` | `test_summary::test_accountability_line`, `::test_unclassified_controller_attributes`; `test_template_spec::test_count_marker_classes_2_8` (every new class has a renderer and a noun); `test_fill::test_count_markers_2_8_values` | T28.80, T27.16 | 2 |

### 4H. Check rules (11.5 h)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T28.A0 | **C21** mandatory inputs cited: every file holding a `security_setting`, `access_rule`, `config_external`, or `app` `config_key` with `secret_location` is cited with a line at least once with **all** generated blocks masked (`docmodel.mask_blocks`); unparsed file needs the path only | `check.py` | `test_check::test_c21_uncited_security_config_fails`, `::test_c21_unlined_citation_fails`, `::test_c21_generated_16_6_citation_does_not_satisfy`, `::test_c21_unparsed_file_needs_path_only`, `::test_c21_ignores_wording`; corpus `config-not-reviewed` | T28.30, T28.90 | 2.5 |
| T28.A1 | **C22** area and protection coverage: every non-root `mvc_area_path` is the folder cited in a 4.1 row (reuse `_c7_counts` 4.1 parse); handler files with `state_changing: true` or label `no_app_restriction`/`signed_in_any`/`unknown` must be cited — refactor `_uncited_entry_points` to take a filter so C13 and C22 share the citation map; undeclared guard candidates advisory (fails under `--strict`); read-only guarded handlers stay advisory; `desktop` not an obligation | `check.py` | `::test_c22_area_missing_from_4_1_fails`, `::test_c22_root_area_not_demanded`, `::test_c22_unguarded_file_uncited_fails`, `::test_c22_readonly_guarded_stays_advisory`, `::test_c22_shares_c13_map`, `::test_c22_undeclared_candidates_strict_only`; corpus `area-coverage` | T28.16, T28.65 | 3.5 |
| T28.A2 | **C23** advisory (auth topics): match §14 rows and "Unknown - see Open questions." paragraphs against the closed topic vocabulary; name the location when a `security_setting`/`access_rule` Fact exists | `check.py` | `::test_c23_auth_topic_advisory` | T28.30 | 1.5 |
| T28.A3 | C20-family advisories: file cited in a sentence with a closed exclusion phrase (`not reviewed`, `not inspected`, `excluded`, `was not read`), plus the C21 hint for mandatory inputs; range `a-a` → "write `:a`" | `check.py` | `::test_c20_cite_in_not_reviewed_sentence_advisory`, `::test_c20_mandatory_input_hint`, `::test_c20_single_line_range_advisory` | T26.50 | 1.5 |
| T28.A4 | `template_spec`: headings 5.4, 8.x blocks, 16.8, 2.2, `REQUIRED_SUBSECTIONS`, the maintenance row in 16.x, `UPGRADE_STEPS["2.8"]`, `UPGRADE_NOTES`, `TEMPLATE_VERSION = "2.8"`; the five new blocks are opaque, so 2.7.1's A.1 line (generated from `OPAQUE_BLOCKS`) names them with no extra code (`test_register::test_not_audited_line_lists_the_2_8_blocks`); section 5.3 rows are planned per row (T28.A5); prose in 5.1 and 5.2 stays outside the plan (accepted residual, ADR 0019) | `template_spec.py`, template | `test_core` template tests; 2.7 documents fail C3 until upgraded | T28.90 | 1 |
| T28.A5 | Audit plan covers the access narrative: `audit_plan` plans every 5.3 row as `5.3/<slug>` (full coverage, the 10.2 machinery with no status filter); `register.REF_RE`, `fingerprint.row_keys`, `audit_plan.ref_for`/`_in_section` and C11's allowed-section list gain `5.3`; Check message names the row text as for 10.2 | `audit_plan.py`, `register.py`, `fingerprint.py`, `check.py` | `test_audit_plan::test_section_5_3_rows_planned_per_row`, `::test_5_3_row_without_register_row_fails_c19`, `test_register::test_5_3_row_key_valid_and_sealed`; corpus `audit-per-row-5-3` | T28.A4 | 1.5 |

### 4I. Workflow, SKILL, release (39 h)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T28.B0 | **Dropped.** Q23 was accepted and `appdoc upgrade` shipped in 2.7.0 (T27.30–T27.32); nothing to carry here | — | removed from the 2.8 total | — | 0 |
| T28.B1 | Version drift warning: `extract` prints a stderr warning and `check-report.md` carries "The existing document is on template X; this AppDoc writes Y. Run appdoc upgrade…"; **not** in `facts-summary.md` | `__main__.py`, `check.py` | `::test_drift_warning_stderr_and_report_only` | T28.A4 | 1.5 |
| T28.B2 | `SKILL_RULES` constant and a generated block in `gen_docs`; SKILL.md Orient (read `access-model`, `connections`, `integrations` before §3, 5, 8, 10), writing rules (never list a config file as not reviewed; "Unknown" only after checking the summary; every `state_changing` handler considered; one subsystem per area), audit checklist | `tools/gen_docs.py`, SKILL.md | `test_release::test_generated_docs_current` | T28.A4 | 3.5 |
| T28.B3 | Optional, any release: `render --mermaid sibling` writes `mermaid.min.js` once beside the HTML; default `inline` unchanged | `render/page.py` | `test_render::test_mermaid_sibling_mode`, `::test_inline_default_unchanged` | — | 1.5 |
| T28.C0 | `facts.SCHEMA` next after 2.7's; conformance for every new kind; `aspnet`/`aspnet_core` capabilities; R18/R19 tests (an email-like role, SID, secret constant and connection-string password never appear in any Fact, block or summary) | `facts.py`, `tests/test_conformance.py` | suite green | all 4C–4F | 1.5 |
| T28.C1 | ADRs 0018 (security-bearing configuration is mandatory input: R16, R19, C21), 0019 (effective protection is application-layer: R17, R20, W4, disclosure line, C22, .NET-only scope, residual risk), 0020 (as the plan names it); CONTEXT.md terms | `docs/adr/` | merged | T28.A1 | 2 |
| T28.C2 | Fresh run + independent audit of the four examples (eShop, flaskr, gitea, petclinic) on template 2.8: write Narrative, `build`, `audit-plan`, fresh-agent audit, `seal --audit --date`, `build`; the new blocks appear (the audit follows the 2.7.1 order: fix every advisory, make every Narrative edit, then audit all planned keys and every row of the sampled sections in one pass, so a reseed cannot leave uncovered keys; the 2.7.1 delta audit needed three auditor passes per app before this rule) with "none" where the Stack does not report | `examples/current/*` | `build --require-audit --strict` passes; rotation moves 2.7 to `previous` | T28.C0, T28.B2 | 24 |
| T28.C3 | Private acceptance run on the DegreeAudit checkout; every group-C row produced as a Fact, candidate, block line or Check problem; counts go to the release report only | `tools/acceptance.py` | all 2.8 rows green | T28.C0, T28.91 | 2 |
| T28.C4 | `docs/diagnostic-2.8.0-comparison.md`; CHANGELOG with upgrade notes 2.7 → 2.8 (run `appdoc upgrade`, re-extract, cite every mandatory config file with a line, add area folders to 4.1, address obliging candidates, audit, build) | docs | merged | T28.C2 | 2 |
| T28.C5 | `tools/release.py 2.8.0` (tests, determinism, extractor eval, narrative eval, rotation); tag; CI green | — | tag exists | T28.C4 | 1 |

**2.8 critical path:** T28.01 → T28.02 → T28.21 → T28.30 → T28.33 → T28.34 → T28.35 → T28.40 → T28.41 → T28.62 → T28.65 → T28.67 → T28.70 → T28.72 → T28.91 → T28.A1 → T28.C2 → T28.C5. W5/W6 (4B), W3 (4D) and the labelled set (T28.75) run in parallel with the config chain; W4 is the longest single block and should be split between two engineers at T28.61/T28.63.

---
## 5. Release 2.9.0 — integrations, CI, repository docs (plan 2.8 rev 4, items marked 2.9)

Schema next after 2.8's (expected `/9`). **No template bump:** the blocks shipped in 2.8, so 2.9 only fills them. New kinds in `GENERIC_KINDS`: `ci_job`, `doc_file`, `test_suite`, `xsd_schema`, `logging_target`, `share`. Note: things can fail that passed (new `debug-settings-deployed` id, block content changes until `fill`, any newly obliging pattern); say so in the upgrade notes.

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| T29.01 | **W7** config-configured clients: key suffix set `Url\|Uri\|Endpoint\|BaseAddress\|Host\|Wsdl` reaching a `new T(...)` first argument (regex spans lines), `.Url`/`.BaseAddress`/`.Endpoint.Address` assignment → `external_call type=service`; no double report with smtp | `stacks/aspnet.py`, `integration.py` | `::test_config_url_ctor_client_multiline`, `::test_config_url_property_client`, `::test_smtp_not_double_reported`; corpus `config-client` | T28.C5 | 3 |
| T29.02 | **W7** file-drop taint rule inside one method: name tainted when assigned from a config read, `Path.Combine`, `+`, interpolation, `string.Format` of tainted names (≤4 assignments); tainted name as first argument of `File.Write*`/`Bitmap.Save`/`Image.Save`/… → `external_call type=file_drop`; untraced → `path_ref`, never guessed | same | `::test_file_drop_two_hops`, `::test_file_drop_three_hops`, `::test_file_drop_four_assignment_cap`, `::test_save_stream_not_a_drop`, `::test_untraced_path_not_guessed`, `::test_app_data_write_is_local_fil…`; corpus `unc-drop` | T29.01 | 4 |
| T29.03 | **W7** config-only `share` Fact: any config key whose value starts with `\\` → `share key unc: true`, no host or value, joined to the lines that read the key | `stacks/generic.py` | corpus `share-key` | T28.21 | 1.5 |
| T29.04 | **W7** feed `integrations` block with `service`, `file_drop`, `share`; per-configuration connection-target matrix **only** if Q31 accepted (`Record connection targets: yes`) | `integration.py`, `fill.py` | `test_fill::test_integrations_block_lists_service_file_drop_share`, `::test_integrations_block_capped_n_of_m`, `::test_connection_target_matrix_only_with_directive`, `::test_connection_target_matrix_absent_by_default` | T29.02, T29.03 | 1.5 |
| T29.05 | **W8** restricted line reader for `.gitlab-ci.yml` and GitHub workflows (stdlib; Azure Pipelines and Jenkinsfile named "not read"): job maps, `stage`, `only/except/rules` (list or map `refs:`), `when`, `environment` (scalar or map), `variables`, `script` incl. block scalars, flow sequences, trailing comments, regex literals; unmatched line in a job → `parse_confidence: partial` and negative claims suppressed (R20); `extends`/`include` | `stacks/generic.py` or `ci.py` | `::test_gitlab_ci_jobs`, `::test_block_scalar_script_lines_read`, `::test_flow_sequence_on_trigger`, `::test_only_as_map_refs`, `::test_rules_if_stored_as_trigger_other`, `::test_trailing_comment_after_key`, `::test_regex_literal_in_only`; corpus `ci-jobs`, `ci-fail-safe` | T28.20 | 5 |
| T29.06 | **W8** `ci_job` detail: stage, trigger class, environment (name; URL as `scheme://host`), `build_config` sorted list (`multiple` where they differ), step classes, `unclassified` (first token only), `parse_confidence` | same | `::test_ci_job_detail` | T29.05 | 2 |
| T29.07 | **W8** configuration resolution: `/p:Configuration=`, `-p:`, `/property:`, `-c`, `--configuration`, quoted forms, `$NAME`, `${NAME}`, `$env:NAME`, `$(NAME)`, `${NAME:-Release}`; resolves only from variables defined in the same file at global or job level, else `unresolved: [variable]`; variables recorded by key name only (R19) | same | `::test_build_config_env_powershell_form`, `::test_build_config_resolved_from_v…`, `::test_unresolved_variable_listed` | T29.06 | 2 |
| T29.08 | **W8** negative claims and `test_suite`: "No job runs tests." only when every job and file fully resolved, else "Test steps not determined: N unresolved references."; test verbs by first token (`dotnet test`, `nunit3-console`, `Invoke-Pester`, …); `test_suite` from project references or `[TestMethod]\|[Fact]\|[Test]` | same | `::test_pipeline_no_test_trailer`, `::test_test_suite_old_style_project` | T29.07, T28.24 | 3 |
| T29.09 | **W9** `doc_file` for `README*` at any depth and `*.md`/`*.htm*` under code-free unpruned folders (`.docx/.csv/.xlsx` by name only); `headings` as (line, level), heading text only when it matches a closed topic (R18); closed topic vocabulary incl. `logging`, `maintenance`, `scheduled`, `integration…`; `owner_entries` count with HTML comments stripped | `stacks/generic.py` | `::test_readme_topics`, `::test_topic_vocabulary_logging_maintenance_scheduled`, `::test_owner_entries_counted_no_names`, `::test_owner_entries_ignore_html_comments`, `::test_heading_text_only_when_closed_topic`, `::test_docs_folder_with_code_not_doc_file`; corpus `readme-topics` | T28.20 | 3 |
| T29.10 | **W9** `logging_target` from framework config sections (appender type, file path literal, level) with transform overrides | `dotnetcfg.py` | `::test_logging_target_with_transform_override` | T28.34 | 1.5 |
| T29.11 | **W9** cross-source advisories (deterministic): README branch tokens no CI `only:` uses; coverage badge with no `test` job; feature bullets matching no §4 row title; `doc_mentions_config_key`; **`multi_sink_handler`** (external write and data write in one handler span, with line order); facts summary gains "Repository documentation" | `check.py`, `smells.py`, `summary.py` | advisory tests; `::test_multi_sink_handler` | T29.09, T29.02 | 3 |
| T29.12 | **W10** scan accounting: one "code" extension list shared with stacks (`.bat`, `.xsl`, `.ps1` are code); prune `AppDoc output (v1)` (`architecture-fingerprint.json` + `evidence/evidence-graph.json`); `Generated documentation candidate` (topmost recursive folder, ≥20 files or ≥3 with repeated names, ≥80% `.json/.md/.html`; not paired with `duplicate_folders`) | `scan.py` | `::test_prune_v1_output`, `::test_code_definition_shared_with_stacks`, `::test_doc_copy_candidate_topmost_recursive`, `::test_doc_copy_with_repeated_names_lower_threshold`, `::test_doc_copy_not_duplicated_with_duplicate_folders`; corpus `v1-output` | T26.31 | 4 |
| T29.13 | **W10** content-data folders (no code, ≥200 files, ≥95% one data extension) counted `content` and excluded from "files read" (config-key extraction still runs); vendored-library candidate (`*.min.js`, `lib`/`vendor`/`third_party`/`node_modules` with large single-file scripts); tool-state dot-folder candidate; scan split line `Source F · Content C (in N folders) · Documentation D · Pruned P` | `scan.py`, `fill.py` | `::test_content_folder_counted_separately`, `::test_vendored_min_js_candidate`, `::test_scan_split_counts`; corpus `content-folder` | T29.12 | 4 |
| T29.14 | **W12** `schema_object` from `.edmx`/`DbContext`; `ui_page type=report` for `.rdlc/.rdl`; `data_access type=sql` gains `schema`; `xsd_schema` (top-level element and complexType names and counts) | `stacks/aspnet.py`, `stacks/generic.py` | `::test_edmx_entities`, `::test_rdlc_report_page`, `::test_sql_schema_detail`, `::test_xsd_element_names`; corpus `xsd-format` | T28.20 | 4 |
| T29.15 | Block content: `pipeline` (16.8 rows, test suites, negative-claim trailer, unresolved references, CI files present but not read), `repo-docs` (2.2: topics, copies, `doc_mentions_config_key`), `integrations` convention calls; SKILL rule: read every file tagged `owner`, `environment`, `operations`, `logging`, `maintenance`, `scheduled` before §11, §14, §16; count-marker classes for CI jobs and test suites | `fill.py`, `template_spec.py`, SKILL_RULES | `::test_pipeline_block`, `::test_repo_docs_block` | T29.08, T29.11 | 3 |
| T29.16 | `debug-settings-deployed` (heuristic; `debug-setting-in-nondebug-config` joined to a `ci_job` or `publish_profile` that deploys that configuration) and `ci-without-test` (deploy job, no test job, ≥1 `test_suite`, fully resolved graph); both through the labelled-set gate | `smells.py`, `eval/labels/` | positive/negative tests; precision ≥ 0.8 to oblige | T29.08, T28.75 | 2 |
| T29.17 | **C23 remaining topics:** a `doc_file` with the topic, `external_call type=file_drop\|service`, or `ci_job environment` exists → advisory names the location | `check.py` | `::test_c23_doc_topic_advisory`, `::test_c23_ci_environment_advisory` | T29.09, T29.06 | 2 |
| T29.18 | Detector accountability lines for new detectors (file writes seen vs file-drop recognised, CI lines seen vs recognised) | `summary.py` | summary test | T29.02, T29.05 | 1 |
| T29.19 | `facts.SCHEMA` next; conformance (`GENERIC_KINDS` updated); R18/R19 tests for CI variables and README owners | `facts.py`, tests | suite green | all of 2.9 | 1.5 |
| T29.20 | Mechanical regeneration of the four examples (no new audit; A.1 discloses regeneration after audit); rotate; `docs/diagnostic-2.9.0-comparison.md` | `examples/` | `build` passes | T29.19 | 4 |
| T29.21 | Private acceptance run for 2.9 rows (DA-E2, E3, E4, E10 scan, G 6.3, G 6.5, S5 CI) | `tools/acceptance.py` | all 2.9 rows green | T29.19 | 2 |
| T29.22 | ADR amendments (0018/0019 as needed); CHANGELOG with the corrected 2.8 → 2.9 upgrade notes; `tools/release.py 2.9.0`; tag | docs | tag exists, CI green | T29.20, T29.21 | 2 |

**2.9 critical path:** T29.05 → T29.06 → T29.07 → T29.08 → T29.15 → T29.19 → T29.20 → T29.22. W7, W9, W10 and W12 are independent of the CI chain and can run in parallel.

---

## 6. Optional and deferred

| ID | Task | Notes | h |
|---|---|---|---|
| T90.01 | Performance plan Phase 5 (deferred in `docs/performance-plan.md` §8) | not scheduled; re-estimate from that section before starting | — |
| T90.02 | Q32: stop recording git author names in `ownership` Facts (R18) | done in 2.6.0 as T26.66 (counts and dates only; no exemption); bumps schema | ≈ 4 |
| T90.03 | Second public classic-MVC example from a real repository (Q24) | replaces the synthetic `mvc5-classic` as false-positive data when one is found | ≈ 16 |
| T90.04 | `render --mermaid sibling` (also T28.B3) | can ride in 2.6.0 | 1.5 |

---

## 7. Cross-release view

```
T00.1–3 ─┐
         ├─ 2.5.0:  corpus → extractors → bump → examples → tag (39 h)
         │            └─ blocks everything below that changes Facts
2.6.0 ───┤  guardrails (provenance, determinism) ─┬─ capabilities ─┐
         │  scan/config work ─────────────────────┤                ├─ gate, gen_docs, release.py → examples → tag (≈ 68 h)
         │  C20 and previews ─────────────────────┘                │
2.7.0 ───┤  register chain → audit-plan → SKILL → fresh audits → tag (≈ 52 h, +16 upgrade)
2.8.0 ───┤  corpus/target → .config reader → transforms → rules → W4 → patterns → blocks → C21/C22 → audits → tag (≈ 175 h)
2.9.0 ───┘  CI reader ‖ taint/share ‖ docs ‖ scan ‖ xsd → block content → regen → tag (≈ 62 h)
```

**Hard dependencies between releases**
- 2.6 T26.41 (cache salt from the bundle hash) removed the R21 bump rule (landed); no task bumps a constant by hand any more.
- 2.7 T27.02 (`doc_sha`) and T27.10 (opaque registry) are prerequisites for 2.8's T28.90.
- 2.8 T28.A4 (`UPGRADE_STEPS["2.8"]`) needs 2.7's step table (T27.30).
- 2.9 reuses the raw-Fact foundation (T28.20–T28.25) and the labelled-set gate (T28.75).

**Parallelism.** Within a release, tasks with no shared "Needs" can go to separate subagents: 2.5 (1B, 1C, 1D), 2.6 (2B, 2C, T26.50), 2.7 (3A, count markers, notes), 2.8 (4B, 4D, T28.75 alongside the config chain; W4 split at T28.61/T28.63), 2.9 (W7, W9, W10, W12 against the CI chain). Example regeneration and audits (T25.42, T26.64, T27.42, T28.C2, T29.20) must run after the release's code is frozen; the audits in T27.42 and T28.C2 need a fresh agent that did not write the Narrative.

**Smallest useful drop first.** The 2.8 first slice (≈ 9 d: 4A minimal, 4B, 4C W13/W1/W2, 4D, T28.A0) can ship as a patch on top of 2.5.0 if the DegreeAudit-class gaps (config never reviewed, unreadable `<authorization>`) must be closed before 2.6–2.7 finish; it needs no template change, but C21 should then be gated on the document stamp.
