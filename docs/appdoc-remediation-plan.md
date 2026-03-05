# AppDoc Remediation Plan

**Status**: Active  
**Principle**: Build a pipeline where every stage does one thing cleanly. AI enriches evidence before it is rendered. Deterministic code never synthesises meaning.

---

## Audit-to-Plan Coverage Matrix

Every finding in the quality audit maps to a stage, a prompt instruction, or an implementation phase below. Nothing is left to chance or "future work."

| Audit Finding | Severity | Addressed By |
|---------------|----------|--------------|
| Config keys (MSBuild, CI YAML) mixed with runtime config | High | Stage 2 — `tier` field; Stage 3 — renderer groups by tier |
| SAP RFC proxies appear as First-Party Debt | High | Stage 2 — `isGenerated` field; Stage 3 — renderer routes generated items to appendix |
| 292–819 models undifferentiated by role | High | Stage 2 — `role` field; Stage 3 — renderer groups by role |
| "Auto-generated: Controls X behavior" descriptions | High | Stage 2 — `businessPurpose` from source; no fallback exists in Stage 3 |
| Evidence IDs (`ev-0001`) in narrative prose | Med | Stage 4 polish — explicit prohibition |
| "Appears to support" template language | Med | Stage 4 polish — explicit prohibition; definitive sentence required |
| Identical 3-bullet enhancement across all repos | Med | Stage 4 polish — per-artifact developer-question contract |
| Zero-test silent pass | Med | Stage 2 — enricher writes `testDiagnosis`; Stage 4 surfaces as callout |
| `dependencies-catalog` assembly refs lumped with NuGet | Low-Med | Stage 2 — `dependencyKind` field; Stage 3 — renders separate sections |
| `Critical Path: Yes/No` uniformly No with no rationale | Low-Med | Stage 2 — enricher assesses call-site usage; Stage 4 reorders by criticality |
| Overview "architecture confidence: weak" unexplained | Med | Stage 2 — enricher writes `confidenceNote`; Stage 4 surfaces in callout |
| Integration surfaces undocumented (SAP, Blackboard, WCF) | Med | Stage 2 — `integrationTargets` array; Stage 4 adds integration narrative |
| Architecture fingerprint vs polish terminology mismatch | Med | Stage 4 — fingerprint read required; style contract constrains vocabulary |
| Active vs legacy endpoint guidance absent | Med | Stage 2 — enricher assesses usage patterns; Stage 4 flags low-usage clients |
| Cross-project roles unexplained (WorkbenchTesting etc.) | Low | Stage 2 — `projectRole` field per project; Stage 4 adds Project Map callout |
| Inter-entity relationships absent from data-model | Med | Stage 2 — `relationships` array; Stage 4 writes domain narrative from it |
| Schema/ORM linkage absent (`.edmx`, SQL scripts) | Med | Stage 2 — enricher surfaces schema files; Stage 3 lists them in data-model |
| Operational service pattern undocumented (batch/queue) | Low-Med | Stage 2 — `operationalProfile` field; Stage 4 adds Operational Note |
| External hostnames in overview unexplained | Low | Stage 2 — enricher resolves hostname purpose from config; Stage 4 annotates |
| No validation gate before renderer rebuild | High | Phase 2.5 — explicit validation checklist before any Phase 3 work |
| `appdoc.enrich` not wired into orchestration | High | Phase 6 — `run-appdoc-enrich.ps1` orchestration script defined |

---

## The Real Problem

The previous version of this plan listed seven items. Six were regex fixes. Adding more patterns to a classification blacklist is not a remedy — it is deferred failure. Every new codebase brings unfamiliar folder names, unfamiliar code-generation tools, and unfamiliar config file formats that the patterns don't anticipate. The docs degrade. The team adds more patterns. The cycle repeats.

The root cause is not a missing pattern. It is a pipeline with the wrong separation of concerns.

**Today's pipeline:**

```
Extract → [classify + describe + render] → AI tries to fix the output
```

