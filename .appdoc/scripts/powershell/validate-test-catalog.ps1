param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-TestValidationValue {
    param(
        [AllowNull()]
        [object]$Object,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [AllowNull()]
        [object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Get-TestSectionContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$SectionName
    )

    $pattern = '(?ims)^##\s+' + [regex]::Escape($SectionName) + '\s*$\r?\n(.*?)(?=^##\s+[^\r\n]+|\z)'
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return [string]$match.Groups[1].Value
    }
    return ""
}

function Get-TestSignalStrength {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
    if (Test-Path $scopeModule) {
        Import-Module $scopeModule -Force -ErrorAction SilentlyContinue
    }

    $candidateFiles = @()
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        $candidateFiles = @(
            Get-AppDocSourceFiles -RootPath $RootPath -Artifact "test-catalog" -Include @("*.cs","*.ts","*.js","*.py","*.java","*.go","*.feature")
        )
    }
    else {
        $candidateFiles = @(
            Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include @("*.cs","*.ts","*.js","*.py","*.java","*.go","*.feature") -ErrorAction SilentlyContinue
        )
    }

    $projectSignals = @()
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        $projectSignals = @(
            Get-AppDocSourceFiles -RootPath $RootPath -Artifact "test-catalog" -Include @("*.csproj","*.vbproj","*.fsproj") |
                Where-Object {
                    $p = [string]$_.FullName
                    $n = [string]$_.Name
                    $p -match '(?i)(?:^|[\\/])(?:test|tests|spec|specs)(?:[\\/]|$)' -or
                    $n -match '(?i)\.(tests?|specs?)\.(csproj|vbproj|fsproj)$'
                }
        )
    }
    else {
        $projectSignals = @(
            Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include @("*.csproj","*.vbproj","*.fsproj") -ErrorAction SilentlyContinue |
                Where-Object {
                    $p = [string]$_.FullName
                    $n = [string]$_.Name
                    $p -match '(?i)(?:^|[\\/])(?:test|tests|spec|specs)(?:[\\/]|$)' -or
                    $n -match '(?i)\.(tests?|specs?)\.(csproj|vbproj|fsproj)$'
                }
        )
    }

    $signalCount = 0
    $testLikeFileCount = 0
    # Limit the number of files scanned for test signals to avoid excessive memory/CPU usage
    $MaxFilesToScan = 450
    foreach ($file in @($candidateFiles | Select-Object -First $MaxFilesToScan)) {
        $path = [string]$file.FullName
        if ($path -notmatch '(?i)(?:^|[\\/])(?:test|tests|spec|specs|__tests__)(?:[\\/]|$)' -and
            $path -notmatch '(?i)(?:\.test|\.tests|\.spec|_test|_tests)\.') {
            continue
        }
        $testLikeFileCount++

        $raw = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $raw) { continue }

        $signalCount += ([regex]::Matches($raw, '(?i)\[(Fact|Theory|Test|TestMethod|TestCase)\]')).Count
        $signalCount += ([regex]::Matches($raw, '(?i)\b(describe|it|test)\s*\(')).Count
        $signalCount += ([regex]::Matches($raw, '(?i)\bdef\s+test_[A-Za-z0-9_]+\s*\(')).Count
        $signalCount += ([regex]::Matches($raw, '(?i)@Test\b')).Count
        $signalCount += ([regex]::Matches($raw, '(?im)^\s*Scenario:')).Count
        # Detect Go test functions: func TestXxx(t *testing.T)
        $signalCount += ([regex]::Matches($raw, '(?m)^\s*func\s+Test\w*\s*\(.*\*testing\.T\s*\)')).Count
    }

    return [ordered]@{
        signalCount = [int]$signalCount
        projectSignalCount = @($projectSignals).Count
        testLikeFileCount = [int]$testLikeFileCount
    }
}

function Get-TestGraphAlignedEntityCount {
    param(
        [AllowEmptyCollection()]
        [array]$Records = @()
    )

    # Evidence graph de-duplicates test entities by deterministic id seeded from test name.
    # Mirror that behavior so validator compares like-for-like counts.
    $uniqueNames = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($record in @($Records)) {
        if (-not $record) { continue }
        $kind = ([string](Get-TestValidationValue -Object $record -Name "kind" -Default "")).Trim().ToLowerInvariant()
        if ($kind -notin @("test-case","test-suite","test","suite","parameterized test")) { continue }

        $name = [string](Get-TestValidationValue -Object $record -Name "name" -Default "")
        if ([string]::IsNullOrWhiteSpace($name)) { $name = "unnamed-test" }
        [void]$uniqueNames.Add($name.Trim().ToLowerInvariant())
    }

    return [int]$uniqueNames.Count
}

Write-Progress -Activity "Validating Test Catalog" -Status "Checking catalog..." -PercentComplete 0

$catalogPath = Join-Path $RootPath "docs\test-catalog.md"
if (-not (Test-Path $catalogPath)) {
    Write-Error "Test catalog file not found at $catalogPath"
    exit 1
}

$content = Get-Content $catalogPath -Raw
if ($content -notmatch '(?im)^#\s+Test Catalog\b') {
    Write-Error "Invalid test catalog format (missing title)."
    exit 1
}

$issues = @()
$warnings = @()

