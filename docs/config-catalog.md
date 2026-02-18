# Configuration Catalog

**Generated**: 2026-02-18 13:44:47

## Executive Summary

This document inventories all configuration options, environment variables, and settings that control system behavior. It enables operations teams to deploy and configure the system correctly across different environments, and helps developers understand which behaviors are configurable versus hardcoded. Reference this when troubleshooting environment-specific issues or planning new deployments.

## Overview

This section summarizes generated findings from deterministic codebase analysis.

## Configuration Sources

- **JSON Configuration**: 1 file(s)
- **YAML Configuration**: 1 file(s)

## Configuration Options

| Name | Type | Default | Description | Required | Source |
|------|------|---------|-------------|----------|--------|
| chat.tools.fileOperations.autoApprove.list | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.fileOperations.autoApprove.list |
| chat.tools.fileOperations.autoApprove.read | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.fileOperations.autoApprove.read |
| chat.tools.terminal.autoApprove.-ErrorAction | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.-ErrorAction |
| chat.tools.terminal.autoApprove.-Json | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.-Json |
| chat.tools.terminal.autoApprove.-RootPath | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.-RootPath |
| chat.tools.terminal.autoApprove.-Verbose | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.-Verbose |
| chat.tools.terminal.autoApprove..\.AppDoc\\scripts\\powershell\\*.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove..\.AppDoc\\scripts\\powershell\\*.ps1 |
| chat.tools.terminal.autoApprove..AppDoc/scripts/powershell/*.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove..AppDoc/scripts/powershell/*.ps1 |
| chat.tools.terminal.autoApprove.**/analyze-capability-gaps.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-capability-gaps.ps1 |
| chat.tools.terminal.autoApprove.**/analyze-codebase.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-codebase.ps1 |
| chat.tools.terminal.autoApprove.**/analyze-repository.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-repository.ps1 |
| chat.tools.terminal.autoApprove.**/calculate-quality-metrics.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/calculate-quality-metrics.ps1 |
| chat.tools.terminal.autoApprove.**/catalog-samples.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/catalog-samples.ps1 |
| chat.tools.terminal.autoApprove.**/extract-config.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/extract-config.ps1 |
| chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1 |
| chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1 | JSON Configuration | true | Required for unattended startup-hook report generation; see [Required configuration criteria](#required-configuration-criteria). | Yes | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1 |
| chat.tools.terminal.autoApprove.**/generate-build-cookbook.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-build-cookbook.ps1 |
| chat.tools.terminal.autoApprove.**/generate-config-catalog.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-config-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/generate-data-model.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-data-model.ps1 |
| chat.tools.terminal.autoApprove.**/generate-debt-register.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-debt-register.ps1 |
| chat.tools.terminal.autoApprove.**/generate-dependencies-catalog.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-dependencies-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/generate-dependency-graph.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-dependency-graph.ps1 |
| chat.tools.terminal.autoApprove.**/generate-improvements.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-improvements.ps1 |
| chat.tools.terminal.autoApprove.**/generate-overview.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-overview.ps1 |
| chat.tools.terminal.autoApprove.**/generate-test-catalog.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-test-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/run-all-generators.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/run-all-generators.ps1 |
| chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1 | JSON Configuration | true | Required for unattended startup-hook report synthesis; see [Required configuration criteria](#required-configuration-criteria). | Yes | .vscode/settings.json:chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1 |
| chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1 |
| chat.tools.terminal.autoApprove.**/validate-build-cookbook.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-build-cookbook.ps1 |
| chat.tools.terminal.autoApprove.**/validate-config-catalog.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-config-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/validate-data-model.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-data-model.ps1 |
| chat.tools.terminal.autoApprove.**/validate-debt-register.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-debt-register.ps1 |
| chat.tools.terminal.autoApprove.**/validate-overview.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-overview.ps1 |
| chat.tools.terminal.autoApprove.**/validate-test-catalog.ps1 | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-test-catalog.ps1 |
| chat.tools.terminal.autoApprove.Copy-Item | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Copy-Item |
| chat.tools.terminal.autoApprove.Get-ChildItem | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Get-ChildItem |
| chat.tools.terminal.autoApprove.Get-Content | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Get-Content |
| chat.tools.terminal.autoApprove.git | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.git |
| chat.tools.terminal.autoApprove.git fetch | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.git fetch |
| chat.tools.terminal.autoApprove.git status | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.git status |
| chat.tools.terminal.autoApprove.pwsh | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.pwsh |
| chat.tools.terminal.autoApprove.Remove-Item | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Remove-Item |
| chat.tools.terminal.autoApprove.Set-ExecutionPolicy | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Set-ExecutionPolicy |
| chat.tools.terminal.autoApprove.Test-Path | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:chat.tools.terminal.autoApprove.Test-Path |
| chat.tools.terminal.autoApprove.Write-Host | JSON Configuration | true | Required for startup-hook CLI status/output commands; see [Required configuration criteria](#required-configuration-criteria). | Yes | .vscode/settings.json:chat.tools.terminal.autoApprove.Write-Host |
| github.copilot.chat.executions.enabled | JSON Configuration | true | Nested configuration option | No | .vscode/settings.json:github.copilot.chat.executions.enabled |

## Required configuration criteria

The following keys are marked **Required** because AppDoc startup hooks rely on unattended Copilot terminal execution for assessment output:

- `chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1`
- `chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1`
- `chat.tools.terminal.autoApprove.Write-Host`

### Why they are required

- The two assessment script approvals enable automatic creation and synthesis of report artifacts during startup automation.
- The `Write-Host` approval enables non-interactive CLI status/output commands used by startup hooks for progress and diagnostics visibility.

### Consequences if missing

- **Automation disabled/degraded (runtime dependency for startup hooks):** hooks pause for manual approval or skip blocked commands, so unattended execution is no longer reliable.
- **Startup/validation failures (operational outcome):** when report generation/synthesis is blocked, expected assessment outputs may be missing, which can cause downstream validation or quality checks to fail.
- **Runtime errors/interruptions (execution path dependent):** if a required startup-hook command is denied or cannot execute in non-interactive mode, the orchestration path can terminate early or continue with incomplete results.

### Validation classification

- **Deployment-time validation policy:** CI/deployment should fail when these keys are missing in environments that require unattended startup hooks.
- **Runtime dependency scope:** this requirement applies to Copilot startup-hook automation behavior (not to standalone manual script execution where a user can approve/compensate interactively).

## Environment Variables

| Variable | Default | Description | Sensitive | Required |
|----------|---------|-------------|-----------|----------|
| CHAT__TOOLS__TERMINAL__AUTOAPPROVE__GENERATE_API_INVENTORY__PS1 | true | Derived from config key 'chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1' | No | No |
| CHAT__TOOLS__TERMINAL__AUTOAPPROVE__GENERATE_ASSESSMENT_REPORT__PS1 | true | Derived from config key 'chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1' | No | Yes |
| CHAT__TOOLS__TERMINAL__AUTOAPPROVE__GENERATE_DATA_MODEL__PS1 | true | Derived from config key 'chat.tools.terminal.autoApprove.**/generate-data-model.ps1' | No | No |
| CHAT__TOOLS__TERMINAL__AUTOAPPROVE__SYNTHESIZE_ASSESSMENT_REPORT__PS1 | true | Derived from config key 'chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1' | No | Yes |
| CHAT__TOOLS__TERMINAL__AUTOAPPROVE__VALIDATE_API_INVENTORY__PS1 | true | Derived from config key 'chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1' | No | No |
| CHAT__TOOLS__TERMINAL__AUTOAPPROVE__VALIDATE_DATA_MODEL__PS1 | true | Derived from config key 'chat.tools.terminal.autoApprove.**/validate-data-model.ps1' | No | No |
| CHAT__TOOLS__TERMINAL__AUTOAPPROVE__WRITE_HOST | true | Derived from config key 'chat.tools.terminal.autoApprove.Write-Host' | No | Yes |

## Configuration Validation
This section will be populated as artifacts are discovered.
## Configuration Management
This section will be populated as artifacts are discovered.
## Security Considerations
This section will be populated as artifacts are discovered.
## Example Configurations
This section will be populated as artifacts are discovered.

## Evidence Traceability

| Field | Value |
|------|-------|
| Evidence Artifact | evidence/config-catalog.evidence.json |
| Record Count | 46 |
| Generator | generate-config-catalog.ps1 |
| Required Evidence Keys | configurations |
| Grounding Mode | Deterministic extraction records |
---
**Generated by AppDoc Framework**