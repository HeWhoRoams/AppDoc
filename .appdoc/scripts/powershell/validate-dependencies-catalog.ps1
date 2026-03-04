param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-DependencyValidationValue {
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

function Get-DependencySectionContent {
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

function Get-DependencyTableDataRowCount {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SectionContent
    )

    $rows = @(
        ($SectionContent -split "`r?`n") |
            Where-Object {
                $line = ([string]$_).Trim()
                $line -match '^\|' -and $line -notmatch '^\|\s*[-: ]+\|'
            }
    )

    if ($rows.Count -le 1) { return 0 }
    return ($rows.Count - 1)
}

function Get-DependencySignalStrength {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
    if (Test-Path $scopeModule) {
        Import-Module $scopeModule -Force -ErrorAction SilentlyContinue
    }

    $patterns = @(
        "*.csproj",
        "*.vbproj",
        "packages.config",
        "*.nuspec",
        "package.json",
        "package-lock.json",
        "pnpm-lock.yaml",
        "yarn.lock",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
        "requirements.txt",
        "Pipfile",
        "pyproject.toml",
        "poetry.lock",
        "go.mod",
        "Cargo.toml"
    )

    $files = @()
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        $files = @(
            Get-AppDocSourceFiles -RootPath $RootPath -Artifact "dependencies-catalog" -Include $patterns
        )
    }
    else {
        $files = @(
            Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include $patterns -ErrorAction SilentlyContinue
        )
    }

    return [ordered]@{
        signalCount = @($files).Count
    }
}

function Get-DependencyGraphAlignedEntityCount {
    param(
        [AllowEmptyCollection()]
        [array]$Records = @()
    )

    # Evidence graph de-duplicates dependency entities by deterministic id seeded from dependency name.
    $uniqueNames = New-Object 'System.Collections.Generic.HashSet[string]'
    $recordIndex = 0
    foreach ($record in @($Records)) {
        if (-not $record) { $recordIndex++; continue }
        $kind = ([string](Get-DependencyValidationValue -Object $record -Name "kind" -Default "")).Trim().ToLowerInvariant()
        if ($kind -ne "dependency") { $recordIndex++; continue }

        $name = [string](Get-DependencyValidationValue -Object $record -Name "name" -Default "")
        if ([string]::IsNullOrWhiteSpace($name)) {
            $name = "unknown-dependency-$recordIndex"
            Write-Warning "Dependency record at index $recordIndex is missing a name. Assigned placeholder: $name."
        }
        [void]$uniqueNames.Add($name.Trim().ToLowerInvariant())
        $recordIndex++
    }

    return [int]$uniqueNames.Count
}

Write-Progress -Activity "Validating Dependencies Catalog" -Status "Checking catalog..." -PercentComplete 0

$catalogPath = Join-Path $RootPath "docs" "dependencies-catalog.md"
if (-not (Test-Path $catalogPath)) {
    Write-Error "Dependencies catalog file not found at $catalogPath"
    exit 1
}

$content = Get-Content $catalogPath -Raw
if ($content -notmatch '(?im)^#\s+Dependencies Catalog\b') {
    Write-Error "Invalid dependencies catalog format (missing title)."
    exit 1
}

$issues = @()
$warnings = @()

$canonicalPath = Join-Path (Join-Path (Join-Path $RootPath "docs") "evidence") "metrics-canonical.json"
$canonicalDependencyCount = $null
if (Test-Path $canonicalPath) {
    try {
        $canonical = Get-Content $canonicalPath -Raw | ConvertFrom-Json -Depth 120
        if ($canonical.totals) {
            $canonicalDependencyCount = [int](Get-DependencyValidationValue -Object $canonical.totals -Name "dependencyCount" -Default 0)
        }
    }
    catch {
        $warnings += "canonical-metrics-unparseable"
    }
}

