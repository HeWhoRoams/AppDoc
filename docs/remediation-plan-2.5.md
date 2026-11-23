# AppDoc v2.4.0 → v2.5.0 Remediation Plan

**Date:** 2026-11-13 (rev 2, 2026-11-23: status and amendments below)
**Basis:** `docs/diagnostic-2.4-comparison.md` (objective metrics + four independent deep-dives of the public 2.4 examples) and a line-level map of `appdoc/check.py`, `appdoc/fill.py`, `appdoc/extract.py`, `appdoc/facts.py`, `appdoc/scan.py` and `appdoc/stacks/*.py`.
**Goal:** fix the six systemic findings so the same class of failure cannot come back on a new run, a new Target or a new Stack — not just patch the four examples.
**Format:** follows the house remediation-plan convention (`remediation-plan-rev2.md`); every item carries a failing test (TDD) and a corpus case.

---

## Status and amendments (rev 2, 2026-11-23)

Checked against `origin/main` at `2e59393` (version 2.4.0, schema `/5`). `main` now holds the `v2.5.0` branch merged with the performance and integration work, so **there is one line**. No `v2.4.0` or `v2.5.0` tag exists on the remote.

### Implementation status

| Item | State on `main` | Evidence |
|---|---|---|
| 0.1 diagnostic in repo | Done | `docs/diagnostic-2.4-comparison.md`, `tests/diag_metrics.py`, `tests/test_diag_metrics.py` |
| 0.2 failure corpus (`tests/corpus/`, `tests/test_corpus.py`) | **Not started** | no `tests/corpus/` |
| 0.3 pin the metric baseline | Partly (the 2.4 values are pinned; confirm the "before" values still match) | `tests/test_diag_metrics.py::test_pinned_baseline` |
| 1.1 C14 | **Done** | `check._c14_unknowns` (commits ed4c099, db2589e) |
| 1.2 C15 | **Done** (English "N of M" matching, failing; 2.7 replaces it with count markers) | `check._c15_register_counts` (a7e2921) |
| 1.3 C16 | **Done** (advisory; fails under `--strict`) | `check` (8deea1b) |
| 1.4 owner context and advisory | **Not started.** `appdoc-context.md` is read today only for its ```` ```never-mention ```` block (`check._never_mention`); no `owner_file` Fact is emitted from it and there is no advisory | `check.py`, `citations.OWNER_CONTEXT` |
| 1.5 config role split (`env`, `ci`) | **Not started.** The post-pass only promotes `unclassified` to `app`. A `ci` role already exists for CI file names (`generic.config_role`) | `extract.extract`, `generic.py` |
| 2.1 aspnet_core Razor `ui_page`, EF `data_access`, HttpClient `external_call` | **Not started.** `ui_page` is emitted for XAML only | `aspnet_core.py` |
| 2.2 Go connection, schema, templates | **Not started** | `go.py` |
| 2.3 Flask SQLAlchemy connection | **Not started.** The shared integration catalog runs in the Flask stack but has no SQLAlchemy entry (database connections stay in the stack code) | `python_flask.py`, `stacks/integrations.py` |
| 2.4 conformance pins | **Not started** | `tests/test_conformance.py` |
| Phase 3 release (schema `/6`, ADRs 0011/0012, examples, CHANGELOG) | **Not started.** No ADR past 0010 except 0016 | `docs/adr/` |

Remaining effort: about **4.5 d** of the original 6 d (C14–C16 took about 10 h).

### What changed underneath the plan

`main` carries unreleased work that this plan was written before: the performance phases 0–4 (a process pool, `--workers`, a content-hash cache, `--skip-tests`, `--no-ownership`, `--ownership-top`) and the integration catalog and `System Connections` view (`stacks/integrations.py`, `appdoc/integration.py`). It has no version bump and a `## Unreleased` CHANGELOG section. Amendments:

