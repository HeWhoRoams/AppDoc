# Remediation plan: code review of 2.5.0 + 2.6.0 (2026-11-23)

**Scope.** The 20 findings of the two-axis review of `git diff 2e59393...impl/2.6.0` (11 Standards, 9 Spec). Source reports: the review of 2026-11-23 (this session). Finding IDs: **S1–S11** (Standards) and **P1–P9** (Spec, "plan").
**Release handling.** 2.6.0 has been tagged only in the local clone and has not been pushed. These fixes are made as commits on `impl/2.6.0` **before the first push**; the examples are regenerated once at the end, and `v2.6.0` is re-created at the new head. Schema stays `appdoc-facts/7`, because nothing has shipped at `/7` (R6 concerns released schemas). If a decision below changes Facts output for an input that 2.5.0 shipped, that is already covered by the `/7` bump.
**Principle.** Every finding gets one disposition: **Fix** (code and test), **Align** (the plan or ADR was wrong or silent; the text changes, the code stays) or **Accept** (recorded with a reason). No test is weakened (R2); where a test changes, the new one asserts at least what the old one did.

## 1. Decisions needed before work starts

| ID | Question | Recommendation | Affects |
|---|---|---|---|
| **D1** | `PasswordHash`, `TokenCache`, `PasswordFile` etc. are no longer secret keys (plan 2.6 §4.4 closed modifier set). R19 says the secret-key rule also gates **value resolution** (2.8 resolves guard constants). Keep the plan's rule for the `secret_location` flag, but add a second, conservative predicate for "never record or resolve a value"? | **Yes.** Two predicates: `is_secret_key` (display flag; segment-aware, as planned) and `never_record_value(key)` = `is_secret_key` **or** the old broad regex. R19 and 2.8 use only the second. The flag stays precise; the safety net stays wide. | S4 |
| **D2** | Plan 2.5 §1.5.2 says `secret_location` is true "only for role `app`". An INI key such as `[db] DB_PASSWORD` that no code reads is `unclassified` and keeps the flag. Follow the plan literally (flag lost) or keep the flag on `unclassified` keys? | **Keep the flag; change the plan text** to "never on `env` or `ci` keys". Losing a password flag in a config file because no code reads the key hides the exact thing the table exists to show. | P2 |
| **D3** | `entry_point.handler` is a fifth subtype the plan's closed set (`route\|page\|command\|job`) omits. Count it or not? | **Not counted** (`entry_point_counts` already documents this); add `handler` to the plan's closed set and make "declared subtype is counted or explicitly uncounted" a conformance test. | P7 |

All other items need no decision.

## 2. Disposition of every finding

| ID | Finding (short) | Disposition | Task |
|---|---|---|---|
| S1 | Three or more newline normalizations (R14) | Fix | F1 |
| S2 | C17 absent from `RULE_TITLES`/`RULE_SUMMARIES`; four parallel rule tables (R5/P6) | Fix | F2 |
| S3 | `_c7_config_count` parses generated English; duplicates the exact block comparison | Fix | F3 |
| S4 | Secret modifier set lets hash/cache/header names pass the R19 gate | Fix per D1 | F10 |
| S5 | Gate refers to an `.appdoc-regen` folder it never creates, and deletes one if present | Fix | F4 |
| S6 | Unused module-level `capabilities` aliases; test-only string-id branch of `capabilities_of` | Fix | F12 |
| S7 | Duplicated folder-prefix loops in `scan.py`; 55-line `_duplicate_folders` | Fix | F13 |
| S8 | `plural` lives in `fill.py`, forcing a function-level import | Fix | F14 |
| S9 | `RuntimeError` in `fill._config_reference` | Accept (plan-specified invariant) + proof test | F15 |
| S10 | Unused injectable `cites_of` in `_c20_precision` | Fix | F5 |
| S11 | `release.py` parses versions itself; `_git_in` duplicates `_git` | Fix | F6 |
| P1 | Release passes without the narrative eval; half-edited tree on a late failure | Fix | F7 |
| P2 | `secret_location` kept on `unclassified` keys | Align per D2 | F11 |
| P3 | Gate drops every `ownership` Fact, including `Ownership:` role Facts from `appdoc-context.md` | Fix | F8 |
| P4 | Gate schema comparison uses `!=`; plan and ADR claim `version_tuple` | Align | F9 |
| P5 | B-5: `GENERIC_KINDS` and "read by the generic reader" missing | Fix | F16 |
| P6 | B-2: no `--skip-tests` default test; determinism runs never include git ownership | Fix | F17 |
| P7 | `entry_point.handler` outside the closed set | Align per D3 | F18 |
| P8 | Duplicate threshold uses files, not hashes (empty files dilute) | Fix | F13 |
| P9 | Unlisted changes (footer, double-count fix, `listener`, extra corpus cases, `--skip-checks`) and the gate's destructive delete | Align (record) ; delete removed by F4 | F19 |

