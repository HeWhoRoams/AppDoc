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

# Count commands
$commandCount = ($content | Select-String -Pattern "^## " | Measure-Object).Count

Write-Progress -Activity "Validating Build Cookbook" -Status "Validated $commandCount commands" -PercentComplete 100

Write-Host "Build cookbook validated: $commandCount commands found"