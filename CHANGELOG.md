# Changelog

## Unreleased

### Changed
- Six 2.7.0 additions that the 2.7 plan did not list are now recorded in `docs/remediation-plan-2.7.md` ("Changes made during implementation"): the C1 extensions for Go, protobuf, Ruby, PHP, Kotlin and Terraform files; `audit-plan --check`; the "Fix advisories" run step; auditors covering every row of a sampled section after any edit; `Audit floor:` percent syntax; and fill-before-seal (S6.1). ADR 0015 has an amendment for the last three audit rules.
- `doc_sha` masks the opaque generated blocks only. `scan-coverage` and `config-reference` stay in the fingerprint, so a Facts change that alters them reseeds the audit sample. Documented in ADR 0015 and plan 3.1; behaviour unchanged.
- The C17 scope rule is documented as implemented: any single digit in the scope line fails, not only a digit sequence.

- Per-row audit coverage. `audit-plan` plans one key `<section>/<slug>` per row: every 10.2 control with Status Present, every 16.5 and 17 row that is not Unknown or Not applicable, and the sampled section 9 rows (same floor, seeded by `doc_sha`). The slug is the first cell, lower-cased, non-alphanumerics to `-`, repeats suffixed `-2`, `-3`. The register `ref` of such a row is its key (`10.2/read-only-db-role`); C11 checks the key against the table, and C19 under `--require-audit` names each uncovered row and the ref to use. The plan file keeps the schema `appdoc-audit-plan/1` (the `ids` hold row keys and `items` the first cells). A.2 counts planned, audited and extra per row.
- `seal` also stamps per-row keys with `claim_sha` and `sealed_by`; Answerable, Dismissed and other section-level rows stay unsealed by design, and Appendix A and the comparison diagnostic say so (they no longer call them "mostly Corrected or Downgraded rows").

### Notes
- **Upgrade note:** a document audited under 2.7.0 fails C19 under `--require-audit` until its register has a row for each planned key in 10.2 (Present controls), 16.5, 17 and the sampled section 9 rows. Run `appdoc audit-plan`, audit the rows it names and add them with the refs it prints, then `appdoc seal --audit --date YYYY-MM-DD`. The old one-row-per-section refs (`10.2`, `16.5`, `17`, `9`) stay valid but cover nothing. Section 17 Command cells must hold exactly one command (planned, not yet in the code).

## 2.7.0

Template release. Template **2.7**; schema stays `appdoc-facts/7` (`audit-plan.json`, `notes.jsonl` and the new register keys are separate files). Plan: `docs/remediation-plan-2.7.md`; comparison with 2.6.0: `docs/diagnostic-2.7.0-comparison.md`.

### Upgrade notes (2.6.0 to 2.7.0)
A 2.6 document (template 2.4) fails C3 on 2.7.0 until it is upgraded once. Run these steps in order on each Target.
1. `appdoc upgrade <target>`. It adds what is mechanical (stamp 2.7, the `closed-questions` markers under section 14, section 17, the fixed 5.3 line, missing columns and rows), keeps every line of text (text that does not fit goes under an `appdoc:upgrade-orphan` comment that C3 fails on until you move it), re-extracts the Facts and fills the generated blocks. It never writes `evidence.jsonl`, `notes.jsonl` or `audit-plan.json` and never seals. It writes `docs/appdoc/UPGRADE-TODO.md`.
2. Work through `UPGRADE-TODO.md`; each item names the Check rule that fails until it is done. Move "Known extractor limitation" paragraphs to `notes.jsonl`. Shorten the audit `scope` to the method and move per-section caveats to `exclusions`. Fix severity order in 10.1 and 15 (C9), `answered_in` on Answerable rows, section 17 rows, and two live rows on one ref. If rows were deleted under 2.4, restore them from git history and add `supersedes` to the replacing row.
3. `appdoc build --expand-citations <target>`. It rewrites each bare file name that has exactly one full path to the full path, in the Narrative only (outside code fences and generated blocks). Bare names in register rows and notes are fixed by hand (C1 names the full path).
4. Replace hand-written counts with count markers (`<!-- appdoc:count V -->7<!-- /appdoc:count -->`); `fill` and `build` write the number. C15 lists what is still hand-written.
5. `notes.jsonl` for the limitations and answers that belong to a block (C18 checks that each note matches its block).
6. Fill section 17, Build, Run and Test Locally (one command per step, or `Not applicable` with the evidence that says why).
7. `appdoc audit-plan <target>`, then audit the planned IDs (and the finding candidates the plan lists), then `appdoc seal --audit --date YYYY-MM-DD <target>`. `audit-plan --check` prints whether the plan on disk is stale. The sample reseeds on every Narrative edit, so audit every row of the sampled sections in the final pass, after the last edit.
8. `appdoc build --require-audit --strict <target>`; commit `docs/appdoc/`. Update the `APPDOC_REF` pin in `.github/workflows/appdoc-docs-gate.yml` to `v2.7.0` (the shipped `ci/appdoc-docs-gate.yml` already pins it). The Facts schema is the same as in 2.6.0, so the gate does not exit 3 for this release.

