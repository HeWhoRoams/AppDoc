# AppDoc roadmap

**Last updated:** 2026-10-23
**Current version:** 1.1.0

This file says what is done, what comes next, and what is planned for 2.0. The detailed reasoning
for the 1.1.0 work is in `CHANGELOG.md`, the two remediation plans (`AppDoc-Skill-Remediation-Plan.md` and
`AppDoc-Review-Remediation-Plan.md`, kept in the project workspace) and in `docs/adr/`.

## Done (1.0.x – 1.1.0)

- Deterministic Layer 1 build (`run-appdoc-build.ps1`): framework detection, evidence extractors
  (C#/Roslyn AST with regex fallback, TypeScript, Python, Java, Classic ASP / Web Forms), 20-section
  composed document, Mermaid C4 and flow diagrams, pristine report, validation gate.
- Quarantined Layer 2 enrichment loop: redacted input envelopes, provenance tags, Verified-fact lock,
  no-fabrication, fail-closed secret-redaction gate, input-hash cache that honours corrected outputs.
- Harness-agnostic packaging: `SKILL.md` + `references/`; GitHub Copilot wrappers in `.github/prompts/`.
- The gate records sub-validator failures and the build reports the outcome in its exit code (ADR 0003).
- Operator redaction (`redactionPatterns` literal values, `redactionRegexes`), fail-closed on bad input.
- No target-specific knowledge in the tool; target narrative via operator overlays (ADR 0001 amendment).
- Output: provenance footer on every generated file, LF line endings, self-contained offline HTML
  report, configurable `outputDir`, author emails hidden by default, stable across re-runs.
- CI: hygiene and harness-neutral lint, PSScriptAnalyzer, Pester on Ubuntu and Windows, a run without
  .NET, the quarantine proof harness, and a docs drift check.

## Next (1.2.0)

- Remove the deprecated function aliases and the accepted old section heading ("Help Desk
  Workflows").
- Turn on the remaining PSScriptAnalyzer rules in CI (indentation, aliases, empty catch blocks in
  tests) once the code is clean for each.
- Finish the structural refactors that 1.1.0 started: per-section composer module, validators as
  module functions returning structured results, a data-driven pipeline phase table.
- AST caches: invalidate on source change (today a cached parse is reused as long as the file exists).
- Make file enumeration independent of the operating system's notion of hidden folders.

## 2.0

- A redesigned editorial step that replaces the removed `/appdoc.enhance` command: owner-reviewed
  narrative that feeds operator overlays rather than editing generated files in place.
- New framework extractors (Django, Go, Ruby) and AST parsing beyond C# and TypeScript.
- Regenerating docs from a commit hook (ADR 0002 direction).
