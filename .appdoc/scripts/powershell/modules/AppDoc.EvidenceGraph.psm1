# AppDoc.EvidenceGraph Module
# Purpose: Build a canonical deterministic evidence graph from artifact evidence payloads.

$script:AppDocEvidenceGraphVersion = "1.0.0"
$script:AppDocEvidenceGraphSchemaVersion = "appdoc-evidence-graph/v1"

$determinismModulePath = Join-Path $PSScriptRoot "AppDoc.Determinism.psm1"
if (Test-Path $determinismModulePath) {
    try {
        Import-Module $determinismModulePath -Force | Out-Null
    }
    catch {
        Write-Verbose ("Failed to import determinism module: {0}" -f $_.Exception.Message)
    }
}

$scopeModulePath = Join-Path $PSScriptRoot "AppDoc.Scope.psm1"
if (Test-Path $scopeModulePath) {
    try {
        Import-Module $scopeModulePath -Force -ErrorAction SilentlyContinue | Out-Null
    }
    catch {
        Write-Verbose ("Failed to import scope module: {0}" -f $_.Exception.Message)
    }
}

function Get-AppDocEvidenceGraphValue {
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
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Get-AppDocEvidenceGraphContract {
    [CmdletBinding()]
    param()

    return [ordered]@{
        version = $script:AppDocEvidenceGraphVersion
        schemaVersion = $script:AppDocEvidenceGraphSchemaVersion
        entityTypes = @(
            "system",
            "component",
            "endpoint_inbound",
            "endpoint_outbound",
            "data_model",
            "config_key",
            "dependency",
            "test_case"
        )
        edgeTypes = @(
            "calls",
            "reads",
            "writes",
            "maps_to_config",
            "serializes",
            "depends_on",
            "validated_by"
        )
        artifacts = @(
            [ordered]@{ name = "api-inventory"; kinds = @("endpoint") }
            [ordered]@{ name = "data-model"; kinds = @("model") }
            [ordered]@{ name = "config-catalog"; kinds = @("configuration", "environment-variable") }
            [ordered]@{ name = "dependencies-catalog"; kinds = @("dependency") }
            [ordered]@{ name = "test-catalog"; kinds = @("test-case", "test-suite", "test", "suite", "parameterized test") }
        )
        determinism = [ordered]@{
            canonicalOrdering = @(
                "entities:type,name,id",
                "edges:type,from,to,id"
            )
            stableIdAlgorithm = "sha1(prefix|seed)[0:8]"
        }
    }
}

function ConvertTo-AppDocEvidenceGraphId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prefix,
        [Parameter(Mandatory=$true)]
        [string]$Seed
    )

    $value = if ([string]::IsNullOrWhiteSpace($Seed)) { "item" } else { $Seed.Trim() }
    $slug = [regex]::Replace($value.ToLowerInvariant(), '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($slug)) { $slug = "item" }
    if ($slug.Length -gt 42) { $slug = $slug.Substring(0, 42).Trim('_') }

    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $hashBytes = $sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($value.ToLowerInvariant()))
    }
    finally {
        $sha1.Dispose()
    }
    $hashHex = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
    $hashShort = $hashHex.Substring(0, 8)

    return "{0}_{1}_{2}" -f $Prefix, $slug, $hashShort
}

function Get-AppDocEvidenceGraphRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (Get-Command Get-AppDocRelativePath -ErrorAction SilentlyContinue) {
        return (Get-AppDocRelativePath -RootPath $RootPath -Path $Path)
    }

    $rootNorm = $RootPath.TrimEnd('\', '/')
    $pathNorm = $Path.TrimEnd('\', '/')
    if ($pathNorm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $pathNorm.Substring($rootNorm.Length).TrimStart('\', '/').Replace('\', '/')
    }
    return $pathNorm.Replace('\', '/')
}

function Get-AppDocEvidenceGraphArtifactPayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Artifact
    )

    $evidenceDir = Join-Path (Join-Path $RootPath "docs") "evidence"
    $path = Join-Path $evidenceDir ("{0}.evidence.json" -f $Artifact)
    if (-not (Test-Path $path)) {
        return [ordered]@{
            artifact = $Artifact
            path = $path
            relativePath = (Get-AppDocEvidenceGraphRelativePath -RootPath $RootPath -Path $path)
            exists = $false
            records = @()
            recordCount = 0
        }
    }

    try {
        $payload = Get-Content -Path $path -Raw | ConvertFrom-Json -Depth 120
        $records = @(
            Get-AppDocEvidenceGraphValue -Object $payload -Name "records" -Default @() |
                Where-Object { $_ }
        )
        return [ordered]@{
            artifact = $Artifact
            path = $path
            relativePath = (Get-AppDocEvidenceGraphRelativePath -RootPath $RootPath -Path $path)
            exists = $true
            records = $records
            recordCount = $records.Count
        }
    }
    catch {
        return [ordered]@{
            artifact = $Artifact
            path = $path
            relativePath = (Get-AppDocEvidenceGraphRelativePath -RootPath $RootPath -Path $path)
            exists = $true
            records = @()
            recordCount = 0
            parseError = $_.Exception.Message
        }
    }
}

function Get-AppDocEvidenceGraphEndpointDirection {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Record
    )

    $metadata = Get-AppDocEvidenceGraphValue -Object $Record -Name "metadata" -Default @{}
    $direction = [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "direction" -Default "")
    if ($direction -match '^(?i)(inbound|outbound)$') {
        return $direction.ToLowerInvariant()
    }

    $sourceType = [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "sourceType" -Default "")
    $name = [string](Get-AppDocEvidenceGraphValue -Object $Record -Name "name" -Default "")
    $source = [string](Get-AppDocEvidenceGraphValue -Object $Record -Name "source" -Default "")

    if ($sourceType -match '^(?i)(soap-client|wcf-client|asmx-client|proxy-client)$' -or
        $name -match '^/soap-client/' -or
        $source -match '(?i)(?:^|[\\/])(Service References|Connected Services|Web References)(?:[\\/]|$)') {
        return "outbound"
    }

    return "inbound"
}

function Get-AppDocEvidenceGraphComponentName {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Record
    )

    $metadata = Get-AppDocEvidenceGraphValue -Object $Record -Name "metadata" -Default @{}
    $componentCandidates = @(
        [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "component" -Default ""),
        [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "controller" -Default ""),
        [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "service" -Default ""),
        [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "class" -Default ""),
        [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "className" -Default "")
    )

    foreach ($candidate in $componentCandidates) {
        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            return ($candidate.Trim())
        }
    }

    return "Core Processing"
}

function New-AppDocEvidenceGraphEntity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Type,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [string]$Artifact = "",
        [string]$Source = "",
        [double]$Confidence = 1.0,
        [hashtable]$Attributes = @{}
    )

    $id = ConvertTo-AppDocEvidenceGraphId -Prefix $Type -Seed $Name
    return [ordered]@{
        id = $id
        type = $Type
        name = $Name
        artifact = $Artifact
        source = $Source
        confidence = [Math]::Round([Math]::Max(0, [Math]::Min(1, $Confidence)), 4)
        attributes = $Attributes
    }
}

function New-AppDocEvidenceGraphEdge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Type,
        [Parameter(Mandatory=$true)]
        [string]$From,
        [Parameter(Mandatory=$true)]
        [string]$To,
        [string]$Label = "",
        [string]$Artifact = "",
        [double]$Confidence = 1.0
    )

    $seed = "{0}|{1}|{2}|{3}" -f $Type, $From, $To, $Label
    return [ordered]@{
        id = ConvertTo-AppDocEvidenceGraphId -Prefix "edge" -Seed $seed
        type = $Type
        from = $From
        to = $To
        label = $Label
        artifact = $Artifact
        confidence = [Math]::Round([Math]::Max(0, [Math]::Min(1, $Confidence)), 4)
    }
}