- **A-1 Release content.** 2.5.0 ships that unreleased work too. It is additive (the `connection.type` vocabulary widened; no `SCHEMA` change of its own), and the `/6` bump below covers it. The CHANGELOG 2.5.0 entry absorbs `## Unreleased`.
- **A-2 R21 (new; superseded in 2.6 §4.6, no manual bump remains): extractor logic changes bump `extract.EXTRACTOR_VERSION`.** The per-file cache key is salted with `SCHEMA` and this constant. A change to what a Stack emits for a file is invisible to the cache unless one of them changes. Every Phase 2 item, and 1.5 if it adds a per-file detail key, bumps it in the same commit. (2.6 §4.6 replaces the manual constant with the bundle hash.) Test: `tests/test_cache.py::test_bumped_extractor_version_changes_key` already exists; add `test_phase2_items_bump_extractor_version`, which compares the constant with a pinned value in the Phase 3 commit.
- **A-3 The cache stores pre-promotion Facts** (`extract.py`: "the cache stores pre-promotion per-file facts, so warm==cold"). Therefore 1.5's role split must stay in the **post-pass**, and the read kind it needs (env var, CI file, other) must be a **per-file detail** emitted by the Stacks and recorded in `DETAIL_KEYS["config_key"]` (today `role secret_location source use via`; use `via` if it already names the read call, otherwise add `read_kind`). It must not depend on another file's content.
- **A-4 Phase 2 gets parallel and cache coverage for free but must be proven.** Each new sample file runs through `test_core::test_two_runs_are_byte_identical_for_every_sample` and `test_parallel`. Add one assertion per new capability that a warm-cache run (`use_cache=True` twice) and a `--workers 2` run give byte-identical `facts.json`.
- **A-5 `appdoc-context.md` has one parser.** 1.4 adds `Ownership:` lines; the file already carries a `never-mention` block, and 2.7 adds `Audit floor:` and 2.8 adds `Auth attributes:`, `Production config:` and `Reference year:`. Implement 1.4 with a small `appdoc/context.py` that returns every directive in one pass (2.8 W13 extends it) rather than a second ad-hoc reader beside `check._never_mention`.
- **A-6 Line numbers in this plan predate the performance refactor** (`extract.py:99-114` is now a function `extract.extract` with `_extract_file`, `_extract_all` and a post-pass). Locate by function name.
- **A-7 Examples layout.** `examples/` holds `eShop`, `flaskr-tdd`, `gitea`, `spring-petclinic` (2.4 runs at the old names) and `*-2.4` copies. 2.5 regenerates the four unsuffixed folders; 2.6 §7.2 migrates to `current/` and `previous/`.
- **A-8 Tags.** Create `v2.4.0` at `9241c2f` now (it exists in history and was never tagged), and `v2.5.0` at the 2.5 release commit (2.6 §3.0). The gate YAML still tells adopters to pin a tag that does not exist.
- **A-9 Amendments proposed in 2.6 §10 (A1–A3).** A1 (tags) is A-8 here. A2 (fix the gate YAML clone path and `--out`) and A3 (make C15 advisory) are **not applied**; C15 shipped as a failure. This is a recorded R6 exception; 2.7 demotes it.

---

## 1. Verdict on the 2.4 examples

All four public 2.4 docs **Check PASS** with every citation resolved. The 2.4 bump delivered the honesty features (retired candidates, config roles, version skew, per-claim C2) cleanly. The remaining quality gap is not structural — it is **first-draft accuracy** and **extractor coverage**. Six systemic findings recur across the set:

| # | Finding (evidence) | Where it showed up |
|---|---|---|
| F1 | **First-draft over-claiming.** The audit's Corrected rows are dominated by over-generalized claims ("any page", "all handlers", "one failing receiver faults the batch"). (The wrong/too-narrow *line-cite* half of this is already enforced by C11's anchor check; the gap is the over-generalization, which is caught only *after* the audit.) | All four (7–18 Corrected rows each) |
| F2 | **Answerable unknowns leak into §14.** Q-rows the auditor resolved (Answerable) are still listed, or silently dropped, creating a §14/register count mismatch. | spring (Q-5), gitea (Q-6/10/11/14; A.2 "14 \| 10 of 10"), eShop (Q-11/12/17) |
| F3 | **Extractor thin on the fact kinds the narrative needs most.** `ui_page` (XAML-only for eShop, none for gitea/flaskr), `external_call` (base-addresses only for eShop), `data_access` (Repository/`RegisterModel` only, no queries), `schema_object` (none for eShop/gitea/flaskr), `connection` (none for gitea/flaskr). The narrative compensates by hand. | All four |
| F4 | **Stale prose that references the register.** A hand-written sentence that counts register rows goes stale when the register changes; the render guard catches stale *blocks* but not stale *prose*. | spring (§15.1 "5 of 12" vs 7 of 13), gitea (V-11–V-14 added post-audit, "need a delta audit") |
| F5 | **Owner + deployment runbook structurally empty.** §11 ownership and §16.5 Rollback/Backup/Restore are Unknown in all four (shallow clones, no owner file). Honest, but the two most operationally useful sections are the emptiest. | All four |
| F6 | **Noisy generated config table.** The curated-config feature works, but the raw 16.6 block leaks non-app keys (`GO`, `SSH_ORIGINAL_COMMAND`, `ALLOWED_TYPES`) and mis-flags env vars as secrets; count mismatch (gitea facts 785 vs block 758). | gitea (10,601 keys), eShop (258) |

