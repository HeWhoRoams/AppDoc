param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [switch]$SkipC4
)

$contractModule = Join-Path $PSScriptRoot "modules\AppDoc.Diagrams.Contract.psm1"
$extractorModule = Join-Path $PSScriptRoot "modules\AppDoc.Diagrams.GraphExtractor.psm1"
$rendererModule = Join-Path $PSScriptRoot "modules\AppDoc.Diagrams.Renderer.psm1"
$determinismModule = Join-Path $PSScriptRoot "modules\AppDoc.Determinism.psm1"

if (-not (Test-Path $contractModule)) { Write-Error "Required module not found: $contractModule"; exit 1 }
if (-not (Test-Path $extractorModule)) { Write-Error "Required module not found: $extractorModule"; exit 1 }
if (-not (Test-Path $rendererModule)) { Write-Error "Required module not found: $rendererModule"; exit 1 }

Import-Module $contractModule -Force -ErrorAction Stop
Import-Module $extractorModule -Force -ErrorAction Stop
Import-Module $rendererModule -Force -ErrorAction Stop
if (Test-Path $determinismModule) {
    Import-Module $determinismModule -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

Write-Host "🧱 Generating deterministic architecture diagram suite..." -ForegroundColor Cyan

$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) {
    New-Item -Path $docsPath -ItemType Directory -Force | Out-Null
}

$c4Script = Join-Path $PSScriptRoot "generate-c4-mermaid-diagrams.ps1"
if (-not $SkipC4 -and (Test-Path $c4Script)) {
    try {
        & $c4Script -CodebasePath $RootPath -OutputPath $docsPath | Out-Null
    }
    catch {
        Write-Warning ("C4 diagram generation failed in suite pre-step: {0}" -f $_.Exception.Message)
    }
}

$contract = Get-AppDocDiagramContract
$graphData = Get-AppDocDiagramGraphData -RootPath $RootPath -Contract $contract
$truthPackPath = Write-AppDocDiagramTruthPack -RootPath $RootPath -GraphData $graphData
$diagramPaths = Write-AppDocDiagramSuite -RootPath $RootPath -GraphData $graphData -Contract $contract

$metrics = $graphData.metrics
Write-Host "✅ Diagram suite generated:" -ForegroundColor Green
Write-Host ("   Internal flow: {0}" -f [string]$diagramPaths.internalFlow) -ForegroundColor Gray
Write-Host ("   Data flow:     {0}" -f [string]$diagramPaths.dataFlow) -ForegroundColor Gray
Write-Host ("   Sequences:     {0}" -f [string]$diagramPaths.criticalSequences) -ForegroundColor Gray
Write-Host ("   Data lineage:  {0}" -f [string]$diagramPaths.dataLineageCore) -ForegroundColor Gray
Write-Host ("   Diagram index: {0}" -f [string]$diagramPaths.index) -ForegroundColor Gray
Write-Host ("   Truth pack:    {0}" -f [string]$truthPackPath) -ForegroundColor Gray
Write-Host ("   Nodes: {0}, Edges: {1}, Inbound: {2}, Outbound: {3}" -f `
    [int]$metrics.nodeCount, [int]$metrics.edgeCount, [int]$metrics.inboundEndpointCount, [int]$metrics.outboundEndpointCount) -ForegroundColor Gray
