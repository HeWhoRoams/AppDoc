# <Target name> Documentation
<!-- Replace the title placeholder. Copy this file to docs/appdoc/application-documentation.md and fill every section.
CONVENTIONS (render strips all HTML comments):
- Citation = backticked Target-relative path with optional line or range: `portal/verify.asp:6`, `src/App.java:40-52`. Owner context is cited as `appdoc-context.md`.
- Prefix a reasoned (not directly observed) statement with **Inferred:** and still cite what it rests on.
- Anything you cannot establish is Unknown: list it in section 14; elsewhere write "Unknown - see Open questions."
- NEVER write a secret value. Write "value omitted" and cite the location.
- Diagrams go in ```mermaid fences.
Delete nothing from the headings; the Check requires all 16 sections in order, each with real content. -->

## 1. Application Index
<!-- Links to every section plus a quick cross-reference table (topic -> section). Fed by all sections. Write last. -->

## 2. Coverage and Overview
<!-- Fed by: facts-summary.md, `stack` Facts, Owner context. Name every unsupported Stack here (C7 fails otherwise). -->

### 2.1 What was inspected
<!-- Stacks, folders, file counts, and what was NOT inspected. Name unsupported Stacks explicitly. -->

### 2.2 Purpose and users
<!-- What the Target does and who uses it. Cite source or `appdoc-context.md`; otherwise Unknown. -->

### 2.3 System boundary
<!-- What is inside the Target and which external systems it touches. -->

## 3. Architecture
<!-- Fed by: folders, entry points, `connection` Facts, `auth_check` Facts. Every paragraph/list item needs a Citation, **Inferred:**, or Unknown. -->

### 3.1 Components
<!-- Main modules/folders and their responsibilities, each cited. -->

### 3.2 Diagram
<!-- One Mermaid diagram of the components (```mermaid fence). -->

### 3.3 Authentication and authorization
<!-- How users are authenticated and checks enforced. Cite `auth_check` Facts and source lines. -->

## 4. Functional Inventory
<!-- Fed by: `entry_point` Facts grouped by folder/subsystem. One cited line per function or page group. -->

## 5. Roles and Access Model
<!-- Fed by: `auth_check` Facts, role names. Role-to-capability matrix; each table row cited. -->

## 6. UI Catalog
<!-- Fed by: `entry_point` Facts of type page, their inputs. One cited row per page or screen. -->

## 7. Workflows
<!-- Create one `###` subsection per workflow, named from the Target (e.g. `### 7.1 Submit a help request`).
Start from entry points and data access Facts, read source to explain steps, cite each step. Write this section last. -->

## 8. Data and Integrations
<!-- Fed by: `connection`, `data_access`, `external_call` Facts. Must have content if any such Facts exist (C4). Never write connection secrets: "value omitted". -->

### 8.1 Connections
<!-- Databases and services connected to; cite the config location with a line. -->

### 8.2 Stored procedures and SQL
<!-- Stored procedures and SQL used, by caller, each cited. -->

### 8.3 External calls
<!-- HTTP/web service/email/file-share calls, each cited. -->

## 9. Troubleshooting Matrix
<!-- Fed by: `message` Facts and error branches in source. One cited row per symptom. -->

| Symptom | Checks | Known response | Escalate when |
|---|---|---|---|

## 10. Security and Operational Risks
<!-- Fed by: `secret_location`, `auth_check` gaps, source reading. EVERY Citation here MUST carry a line (`path:line`). Never write secret values. -->

## 11. Ownership and Maintenance
<!-- Fed by: `ownership` Facts and Owner context (cite `appdoc-context.md`). Do not invent owners; use Unknown. -->

## 12. Architecture and Data-Flow Diagrams
<!-- Mermaid only: component, data-flow and sequence diagrams in ```mermaid fences, with a one-line cited caption each. -->

## 13. Glossary
<!-- Target-specific terms and what they mean, with a Citation to where each appears. -->

## 14. Open Questions and Documentation Gaps
<!-- Every Unknown, as a bullet. This section must not be empty if Unknown appears anywhere else (C4). -->

## 15. Recommendations
<!-- Prioritized actions for security, technical debt and documentation gaps; each cites the finding it addresses. -->

## 16. Operations Runbook
<!-- Fed by: config, connections, dependencies, Owner context. Platform, servers, sessions, failure modes, deployment. Do not invent environments; use Unknown. -->
