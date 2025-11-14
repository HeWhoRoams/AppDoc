param(
    [Parameter(Mandatory=$false)]
    [string]$RootPath = ".",
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "docs/assessment-report.md"
)

<#
.SYNOPSIS
    Synthesizes a comprehensive assessment report from all analysis data.

.DESCRIPTION
    This script loads all generated analysis JSON files and creates a unified
    markdown report summarizing the assessment findings.

.PARAMETER OutputPath
    Path where the final report should be saved. Defaults to specs/001-review-ai-samples/final-assessment-report.md

.EXAMPLE
    .\synthesize-assessment-report.ps1
    .\synthesize-assessment-report.ps1 -OutputPath "custom-report.md"
#>

# Synthesize assessment report
Write-Host "Synthesizing final assessment report..."

try {
    # Load all analysis data with error handling
    $catalog = @()
    $catalogPath = "specs/001-review-ai-samples/sample-catalog.json"
    if (Test-Path $catalogPath) {
        $catalog = Get-Content $catalogPath | ConvertFrom-Json
        Write-Host "Loaded $($catalog.Count) samples from catalog."
    } else {
        Write-Warning "Sample catalog not found at $catalogPath"
    }

    $gapAnalysis = @{ Gaps = @(); Samples = @() }
    $gapPath = "specs/001-review-ai-samples/gap-analysis.json"
    if (Test-Path $gapPath) {
        $gapAnalysis = Get-Content $gapPath | ConvertFrom-Json
        Write-Host "Loaded $($gapAnalysis.Gaps.Count) gaps from analysis."
    } else {
        Write-Warning "Gap analysis not found at $gapPath"
    }

    $improvements = @()
    $improvementsPath = "specs/001-review-ai-samples/improvement-suggestions.json"
    if (Test-Path $improvementsPath) {
        $improvements = Get-Content $improvementsPath | ConvertFrom-Json
        Write-Host "Loaded $($improvements.Count) improvement suggestions."
    } else {
        Write-Warning "Improvement suggestions not found at $improvementsPath"
    }

    $metrics = @{ comparison = @{} }
    $metricsPath = "specs/001-review-ai-samples/quality-metrics.json"
    if (Test-Path $metricsPath) {
        $metrics = Get-Content $metricsPath | ConvertFrom-Json
        Write-Host "Loaded quality metrics."
    } else {
        Write-Warning "Quality metrics not found at $metricsPath"
    }

    # Generate comprehensive report
    $report = @"
# Final Assessment Report: AI Samples vs Current AppDoc

Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")

## Executive Summary

This report assesses the current AppDoc documentation generation capabilities against high-quality AI-generated samples to identify improvement opportunities.

## Sample Analysis

**Total Samples Reviewed:** $($catalog.Count)

"@

    if ($gapAnalysis.Samples -and $gapAnalysis.Samples.Count -gt 0) {
        $avgScore = ($gapAnalysis.Samples | Measure-Object -Property QualityScore -Average).Average
        $report += @"

### Sample Quality Overview
- Average quality score: $([math]::Round($avgScore, 1))/10
- Samples with code snippets: $(($catalog | Where-Object { $_.hasCode }).Count)
- Samples with diagrams: $(($catalog | Where-Object { $_.hasDiagrams }).Count)

"@
    }

    $report += @"

## Capability Gaps Identified

**Total Gaps:** $($gapAnalysis.Gaps.Count)

"@

    if ($gapAnalysis.Gaps -and $gapAnalysis.Gaps.Count -gt 0) {
        foreach ($gap in $gapAnalysis.Gaps) {
            $report += @"
### $($gap.GapType) - $($gap.Severity.ToUpper())
**Description:** $($gap.Description)

**Current State:** $($gap.CurrentState)

**Target State:** $($gap.TargetState)

---
"@
        }
    } else {
        $report += "No significant gaps identified in the analysis.`n`n"
    }

    $report += @"


## Quality Metrics Comparison

"@

    if ($metrics.comparison) {
        $report += @"
**Current Documentation Average Score:** $($metrics.comparison.currentAverageScore)/10
**AI Samples Average Score:** $($metrics.comparison.aiSampleAverageScore)/10
**Quality Gap:** $($metrics.comparison.scoreGap)

### Feature Coverage
- Code Snippets: Current $($metrics.comparison.codeSnippetCoverage.current * 100)% vs AI $($metrics.comparison.codeSnippetCoverage.ai * 100)%
- Diagrams: Current $($metrics.comparison.diagramCoverage.current * 100)% vs AI $($metrics.comparison.diagramCoverage.ai * 100)%

"@
    } else {
        $report += "Quality metrics not available.`n`n"
    }

    $report += @"


## Recommended Improvements

**Total Recommendations:** $($improvements.Count)

"@

    if ($improvements -and $improvements.Count -gt 0) {
        foreach ($improvement in $improvements | Sort-Object -Property priority) {
            $report += @"
### Priority $($improvement.priority): $($improvement.component.ToUpper())
**Description:** $($improvement.description)

**Implementation:** $($improvement.implementationApproach)

**Effort:** $($improvement.estimatedEffort)

---
"@
        }
    } else {
        $report += "No improvement recommendations available.`n`n"
    }

    $report += @"


## Next Steps

1. Prioritize improvements by impact and effort
2. Implement prompt enhancements for better quality
3. Enhance scripts with code extraction and diagram generation
4. Update templates with AI sample formatting standards
5. Re-assess quality after improvements

## Conclusion

The assessment reveals significant opportunities to improve AppDoc's documentation quality to match AI-generated standards. Key focus areas include code snippet inclusion, visual diagram generation, and enhanced technical depth.

"@

    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    $report | Out-File -FilePath $OutputPath -Encoding UTF8

    Write-Host "Final assessment report synthesized at $OutputPath"
} catch {
    Write-Error "Failed to synthesize assessment report: $_"
    exit 1
}
