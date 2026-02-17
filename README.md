# appdoc


## Overview

AppDoc provides automated documentation extraction, quality assessment, and improvement tools for codebases. The toolkit is implemented in PowerShell and outputs comprehensive reports and recommendations based on analysis of your codebase and generated documentation.

**Note:** The layout and content of external AI-generated samples were used only to inform improvements to AppDoc's templates and prompts. No external sample files are required or processed at runtime.

## Prerequisites

- **PowerShell 7+** (required for all scripts)
- **Windows OS** (tested)
- **VS Code + GitHub Copilot Chat** (for `/appdoc.begin`, `/appdoc.enhance`, `/appdoc.diagrams` commands)
- **Target codebase path** where `docs/` output can be written

## Core Scripts

Primary deterministic workflow:

- `.appdoc/scripts/powershell/run-all-generators.ps1` — end-to-end deterministic pipeline
- `.appdoc/scripts/powershell/appdoc.diagnose.ps1` — environment/readiness diagnostics
- `.appdoc/scripts/powershell/validate-documentation.ps1` — structured validation + scoring
- `.appdoc/scripts/powershell/remediate-generated-docs.ps1` — post-generation cleanup + evidence traceability

Key generators in current workflow include:

- `generate-overview.ps1`, `generate-start-here.ps1`, `generate-docs-index.ps1`
- `generate-api-inventory.ps1`, `generate-data-model.ps1`, `generate-config-catalog.ps1`
- `generate-build-cookbook.ps1`, `generate-test-catalog.ps1`, `generate-task-guides.ps1`
- `generate-debt-register.ps1`, `generate-dependencies-catalog.ps1`
- `generate-c4-mermaid-diagrams.ps1`

## Quick Start

1. Download or clone the `AppDoc` repo into the root of the codebase you want documented.
2. Open that repository in Visual Studio Code.
3. Recommended: Generate Agent Instructions or run an INIT command to have your AI investigate your codebase.
4. Open the GitHub Copilot Chat and run `/appdoc.begin` to start the guided AppDoc workflow.
5. Chat should prompt you to run `/appdoc.enhance` once that completes, otherwise run it.

That's it — AppDoc will perform environment checks and walk you through analysis and generation.

## Architecture Diagrams

AppDoc now generates **Mermaid C4 diagrams** in Markdown format under `docs/diagrams/`.

- `docs/diagrams/c4-context.md`
- `docs/diagrams/c4-container.md`

Use `/appdoc.diagrams` to AI-enhance those Mermaid diagrams in place.

## Script Execution Modes

You can run deterministic generation directly with:

`pwsh ./.appdoc/scripts/powershell/run-all-generators.ps1 -RootPath <codebase-path>`

Useful flags:

- `-DryRun` — previews which scripts and phases would run without generating artifacts.
- `-StrictValidation` — fails the run when generated artifacts score below threshold.
- `-QualityThreshold <1-100>` — sets strict validation cutoff (default: `80`).
- `-SkipDiagrams` — skips C4 diagram generation.
- `-NoAI` — runs deterministic extraction + validation only.

Mermaid C4 diagrams can be generated directly with:

`pwsh ./.appdoc/scripts/powershell/generate-c4-mermaid-diagrams.ps1 -CodebasePath <codebase-path> -OutputPath <codebase-path>/docs -DiagramLevels All`

To AI-enhance generated Mermaid diagrams in place, run `/appdoc.diagrams` in Copilot Chat.

Diagnostics and validation commands:

- `pwsh ./.appdoc/scripts/powershell/appdoc.diagnose.ps1 -RootPath <codebase-path> -Fix`
- `pwsh ./.appdoc/scripts/powershell/validate-documentation.ps1 -RootPath <codebase-path>`
- `pwsh ./.appdoc/scripts/powershell/validate-documentation.ps1 -RootPath <codebase-path> -Strict -Threshold 80`

## Framework Support Matrix

Last updated: 2026-02-17

### Supported Frameworks

