# AppDoc enrichment loop — operating notes

Details for the quarantined LLM-session enrichment loop summarized in `SKILL.md`. The field-level contract the LLM must follow is in `enrichment-contract.md`.

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
- **Input-hash cache:** re-runs skip unchanged records (deterministic + cost-safe). Editing an output file and re-running re-applies it (`cacheState = superseded`); the cache never hides a corrected output.
