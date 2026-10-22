# Configuration Catalog
**Generated**: 2026-10-17 18:40:50

## Summary

This artifact lists configuration inputs that can change runtime behavior, with sensitive values redacted and evidence references preserved.

## Configuration Sources

- **JSON Configuration**: 1 files
- **YAML Configuration**: 2 files

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
| itsm.base-url | YAML Configuration | https://itsm.acme.internal | Purpose unclear from available evidence — review source usage. | Yes | Deployment/environment | Environment-specific | .tmp-java-golden-verify/src/main/resources/application.yml:yaml/itsm.base-url |
| logging.level.com.acme | YAML Configuration | INFO | Purpose unclear from available evidence — review source usage. | No | Deployment/environment | Environment-specific | .tmp-java-golden-verify/src/main/resources/application.yml:yaml/logging.level.com.acme |
| server.port | YAML Configuration | 8080 | Purpose unclear from available evidence — review source usage. | Yes | Deployment/environment | Environment-specific | .tmp-java-golden-verify/src/main/resources/application.yml:yaml/server.port |
| spring.application.name | YAML Configuration | tickets-service | Purpose unclear from available evidence — review source usage. | No | Deployment/environment | Environment-specific | .tmp-java-golden-verify/src/main/resources/application.yml:yaml/spring.application.name |
| spring.datasource.password | YAML Configuration | ***masked*** | Purpose unclear from available evidence — review source usage. | Yes | Deployment/environment | Environment-specific | .tmp-java-golden-verify/src/main/resources/application.yml:yaml/spring.datasource.password |
| spring.datasource.url | YAML Configuration | jdbc:mysql://db-host.internal:3306/tickets | Purpose unclear from available evidence — review source usage. | Yes | Deployment/environment | Environment-specific | .tmp-java-golden-verify/src/main/resources/application.yml:yaml/spring.datasource.url |
| spring.datasource.username | YAML Configuration | tickets_user | Purpose unclear from available evidence — review source usage. | Yes | Deployment/environment | Environment-specific | .tmp-java-golden-verify/src/main/resources/application.yml:yaml/spring.datasource.username |
| spring.jpa.hibernate.ddl-auto | YAML Configuration | update | Purpose unclear from available evidence — review source usage. | No | Deployment/environment | Environment-specific | .tmp-java-golden-verify/src/main/resources/application.yml:yaml/spring.jpa.hibernate.ddl-auto |

### Tooling and Workflow Configuration

