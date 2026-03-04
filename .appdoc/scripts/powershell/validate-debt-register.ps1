param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Validate technical debt register
Write-Progress -Activity "Validating Technical Debt Register" -Status "Checking register..." -PercentComplete 0

$registerPath = Join-Path $RootPath "docs\debt-register.md"

if (-not (Test-Path $registerPath)) {
    Write-Error "Technical debt register file not found at $registerPath"
    exit 1
}

$content = Get-Content $registerPath -Raw

if ($content -notmatch "# Technical Debt Register") {
    Write-Error "Invalid technical debt register format"
    exit 1
}

# Count debts from evidence first, fallback to debt item table rows
$debtCount = 0
$evidencePath = Join-Path $RootPath "docs\evidence\debt-register.evidence.json"
if (Test-Path $evidencePath) {
    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
        $debtCount = @($evidence.records | Where-Object { [string]$_.kind -in @("technical-debt", "debt-item") }).Count
    }
    catch { }
}

if ($debtCount -le 0) {
    $debtCount = ([regex]::Matches(
        $content,
        '(?im)^\|\s*[^|]+\s*\|\s*`[^|`]+:\d+`\s*\|\s*[^|]+\s*\|\s*[^|]+\s*\|\s*[^|]+\s*\|'
    )).Count
}

$issues = @()
if ($content -notmatch '(?im)^###\s+First-Party Debt \(Priority\)\s*$') {
    $issues += "missing-first-party-debt-section"
}
if ($content -notmatch '(?im)^###\s+Vendor/Generated Debt\s*$') {
    $issues += "missing-vendor-generated-debt-section"
}

$debtRows = @([regex]::Matches($content, '(?im)^\|\s*[^|]+\|\s*`[^`]+`\s*\|\s*(first-party|vendor/generated)\s*\|.*\|\s*
if ($debtRows.Count -gt 0) {
    $duplicates = @($debtRows | Group-Object | Where-Object { $_.Count -gt 1 })
    if ($duplicates.Count -gt 0) {
        $issues += ("duplicate-debt-rows:{0}" -f $duplicates.Count)
    }
}

Write-Progress -Activity "Validating Technical Debt Register" -Status "Validated $debtCount debts" -PercentComplete 100

if ($issues.Count -gt 0) {
    Write-Host "Technical debt register validation failed:" -ForegroundColor Red
    foreach ($issue in ($issues | Select-Object -Unique)) {
        Write-Host (" - {0}" -f $issue) -ForegroundColor Red
    }
    exit 1
}

Write-Host "Technical debt register validated: $debtCount debts found"
) | ForEach-Object { [string]$_.Value.Trim() })
if ($debtRows.Count -gt 0) {
    $duplicates = @($debtRows | Group-Object | Where-Object { $_.Count -gt 1 })
    if ($duplicates.Count -gt 0) {
        $issues += ("duplicate-debt-rows:{0}" -f $duplicates.Count)
    }
}

Write-Progress -Activity "Validating Technical Debt Register" -Status "Validated $debtCount debts" -PercentComplete 100

if ($issues.Count -gt 0) {
    Write-Host "Technical debt register validation failed:" -ForegroundColor Red
    foreach ($issue in ($issues | Select-Object -Unique)) {
        Write-Host (" - {0}" -f $issue) -ForegroundColor Red
    }
    exit 1
}

Write-Host "Technical debt register validated: $debtCount debts found"
