# appdoc Development Guidelines

Maintained by hand to reflect the actual repository layout and the four AppDoc Copilot commands.

## Active Technologies
- PowerShell 7.2+ (scripts and modules), Markdown (templates), JSON (evidence layer)
- Optional: .NET SDK for the Roslyn-based C# AST parser (regex fallback when absent)
- File system output only (`docs/`, `docs/evidence/`, `docs/diagrams/`)

## Project Structure

```text
.appdoc/        # scripts (powershell/), modules, tools (C# AST parser), templates
docs/           # generated artifacts (start-here, overview, api-inventory, ...) + diagrams/ + evidence/
tests/          # PowerShell test suite (tests/powershell/) and fixtures
.github/prompts/  # Copilot prompt definitions (appdoc.*)
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
