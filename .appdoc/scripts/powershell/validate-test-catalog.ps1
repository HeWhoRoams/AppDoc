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

# Count tests from evidence first, fallback to rendered test-case rows
$testCount = 0
$evidencePath = Join-Path $RootPath "docs\evidence\test-catalog.evidence.json"
if (Test-Path $evidencePath) {
    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
        $testCount = @($evidence.records | Where-Object { [string]$_.kind -in @("test-case", "test-suite") }).Count
    }
    catch {
        Write-Warning ("Failed to load or parse evidence file: {0}. Error: {1}" -f $evidencePath, $_)
    }
}


# Fallback: Count test cases by matching markdown table rows with backtick-enclosed cells and two trailing 'N/A' columns.
# This expects lines like: | `TestName` | `Suite` | N/A | N/A |
if ($testCount -le 0) {
    $testCount = ([regex]::Matches(
        $content,
        '(?im)^\|\s*`[^|`]+`\s*\|\s*`[^|`]+`\s*\|\s*N/A\s*\|\s*N/A\s*\|'
    )).Count
    if ($testCount -eq 0 -and $content.Trim().Length -gt 0) {
        Write-Warning "No test cases found using fallback regex. The test catalog format may have changed."
    }
}

Write-Progress -Activity "Validating Test Catalog" -Status "Validated $testCount tests" -PercentComplete 100

Write-Host "Test catalog validated: $testCount tests found"
