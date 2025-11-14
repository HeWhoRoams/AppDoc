#
# generate-overview.ps1
#
# Purpose: Populates the overview template with repository analysis, tech stack, and navigation
#          to all documentation artifacts. Serves as the landing page for documentation.
#
# Usage: .\generate-overview.ps1 -RootPath <target_codebase_path>
# Output: Populates docs/overview.md from template
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Import template helpers
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) {
    . $helpersPath
}

Write-Host "📊 Generating System Overview..." -ForegroundColor Cyan

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Initialize template
$outputPath = Join-Path $RootPath "docs\overview.md"
$initialized = Initialize-TemplateFile -TemplateName "overview-template.md" -OutputPath $outputPath -RootPath $RootPath

if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating System Overview" -Status "Analyzing repository..." -PercentComplete 0

$docsPath = Join-Path $RootPath "docs"

# Quick file/language analysis instead of calling separate scripts
$codeFiles = Get-ChildItem -Path $RootPath -Recurse -Include "*.cs","*.js","*.ts","*.py" -ErrorAction SilentlyContinue |
    Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\packages\\)' }

$languageCount = @{}
$codeFiles | ForEach-Object {
    $ext = $_.Extension
    if (-not $languageCount.ContainsKey($ext)) {
        $languageCount[$ext] = 0
    }
    $languageCount[$ext]++
}

Write-Progress -Activity "Generating System Overview" -Status "Populating template..." -PercentComplete 50

# Build tech stack table
$techStackContent = if ($languageCount.Keys.Count -gt 0) {
    $tableRows = $languageCount.GetEnumerator() | Sort-Object Value -Descending | ForEach-Object {
        $tech = switch ($_.Key) {
            ".cs" { "C# / .NET" }
            ".js" { "JavaScript" }
            ".ts" { "TypeScript" }
            ".py" { "Python" }
            default { $_.Key }
        }
        "| Language | $tech | - | Application code |"
    }
    ($tableRows -join "`n")
} else {
    ""
}

# Build system purpose placeholder replacement
$systemPurposeContent = if ($codeFiles.Count -gt 0) {
    "This codebase contains $($codeFiles.Count) code files across $($languageCount.Keys.Count) language(s). Full analysis available in linked documentation."
} else {
    ""
}

# Update template sections
$content = Get-Content -Path $outputPath -Raw

# Replace system purpose (just the italic line)
if ($systemPurposeContent) {
    $content = Update-TemplateSection -Content $content -PlaceholderText "_System purpose not yet documented. Analyze README and code structure to determine._" -NewContent $systemPurposeContent
}

# Replace tech stack table (insert rows after header, remove placeholder line)
if ($techStackContent) {
    # Find and replace the empty table + placeholder with populated table
    $oldTable = "| Category | Technology | Version | Purpose |`r`n|----------|-----------|---------|---------|`r`n`r`n_Technology stack not yet identified. Analyze package files and code._"
    $newTable = "| Category | Technology | Version | Purpose |`r`n|----------|-----------|---------|---------|`r`n" + $techStackContent
    $content = Update-TemplateSection -Content $content -PlaceholderText $oldTable -NewContent $newTable
}
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Progress -Activity "Generating System Overview" -Status "Complete" -PercentComplete 100
Write-Host "✅ System overview generated: $outputPath" -ForegroundColor Green
Write-Host "   Code files analyzed: $($codeFiles.Count)" -ForegroundColor Gray
