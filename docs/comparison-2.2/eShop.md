# AppDoc 2.2 Comparison: eShop
**Date:** 2026-11-11
**New doc:** docs/appdoc-2.2/application-documentation.md
**Standard:** HELP_DESK_APPLICATION_DOCUMENTATION.html

## Strengths

- **Citation density and discipline.** Every factual claim carries a path-and-line citation. The document never asserts a fact without evidence, and "Inferred" / "Unknown" labels are used consistently. This exceeds the reference standard, which uses "Verified" / "Inferred" / "Unknown" but with fewer per-claim citations.
- **Functional inventory depth.** Section 4 lists 22 features (F-01 to F-22) with entry points, inputs/outputs/rules, dependencies, and status. The reference standard has 14 features. The eShop doc covers every service's API surface, the Blazor storefront, the webhook demo, the MAUI apps, and the Playwright harness.
- **UI catalog completeness.** Section 6 lists 15 UI entries (UI-01 to UI-15) covering WebApp, Identity, WebhookClient, and HybridApp pages with visible controls, states/effects, and role evidence. The reference standard has ~15 screens but with less per-screen detail.
- **Security findings with severity and impact.** Section 10.1 lists 17 verified findings (V-01 to V-17) with severity, evidence, and impact. The reference standard has 10 findings. The eShop doc identifies the unauthenticated Catalog write routes, the committed signing key, card data in tokens, and the failed-order-looks-successful defect.
- **Troubleshooting matrix.** Section 9 has 20 symptom rows with checks, known response, and escalation triggers. The reference standard has 12 rows. The eShop doc covers the full event-driven order lifecycle, RabbitMQ failure modes, and webhook registration failures.
- **Operations runbook.** Section 16 covers platform requirements, data stores, session/auth behavior, known failure modes (11 rows), deployment/change process (8 steps), and a configuration reference (100+ keys). The reference standard's runbook is thinner.
- **Architecture diagrams.** Section 12 includes 5 Mermaid diagrams (component topology, checkout sequence, order-progression data flow, webhook sequence, ER diagram, start-order dependencies). The reference standard has 2.
- **Glossary.** Section 13 has 45 terms with citations. The reference standard has ~20.
- **Open questions with structure.** Section 14 uses a table with ID, question, why it matters, how to close, owner, and priority. The reference standard uses a flat numbered list.
- **Recommendations with traceability.** Section 15 has 19 recommendations with severity, effort, and "Addresses" references back to V-IDs and Q-IDs. The reference standard has 11 recommendations without cross-references.
- **Honest scoping.** The document explicitly states what was not reviewed (ClientApp beyond project file, test contents, EF migrations, static assets) and does not guess.

## Weaknesses

- **No Evidence Register / Appendix A.** The document header says "The Evidence Register (source-to-claim audit) is rendered as Appendix A" but no Appendix A exists. The `evidence.jsonl` file contains only `{"type": "audit", "performed": false, "scope": "blind regeneration - audit not performed"}`. The reference standard has a full Evidence Register (section 14) with 15 rows mapping findings to artifacts and limitations.
- **No Verification Appendix.** The reference standard's section 18 lists exact re-run commands for every "Verified" claim. The eShop doc has no equivalent.
- **Webhooks Paid-handler defect not identified.** The `OrderStatusChangedToPaidIntegrationEventHandler` logs "…Shipped…" text and is typed `ILogger<…Shipped…>` — a copy-paste defect. The new doc mentions the OrderPaid handler only in Q-17 ("Does the Webhooks OrderPaid handler mirror the shipped handler?") without identifying the actual defect.
- **MAUI ClientApp absent from UI catalog.** Section 6 covers HybridApp (UI-15) but not the native MAUI ClientApp. The reference standard catalogs every subsystem's UI surface.
- **Identity.API controllers under-catalogued in section 6.** Only the login (UI-10) and logged-out (UI-11) views are listed. The consent, device, grants, and diagnostics controllers (mentioned in 3.3 and 5.2) have no UI rows.
- **3 source-answerable questions left open.** Q-15 (TokenLifetimeMinutes readers), Q-16 (Dependabot ecosystems), and Q-17 (OrderPaid handler mirror) are all answerable from the source but remain open.
- **Section 8.5 not cross-linked to 8.3 IDs.** The failure/fallback table in 8.5 references C-IDs and X-IDs but the cross-referencing is less systematic than the reference standard's 8A.6, which explicitly ties each failure mode to a specific call.
- **No "Restriction" note in 5.3.** The reference standard's role-to-capability matrix includes an explicit "Do not infer a permission from a visible button" restriction. The eShop doc's matrix lacks this guardrail.
- **Configuration reference is raw.** Section 16.6 lists 100+ keys with "Defined at" and "Secret location" but no "Default" or "Effect" columns as specified in the template. The reference standard's runbook integrates configuration contextually.
- **No per-entity field tables for all core entities.** Section 8.4 provides field tables for CatalogItem, Order, and WebhookSubscription but not for Buyer, PaymentMethod, OrderItem, or the Basket Redis model. The reference standard's 8B data dictionary covers every procedure's parameters.

