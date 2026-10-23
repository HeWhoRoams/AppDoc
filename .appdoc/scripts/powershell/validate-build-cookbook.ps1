#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

# Validate build cookbook
Write-Progress -Activity "Validating Build Cookbook" -Status "Checking cookbook..." -PercentComplete 0

$cookbookPath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "build-cookbook.md"

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
$evidencePath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "evidence\build-cookbook.evidence.json"
if (Test-Path $evidencePath) {
    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
        $commandCount = @($evidence.records | Where-Object { [string]$_.kind -in @("build-command", "command") }).Count
    }
    catch { Write-Warning ("build-cookbook evidence could not be read; counting 0 commands: {0}" -f $_.Exception.Message) }
}

if ($commandCount -le 0) {
    $commandCount = ([regex]::Matches(
        $content,
        '(?im)^\|\s*\d+\s*\|\s*`{1,2}[^|`]+`{1,2}\s*\|'
    )).Count
}

Write-Progress -Activity "Validating Build Cookbook" -Status "Validated $commandCount commands" -PercentComplete 100

Write-Host "Build cookbook validated: $commandCount commands found"
