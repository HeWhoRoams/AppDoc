#
# generate-overview.ps1
#
# Purpose: Populates the overview template with repository analysis and technology summary.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
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

$overviewExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.Overview.Extractor.psm1"
if (-not (Test-Path $overviewExtractorModule)) { Write-Error "Required module not found: $overviewExtractorModule"; exit 1 }
Import-Module $overviewExtractorModule -Force -ErrorAction Stop

$overviewRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.Overview.Renderer.psm1"
if (-not (Test-Path $overviewRendererModule)) { Write-Error "Required module not found: $overviewRendererModule"; exit 1 }
Import-Module $overviewRendererModule -Force -ErrorAction Stop

Write-Host "📊 Generating System Overview..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\overview.md"
$initialized = Initialize-TemplateFile -TemplateName "overview-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating System Overview" -Status "Analyzing repository..." -PercentComplete 10
$overviewData = Get-AppDocOverviewData -RootPath $RootPath
$codeFiles = @($overviewData.codeFiles)
$languageCount = $overviewData.languageCount

Write-Progress -Activity "Generating System Overview" -Status "Populating template..." -PercentComplete 60
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocOverviewContent -Content $content -CodeFileCount ([int]$overviewData.codeFileCount) -LanguageCount $languageCount
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "overview"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @()

$systemPurpose = "This codebase contains $($overviewData.codeFileCount) code files across $($languageCount.Keys.Count) language(s). Full analysis available in linked documentation."
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "repository" -Name "system-purpose" -Kind "summary" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
    text = $systemPurpose
    fileCount = [int]$overviewData.codeFileCount
    languageCount = [int]$languageCount.Keys.Count
}

foreach ($lang in $languageCount.Keys) {
    $evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "repository" -Name ([string]$lang) -Kind "technology" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
        extension = [string]$lang
        count = [int]$languageCount[$lang]
    }
}

$evidenceMetadata = @{
    generator = "generate-overview.ps1"
}
if ($contract) {
    $evidenceMetadata.requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    $evidenceMetadata.requiredSections = @($contract.requiredSections)
}

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata $evidenceMetadata
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-overview.ps1"
    })
}

Write-Progress -Activity "Generating System Overview" -Status "Complete" -PercentComplete 100
Write-Host "✅ System overview generated: $outputPath" -ForegroundColor Green
Write-Host "   Code files analyzed: $($overviewData.codeFileCount)" -ForegroundColor Gray