| Status | Language | Framework | Version Range | Coverage | Notes |
|---|---|---|---|---:|---|
| ✅ Full | C# | ASP.NET Core | 2.1+ | 90% | Controller/route detection, config extraction, model heuristics |
| ⚠️ Partial | C# | ASP.NET MVC 5 | 5.x | 75% | Action detection supported; some attribute edge cases remain |
| ⚠️ Partial | JS/TS | Express.js | 4.x | 60% | Basic `app.METHOD` and router patterns; middleware chains limited |
| ⚠️ Partial | Python | Flask | 2.x+ | 65% | `@app.route` and common blueprint patterns supported |
| ⚠️ Partial | Python | FastAPI | 0.9+ | 70% | Decorator and response model heuristics supported |
| ⚠️ Partial | Python | Django | 3.x+ | 55% | URL pattern extraction supported; deep viewset inference limited |
| ⚠️ Partial | Java | Spring Boot | 2.x+ | 60% | `@*Mapping` and `@RequestMapping` scanning supported |

### Unsupported or Planned

| Status | Framework | Planned |
|---|---|---|
| ❌ Not supported | Ruby on Rails | Planned (TBD) |
| ❌ Not supported | Go (Gin/Echo) | Planned (TBD) |
| ❌ Not supported | PHP (Laravel) | Planned (TBD) |

### Detection Signals

- C#: `*.csproj`, `*.sln`, `[ApiController]`, `[HttpGet]`, `MapControllers`
- JS/TS: `package.json` dependencies (`express`) and `app.get` / `router.get` patterns
- Python: `requirements.txt` / `pyproject.toml` deps (`flask`, `fastapi`, `django`), route decorators, `urls.py`
- Java: `pom.xml` Spring dependencies, `@RestController`, `@RequestMapping`

### Requesting New Framework Support

Open an issue with:

1. Framework name and target version
2. Minimal sample project or repo
3. Expected artifacts (API inventory, data model, config catalog, etc.)
4. Known route/config/model patterns used in your codebase


## Output Files
- **[Start Here](docs/start-here.md)** - Role-based onboarding and quick orientation
- **[Overview](docs/overview.md)** - High-level system summary and documentation index
- **[API Inventory](docs/api-inventory.md)** - HTTP endpoints and API contracts
- **[Data Model](docs/data-model.md)** - Data structures and entities
- **[Configuration Catalog](docs/config-catalog.md)** - Configuration options and environment variables
- **[Build Cookbook](docs/build-cookbook.md)** - Build and deployment commands
- **[Test Catalog](docs/test-catalog.md)** - Test suites and coverage
- **[Task Guides](docs/task-guides.md)** - Task-centric implementation and operations playbooks
- **[Tech Debt Register](docs/debt-register.md)** - Known issues and improvement opportunities
- **[Dependencies Catalog](docs/dependencies-catalog.md)** - External packages and libraries
- **[Documentation Index](docs/index.md)** - Landing page linking all generated artifacts
- **[C4 Context Diagram](docs/diagrams/c4-context.md)** - Mermaid C4 system context
- **[C4 Container Diagram](docs/diagrams/c4-container.md)** - Mermaid C4 container view
- **[Quality Report](docs/quality-report.json)** - Generator quality scoring output
- **[Validation Report](docs/validation-report.json)** - Deterministic validation metrics
- **[Diagnostics Report](docs/diagnostics-report.json)** - Environment/runtime diagnostics
- **[Evidence Manifest](docs/evidence/manifest.json)** - Traceability index for artifact evidence records

## Troubleshooting

- Ensure all required scripts and modules are present in `.appdoc/scripts/powershell/`
- Use PowerShell 7+ for compatibility
- Check file paths for documentation output
- Review error messages for missing files or permissions
- Run `pwsh ./.appdoc/scripts/powershell/appdoc.diagnose.ps1 -RootPath <codebase-path> -Fix` to validate environment and script readiness

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

License file is not currently included in this repository. Add a `LICENSE` file before external distribution.

## Support

For support, please open an issue on GitHub.

---

