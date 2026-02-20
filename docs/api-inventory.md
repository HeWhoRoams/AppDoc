# API Inventory

**Generated**: 2026-02-20 14:53:12

## Plain Language Summary

This artifact documents the detected API surface, including endpoint contracts and supporting evidence, so developers can understand how the system is called.

## Executive Summary

This document catalogs all API endpoints exposed by the system, including their HTTP methods, parameters, authentication requirements, and response formats. It serves as the primary reference for developers integrating with or consuming this API, and provides essential information for testing, monitoring, and troubleshooting API interactions.

## Overview

This inventory is extracted from controller/action evidence and is intended for implementation impact analysis, integration planning, and endpoint ownership review.

## API Endpoints

| Name | Path | Method | Description | Parameters | Return Type | Status Codes | Auth Required |
|------|------|--------|-------------|------------|------------|--------------|---------------|

_No API endpoints detected. This codebase may not expose HTTP APIs, or uses patterns not yet recognized by the scanner._

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