## 3. Tasks

Columns as in `docs/task-breakdown.md`. Tests are written first and must fail on the current head for the stated reason.

### Group G1 — Check, gate, release tooling (`check.py`, `gate.py`, `release.py`, `gen_docs.py`, `textnorm.py`, `version.py`, `tools/`)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| F1 | **One newline rule (S1).** Add `textnorm.normalize_newlines(x: str\|bytes)` (CRLF and lone CR to LF, nothing else); `normalize_text` is built on it; `bundle_hash`, `tools/artifact_hashes._digest` and `check.py:1225` call it. ADR 0016/R14 text states there are exactly two normalizations: *newlines* (all hashes of file content) and *text* (newlines + trailing whitespace + final newline + NFC, for claims and seals) | `textnorm.py`, `version.py`, `tools/artifact_hashes.py`, `check.py`, ADR 0016 | `test_determinism::test_no_inline_newline_replace` greps `appdoc/` and `tools/` for `replace("\r\n"`/`replace(b"\r\n"` outside `textnorm.py` (red now: 3 hits); `test_textnorm::test_bytes_and_str_agree`; bundle hash unchanged for LF files | — | 1.5 |
| F2 | **One rule registry (S2).** A single `check.RULES` tuple of `Rule(id, title, summary, flags, preview)`; `RULE_TITLES`, `RULE_SUMMARIES`, `RULE_FLAGS`, `PREVIEW_RULES`, `RULE_RANGE` are derived from it; add C17; remove the `problems.setdefault` tolerance and the empty-title fallback; `gen_docs.rules` reads `RULES` | `check.py`, `tools/gen_docs.py`, README | `test_check::test_every_raised_rule_is_registered` (scans `check.py` for the rule ids passed to the problem collector; red now: C17), `::test_rule_range_matches_registry`, `gen_docs --check` shows C17 in README | — | 4 |
| F3 | **Delete prose parsing (S3).** Remove `_c7_config_count`; the exact comparison of the 16.6 block with `render_block` fails on any count mismatch. Make that failure's message say which count differs (application keys shown vs expected) so no information is lost | `check.py`, `fill.py` | `test_fill::test_config_trailer_counts` and the C7 count test still pass with the regex gone; new `test_check::test_c7_config_block_count_message` asserts the message names the expected count | F2 | 1.5 |
| F4 | **Gate leaves the Target alone (S5, P9).** Remove every reference to `.appdoc-regen` (code, docstring, `tools/gate_selftest.py`, scan exclusion if only it used it); the gate neither creates nor deletes anything in the Target. ADR 0014 keeps the in-memory deviation text | `gate.py`, `tools/gate_selftest.py`, `scan.py`, ADR 0014 | `test_gate::test_gate_does_not_touch_target` hashes the whole tree before and after (red now if a stale `.appdoc-regen` exists: it is deleted); the old "regen folder removed" test is replaced by it | — | 1.5 |
| F5 | **Drop `cites_of` (S10).** Remove the unused parameter; tests that injected it call the real finder | `check.py`, `tests/test_check.py` | suite green; grep shows no `cites_of=` | F2 | 0.5 |
| F6 | **Release script hygiene (S11).** `next_dev` uses `template_spec.version_tuple`; one `_git(args, cwd=None)` | `tools/release.py` | `test_release` cases for `2.6.0 → 2.6.1.dev0` and `2.6.9 → 2.6.10.dev0`; no `_git_in` | — | 1 |
| F7 | **Release cannot skip the eval or half-edit (P1).** Preflight first: `APPDOC_EVAL_ROOT` must resolve all four clones, else exit non-zero **before** any edit; `--skip-narrative-eval` is the only bypass, prints a loud line, and the release commit message records it; any failure after the first edit restores the tree (`git checkout -- .` for tracked files, `git clean` limited to files the script created). `--skip-checks` is renamed `--test-only-skip-checks` and is accepted only with `--dry-run` | `tools/release.py`, `eval/score.py` (exit non-zero on `--require-clones`) | `test_release::test_missing_clones_abort_before_edit`, `::test_late_failure_restores_tree`, `::test_skip_flag_is_recorded`, `::test_skip_checks_needs_dry_run` | F6 | 3 |
| F8 | **Gate ignores only git ownership (P3).** Filter on `detail.source == "git"` (verify the git Facts carry it; if not, add `source: git` in `extract._ownership`) and keep `Ownership:` role Facts in the comparison | `gate.py`, `extract.py` | `test_gate::test_ownership_role_edit_exits_2` (change a role in `appdoc-context.md`, same count: red now, exits 0), `::test_git_ownership_change_still_ignored` | — | 1.5 |
| F9 | **Schema compare wording (P4).** Equality is the intended test, an older and a newer schema are both "AppDoc upgraded". Correct ADR 0014 point 2 and plan 2.6 §3.1 so they do not claim `version_tuple` for schemas | ADR 0014, `docs/remediation-plan-2.6.md` | text only; `grep version_tuple` in ADR 0014 names template versions only | — | 0.5 |

