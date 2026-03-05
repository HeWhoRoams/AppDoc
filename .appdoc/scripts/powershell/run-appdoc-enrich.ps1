param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    [Parameter(Mandatory=$false)]
    [switch]$StrictGate,
    [Parameter(Mandatory=$false)]
    [switch]$SkipGate,
    [Parameter(Mandatory=$false)]
    [switch]$SkipSemanticApply
)

$evidenceModulePath = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (-not (Test-Path $evidenceModulePath)) {
    Write-Error "Required module not found: $evidenceModulePath"
    exit 1
}
Import-Module $evidenceModulePath -Force -ErrorAction Stop

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$docsPath = Join-Path $RootPath "docs"
$evidenceDir = Join-Path $docsPath "evidence"
if (-not (Test-Path $evidenceDir)) {
    Write-Error "Evidence directory not found: $evidenceDir"
    exit 1
}

$fingerprintPath = Join-Path $docsPath "architecture-fingerprint.json"
$fingerprintType = "unknown"
if (Test-Path $fingerprintPath) {
    try {
        $fingerprint = Get-Content -Path $fingerprintPath -Raw | ConvertFrom-Json -Depth 50
        if ($fingerprint -and $fingerprint.primaryStyle) {
            $fingerprintType = [string]$fingerprint.primaryStyle
        }
    }
    catch {
        Write-Warning "Failed to parse architecture fingerprint: $($_.Exception.Message)"
    }
}

function Set-AppDocMissingField {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Record,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Value = $null
    )

    if (-not $Record.ContainsKey($Name)) {
        $Record[$Name] = $Value
    }
}

function Convert-AppDocRecordToHashtable {
    param(
        [Parameter(Mandatory=$true)]
        $Record
    )

    if ($Record -is [hashtable]) {
        return $Record
    }

    return ($Record | ConvertTo-Json -Depth 50 | ConvertFrom-Json -AsHashtable -Depth 50)
}

$evidenceFiles = @(Get-ChildItem -Path $evidenceDir -Filter "*.evidence.json" -File -ErrorAction Stop | Sort-Object Name)
if ($evidenceFiles.Count -eq 0) {
    Write-Host "No evidence files found in $evidenceDir" -ForegroundColor Yellow
    exit 0
}

$processed = 0
foreach ($file in $evidenceFiles) {
    try {
        $payload = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 80
    }
    catch {
        Write-Warning "Skipping unreadable evidence file $($file.Name): $($_.Exception.Message)"
        continue
    }

    if (-not $payload.ContainsKey("records")) {
        Write-Warning "Skipping evidence file without records array: $($file.Name)"
        continue
    }

    $artifact = if ($payload.ContainsKey("artifact")) { [string]$payload["artifact"] } else { [System.IO.Path]::GetFileNameWithoutExtension($file.Name).Replace(".evidence", "") }
    $records = @($payload["records"])

    $enrichedRecords = @(
        $records | ForEach-Object {
            $record = Convert-AppDocRecordToHashtable -Record $_

            Set-AppDocMissingField -Record $record -Name "confidenceNote"
            Set-AppDocMissingField -Record $record -Name "role"
            Set-AppDocMissingField -Record $record -Name "businessPurpose"
            Set-AppDocMissingField -Record $record -Name "isGenerated"
            Set-AppDocMissingField -Record $record -Name "tier"
            Set-AppDocMissingField -Record $record -Name "dependencyKind"
            Set-AppDocMissingField -Record $record -Name "criticalPath"
            Set-AppDocMissingField -Record $record -Name "upgradeUrgency"
            Set-AppDocMissingField -Record $record -Name "requiredForDeployment"
            Set-AppDocMissingField -Record $record -Name "schemaSource"
            Set-AppDocMissingField -Record $record -Name "integrationTargets"
            Set-AppDocMissingField -Record $record -Name "relationships"
            Set-AppDocMissingField -Record $record -Name "operationalProfile"
            Set-AppDocMissingField -Record $record -Name "projectRole"
            Set-AppDocMissingField -Record $record -Name "usageFrequency"
            Set-AppDocMissingField -Record $record -Name "testDiagnosis"

            if (-not $record.ContainsKey("confidence")) {
                $record["confidence"] = $null
            }

            $record
        }
    )

    $enrichedPayload = [ordered]@{
        artifact = $artifact
        architectureFingerprint = $fingerprintType
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        recordCount = @($enrichedRecords).Count
        records = $enrichedRecords
        metadata = [ordered]@{
            enriched = $true
            enrichmentMode = "schema-bootstrap"
            enrichmentPrompt = ".github/prompts/appdoc.enrich.prompt.md"
            sourceEvidence = $file.Name
            requiresSemanticEnrichment = $true
        }
    }

    $outputName = $file.Name.Replace(".evidence.json", ".evidence.enriched.json")
    $outputPath = Join-Path $evidenceDir $outputName

    if ($DryRun) {
        Write-Host "[DryRun] Would write $outputName" -ForegroundColor Gray
    }
    else {
        $enrichedPayload | ConvertTo-Json -Depth 80 | Out-File -FilePath $outputPath -Encoding UTF8
        [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact ("{0}.enriched" -f $artifact) -EvidencePath $outputPath -RecordCount $enrichedPayload.recordCount -Metadata @{ generator = "run-appdoc-enrich.ps1"; mode = "schema-bootstrap" })
        Write-Host "Enriched evidence written: $outputName" -ForegroundColor Green
    }

    $processed++
}

