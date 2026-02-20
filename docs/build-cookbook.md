# Build Cookbook

**Generated**: 2026-02-20 12:10:08

## Plain Language Summary

This artifact captures the commands and workflow needed to build, run, and troubleshoot the application in a repeatable way.

## Executive Summary

This document provides step-by-step instructions for building, testing, and deploying the system from source code. It includes all required dependencies, build commands, CI/CD integration details, and troubleshooting guidance. Use this to set up development environments, automate builds, or diagnose build failures.

## Overview

This cookbook is assembled from detected build commands and CI hints so teams can reproduce, troubleshoot, and standardize build execution.

## Prerequisites

- .NET 8.0 SDK or later

## Build Steps

| Step | Command | Description | Estimated Time |
|------|---------|-------------|----------------|
| 1 | `dotnet build SampleApp.sln` | Build all projects in the solution | N/A |
| 2 | `dotnet clean SampleApp.sln` | Clean build artifacts | N/A |
| 3 | `dotnet publish SampleApp.sln -c Release` | Publish release build | N/A |
| 4 | `dotnet restore SampleApp.sln` | Restore NuGet packages | N/A |
| 5 | `dotnet test SampleApp.sln` | Run all tests in the solution | N/A |
| 6 | `dotnet build ".appdoc/tools/AppDoc.CSharpAstParser/AppDoc.CSharpAstParser.csproj"` | Build individual project | N/A |
| 7 | `dotnet build "tests/powershell/fixtures/sample-dotnet-app/SampleApp.Common/SampleApp.Common.csproj"` | Build individual project | N/A |
| 8 | `dotnet build "tests/powershell/fixtures/sample-dotnet-app/SampleApp.Service/SampleApp.Service.csproj"` | Build individual project | N/A |
| 9 | `dotnet build "tests/powershell/fixtures/sample-dotnet-app/SampleApp.Web/SampleApp.Web.csproj"` | Build individual project | N/A |
| 10 | `msbuild SampleApp.sln /p:Configuration=Release` | Build solution using MSBuild | N/A |
| 11 | `msbuild SampleApp.sln /t:Clean` | Clean using MSBuild | N/A |
| 12 | `msbuild SampleApp.sln /t:Rebuild /p:Configuration=Release` | Clean and rebuild | N/A |
| 13 | `nuget restore SampleApp.sln` | Restore NuGet packages | N/A |

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
| Record Count | 15 |
| Generator | generate-build-cookbook.ps1 |
| Required Evidence Keys | commands |
| Grounding Mode | Deterministic extraction records |

---