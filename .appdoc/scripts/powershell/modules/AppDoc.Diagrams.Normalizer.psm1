$script:AppDocGraphSchemaVersion = "appdoc-graph/v1"

function Get-AppDocGraphValue {
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

function ConvertTo-AppDocGraphStableId {
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

    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $hashBytes = $sha1.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($text))
    }
    finally {
        $sha1.Dispose()
    }

    $hashHex = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
    $hashShort = $hashHex.Substring(0, 8)

    if ($normalized.Length -gt 30) {
        $normalized = $normalized.Substring(0, 30).Trim('_')
    }
    if ([string]::IsNullOrWhiteSpace($normalized)) { $normalized = "item" }

    return "{0}_{1}_{2}" -f $Prefix, $normalized, $hashShort
}

function ConvertTo-AppDocGraphLabel {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Value,
        [int]$MaxLength = 72
    )

    $text = [string]$Value
    $text = ($text -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { $text = "Unknown" }
    if ($text.Length -gt $MaxLength) {
        return ($text.Substring(0, [Math]::Max(0, $MaxLength - 3)).Trim() + "...")
    }
    return $text
}

function ConvertTo-AppDocGraphEvidenceRefs {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,
        [int]$MaxRefs = 12
    )

    $refs = New-Object 'System.Collections.Generic.List[string]'
    foreach ($item in @($Value)) {
        $ref = [string]$item
        if ([string]::IsNullOrWhiteSpace($ref)) { continue }
        $refs.Add($ref.Trim())
    }

    return @($refs.ToArray() | Sort-Object -Unique | Select-Object -First $MaxRefs)
}

function ConvertTo-AppDocGraphNode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]$Node
    )

    $allowedTypes = @("actor","inbound","outbound","component","data","config","external","dependency")
    $type = [string](Get-AppDocGraphValue -Object $Node -Name "type" -Default "component")
    $type = $type.Trim().ToLowerInvariant()
    if ($allowedTypes -notcontains $type) { $type = "component" }

    $label = ConvertTo-AppDocGraphLabel -Value ([string](Get-AppDocGraphValue -Object $Node -Name "label" -Default "Unknown"))
    $group = [string](Get-AppDocGraphValue -Object $Node -Name "group" -Default "")
    $group = ($group -replace '\s+', '-').Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($group)) { $group = "default" }

    $id = [string](Get-AppDocGraphValue -Object $Node -Name "id" -Default "")
    if ([string]::IsNullOrWhiteSpace($id)) {
        $id = ConvertTo-AppDocGraphStableId -Prefix $type -Seed ("{0}|{1}" -f $type, $label)
    }

    return [ordered]@{
        id = $id
        type = $type
        label = $label
        group = $group
        evidence_refs = ConvertTo-AppDocGraphEvidenceRefs -Value (Get-AppDocGraphValue -Object $Node -Name "evidence_refs" -Default @())
    }
}

function ConvertTo-AppDocGraphEdge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]$Edge
    )

    $from = [string](Get-AppDocGraphValue -Object $Edge -Name "from" -Default "")
    $to = [string](Get-AppDocGraphValue -Object $Edge -Name "to" -Default "")
    if ([string]::IsNullOrWhiteSpace($from) -or [string]::IsNullOrWhiteSpace($to)) { return $null }
    if ($from -eq $to) { return $null }

    $type = [string](Get-AppDocGraphValue -Object $Edge -Name "type" -Default "relation")
    $type = $type.Trim().ToLowerInvariant()
    if ([string]::IsNullOrWhiteSpace($type)) { $type = "relation" }

    $label = ConvertTo-AppDocGraphLabel -Value ([string](Get-AppDocGraphValue -Object $Edge -Name "label" -Default $type)) -MaxLength 48
    $id = [string](Get-AppDocGraphValue -Object $Edge -Name "id" -Default "")
    if ([string]::IsNullOrWhiteSpace($id)) {
        $id = ConvertTo-AppDocGraphStableId -Prefix "edge" -Seed ("{0}|{1}|{2}|{3}" -f $from, $to, $type, $label)
    }

    return [ordered]@{
        id = $id
        from = $from
        to = $to
        type = $type
        label = $label
        evidence_refs = ConvertTo-AppDocGraphEvidenceRefs -Value (Get-AppDocGraphValue -Object $Edge -Name "evidence_refs" -Default @())
    }
}