### Group G2 — Secrets and extract (`secrets.py`, `extract.py`, ADRs 0009/R19)

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| F10 | **Two predicates (S4, D1).** `secrets.never_record_value(key)`: true when `is_secret_key(key)` or the pre-2.6 broad regex matches; `is_secret_key` unchanged. R19 in the plans and ADR 0009 say value gating uses `never_record_value`. Add a guard for future callers: `config_key` Facts never carry a value (assert in `Fact.make` for kind `config_key` already? if not, a test). Simplify `_words` (one noun table with a flag for fused nouns) with identical results | `secrets.py`, ADR 0009, plans' R19 text | `test_core::test_never_record_value_is_superset` (property: for every key in the positive and negative lists, `is_secret_key ⇒ never_record_value`); `::test_password_hash_not_flagged_but_never_recorded`; the existing ≥20/≥25 name lists unchanged | — | 2.5 |
| F11 | **Flag stays on unclassified keys (P2, D2).** Keep behaviour; add `test_generic_facts::test_unclassified_secret_key_keeps_flag` (the INI `[db] DB_PASSWORD` case); amend plan 2.5 §1.5.2, task T25.22 and ADR 0009 amendment to "never on `env` or `ci` keys" | tests, plan 2.5, ADR 0009 | test green on current code; plan text changed | — | 1 |

### Group G3 — Scan, fill, stacks, conformance, determinism

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| F12 | **Remove dead capability access (S6).** Delete the seven module-level `capabilities = X.capabilities` aliases and the string-id branch of `capabilities_of` (it takes a Stack instance only; tests use instances) | `stacks/*.py`, `stacks/__init__.py`, `tests/test_conformance.py` | grep finds no module alias; conformance green | — | 1.5 |
| F13 | **Scan clean-up and the hash threshold (S7, P8).** One `_prefixes(path)` generator and one `_under(a, b)` used by `_folders_of`, `_duplicate_folders` and `folders_with`; split `_duplicate_folders` into `_match_counts`, `_pick_partner`, `_collapse`; the 50% test is `matched * 2 >= indexed_files_of_A` where the denominator counts only files that were hashed (non-empty, within `MAX_BYTES`) | `scan.py` | `test_core::test_duplicate_threshold_ignores_empty_files` (a folder of 4 identical files + 4 empty `__init__.py` pairs with its twin; red now), existing duplicate tests and `dup-*` corpus cases unchanged; `duplicate_folders` output for the four examples is compared before and after (differences listed in the release notes) | — | 4 |
| F14 | **`plural` to a neutral module (S8).** New `appdoc/textutil.py` with `plural`; `fill`, `register`, `check` import it at module level; remove the function-level import | `fill.py`, `register.py`, `check.py` | no circular-import workaround remains (`grep "import.*plural"` inside functions = 0) | F2 | 1 |
| F15 | **Prove the invariant (S9).** Keep the `RuntimeError`; add `test_fill::test_config_reference_invariant_unreachable`, which runs `extract` + `fill` over every sample and corpus Target and asserts the guard never fires; a comment names which promotion rule guarantees it | `tests/test_fill.py`, `fill.py` | test green | — | 0.5 |
| F16 | **B-5 generic kinds (P5).** `tests/test_conformance.py::GENERIC_KINDS` = kinds emitted by `generic.extract` (derived by running it over all samples and asserted equal to a literal set so additions are deliberate); per-stack capability checks skip them; a helper `fill.none_phrase(kinds)` returns "read by the generic reader" for generic-fed kinds and the existing capability-aware "No supported Stack reports …" otherwise; 16.7 and the block "none" sentences use it | `tests/test_conformance.py`, `fill.py` | `test_conformance::test_generic_kinds_exempt`, `test_fill::test_none_phrase_names_the_reader` | F12 | 3 |
| F17 | **Determinism extras (P6).** (a) `test_determinism::test_skip_tests_default_off_and_changes_output`; (b) run the harness's run-twice, workers 1 vs 2 and cache cold vs warm **with ownership on** against a temp git repo built with fixed `GIT_AUTHOR_DATE`/`GIT_COMMITTER_DATE`/identity (skipped with a message when `git` is absent) | `tests/test_determinism.py` | tests green; (b) red if ownership output depended on wall-clock or worker count | — | 3 |
| F18 | **Subtype set (P7, D3).** Add `handler` to the plan's closed subtype set; `test_conformance::test_every_entry_point_subtype_is_counted_or_listed_uncounted` compares each stack's declared `entry_point.*` capabilities with `fill.COUNTED_ENTRY_TYPES` ∪ `fill.UNCOUNTED_ENTRY_TYPES = {"handler"}` | `fill.py`, `tests/test_conformance.py`, plan 2.6 §4.1 | test red until the two sets exist | F12 | 1.5 |
| F19 | **Record the unlisted changes (P9).** CHANGELOG 2.6.0 "Changed/Fixed": removal of the `Generated: <date>` render footer (R13), the aspnet-core HttpClient double-count fix, `listener` in `DETAIL_KEYS["entry_point"]`; the plan task list gains the extra corpus cases (`owner-present`, `static-assets`) | `CHANGELOG.md`, `docs/task-breakdown.md` | text only | F4, F7 | 1 |