The extractor captures signals and simultaneously makes classification decisions (is this model infrastructure or domain?) and description decisions (what does this config key do?). The renderer synthesises meanings it cannot reliably infer. AI enhancement is then deployed as a rescue operation against already-corrupted output — editing rendered markdown rather than structured data.

Pattern-matching can extract. It cannot understand. The moment a task requires understanding — "is this a ViewModel or a domain Entity?", "what does this config key control?", "is this class developer-authored or generated?" — pattern-matching will always be unreliable against unfamiliar codebases.

**The target pipeline:**

```
Extract → Enrich (AI on evidence) → Render → Polish (AI on prose)
```

Each stage has one job and one input format. The overview artifact already proves this works — its `TruthPack → ContextPack → Pipeline → Narrative → Render` architecture produces the cleanest output in the entire system, consistently. This plan extends that architecture to every artifact.

---

## The Four-Stage Contract

### Stage 1 — Extract (deterministic, always)

The extractor's only job is to **capture raw signals faithfully**. It does not classify. It does not describe. It does not decide what is important.

The extractor records what it found and where it found it. Nothing more.

**What changes**: Extractors stop making classification decisions. The `isInfrastructureModel` path checks, `isToolingConfig` predicates, and `Synthesize-AppDocConfigDescription` fallbacks are all removed from this stage. The extractor records the raw type, path, source, and value — that is its entire contract.

**Evidence schema additions** — full set of nullable fields added to `AppDoc.Contracts.psm1`. All are null after extraction and populated by Stage 2:

```json
{
  "role": null,
  "businessPurpose": null,
  "isGenerated": null,
  "tier": null,
  "confidence": null,
  "confidenceNote": null,
  "integrationTargets": null,
  "relationships": null,
  "dependencyKind": null,
  "operationalProfile": null,
  "projectRole": null,
  "usageFrequency": null,
  "testDiagnosis": null
}
```

All existing evidence files remain valid — null fields are ignored by the current renderer until Stage 3 is deployed.

---

### Stage 2 — Enrich (AI on structured evidence, before rendering)

The enricher reads raw evidence records from `docs/evidence/*.evidence.json` alongside targeted source file snippets, and produces enriched evidence records with semantic labels.

The enricher operates on **JSON, not on markdown**. It never touches a rendered file. It reasons about code structure — how a class is used, what a config key controls, whether a file is generated or written by a developer — and writes those conclusions as structured fields on the evidence records.

This is where AI's real strength is applied: semantic reasoning over structured code evidence, not document editing.

**Enriched evidence record examples:**

```json
{
  "name": "StudentAcademicSummaryViewModel",
  "kind": "model",
  "filePath": "Models/ViewModels/StudentAcademicSummaryViewModel.cs",
  "role": "ViewModel",
  "businessPurpose": "Aggregates a student's completed credits, GPA, and standing for the degree audit display page.",
  "isGenerated": false,
  "confidence": 0.92
}
```

```json
{
  "key": "SmtpServer",
  "kind": "configuration",
  "tier": "runtime",
  "businessPurpose": "SMTP host used by NotificationService to send degree audit completion emails.",
  "isGenerated": false,
  "confidence": 0.88
}
```

```json
{
  "name": "RFCHelper_ZCcaTitleIvFunds",
  "kind": "model",
  "filePath": "Service References/ZCcaTitleIvFunds/RFCHelper_ZCcaTitleIvFunds.cs",
  "role": "GeneratedProxy",
  "isGenerated": true,
  "businessPurpose": "SAP RFC client proxy — auto-generated by ERPConnect. Not developer-authored.",
  "confidence": 0.99
}
```

**The enricher prompt contract** — new file `appdoc.enrich.prompt.md`:

