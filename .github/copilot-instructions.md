# AppDoc — GitHub Copilot adapter notes

AppDoc is a harness-agnostic skill. [`SKILL.md`](../SKILL.md) is the source of truth for what AppDoc does and how to run it; [`references/`](../references/) holds the detailed contracts. This file only tells Copilot where things are and which slash commands map to which steps.

## Slash commands (thin wrappers in `.github/prompts/`)

| Command | Maps to | Defined in |
|---|---|---|
| `/appdoc.begin <target>` | Layer 1 — the deterministic build (`run-appdoc-build.ps1`) | `SKILL.md`, `references/verification.md` |
| `/appdoc.enrich` | Layer 2 — the quarantined enrichment loop | `references/enrichment-contract.md`, `references/enrichment-operations.md` |
| `/appdoc.diagrams` | Optional wording polish of the generated Mermaid diagrams (structure unchanged) | `.github/prompts/appdoc.diagrams.prompt.md` |

Always build through `run-appdoc-build.ps1`. It loads the target's config, runs the pipeline, applies the redaction sweep, stamps provenance and returns the exit code (0 pass, 2 gate failed, 3 fail-closed stop, 1 tool error).

## Repository layout

```text
SKILL.md              # the skill contract (entry point for any AI harness)
references/           # enrichment contract/operations, config schema, verification
.appdoc/scripts/powershell/   # entry scripts (run-appdoc-build.ps1, generate-*, validate-*, ci-*)
.appdoc/scripts/powershell/modules/   # shared modules (AppDoc.*.psm1)
.appdoc/templates/    # Markdown templates, HTML themes, vendored Mermaid
docs/                 # AppDoc's own generated documentation (self-dogfood) + docs/adr/
tests/powershell/     # Pester suites (*.Tests.ps1, test-golden-*.ps1) + the quarantine harness
tests/fixtures/       # sample targets used by the tests
```

## Coding conventions

- PowerShell 7.2+. Every entry script starts with `#requires -Version 7.2` and `[CmdletBinding()]`.
- Function names use approved PowerShell verbs and PascalCase (`Get-AppDoc…`, `ConvertTo-AppDoc…`); the linter settings are in `PSScriptAnalyzerSettings.psd1` at the repo root.
- No empty `catch {}`: report through `Write-AppDocDiagnostic` (or rethrow).
- Generated text is UTF-8 without BOM, LF line endings (`.editorconfig`, `.gitattributes`).
- Resolve the output folder with `Get-AppDocDocsPath` (`modules/AppDoc.Paths.psm1`), never a literal `docs`.
- Never add knowledge of a specific target to the tool; target narrative belongs in that target's overlay files.
- Do not hand-edit generated evidence JSON.
