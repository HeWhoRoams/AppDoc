# AppDoc v3 Implementation Checklist

**Version:** 3.0.0  
**Date:** 2026-03-04  
**Source Plan:** `docs/technical-implementation-plan.md`

## How to Use This Checklist

- Complete tasks in phase order: A → B → C.
- Treat each checkbox as a pull-request-ready unit (code + tests/validation + artifact proof).
- Do not mark a task complete without running its validation commands and recording outputs.
- If a task touches scoring or schema, update both generator and validator paths in the same PR.

---

## Phase A — Trust First (P0)

### A1. Architecture contradiction controls

- [x] **A1.1 Update architecture weighting logic**
  - **Primary code:** `.appdoc/scripts/powershell/modules/AppDoc.Overview.TruthPack.psm1`
  - **Also review:** `.appdoc/scripts/powershell/generate-overview.ps1`, `docs/architecture-fingerprint.json` producer path
  - **Implementation:**
    - Increase weight for SOAP/WCF host + contract evidence.
    - Decrease confidence for architecture style selected from weak REST-only hints.
    - Emit explicit style label (`WCF-first` / `SOAP-first`) when dominant.
  - **Output impact:** `docs/architecture-fingerprint.json`, `docs/overview.md`

- [x] **A1.2 Add architecture contradiction validator**
  - **Primary code:** `.appdoc/scripts/powershell/validate-documentation.ps1`
  - **Inputs to compare:** `docs/architecture-fingerprint.json`, `docs/api-inventory.md`, `docs/framework-detection.json`, `docs/overview.md`
  - **Implementation:**
    - Add contradiction checks and issue key: `architecture-contradiction`.
    - Hard-penalize quality score and report reason in `quality-report.json`.
  - **Output impact:** `docs/validation-report.json`, `docs/quality-report.json`

- [x] **A1.3 Add fixture-based contradiction test**
  - **Primary code:** `tests/powershell/` (new or existing validator tests)
  - **Implementation:**
    - Create fixture where architecture sources intentionally disagree.
    - Assert contradiction issue is emitted and quality score drops.

### A2. Canonical metrics and drift hard-fail

- [x] **A2.1 Create canonical metrics artifact**
  - **Primary code:** `.appdoc/scripts/powershell/run-all-generators.ps1`
  - **Add output:** `docs/evidence/metrics-canonical.json`
  - **Implementation:**
    - Standardize endpoint/model/test/dependency counts in one artifact.
    - Write deterministic schema and ordering.

- [x] **A2.2 Refactor generators to consume canonical totals**
  - **Primary code:**
    - `.appdoc/scripts/powershell/generate-overview.ps1`
    - `.appdoc/scripts/powershell/generate-api-inventory.ps1`
    - `.appdoc/scripts/powershell/validate-test-catalog.ps1`
    - `.appdoc/scripts/powershell/validate-dependencies-catalog.ps1`
  - **Implementation:**
    - Replace ad-hoc recounts where applicable.
    - Preserve per-artifact detail while aligning headline totals to canonical source.

- [x] **A2.3 Add metric drift hard-fail**
  - **Primary code:** `.appdoc/scripts/powershell/validate-documentation.ps1`
  - **Implementation:**
    - Compare root artifact metrics against `metrics-canonical.json`.
    - Emit issue key `cross-artifact-metric-drift` and fail threshold when present.

### A3. Quality model realism

- [x] **A3.1 Add penalty model with breakdown**
  - **Primary code:** `.appdoc/scripts/powershell/validate-documentation.ps1`
  - **Implementation:**
    - Penalize: contradiction, duplicate rows, misclassification, stale provenance, verbosity overflow.
    - Emit per-artifact penalty details into `docs/quality-report.json`.

- [x] **A3.2 Add “pass with weak coverage” state**
  - **Primary code:** `.appdoc/scripts/powershell/validate-documentation.ps1`
  - **Implementation:**
    - Introduce status threshold where report passes but flags insufficient coverage.
    - Ensure state is explicit in `validation-report.json` and `quality-report.json`.

---

## Phase B — Reader Value by Default (P1)

### B1. Onboarding paths (`index.md`, `start-here.md`)

- [x] **B1.1 Implement 3-path index contract**
  - **Primary code:** index generator path in `.appdoc/scripts/powershell/run-all-generators.ps1` pipeline
  - **Outputs:** `docs/index.md`
  - **Implementation:** Operate / Change Code / Architecture paths with “When to read”, “What you’ll learn”, read-time.

- [x] **B1.2 Implement executable first-30-min flow**
  - **Primary code:** start-here generator path (existing script in pipeline)
  - **Outputs:** `docs/start-here.md`
  - **Implementation:**
    - First 30 minutes commands + expected outputs.
    - First 3 files quick-start.
    - Role-specific outcomes.

### B2. Overview narrative quality

- [x] **B2.1 Enforce section contract in overview generation**
  - **Primary code:** `.appdoc/scripts/powershell/generate-overview.ps1`
  - **Validator:** `.appdoc/scripts/powershell/validate-overview.ps1`
  - **Required sections:** System boundary, runtime path, inputs→processing→outputs, external systems, confidence notes.

- [x] **B2.2 Reduce hedge language, keep confidence tags**
  - **Primary code:** `.appdoc/scripts/powershell/generate-overview.ps1`
  - **Implementation:**
    - Replace repetitive hedges with one confidence statement per subsection.
    - Preserve explicit inferred labeling.

### B3. Catalog curation and de-noise