```
Input:  docs/evidence/<artifact>.evidence.json
        docs/evidence/architecture-fingerprint.json  (always included)
        Source file snippets (top 3 consuming files for each record)
Output: docs/evidence/<artifact>.evidence.enriched.json

═══════════════════════════════════════════════════
UNIVERSAL FIELDS  (populate for every record type)
═══════════════════════════════════════════════════

role
  The semantic role of this item. Valid values per artifact type:

  Models    → ViewModel | Entity | DTO | Aggregate | GeneratedProxy | Unknown
  Config    → runtime | deployment | build-tooling
  Debt      → developer-authored | generated-artifact
  Dependency → nuget | assembly-reference | npm | system

businessPurpose
  One plain-English sentence. What does this item do
  in the context of this specific application?
  Read the consuming code. Do not infer from the name alone.
  If unclear: "Purpose unclear from available evidence — review <filename>."
  Never hallucinate. Never describe the item in terms of its own name.

isGenerated
  true  → produced by a code-generation tool; no hand-authored logic present.
  false → developer-authored.
  A class is generated when it exhibits: only auto-assigned properties,
  machine-style naming (RFCHelper_*, *_Binding_*, Reference.cs, *.designer.cs,
  *.g.cs, *.Generated.cs), or repetitive field patterns with no custom logic.

confidence
  0.0–1.0. How certain are you, given the provided snippets?

confidenceNote
  Required when confidence < 0.80. One sentence: what structural signal was ambiguous?
  Example: "No consuming call sites found — role inferred from namespace only."

═══════════════════════════════════════════════════
MODEL-SPECIFIC FIELDS
═══════════════════════════════════════════════════

relationships
  Array of relationship descriptors. For each related model that this model
  references (navigation property, foreign key, constructor parameter):
  { "target": "ModelName", "type": "HasMany | BelongsTo | References | UsedBy" }
  Maximum 5 relationships. Omit if no relationships are evident from the snippets.

schemaSource
  If the model is backed by a database schema: the .edmx file, migration file,
  or SQL script that defines its persistence shape. File path relative to repo root.
  Null if no schema file found.

═══════════════════════════════════════════════════
CONFIG-SPECIFIC FIELDS
═══════════════════════════════════════════════════

tier
  runtime    → read at application startup or request time. Required to run.
  deployment → environment-specific overrides (transforms, CI YAML variables).
  build-tooling → MSBuild properties, test runner settings, CI pipeline structure.
  
  Determination rule: find the code that reads this key. If ConfigurationManager,
  Environment.GetEnvironmentVariable, or IConfiguration reads it at runtime → runtime.
  If it only appears in *.yml, *.yaml CI files or *.csproj → build-tooling.

requiredForDeployment
  true if this key must be set correctly in every deployment environment.
  Connection strings and SMTP/API host keys are almost always true.
  MSBuild OutputType is always false.

═══════════════════════════════════════════════════
DEPENDENCY-SPECIFIC FIELDS
═══════════════════════════════════════════════════

dependencyKind
  One of: nuget | assembly-reference | npm | system

criticalPath
  true if this package is called on the primary execution path of the application.
  Determine from call-site frequency in the source snippets.
  Do not default to false. Assess each package individually.

upgradeUrgency
  current | outdated | severely-outdated | cve-flagged
  If version information is present in the evidence, assess relative to
  known release history. If unknown, emit "unknown".

═══════════════════════════════════════════════════
INTEGRATION-SPECIFIC FIELDS
═══════════════════════════════════════════════════

integrationTargets
  Array. Populated on overview and api-inventory evidence records.
  For each external system this application calls or is called by:
  {
    "name": "System name (e.g. SAP, Blackboard, SQL Server)",
    "direction": "inbound | outbound | bidirectional",
    "protocol": "SOAP | REST | RFC | JDBC | Queue | File | Unknown",
    "notes": "One sentence describing what data crosses this boundary."
  }
  Sources: WSDL references, WCF client configs, HTTP client usage,
  connection strings, RFC helper classes, queue configuration.

═══════════════════════════════════════════════════
OPERATIONAL FIELDS
═══════════════════════════════════════════════════

operationalProfile
  Populated only for components that exhibit batch, queue, or scheduled patterns.
  {
    "pattern": "batch | queue | scheduled | real-time",
    "trigger": "What initiates this component? Cron, message arrival, HTTP request?",
    "notes": "One sentence on operational behaviour (e.g. retry, idempotency, SLA)."
  }
  Null for all other records.

projectRole
  Populated only for top-level project records in the solution.
  One of: application | library | test-project | tooling | migration | unknown.
  Include one sentence: what is this project's purpose in the solution?

usageFrequency
  For api-inventory endpoint records: active | low-usage | no-callers-found.
  Determine by counting call sites in the source snippets.
  For SOAP client collections: assess which clients have recent/frequent callers.

testDiagnosis
  Populated only on test-catalog evidence records.
  {
    "coverageLevel": "high | medium | low | none",
    "discoveryMethod": "How tests were found (e.g. MSTest attributes, Xunit, describe())",
    "zeroTestReason": "If coverage is none: scope-failure | genuine-gap | unknown",
    "underservedAreas": ["List of domain areas with thin or no test coverage"]
  }

═══════════════════════════════════════════════════
ARCHITECTURE FINGERPRINT CONSTRAINT
═══════════════════════════════════════════════════

Always read architecture-fingerprint.json before writing any enriched record.
The fingerprint type constrains the vocabulary you may use:

  soap-client    → This codebase makes outbound SOAP calls. It does not expose
                   "API endpoints" or "API responses". Use: "RFC calls", "SOAP
                   operations", "service invocations".
  mvc-webapp     → Standard terminology applies.
  library        → Has no endpoints. Has no runtime config. Has no SMTP.

If the enhancement pass ever uses terminology that contradicts the fingerprint,
it will produce inaccurate documentation. Record the fingerprint type as a
top-level field on the enriched evidence file:

  { "architectureFingerprint": "<type>", "records": [...] }

═══════════════════════════════════════════════════
HONESTY RULES
═══════════════════════════════════════════════════

1. Never hallucinate. If you cannot find evidence, say so.
2. Never infer businessPurpose from a name alone. Read the code.
3. Do not default criticalPath to false. Assess it.
4. When confidence < 0.80, always populate confidenceNote.
5. Record schemaSource only when you actually find the schema file.
```

