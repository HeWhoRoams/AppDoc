# $ARGUMENTS — Troubleshooting Playbook

---
# METADATA
---
title: "Troubleshooting Playbook"
app: "$ARGUMENTS"
template: "troubleshooting.playbook.template.md"
version: "2.0"
generated_by: "AppDoc Agent"
generated_at: "$DATE_GENERATED"
sources_scanned: $SOURCES_SCANNED
trigger_condition_summary: $TROUBLE_TRIGGER_SUMMARY
---

## 0 — Overview
This troubleshooting playbook compiles recurring error signatures, probable root causes inferred from code/logs, and recommended remediations or diagnostics. This playbook is generated only if trigger conditions (logs, exceptions, error-mapping files, or repeated signatures) are met.

---

## 1 — Quick Health Checklist
- [ ] Validate configuration files and environment variables
- [ ] Confirm DB / external service connectivity
- [ ] Confirm credentials and secrets rotation status
- [ ] Confirm monitoring/alerts pipeline is active

---

## 2 — Recurring Error Patterns (Auto-detected)

| Error Signature (exact) | Frequency | Probable Root Cause | Immediate Remediation | Affected Modules / Files |
|--------------------------|:--------:|---------------------|------------------------|--------------------------|
| `$ERROR_SIGNATURE_1` | $COUNT_1 | $ROOT_CAUSE_1 | $REMEDIATION_1 | $FILES_1 |
| `$ERROR_SIGNATURE_2` | $COUNT_2 | $ROOT_CAUSE_2 | $REMEDIATION_2 | $FILES_2 |

**Detection rule:** only include signatures occurring >= 2 times unless severity high (P0).

---

## 3 — Error Triage Procedures

For each error signature:
1. **Collect evidence:** `grep` logs for signature, gather timestamps and request IDs (if present).
2. **Reproduce steps:** run the workflow or unit test that triggers the error (link to test if found).
3. **Root cause analysis:** examine surrounding code, stack traces, and input validation.
4. **Immediate mitigation:** temporary workaround or feature flag disablement.
5. **Permanent fix:** create a P0/P1/P2 task and reference file/line.

---

## 4 — Diagnostics & Tools
- Commands to fetch recent logs: `$LOG_FETCH_COMMAND`  
- Key log file locations: `$LOG_FILE_PATHS`  
- Short helper scripts (if discovered): `$HELPER_SCRIPTS`  
- Query examples for monitoring dashboards (if applicable): `$MONITORING_QUERIES`

---

## 5 — Prevention & Hardening Recommendations
- Standardize structured logging (JSON) with unique request IDs
- Add retries with exponential backoff for transient external calls
- Centralize config & secrets; avoid hardcoding
- Increase test coverage for observed flaky code paths

---

## 6 — References & Links
- Related tests: $RELATED_TESTS
- Source files referenced: $REFERENCE_FILES
- Monitoring dashboards or alerts: $MONITORING_LINKS

*(end of troubleshooting playbook)*
