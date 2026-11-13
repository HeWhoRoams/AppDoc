# AppDoc 2.2 Comparison: gitea
**Date:** 2026-11-11
**New doc:** docs/appdoc-2.2/application-documentation.md
**Standard:** HELP_DESK_APPLICATION_DOCUMENTATION.html

## Strengths

- **Structure matches the standard's skeleton.** All 16 numbered sections are present and in the same order as the reference (Application Index → Coverage → Architecture → Functional Inventory → Roles → UI Catalog → Workflows → Data & Integrations → Troubleshooting → Security → Ownership → Diagrams → Glossary → Open Questions → Recommendations → Operations Runbook). The standard's `4A` (subsystem inventory) is folded into `4.1`, and `8A`/`8B` (external-call register / stored-procedure dictionary) are folded into `8.1`–`8.5` — a reasonable consolidation for a Go app with no stored procedures.
- **Citation discipline is the standout.** Nearly every claim carries a `path:line` citation, and the document opens with an explicit reading contract (Cited / Inferred / Unknown, "value omitted" for secrets, Evidence Register as Appendix A). This is at or above the standard's bar.
- **Epistemic honesty.** `Unknown` items are routed to section 14 with owner and priority; section 2.1 states exactly what was and was not read (608 templates, 502 public assets, 419 web_src, 407 migrations, 331 options, 886 tests) and refuses to guess. The standard does the same; the gitea doc does it with a generated scan-coverage block.
- **Functional inventory is concrete.** F-1…F-18 each have an entry point, inputs/outputs/rules, dependencies, and a Cited status, and the 4.1 subsystem table maps every top-level folder to the F-IDs it serves.
- **Data model is field-level.** Section 8.4 gives per-field tables (User, Repository, Issue) with type, null, key/FK, sensitivity, and a per-field citation — stronger than the standard's entity-level table.
- **Security section is well-formed.** 10.1 lists five verified findings (V-1…V-5) with severity, evidence, and impact; 10.2 is an explicit "unknowns that must not be treated as controls" table (TLS, rate limiting, backup, secret management) — the same pattern as the standard.
- **Operations runbook is the most complete section.** 16.1–16.6 cover platform requirements, data stores, session/auth behavior, a 10-row failure-mode table, a deployment/change table, and a generated config reference.
- **Diagrams.** Three Mermaid diagrams (architecture flowchart, ER diagram, git-push sequence) with captions and citations.

## Weaknesses

- **Stack detection is wrong for the primary language.** Section 2.1 reports **go** as "no (generic only), 1 file read" and **node-express** as "yes, 278 files read." Gitea *is* a Go application; the Go stack is the primary one and is marked unsupported/generic-only, so Go-specific facts (framework, dependency graph) are thin. The 278 "node-express" files are the `web_src/` frontend, `tests/e2e/` Playwright harness, and `tools/` TypeScript tooling — the doc correctly notes there is no Express server, but the stack *label* is still misleading. This is the single largest accuracy problem in the document.
- **Cron is referenced, not enumerated.** Cron is a first-class Gitea subsystem (F-16, 7.5, 11, 16.4) but the 30 registered tasks are never listed. 7.5 names the three registration functions (`initBasicTasks`, `initExtendedTasks`, `initActionsTasks`) and the manual-run path, but there is no task-by-task list with schedule, default-enabled state, and what each does.
- **Config reference (16.6) is a raw dump, not a curated reference.** It lists ~900+ rows (and defers "9052 more" to facts.json), the vast majority tagged "(commented default)" with `no` secret. Low signal-to-noise; it reads as an unfiltered extractor output rather than an operator-facing reference.
- **External-call register is thin.** 8.3 lists only five calls (X-1…X-5). The standard's 8A register is far more granular (23 DB connections, a multi-hundred-row stored-procedure register, direct-SQL tables, HTTP/COM boundaries). For gitea the equivalent depth (per-endpoint API surface, per-cron outbound call, per-storage-backend call) is not present.
- **Ownership (11) is thin.** "Git history is shallow, so ownership is Unknown." The test-coverage mapping is good, but `MAINTAINERS` and `CONTRIBUTING.md` are named and then not read, leaving the section mostly a file-to-F-ID table.
- **UI catalog (6) is shallower than the standard.** 11 rows vs. the standard's 14, and the gitea rows are route-level (route + role) rather than control-level (visible fields, states, effects). The standard's UI catalog names the actual form controls and per-state behavior.
- **No Verification Appendix.** The standard has section 18 (Verification Appendix); the gitea doc has no equivalent in-document section (the check output lives in a separate `check-report.md`).
- **Evidence Register relocated.** The standard puts it at section 14; the gitea doc moves it to Appendix A and reuses 14 for Open Questions. Not a defect, but a structural deviation from the reference.

