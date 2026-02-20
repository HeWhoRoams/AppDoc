param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

Write-Progress -Activity "Validating Overview" -Status "Checking overview sections..." -PercentComplete 0

$overviewPath = Join-Path $RootPath "docs\overview.md"
if (-not (Test-Path $overviewPath)) {
    Write-Error "overview.md not found at $overviewPath"
    exit 1
}

$overview = Get-Content $overviewPath -Raw
$issues = @()

$requiredSections = @(
    "Welcome",
    "Executive Summary",
    "System Purpose",
    "Architecture",
    "Technology Stack"
)

foreach ($section in $requiredSections) {
    if (-not [regex]::IsMatch($overview, "(?im)^##\s+" + [regex]::Escape($section) + "\b")) {
        $issues += "missing-section:$section"
    }
}

$welcomeMatch = [regex]::Match(
    $overview,
    '(?ims)^##\s+Welcome\s*$\r?\n(.*?)(?=^##\s+[^\r\n]+|\z)'
)

if (-not $welcomeMatch.Success) {
    $issues += "missing-welcome-content"
}
else {
    $welcomeContent = [string]$welcomeMatch.Groups[1].Value
    $requiredWelcomeSubsections = @(
        "what_it_does",
        "inputs",
        "processing_steps",
        "outputs",
        "external_systems",
        "confidence_notes",
        "evidence_refs"
    )

    foreach ($subsection in $requiredWelcomeSubsections) {
        if (-not [regex]::IsMatch($welcomeContent, "(?im)^###\s+" + [regex]::Escape($subsection) + "\b")) {
            $issues += "missing-welcome-subsection:$subsection"
        }
    }

    $welcomeEvidenceHits = ([regex]::Matches($welcomeContent, '(?i)ev-\d{4}')).Count
    if ($welcomeEvidenceHits -eq 0) {
        $issues += "missing-welcome-evidence-refs"
    }
}

Write-Progress -Activity "Validating Overview" -Status "Complete" -PercentComplete 100

if ($issues.Count -gt 0) {
    Write-Host "Overview validation failed:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host " - $issue" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Overview validation passed" -ForegroundColor Green
