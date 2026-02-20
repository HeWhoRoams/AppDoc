function Get-AppDocDiagramRendererValue {
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

function ConvertTo-AppDocMermaidLabel {
    [CmdletBinding()]
    param(
        [string]$Label
    )

    if ([string]::IsNullOrWhiteSpace($Label)) { return "Unknown" }
    $value = $Label.Trim()
    $value = $value.Replace('"', "'")
    $value = $value.Replace("`r", " ").Replace("`n", " ")
    return $value
}

function Get-AppDocDiagramTopEvidenceRefs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData,
        [int]$Limit = 10
    )

    $refs = @()
    foreach ($node in @(Get-AppDocDiagramRendererValue -Object $GraphData -Name "nodes" -Default @())) {
        $refs += @(
            Get-AppDocDiagramRendererValue -Object $node -Name "evidence_refs" -Default @() |
                ForEach-Object { [string]$_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }
    foreach ($edge in @(Get-AppDocDiagramRendererValue -Object $GraphData -Name "edges" -Default @())) {
        $refs += @(
            Get-AppDocDiagramRendererValue -Object $edge -Name "evidence_refs" -Default @() |
                ForEach-Object { [string]$_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
    }

    return @($refs | Select-Object -Unique | Select-Object -First $Limit)
}

function Get-AppDocDiagramNodeClassName {
    [CmdletBinding()]
    param(
        [string]$NodeType
    )

    switch ($NodeType) {
        "actor" { return "actor" }
        "inbound" { return "inbound" }
        "outbound" { return "outbound" }
        "component" { return "component" }
        "data" { return "data" }
        "config" { return "config" }
        "external" { return "external" }
        "dependency" { return "dependency" }
        default { return "component" }
    }
}

function New-AppDocMermaidClassDefs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Contract
    )

    $styles = Get-AppDocDiagramRendererValue -Object (Get-AppDocDiagramRendererValue -Object $Contract -Name "style" -Default @{}) -Name "classes" -Default @{}
    $lines = @()
    foreach ($key in @("actor","inbound","outbound","component","data","config","external","dependency")) {
        $styleValue = [string](Get-AppDocDiagramRendererValue -Object $styles -Name $key -Default "")
        if ([string]::IsNullOrWhiteSpace($styleValue)) { continue }
        $lines += ("classDef {0} {1}" -f $key, $styleValue)
    }
    return $lines
}

function Get-AppDocDiagramNodeMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData
    )

    $map = @{}
    foreach ($node in @(Get-AppDocDiagramRendererValue -Object $GraphData -Name "nodes" -Default @())) {
        $id = [string](Get-AppDocDiagramRendererValue -Object $node -Name "id" -Default "")
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        if (-not $map.ContainsKey($id)) { $map[$id] = $node }
    }
    return $map
}

function New-AppDocGroupedMermaidLines {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$NodeMap,
        [Parameter(Mandatory=$true)]
        [hashtable]$GroupMap
    )

    $lines = @()
    foreach ($groupId in @("actors","inputs","processing","data","outputs","dependencies")) {
        if (-not $GroupMap.ContainsKey($groupId)) { continue }
        $group = $GroupMap[$groupId]
        $title = [string](Get-AppDocDiagramRendererValue -Object $group -Name "title" -Default $groupId)
        $nodeIds = @(
            Get-AppDocDiagramRendererValue -Object $group -Name "nodeIds" -Default @() |
                ForEach-Object { [string]$_ } |
                Where-Object { $NodeMap.ContainsKey($_) } |
                Select-Object -Unique
        )
        if ($nodeIds.Count -eq 0) { continue }

        $lines += ('    subgraph {0}["{1}"]' -f $groupId, (ConvertTo-AppDocMermaidLabel -Label $title))
        foreach ($nodeId in $nodeIds) {
            $label = [string](Get-AppDocDiagramRendererValue -Object $NodeMap[$nodeId] -Name "label" -Default $nodeId)
            $lines += ('        {0}["{1}"]' -f $nodeId, (ConvertTo-AppDocMermaidLabel -Label $label))
        }
        $lines += "    end"
    }
    return $lines
}

