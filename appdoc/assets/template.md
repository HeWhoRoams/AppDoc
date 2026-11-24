# <Target name> Documentation
<!-- appdoc:template 2.8 -->
<!-- appdoc:guide Replace the title placeholder. Copy this file to docs/appdoc/application-documentation.md and fill every section.
Keep the `appdoc:template` stamp and the `appdoc:generated` markers. Delete every `appdoc:guide` comment as you fill its section (C9 fails while any remain).
CONVENTIONS:
- Citation = backticked Target-relative path with optional line or range: `portal/verify.asp:6`, `src/App.java:40-52`. Owner context is cited as `appdoc-context.md`. Cite the full path: a bare file name that lives in a folder (`verify.asp:6`) fails C1 on template 2.7; `appdoc build --expand-citations` rewrites the unique ones.
- Prefix a reasoned (not directly observed) statement with **Inferred:** and still cite what it rests on.
- Anything you cannot establish is Unknown: add it as a row of section 14; elsewhere write "Unknown - see Open questions."
- NEVER write a secret value. Write "value omitted" and cite the location.
- Diagrams go in ```mermaid fences.
- Keep every heading (all 17) and every table header exactly as given (C3, C8, C9). IDs (F-1, UI-1, C-1, X-1, V-1, Q-1, R-1) are unique and every ID you mention must exist (C10). Order sections 10.1 and 15 by severity, most severe first (C9); keep each ID when you move a row.
- Handles: the document refers to evidence only through IDs, Citations, count markers, notes and generated blocks, never through a number or claim typed from memory.
  - A count is a count marker: the number between an opening `appdoc:count CLASS` comment and a closing `/appdoc:count` comment (the same comment syntax as the generated markers, with the class in the opening one). Write any number there and `appdoc fill` replaces it. Classes: V F UI C X Q R, rows superseded, routes jobs pages commands config-keys (C15). A hand-written "N of M" is only an advisory.
  - A limitation of a generated block is a line of `docs/appdoc/notes.jsonl` ({"block", "text", "cites", "block_sha"}), rendered by `fill` as "Known extractor limitation: ..." inside its block; leave `block_sha` empty and `appdoc build` seals it. That label is reserved: written by hand in the Narrative it fails C18.
  - Never delete an `evidence.jsonl` row; a correction is a new row with `"supersedes": "E-n"`. A row that closes a question (`Answerable`) names the answering section in `"answered_in"`.
  - The audit record's `scope` describes the method only: C17 rejects any ID token and any digit 0-9 at all, even a lone "3" (words such as "three" are fine); what the audit covered is computed into Appendix A.1, and a section left out is a reasoned entry in `exclusions` (C17).
- Writing rules the Check enforces (2.7):
  - A backticked file name is a Citation even in a negative sentence: write a name that does not exist without backticks (appdoc-context.md does not exist), or C1 fails.
  - A sentence that carries a count marker still needs a Citation (C5).
  - A `|` inside a table cell must be written `\|`.
  - A ref allows one live register row. Sections 10.2 (Present controls), 16.5, 17 and the sampled rows of section 9 are planned per row: `audit-plan` names a key `<section>/<slug>` for each (the slug is the lower-cased first cell, non-alphanumerics to `-`; a repeat gets `-2`, `-3`), and the auditor writes one row per planned key with that key as its ref, never one combined row for the section. C19 fails any planned key without a live row.
  - Section 11 Status is Cited, Inferred or Unknown.
  - C16 universal claims cite only single lines: a sentence with all, any, each, every, always, never, whole or entire needs the covering range (`path:start-end`) or **Inferred:**. C20 citation precision: a cell may cite at most 5 sources, each range at most 100 lines, and a wide range that is the claim's only lined Citation fails. A plain `build` prints both as advisories and `check --strict` fails on them: fix them before the audit plan.
- Section 17 (Build, Run and Test Locally): the Command cell holds exactly one backticked command and nothing else (extra commands and prose go under the table). In each Command cell write a backticked command, `Unknown - see Open questions.` (the repository does not show it; also a row in section 14), or `Not applicable` (cite the evidence). Any row but an Unknown one cites its Evidence with a lined Citation (C9).
- Run `appdoc fill` to write the generated blocks (scan-coverage, repo-docs, entry-points, access-model, connections, integrations, closed-questions, config-reference, scheduled-jobs, pipeline, appendix-a); never edit them by hand (C7). Run it again after every change to evidence.jsonl or notes.jsonl. -->

**Target:** <fill: folder name> | **Commit:** <fill: facts.json target.commit> | **Evidence date:** <fill: YYYY-MM-DD>

**How to read this document.** *Cited* claims carry a path-and-line Citation. **Inferred:** marks reasoning from cited evidence. *Unknown* items are listed in section 14 and must not be assumed. Secret values are never reproduced; their locations are cited with "value omitted". The Evidence Register (source-to-claim audit) is rendered as Appendix A.

## 1. Application Index
<!-- appdoc:guide The support cross-reference: one row per common support need, pointing to the screen or file and the workflow (link workflows as [7.1 Name](#71-name)). The table of contents is generated by render. Write last. -->

| Support need | Primary screen or file | Workflow |
|---|---|---|

## 2. Coverage and Overview
<!-- appdoc:guide Fed by: facts-summary.md, `stack` Facts, Owner context. Name every unsupported Stack here (C7 fails otherwise). -->

### 2.1 What was inspected
<!-- appdoc:guide The generated block below states stacks, counts and pruned folders. Add what was NOT read (folders, file types, runtime) and name unsupported Stacks explicitly. A sentence here that states the audit state must not state counts by result (they go stale after every delta pass): use a `rows` count marker and refer to Appendix A. -->

<!-- appdoc:generated scan-coverage -->
<!-- /appdoc:generated scan-coverage -->

### 2.2 Purpose and users
<!-- appdoc:guide What the Target does and who uses it. Cite source or `appdoc-context.md`; otherwise Unknown. End with one sentence on overall risk posture naming the most severe 10.1 IDs. -->

### 2.3 System boundary
<!-- appdoc:guide What is inside the Target and which external systems it touches. -->

### 2.4 Repository documentation (generated)
<!-- appdoc:guide The generated block below lists the documentation files in the repository. Do not edit it: run `appdoc fill`. -->

<!-- appdoc:generated repo-docs -->
<!-- /appdoc:generated repo-docs -->

## 3. Architecture
<!-- appdoc:guide Fed by: folders, entry points, `connection` Facts, `auth_check` Facts. Every paragraph/list item needs a Citation, **Inferred:**, or Unknown. -->

### 3.1 Components
<!-- appdoc:guide Main modules/folders and their responsibilities, each cited. -->

### 3.2 Diagram
<!-- appdoc:guide One Mermaid diagram of the components (```mermaid fence). -->

