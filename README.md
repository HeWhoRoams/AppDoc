# AppDoc

## Overview

AppDoc is a **local-first, deterministic PowerShell 7 documentation auto-generator** for legacy and unknown codebases. It scans a codebase and emits an **evidence-traceable documentation set**: a single cohesive 20-section master document, the per-artifact catalogs, a machine-readable evidence layer, and a self-contained themed HTML report.

Every claim is **source-grounded** (a `file:line` citation, not an inference). Claims it cannot ground are **honestly tagged** — `Verified` / `Inferred` / `Unknown` / `Partly-verified` — rather than fabricated. The tool's aim is onboarding documentation for codebases nobody fully understands.

Two things set it apart:

- **Deterministic core.** The accuracy layer is a single command with no LLM involved. Re-runnable, byte-stable, and gate-able.
- **A quarantined AI layer.** Owner-required narrative is filled by the *surrounding* LLM session under a fail-closed quarantine that refuses anything it cannot keep grounded. AppDoc holds **no API key, no provider, and makes no network LLM call** — the LLM is the session running the skill.

## Prerequisites

- **PowerShell 7.2+** (`pwsh`) — required for all scripts (Windows PowerShell 5.1 is not supported). Runs on **Windows and Linux**; CI exercises both.
- **Target codebase path** where the `docs/` output can be written. Work on a **scratch copy** of a real target so you never clobber its committed `docs/`.
- **(Optional)** An AI/LLM session for the enrichment layer. No provider or key is required by AppDoc.

## How it works

AppDoc is a **skill / AI workflow** you invoke from inside an existing AI/LLM session. It runs in two layers:

### Layer 1 — the deterministic core (the gate-able source of truth)

One command, no LLM. It orchestrates the extraction pipeline (framework detection → architecture fingerprint → evidence extractors → the 20-section composer → themed HTML → pristine + conformance gate). This is the default and the accuracy core.

### Layer 2 — the semantic enrichment layer (optional, opt-in)

Fills the owner-required narrative cells (purpose, data flows, ownership) that source parsing alone can't produce, using the **surrounding** LLM session. It runs under a **fail-closed quarantine**:

- **Per-field provenance tags** — every applied field is marked `llm`, `deterministic`, or `open`.
- **A tiered Verified-fact lock** — the LLM may fill only `null` / `Unknown` / low-confidence heuristic fields, and can **never** override a Verified, source-grounded fact (an attempted override is refused and logged).
- **No-fabrication** — fields left un-provided stay `Unknown`.
- **An input-hash cache** — re-runs skip unchanged records.

It is **OFF by default** and no-ops to deterministic-only output when not enabled. The layer's contract is in [`references/enrichment-contract.md`](references/enrichment-contract.md); GitHub Copilot slash-command wrappers (`/appdoc.begin`, `/appdoc.enrich`, `/appdoc.diagrams`) live in `.github/prompts/`.

## Using AppDoc as a skill

AppDoc ships as a harness-agnostic skill: `SKILL.md` is the entry point and `references/` holds the detailed contracts (`enrichment-contract.md`, `enrichment-operations.md`, `config-schema.md`, `verification.md`). Any AI tool that can read `SKILL.md` and run `pwsh` can drive it. GitHub Copilot slash-command wrappers live in `.github/prompts/`.

## Branding and configuration

AppDoc is CMU-first: reports default to the CMU maroon/gold theme and mark. Theme, logo, report header text, redaction patterns and output directory are all configurable per target via `.appdoc/config.json` — see [`references/config-schema.md`](references/config-schema.md). Other organizations set `theme`/`themeFile` and `masthead.logoSvg` (`none` or their own SVG).

## Quick Start

The one-command entry point:

```bash
pwsh ./.appdoc/scripts/powershell/run-appdoc-build.ps1 -Path <repo>
```

That single command produces the complete docs package from a clean output directory. It takes an **optional** `<repo>/.appdoc/config.json` — no config file means default behavior.

