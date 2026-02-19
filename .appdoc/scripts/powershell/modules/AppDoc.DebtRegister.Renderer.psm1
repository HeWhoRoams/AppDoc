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
                $newline = if ($matchText -match "\r\n") { "`r`n" } elseif ($matchText -match "\n") { "`n" } else { [Environment]::NewLine }
                return ($m.Groups[1].Value + $sections.debtItemsContent + $newline)
            }
        )
    } else {
        Write-Warning "Debt Items section not found or pattern did not match. Appending debt items content to end of document."
        # Detect newline style from existing content or fallback to Environment.NewLine
        $newline = if ($updated -match "\r\n") { "`r`n" } elseif ($updated -match "\n") { "`n" } else { [Environment]::NewLine }
        $updated += $newline + $newline + $sections.debtItemsContent + $newline
    }

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocDebtRegisterMarkdown',
    'Update-AppDocDebtRegisterContent'
)
