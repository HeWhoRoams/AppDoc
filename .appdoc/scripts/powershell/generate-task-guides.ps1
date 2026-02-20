param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) {
    . $helpersPath
}

$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
if (Test-Path $scopeModule) {
    Import-Module $scopeModule -Force -ErrorAction Stop
}

$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
if (Test-Path $contractsModule) {
    Import-Module $contractsModule -Force -ErrorAction Stop
}

$evidenceModule = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (Test-Path $evidenceModule) {
    Import-Module $evidenceModule -Force -ErrorAction Stop
}

$taskExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.TaskGuides.Extractor.psm1"
if (-not (Test-Path $taskExtractorModule)) { Write-Error "Required module not found: $taskExtractorModule"; exit 1 }
Import-Module $taskExtractorModule -Force -ErrorAction Stop

$taskRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.TaskGuides.Renderer.psm1"
if (-not (Test-Path $taskRendererModule)) { Write-Error "Required module not found: $taskRendererModule"; exit 1 }
Import-Module $taskRendererModule -Force -ErrorAction Stop

Write-Host "🧭 Generating Task Guides..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

if (-not (Get-Command Initialize-TemplateFile -ErrorAction SilentlyContinue)) {
    Write-Error "Required function Initialize-TemplateFile not found. Ensure template-helpers.ps1 is available."
    exit 1
}

$outputPath = Join-Path $RootPath "docs\task-guides.md"
$initialized = Initialize-TemplateFile -TemplateName "task-guides-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize task-guides template"
    exit 1
}


$taskData = Get-AppDocTaskGuidesData -RootPath $RootPath
# Defensive null/structure check for $taskData
if ($null -eq $taskData) {
    Write-Error "Get-AppDocTaskGuidesData returned null or missing required properties. Cannot continue generating task guides."
    exit 1
}

$hasEndpointRows = $false
if ($taskData -is [hashtable] -or $taskData -is [System.Collections.Specialized.OrderedDictionary]) {
    $hasEndpointRows = $taskData.Contains('endpointRows')
} else {
    $hasEndpointRows = ($taskData.PSObject.Properties.Name -contains 'endpointRows')
}

if (-not $hasEndpointRows) {
    Write-Error "Get-AppDocTaskGuidesData returned null or missing required properties. Cannot continue generating task guides."
    exit 1
}
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocTaskGuidesContent -Content $content -TaskData $taskData
$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "task-guides"
$contract = $null
if (Get-Command Get-AppDocArtifactContract -ErrorAction SilentlyContinue) {
    $contract = Get-AppDocArtifactContract -Artifact $artifact
}



$endpointCount = ($taskData.endpointRows ?? @()).Count
$buildCommandCount = ($taskData.buildCommandRows ?? @()).Count
$dependencyCount = ($taskData.dependencyRows ?? @()).Count
$debtCount = ($taskData.debtRows ?? @()).Count
$testCount = ($taskData.testRows ?? @()).Count

# Defensive logging for missing sources
$logPrefix = "[TaskGuidesEvidence]"
if ($endpointCount -eq 0 -and $buildCommandCount -eq 0 -and $dependencyCount -eq 0 -and $debtCount -eq 0 -and $testCount -eq 0) {
    Write-Warning "$logPrefix No task guide evidence sources found. All summary counts will be zero."
}

$evidenceRecords = @()

# Helper to set confidence/status based on evidence presence
function Get-ConfidenceAndStatus {
    param([int]$count)
    if ($count -gt 0) {
        return @{ Confidence = 1.0; Status = 'Detected' }
    }

    return @{ Confidence = 0.5; Status = 'NotDetected' }
}

$metaList = @(
    @{ Name = 'change-endpoint-safely'; Category = 'implementation'; Count = $endpointCount; EvidenceKey = 'endpointEvidence' }
    @{ Name = 'debug-build-failure'; Category = 'operations'; Count = $buildCommandCount; EvidenceKey = 'buildEvidence' }
    @{ Name = 'triage-dependency-risk'; Category = 'risk'; Count = $dependencyCount; EvidenceKey = 'dependencyEvidence' }
    @{ Name = 'plan-debt-sprint'; Category = 'maintenance'; Count = $debtCount; EvidenceKey = 'debtEvidence' }
)

foreach ($meta in $metaList) {
    $cs = Get-ConfidenceAndStatus -count $meta.Count
    $evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name $meta.Name -Kind "task-guide" -Confidence $cs.Confidence -Provider "generator" -ProviderType "deterministic" -Status $cs.Status -Metadata @{ category = $meta.Category; ($meta.EvidenceKey) = $meta.Count }
}

# Summary record
$summaryCS = Get-ConfidenceAndStatus -count ($endpointCount + $buildCommandCount + $dependencyCount + $debtCount + $testCount)
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "task-guide-summary" -Kind "summary" -Confidence $summaryCS.Confidence -Provider "generator" -ProviderType "deterministic" -Status $summaryCS.Status -Metadata @{ endpointCount = $endpointCount; buildCommandCount = $buildCommandCount; dependencyCount = $dependencyCount; debtCount = $debtCount; testCount = $testCount }

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = if ($contract) { @($contract.requiredEvidenceKeys) } else { @("tasks", "summary") }
    requiredSections = if ($contract) { @($contract.requiredSections) } else { @("Executive Summary", "Task Guides", "Operational Checklist") }
    generator = "generate-task-guides.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{ generator = "generate-task-guides.ps1" })
}

Write-Host "✅ Task guides generated: $outputPath" -ForegroundColor Green
Write-Host "   Evidence categories: $($metaList.Count)" -ForegroundColor Gray
