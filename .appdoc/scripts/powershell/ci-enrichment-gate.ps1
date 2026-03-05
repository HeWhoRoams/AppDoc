param(
    [Parameter(Mandatory=$false)]
    [string]$RootPath = (Get-Location).Path,
    [Parameter(Mandatory=$false)]
    [switch]$Strict,
    [Parameter(Mandatory=$false)]
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-GateIssue {
    param(
        [System.Collections.Generic.List[object]]$Issues,
        [string]$Severity,
        [string]$Code,
        [string]$Message,
        [string]$Path = ""
    )

    $Issues.Add([ordered]@{
        severity = $Severity
        code = $Code
        message = $Message
        path = $Path
    }) | Out-Null
}

function Get-ObjectValue {
    param(
        [AllowNull()]
        [object]$Object,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [AllowNull()]
        [object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Get-RecordsByKind {
    param(
        [AllowNull()]
        [object]$Payload,
        [string[]]$Kinds = @()
    )

    $records = @((Get-ObjectValue -Object $Payload -Name "records" -Default @()))
    if ($Kinds.Count -eq 0) { return $records }
    return @($records | Where-Object { [string]$_.'kind' -in $Kinds })
}

if (-not (Test-Path $RootPath)) {
    throw "Root path does not exist: $RootPath"
}

$docsPath = Join-Path $RootPath "docs"
$evidencePath = Join-Path $docsPath "evidence"
if (-not (Test-Path $evidencePath)) {
    throw "Evidence directory not found: $evidencePath"
}

$issues = New-Object System.Collections.Generic.List[object]
$summary = [ordered]@{
    enrichedFilesChecked = 0
    recordsChecked = 0
    structuralErrors = 0
    semanticErrors = 0
    warnings = 0
    strictMode = [bool]$Strict
}

$requiredFields = @(
    "confidenceNote",
    "role",
    "businessPurpose",
    "isGenerated",
    "tier",
    "dependencyKind",
    "criticalPath",
    "upgradeUrgency",
    "requiredForDeployment",
    "schemaSource",
    "integrationTargets",
    "relationships",
    "operationalProfile",
    "projectRole",
    "usageFrequency",
    "testDiagnosis",
    "confidence"
)

$baseEvidenceFiles = @(Get-ChildItem -Path $evidencePath -Filter "*.evidence.json" -File -ErrorAction SilentlyContinue | Sort-Object Name)
$enrichedFiles = @(Get-ChildItem -Path $evidencePath -Filter "*.evidence.enriched.json" -File -ErrorAction SilentlyContinue | Sort-Object Name)

foreach ($baseFile in $baseEvidenceFiles) {
    $enrichedName = $baseFile.Name.Replace(".evidence.json", ".evidence.enriched.json")
    $enrichedFile = Join-Path $evidencePath $enrichedName
    if (-not (Test-Path $enrichedFile)) {
        Add-GateIssue -Issues $issues -Severity "error" -Code "missing_enriched_file" -Message "Missing enriched evidence file: $enrichedName" -Path $enrichedFile
    }
}

$fingerprintPath = Join-Path $docsPath "architecture-fingerprint.json"
$expectedFingerprint = ""
if (Test-Path $fingerprintPath) {
    try {
        $fingerprintPayload = Get-Content -Path $fingerprintPath -Raw | ConvertFrom-Json -Depth 50
        $expectedFingerprint = [string](Get-ObjectValue -Object $fingerprintPayload -Name "primaryStyle" -Default "")
    }
    catch {
        Add-GateIssue -Issues $issues -Severity "warning" -Code "architecture_fingerprint_unreadable" -Message "Failed to parse architecture-fingerprint.json" -Path $fingerprintPath
    }
}

foreach ($file in $enrichedFiles) {
    $summary.enrichedFilesChecked++

    $payload = $null
    try {
        $payload = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -Depth 120
    }
    catch {
        Add-GateIssue -Issues $issues -Severity "error" -Code "invalid_json" -Message "Invalid JSON in enriched evidence file." -Path $file.FullName
        continue
    }

    $artifact = [string](Get-ObjectValue -Object $payload -Name "artifact" -Default "")
    $records = @((Get-ObjectValue -Object $payload -Name "records" -Default @()))
    $summary.recordsChecked += $records.Count

    $payloadFingerprint = [string](Get-ObjectValue -Object $payload -Name "architectureFingerprint" -Default "")
    if ([string]::IsNullOrWhiteSpace($payloadFingerprint)) {
        Add-GateIssue -Issues $issues -Severity "error" -Code "missing_architecture_fingerprint" -Message "architectureFingerprint is missing on enriched payload." -Path $file.FullName
    }
    elseif (-not [string]::IsNullOrWhiteSpace($expectedFingerprint) -and $payloadFingerprint -ne $expectedFingerprint) {
        Add-GateIssue -Issues $issues -Severity "warning" -Code "architecture_fingerprint_mismatch" -Message ("Enriched fingerprint '{0}' differs from docs fingerprint '{1}'." -f $payloadFingerprint, $expectedFingerprint) -Path $file.FullName
    }

    foreach ($record in $records) {
        foreach ($field in $requiredFields) {
            $present = $false
            if ($record -is [System.Collections.IDictionary]) {
                $present = $record.Contains($field)
            }
            else {
                $present = ($null -ne $record.PSObject.Properties[$field])
            }

            if (-not $present) {
                Add-GateIssue -Issues $issues -Severity "error" -Code "missing_required_field" -Message ("Record missing required enrichment field '{0}'." -f $field) -Path $file.FullName
                continue
            }
        }

        $confidenceValue = Get-ObjectValue -Object $record -Name "confidence" -Default $null
        [double]$confidence = 0.0
        if ($null -ne $confidenceValue -and [double]::TryParse([string]$confidenceValue, [ref]$confidence)) {
            if ($confidence -lt 0.8) {
                $note = [string](Get-ObjectValue -Object $record -Name "confidenceNote" -Default "")
                if ([string]::IsNullOrWhiteSpace($note)) {
                    $severity = if ($Strict) { "error" } else { "warning" }
                    Add-GateIssue -Issues $issues -Severity $severity -Code "missing_confidence_note" -Message "confidence < 0.80 requires confidenceNote." -Path $file.FullName
                }
            }
        }
    }

    $metadata = Get-ObjectValue -Object $payload -Name "metadata" -Default $null
    $mode = [string](Get-ObjectValue -Object $metadata -Name "enrichmentMode" -Default "")
    $isBootstrapMode = ($mode -eq "schema-bootstrap")

    if (-not $isBootstrapMode -or $Strict) {
        if ($artifact -eq "config-catalog") {
            $configRecords = @(Get-RecordsByKind -Payload $payload -Kinds @("configuration"))
            $nonNullTiers = @($configRecords | ForEach-Object { [string](Get-ObjectValue -Object $_ -Name "tier" -Default "") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
            if ($configRecords.Count -ge 3 -and $nonNullTiers.Count -lt 2) {
                Add-GateIssue -Issues $issues -Severity "error" -Code "insufficient_tier_diversity" -Message "Expected at least 2 config tier values for repositories with 3+ config records." -Path $file.FullName
            }
        }

        if ($artifact -eq "data-model") {
            $modelRecords = @(Get-RecordsByKind -Payload $payload -Kinds @("model"))
            $nonNullRoles = @($modelRecords | ForEach-Object { [string](Get-ObjectValue -Object $_ -Name "role" -Default "") } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
            if ($modelRecords.Count -ge 20 -and $nonNullRoles.Count -lt 2) {
                Add-GateIssue -Issues $issues -Severity "error" -Code "insufficient_role_diversity" -Message "Expected at least 2 model roles for repositories with 20+ models." -Path $file.FullName
            }
        }

        if ($artifact -eq "dependencies-catalog") {
            $depRecords = @(Get-RecordsByKind -Payload $payload -Kinds @("dependency"))
            $assessed = @($depRecords | Where-Object { $null -ne (Get-ObjectValue -Object $_ -Name "criticalPath" -Default $null) }).Count
            if ($depRecords.Count -gt 0 -and $assessed -lt $depRecords.Count) {
                $severity = if ($Strict) { "error" } else { "warning" }
                Add-GateIssue -Issues $issues -Severity $severity -Code "critical_path_not_assessed" -Message "Not all dependency records have criticalPath assessment." -Path $file.FullName
            }
        }

        if ($artifact -eq "test-catalog") {
            $testRecords = @(Get-RecordsByKind -Payload $payload -Kinds @("test-case", "test-suite"))
            foreach ($testRecord in $testRecords) {
                $diag = Get-ObjectValue -Object $testRecord -Name "testDiagnosis" -Default $null
                if ($null -eq $diag) {
                    $severity = if ($Strict) { "error" } else { "warning" }
                    Add-GateIssue -Issues $issues -Severity $severity -Code "missing_test_diagnosis" -Message "testDiagnosis missing on test-catalog enriched record." -Path $file.FullName
                    break
                }
            }
        }
    }
}

$structuralCodes = @('missing_enriched_file', 'invalid_json', 'missing_architecture_fingerprint', 'missing_required_field')
$summary.structuralErrors = @($issues | Where-Object { $_.severity -eq 'error' -and ($structuralCodes -contains [string]$_.code) }).Count
$summary.semanticErrors = @($issues | Where-Object { $_.severity -eq 'error' -and (-not ($structuralCodes -contains [string]$_.code)) }).Count
$summary.warnings = @($issues | Where-Object { $_.severity -eq 'warning' }).Count

$hasErrors = @($issues | Where-Object { $_.severity -eq 'error' }).Count -gt 0
$passed = -not $hasErrors

$issueArray = @()
foreach ($issue in $issues) {
    $issueArray += $issue
}

$result = [pscustomobject]@{
    passed = $passed
    strictMode = [bool]$Strict
    summary = $summary
    issues = $issueArray
}

if ($Json) {
    $result | ConvertTo-Json -Depth 50
}
else {
    if ($passed) {
        Write-Host "Enrichment gate passed." -ForegroundColor Green
    }
    else {
        Write-Host "Enrichment gate failed." -ForegroundColor Red
    }

    Write-Host ("Checked enriched files: {0}; records: {1}" -f $summary.enrichedFilesChecked, $summary.recordsChecked) -ForegroundColor Gray
    Write-Host ("Structural errors: {0}; semantic errors: {1}; warnings: {2}" -f $summary.structuralErrors, $summary.semanticErrors, $summary.warnings) -ForegroundColor Gray

    foreach ($issue in $issues) {
        $color = if ($issue.severity -eq 'error') { 'Yellow' } else { 'DarkYellow' }
        Write-Host (" - [{0}] {1}: {2} ({3})" -f $issue.severity.ToUpperInvariant(), $issue.code, $issue.message, $issue.path) -ForegroundColor $color
    }
}

if (-not $passed) {
    exit 1
}
