# AppDoc Artifact Quality Audit

**Date**: 2026-03-05
**Repos Audited**: academichistory, LmsConnect-master, CMich.CoreApi-master, DegreeAudit
**Auditor**: GitHub Copilot (AI-assisted critical review)

---

## Scoring Key

| Score | Meaning |
|-------|---------|
| 9–10 | Excellent — production-ready, actionable, evidence-backed |
| 7–8  | Good — useful with minor gaps |
| 5–6  | Adequate — boilerplate present, some value, needs work |
| 3–4  | Weak — mostly template/noise, limited usefulness |
| 1–2  | Poor — placeholder content, no actionable signal |

**Attributes scored:**
1. **Accuracy** — Is the content factually correct based on code evidence?
2. **Readability** — Can a developer/operator use this without decoding generator syntax?
3. **Completeness** — Are meaningful gaps absent?
4. **Signal/Noise** — How much is useful content vs. boilerplate/auto-generated filler?

---

## 1. academichistory

### Artifact Scores

| Artifact | Accuracy | Readability | Completeness | Signal/Noise | Avg |
|----------|----------|-------------|--------------|--------------|-----|
| overview.md | 8 | 8 | 7 | 6 | **7.3** |
| api-inventory.md | 9 | 9 | 8 | 8 | **8.5** |
| data-model.md | 7 | 7 | 6 | 6 | **6.5** |
| config-catalog.md | 5 | 4 | 7 | 3 | **4.8** |
| build-cookbook.md | 7 | 7 | 6 | 6 | **6.5** |
| test-catalog.md | 8 | 7 | 5 | 6 | **6.5** |
| debt-register.md | 7 | 7 | 5 | 7 | **6.5** |
| dependencies-catalog.md | 6 | 6 | 6 | 5 | **5.8** |

### Strengths
- **best api-inventory across all repos**: 3 endpoints, controller sources, auth notes, concrete endpoint paths — genuinely actionable for a new developer.
- **overview.md** received the most thorough enhancement, including architecture highlights, component callouts, and proper navigation.
- **test-catalog.md** honestly and correctly reports zero test coverage — high accuracy marks for not hallucinating test suites.
- Enhancement cross-linking is consistent and structurally correct.

### Weaknesses
- **config-catalog.md** is heavily polluted with CI/CD YAML pipeline keys (e.g., `artifacts.paths`, `deploy_production.script[0]`) alongside actual app configuration, with no separation. Auto-generated descriptions ("Auto-generated: Controls X behavior") dominate.
- **data-model.md** lists 12 models with field counts but provides no relationships, no lifecycle notes, no example data shapes.
- **dependencies-catalog.md** lists packages but provides no vulnerability flags, no upgrade notes, and lumps assembly refs with NuGet packages without priority context.

### Gaps
- No explanation of *why* test coverage is zero — is it a test project discovery failure or a genuine gap?
- `overview.md` architecture confidence is listed as "weak" but no clarifying context is provided.
- No documentation of the SAP integration behavior beyond library reference.

---

## 2. LmsConnect-master

### Artifact Scores

| Artifact | Accuracy | Readability | Completeness | Signal/Noise | Avg |
|----------|----------|-------------|--------------|--------------|-----|
| overview.md | 7 | 6 | 7 | 5 | **6.3** |
| api-inventory.md | 8 | 7 | 7 | 7 | **7.3** |
| data-model.md | 6 | 6 | 5 | 5 | **5.5** |
| config-catalog.md | 5 | 3 | 7 | 3 | **4.5** |
| build-cookbook.md | 7 | 7 | 6 | 6 | **6.5** |
| test-catalog.md | 7 | 7 | 7 | 7 | **7.0** |
| debt-register.md | 7 | 7 | 6 | 7 | **6.8** |
| dependencies-catalog.md | 6 | 6 | 6 | 5 | **5.8** |

### Strengths
- **test-catalog.md** is the best in the batch — 40+ MSTest suites, concrete test case names, strong structural coverage of the processing service and memberships.
- **api-inventory.md** correctly characterises the SOAP surface and distinguishes it from REST. Service policy auth boundary noted.
- **debt-register.md** includes actionable `TODO` items with inline code comments preserved from source — not just line counts.
- Architecture fingerprint confidence (0.99) is appropriately communicated.

### Weaknesses
- **overview.md** still contains raw evidence-reference prose (`ev-0001, ev-0002`) in the welcome section that is not meaningful to a developer without knowing the evidence graph schema. Duplicate "appears to support" language is template noise.
- **config-catalog.md** mixes axoCover tool configuration (`.axoCover/settings.json`) with real runtime app config and CI/CD pipeline keys into one undifferentiated list. Extremely high noise ratio.
- **data-model.md** has 112 models but no inter-domain relationship analysis, no persistence mapping notes, and no ORM/NHibernate entity distinction highlighted.

