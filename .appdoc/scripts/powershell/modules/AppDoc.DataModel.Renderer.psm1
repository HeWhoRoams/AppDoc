function Get-AppDocDataModelMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Models,
        [int]$MaxDetailedModels = 120
    )

    $modelTablePlaceholder = @"
| Model Name | Fields | Types | Description | Constraints | Indexes |
|------------|--------|-------|-------------|-------------|---------|

_No data models detected. This codebase may use dynamic structures or patterns not yet recognized by the scanner._
"@

    if (-not $Models -or $Models.Count -eq 0) {
        return $modelTablePlaceholder
    }

    $domainRows = @($Models | ForEach-Object {
        $path = if ($_.filePath) { [string]$_.filePath } else { "unknown" }
        $domain = "general"
        if ($path -match '^([^/\\]+)/') {
            $domain = $Matches[1]
        }
        [pscustomobject]@{
            domain = $domain
            type = [string]$_.type
            fieldCount = @($_.properties).Count
        }
    })

    $domainSummary = @($domainRows | Group-Object -Property domain | Sort-Object Count -Descending)
    $domainSummaryTable = @(
        "| Domain | Models | Avg Fields | Dominant Type |",
        "|--------|--------|------------|---------------|"
    )
    foreach ($group in $domainSummary | Select-Object -First 25) {
        $avgFields = [Math]::Round((($group.Group | Measure-Object -Property fieldCount -Average).Average), 1)
        $dominantType = ($group.Group | Group-Object -Property type | Sort-Object Count -Descending | Select-Object -First 1).Name
        $domainSummaryTable += "| $($group.Name) | $($group.Count) | $avgFields | $dominantType |"
    }

    $topModels = @($Models | Sort-Object { @($_.properties).Count } -Descending | Select-Object -First 30)
    $topModelTable = @(
        "| Model | Fields | Type | Source |",
        "|-------|--------|------|--------|"
    )
    foreach ($model in $topModels) {
        $source = "{0}:{1}" -f [string]$model.filePath, [int]$model.lineNumber
        $topModelTable += "| ``$([string]$model.name)`` | $(@($model.properties).Count) | $([string]$model.type) | $source |"
    }

    $detailedModels = @($Models | Select-Object -First $MaxDetailedModels)
    $modelRows = @()
    foreach ($model in $detailedModels) {
        $fieldsCount = @($model.properties).Count
        $typesSummary = if ($fieldsCount -gt 0) {
            ($model.properties[0..([Math]::Min(2, $fieldsCount - 1))] | ForEach-Object {
                if ($_ -match ':') { $_.Split(':')[1].Trim() } else { 'unknown' }
            }) -join ', '
        } else {
            'N/A'
        }
        if ($fieldsCount -gt 3) { $typesSummary += "..." }

        $description = "$([string]$model.type) from $([string]$model.filePath):$([int]$model.lineNumber)"
        $constraints = if ($model.example) { "See example" } else { "N/A" }
        $modelRows += "| ``$([string]$model.name)`` | $fieldsCount | $typesSummary | $description | $constraints | N/A |"
    }

    $totalProperties = ($Models | ForEach-Object { @($_.properties).Count } | Measure-Object -Sum).Sum
    $averageProperties = [Math]::Round((($Models | ForEach-Object { @($_.properties).Count } | Measure-Object -Average).Average), 1)
    $typeDistribution = ($Models | Group-Object type | ForEach-Object { "- $($_.Name): $($_.Count)" }) -join "`n"

    return @"
### Domain Summary

$($domainSummaryTable -join "`n")

### Top Entities by Field Count

$($topModelTable -join "`n")

### Detailed Inventory

| Model Name | Fields | Types | Description | Constraints | Indexes |
|------------|--------|-------|-------------|-------------|---------|
$($modelRows -join "`n")

_Detailed inventory is capped to first $($detailedModels.Count) models for readability. Full model evidence is preserved in_ ``docs/evidence/data-model.evidence.json``.

**Statistics:**
- Total Models: $($Models.Count)
- Total Properties: $totalProperties
- Average Properties per Model: $averageProperties

**Type Distribution:**
$typeDistribution
"@
}

function Update-AppDocDataModelContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$ModelContent
    )

    $placeholder = @"
| Model Name | Fields | Types | Description | Constraints | Indexes |
|------------|--------|-------|-------------|-------------|---------|

_No data models detected. This codebase may use dynamic structures or patterns not yet recognized by the scanner._
"@

    $updated = $Content
    if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $placeholder -NewContent $ModelContent
    }

    $pattern = '(?s)(##\s+Data Models\s*\r?\n\r?\n).*'
    return [regex]::Replace(
        $updated,
        $pattern,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $ModelContent + "`r`n")
        }
    )
}

Export-ModuleMember -Function @(
    'Get-AppDocDataModelMarkdown',
    'Update-AppDocDataModelContent'
)