F1 and F4 are the same root cause (hand-written prose drifts from the evidence). F2 is a missing reconciliation. F3 is the biggest lever and is feature work. F5 and F6 are extractor/classification gaps.

---

## 2. Root causes

| # | Root cause | Findings | Fixed by |
|---|---|---|---|
| RC-A | **Prose that references the evidence is not re-validated against it.** A hand-written sentence (a count, a universal claim) is checked for *structure* (C3/C9) but not for *agreement with the register/Facts*. | F1, F4 | 1.2, 1.3 |
| RC-B | **§14 and the register are two sources of truth with no reconciliation.** The writer edits §14; the auditor edits the register; nothing checks they agree. | F2 | 1.1 |
| RC-C | **The extractors cover only a subset of the fact kinds the narrative relies on.** The doc is only as good as the human who fills the gaps the extractor leaves. | F3 | Phase 2 |
| RC-D | **Ownership is Unknown by absence, not by audit, and the doc does not say so.** No owner-context file is detected, so §11 is empty with no explanation. | F5 | 1.4 |
| RC-E | **Config role is decided before the read is classified.** An env-var read and a config-file read both become `app`, so the 16.6 table is polluted and env vars are mis-flagged as secrets. | F6 | 1.5 |

---

## 3. Rules for this release

Every item is checked against these in review (carried forward from rev2, R1–R7, plus two new):

- **R1 Reproduce first.** No fix merges without a test that fails on the `v2.4.0` tag and names the finding.
- **R2 Never weaken the Check to make an example pass.**
- **R3 Closed sets only.** A name may be hardcoded when an OS or tool specification defines it. A name people choose may trigger a question, never a behaviour.
- **R4 Generated blocks state what a script read.** No interpretation. Every truncated list says N of M. Every "none" says which Stacks could have produced it.
- **R5 One implementation per judgment.** Anything the tool prints for a human to run is executed by a test.
- **R6 Version honestly.** A change to `facts.json` output bumps `SCHEMA`. A change that fails committed documents bumps `TEMPLATE_VERSION`.
- **R7 House constraints.** Standard library only, `unittest` only, Python 3.10+, Windows and Linux.
- **R8 (new) A lint that is a heuristic is advisory, not a gate.** A rule that depends on English quantifiers or a fuzzy pattern is advisory by default and may fail only under `--strict`. It can never be the only thing standing between a doc and a PASS.
- **R21 (added in rev 2; superseded in 2.6 §4.6) The cache salt is `schema` plus `version.bundle_hash()`, so nothing is bumped by hand.** See A-2 for the interim rule.
- **R9 (new) The Check re-validates prose against the register, not just structure.** Any hand-written sentence that states a count of register rows or Facts is checked against the live value (RC-A).

---

## 4. Phase 0 — Reproduce and pin (do first)

**0.1 Commit the diagnostic.** `docs/diagnostic-2.4-comparison.md` is the evidence. Add a traceability table to this plan: finding → item → test name. (The objective metrics are reproducible via `tmp/diag_metrics.py`; move it to `tests/diag_metrics.py` and add a `tests/test_diag_metrics.py` that asserts the metric parser reads all six artifacts, so the diagnostic is itself pinned.)

**0.2 Build the failure corpus** under `tests/corpus/<case>/`: a Target of a few files plus a `docs/appdoc/` with a Narrative and register. One `unittest` module, `tests/test_corpus.py`, written to the *new* expected behaviour so every case is red on `v2.4.0`.