Examples: `examples/current/` (2.7.0) is a fresh run, not an upgrade: new Narratives, an independent audit from `audit-plan.json`, sealed with `--audit --date`; `examples/previous/` is 2.6.0. The four 2.7.0 Checks pass with `--require-audit --strict`.

### Added
- Register history: rows may carry `supersedes` (an id or a list; a replaced row stays in the file) and `sealed_by` (`audit` or `upgrade`). The audit record on line 1 carries `audited_on`, `audited_with`, `audited_bundle` and `doc_sha`. C11 counts live rows; C10, C12, C14 and the Check's Verification read live rows only. Appendix A shows audit provenance, upgrade seals and superseded rows.
- `appdoc seal --audit --date YYYY-MM-DD` records the audit and seals unsealed rows as audited. C17 checks the provenance under `--require-audit` and `--strict`.
- `notes.jsonl`: notes rendered inside their block, sealed by `build` (empty `block_sha`), and C18 checks each note against its block.
- Computed audit scope: A.1 prints the scope line from the register; C17 on 2.7 fails an audit `scope` with an ID or a digit, and `exclusions` are whole sections.
- `appdoc audit-plan <target>` writes `docs/appdoc/audit-plan.json` (every finding, workflow, open question and finding candidate, full sections, and a seeded sample of the others with a 25% / minimum 5 floor); `audit-plan --check` is read-only (exit 0 equal, 2 stale or missing). C19: the audit follows the plan; A.2 shows planned, audited and extra.
- Count markers (`appdoc:count`, closed class list `template_spec.COUNT_CLASSES`): `fill` writes the number from the Facts or the register; C15 checks them and a hand-written "N of M" is an advisory.
- C9 severity order in 10.1 and 15; C1 full-path Citations (bare names fail, also in register rows and notes), and `build --expand-citations`.
- Closed-questions block (section 14) rendered by `fill`; Answerable rows need `answered_in`; A.2 lists missing E-IDs.
- Section 17, Build, Run and Test Locally (template, spec, C3 and C9 on 2.7).
- `appdoc upgrade <target>` (`appdoc/upgrade.py`, steps in `template_spec.UPGRADE_STEPS`) writes `UPGRADE-TODO.md`; corpus cases `upgrade-2-1` and `upgrade-2-6-to-2-7` replay the steps.
- Go and other extractor-read extensions are Citations (`go`, `rs`, `rb`, `php`, `kt`, `kts`, `proto`, `tf`; `mod` and `sum` line-only, plus the exact names `go.mod` and `go.sum`).
- SKILL.md and the template guide teach C16 and C20 (documented, not new), Needs-owner rows, whole-section exclusions, the final audit pass and count-free audit-state sentences. CONTEXT.md terms; ADR 0015 and 0017; ADR 0007 amended.

### Changed
- `TEMPLATE_VERSION` is 2.7. C3 is strict: a document must carry the running template's stamp (the 2.4 older-stamp window is removed), and C3 fails on an `upgrade-orphan` comment.
- The C1, C9 and C17 rules that 2.6.0 previewed as "fails from template 2.7" now fail on a 2.7 stamp.
- `seal` and `build` fill the non-opaque generated blocks before computing `doc_sha`, so the sealed hash matches the finished document.
- The skill's run order (SKILL.md, `appdoc/workflow.py`): upgrade, fix advisories, `audit-plan`, audit the planned IDs, apply findings, audit the delta, `seal --audit --date`, `build`.
- Check messages say why (section 17 Command cell; C1 on a backticked name that does not exist).
- `tools/release.py` rotation and the example folders also carry `audit-plan.json`.

### Known limitations
- Determinism is verified on Linux only: `extract --workers 1` and `--workers 4` reproduce the committed `facts.json` of all four examples byte for byte. The CI hash job has not run on Windows, so Windows is not verified.
- Audit exclusions are whole sections only: a generated block inside a section that has planned IDs cannot be excluded on its own.
- The audit-plan sample reseeds on every Narrative edit, so the final audit pass must cover every row of the sampled sections.
- Test-code finding candidates are not planned.
- A Needs-owner question needs a Supported row.
- The section 17 Command cell check accepts a short command chain, though the docs say exactly one command.
- A hand-written "N of M" is an advisory only (C15); only count markers are checked against the Facts.

