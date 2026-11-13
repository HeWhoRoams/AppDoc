# AppDoc v2.4.0 — Comparative Diagnostic (four public examples)

**Date:** 2026-11-13 · **Scope:** `examples/{flaskr-tdd,spring-petclinic,eShop,gitea}-2.4` vs their 2.3 originals.
**Method:** (1) objective metrics computed from the six artifacts per example (`tmp/diag_metrics.py`); (2) four parallel independent deep-dives (one per example) reading the narrative, evidence register, facts summary and check report. helpweb is excluded (internal app, Decision D5).

All four 2.4 docs **Check PASS** with every citation resolved. The differences below are about *quality of the narrative and the audit*, not structural validity.

---

## 1. Objective metrics

| Metric | flaskr-tdd | spring-petclinic | eShop | gitea |
|---|---|---|---|---|
| Check | PASS | PASS | PASS | PASS |
| Citations (total) | 363 | 656 | 1304 | 1300 |
| Citations with a line | 307 (84.6%) | 622 (94.8%) | 1229 (94.2%) | 1156 (88.9%) |
| Audit rows | 91 | 123 | 114 | 140 |
| **Supported** | 80 (**87.9%**) | 103 (**83.7%**) | 94 (**82.5%**) | 120 (**85.7%**) |
| Corrected | 7 | 18 | 16 | 14 |
| Downgraded | 1 | 1 | 1 | 2 |
| Answerable | 2 | 1 | 3 | 4 |
| Dismissed | 1 | 0 | 0 | 0 |
| Rows with a limitation | 56 (62%) | 71 (58%) | 59 (52%) | 57 (41%) |
| Facts (total) | 107 | 431 | 1707 | 19440 |
| Words | 12,415 | 17,340 | 25,609 | 25,096 |
| Unknowns (Q-) | 51 | 46 | 69 | 62 |
| Security findings (V-) | 65 refs | 64 refs | 139 refs | 94 refs |
| Retired candidates named | 2 | 0 | 9 | 11 |

### 2.3 → 2.4 delta (what the version bump actually changed)

| Example | Facts | Supported % | Words | Retired named |
|---|---|---|---|---|
| flaskr-tdd | 101 → 107 | 84.2 → **87.9** | 12,340 → 12,415 | 0 → **2** |
| spring-petclinic | 425 → 431 | 80.9 → **83.7** | 17,850 → 17,340 | 0 → 0 |
| eShop | 1701 → 1707 | 82.5 → 82.5 | 25,257 → 25,609 | 0 → **9** |
| gitea | 19,434 → 19,440 | 85.7 → 85.7 | 24,474 → 25,096 | 0 → **11** |

**Read:** the 2.4 changes are *honesty* changes, not accuracy changes. Every example now names its retired-code candidates (the 1.4 feature) and carries a `generator` field (2.5). Supported % rose where the audit was re-run (flaskr, spring) and held where it wasn't (eShop, gitea). The narrative got slightly longer on gitea/eShop (retired + config-role prose) and slightly shorter on spring (a stale sentence removed).

---

## 2. Where each example shines

