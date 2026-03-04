param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
if (-not (Test-Path $scopeModule)) {
    Write-Error "Required module not found: $scopeModule"
    exit 1
}
Import-Module $scopeModule -Force -ErrorAction Stop

$evidenceModule = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (-not (Test-Path $evidenceModule)) {
    Write-Error "Required module not found: $evidenceModule"
    exit 1
}
Import-Module $evidenceModule -Force -ErrorAction Stop

$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
if (-not (Test-Path $contractsModule)) {
    Write-Error "Required module not found: $contractsModule"
    exit 1
}
Import-Module $contractsModule -Force -ErrorAction Stop

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) {
    New-Item -Path $docsPath -ItemType Directory -Force | Out-Null
}

$evidenceRoot = Join-Path $docsPath "evidence"

$outputPath = Join-Path $docsPath "start-here.md"

$codeFiles = @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "start-here" -Include @("*.cs","*.js","*.ts","*.py","*.java"))
$languageCount = @{}
foreach ($file in $codeFiles) {
    $ext = [string]$file.Extension
    if (-not $languageCount.ContainsKey($ext)) {
        $languageCount[$ext] = 0
    }
    $languageCount[$ext] += 1
}

$apiDocPath = Join-Path $docsPath "api-inventory.md"
$apiEndpointCount = 0
$apiEvidencePath = Join-Path $evidenceRoot "api-inventory.evidence.json"
if (Test-Path $apiEvidencePath) {
    try {
        $apiEvidence = Get-Content $apiEvidencePath -Raw | ConvertFrom-Json
        $apiEndpointCount = @($apiEvidence.records | Where-Object { [string]$_.kind -eq 'endpoint' }).Count
    }
    catch {
        $apiEndpointCount = 0
    }
}
if ($apiEndpointCount -eq 0 -and (Test-Path $apiDocPath)) {
    $apiContent = Get-Content $apiDocPath -Raw
    $apiEndpointCount = ([regex]::Matches($apiContent, '(?im)^\|\s*`[^|]+`\s*\|\s*`[^|]+`\s*\|\s*(GET|POST|PUT|DELETE|PATCH|ANY)\s*\|')).Count
}

$modelDocPath = Join-Path $docsPath "data-model.md"
$modelCount = 0
$modelEvidencePath = Join-Path $evidenceRoot "data-model.evidence.json"
if (Test-Path $modelEvidencePath) {
    try {
        $modelEvidence = Get-Content $modelEvidencePath -Raw | ConvertFrom-Json
        $modelCount = @($modelEvidence.records | Where-Object { [string]$_.kind -eq 'model' }).Count
    }
    catch {
        $modelCount = 0
    }
}
if ($modelCount -eq 0 -and (Test-Path $modelDocPath)) {
    $modelContent = Get-Content $modelDocPath -Raw
    $modelSectionMatch = [regex]::Match($modelContent, '(?ims)^##\s+Data Models\s*$\r?\n(.*?)(?=^##\s+[^\r\n]+|\z)')
    if ($modelSectionMatch.Success) {
        $tableRows = @(
            ($modelSectionMatch.Groups[1].Value -split "`r?`n") |
                Where-Object {
                    $line = ([string]$_).Trim()
                    $line -match '^\|' -and $line -notmatch '^\|\s*[-: ]+\|'
                }
        )
        if ($tableRows.Count -gt 1) {
            $modelCount = $tableRows.Count - 1
        }
    }
}

$languagesText = if ($languageCount.Count -gt 0) {
    ($languageCount.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object { "$($_.Key) ($($_.Value))" }) -join ", "
} else {
    "No source files detected"
}

$markdown = @"
# Start Here

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Who This Is For

- New contributors who need a fast orientation before changing code.
- Maintainers who need reliable links from overview to implementation evidence.
- Architects and leads who need risk hotspots and modernization cues.

## 15-Minute Orientation

1. Read [System Overview](overview.md) for scope and system context.
2. Review [C4 Context](diagrams/c4-context.md) and [C4 Container](diagrams/c4-container.md).
3. Skim [API Inventory](api-inventory.md) and [Data Model](data-model.md) for behavior and structure.
4. Review [Build Cookbook](build-cookbook.md) and [Test Catalog](test-catalog.md) before making changes.
5. Check [Technical Debt Register](debt-register.md) and [Dependencies Catalog](dependencies-catalog.md) for risk.

