param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [switch]$Strict,
    [Parameter(Mandatory=$false)]
    [switch]$Json
)

$contractModule = Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Diagrams.Contract.psm1'
$normalizerModule = Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Diagrams.Normalizer.psm1'
if (-not (Test-Path $contractModule)) {
    Write-Error "Required module not found: $contractModule"
    exit 1
}
Import-Module $contractModule -Force -ErrorAction Stop
if (Test-Path $normalizerModule) {
    Import-Module $normalizerModule -Force -ErrorAction SilentlyContinue
}

function Get-DiagramValidationValue {
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

function Get-MermaidBlockContent {
    param([string]$Markdown)

    if ([string]::IsNullOrWhiteSpace($Markdown)) { return "" }
    $match = [regex]::Match($Markdown, '(?ms)```mermaid\s*(.*?)\s*```')
    if ($match.Success) {
        return [string]$match.Groups[1].Value
    }
    return ""
}

function Get-MermaidFlowCounts {
    param([string]$Mermaid)

    if ([string]::IsNullOrWhiteSpace($Mermaid)) {
        return [ordered]@{ nodeCount = 0; edgeCount = 0 }
    }

    $nodeIds = New-Object System.Collections.Generic.HashSet[string]
    $edgeCount = 0
    foreach ($line in ($Mermaid -split "`r?`n")) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        if ($trimmed -match '^(flowchart|graph|sequenceDiagram|subgraph|end)\b') { continue }
        if ($trimmed -match '^class(Def)?\b') { continue }
        if ($trimmed -match '^(?<id>[A-Za-z][A-Za-z0-9_]*)\s*\[') {
            [void]$nodeIds.Add([string]$Matches['id'])
            continue
        }
        # Expanded Mermaid edge detection: require matching pipe pairs for labels, support more connectors
        # Supported connectors: -->, -+->, ==>, <->, <-->, ~~~, ==> , <==>, etc.
        $edgePattern = @(
            # With label (require both pipes)
            '^(?<from>[A-Za-z][A-Za-z0-9_]*)\s*(-->|-+->|==>|<->|<-->|~~~|==>|<==>|<-+->)\s*\|(?<label>[^|]+)\|\s*(?<to>[A-Za-z][A-Za-z0-9_]*)$',
            # Without label
            '^(?<from>[A-Za-z][A-Za-z0-9_]*)\s*(-->|-+->|==>|<->|<-->|~~~|==>|<==>|<-+->)\s*(?<to>[A-Za-z][A-Za-z0-9_]*)$'
        )
        $matched = $false
        foreach ($pat in $edgePattern) {
            if ($trimmed -match $pat) {
                $edgeCount++
                [void]$nodeIds.Add([string]$Matches['from'])
                [void]$nodeIds.Add([string]$Matches['to'])
                $matched = $true
                break
            }
        }
        }
    }

    return [ordered]@{
        nodeCount = [int]$nodeIds.Count
        edgeCount = [int]$edgeCount
    }
}

function Get-DiagramCoverageSnapshot {
    param([string]$Markdown)

    if ([string]::IsNullOrWhiteSpace($Markdown)) { return $null }
    $match = [regex]::Match(
        $Markdown,
        '(?im)Coverage snapshot:\s*(\d+)\s*nodes,\s*(\d+)\s*edges,\s*(\d+)\s*inbound interfaces,\s*(\d+)\s*outbound integrations'
    )
    if (-not $match.Success) { return $null }

    return [ordered]@{
        nodeCount = [int]$match.Groups[1].Value
        edgeCount = [int]$match.Groups[2].Value
        inboundCount = [int]$match.Groups[3].Value
        outboundCount = [int]$match.Groups[4].Value
    }
}

$contract = $null
try {
    $contract = Get-AppDocDiagramContract -ErrorAction Stop
} catch {
    Write-Error "Failed to get diagram contract: $($_.Exception.Message)"
    exit 1
}
if ($null -eq $contract -or $contract.Count -eq 0) {
    Write-Error "Diagram contract is null or empty. Cannot proceed."
    exit 1
}
$diagramsPath = Join-Path $RootPath (Join-Path "docs" "diagrams")
$truthPackPath = Join-Path $RootPath (Join-Path "docs" (Join-Path "evidence" "diagram-truth-pack.json"))

