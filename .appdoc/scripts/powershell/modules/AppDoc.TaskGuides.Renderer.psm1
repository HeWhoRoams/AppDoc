function Get-AppDocTaskGuidesMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$TaskData
    )

    $changeEndpointGuide = @"
1. Open [API Inventory](api-inventory.md) and identify the target endpoint plus adjacent related endpoints.
2. Trace impacted types in [Data Model](data-model.md) and verify associated configuration in [Configuration Catalog](config-catalog.md).
3. Implement changes and run the minimal build/test loop from [Build Cookbook](build-cookbook.md) and [Test Catalog](test-catalog.md).
4. Re-run AppDoc generation with strict validation and review contradiction/grounding metrics.

**Evidence snapshot**:
$($TaskData.sampleEndpoints -join "`n")
"@

    $debugBuildGuide = @"
1. Start with command parity from [Build Cookbook](build-cookbook.md) and execute the shortest failing command first.
2. Validate environmental assumptions using [Configuration Catalog](config-catalog.md).
3. Compare local output with pipeline behavior and check dependency/version drift in [Dependencies Catalog](dependencies-catalog.md).
4. Confirm recovery by running targeted tests from [Test Catalog](test-catalog.md).

**Evidence snapshot**:
$($TaskData.sampleBuildCommands -join "`n")
"@

    $dependencyRiskGuide = @"
1. Review [Dependencies Catalog](dependencies-catalog.md) for version conflicts and widely used packages.
2. Prioritize risk by usage breadth, version divergence, and critical-path runtime involvement.
3. Validate likely blast radius using [API Inventory](api-inventory.md), [Data Model](data-model.md), and [Build Cookbook](build-cookbook.md).
4. Stage upgrades incrementally and re-run strict documentation validation.

**Evidence snapshot**:
$($TaskData.sampleDependencies -join "`n")
"@

    $debtSprintGuide = @"
1. Group [Technical Debt Register](debt-register.md) findings by impact and ownership domain.
2. Select high-leverage items that reduce recurring defects or shorten release lead time.
3. Attach measurable exit criteria (tests added, complexity reduced, obsolete code removed).
4. Document outcomes and regenerate docs to refresh evidence and trend metrics.

**Evidence snapshot**:
$($TaskData.sampleDebt -join "`n")
"@

    $checklist = @"
- Confirm docs validation score remains above threshold in strict mode.
- Confirm contradictionConsistencyScore and claimGroundingScore remain stable.
- Confirm no sensitive values leak into generated markdown output.
- Confirm changed workflows reference concrete commands and tests.
- Confirm task guidance links to current artifacts, not stale assumptions.
"@

    $evidenceTraceability = @"
| Field | Value |
|------|-------|
| Evidence Artifact | evidence/task-guides.evidence.json |
| Endpoint Evidence Count | $(@($TaskData.endpointRows).Count) |
| Build Evidence Count | $(@($TaskData.buildCommandRows).Count) |
| Dependency Evidence Count | $(@($TaskData.dependencyRows).Count) |
| Debt Evidence Count | $(@($TaskData.debtRows).Count) |
| Test Evidence Count | $(@($TaskData.testRows).Count) |
"@

    return [ordered]@{
        changeEndpointGuide = $changeEndpointGuide
        debugBuildGuide = $debugBuildGuide
        dependencyRiskGuide = $dependencyRiskGuide
        debtSprintGuide = $debtSprintGuide
        checklist = $checklist
        evidenceTraceability = $evidenceTraceability
    }
}

function Update-AppDocTaskGuidesContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [hashtable]$TaskData
    )

    $sections = Get-AppDocTaskGuidesMarkdown -TaskData $TaskData
    $updated = $Content


    # Change an Endpoint Safely
    $before = $updated
    $updated = [regex]::Replace(
        $updated,
        '(?s)(###\s+Change an Endpoint Safely\s*\r?\n\r?\n).*?(?=\r?\n###\s+Debug a Build Failure\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.changeEndpointGuide + "`r`n")
        }
    )
    if ($before -eq $updated) { Write-Verbose "[TaskGuides.Renderer] Pattern not matched: Change an Endpoint Safely" }

    # Debug a Build Failure
    $before = $updated
    $updated = [regex]::Replace(
        $updated,
        '(?s)(###\s+Debug a Build Failure\s*\r?\n\r?\n).*?(?=\r?\n###\s+Triage Dependency Risk\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.debugBuildGuide + "`r`n")
        }
    )
    if ($before -eq $updated) { Write-Verbose "[TaskGuides.Renderer] Pattern not matched: Debug a Build Failure" }

    # Triage Dependency Risk
    $before = $updated
    $updated = [regex]::Replace(
        $updated,
        '(?s)(###\s+Triage Dependency Risk\s*\r?\n\r?\n).*?(?=\r?\n###\s+Plan a Debt Sprint\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.dependencyRiskGuide + "`r`n")
        }
    )
    if ($before -eq $updated) { Write-Verbose "[TaskGuides.Renderer] Pattern not matched: Triage Dependency Risk" }

    # Plan a Debt Sprint
    $before = $updated
    $updated = [regex]::Replace(
        $updated,
        '(?s)(###\s+Plan a Debt Sprint\s*\r?\n\r?\n).*?(?=\r?\n##\s+Operational Checklist\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.debtSprintGuide + "`r`n")
        }
    )
    if ($before -eq $updated) { Write-Verbose "[TaskGuides.Renderer] Pattern not matched: Plan a Debt Sprint" }

    # Operational Checklist
    $before = $updated
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Operational Checklist\s*\r?\n\r?\n).*?(?=\r?\n---\s*\r?\n)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.checklist + "`r`n")
        }
    )
    if ($before -eq $updated) { Write-Verbose "[TaskGuides.Renderer] Pattern not matched: Operational Checklist" }

    if ($updated -notmatch '(?im)^##\s+Evidence Traceability\b') {
        $regex = [regex]::new('(?s)\r?\n---\s*\r?\n')
        $updated = $regex.Replace(
            $updated,
            "`r`n## Evidence Traceability`r`n`r`n$($sections.evidenceTraceability)`r`n`r`n---`r`n",
            1
        )
    } else {
        $updated = [regex]::Replace(
            $updated,
            '(?s)(##\s+Evidence Traceability\s*\r?\n\r?\n).*?(?=\r?\n---\s*\r?\n)',
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Groups[1].Value + $sections.evidenceTraceability + "`r`n")
            }
        )
    }

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocTaskGuidesMarkdown',
    'Update-AppDocTaskGuidesContent'
)