if (-not $DryRun) {
    if (-not $SkipSemanticApply) {
        Write-Host ""
        Write-Host "Applying semantic enrichment..." -ForegroundColor Cyan
        $semanticApplyScript = Join-Path $PSScriptRoot "run-appdoc-semantic-enrich.ps1"
        if (-not (Test-Path $semanticApplyScript)) {
            throw "Semantic enrichment script not found: $semanticApplyScript"
        }

        & $semanticApplyScript -RootPath $RootPath
        $semanticInvocationSucceeded = $?
        $semanticExitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }
        if ((-not $semanticInvocationSucceeded) -or $semanticExitCode -ne 0) {
            throw "Semantic enrichment apply failed (exit code $semanticExitCode)."
        }
    }

    $gatePassed = $true
    if (-not $SkipGate) {
        Write-Host ""
        Write-Host "Running enrichment gate..." -ForegroundColor Cyan
        $enrichmentGateScript = Join-Path $PSScriptRoot "ci-enrichment-gate.ps1"
        if (Test-Path $enrichmentGateScript) {
            $global:LASTEXITCODE = 0
            if ($StrictGate) {
                & $enrichmentGateScript -RootPath $RootPath -Strict
            }
            else {
                & $enrichmentGateScript -RootPath $RootPath
            }

            $gateInvocationSucceeded = $?
            $gateExitCode = if ($null -ne $LASTEXITCODE) { [int]$LASTEXITCODE } else { 0 }

            if ((-not $gateInvocationSucceeded) -or $gateExitCode -ne 0) {
                $gatePassed = $false
                if ($StrictGate) {
                    throw "Enrichment gate failed in strict mode (exit code $gateExitCode)."
                }
                Write-Warning "Enrichment gate reported issues. Continuing because -StrictGate was not specified."
            }
        }
        else {
            Write-Warning "Enrichment gate script not found: $enrichmentGateScript"
        }
    }

    if ($StrictGate -and -not $gatePassed) {
        throw "Strict enrichment gate failed. Re-render step aborted."
    }

    Write-Host ""
    Write-Host "Re-rendering enrichment-aware artifacts..." -ForegroundColor Cyan
    $renderScripts = @(
        "generate-config-catalog.ps1",
        "generate-data-model.ps1",
        "generate-debt-register.ps1",
        "generate-dependencies-catalog.ps1"
    )

    foreach ($renderScript in $renderScripts) {
        $renderPath = Join-Path $PSScriptRoot $renderScript
        if (-not (Test-Path $renderPath)) {
            Write-Warning "Render script not found: $renderScript"
            continue
        }

        try {
            & $renderPath -RootPath $RootPath
        }
        catch {
            Write-Warning "Failed to re-render via ${renderScript}: $($_.Exception.Message)"
        }
    }
}

Write-Host ""
Write-Host "AppDoc enrichment bootstrap complete." -ForegroundColor Cyan
Write-Host "Architecture fingerprint: $fingerprintType" -ForegroundColor Gray
Write-Host "Evidence files processed: $processed" -ForegroundColor Gray
Write-Host ""
Write-Host "Semantic inputs: docs/evidence/semantic/input/*.semantic.input.json" -ForegroundColor Gray
Write-Host "Optional semantic outputs: docs/evidence/semantic/output/*.semantic.output.json" -ForegroundColor Gray