### Group G4 — Regenerate and re-release

| ID | Task | Where | Done when | Needs | h |
|---|---|---|---|---|---|
| F20 | Re-run `extract`/`fill`/`build --require-audit` on the four clean clones (`/tmp/ex`, or re-clone at the recorded commits) with the final code; confirm `facts.json` for each differs from the committed `examples/current` **only** where F13 or F11 explains it, and that provenance records the new bundle hash; regenerate `docs/diagnostic-2.6.0-comparison.md`; update `eval/baseline.json` only through the repo's update flag and only where a changed count is explained | `examples/current/*`, `docs/` | all four Check PASS with `--require-audit`; byte-identical across `--workers 1` and 4 and cache on/off; eval shows 0 regressions with `APPDOC_EVAL_ROOT` | F1–F19 | 3 |
| F21 | Full suite, `check_stdlib_only.py`, `gen_docs --check`; re-create the annotated tag (`git tag -d v2.6.0 && git tag -a v2.6.0`); rebuild the patch series against `465790b` and apply it to a clean checkout of the 2.5.0 series as before | git | suite green on the clean checkout | F20 | 1 |

## 4. Order and effort

```
G1  F1 → F2 → F3, F5 ; F4 ; F6 → F7 ; F8 ; F9                    ≈ 13.5 h
G2  F10 ; F11                                                      ≈  3.5 h
G3  F12 → F16, F18 ; F13 ; F14 ; F15 ; F17 ; F19                   ≈ 17   h
G4  F20 → F21                                                      ≈  4   h
                                                          total   ≈ 38   h
```

Groups touch different files except for `check.py` (F1, F2, F3, F5, F14 — all in G1/G3: F14's `check.py` edit is one import line and runs after F2). Run the groups one after another on `impl/2.6.0`, one subagent per group, G4 last, as for 2.5 and 2.6. Every group commit keeps the full suite green. Because every edit to `appdoc/` changes the bundle hash, the examples are regenerated once, in G4, not per group.

## 5. Done means

1. Every finding S1–S11 and P1–P9 has the disposition in §2 and its task closed; no new `PENDING` corpus entry.
2. The new tests named above exist, were red on the previous head for the stated reason, and are green; no existing test was weakened.
3. `grep` finds one newline normalization, one rule registry, no `.appdoc-regen`, no unused capability aliases.
4. `never_record_value` exists and R19, ADR 0009 and the plans refer to it; the secret-key lists still pass.
5. The gate exits 2 on a same-count `Ownership:` role edit; the release script refuses to run without the four clones unless `--skip-narrative-eval` is passed, and leaves the tree clean on any failure.
6. Four examples regenerate with Check PASS `--require-audit`, byte-identical across workers and cache; `docs/diagnostic-2.6.0-comparison.md` regenerated.
7. `v2.6.0` re-created at the new head; the patch series applies to a clean 2.5.0 checkout and the suite passes there.

## 6. What this plan does not fix

- Standards S9 stays a `RuntimeError`: the plan (2.6 §4.4.3) specifies it, and F15 proves it unreachable from Target data.
- The wording "byte-identical" in the duplicate-folder heading (reported in the 2.6 final report, not in the review) is left for 2.7, where the heading text is generated and audited anyway; the property that matters (≥ 50% of hashed files match) is now what the code tests.
- Windows execution of the CI hash job is still unverified until the first push.
