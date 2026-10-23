# Changelog

All notable changes to AppDoc. Dates are ISO 8601. ADRs are in `docs/adr/`.

## 1.1.0 — 2026-10-23 (unreleased until tagged)

### Breaking changes

- **Build exit codes** (ADR 0003). `run-appdoc-build.ps1` now reports the outcome: `0` gate passed,
  `2` gate failed, `3` fail-closed stop (redaction sweep or semantic secret-redaction gate), `1` tool
  error (bad path, missing module, a generator that crashed, missing or unreadable
  `validation-report.json`). Wrappers that assumed `0` must treat non-zero as "not done", or pass
  `-AllowGateFail` for exploratory runs.
- **Sub-validator failures count.** A sub-validator that exits non-zero is recorded as failed; one that
  crashes fails the gate (`validatorInternalErrors`). Fixtures were fixed rather than thresholds lowered.
- **Section 7 renamed** from "Help Desk Workflows" to "Operational Workflows" (sub-tag
  `service-procedure`). The old heading is still accepted by the gate with a deprecation warning
  until 1.2.0.
- **`/appdoc.enhance` removed.** A redesigned editorial step is planned for 2.0 (see ROADMAP).
- **Author emails hidden** in git-ownership output by default. Opt in with
  `"ownership": { "showEmails": true }`. `.mailmap` is honoured.
- **`redactionPatterns` are literal values.** Regex metacharacters are no longer interpreted; use the
  new `redactionRegexes` key for patterns.

### Added

- `redactionRegexes` (case-insensitive, 2 s timeout); an invalid regex stops the build with exit 3.
- Operator overlays (`<target>/.appdoc/overlays/<section-slug>.md`, or an explicit `overlays` map in `.appdoc/config.json`):
  target-specific narrative now lives in the target, never in the tool (ADR 0001 amendment).
- `opaqueTokenPattern` config key for target-specific opaque identifiers.
- `outputDir` works end to end (must stay inside the target; otherwise falls back to `docs` with a warning).
- Self-contained offline HTML report: Mermaid 11.17.2 is vendored and inlined by default
  (`"assets": "inline"`); `"assets": "cdn"` keeps the old behaviour.
- Provenance footer on every generated file; generated text is UTF-8 without BOM with LF endings.
- Hand-authored docs marker `<!-- appdoc:hand-authored -->`: such files (and `docs/adr/`) are never
  stamped, normalised or rewritten by the redaction sweep.
- CI: hygiene and harness/target-name lint, PSScriptAnalyzer (approved verbs, trailing whitespace,
  no empty catch blocks in production code), Pester on Ubuntu and Windows plus a run without .NET,
  the quarantine proof harness, and a docs drift check. Actions are pinned by SHA.
- Tests: gate validator failure, build exit codes (including generator crash), re-run determinism,
  operator redaction, composer target-leak, provenance footer, git ownership, outputDir, theme,
  module import; quarantine proof 5b (superseded cache).
- `NOTICE`, `PSScriptAnalyzerSettings.psd1`, `.vscode/settings.example.json`.

### Changed

- Pipeline order: every evidence producer runs before the overview, task guides, evidence register
  and composer, so they see complete evidence. Shared artifacts (api-inventory, data-model,
  build-cookbook) have one explicit owner per target instead of being overwritten.
- Enrichment cache: an output that was corrected after caching is marked `superseded` and honoured.
- Config errors (invalid JSON, missing theme file) stop the build instead of being ignored.
- 51 functions renamed to approved PowerShell verbs. Aliases remain for `Tag-Claim`,
  `Redact-AppDocSemantic*` and `Sanitize-AppDocExternalCallUrl` until 1.2.0.
- `.github/prompts/appdoc.begin.prompt.md` is a thin wrapper over `SKILL.md`;
  `.github/copilot-instructions.md` rewritten as adapter notes.

### Fixed

- Re-runs on the same target produce the same output (stale derived evidence is removed first; the
  gate no longer writes scratch files into the target).
- Duplicate endpoints from the Node AST and regex paths; Java truth-pack/graph count mismatch;
  classic-ASP coverage snapshot; integrity-gate `cicdCount`.
- Regexes that silently failed on CRLF input.
- Web Forms targets no longer receive classic-ASP IIS deployment steps.
- Classic-ASP targets get a real api-inventory appendix instead of a stale "N/A" one.
- Generator failures that were only logged as warnings now fail the build.
- No empty `catch {}` in production code; helper dot-sourcing fails closed.
- The overview no longer invents one dependency for a detected .NET framework with no code files.
- The diagram stability gate no longer fails under StrictMode when the diagram suite leaves
  `$LASTEXITCODE` unset.

### Removed

- Dead scripts: `analyze-codebase.ps1`, `common.ps1`, `generate-architecture-diagram.ps1`,
  `generate-assessment-report.ps1`, `quality-framework.psm1`.
- All Help Desk-specific narrative from the composer (moved to that target's overlay).

## 1.0.x

Initial deterministic Layer 1 build, quarantined Layer 2 enrichment loop, harness-agnostic packaging.
See git history up to `2a14b72`.
