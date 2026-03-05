function Update-MarkdownSection {
    param(
        [string]$Content,
        [string]$SectionName,
        [string]$NextSectionPattern,
        [string]$NewContent,
        [string]$Newline
    )
    $sectionPattern = "(?s)(##\s+$([regex]::Escape($SectionName))\s*\r?\n$Newline).*?(?=$NextSectionPattern)"
    $match = [regex]::Match($Content, $sectionPattern)
    if (-not $match.Success) {
        Write-Warning "Section '$SectionName' not found for update."
        return $Content
    }
    return [regex]::Replace(
        $Content,
        $sectionPattern,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $NewContent + $Newline)
        }
    )
}
function Get-DetectedNewline {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )
    if ($Text -match "\r\n") { return "`r`n" }
    if ($Text -match "\n") { return "`n" }
    return [Environment]::NewLine
}

function Resolve-AppDocDebtCategory {
    param([string]$Type)

    $value = ([string]$Type).ToLowerInvariant()
    if ($value -match 'security|vulnerability|xss|injection|auth|secret') { return 'Security' }
    if ($value -match 'performance|slow|latency|allocation|memory') { return 'Performance' }
    if ($value -match 'test|coverage|assert|flaky') { return 'Testing' }
    if ($value -match 'dependency|package|library|version') { return 'Dependencies' }
    if ($value -match 'style|format|lint|naming') { return 'Code Quality' }
    if ($value -match 'complex|duplication|maintain|smell|refactor|todo|fixme') { return 'Maintainability' }
    return 'General'
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
        $emptySectionContent = @(
            "### First-Party Debt (Priority)",
            "",
            "| Item | Location | Ownership | Category | Impact | Priority | Risk Metadata | Description |",
            "|------|----------|-----------|----------|--------|----------|---------------|-------------|",
            "| N/A | N/A | first-party | N/A | N/A | N/A | N/A | No first-party debt rows detected |",
            "",
            "### Vendor/Generated Debt",
            "",
            "| Item | Location | Ownership | Category | Impact | Priority | Risk Metadata | Description |",
            "|------|----------|-----------|----------|--------|----------|---------------|-------------|",
            "| N/A | N/A | vendor/generated | N/A | N/A | N/A | N/A | No vendor/generated debt rows detected |"
        ) -join "`n"

        return [ordered]@{
            debtItemsContent = $emptySectionContent
            debtTablePlaceholder = $debtTablePlaceholder
        }
    }

    $dedupedDebts = @(
        $Debts |
            Group-Object -Property @{ Expression = {
                "{0}|{1}|{2}" -f [string]$_.type, [string]$_.file, [string]$_.line
            } } |
            ForEach-Object { $_.Group | Select-Object -First 1 }
    )

    $getField = {
        param($record, [string]$fieldName, $defaultValue = $null)

        if ($null -eq $record) { return $defaultValue }

        if ($record -is [System.Collections.IDictionary] -and $record.Contains($fieldName)) {
            return $record[$fieldName]
        }

        $prop = $record.PSObject.Properties[$fieldName]
        if ($prop) { return $prop.Value }

        $metadata = $null
        if ($record -is [System.Collections.IDictionary] -and $record.Contains('metadata')) {
            $metadata = $record['metadata']
        } elseif ($record.PSObject.Properties['metadata']) {
            $metadata = $record.metadata
        }

        if ($null -ne $metadata) {
            if ($metadata -is [System.Collections.IDictionary] -and $metadata.Contains($fieldName)) {
                return $metadata[$fieldName]
            }
            $metadataProp = $metadata.PSObject.Properties[$fieldName]
            if ($metadataProp) { return $metadataProp.Value }
        }

        return $defaultValue
    }

    $isVendorOrGenerated = {
        param($debt)

        $role = [string](& $getField $debt 'role' '')
        if (-not [string]::IsNullOrWhiteSpace($role)) {
            return $role -eq 'generated-artifact'
        }

        $isGenerated = & $getField $debt 'isGenerated' $null
        if ($null -ne $isGenerated) {
            return [bool]$isGenerated
        }

        $path = [string](& $getField $debt 'filePath' (& $getField $debt 'file' ''))
        return $path -match '(?i)(?:^|[\\/])(bin|obj|node_modules|packages|vendor|generated|service references|connected services)(?:[\\/]|$)'
    }

    $firstPartyDebts = @($dedupedDebts | Where-Object { -not (& $isVendorOrGenerated $_) })
    $vendorDebts = @($dedupedDebts | Where-Object { (& $isVendorOrGenerated $_) })

    $tableHeader = "| Item | Location | Ownership | Category | Impact | Priority | Risk Metadata | Description |`n|------|----------|-----------|----------|--------|----------|---------------|-------------|"
    $renderRows = {
        param([array]$rows, [string]$ownership)
        foreach ($debt in @($rows)) {
            $filePath = [string](& $getField $debt 'filePath' (& $getField $debt 'file' ''))
            $line = & $getField $debt 'line' 0
            $location = if (-not [string]::IsNullOrWhiteSpace($filePath)) { "${filePath}:$line" } else { "unknown:0" }
            $item = [string](& $getField $debt 'type' (& $getField $debt 'name' 'debt-item'))
            $category = Resolve-AppDocDebtCategory -Type $item
            $priority = [string](& $getField $debt 'priority' 'Medium')
            $impact = switch ($priority) {
                "High" { "High" }
                "Medium" { "Medium" }
                "Low" { "Low" }
                default { "Medium" }
            }
            $businessPurpose = [string](& $getField $debt 'businessPurpose' '')
            $descriptionSource = if (-not [string]::IsNullOrWhiteSpace($businessPurpose)) { $businessPurpose } else { [string](& $getField $debt 'description' '') }
            $description = ($descriptionSource -replace '\|', '\\|').Trim()
            if ([string]::IsNullOrWhiteSpace($description)) {
                $description = "Purpose unclear from available evidence — review $filePath."
            }
            $riskMetadata = if ($ownership -eq "developer-authored") { "Direct runtime/refactor risk" } else { "Generated/vendor maintenance risk" }
            "| $item | ``$location`` | $ownership | $category | $impact | $priority | $riskMetadata | $description |"
        }
    }

    $firstPartyRows = @(& $renderRows $firstPartyDebts "developer-authored")
    $vendorRows = @(& $renderRows $vendorDebts "generated-artifact")


    return [ordered]@{
        debtItemsContent = @(
            "### Developer-Authored Debt (Priority)",
            "",
            $tableHeader,
            $(if ($firstPartyRows.Count -gt 0) { $firstPartyRows -join "`n" } else { "| N/A | N/A | developer-authored | N/A | N/A | N/A | N/A | No developer-authored debt rows detected |" }),
            "",
            "### Generated Artifact Debt",
            "",
            $tableHeader,
            $(if ($vendorRows.Count -gt 0) { $vendorRows -join "`n" } else { "| N/A | N/A | generated-artifact | N/A | N/A | N/A | N/A | No generated artifact debt rows detected |" })
        ) -join "`n"
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

    $categoryGroups = @(
        $Debts |
            ForEach-Object { [pscustomobject]@{ category = (Resolve-AppDocDebtCategory -Type ([string]$_.type)) } } |
            Group-Object -Property category |
            Sort-Object Count -Descending
    )
    $categoriesContent = if ($categoryGroups.Count -gt 0) {
        $lines = @("Most extracted debt in this run is concentrated in the following categories:")
        foreach ($group in $categoryGroups) {
            $lines += "- **$($group.Name)**: $($group.Count) items"
        }
        ($lines -join [Environment]::NewLine)
    }
    else {
        "No debt categories were derived from the current scan."
    }

    $debtCount = @($Debts).Count
    $impactLevel = if ($debtCount -ge 200) { "high" } elseif ($debtCount -ge 75) { "moderate" } else { "localized" }
    $impactContent = "The current register contains $debtCount items, indicating $impactLevel remediation pressure on delivery speed and change safety. Prioritize hotspots in high-churn files to reduce regression risk fastest."

    $newline = Get-DetectedNewline -Text $updated
    $updated = Update-MarkdownSection $updated "Overview" "\r?\n##\s+Debt Categories\b" "This register is built from extracted code-smell and maintainability signals and is intended to support prioritized remediation planning." $newline
    $updated = Update-MarkdownSection $updated "Debt Categories" "\r?\n##\s+Debt Items\b" $categoriesContent $newline
    $updated = Update-MarkdownSection $updated "Impact Assessment" "\r?\n##\s+Remediation Plan\b" $impactContent $newline
    $updated = Update-MarkdownSection $updated "Remediation Plan" "\r?\n##\s+Monitoring and Tracking\b" "Use a phased plan: isolate highest-risk files first, split oversized classes/methods in small slices, and add regression coverage around each refactor before broad cleanup." $newline
    $updated = Update-MarkdownSection $updated "Monitoring and Tracking" "(\r?\n##\s+|\z)" "Track debt trendlines with recurring static-analysis runs and include debt deltas in release-readiness reviews to prevent re-accumulation." $newline

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocDebtRegisterMarkdown',
    'Update-AppDocDebtRegisterContent'
)