---

### Stage 3 — Render (deterministic, from enriched evidence)

The renderer reads enriched evidence and formats it. It makes no classification decisions because the records already carry `role`, `tier`, `isGenerated`, and `businessPurpose`. It simply groups and formats.

Every conditional that was previously making a classification judgment in the renderer is replaced by a field read:

| Before (pattern matching in renderer) | After (field read from enriched evidence) |
|----------------------------------------|-------------------------------------------|
| `$path -match '(?i)/ViewModels?/'`     | `$record.role -eq "ViewModel"` |
| `$isToolingConfig` predicate           | `$record.tier -eq "build-tooling"` |
| `$isVendorOrGenerated` ScriptBlock     | `$record.isGenerated -eq $true` |
| `Synthesize-AppDocConfigDescription`   | `$record.businessPurpose` |
| `"Auto-generated: Controls X behavior"` | never emitted |
| Assembly refs mixed into NuGet table   | `$record.dependencyKind -eq "assembly-reference"` → own section |
| `Critical Path: Yes` uniform default   | `$record.criticalPath -eq $true` → sort first |
| No schema reference in data-model      | `$record.schemaSource` → listed under model entry |
| No relationships in data-model table   | `$record.relationships` → rendered as child rows |
| No operational note for batch services | `$record.operationalProfile` → rendered as callout block |
| No project role section                | `$record.projectRole` → rendered in Project Map section |

**Renderer output structure changes per artifact:**

- `config-catalog.md`: three labelled sections — **Runtime Configuration**, **Deployment / Environment**, **Build & Tooling** — in that order. Only Runtime section is open by default in rendered markdown.
- `data-model.md`: two sections — **Domain Models** (ViewModel, Entity, DTO, Aggregate) and **Generated / Proxy Classes** (GeneratedProxy) — with a domain narrative header and a Project Map callout.
- `debt-register.md`: two tables — **Developer-Authored Debt** and **Generated Artifact Inventory** — with separate counts.
- `dependencies-catalog.md`: three sections — **NuGet Packages**, **Assembly References**, **npm Packages** — sorted by `criticalPath` descending within each section.
- `overview.md`: new **Integration Map** section populated from `integrationTargets` array; new **Project Map** section populated from `projectRole` fields.

