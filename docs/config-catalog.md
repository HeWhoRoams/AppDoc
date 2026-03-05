# Configuration Catalog

**Generated**: 2026-03-05 16:38:30

## Executive Summary

This document inventories all configuration options, environment variables, and settings that control system behavior. It enables operations teams to deploy and configure the system correctly across different environments, and helps developers understand which behaviors are configurable versus hardcoded. Reference this when troubleshooting environment-specific issues or planning new deployments.

## Overview

This catalog is assembled from Web.config/App.config, project files, and pipeline YAML to show where runtime and deployment behavior are controlled.

## Configuration Sources

- **JSON Configuration**: 1 files
- **YAML Configuration**: 1 files

## Configuration Options

### Runtime Configuration (Priority)

No runtime configuration entries detected.

### Deployment / Environment Configuration

| Name | Type | Default | Description | Required | Where Used | Environment Requirement | Source |
|------|------|---------|-------------|----------|------------|--------------------------|--------|
| jobs.syntax-gate.runs-on | YAML Configuration | windows-latest | Purpose unclear from available evidence — review .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.runs-on. | No | Deployment/environment | Environment-specific | .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.runs-on |
| jobs.syntax-gate.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.steps.shell. | No | Deployment/environment | Environment-specific | .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.steps.shell |
| jobs.syntax-gate.steps[0] | YAML Configuration | uses: actions/checkout@v4 | Purpose unclear from available evidence — review .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.steps[0]. | No | Deployment/environment | Environment-specific | .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.steps[0] |
| jobs.syntax-gate.steps[1] | YAML Configuration | name: Run PowerShell syntax gate | Purpose unclear from available evidence — review .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.steps[1]. | No | Deployment/environment | Environment-specific | .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.steps[1] |
| jobs.syntax-gate.steps[2] | YAML Configuration | name: Run documentation integrity gate | Purpose unclear from available evidence — review .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.steps[2]. | No | Deployment/environment | Environment-specific | .github/workflows/appdoc-ci.yml:yaml/jobs.syntax-gate.steps[2] |
| name | YAML Configuration | appdoc-ci | Purpose unclear from available evidence — review .github/workflows/appdoc-ci.yml:yaml/name. | No | Deployment/environment | Environment-specific | .github/workflows/appdoc-ci.yml:yaml/name |
| on.push.branches[0] | YAML Configuration | main | Purpose unclear from available evidence — review .github/workflows/appdoc-ci.yml:yaml/on.push.branches[0]. | No | Deployment/environment | Environment-specific | .github/workflows/appdoc-ci.yml:yaml/on.push.branches[0] |
| on.push.branches[1] | YAML Configuration | master | Purpose unclear from available evidence — review .github/workflows/appdoc-ci.yml:yaml/on.push.branches[1]. | No | Deployment/environment | Environment-specific | .github/workflows/appdoc-ci.yml:yaml/on.push.branches[1] |

### Tooling and Workflow Configuration