function New-AppDocInternalFlowMermaid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData,
        [Parameter(Mandatory=$true)]
        [hashtable]$Contract
    )

    $limits = Get-AppDocDiagramRendererValue -Object $Contract -Name "limits" -Default @{}
    $maxEdges = [int](Get-AppDocDiagramRendererValue -Object $limits -Name "maxEdgesPerDiagram" -Default 120)

    $nodeMap = Get-AppDocDiagramNodeMap -GraphData $GraphData
    $allNodes = @($nodeMap.Values)
    $edges = @(
        Get-AppDocDiagramRendererValue -Object $GraphData -Name "edges" -Default @() |
            Select-Object -First $maxEdges
    )

    $groupMap = @{
        actors = [ordered]@{
            title = "Actors"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "actor" } | ForEach-Object { [string]$_.id })
        }
        inputs = [ordered]@{
            title = "Inbound Interfaces"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "inbound" } | ForEach-Object { [string]$_.id })
        }
        processing = [ordered]@{
            title = "Application Processing"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "component" } | ForEach-Object { [string]$_.id })
        }
        data = [ordered]@{
            title = "Models and Data"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("data","config") } | ForEach-Object { [string]$_.id })
        }
        outputs = [ordered]@{
            title = "Outbound Integrations"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("outbound","external") } | ForEach-Object { [string]$_.id })
        }
        dependencies = [ordered]@{
            title = "Supporting Dependencies"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "dependency" } | ForEach-Object { [string]$_.id })
        }
    }

    $lines = @("flowchart LR")
    $lines += New-AppDocGroupedMermaidLines -NodeMap $nodeMap -GroupMap $groupMap

    foreach ($edge in $edges) {
        $from = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "from" -Default "")
        $to = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "to" -Default "")
        if (-not $nodeMap.ContainsKey($from) -or -not $nodeMap.ContainsKey($to)) { continue }
        $label = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "label" -Default "")
        if ([string]::IsNullOrWhiteSpace($label)) {
            $lines += ("    {0} --> {1}" -f $from, $to)
        }
        else {
            $lines += ("    {0} -->|{1}| {2}" -f $from, (ConvertTo-AppDocMermaidLabel -Label $label), $to)
        }
    }

    foreach ($node in $allNodes) {
        $nodeId = [string](Get-AppDocDiagramRendererValue -Object $node -Name "id" -Default "")
        $className = Get-AppDocDiagramNodeClassName -NodeType ([string](Get-AppDocDiagramRendererValue -Object $node -Name "type" -Default "component"))
        if (-not [string]::IsNullOrWhiteSpace($nodeId)) {
            $lines += ("    class {0} {1}" -f $nodeId, $className)
        }
    }

    $lines += New-AppDocMermaidClassDefs -Contract $Contract
    return ($lines -join "`n")
}

