# appdoc Development Guidelines

Auto-generated from feature plans and the current AppDoc workflow. Refreshed to reflect the actual repository layout and the four AppDoc Copilot commands.

## Active Technologies
- PowerShell 7+ (for scripts), Markdown (for templates) + VS Code API, PowerShell modules (001-review-ai-samples)
- File system (markdown files, JSON outputs) (001-review-ai-samples)
- Artifact generation templates and parsers (1-appdoc-artifacts)
- PowerShell 7+ + Mermaid markdown generation (001-c4-mermaid-diagrams)
- File system (Mermaid markdown files in `docs/diagrams/`) (001-c4-mermaid-diagrams)

- File system (markdown files in `docs/`, JSON outputs in `docs/evidence/`) (001-bootstrap-artifact-catalog)

## Project Structure

```text
.appdoc/        # scripts (powershell/), modules, tools (C# AST parser), templates
docs/           # generated artifacts (start-here, overview, api-inventory, ...) + diagrams/ + evidence/
tests/          # PowerShell test suite (tests/powershell/) and fixtures
.github/prompts/  # Copilot prompt definitions (appdoc.*, speckit.*)
```

## Commands

### AppDoc Workflow Commands

**`/appdoc.begin <codebase-path> [output-dir]`**
- Executes complete AppDoc workflow: analyze → generate → validate → assess
- Generates 8 baseline documentation artifacts from codebase analysis
- Output: Machine-generated v0.9 documentation in `docs/` folder
- Example: `/appdoc.begin c:\myproject c:\myproject\docs`

**`/appdoc.enrich`**
- Bootstraps evidence, applies semantic enrichment, and runs the enrichment quality gate
- Runs `run-appdoc-enrich.ps1` (bootstrap + semantic apply + gate) against the codebase
- Produces `docs/evidence/semantic/input/*.semantic.input.json` records (and optional `output/*.semantic.output.json` responses) for AI review
- Must run before `/appdoc.enhance`
- Example: `pwsh ./.appdoc/scripts/powershell/run-appdoc-enrich.ps1 -RootPath <codebase-path>`

**`/appdoc.enhance`**
- Transforms v0.9 machine-generated artifacts into production-ready documentation
- AI-driven synthesis: fills gaps, corrects inaccuracies, adds context and diagrams
- Enhances all 8 artifacts in place with code-verified information
- Must run after `/appdoc.begin`

**`/appdoc.diagrams`**
- Enhances deterministically-generated Mermaid C4 diagrams with AI analysis
- Adds missing external systems, actors, and detailed descriptions from codebase
- Updates Mermaid markdown diagram files in place
- Workflow:
  1. **Generate baseline**: `generate-c4-mermaid-diagrams.ps1` (creates Mermaid markdown files)
  2. **AI enhance**: `/appdoc.diagrams` (AI enhances Mermaid files with codebase analysis)

## Code Style

Follow the existing conventions in each area: PowerShell 7+ scripts under `.appdoc/scripts/powershell/` (PascalCase functions, `[CmdletBinding()]`, structured error output), Markdown templates under `.appdoc/templates/`, and generated documentation in `docs/`. Preserve `<!-- AUTO-GENERATED -->` markers and do not hand-edit generated evidence JSON.

## Recent Changes
- 001-c4-mermaid-diagrams: Added PowerShell 7+ Mermaid C4 generation workflow and markdown-based diagram outputs
- 001-review-ai-samples: Added PowerShell 7+ (for scripts), Markdown (for templates) + VS Code API, PowerShell modules

- 001-bootstrap-artifact-catalog: Added file-system artifact catalog (markdown in `docs/`, JSON outputs in `docs/evidence/`)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