| Name | Type | Default | Description | Required | Where Used | Environment Requirement | Source |
|------|------|---------|-------------|----------|------------|--------------------------|--------|
| chat.tools.fileOperations.autoApprove.list | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.fileOperations.autoApprove.list. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.fileOperations.autoApprove.list |
| chat.tools.fileOperations.autoApprove.read | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.fileOperations.autoApprove.read. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.fileOperations.autoApprove.read |
| chat.tools.terminal.autoApprove.-ErrorAction | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.-ErrorAction. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.-ErrorAction |
| chat.tools.terminal.autoApprove.-Json | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.-Json. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.-Json |
| chat.tools.terminal.autoApprove.-RootPath | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.-RootPath. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.-RootPath |
| chat.tools.terminal.autoApprove.-Verbose | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.-Verbose. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.-Verbose |
| chat.tools.terminal.autoApprove..\.AppDoc\\scripts\\powershell\\*.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove../.AppDoc/scripts/powershell/*.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove../.AppDoc/scripts/powershell/*.ps1 |
| chat.tools.terminal.autoApprove..AppDoc/scripts/powershell/*.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove..AppDoc/scripts/powershell/*.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove..AppDoc/scripts/powershell/*.ps1 |
| chat.tools.terminal.autoApprove.**/analyze-capability-gaps.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-capability-gaps.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-capability-gaps.ps1 |
| chat.tools.terminal.autoApprove.**/analyze-codebase.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-codebase.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-codebase.ps1 |
| chat.tools.terminal.autoApprove.**/analyze-repository.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-repository.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/analyze-repository.ps1 |
| chat.tools.terminal.autoApprove.**/calculate-quality-metrics.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/calculate-quality-metrics.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/calculate-quality-metrics.ps1 |
| chat.tools.terminal.autoApprove.**/catalog-samples.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/catalog-samples.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/catalog-samples.ps1 |
| chat.tools.terminal.autoApprove.**/extract-config.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/extract-config.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/extract-config.ps1 |
| chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1 |
| chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1 |
| chat.tools.terminal.autoApprove.**/generate-build-cookbook.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-build-cookbook.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-build-cookbook.ps1 |
| chat.tools.terminal.autoApprove.**/generate-config-catalog.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-config-catalog.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-config-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/generate-data-model.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-data-model.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-data-model.ps1 |
| chat.tools.terminal.autoApprove.**/generate-debt-register.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-debt-register.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-debt-register.ps1 |
| chat.tools.terminal.autoApprove.**/generate-dependencies-catalog.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-dependencies-catalog.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-dependencies-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/generate-dependency-graph.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-dependency-graph.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-dependency-graph.ps1 |
| chat.tools.terminal.autoApprove.**/generate-improvements.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-improvements.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-improvements.ps1 |
| chat.tools.terminal.autoApprove.**/generate-overview.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-overview.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-overview.ps1 |
| chat.tools.terminal.autoApprove.**/generate-test-catalog.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-test-catalog.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/generate-test-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/run-all-generators.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/run-all-generators.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/run-all-generators.ps1 |
| chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1 |
| chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1 |
| chat.tools.terminal.autoApprove.**/validate-build-cookbook.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-build-cookbook.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-build-cookbook.ps1 |
| chat.tools.terminal.autoApprove.**/validate-config-catalog.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-config-catalog.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-config-catalog.ps1 |
| chat.tools.terminal.autoApprove.**/validate-data-model.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-data-model.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-data-model.ps1 |
| chat.tools.terminal.autoApprove.**/validate-debt-register.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-debt-register.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-debt-register.ps1 |
| chat.tools.terminal.autoApprove.**/validate-overview.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-overview.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-overview.ps1 |
| chat.tools.terminal.autoApprove.**/validate-test-catalog.ps1 | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-test-catalog.ps1. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.**/validate-test-catalog.ps1 |
| chat.tools.terminal.autoApprove.Copy-Item | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.Copy-Item. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.Copy-Item |
| chat.tools.terminal.autoApprove.Get-ChildItem | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.Get-ChildItem. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.Get-ChildItem |
| chat.tools.terminal.autoApprove.Get-Content | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.Get-Content. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.Get-Content |
| chat.tools.terminal.autoApprove.git | JSON Configuration | false | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.git. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.git |
| chat.tools.terminal.autoApprove.git fetch | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.git fetch. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.git fetch |
| chat.tools.terminal.autoApprove.git status | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.git status. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.git status |
| chat.tools.terminal.autoApprove.pwsh | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.pwsh. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.pwsh |
| chat.tools.terminal.autoApprove.Remove-Item | JSON Configuration | false | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.Remove-Item. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.Remove-Item |
| chat.tools.terminal.autoApprove.Set-ExecutionPolicy | JSON Configuration | false | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.Set-ExecutionPolicy. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.Set-ExecutionPolicy |
| chat.tools.terminal.autoApprove.Test-Path | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.Test-Path. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.Test-Path |
| chat.tools.terminal.autoApprove.Write-Host | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:chat.tools.terminal.autoApprove.Write-Host. | Yes | Tooling/workflow | Build pipeline | .vscode/settings.json:chat.tools.terminal.autoApprove.Write-Host |
| github.copilot.chat.executions.enabled | JSON Configuration | true | Purpose unclear from available evidence — review .vscode/settings.json:github.copilot.chat.executions.enabled. | No | Tooling/workflow | Build pipeline | .vscode/settings.json:github.copilot.chat.executions.enabled |

Masking policy: secret-like keys are masked in defaults to reduce accidental leakage.

## Environment Variables

| Variable | Default | Description | Sensitive | Required |
|----------|---------|-------------|-----------|----------|
|  |  | Environment variable | No | No |

## Configuration Validation

This run extracted configuration keys and sources but not a full validation matrix. Treat required-key checks, value-shape checks, and environment overrides as mandatory pre-release validation tasks.

## Configuration Management

Configuration is distributed across application config files, transforms, project metadata, and pipeline settings. Manage changes with environment-specific promotion controls and explicit review for sensitive settings.

## Security Considerations

Trust model: auto-approve entries execute with local user privileges and should only target trusted scripts under validated repository paths. This workflow enforces repository scope filtering but does not provide cryptographic file-integrity attestation; protect repos and runners accordingly. Restrict auto-approve patterns to least privilege, avoid broad wildcards, and keep display-only commands such as Write-Host non-required from a security perspective.

## Example Configurations

Environment-specific examples are not emitted automatically to avoid accidental secret leakage. Build examples from non-sensitive templates and validate with the required configuration criteria below.

## Required configuration criteria

Use least-privilege auto-approve rules for trusted automation paths only:

- chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1
- chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1

Do not treat chat.tools.terminal.autoApprove.Write-Host as a required security control. Write-Host is a display/UI command and should remain optional.
