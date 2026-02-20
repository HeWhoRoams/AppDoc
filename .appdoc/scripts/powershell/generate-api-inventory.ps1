#
# generate-api-inventory.ps1
#
# Purpose: Scans the target codebase for API endpoints and populates
#          the api-inventory template.
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

$apiExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.ApiInventory.Extractor.psm1"
if (-not (Test-Path $apiExtractorModule)) { Write-Error "Required module not found: $apiExtractorModule"; exit 1 }
Import-Module $apiExtractorModule -Force -ErrorAction Stop

$apiRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.ApiInventory.Renderer.psm1"
if (-not (Test-Path $apiRendererModule)) { Write-Error "Required module not found: $apiRendererModule"; exit 1 }
Import-Module $apiRendererModule -Force -ErrorAction Stop

Write-Host "📡 Generating API Inventory..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\api-inventory.md"
$initialized = Initialize-TemplateFile -TemplateName "api-inventory-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating API Inventory" -Status "Scanning for APIs..." -PercentComplete 10
$apiData = Get-AppDocApiInventoryData -ScriptsRoot $PSScriptRoot -RootPath $RootPath
$inventory = $apiData.inventory
$endpoints = @(if ($inventory -and $inventory.endpoints) { $inventory.endpoints } else { @() })

if ($apiData.astEndpointCount -gt 0) {
    Write-Host "  Added $($apiData.astEndpointCount) AST endpoint records" -ForegroundColor Gray
}
Write-Host "  Scanned $($apiData.scannedApiFileCount) potential API files" -ForegroundColor Gray

if ($endpoints.Count -eq 0) {
    Write-Host "⚠️  No API endpoints detected!" -ForegroundColor Yellow
    Write-Host "   Searched in: $RootPath" -ForegroundColor Gray
    Write-Host "   File extensions: *.js, *.ts, *.cs, *.py, *.java, *.svc, *.asmx" -ForegroundColor Gray
}

Write-Progress -Activity "Generating API Inventory" -Status "Populating template..." -PercentComplete 80
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocApiInventoryContent -Content $content -Endpoints $endpoints
$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "api-inventory"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @(
    $endpoints | ForEach-Object {
        $sourcePath = if ([string]::IsNullOrWhiteSpace([string]$_.filePath)) { "unknown" } else { [string]$_.filePath }
        $endpointName = if ([string]::IsNullOrWhiteSpace([string]$_.path)) { "{0}:{1}" -f [string]$_.method, [string]$_.controller } else { [string]$_.path }
        New-AppDocExtractionRecord -Artifact $artifact -Source $sourcePath -Name $endpointName -Kind "endpoint" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            method = [string]$_.method
            controller = [string]$_.controller
            lineNumber = [int]$_.lineNumber
            returnType = [string]$_.returnType
            parameters = [string]$_.parameters
            auth = [string]$_.auth
            description = [string]$_.description
            direction = if ($_.direction) { [string]$_.direction } else { "inbound" }
            sourceType = if ($_.sourceType) { [string]$_.sourceType } else { "regex" }
            integrationUrl = if ($_.integrationUrl) { [string]$_.integrationUrl } else { "" }
            integrationContract = if ($_.integrationContract) { [string]$_.integrationContract } elseif ($_.contractName) { [string]$_.contractName } else { "" }
        }
    }
)
$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    generator = "generate-api-inventory.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-api-inventory.ps1"
    })
}

Write-Progress -Activity "Generating API Inventory" -Status "Complete" -PercentComplete 100
Write-Host "✅ API inventory generated: $outputPath" -ForegroundColor Green
Write-Host "   Endpoints found: $($endpoints.Count)" -ForegroundColor Gray
