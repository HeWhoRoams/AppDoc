param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [switch]$IncludeAssessment,
    [Parameter(Mandatory=$false)]
    [string]$SampleDir
)

<#
.SYNOPSIS
    Runs all documentation generators with optional quality assessment.

.DESCRIPTION
    This script executes all AppDoc documentation generators and optionally
    runs quality assessment against AI samples.

.PARAMETER RootPath
    Root path of the project to analyze.

.PARAMETER IncludeAssessment
    Include AI sample quality assessment in the workflow.

.PARAMETER SampleDir
    Directory containing AI samples for assessment. Required if IncludeAssessment is used.

.EXAMPLE
    .\run-all-generators.ps1 -RootPath "c:\myproject"
    .\run-all-generators.ps1 -RootPath "c:\myproject" -IncludeAssessment -SampleDir "AppDoc.ai_samples"
#>

# Validation function to detect placeholder content and assess quality
function Validate-GeneratedDoc {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [string]$DocType
    )
    
    if (-not (Test-Path $FilePath)) {
        return @{
            docType = $DocType
            exists = $false
            quality = "MISSING"
            score = 0
            placeholders = @()
            issues = @("File does not exist")
        }
    }
    
    $content = Get-Content $FilePath -Raw
    $placeholders = @()
    $issues = @()
    
    # Detect common placeholder patterns
    $placeholderPatterns = @(
        @{ Pattern = '_No .* detected'; Description = "Empty detection placeholder" }
        @{ Pattern = 'Describe the purpose'; Description = "Generic template instruction" }
        @{ Pattern = 'Document (the|where|how)'; Description = "Template instruction remaining" }
        @{ Pattern = '\[PLACEHOLDER\]|\[TODO\]|\[TBD\]'; Description = "Explicit placeholder marker" }
        @{ Pattern = 'This (section|codebase) may'; Description = "Uncertain filler text" }
        @{ Pattern = 'Check for|Consult|Review'; Description = "Deferred instruction" }
    )
    
    foreach ($pattern in $placeholderPatterns) {
        $matches = [regex]::Matches($content, $pattern.Pattern, 'IgnoreCase')
        if ($matches.Count -gt 0) {
            $placeholders += "$($matches.Count)x $($pattern.Description)"
        }
    }
    
    # Count critical sections (table rows, list items)
    $tableRowCount = ([regex]::Matches($content, '^\|[^|]+\|', 'Multiline')).Count
    $listItemCount = ([regex]::Matches($content, '^[-*]\s+', 'Multiline')).Count
    $codeBlockCount = ([regex]::Matches($content, '```', 'Multiline')).Count
    
    # Detect empty critical sections
    if ($content -match '\|\s*---\s*\|[\r\n]+[\r\n]+_No') {
        $issues += "Empty table with placeholder"
    }
    
    if ($tableRowCount -le 2 -and $DocType -in @('API Inventory', 'Data Model', 'Config Catalog', 'Test Catalog')) {
        $issues += "Table has no data rows (header only)"
    }
    
    # Calculate quality score (0-100)
    $score = 100
    $score -= ($placeholders.Count * 15)  # -15 per placeholder type
    $score -= ($issues.Count * 20)        # -20 per issue
    
    # Bonus for having content
    if ($tableRowCount -gt 5) { $score += 10 }
    if ($listItemCount -gt 10) { $score += 5 }
    if ($codeBlockCount -gt 2) { $score += 5 }
    
    $score = [Math]::Max(0, [Math]::Min(100, $score))
    
    # Determine quality level
    $quality = if ($score -ge 80) { "HIGH" } 
               elseif ($score -ge 40) { "MEDIUM" }
               else { "LOW" }
    
    return @{
        docType = $DocType
        exists = $true
        quality = $quality
        score = $score
        placeholders = $placeholders
        issues = $issues
        tableRows = $tableRowCount
        listItems = $listItemCount
        codeBlocks = $codeBlockCount
    }
}

# Run all generators
Write-Host "Running all documentation generators..."

$scripts = @(
    "analyze-repository.ps1",
    "generate-dependency-graph.ps1",
    "extract-config.ps1",
    "generate-overview.ps1",
    "generate-api-inventory.ps1",
    "generate-data-model.ps1",
    "generate-config-catalog.ps1",
    "generate-build-cookbook.ps1",
    "generate-test-catalog.ps1",
    "generate-debt-register.ps1",
    "generate-dependencies-catalog.ps1"
)

foreach ($script in $scripts) {
    $scriptPath = Join-Path $PSScriptRoot $script
    if (Test-Path $scriptPath) {
        Write-Host "Running $script..."
        try {
            & $scriptPath -RootPath $RootPath
        } catch {
            Write-Warning "Failed to run $script`: $_"
        }
    } else {
        Write-Warning "Script $script not found"
    }
}

