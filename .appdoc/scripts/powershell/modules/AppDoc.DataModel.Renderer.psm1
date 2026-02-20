## Module-scoped placeholder for data model table
$script:DataModelPlaceholder = @"
| Model Name | Fields | Types | Description | Constraints | Indexes |
|------------|--------|-------|-------------|-------------|---------|

_No data models detected. This codebase may use dynamic structures or patterns not yet recognized by the scanner._
"@

function Get-AppDocDataModelMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Models,
        [int]$MaxDetailedModels = 120
    )

    if (-not $Models -or $Models.Count -eq 0) {
        return $script:DataModelPlaceholder
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
                $entry = $_
                if ($null -eq $entry) {
                    'unknown'
                } elseif ($entry -is [string]) {
                    if ($entry -match ':') {
                        $parts = $entry.Split(':', 2)
                        if ($parts.Count -ge 2 -and $parts[1].Trim()) { $parts[1].Trim() } else { 'unknown' }
                    } else {
                        'unknown'
                    }
                } elseif ($entry.PSObject.Properties['type']) {
                    $entry.type
                } elseif ($entry.PSObject.Properties['Type']) {
                    $entry.Type
                } else {
                    'unknown'
                }
            }) -join ', '
        } else {
            'N/A'
        }
        if ($fieldsCount -gt 3) { $typesSummary += "..." }

        $description = "$([string]$model.type) from $([string]$model.filePath):$([int]$model.lineNumber)"
        $constraints = if ($model.example) { "See example" } else { "N/A" }
        $modelRows += "| ``$([string]$model.name)`` | $fieldsCount | $typesSummary | $description | $constraints | N/A |"
    }

    $propertyCounts = $Models | ForEach-Object { @($_.properties).Count }
    $propertyStats = $propertyCounts | Measure-Object -Sum -Average
    $totalProperties = $propertyStats.Sum
    $averageProperties = [Math]::Round(($propertyStats.Average), 1)
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


    $placeholder = $script:DataModelPlaceholder

    $updated = $Content

    if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $placeholder -NewContent $ModelContent
    } elseif ($updated -and $placeholder -and $updated.Contains($placeholder)) {
        $updated = $updated.Replace($placeholder, $ModelContent)
    }

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Data Models\s*\r?\n\r?\n).*?(?=\r?\n##\s+[^\r\n]+|\z)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $ModelContent + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Overview\s*\r?\n\r?\n).*?(?=\r?\n##\s+Data Models\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "This catalog is extracted from model/type declarations and grouped by domain, model size, and structural shape to support impact analysis and refactoring." + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Validation Rules\s*\r?\n\r?\n).*?(?=\r?\n##\s+Indexes and Performance\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Validation rules are mostly implemented in business logic and model usage paths rather than centralized schema annotations. Use model call-sites and domain services to confirm runtime validation behavior." + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Indexes and Performance\s*\r?\n\r?\n).*?(?=\r?\n##\s+Data Flow Patterns\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Index and persistence-performance metadata are not directly available from type extraction alone. Pair this catalog with database artifacts and query traces when assessing performance risk." + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Data Flow Patterns\s*\r?\n\r?\n).*?(?=\r?\n##\s+Schema Evolution\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Model flow is inferred through controller/service usage rather than fully reconstructed as end-to-end pipelines in this artifact. Use API and component hotspots in [System Overview](overview.md) to map key data movement paths." + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Schema Evolution\s*\r?\n\r?\n).*?(?=\r?\n##\s+Example Instances\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Historical schema evolution evidence is out of scope for this deterministic scan. Use migration history, release notes, and git history to track breaking or structural model changes." + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Example Instances\s*\r?\n\r?\n).*?(?=(\r?\n##\s+)|\z)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Concrete example instances were not extracted automatically. Derive practical examples from representative controller actions and test fixtures that construct these models." + "`r`n")
        }
    )

    # Ensure stale empty-detection placeholder text is fully removed after population.
    $updated = $updated -replace '(?im)^_No data models detected\..*?_$', ''
    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocDataModelMarkdown',
    'Update-AppDocDataModelContent'
)
