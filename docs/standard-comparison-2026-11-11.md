# AppDoc vs Standard — Full Comparison (2026-11-11)

Reference standard: `C:\Github\helpweb\Planning\HELP_DESK_APPLICATION_DOCUMENTATION.html` (18 sections).
Targets audited (current regenerated docs, all Check PASS, all with Appendix A):
- `examples/flaskr-tdd/application-documentation.md` (Python/Flask, small)
- `examples/spring-petclinic/application-documentation.md` (Java/Spring Boot, JPA, Thymeleaf)
- `examples/eShop/application-documentation.md` (.NET microservices, Blazor, Aspire)
- `examples/gitea/application-documentation.md` (Go SCM, unsupported stack, ~6200 files)

Section mapping (standard → AppDoc): 4A→4.1; 8A→8.x; 14+18→`verification.md`/Appendix A; 17→16.x; 16→15. AppDoc keeps 16 numbered sections by design.

**Status of prior findings:** every prior re-audit finding was re-verified against the current docs and source. **All are confirmed; none are fixed or not-applicable.** (The docs were regenerated after the first audit, but the same classes of gaps re-emerged — see cross-cutting findings below.)

---

## Cross-cutting findings (highest-leverage remediation targets)

These appear across multiple repos, so fixing them in the skill/template/Check fixes all four at once.

