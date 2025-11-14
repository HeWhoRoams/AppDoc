param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Validate test catalog
Write-Progress -Activity "Validating Test Catalog" -Status "Checking catalog..." -PercentComplete 0

$catalogPath = Join-Path $RootPath "docs\test-catalog.md"

if (-not (Test-Path $catalogPath)) {
    Write-Error "Test catalog file not found at $catalogPath"
    exit 1
}

$content = Get-Content $catalogPath -Raw

if ($content -notmatch "# Test Catalog") {
    Write-Error "Invalid test catalog format"
    exit 1
}

# Count tests
$testCount = ($content | Select-String -Pattern "^## " | Measure-Object).Count

Write-Progress -Activity "Validating Test Catalog" -Status "Validated $testCount tests" -PercentComplete 100

Write-Host "Test catalog validated: $testCount tests found"