To apply the optional enrichment layer, run the same command with `-EnableSemanticEnrich`; the deterministic pipeline then emits a redacted pending-field envelope for the surrounding LLM session to fill, and a re-run applies that output under the quarantine. See `SKILL.md` for the full enrichment protocol.

## Core Scripts

The underlying pieces `run-appdoc-build.ps1` orchestrates (each verified to exist):

| Script | Purpose | Verified flags |
|---|---|---|
| `run-appdoc-build.ps1` | The one-command build (config → generators → composer/pristine/validate → themed HTML → redaction sweep) | `-Path` (required), `-Profile`, `-QualityThreshold` (default `80`), `-SkipDiagrams`, `-SkipSyntaxGate`, `-StrictValidation`, `-EnableSemanticEnrich` |
| `run-all-generators.ps1` | The end-to-end deterministic generation pipeline | `-RootPath` (required), `-Profile`, `-QualityThreshold` (default `80`), `-PristineFloor` (default `80`), `-SkipDiagrams`, `-SkipSyntaxGate`, `-StrictValidation`, `-PristineGate`, `-DryRun` |
| `validate-documentation.ps1` | The authoritative validation gate (composite score + blocking policy checks) | `-RootPath` (required), `-Threshold` (default `80`), `-Strict`, `-Json`, `-PristineGate`, `-PristineFloor` |
| `ci-enrichment-gate.ps1` | Enrichment quality gate (Phase 2.5 checks) | `-RootPath` (default cwd), `-Strict`, `-Json` |
| `appdoc.diagnose.ps1` | Environment / readiness diagnostics | `-RootPath` (required), `-Fix`, `-Json` |
| `generate-html-report.ps1` | Renders the composed docs to a self-contained themed `report.html` | `-RootPath` (required), `-ThemePath` |
| `run-appdoc-enrich.ps1` | Bootstrap + semantic apply + enrichment-gate orchestration | `-RootPath` (required), `-StrictGate`, `-SkipGate`, `-SkipSemanticApply`, `-SkipReRender`, `-DryRun` |

Note: pass/fail is **not** just the score. `validate-documentation.ps1` applies blocking **policy** checks (e.g. `provenance-missing`) that can force a failing status even when the composite score is at or above the threshold. Read the diagnostics, not just the number.

## Framework Support

These framework classes are **proven on real third-party targets with golden-test CI**. Each has a golden regression suite in `tests/powershell/`:

| Framework class | Extraction path | Golden test |
|---|---|---|
| Classic ASP / ASP.NET Web Forms | Regex (classic-ASP extractors) | `test-golden-classic-asp.ps1`, `test-golden-csharp-webforms.ps1` |
| C# ASP.NET Core | **AST-backed** (Roslyn) with a regex fallback | `test-golden-csharp-core-api.ps1` |
| Python Flask | Regex | `test-golden-python-flask.ps1` |
| Node/Express (TypeScript) | Regex | `test-golden-node-express.ps1` |
| Java Spring | Regex | `test-golden-java-spring.ps1` |

C# **ASP.NET MVC 5** is additionally proven on a real convention-routed target (plain `public ActionResult X()` actions routed by convention, no `[Http*]` attributes).

**Honest caveats:**

- **C# / ASP.NET Core is the genuinely AST-backed path** (Roslyn, with a regex fallback provider when `dotnet` is absent). The other classes are **regex-based**.
- **Detection depth is uneven and the coverage matrix is calibrated per framework, not a single percentage.** A detector recognizing a framework is not the same as its extractors producing real records — each class is proven per-framework against its own fixture. The untested long tail (Django, Go, Ruby, Rust, microservice/polyglot) is a low-confidence claim until it earns a fixture + golden.

### Requesting New Framework Support

Open an issue with:

1. Framework name and target version
2. Minimal sample project or repo
3. Expected artifacts (API inventory, data model, config catalog, etc.)
4. Known route/config/model patterns used in your codebase

## Security / secret handling

Per [ADR 0001](docs/adr/0001-redaction-externalize-per-target-secrets.md), AppDoc ships **shape-patterns only** (high-entropy / base64 / named-key / URI-credential). It **never** carries a specific target's live secret *values* in source — a reusable tool does not bake one test target's credentials into its git history.

