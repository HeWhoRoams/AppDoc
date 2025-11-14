# Analyze codebase to identify documentation gaps
# Used by /AppDoc.analyze command

param(
    [string]$RootPath = (Get-Location).Path,
    [switch]$IncludePrivate,
    [string]$Output = "docs/coverage-report.md",
    [switch]$Json,
    [switch]$Help
)

if ($Help) {
    Write-Host @"
AppDoc Framework - Analyze Codebase

Scans the codebase to identify documentation gaps and generate coverage report.

Parameters:
  -RootPath <path>       Project root path (default: current directory)
  -IncludePrivate        Include private/internal symbols in analysis
  -Output <path>         Output file path (default: docs/coverage-report.md)
  -Json                  Output results as JSON instead of markdown
  -Help                  Show this help message

Examples:
  .\analyze-codebase.ps1
  .\analyze-codebase.ps1 -RootPath C:\projects\myapp
  .\analyze-codebase.ps1 -IncludePrivate -Json
  .\analyze-codebase.ps1 -Output analysis/coverage.md

Output:
  Generates a documentation coverage report with:
  - Overall coverage statistics
  - Undocumented symbols by priority
  - Coverage by language/module
  - Recommendations for documentation
"@
    exit 0
}

# Import common functions
$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
. (Join-Path $scriptDir "common.ps1")

# Main analysis function
function Analyze-CodebaseDocumentation {
    $startTime = Get-Date

    Write-Host "📊 Analyzing codebase for documentation gaps..." -ForegroundColor Cyan

    # Get project metadata
    Write-Host "  → Loading project metadata..." -NoNewline
    $metadata = Get-ProjectMetadata -RootPath $RootPath
    Write-Host " ✓" -ForegroundColor Green

    # Find source files (include C# for .NET projects)
    Write-Host "  → Scanning for source files..." -NoNewline
    $sourceFiles = Find-SourceFiles -RootPath $RootPath -Languages @("typescript", "javascript", "python", "java", "csharp")
    Write-Host " ✓ Found $($sourceFiles.TotalFiles) files" -ForegroundColor Green
    
    # Early exit if no files found
    if ($sourceFiles.TotalFiles -eq 0) {
        Write-Host "  ⚠️ No source files found to analyze" -ForegroundColor Yellow
        return @{
            TotalFiles = 0
            TotalSymbols = 0
            DocumentedSymbols = 0
            PartiallyDocumented = 0
            UndocumentedSymbols = 0
            CoveragePercent = 0
            SymbolsByPriority = @{
                P1 = @(); P2 = @(); P3 = @(); P4 = @()
            }
            FileAnalysis = @()
        }
    }

    # Analyze each file (simplified - in real implementation would parse symbols)
    Write-Host "  → Analyzing symbols and documentation..." -NoNewline
    $analysis = @{
        TotalFiles = $sourceFiles.TotalFiles
        TotalSymbols = 0
        DocumentedSymbols = 0
        PartiallyDocumented = 0
        UndocumentedSymbols = 0
        SymbolsByPriority = @{
            P1 = @()
            P2 = @()
            P3 = @()
            P4 = @()
        }
        FileAnalysis = @()
    }

    # Simplified symbol counting (real implementation would use Tree-sitter or VSCode API)
    foreach ($file in $sourceFiles.Files) {
        $content = Get-Content $file -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $fileAnalysis = @{
            Path = $file
            Symbols = @()
            Coverage = 0
        }

        # Rough heuristics for symbol detection
        $functionMatches = [regex]::Matches($content, '(?:function|def|public|private)\s+(\w+)\s*\(')
        $classMatches = [regex]::Matches($content, '(?:class|interface)\s+(\w+)')

        foreach ($match in $functionMatches) {
            $symbolName = $match.Groups[1].Value
            $hasDoc = $content -match "(?:/\*\*|'''|`"`"`")\s*[\s\S]*?$symbolName"

            $symbol = @{
                Name = $symbolName
                Type = "function"
                Documented = $hasDoc
                Priority = "P2"  # Simplified priority
            }

            $fileAnalysis.Symbols += $symbol
            $analysis.TotalSymbols++

            if ($hasDoc) {
                $analysis.DocumentedSymbols++
            } else {
                $analysis.UndocumentedSymbols++
                $analysis.SymbolsByPriority.P2 += @{
                    Symbol = $symbolName
                    File = $file
                    Line = 0  # Would extract from match in real impl
                }
            }
        }

        foreach ($match in $classMatches) {
            $symbolName = $match.Groups[1].Value
            $hasDoc = $content -match "(?:/\*\*|'''|`"`"`")\s*[\s\S]*?class\s+$symbolName"

            $symbol = @{
                Name = $symbolName
                Type = "class"
                Documented = $hasDoc
                Priority = "P1"  # Classes are higher priority
            }

            $fileAnalysis.Symbols += $symbol
            $analysis.TotalSymbols++

            if ($hasDoc) {
                $analysis.DocumentedSymbols++
            } else {
                $analysis.UndocumentedSymbols++
                $analysis.SymbolsByPriority.P1 += @{
                    Symbol = $symbolName
                    File = $file
                    Line = 0
                }
            }
        }

        if ($fileAnalysis.Symbols.Count -gt 0) {
            $documented = ($fileAnalysis.Symbols | Where-Object { $_.Documented }).Count
            $fileAnalysis.Coverage = [math]::Round(($documented / $fileAnalysis.Symbols.Count) * 100, 1)
            $analysis.FileAnalysis += $fileAnalysis
        }
    }

    Write-Host " ✓ Analyzed $($analysis.TotalSymbols) symbols" -ForegroundColor Green

    # Calculate overall coverage
    if ($analysis.TotalSymbols -gt 0) {
        $analysis.CoveragePercent = [math]::Round(($analysis.DocumentedSymbols / $analysis.TotalSymbols) * 100, 1)
    } else {
        $analysis.CoveragePercent = 0
    }

    $elapsed = (Get-Date) - $startTime
    Write-Host "`n✅ Analysis complete in $([math]::Round($elapsed.TotalSeconds, 1)) seconds" -ForegroundColor Green
    Write-Host "   Coverage: $($analysis.CoveragePercent)% ($($analysis.DocumentedSymbols)/$($analysis.TotalSymbols) documented)" -ForegroundColor $(if ($analysis.CoveragePercent -ge 80) { "Green" } else { "Yellow" })

    return $analysis
}

