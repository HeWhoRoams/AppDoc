param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Validate build cookbook
Write-Progress -Activity "Validating Build Cookbook" -Status "Checking cookbook..." -PercentComplete 0

$cookbookPath = Join-Path $RootPath "docs\build-cookbook.md"

if (-not (Test-Path $cookbookPath)) {
    Write-Error "Build cookbook file not found at $cookbookPath"
    exit 1
}

$content = Get-Content $cookbookPath -Raw

if ($content -notmatch "# Build Cookbook") {
    Write-Error "Invalid build cookbook format"
    exit 1
}

# Count commands from evidence first, fallback to rendered table rows
$commandCount = 0
$evidencePath = Join-Path $RootPath "docs\evidence\build-cookbook.evidence.json"
if (Test-Path $evidencePath) {
    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
        $commandCount = @($evidence.records | Where-Object { [string]$_.kind -in @("build-command", "command") }).Count
    }
    catch { }
}

if ($commandCount -le 0) {
    $commandCount = ([regex]::Matches(
        $content,
        '(?im)^\|\s*\d+\s*\|\s*`{1,2}[^|`]+`{1,2}\s*\|'
    )).Count
}

Write-Progress -Activity "Validating Build Cookbook" -Status "Validated $commandCount commands" -PercentComplete 100

Write-Host "Build cookbook validated: $commandCount commands found"
