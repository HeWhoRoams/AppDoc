function Get-AppDocDiagramNodeMap{param($GraphData); return @{a=@{label="x"}}}
function Get-AppDocSequenceScenarios{param($GraphData,$Contract); return @()}
function Get-AppDocDiagramTopEvidenceRefs{param($GraphData,$Limit); return @()}
function ConvertTo-AppDocMermaidLabel{param($Label); return $Label}
function Get-AppDocDiagramRendererValue{param($Object,$Name,$Default); return $Default}
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
        $lines += "No deterministic request journeys were detected for sequence rendering in this scan."
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
            $lines += "```mermaid"
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
            $lines += "```"
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