function New-AppDocDataFlowMermaid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData,
        [Parameter(Mandatory=$true)]
        [hashtable]$Contract
    )

    $limits = Get-AppDocDiagramRendererValue -Object $Contract -Name "limits" -Default @{}
    $maxEdges = [int](Get-AppDocDiagramRendererValue -Object $limits -Name "maxEdgesPerDiagram" -Default 120)
    $nodeMap = Get-AppDocDiagramNodeMap -GraphData $GraphData
    $allNodes = @($nodeMap.Values)

    $edges = @(
        Get-AppDocDiagramRendererValue -Object $GraphData -Name "edges" -Default @() |
            Where-Object { [string]$_.type -in @("request","routes","configures","data","returns","invoke","calls") } |
            Select-Object -First $maxEdges
    )

    $groupMap = @{
        inputs = [ordered]@{
            title = "Inputs"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("actor","inbound","config") } | ForEach-Object { [string]$_.id })
        }
        processing = [ordered]@{
            title = "Transforms"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "component" } | ForEach-Object { [string]$_.id })
        }
        data = [ordered]@{
            title = "Data Structures"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "data" } | ForEach-Object { [string]$_.id })
        }
        outputs = [ordered]@{
            title = "Outputs"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("outbound","external","dependency") } | ForEach-Object { [string]$_.id })
        }
    }

    $lines = @("flowchart LR")
    $lines += New-AppDocGroupedMermaidLines -NodeMap $nodeMap -GroupMap $groupMap

    foreach ($edge in $edges) {
        $from = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "from" -Default "")
        $to = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "to" -Default "")
        if (-not $nodeMap.ContainsKey($from) -or -not $nodeMap.ContainsKey($to)) { continue }
        $label = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "label" -Default "")
        if ([string]::IsNullOrWhiteSpace($label)) {
            $lines += ("    {0} --> {1}" -f $from, $to)
        }
        else {
            $lines += ("    {0} -->|{1}| {2}" -f $from, (ConvertTo-AppDocMermaidLabel -Label $label), $to)
        }
    }

    foreach ($node in $allNodes) {
        $nodeId = [string](Get-AppDocDiagramRendererValue -Object $node -Name "id" -Default "")
        $className = Get-AppDocDiagramNodeClassName -NodeType ([string](Get-AppDocDiagramRendererValue -Object $node -Name "type" -Default "component"))
        if (-not [string]::IsNullOrWhiteSpace($nodeId)) {
            $lines += ("    class {0} {1}" -f $nodeId, $className)
        }
    }

    $lines += New-AppDocMermaidClassDefs -Contract $Contract
    return ($lines -join "`n")
}

