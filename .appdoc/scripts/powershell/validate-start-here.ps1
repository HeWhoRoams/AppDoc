param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

Write-Progress -Activity "Validating Start Here" -Status "Checking start-here guide..." -PercentComplete 0

$path = Join-Path $RootPath "docs" "start-here.md"
if (-not (Test-Path $path)) {
    Write-Error "Start Here file not found at $path"
    exit 1
}

$content = Get-Content $path -Raw
if ($content -notmatch "(?m)^# Start Here") {
    Write-Error "Invalid Start Here format"
    exit 1
}

$requiredSections = @(
    "Who This Is For",
    "15-Minute Orientation",
    "Role-Based Paths",
    "System Signals",
    "Evidence Traceability"
)

$missing = @()
foreach ($section in $requiredSections) {
    if ($content -notmatch "(?im)^##\s+$([regex]::Escape($section))\b") {
        $missing += $section
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Start Here missing required sections: $($missing -join ', ')"
    exit 1
}

Write-Progress -Activity "Validating Start Here" -Status "Complete" -PercentComplete 100
Write-Host "Start Here validated: all required sections present"
