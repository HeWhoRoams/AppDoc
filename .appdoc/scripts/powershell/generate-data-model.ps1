#
# generate-data-model.ps1
#
# Purpose: Scans the target codebase for models/entities and populates
#          the data-model template.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [int]$MaxDetailedModels = 120
)

$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) {
    . $helpersPath
}

$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
if (-not (Test-Path $scopeModule)) { Write-Error "Required module not found: $scopeModule"; exit 1 }
Import-Module $scopeModule -Force -ErrorAction Stop

$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
if (-not (Test-Path $contractsModule)) { Write-Error "Required module not found: $contractsModule"; exit 1 }
Import-Module $contractsModule -Force -ErrorAction Stop

$evidenceModule = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (-not (Test-Path $evidenceModule)) { Write-Error "Required module not found: $evidenceModule"; exit 1 }
Import-Module $evidenceModule -Force -ErrorAction Stop

$dataModelExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.DataModel.Extractor.psm1"
if (-not (Test-Path $dataModelExtractorModule)) { Write-Error "Required module not found: $dataModelExtractorModule"; exit 1 }
Import-Module $dataModelExtractorModule -Force -ErrorAction Stop

$dataModelRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.DataModel.Renderer.psm1"
if (-not (Test-Path $dataModelRendererModule)) { Write-Error "Required module not found: $dataModelRendererModule"; exit 1 }
Import-Module $dataModelRendererModule -Force -ErrorAction Stop

Write-Host "🗂️  Generating Data Model..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\data-model.md"
$initialized = Initialize-TemplateFile -TemplateName "data-model-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Data Model" -Status "Scanning for models..." -PercentComplete 10
$modelData = Get-AppDocDataModelData -RootPath $RootPath -ScriptsRoot $PSScriptRoot
$models = @($modelData.models)

if ($modelData.astModelCount -gt 0) {
    Write-Host "  Added $($modelData.astModelCount) AST model records" -ForegroundColor Gray
}
if ($modelData.potentialModelFileCount -gt 0) {
    Write-Host "  Found $($modelData.potentialModelFileCount) potential model files" -ForegroundColor Gray
}

if ($models.Count -eq 0) {
    Write-Host "⚠️  No data models detected!" -ForegroundColor Yellow
    Write-Host "   Searched in: $RootPath" -ForegroundColor Gray
}

Write-Progress -Activity "Generating Data Model" -Status "Populating template..." -PercentComplete 80
$modelContent = Get-AppDocDataModelMarkdown -Models $models -MaxDetailedModels $MaxDetailedModels
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocDataModelContent -Content $content -ModelContent $modelContent
$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "data-model"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @(
    $models | ForEach-Object {
        $safeLineNumber = $null
        $lineStr = $_.lineNumber
        if ($lineStr -ne $null) {
            $parsed = 0
            if ([int]::TryParse($lineStr.ToString(), [ref]$parsed)) {
                $safeLineNumber = $parsed
            }
        }
        New-AppDocExtractionRecord -Artifact $artifact -Source ([string]$_.filePath) -Name ([string]$_.name) -Kind "model" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            modelType = [string]$_.type
            lineNumber = $safeLineNumber
            propertyCount = @($_.properties).Count
            properties = @($_.properties)
        }
    }
)
$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    generator = "generate-data-model.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-data-model.ps1"
    })
}

Write-Progress -Activity "Generating Data Model" -Status "Complete" -PercentComplete 100
Write-Host "✅ Data model generated: $outputPath" -ForegroundColor Green
Write-Host "   Models found: $($models.Count)" -ForegroundColor Gray