| Case | Contains | Asserts |
|---|---|---|
| `unknowns-leak` | §14 lists Q-5; the register has an `Answerable` row for Q-5; A.2 states 14 but §14 has 10 rows | C14 fails twice (resolved-in-14, A.2 count) |
| `stale-count` | §15.1 states "5 of 12 recommendations"; the register has 13 `R-` rows | C15 fails |
| `quantifier-cite` | A Cited claim "all handlers …" whose only citation is `app.py:40` (single line) | C16 advisory present; fails under `--strict` |
| `config-env` | `app.py` reads `os.getenv("DATABASE_URL")` and `config["DEBUG"]` from `appsettings.json` | The env key is role `env` (not in 16.6); the file key is role `app` (in 16.6); the env key is not `secret_location` |
| `owner-absent` | §11 all-Unknown; no `appdoc-context.md` at the Target root | Advisory: ownership Unknown by absence |
| `razor-ui` | An ASP.NET Core `.razor` page with a `@page` route | A `ui_page` fact is emitted (Phase 2) |
| `ef-data` | An ASP.NET Core `DbSet<T>` property and a `.ToListAsync()` call | `data_access` facts are emitted (Phase 2) |
| `go-conn` | A Go `sql.Open("postgres", dsn)` and `xorm.NewEngine` | `connection` facts are emitted (Phase 2) |
| `flask-sa` | A Flask `db = SQLAlchemy(app)` | A `connection` fact is emitted (Phase 2) |

**0.3 Pin the metric baseline.** Record the four examples' current metrics (from `docs/diagnostic-2.4-comparison.md` §1) in `tests/test_diag_metrics.py` as the "before" values; after Phase 3 the regenerated examples must not regress on Supported % or citations-with-line.

---

## 5. Phase 1 — Root-cause fixes (remediation; no new fact kinds)

### 1.1 §14 and the register must agree (RC-B, F2)

**Change**
1. New rule **C14** in `check.py`: `_c14_unknowns(lines, heads, ids, reg, add)`, called from `run` after `_c11_register` (which already parses the register into `reg`).
2. **Resolved-in-§14 clause.** Parse the §14 table with the existing `_spec_table(lines, heads, "14")` (check.py:259) to get the set of `Q-` IDs present. From `reg`, collect rows whose `ref` matches `Q-\d+` and whose `result` is `Answerable` or `Dismissed`. For each such ID that is *also* in the §14 table, fail:
   `f"section 14 lists {qid} but the audit resolved it ({row.id}, {row.result}); remove it from section 14 or record the answer in the row"`.
3. **A.2 count clause.** The `appendix-a` block (written by `fill._appendix_a`) carries an A.2 coverage table with a row `| 14 | <n> of <m> |` where `<m>` is the total number of `Q-` IDs the writer declared. Parse that row (`re.search(r"\|\s*14\s*\|\s*(\d+)\s+of\s+(\d+)\s*\|", appendix_block_text)`) and require `<m>` to equal the number of **distinct `Q-\d+` refs in the register**. If they differ, fail:
   `f"Appendix A.2 states {m} unknowns but the register carries {actual} Q-refs"`.
   (This is the gitea case: A.2 says `10 of 10` but the register has 14 Q-refs.)
4. `Dismissed` and `Answerable` are the only results that remove a Q from §14; `Supported`/`Corrected`/`Downgraded` rows for a Q-ref do not (a Q can be audited and still stand).

**Why this is not a weakening:** it only *adds* a consistency check between two artifacts the writer already maintains; it cannot be satisfied by deleting evidence.

**Tests:** `tests/test_check.py::test_c14_answerable_in_14_fails`, `::test_c14_a2_count_mismatch`, `::test_c14_supported_q_stays`. Corpus `unknowns-leak`.

**ADR:** new 0011 (register is the single source of truth for which unknowns stand).

### 1.2 Prose that counts the register is re-validated (RC-A, F4)

**Change**
1. New rule **C15** in `check.py`: `_c15_register_counts(lines, reg, add)`, called from `run`.
2. Scan the narrative (generated blocks masked, comments stripped — the same `lines` C11 uses) for the pattern `r"\b(\d+) of (\d+)\b\s+([A-Za-z-]+)"` (an "N of M" followed by a noun).
3. Map the noun to an ID class and require the **denominator** to equal the live count of that class in the register: `recommendation(s)`→`R-\d+`, `finding(s)`/`V-finding(s)`→`V-\d+`, `control(s)`→`10.1`/`10.2` rows, `unknown(s)`→`Q-\d+`, `row(s)`→total register rows. Nouns that map to no class are skipped (not every "N of M" is a register count). If a mapped denominator differs, fail:
   `f'states "{shown}" but the register has {actual} {noun}'`.
