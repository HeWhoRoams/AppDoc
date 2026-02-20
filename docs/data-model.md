# Data Model Catalog

**Generated**: 2026-02-20 12:10:03

## Plain Language Summary

This artifact summarizes the main data structures detected in code and how those models support application behavior.

## Executive Summary

This document defines all data structures, entities, and their relationships within the system. It provides developers with a comprehensive understanding of the data architecture, including field types, constraints, validation rules, and data flow patterns. Use this as a reference for database design, API contract validation, and understanding system state management.

## Overview

This catalog is extracted from model/type declarations and grouped by domain, model size, and structural shape to support impact analysis and refactoring.

## Data Models

| Model Name | Fields | Types | Description | Constraints | Indexes |
|------------|--------|-------|-------------|-------------|---------|

_No data models detected. This codebase may use dynamic structures or patterns not yet recognized by the scanner._

## Relationships

Relationship coverage in this artifact depends on extractable type metadata; verify runtime associations in service and persistence layers where needed.

## Validation Rules

Validation rules are mostly implemented in business logic and model usage paths rather than centralized schema annotations. Use model call-sites and domain services to confirm runtime validation behavior.

## Indexes and Performance

Index and persistence-performance metadata are not directly available from type extraction alone. Pair this catalog with database artifacts and query traces when assessing performance risk.

## Data Flow Patterns

Model flow is inferred through controller/service usage rather than fully reconstructed as end-to-end pipelines in this artifact. Use API and component hotspots in [System Overview](overview.md) to map key data movement paths.

## Schema Evolution

Historical schema evolution evidence is out of scope for this deterministic scan. Use migration history, release notes, and git history to track breaking or structural model changes.

## Example Instances

Concrete example instances were not extracted automatically. Derive practical examples from representative controller actions and test fixtures that construct these models.
## Evidence Traceability

| Field | Value |
|------|-------|
| Evidence Artifact | evidence/data-model.evidence.json |
| Record Count | 0 |
| Generator | generate-data-model.ps1 |
| Required Evidence Keys | models |
| Grounding Mode | Deterministic extraction records |

---