# Dependencies Catalog

**Generated**: 2026-02-20 12:10:09

## Plain Language Summary

This artifact summarizes external packages and integrations that influence runtime behavior, maintenance risk, and upgrade planning.

## Executive Summary

This document inventories all external dependencies, libraries, packages, and frameworks used by the system. It helps developers understand third-party code being used, manage security vulnerabilities, plan upgrades, and track licensing requirements.

## Overview

This catalog aggregates dependencies discovered from package manifests, project references, and assembly references. Use it to identify version drift, runtime coupling, and upgrade planning priorities.

## Dependency Summary

| Package Manager | Total Dependencies | Direct | Transitive |
|-----------------|-------------------|--------|------------|
| NuGet | 8 | 8 | 0 |
| Project References | 2 | 2 | 0 |
| Assembly References | 0 | 0 | 0 |

**Projects**: 4
## Dependencies by Type

### NuGet Packages

| Package | Version | Used By | Purpose |
|---------|---------|---------|---------|
| `EntityFramework` | 6.4.4 | SampleApp.Common | NuGet package |
| `Microsoft.AspNetCore.Mvc` | 2.2.0 | SampleApp.Web | NuGet package |
| `Microsoft.CodeAnalysis.CSharp` | 4.12.0 | AppDoc.CSharpAstParser | NuGet package |
| `Microsoft.Extensions.Hosting.WindowsServices` | 6.0.0 | SampleApp.Service | NuGet package |
| `Newtonsoft.Json` | 13.0.1 | SampleApp.Web | NuGet package |
| `RabbitMQ.Client` | 6.4.0 | SampleApp.Service | NuGet package |
| `System.Data.SqlClient` | 4.8.5 | SampleApp.Common | NuGet package |
| `System.Net.Http` | 4.3.4 | SampleApp.Web | NuGet package |

**Total NuGet Packages**: 8
### NPM Packages

No NPM package manifests were detected in scoped source paths for this run.
### Python Packages

No Python package manifests were detected in scoped source paths for this run.
### Maven/Gradle Dependencies

No Maven or Gradle dependency manifests were detected in scoped source paths for this run.
## Project References

Internal project dependencies:

- **`SampleApp.Common`** referenced by: SampleApp.Service, SampleApp.Web

**Total Project References**: 2
## Version Conflicts

_No version conflicts detected._
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
| Record Count | 10 |
| Generator | generate-dependencies-catalog.ps1 |
| Required Evidence Keys | dependencies |
| Grounding Mode | Deterministic extraction records |

---