function Get-AppDocSequenceScenarios {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData,
        [Parameter(Mandatory=$true)]
        [hashtable]$Contract
    )

    $limits = Get-AppDocDiagramRendererValue -Object $Contract -Name "limits" -Default @{}
    $maxScenarios = [int](Get-AppDocDiagramRendererValue -Object $limits -Name "maxSequenceScenarios" -Default 5)
    if ($maxScenarios -lt 1) { $maxScenarios = 1 }

    $nodeMap = Get-AppDocDiagramNodeMap -GraphData $GraphData
    $edges = @(
        Get-AppDocDiagramRendererValue -Object $GraphData -Name "edges" -Default @()
    )

    $requestByInbound = @{}
    foreach ($edge in @($edges | Where-Object { [string]$_.type -eq "request" })) {
        $to = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "to" -Default "")
        if ([string]::IsNullOrWhiteSpace($to)) { continue }
        if (-not $requestByInbound.ContainsKey($to)) { $requestByInbound[$to] = @() }
        $requestByInbound[$to] += $edge
    }

    $outboundByComponent = @{}
    foreach ($edge in @($edges | Where-Object { [string]$_.type -in @("invoke","calls") })) {
        $from = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "from" -Default "")
        if ([string]::IsNullOrWhiteSpace($from)) { continue }
        if (-not $outboundByComponent.ContainsKey($from)) { $outboundByComponent[$from] = @() }
        $outboundByComponent[$from] += $edge
    }

    $dataByComponent = @{}
    foreach ($edge in @($edges | Where-Object { [string]$_.type -in @("returns","data") })) {
        $from = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "from" -Default "")
        if ([string]::IsNullOrWhiteSpace($from)) { continue }
        if (-not $dataByComponent.ContainsKey($from)) { $dataByComponent[$from] = @() }
        $dataByComponent[$from] += $edge
    }

    $routeEdges = @(
        $edges |
            Where-Object { [string]$_.type -eq "routes" } |
            Sort-Object @{ Expression = { [string]$_.from } }, @{ Expression = { [string]$_.to } }
    )

    $scenarios = @()
    foreach ($route in $routeEdges) {
        $endpointId = [string](Get-AppDocDiagramRendererValue -Object $route -Name "from" -Default "")
        $componentId = [string](Get-AppDocDiagramRendererValue -Object $route -Name "to" -Default "")
        if ([string]::IsNullOrWhiteSpace($endpointId) -or [string]::IsNullOrWhiteSpace($componentId)) { continue }
        if (-not $nodeMap.ContainsKey($endpointId) -or -not $nodeMap.ContainsKey($componentId)) { continue }

        $endpointNode = $nodeMap[$endpointId]
        $componentNode = $nodeMap[$componentId]
        $requestEdge = $null
        if ($requestByInbound.ContainsKey($endpointId)) {
            $requestEdge = @($requestByInbound[$endpointId] | Select-Object -First 1)[0]
        }
        $requestFrom = if ($requestEdge) { [string](Get-AppDocDiagramRendererValue -Object $requestEdge -Name "from" -Default "") } else { "" }
        if ([string]::IsNullOrWhiteSpace($requestFrom)) {
            $requestFrom = @(
                $nodeMap.Keys |
                    Where-Object { [string](Get-AppDocDiagramRendererValue -Object $nodeMap[$_] -Name "type" -Default "") -eq "actor" } |
                    Select-Object -First 1
            )[0]
        }
        if ([string]::IsNullOrWhiteSpace($requestFrom) -or -not $nodeMap.ContainsKey($requestFrom)) { continue }

        $outboundEdge = $null
        if ($outboundByComponent.ContainsKey($componentId)) {
            $outboundEdge = @($outboundByComponent[$componentId] | Select-Object -First 1)[0]
        }
        $dataEdge = $null
        if ($dataByComponent.ContainsKey($componentId)) {
            $dataEdge = @($dataByComponent[$componentId] | Select-Object -First 1)[0]
        }

        $score = 1
        if ($outboundEdge) { $score += 2 }
        if ($dataEdge) { $score += 1 }
        $evidenceRefsForRoute = @(
            Get-AppDocDiagramRendererValue -Object $route -Name "evidence_refs" -Default @()
        )
        $score += [Math]::Max(0, [int]$evidenceRefsForRoute.Count)

        $scenarios += [ordered]@{
            actorId = $requestFrom
            endpointId = $endpointId
            componentId = $componentId
            dataEdge = $dataEdge
            outboundEdge = $outboundEdge
            score = $score
            title = (ConvertTo-AppDocMermaidLabel -Label ([string](Get-AppDocDiagramRendererValue -Object $endpointNode -Name "label" -Default $endpointId)))
        }
    }

    return @(
        $scenarios |
            Sort-Object @{ Expression = { [int]$_.score }; Descending = $true }, @{ Expression = { [string]$_.title } } |
            Select-Object -First $maxScenarios
    )
}

function New-AppDocCriticalSequencesMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData,
        [Parameter(Mandatory=$true)]
        [hashtable]$Contract
    )

    $nodeMap = Get-AppDocDiagramNodeMap -GraphData $GraphData
    $scenarios = Get-AppDocSequenceScenarios -GraphData $GraphData -Contract $Contract
    $refs = Get-AppDocDiagramTopEvidenceRefs -GraphData $GraphData -Limit 16

    $lines = @()
    $lines += "# Critical Sequences"
    $lines += ""
    $lines += "_Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')_"
    $lines += ""
    $lines += "## What This View Explains"
    $lines += ""
    $lines += "This artifact captures the highest-signal runtime request journeys from deterministic evidence so teams can review end-to-end behavior quickly."
    $lines += ""

    if ($scenarios.Count -eq 0) {
        $lines += "No high-confidence request journeys were available for scenario rendering in this scan."
        $lines += ""
        $lines += "## Baseline Sequence"
        $lines += ""
        $lines += '```mermaid'
        $lines += "sequenceDiagram"
        $lines += "    autonumber"
        $lines += "    participant caller as Caller"
        $lines += "    participant system as Application"
        $lines += "    caller->>system: Request"
        $lines += "    system-->>caller: Response"
        $lines += '```'
        $lines += ""
    }
    else {
        $scenarioIndex = 0
        foreach ($scenario in $scenarios) {
            $scenarioIndex++
            $actorNode = $nodeMap[[string]($scenario.actorId)]
            $endpointNode = $nodeMap[[string]($scenario.endpointId)]
            $componentNode = $nodeMap[[string]($scenario.componentId)]
            $actorLabel = ConvertTo-AppDocMermaidLabel -Label ([string](Get-AppDocDiagramRendererValue -Object $actorNode -Name "label" -Default "Caller"))
            $endpointLabel = ConvertTo-AppDocMermaidLabel -Label ([string](Get-AppDocDiagramRendererValue -Object $endpointNode -Name "label" -Default "Endpoint"))
            $componentLabel = ConvertTo-AppDocMermaidLabel -Label ([string](Get-AppDocDiagramRendererValue -Object $componentNode -Name "label" -Default "Component"))
            $sectionTitle = [string]($scenario.title)
            if ([string]::IsNullOrWhiteSpace($sectionTitle)) { $sectionTitle = "Scenario $scenarioIndex" }

            $lines += ("## Scenario {0}: {1}" -f $scenarioIndex, $sectionTitle)
            $lines += ""
            $lines += '```mermaid'
            $lines += "sequenceDiagram"
            $lines += "    autonumber"
            $lines += ("    participant actor as {0}" -f $actorLabel)
            $lines += ("    participant endpoint as {0}" -f $endpointLabel)
            $lines += ("    participant component as {0}" -f $componentLabel)
            $lines += "    actor->>endpoint: Request"
            $lines += "    endpoint->>component: Route request"

            if ($scenario.dataEdge) {
                $dataTo = [string](Get-AppDocDiagramRendererValue -Object $scenario.dataEdge -Name "to" -Default "")
                if ($nodeMap.ContainsKey($dataTo)) {
                    $dataNode = $nodeMap[$dataTo]
                    $dataLabel = ConvertTo-AppDocMermaidLabel -Label ([string](Get-AppDocDiagramRendererValue -Object $dataNode -Name "label" -Default "Data Model"))
                    $lines += ("    participant data as {0}" -f $dataLabel)
                    $lines += "    component->>data: Read/Write"
                }
            }

            if ($scenario.outboundEdge) {
                $outboundTo = [string](Get-AppDocDiagramRendererValue -Object $scenario.outboundEdge -Name "to" -Default "")
                if ($nodeMap.ContainsKey($outboundTo)) {
                    $outboundNode = $nodeMap[$outboundTo]
                    $outboundLabel = ConvertTo-AppDocMermaidLabel -Label ([string](Get-AppDocDiagramRendererValue -Object $outboundNode -Name "label" -Default "External Integration"))
                    $lines += ("    participant external as {0}" -f $outboundLabel)
                    $lines += "    component->>external: Invoke integration"
                }
            }

            $lines += "    component-->>actor: Response"
            $lines += '```'
            $lines += ""
        }
    }

    $lines += "## Evidence Refs"
    $lines += ""
    if ($refs.Count -gt 0) {
        foreach ($ref in $refs) { $lines += "- $ref" }
    }
    else {
        $lines += "- No evidence references captured in this run."
    }
    $lines += ""
    return ($lines -join "`n")
}