| Name | Type | Default | Description | Required | Where Used | Environment Requirement | Source |
|------|------|---------|-------------|----------|------------|--------------------------|--------|
| jobs.golden-test-csharp-core.name | YAML Configuration | Golden-file regression (C# / ASP.NET Core Web API) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp-core.name |
| jobs.golden-test-csharp-core.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp-core.runs-on |
| jobs.golden-test-csharp-core.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp-core.steps.shell |
| jobs.golden-test-csharp-core.steps.uses | YAML Configuration | actions/setup-pwsh@v3 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp-core.steps.uses |
| jobs.golden-test-csharp-core.steps[0] | YAML Configuration | uses: actions/checkout@v4 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp-core.steps[0] |
| jobs.golden-test-csharp-core.steps[1] | YAML Configuration | name: Setup PowerShell | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp-core.steps[1] |
| jobs.golden-test-csharp-core.steps[2] | YAML Configuration | name: Install Pester | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp-core.steps[2] |
| jobs.golden-test-csharp-core.steps[3] | YAML Configuration | name: Run C# ASP.NET Core Web API golden-file regression test | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp-core.steps[3] |
| jobs.golden-test-csharp.name | YAML Configuration | Golden-file regression (C# / ASP.NET Web Forms) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp.name |
| jobs.golden-test-csharp.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp.runs-on |
| jobs.golden-test-csharp.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp.steps.shell |
| jobs.golden-test-csharp.steps.uses | YAML Configuration | actions/setup-pwsh@v3 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp.steps.uses |
| jobs.golden-test-csharp.steps[0] | YAML Configuration | uses: actions/checkout@v4 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp.steps[0] |
| jobs.golden-test-csharp.steps[1] | YAML Configuration | name: Setup PowerShell | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp.steps[1] |
| jobs.golden-test-csharp.steps[2] | YAML Configuration | name: Install Pester | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp.steps[2] |
| jobs.golden-test-csharp.steps[3] | YAML Configuration | name: Run C# Web Forms golden-file regression test | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-csharp.steps[3] |
| jobs.golden-test-java.name | YAML Configuration | Golden-file regression (Java / Spring Boot) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-java.name |
| jobs.golden-test-java.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-java.runs-on |
| jobs.golden-test-java.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-java.steps.shell |
| jobs.golden-test-java.steps.uses | YAML Configuration | actions/setup-pwsh@v3 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-java.steps.uses |
| jobs.golden-test-java.steps[0] | YAML Configuration | uses: actions/checkout@v4 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-java.steps[0] |
| jobs.golden-test-java.steps[1] | YAML Configuration | name: Setup PowerShell | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-java.steps[1] |
| jobs.golden-test-java.steps[2] | YAML Configuration | name: Install Pester | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-java.steps[2] |
| jobs.golden-test-java.steps[3] | YAML Configuration | name: Run Java / Spring Boot golden-file regression test | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-java.steps[3] |
| jobs.golden-test-node.name | YAML Configuration | Golden-file regression (Node / Express + TypeScript) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-node.name |
| jobs.golden-test-node.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-node.runs-on |
| jobs.golden-test-node.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-node.steps.shell |
| jobs.golden-test-node.steps.uses | YAML Configuration | actions/setup-pwsh@v3 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-node.steps.uses |
| jobs.golden-test-node.steps[0] | YAML Configuration | uses: actions/checkout@v4 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-node.steps[0] |
| jobs.golden-test-node.steps[1] | YAML Configuration | name: Setup PowerShell | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-node.steps[1] |
| jobs.golden-test-node.steps[2] | YAML Configuration | name: Install Pester | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-node.steps[2] |
| jobs.golden-test-node.steps[3] | YAML Configuration | name: Run Node / Express (TypeScript) golden-file regression test | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-node.steps[3] |
| jobs.golden-test-python.name | YAML Configuration | Golden-file regression (Python / Flask) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-python.name |
| jobs.golden-test-python.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-python.runs-on |
| jobs.golden-test-python.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-python.steps.shell |
| jobs.golden-test-python.steps.uses | YAML Configuration | actions/setup-pwsh@v3 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-python.steps.uses |
| jobs.golden-test-python.steps[0] | YAML Configuration | uses: actions/checkout@v4 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-python.steps[0] |
| jobs.golden-test-python.steps[1] | YAML Configuration | name: Setup PowerShell | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-python.steps[1] |
| jobs.golden-test-python.steps[2] | YAML Configuration | name: Install Pester | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-python.steps[2] |
| jobs.golden-test-python.steps[3] | YAML Configuration | name: Run Python / Flask golden-file regression test | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test-python.steps[3] |
| jobs.golden-test.name | YAML Configuration | Golden-file regression (framework-agnostic) | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test.name |
| jobs.golden-test.runs-on | YAML Configuration | ubuntu-latest | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test.runs-on |
| jobs.golden-test.steps.shell | YAML Configuration | pwsh | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test.steps.shell |
| jobs.golden-test.steps.uses | YAML Configuration | actions/setup-pwsh@v3 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test.steps.uses |
| jobs.golden-test.steps[0] | YAML Configuration | uses: actions/checkout@v4 | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test.steps[0] |
| jobs.golden-test.steps[1] | YAML Configuration | name: Setup PowerShell | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test.steps[1] |
| jobs.golden-test.steps[2] | YAML Configuration | name: Install Pester | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test.steps[2] |
| jobs.golden-test.steps[3] | YAML Configuration | name: Run golden-file regression test | Purpose unclear from available evidence — review source usage. | No | Tooling/workflow | Build pipeline | .github/workflows/appdoc-ci.yml:yaml/jobs.golden-test.steps[3] |
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
| Record Count | 110 |
| Generator | generate-config-catalog.ps1 |
| Required Evidence Keys | configurations |
| Grounding Mode | Deterministic extraction records |
---
**Generated by AppDoc Framework**
## Provenance

- Generator Version: appdoc-run-all-generators/3.0.0
- Commit Hash: 85946f7
- Generated At: 2026-10-17T18:41:14-04:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