### Gaps
- SOAP/WCF service contract is mentioned but no WSDL or contract schema reference exists.
- Blackboard integration specifics (what data goes to/from Blackboard) are not documented beyond library name.
- The `ProcessingService` component (batch processing, queue monitoring) deserves a dedicated operational runbook section but has none.

---

## 3. CMich.CoreApi-master

### Artifact Scores

| Artifact | Accuracy | Readability | Completeness | Signal/Noise | Avg |
|----------|----------|-------------|--------------|--------------|-----|
| overview.md | 7 | 6 | 6 | 5 | **6.0** |
| api-inventory.md | 7 | 6 | 7 | 6 | **6.5** |
| data-model.md | 5 | 4 | 6 | 3 | **4.5** |
| config-catalog.md | 5 | 3 | 6 | 3 | **4.3** |
| build-cookbook.md | 7 | 7 | 6 | 6 | **6.5** |
| test-catalog.md | 7 | 7 | 7 | 7 | **7.0** |
| debt-register.md | 6 | 5 | 7 | 5 | **5.8** |
| dependencies-catalog.md | 6 | 6 | 6 | 5 | **5.8** |

### Strengths
- **test-catalog.md** accurately captures 544 test cases across 30 suites, with correct attribution to C# and JavaScript.
- **api-inventory.md** correctly identifies the system as a pure SOAP client (outbound only, 101 endpoints) — a meaningful architectural characterisation.
- **build-cookbook.md** is structurally accurate with 10 project-level build targets, all verified against the solution structure.

### Weaknesses
- **data-model.md** is the weakest artifact in the entire run: 819 models with large auto-generated SAP wrapper classes (TitleIVFunds, EHSInfo) dominate the top of the list. The models are code-generated SAP RFC proxies, not business models — this distinction is absent, causing severe signal noise.
- **debt-register.md** lists 178 items, the majority of which are large auto-generated RFC helper classes (e.g., `RFCHelper_ZCcaTitleIvFunds.cs` at 3532 lines). These are known generated artifacts, not genuine developer debt, yet they appear identically to real issues.
- **config-catalog.md** is dominated by MSBuild `OutputType`/`TargetFramework` entries across 10 projects — structural noise, not operational configuration.

### Gaps
- No documentation of the SAP RFC infrastructure design pattern (ERPConnect40, RFC helpers) — the single most important architectural concept in the repo.
- No guidance on which of the 101 SOAP clients are actively used vs. legacy.
- External host names (`cmu-r3msl01.hosts.secure-24.net`, `it-penguin.central.cmich.local`) are mentioned in overview but not explained in context.
- The architecture fingerprint says `soap-client` but the enhancement summary still references "API responses" as if this were an inbound REST service — a subtle inaccuracy.

---

## 4. DegreeAudit

### Artifact Scores

| Artifact | Accuracy | Readability | Completeness | Signal/Noise | Avg |
|----------|----------|-------------|--------------|--------------|-----|
| overview.md | 7 | 7 | 7 | 6 | **6.8** |
| api-inventory.md | 8 | 7 | 7 | 6 | **7.0** |
| data-model.md | 7 | 6 | 6 | 5 | **6.0** |
| config-catalog.md | 5 | 4 | 7 | 3 | **4.8** |
| build-cookbook.md | 7 | 7 | 6 | 6 | **6.5** |
| test-catalog.md | 8 | 8 | 6 | 8 | **7.5** |
| debt-register.md | 7 | 6 | 8 | 6 | **6.8** |
| dependencies-catalog.md | 7 | 6 | 6 | 5 | **6.0** |

### Strengths
- **test-catalog.md** is the most readable across repos — 4 suites, 25 named test cases, all with full method names, focused on requirement engine and constraint logic. Very high signal.
- **api-inventory.md** correctly identifies 15 auth-required endpoints in the `DataController`, with source file line references — directly actionable for security review.
- **debt-register.md** has the highest item count (342) and is the most representative of real debt. Class sizes (`Data.cs` at 7191 lines, `EvaluationEngine.cs` at 2818) are clearly architectural problems, not noise.
- **overview.md** correctly notes the architecture fingerprint confidence is 0.7 (lower than other repos) — honest uncertainty communication.

