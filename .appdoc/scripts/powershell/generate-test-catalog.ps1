#
# generate-test-catalog.ps1
#
# Purpose: Scans the target codebase for tests and populates the test-catalog template.
#


param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [int]$MaxTestCases = 50
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

$testExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.TestCatalog.Extractor.psm1"
if (-not (Test-Path $testExtractorModule)) { Write-Error "Required module not found: $testExtractorModule"; exit 1 }
Import-Module $testExtractorModule -Force -ErrorAction Stop

$testRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.TestCatalog.Renderer.psm1"
if (-not (Test-Path $testRendererModule)) { Write-Error "Required module not found: $testRendererModule"; exit 1 }
Import-Module $testRendererModule -Force -ErrorAction Stop

Write-Host "🧪 Generating Test Catalog..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\test-catalog.md"
$initialized = Initialize-TemplateFile -TemplateName "test-catalog-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}


Write-Progress -Activity "Generating Test Catalog" -Status "Scanning tests..." -PercentComplete 10
$testData = Get-AppDocTestCatalogData -RootPath $RootPath
if ($null -eq $testData) {
    Write-Error "Get-AppDocTestCatalogData returned null. Cannot continue generating test catalog."
    exit 1
}
$tests = @($testData.tests)
Write-Host "  Found $($testData.testFileCount) test files" -ForegroundColor Gray

Write-Progress -Activity "Generating Test Catalog" -Status "Populating template..." -PercentComplete 60
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocTestCatalogContent -Content $content -Tests $tests -MaxTestCases $MaxTestCases
$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "test-catalog"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @(
    $tests | ForEach-Object {
        New-AppDocExtractionRecord -Artifact $artifact -Source ([string]$_.source) -Name ([string]$_.name) -Kind "test-case" -Confidence 0.85 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            type = [string]$_.type
            file = [string]$_.file
            framework = [string]$_.framework
        }
    }
)

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    testCount = $tests.Count
    generator = "generate-test-catalog.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-test-catalog.ps1"
    })
}

Write-Progress -Activity "Generating Test Catalog" -Status "Complete" -PercentComplete 100
Write-Host "✅ Test catalog generated: $outputPath" -ForegroundColor Green
Write-Host "   Test cases found: $($tests.Count)" -ForegroundColor Gray