- [ ] **B3.1 API inventory: summary + appendix split**
  - **Primary code:** `.appdoc/scripts/powershell/generate-api-inventory.ps1`
  - **Validation:** `.appdoc/scripts/powershell/validate-documentation.ps1`
  - **Implementation:**
    - Keep concise summary in `docs/api-inventory.md`.
    - Move full endpoint table(s) to appendix file(s) linked from summary.
    - Include operation intent/auth boundary/timeout-retry-idempotency-confidence fields.

- [ ] **B3.2 Data model: domain-first view**
  - **Primary code:** data-model generator path
  - **Output:** `docs/data-model.md`
  - **Implementation:** separate domain entities from infrastructure/generated proxies; show high-impact shortlist first.

- [ ] **B3.3 Config catalog: runtime/tooling split and masking**
  - **Primary code:** config-catalog generator path
  - **Output:** `docs/config-catalog.md`
  - **Implementation:** runtime-first + where-used + environment requirement + masking policy.

- [ ] **B3.4 Test/dependency/debt catalog de-duplication and prioritization**
  - **Primary code:**
    - `.appdoc/scripts/powershell/validate-test-catalog.ps1`
    - `.appdoc/scripts/powershell/validate-dependencies-catalog.ps1`
    - debt-register generator/validator path
  - **Implementation:**
    - suppress duplicate cases/rows,
    - classify critical-path dependencies,
    - separate first-party vs vendor/generated debt with risk metadata.

### B4. Diagram usability (L1/L2)

- [ ] **B4.1 Implement L1/L2 diagram layering**
  - **Primary code:** `.appdoc/scripts/powershell/generate-mermaid-architecture-suite.ps1`
  - **Modules:**
    - `.appdoc/scripts/powershell/modules/AppDoc.Diagrams.Renderer.psm1`
    - `.appdoc/scripts/powershell/modules/AppDoc.Diagrams.Normalizer.psm1`
  - **Output:** `docs/diagrams/*.md`

- [ ] **B4.2 Enforce readable labels and coverage checks**
  - **Primary code:** `.appdoc/scripts/powershell/validate-diagrams.ps1`
  - **Implementation:**
    - no hash/noise labels in reader-facing nodes,
    - enforce coverage snapshot expectations,
    - diagram index includes “when to use”.

---

## Phase C — Maturity and Reproducibility (P2)

### C1. Universal provenance

- [ ] **C1.1 Add provenance block to all root markdown and JSON outputs**
  - **Primary code:** `.appdoc/scripts/powershell/run-all-generators.ps1` orchestration + artifact writers
  - **Required fields:** generator version, commit hash, timestamp, scope/profile, confidence/inference flags where applicable.

- [ ] **C1.2 Fail validation if provenance missing**
  - **Primary code:** `.appdoc/scripts/powershell/validate-documentation.ps1`

### C2. Companion summaries for machine JSON artifacts

- [ ] **C2.1 Generate companion markdown files**
  - **Primary code:** reporting/narrative generation path
  - **Targets:**
    - `diagram-truth-pack.json`
    - `evidence-graph.json`
    - `manifest.json`
    - `narrative-context-pack.json`
    - `narrative-run-report.json`
    - `overview-truth-pack.json`
    - `diagnostics-report.json`
    - `quality-report.json`
    - `validation-report.json`
  - **Template:** what changed, why it matters, what to do next, trust-but-verify.

### C3. Evidence schema enrichment

- [ ] **C3.1 Add enrichment fields and manifest markdown checksums**
  - **Primary code:** `.appdoc/scripts/powershell/modules/AppDoc.EvidenceGraph.psm1` + manifest writer path
  - **Implementation:** inference flags, dedupe metadata, ownership/runtime relevance/sensitivity tags, signoff metadata.

- [ ] **C3.2 Enforce schema in validators/tests**
  - **Primary code:** `.appdoc/scripts/powershell/validate-documentation.ps1`, `tests/powershell/*`

---

## Validation Command Checklist (Run at End of Each Phase)

- [ ] Run generation workflow:
  - `pwsh -File .appdoc/scripts/powershell/run-all-generators.ps1`
- [ ] Run documentation validation:
  - `pwsh -File .appdoc/scripts/powershell/validate-documentation.ps1`
- [ ] Run diagram validation:
  - `pwsh -File .appdoc/scripts/powershell/validate-diagrams.ps1`
- [ ] Run PowerShell tests:
  - `pwsh -Command "Invoke-Pester tests/powershell"`

---

## Matrix Verification (Required)

- [ ] `C:\Github\DegreeAudit`
- [ ] `C:\Github\CMich.CoreApi-master`
- [ ] `C:\Github\LmsConnect-master`

For each repo, capture:
- [ ] `validation-report.json` summary
- [ ] `quality-report.json` penalty breakdown
- [ ] contradiction/drift/duplication issue counts
- [ ] onboarding path execution evidence

---

## Release Readiness Checklist

- [ ] No architecture contradiction findings.
- [ ] No cross-artifact metric drift findings.
- [ ] No duplicate-row findings in curated catalogs.
- [ ] Provenance present in all required artifacts.
- [ ] Companion summaries generated and linked.
- [ ] Quality model reflects penalties (no artificial 100% when defects exist).
- [ ] New engineer can follow `start-here.md` without external tribal knowledge.

## Provenance

- Generator Version: appdoc-run-all-generators/3.0.0
- Commit Hash: 1a97947
- Generated At: 2026-03-04T15:09:09-05:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
