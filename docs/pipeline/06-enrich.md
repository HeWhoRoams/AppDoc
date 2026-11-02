<!-- appdoc:hand-authored -->

[Overview](README.md) › 6 Enrich

# Stage 6: Enrich (optional)

**How can an AI session add meaning to the evidence without being able to overwrite a verified fact or see a secret?**

Enrichment is **off by default**. When it is off, the build prints one line and moves on. When it is on, the work is split across **two builds** with an AI session in between. AppDoc never calls a language model itself. The session that runs AppDoc does the reading and writing between the two builds.

```mermaid
---
title: "L1 · Stage 6 Enrich"
---
sequenceDiagram
  accTitle: Stage 6 Enrich
  accDescr: In build 1 with enrichment on, the stage bootstraps enriched evidence and writes a redacted input file, after secret gate G5, which stops the build with exit 3 if a secret survived. The AI session reads the input and the real source files and writes an output file. In build 2 the stage reads that output and merges it through filter gate G6, which refuses any attempt to overwrite a verified fact and logs it. The merged result and the refusal log are written.

  participant B as Build
  participant E as Enrich stage
  participant S as AI session
  participant F as docs/evidence/semantic

  Note over B,F: Build 1, enrichment on
  B->>E: stages 1 to 5 done, start stage 6
  E->>E: 6.1 bootstrap enriched evidence
  E->>E: 6.2 redact the pending fields
  alt G5 STOP: a secret survived redaction
    E-->>B: blocked, input NOT written
    B-->>B: exit 3
  else clean
    E->>F: 6.3 write input/*.semantic.input.json
  end
  B-->>S: build ends, exit code per stage 7

  Note over S,F: Between builds, outside AppDoc
  S->>F: read input, read real source
  S->>F: write output/*.semantic.output.json

  Note over B,F: Build 2, enrichment on
  B->>E: stages 1 to 5 done, start stage 6
  E->>F: read output
  E->>E: 6.4 G6 FILTER: merge under quarantine
  E->>F: write applied/ and quarantine-refusals.json
```

Shapes and lines: [legend](legend.md). In a sequence diagram, time runs downward and each column is one actor.

## What happens

| Step | What it does | Output |
|---|---|---|
| 6.1 | `run-appdoc-enrich.ps1` builds enriched evidence from the deterministic evidence. The build passes `-SkipGate` and `-SkipReRender`, so the four gate-scored catalogs stay byte-identical | `evidence/*.evidence.enriched.json` |
| 6.2 | For each file, builds the input envelope: one record per pending item, with secret values replaced by `[REDACTED]`. Keys and names are kept | In-memory envelope |
| 6.3 | Runs the secret gate **G5** on the envelope. If it is clean, writes the input file | `semantic/input/<artifact>.semantic.input.json` |
| 6.4 | Reads `semantic/output/` if the AI session has written it. Merges each field under the quarantine rules (**G6**) and tags it | `semantic/applied/`, `semantic/quarantine-refusals.json`, `semantic-pending.json` |

An input-hash cache means a re-run skips records whose input has not changed. A corrected output file is picked up again.

## Gates

| Gate | Kind | Passes when | On failure |
|---|---|---|---|
| [G5](gates.md#g5) | STOP | No known secret, operator pattern or credential shape survives in the redacted envelope | The input file is not written and the build exits **3**. The first blocked file ends the stage |
| [G6](gates.md#g6) | FILTER | A value may fill a field that is open or filled only by a heuristic | An attempt to overwrite a Verified field is refused and logged. The run continues |

A failure in the enrichment stage that is **not** G5 (a missing script, an unexpected throw) is a warning and the build carries on. **P-1.**

## Go deeper

- What the quarantine guarantees, and the provenance words `llm`, `deterministic`, `open`: [enrichment quarantine](detail/enrichment-quarantine.md)
- The exact input and output shapes and the 16 fields: [enrichment-contract](../../references/enrichment-contract.md)
- How an operator runs the two builds: [enrichment-operations](../../references/enrichment-operations.md)
- Next: [Stage 7 Close out](07-close-out.md)

<details>
<summary>Code</summary>

- `.appdoc/scripts/powershell/run-appdoc-build.ps1`, section `(6)`
- `.appdoc/scripts/powershell/run-appdoc-enrich.ps1`
- `.appdoc/scripts/powershell/run-appdoc-semantic-enrich.ps1`: the secret gate, the input-hash cache, the tiered merge
- `.appdoc/scripts/powershell/modules/AppDoc.SemanticRedaction.psm1` (`Test-AppDocSemanticRedactionGate`)

</details>
