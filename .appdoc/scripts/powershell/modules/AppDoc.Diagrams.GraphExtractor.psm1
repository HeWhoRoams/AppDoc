function Get-AppDocDiagramValue {
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

function Get-AppDocDiagramEvidencePayload {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$EvidenceRoot,
        [Parameter(Mandatory=$true)]
        [string]$Artifact
    )

    $path = Join-Path $EvidenceRoot ("{0}.evidence.json" -f $Artifact)
    if (-not (Test-Path $path)) {
        return [ordered]@{
            records = @()
            path = $path
            exists = $false
        }
    }

    try {
        $payload = Get-Content $path -Raw | ConvertFrom-Json -Depth 80
        $records = @(
            Get-AppDocDiagramValue -Object $payload -Name "records" -Default @() |
                Where-Object { $_ }
        )
        return [ordered]@{
            records = $records
            path = $path
            exists = $true
        }
    }
    catch {
        Write-Verbose ("Failed to parse evidence payload '{0}': {1}" -f $path, $_.Exception.Message)
        return [ordered]@{
            records = @()
            path = $path
            exists = $true
            parseError = $_.Exception.Message
        }
    }
}

function ConvertTo-AppDocDiagramId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Prefix,
        [Parameter(Mandatory=$true)]
        [string]$Seed
    )

    $text = if ([string]::IsNullOrWhiteSpace($Seed)) { "item" } else { $Seed.Trim().ToLowerInvariant() }
    $normalized = [regex]::Replace($text, '[^a-z0-9]+', '_').Trim('_')
    if ([string]::IsNullOrWhiteSpace($normalized)) { $normalized = "item" }

    $hashBytes = [System.Security.Cryptography.SHA1]::Create().ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))
    $hashHex = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
    $hashShort = $hashHex.Substring(0, 8)

    $baseLength = 22
    if ($normalized.Length -gt $baseLength) {
        $normalized = $normalized.Substring(0, $baseLength).Trim('_')
    }
    if ([string]::IsNullOrWhiteSpace($normalized)) { $normalized = "item" }

    return "{0}_{1}_{2}" -f $Prefix, $normalized, $hashShort
}

function ConvertTo-AppDocDiagramLabel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Value,
        [int]$MaxLength = 72
    )

    $label = ($Value -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($label)) { return "Unknown" }
    if ($label.Length -gt $MaxLength) {
        return ($label.Substring(0, [Math]::Max(0, $MaxLength - 3)).Trim() + "...")
    }
    return $label
}

function Get-AppDocDiagramDirection {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Record
    )

    $metadata = Get-AppDocDiagramValue -Object $Record -Name "metadata" -Default @{}
    $direction = [string](Get-AppDocDiagramValue -Object $metadata -Name "direction" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($direction)) {
        return $direction.Trim().ToLowerInvariant()
    }

    $sourceType = [string](Get-AppDocDiagramValue -Object $metadata -Name "sourceType" -Default "")
    $path = [string](Get-AppDocDiagramValue -Object $metadata -Name "path" -Default "")
    if ($sourceType -eq "soap-client" -or $path -match '^/soap-client/') {
        return "outbound"
    }

    return "inbound"
}

function Get-AppDocDiagramIntegrationName {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Record
    )

    $metadata = Get-AppDocDiagramValue -Object $Record -Name "metadata" -Default @{}
    $integrationUrl = [string](Get-AppDocDiagramValue -Object $metadata -Name "integrationUrl" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($integrationUrl)) {
        try {
            $uri = [Uri]$integrationUrl
            if ($uri -and $uri.Host) {
                return [string]$uri.Host
            }
        }
        catch {
        }
        return $integrationUrl
    }

    $name = [string](Get-AppDocDiagramValue -Object $Record -Name "name" -Default "")
    if ($name -match '^/soap-client/([^/]+)') {
        return [string]$Matches[1]
    }

    return "External Integration"
}

