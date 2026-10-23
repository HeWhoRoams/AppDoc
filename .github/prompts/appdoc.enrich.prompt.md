# AppDoc Semantic Enrichment (Copilot adapter)

This prompt is a thin wrapper. The enrichment contract is harness-agnostic and lives in
[`references/enrichment-contract.md`](../../references/enrichment-contract.md); the operating procedure is in
[`SKILL.md`](../../SKILL.md) and [`references/enrichment-operations.md`](../../references/enrichment-operations.md).

## User Input

```text
$ARGUMENTS
```

## Steps

1. Read `references/enrichment-contract.md` completely and follow it exactly.
2. Target repository root: argument 1 (a scratch copy of the real target).
3. Emit the redacted input: `pwsh ./.appdoc/scripts/powershell/run-appdoc-build.ps1 -Path <target> -EnableSemanticEnrich`.
4. Read `<target>/docs/evidence/semantic/input/*.semantic.input.json`, ground each field in the real source, and write
   `<target>/docs/evidence/semantic/output/<artifact>.semantic.output.json`.
5. Re-run the same command to apply under the quarantine, then verify per `references/verification.md`.

Never fabricate, never override a Verified fact, never weaken redaction or the gate.
