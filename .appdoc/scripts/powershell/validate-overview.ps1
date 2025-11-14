param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Validate overview against codebase
Write-Progress -Activity "Validating Overview" -Status "Checking overview..." -PercentComplete 0

$overviewPath = Join-Path $RootPath "docs\overview.md"
if (!(Test-Path $overviewPath)) {
    Write-Host "Overview not found, cannot validate"
    exit 1
}

$overview = Get-Content $overviewPath -Raw

# Simple validation: check if total files mentioned matches current count
$currentFiles = (Get-ChildItem -Path $RootPath -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\node_modules\\' }).Count

if ($overview -match "Total Files: (\d+)") {
    $reportedFiles = [int]$matches[1]
    if ($reportedFiles -eq $currentFiles) {
        Write-Host "Validation passed: File count matches"
    } else {
        Write-Host "Validation failed: File count mismatch ($reportedFiles vs $currentFiles)"
    }
}

Write-Progress -Activity "Validating Overview" -Status "Complete" -PercentComplete 100