## Gaps by cause

| Gap | Cause | Severity |
|-----|-------|----------|
| Go stack reported "generic only"; primary-language facts thin | (a) extractor limitation — no Go stack handler | High |
| Frontend/tooling mislabeled as "node-express" supported stack | (a) extractor limitation — stack marker heuristic | Medium |
| 30 cron tasks not enumerated (no 7.12) | (a) extractor limitation — no cron-task-list extraction; (b) writer did not hand-enumerate | High |
| F-13 (Git over SSH) not deepened to the specific lines the answer key expects | (b) writer judgment | Low |
| F-10 (admin management) does not mention `REVERSE_PROXY_TRUSTED_PROXIES` | (b) writer judgment | Low |
| 5.3 matrix not widened to projects / wiki / releases / token scopes as rows | (b) writer judgment | Medium |
| 16.5 lacks explicit `gitea doctor` and `gitea admin` operator rows | (b) writer judgment | Medium |
| Ownership (11) left thin; MAINTAINERS/CONTRIBUTING not read | (b) writer judgment | Medium |
| Config reference (16.6) is an unfiltered dump | (c) template gap — no curation/filter step for the generated config block | Medium |
| No dedicated "full cron task list" section in the template | (c) template gap | Medium |
| No Verification Appendix (standard §18) in the template | (c) template gap | Low |
| Evidence Register at Appendix A rather than §14 | (c) template gap (placement) | Low |
| Check passes despite wrong stack label and thin Go facts | (d) check gap — check verifies citation resolution + structure, not stack correctness or fact depth | High |
| Check does not verify cron-task enumeration completeness | (d) check gap | Medium |
| Check does not verify the role matrix covers every F-ID / capability area | (d) check gap | Low |

## Areas to enhance

