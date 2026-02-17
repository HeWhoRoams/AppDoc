param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [switch]$IncludeAssessment,
    [Parameter(Mandatory=$false)]
    [string]$SampleDir,
    [Parameter(Mandatory=$false)]
    [switch]$SkipDiagrams,
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    [Parameter(Mandatory=$false)]
    [switch]$StrictValidation,
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,100)]
    [int]$QualityThreshold = 80,
    [Parameter(Mandatory=$false)]
    [string]$Profile = "default",
    [Parameter(Mandatory=$false)]
    [switch]$NoAI
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

.PARAMETER SkipDiagrams
    Skip C4 architecture diagram generation.

.PARAMETER DryRun
    Preview workflow execution without running generators or writing artifacts.

.PARAMETER StrictValidation
    Fail the workflow when validation scores are below the quality threshold.

.PARAMETER QualityThreshold
    Minimum quality score required per artifact when strict validation is enabled.

.PARAMETER Profile
    Documentation profile name or path used to configure generation behavior.

.PARAMETER NoAI
    Runs deterministic extraction/validation only and skips AI-oriented phases.

.EXAMPLE
    .\run-all-generators.ps1 -RootPath "c:\myproject"
    .\run-all-generators.ps1 -RootPath "c:\myproject" -IncludeAssessment -SampleDir "AppDoc.ai_samples"
    .\run-all-generators.ps1 -RootPath "c:\myproject" -SkipDiagrams
#>

$diagnosticsModule = Join-Path $PSScriptRoot "modules\AppDoc.Diagnostics.psm1"
$frameworkModule = Join-Path $PSScriptRoot "modules\AppDoc.FrameworkDetection.psm1"
$profilesModule = Join-Path $PSScriptRoot "modules\AppDoc.Profiles.psm1"
if (Test-Path $diagnosticsModule) {
    Import-Module $diagnosticsModule -Force -ErrorAction Stop
}
if (Test-Path $frameworkModule) {
    Import-Module $frameworkModule -Force -ErrorAction Stop
}
if (Test-Path $profilesModule) {
    Import-Module $profilesModule -Force -ErrorAction Stop
}

function Add-AppDocDiagnostic {
    param(
        [string]$Category,
        [string]$Severity,
        [string]$Message,
        [string]$Component = "orchestrator",
        [string]$FilePath = "",
        [hashtable]$Details = @{}
    )

    if (Get-Command Write-AppDocDiagnostic -ErrorAction SilentlyContinue) {
        [void](Write-AppDocDiagnostic -Category $Category -Severity $Severity -Message $Message -Component $Component -FilePath $FilePath -Details $Details)
    }
}

# Region: validation helpers
function Get-MarkdownSectionContent {
    param(
        [string]$Content,
        [string]$Section
    )

    if (-not $Content) { return "" }
    $pattern = "(?ms)^##\s+" + [regex]::Escape($Section) + "\s*$\r?\n(.*?)(?=^##\s+[^\r\n]+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return $match.Groups[1].Value.Trim()
    }
    return ""
}

function Get-MarkdownDataRowCount {
    param(
        [string]$SectionContent
    )

    if (-not $SectionContent) { return 0 }

    $rows = 0
    $headerRows = 0
    foreach ($line in ($SectionContent -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\|' -and $trimmed -notmatch '^\|\s*-') {
            $rows++
            if ($trimmed -match '^\|\s*Name\s*\|\s*Path\s*\|\s*Method\s*\|' -or
                $trimmed -match '^\|\s*Model Name\s*\|' -or
                $trimmed -match '^\|\s*Step\s*\|\s*Command\s*\|' -or
                $trimmed -match '^\|\s*Dependency\s*\|\s*Version\s*\|') {
                $headerRows++
            }
        }
    }

    if ($rows -gt 0) {
        if ($headerRows -gt 0) {
            return [Math]::Max(0, $rows - $headerRows)
        }
        return [Math]::Max(0, $rows - 1)
    }

    return 0
}

