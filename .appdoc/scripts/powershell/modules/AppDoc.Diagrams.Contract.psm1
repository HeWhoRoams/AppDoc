function Get-AppDocDiagramContract {
    [CmdletBinding()]
    param()

    return [ordered]@{
        schemaVersion = "1.1.0"
        graphSchemaVersion = "appdoc-graph/v1"
        requiredViews = @(
            [ordered]@{ id = "c4-context"; file = "c4-context.md"; purpose = "System boundary and external actors." }
            [ordered]@{ id = "c4-container"; file = "c4-container.md"; purpose = "Deployable/runtime containers and relationships." }
            [ordered]@{ id = "internal-flow"; file = "internal-flow.md"; purpose = "Core request and processing flow." }
            [ordered]@{ id = "data-flow"; file = "data-flow.md"; purpose = "Input, transform, persistence, and output movement." }
            [ordered]@{ id = "critical-sequences"; file = "critical-sequences.md"; purpose = "Deterministic critical request journeys in sequence form." }
            [ordered]@{ id = "data-lineage-core"; file = "data-lineage-core.md"; purpose = "Partitioned core data lineage flow for readability." }
        )
        limits = [ordered]@{
            maxInboundEndpoints = 24
            maxOutboundEndpoints = 12
            maxComponents = 18
            maxModels = 24
            maxConfigs = 12
            maxDependencies = 12
            maxEdgesPerDiagram = 120
            maxLabelLength = 72
            maxSequenceScenarios = 5
            maxLineageNodesPerDiagram = 18
            maxLineageEdgesPerDiagram = 80
        }
        style = [ordered]@{
            direction = "LR"
            classes = [ordered]@{
                actor = "fill:#0f172a,stroke:#0f172a,color:#ffffff,stroke-width:1px"
                inbound = "fill:#dcfce7,stroke:#166534,color:#166534,stroke-width:1px"
                outbound = "fill:#ffedd5,stroke:#9a3412,color:#9a3412,stroke-width:1px"
                component = "fill:#dbeafe,stroke:#1d4ed8,color:#1d4ed8,stroke-width:1px"
                data = "fill:#fef9c3,stroke:#854d0e,color:#854d0e,stroke-width:1px"
                config = "fill:#f5f3ff,stroke:#5b21b6,color:#5b21b6,stroke-width:1px"
                external = "fill:#fee2e2,stroke:#991b1b,color:#991b1b,stroke-width:1px"
                dependency = "fill:#ede9fe,stroke:#4338ca,color:#4338ca,stroke-width:1px"
            }
        }
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocDiagramContract'
)