# Run assessment if requested
if ($IncludeAssessment) {
    if (-not $SampleDir) {
        Write-Error "SampleDir parameter is required when using -IncludeAssessment"
        exit 1
    }

    Write-Host "Running quality assessment..."

    $assessmentScripts = @(
        "catalog-samples.ps1",
        "analyze-capability-gaps.ps1",
        "generate-improvements.ps1",
        "calculate-quality-metrics.ps1",
        "synthesize-assessment-report.ps1"
    )

    foreach ($script in $assessmentScripts) {
        $scriptPath = Join-Path $PSScriptRoot $script
        if (Test-Path $scriptPath) {
            Write-Host "Running assessment script $script..."
            try {
                switch ($script) {
                    "catalog-samples.ps1" { & $scriptPath -SampleDir $SampleDir }
                    "analyze-capability-gaps.ps1" { & $scriptPath -SampleDir $SampleDir -CurrentDocsDir "docs" }
                    "generate-improvements.ps1" { & $scriptPath }
                    "calculate-quality-metrics.ps1" { & $scriptPath }
                    "synthesize-assessment-report.ps1" { & $scriptPath }
                }
            } catch {
                Write-Warning "Failed to run assessment script $script`: $_"
            }
        } else {
            Write-Warning "Assessment script $script not found"
        }
    }
}

Write-Host "`n=== Documentation Quality Report ===" -ForegroundColor Cyan

# Validate all generated documents
$docsPath = Join-Path $RootPath "docs"
$validationResults = @()

$documents = @(
    @{ File = "overview.md"; Type = "Overview" }
    @{ File = "api-inventory.md"; Type = "API Inventory" }
    @{ File = "data-model.md"; Type = "Data Model" }
    @{ File = "config-catalog.md"; Type = "Config Catalog" }
    @{ File = "build-cookbook.md"; Type = "Build Cookbook" }
    @{ File = "test-catalog.md"; Type = "Test Catalog" }
    @{ File = "debt-register.md"; Type = "Debt Register" }
    @{ File = "dependencies-catalog.md"; Type = "Dependencies Catalog" }
)

foreach ($doc in $documents) {
    $filePath = Join-Path $docsPath $doc.File
    $result = Validate-GeneratedDoc -FilePath $filePath -DocType $doc.Type
    $validationResults += $result
}

# Display quality summary with color coding
Write-Host "`nQuality Summary:" -ForegroundColor White
Write-Host ("=" * 80) -ForegroundColor Gray

foreach ($result in $validationResults) {
    $emoji = switch ($result.quality) {
        "HIGH"   { "🟢" }
        "MEDIUM" { "🟡" }
        "LOW"    { "🔴" }
        "MISSING" { "❌" }
    }
    
    $color = switch ($result.quality) {
        "HIGH"   { "Green" }
        "MEDIUM" { "Yellow" }
        "LOW"    { "Red" }
        "MISSING" { "DarkRed" }
    }
    
    Write-Host "$emoji " -NoNewline
    Write-Host "$($result.docType): " -NoNewline -ForegroundColor White
    Write-Host "$($result.quality) ($($result.score)%)" -ForegroundColor $color
    
    if ($result.placeholders.Count -gt 0) {
        foreach ($placeholder in $result.placeholders) {
            Write-Host "   ⚠️  $placeholder" -ForegroundColor DarkYellow
        }
    }
    
    if ($result.issues.Count -gt 0) {
        foreach ($issue in $result.issues) {
            Write-Host "   ❌ $issue" -ForegroundColor DarkRed
        }
    }
}

# Calculate overall metrics
$totalDocs = $validationResults.Count
$highQuality = ($validationResults | Where-Object { $_.quality -eq "HIGH" }).Count
$mediumQuality = ($validationResults | Where-Object { $_.quality -eq "MEDIUM" }).Count
$lowQuality = ($validationResults | Where-Object { $_.quality -eq "LOW" }).Count
$missingDocs = ($validationResults | Where-Object { $_.quality -eq "MISSING" }).Count
$avgScore = [Math]::Round(($validationResults | Where-Object { $_.exists } | Measure-Object -Property score -Average).Average, 1)

Write-Host "`n" + ("=" * 80) -ForegroundColor Gray
Write-Host "Overall Statistics:" -ForegroundColor Cyan
Write-Host "  Total Documents: $totalDocs" -ForegroundColor White
Write-Host "  🟢 High Quality (>80%): $highQuality" -ForegroundColor Green
Write-Host "  🟡 Medium Quality (40-80%): $mediumQuality" -ForegroundColor Yellow
Write-Host "  🔴 Low Quality (<40%): $lowQuality" -ForegroundColor Red
if ($missingDocs -gt 0) {
    Write-Host "  ❌ Missing Documents: $missingDocs" -ForegroundColor DarkRed
}
Write-Host "  📊 Average Quality Score: $avgScore%" -ForegroundColor White

# Save quality report JSON
$reportPath = Join-Path $docsPath "quality-report.json"
$reportData = @{
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    overall = @{
        totalDocs = $totalDocs
        highQuality = $highQuality
        mediumQuality = $mediumQuality
        lowQuality = $lowQuality
        missingDocs = $missingDocs
        averageScore = $avgScore
    }
    documents = $validationResults
}
$reportData | ConvertTo-Json -Depth 10 | Out-File -FilePath $reportPath -Encoding UTF8
Write-Host "`n📄 Quality report saved: $reportPath" -ForegroundColor Cyan

# Exit with warning if majority are low quality
if ($lowQuality -gt ($totalDocs / 2)) {
    Write-Host "`n⚠️  WARNING: More than 50% of documentation is LOW quality!" -ForegroundColor Red
    Write-Host "   Consider running AppDoc enhancement workflow or manual review." -ForegroundColor Yellow
}

Write-Host "`nAll generators completed." -ForegroundColor Green
