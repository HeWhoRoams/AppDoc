# $ARGUMENTS — Documentation Consistency Audit Report

---
# METADATA
---
title: "Audit Report"
app: "$ARGUMENTS"
template: "audit.report.template.md"
version: "2.0"
generated_by: "AppDoc Agent"
generated_at: "$DATE_GENERATED"
sources_scanned: $SOURCES_SCANNED
---

## 1 — Executive Summary & Metrics
- **Documents Generated:** $DOCUMENTS_GENERATED
- **Total Placeholders Found:** $TOTAL_PLACEHOLDERS
- **Placeholders Populated:** $POPULATED_PLACEHOLDERS
- **Auto-Resolved Tasks (P2/P3):** $AUTO_RESOLVED_TASKS
- **Tasks Created (P0/P1/P2/P3):** $TASK_COUNTS_BY_PRIORITY
- **P0 Security Findings:** $P0_COUNT
- **Validation Summary:** V: $VALIDATED_COUNT, P: $PARTIAL_COUNT, N: $NOT_VALIDATED_COUNT
- **Documentation Completeness Score:** $COMPLETENESS_SCORE/100
- **Confidence Rating:** $CONFIDENCE_RATING

---

## 2 — Validation Detail by Artifact

| Artifact | Validation | Issues Found | Top 3 Actions |
|----------|------------|--------------|----------------|
| architecture.md | $ARCH_VALIDATION_STATE | $ARCH_ISSUES_COUNT | 1) $ARCH_TASK_1 2) $ARCH_TASK_2 3) $ARCH_TASK_3 |
| logic-and-workflows.md | $LOGIC_VALIDATION_STATE | $LOGIC_ISSUES_COUNT | 1) $LOGIC_TASK_1 2) $LOGIC_TASK_2 3) $LOGIC_TASK_3 |
| Documentation Tasks.md | $TASKS_VALIDATION_STATE | $TASKS_ISSUES_COUNT | 1) $TASKS_TASK_1 2) $TASKS_TASK_2 |
| troubleshooting.playbook.md | $TROUBLE_VALIDATION_STATE | $TROUBLE_ISSUES_COUNT | 1) $TROUBLE_TASK_1 |

---

## 3 — Findings (Detailed)
For each significant finding include:
- **Finding:** short title
- **Severity:** [P0 / P1 / P2 / P3]
- **Description:** brief description and evidence (file:line)
- **Action:** recommended remediation (create task)
- **Status:** [To Do / Blocked / Auto-Resolved]

(Repeat for each finding)

---

## 4 — Security & Compliance Summary
- **Secrets or sensitive data found:** $SENSITIVE_DATA_FOUND (list)
- **Hardcoded credentials:** $HARDCODED_CREDENTIALS (list)
- **Unvalidated inputs:** $UNVALIDATED_INPUTS (list)
- **Deprecated dependencies:** $DEPRECATED_DEPENDENCIES (list)
- **Immediate P0 actions:** $P0_ACTIONS

---

## 5 — Recommendations & Next Steps
- High Priority Fixes (P0/P1): $HIGH_PRIORITY_LIST
- Medium Priority (P2): $MEDIUM_PRIORITY_LIST
- Low Priority (P3): $LOW_PRIORITY_LIST
- Suggested re-run cadence: $RE_RUN_SUGGESTION

---

## 6 — Conclusion
- **Overall Completeness:** $COMPLETENESS_SCORE/100
- **Confidence:** $CONFIDENCE_RATING
- **Next Suggested Action:** $NEXT_SUGGESTED_ACTION

*(end of audit report)*