## 2.6.0

Tooling, provenance and Facts release. Schema `appdoc-facts/7`; template stays 2.4. Plan: `docs/remediation-plan-2.6.md`.

### Upgrade notes (2.5.0 to 2.6.0)
1. Re-run `extract` on every Target. It writes the new `provenance.json` next to `facts.json` and `facts-summary.md`, and `facts.json` now carries schema `appdoc-facts/7` (typed capabilities, `scan.duplicate_folders`, `secret_ref`, no `generator` field, no author names in `ownership`). Then run `build`.
2. Expect advisories marked "fails from template 2.7" (C1 bare-name Citations, C9 severity order, C17 scope text) and the C7 duplicate-folder advisory. They need no action on a template 2.4 document; the duplicate-folder advisory asks you to name both folders in 2.1 and say which copy is live.
3. The docs-as-code gate exits 3 ("AppDoc upgraded") until `facts.json` is re-extracted and committed, because the schema changed. From 2.6.0 on, an AppDoc patch release with the same schema never trips the gate: the version in `provenance.json` is informational.
4. Update the `APPDOC_REF` pin in `.github/workflows/appdoc-docs-gate.yml` to `v2.6.0` (the shipped `ci/appdoc-docs-gate.yml` already pins it).
5. Examples: `examples/current/` (2.6.0) and `examples/previous/` (2.5.0) replace the unsuffixed and `*-2.4` folders. The 2.6.0 examples were regenerated mechanically from the 2.5.0 Narratives and registers with no new audit; Appendix A.1 says the generated blocks were regenerated after the audit. See `docs/diagnostic-2.6.0-comparison.md`.

### Added
- `provenance.json` sidecar (`generator`, `bundle` hash, `schema`, and `blocks_by` written by `fill`), replacing the `generator` field in `facts.json`; C7 reads it (ADR 0013). Appendix A.1 prints the AppDoc version and bundle that wrote the generated blocks.
- Stack `capabilities` live on the Stack class with `entry_point` subtypes; `stacks.capabilities_of` is the only lookup and `fill` names the Stacks that report a kind instead of a "not covered" list.
- Determinism harness (`tests.test_determinism`, `tools/artifact_hashes.py`, a CI job comparing hashes across the OS matrix), the shared `textnorm.normalize_text`, and ten corpus cases for 2.6.
- Extractor answer keys with precision and recall per Stack and kind (`eval/extractor_checks.py`, `eval/baseline.json`) and narrative answer keys for all four examples (`eval/score.py`); `tools/release.py` runs both and refuses a regression. `tests/test_scale.py` runs a 10,000-file tree.
- `appdoc gate <target> [--require-audit] [--strict] [--workers N]`: regenerates the Facts (no cache) and compares them with the committed `facts.json` (exit 2 "Facts changed" with a diff of at most 200 lines; exit 3 "AppDoc upgraded" when the schema differs), then runs the Check. The checkout-dependent fields (`target.commit`, `target.history`, git `ownership` Facts) are not compared. The gate YAML clones the pinned release to `$RUNNER_TEMP/appdoc-skill` and calls `gate` from there.
- C20 Citation precision (advisory; fails under `--strict`): a range over 100 lines as a claim's only lined Citation in sections 4, 7 and 10, and more than 5 Citations in a section 4 or 10.1 cell.
- Previews of template 2.7 rules, printed as "fails from template 2.7" and never failing a 2.4 document: C9 severity order in 10.1 and 15, C1 bare-name Citations (the message names the full path), C17 audit scope text with an ID or a digit.
- `tools/gen_docs.py` writes the generated blocks of README.md, SKILL.md and the gate YAML (`--check` for CI); `appdoc/workflow.py` holds the skill's steps; `tools/release.py X.Y.Z [--dry-run]` cuts a release; CI runs the gate self-test and `tests/test_release.py`.

