# Configuration Catalog
**Generated**: 2026-10-23 01:55:31

## Summary

This artifact lists configuration inputs that can change runtime behavior, with sensitive values redacted and evidence references preserved.

## Configuration Sources

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
| jobs.drift.name | YAML Configuration | Committed docs/ match a fresh build | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.drift.name |
| jobs.drift.needs | YAML Configuration | hygiene | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.drift.needs |
| jobs.drift.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.drift.runs-on |
| jobs.drift.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.drift.steps.shell |
| jobs.drift.steps.with.fetch-depth | YAML Configuration | 0 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.drift.steps.with.fetch-depth |
| jobs.drift.steps[0] | YAML Configuration | uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.drift.steps[0] |
| jobs.drift.steps[1] | YAML Configuration | name: Rebuild the self-dogfood docs in a scratch copy and compare | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.drift.steps[1] |
| jobs.hygiene.name | YAML Configuration | Repo hygiene and static gates | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.name |
| jobs.hygiene.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.runs-on |
| jobs.hygiene.steps.run | YAML Configuration | ./.appdoc/scripts/powershell/ci-doc-integrity-gate.ps1 -RootPath . | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps.run |
| jobs.hygiene.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps.shell |
| jobs.hygiene.steps[0] | YAML Configuration | uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[0] |
| jobs.hygiene.steps[1] | YAML Configuration | name: No tracked files that .gitignore excludes | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[1] |
| jobs.hygiene.steps[2] | YAML Configuration | name: Skill docs are harness-agnostic and frontmatter is valid | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[2] |
| jobs.hygiene.steps[3] | YAML Configuration | name: Core is harness-neutral and carries no target-specific names | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[3] |
| jobs.hygiene.steps[4] | YAML Configuration | name: Entry scripts declare PowerShell 7.2 and CmdletBinding | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[4] |
| jobs.hygiene.steps[5] | YAML Configuration | name: Scripts named in docs, prompts and editor settings exist | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[5] |
| jobs.hygiene.steps[6] | YAML Configuration | name: No absolute host paths and no CR line endings in committed docs/ | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[6] |
| jobs.hygiene.steps[7] | YAML Configuration | name: PowerShell syntax gate | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[7] |
| jobs.hygiene.steps[8] | YAML Configuration | name: Documentation integrity gate | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.hygiene.steps[8] |
| jobs.lint.name | YAML Configuration | PSScriptAnalyzer | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.lint.name |
| jobs.lint.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.lint.runs-on |
| jobs.lint.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.lint.steps.shell |
| jobs.lint.steps[0] | YAML Configuration | uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.lint.steps[0] |
| jobs.lint.steps[1] | YAML Configuration | name: Analyze (enforced rules fail the job; the rest are reported) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.lint.steps[1] |
| jobs.tests.name | YAML Configuration | Pester + proof harness (${{ matrix.os }}, dotnet ${{ matrix.dotnet }}) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.name |
| jobs.tests.needs | YAML Configuration | hygiene | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.needs |
| jobs.tests.runs-on | YAML Configuration | ${{ matrix.os }} | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.runs-on |
| jobs.tests.steps.if | YAML Configuration | matrix.dotnet == 'without' | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps.if |
| jobs.tests.steps.run | YAML Configuration | ./tests/powershell/test-semantic-quarantine.ps1 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps.run |
| jobs.tests.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps.shell |
| jobs.tests.steps.with.dotnet-version | YAML Configuration | 8.0.x | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps.with.dotnet-version |
| jobs.tests.steps.with.fetch-depth | YAML Configuration | 0 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps.with.fetch-depth |
| jobs.tests.steps[0] | YAML Configuration | uses: actions/checkout@11d5960a326750d5838078e36cf38b85af677262 # v4.4.0 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[0] |
| jobs.tests.steps[1] | YAML Configuration | uses: actions/setup-dotnet@67a3573c9a986a3f9c594539f4ab511d57bb3ce9 # v4.3.1 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[1] |
| jobs.tests.steps[2] | YAML Configuration | name: Hide dotnet (regex-fallback leg) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[2] |
| jobs.tests.steps[3] | YAML Configuration | name: Install Pester 5 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[3] |
| jobs.tests.steps[4] | YAML Configuration | name: Pester (unit suites + golden suites) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[4] |
| jobs.tests.steps[5] | YAML Configuration | name: Semantic quarantine proof harness (plain script, not Pester) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.steps[5] |
| jobs.tests.strategy.fail-fast | YAML Configuration | false | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.strategy.fail-fast |
| jobs.tests.strategy.matrix.dotnet | YAML Configuration | [with] | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.strategy.matrix.dotnet |
| jobs.tests.strategy.matrix.include.dotnet | YAML Configuration | without | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.strategy.matrix.include.dotnet |
| jobs.tests.strategy.matrix.include[0] | YAML Configuration | os: ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.strategy.matrix.include[0] |
| jobs.tests.strategy.matrix.os | YAML Configuration | [ubuntu-latest, windows-latest] | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.tests.strategy.matrix.os |
| on.push.branches | YAML Configuration | [main] | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/on.push.branches |
| permissions.contents | YAML Configuration | read | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/permissions.contents |

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
| Record Count | 49 |
| Generator | generate-config-catalog.ps1 |
| Required Evidence Keys | configurations |
| Grounding Mode | Deterministic extraction records |
---
**Generated by AppDoc Framework**

## Provenance

- Generator Version: appdoc-run-all-generators/3.0.0
- Commit Hash: 17cdd36
- Generated At: 2026-10-23T01:55:45-04:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