$issues = @()
$details = @()
$truthPackValidation = $null
$diagramContentMap = @{}
$diagramMermaidCountMap = @{}
$diagramCoverageSnapshotMap = @{}
$requiredViews = @(if ($contract -and $contract.requiredViews) { $contract.requiredViews } else { @() })

foreach ($view in $requiredViews) {
    $file = [string]$view.file
    if ([string]::IsNullOrWhiteSpace($file)) { continue }
    $path = Join-Path $diagramsPath $file
    $exists = Test-Path $path
    $hasMermaidFence = $false
    $size = 0
    if ($exists) {
        $content = Get-Content $path -Raw
        if ($null -eq $content) { $content = "" }
        $diagramContentMap[$file] = $content
        $size = $content.Length
$hasMermaidFence = ($content -match '(?ms)
        }
        $snapshot = Get-DiagramCoverageSnapshot -Markdown $content
        if ($snapshot) {
            $diagramCoverageSnapshotMap[$file] = $snapshot
        }
        $placeholderPhrases = @(
            'no diagram detected',
            'no image detected',
            'no mermaid detected',
            'no sequence detected',
            'no flow detected'
        )
        foreach ($phrase in $placeholderPhrases) {
            if ($content.Trim().ToLower() -eq $phrase) {
                $issues += "placeholder-like-content:$file"
                break
            }
        }
        if ($size -lt 80) {
            $issues += "diagram-too-small:$file"
        }

        if ($file -eq "c4-context.md" -and $content -notmatch '(?im)^\s*C4Context\s*$') {
            $issues += "missing-c4context-directive:$file"
        }
        if ($file -eq "c4-container.md" -and $content -notmatch '(?im)^\s*C4Container\s*$') {
            $issues += "missing-c4container-directive:$file"
        }
        if ($file -in @("internal-flow.md","data-flow.md","data-lineage-core.md") -and $content -notmatch '(?im)^\s*flowchart\s+(LR|TD)\s*$') {
            $issues += "missing-flowchart-directive:$file"
        }
        if ($file -eq "critical-sequences.md" -and $content -notmatch '(?im)^\s*sequenceDiagram\s*$') {
            $issues += "missing-sequence-directive:$file"
        }
    }
    else {
        $issues += "missing-diagram:$file"
    }

    $details += [ordered]@{
        file = $file
        path = $path
        exists = $exists
        hasMermaidFence = $hasMermaidFence
        length = $size
    }
}