function Get-AppDocDiagramComponentName {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Record
    )

    $metadata = Get-AppDocDiagramValue -Object $Record -Name "metadata" -Default @{}
    $controller = [string](Get-AppDocDiagramValue -Object $metadata -Name "controller" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($controller)) {
        return $controller
    }

    $domain = [string](Get-AppDocDiagramValue -Object $metadata -Name "domain" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($domain)) {
        return ("{0} Domain" -f $domain)
    }

    $source = [string](Get-AppDocDiagramValue -Object $Record -Name "source" -Default "")
    if ($source -match '([^\\/]+)\.(cs|ts|js)') {
        return [string]$Matches[1]
    }

    return "Core Processing"
}

function Get-AppDocDiagramEndpointLabel {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Record
    )

    $metadata = Get-AppDocDiagramValue -Object $Record -Name "metadata" -Default @{}
    $method = [string](Get-AppDocDiagramValue -Object $metadata -Name "method" -Default "")
    $path = [string](Get-AppDocDiagramValue -Object $metadata -Name "path" -Default "")
    $name = [string](Get-AppDocDiagramValue -Object $Record -Name "name" -Default "")

    if (-not [string]::IsNullOrWhiteSpace($method) -and -not [string]::IsNullOrWhiteSpace($path)) {
        return ("{0} {1}" -f $method.ToUpperInvariant(), $path)
    }
    if (-not [string]::IsNullOrWhiteSpace($path)) { return $path }
    if (-not [string]::IsNullOrWhiteSpace($name)) { return $name }
    return "Endpoint"
}

function Get-AppDocDiagramModelLabel {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Record
    )

    $name = [string](Get-AppDocDiagramValue -Object $Record -Name "name" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($name)) { return $name }

    $metadata = Get-AppDocDiagramValue -Object $Record -Name "metadata" -Default @{}
    $type = [string](Get-AppDocDiagramValue -Object $metadata -Name "type" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($type)) { return $type }
    return "Data Model"
}

function Add-AppDocDiagramNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphState,
        [Parameter(Mandatory=$true)]
        [string]$Type,
        [Parameter(Mandatory=$true)]
        [string]$Label,
        [string]$Group = "",
        [AllowEmptyCollection()]
        [string[]]$EvidenceRefs = @()
    )

    $nodeId = ConvertTo-AppDocDiagramId -Prefix $Type -Seed $Label
    if (-not $GraphState.nodeMap.ContainsKey($nodeId)) {
        $GraphState.nodeMap[$nodeId] = [ordered]@{
            id = $nodeId
            type = $Type
            label = (ConvertTo-AppDocDiagramLabel -Value $Label)
            group = $Group
            evidence_refs = @()
        }
    }

    if ($EvidenceRefs -and $EvidenceRefs.Count -gt 0) {
        $node = $GraphState.nodeMap[$nodeId]
        $node.evidence_refs = @(
            @($node.evidence_refs) + @($EvidenceRefs) |
                ForEach-Object { [string]$_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique |
                Select-Object -First 10
        )
    }

    return $nodeId
}

function Add-AppDocDiagramEdge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphState,
        [Parameter(Mandatory=$true)]
        [string]$From,
        [Parameter(Mandatory=$true)]
        [string]$To,
        [Parameter(Mandatory=$true)]
        [string]$Type,
        [Parameter(Mandatory=$true)]
        [string]$Label,
        [AllowEmptyCollection()]
        [string[]]$EvidenceRefs = @()
    )

    if ([string]::IsNullOrWhiteSpace($From) -or [string]::IsNullOrWhiteSpace($To)) { return }
    if ($From -eq $To) { return }

    $edgeId = ConvertTo-AppDocDiagramId -Prefix "edge" -Seed ("{0}|{1}|{2}" -f $From, $To, $Type)
    if (-not $GraphState.edgeMap.ContainsKey($edgeId)) {
        $GraphState.edgeMap[$edgeId] = [ordered]@{
            id = $edgeId
            from = $From
            to = $To
            type = $Type
            label = (ConvertTo-AppDocDiagramLabel -Value $Label -MaxLength 48)
            evidence_refs = @()
        }
    }

    if ($EvidenceRefs -and $EvidenceRefs.Count -gt 0) {
        $edge = $GraphState.edgeMap[$edgeId]
        $edge.evidence_refs = @(
            @($edge.evidence_refs) + @($EvidenceRefs) |
                ForEach-Object { [string]$_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique |
                Select-Object -First 10
        )
    }
}