## Role-Based Paths

| Role | Start Here | Then Go To | Goal |
|------|------------|------------|------|
| New Engineer | [System Overview](overview.md) | [Build Cookbook](build-cookbook.md) → [Test Catalog](test-catalog.md) | Make a safe first change |
| Backend Developer | [API Inventory](api-inventory.md) | [Data Model](data-model.md) → [Configuration Catalog](config-catalog.md) | Implement or modify behavior |
| Architect | [System Overview](overview.md) | [C4 Diagrams](diagrams/c4-context.md) → [Debt Register](debt-register.md) | Assess structure and modernization priorities |
| Operations / Support | [Build Cookbook](build-cookbook.md) | [Configuration Catalog](config-catalog.md) → [Dependencies Catalog](dependencies-catalog.md) | Run, diagnose, and secure the system |

## System Signals

- Source files detected: **$($codeFiles.Count)**
- Languages detected: **$($languageCount.Count)** ($languagesText)
- API endpoints documented: **$apiEndpointCount**
- Data models documented: **$modelCount**

## Documentation Map

- [System Overview](overview.md)
- [API Inventory](api-inventory.md)
- [Data Model](data-model.md)
- [Configuration Catalog](config-catalog.md)
- [Build Cookbook](build-cookbook.md)
- [Test Catalog](test-catalog.md)
- [Task Guides](task-guides.md)
- [Technical Debt Register](debt-register.md)
- [Dependencies Catalog](dependencies-catalog.md)
- [Documentation Index](index.md)
- [Evidence Manifest](evidence/manifest.json)

---
**Generated by AppDoc Framework**
"@

$markdown | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "start-here"
$evidenceRecords = @()

if (Get-Command New-AppDocExtractionRecord -ErrorAction SilentlyContinue) {
    $evidenceRecords = @(
        New-AppDocExtractionRecord -Artifact $artifact -Source "repository" -Name "source-files" -Kind "summary" -Confidence 0.95 -Provider "generator" -ProviderType "deterministic" -Metadata @{ count = $codeFiles.Count; languages = @($languageCount.Keys) }
        New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "api-inventory" -Kind "endpoint" -Confidence 0.9 -Provider "generator" -ProviderType "deterministic" -Metadata @{ documentedEndpoints = $apiEndpointCount }
        New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "data-model" -Kind "model" -Confidence 0.9 -Provider "generator" -ProviderType "deterministic" -Metadata @{ documentedModels = $modelCount }
    )
}
else {
    $evidenceRecords = @(
        @{ artifact = $artifact; source = "repository"; name = "source-files"; kind = "summary"; confidence = 0.95; provider = "generator"; providerType = "deterministic"; metadata = @{ count = $codeFiles.Count; languages = @($languageCount.Keys) } },
        @{ artifact = $artifact; source = "docs"; name = "api-inventory"; kind = "endpoint"; confidence = 0.9; provider = "generator"; providerType = "deterministic"; metadata = @{ documentedEndpoints = $apiEndpointCount } },
        @{ artifact = $artifact; source = "docs"; name = "data-model"; kind = "model"; confidence = 0.9; provider = "generator"; providerType = "deterministic"; metadata = @{ documentedModels = $modelCount } }
    )
}

if (Get-Command Write-AppDocEvidenceArtifact -ErrorAction SilentlyContinue) {
    $contract = $null
    if (Get-Command Get-AppDocArtifactContract -ErrorAction SilentlyContinue) {
        $contract = Get-AppDocArtifactContract -Artifact "start-here"
    }

    $evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
        requiredEvidenceKeys = if ($contract) { @($contract.requiredEvidenceKeys) } else { @("summary", "endpoints", "models") }
        requiredSections = if ($contract) { @($contract.requiredSections) } else { @("Who This Is For", "15-Minute Orientation", "Role-Based Paths", "System Signals") }
        generator = "generate-start-here.ps1"
    }
    if ($evidencePath -and (Get-Command Update-AppDocEvidenceManifest -ErrorAction SilentlyContinue)) {
        [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{ generator = "generate-start-here.ps1" })
    }
}

Write-Host "✅ Start-here guide generated: $outputPath" -ForegroundColor Green