## Gaps by cause

| Gap | Cause | Severity |
|-----|-------|----------|
| No Evidence Register / Appendix A | (b) Writer judgment — audit not performed; (d) Check gap — C10 only fires when verification.md exists | High |
| No Verification Appendix | (c) Template gap — no section 18 in the 16-section template; (b) Writer judgment | Medium |
| Webhooks Paid-handler defect missed | (b) Writer judgment — handler not read in detail; (a) Extractor limitation — no "copy-paste defect" detection | High |
| MAUI ClientApp not in UI catalog | (a) Extractor limitation — no MAUI/XAML extractor; (b) Writer judgment — only project file opened | Medium |
| Identity controllers not in UI catalog | (b) Writer judgment — controllers mentioned in 3.3/5.2 but not catalogued in 6 | Low |
| 3 source-answerable Qs left open | (b) Writer judgment — items not investigated before closing | Medium |
| 8.5 not cross-linked to 8.3 IDs | (c) Template gap — template says "must reference 8.3/8.1 IDs" but enforcement is weak | Low |
| No Restriction note in 5.3 | (c) Template gap — template comment says "include Restriction note" but not enforced | Low |
| Config reference missing Default/Effect columns | (c) Template gap — generated block only emits Key/Defined at/Secret location | Medium |
| Missing field tables for Buyer, PaymentMethod, OrderItem | (b) Writer judgment — only 3 of 7 core entities got field tables | Low |
| No per-procedure data dictionary equivalent | (a) Extractor limitation — no stored-procedure extractor for .NET; N/A for eShop (no SPs) | N/A |
| No "N of M shown" completeness marker on enumerations | (c) Template gap — template comment says to add it but not enforced | Low |

## Areas to enhance

1. **Perform the source-to-claim audit.** The `evidence.jsonl` says "audit not performed." A fresh agent should verify every claim against its cited lines and produce a verification.md with the Evidence Register table. This would enable C10 and produce Appendix A.
2. **Read the Webhooks OrderPaid handler.** `src/Webhooks.API/IntegrationEvents/OrderStatusChangedToPaidIntegrationEventHandler.cs` should be read and the copy-paste defect (wrong log text, wrong `ILogger<>` generic) documented as a V-finding or at minimum closed in Q-17.
3. **Catalog the MAUI ClientApp UI.** Even a minimal row (app shell, pages, services) in section 6 would close the gap. The 198 files under `src/ClientApp/` should be at least folder-listed with a "not reviewed" status.
4. **Add Identity controller UI rows.** Consent, device, grants, and diagnostics controllers should each get a UI row in section 6 (even if minimal: route, purpose, `[Authorize]` status).
5. **Close the 3 source-answerable questions.** Q-15 (search for `TokenLifetimeMinutes` readers), Q-16 (read `.github/dependabot.yml`), and Q-17 (read the OrderPaid handler) are all answerable from the repository.
6. **Add a Verification Appendix.** Even a minimal section listing the key grep/Select-String commands used to verify the top findings would match the reference standard's rigor.
7. **Enrich the configuration reference.** Add "Default" and "Effect" columns to the 16.6 table. The extractor already has the values; the template needs to request them.
8. **Add field tables for remaining core entities.** Buyer, PaymentMethod, OrderItem, and the Basket Redis model should get the same Field|Type|Null|Key/FK|Sensitivity|Citation treatment as CatalogItem, Order, and WebhookSubscription.
9. **Add a Restriction note to 5.3.** "Do not infer a permission from a visible button or a granted scope. The authoritative enforcement is the code cited in 5.2."
10. **Cross-link 8.5 to 8.3 IDs explicitly.** Each row in 8.5 should start with the X-ID or C-ID it describes, making the cross-reference mechanical.