The renderer becomes thin. Any codebase, any tech stack, any naming convention — the renderer does not care. The enricher has already done the understanding.

---

### Stage 4 — Polish (AI on rendered prose, light touch)

The polish pass — today called "enhance" — changes its role. It no longer needs to rescue poorly-classified or undescribed content. It has one job: make clean, accurate, classified content read beautifully.

**Replacement for `appdoc.enhance.prompt.md`:**

```
[OBJECTIVE]
You are a senior technical writer performing a final editorial pass on
documentation that is already structurally correct and semantically accurate.
Your job is not to fix errors. Your job is to make excellent content
read as clearly as possible for a developer opening this file for the first time.

[MANDATORY: READ THIS FIRST]
Before writing a single word, read docs/evidence/architecture-fingerprint.json.
The fingerprint type constrains every artifact you touch.

  soap-client  → Never write "API endpoint", "API response", "REST".
                 Use: "service operation", "RFC call", "SOAP invocation".
  library      → Never write "endpoint", "deployment config", "runtime".
                 This codebase has no inbound surface and may have no runtime config.
  mvc-webapp   → Standard terminology.

If your output contains terminology that contradicts the fingerprint, that is
a documentation error. Correct it before submitting.

[WHAT YOU ARE NOT DOING]
Do not re-classify models, config keys, or debt items. That has been done.
Do not add boilerplate "Enhanced X Summary" scaffold sections. Add substance.
Do not add [NEEDS VERIFICATION] markers to items with confidence ≥ 0.80.
Do not reproduce evidence IDs (ev-0001, ev-0002) anywhere in prose.
Do not write "appears to", "likely", "seems to", or "may" when evidence is present.
  Evidence is present. Be definitive.

[WHAT YOU ARE DOING]
Read each artifact as a developer would on their first day with this codebase.
Ask: what question is this developer trying to answer?

─────────────────────────────────────────────
overview.md  →  "What does this system do and where do I start?"
─────────────────────────────────────────────
Write the opening paragraph as one confident, plain-English answer.
No technobabble. No evidence IDs. One paragraph. Be definitive.

If the enriched evidence contains integrationTargets, add an Integration Map
section: one row per external system, showing name / direction / protocol /
one-sentence description of what crosses that boundary. This replaces any
vague integration mention in existing prose.

If the enriched evidence contains projectRole fields for multiple projects,
add a Project Map callout: one row per project with its role and purpose sentence.
This makes CMich.WorkbenchTesting and similar projects visible and explained.

If architecture fingerprint confidence is below 0.80, add a callout:
"Architecture Confidence: [Low/Medium]" and include the confidenceNote from
the enriched evidence explaining what structural signal was ambiguous.
Do not leave low-confidence overviews without this note.

─────────────────────────────────────────────
api-inventory.md  →  "Which endpoints should I know about and why?"
─────────────────────────────────────────────
Add one business-intent sentence above each controller group — not the HTTP method,
the user need it serves.

If the enriched evidence contains usageFrequency = "no-callers-found" on any
endpoint or SOAP operation, add a "Low-Usage / Possibly Legacy" note beneath it.
Do not silently omit these — they are high-risk surfaces that may be unmaintained.

Flag auth gaps where the enricher set a low confidence auth note and the endpoint
handles user data. One sentence, frank.

─────────────────────────────────────────────
data-model.md  →  "What are the important domain objects?"
─────────────────────────────────────────────
Write a 2-sentence domain narrative before the entity tables: name the 3 most
important entities and their relationship in plain English. Read the relationships
array in the enriched evidence — do not guess.

If enriched records contain schemaSource fields, add a "Schema Sources" callout
listing the .edmx, migration files, or SQL scripts that back these models.
A developer should know immediately where the database schema is defined.

─────────────────────────────────────────────
config-catalog.md  →  "What do I need to configure to run this?"
─────────────────────────────────────────────
Write a "Deployment Checklist" callout at the top of the Runtime Configuration
section. List only keys where requiredForDeployment = true. Under 10 lines.
No table. A developer should be able to act on it without scrolling.

Do not write descriptions for build-tooling entries. They are already in their
own section with correct businessPurpose from the enricher. Leave them as-is.

If any config key has an unresolved external hostname in its value (an IP address
or server name from the enriched evidence), annotate it with one sentence noting
what the hostname is used for, if the enricher identified it.

─────────────────────────────────────────────
debt-register.md  →  "What are the three things most likely to bite us?"
─────────────────────────────────────────────
Add a "Top Risk" callout at the very top: the 3 highest-priority developer-authored
debt items, one sentence each. No tables in the callout. Direct and frank.
Select only items where role = "developer-authored". The generated artifact section
is informational — do not mix it into the risk callout.

─────────────────────────────────────────────
test-catalog.md  →  "Am I confident in this codebase?"
─────────────────────────────────────────────
Add a "Coverage Confidence" callout: one sentence from the enriched testDiagnosis —
High / Medium / Low / None — and list the domain areas with the thinnest coverage.

If coverageLevel = "none" and zeroTestReason = "scope-failure", add an explicit
note: "Zero tests found. This may be a discovery gap — verify manually before
treating as untested." Do not silently pass zero-test results as zero-coverage facts.

─────────────────────────────────────────────
dependencies-catalog.md  →  "Is anything dangerous or overdue?"
─────────────────────────────────────────────
The renderer has already sorted packages into NuGet / Assembly / npm sections
ordered by criticalPath. Your job is editorial:

Add an "Attention Required" callout only when any package has
upgradeUrgency = "cve-flagged" or "severely-outdated". List package name,
current version, and one-sentence risk statement. If none qualify, omit the callout.

Do not add a callout for packages marked "outdated" — that is noise. CVE and
severely-outdated only.

─────────────────────────────────────────────
Components with operationalProfile
─────────────────────────────────────────────
For any component that the enricher assigned an operationalProfile (batch, queue,
scheduled), add an "Operational Note" callout in the relevant artifact:
  Pattern: <batch|queue|scheduled>
  Trigger: <what starts it>
  Notes: <operational behaviour>
This applies to services like ProcessingService in LmsConnect — operators and
on-call developers need to know how to reason about these components.

[STYLE CONTRACT]
Write for a developer, not a documentation tool.
"This service sends email notifications when a degree audit completes."
Not: "Responsible for outbound SMTP communication lifecycle management."
If a sentence needs a dictionary, rewrite it.
Confidence without arrogance. Precision without jargon.
Short sentences. Active voice.
```

