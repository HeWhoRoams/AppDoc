# AppDoc Begin (Copilot adapter)

This prompt is a thin wrapper. The procedure is defined in [`SKILL.md`](../../SKILL.md) (Layer 1 — deterministic build) and verified as described in [`references/verification.md`](../../references/verification.md). Follow those; this file only maps the slash-command arguments.

## User Input

```text
$ARGUMENTS
```

## Arguments

- Argument 1 (required): the target repository root.
- Optional flags: `--strict`, `--threshold <1-100>`, `--skip-diagrams`.

To change where the output is written, set `outputDir` in `<target>/.appdoc/config.json` (see `references/config-schema.md`); there is no command-line output-path argument.

## Run

Work on a scratch copy of the target (SKILL.md, "Prerequisites and setup"), then run the single build command:

```powershell
pwsh -NoProfile -File ./.appdoc/scripts/powershell/run-appdoc-build.ps1 -Path <target-root> [-StrictValidation] [-QualityThreshold N] [-SkipDiagrams]
```

Flag mapping: `--strict` → `-StrictValidation`, `--threshold N` → `-QualityThreshold N`, `--skip-diagrams` → `-SkipDiagrams`.

Do not call `run-all-generators.ps1` or individual generators directly: the build command also loads the target's config, applies the redaction sweep and stamps provenance.

## Report

- Exit code `0` = gate passed; `2` = gate failed; `3` = fail-closed redaction stop; `1` = tool error. Report any non-zero code as "not done".
- Summarise from `<output>/validation-report.json` (status, overallScore, pristine sub-score, any failed validators) and `<output>/diagnostics-report.json`.
- Do not invent output; only report files and metrics that exist.

## Optional next step

The quarantined enrichment loop (SKILL.md, Layer 2; Copilot adapter: `/appdoc.enrich`).
