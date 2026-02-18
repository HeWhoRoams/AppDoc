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

# Count configuration option rows
$configCount = ([regex]::Matches(
    $content,
    '(?im)^\|\s*[^|`\r\n]+\s*\|\s*[^|]+\|\s*[^|]+\|\s*[^|]+\|\s*(Yes|No)\s*\|\s*[^|]+\|'
)).Count

Write-Progress -Activity "Validating Config Catalog" -Status "Validated $configCount configs" -PercentComplete 100

Write-Host "Config catalog validated: $configCount configs found"
