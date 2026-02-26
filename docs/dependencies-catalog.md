# Dependencies Catalog

**Generated**: 2026-02-25 14:48:54

## Plain Language Summary

This artifact summarizes external packages and integrations that influence runtime behavior, maintenance risk, and upgrade planning.

## Executive Summary

This document inventories all external dependencies, libraries, packages, and frameworks used by the system. It helps developers understand third-party code being used, manage security vulnerabilities, plan upgrades, and track licensing requirements.

## Overview

This catalog aggregates dependencies discovered from package manifests, project references, and assembly references. Use it to identify version drift, runtime coupling, and upgrade planning priorities.

## Dependency Summary

| Package Manager | Total Dependencies | Direct | Transitive |
|-----------------|-------------------|--------|------------|

Dependency records in scope: none in this scan. The repository may be self-contained or use unmanaged dependency sources.
## Dependencies by Type

### NuGet Packages

NuGet package entries in scope: none in this scan.
### NPM Packages

No NPM package manifests were detected in scoped source paths for this run.
### Python Packages

No Python package manifests were detected in scoped source paths for this run.
### Maven/Gradle Dependencies

No Maven or Gradle dependency manifests were detected in scoped source paths for this run.
## Project References

Project-reference edges in scope: none in this scan.
## Version Conflicts

Version divergence signals in scope: none in this scan.
## Security Considerations

This artifact does not currently include automated CVE/advisory enrichment. Use dependency scanning tools in CI and prioritize packages with multiple versions or broad usage footprint for security review.

## Licensing

_No license information extracted. Verify licenses for compliance._
## Upgrade Recommendations

Focus upgrades on packages that appear in many projects, show version divergence, or sit on critical execution paths. Roll upgrades in small batches and validate build/test outputs after each change set.
## Evidence Traceability

| Field | Value |
|------|-------|
| Evidence Artifact | evidence/dependencies-catalog.evidence.json |
| Record Count | 0 |
| Generator | generate-dependencies-catalog.ps1 |
| Required Evidence Keys | dependencies |
| Grounding Mode | Deterministic extraction records |

---