4. The numerator is not checked (it is a claim about a subset, which the audit covers); only the denominator is a count the tool can verify.

**Why this is not a weakening:** it verifies a number the tool already knows against the prose that states it; it cannot be satisfied by inflating the register.

**Tests:** `tests/test_check.py::test_c15_register_count_mismatch`, `::test_c15_correct_count_passes`. Corpus `stale-count`.

### 1.3 Universal claims with single-line cites are flagged (RC-A, F1)

**Change**
1. New rule **C16** in `check.py`: `_c16_quantifier(lines, cites_by_line, add, strict)`, called from `run`. `cites_by_line` is the per-line citation map C1 already builds.
2. For each line that is a Cited claim (carries a claim marker and ≥1 Citation) and whose sentence contains a universal quantifier from the closed set `{"all", "every", "any", "whole", "entire", "always", "never", "each"}` (R3: English, but advisory per R8), check whether **all** of its citations are single-line (`start == end`, no range). If so, report:
   `f"line {n}: a universal claim cites only single lines; cite the covering range or mark it Inferred"`.
3. **Advisory by default; failing under `--strict`** (the same pattern as C13 entry-points-not-cited). It is never the only thing between a doc and a PASS (R8).

**Why this is not a weakening:** it is advisory; it surfaces the #1 correction pattern (F1) *before* the audit instead of after.

**Tests:** `tests/test_check.py::test_c16_advisory_present`, `::test_c16_fails_under_strict`, `::test_c16_range_cite_not_flagged`. Corpus `quantifier-cite`.

### 1.4 Ownership is Unknown by absence, and the doc says so (RC-D, F5)

**Change**
1. `extract.py`: detect `appdoc-context.md` (`citations.OWNER_CONTEXT`) at the Target root. If present, emit an `owner_file` fact (kind already in `facts.KINDS`) and parse any `Ownership:` lines into `ownership` facts. If absent, emit nothing (the current behaviour).
2. New **advisory** in `check.py` (fold into C4, the gaps-declared rule): when §11 (ownership) is present and every row is `Unknown` **and** no `owner_file` fact exists, add:
   `"ownership is Unknown by absence (no appdoc-context.md); add one to fill section 11"`.
3. The same advisory applies to §16.5 when Rollback/Backup/Restore are all `Unknown` and no owner file exists: `"deployment runbook is Unknown by absence (no appdoc-context.md)"`.

**Why this is not a weakening:** it only makes an existing honest gap *explicit*; it does not assert ownership.

**Tests:** `tests/test_core.py::test_owner_context_detected`, `::test_owner_absent_advisory`. Corpus `owner-absent`.

### 1.5 Config role is decided after the read is classified (RC-E, F6)

**Change**
1. `extract.py` config post-pass (lines 99–114): today it promotes `unclassified`→`app` when a key is read from code. Split the promotion by **how** it is read:
   - an **env-var read** (`os.getenv`, `os.environ`, `os.lookupenv`, `Environment.GetEnvironmentVariable`, `getenv`, `os.Getenv`) → role `env`;
   - a read whose source file is a CI/build file (`.github/`, `Jenkinsfile`, `azure-pipelines*`, `*.pipeline.*`) → role `ci`;
   - any other code read of a config file → role `app` (the current behaviour).
2. `secret_location` is never set on `env` or `ci` keys (an env var is not an application secret). It is kept on `app` and `unclassified` keys, so an INI `[db] DB_PASSWORD` that no code reads keeps the flag. This removes the gitea mis-flags (`GO`, `SSH_ORIGINAL_COMMAND`).
3. `fill.py::_config_reference` (line 155) already filters `role == "app"`, so `env`/`ci` keys drop out of the 16.6 block automatically. Add to its trailer:
   `f"{env_n} env-var keys and {ci_n} CI keys are excluded from the application table (see facts.json)"`.
4. The 16.6 count (C7 `_c7_counts`) now compares against the `app`-role key count, so the gitea 785-vs-758 mismatch is resolved by construction.

