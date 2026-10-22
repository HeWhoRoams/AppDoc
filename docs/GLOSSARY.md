# AppDoc Glossary

Working definitions for the AppDoc documentation-generation pipeline. For decisions and their
rationale, see `docs/adr/`.

## The artifact

- **20-section documentation set** — The complete, source-grounded output for a target: a single
  `application-documentation.md` (the unified 20-section master) plus supporting artifacts
  (`architecture-fingerprint.json`, `config-catalog.md`, `data-model.md`, `external-calls.md`,
  `extcalls.md`, `api-inventory.md`, `validation-report.json`, HTML renders, and the per-section
  source-docs). "Pristine" means every section carries real, source-grounded content or an honest
  `Unknown` — no thin placeholder where parseable content exists.

## Core concepts

- **Source grounding** — Every claim in the docs traces to an actual source file/symbol, not to
  inference. A cell with no parseable source evidence is an honest `Unknown`, never a guess.
- **Framework fingerprint** — The detected language/framework class (classic ASP, C# WebForms, C#
  ASP.NET Core, Java Spring, Node/Express, Python/Flask, …) that selects the right extractors.
- **Deterministic path** — The generator side: extractors parse source and emit artifacts with no
  LLM involvement. Re-runnable and stable.
- **Enrichment path (semantic enrichment)** — The LLM-assisted side: fills owner-required semantic
  cells (purpose, data flows, ownership narrative) that source parsing alone can't produce. Runs in
  the *surrounding* AI session — AppDoc carries no model, no key, no network call.
- **Operator channel** — The per-target seam through which an operator supplies run-specific inputs
  (notably `redactionPatterns`) — via the CLI `-RedactionPatterns` param or the target's
  `.appdoc/config.json`. This is how per-target secrets are supplied without the tool shipping them.

## Redaction (secret handling)

- **Shape pattern** — Redaction by value *shape*: high-entropy / base64 / long-token / named-key /
  URI-credential (`user:pass@`). The tool ships only shape patterns, never specific secret values.
- **URI-credential pattern** — Single-source array (shared by the semantic and config-catalog
  modules) that redacts `user:pass@` inside connection strings / URIs, value-scoped.
- **Named-key pattern** — A credential-shaped key (`password`, `secret`, `token`, `api_key`, …)
  causes its value to render `[REDACTED]` while the key name is retained, so the doc *highlights*
  "a secret here" without documenting the value.
- **Known-secrets list** — The (now empty) built-in backstop of literal secret values. Per ADR 0001
  it is operator-supplied per target, not hardcoded in the tool.
- **Fail-closed gate** — `Test-AppDocSemanticRedactionGate`: if a known secret survives into the LLM
  input envelope, the enrichment stage *blocks* rather than proceeding.
- **`[REDACTED]`** — The placeholder a masked secret value renders as.
- **Over-redaction** — Masking a legitimate value (a source path, a config key) that should have
  been preserved; the invariant is that legit keys/paths stay joinable.

## Verification

- **Gate / validation report** — `validation-report.json`: the pass/fail verdict + overall score
  for a target's docs (e.g. `pass / 94`).
- **Pristine score** — The sub-score measuring source-groundedness across the 20 sections.
- **Golden tests** — Pester suites that lock the *recorded* output of each framework class to its
  committed baseline (132 assertions across 6 classes). They guard against extractor regressions.
- **Quarantine harness (18-proof)** — A self-contained fail-closed redaction test that uses its *own*
  fixture secrets via the operator channel; independent of any hardcoded list.
- **Committed baselines** — The recorded gate scores for the two committed test targets
  (89 and 97) used as regression references.
- **Provenance footer** — `Set-AppDocRootProvenance`: a `## Provenance` block stamped onto every
  `docs/**/*.md`/`.json` recording the generation run (tool version, target, timestamp).

## Process

- **Docs-as-code** — Generated documentation is versioned and committed like code, with a
  commit-hook regeneration to keep it in sync (ADR 0002).
- **Operator vs. tool boundary** — The tool is reusable and generic; a *target* is an application
  the tool is run against. Target-specific data (its secrets, its config values) belongs to the
  operator/target, never to the tool's source.