| Example | Standout strength (with evidence) |
|---|---|
| **flaskr-tdd** | **V-9 verified by execution** — the test suite drops the app's default DB because `db = SQLAlchemy(app)` reads the URI at import before the fixture overrides it. The auditor ran pytest on a scratch copy and confirmed `project/flaskr.db` lost its `post` table (E-79). The deepest finding in the set, and the only one proven by running code. |
| **spring-petclinic** | **V-9 nested mass-assignment** — traces the full chain (binder disallows only `id`/`*.id`, `Owner.pets` cascade ALL with no `@Valid`, `open-in-view=false` so `save()` merges the detached graph). The audit even corrected R-13 to cover all three controllers (E-106). Best *analysis* in the set. |
| **eShop** | **Scale + security depth** — 1163 files collapsed to 24 subsystem rows, never enumerated; 21 V-findings including the subtle V-15 (unmasked card logged via C# record `ToString` at `OrdersApi.cs:134`). Best *scale handling* and broadest security surface. |
| **gitea** | **Extreme-scale grouping** — 1431 routes → 12 handler files; 10,601 raw config keys → 371 app keys → 150 shown + a 14-row curated table; 31 cron jobs enumerated. Best *extreme-scale* handling (19,440 facts). |

**Cross-cutting strength (all four):** the audit is genuinely corrective, not a rubber stamp — 7–18 rows per doc were *Corrected* and the fixes are reflected in the final text. Epistemics (Cited / Inferred / Unknown, "value omitted", "not observed on a deployed instance") are consistent and honest across the set.

---

## 3. Where each example fails

| Example | Standout weakness (with evidence) |
|---|---|
| **flaskr-tdd** | **Thin extractor coverage** — `connections`, `external calls`, `ui pages`, `schema objects` all "None extracted"; the doc hand-fills C-1, X-1, UI-1/2/3, the `Post` model. Ownership and the whole deployment runbook (Upgrade/Rollback/Backup/Restore) are Unknown. Smallest, so the gaps are most visible. |
| **spring-petclinic** | **15% correction rate + a stale sentence** — 18/123 rows Corrected (mostly wrong/too-narrow line cites and over-claimed test coverage), and §15.1's coverage sentence ("5 of 12") contradicts the actual register (7 of 13) — a known inconsistency left in the final doc (E-93, E-136). Q-5 was answerable and stayed in §14. |
| **eShop** | **A real security gap missed** — the chatbot's `GetUserInfo` tool returns name/address/email/phone to the model host (E-47 limitation), but no V-finding covers PII flowing to the LLM. Also an overstated batch-fault claim ("one failing receiver faults the whole batch") that the audit flagged but the text never fixed (E-31). |
| **gitea** | **§14 inconsistent with its own audit** — the visible table lists 10 Q-rows but the register carries 14; the four missing (Q-6/10/11/14) are exactly the four *Answerable* rows, and A.2 says "14 \| 10 of 10". The generated config table (16.6) is noisy (non-app keys, mis-flagged secrets, 785 vs 758 count mismatch). V-11–V-14 were added post-audit and "need a delta audit". |

---

## 4. Systemic patterns (the real diagnostic)

These recur across the set and point at the tool, not the individual docs:

1. **Citation precision is the #1 accuracy failure mode.** Every doc's Corrected rows are dominated by wrong/too-narrow line cites and over-generalized claims ("any page", "all handlers", "one failing receiver faults the batch"). The audit catches them, but the *first draft* systematically over-claims. → A pre-audit lint for over-generalized quantifiers and for cites that don't contain the anchor would cut the correction rate.

2. **Answerable unknowns leak into §14.** spring (Q-5), gitea (Q-6/10/11/14) and eShop (Q-11/12/17) all had Q-rows the auditor resolved, yet the doc still lists them (or, for gitea, silently drops them, creating the §14/register mismatch). → `fill` should reconcile §14 against the register's Answerable rows at build time.

3. **The extractor is thin on the fact kinds the narrative needs most.** Across all four: `ui_page` (XAML-only for eShop, none for gitea/flaskr), `external_call` (base-addresses only for eShop), `data_access` (DbSet/`RegisterModel` only, no queries), `schema_object` (none for eShop/gitea/flaskr), `connection` (none for gitea/flaskr). The narrative compensates by hand — accurate, but the "facts" foundation is thinner than the doc implies. → This is the biggest lever for v2.5.

4. **Stale generated blocks survive to the final doc.** spring's §15.1 coverage sentence and gitea's post-audit V-11–V-14 both show that content added/changed *after* `fill` regenerates Appendix A is not re-checked. The render guard (1.3) catches stale *blocks* but not stale *prose that references the register*. → A C-rule that re-validates any sentence citing a register count against the live register.

5. **Owner + deployment runbook are structurally empty.** All four docs have §11 ownership and §16.5 Rollback/Backup/Restore as Unknown (shallow clones, no owner file). This is honest but means the two most operationally useful sections are the emptiest. → An `appdoc-context.md` owner file (already in `OWNER_CONTEXT`) would fill this; none of the four targets have one.

6. **Scale is handled well; the cost is a noisy generated config table.** gitea (10,601 keys) and eShop (258) both show the curated-config feature working, but the raw generated block still leaks non-app keys and mis-flagged secrets. The "Known extractor limitation" note is honest but the table remains misleading. → Tighten the config post-pass (1.4) to drop env/CI keys before the block is emitted.

---

## 5. Ranking

| Rank | Example | Why |
|---|---|---|
| 1 | **eShop** | Best scale handling + broadest, deepest security analysis; audit loop fully closed. Held back by one missed PII finding and a few overstated failure claims. |
| 2 | **gitea** | Best extreme-scale grouping and a rigorous audit; held back by the §14/register inconsistency and a noisy config table. |
| 3 | **spring-petclinic** | Best single analysis (V-9 mass-assignment) and honest epistemics; held back by the highest correction rate and a stale §15.1. |
| 4 | **flaskr-tdd** | Most honest and the only execution-verified finding (V-9), but the smallest and its extractor coverage is thinnest, so the gaps are most visible. |

**Bottom line:** all four are structurally valid and honest. The 2.4 bump delivered the honesty features (retired candidates, config roles, version skew, per-claim C2) cleanly. The remaining quality gap is *first-draft accuracy* (over-claiming + citation precision) and *extractor coverage* on UI/external-call/data-access/schema facts — those two are the v2.5 targets.