if (-not (Test-Path $truthPackPath)) {
    $issues += "missing-truth-pack:diagram-truth-pack.json"
}
else {
    try {
        $truthPack = Get-Content $truthPackPath -Raw | ConvertFrom-Json -Depth 100
        $expectedGraphSchema = "appdoc-graph/v1"
        if ($contract.graphSchemaVersion) {
            $expectedGraphSchema = [string]$contract.graphSchemaVersion
        }

        $actualGraphSchema = ""
        if ($truthPack.schemaVersion) {
            $actualGraphSchema = [string]$truthPack.schemaVersion
        }
        if ([string]::IsNullOrWhiteSpace($actualGraphSchema)) {
            $issues += "truth-pack-schema-missing"
        }
        elseif ($actualGraphSchema -ne $expectedGraphSchema) {
            $issues += ("truth-pack-schema-mismatch:{0}" -f $actualGraphSchema)
        }

        if (Get-Command Test-AppDocGraphV1 -ErrorAction SilentlyContinue) {
            $truthPackValidation = Test-AppDocGraphV1 -Graph $truthPack
            if (-not $truthPackValidation.passed) {
                $truthMetricsForContract = Get-DiagramValidationValue -Object $truthPack -Name "metrics" -Default @{}
                $truthEdgeCountForContract = [int](Get-DiagramValidationValue -Object $truthMetricsForContract -Name "edgeCount" -Default 0)
                $truthInboundForContract = [int](Get-DiagramValidationValue -Object $truthMetricsForContract -Name "inboundEndpointCount" -Default 0)
                $truthOutboundForContract = [int](Get-DiagramValidationValue -Object $truthMetricsForContract -Name "outboundEndpointCount" -Default 0)
                foreach ($graphIssue in @($truthPackValidation.issues)) {
                    if ([string]$graphIssue -eq "edges-empty" -and $truthEdgeCountForContract -eq 0 -and $truthInboundForContract -eq 0 -and $truthOutboundForContract -eq 0) {
                        continue
                    }
                    $issues += ("truth-pack-contract:{0}" -f [string]$graphIssue)
                }
            }
        }

        $truthMetrics = Get-DiagramValidationValue -Object $truthPack -Name "metrics" -Default @{}
        $truthNodeCount = [int](Get-DiagramValidationValue -Object $truthMetrics -Name "nodeCount" -Default 0)
        $truthEdgeCount = [int](Get-DiagramValidationValue -Object $truthMetrics -Name "edgeCount" -Default 0)
        $truthInboundCount = [int](Get-DiagramValidationValue -Object $truthMetrics -Name "inboundEndpointCount" -Default 0)
        $truthOutboundCount = [int](Get-DiagramValidationValue -Object $truthMetrics -Name "outboundEndpointCount" -Default 0)

        foreach ($diagramFile in @("internal-flow.md","data-flow.md")) {
            if (-not $diagramCoverageSnapshotMap.ContainsKey($diagramFile)) {
                $issues += ("coverage-snapshot-missing:{0}" -f $diagramFile)
                continue
            }

            $snapshot = $diagramCoverageSnapshotMap[$diagramFile]
            if ([int]$snapshot.nodeCount -ne $truthNodeCount) {
                $issues += ("snapshot-node-mismatch:{0}:{1}/{2}" -f $diagramFile, [int]$snapshot.nodeCount, $truthNodeCount)
            }
            if ([int]$snapshot.edgeCount -ne $truthEdgeCount) {
                $issues += ("snapshot-edge-mismatch:{0}:{1}/{2}" -f $diagramFile, [int]$snapshot.edgeCount, $truthEdgeCount)
            }
            if ([int]$snapshot.inboundCount -ne $truthInboundCount) {
                $issues += ("snapshot-inbound-mismatch:{0}:{1}/{2}" -f $diagramFile, [int]$snapshot.inboundCount, $truthInboundCount)
            }
            if ([int]$snapshot.outboundCount -ne $truthOutboundCount) {
                $issues += ("snapshot-outbound-mismatch:{0}:{1}/{2}" -f $diagramFile, [int]$snapshot.outboundCount, $truthOutboundCount)
            }
        }

        foreach ($diagramFile in @("internal-flow.md","data-flow.md")) {
            if (-not $diagramMermaidCountMap.ContainsKey($diagramFile)) { continue }
            if (-not $diagramCoverageSnapshotMap.ContainsKey($diagramFile)) { continue }

            $parsed = $diagramMermaidCountMap[$diagramFile]
            $snapshot = $diagramCoverageSnapshotMap[$diagramFile]
            if ([int]$parsed.edgeCount -ne [int]$snapshot.edgeCount) {
                $issues += ("parsed-edge-mismatch:{0}:{1}/{2}" -f $diagramFile, [int]$parsed.edgeCount, [int]$snapshot.edgeCount)
            }
            if ([int]$parsed.nodeCount -ne [int]$snapshot.nodeCount) {
                $issues += ("parsed-node-mismatch:{0}:{1}/{2}" -f $diagramFile, [int]$parsed.nodeCount, [int]$snapshot.nodeCount)
            }
        }
    }
    catch {
        $issues += ("truth-pack-parse-failed:{0}" -f $_.Exception.Message)
    }
}

$result = [ordered]@{
    passed = ($issues.Count -eq 0)
    strict = $Strict.IsPresent
    diagramsPath = $diagramsPath
    truthPackPath = $truthPackPath
    issueCount = $issues.Count
    issues = @($issues | Select-Object -Unique)
    truthPackValidation = $truthPackValidation
    details = $details
}

if ($Json) {
    Write-Output ( $result | ConvertTo-Json -Depth 20 )
}
else {
    if ($result.passed) {
        Write-Host "Diagram validation passed." -ForegroundColor Green
    }
    else {
        Write-Warning ("Diagram validation reported {0} issue(s)." -f $result.issueCount)
        foreach ($issue in $result.issues) {
            Write-Warning (" - {0}" -f $issue)
        }
    }
}

if ($Strict -and -not $result.passed) {
    exit 1
}
exit 0