1. **Add a Go stack handler** so the primary language yields full facts (module graph, framework detection, dependency list). This is the highest-leverage fix; it directly corrects the "go = generic only" and "node-express = supported" mislabels.
2. **Tighten stack-marker heuristics** so a pnpm/Vite frontend workspace is not labeled a supported "node-express" web stack.
3. **Extract the cron task list** (all `RegisterTask` calls across `tasks_basic.go`, `tasks_extended.go`, `tasks_actions.go`) into a generated table: name, schedule, default-enabled, one-line purpose. Render it as a dedicated section (the answer key's "7.12").
4. **Deepen F-13 (Git over SSH)** to cite the specific accept/auth lines the answer key expects, not just the `session`-channel range.
5. **Expand F-10 (admin management)** to name the reverse-proxy settings it governs, including `REVERSE_PROXY_TRUSTED_PROXIES`.
6. **Widen the 5.3 role-to-capability matrix** with explicit rows for projects, wiki, releases, and token scopes (currently only packages and Actions are rows; token scopes appear only in the restriction note).
7. **Add operator rows to 16.5** for `gitea doctor` and `gitea admin` (rollback and secret rotation are already present; `gitea dump` is mentioned under Backup/Restore).
8. **Curate the 16.6 config reference**: surface non-commented, security- and operations-relevant keys inline; move the full ~9k-key dump to an appendix or facts.json reference.
9. **Read `MAINTAINERS` and `CONTRIBUTING.md`** to fill section 11 (ownership) beyond the file-to-F-ID table.
10. **Expand 8.3** toward the standard's 8A granularity: per-endpoint API surface, per-cron outbound call, per-storage-backend call.
11. **Add a Verification Appendix** (or fold `check-report.md` into the document) to match standard §18.
12. **Add Check rules** for: (a) cron-task enumeration completeness, (b) role-matrix coverage of every F-ID, (c) stack-label sanity (flag a "supported" stack whose marker file has no matching framework dependency).

## Scorecard

| Section | Score | Notes |
|---------|-------|-------|
| 1. Application Index | 4 | Strong support-need → file → workflow cross-reference; every row cited. |
| 2. Coverage and Overview | 4 | Excellent coverage honesty and boundary; undermined by the wrong stack labels in 2.1. |
| 3. Architecture | 5 | Components, flowchart, and auth/authz all cited and accurate. |
| 4. Functional Inventory | 4 | 18 features + subsystem table; cron not enumerated, a few features thin. |
| 5. Roles and Access Model | 4 | Cited matrix present; not widened to projects/wiki/releases/token scopes. |
| 6. UI Catalog | 3 | 11 route-level rows; shallower than the standard's control-level catalog. |
| 7. Workflows | 4 | 7 workflows with failure/escalation; no 7.12 cron-task enumeration. |
| 8. Data and Integrations | 4 | Field-level entity tables + failure/fallback; external-call register thin. |
| 9. Troubleshooting Matrix | 4 | 12 symptoms, each with a cited check and escalation trigger. |
| 10. Security and Operational Risks | 5 | 5 verified findings + explicit "unknowns not to treat as controls" table. |
| 11. Ownership and Maintenance | 2 | Ownership Unknown; test-coverage mapping good but MAINTAINERS/CONTRIBUTING not read. |
| 12. Architecture and Data-Flow Diagrams | 4 | ER + git-push sequence diagrams, cited. |
| 13. Glossary | 4 | 10 terms, each cited. |
| 14. Open Questions and Documentation Gaps | 4 | 8 questions with owner and priority; well-scoped. |
| 15. Recommendations | 4 | 9 recommendations with severity/effort, each mapped to a finding. |
| 16. Operations Runbook | 4 | Most complete section; missing doctor/admin rows, config reference is a raw dump. |

**Overall: 3.9 / 5.** Structurally and citation-wise at or above the reference standard; held back by the Go-stack mislabel, the unenumerated cron subsystem, the thin ownership section, and the uncurated config reference.

## Verified prior findings

| Finding | Present? | Notes |
|---------|----------|-------|
| 7.12 lists all 30 cron tasks | No | No section 7.12 exists. Cron is covered in 7.5 (Run a cron task) and F-16, naming `initBasicTasks`/`initExtendedTasks`/`initActionsTasks` and the manual-run path, but the 30 individual tasks are not enumerated. |
| F13 cites lines 367 and 400 | No | F-13 is "Git over SSH," citing `modules/ssh/server.go:40-52`. Lines 367/400 are not cited in F-13 (in the 16.6 config reference those lines are `database.PASSWD` entries). |
| F10 mentions `REVERSE_PROXY_TRUSTED_PROXIES` | No | F-10 is "Admin user, org, repo, package, hook, auth, notice, application management," citing `routers/web/web.go:800-870`. It does not mention `REVERSE_PROXY_TRUSTED_PROXIES`; that key appears only in the 16.6 config reference (`custom/conf/app.example.ini:479`). |
| Widen 5.3 (Actions, packages, projects, wiki, releases, token scopes) | Partial | The 5.3 matrix has rows for F-14 (Package registry) and F-15 (Actions). It has no separate rows for projects, wiki, or releases. Token scopes appear only in the "Restriction" note, not as a matrix row. |
| 16.5 operator rows (`gitea dump`, `doctor`, `admin`, rollback, secret rotation) | Partial | 16.5 has Rollback and Secret rotation rows and mentions `gitea dump`/`restore-repo` under Backup/Restore. It has no explicit operator rows for `gitea doctor` or `gitea admin`. |
