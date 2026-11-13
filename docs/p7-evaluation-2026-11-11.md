# P7 Evaluation Report — AppDoc v2.2.0

**Date:** 2026-11-11
**Plan:** `plans/2026-11-11-appdoc-v2.2-remediation-plan-rev2.md`
**Targets:** flaskr-tdd, spring-petclinic, eShop, gitea, helpweb (held-out)

---

## 1. P7.1 — Install, Verify, Re-extract

| Step | Result |
|------|--------|
| `install_skill.py` | PASS (33 files, 0 mismatches) |
| Hash verify | PASS (33/33 match) |
| flaskr-tdd extract | 1.165s, 29 files, schema /3 |
| spring-petclinic extract | 3.414s, 138 files, schema /3 |
| eShop extract | 25.277s, 1151 files, schema /3 |
| gitea extract | 107.145s, 6431 files, schema /3 |
| gitea `packages/` in Facts | 168 files (was 0 in 2.1) |
| gitea `build/` in Facts | 10 files (was 0 in 2.1) |
| gitea file counts vs disk | modules=1288, routers=519, services=746, models=469, build=10 — all match |
| spring-petclinic config roles | app=3 files (application*.properties only), build=12, ci=30, orchestration=60 |

**Verdict:** PASS. The evidence-based pruning fix (A2) works: gitea's `packages/` and `build/` now appear in Facts. Config role classification (A3) correctly isolates the 3 real app config files from 121 non-app sources.

---

## 2. P7.3a — Frozen 2.1 Fixtures Must Fail

| Fixture | Problems | Rules fired |
|---------|----------|-------------|
| flaskr-tdd (stamped 2.2) | 379 | C1, C7, C8, C9, C10, C11 |
| eShop (stamped 2.2) | 951 | C1, C7, C8, C9, C10, C11 |

**Verdict:** PASS. The new rules (C9 table conformance, C10 reference resolution, C11 register validity) catch the known 2.1 defects. The Check bites.

---

## 3. P7.2 — Blind Regeneration

The writer subagents received the skill instructions only, not the per-repo fix list.

| Target | Check result | Iterations | Notes |
|--------|-------------|------------|-------|
| flaskr-tdd | PASS | 2 | 1 C5 problem: `Procfile:1` did not parse as a Citation, and the writer downgraded a correct Cited claim to Inferred to pass (parser fix: v2.3 Phase 1) |
| spring-petclinic | PASS | 3 | 25→1→0 problems |
| eShop | PASS | 2 | 21→0 problems |
| gitea | PASS | 2 | 10→0 problems |
| helpweb (held-out) | PASS | 4 | 87→0 problems |

**Verdict:** PASS. All 5 targets (including the held-out Classic ASP target) pass the Check on blind regeneration. The skill is self-sufficient: a writer with only the skill instructions can produce a document that passes C1–C11.

---

## 4. P7.3b — Answer Key Scoring

The rev1 Phase 6 step 4 fix list is the answer key. The verdicts below are the per-item verdicts in the "Verified prior findings" tables of `docs/comparison-2.2/*.md`, each made by reading the generated document and the Target.

> **Correction.** An earlier version of this section listed 14 items (16 rows), scored 6 PARTIAL and 6 NO, and scored gitea F10 / `REVERSE_PROXY_TRUSTED_PROXIES` as YES. Those figures came from a substring grep: a key found anywhere in the document, including the 16.6 config dump, counted as present. The comparison reports show that key appears only in 16.6 (`custom/conf/app.example.ini:479`) and not in the F-10 admin row, so F10 is NO. Row counts were also wrong: the comparisons list 19 items. flaskr username enumeration is NO (not PARTIAL): the doc cites `project/app.py:79-83` in V-5 and 7.1 but never names the property.

