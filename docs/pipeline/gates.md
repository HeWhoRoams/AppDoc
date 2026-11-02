<!-- appdoc:hand-authored -->

[Overview](README.md) › Gates and exit codes

# Gates and exit codes

**What exactly does each gate check, what happens when it fails, and what does each exit code mean?**

This is the one place where gate criteria are written. Every other page links here by gate ID. The rules themselves live in [ADR 0001](../adr/0001-redaction-externalize-per-target-secrets.md), [ADR 0003](../adr/0003-sub-validator-failure-policy.md) and [`references/`](../../references/); this page summarises them and points at the code.

Gate kinds (STOP, SCORE, FILTER) are explained in the [legend](legend.md#gate-kinds).

## Gate catalog

| ID | Stage | Kind | Checks | Passes when | On failure | Exit | Code (file · function) | Rule source | Known gap |
|---|---|---|---|---|---|---|---|---|---|
| <a id="g1a"></a>**G1a** | 1 Configure | STOP | `<target>/.appdoc/config.json` parses | The file is absent (defaults apply) or is valid JSON | The build stops before it writes anything | 1 | `run-appdoc-build.ps1` · `Get-AppDocConfig` (`AppDoc.Config.psm1`) | [config-schema](../../references/config-schema.md) | none |
| <a id="g1b"></a>**G1b** | 1 Configure | STOP | Operator redaction compiles | Every `redactionRegexes` entry is a valid regex (case-insensitive, 2 s match timeout); `redactionPatterns` are escaped literals and cannot fail | The build stops before it writes anything | 3 | `run-appdoc-build.ps1` · `Get-AppDocOperatorRedactionMatchers` (`AppDoc.SecretPolicy.psm1`) | ADR 0001, [config-schema](../../references/config-schema.md) | none |
| <a id="g2"></a>**G2** | 2 Collect evidence | SCORE | No script in the orchestrator's phase loop threw | `scriptFailures` is empty | Each failure is recorded in `diagnostics-report.json` (`metadata.scriptFailures`). The run continues. Close-out turns the list into exit 1 | 1 (at close-out) | `run-all-generators.ps1` phase loop; `run-appdoc-build.ps1` close-out | ADR 0003 §4 | **P-1**: only the phase loop is recorded; other generators only warn |
| <a id="g3"></a>**G3** | 4 Validate | SCORE | Validation gate status | `status` is `pass`, or `pass-with-weak-coverage` without `-StrictValidation` | The status is written to `validation-report.json`. The run continues. Close-out turns a failed status into exit 2 unless `-AllowGateFail` is set | 2 (at close-out) | `validate-documentation.ps1` | ADR 0003, [verification](../../references/verification.md), [scoring](detail/validation-scoring.md) | **P-5**: SKILL.md says the bar is `status=pass` |
| <a id="g4"></a>**G4** | 5 Finalize | STOP | The final redaction sweep can run | The redaction module loads and returns its URI-credential patterns | The build stops; the docs are **not** swept and must not be published | 3 | `run-appdoc-build.ps1` step 5 · `Get-AppDocSemanticUriCredentialPatterns` (`AppDoc.SemanticRedaction.psm1`) | ADR 0001 | none |
| <a id="g5"></a>**G5** | 6 Enrich | STOP | Secret-redaction hard gate on the LLM-facing input | No known secret, operator pattern or credential shape survives in the redacted envelope | The stage is blocked, the input file is **not** written, the build stops | 3 | `run-appdoc-semantic-enrich.ps1` · `Test-AppDocSemanticRedactionGate` (`AppDoc.SemanticRedaction.psm1`) | [enrichment-contract](../../references/enrichment-contract.md) | none |
| <a id="g6"></a>**G6** | 6 Enrich | FILTER | Quarantine merge | An LLM value may fill a field that is open or filled only by a heuristic; it may not overwrite a Verified field | The override is refused and logged to `semantic/quarantine-refusals.json`; the Verified value stays; the run continues | none | `run-appdoc-semantic-enrich.ps1` (tiered merge) | [enrichment-contract](../../references/enrichment-contract.md), [quarantine](detail/enrichment-quarantine.md) | none |
| <a id="g7"></a>**G7** | 2 Collect evidence | STOP (intended) | Preflight PowerShell syntax gate over the scripts folder | `ci-syntax-gate.ps1` reports no errors | The orchestrator throws. The build catches that as a warning and carries on | none in practice | `run-all-generators.ps1` · `ci-syntax-gate.ps1` | none | **T-1** |
| <a id="g8"></a>**G8** | 2 Collect evidence | STOP (intended) | Only one run per output folder | The PID in `.appdoc-run.session.json` is not a live process | The orchestrator exits 1. The build ignores that and carries on | none in practice | `run-all-generators.ps1` | none | **T-2** |

Gates G1–G6 are drawn on [the overview](README.md). G7 and G8 are described on [Collect evidence](02-collect-evidence.md): they are meant to stop the run, but the build does not enforce them.

## Exit codes

`run-appdoc-build.ps1` reports the outcome in its exit code ([ADR 0003](../adr/0003-sub-validator-failure-policy.md)). Treat any non-zero code as "not done".

| Code | Meaning | Every path that sets it |
|---|---|---|
| **0** | The gate passed, or `-AllowGateFail` was given | Close-out step 7.5 or 7.6 |
| **1** | Tool error | Target path does not exist; `AppDoc.Config` module missing; invalid config JSON (**G1a**); the orchestrator produced no docs folder; `validation-report.json` missing or unreadable; `diagnostics-report.json` unreadable; a recorded generator failure (**G2**) |
| **2** | The gate failed: the docs were written but did not pass | Close-out step 7.6, status `fail` (or `blocked`, or `pass-with-weak-coverage` under `-StrictValidation`) |
| **3** | Fail-closed stop | An invalid `redactionRegexes` entry (**G1b**); the sweep module cannot load (**G4**); the secret-redaction hard gate blocks (**G5**) |

Codes 1 (early paths) and 3 end the run where they happen. The line-ending pass and the close-out checks do not run.

### Close-out decision

After stages 1–6 have finished without a stop, the build decides the code in this order. [Close out](07-close-out.md) shows the same order as a diagram.

| Step | Check | Result |
|---|---|---|
| 7.2 | `validation-report.json` exists and parses | No → exit **1** |
| 7.3 | `diagnostics-report.json` (if present) parses | No → exit **1** |
| 7.4 | `metadata.scriptFailures` is empty (**G2**) | No → exit **1** |
| 7.5 | Status is `pass`, or `pass-with-weak-coverage` and not `-StrictValidation` (**G3**) | Yes → exit **0** |
| 7.6 | Otherwise: `-AllowGateFail` set? | Yes → exit **0** with a warning. No → exit **2** |

The orchestrator's own exit code is deliberately not used: native commands it runs also set `$LASTEXITCODE`, so the value is ambiguous. The outcome comes from `validation-report.json` and `diagnostics-report.json`.

## Checks that only warn

These look like gates but never change the outcome of a build.

| Check | Stage | Effect when it fails |
|---|---|---|
| Diagram validation (`validate-diagrams.ps1`) | 3 | Warning and a diagnostic entry |
| Remediation pass (`remediate-generated-docs.ps1`) | 3 | Warning |
| C4 diagrams, diagram suite, HTML report | 3 | Warning (**P-1**) |
| Evidence-graph integrity | 4 | Soft mode: warning. `-StrictValidation`: throws and aborts the orchestrator (same mechanism as **T-1**; not run) |
| Documentation integrity gate (`ci-doc-integrity-gate.ps1`) in the orchestrator | 4 | Soft mode: warning. `-StrictValidation`: throws (same mechanism as **T-1**; not run) |
| Document quality report | 4 | Informational; a warning when more than half the documents are low quality |
| Pristine report | 4 | Report-only. `-PristineGate` exists on the orchestrator and validator, but the build never passes it, so status `blocked` cannot come from a build |
| Second-pass composer, pristine and validation | 3, 4 | Warning |
| Enrichment failure other than G5 | 6 | Warning |

## Known gaps

Where the code differs from its contract. Each gap is tagged on the pages that draw the behaviour. Remove a tag in the same change that fixes the gap.

| ID | Gap | Where | How it was found |
|---|---|---|---|
| **P-1** | A generator crash exits 0 unless the script ran in the phase loop. The C4 generator, diagram suite, HTML report, a script that cannot be found, the second pass and non-gate enrichment failures only warn. ADR 0003 §4 says a crashed generator is exit 1 | 2, 3, 6 | Code review 2026-10-23; the trace confirmed the code paths |
| **P-5** | SKILL.md's hard bar says `status=pass`, but the build exits 0 on `pass-with-weak-coverage` (as ADR 0003 allows) | 4, 7 | Code review 2026-10-23 |
| **T-1** | A failed syntax pre-check only warns. On a target with no earlier docs the build then exits 2 on an empty package. On a target that already has docs, the second pass re-validates the stale evidence and the build exits **0 with status `pass`** | 2 | Trace, 2026-10-23: a syntax error injected into one generator on a scratch copy |
| **T-2** | The "another run is active" guard exits the orchestrator, but the build ignores that and carries on into the second pass, sweep and exit decision, exiting 0 | 2 | Trace, 2026-10-23: a live PID written to `.appdoc-run.session.json` |
| **T-3** | On a target that is not Classic ASP or Web Forms, `generate-classic-asp-failures.ps1` runs after `generate-test-catalog.ps1` and overwrites `test-catalog.md` with a "not applicable" placeholder. `evidence/test-catalog.evidence.json` still records the tests, so the two disagree. The gate still passes. The sibling `generate-classic-asp-extcalls.ps1` has a no-clobber guard for the same situation; this script does not | 2 | Trace, 2026-10-23: a fixture with two tests ended with "No test cases were extracted" |
| **T-5** | The three Analysis-phase scripts (`analyze-repository`, `generate-dependency-graph`, `extract-config`) only print JSON to the console. The orchestrator does not capture it, nothing writes it to disk, and no other script reads it. The phase scans the target and produces nothing | 2 | Trace, 2026-10-23: ran `analyze-repository.ps1` on a scratch copy (JSON on the console, no new file) and searched the repository for readers (none) |

Not raised as a gap: values the LLM writes into `semantic/applied/` are not swept for operator secrets, because the sweep runs before enrichment. The contract puts a gate on the input only.

## How these pages were checked

- Read in full: `run-appdoc-build.ps1`, `run-all-generators.ps1` (phase list, gates, close-out), `validate-documentation.ps1` (validators, scoring, status), `run-appdoc-enrich.ps1`, `run-appdoc-semantic-enrich.ps1`, `AppDoc.SecretPolicy.psm1`, `AppDoc.SemanticRedaction.psm1`, `AppDoc.Provenance.psm1`, and the CI workflow.
- Run: builds on scratch copies of `python-flask-sample` (plain, with enrichment on, with a mock LLM output that tries to override a Verified field), `node-express-sample` and `csharp-core-api-sample`, with PowerShell 7.4.6 on Linux. The T-1, T-2 and T-3 experiments used the same fixtures.
- Not run: the Windows leg, `-StrictValidation` paths, and a real Classic ASP or Web Forms target.
