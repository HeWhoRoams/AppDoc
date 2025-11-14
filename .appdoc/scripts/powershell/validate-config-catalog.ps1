param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Validate config catalog
Write-Progress -Activity "Validating Config Catalog" -Status "Checking catalog..." -PercentComplete 0

$catalogPath = Join-Path $RootPath "docs\config-catalog.md"

if (-not (Test-Path $catalogPath)) {
    Write-Error "Config catalog file not found at $catalogPath"
    exit 1
}

$content = Get-Content $catalogPath -Raw

if ($content -notmatch "# Config(?:uration)? Catalog") {
    Write-Error "Invalid config catalog format"
    exit 1
}

# Count configs
$configCount = ($content | Select-String -Pattern "^## " | Measure-Object).Count

Write-Progress -Activity "Validating Config Catalog" -Status "Validated $configCount configs" -PercentComplete 100

Write-Host "Config catalog validated: $configCount configs found"