# AppDoc.Overview.ContextPack Module
# Purpose: Build a versioned, normalized narrative context pack from deterministic overview truth data.

$script:AppDocOverviewContextPackVersion = "3.0.0"

function Get-AppDocOverviewContextPackValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Object,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [AllowNull()]
        [object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) {
        return $prop.Value
    }

    return $Default
}

function ConvertTo-AppDocOverviewContextArray {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @([string]$Value)
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @()
        foreach ($item in $Value) {
            if ($null -ne $item) { $items += $item }
        }
        return @($items)
    }

    return @($Value)
}

function Normalize-AppDocOverviewPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return "" }
    $normalized = $Path -replace '\\', '/'
    if ($normalized -like 'file:///*') {
        # Preserve three slashes for file URIs, only collapse after prefix
        $prefix = 'file:///'
        $rest = $normalized.Substring($prefix.Length)
        $restCollapsed = $rest -replace '/{2,}', '/'
        $normalized = $prefix + $restCollapsed
    } else {
        # collapse duplicate slash but preserve URL protocol separator (e.g. https://)
        $normalized = $normalized -replace '(?<!:)/{2,}', '/'
    }
    return $normalized.Trim()
}

function Get-AppDocOverviewEntityType {
    [CmdletBinding()]
    param([string]$Kind)

    switch ($Kind) {
        "endpoint" { return "endpoint" }
        "model" { return "model" }
        "configuration" { return "config" }
        "dependency" { return "dep" }
        default { return "signal" }
    }
}

function New-AppDocOverviewIntentCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Id,
        [Parameter(Mandatory=$true)]
        [string]$Type,
        [Parameter(Mandatory=$true)]
        [string]$Text,
        [AllowEmptyCollection()]
        [string[]]$EvidenceIds = @()
    )

    return [ordered]@{
        id = $Id
        type = $Type
        text = $Text
        evidence_ids = @(
            $EvidenceIds |
                Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
                Select-Object -Unique
        )
    }
}

