# API Inventory

**Generated**: 2026-03-11 14:45:19

## Summary

This artifact documents the detected API surface, including endpoint contracts and supporting evidence, so developers can understand how the system is called.

## API Endpoints

| Name | Path | Method | Description | Parameters | Return Type | Status Codes | Auth Required |
|------|------|--------|-------------|------------|------------|--------------|---------------|

_No API endpoints detected. This codebase may not expose HTTP APIs, or uses patterns not yet recognized by the scanner._

### Detailed Appendix

Full endpoint catalogs with operation intent, auth boundary, timeout/retry guidance, idempotency, and confidence are in [API Inventory Appendix](api-inventory.appendix.md).

Deterministic evidence remains in `docs/evidence/api-inventory.evidence.json`.

## Data Models

Data model contracts are documented externally in [data-model.md]. Cross-reference with data models in data-model.md for field-level structure and model ownership.

## Authentication & Security

Authentication and authorization behavior is summarized when explicit markers are extracted. For authoritative enforcement details, review controller attributes, middleware, and configuration policy in source.

## Error Responses

Error-response contracts should be validated against controller branches and exception handling paths before behavior changes.

## API Versioning

Versioning policy is inferred from discovered routes. If no explicit scheme appears, treat route and payload compatibility as a release-management concern.

## Usage Examples

Example request/response payloads are not always deterministically extractable; use endpoint signatures and implementation code to author scenario-specific examples.

## Dependencies

No outbound API dependency contract was extracted from route evidence in this run. Review [Dependencies Catalog](dependencies-catalog.md) and configuration URL entries when tracing integration behavior.
## Evidence Traceability

| Field | Value |
|------|-------|
| Evidence Artifact | evidence/api-inventory.evidence.json |
| Record Count | 0 |
| Generator | generate-api-inventory.ps1 |
| Required Evidence Keys | endpoints |
| Grounding Mode | Deterministic extraction records |

---

## Provenance

- Generator Version: appdoc-run-all-generators/3.0.0
- Commit Hash: eed63d1
- Generated At: 2026-03-11T14:45:38-04:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