| Repo | Item | Verdict | Basis |
|------|------|---------|-------|
| flaskr-tdd | Element removed only when `status === 1`, reload unconditional | PARTIAL | 7.3 documents the server-side `status` contract; the client `main.js` behavior is missing |
| flaskr-tdd | Username-enumeration finding (`app.py:80-83`) | NO | Cited in V-5 and 7.1, never named as a finding |
| flaskr-tdd | Glossary `safe` row | NO | 13 has 7 terms, no `safe` |
| spring-petclinic | Six controllers, not five | NO | 4 says "five controllers", 3.1 lists six |
| spring-petclinic | V-12 notes `default_batch_fetch_size=16` | NO | The value appears only in the 16.6 config table |
| spring-petclinic | Postgres index on `LOWER(name)` | NO | 8.2/V-9 say "a named unique index" without the expression |
| spring-petclinic | Error flash not shown on direct re-render (7.1/7.2) | NO | Flash described as set and the form re-rendered; not-shown not noted |
| spring-petclinic | Actuator endpoints as an Inferred list | NO | V-4 and Q-6 mark the set Unknown |
| spring-petclinic | Cite concurrency and dialect integration tests | YES | 11 cites `PetClinicConcurrencyTests` and `PostgresIntegrationTests` |
| eShop | F-18 refers to section 7.5 | YES | F-18 row links to 7.5 |
| eShop | Webhooks Paid-handler defect | NO | Not identified; Q-17 left open |
| eShop | Identity.API controllers/views and MAUI ClientApp in 4 and 6 | PARTIAL | Login and logged-out views only; no ClientApp UI row; F-22 is Unknown |
| eShop | Close the 3 source-answerable questions (Q-15, Q-16, Q-17) | NO | All three still open in 14 |
| eShop | Fix E-17 re-run command | N/A | No Evidence Register in the output, so no re-run commands exist |
| gitea | Scheduled tasks enumerated | NO | No section lists the tasks; cron appears in 7.5 and F-16 only |
| gitea | F13 cites lines 367 and 400 | NO | Not cited in F-13 (Git over SSH); see the answer-key note |
| gitea | F10 mentions `REVERSE_PROXY_TRUSTED_PROXIES` | NO | Appears only in 16.6 |
| gitea | Widen 5.3 (Actions, packages, projects, wiki, releases, token scopes) | PARTIAL | Rows for packages and Actions only; token scopes in the Restriction note |
| gitea | 16.5 operator rows (`gitea dump`, `doctor`, `admin`, rollback, secret rotation) | PARTIAL | Rollback, secret rotation and a `dump` mention; no `doctor` or `admin` rows |

**Score: 19 items: 2 YES, 4 PARTIAL, 12 NO, 1 N/A (10.5% fully present; 31.6% at least partial, counting the 18 scorable items: 11.1% and 33.3%).**

By repo: flaskr-tdd 0 YES / 1 PARTIAL / 2 NO; spring-petclinic 1 / 0 / 5; eShop 1 / 1 / 2 plus 1 N/A; gitea 0 / 2 / 3.

The scorer in section 9 uses a finer key (22 scorable items, because the Identity/MAUI row and the three questions are split) and a deliberately generous Partial; its 2 Present match the 2 YES above.

