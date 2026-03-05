# Build Cookbook

**Generated**: 2026-03-04 15:08:53

## Plain Language Summary

This artifact captures the commands and workflow needed to build, run, and troubleshoot the application in a repeatable way.

## Executive Summary

This document provides step-by-step instructions for building, testing, and deploying the system from source code. It includes all required dependencies, build commands, CI/CD integration details, and troubleshooting guidance. Use this to set up development environments, automate builds, or diagnose build failures.

## Overview

This cookbook is assembled from detected build commands and CI hints so teams can reproduce, troubleshoot, and standardize build execution.

## Prerequisites

Use a Windows development environment with dotnet, msbuild, and nuget available on PATH. Align SDK/toolchain versions with solution and CI expectations before running full builds.

## Build Steps

_Add step-by-step build instructions or reference build scripts here. Remove this section if not needed._

## Dependencies

| Dependency | Version | Purpose | Installation |
|------------|---------|---------|--------------|
| dotnet CLI | Environment-dependent | Build, restore, test, and publish commands | Install the SDK version required by the solution |
| MSBuild | Environment-dependent | Legacy solution build/rebuild workflows | Install via Visual Studio Build Tools or Visual Studio |
| NuGet CLI | Environment-dependent | Package restore for legacy flows | Install NuGet CLI and ensure PATH availability |

## CI/CD Integration

**Detected CI/CD Platforms:**

- **GitHub Actions**: `.github\workflows\appdoc-ci.yml` - Workflow: appdoc-ci

## Troubleshooting

Start with restore (dotnet restore or nuget restore) and then run the narrowest failing build command from this artifact. If failures persist, compare local toolchain versions with CI and check dependency/version drift in [Dependencies Catalog](dependencies-catalog.md).

## Example Build Scripts

A curated script was not extracted in this run. For repeatable local execution, chain restore -> build -> test commands from the Build Steps table into a repo-specific helper script.
## Evidence Traceability

| Field | Value |
|------|-------|
| Evidence Artifact | evidence/build-cookbook.evidence.json |
| Record Count | 1 |
| Generator | generate-build-cookbook.ps1 |
| Required Evidence Keys | commands |
| Grounding Mode | Deterministic extraction records |

---

## Provenance

- Generator Version: appdoc-run-all-generators/3.0.0
- Commit Hash: 1a97947
- Generated At: 2026-03-04T15:09:09-05:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