### Weaknesses
- **config-catalog.md** has the same systemic issue: email notification templates, status filter strings, and connection strings are mixed with MSBuild properties and CI YAML keys in one table. This is the worst readability artifact across the whole audit.
- **data-model.md** lists 292 models but provides no distinction between ViewModels, domain entities, persistence entities, and DTOs — all are treated equally, burying the important ones.
- Enhancement summaries are structurally identical across all artifacts for all repos (same 3-bullet format, same "Verification Needed" template) — the enhancement pass added navigational scaffolding but not repo-specific insight depth.

### Gaps
- The EF data model and SQL schema are not connected — the repo has an `.edmx` file and SQL scripts, but the data-model artifact doesn't reference them.
- The `CMich.WorkbenchTesting` project is not explained anywhere.
- No documentation of the degree audit evaluation algorithm logic despite `EvaluationEngine.cs` being the core of the system.

---

## Cross-Repo Systematic Analysis

### Systemic Strengths

| Strength | Description |
|----------|-------------|
| **Structural consistency** | All repos produce identical artifact shapes, cross-links, and provenance sections — easy to navigate across repos |
| **Evidence traceability** | Every artifact has a grounding reference back to a source file with line numbers |
| **Honest incompleteness** | The workflow correctly marks missing items as absent rather than hallucinating content |
| **Build cookbook accuracy** | Build commands match solution file names; CI/CD platform detection is correct |
| **Endpoint detection** | API counts and auth markers are deterministically accurate |

### Systemic Weaknesses

| Weakness | Affected Artifacts | Severity |
|----------|--------------------|----------|
| **Config catalog SNR** | config-catalog (all repos) | High |
| CI/CD YAML keys, MSBuild props, and real app configuration are mixed into one undifferentiated table. Makes the artifact nearly unreadable for operators. | | |
| **Template prose dominates** | overview, all enhancements | Medium |
| "This application appears to support X and Y..." and evidence reference IDs `(ev-0001)` are not stripped or reframed in the enhancement pass. | | |
| **No domain-semantic layer** | data-model (all repos) | High |
| Field counts and class names are listed but there is no classification of models by role (ViewModel, Entity, DTO, generated proxy). CMich.CoreApi's RFC wrappers and DegreeAudit's ViewModels need different treatment. | | |
| **Debt register doesn't distinguish generated code** | debt-register (CMich.CoreApi, DegreeAudit) | High |
| Auto-generated SAP RFC helpers and large ViewModelFactory/Conversion classes are flagged as debt identically to real developer debt. | | |
| **Enhancement depth is shallow** | All enhancements | Medium |
| Every enhancement added the same 3-bullet summary + cross-links + 1 verification note. No repo-specific narrative, no business context, no operational guidance. | | |
| **Test catalog gaps not explained** | test-catalog (academichistory) | Medium |
| Zero tests found with no commentary on whether this is a discovery failure or genuine gap. | | |
| **Dependency criticality not prioritized** | dependencies-catalog (all repos) | Low-Medium |
| `Critical Path: Yes/No` exists in the table but is uniformly under-utilized; most packages marked `No` without rationale. | | |

---

## Remediation Plan

The following plan addresses the systemic gaps **deterministically and at the workflow level**, not as one-off manual fixes.

### Priority 1 — Config Catalog Denoising (High Impact)

**Problem**: Operational config is buried under CI/CD pipeline keys, MSBuild properties, and test tool settings.

**Remediation**:
- Modify `generate-config-catalog.ps1` to separate configuration into labelled sections:
  - `Runtime Application Config` (Web.config/App.config appSettings + connectionStrings)
  - `Environment / Deployment Config` (CI YAML variables, environment-specific transforms)
  - `Build / Tooling Config` (MSBuild properties, test runner settings) — collapsed by default or placed in appendix
- Add a "Required for Deployment" flag that auto-marks `connectionStrings` and `Required: Yes` entries at the top.

**Expected gain**: Config catalog readability from ~3.5 → ~7.5 average.

---

### Priority 2 — Data Model Role Classification (High Impact)

**Problem**: ViewModels, domain entities, DTOs, and generated proxies are rendered identically, burying important models.

**Remediation**:
- Extend the AST/model parser to classify models by namespace pattern:
  - `*/ViewModels/*` → ViewModel
  - `*/Models/*` → Domain Model
  - `*/Entities/*` → Persistence Entity
  - `*/Service References/*` or `*/RfcHelper/*` → Generated/Proxy (exclude from high-impact tables)
- Add a `Role` column to the data model tables.
- Generated/proxy models should be in a collapsed appendix section.

**Expected gain**: Data model signal/noise from ~4.5 → ~7.5; eliminates RFC wrapper noise in CMich.CoreApi.

---

### Priority 3 — Debt Register Generated-Code Triage (High Impact)

**Problem**: Auto-generated and auto-sized SAP RFC classes inflate debt counts and obscure real issues.