function Get-AppDocEvidenceGraphData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowEmptyCollection()]
        [string[]]$Artifacts = @()
    )

    $contract = Get-AppDocEvidenceGraphContract
    $contractArtifacts = @($contract.artifacts)
    if ($Artifacts -and $Artifacts.Count -gt 0) {
        $normalized = @($Artifacts | ForEach-Object { ([string]$_).Trim() } | Where-Object { $_ } | Select-Object -Unique)
        $contractArtifacts = @(
            $contractArtifacts |
                Where-Object { $normalized -contains [string]$_.name }
        )
    }

    $projectName = Split-Path -Path $RootPath -Leaf
    if ([string]::IsNullOrWhiteSpace($projectName)) { $projectName = "repository" }

    $entityMap = @{}
    $edgeMap = @{}
    $artifactSourceList = @()

    $addEntity = {
        param([hashtable]$Entity)
        if (-not $Entity -or -not $Entity.id) { return }
        $id = [string]$Entity.id
        if (-not $entityMap.ContainsKey($id)) {
            $entityMap[$id] = $Entity
            return
        }

        $existing = $entityMap[$id]
        $existingConfidence = [double](Get-AppDocEvidenceGraphValue -Object $existing -Name "confidence" -Default 0)
        $newConfidence = [double](Get-AppDocEvidenceGraphValue -Object $Entity -Name "confidence" -Default 0)
        if ($newConfidence -gt $existingConfidence) {
            $existing.confidence = [Math]::Round($newConfidence, 4)
        }

        $existingSources = @(
            (Get-AppDocEvidenceGraphValue -Object $existing -Name "attributes" -Default @{}).sources
        )
        $incomingSources = @(
            (Get-AppDocEvidenceGraphValue -Object $Entity -Name "attributes" -Default @{}).sources
        )
        $mergedSources = @($existingSources + $incomingSources | Where-Object { $_ } | Select-Object -Unique | Sort-Object)
        if ($mergedSources.Count -gt 0) {
            $existing.attributes.sources = $mergedSources
        }
    }

    $addEdge = {
        param([hashtable]$Edge)
        if (-not $Edge -or -not $Edge.id) { return }
        $id = [string]$Edge.id
        if (-not $edgeMap.ContainsKey($id)) {
            $edgeMap[$id] = $Edge
            return
        }

        $existing = $edgeMap[$id]
        $existingConfidence = [double](Get-AppDocEvidenceGraphValue -Object $existing -Name "confidence" -Default 0)
        $newConfidence = [double](Get-AppDocEvidenceGraphValue -Object $Edge -Name "confidence" -Default 0)
        if ($newConfidence -gt $existingConfidence) {
            $existing.confidence = [Math]::Round($newConfidence, 4)
        }
    }

    $componentIdByName = @{}
    $getComponentId = {
        param(
            [string]$Name,
            [string]$Source = "",
            [string]$Artifact = ""
        )

        $componentName = if ([string]::IsNullOrWhiteSpace($Name)) { "Core Processing" } else { $Name.Trim() }
        $componentKey = $componentName.ToLowerInvariant()
        if ($componentIdByName.ContainsKey($componentKey)) {
            return [string]$componentIdByName[$componentKey]
        }

        $entity = New-AppDocEvidenceGraphEntity -Type "component" -Name $componentName -Artifact $Artifact -Source $Source -Attributes @{
            sources = @($Source)
        }
        & $addEntity $entity
        $componentIdByName[$componentKey] = [string]$entity.id
        return [string]$entity.id
    }

    $systemEntity = New-AppDocEvidenceGraphEntity -Type "system" -Name $projectName -Artifact "overview" -Source "repository" -Attributes @{
        role = "root-system"
    }
    & $addEntity $systemEntity
    $systemId = [string]$systemEntity.id

    foreach ($artifactSpec in $contractArtifacts) {
        $artifactName = [string]$artifactSpec.name
        $payload = Get-AppDocEvidenceGraphArtifactPayload -RootPath $RootPath -Artifact $artifactName
        $artifactSourceList += [ordered]@{
            artifact = $artifactName
            path = [string]$payload.relativePath
            exists = [bool]$payload.exists
            recordCount = [int]$payload.recordCount
            parseError = [string](Get-AppDocEvidenceGraphValue -Object $payload -Name "parseError" -Default "")
        }

        $records = @($payload.records)
        foreach ($record in $records) {
            if (-not $record) { continue }
            $kind = ([string](Get-AppDocEvidenceGraphValue -Object $record -Name "kind" -Default "")).Trim().ToLowerInvariant()
            if ([string]::IsNullOrWhiteSpace($kind)) { continue }

            $name = [string](Get-AppDocEvidenceGraphValue -Object $record -Name "name" -Default "")
            $source = [string](Get-AppDocEvidenceGraphValue -Object $record -Name "source" -Default "")
            $confidence = [double](Get-AppDocEvidenceGraphValue -Object $record -Name "confidence" -Default 1.0)
            $metadata = Get-AppDocEvidenceGraphValue -Object $record -Name "metadata" -Default @{}

            switch -Regex ($kind) {
                '^endpoint$' {
                    $direction = Get-AppDocEvidenceGraphEndpointDirection -Record $record
                    $method = [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "method" -Default "ANY")
                    if ([string]::IsNullOrWhiteSpace($method)) { $method = "ANY" }
                    $path = [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "path" -Default "")
                    if ([string]::IsNullOrWhiteSpace($path)) { $path = $name }
                    $endpointName = "{0} {1}" -f $method.ToUpperInvariant(), $path

                    $entityType = if ($direction -eq "outbound") { "endpoint_outbound" } else { "endpoint_inbound" }
                    $endpointEntity = New-AppDocEvidenceGraphEntity -Type $entityType -Name $endpointName -Artifact $artifactName -Source $source -Confidence $confidence -Attributes @{
                        method = $method.ToUpperInvariant()
                        path = $path
                        direction = $direction
                        sourceType = [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "sourceType" -Default "")
                        sources = @($source)
                    }
                    & $addEntity $endpointEntity

                    $componentName = Get-AppDocEvidenceGraphComponentName -Record $record
                    $componentId = & $getComponentId $componentName $source $artifactName

                    if ($direction -eq "inbound") {
                        $edge = New-AppDocEvidenceGraphEdge -Type "calls" -From $endpointEntity.id -To $componentId -Label $endpointName -Artifact $artifactName -Confidence $confidence
                    }
                    else {
                        $edge = New-AppDocEvidenceGraphEdge -Type "calls" -From $componentId -To $endpointEntity.id -Label $endpointName -Artifact $artifactName -Confidence $confidence
                    }
                    & $addEdge $edge
                    continue
                }
                '^model$' {
                    $modelName = if ([string]::IsNullOrWhiteSpace($name)) { "unknown-model" } else { $name }
                    $modelEntity = New-AppDocEvidenceGraphEntity -Type "data_model" -Name $modelName -Artifact $artifactName -Source $source -Confidence $confidence -Attributes @{
                        sources = @($source)
                    }
                    & $addEntity $modelEntity

                    $componentName = Get-AppDocEvidenceGraphComponentName -Record $record
                    $componentId = & $getComponentId $componentName $source $artifactName
                    $edge = New-AppDocEvidenceGraphEdge -Type "serializes" -From $componentId -To $modelEntity.id -Label $modelName -Artifact $artifactName -Confidence $confidence
                    & $addEdge $edge
                    continue
                }
                '^(configuration|environment-variable)$' {
                    $configName = if ([string]::IsNullOrWhiteSpace($name)) { [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "key" -Default "") } else { $name }
                    if ([string]::IsNullOrWhiteSpace($configName)) { $configName = "unknown-config" }
                    $configEntity = New-AppDocEvidenceGraphEntity -Type "config_key" -Name $configName -Artifact $artifactName -Source $source -Confidence $confidence -Attributes @{
                        classification = [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "classification" -Default "")
                        sources = @($source)
                    }
                    & $addEntity $configEntity

                    $componentName = Get-AppDocEvidenceGraphComponentName -Record $record
                    $componentId = & $getComponentId $componentName $source $artifactName
                    $edge = New-AppDocEvidenceGraphEdge -Type "maps_to_config" -From $componentId -To $configEntity.id -Label $configName -Artifact $artifactName -Confidence $confidence
                    & $addEdge $edge
                    continue
                }
                '^dependency$' {
                    $depName = if ([string]::IsNullOrWhiteSpace($name)) { "unknown-dependency" } else { $name }
                    $depEntity = New-AppDocEvidenceGraphEntity -Type "dependency" -Name $depName -Artifact $artifactName -Source $source -Confidence $confidence -Attributes @{
                        version = [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "version" -Default "")
                        sources = @($source)
                    }
                    & $addEntity $depEntity

                    $componentName = Get-AppDocEvidenceGraphComponentName -Record $record
                    $componentId = & $getComponentId $componentName $source $artifactName
                    $edge = New-AppDocEvidenceGraphEdge -Type "depends_on" -From $componentId -To $depEntity.id -Label $depName -Artifact $artifactName -Confidence $confidence
                    & $addEdge $edge
                    continue
                }
                '^(test-case|test-suite|test|suite|parameterized test)$' {
                    $testName = if ([string]::IsNullOrWhiteSpace($name)) { "unnamed-test" } else { $name }
                    $testEntity = New-AppDocEvidenceGraphEntity -Type "test_case" -Name $testName -Artifact $artifactName -Source $source -Confidence $confidence -Attributes @{
                        testKind = $kind
                        framework = [string](Get-AppDocEvidenceGraphValue -Object $metadata -Name "framework" -Default "")
                        sources = @($source)
                    }
                    & $addEntity $testEntity

                    $componentName = Get-AppDocEvidenceGraphComponentName -Record $record
                    $componentId = & $getComponentId $componentName $source $artifactName
                    $edge = New-AppDocEvidenceGraphEdge -Type "validated_by" -From $componentId -To $testEntity.id -Label $testName -Artifact $artifactName -Confidence $confidence
                    & $addEdge $edge
                    continue
                }
                default { continue }
            }
        }
    }

    if (-not $componentIdByName.ContainsKey("core processing")) {
        $coreId = & $getComponentId "Core Processing" "repository" "overview"
        [void]$coreId
    }

    $entities = @(
        $entityMap.Values |
            Sort-Object `
                @{ Expression = { [string]$_.type } }, `
                @{ Expression = { [string]$_.name } }, `
                @{ Expression = { [string]$_.id } }
    )
    $edges = @(
        $edgeMap.Values |
            Sort-Object `
                @{ Expression = { [string]$_.type } }, `
                @{ Expression = { [string]$_.from } }, `
                @{ Expression = { [string]$_.to } }, `
                @{ Expression = { [string]$_.id } }
    )

    $countByType = @{}
    foreach ($type in @($contract.entityTypes)) {
        $countByType[$type] = @($entities | Where-Object { [string]$_.type -eq $type }).Count
    }

    return [ordered]@{
        schemaVersion = $contract.schemaVersion
        graphVersion = $contract.version
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        project = [ordered]@{
            name = $projectName
            rootPath = "."
        }
        sources = @($artifactSourceList | Sort-Object @{ Expression = { [string]$_.artifact } })
        entities = $entities
        edges = $edges
        metrics = [ordered]@{
            entityCount = $entities.Count
            edgeCount = $edges.Count
            entityTypeCount = $countByType
            inboundEndpointCount = [int]$countByType["endpoint_inbound"]
            outboundEndpointCount = [int]$countByType["endpoint_outbound"]
            componentCount = [int]$countByType["component"]
            modelCount = [int]$countByType["data_model"]
            configCount = [int]$countByType["config_key"]
            dependencyCount = [int]$countByType["dependency"]
            testCaseCount = [int]$countByType["test_case"]
        }
        determinism = $contract.determinism
    }
}

function Write-AppDocEvidenceGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowNull()]
        [object]$GraphData = $null
    )

    if ($null -eq $GraphData) {
        $GraphData = Get-AppDocEvidenceGraphData -RootPath $RootPath
    }

    $evidenceDir = Join-Path (Join-Path $RootPath "docs") "evidence"
    if (-not (Test-Path $evidenceDir)) {
        New-Item -Path $evidenceDir -ItemType Directory -Force | Out-Null
    }

    $outputPath = Join-Path $evidenceDir "evidence-graph.json"
    $payload = [ordered]@{}
    if ($GraphData -is [System.Collections.IDictionary]) {
        foreach ($key in @($GraphData.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
            $payload[$key] = $GraphData[$key]
        }
    }
    else {
        foreach ($prop in @($GraphData.PSObject.Properties | Sort-Object Name)) {
            $payload[$prop.Name] = $prop.Value
        }
    }

    if (Get-Command Get-AppDocDeterministicHash -ErrorAction SilentlyContinue) {
        $excludeKeys = @("generatedAt", "updatedAt", "timestamp")
        $payload.determinismHash = [ordered]@{
            hashAlgorithm = "SHA256"
            excludeKeys = $excludeKeys
            contentHash = Get-AppDocDeterministicHash -InputObject $payload -ExcludeKeys $excludeKeys
        }
    }

    $payload | ConvertTo-Json -Depth 80 | Out-File -FilePath $outputPath -Encoding UTF8
    return $outputPath
}

function Test-AppDocEvidenceGraphIntegrity {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowNull()]
        [object]$GraphData = $null
    )

    if ($null -eq $GraphData) {
        $graphPath = Join-Path (Join-Path (Join-Path $RootPath "docs") "evidence") "evidence-graph.json"
        if (Test-Path $graphPath) {
            try {
                $GraphData = Get-Content -Path $graphPath -Raw | ConvertFrom-Json -Depth 120
            }
            catch {
                return [ordered]@{
                    passed = $false
                    issues = @("Unable to parse evidence graph JSON: $($_.Exception.Message)")
                    warnings = @()
                    metrics = @{}
                }
            }
        }
        else {
            $GraphData = Get-AppDocEvidenceGraphData -RootPath $RootPath
        }
    }

    $contract = Get-AppDocEvidenceGraphContract
    $issues = @()
    $warnings = @()

    $schemaVersion = [string](Get-AppDocEvidenceGraphValue -Object $GraphData -Name "schemaVersion" -Default "")
    if ($schemaVersion -ne [string]$contract.schemaVersion) {
        $issues += ("schemaVersion mismatch (expected '{0}', got '{1}')" -f [string]$contract.schemaVersion, $schemaVersion)
    }

    $entities = @(
        Get-AppDocEvidenceGraphValue -Object $GraphData -Name "entities" -Default @() |
            Where-Object { $_ }
    )
    $edges = @(
        Get-AppDocEvidenceGraphValue -Object $GraphData -Name "edges" -Default @() |
            Where-Object { $_ }
    )

    $entityIds = @{}
    foreach ($entity in $entities) {
        $id = [string](Get-AppDocEvidenceGraphValue -Object $entity -Name "id" -Default "")
        $type = [string](Get-AppDocEvidenceGraphValue -Object $entity -Name "type" -Default "")
        if ([string]::IsNullOrWhiteSpace($id)) {
            $issues += "Entity with missing id detected."
            continue
        }
        if ($entityIds.ContainsKey($id)) {
            $issues += ("Duplicate entity id detected: {0}" -f $id)
            continue
        }
        $entityIds[$id] = $true

        if (-not ($contract.entityTypes -contains $type)) {
            $issues += ("Unsupported entity type detected: {0}" -f $type)
        }
    }

    foreach ($edge in $edges) {
        $edgeType = [string](Get-AppDocEvidenceGraphValue -Object $edge -Name "type" -Default "")
        $from = [string](Get-AppDocEvidenceGraphValue -Object $edge -Name "from" -Default "")
        $to = [string](Get-AppDocEvidenceGraphValue -Object $edge -Name "to" -Default "")

        if (-not ($contract.edgeTypes -contains $edgeType)) {
            $issues += ("Unsupported edge type detected: {0}" -f $edgeType)
        }
        if (-not [string]::IsNullOrWhiteSpace($from) -and -not $entityIds.ContainsKey($from)) {
            $issues += ("Edge references missing source entity: {0}" -f $from)
        }
        if (-not [string]::IsNullOrWhiteSpace($to) -and -not $entityIds.ContainsKey($to)) {
            $issues += ("Edge references missing target entity: {0}" -f $to)
        }
    }

    $metrics = Get-AppDocEvidenceGraphValue -Object $GraphData -Name "metrics" -Default @{}
    $inboundEndpointCount = [int](Get-AppDocEvidenceGraphValue -Object $metrics -Name "inboundEndpointCount" -Default 0)
    $outboundEndpointCount = [int](Get-AppDocEvidenceGraphValue -Object $metrics -Name "outboundEndpointCount" -Default 0)

    $fingerprintPath = Join-Path $RootPath "docs\architecture-fingerprint.json"
    if (Test-Path $fingerprintPath) {
        try {
            $fingerprint = Get-Content -Path $fingerprintPath -Raw | ConvertFrom-Json -Depth 60
            $apiExpected = [bool](Get-AppDocEvidenceGraphValue -Object $fingerprint -Name "apiSurfaceExpected" -Default $true)
            if ($apiExpected -and ($inboundEndpointCount + $outboundEndpointCount -eq 0)) {
                $issues += "Architecture fingerprint expects API surface but evidence graph contains zero endpoints."
            }
            if ((-not $apiExpected) -and ($inboundEndpointCount + $outboundEndpointCount -gt 0)) {
                $warnings += "Architecture fingerprint indicates no API surface while evidence graph has endpoint entities."
            }
        }
        catch {
            $warnings += ("Unable to parse architecture-fingerprint.json for graph expectation checks: {0}" -f $_.Exception.Message)
        }
    }

    return [ordered]@{
        passed = ($issues.Count -eq 0)
        issues = @($issues | Select-Object -Unique)
        warnings = @($warnings | Select-Object -Unique)
        metrics = [ordered]@{
            entityCount = $entities.Count
            edgeCount = $edges.Count
            inboundEndpointCount = $inboundEndpointCount
            outboundEndpointCount = $outboundEndpointCount
        }
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocEvidenceGraphContract',
    'Get-AppDocEvidenceGraphData',
    'Write-AppDocEvidenceGraph',
    'Test-AppDocEvidenceGraphIntegrity'
)
