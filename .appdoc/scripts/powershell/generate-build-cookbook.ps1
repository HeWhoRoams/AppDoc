#
# generate-build-cookbook.ps1
#
# Purpose: Scans the target codebase for build configurations and populates the build-cookbook
#          template with discovered build, test, and deployment commands.
#
# Usage: .\generate-build-cookbook.ps1 -RootPath <target_codebase_path>
# Output: Populates docs/build-cookbook.md from template
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Import template helpers
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
if (Test-Path $contractsModule) {
    Import-Module $contractsModule -Force -ErrorAction Stop
}

$evidenceModule = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (Test-Path $evidenceModule) {
    Import-Module $evidenceModule -Force -ErrorAction Stop
}

$buildExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.BuildCookbook.Extractor.psm1"
if (-not (Test-Path $buildExtractorModule)) {
    Write-Error "Required module not found: $buildExtractorModule"
    exit 1
}
Import-Module $buildExtractorModule -Force -ErrorAction Stop

$buildRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.BuildCookbook.Renderer.psm1"
if (-not (Test-Path $buildRendererModule)) {
    Write-Error "Required module not found: $buildRendererModule"
    exit 1
}
Import-Module $buildRendererModule -Force -ErrorAction Stop

Write-Host "🔨 Generating Build Cookbook..." -ForegroundColor Cyan

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Initialize template
$outputPath = Join-Path $RootPath "docs\build-cookbook.md"
$initialized = Initialize-TemplateFile -TemplateName "build-cookbook-template.md" -OutputPath $outputPath -RootPath $RootPath

if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Build Cookbook" -Status "Scanning build files..." -PercentComplete 0

$commands = @()
$prerequisites = @()
$cicdInfo = @()

try {
    Write-Progress -Activity "Generating Build Cookbook" -Status "Extracting commands and build metadata..." -PercentComplete 10
    $buildData = Get-AppDocBuildCookbookData -RootPath $RootPath
    $commands = @($buildData.commands)
    $prerequisites = @($buildData.prerequisites)
    $cicdInfo = @($buildData.cicdInfo)
} catch {
    Write-Warning "Error scanning build files: $_"
}

Write-Progress -Activity "Generating Build Cookbook" -Status "Populating template..." -PercentComplete 50

# Update template
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocBuildCookbookContent -Content $content -Commands $commands -Prerequisites $prerequisites -CicdInfo $cicdInfo

$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "build-cookbook"
$contract = Get-AppDocArtifactContract -Artifact $artifact
if (-not $contract) {
    Write-Warning "No contract found for artifact '$artifact'; using empty requirements."
    $contract = @{ requiredEvidenceKeys = @(); requiredSections = @() }
}
$evidenceRecords = @()

$evidenceRecords += @(
    $commands | ForEach-Object {
        New-AppDocExtractionRecord -Artifact $artifact -Source ([string]$_.source) -Name ([string]$_.name) -Kind "build-command" -Confidence 0.85 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            command = [string]$_.command
            type = [string]$_.type
            invocation = [string]$_.invocation
        }
    }
)

$evidenceRecords += @(
    $prerequisites | ForEach-Object {
        New-AppDocExtractionRecord -Artifact $artifact -Source "repository" -Name ([string]$_) -Kind "prerequisite" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{}
    }
)

$evidenceRecords += @(
    $cicdInfo | ForEach-Object {
        New-AppDocExtractionRecord -Artifact $artifact -Source ([string]$_.path) -Name ([string]$_.platform) -Kind "cicd" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            file = [string]$_.file
            details = [string]$_.details
        }
    }
)

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    commandCount = $commands.Count
    prerequisiteCount = $prerequisites.Count
    cicdCount = $cicdInfo.Count
    generator = "generate-build-cookbook.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-build-cookbook.ps1"
    })
}

Write-Progress -Activity "Generating Build Cookbook" -Status "Complete" -PercentComplete 100
Write-Host "✅ Build cookbook generated: $outputPath" -ForegroundColor Green
Write-Host "   Commands found: $($commands.Count)" -ForegroundColor Gray
Write-Host "   Prerequisites detected: $($prerequisites.Count)" -ForegroundColor Gray
Write-Host "   CI/CD platforms detected: $($cicdInfo.Count)" -ForegroundColor Gray
