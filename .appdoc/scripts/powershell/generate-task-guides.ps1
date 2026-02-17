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

Write-Host "🧭 Generating Task Guides..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\task-guides.md"
$initialized = Initialize-TemplateFile -TemplateName "task-guides-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize task-guides template"
    exit 1
}

$docsPath = Join-Path $RootPath "docs"
$evidenceRoot = Join-Path $docsPath "evidence"

function Get-EvidenceRecords {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EvidenceRoot,
        [Parameter(Mandatory=$true)]
        [string]$Artifact
    )

    $path = Join-Path $EvidenceRoot ("{0}.evidence.json" -f $Artifact)
    if (-not (Test-Path $path)) { return @() }

    try {
        $payload = Get-Content $path -Raw | ConvertFrom-Json
        return @($payload.records)
    }
    catch {
        return @()
    }
}

$apiRecords = Get-EvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "api-inventory"
$buildRecords = Get-EvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "build-cookbook"
$dependencyRecords = Get-EvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "dependencies-catalog"
$debtRecords = Get-EvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "debt-register"
$testRecords = Get-EvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "test-catalog"

$endpointRows = @($apiRecords | Where-Object { [string]$_.kind -eq "endpoint" })
$buildCommandRows = @($buildRecords | Where-Object { [string]$_.kind -in @("build-command", "command") })
$dependencyRows = @($dependencyRecords | Where-Object { [string]$_.kind -eq "dependency" })
$debtRows = @($debtRecords | Where-Object { [string]$_.kind -in @("technical-debt", "debt-item") })
$testRows = @($testRecords | Where-Object { [string]$_.kind -in @("test-case", "test-suite") })

$sampleEndpoints = @($endpointRows | Select-Object -First 5 | ForEach-Object {
    $method = if ($_.metadata -and $_.metadata.method) { [string]$_.metadata.method } else { "ANY" }
    $name = if ($_.name) { [string]$_.name } else { "endpoint" }
    "- ``$method`` ``$name``"
})
if ($sampleEndpoints.Count -eq 0) { $sampleEndpoints = @("- No endpoint evidence available") }

$sampleBuildCommands = @($buildCommandRows | Select-Object -First 5 | ForEach-Object {
    $cmd = if ($_.metadata -and $_.metadata.invocation) { [string]$_.metadata.invocation } else { [string]$_.name }
    "- ``$cmd``"
})
if ($sampleBuildCommands.Count -eq 0) { $sampleBuildCommands = @("- No build command evidence available") }

$sampleDependencies = @($dependencyRows | Group-Object -Property name | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
    "- ``$($_.Name)`` used in $($_.Count) location(s)"
})
if ($sampleDependencies.Count -eq 0) { $sampleDependencies = @("- No dependency evidence available") }

$sampleDebt = @($debtRows | Select-Object -First 5 | ForEach-Object {
    $desc = if ($_.metadata -and $_.metadata.description) { [string]$_.metadata.description } else { [string]$_.name }
    "- $desc"
})
if ($sampleDebt.Count -eq 0) { $sampleDebt = @("- No debt evidence available") }

$changeEndpointGuide = @"
1. Open [API Inventory](api-inventory.md) and identify the target endpoint plus adjacent related endpoints.
2. Trace impacted types in [Data Model](data-model.md) and verify associated configuration in [Configuration Catalog](config-catalog.md).
3. Implement changes and run the minimal build/test loop from [Build Cookbook](build-cookbook.md) and [Test Catalog](test-catalog.md).
4. Re-run AppDoc generation with strict validation and review contradiction/grounding metrics.

**Evidence snapshot**:
$($sampleEndpoints -join "`n")
"@

$debugBuildGuide = @"
1. Start with command parity from [Build Cookbook](build-cookbook.md) and execute the shortest failing command first.
2. Validate environmental assumptions using [Configuration Catalog](config-catalog.md).
3. Compare local output with pipeline behavior and check dependency/version drift in [Dependencies Catalog](dependencies-catalog.md).
4. Confirm recovery by running targeted tests from [Test Catalog](test-catalog.md).

**Evidence snapshot**:
$($sampleBuildCommands -join "`n")
"@

$dependencyRiskGuide = @"
1. Review [Dependencies Catalog](dependencies-catalog.md) for version conflicts and widely used packages.
2. Prioritize risk by usage breadth, version divergence, and critical-path runtime involvement.
3. Validate likely blast radius using [API Inventory](api-inventory.md), [Data Model](data-model.md), and [Build Cookbook](build-cookbook.md).
4. Stage upgrades incrementally and re-run strict documentation validation.

**Evidence snapshot**:
$($sampleDependencies -join "`n")
"@

$debtSprintGuide = @"
1. Group [Technical Debt Register](debt-register.md) findings by impact and ownership domain.
2. Select high-leverage items that reduce recurring defects or shorten release lead time.
3. Attach measurable exit criteria (tests added, complexity reduced, obsolete code removed).
4. Document outcomes and regenerate docs to refresh evidence and trend metrics.

**Evidence snapshot**:
$($sampleDebt -join "`n")
"@

$checklist = @"
- Confirm docs validation score remains above threshold in strict mode.
- Confirm contradictionConsistencyScore and claimGroundingScore remain stable.
- Confirm no sensitive values leak into generated markdown output.
- Confirm changed workflows reference concrete commands and tests.
- Confirm task guidance links to current artifacts, not stale assumptions.
"@

$content = @"
# Task Guides

**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')

## Executive Summary

This document provides task-centric implementation and maintenance playbooks derived from deterministic evidence. It helps engineers complete common workflows safely while preserving architecture and operational quality.

## Task Guides

### Change an Endpoint Safely

$changeEndpointGuide

### Debug a Build Failure

$debugBuildGuide

### Triage Dependency Risk

$dependencyRiskGuide

### Plan a Debt Sprint

$debtSprintGuide

## Operational Checklist

$checklist

---

**Generated by AppDoc Framework**
"@

$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "task-guides"
$contract = $null
if (Get-Command Get-AppDocArtifactContract -ErrorAction SilentlyContinue) {
    $contract = Get-AppDocArtifactContract -Artifact $artifact
}

$evidenceRecords = @()
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "change-endpoint-safely" -Kind "task-guide" -Confidence 0.95 -Provider "generator" -ProviderType "deterministic" -Metadata @{ category = "implementation"; endpointEvidence = $endpointRows.Count }
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "debug-build-failure" -Kind "task-guide" -Confidence 0.95 -Provider "generator" -ProviderType "deterministic" -Metadata @{ category = "operations"; buildEvidence = $buildCommandRows.Count }
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "triage-dependency-risk" -Kind "task-guide" -Confidence 0.95 -Provider "generator" -ProviderType "deterministic" -Metadata @{ category = "risk"; dependencyEvidence = $dependencyRows.Count }
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "plan-debt-sprint" -Kind "task-guide" -Confidence 0.95 -Provider "generator" -ProviderType "deterministic" -Metadata @{ category = "maintenance"; debtEvidence = $debtRows.Count }
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "docs" -Name "task-guide-summary" -Kind "summary" -Confidence 0.9 -Provider "generator" -ProviderType "deterministic" -Metadata @{ endpointCount = $endpointRows.Count; buildCommandCount = $buildCommandRows.Count; dependencyCount = $dependencyRows.Count; debtCount = $debtRows.Count; testCount = $testRows.Count }

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