### 3.3 Authentication and authorization
<!-- appdoc:guide How users are authenticated and checks enforced. Cite `auth_check` Facts and source lines. -->

## 4. Functional Inventory
<!-- appdoc:guide Fed by: `entry_point` Facts grouped by subsystem. The generated block below counts every entry point; never write those counts by hand, and quote them only as the block states them.
One row per feature or route group, IDs F-1, F-2, ...
Area names the subsystem or domain. Keep each cell to about five Citations; split the row otherwise.
Status is Cited, Inferred or Unknown. -->

<!-- appdoc:generated entry-points -->
<!-- /appdoc:generated entry-points -->

| ID | Area | Feature | Entry point | Inputs, outputs and rules | Dependencies | Status |
|---|---|---|---|---|---|---|

### 4.1 Subsystem inventory
<!-- appdoc:guide Fed by: the top-folders table in facts-summary.md. One row per subsystem, cited to the folder (`src/web/`).
Files is the Facts file count for that folder as a plain number (C7 compares it). Features lists the F-IDs from section 4. -->

| Subsystem | Files | Features | Primary data and dependencies | Purpose | Status |
|---|---|---|---|---|---|

## 5. Roles and Access Model
<!-- appdoc:guide Fed by: `auth_check` Facts, role names. If the Target has no auth, still fill 5.1-5.3: say no roles were observed and mark every capability public. -->

