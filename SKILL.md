---
name: appdoc
description: "Use to generate codebase documentation with AppDoc: run the deterministic single-command build and the quarantined LLM-session enrichment loop."
version: 1.0.0
author: Tim Niles / Hermes Agent
license: MIT
metadata:
  hermes:
    tags: [appdoc, powershell, documentation-generator, skill, llm-enrichment, quarantine, redaction, cmu]
    category: software-development
---

# AppDoc — Documentation Generator Skill

AppDoc is a **local-first, deterministic** PowerShell 7 documentation auto-generator. It scans a
codebase and emits an evidence-traceable `docs/` package (20-section master + per-artifact
catalogs + Mermaid C4 + self-contained themed HTML + pristine/gate reports). Every claim is tagged
`Verified` / `Inferred` / `Unknown` / `Partly-verified`; sections the deterministic layer cannot
source-ground are emitted as honest `Unknown / owner-required` — **the tool never fabricates.**

This skill runs AppDoc in **two layers**:

1. **The deterministic core** (the gate-able source of truth) — one command, no LLM, byte-stable.
2. **The quarantined enrichment loop** — an EXTERNAL LLM SESSION (this skill's caller) fills the
   pending interpretation fields from source; AppDoc's deterministic apply-merge then **validates +
   applies** that output under a quarantine (provenance tagging, a Verified-fact lock, no-fabrication,
   a fail-closed secret-redaction gate). AppDoc holds **NO API key, NO provider, NO HTTP client** —
   the LLM is the session running this skill.

---

## When to use
- The user wants AppDoc to document a codebase (or re-run it after code changed).
- The user wants the optional LLM enrichment applied to the `Unknown` / interpretation fields.
- You are operating the AppDoc repo or a clone and must produce + verify a `docs/` package.

## Environment (this host)
- AppDoc repo: `/persistent/agent/workspace/AppDoc`. PowerShell 7 (`pwsh`); Linux. Verify
  `which pwsh` — if absent, install from the official GitHub-release tarball (it may not survive a
  container rebuild). The pipeline **is runnable** — verify changes by actually running it.
- Real targets write into `<target>/docs/`. **Work on a scratch copy** (`cp -a <target> <scratch>`)
  and point every run at the copy — never clobber a target's committed `docs/`.
- A real target's real credentials are the worst-case redaction test. After any run, grep the output
  for the target's known secret values (masked) — they must be absent.

---

## Layer 1 — The deterministic core (single command)

The ONE entry point. `appdoc build <path>` semantics:

```bash
pwsh -NoProfile -File .appdoc/scripts/powershell/run-appdoc-build.ps1 -Path <target-repo>
```

It is a **thin wrapper that orchestrates** the existing pipeline (does NOT re-implement the
extractors / composer / gate): load `<target>/.appdoc/config.json` → run
`run-all-generators.ps1` (framework detection → architecture fingerprint → evidence extractors incl.
git-ownership → the 20-section composer → themed HTML → pristine → the conformance gate) → themed
HTML re-render → config-driven redaction sweep.

**Produces** (in `<target>/docs/`): the 20-section `application-documentation.md`,
`report.html` (self-contained, CMU maroon/gold default), all `evidence/*.json` (incl.
`git-ownership.evidence.json`), `pristine-report.md`, and `validation-report.json`.

### Parameters
| Param | Default | Meaning |
|---|---|---|
| `-Path <repo>` | *(mandatory, position 0)* | Target repo to document. |
| `-Profile` | `default` | Artifact-set profile. |
| `-QualityThreshold` | `80` | Gate pass threshold (never lower it to force a pass). |
| `-SkipDiagrams` | off | Skip C4/Mermaid diagram generation. |
| `-SkipSyntaxGate` | off | Skip the syntax gate. |
| `-StrictValidation` | off | Strict validation mode. |
| `-EnableSemanticEnrich` | **off** | Enable the Layer-2 enrichment stage (see below). OFF = deterministic-only, byte-identical to today. |

### Config (`.appdoc/config.json`, optional)
`schemaVersion: appdoc-config/v1`. Drives: `theme` (default CMU `#6a0032`/`#ffc82e`, swappable via
`themeFile`), `redactionPatterns[]` (extra secrets to sweep into `[REDACTED]`), `pristineFloor`
(default 80), `minCommitsForOwnership` (default 2), `outputDir` (default `docs`). **No config =
today's behavior** (backward-compatible, byte-identical).

### The deterministic hard bars (must hold on every run)
- **Gate:** `status=pass`, `overallScore` ≥ threshold, pristine sub-score reported (additive,
  non-blocking — it must not change pass/fail).
- **No fabrication:** every section is real content or an honest `Unknown / owner-required`.
- **Redaction 0 leaks (secret VALUES):** the target's real secret *values* (passwords, tokens, keys,
  conn-string credentials) are absent from every `docs/` file. **How to obtain them:** read the
  target's config files (`Web.config` / `App.config` / `appsettings*.json` / `.env` / `*.yml`), extract
  every `User Id` / `Password` / `Pwd` / secret + Data Source host, and grep the built `docs/` for each.
  **Usernames / hosts are NOT a secret class** and may legitimately appear in output — treat a
  username/host leak as a *reported finding* (it usually matches the committed baseline), or add the
  specific value to operator `redactionPatterns` (below) to force it redacted. The fail-closed gate
  blocks the stage only when a real *secret value* (a known-secret or a high-entropy blob) would
  survive into the input.
