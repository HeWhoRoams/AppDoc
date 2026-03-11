# Technical Debt Register

**Generated**: 2026-03-11 14:45:29

## Summary

This artifact captures detected risks and technical debt signals so teams can prioritize stabilization and modernization work.

## Debt Categories

No debt categories were derived from the current scan.

## Debt Items

### First-Party Debt (Priority)

| Item | Location | Ownership | Category | Impact | Priority | Risk Metadata | Description |
|------|----------|-----------|----------|--------|----------|---------------|-------------|
| N/A | N/A | first-party | N/A | N/A | N/A | N/A | No first-party debt rows detected |

### Vendor/Generated Debt

| Item | Location | Ownership | Category | Impact | Priority | Risk Metadata | Description |
|------|----------|-----------|----------|--------|----------|---------------|-------------|
| N/A | N/A | vendor/generated | N/A | N/A | N/A | N/A | No vendor/generated debt rows detected |

## Impact Assessment

The current register contains 0 items, indicating localized remediation pressure on delivery speed and change safety. Prioritize hotspots in high-churn files to reduce regression risk fastest.

## Remediation Plan

Use a phased plan: isolate highest-risk files first, split oversized classes/methods in small slices, and add regression coverage around each refactor before broad cleanup.

## Monitoring and Tracking

Track debt trendlines with recurring static-analysis runs and include debt deltas in release-readiness reviews to prevent re-accumulation.
## Evidence Traceability

| Field | Value |
|------|-------|
| Evidence Artifact | evidence/debt-register.evidence.json |
| Record Count | 0 |
| Generator | generate-debt-register.ps1 |
| Required Evidence Keys | debtItems |
| Grounding Mode | Deterministic extraction records |

---

## Provenance

- Generator Version: appdoc-run-all-generators/3.0.0
- Commit Hash: eed63d1
- Generated At: 2026-03-11T14:45:38-04:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
