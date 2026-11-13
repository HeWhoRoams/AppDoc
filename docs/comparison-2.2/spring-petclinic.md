# AppDoc 2.2 Comparison: spring-petclinic
**Date:** 2026-11-11
**New doc:** docs/appdoc-2.2/application-documentation.md
**Standard:** HELP_DESK_APPLICATION_DOCUMENTATION.html

## Strengths

- **Citation density is excellent.** Nearly every claim carries a `path:line` citation (e.g. `OwnerController.java:94-130`, `application.properties:19-21`). This is at or above the reference standard's "Verified: <file>" discipline, and goes further by pinning exact line ranges.
- **Verified / Inferred / Unknown discipline is consistent and explicit.** The header defines the three markers, and the body uses them uniformly. Inferences are flagged (`**Inferred:**`) and unknowns are routed to section 14 rather than asserted. The reference standard uses the same triad; the new doc applies it as rigorously.
- **Security findings are strong and well-structured.** Section 10.1 lists 14 findings (V-1 to V-14) with severity, evidence, and impact, plus a 10.2 "unknowns that must not be treated as controls" table. This matches and in places exceeds the reference's numbered security list (10 findings) and its "unknowns" paragraph.
- **Data-entity sensitivity analysis is a clear win.** Section 8.4 gives per-entity sensitivity plus full field-level tables (type, null, key/FK, sensitivity, citation) for `owners`, `pets`, `visits`, `vets`, `types`, `specialties`. The reference standard's section 8 is a single coarser table; the new doc is more granular.
- **Troubleshooting matrix is excellent.** Section 9 has 12 symptom rows, each with evidence-supported checks, known response, and an "escalate when" column, all cited. Comparable in quality to the reference's 12-row matrix.
- **Operations runbook is complete.** Section 16 covers platform requirements, data stores, session/auth behavior, known failure modes, deployment/change process, and a generated configuration reference. Matches the reference's section 17 structure.
- **Diagrams.** Three Mermaid diagrams (component, data-flow, sequence, ER) in sections 3.2 and 12. The reference has two (flowchart, sequence). The new doc adds an ER diagram.
- **Test-suite inventory.** Section 11 maps test classes to feature IDs, including the concurrency and Postgres dialect tests (see Verified prior findings). The reference standard has no equivalent.
- **Open questions and recommendations are actionable.** 15 open questions (each with why-it-matters, how-to-close, owner, priority) and 14 recommendations (severity, effort, addresses). The reference uses plain numbered lists; the new doc's tabular form is easier to track.

## Weaknesses

- **Controller count is wrong in section 4.** It states "17 route-and-method combinations in **five** controllers," but there are **six** (`OwnerController`, `PetController`, `VisitController`, `VetController`, `WelcomeController`, `CrashController`). Section 3.1 correctly lists all six, so the document is internally inconsistent. (Verified against source: six `@Controller`/`@RestController` classes.)
- **V-12 omits the `default_batch_fetch_size=16` mitigation.** The eager-loading finding cites `Owner.java:67` / `Pet.java:56` but does not note that `spring.jpa.properties.hibernate.default_batch_fetch_size=16` is set (`application.properties:13`), which materially softens the N+1 concern. The config key appears only in the 16.6 reference table, disconnected from the finding.
- **Postgres uniqueness detail is flattened.** Section 8.2 / V-9 describe the pet-name rule as "a named unique index in PostgreSQL," but the actual index is `CREATE UNIQUE INDEX ... ON pets (owner_id, LOWER(name))` (`db/postgres/schema.sql:45`) — i.e. case-insensitive via `LOWER()`, which is a different mechanism from H2's `VARCHAR_IGNORECASE(30)` column type. The doc treats H2 and Postgres as equivalent and misses the `LOWER(name)` expression.
- **7.1 / 7.2 miss the flash-not-rendered subtlety.** On validation failure the controller calls `redirectAttributes.addFlashAttribute("error", ...)` and then returns the view name **directly** (no `redirect:`) — `OwnerController.java:79-82` and `:155-158`. Flash attributes are only rendered after a redirect, so the error message is **not** shown on the re-rendered form. The doc describes it as "sets an error flash message and re-renders the form," implying the user sees it.
- **Actuator endpoints are marked Unknown rather than Inferred.** V-4 and Q-6 say "which endpoints exist is Unknown." Given `management.endpoints.web.exposure.include=*` and the actuator starter, an **Inferred** list (health, info, metrics, env, beans, loggers, etc.) is derivable and would be more useful than a bare Unknown.
- **No Verification Appendix.** The reference standard's section 18 lists the exact reproducible commands behind each "Verified" claim. The new doc has no equivalent; its citations are line references but there is no re-runnable command appendix.
- **Evidence Register is referenced but absent from the markdown.** The header says the Evidence Register "is rendered as Appendix A," but the `.md` ends at 16.6 with no Appendix A. (It is presumably in the HTML render; the markdown deliverable is incomplete on this point.)
- **Subsystem inventory (4.1) is thin.** It is a per-folder file-count table. The reference's 4A inventories subsystems by file count, primary databases, observed purpose, and status — richer and more decision-useful.

## Gaps by cause