**Why this is not a weakening:** nothing disappears — `env`/`ci` keys are still in `facts.json`, just not asserted to be application configuration (R4).

**Tests:** `tests/test_generic_facts.py::test_env_key_role_env`, `::test_ci_key_role_ci`, `::test_env_key_not_secret`; `tests/test_render.py::test_config_trailer_counts`. Corpus `config-env`.

**ADR:** amend 0009 (config role is evidence-based, split by read kind).

---

## 6. Phase 2 — Extractor coverage (feature work; the v2.5 lever, F3)

Each item adds facts for a kind the narrative already relies on. Every new capability is pinned by the conformance test (2.5) and a corpus case. These are separable from Phase 1: Phase 1 is pure remediation and lower-risk; Phase 2 is where new regexes are introduced.

### 2.1 ASP.NET Core: razor pages, EF data access, HttpClient calls

**Change** (`appdoc/stacks/aspnet_core.py`)
1. **`ui_page` from `.razor`.** In `_razor_pages` (line 327), in addition to the existing `entry_point` (type=page), emit a `ui_page` fact with `root` (the page path) and `route` (the `@page` directive). `ui_page` is already in the stack's `capabilities`.
2. **`data_access` from EF.** In `_data_and_calls` (line 259), add: `DbSet<T>` property declarations (`public DbSet<X> Y`) → `data_access` type=`ef` operation=`set`; and `DbContext` query calls (`.Where(`, `.ToListAsync(`, `.FirstOrDefaultAsync(`, `ExecuteSqlRaw(`) → `data_access` type=`ef` operation=`query`.
3. **`external_call` from HttpClient.** In `_data_and_calls`, add `HttpClient`/`IHttpClient` call sites (`.SendAsync(`, `.PostAsync(`, `.GetAsync(`, `.GetStringAsync(`) → `external_call` with the URL literal where present, `via="HttpClient"`.

**Tests:** `tests/test_facts_aspnet_core.py::test_razor_ui_page`, `::test_ef_dbset_data_access`, `::test_httpclient_external_call`. Corpus `razor-ui`, `ef-data`.

### 2.2 Go: connections, schema objects, template pages

**Change** (`appdoc/stacks/go.py`)
1. **`connection`.** Add `database/sql` `sql.Open(`, xorm `xorm.NewEngine(`, `sqlx.Open(` → `connection`. Add `connection` to the stack's `capabilities` (line 653).
2. **`schema_object`.** Add xorm `RegisterModel(` → `schema_object` type=`table` (the model name is the table). Add `schema_object` to `capabilities`.
3. **`ui_page` (shallow).** Count `templates/**/*.html` as `ui_page` facts with `root` = the template path (no deep parse — R4: state what a script read). Add `ui_page` to `capabilities`.

**Decision D2:** go `ui_page` is **count-only** (shallow). Deep-parsing Go templates is a separate, larger effort; the count closes the "UI catalog is source-only" gap (F3) without a new parser.

**Tests:** `tests/test_facts_go.py::test_go_connection`, `::test_go_register_model_schema`, `::test_go_template_ui_page`. Corpus `go-conn`.

### 2.3 Python Flask: SQLAlchemy connection

**Change** (`appdoc/stacks/python_flask.py`)
1. **`connection`.** In `_connections` (line 364), add the Flask-SQLAlchemy pattern `SQLAlchemy(app)` / `db = SQLAlchemy(...)` → `connection` type=`sqlalchemy`. (The existing `create_engine` pattern stays.) This closes the flaskr gap where the engine is created by Flask-SQLAlchemy from `DATABASE_URL`, not an explicit `create_engine`.

**Tests:** `tests/test_facts_python_flask.py::test_sqlalchemy_connection`. Corpus `flask-sa`.

### 2.4 Conformance test pins every new capability

**Change** (`tests/test_conformance.py`)
1. Extend the existing per-stack iteration: for each new capability added in 2.1–2.3, assert the stack's sample (`tests/samples/<stack>/`) contains a file that exercises it, and that the emitted fact's detail keys are a subset of `facts.DETAIL_KEYS[kind]`.
2. Add the sample files: a `.razor` page + `DbSet` + `SendAsync` (aspnet-core), a `sql.Open` + `RegisterModel` + a `templates/` file (go), a `SQLAlchemy(app)` (python-flask).

