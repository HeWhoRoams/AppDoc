param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

Write-Progress -Activity "Validating Task Guides" -Status "Checking task guides..." -PercentComplete 0

$path = Join-Path $RootPath "docs\task-guides.md"
if (-not (Test-Path $path)) {
    Write-Error "Task guides file not found at $path"
    exit 1
}

$content = Get-Content $path -Raw

if ($content -notmatch "# Task Guides") {
    Write-Error "Invalid task guides format"
    exit 1
}

$requiredSections = @(
    "Executive Summary",
    "Task Guides",
    "Operational Checklist",
    "Evidence Traceability"
)

$missing = @()
foreach ($section in $requiredSections) {
    if ($content -notmatch "(?im)^##\s+$([regex]::Escape($section))\b") {
        $missing += $section
    }
}

if ($missing.Count -gt 0) {
    Write-Error "Task guides missing required sections: $($missing -join ', ')"
    exit 1
}

$guideHeadings = ([regex]::Matches($content, '(?im)^###\s+')).Count
if ($guideHeadings -lt 4) {
    Write-Error "Task guides expected at least 4 task subsections, found $guideHeadings"
    exit 1
}

Write-Progress -Activity "Validating Task Guides" -Status "Complete" -PercentComplete 100
Write-Host "Task guides validated: $guideHeadings task sections found"
