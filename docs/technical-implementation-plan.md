# AppDoc Documentation Production Plan (v3)

**Version:** 3.0.0  
**Date:** 2026-03-04  
**Status:** Execution Ready (Outcome-Focused)

**Execution Checklist:** `docs/implementation-checklist-v3.md`

## 1. Goal

Generate documentation that is accurate, readable, and actionable on first read, while remaining deterministic and reproducible across mixed legacy codebases.

## 2. Product Principles (No-Bloat Rules)

1. Every generated section must answer a reader question.
2. No large table appears without a concise summary above it.
3. Accuracy is ranked above completeness; inferred content must be labeled.
4. Cross-artifact metrics must match one canonical source.
5. A report cannot score "high quality" when contradictions or duplicates exist.
6. Any content not used by operator/developer/architect paths is removed.

## 3. Definition of “Award-Winning” Output

Documentation is considered excellent only when all criteria below are true:

- **Trustworthy:** no architecture contradiction, no metric drift, no stale provenance.
- **Useful in 5 minutes:** new engineer can run first commands from `start-here.md` without opening other files.
- **Decision-ready:** each major artifact has summary + why-it-matters + next action.
- **Scannable:** top sections are concise; detail is moved to appendices/evidence.
- **Traceable:** every non-trivial claim has evidence reference and confidence labeling.

## 4. Output Contract by Artifact

### 4.1 `overview.md`
- Required sections: System Boundary, Runtime Path, Inputs→Processing→Outputs, External Systems, Confidence Notes.
- Must contain one explicit architecture statement aligned with `architecture-fingerprint.json`.
- Must not contain unresolved contradiction language.

### 4.2 `index.md` + `start-here.md`
- `index.md` must expose exactly three reader paths: Operate, Change Code, Architecture.
- Each link includes: when to read, what you learn, estimated read time.
- `start-here.md` must include: first 30 minutes, first 3 files, expected outputs.

### 4.3 Catalogs (`api-inventory.md`, `data-model.md`, `config-catalog.md`, `test-catalog.md`, `dependencies-catalog.md`, `build-cookbook.md`, `task-guides.md`, `debt-register.md`)
- Each catalog starts with a concise executive summary.
- Reader-first views (top risks, top entities, top actions) appear before full raw tables.
- Large raw details are moved to appendices/evidence with links.
- Duplicate rows are suppressed and counted as validator penalty if present.

### 4.4 Diagrams (`docs/diagrams/*.md`)
- Two-layer model required:
  - **L1:** concise reader view.
  - **L2:** integration/detail view.
- Reader-facing labels must be human names (no hash/noise ids).
- Diagram index explains when to use each diagram.

### 4.5 Machine reports (`diagnostics-report.json`, `quality-report.json`, `validation-report.json`, etc.)
- Each critical JSON report has a companion markdown summary:
  - what changed,
  - why it matters,
  - what to do next,
  - trust-but-verify notes.

## 5. Accuracy and Consistency Controls (Addresses Current Failures)

### 5.1 Architecture correctness
- Update fingerprint weighting to prioritize SOAP/WCF contract/host evidence above generic REST hints.
- Add contradiction check across fingerprint, API inventory, and framework detection.
- Fail validation on contradiction.

### 5.2 Canonical metrics
- Create `docs/evidence/metrics-canonical.json`.
- Endpoint/model/test/dependency totals must be read from this file by generators and validators.
- Hard-fail on drift across root artifacts.

### 5.3 Quality scoring realism
- Penalize: contradiction, duplicate rows, misclassification, stale provenance, verbosity overflow.
- Add explicit “pass with weak coverage” state.
- Require per-artifact penalty breakdown in `quality-report.json`.

## 6. Readability Budgets (Hard Limits)

- Top summary section in each markdown artifact: target 8–15 lines.
- Any table > 25 rows must be preceded by a “What matters most” summary.
- Any page > 350 lines must include section-level quick links.
- Repeated hedge phrases (e.g., "appears to") are reduced and replaced with confidence labels.

## 7. Provenance and Reproducibility

Every markdown and JSON artifact must include or link provenance metadata:
- generator version,
- git commit hash,
- generated timestamp,
- profile/scope,
- confidence/inference flags where applicable.

Validation fails if provenance is missing.

## 8. Execution Plan (Minimal, High Impact)

### Phase A — Trust First (P0)
1. Architecture contradiction controls.
2. Canonical metrics and drift hard-fail.
3. Quality scoring penalties and weak-coverage mode.

### Phase B — Reader Value (P1)
1. Index/start-here operator and developer flows.
2. Overview rewrite to narrative contract.
3. Catalog curation + appendix split.
4. Diagram L1/L2 restructuring.

### Phase C — Maturity (P2)
1. Universal provenance enforcement.
2. JSON companion summaries.
3. Evidence schema enrichment and markdown checksums in manifest.

## 9. Verification Matrix

Run full workflow and validation after each phase for:
- `C:\Github\DegreeAudit`
- `C:\Github\CMich.CoreApi-master`
- `C:\Github\LmsConnect-master`

Required outcomes per phase:
- No architecture contradiction warnings.
- No `cross-artifact-metric-drift` findings.
- Quality score decreases when contradiction fixtures are injected.
- New developer path in `start-here.md` executes without out-of-band knowledge.

## 10. Exit Gates

### Gate A (Trust)
- Accuracy controls active; contradiction and drift fail fast.

### Gate B (Usability)
- Human-first summaries present and useful in all root artifacts.
- Diagrams are understandable from L1 without evidence JSON.

### Gate C (Operational Quality)
- Provenance universal.
- Companion summaries complete.
- Reproducible outputs across all matrix repos.

## 11. Final Done Criteria

1. Workflow passes for all three target repositories.
2. Validators show no contradiction, drift, or duplication failures.
3. Reader-path tasks are executable and deterministic.
4. Documentation is concise at top-level, detailed by drill-down, and fully traceable to evidence.

## Provenance

- Generator Version: appdoc-run-all-generators/3.0.0
- Commit Hash: eed63d1
- Generated At: 2026-03-11T14:45:38-04:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
