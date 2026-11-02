---
status: accepted (2026-11-02)
supersedes: ADR-0001, ADR-0002, ADR-0003
---

# AppDoc 2.0: deterministic Facts, AI-written Narrative, pass/fail Check

AppDoc 1.x tried to generate the whole document deterministically, which took ~38,700 lines of PowerShell (56 scripts, 50 modules), a 15-component scored gate, a redaction subsystem and a quarantined enrichment layer, and still could not produce the workflow, troubleshooting and security content that makes a document like the HelpWeb reference useful to a human developer. AppDoc 2.0 splits the work: small Python (3.10+, standard library only) extractors write a reproducible Facts file per Target; the AI writes the Narrative from that Facts file and may read Target source, citing a file for every claim (with a line where specific, always for security and risk); and a pass/fail Check verifies Citations, empty sections, gaps and secret-shaped strings. Only the Facts file is byte-reproducible; the Narrative is grounded but may vary in wording.

## Considered Options

- **Keep full determinism (1.x).** Rejected: every section needs its own extractor, which is the bloat, and it cannot explain behavior.
- **AI reads source with a template, no extraction.** Rejected: nothing reproducible to anchor or verify against.
- **AI writes from the Facts file only.** Rejected: loses the workflows, troubleshooting and security findings the Reader most needs.

## Consequences

- Extractors never record secret values, only their locations, so the 1.x redaction subsystem (ADR-0001) is removed; the Check's secret scan backs up the rule that the Narrative never reproduces values.
- Output goes to `docs/appdoc/` in the Target and is committed there (replaces ADR-0002's `docs/` home).
- The scored gate and its sub-validator failure policy (ADR-0003) are replaced by the Check's problem list.
- Tests assert expected Facts per sample Target and Facts-file reproducibility; byte-locked golden suites of full output are dropped.
- PowerShell 7.2+ is no longer a requirement; Python 3.10+ is.
