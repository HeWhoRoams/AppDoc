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

# Count models
$modelCount = ($content | Select-String -Pattern "^## " | Measure-Object).Count

Write-Progress -Activity "Validating Data Model" -Status "Validated $modelCount models" -PercentComplete 100

Write-Host "Data model validated: $modelCount models found"