- **Deterministic (gate-stable):** the **gate result + the 4 gate-scored per-artifact `.md` catalogs**
  are byte-stable across re-runs. Do NOT require full-package byte-identity — the evidence package
  carries volatile per-record `timestamp` / `updatedAt` / `generatedAt` fields, JSON key-ordering, and
  framework-detection set/order variance, so AppDoc's own "determinism hash (excl. timestamp)" may
  differ between runs. Compare the gate result + the 4 gate-scored catalogs, not the whole tree.
- **No literal generator text** in the composed doc (no `$(...)` / `$var` residue).

### Operator redaction overrides (`.appdoc/config.json`, optional)
`redactionPatterns[]` are extra exact values / regexes the pipeline sweeps into `[REDACTED]` beyond the
built-in extractors + the semantic gate. Use them for target-specific secrets the built-in patterns
don't cover (e.g. a service-account username you've decided to treat as secret). A fresh agent cannot
know a target's hardcoded secret list — read the config files (above) to discover them.

---

## Layer 2 — The quarantined enrichment loop (the LLM-session protocol)

This is the skill's core. AppDoc has **already produced the ground truth** (Layer 1). Your job as
the external LLM session is to **enrich the pending interpretation fields** of a redacted evidence
envelope — grounded in the source, never fabricated. AppDoc's deterministic apply-merge then
**validates and applies** your output under a quarantine, so a fabricated or over-reaching field is
**REFUSED, not trusted.**

### The loop (4 steps)
```
1. EMIT  (deterministic)  : single command -EnableSemanticEnrich  ->  docs/evidence/semantic/input/*.semantic.input.json   (REDACTED)
2. ENRICH (YOU, the LLM)   : READ input/ -> WRITE output/*.semantic.output.json   (grounded, null-preserving)
3. APPLY (deterministic)   : single command -EnableSemanticEnrich (re-run)        ->  apply-merge quarantines output/
4. VERIFY (deterministic)  : the hard bars still hold (gate, pristine, redaction 0, no fabrication)
```

**Step 1 — Emit the redacted input.** Run the single command with enrichment ON. AppDoc writes the
redacted pending-field envelope to `<target>/docs/evidence/semantic/input/<artifact>.semantic.input.json`.
Secret **values** are `[REDACTED]` (the fail-closed gate blocks the whole stage if a real secret would
survive into the input — a secret never reaches you). Keys/names are kept.

**Step 2 — Enrich (you are the LLM).** For each input record, read the **real source files**
(the `.cs`/`.config`/`readme` under the target) and fill ONLY the fields you can **ground** in
source. Write the same-stem file to `<target>/docs/evidence/semantic/output/<artifact>.semantic.output.json`.

The **contract** (shape + rules are authoritative in `.github/prompts/appdoc.enrich.prompt.md`):

- **Input** record = `{ source, name, kind, confidence, metadata{…redacted…}, expectedFields[16] }`.
  **Join key = `source|name|kind` (lowercase).**
- **Output** = `{ artifact, generatedAt, records[] }`; `records` is **always a JSON array**; each
  record = its **join key verbatim** + ONLY the fields you supply (any of the 16).
- **The 16 fields:** `confidenceNote, role, businessPurpose, isGenerated, tier, dependencyKind,
  criticalPath, upgradeUrgency, requiredForDeployment, schemaSource, integrationTargets,
  relationships, operationalProfile, projectRole, usageFrequency, testDiagnosis`.
- **Rules (non-negotiable):**
  - Leave a field **null / omit it when evidence is insufficient — NEVER fabricate.**
  - Do **NOT** set `schemaSource` (it is a Verified deterministic fact — any override is refused + logged).
  - Heuristic-derived fields (name-based `role`/`tier`) may be refined; source-grounded facts must not be.
  - Secret values stay `[REDACTED]`; config keys/names are fine.
  - Copy the `source`/`name` **verbatim** from the input (the join depends on it).

**Scoping a large pending set (real targets have thousands of pending fields).** Do not blindly grind
the whole set — ground a *substantial bounded* set with every field source-backed or `null`: prioritize
(1) core domain entities (`Models/` / primary classes), (2) the primary connection strings / credentials
/ auth-critical config keys, (3) auth-critical + high-impact endpoints. Ground `role` /
`businessPurpose` / `criticalPath` / `isGenerated` / `integrationTargets` on those; leave low-signal
records un-emitted (they stay `open`, which is honest). Deliberately include some long-path records —
they join cleanly and are the ones the redaction precision keeps safe.

