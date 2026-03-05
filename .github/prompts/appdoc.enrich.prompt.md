# AppDoc Enrichment Prompt

[OBJECTIVE]
You are enriching deterministic AppDoc evidence records before rendering. Work only on JSON evidence and source snippets. Do not edit markdown.

[INPUT]
- `docs/evidence/<artifact>.evidence.json`
- `docs/architecture-fingerprint.json`
- Top 3 consuming source snippets per evidence record

[OUTPUT]
- `docs/evidence/<artifact>.evidence.enriched.json`
- Preserve all original record fields
- Add/update only enrichment fields

[ENRICHMENT FIELDS]
Populate (or keep null when unknown):
- `role`
- `businessPurpose`
- `isGenerated`
- `tier`
- `confidence`
- `confidenceNote`
- `integrationTargets`
- `relationships`
- `dependencyKind`
- `operationalProfile`
- `projectRole`
- `usageFrequency`
- `testDiagnosis`
- `criticalPath`
- `upgradeUrgency`
- `requiredForDeployment`
- `schemaSource`

[ROLE VALUES]
- Models: `ViewModel | Entity | DTO | Aggregate | GeneratedProxy | Unknown`
- Config: `runtime | deployment | build-tooling`
- Debt: `developer-authored | generated-artifact`
- Dependency kind: `nuget | assembly-reference | npm | system`

[MANDATORY RULES]
1. Never hallucinate. If evidence is insufficient, keep field null and explain uncertainty in `confidenceNote`.
2. Never infer `businessPurpose` from the name alone.
3. If `confidence < 0.80`, `confidenceNote` is required.
4. For `soap-client` architecture fingerprint, never use inbound REST terminology.
5. Keep generated proxies (`RFCHelper_*`, `*.designer.cs`, `Reference.cs`, `*.g.cs`) marked `isGenerated=true` unless code proves otherwise.
6. For zero-test repositories, set `testDiagnosis.zeroTestReason` to `scope-failure | genuine-gap | unknown`.

[STYLE]
- `businessPurpose` must be one plain-English sentence.
- Be specific and concise.
- Prefer factual statements from call sites over conventions.