---

## What This Solves Permanently

| Problem observed in audit | Architectural cause | This pipeline's fix |
|---------------------------|---------------------|---------------------|
| MSBuild keys in runtime config section | Renderer classifying by pattern | Enricher sets `tier: build-tooling`; renderer groups by field |
| SAP RFC proxies in First-Party Debt | Scope blacklist missed ERPConnect | Enricher sets `isGenerated: true`; renderer routes automatically |
| 292–819 models undifferentiated | Renderer had no role field to read | Enricher classifies each model; renderer groups by `role` |
| "Auto-generated: Controls X behavior" | Renderer fell back to string template | Enricher writes `businessPurpose` from source; no fallback exists |
| Evidence IDs in narrative prose | Renderer inlined refs into narrative | Polish: explicit prohibition; definitive sentence required |
| Identical 3-bullet enhancement across repos | Enhance prompt had no substance contract | Polish runs on clean content; per-artifact developer-question contract |
| Zero-test silent pass | Extractor didn't distinguish scope fail from genuine gap | Enricher writes `testDiagnosis` with `zeroTestReason`; polish surfaces it |
| Assembly refs lumped with NuGet | No `dependencyKind` field | Enricher sets field; renderer renders three separate sections |
| `Critical Path: Yes/No` uniformly No | No usage assessment | Enricher assesses call-site frequency; renderer sorts by `criticalPath` |
| Overview confidence "weak" unexplained | No `confidenceNote` field | Enricher writes note; polish adds confidence callout when < 0.80 |
| Integration surfaces undocumented | No `integrationTargets` field | Enricher writes integration array; overview renderer adds Integration Map |
| Fingerprint vs polish terminology mismatch | Polish prompt unaware of fingerprint | Polish prompt mandates fingerprint read first; style contract enforces it |
| Active vs legacy endpoint guidance absent | No `usageFrequency` field | Enricher assesses callers; polish flags no-caller operations |
| Cross-project roles unexplained | No `projectRole` field | Enricher writes role; overview renderer adds Project Map |
| Inter-entity relationships absent | No `relationships` field | Enricher writes relationship array; renderer adds child rows |
| Schema/ORM linkage absent (.edmx, SQL) | No `schemaSource` field | Enricher surfaces schema files; renderer lists them; polish adds callout |
| Operational service undocumented | No `operationalProfile` field | Enricher writes profile; polish adds Operational Note callout |
| External hostnames unexplained | No hostname resolution | Enricher resolves purpose from config consumers; polish annotates |

