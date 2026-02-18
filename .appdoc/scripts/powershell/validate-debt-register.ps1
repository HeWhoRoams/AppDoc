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

Write-Progress -Activity "Validating Technical Debt Register" -Status "Validated $debtCount debts" -PercentComplete 100

Write-Host "Technical debt register validated: $debtCount debts found"
