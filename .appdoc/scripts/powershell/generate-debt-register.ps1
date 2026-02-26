#
# generate-debt-register.ps1
#
# Purpose: Scans the target codebase for technical debt indicators and populates the
#          debt-register template with discovered debt items and priorities.
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

$debtExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.DebtRegister.Extractor.psm1"
if (-not (Test-Path $debtExtractorModule)) {
    Write-Error "Required module not found: $debtExtractorModule"
    exit 1
}
Import-Module $debtExtractorModule -Force -ErrorAction Stop

$debtRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.DebtRegister.Renderer.psm1"
if (-not (Test-Path $debtRendererModule)) {
    Write-Error "Required module not found: $debtRendererModule"
    exit 1
}
Import-Module $debtRendererModule -Force -ErrorAction Stop

Write-Host "📋 Generating Technical Debt Register..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\debt-register.md"
$initialized = Initialize-TemplateFile -TemplateName "tech-debt-register-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Technical Debt Register" -Status "Scanning code..." -PercentComplete 10

$debtData = Get-AppDocDebtRegisterData -RootPath $RootPath
if ($debtData -and $debtData.debts) {
    $debts = @($debtData.debts) | Where-Object { $_ -ne $null }
} else {
    $debts = @()
}

Write-Progress -Activity "Generating Technical Debt Register" -Status "Populating template..." -PercentComplete 60
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocDebtRegisterContent -Content $content -Debts $debts
$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Normalize-AppDocMarkdownStructure -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "debt-register"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @(
    $debts | ForEach-Object {
        $sourcePath = if ($_.filePath) { [string]$_.filePath } else { [string]$_.file }
        New-AppDocExtractionRecord -Artifact $artifact -Source $sourcePath -Name ([string]$_.type) -Kind "technical-debt" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            description = [string]$_.description
            file = [string]$_.file
            line = [int]$_.line
            priority = [string]$_.priority
        }
    }
)

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    debtCount = $debts.Count
    generator = "generate-debt-register.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-debt-register.ps1"
    })
}

Write-Progress -Activity "Generating Technical Debt Register" -Status "Complete" -PercentComplete 100
Write-Host "✅ Technical debt register generated: $outputPath" -ForegroundColor Green
Write-Host "   Debt items found: $($debts.Count)" -ForegroundColor Gray
Write-Host "   Files scanned: $($debtData.scannedFileCount)" -ForegroundColor Gray
