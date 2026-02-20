# Configuration Catalog

**Generated**: 2026-02-19 16:14:20

## Executive Summary

This document inventories all configuration options, environment variables, and settings that control system behavior. It enables operations teams to deploy and configure the system correctly across different environments, and helps developers understand which behaviors are configurable versus hardcoded. Reference this when troubleshooting environment-specific issues or planning new deployments.

## Overview

Deterministic scan summary for this artifact.

## Configuration Sources

- **JSON Configuration**: 1 file(s)
- **MSBuild Project Configuration**: 4 file(s)
- **YAML Configuration**: 1 file(s)

## Configuration Options

| Name | Type | Default | Description | Required | Source |
|------|------|---------|-------------|----------|--------|
| OutputType | string | Exe | Auto-generated: Controls OutputType behavior. | No | .appdoc\tools\AppDoc.CSharpAstParser\AppDoc.CSharpAstParser.csproj:PropertyGroup/OutputType |
| TargetFramework | string | net8.0 | Auto-generated: Controls TargetFramework behavior. | No | .appdoc\tools\AppDoc.CSharpAstParser\AppDoc.CSharpAstParser.csproj:PropertyGroup/TargetFramework |
| jobs.syntax-gate.runs-on | string | windows-latest | Auto-generated: Controls jobs.syntax-gate.runs-on behavior. | No | .github\workflows\appdoc-ci.yml:yaml/jobs.syntax-gate.runs-on |
| jobs.syntax-gate.steps.shell | string | pwsh | Auto-generated: Controls jobs.syntax-gate.steps.shell behavior. | No | .github\workflows\appdoc-ci.yml:yaml/jobs.syntax-gate.steps.shell |
| jobs.syntax-gate.steps[0] | string | uses: actions/checkout@v4 | Auto-generated: Controls jobs.syntax-gate.steps[0] behavior. | No | .github\workflows\appdoc-ci.yml:yaml/jobs.syntax-gate.steps[0] |
| jobs.syntax-gate.steps[1] | string | name: Run PowerShell syntax gate | Auto-generated: Controls jobs.syntax-gate.steps[1] behavior. | No | .github\workflows\appdoc-ci.yml:yaml/jobs.syntax-gate.steps[1] |
| name | string | appdoc-ci | Auto-generated: Controls name behavior. | No | .github\workflows\appdoc-ci.yml:yaml/name |
| on.push.branches[0] | string | main | Auto-generated: Controls on.push.branches[0] behavior. | No | .github\workflows\appdoc-ci.yml:yaml/on.push.branches[0] |
| on.push.branches[1] | string | master | Auto-generated: Controls on.push.branches[1] behavior. | No | .github\workflows\appdoc-ci.yml:yaml/on.push.branches[1] |
| chat.tools.fileOperations.autoApprove.list | boolean | true | If true, allows Copilot or automation to run chat.tools.fileOperations.autoApprove.list commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.fileOperations.autoApprove.list |
| chat.tools.fileOperations.autoApprove.read | boolean | true | If true, allows Copilot or automation to run chat.tools.fileOperations.autoApprove.read commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.fileOperations.autoApprove.read |
| chat.tools.terminal.autoApprove.-ErrorAction | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.-ErrorAction commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.-ErrorAction |
| chat.tools.terminal.autoApprove.-Json | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.-Json commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.-Json |
| chat.tools.terminal.autoApprove.-RootPath | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.-RootPath commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.-RootPath |
| chat.tools.terminal.autoApprove.-Verbose | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.-Verbose commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.-Verbose |
| chat.tools.terminal.autoApprove..\.AppDoc\\scripts\\powershell\\*.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove..\.AppDoc\\scripts\\powershell\\*.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove../.AppDoc/scripts/powershell/*.ps1 |
| chat.tools.terminal.autoApprove..AppDoc/scripts/powershell/*.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove..AppDoc/scripts/powershell/*.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove..AppDoc/scripts/powershell/*.ps1 |
| chat.tools.terminal.autoApprove.**/analyze-capability-gaps.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/analyze-capability-gaps.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-capability-gaps.ps1 |
| chat.tools.terminal.autoApprove.**/analyze-codebase.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/analyze-codebase.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-codebase.ps1 |
| chat.tools.terminal.autoApprove.**/analyze-repository.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/analyze-repository.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-repository.ps1 |
| chat.tools.terminal.autoApprove.**/calculate-quality-metrics.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/calculate-quality-metrics.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/calculate-quality-metrics.ps1 |
| chat.tools.terminal.autoApprove.**/catalog-samples.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/catalog-samples.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/catalog-samples.ps1 |
| chat.tools.terminal.autoApprove.**/extract-config.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/extract-config.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/extract-config.ps1 |
| chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1 |
| chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1 |
| chat.tools.terminal.autoApprove.**/generate-build-cookbook.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-build-cookbook.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-build-cookbook.ps1 |
| chat.tools.terminal.autoApprove.**/generate-config-catalog.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-config-catalog.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-config-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/generate-data-model.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-data-model.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-data-model.ps1 |
| chat.tools.terminal.autoApprove.**/generate-debt-register.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-debt-register.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-debt-register.ps1 |
| chat.tools.terminal.autoApprove.**/generate-dependencies-catalog.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-dependencies-catalog.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-dependencies-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/generate-dependency-graph.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-dependency-graph.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-dependency-graph.ps1 |
| chat.tools.terminal.autoApprove.**/generate-improvements.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-improvements.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-improvements.ps1 |
| chat.tools.terminal.autoApprove.**/generate-overview.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-overview.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-overview.ps1 |
| chat.tools.terminal.autoApprove.**/generate-test-catalog.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/generate-test-catalog.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-test-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/run-all-generators.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/run-all-generators.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/run-all-generators.ps1 |
| chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1 |
| chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1 |
| chat.tools.terminal.autoApprove.**/validate-build-cookbook.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/validate-build-cookbook.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-build-cookbook.ps1 |
| chat.tools.terminal.autoApprove.**/validate-config-catalog.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/validate-config-catalog.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-config-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/validate-data-model.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/validate-data-model.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-data-model.ps1 |
| chat.tools.terminal.autoApprove.**/validate-debt-register.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/validate-debt-register.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-debt-register.ps1 |
| chat.tools.terminal.autoApprove.**/validate-overview.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/validate-overview.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-overview.ps1 |
| chat.tools.terminal.autoApprove.**/validate-test-catalog.ps1 | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.**/validate-test-catalog.ps1 commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-test-catalog.ps1 |
| chat.tools.terminal.autoApprove.Copy-Item | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.Copy-Item commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Copy-Item |
| chat.tools.terminal.autoApprove.Get-ChildItem | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.Get-ChildItem commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Get-ChildItem |
| chat.tools.terminal.autoApprove.Get-Content | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.Get-Content commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Get-Content |
| chat.tools.terminal.autoApprove.git | boolean | false | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.git commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.git |
| chat.tools.terminal.autoApprove.git fetch | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.git fetch commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.git fetch |
| chat.tools.terminal.autoApprove.git status | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.git status commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.git status |
| chat.tools.terminal.autoApprove.pwsh | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.pwsh commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.pwsh |
| chat.tools.terminal.autoApprove.Remove-Item | boolean | false | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.Remove-Item commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Remove-Item |
| chat.tools.terminal.autoApprove.Set-ExecutionPolicy | boolean | false | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.Set-ExecutionPolicy commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Set-ExecutionPolicy |
| chat.tools.terminal.autoApprove.Test-Path | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.Test-Path commands/scripts without manual approval. | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Test-Path |
| chat.tools.terminal.autoApprove.Write-Host | boolean | true | If true, allows Copilot or automation to run chat.tools.terminal.autoApprove.Write-Host commands/scripts without manual approval. | Yes | .vscode/settings.json:chat.tools.terminal.autoApprove.Write-Host |
| github.copilot.chat.executions.enabled | boolean | true | Enables Copilot chat command execution features. | No | .vscode/settings.json:github.copilot.chat.executions.enabled |
| TargetFramework | string | net6.0 | Auto-generated: Controls TargetFramework behavior. | No | tests\powershell\fixtures\sample-dotnet-app\SampleApp.Common\SampleApp.Common.csproj:PropertyGroup/TargetFramework |
| OutputType | string | WinExe | Auto-generated: Controls OutputType behavior. | No | tests\powershell\fixtures\sample-dotnet-app\SampleApp.Service\SampleApp.Service.csproj:PropertyGroup/OutputType |
| TargetFramework | string | net6.0 | Auto-generated: Controls TargetFramework behavior. | No | tests\powershell\fixtures\sample-dotnet-app\SampleApp.Service\SampleApp.Service.csproj:PropertyGroup/TargetFramework |
| TargetFramework | string | net6.0 | Auto-generated: Controls TargetFramework behavior. | No | tests\powershell\fixtures\sample-dotnet-app\SampleApp.Web\SampleApp.Web.csproj:PropertyGroup/TargetFramework |