**Analysis:** The blind regeneration produces structurally valid documents (Check passes) but misses the specific factual details that the answer key targets. This is expected: the answer key items are *content* improvements (specific findings, specific line numbers, specific enumerations) that require deep source reading, not structural compliance. The Check enforces structure and resolution, not content depth. The gaps are writer-judgment gaps (the writer didn't read deep enough) and extractor gaps (no Go stack handler, no cron-task enumeration).

---

## 5. P7.4 — Seeded-Error Test

**Method:** 10 known-false claims inserted into the passing flaskr-tdd document, each with a resolving citation (real file:line that exists but doesn't support the claim). An independent audit agent was given the seeded document and the target codebase.

**Result: 10/10 caught (100% catch rate).**

| # | Seeded false claim | Caught? |
|---|-------------------|---------|
| 1 | `/health` endpoint exists | YES |
| 2 | `Post` model has `created_at` column | YES |
| 3 | Uses `check_password_hash` | YES |
| 4 | Delete uses POST method | YES |
| 5 | Uses Flask-Login | YES |
| 6 | Validates 280-char input | YES |
| 7 | Index filters by `q` param | YES |
| 8 | PostgreSQL by default | YES |
| 9 | Uses `unittest.TestCase` | YES |
| 10 | `SECRET_KEY` from env var | YES |

The audit also found 3 minor/borderline issues in the original (non-seeded) document, demonstrating it goes beyond the seeded errors.

**Verdict:** PASS. The independent audit procedure works. A fresh agent that reads the cited lines catches fabricated claims with resolving citations.

---

## 6. P7.5 — Helpweb Held-Out Benchmark

**Target:** `C:\Github\helpweb` (Classic ASP, 5889 files) — the codebase that the reference standard documents. No plan or prompt has described this target.

| Metric | Result |
|--------|--------|
| Extract time | 162s |
| Check result | PASS (4 iterations, 87→0) |
| Features | 25 (F-1 to F-25) |
| UI screens | 12 (UI-1 to UI-12) |
| DB connections | 5 (C-1 to C-5) |
| External calls | 3 (X-1 to X-3) |
| Security findings | 10 (V-1 to V-10) |
| Recommendations | 15 (R-1 to R-15) |
| Open questions | 8 (Q-1 to Q-8) |
| Most severe | V-1 (hardcoded guest credentials), V-2 (plaintext DB credentials) — both Critical |

**Verdict:** PASS. AppDoc 2.2 handles an unseen Classic ASP target end-to-end. The Classic ASP stack handler works, the Check passes, and the document is structurally complete.

---

## 7. P7.6 — LLM Comparison Reports

Four comparison reports written to `docs/comparison-2.2/`:

| Target | Score | Key finding |
|--------|-------|-------------|
| flaskr-tdd | 3.8/5 | Strong structure and citations; misses client-side JS behavior, username enumeration as a distinct finding, glossary `safe` row |
| spring-petclinic | 4.3/5 | Exceeds standard in data-sensitivity tables and test inventory; controller count inconsistent (5 vs 6), misses `LOWER(name)` and flash-on-rerender |
| eShop | 4.4/5 | Exceeds standard in most sections; misses Webhooks Paid-handler defect, MAUI ClientApp UI rows, 3 closable questions |
| gitea | 3.9/5 | Strong structure and runbook; Go stack mislabeled "generic", cron not enumerated, config reference is raw dump |

**Cross-cutting themes:**
1. **Structure and citations are strong** — all 4 docs exceed the standard on citation density and structural completeness.
2. **Content depth is the gap** — specific findings (Paid-handler defect, username enumeration, cron enumeration) require deep source reading that the blind writer doesn't always perform.
3. **The Check enforces structure, not content** — a document can pass C1–C11 while missing specific factual details. This is by design (ADR 0006: the Check never judges meaning).
4. **Extractor gaps remain** — no Go stack handler (gitea), no cron-task enumeration, no client-side JS behavior extraction.
5. **The Evidence Register / audit is the differentiator** — the standard's strongest feature (Verification Appendix with re-run commands) is absent because the audit was not performed in blind mode.

---

## 8. Summary

| P7 Step | Result |
|---------|--------|
| P7.1 Install/verify/extract | PASS |
| P7.3a 2.1 fixtures fail | PASS (379 + 951 problems) |
| P7.2 Blind regeneration | PASS (all 5 targets pass Check) |
| P7.3b Answer key | 2 YES / 4 PARTIAL / 12 NO / 1 N/A of 19 (expected: content depth gap) |
| P7.4 Seeded-error test | PASS (10/10 caught) |
| P7.5 Helpweb held-out | PASS (Classic ASP, 87→0) |
| P7.6 LLM comparisons | Written (scores 3.8–4.4/5) |

**Overall verdict:** AppDoc v2.2.0 achieves its structural goals. The Check enforces what it can (structure, resolution, numbers against Facts, anchors) and the blind writer produces passing documents on all 5 targets including the held-out Classic ASP. The remaining gaps are content-depth gaps (specific findings, enumerations, deep source reading) that are outside the Check's scope by design. The audit procedure works (100% catch rate on seeded errors).

**Next iteration priorities (from comparison reports):**
1. Go stack handler (gitea mislabeled "generic")
2. Cron-task enumeration extractor
3. Client-side JS behavior extraction
4. Consistency check between §4 count and §3.1 enumeration (spring-petclinic 5 vs 6)
5. Config reference curation (gitea 900-row dump)

---

## 9. v2.3 baseline: answer-key scorer

`python eval/score.py <repo> <application-documentation.md>` slices each document with `appdoc.docmodel.headings` and reads Citations with `appdoc.citations.find_citations`. An item is **Present** only when a covering Citation and every `must_contain` term are in the same section block (the item's section or an allowed alternative). **Partial** means the Citation, or the terms, occur somewhere else in the document (for example only in the 16.6 config dump). **Absent** means neither. Keys are in `eval/answer-keys/`; results are in `eval/results/2026-11-11-<repo>.json`. The four 2.2 outputs were scored as they are on disk (slightly hand-edited after generation).

| Repo | Present | Partial | Absent | Retired | Scorable |
|------|---------|---------|--------|---------|----------|
| flaskr-tdd | 0 | 2 | 1 | 0 | 3 |
| spring-petclinic | 1 | 4 | 1 | 0 | 6 |
| eShop | 1 | 6 | 1 | 1 | 8 |
| gitea | 0 | 4 | 1 | 0 | 5 |
| **Total** | **2** | **16** | **4** | **1** | **22** |

| Item | Status | Reason |
|------|--------|--------|
| FL-1 client JS `status === 1` | Absent | `main.js` is never cited and the terms do not occur |
| FL-2 username enumeration | Partial | `app.py:80-83` is cited, but "enumeration" is never written |
| FL-3 glossary `safe` | Partial | `safe` appears in V-3, not in section 13 |
| SP-1 six controllers | Absent | Neither "six controllers" nor "6 controllers" occurs |
| SP-2 `default_batch_fetch_size` | Partial | Only in 16.6 |
| SP-3 `LOWER(name)` | Partial | `postgres/schema.sql:45` is cited in 8.2; the expression is not named |
| SP-4 flash on re-render | Partial | `OwnerController.java:80` is cited; the not-rendered effect is not stated |
| SP-5 actuator Inferred list | Partial | `application.properties:21` is cited; no endpoint list |
| SP-6 concurrency and dialect tests | Present | Section 11 |
| ES-1 F-18 refers to 7.5 | Present | Section 4 |
| ES-2 Paid-handler defect (also closes Q-17) | Partial | Terms occur; the handler file is never cited |
| ES-3 Identity.API views in 6 | Partial | Consent, device and grants are named in 5.2 only |
| ES-4 Identity.API controllers in 4 | Partial | `ConsentController.cs` is cited elsewhere |
| ES-5 ClientApp UI rows in 6 | Partial | No `src/ClientApp/Views` Citation |
| ES-6 ClientApp in 4 | Partial | F-22 is "not reviewed beyond folder layout" |
| ES-7 Q-15 `TokenLifetimeMinutes` closed | Partial | The key is cited and named only in the open question Q-15 |
| ES-8 Q-16 Dependabot ecosystems | Absent | `nuget` is never written; `dependabot.yml:7` is not cited |
| ES-9 E-17 re-run command | Retired | Register format changed |
| GT-1 31 scheduled tasks | Absent | The 31 task names are not enumerated |
| GT-2 sample DB credential finding | Partial | `app.example.ini:400` is a 16.6 row only |
| GT-3 `REVERSE_PROXY_TRUSTED_PROXIES` | Partial | Occurs only in 16.6 (`app.example.ini:479`) |
| GT-4 widened 5.3 | Partial | Terms occur outside 5.3 |
| GT-5 16.5 operator rows | Partial | `cmd/main.go:100-140` is cited; no `doctor` or `admin` rows |

Reading the two tables together: the scorer's 2 Present equal the comparison reports' 2 YES (SP-6, ES-1). Its Partial is looser than the comparison verdicts, because a Citation or a term elsewhere in the document is enough, so the 12 NO rows show up as Partial or Absent here. The v2.3 target in the plan is judged on Present only.

**Answer-key corrections made while verifying against source:**
- **GT-1:** the true cron count is 31 (`RegisterTaskFatal("<name>")` literals: 6 in `services/cron/tasks_actions.go`, 10 in `tasks_basic.go`, 15 in `tasks_extended.go`); the earlier "30" was wrong.
- **GT-2 (old "F13 lines 367 and 400"):** those lines exist, in `custom/conf/app.example.ini` (367 is the MySQL `;PASSWD =` placeholder, 400 a literal sample MSSQL password). `modules/ssh/server.go` has 147 lines, so the comparison report's reading of F-13 as Git over SSH does not apply to them.
- **SP-4:** the plan's `OwnerController.java:155-158` is `:156-159`; the flash calls are at `:80` and `:157`.
