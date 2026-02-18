param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Validate data model
Write-Progress -Activity "Validating Data Model" -Status "Checking model..." -PercentComplete 0

$modelPath = Join-Path $RootPath "docs\data-model.md"

if (-not (Test-Path $modelPath)) {
    Write-Error "Data model file not found at $modelPath"
    exit 1
}

$content = Get-Content $modelPath -Raw

if ($content -notmatch "# Data Model") {
    Write-Error "Invalid data model format"
    exit 1
}

# Count models from evidence first, fallback to rendered table rows.
$modelCount = 0
$evidencePath = Join-Path $RootPath "docs\evidence\data-model.evidence.json"
if (Test-Path $evidencePath) {
    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
        $modelCount = @($evidence.records | Where-Object { [string]$_.kind -eq "model" }).Count
    }
    catch { }
}

if ($modelCount -le 0) {
    $modelCount = ([regex]::Matches(
        $content,
        '(?im)^\|\s*`[^|]+`\s*\|\s*\d+\s*\|'
    )).Count
}

Write-Progress -Activity "Validating Data Model" -Status "Validated $modelCount models" -PercentComplete 100

Write-Host "Data model validated: $modelCount models found"