No new patterns were added to fix any of these. None need to be. When the next codebase uses Phoenix LiveView, Rust-generated WASM modules, or a home-grown code generator with no standard markers — the enricher reads the code and classifies it correctly because it understands, not because someone anticipated the pattern.

---

## New Workflow Step: `appdoc.enrich`

```
/appdoc.begin   → deterministic extraction   → docs/evidence/*.evidence.json
/appdoc.enrich  → AI enrichment on evidence  → docs/evidence/*.evidence.enriched.json
                  (re-render from enriched)   → docs/*.md (structured, clean)
/appdoc.enhance → editorial polish           → docs/*.md (production-ready)
```

`appdoc.enrich` is fast — it reads evidence JSON and targeted source snippets, not the entire codebase. It can be re-run after significant refactors without touching generation. It outputs structured JSON that the renderer reads directly.

---

## Implementation Sequence

Each phase delivers independently verifiable value before the next begins.

**Phase 1 — Evidence schema** *(no output change)*  
Add `role`, `businessPurpose`, `isGenerated`, `tier`, `confidence`, `confidenceNote`, `integrationTargets`, `relationships`, `dependencyKind`, `operationalProfile`, `projectRole`, `usageFrequency`, `testDiagnosis`, `criticalPath`, `upgradeUrgency`, `requiredForDeployment`, `schemaSource` to `AppDoc.Contracts.psm1`. Make them all nullable. All existing evidence files remain valid with nulls. No output changes. No risk.

**Phase 2 — `appdoc.enrich.prompt.md`** *(new prompt, no code change)*  
Write the enrichment prompt from the contract above. Test against all four existing repos before any code changes. The validation target for each repo:

- academichistory: `SmtpServer` config key gets `tier: runtime`; zero tests get `testDiagnosis.zeroTestReason`; SAP library gets an `integrationTargets` entry.
- LmsConnect-master: ProcessingService gets `operationalProfile`; Blackboard integration gets an `integrationTargets` entry; NHibernate entity classes get `role: Entity`.
- CMich.CoreApi-master: All `RFCHelper_*` classes get `isGenerated: true`; fingerprint token `soap-client` written to enriched file header; `cmu-r3msl01.hosts.secure-24.net` hostname resolved in config.
- DegreeAudit: `.edmx` file path written to at least one model's `schemaSource`; `EvaluationEngine.cs` gets `role: developer-authored` debt with high-severity business purpose; ViewModels separated from entities by `role`.

**Phase 2.5 — Enricher validation gate** *(do not proceed to Phase 3 until all pass)*  
Run the enricher output through this checklist for each repo:

```
□ enriched file contains architectureFingerprint field
□ no record has businessPurpose containing "Auto-generated" or inferred from name
□ no record with confidence < 0.80 is missing confidenceNote
□ config-catalog enriched records: at least 3 tier values present (not all same tier)
□ data-model enriched records: at least 2 role values present for repos with 20+ models
□ at least 1 integrationTarget found for each repo known to integrate externally
□ test-catalog enriched records: testDiagnosis.coverageLevel populated for every suite
□ dependency records: criticalPath assessed per-record (not all false)
□ zero-test repo: testDiagnosis.zeroTestReason = "scope-failure" or "genuine-gap", not null
```

