# Changelog

All notable changes to AppDoc. Dates are ISO 8601. ADRs are in `docs/adr/`.

## 1.1.0 — 2026-10-23 (unreleased until tagged)

### Changed (audit remediation)

- **Secrets in free text are redacted** (audit finding 1). TODO/FIXME/HACK text, and every generated
  file in the final sweep, now pass through `Protect-AppDocFreeText`: vendor-shaped secrets (AWS, GitHub,
  Slack, Stripe, Google, JWT, PEM) and `name = value` pairs whose name looks like a secret. The sweep
  fails the build (exit 3) if a vendor shape survives, and the validator scores a leak.
- **Faster scope filter** (finding 2). `Get-AppDocSourceFiles` skips excluded folders instead of listing
  and then filtering every file (10,000 files in about 0.3 s, down from about 17 s). It returns files
  in ordinal path order on every OS. Two AST-cache snapshot hashes changed because their file lists are
  now ordered that way; the content is the same.

### Breaking changes

- **Enrichment is no longer optional.** The Layer 2 enrichment stage runs on every build. The
  `-EnableSemanticEnrich` switch and the `enableSemanticEnrich` config key are removed (a leftover
  config key is ignored). The stage writes the redacted input and applies any output the AI session
  left; with none present it applies nothing, and the four gate-scored catalogs are unchanged.
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

- Output snapshot harness (`tests/powershell/test-output-snapshot.ps1`): builds every fixture and
  compares each generated file, the exit code and the gate result with a committed baseline
  (`tests/powershell/snapshots/no-dotnet/`). Runs in CI on the Linux leg without .NET.

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
- Internal: one object accessor, `Get-AppDocValue` (new `AppDoc.Values.psm1`), replaces 21 copies of the
  property getters (666 call sites). Nine per-extractor relative-path wrappers are gone; callers use
  `Get-AppDocRelativePath`; the Classic ASP generators' `Get-RelativePath` is gone too. Six extractors no longer
  fall back to an unfiltered `Get-ChildItem` when the scope module is missing (it is imported eagerly).
  Per-artifact file patterns now live in `.appdoc/policies/scope.v1.json` (`patternSets`; read with
  `Get-AppDocScopePatterns`, or `Get-AppDocSourceFiles -Set`). A repo-local policy without `patternSets`
  falls back to the built-in sets. Generated output is byte-identical (snapshot harness).

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
