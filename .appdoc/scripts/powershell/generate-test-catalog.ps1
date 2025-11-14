#
# generate-test-catalog.ps1
#
# Purpose: Scans the target codebase for test files and populates the test-catalog template
#          with discovered test suites, test cases, and coverage information.
#
# Usage: .\generate-test-catalog.ps1 -RootPath <target_codebase_path>
# Output: Populates docs/test-catalog.md from template
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

Write-Host "🧪 Generating Test Catalog..." -ForegroundColor Cyan

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Initialize template
$outputPath = Join-Path $RootPath "docs\test-catalog.md"
$initialized = Initialize-TemplateFile -TemplateName "test-catalog-template.md" -OutputPath $outputPath -RootPath $RootPath

if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Test Catalog" -Status "Scanning tests..." -PercentComplete 0

$tests = @()

# Scan for test files with expanded patterns
try {
    $testFiles = Get-ChildItem -Path $RootPath -Recurse -Include "*.test.js","*.test.ts","*.spec.js","*.spec.ts","*Test.cs","*Tests.cs","test_*.py" -ErrorAction Stop |
        Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\packages\\)' }

    Write-Host "  Found $($testFiles.Count) test files" -ForegroundColor Gray

    foreach ($file in $testFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        # JavaScript/TypeScript test frameworks (Jest, Mocha, Jasmine)
        $pattern = '(it|test|describe)\([' + "'" + '"' + ']([^' + "'" + '"' + ']+)[' + "'" + '"' + ']'
        $testCases = [regex]::Matches($content, $pattern)
        foreach ($match in $testCases) {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
            $tests += @{
                type = $match.Groups[1].Value
                name = $match.Groups[2].Value
                file = $file.Name
                framework = "JavaScript"
                source = "${relativePath}:$lineNumber"
            }
        }
        
        # C# test frameworks (xUnit, NUnit, MSTest)
        if ($file.Name -match "Tests?\.cs$") {
            $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
            
            # Match test attributes and their methods
            $testAttributes = @(
                @{ Pattern = '\[Fact\]'; Framework = 'xUnit' },
                @{ Pattern = '\[Theory\]'; Framework = 'xUnit' },
                @{ Pattern = '\[Test\]'; Framework = 'NUnit' },
                @{ Pattern = '\[TestMethod\]'; Framework = 'MSTest' },
                @{ Pattern = '\[TestCase'; Framework = 'NUnit' }
            )
            
            foreach ($attr in $testAttributes) {
                $matches = [regex]::Matches($content, $attr.Pattern)
                foreach ($match in $matches) {
                    # Find the method following this attribute
                    $afterAttr = $content.Substring($match.Index)
                    if ($afterAttr -match 'public\s+(?:async\s+)?(?:Task<?\w*>?\s+)?(?:void\s+)?(\w+)\s*\(') {
                        $methodName = $Matches[1]
                        $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                        
                        $testType = if ($attr.Pattern -match 'Theory|TestCase') { 'parameterized test' } else { 'test' }
                        
                        $tests += @{
                            type = $testType
                            name = $methodName
                            file = $file.Name
                            framework = "C# ($($attr.Framework))"
                            source = "${relativePath}:$lineNumber"
                        }
                    }
                }
            }
        } # End C# test detection
        
        # Python test frameworks (pytest, unittest)
        $pythonTests = [regex]::Matches($content, "def\s+(test_\w+)\(")
        $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
        foreach ($match in $pythonTests) {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $tests += @{
                type = "test"
                name = $match.Groups[1].Value
                file = $file.Name
                framework = "Python"
                source = "${relativePath}:$lineNumber"
            }
        }
    } # End foreach file
} catch {
    Write-Warning "Error scanning test files: $_"
}

Write-Progress -Activity "Generating Test Catalog" -Status "Populating template..." -PercentComplete 50

# Build test suites table
$testTablePlaceholder = "| Suite Name | Type | Purpose | Coverage Target | Key Scenarios | Execution Time |`r`n|------------|------|--------|----------------|--------------|----------------|`r`n`r`n_No test suites detected. Check for test files and testing framework configuration._"

$testSuitesContent = if ($tests.Count -gt 0) {
    $tableRows = $tests | Group-Object -Property file | ForEach-Object {
        $suiteName = $_.Name
        $type = ($_.Group | Select-Object -First 1).framework
        $testCount = $_.Count
        "| ``$suiteName`` | $type | Test suite | $testCount tests | Unit/Integration | N/A |"
    }
    ($tableRows -join "`r`n")
} else {
    ""
}

# Build test cases table
$testCasesPlaceholder = "| Case Name | Suite | Input | Expected Output | Description | Priority |`r`n|-----------|-------|------|----------------|-------------|----------|`r`n`r`n_No test cases detected. Refer to test files for individual test implementations._"

$testCasesContent = if ($tests.Count -gt 0) {
    # Limit to first 50 tests to avoid overwhelming output
    $tableRows = $tests | Select-Object -First 50 | ForEach-Object {
        $testName = $_.name
        $suiteName = $_.file
        # Convert method name to readable description (e.g., "TestUserCanLogin" -> "Test user can login")
        $description = $testName -creplace '([a-z])([A-Z])', '$1 $2' -replace 'test_', '' -replace '_', ' '
        "| ``$testName`` | ``$suiteName`` | N/A | N/A | $description | Medium |"
    }
    $note = if ($tests.Count -gt 50) { "`r`n`r`n_Showing first 50 of $($tests.Count) test cases. See test files for complete list._" } else { "" }
    ($tableRows -join "`r`n") + $note
} else {
    ""
}

# Update template
$content = Get-Content -Path $outputPath -Raw

# Update test suites section
if ($testSuitesContent) {
    $oldText = "| Suite Name | Type | Purpose | Coverage Target | Key Scenarios | Execution Time |`r`n|------------|------|--------|----------------|--------------|----------------|`r`n`r`n_No test suites detected. Check for test files and testing framework configuration._"
    $newText = "| Suite Name | Type | Purpose | Coverage Target | Key Scenarios | Execution Time |`r`n|------------|------|--------|----------------|--------------|----------------|`r`n" + $testSuitesContent
    $content = Update-TemplateSection -Content $content -PlaceholderText $oldText -NewContent $newText
}

# Update test cases section
if ($testCasesContent) {
    $oldText = "| Case Name | Suite | Input | Expected Output | Description | Priority |`r`n|-----------|-------|------|----------------|-------------|----------|`r`n`r`n_No test cases detected. Refer to test files for individual test implementations._"
    $newText = "| Case Name | Suite | Input | Expected Output | Description | Priority |`r`n|-----------|-------|------|----------------|-------------|----------|`r`n" + $testCasesContent
    $content = Update-TemplateSection -Content $content -PlaceholderText $oldText -NewContent $newText
}
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Progress -Activity "Generating Test Catalog" -Status "Complete" -PercentComplete 100
Write-Host "✅ Test catalog generated: $outputPath" -ForegroundColor Green
Write-Host "   Test cases found: $($tests.Count)" -ForegroundColor Gray
