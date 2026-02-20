function Get-AppDocDiagramRendererValue{param($Object,$Name,$Default);return $null}
function Get-AppDocDiagramNodeMap{param($GraphData);return @{}}
function ConvertTo-AppDocMermaidLabel{param($Label);return $Label}
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