### 5.1 Observed role concepts
<!-- appdoc:guide Role, group, scope or client names found in source, each cited. -->

### 5.2 Authorization enforcement
<!-- appdoc:guide Where and how access is enforced (middleware, attributes, checks), each cited. Name routes with no check. -->

### 5.3 Role-to-capability matrix
<!-- appdoc:guide Rows are capability areas from section 4 (cover every Area); the first column is named Capability and the other columns are roles you name. Y = allowed (cited), ? = unclear, blank = no.
Include rows a role must NOT have, and a token/scope view where the API is scope-gated. Keep the fixed Restriction line below the table (C9). -->

| Capability | Role 1 | Role 2 |
|---|---|---|

**Restriction:** do not infer a permission from a visible control or a granted scope; enforcement is the code cited in 5.2.

### 5.4 Application-layer access (generated)
<!-- appdoc:guide The generated block below states the application-layer access model the extractor read. Do not edit it: run `appdoc fill`. -->

<!-- appdoc:generated access-model -->
<!-- /appdoc:generated access-model -->

## 6. UI Catalog
<!-- appdoc:guide Fed by: `entry_point` Facts of type page, their inputs. Start with: "Source-only catalog; no screenshots or live session."
One row per page or screen, IDs UI-1, UI-2, ... Cover every UI project (web, identity, admin, mobile);
if you catalog only some screens, say "N of M screens catalogued" and name the rest in section 14. -->

| ID | Page | Route or entry | Reached from | Visible controls and data | States and effects | Roles and evidence |
|---|---|---|---|---|---|---|

## 7. Workflows
<!-- appdoc:guide Create one `###` subsection per workflow, named from the Target (e.g. `### 7.1 Submit a help request`).
Start from entry points and data access Facts, read source to explain steps, cite each step.
Cover every create/edit/delete flow listed in section 4. End each workflow with a cited
"Failure and escalation:" line. A list or table that claims to be complete ("all", "as coded")
must list every item; otherwise write "N of M shown" with M taken from source. Write this section last. -->

## 8. Data and Integrations
<!-- appdoc:guide Fed by: `connection`, `data_access`, `external_call` Facts. Must have content if any such Facts exist (C4). Never write connection secrets: "value omitted". -->

### 8.1 Connections
<!-- appdoc:guide Databases, caches, queues and services connected to, IDs C-1, C-2, ...; cite the config location with a line. -->

| ID | Name | Kind | Configured at | Used by |
|---|---|---|---|---|

<!-- appdoc:generated connections -->
<!-- /appdoc:generated connections -->

### 8.2 Stored procedures and SQL
<!-- appdoc:guide Stored procedures and SQL used, by caller, each cited. If none, say so and name the data-access mechanism (ORM etc.). -->

### 8.3 External calls
<!-- appdoc:guide HTTP/web service/message bus/email/file-share calls, IDs X-1, X-2, ..., each cited. Mark test-only calls as such. -->

| ID | Call | Direction | Caller | Notes |
|---|---|---|---|---|

<!-- appdoc:generated integrations -->
<!-- /appdoc:generated integrations -->

### 8.4 Data entities and sensitivity
<!-- appdoc:guide Main entities/tables, key fields, where defined, and sensitivity (PII, credentials, financial, public).
For each core entity add a field table after this one: | Field | Type | Null | Key/FK | Sensitivity | Citation |
taken from the schema, migrations or model classes. Put an erDiagram in section 12. -->

| Entity | Key fields | Defined at | Sensitivity |
|---|---|---|---|

### 8.5 Failure, fallback and observability
<!-- appdoc:guide One row per 8.1 and 8.3 ID (C10): what happens when that dependency is down or slow.
Cite the code; where there is no handling, say "none" and cite where you looked. -->

| ID | Timeout and retry | On failure | Observability |
|---|---|---|---|

