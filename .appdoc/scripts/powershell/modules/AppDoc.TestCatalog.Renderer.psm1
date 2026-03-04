function Get-AppDocTestCatalogMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Tests,
        [int]$MaxTestCases = 50
    )

    $testSuitesPlaceholder = @"
| Suite Name | Type | Purpose | Coverage Target | Key Scenarios | Execution Time |
|------------|------|--------|----------------|--------------|----------------|

_No test suites detected. Check for test files and testing framework configuration._
"@

    $testCasesPlaceholder = @"
| Case Name | Suite | Input | Expected Output | Description | Priority |
|-----------|-------|------|----------------|-------------|----------|

_No test cases detected. Refer to test files for individual test implementations._
"@

    if (-not $Tests -or $Tests.Count -eq 0) {
        return [ordered]@{
            testSuitesContent = $testSuitesPlaceholder
            testCasesContent = $testCasesPlaceholder
            testSuitesPlaceholder = $testSuitesPlaceholder
            testCasesPlaceholder = $testCasesPlaceholder
            dedupedTestCount = 0
        }
    }

    $dedupedTests = @(
        $Tests |
            Group-Object -Property @{ Expression = { "{0}|{1}" -f [string]$_.file, [string]$_.name } } |
            ForEach-Object { $_.Group | Select-Object -First 1 }
    )

    $testSuitesRows = @(
        $dedupedTests |
            Group-Object -Property file |
            Sort-Object Name |
            ForEach-Object {
                $suiteName = [string]$_.Name
                $type = [string](($_.Group | Select-Object -First 1).framework)
                $testCount = [int]$_.Count
                "| ``$suiteName`` | $type | Test suite | $testCount tests | Unit/Integration | N/A |"
            }
    )
    $testSuitesContent = "| Suite Name | Type | Purpose | Coverage Target | Key Scenarios | Execution Time |`n|------------|------|--------|----------------|--------------|----------------|`n" + ($testSuitesRows -join "`n")

    $visibleTests = @($dedupedTests | Select-Object -First $MaxTestCases)
    $testCasesRows = @(
        $visibleTests | ForEach-Object {
            $testName = [string]$_.name
            $suiteName = [string]$_.file
            $description = $testName -creplace '([a-z])([A-Z])', '$1 $2' -replace 'test_', '' -replace '_', ' '
            $priority = if ($suiteName -match '(?i)integration|e2e|critical|smoke') { "High" } else { "Medium" }
            "| ``$testName`` | ``$suiteName`` | N/A | N/A | $description | $priority |"
        }
    )
    $testCasesContent = "| Case Name | Suite | Input | Expected Output | Description | Priority |`n|-----------|-------|------|----------------|-------------|----------|`n" + ($testCasesRows -join "`n")
    if ($dedupedTests.Count -gt $MaxTestCases) {
        $testCasesContent += "`n`n_Showing first $MaxTestCases of $($dedupedTests.Count) de-duplicated test cases. See test files for complete list._"
    }

    return [ordered]@{
        testSuitesContent = $testSuitesContent
        testCasesContent = $testCasesContent
        testSuitesPlaceholder = $testSuitesPlaceholder
        testCasesPlaceholder = $testCasesPlaceholder
        dedupedTestCount = $dedupedTests.Count
    }
}

