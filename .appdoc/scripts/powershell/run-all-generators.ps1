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

Write-Host "All generators completed."