Generated docs **highlight** that a secret exists (key name + location) but **never document its value** — the value renders as `[REDACTED]` while the key is retained.

Per-target secret values are **operator-supplied**, not hardcoded, through:

- the target's `.appdoc/config.json` `redactionPatterns[]` (what the one-command build consumes), or
- a CLI `-RedactionPatterns` flag on the generator / enrichment scripts (`generate-source-docs.ps1`, `run-appdoc-semantic-enrich.ps1`).

A fail-closed gate (`Test-AppDocSemanticRedactionGate`) blocks the enrichment stage if a real secret value would survive into the LLM-facing input envelope — a secret never reaches the surrounding session.

## Verification

- **`validate-documentation.ps1`** — the authoritative gate: a composite score plus blocking policy checks. A run can score at or above threshold and still fail on a blocking policy issue.
- **Six golden regression suites** — one per framework class (all assertions must pass). They lock each framework's recorded output to its committed baseline and guard against extractor regressions.
- **The semantic-quarantine proof harness** (`tests/powershell/test-semantic-quarantine.ps1`) — a self-contained, fail-closed proof of the redaction + quarantine layer using its own fixture secrets. Run it as a plain script, **not** Pester:

```bash
pwsh -NoProfile -File tests/powershell/test-semantic-quarantine.ps1
```

A **passing gate is a floor, not a ceiling** — it proves the output is non-empty and source-grounded, not that every extractor caught its full surface.

## Output

The build writes to the target's `docs/` (a stable, committed home — see Docs-as-code below). The real artifacts:

- **`application-documentation.md`** — the unified 20-section master document.
- **Per-artifact catalogs** — the `.md` files (`api-inventory.md`, `data-model.md`, `config-catalog.md`, `build-cookbook.md`, `overview.md`, `start-here.md`, `task-guides.md`, `index.md`, plus framework-specific `extcalls.md` / `security.md` / `procdict.md` and `evidence-register.md` / `verification-appendix.md`).
- **`evidence/`** — the machine-readable evidence layer (`*.evidence.json` per artifact, incl. `git-ownership.evidence.json`, plus `semantic/` when enrichment is enabled).
- **`diagrams/`** — Mermaid C4 + flow/lineage diagrams.
- **`report.html`** — the self-contained themed HTML render (CMU maroon/gold default).
- **`validation-report.json`** — the gate verdict + score.
- **`pristine-report.md`** — the per-section source-groundedness (pristine) report.

Every `docs/**/*.md` / `.json` carries a `## Provenance` footer recording the generation run.

## Docs-as-code

Per [ADR 0002](docs/adr/0002-generated-docs-as-code.md), generated documentation is treated as **code**: it lives in a stable, non-wiped `docs/` home, is committed to git, and is kept in sync with the source it describes. The long-term sync mechanism is a **commit hook** that regenerates the documentation on code change and commits the diff. A build creates `docs/` only if absent and overwrites generated artifacts in place — it preserves hand-authored material (ADRs, the glossary, plans) and appends a provenance footer rather than wiping the directory.

## Troubleshooting

- Use **PowerShell 7+** (`pwsh`) for compatibility.
- Ensure all required scripts and modules are present in `.appdoc/scripts/powershell/`.
- Run `pwsh ./.appdoc/scripts/powershell/appdoc.diagnose.ps1 -RootPath <codebase-path> -Fix` to validate environment and script readiness.
- Check file paths for documentation output and review error messages for missing files or permissions.
- If a gate passes but a framework's surface looks thin, read the per-surface coverage metric (e.g. `apiCoverage`) as the real signal — a passing gate is a floor, not a ceiling.

## Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Submit a pull request

The gate is the accuracy device — never lower the quality threshold or weaken a policy gate to make output pass.

## License

MIT — see [LICENSE](LICENSE). Copyright (c) 2026 Tim Niles.

## Support

For support, please open an issue on GitHub.

---