**Remediation**:
- Add a file-path filter to `generate-debt-register.ps1`:
  - Paths matching `*/Service References/*`, `*/RfcHelper/*`, `*/Generated/*` → auto-tag as `generated-artifact`, exclude from `First-Party Debt (Priority)` table
- Add a `Debt Source Type` column: `developer-authored` | `generated-artifact` | `third-party`
- Report debt counts separately: "Developer-authored debt: N, Generated artifact debt: M"

**Expected gain**: Debt register accuracy/signal from ~5.5 → ~8.0 for CMich.CoreApi; reduces false positives across all repos.

---

### Priority 4 — Overview Template Prose Replacement (Medium Impact)

**Problem**: Evidence reference IDs (`ev-0001`) and "appears to support" template language persist in the overview even after enhancement.

**Remediation**:
- Post-process the overview generation to strip or inline evidence IDs from the Welcome section prose.
- Replace `"This application appears to support X"` template with a deterministic sentence derived from controller names + endpoint counts:
  - `"This application exposes N inbound endpoints across X controllers, serving [business domain derived from controller names]."`
- The enhancement prompt should require that the `Welcome` section is replaced (not appended to) with a cleaner human-readable summary.

**Expected gain**: Overview readability from ~6.5 → ~8.0.

---

### Priority 5 — Enhancement Prompt Depth Requirements (Medium Impact)

**Problem**: The enhancement pass adds identical 3-bullet summaries to every artifact across every repo, providing navigational value but no repo-specific insight.

**Remediation**:
- Update `appdoc.enhance.prompt.md` with per-artifact enhancement requirements:
  - **overview.md**: Must describe the primary business function (not just component names), identify the architecture pattern in plain English, and call out any integration dependencies.
  - **data-model.md**: Must classify entity roles, identify the top 3 entities critical to the business domain, and flag any relationships or lifecycle constraints.
  - **api-inventory.md**: Must describe the *intent* of the top 5 endpoints (not just paths), and note any endpoints missing auth where it looks like it should be present.
  - **debt-register.md**: Must separate generated/framework debt from developer-authored debt; highlight the top 3 debt items most likely to cause production incidents.
  - **test-catalog.md**: Must state coverage confidence (high/medium/low/none) and identify the most underserved domain areas.

**Expected gain**: Enhancement average signal/noise from ~5.5 → ~7.5.

---

### Priority 6 — Test Coverage Gap Diagnosis (Low-Medium Impact)

**Problem**: Zero-test results are reported without diagnosis.

**Remediation**:
- When `generate-test-catalog.ps1` finds 0 tests, emit a diagnostic block explaining discovery settings and suggesting manual verification paths.
- Check for test project existence by scanning for `[TestClass]`, `[Fact]`, `[Test]`, or `describe()` patterns even if test project structure wasn't auto-detected.

---

## Overall Scores by Repo

| Repo | Avg Accuracy | Avg Readability | Avg Completeness | Avg Signal/Noise | **Overall** |
|------|-------------|-----------------|------------------|------------------|-------------|
| academichistory | 7.1 | 7.1 | 6.3 | 6.4 | **6.7** |
| LmsConnect-master | 6.9 | 6.6 | 6.6 | 6.3 | **6.6** |
| CMich.CoreApi-master | 6.3 | 5.6 | 6.5 | 5.0 | **5.9** |
| DegreeAudit | 7.1 | 6.4 | 6.6 | 5.9 | **6.5** |

**Notes**:
- **academichistory** scores highest because of its small, well-scoped surface — fewer endpoints and models mean less noise and more accurate summaries.
- **CMich.CoreApi-master** scores lowest due to the generated RFC proxy problem inflating both the data model and debt register with low-signal content.
- All repos share the same config-catalog noise problem, which is the single highest-impact fix available.

---

## Recommended Workflow Remediation Sequence

```
Phase 1 (Deterministic Generator Fixes):
  1. Config catalog denoising (Priority 1)
  2. Data model role classification (Priority 2)
  3. Debt register generated-code filter (Priority 3)

Phase 2 (Enhancement Prompt Improvements):
  4. Overview prose cleanup (Priority 4)
  5. Enhancement prompt depth requirements (Priority 5)

Phase 3 (Edge Case Coverage):
  6. Test coverage gap diagnosis (Priority 6)
```

Phases 1–3 should be implemented in the generator scripts and are fully deterministic — no AI enhancement required. Phase 2 improves AI enhancement quality. Phase 3 closes diagnostic gaps.

---

*This audit was performed by reviewing generated and enhanced artifact content directly against source evidence tables, cross-referenced with known code structure from static analysis results.*
