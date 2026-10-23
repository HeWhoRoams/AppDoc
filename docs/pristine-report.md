# Pristine Check Report

**Benchmark**: HELP_DESK_APPLICATION_DOCUMENTATION.md (18-section CMU Help Desk benchmark)  
**Report date**: 10/22/2026 10:29:35  
**Composed doc**: docs/application-documentation.md (20 sections)  

> **What this is:** a per-section rubric that scores each of the 20 composed sections against the HELP_DESK benchmark, so "up to the standard" is MEASURABLE per section. Each section is classified exactly once:
>   
>   | Status | Meaning |
>   |--------|---------|
>   | **PASS** | structurally present + populated with REAL content + epistemic-tagged + re-verifiable + at benchmark depth |
>   | **WEAK** | present + populated but BELOW benchmark depth (a source-grounded section with real rows but fewer than the source/benchmark cap supports), or missing epistemic tags — a real finding |
>   | **EMPTY** | present (heading) but NO real content, and the source DOES support content — a real finding |
>   | **OWNER_REQUIRED** | a KNOWN owner-pending cell (capability matrix 5.2, policy/escalation 7, escalation paths 11, ownership/on-call/SLO 13, open questions 17) — correctly tagged `Unknown`, pending `/appdoc.enhance`, NOT a failure |
>   | **N/A** | a FRAMEWORK-N/A section: it documents a capability that only exists in classic-ASP codebases (today, only the Stored-procedure data dictionary — ADO stored procedures transcribed from live `.inc` files). When the target has NO ADO data surface, it is **excluded from the sub-score denominator** (not summed, not counted) and NOT treated as EMPTY — the honest classification, not a gap |
>   
>   **Depth rule (objective):** a TABLE section is populated iff it carries >=1 real data row (not a header + a `_No ... detected._` placeholder); a TEXT/DIAGRAM section iff it carries >=1 substantive paragraph / list-item / mermaid block. WEAK vs PASS compares the surfaced rows to the **benchmark cap** (the composer-designed representative sample, e.g. Functional Inventory capped at 60) CAPPED by the real source count (from the evidence artifacts), so a thin source is never a false finding.

> **Non-blocking / additive:** the overall pristine sub-score below is a DEPTH measurement. It is reported in `docs/validation-report.json` (a `pristine` field) but does NOT change `status` (pass/fail) or `overallScore` (the structural conformance composite is untouched). It is not a gate and cannot be gamed into a pass.

## Per-section rubric (20 sections)

| # | Section | Status | Reason (one line) | Rows | Benchmark ref |
|---|---------|--------|-------------------|------|---------------|
| 1 | Application Index | **PASS** | at benchmark depth; real content; epistemic-tagged | 0 | 1 |
| 2 | Coverage and Executive Overview | **PASS** | at benchmark depth; real content; epistemic-tagged | 12 | 2 |
| 3 | Architecture | **PASS** | at benchmark depth; real content; epistemic-tagged | 2 | 3 |
| 4 | Functional Inventory | **EMPTY** | no real content (placeholder only) | 0 | 4 |
| 5 | Roles and Access Model | **OWNER-REQUIRED** | owner-pending cell (correctly Unknown; pending /appdoc.enhance); also carries 2 verified source-derivable row(s) | 0 | 5 (5.2 owner-required) |
| 6 | UI Catalog | **EMPTY** | no real content (placeholder only) | 0 | 6 |
| 7 | Help Desk Workflows | **OWNER-REQUIRED** | owner-pending cell (correctly Unknown; pending /appdoc.enhance); also carries 3 verified source-derivable row(s) | 0 | 7 (7.x policy/escalation owner-required) |
| 8 | Data and Integrations | **EMPTY** | no real content (placeholder only) | 0 | 8 |
| 9 | External Call Register | **PASS** | at benchmark depth; real content; epistemic-tagged | 1 | 8A |
| 10 | Stored-procedure data dictionary | **N/A** | framework-N/A (stored-procedure data dictionary is classic-ASP-specific (ADO stored procedures transcribed from live `.inc` files); target is ASP.NET Core — no ADO data surface detected) | 0 | 8B |
| 11 | Troubleshooting Matrix | **PASS** | Verified-source-doc — populated from `README.md`: 146 (cited hand-authored docs; owner-pending cell resolved from source-of-truth) | 0 | 9 (11 escalation-paths owner-required) |
| 12 | Security and Operational Risks | **PASS** | at benchmark depth; real content; epistemic-tagged | 5 | 10 |
| 13 | Ownership and Maintenance | **OWNER-REQUIRED** | owner-pending cell (correctly Unknown; pending /appdoc.enhance); also carries 23 verified source-derivable row(s) | 23 | 11 (13 ownership/SLO owner-required) |
| 14 | Architecture and Data-Flow Diagrams | **PASS** | at benchmark depth; real content; epistemic-tagged | 0 | 12 |
| 15 | Glossary | **EMPTY** | no real content (placeholder only) | 0 | 13 (Glossary) |
| 16 | Evidence Register | **PASS** | at benchmark depth; real content; epistemic-tagged | 84 | discipline-addition (14) |
| 17 | Open Questions and Documentation Gaps | **OWNER-REQUIRED** | owner-pending cell (correctly Unknown; pending /appdoc.enhance); also carries 12 verified source-derivable row(s) | 0 | 17 |
| 18 | Recommendations | **PASS** | at benchmark depth; real content; epistemic-tagged | 2 | 16 |
| 19 | Operations Runbook | **PASS** | at benchmark depth; real content; epistemic-tagged | 5 | 17 (Ops Runbook) |
| 20 | Verification Appendix | **PASS** | at benchmark depth; real content; epistemic-tagged | 54 | discipline-addition (18) |