function Update-AppDocTestCatalogContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Tests,
        [int]$MaxTestCases = 50
    )

    $sections = Get-AppDocTestCatalogMarkdown -Tests $Tests -MaxTestCases $MaxTestCases
    $updated = $Content
    $testCount = $sections.dedupedTestCount
    $suiteCount = if ($testCount -gt 0) { @($Tests | Group-Object -Property file).Count } else { 0 }


    # Only perform placeholder replacement if the section headers are missing
    $hasTestSuitesHeader = $updated -match '##\s+Test Suites'
    $hasTestCasesHeader = $updated -match '##\s+Test Cases'

    $testSuitesInserted = $false
    $testCasesInserted = $false
    if (-not $hasTestSuitesHeader) {
        if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
            $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.testSuitesPlaceholder -NewContent $sections.testSuitesContent
        } else {
            $updated = $updated.Replace($sections.testSuitesPlaceholder, $sections.testSuitesContent)
        }
        $testSuitesInserted = $true
    }
    if (-not $hasTestCasesHeader) {
        if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
            $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.testCasesPlaceholder -NewContent $sections.testCasesContent
        } else {
            $updated = $updated.Replace($sections.testCasesPlaceholder, $sections.testCasesContent)
        }
        $testCasesInserted = $true
    }


    $testSuitesPattern = '(?s)(##\s+Test Suites\s*\r?\n\r?\n).*?(?=\r?\n##\s+Test Coverage Metrics\b)'
    if ($hasTestSuitesHeader -and -not $testSuitesInserted) {
        if ([regex]::IsMatch($updated, $testSuitesPattern)) {
            $updated = [regex]::Replace(
                $updated,
                $testSuitesPattern,
                [System.Text.RegularExpressions.MatchEvaluator]{
                    param($m)
                    $source = $m.Value
                    $lineEnding = ($source -match "\r\n") ? "`r`n" : "`n"
                    return ($m.Groups[1].Value + $sections.testSuitesContent + $lineEnding)
                }
            )
        } else {
            Write-Verbose "Test Coverage Metrics section not found after Test Suites header; content not updated to avoid duplication."
        }
    }

    $testCasesPattern = '(?s)(##\s+Test Cases\s*\r?\n\r?\n).*?(?=\r?\n##\s+Test Maintenance\b)'
    if ($hasTestCasesHeader -and -not $testCasesInserted) {
        if ([regex]::IsMatch($updated, $testCasesPattern)) {
            $updated = [regex]::Replace(
                $updated,
                $testCasesPattern,
                [System.Text.RegularExpressions.MatchEvaluator]{
                    param($m)
                    return ($m.Groups[1].Value + $sections.testCasesContent + "`r`n")
                }
            )
        } else {
            if ((-not ($updated -match '##\s+Test Maintenance')) -and (-not [string]::IsNullOrEmpty($sections.testCasesContent)) -and (-not ($updated -match [regex]::Escape($sections.testCasesContent)))) {
                Write-Verbose "Test Cases header or lookahead not found; appending test cases content before '## Test Maintenance' section."
                $updated += "`r`n`r`n" + $sections.testCasesContent + "`r`n"
            } else {
                Write-Verbose "Test Cases content or '## Test Maintenance' section already present; skipping fallback append."
            }
        }
    }

    $coverageSummary = if ($testCount -gt 0) {
        "Detected $testCount de-duplicated test cases across $suiteCount suites in this scan. Line/branch coverage percentages are not computed here; use CI coverage tooling for quantitative baselines."
    } else {
        "No tests were detected in this scan. Validate test project scope and framework discovery settings."
    }
    $exampleRun = if ($testCount -gt 0) {
        'Run `dotnet test` at solution scope for baseline verification, then rerun only impacted suites while iterating on failures. Capture failing test names and stack traces as part of remediation records.'
    } else {
        'No runnable test commands were inferred from discovered evidence. Verify test projects and build scripts before relying on this artifact.'
    }

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Overview\s*\r?\n\r?\n).*?(?=\r?\n##\s+Test Environment Setup\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Test metadata is extracted from discovered test files and method signatures. Use this catalog to understand suite intent and identify where coverage is concentrated." + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Test Environment Setup\s*\r?\n\r?\n).*?(?=\r?\n##\s+Test Suites\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "No dedicated environment bootstrap script was extracted. Use the build and restore commands in [Build Cookbook](build-cookbook.md), then execute targeted suites from this catalog." + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Test Coverage Metrics\s*\r?\n\r?\n).*?(?=\r?\n##\s+Test Cases\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $coverageSummary + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Test Maintenance\s*\r?\n\r?\n).*?(?=\r?\n##\s+Example Test Runs\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Prioritize maintenance for suites tied to frequently changed business rules and high-churn components. Keep suite names and test intent aligned with current behavior to preserve debugging value." + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Example Test Runs\s*\r?\n\r?\n).*?(?=(\r?\n##\s+)|\z)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $exampleRun + "`r`n")
        }
    )

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocTestCatalogMarkdown',
    'Update-AppDocTestCatalogContent'
)
