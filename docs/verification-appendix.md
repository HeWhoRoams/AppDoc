# Verification Appendix

This appendix lists the exact, re-runnable PowerShell commands used to verify each `Verified` claim in the Evidence Register. All commands are run **from the repository root** (`<repo-root>`). A non-empty `Select-String` result proves the cited source-level fact.

**Verified claims:** 8  |  **Re-runnable commands:** 3  |  **Insufficient detail (downgraded):** 5

| Claim | Status | Command |
|---|---|---|
| jobs.syntax-gate.runs-on  [config-catalog] | Verified | Select-String -Path '.github/workflows/appdoc-ci.yml' -Pattern 'jobs\.syntax-gate\.runs-on' |
| jobs.syntax-gate.steps.shell  [config-catalog] | Verified | Select-String -Path '.github/workflows/appdoc-ci.yml' -Pattern 'jobs\.syntax-gate\.steps\.shell' |
| jobs.syntax-gate.steps[0]  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| jobs.syntax-gate.steps[1]  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| jobs.syntax-gate.steps[2]  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| name  [config-catalog] | Verified | Select-String -Path '.github/workflows/appdoc-ci.yml' -SimpleMatch 'name' |
| on.push.branches[0]  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| on.push.branches[1]  [config-catalog] | Partly verified | N/A — insufficient evidence detail |

**Scope note:** These commands verify *source-level* facts only. They do not verify runtime behavior, production configuration, or database procedure logic. A row marked `Partly verified` has a command field of `N/A — insufficient evidence detail` because the deterministic extractor recorded a file reference but not a confirmable searchable token.

## Provenance

- Generator Version: appdoc-run-all-generators/3.0.0
- Commit Hash: 17cdd36
- Generated At: 2026-10-23T01:55:45-04:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
