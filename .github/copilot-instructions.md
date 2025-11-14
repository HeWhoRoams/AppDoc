# appdoc Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-11-12

## Active Technologies
- PowerShell 7+ (for scripts), Markdown (for templates) + VS Code API, PowerShell modules (001-review-ai-samples)
- File system (markdown files, JSON outputs) (001-review-ai-samples)
- Artifact generation templates and parsers (1-appdoc-artifacts)
- PowerShell 7+ + PlantUML JAR (optional, bundled or downloaded), Java 8+ (optional for SVG rendering) (001-c4-plantuml-diagrams)
- File system (PlantUML source `.puml` files, generated SVG files in `docs/diagrams/`) (001-c4-plantuml-diagrams)

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
- Enhances deterministically-generated PlantUML C4 diagrams with AI analysis
- Adds missing external systems, actors, and detailed descriptions from codebase
- Updates `.puml` source files before SVG rendering
- Three-step workflow separates generation, enhancement, and rendering:
  1. **Generate baseline**: `generate-c4-diagrams.ps1 -RenderMode SourceOnly` (creates .puml files)
  2. **AI enhance**: `/appdoc.diagrams` (AI enhances .puml files with codebase analysis)
  3. **Render SVGs**: `render-plantuml-diagrams.ps1` (converts enhanced .puml to SVG)

## Code Style

NEEDS CLARIFICATION (varies by repo): Follow standard conventions

## Recent Changes
- 001-c4-plantuml-diagrams: Added PowerShell 7+ + PlantUML JAR (optional, bundled or downloaded), Java 8+ (optional for SVG rendering)
- 001-review-ai-samples: Added PowerShell 7+ (for scripts), Markdown (for templates) + VS Code API, PowerShell modules

- 001-bootstrap-artifact-catalog: Added NEEDS CLARIFICATION (varies by repo) + NEEDS CLARIFICATION (detected per repo)


<!-- MANUAL ADDITIONS START -->
<!-- MANUAL ADDITIONS END -->