| Gap | Cause | Severity |
|-----|-------|----------|
| "five controllers" (should be six) in §4 | (b) writer judgment; (d) check gap (no controller-count consistency check) | Medium |
| V-12 does not note `default_batch_fetch_size=16` | (b) writer judgment (config not linked to the finding) | Low |
| Postgres index on `LOWER(name)` not captured | (b) writer judgment; (a) extractor (schema fact may not surface the index expression) | Low |
| 7.1/7.2 error flash not shown on direct re-render | (b) writer judgment (flash-vs-redirect semantics not reasoned) | Medium |
| Actuator endpoints Unknown instead of Inferred list | (b) writer judgment; (a) extractor (runtime endpoint list not extractable) | Low |
| No Verification Appendix (reproducible commands) | (c) template gap | Medium |
| Evidence Register (Appendix A) absent from markdown | (c) template gap / render | Low |
| Subsystem inventory (4.1) thin vs reference 4A | (c) template gap | Low |

## Areas to enhance

1. **Fix the controller count** in section 4 to "six controllers," and add a Check that cross-validates the controller count stated in §4 against the controllers enumerated in §3.1 (and against extracted `@Controller` facts).
2. **Link config to findings.** In V-12, note that `spring.jpa.properties.hibernate.default_batch_fetch_size=16` (`application.properties:13`) is set and what it does for the eager graph. More generally, have the writer cross-reference the 16.6 config table into relevant findings.
3. **Capture index expressions.** In 8.2 / V-9, state that the Postgres unique index is on `(owner_id, LOWER(name))` (case-insensitive via `LOWER()`), and contrast it with H2's `VARCHAR_IGNORECASE` column and MySQL's unnamed `UNIQUE` clause. Consider whether the extractor should surface index column expressions, not just names.
4. **Reason about flash semantics.** In 7.1 / 7.2, note that the error flash attribute is set but **not rendered** because the handler returns the view directly rather than redirecting, so the user does not see the error message on the re-rendered form.
5. **Provide an Inferred actuator list.** In V-4 / Q-6, list the endpoints that `management.endpoints.web.exposure.include=*` would expose (health, info, metrics, env, beans, loggers, …) marked **Inferred**, and keep the runtime-verification question open.
6. **Add a Verification Appendix** with the exact re-runnable commands behind the "Cited"/"Verified" claims (mirroring the reference standard's section 18).
7. **Emit the Evidence Register in the markdown** (Appendix A), not only the HTML, so the `.md` deliverable is self-contained.
8. **Enrich the subsystem inventory** (4.1) toward the reference's 4A shape: file count, primary data dependencies, observed purpose, and status per subsystem.

## Scorecard

| Section | Score | Notes |
|---------|-------|-------|
| 1. Application Index | 5 | Support-need table with citations and workflow links; strong. |
| 2. Coverage and Overview | 4 | Clear boundary, purpose/users, risk posture; honest about shallow history. |
| 3. Architecture | 4 | Components, diagram, and auth all cited; diagram is simple but accurate. |
| 4. Functional Inventory | 4 | 17 features well cited; docked for the "five controllers" error and thin 4.1. |
| 5. Roles and Access Model | 5 | Correctly establishes no auth; capability matrix and restriction note are excellent. |
| 6. UI Catalog | 4 | Nine pages, source-only, controls/states/roles cited; no screenshots (expected). |
| 7. Workflows | 4 | Ten detailed workflows with failure/escalation; misses the 7.1/7.2 flash subtlety. |
| 8. Data and Integrations | 4 | Connections, SQL, external calls, entity field tables, observability; misses `LOWER(name)`. |
| 9. Troubleshooting Matrix | 5 | Twelve cited rows with checks, response, and escalation; excellent. |
| 10. Security and Operational Risks | 5 | 14 severity-ranked findings + unknowns table; strong and well-evidenced. |
| 11. Ownership and Maintenance | 4 | Ownership table + test-suite inventory (incl. concurrency and Postgres tests). |
| 12. Architecture and Data-Flow Diagrams | 4 | Three Mermaid diagrams (flow, sequence, ER); clear and cited. |
| 13. Glossary | 4 | Seventeen terms with citations; covers domain and config terms. |
| 14. Open Questions | 5 | Fifteen questions with why-it-matters, how-to-close, owner, priority. |
| 15. Recommendations | 5 | Fourteen severity/effort-ranked recs mapped to findings + coverage summary. |
| 16. Operations Runbook | 4 | Platform, data stores, session, failure modes, deployment, config reference; complete. |

**Overall:** 4.3 / 5. The document is structurally complete, heavily cited, and disciplined about Verified/Inferred/Unknown. The main defects are a factual error (controller count), a few missed subtleties (batch fetch size, `LOWER(name)`, flash-not-rendered, actuator Inferred list), and the absence of a Verification Appendix and an in-markdown Evidence Register.

## Verified prior findings

| Finding | Present? | Notes |
|---------|----------|-------|
| Six controllers, not five | **No** | §4 says "five controllers"; §3.1 lists six. Source has six. Internal inconsistency; the known error persists. |
| V-12 notes `default_batch_fetch_size=16` | **No** | V-12 cites eager loading only; the `=16` value appears solely in the 16.6 config table, not in the finding. |
| Postgres index is on `LOWER(name)` | **No** | 8.2/V-9 say "a named unique index in PostgreSQL" without the `LOWER(name)` expression (`db/postgres/schema.sql:45`). |
| 7.1/7.2: error flash not shown on direct re-render | **No** | 7.1 step 4 and 7.2 step 3 describe the flash as set and the form re-rendered, without noting it is not rendered (direct view return, no redirect). |
| Actuator endpoints as an Inferred list | **No** | V-4 and Q-6 mark the endpoint set Unknown; no Inferred list is provided. |
| Cite concurrency and dialect integration tests | **Yes** | §11 cites `PetClinicConcurrencyTests` (concurrency) and `PostgresIntegrationTests` (PostgreSQL dialect compatibility), both present in `src/test/java`. |