function Get-DocSpecificIssues {
    param(
        [string]$DocType,
        [string]$Content
    )

    $issues = @()

    switch ($DocType) {
        "API Inventory" {
            $section = Get-MarkdownSectionContent -Content $Content -Section "API Endpoints"
            if (-not $section) {
                $issues += "API Endpoints section missing"
            }
            elseif ($section -match '_No API endpoints detected') {
                $issues += "API Endpoints section still contains placeholder text"
            }
            elseif ((Get-MarkdownDataRowCount -SectionContent $section) -eq 0) {
                $issues += "API Endpoints table has no populated rows"
            }
        }
        "Data Model" {
            $section = Get-MarkdownSectionContent -Content $Content -Section "Data Models"
            if (-not $section) {
                $issues += "Data Models section missing"
            }
            elseif ($section -match '_No data models detected') {
                $issues += "Data Models section still contains placeholder text"
            }
            elseif ((Get-MarkdownDataRowCount -SectionContent $section) -eq 0) {
                $issues += "Data Models table has no populated rows"
            }
        }
        "Config Catalog" {
            $configSection = Get-MarkdownSectionContent -Content $Content -Section "Configuration Options"
            if (-not $configSection) {
                $issues += "Configuration Options section missing"
            }
            elseif ($configSection -match '_No configuration options detected') {
                $issues += "Configuration Options placeholder text remains"
            }
            elseif ((Get-MarkdownDataRowCount -SectionContent $configSection) -eq 0) {
                $issues += "Configuration Options table has no populated rows"
            }

            $envSection = Get-MarkdownSectionContent -Content $Content -Section "Environment Variables"
            if ($envSection) {
                if ($envSection -match '_No environment variables detected') {
                    $issues += "Environment Variables placeholder text remains"
                }
                elseif ((Get-MarkdownDataRowCount -SectionContent $envSection) -eq 0) {
                    $issues += "Environment Variables table has no populated rows"
                }
            }
        }
        "Build Cookbook" {
            $buildSteps = Get-MarkdownSectionContent -Content $Content -Section "Build Steps"
            if (-not $buildSteps -or $buildSteps -match '_No build steps detected') {
                $issues += "Build Steps section missing actionable commands"
            }
            elseif ((Get-MarkdownDataRowCount -SectionContent $buildSteps) -eq 0) {
                $issues += "Build Steps table has no populated rows"
            }

            $depsSection = Get-MarkdownSectionContent -Content $Content -Section "Dependencies"
            if (-not $depsSection -or $depsSection -match '_No build dependencies detected') {
                $issues += "Build dependencies not documented"
            }
        }
        "Test Catalog" {
            $suiteSection = Get-MarkdownSectionContent -Content $Content -Section "Test Suites"
            if (-not $suiteSection -or $suiteSection -match '_No test suites detected') {
                $issues += "Test Suites section missing or empty"
            }
            elseif ((Get-MarkdownDataRowCount -SectionContent $suiteSection) -eq 0) {
                $issues += "Test Suites table has no populated rows"
            }

            $casesSection = Get-MarkdownSectionContent -Content $Content -Section "Test Cases"
            if ($casesSection) {
                if ($casesSection -match '_No test cases detected') {
                    $issues += "Test Cases placeholder text remains"
                }
                elseif ((Get-MarkdownDataRowCount -SectionContent $casesSection) -eq 0) {
                    $issues += "Test Cases table has no populated rows"
                }
            }
        }
        "Debt Register" {
            $debtSection = Get-MarkdownSectionContent -Content $Content -Section "Debt Items"
            if (-not $debtSection -or $debtSection -match '_No technical debt items detected') {
                $issues += "Debt Items section missing actionable entries"
            }
            elseif ((Get-MarkdownDataRowCount -SectionContent $debtSection) -eq 0) {
                $issues += "Debt Items table has no populated rows"
            }
        }
        "Dependencies Catalog" {
            $summarySection = Get-MarkdownSectionContent -Content $Content -Section "Dependency Summary"
            if (-not $summarySection -or $summarySection -match '_No dependencies detected') {
                $issues += "Dependency summary not populated"
            }
            elseif ((Get-MarkdownDataRowCount -SectionContent $summarySection) -eq 0) {
                $issues += "Dependency summary table has no populated rows"
            }
        }
    }

    return $issues
}