function Get-AppDocLineagePartitionRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData,
        [Parameter(Mandatory=$true)]
        [hashtable]$Contract
    )

    $limits = Get-AppDocDiagramRendererValue -Object $Contract -Name "limits" -Default @{}
    $maxNodesPerDiagram = [int](Get-AppDocDiagramRendererValue -Object $limits -Name "maxLineageNodesPerDiagram" -Default 18)
    if ($maxNodesPerDiagram -lt 4) { $maxNodesPerDiagram = 18 }
    $maxEdgesPerDiagram = [int](Get-AppDocDiagramRendererValue -Object $limits -Name "maxLineageEdgesPerDiagram" -Default 80)

    $nodeMap = Get-AppDocDiagramNodeMap -GraphData $GraphData
    $nodes = @($nodeMap.Values)
    $edges = @(
        Get-AppDocDiagramRendererValue -Object $GraphData -Name "edges" -Default @() |
            Where-Object { [string]$_.type -in @("request","routes","configures","data","returns","invoke","calls","uses") }
    )

    $alwaysNodeIds = @(
        $nodes |
            Where-Object { [string]$_.type -in @("actor","component","config","inbound","outbound","external") } |
            ForEach-Object { [string]$_.id } |
            Select-Object -Unique
    )
    $dataNodeIds = @(
        $nodes |
            Where-Object { [string]$_.type -in @("data","dependency") } |
            Sort-Object @{ Expression = { [string]$_.label } } |
            ForEach-Object { [string]$_.id }
    )

    $partitions = @()

    $coreDataIds = @($dataNodeIds | Select-Object -First $maxNodesPerDiagram)
    $coreAllowed = @($alwaysNodeIds + $coreDataIds | Select-Object -Unique)
    $coreEdges = @(
        $edges |
            Where-Object {
                $from = [string](Get-AppDocDiagramRendererValue -Object $_ -Name "from" -Default "")
                $to = [string](Get-AppDocDiagramRendererValue -Object $_ -Name "to" -Default "")
                ($coreAllowed -contains $from) -and ($coreAllowed -contains $to)
            } |
            Select-Object -First $maxEdgesPerDiagram
    )
    $partitions += [ordered]@{
        id = "core"
        title = "Data Lineage (Core)"
        nodeIds = $coreAllowed
        edges = $coreEdges
    }

    $remaining = @()
    if ($dataNodeIds.Count -gt $maxNodesPerDiagram) {
        $remaining = @($dataNodeIds | Select-Object -Skip $maxNodesPerDiagram)
    }

    $partNumber = 2
    while ($remaining.Count -gt 0) {
        $chunk = @($remaining | Select-Object -First $maxNodesPerDiagram)
        if ($chunk.Count -eq 0) { break }
        $allowed = @($alwaysNodeIds + $chunk | Select-Object -Unique)
        $chunkEdges = @(
            $edges |
                Where-Object {
                    $from = [string](Get-AppDocDiagramRendererValue -Object $_ -Name "from" -Default "")
                    $to = [string](Get-AppDocDiagramRendererValue -Object $_ -Name "to" -Default "")
                    ($allowed -contains $from) -and ($allowed -contains $to)
                } |
                Select-Object -First $maxEdgesPerDiagram
        )

        $partitions += [ordered]@{
            id = ("part-{0:d2}" -f $partNumber)
            title = ("Data Lineage (Part {0})" -f $partNumber)
            nodeIds = $allowed
            edges = $chunkEdges
        }
        $partNumber++
        $remaining = @($remaining | Select-Object -Skip $maxNodesPerDiagram)
    }

    return $partitions
}

