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
    $value = $value.Replace('|', '/')
    $value = $value.Replace('[', '(').Replace(']', ')')
    $value = $value.Replace('`', "'")
    return $value
}

function Get-AppDocMermaidFlowCounts {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Mermaid
    )

    if ([string]::IsNullOrWhiteSpace($Mermaid)) {
        return [ordered]@{ nodeCount = 0; edgeCount = 0 }
    }

    $nodeIds = New-Object System.Collections.Generic.HashSet[string]
    $edgeCount = 0
    $edgePatterns = @(
        '^(?<from>[A-Za-z][A-Za-z0-9_]*)\s*(-->|-\.->|-+->|==>|<->|<-->|~~~|<==>|<-+->)\s*\|(?<label>[^|]+)\|\s*(?<to>[A-Za-z][A-Za-z0-9_]*)$',
        '^(?<from>[A-Za-z][A-Za-z0-9_]*)\s*(-->|-\.->|-+->|==>|<->|<-->|~~~|<==>|<-+->)\s*(?<to>[A-Za-z][A-Za-z0-9_]*)$'
    )

    foreach ($line in ($Mermaid -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^(flowchart|graph|sequenceDiagram|subgraph|end)\b') { continue }
        if ($trimmed -match '^class(Def)?\b') { continue }
        if ($trimmed -match '^(?<id>[A-Za-z][A-Za-z0-9_]*)\s*\[') {
            [void]$nodeIds.Add([string]$Matches['id'])
            continue
        }

        foreach ($pattern in $edgePatterns) {
            if ($trimmed -match $pattern) {
                $edgeCount++
                [void]$nodeIds.Add([string]$Matches['from'])
                [void]$nodeIds.Add([string]$Matches['to'])
                break
            }
        }
    }

    return [ordered]@{
        nodeCount = [int]$nodeIds.Count
        edgeCount = [int]$edgeCount
    }
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

function Get-AppDocDiagramSemanticEdgeLabel {
    [CmdletBinding()]
    param(
        [string]$EdgeType,
        [string]$CurrentLabel
    )

    $label = if ($CurrentLabel) { [string]$CurrentLabel } else { "" }
    $normalized = $label.Trim().ToLowerInvariant()
    if (-not [string]::IsNullOrWhiteSpace($normalized) -and $normalized -notin @("request","routes","returns","data","invoke","calls","uses","configures","contains")) {
        return $label
    }

    $normalized = if ($EdgeType) { $EdgeType.ToString().Trim().ToLowerInvariant() } else { "" }
    switch ($normalized) {
        "request" { return "initiates" }
        "routes" { return "routes to" }
        "returns" { return "returns" }
        "data" { return "reads/writes" }
        "invoke" { return "invokes" }
        "calls" { return "calls" }
        "uses" { return "uses" }
        "configures" { return "configures" }
        "contains" { return "contains" }
        default {
            if ([string]::IsNullOrWhiteSpace($label)) { return "relates to" }
            return $label
        }
    }
}

function Get-AppDocDiagramEdgeOperator {
    [CmdletBinding()]
    param(
        [string]$EdgeType
    )

    switch (($EdgeType | ForEach-Object { if ($_){ $_.ToString().Trim().ToLowerInvariant() } else { "" } })) {
        "configures" { return "-.->" }
        "uses" { return "-.->" }
        "contains" { return "-.->" }
        default { return "-->" }
    }
}

function New-AppDocMermaidEdgeLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$From,
        [Parameter(Mandatory=$true)]
        [string]$To,
        [string]$EdgeType,
        [string]$EdgeLabel
    )

    $operator = Get-AppDocDiagramEdgeOperator -EdgeType $EdgeType
    $semanticLabel = Get-AppDocDiagramSemanticEdgeLabel -EdgeType $EdgeType -CurrentLabel $EdgeLabel
    if ([string]::IsNullOrWhiteSpace($semanticLabel)) {
        return ("    {0} {1} {2}" -f $From, $operator, $To)
    }

    return ("    {0} {1}|{2}| {3}" -f $From, $operator, (ConvertTo-AppDocMermaidLabel -Label $semanticLabel), $To)
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

