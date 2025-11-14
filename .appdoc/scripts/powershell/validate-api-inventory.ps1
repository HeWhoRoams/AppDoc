param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Validate API inventory
Write-Progress -Activity "Validating API Inventory" -Status "Checking inventory..." -PercentComplete 0

$inventoryPath = Join-Path $RootPath "docs\api-inventory.md"

if (-not (Test-Path $inventoryPath)) {
    Write-Error "API inventory file not found at $inventoryPath"
    exit 1
}

$content = Get-Content $inventoryPath -Raw

if ($content -notmatch "# API Inventory") {
    Write-Error "Invalid API inventory format"
    exit 1
}

# Count endpoints
$endpointCount = ($content | Select-String -Pattern "^## " | Measure-Object).Count

Write-Progress -Activity "Validating API Inventory" -Status "Validated $endpointCount endpoints" -PercentComplete 100

Write-Host "API inventory validated: $endpointCount endpoints found"