# Generate markdown report
function New-CoverageReport {
    param($Analysis, $Metadata)

    $report = @"
# Documentation Coverage Report

**Generated**: $(Get-Date -Format "yyyy-MM-DD HH:mm:ss")
**Project**: $($Metadata.Name)

## Summary

| Metric | Count | Percentage |
|--------|-------|------------|
| Total Symbols | $($Analysis.TotalSymbols) | 100% |
| Documented | $($Analysis.DocumentedSymbols) | $($Analysis.CoveragePercent)% |
| Undocumented | $($Analysis.UndocumentedSymbols) | $([math]::Round(100 - $Analysis.CoveragePercent, 1))% |

## Coverage Status

"@

    if ($Analysis.CoveragePercent -ge 80) {
        $report += "✅ **GOOD** - Coverage meets recommended threshold (≥80%)`n`n"
    } elseif ($Analysis.CoveragePercent -ge 60) {
        $report += "⚠️ **FAIR** - Coverage below recommended threshold (60-79%)`n`n"
    } else {
        $report += "❌ **POOR** - Coverage significantly below threshold (<60%)`n`n"
    }

    # Priority items
    $report += "## Priority Documentation Gaps`n`n"

    if ($Analysis.SymbolsByPriority.P1.Count -gt 0) {
        $report += "### P1 - Critical (Public APIs)`n`n"
        foreach ($item in $Analysis.SymbolsByPriority.P1 | Select-Object -First 10) {
            $relativePath = $item.File.Replace($RootPath, "").TrimStart(@('\', '/'))
            $report += "- [ ] ``$relativePath`` - ``$($item.Symbol)``$(if ($item.Line -gt 0) { " (line $($item.Line))" })`n"
        }
        $report += "`n"
    }

    if ($Analysis.SymbolsByPriority.P2.Count -gt 0) {
        $report += "### P2 - High (Exported Functions)`n`n"
        foreach ($item in $Analysis.SymbolsByPriority.P2 | Select-Object -First 10) {
            $relativePath = $item.File.Replace($RootPath, "").TrimStart(@('\', '/'))
            $report += "- [ ] ``$relativePath`` - ``$($item.Symbol)``$(if ($item.Line -gt 0) { " (line $($item.Line))" })`n"
        }
        $report += "`n"
    }

    $report += @"
## Recommendations

1. **Start with P1 items** - $($Analysis.SymbolsByPriority.P1.Count) critical symbols need documentation
2. **Use `/AppDoc.comments`** - Generate inline JSDoc/docstring comments
3. **Consider `/AppDoc.api-docs`** - Create API documentation for endpoints
4. **Update README** - Run `/AppDoc.readme` for project overview
5. **Set coverage goal** - Target 80% minimum for public APIs

## Next Steps

- [ ] Run `/AppDoc.comments --file <path>` on P1 files
- [ ] Generate API documentation with `/AppDoc.api-docs`
- [ ] Update project README with `/AppDoc.readme`
- [ ] Review and customize generated documentation
- [ ] Commit documentation improvements

---

*Generated by AppDoc Framework*
"@

    return $report
}

# Main execution
try {
    $analysis = Analyze-CodebaseDocumentation
    $metadata = Get-ProjectMetadata -RootPath $RootPath

    if ($Json) {
        $result = @{
            Metadata = $metadata
            Analysis = $analysis
        }
        Write-JsonOutput -Data $result
    } else {
        # Generate markdown report
        $report = New-CoverageReport -Analysis $analysis -Metadata $metadata

        # Ensure output directory exists
        $outputDir = Split-Path $Output -Parent
        if ($outputDir -and -not (Test-Path $outputDir)) {
            New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
        }

        # Save report
        $report | Out-File -FilePath $Output -Encoding UTF8
        Write-Host "`n📄 Report saved to: $Output" -ForegroundColor Cyan
        Write-Host "`nTop Priority Items:" -ForegroundColor Yellow
        foreach ($item in $analysis.SymbolsByPriority.P1 | Select-Object -First 5) {
            $relativePath = $item.File.Replace($RootPath, "").TrimStart(@('\', '/'))
            Write-Host "  • $relativePath - $($item.Symbol)" -ForegroundColor White
        }
    }
} catch {
    Write-Error "Analysis failed: $_"
    exit 1
}