function Get-AppDocOverviewContextPackData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [object]$TruthPack,
        [ValidateSet("new_dev","senior_dev","sre")]
        [string]$Audience = "new_dev",
        [ValidateSet("concise","standard","pedagogical")]
        [string]$StyleProfile = "standard"
    )

    $projectName = [string](Get-AppDocOverviewContextPackValue -Object $TruthPack -Name "projectName" -Default (Split-Path $RootPath -Leaf))
    $evidenceRefs = @(Get-AppDocOverviewContextPackValue -Object $TruthPack -Name "evidence_refs" -Default @())
    $facts = Get-AppDocOverviewContextPackValue -Object $TruthPack -Name "facts" -Default @{}
    $counts = Get-AppDocOverviewContextPackValue -Object $TruthPack -Name "counts" -Default @{}
    $graph = Get-AppDocOverviewContextPackValue -Object $TruthPack -Name "graph" -Default @{}

    $entities = @()
    $entityIndex = @{}
    $entityCounter = 1

    foreach ($evidence in $evidenceRefs) {
        if (-not $evidence) { continue }

        $kind = [string](Get-AppDocOverviewContextPackValue -Object $evidence -Name "kind" -Default "")
        $entityType = Get-AppDocOverviewEntityType -Kind $kind
        $name = Normalize-AppDocOverviewPath ([string](Get-AppDocOverviewContextPackValue -Object $evidence -Name "name" -Default ""))
        $source = Normalize-AppDocOverviewPath ([string](Get-AppDocOverviewContextPackValue -Object $evidence -Name "source" -Default ""))
        $evidenceId = [string](Get-AppDocOverviewContextPackValue -Object $evidence -Name "id" -Default "")
        if ([string]::IsNullOrWhiteSpace($evidenceId)) { continue }

        $key = "{0}|{1}|{2}" -f $entityType, $name, $source
        if (-not $entityIndex.ContainsKey($key)) {
            $entityId = "ent-{0}" -f $entityCounter.ToString("0000")
            $entityCounter++
            $entity = [ordered]@{
                id = $entityId
                type = $entityType
                name = $name
                source = $source
                evidence_ids = @($evidenceId)
            }

            $entities += $entity
            $entityIndex[$key] = $entity
        }
        else {
            $entity = $entityIndex[$key]
            if (-not (@($entity.evidence_ids) -contains $evidenceId)) {
                $entity.evidence_ids = @($entity.evidence_ids + $evidenceId)
            }
        }
    }

    $relations = @()
    foreach ($evidence in $evidenceRefs) {
        if (-not $evidence) { continue }

        $kind = [string](Get-AppDocOverviewContextPackValue -Object $evidence -Name "kind" -Default "")
        if ($kind -ne "endpoint") { continue }

        $name = Normalize-AppDocOverviewPath ([string](Get-AppDocOverviewContextPackValue -Object $evidence -Name "name" -Default ""))
        $source = Normalize-AppDocOverviewPath ([string](Get-AppDocOverviewContextPackValue -Object $evidence -Name "source" -Default ""))
        $entityKey = "endpoint|{0}|{1}" -f $name, $source
        if (-not $entityIndex.ContainsKey($entityKey)) { continue }

        $metadata = Get-AppDocOverviewContextPackValue -Object $evidence -Name "metadata" -Default @{}
        $integrationUrl = [string](Get-AppDocOverviewContextPackValue -Object $metadata -Name "integrationUrl" -Default "")
        if ([string]::IsNullOrWhiteSpace($integrationUrl)) { continue }

        $hostName = ""
        try {
            $uri = [Uri]$integrationUrl
            if ($uri -and $uri.Host) {
                $hostName = [string]$uri.Host
            }
        }
        catch {
            $hostName = ""
        }

        if ([string]::IsNullOrWhiteSpace($hostName)) { continue }

        $targetKey = "signal|{0}|integration-host" -f $hostName
        if (-not $entityIndex.ContainsKey($targetKey)) {
            $entityId = "ent-{0}" -f $entityCounter.ToString("0000")
            $entityCounter++
            $hostEntity = [ordered]@{
                id = $entityId
                type = "signal"
                name = $hostName
                source = "integration-host"
                evidence_ids = @()
            }
            $entities += $hostEntity
            $entityIndex[$targetKey] = $hostEntity
        }

        $fromEntity = $entityIndex[$entityKey]
        $toEntity = $entityIndex[$targetKey]
        $relations += [ordered]@{
            from = [string]$fromEntity.id
            to = [string]$toEntity.id
            type = "calls"
        }
    }

    $intentCandidates = @()
    $intentCounter = 1
    $factTypeMap = @{
        "what_it_does" = "business_purpose"
        "inputs" = "data_contract"
        "processing_steps" = "workflow"
        "outputs" = "data_contract"
        "external_systems" = "workflow"
        "confidence_notes" = "confidence_note"
    }

    $sectionEvidenceMap = [ordered]@{}
    foreach ($factSection in @("what_it_does","inputs","processing_steps","outputs","external_systems","confidence_notes")) {
        $items = @(Get-AppDocOverviewContextPackValue -Object $facts -Name $factSection -Default @())
        $sectionEvidenceMap[$factSection] = @()
        foreach ($item in $items) {
            if (-not $item) { continue }
            $text = [string](Get-AppDocOverviewContextPackValue -Object $item -Name "text" -Default "")
            if ([string]::IsNullOrWhiteSpace($text)) { continue }

            $ids = @(
                ConvertTo-AppDocOverviewContextArray -Value (Get-AppDocOverviewContextPackValue -Object $item -Name "evidence_refs" -Default @()) |
                    ForEach-Object { [string]$_ } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )

            $sectionEvidenceMap[$factSection] = @($sectionEvidenceMap[$factSection] + $ids | Select-Object -Unique)
            $intentType = if ($factTypeMap.ContainsKey($factSection)) { [string]$factTypeMap[$factSection] } else { "workflow" }
            $intentId = "intent-{0}" -f $intentCounter.ToString("0000")
            $intentCounter++
            $intentCandidates += New-AppDocOverviewIntentCandidate -Id $intentId -Type $intentType -Text $text -EvidenceIds $ids
        }
    }

    return [ordered]@{
        schema_version = $script:AppDocOverviewContextPackVersion
        generator_version = "generate-overview.ps1"
        generated_at = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        run_id = [Guid]::NewGuid().ToString()
        project = [ordered]@{
            name = $projectName
            root_path = $RootPath
            audience = $Audience
            style_profile = $StyleProfile
        }
        facts = [ordered]@{
            entities = @($entities)
            relations = @($relations)
        }
        intent_candidates = @($intentCandidates)
        section_evidence_defaults = $sectionEvidenceMap
        evidence_refs = @(
            $evidenceRefs |
                ForEach-Object {
                    $rawName = [string](Get-AppDocOverviewContextPackValue -Object $_ -Name "name" -Default "")
                    $rawSource = [string](Get-AppDocOverviewContextPackValue -Object $_ -Name "source" -Default "")
                    $normalizedName = Normalize-AppDocOverviewPath $rawName
                    $normalizedSource = Normalize-AppDocOverviewPath $rawSource
                    [ordered]@{
                        id = [string](Get-AppDocOverviewContextPackValue -Object $_ -Name "id" -Default "")
                        artifact = [string](Get-AppDocOverviewContextPackValue -Object $_ -Name "artifact" -Default "")
                        kind = [string](Get-AppDocOverviewContextPackValue -Object $_ -Name "kind" -Default "")
                        name = $rawName
                        source = $rawSource
                        normalized_name = $normalizedName
                        normalized_source = $normalizedSource
                    }
                }
        )
        constraints = [ordered]@{
            must_ground = $true
            no_invention = $true
            paragraph_level_evidence_preferred = $true
            section_level_evidence_allowed = $true
        }
        graph_summary = [ordered]@{
            enabled = [bool](Get-AppDocOverviewContextPackValue -Object $graph -Name "enabled" -Default $false)
            entity_count = [int](Get-AppDocOverviewContextPackValue -Object $graph -Name "entityCount" -Default 0)
            edge_count = [int](Get-AppDocOverviewContextPackValue -Object $graph -Name "edgeCount" -Default 0)
            endpoint_count = [int](Get-AppDocOverviewContextPackValue -Object $counts -Name "endpointRecords" -Default 0)
            model_count = [int](Get-AppDocOverviewContextPackValue -Object $counts -Name "modelRecords" -Default 0)
            config_count = [int](Get-AppDocOverviewContextPackValue -Object $counts -Name "configurationRecords" -Default 0)
            dependency_count = [int](Get-AppDocOverviewContextPackValue -Object $counts -Name "dependencyRecords" -Default 0)
        }
    }
}

function Write-AppDocOverviewContextPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [hashtable]$ContextPack
    )

    $evidenceDir = Join-Path $RootPath "docs" "evidence"
    if (-not (Test-Path $evidenceDir)) {
        New-Item -Path $evidenceDir -ItemType Directory -Force | Out-Null
    }

    $outputPath = Join-Path $evidenceDir "narrative-context-pack.json"
    $payload = [ordered]@{}
    foreach ($key in @($ContextPack.Keys)) {
        $payload[$key] = $ContextPack[$key]
    }

    if (Get-Command Get-AppDocDeterministicHash -ErrorAction SilentlyContinue) {
        $excludeKeys = @("generated_at", "run_id", "timestamp")
        $payload.determinism = [ordered]@{
            hashAlgorithm = "SHA256"
            excludeKeys = $excludeKeys
            contentHash = (Get-AppDocDeterministicHash -InputObject $payload -ExcludeKeys $excludeKeys)
        }
    }

    $payload | ConvertTo-Json -Depth 80 | Out-File -FilePath $outputPath -Encoding UTF8
    return $outputPath
}

Export-ModuleMember -Function @(
    'Get-AppDocOverviewContextPackData',
    'Write-AppDocOverviewContextPack'
)
