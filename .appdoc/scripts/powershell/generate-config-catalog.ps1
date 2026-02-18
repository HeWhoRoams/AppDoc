#
# generate-config-catalog.ps1
#
# Purpose: Scans the target codebase for configuration files and populates the
#          config-catalog template with discovered configuration options.
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
if (-not (Test-Path $scopeModule)) {
    Write-Error "Required module not found: $scopeModule"
    exit 1
}
Import-Module $scopeModule -Force -ErrorAction Stop

$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
if (-not (Test-Path $contractsModule)) {
    Write-Error "Required module not found: $contractsModule"
    exit 1
}
Import-Module $contractsModule -Force -ErrorAction Stop

$evidenceModule = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (-not (Test-Path $evidenceModule)) {
    Write-Error "Required module not found: $evidenceModule"
    exit 1
}
Import-Module $evidenceModule -Force -ErrorAction Stop

$configExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.ConfigCatalog.Extractor.psm1"
if (-not (Test-Path $configExtractorModule)) {
    Write-Error "Required module not found: $configExtractorModule"
    exit 1
}
Import-Module $configExtractorModule -Force -ErrorAction Stop

$configRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.ConfigCatalog.Renderer.psm1"
if (-not (Test-Path $configRendererModule)) {
    Write-Error "Required module not found: $configRendererModule"
    exit 1
}
Import-Module $configRendererModule -Force -ErrorAction Stop

Write-Host "⚙️  Generating Config Catalog..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\config-catalog.md"
$initialized = Initialize-TemplateFile -TemplateName "config-catalog-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Config Catalog" -Status "Scanning configs..." -PercentComplete 10
$configData = Get-AppDocConfigCatalogData -RootPath $RootPath
$configs = @($configData.configs)
$discoveredConfigFiles = @($configData.discoveredConfigFiles)
$envVars = @($configData.envVars)

Write-Progress -Activity "Generating Config Catalog" -Status "Populating template..." -PercentComplete 60
$scriptRoot = Split-Path $PSScriptRoot -Parent
$appDocRoot = if ($scriptRoot) { Split-Path $scriptRoot -Parent } else { $null }
$templateFallbackPath = if ($appDocRoot) { Join-Path $appDocRoot "templates\config-catalog-template.md" } else { $outputPath }
$content = Get-AppDocConfigCatalogTemplateContent -RootPath $RootPath -TemplateName "config-catalog-template.md" -FallbackPath $templateFallbackPath
$content = Update-AppDocConfigCatalogContent -Content $content -Configs $configs -DiscoveredConfigFiles $discoveredConfigFiles -EnvVars $envVars
$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "config-catalog"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @(
    $configs | ForEach-Object {
        New-AppDocExtractionRecord -Artifact $artifact -Source ([string]$_.source) -Name ([string]$_.key) -Kind "configuration" -Confidence 0.85 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            value = [string]$_.value
            file = [string]$_.file
            type = [string]$_.type
            required = [bool]$_.required
        }
    }
)

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    configCount = $configs.Count
    generator = "generate-config-catalog.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-config-catalog.ps1"
    })
}

Write-Progress -Activity "Generating Config Catalog" -Status "Complete" -PercentComplete 100
Write-Host "✅ Config catalog generated: $outputPath" -ForegroundColor Green
Write-Host "   Configurations found: $($configs.Count)" -ForegroundColor Gray
Write-Host "   Configuration sources: $($discoveredConfigFiles.Count)" -ForegroundColor Gray
Write-Host "   Environment variables: $($envVars.Count)" -ForegroundColor Gray
