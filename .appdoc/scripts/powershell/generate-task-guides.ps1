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

$evidenceRecords = @()
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "change-endpoint-safely" -Kind "task-guide" -Confidence 0.95 -Provider "generator" -ProviderType "deterministic" -Metadata @{ category = "implementation"; endpointEvidence = @($taskData.endpointRows).Count }
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "debug-build-failure" -Kind "task-guide" -Confidence 0.95 -Provider "generator" -ProviderType "deterministic" -Metadata @{ category = "operations"; buildEvidence = @($taskData.buildCommandRows).Count }
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "triage-dependency-risk" -Kind "task-guide" -Confidence 0.95 -Provider "generator" -ProviderType "deterministic" -Metadata @{ category = "risk"; dependencyEvidence = @($taskData.dependencyRows).Count }
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "plan-debt-sprint" -Kind "task-guide" -Confidence 0.95 -Provider "generator" -ProviderType "deterministic" -Metadata @{ category = "maintenance"; debtEvidence = @($taskData.debtRows).Count }
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "task-guide-summary" -Kind "summary" -Confidence 0.9 -Provider "generator" -ProviderType "deterministic" -Metadata @{ endpointCount = @($taskData.endpointRows).Count; buildCommandCount = @($taskData.buildCommandRows).Count; dependencyCount = @($taskData.dependencyRows).Count; debtCount = @($taskData.debtRows).Count; testCount = @($taskData.testRows).Count }

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = if ($contract) { @($contract.requiredEvidenceKeys) } else { @("tasks", "summary") }
    requiredSections = if ($contract) { @($contract.requiredSections) } else { @("Executive Summary", "Task Guides", "Operational Checklist") }
    generator = "generate-task-guides.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{ generator = "generate-task-guides.ps1" })
}

Write-Host "✅ Task guides generated: $outputPath" -ForegroundColor Green
Write-Host "   Guides generated: 4" -ForegroundColor Gray
