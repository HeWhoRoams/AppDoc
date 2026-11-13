# AppDoc 2.2 Comparison: flaskr-tdd
**Date:** 2026-11-11
**New doc:** docs/appdoc-2.2/application-documentation.md
**Standard:** HELP_DESK_APPLICATION_DOCUMENTATION.html

## Strengths

- **Inline path-and-line citations on nearly every claim.** Every row in the functional inventory, role matrix, UI catalog, workflows, data tables, and security findings carries a `file:line` citation. This is at or above the reference standard's citation density, and it is the single biggest quality differentiator of the 2.2 output.
- **Clean, consistent 16-section structure** with a "How to read this document" preamble that defines the Cited / Inferred / Unknown / Recommendation vocabulary up front. The reference standard buries the same vocabulary in a paragraph under the title; the new doc makes it a first-class contract.
- **Security findings are tabular with severity, evidence, and impact columns** (§10.1). The reference standard uses a numbered list; the new doc's table is easier to scan and to feed into a remediation tracker.
- **Role-to-capability matrix (§5.3) is complete and accurate** for the app's two effective roles (logged-in / anonymous), with per-cell citations and an explicit "do not infer a permission from a visible control" restriction note that mirrors the reference standard's §5.3 restriction.
- **Honest coverage and unknowns.** §2.1 (scan coverage), §14 (open questions), §15.1 (coverage summary), and §16.5 (deployment/rollback/backup all marked Unknown) are candid about what was and was not inspected. The reference standard does the same, but the new doc's "Unknown - see Open questions" cross-references are tighter.
- **Machine-generated blocks are present and correct.** The `scan-coverage` and `config-reference` generated blocks render cleanly and match the source.
- **Mermaid diagrams are clean and captioned** (§3.2 architecture, §12 data-flow + ER). The reference standard's diagrams are comparable in quality.
- **Troubleshooting matrix (§9) is well-formed** with symptom / checks / known response / escalate-when columns, matching the reference standard's §9 shape.
- **Recommendations (§15) are severity- and effort-tagged** and each maps back to a specific finding or unknown (V-1…V-5, 10.2 rows, Q-1, Q-2). The reference standard's §16 is a numbered list without per-item traceability; the new doc's "Addresses" column is a genuine improvement.

## Weaknesses

- **Username-enumeration finding is not called out as a distinct security finding.** `app.py:79-83` returns "Invalid username" vs "Invalid password" as separate errors, which lets an attacker enumerate valid usernames. The new doc cites these lines in V-5 (timing side channel) and §7.1, but never names the enumeration property. The reference standard's §10 explicitly names analogous findings (hardcoded guest bypass, debug SQL backdoor) as distinct items.
- **Glossary (§13) is thin (7 terms) and missing the `safe` filter row.** The `safe` Jinja filter is central to finding V-3 (stored XSS) but is not defined in the glossary. The reference standard's §13 has 19 terms including every non-obvious domain term and session variable.
- **Config reference (§16.6) is incomplete.** The generated block lists only `DATABASE_URL`, `USERNAME`, `PASSWORD`. `SECRET_KEY` (`app.py:25`) is a module-level config constant that signs all session cookies and is the subject of finding V-2, yet it is absent from the config reference. The effect-notes paragraph below the table does mention `SECRET_KEY`, but the table itself is wrong.
- **No Verification Appendix.** The reference standard's §18 lists the exact `Select-String` / `Get-ChildItem` commands used to verify every "Verified" claim, so a reviewer can re-run them. The new doc has no equivalent; its citations are inline but not packaged as reproducible commands.
- **Evidence Register is demoted to "Appendix A"** rather than a numbered section. The reference standard's §14 is a first-class numbered section with a Finding / Status / Supporting artifact / Limitation table. The new doc's preamble says the register "is rendered as Appendix A," but the appendix is not visible in the markdown body (it is presumably in the HTML render). This is a structural regression from the reference standard.
- **UI Catalog (§6) is source-only.** The reference standard's §6 explicitly notes "No screenshots or live application session were supplied" and still catalogs 14 screens with per-screen states. The new doc catalogs 3 screens (appropriate for the app's size) but the "Source-only catalog; no screenshots or live session" note is a one-liner rather than a deliberate scoping statement.
- **Subsystem inventory (§4.1) is thin.** Four rows (project/, tests/, root, docs/, .github/) with no file-count or database-dependency detail. The reference standard's §4A inventories 30+ subsystems with file counts, primary databases, and observed purpose. For a 6-file app this is less critical, but the table lacks the "Files" count column the reference standard uses.
- **Troubleshooting matrix (§9) has only 5 rows.** The reference standard's §9 has 12 rows. For a 6-route app 5 is defensible, but the matrix could include the "delete returns status 0 with exception text" row more explicitly (it is present but the "Escalate when" column is thin).
- **Security findings (§10.1) number 5.** The reference standard's §10 has 10 findings. For a 6-file teaching app, 5 is appropriate, but the doc does not include a finding for the **unauthenticated `index` route rendering all posts** (data exposure) or the **`add_entry` 401 with no body** (inconsistent error handling) as distinct items; they are mentioned in §7.2 but not elevated to findings.
- **Ownership and maintenance (§11) is thin.** One row is "Unknown" (ownership/maintainers). The reference standard's §11 has 6 rows (business owner, technical owner, process owner, DB/integration owners, documentation owner, release/change process) all marked Unknown with evidence notes. The new doc collapses this into a single "Unknown" row.