# Validation function to detect placeholder content and assess quality
function Test-GeneratedDoc {
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
        $patternMatches = [regex]::Matches($content, $pattern.Pattern, 'IgnoreCase')
        if ($patternMatches.Count -gt 0) {
            $placeholders += "$($patternMatches.Count)x $($pattern.Description)"
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

    # Doc-type specific structural checks
    $issues += Get-DocSpecificIssues -DocType $DocType -Content $content
    
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

Write-Host "Running all documentation generators..."

$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) {
    New-Item -Path $docsPath -ItemType Directory -Force | Out-Null
}

if (Get-Command Initialize-AppDocDiagnostics -ErrorAction SilentlyContinue) {
    Initialize-AppDocDiagnostics -RootPath $RootPath -OutputPath $docsPath -Reset
}

$activeProfile = $null
if (Get-Command Get-AppDocProfile -ErrorAction SilentlyContinue) {
    $activeProfile = Get-AppDocProfile -RootPath $RootPath -Profile $Profile
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Loaded documentation profile" -Component "orchestrator" -Details @{ profile = $activeProfile.profile }
}

$detectedFrameworks = @()
if (Get-Command Get-AppDocDetectedFrameworks -ErrorAction SilentlyContinue) {
    $detectedFrameworks = Get-AppDocDetectedFrameworks -RootPath $RootPath
    if ($detectedFrameworks.Count -eq 0) {
        Add-AppDocDiagnostic -Category "UNSUPPORTED_FRAMEWORK" -Severity "Warning" -Message "No supported framework signatures detected" -Component "analysis"
    }
    else {
        Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Frameworks detected" -Component "analysis" -Details @{ frameworks = @($detectedFrameworks.framework) }
        $frameworkReportPath = Join-Path $docsPath "framework-detection.json"
        $detectedFrameworks | ConvertTo-Json -Depth 10 | Out-File -FilePath $frameworkReportPath -Encoding UTF8
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Warning" -Message "PowerShell 7+ is recommended for AppDoc generators" -Details @{ version = $PSVersionTable.PSVersion.ToString() }
}

$pipelinePhases = @(
    @{
        Name = "Analysis"
        Scripts = @(
            "analyze-repository.ps1",
            "generate-dependency-graph.ps1",
            "extract-config.ps1"
        )
    },
    @{
        Name = "Generation"
        Scripts = @(
            "generate-overview.ps1",
            "generate-api-inventory.ps1",
            "generate-data-model.ps1",
            "generate-config-catalog.ps1",
            "generate-build-cookbook.ps1",
            "generate-test-catalog.ps1",
            "generate-debt-register.ps1",
            "generate-dependencies-catalog.ps1",
            "generate-task-guides.ps1",
            "generate-start-here.ps1",
            "generate-docs-index.ps1"
        )
    }
)

foreach ($phase in $pipelinePhases) {
    Write-Host "`n[$($phase.Name)]" -ForegroundColor Cyan
    foreach ($script in $phase.Scripts) {
        $scriptPath = Join-Path $PSScriptRoot $script
        if (-not (Test-Path $scriptPath)) {
            Add-AppDocDiagnostic -Category "IO_ERROR" -Severity "Warning" -Message "Script not found: $script" -Component $phase.Name -FilePath $scriptPath
            Write-Warning "Script $script not found"
            continue
        }

        if ($DryRun) {
            Write-Host "[DryRun] Would execute $script" -ForegroundColor Gray
            Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Dry run skipped script execution" -Component $phase.Name -FilePath $scriptPath -Details @{ script = $script }
            continue
        }

        Write-Host "Running $script..."
        try {
            & $scriptPath -RootPath $RootPath
        }
        catch {
            Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to run script: $script" -Component $phase.Name -FilePath $scriptPath -Details @{ exception = $_.Exception.Message }
            Write-Warning "Failed to run $script`: $_"
        }
    }
}

# Generate C4 architecture diagrams in Mermaid (unless skipped)
if (-not $SkipDiagrams) {
    Write-Host "Generating C4 Mermaid architecture diagrams..."
    $c4Script = Join-Path $PSScriptRoot "generate-c4-mermaid-diagrams.ps1"
    if (Test-Path $c4Script) {
        if ($DryRun) {
            Write-Host "[DryRun] Would execute generate-c4-mermaid-diagrams.ps1" -ForegroundColor Gray
            Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Dry run skipped Mermaid C4 diagram generation" -Component "Generation" -FilePath $c4Script
        }
        else {
            try {
                & $c4Script -CodebasePath $RootPath -OutputPath $docsPath -DiagramLevels All
            } catch {
                Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to generate Mermaid C4 diagrams" -Component "Generation" -FilePath $c4Script -Details @{ exception = $_.Exception.Message }
                Write-Warning "Failed to generate Mermaid C4 diagrams: $_"
            }
        }
    } else {
        Add-AppDocDiagnostic -Category "IO_ERROR" -Severity "Info" -Message "Mermaid C4 diagram generator not found (optional feature)" -Component "Generation" -FilePath $c4Script
        Write-Verbose "Mermaid C4 diagram generator not found (optional feature)"
    }
} else {
    Write-Host "Skipping Mermaid C4 diagram generation (SkipDiagrams flag set)" -ForegroundColor Gray
}

# Run assessment if requested
if ($IncludeAssessment) {
    if ($NoAI) {
        Write-Host "Skipping assessment phase in -NoAI mode." -ForegroundColor Gray
        Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Assessment phase skipped because NoAI mode is enabled" -Component "Assessment"
    }
    else {
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
            if ($DryRun) {
                Write-Host "[DryRun] Would execute assessment script $script" -ForegroundColor Gray
                Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Dry run skipped assessment script" -Component "Assessment" -FilePath $scriptPath -Details @{ script = $script }
                continue
            }

            try {
                switch ($script) {
                    "catalog-samples.ps1" { & $scriptPath -SampleDir $SampleDir }
                    "analyze-capability-gaps.ps1" { & $scriptPath -SampleDir $SampleDir -CurrentDocsDir $docsPath }
                    "generate-improvements.ps1" { & $scriptPath }
                    "calculate-quality-metrics.ps1" { & $scriptPath }
                    "synthesize-assessment-report.ps1" { & $scriptPath }
                }
            } catch {
                Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to run assessment script: $script" -Component "Assessment" -FilePath $scriptPath -Details @{ exception = $_.Exception.Message }
                Write-Warning "Failed to run assessment script $script`: $_"
            }
        } else {
            Add-AppDocDiagnostic -Category "IO_ERROR" -Severity "Warning" -Message "Assessment script not found: $script" -Component "Assessment" -FilePath $scriptPath
            Write-Warning "Assessment script $script not found"
        }
    }
    }
}

