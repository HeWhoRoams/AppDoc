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
        }
    }

    $testSuitesRows = @(
        $Tests |
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

    $visibleTests = @($Tests | Select-Object -First $MaxTestCases)
    $testCasesRows = @(
        $visibleTests | ForEach-Object {
            $testName = [string]$_.name
            $suiteName = [string]$_.file
            $description = $testName -creplace '([a-z])([A-Z])', '$1 $2' -replace 'test_', '' -replace '_', ' '
            "| ``$testName`` | ``$suiteName`` | N/A | N/A | $description | Medium |"
        }
    )
    $testCasesContent = "| Case Name | Suite | Input | Expected Output | Description | Priority |`n|-----------|-------|------|----------------|-------------|----------|`n" + ($testCasesRows -join "`n")
    if ($Tests.Count -gt $MaxTestCases) {
        $testCasesContent += "`n`n_Showing first $MaxTestCases of $($Tests.Count) test cases. See test files for complete list._"
    }

    return [ordered]@{
        testSuitesContent = $testSuitesContent
        testCasesContent = $testCasesContent
        testSuitesPlaceholder = $testSuitesPlaceholder
        testCasesPlaceholder = $testCasesPlaceholder
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
                    return ($m.Groups[1].Value + $sections.testSuitesContent + "`r`n")
                }
            )
        } else {
            Write-Verbose "Test Suites header or lookahead not found; appending test suites content to end."
            $updated += "`r`n`r`n" + $sections.testSuitesContent + "`r`n"
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
            Write-Verbose "Test Cases header or lookahead not found; appending test cases content to end."
            $updated += "`r`n`r`n" + $sections.testCasesContent + "`r`n"
        }
    }

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocTestCatalogMarkdown',
    'Update-AppDocTestCatalogContent'
)