| # | Finding | Repos | Leverage |
|---|---------|-------|----------|
| X1 | **Evidence Register under-covers the document.** The register skips whole sections that make claims (UI Catalog, diagrams, glossary, subsystem inventory, recommendations, some runbook subsections). | flaskr, petclinic, eShop, gitea | High |
| X2 | **`verification.md` Corrections use changelog/revision-history language** ("the previous version said…", "an earlier draft claimed…") instead of claim + evidence. | flaskr, petclinic, gitea | High |
| X3 | **`verification.md` summary counts drift from the register** (e.g. "47 Cited claims" vs 43 rows; "4 corrected" vs 5 bullets). | flaskr (petclinic/eShop/gitea: verify) | Med |
| X4 | **No severity on 10.1 security findings** (15 has a Severity column; 10.1 does not, so findings and recs aren't aligned). | petclinic, eShop, gitea (flaskr: findings unranked) | High |
| X5 | **Section 14 (Open Questions) is a flat bullet list** — no IDs, owner, priority, or resolution path. | all four | High |
| X6 | **No column-level data dictionary / ER diagram** (8.4 lists "Key fields" only; no types/keys/FKs/indexes/retention; no `erDiagram`). | petclinic, eShop, gitea (flaskr: no `Post` field table) | High |
| X7 | **10.2 blurs "verified absent" vs "unknown"** (controls positively confirmed missing are labeled the same as genuinely unknown ones). | flaskr (eShop/gitea: soft) | Med |
| X8 | **15 (Recommendations) doesn't cover 10.2 unknowns** (no "establish/verify" recs for TLS, MFA, rate limiting, backup, etc.). | eShop (verify others) | Med |
| X9 | **UI Catalog (6) is thin / missing structural columns** (no Navigation/entry column, no stable screen IDs, no source-only statement; eShop 19/~600, gitea 19/~600). | eShop, gitea (petclinic: not in register) | Med |
| X10 | **External call register (8.3) lacks per-call failure/timeout/retry/auth columns; 8.5 doesn't cross-reference call IDs.** | eShop, gitea | Med |
| X11 | **Operations Runbook (16.5) is a CI catalogue, not an operator runbook** (no upgrade/rollback, backup/restore, secret/token rotation). | gitea (flaskr: no operator commands/rollback) | Med |
| X12 | **Self-audit only — no independent verification; the audit is partial** (large fraction of sections unaudited). | gitea (applies to all) | Med |
| X13 | **Template `<!-- -->` scaffolding left in the raw `.md`** (renderer strips it, but the source shows it). | eShop (18 blocks) | Low |
| X14 | **Config-key register not surfaced** (hundreds of `config_key` Facts extracted but never tabulated). | petclinic (641), eShop, gitea | Med |
| X15 | **Tests not mined** for behavioral claims (concurrency/dialect integration tests exist but weren't cited). | petclinic | Low |
| X16 | **Section 1 TOC omits Appendix A / `verification.md`.** | flaskr | Low |

### Per-repo factual errors (must-fix, lower leverage)
- **flaskr-tdd:** 7.5 step 4 misstates browser behavior (removal only when `status===1`); glossary `safe` row malformed (4 cells in a 3-col table); 10.1 missing username-enumeration finding (`app.py:80-83`, `!=` + distinct messages).
- **spring-petclinic:** §4 intro says "five controllers" (there are six); V-12 omits `default_batch_fetch_size=16` mitigation; V-9/8.2 omit that the Postgres index is `LOWER(name)`; 7.1/7.2 flash-message visibility misstated (re-render, not redirect; form template doesn't render `${error}`).
- **eShop:** F-18 cross-reference wrong (says 7.3, should be 7.5); missed real defect — Webhooks `OrderStatusChangedToPaidIntegrationEventHandler` logs "…Shipped…" and is typed `ILogger<…Shipped…>`; E-17 re-run command broken (unescaped `(`).
- **gitea:** 7.12 cron table incomplete (17 of 30 tasks; 13 missing incl. `delete_old_actions`, `gc_lfs`, `rebuild_issue_indexer`, `delete_old_audit_events`); F13 cites only `app.example.ini:400` (re-run also returns 367); F10 omits `REVERSE_PROXY_TRUSTED_PROXIES`.

---

# flaskr-tdd — AppDoc vs Standard Breakdown

## 1. Overall assessment
A strong, citation-dense document that maps cleanly onto the standard's 18-section rubric and is, for a small single-user Flask app, unusually complete: every claim carries a `path:line` Citation, three Mermaid diagrams, a 13-row security-findings table, a 12-row troubleshooting matrix, and a 43-row Evidence Register with re-run commands. Biggest strength: **evidence discipline** (Cited/Inferred/Unknown triage + per-claim re-run commands match or exceed the standard). Biggest weakness: **internal consistency and completeness of the verification layer** (register under-covers the doc's own sections, summary counts disagree, and a few specific claims are wrong or malformed).

## 2. Strengths
- **Citation density and verifiability.** Every substantive claim in sections 3–16 carries a `path:line` Citation; `check-report.md` confirms all resolve. Stronger than the standard, which cites files but not always line ranges.
- **Explicit Cited / Inferred / Unknown triage.** Consistently marks reasoning and defers to section 14 for Unknowns.
- **Security findings are specific and actionable.** 10.1 has 13 findings (S1–S13), each with evidence, impact, and a matching recommendation in 15 (R1–R13).
- **Workflows named per real behavior** (7.1–7.7), each with a "Failure and escalation" paragraph.
- **Honest scope boundaries.** 2.1 and 15.1 state what was/wasn't inspected (binary `.db`, most of `style.css`, tutorial README, no runtime).
- **Diagrams present and correct.** Three Mermaid diagrams (3.2, 12 data-flow + two sequence).
- **Secrets redaction.** Credential values consistently "value omitted" with locations cited.

## 3. Weaknesses
- **7.5 step 4 misstates browser behavior** (says removal happens "regardless of status"; source gates `removeChild` on `result.status === 1`).
- **Glossary `safe` row malformed** (4 cells in a 3-column table).
- **verification.md summary counts disagree** ("47 Cited claims" vs 43 rows; "4 corrected" vs 5 bullets).
- **verification.md Corrections reads as a changelog** ("The previous version said…").
- **Evidence Register under-covers** (no rows for 5.3, 8.4, 12, 13, 15, 4.1).
- **10.1 missing username-enumeration finding** (`app.py:80-83`).
- **10.2 blurs verified-absent vs unknown** (all rows "Not established").
- **16 runbook lacks operator detail** (no commands, log location, rollback/restore).
- **Section 1 TOC omits Appendix A / verification.md.**
- **No test inventory, config reference table, or `Post` schema field table.**

## 4. Gaps
### 4a. Code/stack (legitimate)
No stored procs/raw SQL (ORM); no AD/email/COM/queue; single shared account → no real role model; shallow clone → ownership Unknown; no deployment config; no logging/observability; no migration tool/seed data; binary `.db` not inspected.
### 4b. AI (should have been better)
7.5 misread of `main.js`; glossary row malformed; verification.md count drift + changelog language; register coverage gap; missing username-enumeration finding; 10.2 "Not established" overused; 16 thin on operator detail; TOC omits Appendix A; missing reference tables (test inventory, config table, `Post` field table).
### 4c. Other
Standard 8B absent by design (ORM); no rendered-UI evidence; no standalone Verification Appendix in main doc (folded into `verification.md`); no prominent handling-note callout.

## 5. Areas to enhance (prioritized)
1. Fix 7.5 step 4 to match `main.js`.
2. Add username-enumeration finding to 10.1 (+ matching rec).
3. Reconcile verification.md counts; de-changelog the Corrections.
4. Extend the Evidence Register to 5.3, 8.4, 12, 13, 15, 4.1 (and 16.2–16.4).
5. Distinguish verified-absent from unknown in 10.2.
6. Add a `Post` schema field table, a config/environment key table, and a test inventory with feature-to-test traceability.
7. Flesh out 16 with operator commands, log location, rollback/restore.
8. Add Appendix A to the section 1 TOC; fix the malformed glossary row.
9. Add a prominent handling-note callout near the top.

## 6. Section-by-section scorecard
| Standard | Mapped | Present? | Quality | Note |
|---|---|---|---|---|
| 1. Application Index | 1 | yes | strong | TOC + cross-ref; TOC omits Appendix A |
| 2. Coverage & Overview | 2 (2.1–2.3) | yes | strong | Inspected/purpose/boundary cited |
| 3. Architecture | 3 (3.1–3.3) | yes | strong | Components, diagram, authn/authz cited |
| 4. Functional Inventory | 4 | yes | strong | 8 features (F1–F8) |
| 4A. Subsystem Inventory | 4.1 | yes | adequate | 4 subsystems; no register row |
| 5. Roles & Access | 5 (5.1–5.3) | yes | strong | Two-state model; 5.3 no register row |
| 6. UI Catalog | 6 | yes | strong | 3 pages; no rendered-UI evidence |
| 7. Workflows | 7 (7.1–7.7) | yes | strong | Named; 7.5 step 4 misstates behavior |
| 8. Data & Integrations | 8 (8.1–8.5) | yes | strong | Connections/SQL/external/entities/failure |
| 8A. External Call Register | 8.1–8.5 | yes | strong | DB/SQL/HTTP/CDN/failure; 8.4 no register row |
| 8B. Stored-proc dictionary | (none) | n/a | n/a | No stored procs (ORM) |
| 9. Troubleshooting Matrix | 9 | yes | strong | 12 symptom rows |
| 10. Security & Ops Risks | 10 (10.1–10.2) | yes | strong | 13 findings; missing enumeration; 10.2 blurs |
| 11. Ownership & Maintenance | 11 | yes | adequate | Ownership Unknown (shallow clone) |
| 12. Diagrams | 12 | yes | strong | Data-flow + two sequence; no register row |
| 13. Glossary | 13 | yes | adequate | 16 terms; `safe` row malformed |
| 14. Evidence Register | verification.md | yes | strong | 43 rows; count drift; under-covers |
| 15. Open Questions | 14 | yes | strong | 9 explicit Unknowns |
| 16. Recommendations | 15 (+15.1) | yes | strong | 13 recs mapped to findings |
| 17. Operations Runbook | 16 (16.1–16.5) | yes | adequate | Lacks operator commands/rollback |
| 18. Verification Appendix | verification.md | yes | strong | Re-run commands; changelog language |

## 7. Verified prior findings
| Prior finding | Status | Evidence |
|---|---|---|
| 7.5 step 4 misstates browser behaviour | **confirmed** | 7.5 step 4 (line 214); `main.js:15-20` gates `removeChild` on `status===1` |
| Glossary `safe` row extra 4th cell | **confirmed** | 13, last row (line 419) |
| verification.md "47 Cited claims" vs 45 rows; "4 corrected" vs 5 bullets | **confirmed** | summary (line 3) 47/4; register 43 rows; Corrections 5 bullets |
| verification.md Corrections changelog language | **confirmed** | "The previous version said…", "absent from the previous version" |
| Register no rows for 5.3, 8.4, 12, 13, 15, most of 4/4.1 | **confirmed** | Section column covers 10.1, 7.x, 8.1, 8.3, 3.3/5.2, 5.1, 4 (E-F1), 10.2, 8.5, 16.1, 11, 6, 9, 2.1 |
| 10.1 missing username-enumeration finding | **confirmed** | 10.1 S1–S13 (301-315); `app.py:80-83` `!=` + distinct messages |
| 10.2 "Not established" blurs verified-absent | **confirmed** | 10.2 (319-330) all "Not established" |
| 16 runbook no operator commands/log/rollback | **confirmed** | 16.4 (360-368) generic; 16.5 (370-381) ends at "edit, run pytest, push" |
| Section 1 TOC omits Appendix A | **confirmed** | TOC (17-30) lists only 2–16 |
| No test inventory / config table / `Post` field table | **confirmed** | `tests/app_test.py` (8 tests), 26 config keys, `models.py` `Post` available but not tabulated |

---

# spring-petclinic — AppDoc vs Standard Breakdown

## 1. Overall assessment
A high-quality, citation-dense document that maps cleanly onto the standard's 18-section rubric and is unusually rigorous about separating Cited/Inferred/Unknown. Biggest strength: **evidence discipline** (every claim cited, `check-report.md` proves resolution, `verification.md` re-verifies 58 claims with re-runnable commands — the standard's §18 made more systematic). Biggest weakness: **depth of the data layer** (§8.4 lists only key fields; no per-dialect schema dictionary, no config-key register despite 641 `config_key` Facts, and the tests that would confirm concurrency/dialect behavior weren't mined).

## 2. Strengths
- **Citation + verification pipeline.** Every claim cited; `check-report.md` proves resolution; `verification.md` re-verifies 58 claims with re-runnable `Select-String` + Limitation column. Exceeds the standard's §18.
- **Explicit Cited/Inferred/Unknown taxonomy.** §10.2 is a well-executed analog of the standard's §10 "Unknowns."
- **Functional Inventory with per-route IDs** (FI-01…FI-17), cross-referenced from §1, §5.3, §7.
- **Security findings with concrete impact** (V-1…V-14), e.g. V-9 (MySQL duplicate backstop), V-13 (unreviewed image).
- **Troubleshooting Matrix keyed to real messages** (16 rows, each citing the exact `messages.properties` line).
- **Operations Runbook with concrete versions and CI** (Java 17, Spring Boot 4.1.0, Maven 3.9.16, Gradle 9.5.1, MySQL 9.7, PostgreSQL 18.4; three CI workflows + `kubectl apply -f k8s/`).
- **Diagrams** (component, data-flow, sequence, ER) — richer than the standard's single sequence diagram.

## 3. Weaknesses
- **§8.4 data dictionary is shallow** (only "Key fields"; no types/nullability/FKs/lengths/constraints — all present in the three `schema.sql` files).
- **No per-dialect schema dictionary** (H2/MySQL/Postgres differ; never given side-by-side).
- **No config-key register** (641 `config_key` Facts extracted, never surfaced).
- **§10.1 findings carry no severity** (V-1…V-14 unranked; §15 has a Severity column).
- **§14 Open Questions have no IDs/owner/resolution path** (plain bullet list).
- **§5.3 has no negative-capability rows** (all-Y + one Unknown; no "Restriction" note).
- **Tests not mined** (`PetClinicConcurrencyTests`, `MySql/PostgresIntegrationTests` exist and bear on V-9/V-11).
- **§15.1 overstates Evidence Register coverage** (routes aggregate-only via E-02; register omits §6, §3.1, §12, §13, §5.3, §16.3).

## 4. Gaps
### 4a. Code/stack (legitimate)
No stored procs (JPA) → 8A.2/8B N/A; no auth → §5 degenerate; no AD; shallow clone → ownership Unknown; demo-only k8s → deployment Unknown; in-memory H2 → no backup subject; no email/COM/file boundaries → 8A.5 N/A.
### 4b. AI (should have been better)
§4 "five controllers" (six); V-12 omits `default_batch_fetch_size=16`; 8.2/V-9 omit `LOWER(name)`; V-4/§5.3 actuator surface Unknown when inferable; 7.1/7.2 flash-message visibility misstated; §8.4 thin given schema available; config-key Facts not surfaced; tests not mined; §15.1 overclaims; verification.md Corrections revision-history language.
### 4c. Other
No severity column in §10.1; §14 no IDs/owner/resolution; §5.3 no "Restriction" note/negative rows; no single executive-summary risk statement; diagrams Mermaid-source only (no rendered fallback).

## 5. Areas to enhance (prioritized)
1. Build a per-dialect schema dictionary (H2/MySQL/Postgres) from the three `schema.sql` files.
2. Add a configuration register (datasource, JPA, actuator, logging, i18n, cache, web) from the 641 `config_key` Facts.
3. Fix the §4 controller count (five → six).
4. Add severity to §10.1 and align with §15.
5. Correct the flash-message claims in §7.1/§7.2.
6. Note the `default_batch_fetch_size=16` mitigation in V-12.
7. Convert V-4/§5.3 actuator surface to an Inferred endpoint list.
8. Mine the integration/concurrency tests.
9. Give §14 questions IDs, owner, resolution path.
10. Add negative-capability rows + a "Restriction" note to §5.3.
11. Rewrite verification.md Corrections without revision-history language.
12. Add an executive-summary risk statement to §2.

## 6. Section-by-section scorecard
| Standard | Mapped | Present? | Quality | Note |
|---|---|---|---|---|
| 1. Application Index | 1 | yes | strong | Support-need cross-ref with citations |
| 2. Coverage & Overview | 2 | yes | strong | Cited; no single exec-summary risk line |
| 3. Architecture | 3 | yes | strong | Components, diagram, clear "no auth" §3.3 |
| 4. Functional Inventory | 4 | yes | strong | 17 FI rows; intro miscounts controllers |
| 4A. Subsystem Inventory | 4.1 | yes | strong | 19 subsystem rows |
| 5. Roles & Access | 5 | yes | adequate | Documents absence; §5.3 all-Y, no negative rows |
| 6. UI Catalog | 6 | yes | adequate | 9 pages; not in Evidence Register |
| 7. Workflows | 7 | yes | strong | 10 workflows; flash-message claim inaccurate |
| 8. Data & Integrations | 8 | yes | adequate | §8.4 shallow |
| 8A. External Call Register | 8.1–8.5 | partial | adequate | 8A.2/8A.5 N/A; no config register |
| 8B. Stored-proc dictionary | (8.4 analog) | no | weak | No procs; per-dialect dictionary missing/thin |
| 9. Troubleshooting Matrix | 9 | yes | strong | 16 rows keyed to real messages |
| 10. Security & Ops Risks | 10 | yes | strong | 14 findings + Unknowns; no severity |
| 11. Ownership & Maintenance | 11 | yes | adequate | Ownership Unknown (shallow clone) |
| 12. Diagrams | 12 | yes | strong | Component, data-flow, sequence, ER |
| 13. Glossary | 13 | yes | strong | 17 terms cited |
| 14. Evidence Register | verification.md | yes | strong | 58 re-verified; skips §6/3.1/12/13/5.3/16.3 |
| 15. Open Questions | 14 | yes | adequate | Thorough; no IDs/owner/resolution |
| 16. Recommendations | 15 | yes | strong | 12 REC rows severity/effort + coverage |
| 17. Operations Runbook | 16 | yes | strong | Platform/data/session/failure/deploy cited |
| 18. Verification Appendix | verification.md | yes | strong | Re-runnable; Corrections revision-history language |

## 7. Verified prior findings
| Prior finding | Status | Evidence |
|---|---|---|
| §4 intro "five controllers" but six | **confirmed** | `application-documentation.md:102`; six in §3.1 and on disk |
| V-12 omits `default_batch_fetch_size=16` | **confirmed** | `application.properties:13`; V-12 (line 371) silent |
| 8.2/V-9 omit `LOWER(name)`; H2/MySQL case-sensitive | **confirmed** | `postgres/schema.sql:45` `ON pets (owner_id, LOWER(name))` |
| V-4 "endpoints Unknown" could be Inferred | **confirmed** | `:363` (V-4), `:173` (§5.3); `include=*` + actuator starter |
| 7.1/7.2 flash attributes only after redirect | **confirmed** | `OwnerController.java:80-81,157-158` re-render (no redirect); form template renders no `${error}` |
| Register skips §6/3.1/12/13/5.3/16.3; 15.1 overclaims per-route | **confirmed** | E-01…E-58; §15.1 (~line 560) |
| verification.md Corrections revision-history language | **confirmed** | "The previous version said…", "An earlier draft…", "the previous version cited README.md:55" |
| 8.4 key fields only, no types/nullability/FKs | **confirmed** | §8.4 "Key fields" only; three `schema.sql` have the detail |
| No config register; no per-dialect dictionary; tests not mined | **confirmed** | `facts-summary.md` 641 `config_key`; tests exist but §2.1/§14 say not run |
| 10.1 no severity; §14 no IDs/owner; 5.3 no negative rows | **confirmed** | §10.1 V-1…V-14 unranked; §14 bullet list; §5.3 all-Y |

---

# eShop — AppDoc vs Standard Breakdown

## 1. Overall assessment
A strong, citation-dense document that maps cleanly onto the standard's 18-section rubric and exceeds it in several areas (per-claim Evidence Register with re-run commands, a 22-row troubleshooting matrix, four Mermaid diagrams, a 16-row security register). Biggest strength: **evidence discipline** (nearly every claim cited, every inference flagged `**Inferred:**`, every unknown routed to §14). Biggest weakness: **coverage completeness on the identity and mobile surfaces** (Identity.API controller/view surface and the 22-screen MAUI ClientApp largely absent from §4/§6) and the **data layer** (8.2/8.4 stop short of a real data dictionary or ER diagram).

## 2. Strengths
- **Citation density and verifiability.** Every material claim cited; `verification.md` (76 rows) adds re-run + Limitation per claim — strictly more than the standard's 15-row register + 18-row appendix.
- **Honest epistemics.** `**Inferred:**`/`Unknown` used consistently; §10.2 lists controls that must not be assumed.
- **Security register depth.** 10.1 has 17 findings (V-01…V-17) with line citations + severity; §15 maps 16 recs (R-01…R-16) back to findings.
- **Multi-service architecture capture.** §3.1/3.2/4.1 enumerate all 12+ services, four PostgreSQL DBs, Redis, RabbitMQ, YARP `mobile-bff`, event-bus/outbox, with a topology diagram.
- **Event-driven workflow fidelity.** §7.5 traces grace-period → stock → payment → paid/shipped with per-step citations + a data-flow diagram.
- **Troubleshooting matrix breadth.** §9 has 22 symptom rows with concrete "Escalate when" triggers.

## 3. Weaknesses
- **Identity.API under-documented in §4/§6** (only "Identity login"/"logged out" in §6; Consent/Device/Grants/Diagnostics controllers and ~9 views absent).
- **MAUI ClientApp absent from the UI Catalog** (22 XAML screens not catalogued; only HybridApp's two Blazor pages).
- **§6 lacks the standard's structural columns** (no Navigation/entry, no stable screen IDs, no source-only statement).
- **External call register (8.3) thin on operational columns** (no per-call failure/timeout/retry/auth; X-IDs never referenced from 8.5).
- **No data dictionary or ER diagram** (8.4 "Key fields" + sensitivity only; 8.2 one-paragraph "no stored procedures").
- **§14 flat bullet list** (18 bullets, no priority/owner/how-to-close; 3 now closable).
- **§15 ignores the 10.2 unknowns** (all 16 recs address 10.1; none establish/verify TLS, cookie flags, MFA, rate limiting, CORS/CSRF, audit, backup, scanning).
- **Severity has no rubric** (V-06 Medium without justification).
- **A real defect was missed** (Webhooks Paid-handler misleading log + wrong `ILogger<>` type).

## 4. Gaps
### 4a. Code/stack (legitimate)
No stored procs/data-dictionary source (EF Core + one hand-written SQL); no AD (Duende IdentityServer + ASP.NET Identity); shallow clone → ownership Unknown; infra in Aspire/Docker (production topology/TLS/failover not in repo); payment simulated; aspnet-core extractor gaps (Playwright harness labeled "node-express"); no MAUI/XAML extractor; no `secret_location` Facts.
### 4b. AI (should have been better)
Missed the Webhooks Paid-handler defect; Identity.API controllers/views under-catalogued; MAUI ClientApp left Unknown without a UI row; §8.5 not cross-linked to X-IDs; §14 left 3 closable items open; §15 didn't extend to 10.2; severity without a rubric; E-17 re-run command broken; E-64/E-67/E-68 lump many claims.
### 4c. Other
18 template `<!-- -->` blocks left in raw `.md`; no ER diagram; §6 no stable screen IDs; F-18 cross-reference wrong (7.3 → 7.5).

## 5. Areas to enhance (prioritized)
1. Add the Webhooks Paid-handler defect to 10.1 and 9.
2. Expand §6 to cover Identity.API and MAUI ClientApp.
3. Add a Navigation/entry column + stable screen IDs + source-only statement to §6.
4. Add per-call failure/timeout/retry/auth columns to 8.3; reference X-IDs from 8.5.
5. Build a data dictionary / ER diagram for 8.2/8.4.
6. Convert §14 to a prioritized table; close the 3 resolvable items.
7. Extend §15 to the 10.2 unknowns with "establish/verify" recs.
8. Add a severity rubric to 10.1; justify V-06.
9. Fix the F-18 cross-reference and the E-17 broken command; split E-64/E-67/E-68.
10. Strip the 18 template `<!-- -->` blocks (or document they are renderer-only).

## 6. Section-by-section scorecard
| Standard | Mapped | Present? | Quality | Note |
|---|---|---|---|---|
| 1. Application Index | 1 | yes | strong | Cross-ref + links; F-18 wrong xref |
| 2. Coverage & Overview | 2 | yes | strong | Cited; node-express mislabel handled |
| 3. Architecture | 3 | yes | strong | All services, diagram, per-service auth |
| 4. Functional Inventory | 4 | partial | adequate | 22 features; Identity + MAUI missing |
| 4A. Subsystem Inventory | 4.1 | yes | strong | 16 subsystems |
| 5. Roles & Access | 5 | yes | strong | No-roles finding, OIDC matrix |
| 6. UI Catalog | 6 | partial | adequate | WebApp/WebhookClient/HybridApp; Identity + MAUI absent |
| 7. Workflows | 7 | yes | strong | 9 workflows, cited steps + failure line |
| 8. Data & Integrations | 8 | partial | adequate | No data dictionary or ER diagram |
| 8A. External Call Register | 8.3 (+8.1,8.5) | partial | adequate | 14 X-IDs; no failure/timeout/retry/auth; not ref'd from 8.5 |
| 8B. Stored-proc dictionary | 8.2/8.4 | no | weak | "No stored procs" + entity/sensitivity; no types/keys/FKs |
| 9. Troubleshooting Matrix | 9 | yes | strong | 22 rows with escalate-when |
| 10. Security & Ops Risks | 10 | yes | strong | 17 findings + 10 unknowns; no rubric; missed defect |
| 11. Ownership & Maintenance | 11 | yes | adequate | Shallow-clone Unknown handled |
| 12. Diagrams | 12 | yes | strong | 4 Mermaid; no ER diagram |
| 13. Glossary | 13 | yes | strong | ~45 terms cited |
| 14. Evidence Register | verification.md | yes | strong | 76 rows; E-17 broken, E-64/67/68 lumped |
| 15. Open Questions | 14 | yes | adequate | 18 bullets; flat; 3 closable |
| 16. Recommendations | 15 (+15.1) | partial | adequate | 16 recs map to 10.1; not 10.2 |
| 17. Operations Runbook | 16 | yes | strong | Platform/data/session/failure/deploy cited |
| 18. Verification Appendix | verification.md | yes | strong | Re-run + corrections + downgrades + unknowns |

## 7. Verified prior findings
| Prior finding | Status | Evidence |
|---|---|---|
| F-18 cross-ref "7.3" but order progression is 7.5 | **confirmed** | F-18 row (~line 175); 7.3 = shopping bag, 7.5 = order progression |
| Identity.API missing from §4/§6 | **confirmed** | §6 only "Identity login"/"logged out"; source 18 `.cshtml` (11 non-layout), 7 controllers, 8 HttpGet + 6 HttpPost |
| §6 no source-only/nav/screen IDs; MAUI (22 XAML) absent | **confirmed** | §6 columns lack nav/IDs/source-only; `src/ClientApp` 22 `.xaml` |
| 8.3 no failure/timeout/retry/auth; X-IDs not ref'd from 8.5 | **confirmed** | 8.3 columns ID/Call/Direction/Caller/Notes; X-01…X-14 only at 399–412; 8.5 (431–470) no X-ID |
| 8.4/8.2 no data dictionary or ER | **confirmed** | 8.4 Entity/Key fields/Defined at/Sensitivity; 8.2 one-paragraph; no `erDiagram` |
| §14 flat; 3 closable now | **confirmed** | 18 bullets; closable: Paid-handler mirror, Dependabot nuget-only weekly, no reader of TokenLifetimeMinutes/PermanentTokenLifetimeDays |
| Missed Paid-handler defect | **confirmed** | `OrderStatusChangedToPaidIntegrationEventHandler.cs:3-7,10` |
| §15 doesn't cover 10.2 unknowns | **confirmed** | R-01…R-16 all address 10.1 |
| 10.1 no severity rubric; V-06 Medium unexplained; 10.2 omits hashing/alerting/retention | **confirmed** | 10.1 High/Medium/Low no criteria; 10.2 rows omit password hashing, alerting, data retention/PII |
| E-17 broken; E-64/67/68 lumped; "expect no match" ambiguous | **confirmed** | E-17 `SetTag("message"` unescaped `(`; E-64 F-12…F-17, E-67 all §6, E-68 all §9 |
| ~16 template `<!-- -->` blocks in raw `.md` | **confirmed** | 18 `<!--` blocks counted |

---

# gitea — AppDoc vs Standard Breakdown

## 1. Overall assessment
A genuinely strong, citation-dense document for an unsupported stack: because Go has no AppDoc extractor, the AI read ~6,200 files directly and produced a 16-section document whose Cited claims carry path-and-line citations, with a separate `verification.md` (Evidence Register + Corrections) rendered as Appendix A. Biggest **strength**: depth and honesty of the security/operational analysis (10, 9, 8.5) and workflow traces (7) — every claim traceable to a line, Unknowns fenced off. Biggest **weakness**: **breadth-vs-depth imbalance on a very large app** — the role matrix (5.3), UI catalog (6), subsystem inventory (4.1), and operations runbook (16.5) are materially shallower than the standard, and several tables are incomplete or self-contradictory (7.12 omits 13 of 30 cron tasks; the file-count discrepancy is repeated unresolved in three places).

## 2. Strengths
- **Citation discipline on an unsupported stack.** Every Cited row in 3–9, 10, 11, 16 carries a `file:line` citation; explicit that Go yields no `entry_point`/`data_access`/`connection`/`auth_check` Facts.
- **Security findings specific and actionable (10.1 F1–F14)** (PBKDF2-not-Argon2 default, built-in fallback `SECRET_KEY`, admin impersonation/sudo with audit off, lax egress, reverse-proxy header trust).
- **Troubleshooting matrix (9) excellent** (~30 rows, all cited to the emitting code line — stronger than the standard's 9).
- **Workflows (7) traced end-to-end** (14 named workflows, each with a "Failure and escalation" line).
- **Honest Unknown handling (10.2, 14).**
- **External call register (8.3) comprehensive** (32 EXT rows: webhooks, SMTP/IMAP, LDAP, OAuth2, migrations, mirrors, LFS, object storage, Redis/memcache, indexers, Actions, packages, git, metrics, internal API, update checker, captcha, test/CI-only).
- **Glossary (13) large and cited** (~70 terms).
- **Recommendations (15) finding-linked and severity/effort-rated** (R-01–R-18) + 15.1 coverage summary.

## 3. Weaknesses
- **7.12 cron task table incomplete and mislabeled** (17 of 30 registered tasks; 13 missing).
- **5.3 role-to-capability matrix narrow** (repository-roles-only; no Actions/packages/projects/wiki/releases; no org-role rows beyond create/manage; no token-scope view).
- **Section 6 UI catalog thin** (19 pages of ~600 templates; labels "by function" because `options/locale/` not read).
- **16.5 is a CI-workflow catalogue, not an operator runbook** (no upgrade/rollback, backup/restore, `SECRET_KEY`/token rotation, `gitea admin`/`doctor`/`dump`).
- **Section 4 flat and dense** (no Area/domain column; F-22 packs ~22 citations; 4.1 no F-ID→subsystem cross-ref).
- **File-count discrepancy repeated unresolved in 3 places** (2.1, 4.1, 14).
- **10.1 findings carry no per-finding severity**; F13 cites only `app.example.ini:400` (re-run also returns 367).
- **8.5 doesn't cross-reference EXT IDs; 8.3 no timeout/retry/fallback columns.**
- **Section 14 not prioritised/owned** (~45 Unknown items; several answerable from source).

## 4. Gaps
### 4a. Code/stack (legitimate)
Go unsupported → no `entry_point`/`data_access`/`connection`/`auth_check` Facts; no stored procs (XORM; Go migrations) → 8B no analogue; no AD in-app (pluggable auth sources); shallow clone → ownership Unknown; no Go/OpenAPI/INI extractor (OpenAPI sampled for path/tag counts; INI from two example files); runtime `app.ini` not in Target → defaults only; production deployment not in repo; Actions runner code not in Target.
### 4b. AI (should have been better)
7.12 incomplete task table; F13 incomplete citation; F10 omits `REVERSE_PROXY_TRUSTED_PROXIES`; file-count discrepancy left unresolved; 5.3 deliberately narrow; §6 under-did (19/~600); workflow depth uneven (several bodies "not opened"); 8.5 no EXT refs / 8.3 no timeout/retry/fallback; 10.1 no severity; §14 not prioritised/owned; self-audit only; 16.5 CI catalogue not operator runbook; no ER/deployment/auth-state/data-layer diagram.
### 4c. Other
No ER diagram / column-level data dictionary; no deployment/auth-state/data-layer data-flow diagram; §4 very dense (F-22 ~22 citations); no Area column; no F-ID cross-ref in 4.1; `docs/` "13 (9)" confusing (live total now 25); partial self-audit (many sections unaudited).

## 5. Areas to enhance (prioritized)
1. Complete the 7.12 cron table to all 30 tasks.
2. Widen 5.3 into a full role model (Actions, packages, projects, wiki, releases + token-scope view + org-role rows).
3. Convert 16.5 into a real operator runbook (upgrade/rollback, backup/restore, secret/token rotation, `admin`/`doctor`/`dump`).
4. Add an ER diagram + column-level data dictionary for core entities in 8.4.
5. Add deployment, auth-state, and data-layer data-flow diagrams to §12.
6. Add per-finding severity to 10.1 (fix F13 → 367+400; add `REVERSE_PROXY_TRUSTED_PROXIES` to F10).
7. Cross-link 8.5 to EXT IDs; add timeout/retry/fallback columns to 8.3.
8. Expand §6 to major screens; read `options/locale/` for real control labels.
9. Add an Area/domain column to §4 and an F-ID cross-ref column to 4.1; split F-22's cell.
10. Resolve the file-count discrepancy in one place.
11. Prioritise and owner §14; answer the source-answerable Unknowns.
12. Trace the "not opened" handler bodies (or add a Go extractor).

## 6. Section-by-section scorecard
| Standard | Mapped | Present? | Quality | Note |
|---|---|---|---|---|
| 1. Application Index | 1 | yes | strong | 14-row cross-ref |
| 2. Coverage & Overview | 2 | yes | strong | Honest about unsupported stack |
| 3. Architecture | 3 | yes | strong | Components, diagram, deep auth chain |
| 4. Functional Inventory | 4 | yes | adequate | 40 F + 12 API rows; flat/dense, F-22 over-packed |
| 4A. Subsystem Inventory | 4.1 | yes | adequate | ~96 rows; ~1/3 "Inferred, names only" |
| 5. Roles & Access | 5 | yes | adequate | 5.1/5.2 strong; 5.3 narrow |
| 6. UI Catalog | 6 | partial | weak | 19 of ~600; labels "by function" |
| 7. Workflows | 7 | yes | adequate | 14 workflows; uneven depth |
| 8. Data & Integrations | 8 | yes | adequate | 8.1–8.5; 8.3 32 EXT rows |
| 8A. External Call Register | 8.1/8.3/8.5 | yes | adequate | Comprehensive; no timeout/retry/fallback; 8.5 no EXT refs |
| 8B. Stored-proc dictionary | 8.2/8.4 | n/a | n/a | No stored procs (Go/XORM); 8.4 not column-level; no ER |
| 9. Troubleshooting Matrix | 9 | yes | strong | ~30 cited rows; exceeds standard |
| 10. Security & Ops Risks | 10 | yes | strong | 14 findings + Unknowns; no severity; F13/F10 gaps |
| 11. Ownership & Maintenance | 11 | partial | weak | Shallow clone → mostly Unknown |
| 12. Diagrams | 12 | partial | adequate | 6 diagrams; no ER/deployment/auth-state/data-layer |
| 13. Glossary | 13 | yes | strong | ~70 cited terms |
| 14. Evidence Register | verification.md | yes | adequate | 126 rows (115 Supported/11 Corrected); partial audit |
| 15. Open Questions | 14 | yes | adequate | ~45 Unknowns; not prioritised/owned |
| 16. Recommendations | 15 | yes | strong | R-01–R-18 severity/effort + coverage |
| 17. Operations Runbook | 16 | partial | weak | 16.1–16.4 good; 16.5 CI catalogue |
| 18. Verification Appendix | verification.md | yes | adequate | Corrections (12 edits) + re-run; self-audit only |

## 7. Verified prior findings
| Prior finding | Status | Evidence |
|---|---|---|
| Support audit partial; 11 of 126 Corrected (~9%) | **confirmed** | `verification.md` Summary "115 Supported, 11 Corrected"; NOT-audited list explicit |
| 7.12 task table incomplete | **confirmed** (worse) | 17 rows; source registers **30** (`services/cron/tasks_*.go`); 13 missing |
| File-count discrepancy repeated in 3 places | **confirmed** | 2.1, 4.1, 14; fs vs Facts: modules 1288/1220, services 746/716, routers 519/471, models 469/449; docs "13 (9)" vs live 25 |
| §4 flat/dense (F-22 22 citations; no Area; no F-ID cross-ref) | **confirmed** | F-22 cell ~22 `routers/api/packages/api.go` citations |
| ~1/3 of 4.1 "Inferred, names only"; Purpose unaudited | **confirmed** | ~30 of ~96; `verification.md` lists 4.1 Purpose as NOT audited |
| 5.3 matrix narrow | **confirmed** | 5.3 intro concedes Actions/packages/projects/wiki/releases not broken out |
| §6 19 of ~600; labels "by function" | **confirmed** | 19 rows; `options/locale/` not inspected |
| Workflow depth uneven; F10 omits REVERSE_PROXY_TRUSTED_PROXIES | **confirmed** | "not opened" at 7.2 s9, 7.3 s3, 7.6 s9, 7.9 s9, 7.10 s9, 7.11 s7, 7.14 s5/s9; `modules/setting/security.go:68,162-164` |
| 16.5 CI catalogue not operator runbook | **confirmed** | `.github/workflows/*` only; no upgrade/rollback/backup/rotation/admin |
| 8.3/8.4 no timeout/retry/fallback; 8.5 no EXT refs; no data dictionary/ER | **confirmed** | 8.3 ID/Call/Direction/Caller/Notes; 8.5 cites `file:line` not EXT-XX; 8.4 "Key fields" only |
| 10.1 no severity; F13 line 400 vs 367 | **confirmed** | F1–F14 no severity; re-run `^;PASSWD = ` returns 367 and 400 |
| §14 not prioritised/owned | **confirmed** | ~45 Unknown bullets, no priority/owner; source-answerable items exist |
| §12 6 diagrams; no ER/deployment/auth-state/data-layer | **confirmed** | 3.2 component + 5 in §12; no ER/deployment/auth-state/data-layer |

**Summary:** all 13 prior findings **confirmed** (none fixed, none n-a). Most concrete factual defects: **incomplete 7.12 cron table** (13/30 missing) and **F13/F10 citation gaps**. Structural gaps vs the standard concentrate in **5.3 (role model), 6 (UI catalog), 16.5 (operator runbook), 8.4/12 (data dictionary + diagrams), and 14 (prioritised gaps)**.