$canonicalPath = Join-Path $RootPath "docs\evidence\metrics-canonical.json"
$canonicalTestCaseCount = $null
$canonicalTestSuiteCount = $null
if (Test-Path $canonicalPath) {
    try {
        $canonical = Get-Content $canonicalPath -Raw | ConvertFrom-Json -Depth 60
        if ($canonical.totals) {
            $canonicalTestCaseCount = [int](Get-TestValidationValue -Object $canonical.totals -Name "testCaseCount" -Default 0)
            $canonicalTestSuiteCount = [int](Get-TestValidationValue -Object $canonical.totals -Name "testSuiteCount" -Default 0)
        }
    }
    catch {
        $warnings += "canonical-metrics-unparseable"
    }
}

$evidencePath = Join-Path $RootPath "docs\evidence\test-catalog.evidence.json"
$testCaseCount = 0
$testSuiteCount = 0
$expectedGraphTestCaseCount = 0
if (Test-Path $evidencePath) {
    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json -Depth 120
        $records = @(
            Get-TestValidationValue -Object $evidence -Name "records" -Default @() |
                Where-Object { $_ }
        )
        $testCaseCount = @(
            $records |
                Where-Object { [string]$_.kind -in @("test-case","test","parameterized test") }
        ).Count
        $testSuiteCount = @(
            $records |
                Where-Object { [string]$_.kind -in @("test-suite","suite") }
        ).Count
        $expectedGraphTestCaseCount = Get-TestGraphAlignedEntityCount -Records $records

        $duplicateTestRows = @(
            $records |
                Where-Object { [string]$_.kind -in @("test-case","test","parameterized test") } |
                Group-Object -Property @{ Expression = { "{0}|{1}" -f [string]$_.source, [string]$_.name } } |
                Where-Object { $_.Count -gt 1 }
        )
        if ($duplicateTestRows.Count -gt 0) {
            $issues += ("duplicate-test-records:{0}" -f $duplicateTestRows.Count)
        }
    }
    catch {
        $issues += "test-evidence-unparseable"
    }
}
else {
    $issues += "test-evidence-missing"
}

$graphPath = Join-Path $RootPath "docs\evidence\evidence-graph.json"
$graphTestCaseCount = -1
if (Test-Path $graphPath) {
    try {
        $graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 120
        $metrics = Get-TestValidationValue -Object $graph -Name "metrics" -Default @{}
        $graphTestCaseCount = [int](Get-TestValidationValue -Object $metrics -Name "testCaseCount" -Default 0)
    }
    catch {
        $issues += "evidence-graph-unparseable"
    }
}
else {
    $warnings += "evidence-graph-missing"
}

if ($graphTestCaseCount -ge 0 -and $graphTestCaseCount -ne $expectedGraphTestCaseCount -and ($issues -notcontains 'test-evidence-unparseable') -and ($issues -notcontains 'test-evidence-missing')) {
    $issues += ("graph-evidence-testcase-mismatch:{0}/{1}" -f $graphTestCaseCount, $expectedGraphTestCaseCount)
}

$signals = Get-TestSignalStrength -RootPath $RootPath
$testSurfaceExpected = ($testCaseCount + $testSuiteCount) -gt 0 -or
    [int]$signals.signalCount -ge 3 -or
    [int]$signals.projectSignalCount -gt 0

$suiteSection = Get-TestSectionContent -Content $content -SectionName "Test Suites"
$casesSection = Get-TestSectionContent -Content $content -SectionName "Test Cases"
$suitePlaceholderPresent = ($suiteSection -match '(?i)_No test suites detected')
$casePlaceholderPresent = ($casesSection -match '(?i)_No test cases detected')

if (($testCaseCount + $testSuiteCount) -gt 0 -and ($suitePlaceholderPresent -or $casePlaceholderPresent)) {
    $issues += "placeholders-present-with-nonzero-test-evidence"
}

if ($null -ne $canonicalTestCaseCount -and $null -ne $canonicalTestSuiteCount) {
    if ($testCaseCount -ne $canonicalTestCaseCount -or $testSuiteCount -ne $canonicalTestSuiteCount) {
        $issues += ("cross-artifact-metric-drift:test-catalog:{0}/{1}-cases,{2}/{3}-suites" -f $testCaseCount, $canonicalTestCaseCount, $testSuiteCount, $canonicalTestSuiteCount)
    }
}

if (($testCaseCount + $testSuiteCount) -eq 0 -and $testSurfaceExpected) {
    $issues += ("test-surface-expected-but-empty:sig{0}/proj{1}" -f [int]$signals.signalCount, [int]$signals.projectSignalCount)
}

if (($testCaseCount + $testSuiteCount) -eq 0 -and -not $testSurfaceExpected) {
    if (-not ($suitePlaceholderPresent -and $casePlaceholderPresent)) {
        $warnings += "no-test-surface-but-missing-explicit-empty-notes"
    }
}

$coverageSection = Get-TestSectionContent -Content $content -SectionName "Test Coverage Metrics"
if ($testCaseCount -gt 0 -and $coverageSection -match '(?i)No tests were detected') {
    $issues += "coverage-metrics-contradiction"
}

Write-Progress -Activity "Validating Test Catalog" -Status "Complete" -PercentComplete 100

if ($issues.Count -gt 0) {
    Write-Host "Test catalog validation failed:" -ForegroundColor Red
    foreach ($issue in ($issues | Select-Object -Unique)) {
        Write-Host (" - {0}" -f $issue) -ForegroundColor Red
    }
    exit 1
}

foreach ($warning in ($warnings | Select-Object -Unique)) {
    Write-Warning ("[validate-test-catalog] {0}" -f $warning)
}

Write-Host ("Test catalog validated: {0} tests and {1} suites found" -f $testCaseCount, $testSuiteCount)
