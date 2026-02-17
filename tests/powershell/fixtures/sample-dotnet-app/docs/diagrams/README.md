# Architecture Diagrams (Mermaid)

This directory contains Mermaid-based C4 diagram markdown files.

## Files

- `c4-context.md` - System context view
- `c4-container.md` - Container view

Each file embeds Mermaid directly in markdown:

```mermaid
graph LR
  A[Example] --> B[Example]
```

## Regeneration

```powershell
.\\.appdoc\scripts\powershell\generate-c4-mermaid-diagrams.ps1 `
  -CodebasePath ".\SampleApp.sln" `
  -OutputPath ".\docs" `
  -DiagramLevels All `
  -Force
```

## Enhancement

Use `/appdoc.diagrams` to enrich diagram details from code evidence.