## Scorecard

| Section | Score | Notes |
|---------|-------|-------|
| 1. Application Index | 5 | Quick cross-reference table with 13 support-need rows, each citing primary files and linking to workflows. Exceeds the reference standard. |
| 2. Coverage and Overview | 5 | Scan-coverage table, stack explanation (node-express = Playwright), purpose/users with risk posture, system boundary with inside/outside. Very thorough. |
| 3. Architecture | 5 | Component list with per-service descriptions, Mermaid topology diagram, detailed auth/authz narrative. The auth section is more detailed than the reference standard. |
| 4. Functional Inventory | 5 | 22 features with full detail. Subsystem inventory (4.1) has 16 rows. Exceeds the reference standard's 14 features. |
| 5. Roles and Access Model | 4 | Observed concepts, enforcement per service, and a two-part matrix (OIDC client-to-scope + capability-to-caller). Missing a Restriction note. Identity controllers not in UI. |
| 6. UI Catalog | 4 | 15 UI entries with rich detail. Missing: MAUI ClientApp, Identity consent/device/grants/diagnostics controllers. |
| 7. Workflows | 5 | 9 workflows with numbered steps, failure/escalation paragraphs, and citations. The event-driven order progression (7.5) is particularly strong. |
| 8. Data and Integrations | 4 | Connections (10), SQL (1 hand-written query), external calls (13), entities with sensitivity, failure/fallback (23 rows). Missing field tables for 4 of 7 core entities. 8.5 cross-linking could be tighter. |
| 9. Troubleshooting Matrix | 5 | 20 rows covering the full order lifecycle, RabbitMQ, Redis, Identity, webhooks, and catalog. Exceeds the reference standard's 12 rows. |
| 10. Security and Operational Risks | 5 | 17 verified findings with severity/evidence/impact. 10.2 "Unknowns" table with 10 controls. Exceeds the reference standard's 10 findings. |
| 11. Ownership and Maintenance | 4 | 10-row table with evidence and status. Test-suite rows present. Missing: named owners (Unknown, correctly). |
| 12. Architecture and Data-Flow Diagrams | 5 | 5 Mermaid diagrams (sequence, data flow, webhook, ER, start-order). Exceeds the reference standard's 2. |
| 13. Glossary | 5 | 45 terms with citations. Exceeds the reference standard's ~20. |
| 14. Open Questions | 4 | 19 questions in a structured table with priority/owner/how-to-close. 3 are source-answerable but left open. |
| 15. Recommendations | 5 | 19 recommendations with severity/effort/Addresses cross-references. Coverage summary at 15.1. Exceeds the reference standard. |
| 16. Operations Runbook | 4 | 6 subsections including the new 16.6 config reference. 11 failure-mode rows. 8 deployment steps. Config reference missing Default/Effect columns. |
| Evidence Register (Appendix A) | 1 | Missing entirely. Header promises it; evidence.jsonl says audit not performed. |
| Verification Appendix | 1 | Missing entirely. No re-run commands. |

## Verified prior findings

| Finding | Present? | Notes |
|---------|----------|-------|
| F-18 → 7.5 | **Yes** | F-18 row in section 4 says "see section 7.5" and links correctly. Fixed from the prior "says 7.3" error. |
| Webhooks Paid-handler defect (wrong log text and `ILogger<>` type) | **No** | Not identified. Q-17 asks "Does the OrderPaid handler mirror the shipped handler?" but does not state the answer. The defect (log text says "Shipped", generic type is `ILogger<…Shipped…>`) is absent from the document. |
| Identity.API controllers/views and MAUI ClientApp in sections 4 and 6 | **Partial** | Identity login (UI-10) and logged-out (UI-11) views are in section 6. Consent, device, grants, and diagnostics controllers are NOT in section 6. MAUI ClientApp is F-22 (Unknown) in section 4 but has NO UI row in section 6. HybridApp is UI-15. |
| Close the 3 source-answerable questions | **No** | Q-15 (TokenLifetimeMinutes readers), Q-16 (Dependabot ecosystems), and Q-17 (OrderPaid handler mirror) are all still open in section 14. None were investigated and closed. |
| Fix E-17 re-run command | **N/A** | No verification.md or Evidence Register exists in this output. The `evidence.jsonl` records "audit not performed." E-17 (broken re-run command with unescaped `(`) does not apply because there are no re-run commands at all. |
