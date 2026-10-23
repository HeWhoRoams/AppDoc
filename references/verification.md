# AppDoc verification reference

Run these before reporting a build or enrichment run as done.

## The deterministic hard bars (must hold on every run)
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

## Test suites and on-target checks
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
  `tests/powershell/test-golden-*.ps1` — all assertions must pass (the suites are the source of truth for the count; do not hardcode it).
- **On a real target:** grep the final `docs/` (and `semantic/input|output|applied/`) for the
  target's known secret values — must be 0. Confirm a deliberate `schemaSource` override is refused
  in `quarantine-refusals.json` and an un-grounded field stays `open`.