function ConvertTo-AppDocDiagramRecordRef {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Record,
        [Parameter(Mandatory=$true)]
        [string]$Artifact,
        [int]$Index = 0
    )

    $id = [string](Get-AppDocDiagramValue -Object $Record -Name "id" -Default "")
    if (-not [string]::IsNullOrWhiteSpace($id)) { return $id }
    return "{0}-{1:d4}" -f $Artifact, $Index
}

function Get-AppDocDiagramRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$FullPath
    )

    try {
        return [System.IO.Path]::GetRelativePath($RootPath, $FullPath)
    }
    catch {
        $root = $RootPath.TrimEnd('\','/')
        if ($FullPath.StartsWith($root, [System.StringComparison]::OrdinalIgnoreCase)) {
            return $FullPath.Substring($root.Length).TrimStart('\','/')
        }
        return $FullPath
    }
}

function Test-AppDocDiagramLegacyInboundPath {
    [CmdletBinding()]
    param(
        [string]$RelativePath
    )

    if ([string]::IsNullOrWhiteSpace($RelativePath)) { return $false }
    $path = ("/" + ($RelativePath -replace '\\', '/')).ToLowerInvariant()

    $blockedSubpaths = @(
        "/bin/",
        "/obj/",
        "/packages/",
        "/node_modules/",
        "/service references/",
        "/connected services/",
        "/generated/",
        "/migrations/",
        "/docs/"
    )
    foreach ($blocked in $blockedSubpaths) {
        if ($path.Contains($blocked)) { return $false }
    }
    if ($path -match '(^|/)(test|tests)(/|$)') { return $false }
    if ($path.EndsWith("/reference.cs")) { return $false }

    return $true
}

function Get-AppDocLegacyInboundFallbackEntries {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowEmptyCollection()]
        [string[]]$ExistingLabels = @(),
        [int]$MaxCount = 24
    )

    if ($MaxCount -lt 1) { return @() }

    $entries = New-Object 'System.Collections.Generic.List[object]'
    $seenLabels = @{}
    foreach ($label in @($ExistingLabels)) {
        $key = [string]$label
        if ([string]::IsNullOrWhiteSpace($key)) { continue }
        $seenLabels[$key.Trim().ToLowerInvariant()] = $true
    }

    $addEntry = {
        param(
            [string]$Label,
            [string]$Component,
            [string]$Source,
            [string]$Path,
            [string]$SourceType
        )

        if ($entries.Count -ge $MaxCount) { return }
        if ([string]::IsNullOrWhiteSpace($Label)) { return }

        $normalized = $Label.Trim().ToLowerInvariant()
        if ($seenLabels.ContainsKey($normalized)) { return }
        $seenLabels[$normalized] = $true

        $index = $entries.Count + 1
        $ref = ("legacy-in-{0:d4}" -f $index)
        $record = [ordered]@{
            artifact = "api-inventory"
            source = $Source
            name = $Label
            kind = "endpoint"
            metadata = [ordered]@{
                direction = "inbound"
                method = "SOAP"
                path = $Path
                sourceType = $SourceType
                component = $Component
            }
        }

        $entry = [ordered]@{
            record = $record
            ref = $ref
            direction = "inbound"
            label = $Label
            component = $Component
            sourceType = $SourceType
        }
        [void]$entries.Add($entry)
    }

    $serviceHostFiles = @(
        Get-ChildItem -Path $RootPath -Recurse -File -Include *.svc,*.asmx -ErrorAction SilentlyContinue |
            Sort-Object @{ Expression = { [string]$_.FullName } }
    )
    foreach ($file in $serviceHostFiles) {
        if ($entries.Count -ge $MaxCount) { break }

        $relativePath = Get-AppDocDiagramRelativePath -RootPath $RootPath -FullPath $file.FullName
        if (-not (Test-AppDocDiagramLegacyInboundPath -RelativePath $relativePath)) { continue }

        $virtualPath = "/" + ($relativePath -replace '\\', '/')
        $projectName = [string]($relativePath -split '[\\/]' | Select-Object -First 1)
        $baseName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
        $componentName = if ([string]::IsNullOrWhiteSpace($projectName)) { $baseName } else { "{0}.{1}" -f $projectName, $baseName }
        $label = "SOAP $virtualPath"

        & $addEntry -Label $label -Component $componentName -Source $relativePath -Path $virtualPath -SourceType "legacy-service-host"
    }

    if ($entries.Count -lt $MaxCount) {
        $contractFiles = @(
            Get-ChildItem -Path $RootPath -Recurse -File -Filter *.cs -ErrorAction SilentlyContinue |
                Sort-Object @{ Expression = { [string]$_.FullName } }
        )

        foreach ($file in $contractFiles) {
            if ($entries.Count -ge $MaxCount) { break }

            $relativePath = Get-AppDocDiagramRelativePath -RootPath $RootPath -FullPath $file.FullName
            if (-not (Test-AppDocDiagramLegacyInboundPath -RelativePath $relativePath)) { continue }

            $content = ""
            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            }
            catch {
                continue
            }
            if ([string]::IsNullOrWhiteSpace($content)) { continue }
            if ($content -notmatch '\[ServiceContract\b') { continue }

            $contractName = ""
            $contractMatch = [regex]::Match(
                $content,
                '(?is)\[ServiceContract[^\]]*\]\s*(?:\[[^\]]*\]\s*)*(?:public\s+)?(?:partial\s+)?(?:interface|class)\s+([A-Za-z_][A-Za-z0-9_]*)'
            )
            if ($contractMatch.Success) {
                $contractName = [string]$contractMatch.Groups[1].Value
            }
            if ([string]::IsNullOrWhiteSpace($contractName)) {
                $contractName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            }

            $operationNames = @(
                [regex]::Matches(
                    $content,
                    '(?is)\[OperationContract[^\]]*\]\s*(?:\[[^\]]*\]\s*)*(?:public\s+)?(?:async\s+)?(?:[A-Za-z_][A-Za-z0-9_<>,\.\?\[\]]*\s+)+([A-Za-z_][A-Za-z0-9_]*)\s*\('
                ) |
                    ForEach-Object { [string]$_.Groups[1].Value } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique |
                    Select-Object -First 8
            )

            if ($operationNames.Count -eq 0) {
                $virtualPath = "/soap/$contractName"
                $label = "SOAP $virtualPath"
                & $addEntry -Label $label -Component $contractName -Source $relativePath -Path $virtualPath -SourceType "legacy-service-contract"
                continue
            }

            foreach ($operationName in $operationNames) {
                if ($entries.Count -ge $MaxCount) { break }
                $virtualPath = "/soap/$contractName/$operationName"
                $label = "SOAP $virtualPath"
                & $addEntry -Label $label -Component $contractName -Source $relativePath -Path $virtualPath -SourceType "legacy-service-contract"
            }
        }
    }

    if ($entries.Count -lt $MaxCount) {
        $pathSignalFiles = @(
            Get-ChildItem -Path $RootPath -Recurse -File -Include *.config,*.cs,*.xml,*.json -ErrorAction SilentlyContinue |
                Sort-Object @{ Expression = { [string]$_.FullName } }
        )
        foreach ($file in $pathSignalFiles) {
            if ($entries.Count -ge $MaxCount) { break }

            $relativePath = Get-AppDocDiagramRelativePath -RootPath $RootPath -FullPath $file.FullName
            if (-not (Test-AppDocDiagramLegacyInboundPath -RelativePath $relativePath)) { continue }

            $content = ""
            try {
                $content = Get-Content -Path $file.FullName -Raw -ErrorAction Stop
            }
            catch {
                continue
            }
            if ([string]::IsNullOrWhiteSpace($content)) { continue }

            $matches = [regex]::Matches($content, '(?i)(/[A-Za-z0-9_\-./]+?\.(?:svc|asmx)(?:/[A-Za-z0-9_\-./]+)?)')
            if ($matches.Count -eq 0) { continue }

            $componentName = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            foreach ($match in $matches) {
                if ($entries.Count -ge $MaxCount) { break }
                $virtualPath = [string]$match.Groups[1].Value
                if ([string]::IsNullOrWhiteSpace($virtualPath)) { continue }
                if ($virtualPath.StartsWith("//")) { continue }
                if ($virtualPath -match '(?i)\?xsd=') { continue }
                if ($virtualPath -match '(?i)^/soap-client/') { continue }
                if ($virtualPath -match '(?i)\.svc/.+\.svc') { continue }

                $label = "SOAP $virtualPath"
                & $addEntry -Label $label -Component $componentName -Source $relativePath -Path $virtualPath -SourceType "legacy-path-signal"
            }
        }
    }

    return @($entries | Select-Object -First $MaxCount)
}