function Get-AppDocGraphComputedMetrics {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [array]$Nodes = @(),
        [AllowEmptyCollection()]
        [array]$Edges = @()
    )

    $nodeMap = @{}
    foreach ($node in @($Nodes)) {
        $id = [string](Get-AppDocGraphValue -Object $node -Name "id" -Default "")
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        if (-not $nodeMap.ContainsKey($id)) { $nodeMap[$id] = $node }
    }

    $actorIds = @(
        $nodeMap.Values |
            Where-Object { [string](Get-AppDocGraphValue -Object $_ -Name "type" -Default "") -eq "actor" } |
            ForEach-Object { [string](Get-AppDocGraphValue -Object $_ -Name "id" -Default "") } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    $inboundInterfaceCount = @(
        @($Edges) |
            Where-Object {
                [string](Get-AppDocGraphValue -Object $_ -Name "type" -Default "") -eq "request" -and
                ($actorIds -contains [string](Get-AppDocGraphValue -Object $_ -Name "from" -Default ""))
            } |
            ForEach-Object {
                $toId = [string](Get-AppDocGraphValue -Object $_ -Name "to" -Default "")
                if ([string]::IsNullOrWhiteSpace($toId) -or -not $nodeMap.ContainsKey($toId)) { return $null }
                $targetNode = $nodeMap[$toId]
                if ([string](Get-AppDocGraphValue -Object $targetNode -Name "type" -Default "") -ne "inbound") { return $null }
                return $toId
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    ).Count

    $outboundEndpointCount = @(
        @($Edges) |
            Where-Object { [string](Get-AppDocGraphValue -Object $_ -Name "type" -Default "") -eq "invoke" } |
            ForEach-Object { [string](Get-AppDocGraphValue -Object $_ -Name "to" -Default "") } |
            Where-Object {
                -not [string]::IsNullOrWhiteSpace($_) -and
                $nodeMap.ContainsKey($_) -and
                [string](Get-AppDocGraphValue -Object $nodeMap[$_] -Name "type" -Default "") -eq "outbound"
            } |
            Select-Object -Unique
    ).Count

    # Single-pass aggregation for node type counts
    $componentCount = 0
    $modelCount = 0
    $configCount = 0
    $dependencyCount = 0
    foreach ($node in $Nodes) {
        $type = [string](Get-AppDocGraphValue -Object $node -Name "type" -Default "")
        switch ($type) {
            "component" { $componentCount++ }
            "data"      { $modelCount++ }
            "config"    { $configCount++ }
            "dependency"{ $dependencyCount++ }
        }
    }
    return [ordered]@{
        nodeCount = @($Nodes).Count
        edgeCount = @($Edges).Count
        inboundEndpointCount = $inboundInterfaceCount
        outboundEndpointCount = $outboundEndpointCount
        componentCount = $componentCount
        modelCount = $modelCount
        configCount = $configCount
        dependencyCount = $dependencyCount
    }
}

function ConvertTo-AppDocGraphV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowEmptyCollection()]
        [array]$Nodes = @(),
        [AllowEmptyCollection()]
        [array]$Edges = @(),
        [AllowNull()]
        [hashtable]$Project = $null,
        [AllowNull()]
        [hashtable]$Sources = $null
    )

    $nodeMap = @{}
    foreach ($rawNode in @($Nodes)) {
        $node = ConvertTo-AppDocGraphNode -Node $rawNode
        $nodeId = [string](Get-AppDocGraphValue -Object $node -Name "id" -Default "")
        if ([string]::IsNullOrWhiteSpace($nodeId)) { continue }

        if (-not $nodeMap.ContainsKey($nodeId)) {
            $nodeMap[$nodeId] = $node
            continue
        }

        $existing = $nodeMap[$nodeId]
        $existing.evidence_refs = ConvertTo-AppDocGraphEvidenceRefs -Value @(
            @(Get-AppDocGraphValue -Object $existing -Name "evidence_refs" -Default @()) +
            @(Get-AppDocGraphValue -Object $node -Name "evidence_refs" -Default @())
        )
    }

    $edgeMap = @{}
    foreach ($rawEdge in @($Edges)) {
        $edge = ConvertTo-AppDocGraphEdge -Edge $rawEdge
        if ($null -eq $edge) { continue }
        $edgeFrom = [string](Get-AppDocGraphValue -Object $edge -Name "from" -Default "")
        $edgeTo = [string](Get-AppDocGraphValue -Object $edge -Name "to" -Default "")
        if (-not $nodeMap.ContainsKey($edgeFrom) -or -not $nodeMap.ContainsKey($edgeTo)) { continue }

        $edgeId = [string](Get-AppDocGraphValue -Object $edge -Name "id" -Default "")
        if (-not $edgeMap.ContainsKey($edgeId)) {
            $edgeMap[$edgeId] = $edge
            continue
        }

        $existing = $edgeMap[$edgeId]
        $existing.evidence_refs = ConvertTo-AppDocGraphEvidenceRefs -Value @(
            @(Get-AppDocGraphValue -Object $existing -Name "evidence_refs" -Default @()) +
            @(Get-AppDocGraphValue -Object $edge -Name "evidence_refs" -Default @())
        )
    }

    $normalizedNodes = @(
        $nodeMap.Values |
            Sort-Object @{ Expression = { [string](Get-AppDocGraphValue -Object $_ -Name "type" -Default "") } }, `
                        @{ Expression = { [string](Get-AppDocGraphValue -Object $_ -Name "label" -Default "") } }, `
                        @{ Expression = { [string](Get-AppDocGraphValue -Object $_ -Name "id" -Default "") } }
    )
    $normalizedEdges = @(
        $edgeMap.Values |
            Sort-Object @{ Expression = { [string](Get-AppDocGraphValue -Object $_ -Name "from" -Default "") } }, `
                        @{ Expression = { [string](Get-AppDocGraphValue -Object $_ -Name "to" -Default "") } }, `
                        @{ Expression = { [string](Get-AppDocGraphValue -Object $_ -Name "type" -Default "") } }, `
                        @{ Expression = { [string](Get-AppDocGraphValue -Object $_ -Name "label" -Default "") } }, `
                        @{ Expression = { [string](Get-AppDocGraphValue -Object $_ -Name "id" -Default "") } }
    )

    $computedMetrics = Get-AppDocGraphComputedMetrics -Nodes $normalizedNodes -Edges $normalizedEdges
    $projectName = [string](Get-AppDocGraphValue -Object $Project -Name "name" -Default "")
    if ([string]::IsNullOrWhiteSpace($projectName)) {
        $projectName = Split-Path $RootPath -Leaf
    }

    $projectRoot = [string](Get-AppDocGraphValue -Object $Project -Name "rootPath" -Default "")
    if ([string]::IsNullOrWhiteSpace($projectRoot)) {
        $projectRoot = $RootPath
    }

    $graph = [ordered]@{
        schemaVersion = $script:AppDocGraphSchemaVersion
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        project = [ordered]@{
            name = $projectName
            rootPath = $projectRoot
        }
        metrics = $computedMetrics
        nodes = $normalizedNodes
        edges = $normalizedEdges
        sources = if ($Sources) { $Sources } else { [ordered]@{} }
        determinism = [ordered]@{
            canonicalOrdering = @(
                "nodes:type,label,id",
                "edges:from,to,type,label,id"
            )
            stableIdAlgorithm = "sha1(prefix|seed)[0:8]"
        }
    }

    # Optional dependency: Get-AppDocDeterministicHash provides contentHash for integrity metadata.
    if (Get-Command Get-AppDocDeterministicHash -ErrorAction SilentlyContinue) {
        $excludeKeys = @("generatedAt", "updatedAt", "timestamp")
        $graph.determinism["hashAlgorithm"] = "SHA256"
        $graph.determinism["excludeKeys"] = $excludeKeys
        $graph.determinism["contentHash"] = Get-AppDocDeterministicHash -Object $graph -ExcludeKeys $excludeKeys
    } else {
        Write-Verbose "Get-AppDocDeterministicHash not found: contentHash will not be set in determinism metadata. Consumers relying on contentHash will not have integrity metadata."
    }
    return $graph
}

