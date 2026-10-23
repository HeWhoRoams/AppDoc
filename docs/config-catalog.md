# Configuration Catalog
**Generated**: 2026-10-22 10:29:27

## Summary

This artifact lists configuration inputs that can change runtime behavior, with sensitive values redacted and evidence references preserved.

## Configuration Sources

- **JSON Configuration**: 1 files
- **YAML Configuration**: 1 files

## Configuration Options

### Runtime Configuration (Priority)

No runtime configuration entries detected.

### Deployment / Environment Configuration

| Name | Type | Default | Description | Required | Where Used | Environment Requirement | Source |
|------|------|---------|-------------|----------|------------|--------------------------|--------|
| name | YAML Configuration | appdoc-ci | Purpose unclear from available evidence — review .github/workflows/appdoc-ci.yml:yaml/name. | No | Deployment/environment | Environment-specific | .github/workflows/appdoc-ci.yml:yaml/name |

### Tooling and Workflow Configuration

| Name | Type | Default | Description | Required | Where Used | Environment Requirement | Source |
|------|------|---------|-------------|----------|------------|--------------------------|--------|
| concurrency.cancel-in-progress | YAML Configuration | true | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/concurrency.cancel-in-progress |
| concurrency.group | YAML Configuration | ci-${{ github.ref }} | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/concurrency.group |
| jobs.hygiene.name | YAML Configuration | Repo hygiene and static gates | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.name |
| jobs.hygiene.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.runs-on |
| jobs.hygiene.steps.run | YAML Configuration | ./.appdoc/scripts/powershell/ci-doc-integrity-gate.ps1 -RootPath . | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps.run |
| jobs.hygiene.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps.shell |
| jobs.hygiene.steps[0] | YAML Configuration | uses: actions/checkout@v4 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[0] |
| jobs.hygiene.steps[1] | YAML Configuration | name: No tracked files that .gitignore excludes | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[1] |
| jobs.hygiene.steps[2] | YAML Configuration | name: PowerShell syntax gate | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[2] |
| jobs.hygiene.steps[3] | YAML Configuration | name: Documentation integrity gate | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[3] |
| jobs.tests.name | YAML Configuration | Pester + proof harness (${{ matrix.os }}) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.name |
| jobs.tests.needs | YAML Configuration | hygiene | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.needs |
| jobs.tests.runs-on | YAML Configuration | ${{ matrix.os }} | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.runs-on |
| jobs.tests.steps.run | YAML Configuration | ./tests/powershell/test-semantic-quarantine.ps1 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps.run |
| jobs.tests.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps.shell |
| jobs.tests.steps.with.dotnet-version | YAML Configuration | 8.0.x | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps.with.dotnet-version |
| jobs.tests.steps[0] | YAML Configuration | uses: actions/checkout@v4 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[0] |
| jobs.tests.steps[1] | YAML Configuration | uses: actions/setup-dotnet@v4 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[1] |
| jobs.tests.steps[2] | YAML Configuration | name: Install Pester 5 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[2] |
| jobs.tests.steps[3] | YAML Configuration | name: Pester (all suites in tests/powershell) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[3] |
| jobs.tests.steps[4] | YAML Configuration | name: Semantic quarantine proof harness (plain script, not Pester) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[4] |
| jobs.tests.strategy.fail-fast | YAML Configuration | false | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.strategy.fail-fast |
| jobs.tests.strategy.matrix.os | YAML Configuration | [ubuntu-latest, windows-latest] | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.strategy.matrix.os |
| on.push.branches | YAML Configuration | [main] | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/on.push.branches |
| permissions.contents | YAML Configuration | read | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/permissions.contents |
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

Treat connection strings, credentials, tokens, and endpoint URLs as sensitive-by-default. Validate redaction of secret-like values before publishing artifacts, and restrict broad wildcard allowlist patterns to trusted, repository-controlled paths.

## Example Configurations

Environment-specific examples are not emitted automatically to avoid accidental secret leakage. Build examples from non-sensitive templates and validate with the required configuration criteria.

## Evidence Traceability

| Field | Value |
|------|-------|
| Evidence Artifact | evidence/config-catalog.evidence.json |
| Record Count | 72 |
| Generator | generate-config-catalog.ps1 |
| Required Evidence Keys | configurations |
| Grounding Mode | Deterministic extraction records |
---
**Generated by AppDoc Framework**
## Provenance

- Generator Version: appdoc-run-all-generators/3.0.0
- Commit Hash: 546ea9d
- Generated At: 2026-10-22T10:29:42-04:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
