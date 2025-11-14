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

# Count debts
$debtCount = ($content | Select-String -Pattern "^## " | Measure-Object).Count

Write-Progress -Activity "Validating Technical Debt Register" -Status "Validated $debtCount debts" -PercentComplete 100

Write-Host "Technical debt register validated: $debtCount debts found"