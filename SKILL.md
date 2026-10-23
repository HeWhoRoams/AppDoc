---
name: appdoc
description: "Generate evidence-traceable codebase documentation with AppDoc: a deterministic PowerShell 7 build plus an optional, quarantined LLM-session enrichment loop. Use when asked to document, re-document, or enrich documentation for a codebase."
license: MIT
version: 1.0.0
compatibility: "Requires PowerShell 7.2+ (pwsh). Optional .NET SDK 8 for the Roslyn C# AST parser (regex fallback when absent). Works with any agent that can read this file and run pwsh."
---

# AppDoc — Documentation Generator Skill

AppDoc is a **local-first, deterministic** PowerShell 7 documentation generator. It scans a codebase and emits an evidence-traceable `docs/` package: a 20-section master document, per-artifact catalogs, Mermaid C4 diagrams, a self-contained themed HTML report, and pristine/gate reports. Every claim is tagged `Verified` / `Inferred` / `Unknown` / `Partly-verified`. Sections the deterministic layer cannot source-ground are emitted as honest `Unknown / owner-required` — **the tool never fabricates.**

It runs in two layers:

1. **Deterministic core** (the gate-able source of truth) — one command, no LLM.
2. **Quarantined enrichment loop** (optional) — the *LLM session running this skill* fills pending interpretation fields from source. AppDoc's deterministic apply-merge validates and applies that output under a quarantine (provenance tags, a Verified-fact lock, no-fabrication, a fail-closed secret-redaction gate). AppDoc holds **no API key, no provider, no HTTP client.**

## When to use

- The user wants a codebase documented, or re-documented after changes.
- The user wants the optional LLM enrichment applied to `Unknown` / interpretation fields.
- You are operating a clone of this repo and must build and verify a `docs/` package.

## Prerequisites and setup

1. **Skill root.** `SKILL_ROOT` is the directory that contains this `SKILL.md`. All commands below are relative to it.
2. **PowerShell 7.2+.** Check `pwsh --version`. If missing, install from <https://github.com/PowerShell/PowerShell/releases> (Windows, Linux, macOS). Do not use Windows PowerShell 5.1.
3. **Optional:** .NET SDK 8 enables the Roslyn AST path for C#; without it AppDoc falls back to regex extraction.
4. **Work on a scratch copy.** Real targets write into `<target>/docs/`. Copy the target (`cp -a` / `Copy-Item -Recurse`) and point every run at the copy so a target's committed `docs/` is never clobbered.

## Layer 1 — deterministic build (one command)

```bash
pwsh -NoProfile -File "$SKILL_ROOT/.appdoc/scripts/powershell/run-appdoc-build.ps1" -Path <target-repo>
```

It orchestrates the pipeline (framework detection → architecture fingerprint → evidence extractors incl. git ownership → 20-section composer → themed HTML → pristine → conformance gate → config-driven redaction sweep). It writes `application-documentation.md`, `report.html`, `evidence/*.json`, `pristine-report.md` and `validation-report.json` into `<target>/docs/`.

| Parameter | Default | Meaning |
|---|---|---|
| `-Path <repo>` | required | Target repository to document. |
| `-Profile` | `default` | Artifact-set profile. |
| `-QualityThreshold` | `80` | Gate pass threshold. Never lower it to force a pass. |
| `-SkipDiagrams` | off | Skip C4/Mermaid diagram generation. |
| `-SkipSyntaxGate` | off | Skip the syntax gate. |
| `-StrictValidation` | off | Strict validation mode. |
| `-EnableSemanticEnrich` | **off** | Enable the Layer-2 enrichment stage. Off = deterministic-only. |
| `-AllowGateFail` | off | Exit 0 even when the gate fails (exploratory runs only; never in CI). |

**Exit codes:** `0` gate passed · `2` gate failed (docs written but not trustworthy) · `3` fail-closed stop (redaction sweep or semantic secret-redaction gate) · `1` tool error. Treat any non-zero code as "not done". See `docs/adr/0003-sub-validator-failure-policy.md`.

Optional per-target configuration (`<target>/.appdoc/config.json`: theme and branding, extra redaction patterns, pristine floor, output directory) is documented in `references/config-schema.md`. No config means defaults.

### Hard bars that must hold on every run

- **Gate:** `status=pass` and `overallScore` ≥ threshold; the pristine sub-score is reported (non-blocking).
- **No fabrication:** every section is real content or an honest `Unknown / owner-required`.
- **Redaction — 0 leaks of secret values.** Discover the target's real secrets from its config files and grep the built `docs/` for each; none may appear.
- **Deterministic:** the gate result and the 4 gate-scored `.md` catalogs are stable across re-runs.
- **No literal generator text** (`$(...)` / `$var` residue) in the composed doc.

Details, test suites and how to verify on a real target: `references/verification.md`.

## Layer 2 — quarantined enrichment loop (LLM-session protocol)

AppDoc has already produced the ground truth. You, the LLM session, enrich the pending interpretation fields of a **redacted** evidence envelope, grounded in source. A fabricated or over-reaching field is **refused, not trusted.**

```
1. EMIT   (deterministic)  build with -EnableSemanticEnrich   -> docs/evidence/semantic/input/*.semantic.input.json   (redacted)
2. ENRICH (you)            read input/ + the real source      -> write docs/evidence/semantic/output/*.semantic.output.json
3. APPLY  (deterministic)  re-run with -EnableSemanticEnrich  -> quarantined apply-merge
4. VERIFY (deterministic)  hard bars still hold; confirm your fields show provenance=llm in semantic/applied/
```

- **The contract** (input/output shape, the 16 fields, the join key `source|name|kind`, quarantine rules, an example) is in `references/enrichment-contract.md`. Read it before step 2.
- **Rules:** leave a field `null`/omitted when evidence is insufficient; never set `schemaSource`; copy `source`/`name`/`kind` verbatim; secrets stay `[REDACTED]`.
- Scoping a large pending set, checking that enrichment actually applied (silent join-key drops), the opt-in re-render of gate-scored catalogs, and what the quarantine guarantees: `references/enrichment-operations.md`.
- A 1-point `overallScore` movement with enrichment ON is expected; the stable invariants are `status=pass` and the pristine sub-score.

## Hard constraints

- **Never fabricate.** Every enrichment field must be groundable in a real source file you read; otherwise leave it null.
- **Never override a Verified deterministic fact** (`schemaSource`, real config values, real endpoint paths). If one looks wrong, report it.
- **Never weaken redaction or the gate** to make output pass (no lowering the threshold, no loosening the fail-closed redaction).
- **Never clobber a target's committed `docs/`** — use a scratch copy.
- **Do not modify the deterministic core** (extractors, composer, gate, quarantine) to make enrichment "work"; report a real bug instead.
- **No network LLM call, no API key, no provider** — you are the LLM; AppDoc only emits redacted input and applies your output.

## Harness adapters

This skill is harness-agnostic. Thin wrappers may exist for specific tools — for example `.github/prompts/appdoc.*.prompt.md` for GitHub Copilot slash commands — and must only point back to this file and `references/`.
