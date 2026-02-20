function Get-DetectedNewline {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )
    if ($Text -match "\r\n") { return "`r`n" }
    if ($Text -match "\n") { return "`n" }
    return [Environment]::NewLine
}
function Get-AppDocDebtRegisterMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Debts
    )

    $debtTablePlaceholder = @"
| Item | Location | Category | Impact | Priority | Effort | Description |
|------|----------|----------|--------|----------|--------|-------------|

_No technical debt items detected. Great job maintaining code quality! Continue monitoring for TODO/FIXME comments._
"@

    if (-not $Debts -or $Debts.Count -eq 0) {
        return [ordered]@{
            debtItemsContent = $debtTablePlaceholder
            debtTablePlaceholder = $debtTablePlaceholder
        }
    }

    $tableHeader = "| Item | Location | Category | Impact | Priority | Effort | Description |`n|------|----------|----------|--------|----------|--------|-------------|"
    $tableRows = $Debts | ForEach-Object {
        $location = if ($_.filePath) { "$($_.filePath):$($_.line)" } else { "$($_.file):$($_.line)" }
        $item = [string]$_.type
        $category = "Code Quality"
        $impact = if ($_.priority -eq "High") { "High" } else { "Medium" }
        $effort = "TBD"
        $description = ([string]$_.description -replace '\|', '\\|').Trim()
        "| $item | ``$location`` | $category | $impact | $($_.priority) | $effort | $description |"
    }

    return [ordered]@{
        debtItemsContent = ($tableHeader + "`n" + ($tableRows -join "`n"))
        debtTablePlaceholder = $debtTablePlaceholder
    }
}

function Update-AppDocDebtRegisterContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Debts
    )

    $sections = Get-AppDocDebtRegisterMarkdown -Debts $Debts
    $updated = $Content
    if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.debtTablePlaceholder -NewContent $sections.debtItemsContent
    }
    else {
        $updated = $updated.Replace($sections.debtTablePlaceholder, $sections.debtItemsContent)
    }


    $debtItemsPattern = '(?s)(##\s+Debt Items\s*\r?\n+).*?(?=\r?\n##\s+Impact Assessment\b|\z)'
    $match = [regex]::Match($updated, $debtItemsPattern)
    if ($match.Success) {
        $updated = [regex]::Replace(
            $updated,
            $debtItemsPattern,
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                # Detect newline style from matched text or fallback to Environment.NewLine
                $matchText = $m.Value
                $newline = Get-DetectedNewline -Text $matchText
                return ($m.Groups[1].Value + $sections.debtItemsContent + $newline)
            }
        )
    } else {
        Write-Warning "Debt Items section not found or pattern did not match. Appending debt items content to end of document."
        # Detect newline style from existing content or fallback to Environment.NewLine
        $newline = Get-DetectedNewline -Text $updated
        $updated += $newline + $newline + $sections.debtItemsContent + $newline
    }

    $categoryResolver = {
        param([string]$type)
        $value = if ($type) { $type.ToLowerInvariant() } else { "" }
        if ($value -match 'deprecated|obsolete|dependency|package') { return "Dependencies" }
        if ($value -match 'security|auth|credential|secret') { return "Security" }
        if ($value -match 'performance|slow|allocation|memory') { return "Performance" }
        if ($value -match 'todo|fixme|hack|long function|large class|magic') { return "Code Quality" }
        return "Maintainability"
    }

    $categoryGroups = @(
        $Debts |
            ForEach-Object { [pscustomobject]@{ category = (& $categoryResolver ([string]$_.type)) } } |
            Group-Object -Property category |
            Sort-Object Count -Descending
    )
    $categoriesContent = if ($categoryGroups.Count -gt 0) {
        $lines = @("Most extracted debt in this run is concentrated in the following categories:")
        foreach ($group in $categoryGroups) {
            $lines += "- **$($group.Name)**: $($group.Count) item(s)"
        }
        ($lines -join [Environment]::NewLine)
    }
    else {
        "No debt categories were derived from the current scan."
    }

    $debtCount = @($Debts).Count
    $impactLevel = if ($debtCount -ge 200) { "high" } elseif ($debtCount -ge 75) { "moderate" } else { "localized" }
    $impactContent = "The current register contains $debtCount item(s), indicating $impactLevel remediation pressure on delivery speed and change safety. Prioritize hotspots in high-churn files to reduce regression risk fastest."

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Overview\s*\r?\n\r?\n).*?(?=\r?\n##\s+Debt Categories\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "This register is built from extracted code-smell and maintainability signals and is intended to support prioritized remediation planning." + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Debt Categories\s*\r?\n\r?\n).*?(?=\r?\n##\s+Debt Items\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $categoriesContent + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Impact Assessment\s*\r?\n\r?\n).*?(?=\r?\n##\s+Remediation Plan\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $impactContent + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Remediation Plan\s*\r?\n\r?\n).*?(?=\r?\n##\s+Monitoring and Tracking\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Use a phased plan: isolate highest-risk files first, split oversized classes/methods in small slices, and add regression coverage around each refactor before broad cleanup." + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Monitoring and Tracking\s*\r?\n\r?\n).*?(?=(\r?\n##\s+)|\z)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Track debt trendlines with recurring static-analysis runs and include debt deltas in release-readiness reviews to prevent re-accumulation." + "`r`n")
        }
    )

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocDebtRegisterMarkdown',
    'Update-AppDocDebtRegisterContent'
)