## 9. Troubleshooting Matrix
<!-- appdoc:guide Fed by: `message` Facts and error branches in source. One cited row per symptom.
"Escalate when" must be a concrete trigger (e.g. "after one retry", "if the queue is down"); use Unknown at most once.
The audit plans each sampled row as `9/<slug>` (the slug is the lower-cased first cell, non-alphanumerics to `-`): one register row per planned key, that key as its ref. -->

| Symptom | Checks | Known response | Escalate when |
|---|---|---|---|

## 10. Security and Operational Risks
<!-- appdoc:guide Fed by: `secret_location`, `auth_check` gaps, source reading. EVERY Citation here MUST carry a line (`path:line`). Never write secret values. -->

### 10.1 Verified findings
<!-- appdoc:guide Risks observed in source, IDs V-1, V-2, ..., most severe first. Severity rubric (an organization may replace it in appdoc-context.md):
Critical = exploitable without authentication, or exposes secrets or data, in the default configuration.
High = authenticated privilege escalation, data-integrity loss, or an exposed credential.
Medium = a weakness that needs another condition to exploit.
Low = hygiene or informational. -->

| ID | Severity | Finding | Evidence | Impact |
|---|---|---|---|---|

### 10.2 Unknowns that must not be treated as controls
<!-- appdoc:guide Consider at least: TLS, CSRF, MFA, cookie flags, rate limiting, audit-log integrity, backup and recovery, production secret management.
Status: "Verified absent" (you confirmed in source that the control does not exist), "Not established" (the code cannot show it),
or "Present" (cite it). Every control that is not Present needs a row in 15 or 14 naming it (C10).
The audit plans each Present control as `10.2/<slug>` (the slug is the lower-cased first cell, non-alphanumerics to `-`): one register row per planned key, that key as its ref. -->

| Control | Status | Where looked |
|---|---|---|

## 11. Ownership and Maintenance
<!-- appdoc:guide Fed by: `ownership` and `owner_file` Facts and Owner context (cite `appdoc-context.md` only if it exists). Fill all six required rows: Business owner, Technical owner, Process owner, Data and integration owners, Documentation owner, Release and change process. Do not invent owners; use Unknown. Never copy personal email addresses.
Status is Cited, Inferred or Unknown.
Add one row per test suite (what it covers, which F-IDs). End with a short "Recommended maintenance minimum" list. -->

| Area | Evidence | Status |
|---|---|---|
| Business owner | | |
| Technical owner | | |
| Process owner | | |
| Data and integration owners | | |
| Documentation owner | | |
| Release and change process | | |

## 12. Architecture and Data-Flow Diagrams
<!-- appdoc:guide Mermaid only, each with a one-line cited caption: component, data-flow and sequence diagrams;
an erDiagram when 8.4 has entities; a deployment diagram when config shows the topology. -->

## 13. Glossary
<!-- appdoc:guide Every Target-specific term used elsewhere in this document, with a Citation to where it appears. -->

| Term | Meaning | Citation |
|---|---|---|

## 14. Open Questions and Documentation Gaps
<!-- appdoc:guide Every Unknown, one row each, IDs Q-1, Q-2, ... Owner is Unknown unless appdoc-context.md names one.
Priority: High, Medium or Low. Must not be empty if Unknown appears anywhere else (C4).
The generated block below the table lists the questions the audit closed and where the body answers them; never edit it. An audit row that closes a question (`result` Answerable) names the section in `answered_in`. -->

| ID | Question | Why it matters | How to close | Owner | Priority |
|---|---|---|---|---|---|

<!-- appdoc:generated closed-questions -->
<!-- /appdoc:generated closed-questions -->

## 15. Recommendations
<!-- appdoc:guide Prioritized actions. Addresses names the V-, Q- or 10.2 control it closes; every V-ID needs a row (C10).
Severity: Critical, High, Medium, Low. Effort: S, M, L. IDs R-1, R-2, ... -->

| ID | Severity | Effort | Recommendation | Addresses |
|---|---|---|---|---|

