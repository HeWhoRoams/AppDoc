# AppDoc Begin Prompt

## User Input

```text
$ARGUMENTS
```

Use this prompt to run deterministic AppDoc generation from start to finish with no interactive pauses.

## Control Flow

1. Parse arguments:
- Argument 1 (required): target repository root path.
- Argument 2 (optional): output docs path (default `docs/`).
- Optional flags: `--strict`, `--threshold <1-100>`, `--skip-diagrams`, `--no-ai`, `--dry-run`.

2. Validate prerequisites:
- Target path exists.
- `.appdoc/scripts/powershell/run-all-generators.ps1` exists.

3. Execute a single orchestrated command:

```powershell
pwsh ./.appdoc/scripts/powershell/run-all-generators.ps1 -RootPath <target-root> [flags]
```

Flag mapping:
- `--strict` => `-StrictValidation`
- `--threshold N` => `-QualityThreshold N`
- `--skip-diagrams` => `-SkipDiagrams`
- `--no-ai` => `-NoAI`
- `--dry-run` => `-DryRun`

4. If command fails:
- Report failure reason.
- Surface key diagnostics from `docs/diagnostics-report.json` and `docs/validation-report.json` when available.

5. If command succeeds:
- Report generated artifacts under `docs/`.
- Provide summary from:
  - `docs/quality-report.json`
  - `docs/validation-report.json`
  - `docs/diagnostics-report.json`

## Non-Negotiables

- Do not run per-generator and per-validator scripts manually when `run-all-generators.ps1` is available.
- Do not pause between phases.
- Do not invent output; only report files and metrics that exist.
- Use absolute paths for script execution.

## Optional Next Step

If `-NoAI` was not used, suggest `/appdoc.enhance` after deterministic generation completes.