function Test-AppDocGraphV1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]$Graph
    )

    $issues = @()
    if ($null -eq $Graph) {
        return [ordered]@{
            passed = $false
            issueCount = 1
            issues = @("graph-null")
            computedMetrics = [ordered]@{}
        }
    }

    $schemaVersion = [string](Get-AppDocGraphValue -Object $Graph -Name "schemaVersion" -Default "")
    if ($schemaVersion -ne $script:AppDocGraphSchemaVersion) {
        $issues += "schema-version-mismatch:$schemaVersion"
    }

    $nodes = @(
        Get-AppDocGraphValue -Object $Graph -Name "nodes" -Default @()
    )
    $edges = @(
        Get-AppDocGraphValue -Object $Graph -Name "edges" -Default @()
    )

    if ($nodes.Count -eq 0) { $issues += "nodes-empty" }

    $nodeIds = @($nodes | ForEach-Object { [string](Get-AppDocGraphValue -Object $_ -Name "id" -Default "") })
    $duplicateNodes = @($nodeIds | Group-Object | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) -and $_.Count -gt 1 })
    if ($duplicateNodes.Count -gt 0) { $issues += "duplicate-node-ids" }

    $nodeMap = @{}
    foreach ($n in $nodes) {
        $id = [string](Get-AppDocGraphValue -Object $n -Name "id" -Default "")
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        if (-not $nodeMap.ContainsKey($id)) { $nodeMap[$id] = $n }
    }

    $edgeIds = @($edges | ForEach-Object { [string](Get-AppDocGraphValue -Object $_ -Name "id" -Default "") })
    $duplicateEdges = @($edgeIds | Group-Object | Where-Object { -not [string]::IsNullOrWhiteSpace($_.Name) -and $_.Count -gt 1 })
    if ($duplicateEdges.Count -gt 0) { $issues += "duplicate-edge-ids" }

    foreach ($edge in $edges) {
        $from = [string](Get-AppDocGraphValue -Object $edge -Name "from" -Default "")
        $to = [string](Get-AppDocGraphValue -Object $edge -Name "to" -Default "")
        if ([string]::IsNullOrWhiteSpace($from) -or -not $nodeMap.ContainsKey($from)) {
            $issues += "edge-missing-from-node:$from"
        }
        if ([string]::IsNullOrWhiteSpace($to) -or -not $nodeMap.ContainsKey($to)) {
            $issues += "edge-missing-to-node:$to"
        }
    }

    $computed = Get-AppDocGraphComputedMetrics -Nodes $nodes -Edges $edges
    $metrics = Get-AppDocGraphValue -Object $Graph -Name "metrics" -Default @{}

        foreach ($metricName in @("componentCount", "modelCount", "configCount", "dependencyCount", "nodeCount", "edgeCount", "inboundEndpointCount", "outboundEndpointCount")) {
        $expected = [int](Get-AppDocGraphValue -Object $computed -Name $metricName -Default -1)
        $actual = [int](Get-AppDocGraphValue -Object $metrics -Name $metricName -Default -1)
        if ($expected -ne $actual) {
            $issues += "metric-mismatch:{0}:{1}:{2}" -f $metricName, $actual, $expected
        }
    }

    return [ordered]@{
        passed = ($issues.Count -eq 0)
        issueCount = $issues.Count
        issues = @($issues | Select-Object -Unique)
        computedMetrics = $computed
    }
}

Export-ModuleMember -Function @(
    "ConvertTo-AppDocGraphV1",
    "Test-AppDocGraphV1"
)