### 15.1 Coverage summary
<!-- appdoc:guide What this document verified, what it did not inspect, and what a reader must confirm before relying on it. A sentence that states the audit state must not state counts by result (they go stale after every delta pass): use a `rows` count marker and refer to Appendix A. -->

## 16. Operations Runbook
<!-- appdoc:guide Fed by: config, connections, dependencies, Owner context. Do not invent environments; use Unknown. -->

### 16.1 Platform requirements
<!-- appdoc:guide Runtime, framework and tool versions, each cited (build files, runtime pins). -->

### 16.2 Data stores
<!-- appdoc:guide Each database/cache/queue from 8.1: how it is provisioned and initialized (migrations, seed data). -->

### 16.3 Session and authentication behavior
<!-- appdoc:guide Session storage, timeouts, cookie settings, token lifetimes; or state there is no auth. -->

### 16.4 Known failure modes and operator responses
<!-- appdoc:guide One cited row per failure mode. -->

| Failure mode | Signal | Operator response |
|---|---|---|

### 16.5 Deployment and change process
<!-- appdoc:guide One row per step, all nine required (C9): Build, Test, Deploy, Upgrade, Rollback, Backup, Restore, Secret rotation, Periodic maintenance (the yearly or recurring checklist: licences and certificates, year-bound configuration values, data refresh).
Attribute each to the job, script or command that does it, cited; Unknown if the repository does not show it.
The audit plans each row that is not Unknown as `16.5/<slug>` (the slug is the lower-cased first cell, non-alphanumerics to `-`): one register row per planned key, that key as its ref. -->

| Step | Procedure | Evidence |
|---|---|---|

### 16.6 Configuration reference
<!-- appdoc:guide The generated block lists application config keys from facts.json: one row per key, secret locations first, commented defaults counted but not listed. Below it, optionally add a table `| Key | Effect | Evidence |` only for keys a workflow or finding depends on; every Key must be a key the block or facts.json names. -->

<!-- appdoc:generated config-reference -->
<!-- /appdoc:generated config-reference -->

### 16.7 Scheduled and background jobs
<!-- appdoc:guide The generated block lists every scheduled or background job found in source, with its schedule and whether it is enabled by default. Do not retype or count it. Add prose only for what a job does when a workflow or finding depends on it, with a Citation. -->

<!-- appdoc:generated scheduled-jobs -->
<!-- /appdoc:generated scheduled-jobs -->

### 16.8 Pipeline (generated)
<!-- appdoc:guide The generated block below lists the build and deployment pipeline the extractor read. Do not edit it: run `appdoc fill`. -->

<!-- appdoc:generated pipeline -->
<!-- /appdoc:generated pipeline -->

## 17. Build, Run and Test Locally
<!-- appdoc:guide Fed by: build files, runtime pins, README, CI steps. Every command is cited where it is defined (a Citation with a line in Evidence).
All five rows are required (C9). Command is one of: a backticked command; `Unknown - see Open questions.` (the repository does not show it; also add a row to section 14); `Not applicable` (cite the evidence, for example the file that shows there is nothing to build). Working directory is the folder the command runs in, relative to the Target (`.` for the root).
The Command cell holds exactly one backticked command and nothing else; put extra commands and prose under the table. A chain (`a`, then `b`) fails C9: use one command or one wrapper script. The audit plans each row that is not Unknown or Not applicable as `17/<slug>` (the slug is the lower-cased first cell, non-alphanumerics to `-`): one register row per planned key, that key as its ref. -->

| Step | Command | Working directory | Evidence |
|---|---|---|---|
| Prerequisites | | | |
| Restore dependencies | | | |
| Build | | | |
| Run | | | |
| Test | | | |

## Appendix A. Evidence Register and Verification
<!-- appdoc:guide Generated from evidence.jsonl (the source-to-claim audit). Do not edit it: write the register, then run `appdoc fill`. -->

<!-- appdoc:generated appendix-a -->
<!-- /appdoc:generated appendix-a -->
