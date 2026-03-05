## Module-scoped placeholder for data model table
$script:DataModelPlaceholder = @"
| Model Name | Fields | Types | Description | Constraints | Schema Source |
|------------|--------|-------|-------------|-------------|---------------|

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

    $getRole = {
        param($model)
        $role = [string](& $getField $model 'role' '')
        if (-not [string]::IsNullOrWhiteSpace($role)) { return $role }

        $isGenerated = & $getField $model 'isGenerated' $null
        if ($null -ne $isGenerated -and [bool]$isGenerated) { return 'GeneratedProxy' }

        $path = [string]($model.filePath ?? "")
        $name = [string]($model.name ?? "")
        $type = [string]($model.type ?? "")

        if ($path -match '(?i)(?:^|[\\/])(generated|service references|connected services|reference\.cs|proxy|proxies)(?:[\\/]|$)' -or $name -match '(?i)(proxy|generated|reference)') {
            return 'GeneratedProxy'
        }
        if ($path -match '(?i)(?:^|[\\/])viewmodels?(?:[\\/]|$)') { return 'ViewModel' }
        if ($path -match '(?i)(?:^|[\\/])entities(?:[\\/]|$)') { return 'Entity' }
        if ($type -match '(?i)dto') { return 'DTO' }
        return 'Unknown'
    }

    $isInfrastructureModel = {
        param($model)
        $role = (& $getRole $model)
        return $role -eq 'GeneratedProxy'
    }

    $domainEntities = @($Models | Where-Object { -not (& $isInfrastructureModel $_) })
    $infrastructureEntities = @($Models | Where-Object { (& $isInfrastructureModel $_) })

    $highImpact = @(
        $domainEntities |
            Sort-Object @{ Expression = { @($_.properties).Count }; Descending = $true }, @{ Expression = { [string]$_.name } } |
            Select-Object -First 20
    )

    $highImpactTable = @(
        "| Model | Role | Fields | Domain | Source | Business Purpose |",
        "|-------|------|--------|--------|--------|------------------|"
    )
    foreach ($model in $highImpact) {
        $path = [string]$model.filePath
        $domain = "general"
        if ($path -match '^([^/\\]+)/') { $domain = $Matches[1] }
        $source = "{0}:{1}" -f $path, [int]$model.lineNumber
        $role = [string](& $getRole $model)
        $businessPurpose = [string](& $getField $model 'businessPurpose' '')
        if ([string]::IsNullOrWhiteSpace($businessPurpose)) {
            $businessPurpose = "Purpose unclear from available evidence — review $path."
        }
        $highImpactTable += "| ``$([string]$model.name)`` | $role | $(@($model.properties).Count) | $domain | $source | $businessPurpose |"
    }

    $infraTable = @(
        "| Model | Role | Type | Source | Business Purpose |",
        "|-------|------|------|--------|------------------|"
    )
    foreach ($model in ($infrastructureEntities | Select-Object -First 40)) {
        $source = "{0}:{1}" -f [string]$model.filePath, [int]$model.lineNumber
        $role = [string](& $getRole $model)
        $businessPurpose = [string](& $getField $model 'businessPurpose' '')
        if ([string]::IsNullOrWhiteSpace($businessPurpose)) {
            $businessPurpose = "Generated/infrastructure model; verify runtime usage from source."
        }
        $infraTable += "| ``$([string]$model.name)`` | $role | $([string]$model.type) | $source | $businessPurpose |"
    }

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
        "| Model | Role | Fields | Type | Source |",
        "|-------|------|--------|------|--------|"
    )
    foreach ($model in $topModels) {
        $source = "{0}:{1}" -f [string]$model.filePath, [int]$model.lineNumber
        $role = [string](& $getRole $model)
        $topModelTable += "| ``$([string]$model.name)`` | $role | $(@($model.properties).Count) | $([string]$model.type) | $source |"
    }

    $detailedModels = @($domainEntities | Select-Object -First $MaxDetailedModels)
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

        $description = [string](& $getField $model 'businessPurpose' '')
        if ([string]::IsNullOrWhiteSpace($description)) {
            $description = "$([string]$model.type) from $([string]$model.filePath):$([int]$model.lineNumber)"
        }
        $constraints = if ($model.example) { "See example" } else { "N/A" }
        $schemaSource = [string](& $getField $model 'schemaSource' 'N/A')
        if ([string]::IsNullOrWhiteSpace($schemaSource)) { $schemaSource = 'N/A' }
        $relationships = & $getField $model 'relationships' $null
        $relationshipSummary = 'N/A'
        if ($relationships) {
            $relList = @($relationships | ForEach-Object {
                if ($_ -is [System.Collections.IDictionary]) {
                    $target = [string]$_.target
                    $relType = [string]$_.type
                    if (-not [string]::IsNullOrWhiteSpace($target)) {
                        if (-not [string]::IsNullOrWhiteSpace($relType)) { "$target ($relType)" } else { $target }
                    }
                } elseif ($_.PSObject.Properties['target']) {
                    $target = [string]$_.target
                    $relType = [string]$_.type
                    if (-not [string]::IsNullOrWhiteSpace($target)) {
                        if (-not [string]::IsNullOrWhiteSpace($relType)) { "$target ($relType)" } else { $target }
                    }
                } else {
                    [string]$_
                }
            } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            if ($relList.Count -gt 0) { $relationshipSummary = ($relList -join ', ') }
        }
        $role = [string](& $getRole $model)
        $modelRows += "| ``$([string]$model.name)`` | $fieldsCount | $typesSummary | $description | $constraints | $schemaSource |"
        if ($relationshipSummary -ne 'N/A') {
            $modelRows += "|  ↳ Relationships |  |  | $relationshipSummary |  |  |"
        }
    }

    $propertyCounts = $domainEntities | ForEach-Object { @($_.properties).Count }
    $propertyStats = $propertyCounts | Measure-Object -Sum -Average
    $totalProperties = $propertyStats.Sum
    $averageProperties = [Math]::Round(($propertyStats.Average), 1)
    $infraPropertyCounts = $infrastructureEntities | ForEach-Object { @($_.properties).Count }
    $infraPropertyStats = $infraPropertyCounts | Measure-Object -Sum -Average
    $infraTotalProperties = $infraPropertyStats.Sum
    $infraAverageProperties = if ($infraPropertyStats.Average) { [Math]::Round($infraPropertyStats.Average, 1) } else { 0 }
    $typeDistributionDomain = ($domainEntities | Group-Object type | ForEach-Object { "- $($_.Name): $($_.Count)" }) -join "`n"
    $typeDistributionInfra = ($infrastructureEntities | Group-Object type | ForEach-Object { "- $($_.Name): $($_.Count)" }) -join "`n"

    return @"
### High-Impact Domain Entities

$($highImpactTable -join "`n")

### Domain Summary

$($domainSummaryTable -join "`n")

### Top Entities by Field Count

$($topModelTable -join "`n")

### Detailed Inventory

| Model Name | Fields | Types | Description | Constraints | Indexes |
|------------|--------|-------|-------------|-------------|---------|
$($modelRows -join "`n")

_Detailed inventory is capped to first $($detailedModels.Count) models for readability. Full model evidence is preserved in_ ``docs/evidence/data-model.evidence.json``.

### Infrastructure and Generated Proxies

$(if ($infrastructureEntities.Count -gt 0) { $infraTable -join "`n" } else { "No infrastructure/generated proxy models were detected in this scan." })

**Statistics:**
- Total Models: $($Models.Count)
- Domain Models: $($domainEntities.Count)
- Infrastructure/Generated Models: $($infrastructureEntities.Count)
- Total Properties (domain only): $totalProperties
- Average Properties per Model (domain only): $averageProperties
- Total Properties (infrastructure only): $infraTotalProperties
- Average Properties per Model (infrastructure only): $infraAverageProperties

**Type Distribution (domain only):**
$typeDistributionDomain

**Type Distribution (infrastructure only):**
$typeDistributionInfra
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
