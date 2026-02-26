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
    $value = $value.Replace('|', '/')
    $value = $value.Replace("`r", " ").Replace("`n", " ")
    return $value}

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