function Get-AppDocDiagramGraphData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [hashtable]$Contract = $null
    )

    if (-not $Contract) {
        if (Get-Command Get-AppDocDiagramContract -ErrorAction SilentlyContinue) {
            $Contract = Get-AppDocDiagramContract
        }
        else {
            $Contract = @{ limits = @{ maxInboundEndpoints = 24; maxOutboundEndpoints = 12; maxComponents = 18; maxModels = 24; maxConfigs = 12; maxDependencies = 12 } }
        }
    }

    $limits = Get-AppDocDiagramValue -Object $Contract -Name "limits" -Default @{}
    $evidenceRoot = Join-Path $RootPath (Join-Path "docs" "evidence")
    $projectName = Split-Path $RootPath -Leaf

    $apiPayload = Get-AppDocDiagramEvidencePayload -EvidenceRoot $evidenceRoot -Artifact "api-inventory"
    $modelPayload = Get-AppDocDiagramEvidencePayload -EvidenceRoot $evidenceRoot -Artifact "data-model"
    $configPayload = Get-AppDocDiagramEvidencePayload -EvidenceRoot $evidenceRoot -Artifact "config-catalog"
    $dependencyPayload = Get-AppDocDiagramEvidencePayload -EvidenceRoot $evidenceRoot -Artifact "dependencies-catalog"

    $graphState = @{
        nodeMap = @{}
        edgeMap = @{}
    }

    $actorId = Add-AppDocDiagramNode -GraphState $graphState -Type "actor" -Label "User / Calling System" -Group "context"
    $coreId = Add-AppDocDiagramNode -GraphState $graphState -Type "component" -Label "Core Processing" -Group "processing"

    $apiRecords = @(
        $apiPayload.records |
            Where-Object { [string](Get-AppDocDiagramValue -Object $_ -Name "kind" -Default "") -eq "endpoint" }
    )
    $indexedApiRecords = @()
    $apiCounter = 0
    foreach ($record in $apiRecords) {
        $apiCounter++
        $apiMetadata = Get-AppDocDiagramValue -Object $record -Name "metadata" -Default @{}
        $apiSourceType = [string](Get-AppDocDiagramValue -Object $apiMetadata -Name "sourceType" -Default "")
        if ([string]::IsNullOrWhiteSpace($apiSourceType)) { $apiSourceType = "api-evidence" }
        $indexedApiRecords += [ordered]@{
            record = $record
            ref = (ConvertTo-AppDocDiagramRecordRef -Record $record -Artifact "api" -Index $apiCounter)
            direction = (Get-AppDocDiagramDirection -Record $record)
            label = (Get-AppDocDiagramEndpointLabel -Record $record)
            component = (Get-AppDocDiagramComponentName -Record $record)
            sourceType = $apiSourceType
        }
    }

    $inbound = @(
        $indexedApiRecords |
            Where-Object { $_.direction -eq "inbound" } |
            Sort-Object @{ Expression = { [string]$_.label } }, @{ Expression = { [string]$_.component } } |
            Select-Object -First ([int](Get-AppDocDiagramValue -Object $limits -Name "maxInboundEndpoints" -Default 24))
    )

    $outbound = @(
        $indexedApiRecords |
            Where-Object { $_.direction -eq "outbound" } |
            Sort-Object @{ Expression = { [string]$_.label } }, @{ Expression = { [string]$_.component } } |
            Select-Object -First ([int](Get-AppDocDiagramValue -Object $limits -Name "maxOutboundEndpoints" -Default 12))
    )

    $hasTrustedLegacyInboundEvidence = $false
    if (@($inbound).Count -eq 0) {
        $maxInbound = [int](Get-AppDocDiagramValue -Object $limits -Name "maxInboundEndpoints" -Default 24)
        $knownLabels = @(
            $indexedApiRecords |
                ForEach-Object { [string]$_.label } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $legacyInbound = Get-AppDocLegacyInboundFallbackEntries -RootPath $RootPath -ExistingLabels $knownLabels -MaxCount $maxInbound
        if (@($legacyInbound).Count -gt 0) {
            $trustedLegacyInbound = @(
                $legacyInbound |
                    Where-Object { [string]$_.sourceType -in @("legacy-service-host","legacy-service-contract") }
            )
            $pathSignalLegacyInbound = @(
                $legacyInbound |
                    Where-Object { [string]$_.sourceType -eq "legacy-path-signal" }
            )

            $hasTrustedLegacyInboundEvidence = (@($trustedLegacyInbound).Count -gt 0)
            if ($hasTrustedLegacyInboundEvidence) {
                $combinedLegacyInbound = @(
                    @($trustedLegacyInbound + $pathSignalLegacyInbound) |
                        Sort-Object @{ Expression = { [string]$_.label } }, @{ Expression = { [string]$_.component } }, @{ Expression = { [string]$_.sourceType } } -Unique
                )
                $inbound = @($combinedLegacyInbound | Select-Object -First $maxInbound)
            }
            else {
                $inbound = @()
            }
        }
    }

    $componentUsage = @{}
    foreach ($entry in @($inbound + $outbound)) {
        $name = [string]$entry.component
        if ([string]::IsNullOrWhiteSpace($name)) { $name = "Core Processing" }
        if (-not $componentUsage.ContainsKey($name)) { $componentUsage[$name] = 0 }
        $componentUsage[$name]++
    }

    $selectedComponents = @(
        $componentUsage.GetEnumerator() |
            Sort-Object @{ Expression = { [int]$_.Value }; Descending = $true }, @{ Expression = { [string]$_.Key } } |
            Select-Object -First ([int](Get-AppDocDiagramValue -Object $limits -Name "maxComponents" -Default 18)) |
            ForEach-Object { [string]$_.Key }
    )
    if ($selectedComponents.Count -eq 0) { $selectedComponents = @("Core Processing") }

    $componentNodeMap = @{}
    foreach ($componentName in $selectedComponents) {
        $nodeId = Add-AppDocDiagramNode -GraphState $graphState -Type "component" -Label $componentName -Group "processing"
        $componentNodeMap[$componentName] = $nodeId
        if ($nodeId -ne $coreId) {
            Add-AppDocDiagramEdge -GraphState $graphState -From $coreId -To $nodeId -Type "contains" -Label "contains"
        }
    }
    if (-not $componentNodeMap.ContainsKey("Core Processing")) {
        $componentNodeMap["Core Processing"] = $coreId
    }

    foreach ($entry in $inbound) {
        $entrySourceType = [string](Get-AppDocDiagramValue -Object $entry -Name "sourceType" -Default "")
        if ($entrySourceType -eq "legacy-path-signal" -and -not $hasTrustedLegacyInboundEvidence) { continue }

        $endpointId = Add-AppDocDiagramNode -GraphState $graphState -Type "inbound" -Label $entry.label -Group "interface" -EvidenceRefs @($entry.ref)
        Add-AppDocDiagramEdge -GraphState $graphState -From $actorId -To $endpointId -Type "request" -Label "request" -EvidenceRefs @($entry.ref)
        $componentName = if ($componentNodeMap.ContainsKey($entry.component)) { $entry.component } else { "Core Processing" }
        Add-AppDocDiagramEdge -GraphState $graphState -From $endpointId -To $componentNodeMap[$componentName] -Type "routes" -Label "routes" -EvidenceRefs @($entry.ref)

        $meta = Get-AppDocDiagramValue -Object $entry.record -Name "metadata" -Default @{}
        $returnType = [string](Get-AppDocDiagramValue -Object $meta -Name "returnType" -Default "")
        if (-not [string]::IsNullOrWhiteSpace($returnType)) {
            $modelId = Add-AppDocDiagramNode -GraphState $graphState -Type "data" -Label $returnType -Group "data" -EvidenceRefs @($entry.ref)
            Add-AppDocDiagramEdge -GraphState $graphState -From $componentNodeMap[$componentName] -To $modelId -Type "returns" -Label "returns" -EvidenceRefs @($entry.ref)
        }
    }

    foreach ($entry in $outbound) {
        $componentName = if ($componentNodeMap.ContainsKey($entry.component)) { $entry.component } else { "Core Processing" }
        $outboundId = Add-AppDocDiagramNode -GraphState $graphState -Type "outbound" -Label $entry.label -Group "integration" -EvidenceRefs @($entry.ref)
        Add-AppDocDiagramEdge -GraphState $graphState -From $componentNodeMap[$componentName] -To $outboundId -Type "invoke" -Label "invokes" -EvidenceRefs @($entry.ref)

        $integrationName = Get-AppDocDiagramIntegrationName -Record $entry.record
        $integrationId = Add-AppDocDiagramNode -GraphState $graphState -Type "external" -Label $integrationName -Group "external" -EvidenceRefs @($entry.ref)
        Add-AppDocDiagramEdge -GraphState $graphState -From $outboundId -To $integrationId -Type "calls" -Label "calls" -EvidenceRefs @($entry.ref)
    }

    $modelRecords = @(
        $modelPayload.records |
            Where-Object { [string](Get-AppDocDiagramValue -Object $_ -Name "kind" -Default "") -eq "model" } |
            Sort-Object @{ Expression = { [string](Get-AppDocDiagramModelLabel -Record $_) } } |
            Select-Object -First ([int](Get-AppDocDiagramValue -Object $limits -Name "maxModels" -Default 24))
    )
    $modelIndex = 0
    foreach ($model in $modelRecords) {
        $modelIndex++
        $ref = ConvertTo-AppDocDiagramRecordRef -Record $model -Artifact "model" -Index $modelIndex
        $modelLabel = Get-AppDocDiagramModelLabel -Record $model
        $modelId = Add-AppDocDiagramNode -GraphState $graphState -Type "data" -Label $modelLabel -Group "data" -EvidenceRefs @($ref)
        Add-AppDocDiagramEdge -GraphState $graphState -From $coreId -To $modelId -Type "data" -Label "reads/writes" -EvidenceRefs @($ref)
    }

    $configRecords = @(
        $configPayload.records |
            Where-Object { [string](Get-AppDocDiagramValue -Object $_ -Name "kind" -Default "") -eq "configuration" } |
            Where-Object {
                $name = [string](Get-AppDocDiagramValue -Object $_ -Name "name" -Default "")
                $name -and ($name -notmatch '^chat\.tools\.')
            } |
            Sort-Object @{ Expression = { [string](Get-AppDocDiagramValue -Object $_ -Name "name" -Default "") } } |
            Select-Object -First ([int](Get-AppDocDiagramValue -Object $limits -Name "maxConfigs" -Default 12))
    )
    $configIndex = 0
    foreach ($config in $configRecords) {
        $configIndex++
        $ref = ConvertTo-AppDocDiagramRecordRef -Record $config -Artifact "cfg" -Index $configIndex
        $label = [string](Get-AppDocDiagramValue -Object $config -Name "name" -Default "Configuration")
        $configId = Add-AppDocDiagramNode -GraphState $graphState -Type "config" -Label $label -Group "input" -EvidenceRefs @($ref)
        Add-AppDocDiagramEdge -GraphState $graphState -From $configId -To $coreId -Type "configures" -Label "configures" -EvidenceRefs @($ref)
    }

    $dependencyRecords = @(
        $dependencyPayload.records |
            Where-Object { [string](Get-AppDocDiagramValue -Object $_ -Name "kind" -Default "") -eq "dependency" } |
            Sort-Object @{ Expression = { [string](Get-AppDocDiagramValue -Object $_ -Name "name" -Default "") } } |
            Select-Object -First ([int](Get-AppDocDiagramValue -Object $limits -Name "maxDependencies" -Default 12))
    )
    $depIndex = 0
    foreach ($dependency in $dependencyRecords) {
        $depIndex++
        $ref = ConvertTo-AppDocDiagramRecordRef -Record $dependency -Artifact "dep" -Index $depIndex
        $depName = [string](Get-AppDocDiagramValue -Object $dependency -Name "name" -Default "")
        if ([string]::IsNullOrWhiteSpace($depName)) { continue }
        $depId = Add-AppDocDiagramNode -GraphState $graphState -Type "dependency" -Label $depName -Group "dependency" -EvidenceRefs @($ref)
        Add-AppDocDiagramEdge -GraphState $graphState -From $coreId -To $depId -Type "uses" -Label "uses" -EvidenceRefs @($ref)
    }

    $nodes = @(
        $graphState.nodeMap.Values |
            Sort-Object @{ Expression = { [string]$_.type } }, @{ Expression = { [string]$_.label } }, @{ Expression = { [string]$_.id } }
    )
    $edges = @(
        $graphState.edgeMap.Values |
            Sort-Object @{ Expression = { [string]$_.from } }, @{ Expression = { [string]$_.to } }, @{ Expression = { [string]$_.type } }, @{ Expression = { [string]$_.id } }
    )

    return [ordered]@{
        schemaVersion = "1.0.0"
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        project = [ordered]@{
            name = $projectName
            rootPath = $RootPath
        }
        metrics = [ordered]@{
            nodeCount = $nodes.Count
            edgeCount = $edges.Count
            inboundEndpointCount = @($inbound).Count
            outboundEndpointCount = @($outbound).Count
            modelCount = @($modelRecords).Count
            configCount = @($configRecords).Count
            dependencyCount = @($dependencyRecords).Count
        }
        nodes = $nodes
        edges = $edges
        sources = [ordered]@{
            apiEvidencePath = [string]$apiPayload.path
            modelEvidencePath = [string]$modelPayload.path
            configEvidencePath = [string]$configPayload.path
            dependencyEvidencePath = [string]$dependencyPayload.path
        }
    }
}

function Write-AppDocDiagramTruthPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData
    )

    $evidenceDir = Join-Path $RootPath (Join-Path "docs" "evidence")
    if (-not (Test-Path $evidenceDir)) {
        New-Item -Path $evidenceDir -ItemType Directory -Force | Out-Null
    }

    $truthPackPath = Join-Path $evidenceDir "diagram-truth-pack.json"
    $payload = [ordered]@{}
    foreach ($key in @($GraphData.Keys)) {
        $payload[$key] = $GraphData[$key]
    }

    if (Get-Command Get-AppDocDeterministicHash -ErrorAction SilentlyContinue) {
        $excludeKeys = @("generatedAt", "updatedAt", "timestamp")
        $payload.determinism = [ordered]@{
            hashAlgorithm = "SHA256"
            excludeKeys = $excludeKeys
            contentHash = (Get-AppDocDeterministicHash -InputObject $payload -ExcludeKeys $excludeKeys)
        }
    }

    $payload | ConvertTo-Json -Depth 50 | Out-File -FilePath $truthPackPath -Encoding UTF8
    return $truthPackPath
}

Export-ModuleMember -Function @(
    'Get-AppDocDiagramGraphData',
    'Write-AppDocDiagramTruthPack'
)