## Summary

| Status | Count | Meaning |
|--------|-------|---------|
| **PASS** | 11 | at benchmark depth, real content, epistemic-tagged |
| **WEAK** | 0 | populated but below benchmark depth / missing tags (real finding) |
| **EMPTY** | 4 | no real content where the source supports it (real finding) |
| **OWNER-REQUIRED** | 4 | known owner-pending cell, correctly Unknown, pending /appdoc.enhance (NOT a failure) |
| **N/A** | 1 | framework-N/A (capability is classic-ASP-specific; target has no ADO surface) — EXCLUDED from the sub-score denominator |
| **Scored (denominator)** | 19 | every section except N/A; the sub-score is Round(Σ(scores) / 19, 1) |
| **Total** | 20 | all sections (scored + N/A) |

| Metric | Value |
|--------|-------|
| **Overall pristine sub-score** | **78.9 / 100** |
| **Denominator (scored sections, excl. N/A)** | 19 |
| PASS ratio (of scored) | 57.9% |
| Re-verifiable (>=1 re-runnable command in Verification Appendix) | yes |
| Determinism hash (over the per-section records, excl. timestamp) | `16b6b8e755a93d71d44057314ccec0c28629c441f6729548ee630837b48fe5fd` |


## Owner-pending checklist (`/appdoc.enhance`)

> **What this is:** the cells that are correctly tagged `Unknown` and pending `/appdoc.enhance` — the complement to the source-derivable (auto) content. These are **NOT failures** (they classify `OWNER_REQUIRED`, not `EMPTY`). This is the deterministic, framework-agnostic "what is left for a human" checklist. It is ADDED on every run regardless of the pristine gate mode.

| # | Section | Benchmark ref | What's missing | Owner must provide | `/appdoc.enhance` target |
|---|---------|---------------|-----------------|--------------------|--------------------------|
| 1 | Roles and Access Model | 5 (5.2 owner-required) | The role/permission capability matrix (§5.2): which roles exist, their concrete permissions, and how access is granted/revoked. Source code shows the role TYPES but not the authoritative policy. | Authoritative role catalog + per-role permission matrix (who can do what), plus the access-control policy (RBAC/claims) with owner sign-off. | /appdoc.enhance --section "Roles and Access Model" (fill §5.2 capability matrix; tag Verified on owner confirmation) |
| 2 | Help Desk Workflows | 7 (7.x policy/escalation owner-required) | The §7.x policy/escalation content: the human approval policy, escalation thresholds/SLAs, and decision rules for help-desk workflows. Code shows the flow shapes but not the policy the owner sets. | Escalation policy + approval thresholds + SLA/decision rules for each help-desk workflow (owner-set, not derivable from source). | /appdoc.enhance --section "Help Desk Workflows" (fill §7 policy/escalation; tag Verified on owner confirmation) |
| 3 | Ownership and Maintenance | 11 (13 ownership/SLO owner-required) | The §13 ownership/SLO/on-call details: owning team, SLO targets, and on-call rotation. Source shows the components, not who owns them or the SLOs. | Owning team(s), SLO targets/definitions, and on-call rotation (org knowledge, not derivable from source). | /appdoc.enhance --section "Ownership and Maintenance" (fill §13 ownership/SLO/on-call; tag Verified on owner confirmation) |
| 4 | Open Questions and Documentation Gaps | 17 | The §17 open-questions resolution: answers/owners for each documented gap. The gaps are auto-surfaced, but their RESOLUTIONS + owners are owner-provided. | For each open gap: the answer (or "unresolved"), a named owner, and a due date/next action. | /appdoc.enhance --section "Open Questions and Documentation Gaps" (fill §17 resolutions/owners; tag Verified on owner confirmation) |

---

### Gate mode

| Mode | Status | Effect |
|------|--------|--------|
| **`report-only`** (DEFAULT) | on for every pipeline run | the pristine sub-score is a DEPTH measurement: additive only — does NOT change `status` (pass/fail) or `overallScore` (the structural conformance composite is untouched). The run is never blocked by the pristine check. |
| **`blocking`** (OPT-IN) | only with `-PristineGate` on `run-all-generators.ps1` | the pristine check becomes a real gate that BLOCKS the run when any section is `EMPTY` (emptyCount>0) OR the sub-score < floor (`-PristineFloor`, default 80). OWNER_REQUIRED cells are EXCLUDED (pending `/appdoc.enhance`, not failures). The decision is the pure function `Test-AppDocPristineGate`; the result is recorded in `validation-report.json` as `pristineGate`. |

*Default = report-only. This report is the human-readable companion; the machine-readable gate decision (`mode` / `enabled` / `blocked`) lives in `docs/validation-report.json` -> `pristineGate`.*

---

*Generated by `generate-pristine-report.ps1` (pure function of the composed doc + evidence artifacts; no LLM, no network, no randomness). The pristine sub-score is a DEPTH measurement: by default it is NON-BLOCKING / additive (report-only) and does not change `status` or `overallScore` in `docs/validation-report.json`; it blocks only under the OPT-IN `blocking` mode (`-PristineGate`).*