Do not proceed to Phase 3 if any item is unchecked. Fix the prompt and re-run.

**Phase 3 — Rebuild renderers to read enriched fields**  
Remove `$isToolingConfig`, `$isVendorOrGenerated`, `$isInfrastructureModel`, and `Synthesize-AppDocConfigDescription` from all renderers. Replace with field reads as documented in the Stage 3 renderer table. Add the new output structure sections (config-catalog three-section layout, data-model domain/generated split, debt-register authored/generated split, dependencies by kind, overview Integration Map and Project Map). Run against all four repos. Outputs must:
- Never emit "Auto-generated: Controls X behavior."
- Config-catalog must have three labelled sections.
- Data-model must have domain and generated sections.
- Debt-register must have two separate debt counts.

**Phase 4 — Replace `appdoc.enhance.prompt.md`**  
Deploy the editorial polish contract above. This pass is now fast and reliable because it is editing clean content rather than correcting structural problems. Test against all four repos — output for each must contain:
- overview.md: no evidence IDs, no "appears to", integration map present where integrationTargets exist.
- config-catalog.md: Deployment Checklist callout at top.
- debt-register.md: Top Risk callout at top.
- test-catalog.md: Coverage Confidence callout present.

**Phase 5 — Strip extractors to pure capture**  
With renderers reading from enriched fields and the full pipeline validated, remove classification logic from extractors. The scope module's `$AppDocGeneratedProxyPatterns` becomes an initialisation hint only — it no longer gates any rendering decision.

**Phase 6 — `appdoc.enrich` orchestration**  
Create `run-appdoc-enrich.ps1` at `.appdoc/scripts/powershell/`. This script:

1. Reads all `docs/evidence/*.evidence.json` files.
2. For each, assembles the evidence JSON + `architecture-fingerprint.json` + targeted source snippets (top 3 call-site files per record, extracted by the script).
3. Submits to the AI prompt defined in `appdoc.enrich.prompt.md`.
4. Writes the output to `docs/evidence/*.evidence.enriched.json`.
5. Triggers a re-render pass by invoking the renderers against the enriched evidence.

Update `run-all-generators.ps1` to document the new three-step workflow:
```
/appdoc.begin   → extraction      → docs/evidence/*.evidence.json
/appdoc.enrich  → AI enrichment   → docs/evidence/*.evidence.enriched.json + re-render
/appdoc.enhance → editorial polish → docs/*.md (production-ready)
```

Document the `appdoc.enrich` step in `README.md` alongside `appdoc.begin` and `appdoc.enhance`.

---

## The Standard This Produces

`CMich.CoreApi-master/docs/data-model.md` after this pipeline:

> **CMich.CoreApi** proxies 101 SAP RFC functions through a typed .NET façade. It has no user-facing features and no inbound endpoints — it is consumed by other services as a library.
>
> The codebase contains 27 developer-authored domain classes. The remaining 792 classes are auto-generated SAP RFC proxies catalogued separately below.

Then a clean table of 27 classes, each with a `Role` column and a `Business Purpose` sentence written from source evidence — not a 819-row undifferentiated list.

`DegreeAudit/docs/debt-register.md` after this pipeline, top of page:

> **Top Risk**
> `EvaluationEngine.cs` (2,818 lines) contains the full degree audit rule engine in a single class with no unit tests. Any change here carries full-blast production risk.
> `Data.cs` (7,191 lines) handles both persistence and business logic. It is the single largest change-risk surface in the codebase.
> `ConversionFactory.cs` (1,204 lines) has no test coverage and is called on every audit render path.

That is the standard. The pipeline architecture above is what makes it repeatable, for any codebase, without manual intervention.

---

*The test for every future pipeline change: does this stage do exactly one thing? If a renderer is classifying, it is doing two things. If an extractor is describing, it is doing two things. Fix the stage boundary — not the pattern list.*
