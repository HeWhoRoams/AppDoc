# ADR 0003: Sub-validator failures count against the gate, and the build exit code reports the gate

- **Status:** Accepted (2026-10-22)
- **Decision area:** Validation gate; build contract; CI and harness integration

## Context

`validate-documentation.ps1` is documented as the authoritative gate. It runs eight per-artifact
sub-validators (`validate-overview.ps1`, `validate-dependencies-catalog.ps1`, …). Each sub-validator
reports failed checks by printing ` - <issue-code>` lines and ending with `exit 1`, and reports
unusable input (for example a missing artifact) with `Write-Error`.

Until this ADR the gate invoked each sub-validator with `& $script … | Out-Null` and recorded
`passed = $true` unless the call threw. `exit 1` does not throw; it only sets `$LASTEXITCODE`, which
was never read. A sub-validator could therefore fail every check and still be reported as `OK`, and
`validatorPassRate` could only drop when an artifact or script was missing.

Separately, `run-appdoc-build.ps1` always exited `0`: a failed gate, a failed strict validation and a
fail-closed semantic redaction block were all reduced to warnings. Harnesses and CI could not tell a
passing build from a failing one without parsing `validation-report.json` themselves.

## Decision

1. **A sub-validator that exits non-zero is recorded as failed.** The gate resets `$LASTEXITCODE`
   before each call, reads it after, and records `passed = $false`, the exit code and the reported
   issue codes. This lowers `validatorPassRate`; the existing score threshold then decides pass or
   fail. Thresholds are unchanged.
2. **A sub-validator that crashes is a tool defect and fails the gate.** An exception that is not a
   `Write-Error` from the validator, or an issue code containing `internal-error`, is recorded with
   `internalError = $true`, listed in `validatorInternalErrors`, and forces `status = fail`.
3. **The build exit code reports the outcome:**

   | Code | Meaning |
   |---|---|
   | 0 | Gate passed (`pass`, or `pass-with-weak-coverage` without `-StrictValidation`), or `-AllowGateFail` was given |
   | 1 | Tool error: bad path, missing module, a generator that crashed, or no or unreadable `validation-report.json` |
   | 2 | Gate failed: the docs were written but did not pass the gate |
   | 3 | Fail-closed stop: the final redaction sweep could not run, or the semantic secret-redaction gate blocked |

4. **A generator that crashes is also a tool error (exit 1).** The orchestrator records it in
   `diagnostics-report.json` (`metadata.scriptFailures`); the build reads that list and exits 1 even
   when the gate passes, because the artifact the generator owns is missing or stale.
5. `-AllowGateFail` exists for exploratory runs. It logs the failed status and exits 0. It is never
   used in CI.

## Consequences

- Failures that were previously hidden become visible. A fixture or target whose sub-validators were
  silently failing may now score lower or fail the gate. That is the intended effect: the failure was
  real. Fix the cause; do not lower the threshold.
- Wrappers that assumed exit 0 must treat 2 and 3 as failures (or pass `-AllowGateFail`).
- Regression tests: `tests/powershell/Gate.ValidatorFailure.Tests.ps1`,
  `tests/powershell/Build.ExitCodes.Tests.ps1`.