if ($DryRun) {
    Write-Host "`nDry-run completed. No generation or validation output files were written." -ForegroundColor Yellow
    if (Get-Command Get-AppDocDiagnosticsSummary -ErrorAction SilentlyContinue) {
        $dryRunSummary = Get-AppDocDiagnosticsSummary
        Write-Host "Diagnostics events captured: $($dryRunSummary.total)" -ForegroundColor Gray
    }
    exit 0
}

$remediationScriptPath = Join-Path $PSScriptRoot "remediate-generated-docs.ps1"
if (Test-Path $remediationScriptPath) {
    Write-Host "`n[Remediation]" -ForegroundColor Cyan
    Write-Host "Running remediate-generated-docs.ps1..."
    try {
        & $remediationScriptPath -RootPath $RootPath | Out-Null
        Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Post-generation remediation completed" -Component "Remediation" -FilePath $remediationScriptPath
    }
    catch {
        Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Post-generation remediation failed" -Component "Remediation" -FilePath $remediationScriptPath -Details @{ exception = $_.Exception.Message }
        Write-Warning "Post-generation remediation failed: $($_.Exception.Message)"
    }
}
else {
    Add-AppDocDiagnostic -Category "IO_ERROR" -Severity "Info" -Message "Remediation script not found; skipping post-generation cleanup" -Component "Remediation" -FilePath $remediationScriptPath
}

Write-Host "`n=== Documentation Quality Report ===" -ForegroundColor Cyan

# Validate all generated documents
$validationResults = @()

$documents = @(
    @{ File = "start-here.md"; Type = "Start Here" }
    @{ File = "overview.md"; Type = "Overview" }
    @{ File = "api-inventory.md"; Type = "API Inventory" }
    @{ File = "data-model.md"; Type = "Data Model" }
    @{ File = "config-catalog.md"; Type = "Config Catalog" }
    @{ File = "build-cookbook.md"; Type = "Build Cookbook" }
    @{ File = "test-catalog.md"; Type = "Test Catalog" }
    @{ File = "debt-register.md"; Type = "Debt Register" }
    @{ File = "dependencies-catalog.md"; Type = "Dependencies Catalog" }
    @{ File = "task-guides.md"; Type = "Task Guides" }
)