## Gaps by cause

| Gap | Cause | Severity |
|-----|-------|----------|
| Username-enumeration finding not called out as a distinct V-item | (b) writer judgment | Medium |
| Glossary missing `safe` filter row | (b) writer judgment | Low |
| Config reference missing `SECRET_KEY` | (a) extractor limitation | Medium |
| No Verification Appendix (reproducible commands) | (c) template gap | High |
| Evidence Register demoted to Appendix A instead of numbered §14 | (c) template gap | Medium |
| Glossary thin (7 terms vs 19 in reference) | (b) writer judgment | Low |
| UI Catalog source-only, no deliberate scoping note | (a) extractor limitation | Low |
| Subsystem inventory lacks file-count / DB-dependency columns | (c) template gap | Low |
| Ownership section collapsed to one Unknown row | (b) writer judgment | Low |
| No Check gate for "config reference completeness" (SECRET_KEY missed) | (d) Check gap | Medium |
| No Check gate for "glossary covers all terms cited in findings" (`safe` missed) | (d) Check gap | Low |
| No Check gate for "every V-item has a matching R-item" (all present, but no automated check) | (d) Check gap | Low |

## Areas to enhance

1. **Add a distinct username-enumeration finding (V-6, Low/Medium).** `app.py:79-83` returns different error strings for bad username vs bad password. This is a real information-disclosure finding and should be its own row in §10.1 with a matching recommendation in §15.
2. **Add a `safe` row to the glossary (§13).** Define it as "Jinja filter that marks a string as safe (unescaped) HTML; used on `Post.text` in `index.html:74` and `search.html:55`, enabling stored XSS (V-3)."
3. **Fix the config-reference extractor to capture `SECRET_KEY`.** The generated block in §16.6 should list all module-level config constants that affect runtime behavior, not just those read via `os.getenv`. `SECRET_KEY` at `app.py:25` is a config constant and must appear.
4. **Add a Verification Appendix (§17 or Appendix B).** For each "Cited" claim, list the exact `grep` / `Select-String` command that reproduces it. This is the reference standard's strongest audit feature and is entirely absent from the 2.2 template.
5. **Promote the Evidence Register back to a numbered section (§14).** The reference standard treats it as a first-class section with a Finding / Status / Supporting artifact / Limitation table. The 2.2 template should render it as §14, not "Appendix A."
6. **Expand the glossary to cover every non-obvious term cited in findings.** Any term that appears in a V-item or R-item but is not defined in §13 is a gap. A Check rule can enforce this.
7. **Add a Check rule: "config reference completeness."** The Check should verify that every module-level config constant (assignment to `app.config[...]` or `os.getenv` or a module-level `UPPER_CASE = ...` that is referenced by `app.config.from_object`) appears in the config reference.
8. **Add a Check rule: "glossary covers finding terms."** Every term cited in a §10.1 finding or §15 recommendation that is not a common English word should have a §13 row.
9. **Expand the ownership section (§11) to match the reference standard's 6-row shape** (business owner, technical owner, process owner, DB/integration owners, documentation owner, release/change process), even if all are Unknown.
10. **Add a deliberate scoping note to the UI Catalog (§6).** State explicitly that no screenshots or live session were available, and that the catalog is source-derived. The reference standard does this; the new doc's one-liner is insufficient.