function Get-AppDocDiagramOrderedNodes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$GraphData
    )

    return @(
        Get-AppDocDiagramRendererValue -Object $GraphData -Name "nodes" -Default @() |
            Sort-Object @{ Expression = { [string](Get-AppDocDiagramRendererValue -Object $_ -Name "type" -Default "") } }, `
                        @{ Expression = { [string](Get-AppDocDiagramRendererValue -Object $_ -Name "label" -Default "") } }, `
                        @{ Expression = { [string](Get-AppDocDiagramRendererValue -Object $_ -Name "id" -Default "") } }
    )
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
    $preferredOrder = @(
        "actors",
        "inputs",
        "processing",
        "models",
        "runtime_config",
        "workflow_config",
        "dotnet_project",
        "vscode_settings",
        "data",
        "outputs",
        "dependencies"
    )
    $dynamicOrder = @(
        @($preferredOrder + @($GroupMap.Keys)) |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    foreach ($groupId in $dynamicOrder) {
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
    $allNodes = Get-AppDocDiagramOrderedNodes -GraphData $GraphData
    $edges = @(
        Get-AppDocDiagramRendererValue -Object $GraphData -Name "edges" -Default @() |
            Select-Object -First $maxEdges
    )

    $dataNodeIds = @($allNodes | Where-Object { [string]$_.type -eq "data" } | ForEach-Object { [string]$_.id })
    $runtimeConfigIds = @($allNodes | Where-Object { [string]$_.type -eq "config" -and [string]$_.group -eq "config-runtime" } | ForEach-Object { [string]$_.id })
    $workflowConfigIds = @($allNodes | Where-Object { [string]$_.type -eq "config" -and [string]$_.group -eq "config-workflow" } | ForEach-Object { [string]$_.id })
    $dotnetProjectConfigIds = @($allNodes | Where-Object { [string]$_.type -eq "config" -and [string]$_.group -eq "config-dotnet" } | ForEach-Object { [string]$_.id })
    $vscodeConfigIds = @($allNodes | Where-Object { [string]$_.type -eq "config" -and [string]$_.group -eq "config-vscode" } | ForEach-Object { [string]$_.id })
    $otherConfigIds = @(
        $allNodes |
            Where-Object {
                [string]$_.type -eq "config" -and
                [string]$_.group -notin @("config-runtime","config-workflow","config-dotnet","config-vscode")
            } |
            ForEach-Object { [string]$_.id }
    )

    $groupMap = @{
        actors = [ordered]@{
            title = "Trust Boundary: External Actors"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "actor" } | ForEach-Object { [string]$_.id })
        }
        inputs = [ordered]@{
            title = "Trust Boundary: Inbound Interfaces"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "inbound" } | ForEach-Object { [string]$_.id })
        }
        processing = [ordered]@{
            title = "Application Core Services"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "component" } | ForEach-Object { [string]$_.id })
        }
        models = [ordered]@{
            title = "Data Models"
            nodeIds = $dataNodeIds
        }
        runtime_config = [ordered]@{
            title = "Runtime Configuration"
            nodeIds = @($runtimeConfigIds + $otherConfigIds | Select-Object -Unique)
        }
        workflow_config = [ordered]@{
            title = "GitHub Actions Workflow"
            nodeIds = $workflowConfigIds
        }
        dotnet_project = [ordered]@{
            title = ".NET Project Settings"
            nodeIds = $dotnetProjectConfigIds
        }
        vscode_settings = [ordered]@{
            title = "VS Code Settings"
            nodeIds = $vscodeConfigIds
        }
        outputs = [ordered]@{
            title = "Trust Boundary: External Integrations"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("outbound","external") } | ForEach-Object { [string]$_.id })
        }
        dependencies = [ordered]@{
            title = "Supporting Dependencies"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "dependency" } | ForEach-Object { [string]$_.id })
        }
    }

    $lines = @("flowchart LR")
    $lines += "    %% Solid edges: runtime request/data flow. Dashed edges: structural/config/dependency links."
    $lines += New-AppDocGroupedMermaidLines -NodeMap $nodeMap -GroupMap $groupMap

    foreach ($edge in $edges) {
        $from = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "from" -Default "")
        $to = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "to" -Default "")
        if (-not $nodeMap.ContainsKey($from) -or -not $nodeMap.ContainsKey($to)) { continue }
        $label = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "label" -Default "")
        $edgeType = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "type" -Default "")
        $lines += New-AppDocMermaidEdgeLine -From $from -To $to -EdgeType $edgeType -EdgeLabel $label
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
    $allNodes = Get-AppDocDiagramOrderedNodes -GraphData $GraphData

    $edges = @(
        Get-AppDocDiagramRendererValue -Object $GraphData -Name "edges" -Default @() |
            Where-Object { [string]$_.type -in @("request","routes","configures","data","returns","invoke","calls","uses") } |
            Select-Object -First $maxEdges
    )

    $groupMap = @{
        inputs = [ordered]@{
            title = "Input Boundary"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("actor","inbound","config") } | ForEach-Object { [string]$_.id })
        }
        processing = [ordered]@{
            title = "Core Transformations"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "component" } | ForEach-Object { [string]$_.id })
        }
        data = [ordered]@{
            title = "Data Stores and Models"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "data" } | ForEach-Object { [string]$_.id })
        }
        outputs = [ordered]@{
            title = "Output Boundary"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("outbound","external","dependency") } | ForEach-Object { [string]$_.id })
        }
    }

    $lines = @("flowchart LR")
    $lines += "    %% Solid edges: runtime request/data flow. Dashed edges: structural/config/dependency links."
    $lines += New-AppDocGroupedMermaidLines -NodeMap $nodeMap -GroupMap $groupMap

    foreach ($edge in $edges) {
        $from = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "from" -Default "")
        $to = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "to" -Default "")
        if (-not $nodeMap.ContainsKey($from) -or -not $nodeMap.ContainsKey($to)) { continue }
        $label = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "label" -Default "")
        $edgeType = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "type" -Default "")
        $lines += New-AppDocMermaidEdgeLine -From $from -To $to -EdgeType $edgeType -EdgeLabel $label
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
    $orderedNodes = Get-AppDocDiagramOrderedNodes -GraphData $GraphData
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
                $orderedNodes |
                    Where-Object { [string](Get-AppDocDiagramRendererValue -Object $_ -Name "type" -Default "") -eq "actor" } |
                    ForEach-Object { [string](Get-AppDocDiagramRendererValue -Object $_ -Name "id" -Default "") } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
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
            requestEdge = $requestEdge
            routeEdge = $route
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
        if ($refs.Count -gt 0) {
            $lines += "Evidence was scanned (" + (($refs -join ", ")) + ") but was insufficient for reconstructing high-confidence request journeys."
        }
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
            $requestEdgeType = if ($scenario.requestEdge) { [string](Get-AppDocDiagramRendererValue -Object $scenario.requestEdge -Name "type" -Default "request") } else { "request" }
            $requestEdgeLabel = if ($scenario.requestEdge) { [string](Get-AppDocDiagramRendererValue -Object $scenario.requestEdge -Name "label" -Default "") } else { "" }
            $requestAction = ConvertTo-AppDocMermaidLabel -Label (Get-AppDocDiagramSemanticEdgeLabel -EdgeType $requestEdgeType -CurrentLabel $requestEdgeLabel)
            if ([string]::IsNullOrWhiteSpace($requestAction)) { $requestAction = "Request" }

            $routeEdgeType = if ($scenario.routeEdge) { [string](Get-AppDocDiagramRendererValue -Object $scenario.routeEdge -Name "type" -Default "routes") } else { "routes" }
            $routeEdgeLabel = if ($scenario.routeEdge) { [string](Get-AppDocDiagramRendererValue -Object $scenario.routeEdge -Name "label" -Default "") } else { "" }
            $routeAction = ConvertTo-AppDocMermaidLabel -Label (Get-AppDocDiagramSemanticEdgeLabel -EdgeType $routeEdgeType -CurrentLabel $routeEdgeLabel)
            if ([string]::IsNullOrWhiteSpace($routeAction)) { $routeAction = "Routes to" }

            $lines += ("    actor->>endpoint: {0}" -f $requestAction)
            $lines += ("    endpoint->>component: {0}" -f $routeAction)

            if ($scenario.dataEdge) {
                $dataTo = [string](Get-AppDocDiagramRendererValue -Object $scenario.dataEdge -Name "to" -Default "")
                if ($nodeMap.ContainsKey($dataTo)) {
                    $dataNode = $nodeMap[$dataTo]
                    $dataLabel = ConvertTo-AppDocMermaidLabel -Label ([string](Get-AppDocDiagramRendererValue -Object $dataNode -Name "label" -Default "Data Model"))
                    $dataEdgeType = [string](Get-AppDocDiagramRendererValue -Object $scenario.dataEdge -Name "type" -Default "data")
                    $dataEdgeLabel = [string](Get-AppDocDiagramRendererValue -Object $scenario.dataEdge -Name "label" -Default "")
                    $dataAction = ConvertTo-AppDocMermaidLabel -Label (Get-AppDocDiagramSemanticEdgeLabel -EdgeType $dataEdgeType -CurrentLabel $dataEdgeLabel)
                    if ([string]::IsNullOrWhiteSpace($dataAction)) { $dataAction = "Reads/Writes" }
                    $lines += ("    participant data as {0}" -f $dataLabel)
                    $lines += ("    component->>data: {0}" -f $dataAction)
                }
            }

            if ($scenario.outboundEdge) {
                $outboundTo = [string](Get-AppDocDiagramRendererValue -Object $scenario.outboundEdge -Name "to" -Default "")
                if ($nodeMap.ContainsKey($outboundTo)) {
                    $outboundNode = $nodeMap[$outboundTo]
                    $outboundLabel = ConvertTo-AppDocMermaidLabel -Label ([string](Get-AppDocDiagramRendererValue -Object $outboundNode -Name "label" -Default "External Integration"))
                    $outboundEdgeType = [string](Get-AppDocDiagramRendererValue -Object $scenario.outboundEdge -Name "type" -Default "invoke")
                    $outboundEdgeLabel = [string](Get-AppDocDiagramRendererValue -Object $scenario.outboundEdge -Name "label" -Default "")
                    $outboundAction = ConvertTo-AppDocMermaidLabel -Label (Get-AppDocDiagramSemanticEdgeLabel -EdgeType $outboundEdgeType -CurrentLabel $outboundEdgeLabel)
                    if ([string]::IsNullOrWhiteSpace($outboundAction)) { $outboundAction = "Invokes" }
                    $lines += ("    participant external as {0}" -f $outboundLabel)
                    $lines += ("    component->>external: {0}" -f $outboundAction)
                }
            }

            # Mirror response path through endpoint
            $lines += "    component-->>endpoint: Response"
            $lines += "    endpoint-->>actor: Response"
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
    $nodes = Get-AppDocDiagramOrderedNodes -GraphData $GraphData
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
            title = "Input Boundary"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("actor","inbound","config") } | ForEach-Object { [string]$_.id })
        }
        processing = [ordered]@{
            title = "Core Transformations"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -eq "component" } | ForEach-Object { [string]$_.id })
        }
        data = [ordered]@{
            title = "Data and Dependencies"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("data","dependency") } | ForEach-Object { [string]$_.id })
        }
        outputs = [ordered]@{
            title = "Output Boundary"
            nodeIds = @($allNodes | Where-Object { [string]$_.type -in @("outbound","external") } | ForEach-Object { [string]$_.id })
        }
    }

    $lines = @("flowchart LR")
    $lines += "    %% Solid edges: runtime request/data flow. Dashed edges: structural/config/dependency links."
    $lines += New-AppDocGroupedMermaidLines -NodeMap $nodeMap -GroupMap $groupMap

    foreach ($edge in $edges) {
        $from = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "from" -Default "")
        $to = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "to" -Default "")
        if (-not $nodeMap.ContainsKey($from) -or -not $nodeMap.ContainsKey($to)) { continue }
        $label = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "label" -Default "")
        $edgeType = [string](Get-AppDocDiagramRendererValue -Object $edge -Name "type" -Default "")
        $lines += New-AppDocMermaidEdgeLine -From $from -To $to -EdgeType $edgeType -EdgeLabel $label
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
    $renderedCounts = Get-AppDocMermaidFlowCounts -Mermaid $Mermaid
    $snapshotNodeCount = [int](Get-AppDocDiagramRendererValue -Object $renderedCounts -Name "nodeCount" -Default 0)
    $snapshotEdgeCount = [int](Get-AppDocDiagramRendererValue -Object $renderedCounts -Name "edgeCount" -Default 0)
    if ($snapshotNodeCount -le 0) {
        $snapshotNodeCount = [int](Get-AppDocDiagramRendererValue -Object $metrics -Name "nodeCount" -Default 0)
    }
    if ($snapshotEdgeCount -le 0) {
        $snapshotEdgeCount = [int](Get-AppDocDiagramRendererValue -Object $metrics -Name "edgeCount" -Default 0)
    }
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
        $snapshotNodeCount, `
        $snapshotEdgeCount, `
        [int](Get-AppDocDiagramRendererValue -Object $metrics -Name "inboundEndpointCount" -Default 0), `
        [int](Get-AppDocDiagramRendererValue -Object $metrics -Name "outboundEndpointCount" -Default 0))
    $dependencyCount = [int](Get-AppDocDiagramRendererValue -Object $metrics -Name "dependencyCount" -Default 0)
    if ($dependencyCount -gt 0) {
        $lines += ("- Outbound integrations count protocol/interface endpoints only; supporting dependency outputs in this view: {0}." -f $dependencyCount)
    }
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

    $hasRequestFlow = @(
        Get-AppDocDiagramRendererValue -Object $GraphData -Name "edges" -Default @() |
            Where-Object { [string]$_.type -in @("request","routes") }
    ).Count -gt 0
    $internalFlowTitle = if ($hasRequestFlow) { "Internal Flow Diagram" } else { "Component Dependencies and Configuration" }
    $internalFlowIntent = if ($hasRequestFlow) {
        "This view shows how requests move from callers into core processing components and then to data models or external integrations."
    } else {
        "This view summarizes static component relationships, supporting dependencies, and configuration sources that shape runtime behavior."
    }

    (New-AppDocDiagramMarkdown -Title $internalFlowTitle -IntentText $internalFlowIntent -Mermaid $internalFlowMermaid -GraphData $GraphData) | Out-File -FilePath $internalFlowPath -Encoding UTF8
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