**Positive "did it apply?" check (not just the refusal log).** `quarantine-refusals.json` catches
over-reach (a Verified fact you tried to override), but it does **not** catch a silent drop from a
join-key mismatch (a mistyped `source` / `name` / `kind` that simply never matches). To confirm your
enrichment actually APPLIED, open `docs/evidence/semantic/applied/<artifact>.semantic.applied.json` and
confirm the fields you set carry `provenance=llm` (not `open`). A record you enriched that shows `open`
for your fields was dropped — re-check the join key against the input verbatim.

**Step 3 — Apply (quarantine).** Re-run the single command with `-EnableSemanticEnrich`. AppDoc's
deterministic apply-merge reads `output/` and applies it under the quarantine (Step 4 properties).

**Step 4 — Verify.** Confirm the hard bars still hold (below). If a record you enriched did **not**
apply, check `docs/evidence/semantic/quarantine-refusals.json` for a refusal (you over-reached a
Verified fact) and `semantic-pending.json` for the still-pending fields. Also run the positive
applied-vs-dropped check (above): confirm your fields show `provenance=llm` in `applied/`.

**Score caveat:** enrichment ON may move `overallScore` by a point or two (e.g. 92 → 91) — the
`-SkipReRender` default keeps the 4 gate-scored `.md` catalogs identical, but the full pipeline re-run
(narrative / diagram / validation) can shift the composite. The stable invariants are `status=pass` +
the **pristine sub-score**, NOT `overallScore`. Do not treat a 1-point `overallScore` movement as a
failure.

**Surfacing enrichment in the gate-scored `.md` (opt-in re-render):** the single command defaults to
`-SkipReRender` (the deterministic `.md` core stays byte-identical), so enrichment lands only in
`semantic/applied/` + the enriched evidence. To project the enriched fields (config / data-model
`businessPurpose`, the api-inventory `Business Purpose` column) into the gate-scored `.md`, re-run the
opt-in re-renderers on the scratch copy: `generate-config-catalog.ps1`, `generate-data-model.ps1`,
`generate-api-inventory.ps1` (each `-RootPath <scratch>`), then `generate-unified-master.ps1 -RootPath
<scratch>`, then `validate-documentation.ps1 -RootPath <scratch> -Threshold 80 -Json`.

### What the quarantine guarantees (do not rely on it trusting your output)
- **Provenance tag** per applied field: `llm` (you supplied it) / `deterministic` (a Verified
  source-grounded fact) / `open` (un-provided, stays Unknown).
- **Verified-fact lock (tiered merge):** you may fill **only** null / `open` / low-confidence
  heuristic fields. A Verified deterministic fact is **immutable** — an attempted override is
  **refused + logged** and the Verified value is kept. (LLM wins over heuristic, NEVER over Verified.)
- **No-fabrication:** a field you left null stays `open`/null — never invented.
- **Fail-closed redaction:** the input you received contains 0 real secrets; if a secret would
  survive into the input, the stage is **blocked** (it does not proceed silently).
- **Input-hash cache:** re-runs skip unchanged records (deterministic + cost-safe).

---

## Verification (run before reporting done)
- **The deterministic hard bars** (Layer 1, above) — gate pass, pristine, redaction 0 (secret values),
  gate-stable determinism. (A `build_cicd_count_mismatch` integrity warning is **benign / non-fatal** —
  it does not fail the gate; do not treat it as an error.)
- **The quarantine harness** (proves the safety layer, mock LLM — no real call needed):
  ```bash
  pwsh -NoProfile -File tests/powershell/test-semantic-quarantine.ps1
  ```
  Run it as a **plain script** (`pwsh -File`), NOT `Invoke-Pester` — it is a standalone proof harness,
  not `It/Should` blocks. All proofs must pass (redaction 0 in input, fail-closed block, provenance
  tagging, Verified-fact refusal, no-fabrication, input-hash cache HIT/MISS, opt-in no-op).
- **Golden regression** (the pipeline is unchanged): `Invoke-Pester` over the 6
  `tests/powershell/test-golden-*.ps1` — must stay 122/122.
- **On a real target:** grep the final `docs/` (and `semantic/input|output|applied/`) for the
  target's known secret values — must be 0. Confirm a deliberate `schemaSource` override is refused
  in `quarantine-refusals.json` and an un-grounded field stays `open`.

---

## Hard constraints
- **Never fabricate.** Every enrichment field you set must be groundable in a real source file you
  read; when you can't ground it, leave it null.
- **Never override a Verified deterministic fact** (e.g. `schemaSource`, real config values, real
  endpoint paths). If you think one is wrong, report it — do not override it.
- **Never weaken redaction or the gate** to make output pass (no lowering the threshold, no
  loosening the fail-closed redaction). The gate is the accuracy device.
- **Never clobber a target's committed `docs/`** — work on a scratch copy.
- **Do not modify the deterministic core** (extractors / composer / gate / quarantine) to make
  enrichment "work" — report a real bug instead; the quarantine and redaction are the safety net.
- **No network LLM call, no API key, no provider** — the LLM is the session running this skill;
  AppDoc only emits redacted input and deterministically applies the external session's output.