function New-AppDocDataLineageMermaid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData,
        [Parameter(Mandatory=$true)]
        [hashtable]$Contract,
        [Parameter(Mandatory=$true)]
        [hashtable]$Partition
    )

    $nodeMap = Get-AppDocDiagramNodeMap -GraphData $GraphData
    $nodeIds = @(
        Get-AppDocDiagramRendererValue -Object $Partition -Name "nodeIds" -Default @() |
            ForEach-Object { [string]$_ } |
            Where-Object { $nodeMap.ContainsKey($_) } |
            Select-Object -Unique
    )
    $allNodes = @($nodeIds | ForEach-Object { $nodeMap[$_] })
    $edges = @(
        Get-AppDocDiagramRendererValue -Object $Partition -Name "edges" -Default @()
    )

    $groupMap = @{
        inputs = [ordered]@{
            title = "Inputs"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("actor","inbound","config") } | ForEach-Object { [string]$_.id })
        }
        processing = [ordered]@{
            title = "Transforms"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "component" } | ForEach-Object { [string]$_.id })
        }
        data = [ordered]@{
            title = "Data and Dependencies"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("data","dependency") } | ForEach-Object { [string]$_.id })
        }
        outputs = [ordered]@{
            title = "Outputs"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("outbound","external") } | ForEach-Object { [string]$_.id })
        }
    }

    $lines = @("flowchart LR")
    $lines += New-AppDocGroupedMermaidLines -NodeMap $nodeMap -GroupMap $groupMap

    foreach ($edge in $edges) {
        $from = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "from" -Default "")
        $to = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "to" -Default "")
        if (-not $nodeMap.ContainsKey($from) -or -not $nodeMap.ContainsKey($to)) { continue }
        $label = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "label" -Default "")
        if ([string]::IsNullOrWhiteSpace($label)) {
            $lines += ("    {0} --> {1}" -f $from, $to)
        }
        else {
            $lines += ("    {0} -->|{1}| {2}" -f $from, (ConvertTo-AppDocMermaidLabel -Label $label), $to)
        }
    }

    foreach ($node in $allNodes) {
        $nodeId = [string](Get-AppDocDiagramRendererValue -Object $node -Name "id" -Default "")
        $className = Get-AppDocDiagramNodeClassName -NodeType ([string](Get-AppDocDiagramRendererValue -Object $node -Name "type" -Default "component"))
        if (-not [string]::IsNullOrWhiteSpace($nodeId)) {
            $lines += ("    class {0} {1}" -f $nodeId, $className)
        }
    }
    $lines += New-AppDocMermaidClassDefs -Contract $Contract
    return ($lines -join "`n")
}

function New-AppDocDiagramMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$IntentText,
        [Parameter(Mandatory=$true)]
        [string]$Mermaid,
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData
    )

    $metrics = Get-AppDocDiagramRendererValue -Object $GraphData -Name "metrics" -Default @{}
    $refs = Get-AppDocDiagramTopEvidenceRefs -GraphData $GraphData -Limit 12

    $lines = @()
    $lines += "# $Title"
    $lines += ""
    $lines += "_Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')_"
    $lines += ""
    $lines += "## What This View Explains"
    $lines += ""
    $lines += $IntentText
    $lines += ""
    $lines += "## Diagram"
    $lines += ""
    $lines += '```mermaid'
    $lines += $Mermaid
    $lines += '```'
    $lines += ""
    $lines += "## Reading Notes"
    $lines += ""
    $lines += "- Solid arrows represent deterministic code-evidenced relationships."
    $lines += "- Nodes are filtered and ordered for readability; full detail remains in evidence artifacts."
    $lines += ("- Coverage snapshot: {0} nodes, {1} edges, {2} inbound interfaces, {3} outbound integrations." -f `
        [int](Get-AppDocDiagramRendererValue -Object $metrics -Name "nodeCount" -Default 0), `
        [int](Get-AppDocDiagramRendererValue -Object $metrics -Name "edgeCount" -Default 0), `
        [int](Get-AppDocDiagramRendererValue -Object $metrics -Name "inboundEndpointCount" -Default 0), `
        [int](Get-AppDocDiagramRendererValue -Object $metrics -Name "outboundEndpointCount" -Default 0))
    $lines += ""
    $lines += "## Evidence Refs"
    $lines += ""
    if ($refs.Count -gt 0) {
        foreach ($ref in $refs) { $lines += "- $ref" }
    }
    else {
        $lines += "- No evidence references captured in this run."
    }
    $lines += ""

    return ($lines -join "`n")
}

