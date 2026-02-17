# appdoc Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-11-12

## Active Technologies
- PowerShell 7+ (for scripts), Markdown (for templates) + VS Code API, PowerShell modules (001-review-ai-samples)
- File system (markdown files, JSON outputs) (001-review-ai-samples)
- Artifact generation templates and parsers (1-appdoc-artifacts)
- PowerShell 7+ + Mermaid markdown generation (001-c4-mermaid-diagrams)
- File system (Mermaid markdown files in `docs/diagrams/`) (001-c4-mermaid-diagrams)

- NEEDS CLARIFICATION (varies by repo) + NEEDS CLARIFICATION (detected per repo) (001-bootstrap-artifact-catalog)

## Project Structure

```text
src/
tests/
```

## Commands

### AppDoc Workflow Commands

**`/appdoc.begin <codebase-path> [output-dir]`**
- Executes complete AppDoc workflow: analyze → generate → validate → assess
- Generates 8 baseline documentation artifacts from codebase analysis
- Output: Machine-generated v0.9 documentation in `docs/` folder
- Example: `/appdoc.begin c:\myproject c:\myproject\docs`

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

NEEDS CLARIFICATION (varies by repo): Follow standard conventions

## Recent Changes
- 001-c4-mermaid-diagrams: Added PowerShell 7+ Mermaid C4 generation workflow and markdown-based diagram outputs
- 001-review-ai-samples: Added PowerShell 7+ (for scripts), Markdown (for templates) + VS Code API, PowerShell modules

- 001-bootstrap-artifact-catalog: Added NEEDS CLARIFICATION (varies by repo) + NEEDS CLARIFICATION (detected per repo)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
