# appdoc


## Overview

AppDoc provides automated documentation extraction, quality assessment, and improvement tools for codebases. The toolkit is implemented in PowerShell and outputs comprehensive reports and recommendations based on analysis of your codebase and generated documentation.

**Note:** The layout and content of external AI-generated samples were used only to inform improvements to AppDoc's templates and prompts. No external sample files are required or processed at runtime.

## Prerequisites

- **PowerShell 7+** (required for all scripts)
- **Windows OS** (tested)
- **VsCode** (future support for CLI AI coming soon)
- **Current documentation output** in `docs/`

## Required Files

To run the full documentation extraction and assessment workflow, ensure the following files exist:

- `.appdoc/scripts/powershell/analyze-capability-gaps.ps1` — Analyze documentation quality and identify gaps
- `.appdoc/scripts/powershell/generate-improvements.ps1` — Generate improvement suggestions
- `.appdoc/scripts/powershell/calculate-quality-metrics.ps1` — Compute quality metrics
- `.appdoc/scripts/powershell/synthesize-assessment-report.ps1` — Generate final assessment report
- `.appdoc/scripts/powershell/run-all-generators.ps1` — Run all documentation generators and assessment scripts
- `.appdoc/scripts/powershell/quality-framework.psm1` — Quality scoring functions
- `.appdoc/scripts/powershell/gap-analysis.psm1` — Gap analysis data structures

## Quick Start

1. Download or clone the `AppDoc` repo into the root of the codebase you want documented.
2. Open that repository in Visual Studio Code.
3. Recommended: Generate Agent Instructions or run an INIT command to have your AI investigate your codebase.
4. Open the GitHub Copilot Chat and run `/appdoc.begin` to start the guided AppDoc workflow.
5. Chat should prompt you to run `/appdoc.enhance` once that completes, otherwise run it.

That's it — AppDoc will perform environment checks and walk you through analysis and generation.


## Output Files
- **[API Inventory](api-inventory.md)** - HTTP endpoints and API contracts
- **[Data Model](data-model.md)** - Data structures and entities
- **[Configuration Catalog](config-catalog.md)** - Configuration options and environment variables
- **[Build Cookbook](build-cookbook.md)** - Build and deployment commands
- **[Test Catalog](test-catalog.md)** - Test suites and coverage
- **[Tech Debt Register](debt-register.md)** - Known issues and improvement opportunities
- **[Dependencies Catalog](dependencies-catalog.md)** - External packages and libraries

## Troubleshooting

- Ensure all required scripts and modules are present in `.appdoc/scripts/powershell/`
- Use PowerShell 7+ for compatibility
- Check file paths for documentation output
- Review error messages for missing files or permissions

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

## License

This project is licensed under the MIT License or something.

## Support

For support, please open an issue on GitHub.

---