function Write-AppDocDiagramSuite {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData,
        [Parameter(Mandatory=$true)]
        [hashtable]$Contract
    )

    $docsPath = Join-Path $RootPath "docs"
    $diagramsPath = Join-Path $docsPath "diagrams"
    if (-not (Test-Path $diagramsPath)) {
        New-Item -Path $diagramsPath -ItemType Directory -Force | Out-Null
    }

    $internalFlowMermaid = New-AppDocInternalFlowMermaid -GraphData $GraphData -Contract $Contract
    $dataFlowMermaid = New-AppDocDataFlowMermaid -GraphData $GraphData -Contract $Contract

    $internalFlowPath = Join-Path $diagramsPath "internal-flow.md"
    $dataFlowPath = Join-Path $diagramsPath "data-flow.md"
    $criticalSequencesPath = Join-Path $diagramsPath "critical-sequences.md"
    $dataLineageCorePath = Join-Path $diagramsPath "data-lineage-core.md"
    $indexPath = Join-Path $diagramsPath "index.md"

    (New-AppDocDiagramMarkdown -Title "Internal Flow Diagram" -IntentText "This view shows how requests move from callers into core processing components and then to data models or external integrations." -Mermaid $internalFlowMermaid -GraphData $GraphData) | Out-File -FilePath $internalFlowPath -Encoding UTF8
    (New-AppDocDiagramMarkdown -Title "Data Flow Diagram" -IntentText "This view traces input sources, processing transformations, and output channels so teams can reason about data movement and side effects." -Mermaid $dataFlowMermaid -GraphData $GraphData) | Out-File -FilePath $dataFlowPath -Encoding UTF8
    (New-AppDocCriticalSequencesMarkdown -GraphData $GraphData -Contract $Contract) | Out-File -FilePath $criticalSequencesPath -Encoding UTF8

    $lineageParts = Get-AppDocLineagePartitionRecords -GraphData $GraphData -Contract $Contract
    $lineageFiles = @()
    $lineageIndex = 0
    foreach ($part in $lineageParts) {
        $lineageIndex++
        $partId = [string](Get-AppDocDiagramRendererValue -Object $part -Name "id" -Default "")
        $partTitle = [string](Get-AppDocDiagramRendererValue -Object $part -Name "title" -Default "Data Lineage")
        $fileName = if ($lineageIndex -eq 1) { "data-lineage-core.md" } else { "data-lineage-{0}.md" -f $partId }
        $filePath = Join-Path $diagramsPath $fileName
        $mermaid = New-AppDocDataLineageMermaid -GraphData $GraphData -Contract $Contract -Partition $part
        (New-AppDocDiagramMarkdown -Title $partTitle -IntentText "This partitioned data-lineage view isolates a subset of data nodes to keep lineage review readable while preserving deterministic topology." -Mermaid $mermaid -GraphData $GraphData) | Out-File -FilePath $filePath -Encoding UTF8
        $lineageFiles += [ordered]@{
            fileName = $fileName
            path = $filePath
            title = $partTitle
        }
    }

    $indexLines = @()
    $indexLines += "# Diagram Index"
    $indexLines += ""
    $indexLines += "Use this sequence to understand architecture quickly: context -> containers -> internal flow -> critical sequences -> data flow -> data lineage."
    $indexLines += ""
    $indexLines += "## Recommended Reading Order"
    $indexLines += ""
    $indexLines += "1. [C4 System Context](c4-context.md)"
    $indexLines += "2. [C4 Container](c4-container.md)"
    $indexLines += "3. [Internal Flow](internal-flow.md)"
    $indexLines += "4. [Critical Sequences](critical-sequences.md)"
    $indexLines += "5. [Data Flow](data-flow.md)"
    $lineageOrder = 6
    foreach ($lineage in $lineageFiles) {
        $indexLines += ("{0}. [{1}]({2})" -f $lineageOrder, [string]$lineage.title, [string]$lineage.fileName)
        $lineageOrder++
    }
    $indexLines += ""
    $indexLines += "## Deterministic Source"
    $indexLines += ""
    $indexLines += "- Truth pack: ``../evidence/diagram-truth-pack.json``"
    $indexLines += "- Graph topology is deterministic; narrative enhancements should preserve node and edge semantics."
    $indexLines += ""
    ($indexLines -join "`n") | Out-File -FilePath $indexPath -Encoding UTF8

    return [ordered]@{
        internalFlow = $internalFlowPath
        dataFlow = $dataFlowPath
        criticalSequences = $criticalSequencesPath
        dataLineageCore = $dataLineageCorePath
        dataLineage = $lineageFiles
        index = $indexPath
    }
}

Export-ModuleMember -Function @(
    'Write-AppDocDiagramSuite'
)
