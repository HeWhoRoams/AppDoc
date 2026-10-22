# Verification Appendix

This appendix lists the exact, re-runnable PowerShell commands used to verify each `Verified` claim in the Evidence Register. All commands are run **from the repository root** (`/persistent/agent/workspace/AppDoc`). A non-empty `Select-String` result proves the cited source-level fact.

**Verified claims:** 54  |  **Re-runnable commands:** 19  |  **Insufficient detail (downgraded):** 35

| Claim | Status | Command |
|---|---|---|
| chat.tools.fileOperations.autoApprove.list  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.fileOperations\.autoApprove\.list' |
| chat.tools.fileOperations.autoApprove.read  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.fileOperations\.autoApprove\.read' |
| chat.tools.terminal.autoApprove.-ErrorAction  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.-ErrorAction' |
| chat.tools.terminal.autoApprove.-Json  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.-Json' |
| chat.tools.terminal.autoApprove.-RootPath  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.-RootPath' |
| chat.tools.terminal.autoApprove.-Verbose  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.-Verbose' |
| chat.tools.terminal.autoApprove..\.AppDoc\\scripts\\powershell\\*.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove..AppDoc/scripts/powershell/*.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/analyze-capability-gaps.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/analyze-codebase.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/analyze-repository.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/calculate-quality-metrics.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/catalog-samples.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/extract-config.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-api-inventory.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-build-cookbook.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-config-catalog.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-data-model.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-debt-register.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-dependencies-catalog.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-dependency-graph.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-improvements.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-overview.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/generate-test-catalog.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/run-all-generators.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/validate-api-inventory.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/validate-build-cookbook.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/validate-config-catalog.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/validate-data-model.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/validate-debt-register.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/validate-overview.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.**/validate-test-catalog.ps1  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.Copy-Item  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.Copy-Item' |
| chat.tools.terminal.autoApprove.Get-ChildItem  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.Get-ChildItem' |
| chat.tools.terminal.autoApprove.Get-Content  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.Get-Content' |
| chat.tools.terminal.autoApprove.git  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.git' |
| chat.tools.terminal.autoApprove.git fetch  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.git status  [config-catalog] | Partly verified | N/A — insufficient evidence detail |
| chat.tools.terminal.autoApprove.pwsh  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.pwsh' |
| chat.tools.terminal.autoApprove.Remove-Item  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.Remove-Item' |
| chat.tools.terminal.autoApprove.Set-ExecutionPolicy  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.Set-ExecutionPolicy' |
| chat.tools.terminal.autoApprove.Test-Path  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.Test-Path' |
| chat.tools.terminal.autoApprove.Write-Host  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'chat\.tools\.terminal\.autoApprove\.Write-Host' |
| github.copilot.chat.executions.enabled  [config-catalog] | Verified | Select-String -Path '.vscode/settings.json' -Pattern 'github\.copilot\.chat\.executions\.enabled' |
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
- Commit Hash: 85946f7
- Generated At: 2026-10-17T18:41:14-04:00
- Profile: default
- Scope: .
- Confidence/Inference Flags: deterministic, evidence-backed