## Scorecard

| Section | Score | Notes |
|---------|-------|-------|
| 1. Application Index | 4 | Clean 5-row table with workflow links. Missing a "Quick cross-reference" sub-section like the reference standard's §1, but the table serves the same purpose. |
| 2. Coverage and Overview | 4 | Scan-coverage block is accurate; purpose/users and system boundary are well-scoped. Slightly thinner than the reference standard's §2.3 (which enumerates 20+ database names), but appropriate for the app's scope. |
| 3. Architecture | 4 | Components, diagram, and auth/authz are all cited. The auth/authz sub-section is accurate and complete for the app. |
| 4. Functional Inventory | 4 | 6 features, all cited. Missing an "Area" column the reference standard uses, but the "Area" column is present here. Subsystem inventory (§4.1) is thin (4 rows, no file counts). |
| 5. Roles and Access Model | 5 | Complete, accurate, well-cited. The role-to-capability matrix is the strongest section in the document. |
| 6. UI Catalog | 3 | 3 screens catalogued (appropriate for the app), but source-only with no deliberate scoping note. Missing the reference standard's per-screen "States and effects" depth. |
| 7. Workflows | 4 | 4 workflows, all cited, with failure/escalation notes. Does not describe the client-side `main.js` delete behavior (element removed only on `status === 1`, reload unconditional), which is a gap for the delete workflow. |
| 8. Data and Integrations | 4 | Connections, stored procedures (none), external calls (none), data entities, and failure/observability are all present and cited. Thinner than the reference standard's §8A (23 DB connections, 30+ stored procedures), but appropriate for the app's scope. |
| 9. Troubleshooting Matrix | 3 | 5 rows, well-formed, but thinner than the reference standard's 12 rows. "Escalate when" column is sparse. |
| 10. Security and Operational Risks | 4 | 5 findings, all cited, with severity/impact. Missing username-enumeration as a distinct finding. Unknowns table (§10.2) is well-formed and matches the reference standard's shape. |
| 11. Ownership and Maintenance | 3 | Thin. One "Unknown" row for ownership. Missing the reference standard's 6-row shape (business/technical/process/DB/doc/release owners). |
| 12. Architecture and Data-Flow Diagrams | 4 | Two mermaid diagrams (data-flow + ER), both captioned and cited. Comparable to the reference standard's §12. |
| 13. Glossary | 2 | 7 terms, missing `safe` and other finding-cited terms. Thinnest section in the document. |
| 14. Open Questions and Documentation Gaps | 4 | 3 questions, well-formed with owner/priority. Appropriate for the app's scope. |
| 15. Recommendations | 4 | 12 recommendations, severity/effort-tagged, each mapped to a finding or unknown. Stronger traceability than the reference standard's §16. |
| 16. Operations Runbook | 4 | Platform requirements, data stores, session behavior, failure modes, deployment, and config reference are all present. Config reference is incomplete (missing `SECRET_KEY`). Deployment/rollback/backup correctly marked Unknown. |

## Verified prior findings

| Finding | Present? | Notes |
|---------|----------|-------|
| 7.5 step 4: element removed only when `status === 1`, reload unconditional | **Partially** | §7.3 step 3-4 documents the server-side `status: 1` / `status: 0` JSON contract and cites the test assertions (`tests/app_test.py:80-88`). It does **not** describe the client-side `main.js` behavior: `if (result.status === 1) { node.parentNode.removeChild(node); }` followed by an unconditional `location.reload()`. The client-side detail is a gap. |
| Username-enumeration finding (`app.py:80-83`) | **No** | The doc cites `app.py:79-83` in V-5 (timing side channel) and §7.1 (login workflow), but does **not** call out username enumeration as a distinct security finding. The distinct "Invalid username" vs "Invalid password" error strings are a real information-disclosure property that should be its own V-item. |
| Glossary `safe` row | **No** | §13 glossary has 7 terms and does **not** include a `safe` row. The `safe` filter is central to V-3 (stored XSS) but is only mentioned in the V-3 finding text, not defined in the glossary. |
