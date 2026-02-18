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

# Count endpoints from evidence first, fallback to rendered table rows.
$endpointCount = 0
$evidencePath = Join-Path $RootPath "docs\evidence\api-inventory.evidence.json"
if (Test-Path $evidencePath) {
    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
        $endpointCount = @($evidence.records | Where-Object { [string]$_.kind -eq "endpoint" }).Count
    }
    catch {
        Write-Warning "[validate-api-inventory] Failed to parse evidence at $evidencePath: $($_.Exception.Message)"
    }
}

if ($endpointCount -le 0) {
    $endpointCount = ([regex]::Matches(
        $content,
        '(?im)^\|\s*`[^|]+`\s*\|\s*`/[^|]+`\s*\|\s*(GET|POST|PUT|DELETE|PATCH|ANY)\s*\|'
    )).Count
}

Write-Progress -Activity "Validating API Inventory" -Status "Validated $endpointCount endpoints" -PercentComplete 100

Write-Host "API inventory validated: $endpointCount endpoints found"