**Why this matters:** a Stack that emits a new kind without a sample and a conformance assertion cannot merge (the rev2 2.3 guard, extended).

---

## 7. Phase 3 — Release

1. **`facts.SCHEMA = "appdoc-facts/6"`** (R6): Phase 1.5 changes `config_key` role values and Phase 2 adds facts, so `facts.json` bytes change for unchanged code. `ci/appdoc-docs-gate.yml` pins `v2.5.0`.
2. **`TEMPLATE_VERSION` stays `2.4`.** No template *structure* changes: C14/C15/C16 are checks, the config trailer is a generated-block content change, and the owner advisory is a check message. No headings or table shapes change, so nothing is re-copied from the template.
3. **Upgrade notes for a 2.4 document** (all mechanical): re-run `extract`; run `appdoc build`; fix what it lists (expected: §14 rows the audit resolved, a stale "N of M" count, env keys now excluded from 16.6). No headings or markers change.
4. **ADRs:** new 0011 (register is the single source of truth for unknowns), 0012 (extractor coverage expansion); amend 0009 (config role split by read kind). CONTEXT.md gains **Register count**, **Unknown by absence**.
5. **Regenerate the four public examples** with v2.5.0, commit, and append a post-remediation section to `docs/diagnostic-2.4-comparison.md` showing the delta (Supported %, citations-with-line, §14/register agreement, 16.6 key count).
6. **CHANGELOG 2.5.0.**

---

## 8. Decisions needed

| # | Decision | Recommendation |
|---|---|---|
| D1 | C16 (quantifier lint): advisory-only, or failing under `--strict`? | Advisory by default, failing under `--strict` (consistent with C13; R8) |
| D2 | Go `ui_page`: count templates only (shallow) vs deep-parse? | Count only (shallow); deep-parse is a separate effort |
| D3 | Bump `SCHEMA` to `/6` (config roles + new facts change `facts.json`)? | Yes (R6) |
| D4 | Bump `TEMPLATE_VERSION` to 2.5? | No — no template structure change; stay 2.4 |
| D5 | Phase 2 (extractor) in this release or a separate 2.6 plan? | In this release, but as a separable phase (Phase 2) so Phase 1 can ship alone |

---

## 9. Order and effort

```
Phase 0  0.1 diagnostic in repo · 0.2 corpus (red) · 0.3 pin metric baseline      1 d
Phase 1  1.1 C14 §14/register reconciliation                                     4 h
         1.2 C15 register-count prose                                            3 h
         1.3 C16 quantifier advisory                                             3 h
         1.4 owner-context detection + advisory                                  3 h
         1.5 config role split env/CI                                            5 h
Phase 2  2.1 aspnet_core razor/EF/HttpClient · 2.2 go conn/schema/ui ·           2 d
         2.3 flask SQLAlchemy · 2.4 conformance pins
Phase 3  schema bump, ADRs, regenerate four examples, CHANGELOG                  1 d
                                                                    Total  about 6 d
```

1.1 goes first (it is the clearest correctness fix and unblocks the §14/register trust). 1.5 goes last in Phase 1 because it changes `facts.json` and needs the per-Target diff reviewed (the rev2 1.4 safety net). Phase 2 is separable: if the release window is short, ship Phase 1 + Phase 3 and defer Phase 2 to 2.6.

---

## 10. Done means

1. Every corpus case is red on `v2.4.0` and green on the release commit.
2. CI is green on ubuntu and windows, Python 3.10 and 3.13, with `APPDOC_CI=1`.
3. In all four regenerated examples: no §14 row has an Answerable/Dismissed register row; no "N of M" sentence contradicts the register; the 16.6 block contains only `app`-role keys and its count matches the Facts.
4. The conformance test passes for every new capability (razor `ui_page`, EF `data_access`, HttpClient `external_call`, go `connection`/`schema_object`/`ui_page`, flask `connection`).
5. `facts.json` for the four examples is byte-stable across two `extract` runs (determinism), and the metric baseline (0.3) shows no regression on Supported % or citations-with-line.
6. A document built with v2.4.0 fails the v2.5.0 Check with the specific C14/C15 messages, and passes after the three upgrade steps.
7. The traceability table from 0.1 has a test name against every finding (F1–F6).