### Changed
- Example layout and rotation: `tools/release.py` deletes `examples/previous`, moves `examples/current` to it, regenerates `current`, writes the `VERSION` files and `docs/diagnostic-<version>-comparison.md` (`test_release::test_examples_current_and_previous`).
- The cache key is salted with `version.bundle_hash()` (every file of the `appdoc` package) plus the Facts schema. `extract.EXTRACTOR_VERSION` is deleted; nothing is bumped by hand, and the first run after any AppDoc change is a cold run.
- `scan` records `retired_candidates` by folder name only and a new `duplicate_folders` list (`{a, b, files}`) for byte-identical folders; both lists collapse nested entries; test paths are never compared. `scan-coverage` renders both, capped at 10 each. C7 asks section 2 to name a duplicate pair (an advisory; it fails under `--strict`).
- Folders holding AppDoc output (`facts.json` with an `appdoc-facts/` schema, or a Narrative with the template stamp) and AppDoc skill bundles inside a Target are pruned and disclosed in 2.1; `.appdocignore` `!name` re-includes them.
- A config file with at least one key that code reads is promoted to `app` as a whole (INI `section.KEY` matches the code's `KEY`); `env` and `ci` keys are never promoted.
- Secret naming is segment-aware (`MIN_PASSWORD_LENGTH` is not a secret location); keys ending in `uri`, `path` or `file` carry the new `config_key` detail `secret_ref`.
- Generated copy uses one `plural()` helper everywhere; the A.4 verification label reads `**E-1** (section N), expect `path:line``.
- `ownership` Facts no longer record git author names (R18): they hold `commits`, `contributors` (a count) and `first_commit`/`last_commit` dates; `facts.DETAIL_KEYS` drops `authors`.
- The rendered HTML page no longer ends with a `Generated: <date>` footer: it read the clock, so two renders of the same Narrative differed (R13). Rendering twice is byte-identical (`test_render`, `test_determinism`).
- `facts.DETAIL_KEYS["entry_point"]` accepts `listener` (the Java Spring extractor already emitted it, and conformance now checks detail keys against the table).

### Fixed
- ASP.NET Core: one `HttpClient` call produced two `external_call` Facts (a plain `http` one and one with `via: HttpClient`); the `HttpClient` emission now supersedes the generic one at the same file and line.

## 2.5.0 — remediation of the 2.4 diagnostic

Schema `appdoc-facts/6`. Template stays 2.4. Re-run `extract`, then `fill` and `build`; the gate exits with "AppDoc upgraded" until `facts.json` is re-extracted and committed.

### Added
- **Owner context** (`appdoc/context.py`): one parser for `appdoc-context.md` (`never-mention` block, `Ownership: <role>: <value>` lines). `extract` emits `owner_file` and `ownership` Facts from it (values are never stored). When §11 or the §16.5 runbook rows are all Unknown and no owner file exists, the Check prints an advisory "Unknown by absence" (C4).
- **Config role split by read kind.** `config_key` gains `read_kind` (`env` or `file`); a post-pass assigns role `env`, `ci` or `app`. Only `app` keys appear in the application table; the 16.6 trailer counts the `env` and `ci` keys it excludes, and C7 compares the block with the `app` count. Env and CI keys are no longer `secret_location`.
- **Extractor coverage:** ASP.NET Core Razor `ui_page`, EF `data_access type=ef`, `HttpClient` `external_call`; Go `connection`, xorm `schema_object`, `templates/**/*.html` `ui_page`; Flask `SQLAlchemy(...)` `connection`. Each is declared in the Stack's capabilities and exercised by a sample.
- **Corpus** (`tests/corpus/`, `tests/test_corpus.py`): small Targets with expected Facts and Check output.
- ADRs 0011 (the register is the single source of truth for unknowns) and 0012 (extractor coverage); ADR 0009 amended.

### Changed
- `facts.SCHEMA` is `appdoc-facts/6`; `extract.EXTRACTOR_VERSION` is 2 (cache salt). Facts for Targets using the newly detected libraries change.
- The four public examples were regenerated from clean clones with 2.5.0 (see `docs/diagnostic-2.4-comparison.md`, "Post-remediation (2.5.0)").


### Added — the integration picture (content Phases 6a + 6b)
- **Widened the `connection.type` vocabulary** (an *additive convention* change — `KINDS` and `SCHEMA` in `facts.py` are unchanged). A shared catalog (`appdoc/stacks/integrations.py`) now detects the non-database system connections the per-stack extractors previously missed: `cache` (Redis/Memcached), `queue` (Kafka, RabbitMQ, SQS, pika, kombu, MassTransit, Confluent), `object_storage` (S3, Azure Blob, GCS), `grpc`, `ldap`, and `search` (Elasticsearch/OpenSearch), wired into the python, java, node and dotnet Stacks. Each yields a `connection` Fact with the correct `type`; `external_call.type` also accepts `grpc`.
- **A `System Connections` view** (`appdoc/integration.py`): a deterministic post-pass (not the AI Narrative) that aggregates the raw `connection`/`external_call`/`dependency` Facts into a system-to-system summary — per-type distinct drivers, counts, file/line provenance, a compact integration map, and the manifest dependencies. Rendered near the top of the Facts summary, and (when a Narrative is present) of the HTML page. It is a pure function of the Facts, so it is byte-identical across runs.
- Fixture `tests/samples/integrations/` plus `tests/test_integration_catalog.py` and `tests/test_integration_view.py`.

> **Extraction changelog note:** Phases 6a/6b are **additive** and on by default (no flag). Existing Samples' `facts.json` is byte-identical to before; `facts.json` only changes for Targets that actually use the newly-detected integrations. This is a *content* change, not a silent change to the default output of existing codebases — documented here so it is not mistaken for a regression.

### Changed — the cache key is now versioned (schema + extractor version)
- The per-file content-hash cache key (`.appdoc-cache.json`) is salted with the Facts `SCHEMA` and a manually-bumped `EXTRACTOR_VERSION` constant (new in `appdoc/extract.py`). A cache written by an older AppDoc build is never served to a newer one, so a schema or extractor-logic change cleanly invalidates stale entries. Default (no-flag) `facts.json` is byte-identical to before — the version bytes are part of the *key*, not the output. (Superseded in 2.6.0: the salt is the bundle hash and nothing is bumped by hand.)
### Fixed — `smtp` is now in the integration view vocabulary
- `smtp` (a Spring-XML mail-sender `connection`) is a canonical type in the view's `TYPE_ORDER`/`TYPE_LABEL` (rendered "Email (SMTP)"), so it groups with the canonical list instead of appearing as an orphan "Smtp" row sorted after it.

## 2.4.0

Remediation release: fixes the five root causes found in the v2.3.0 comparative analysis (`docs/comparison-2.3/`). Plan: `docs/remediation-plan-rev2.md`. Decisions: ADR 0006 amendment (C2 per-claim, binary rule), ADR 0007 amendment (exact match, `claim_sha`), ADR 0010 (evidence-based classification, retired candidates).

### Added
- **`appdoc build <target>`**: runs seal → fill → check → render (render only when the Check passes) and returns the Check's exit code. The mechanical tail is one command.
- **`appdoc seal <target>`**: writes `claim_sha` (12-hex SHA-1 over the normalised text a register row's ref points to) into every ID/workflow row that lacks one. Never overwrites an existing seal.
- **`appdoc --version`**: prints the version and a deterministic bundle hash.
- **C11 claim_sha checks** (active on template 2.4): an ID or workflow row with no `claim_sha` → "not sealed; run `appdoc build`"; a `claim_sha` that differs from the document → "the text changed after it was audited"; two rows for the same ID ref → "keep the row that describes the current text". `Dismissed` and `Answerable` rows are exempt.
- **Render guard**: `render` refuses (exit 2) when a generated block differs from what `fill` would write, so stale HTML cannot be published by calling `render` alone.
- **C1 binary rule**: a lined Citation into a binary file (NUL byte in the first 8 KiB) fails; cite it without a line.
- **C2 per-claim**: every 10.1 row's Evidence cell and every 10.2 row with status `Present` must carry at least one lined Citation. A bare mention stays a resolved Citation (C1) but does not satisfy C2.
- **`register.locate(root, row)`**: finds the (path, line) where a row's anchor appears exactly (case-sensitive, single line). A.4 verification commands are printed from that location.
- **Stack conformance test** (`tests/test_conformance.py`): for every stack, asserts kind validity, path existence, line range, detail-key subset (`facts.DETAIL_KEYS`), no secret shapes, determinism, and capability coverage.
- **Version-skew detection**: `facts.json` carries a `generator` field; C7 fails when it differs from the running version in major.minor. `check-report.md` prints the running version.
- **Capability-aware "none"**: a generated block with no rows names the stacks that can report them and those that cannot.
- **Retired-code candidates**: `scan` records folders that look retired by name (token match: `old`, `bak`, `backup`, `archive`, `deprecated`, `retired`, `obsolete`, `unused`, `copy`, `trash`, `deleteme`, `to be deleted`) or by content (≥5 files, ≥half byte-identical to a file outside). Rendered in scan-coverage as "Folders that look retired (not excluded)". C7 requires section 2.1 to name a name-signal candidate.
- **OS/authoring metadata drop**: `desktop.ini`, `Thumbs.db`, `.DS_Store` and `_vti_` folders are excluded in `scan.walk` under a named rule and counted in scan coverage.
- **Config role `unclassified`**: the default. Promoted to `app` only on positive evidence (framework-defined names, or a key read from code). A `.properties`/`.yml` file with a sibling `<base>_<ll>[_<CC>].<ext>` is a bundle (role `None`).
- **Config-reference trailer**: "K keys in F files were not classified as application configuration: … (see facts.json)".
- **Entry-points headline**: "N route handler files (K under folders that look retired)".
- **`facts.DETAIL_KEYS`**: allowed detail keys per kind (conformance guard).
- **Stack `capabilities`**: each stack module declares the Fact kinds it can emit; the `stack` Fact carries them in `facts.json`.
- ADR 0010 (evidence-based classification, retired candidates). CONTEXT.md: **Retired candidate**, **Unclassified config**, **Seal**.

### Changed
- Facts schema `appdoc-facts/5`; template 2.4; `ci/appdoc-docs-gate.yml` pins `v2.4.0`.
- C11 anchor verification uses `register.locate` (exact, case-sensitive, single line) instead of whitespace-normalised cross-line match.
- A.4 verification commands use the located path and line, not the first cited path.
- `check` is read-only; `build` is the only command that writes.
- SKILL.md "Run" shrinks to: extract, orient, write, **build until it passes**, audit in a fresh agent, **build**, report.

### Fixed
- A.4 commands pointed at the wrong file when a register row cited multiple files (RC1).
- Binary database files were cited with line numbers (RC3).
- Stale Appendix A and findings without register rows went undetected (RC4).
- `To be deleted/` and similar folders were silently pruned by name (RC2).
- Config files were classified as `app` without evidence (RC2).

### Upgrade notes (2.3 → 2.4)
All mechanical: re-run `extract`; change the stamp to 2.4; run `appdoc build`; fix what it lists (expected: anchors not on one line, `:1` on binary files, duplicate ID rows, retired folders to name in 2.1). No headings or markers change.

## 2.3.0

Adds content depth: the extractor surfaces finding candidates, jobs, schema objects, UI pages and ownership files, and the Check requires the writer to address them. Plan: `plans/2026-11-11-appdoc-v2.3-plan.md`. Decisions: `docs/adr/0008-finding-candidates.md`, `docs/adr/0009-curated-config-reference.md`.

### Added
- **Go Stack** (`stacks/go.py`): routes (`net/http`, chi, gin, echo, gorilla, gitea-style groups), CLI commands, cron and scheduled jobs, config reads.
- Facts schema `appdoc-facts/4` with new kinds `smell` (finding candidate), `schema_object` (DDL tables, columns and indexes, with index expressions such as `LOWER(name)`), `owner_file` (`CODEOWNERS`, `MAINTAINERS`, `OWNERS`, `CONTRIBUTING.md`; entry counts only, never names or emails) and `ui_page` (MAUI/XAML pages). `config_key` carries `use` (`define` or `read`); `entry_point type=job` carries `schedule` and `enabled`.
- Seven finding-candidate patterns: `logger-type-mismatch`, `flash-without-redirect`, `distinct-auth-errors`, `unescaped-template-output`, `state-change-on-get`, `actuator-exposed`, `hardcoded-credential-constant`. Credential values are never recorded.
- Flask config definitions (`from_object` modules, `app.config[...] = ...`) and ASP.NET Core MVC views returned by controller actions.
- Template 2.3: generated blocks `entry-points` (section 4), `scheduled-jobs` (new 16.7) and `appendix-a` (end of document); the Check treats them as opaque blocks. 5.3 carries a fixed Restriction line. Section 11 requires six owner rows.
- Check rules: C7 compares prose counts ("five controllers") with the Facts; C10 requires every section 4 Area in 5.3 and every 16.6 effect-table Key to be a `config_key` Fact; C11 fails an `Answerable` question still open in section 14 and anchors over 200 characters or spanning lines; **C12** requires every finding candidate to be cited in 10.1 or `Dismissed` in the register.
- Advisory **Entry points not cited** in `check-report.md`; `check --strict` fails on it.
- Register results `Dismissed` (ref `smell/<id>`) and `Answerable` (ref `14/Q-n`).
- Appendix A in the Markdown: audit state, coverage, register table and verification commands, written by `fill` from `evidence.jsonl`.
- `eval/score.py` answer-key scorer and `eval/answer-keys/`.
- ADR 0008 (finding candidates) and ADR 0009 (curated config reference).

### Changed
- `node-express` is detected only when a `package.json` lists an `express` dependency; a frontend workspace with Playwright tests is no longer labeled an Express Stack.
- 16.6 is a curated generated list: secret locations first, definitions before reads, capped at 150 with a computed "N of M shown" line; commented defaults are counted, not listed.
- The citation parser accepts bare names such as `Procfile`, `Dockerfile`, `Makefile` and `MAINTAINERS`.
- The facts summary lists finding candidates (with ids), schema objects, UI pages, ownership files and scheduled jobs.
- `fill` writes the `appendix-a` block, so run it again after the audit. `ci/appdoc-docs-gate.yml` pins `v2.3.0`, detects schema `/4` as an AppDoc upgrade and runs `check --require-audit`.
- SKILL.md: new writing rules (finding candidates, config and findings, framework defaults, ownership files, resume with `check`), the audit now classifies section 14 questions and finding candidates, and part agents own `entry-points` coverage.

### Fixed
- Flask `USERNAME`-style reads no longer appear as "Defined at"; a module constant loaded by `from_object` (`SECRET_KEY`) is listed.
- gitea reports `go` as supported instead of "generic only".
- A correct Cited claim on an extensionless file no longer has to be downgraded to Inferred to pass C1.
- A narrative sentence such as ``token: `portal/a/long/path/file.asp:123` `` is no longer flagged as a high-entropy secret: a value that is a file path or Citation is skipped. Real secret values, including backticked ones, are still found.
- Citations: `.gitignore:5`, `.dockerignore:2`, `.editorconfig:1`, `test.db:1` and similar dotfiles and data files (`.sqlite`, `.lock`, `.cfg`, `.conf`, `.pem`, ...) are accepted when they carry a line; code members such as `Session.Timeout:20` or `self.db` are not. Paths with spaces (`To be deleted/FrontCounterDev/logcall.asp:212`) are accepted and resolve against the Target.
- 16.6 no longer lists test fixtures, test data and tooling files as application keys: config under test, fixtures, testdata and e2e folders is marked as test code, and config under tools, scripts, docs, examples, contrib and editor folders gets role `build`. JSON, `.env` and .NET config now get a role too.
- JSON config keys are attributed to their own line: `Identity:Scopes:orders` in `appsettings.json` points at the `"orders"` key under `Scopes`, not the first `"orders"` value in the file.
- SKILL.md: run `fill` again after the audit and rewrite the 15.1 and 2.1 audit sentences; run `check` last; a Supported register row always needs a Citation and an anchor; an `Answerable` question is removed from section 14 and answered in the body.

### Removed
- `render` no longer injects its own copy of the Evidence Register as Appendix A; the HTML renders the Appendix A block from the Markdown.

### Upgrade notes (2.2 documents)
A 2.2 document fails with one C3 problem until it is upgraded; C8-C12 are not run on it.
1. Re-run `extract` (schema 4).
2. Change the stamp to `<!-- appdoc:template 2.3 -->`. Copy the `entry-points` block (in 4), the 16.7 heading with its `scheduled-jobs` block, and the Appendix A heading with its `appdoc:generated appendix-a` block from the template; run `appdoc fill`.
3. Add the fixed Restriction line under the 5.3 table, and the six required rows to section 11 (Business owner, Technical owner, Process owner, Data and integration owners, Documentation owner, Release and change process).
4. Remove any hand-written count the new blocks now cover, or make it match.
5. Write the audit register: a row for each finding candidate (cite it in 10.1 or `Dismissed` with a reason) and each section 14 question that the source can answer (close it). Run `fill` again, then `check` until it passes.

## 2.2.0

Moves what can be counted or enumerated out of the AI's hands, makes the Template a contract the Check reads, and turns the Evidence Register into data. Plan: `plans/2026-11-11-appdoc-v2.2-remediation-plan-rev2.md`.

### Added
- `appdoc/template_spec.py`: headings, table columns, ID prefixes (F-, UI-, C-, X-, V-, Q-, R-), allowed values and required rows, in one place.
- `appdoc fill`: writes the generated blocks (2.1 scan coverage, 16.6 Configuration reference) from `facts.json`.
- Evidence Register as `docs/appdoc/evidence.jsonl` with an audit record (performed, auditor, scope) and a literal **Anchor** per row. `render` computes counts and per-section coverage and appends it as Appendix A; an audit declared not performed shows as a banner.
- Check rules C9 (Tables conform), C10 (References resolve), C11 (Register valid); C6 now scans every published file; C7 compares 4.1 file counts and generated blocks with the Facts. `check --require-audit`.
- Template 16.6 Configuration reference; 16.5 requires Build, Test, Deploy, Upgrade, Rollback, Backup, Restore and Secret rotation rows; 10.1 and 14 are tables with Severity and Priority; 10.2 statuses Verified absent / Not established / Present; 8.5 is keyed by 8.1 and 8.3 IDs.
- INI config reader (keys and sections, never values; commented keys recorded as documented defaults).
- `.appdocignore` `!name` re-includes a folder that would be pruned.

### Changed
- Facts schema `appdoc-facts/3`: `target.scan` reconciles files found = scanned + pruned + ignored and lists each pruned folder with its rule; `config_key` carries a `role`. Lockfiles and i18n message bundles no longer produce config keys.
- Folders are pruned on evidence, not by name: nested `packages/`, `build/`, `bin/`, `dist/`, `out/`, `target/` and `vendor/` folders that hold source are now scanned (gitea's package registry and `build/` were missing from 2.1 Facts).
- The section 1 table of contents comes from `render`; section 1 keeps the support cross-reference only.
- `ci/appdoc-docs-gate.yml` pins the AppDoc release and reports an AppDoc upgrade separately from a code change.

### Removed
- `verification.md` and its free-text summary line and Corrections section (replaced by `evidence.jsonl`).

### Upgrade notes (2.1 documents)
A 2.1 document fails with one C3 problem until it is upgraded; C8-C11 are not run on it.
1. Re-run `extract` (schema 3).
2. Add `<!-- appdoc:template 2.2 -->` under the title, and the two `appdoc:generated` marker pairs from the template (in 2.1 and 16.6); run `appdoc fill`.
3. Bring each table header to the template: add `Area` to 4, `Features` to 4.1, `ID` to 6 and 8.1; turn 10.1, 10.2, 14 and 8.5 into the template tables; add the eight 16.5 rows; renumber IDs to the template prefixes.
4. Convert `verification.md` to `evidence.jsonl` (one row per claim, with an anchor copied from the cited lines) and delete `verification.md`.
5. Run `check` until it passes.

## 2.1.0

Closes the structural gaps found by comparing four generated examples with the Help Desk reference document.

### Added
- Template: header line and reading legend; quick cross-reference table; 4.1 Subsystem inventory; 5.1-5.3 roles, enforcement and capability matrix; 8.4 Data entities and sensitivity; 8.5 Failure, fallback and observability; 10.1/10.2 findings vs unknowns that must not be treated as controls; 15.1 Coverage summary; 16.1-16.5 runbook subsections; table schemas for sections 4, 6, 8, 11, 13, 15 and 16.
- Check rule C8 (Structure complete): required numbered subsections exist and have content.
- `verification.md` carries an Evidence Register with re-run commands; `render` appends it to the HTML as Appendix A.

### Changed
- SKILL.md: config-file citation precision, per-workflow failure lines, thin-section rules, and a resumable subsystem-by-subsystem workflow for large Targets.
- Documents written for 2.0.0 fail C8 until the new subsections are added.

## 2.0.0

AppDoc is rebuilt as a small, portable skill. See `docs/adr/0004-facts-plus-narrative.md`.

### Changed
- Scripts now extract **Facts** only; the AI writes the **Narrative** from a fixed Template and may read source, citing every claim.
- Python 3.10+ (standard library only) replaces PowerShell 7.2+.
- One entry point, `SKILL.md`, and three commands: `extract`, `check`, `render`.
- Output is one Markdown document in 16 sections plus the Facts file, the Facts summary, a Check report and a rendered HTML page, under `docs/appdoc/`.
- Claim labels reduced from five to three: Cited, Inferred, Unknown.
- Config files are never read for values; extractors record key names and locations only.
- Theming is a replaceable CSS file (CMU theme by default).

### Added
- `check`: pass/fail problem list (rules C1 to C7), including a secret scan, with a Citation register.
- Facts summary for large Targets.
- Optional `appdoc-context.md` owner notes and `.appdocignore`.
- Stack extractors for Classic ASP, ASP.NET (Web Forms and MVC 5), ASP.NET Core, Java Spring (with Struts, JSP and MyBatis), Python Flask and Node/Express, with a generic fallback for everything else.

### Fixed after first install test
- C1 accepts folders and unique bare filenames; ignores extensionless spans that are not files.
- Facts summary says empty lists are not proof of absence, shows git history, and excludes test-code Facts.
- Ownership only with full git history; `target.history` recorded.

### Removed
- The scored validation gate and its 15 components, the pristine report, the evidence graph and canonical metrics.
- The redaction subsystem and exit-3 path, semantic enrichment and quarantine, generation profiles, theme JSON and masthead options.
- Golden-output test suites, Copilot prompt wrappers, the self-generated `docs/` and its drift check.
- Roslyn and TypeScript AST parsers.

1.x (PowerShell) remains available at the `v1.1.0` tag.