## Environment Variables

| Variable | Default | Description | Sensitive | Required |
|----------|---------|-------------|-----------|----------|
|  |  | Environment variable | No | No |

## Configuration Validation
No evidence found for this section in the current scan.
## Configuration Management
No evidence found for this section in the current scan.
## Security Considerations
No evidence found for this section in the current scan.
## Example Configurations
No evidence found for this section in the current scan.
## Required configuration criteria

- `chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1`
- `chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1`
- `chat.tools.terminal.autoApprove.Write-Host`

### Why they are required

- The two assessment approvals enable automated report generation and synthesis during startup automation.
- The `Write-Host` approval allows CLI output that startup hooks rely on for progress and diagnostics.

### Consequences if missing

- **Automation disabled/degraded — runtime dependency for startup hooks.** Commands will pause for manual approval or skip blocked behaviors, causing unattended startup runs to fail.
- **Startup/validation failures — operational outcome.** Blocked report generation or synthesis may cause downstream validation stages to fail or emit incomplete artifacts.
- **Runtime errors/interruptions — execution path dependent.** If required startup-hook commands can’t execute, the orchestration path may terminate early or produce partial outputs.

### Validation classification

- **Deployment-time validation policy:** CI/deployment should fail when these keys are missing for environments requiring unattended startup hooks.
- **Runtime dependency scope:** this requirement targets Copilot startup-hook automation; manual script execution can compensate with interactive approvals.

## Evidence Traceability

| Field | Value |
|------|-------|
| Evidence Artifact | evidence/config-catalog.evidence.json |
| Record Count | 59 |
| Generator | generate-config-catalog.ps1 |
| Required Evidence Keys | configurations |
| Grounding Mode | Deterministic extraction records |
---
**Generated by AppDoc Framework**