foreach ($doc in $documents) {
    $filePath = Join-Path $docsPath $doc.File
    $result = Test-GeneratedDoc -FilePath $filePath -DocType $doc.Type -RootPath $RootPath
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

$structuredValidationPath = Join-Path $PSScriptRoot "validate-documentation.ps1"
$structuredValidationResult = $null
if (Test-Path $structuredValidationPath) {
    try {
        $structuredValidationJson = if ($StrictValidation) {
            & $structuredValidationPath -RootPath $RootPath -Strict -Threshold $QualityThreshold -Json
        }
        else {
            & $structuredValidationPath -RootPath $RootPath -Threshold $QualityThreshold -Json
        }
        if ($structuredValidationJson) {
            $structuredValidationResult = $structuredValidationJson | ConvertFrom-Json
        }
        Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Structured validation completed" -Component "Validation"
    }
    catch {
        Add-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Structured validation reported issues" -Component "Validation" -Details @{ exception = $_.Exception.Message }
    }
}

$validationGate = $null
if (Get-Command Test-AppDocValidationGate -ErrorAction SilentlyContinue) {
    $validationGate = Test-AppDocValidationGate -ValidationResults $validationResults -QualityThreshold $QualityThreshold -Strict:$StrictValidation

    if ($structuredValidationResult) {
        $scorePass = ([double]$structuredValidationResult.overallScore -ge [double]$QualityThreshold)
        $policyPass = $true
        if ($null -ne $structuredValidationResult.policyGates -and $null -ne $structuredValidationResult.policyGates.passed) {
            $policyPass = [bool]$structuredValidationResult.policyGates.passed
        }
        $structuredPass = ($scorePass -and $policyPass)
        $validationGate = [ordered]@{
            passed = $structuredPass
            reason = if ($structuredPass) { "Structured validation gate passed" } else { "Structured validation gate failed (score and/or policy gates)" }
            averageScore = [double]$structuredValidationResult.overallScore
            belowThreshold = if ($structuredPass) { 0 } else { 1 }
            strict = $StrictValidation.IsPresent
            qualityThreshold = $QualityThreshold
            evaluatedDocuments = if ($structuredValidationResult.validators) { @($structuredValidationResult.validators).Count } else { 0 }
        }
    }

    Write-Host "`nValidation Gate:" -ForegroundColor Cyan
    Write-Host "  Mode: $(if ($StrictValidation) { 'Strict' } else { 'Soft' })" -ForegroundColor White
    Write-Host "  Threshold: $QualityThreshold" -ForegroundColor White
    Write-Host "  Average Score: $($validationGate.averageScore)%" -ForegroundColor White
    Write-Host "  Below Threshold: $($validationGate.belowThreshold)" -ForegroundColor White

    if (-not $validationGate.passed -and $StrictValidation) {
        Add-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Error" -Message "Strict validation gate failed" -Component "Validation" -Details @{ threshold = $QualityThreshold; averageScore = $validationGate.averageScore; belowThreshold = $validationGate.belowThreshold }
    }
    elseif (-not $validationGate.passed) {
        Add-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Validation is below threshold in soft mode" -Component "Validation" -Details @{ threshold = $QualityThreshold; averageScore = $validationGate.averageScore; belowThreshold = $validationGate.belowThreshold }
    }
}

if (Get-Command Export-AppDocDiagnostics -ErrorAction SilentlyContinue) {
    $diagnosticsPath = Join-Path $docsPath "diagnostics-report.json"
    $metadata = @{
        strictValidation = $StrictValidation.IsPresent
        qualityThreshold = $QualityThreshold
        validationGate = $validationGate
        profile = if ($activeProfile) { $activeProfile.profile } else { $Profile }
        noAI = $NoAI.IsPresent
        frameworks = @($detectedFrameworks.framework)
    }
    Export-AppDocDiagnostics -Path $diagnosticsPath -AdditionalData $metadata | Out-Null
    Write-Host "📄 Diagnostics report saved: $diagnosticsPath" -ForegroundColor Cyan
}

# Exit with warning if majority are low quality
if ($lowQuality -gt ($totalDocs / 2)) {
    Write-Host "`n⚠️  WARNING: More than 50% of documentation is LOW quality!" -ForegroundColor Red
    Write-Host "   Consider running AppDoc enhancement workflow or manual review." -ForegroundColor Yellow
}

Write-Host "`nAll generators completed." -ForegroundColor Green

if ($StrictValidation -and $validationGate -and -not $validationGate.passed) {
    exit 1
}