$evidencePath = Join-Path $RootPath "docs" "evidence" "dependencies-catalog.evidence.json"
$dependencyCount = 0
$expectedGraphDependencyCount = 0
if (Test-Path $evidencePath) {
    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json -Depth 120
        $records = @(
            Get-DependencyValidationValue -Object $evidence -Name "records" -Default @() |
                Where-Object { $_ -and [string]$_.kind -eq "dependency" }
        )
        $dependencyCount = $records.Count
        $expectedGraphDependencyCount = Get-DependencyGraphAlignedEntityCount -Records $records

        $duplicateDependencies = @(
            $records |
                Group-Object -Property @{ Expression = { "{0}|{1}|{2}" -f [string]$_.name, [string]$_.source, [string](Get-DependencyValidationValue -Object $_.metadata -Name "version" -Default "") } } |
                Where-Object { $_.Count -gt 1 }
        )
        $totalExcessDuplicates = ($duplicateDependencies | Measure-Object -Property Count -Sum).Sum - $duplicateDependencies.Count
        if ($totalExcessDuplicates -gt 0) {
            $issues += ("duplicate-dependency-records:{0}" -f $totalExcessDuplicates)
        }
    }
    catch {
        $issues += "dependencies-evidence-unparseable"
    }
}
else {
    $issues += "dependencies-evidence-missing"
}

$graphPath = Join-Path $RootPath "docs" "evidence" "evidence-graph.json"
$graphDependencyCount = -1
if (Test-Path $graphPath) {
    try {
        $graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 120
        $metrics = Get-DependencyValidationValue -Object $graph -Name "metrics" -Default @{}
        $graphDependencyCount = [int](Get-DependencyValidationValue -Object $metrics -Name "dependencyCount" -Default 0)
    }
    catch {
        $issues += "evidence-graph-unparseable"
    }
}
else {
    $warnings += "evidence-graph-missing"
}

if ($graphDependencyCount -ge 0 -and $graphDependencyCount -ne $expectedGraphDependencyCount) {
    $issues += ("graph-evidence-dependency-mismatch:{0}/{1}" -f $graphDependencyCount, $expectedGraphDependencyCount)
}

if ($null -ne $canonicalDependencyCount -and $dependencyCount -ne $canonicalDependencyCount) {
    $issues += ("cross-artifact-metric-drift:dependencies-catalog:{0}/{1}" -f $dependencyCount, $canonicalDependencyCount)
}

$signals = Get-DependencySignalStrength -RootPath $RootPath
$dependencySurfaceExpected = ($dependencyCount -gt 0 -or [int]$signals.signalCount -gt 0)

$summarySection = Get-DependencySectionContent -Content $content -SectionName "Dependency Summary"
$summaryEmptyNote = ($summarySection -match '(?i)Dependency records in scope:\s*none in this scan')
$summaryTableRows = Get-DependencyTableDataRowCount -SectionContent $summarySection

if ($dependencyCount -gt 0 -and $summaryEmptyNote) {
    $issues += "placeholder-present-with-nonzero-dependency-evidence"
}
if ($dependencyCount -gt 0 -and $summaryTableRows -eq 0) {
    $issues += "dependency-summary-table-empty"
}
if ($dependencyCount -eq 0 -and $dependencySurfaceExpected) {
    $warnings += ("dependency-surface-expected-but-empty:sig{0}" -f [int]$signals.signalCount)
}
if ($dependencyCount -eq 0 -and -not $dependencySurfaceExpected -and -not $summaryEmptyNote) {
    $warnings += "no-dependency-surface-but-missing-explicit-empty-note"
}

if ($content -notmatch '(?im)^\|.*\bCritical Path\b.*\|') {
    $warnings += "critical-path-column-missing"
}

Write-Progress -Activity "Validating Dependencies Catalog" -Status "Complete" -PercentComplete 100

if ($issues.Count -gt 0) {
    Write-Host "Dependencies catalog validation failed:" -ForegroundColor Red
    foreach ($issue in ($issues | Select-Object -Unique)) {
        Write-Host (" - {0}" -f $issue) -ForegroundColor Red
    }
    exit 1
}

foreach ($warning in ($warnings | Select-Object -Unique)) {
    Write-Warning ("[validate-dependencies-catalog] {0}" -f $warning)
}

Write-Host ("Dependencies catalog validated: {0} dependency records found" -f $dependencyCount)
