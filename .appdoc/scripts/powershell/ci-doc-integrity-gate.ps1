param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Add-IntegrityIssue {
    param(
        [System.Collections.Generic.List[object]]$Issues,
        [string]$Code,
        [string]$Message,
        [string]$Path = ""
    )

    $Issues.Add([ordered]@{
        code = $Code
        message = $Message
        path = $Path
    }) | Out-Null
}

function Get-ObjectPropertyValue {
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
        if ($Object.Contains($Name)) {
            $value = $Object[$Name]
            if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
                return @($value)
            }
            return $value
        }
        return $Default
    }

    $prop = @($Object.PSObject.Properties | Where-Object { $_.Name -eq $Name } | Select-Object -First 1)
    if ($prop.Count -gt 0) {
        $value = $prop[0].Value
        if ($value -is [System.Collections.IEnumerable] -and -not ($value -is [string])) {
            return @($value)
        }
        return $value
    }
    return $Default
}

function Get-MarkdownSectionBlock {
    param(
        [string]$Content,
        [string]$SectionHeader
    )

    if (-not $Content) { return "" }
    $pattern = "(?ms)^##\s+" + [regex]::Escape($SectionHeader) + "\s*$\r?\n(.*?)(?=^##\s+[^\r\n]+|\z)"
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) { return $match.Groups[1].Value }
    return ""
}

function Test-NoTableHeaderContamination {
    param(
        [string]$Content
    )

    if (-not $Content) { return $true }

    # Valid markdown tables should either continue with rows or break with a blank line.
    $contaminated = [regex]::IsMatch(
        $Content,
        '(?m)^\|[^\r\n]+\|\r?\n\|[-:\s|]+\|\r?\n(?!\r?\n|\|)'
    )

    return (-not $contaminated)
}

if (-not (Test-Path $RootPath)) {
    throw "Root path does not exist: $RootPath"
}

$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) {
    Write-Host "Integrity gate skipped: docs directory not found at $docsPath" -ForegroundColor Yellow
    exit 0
}

$issues = New-Object System.Collections.Generic.List[object]
$docFiles = @(
    "overview.md",
    "start-here.md",
    "api-inventory.md",
    "data-model.md",
    "config-catalog.md",
    "build-cookbook.md",
    "test-catalog.md",
    "debt-register.md",
    "dependencies-catalog.md"
) | ForEach-Object { Join-Path $docsPath $_ } | Where-Object { Test-Path $_ }

foreach ($docPath in $docFiles) {
    $name = [IO.Path]::GetFileName($docPath)
    $content = Get-Content -Path $docPath -Raw

    if ($content -match '(?im)^##\s+Population Guide\b') {
        Add-IntegrityIssue -Issues $issues -Code "template_residue" -Message "Population Guide residue found." -Path $docPath
    }

    if ($content -match '(?im)^##\s+[^\r\n]+(?:No evidence found|Evidence for this section|_No )') {
        Add-IntegrityIssue -Issues $issues -Code "heading_concatenation" -Message "Heading and evidence text are concatenated." -Path $docPath
    }

    if (-not (Test-NoTableHeaderContamination -Content $content)) {
        Add-IntegrityIssue -Issues $issues -Code "table_contamination" -Message "Detected text contamination immediately after markdown table header." -Path $docPath
    }

    if ($name -ieq "dependencies-catalog.md") {
        $firstLine = ($content -split "`r?`n")[0]
        if ($firstLine.Trim() -ne "# Dependencies Catalog") {
            Add-IntegrityIssue -Issues $issues -Code "title_malformed" -Message "Dependencies catalog title line is malformed." -Path $docPath
        }
    }

    if ($name -ieq "test-catalog.md") {
        $testCaseHeaderCount = ([regex]::Matches($content, '(?m)^\|\s*Case Name\s*\|\s*Suite\s*\|\s*Input\s*\|\s*Expected Output\s*\|\s*Description\s*\|\s*Priority\s*\|')).Count
        if ($testCaseHeaderCount -gt 1) {
            Add-IntegrityIssue -Issues $issues -Code "duplicate_test_case_tables" -Message "Duplicate test-case placeholder table blocks detected." -Path $docPath
        }
    }
}

$overviewPath = Join-Path $docsPath "overview.md"
if (Test-Path $overviewPath) {
    $overviewContent = Get-Content -Path $overviewPath -Raw
    $welcomeBlock = Get-MarkdownSectionBlock -Content $overviewContent -SectionHeader "Welcome"
    if ($welcomeBlock) {
        $referencedIds = @(
            [regex]::Matches($welcomeBlock, '(?i)\bev-\d{4}\b') |
                ForEach-Object { $_.Value.ToLowerInvariant() } |
                Select-Object -Unique
        )
        $evidenceRows = @(
            [regex]::Matches($welcomeBlock, '(?im)^\|\s*(ev-\d{4})\s*\|') |
                ForEach-Object { $_.Groups[1].Value.ToLowerInvariant() } |
                Select-Object -Unique
        )

        if ($referencedIds.Count -gt 0) {
            $missing = @($referencedIds | Where-Object { $evidenceRows -notcontains $_ })
            if ($missing.Count -gt 0) {
                Add-IntegrityIssue -Issues $issues -Code "overview_evidence_mismatch" -Message ("Overview references missing evidence rows: {0}" -f ($missing -join ", ")) -Path $overviewPath
            }
        }
    }
}

$diagnosticsPath = Join-Path $docsPath "diagnostics-report.json"
if (Test-Path $diagnosticsPath) {
    $diagnostics = Get-Content -Path $diagnosticsPath -Raw | ConvertFrom-Json
    $frameworks = @(Get-ObjectPropertyValue -Object $diagnostics -Name "frameworks" -Default @())
    if ($frameworks.Count -gt 0 -and (@($frameworks | Where-Object { $null -eq $_ }).Count -gt 0)) {
        Add-IntegrityIssue -Issues $issues -Code "diagnostics_frameworks_null" -Message "diagnostics-report frameworks includes null entries." -Path $diagnosticsPath
    }
}

$qualityPath = Join-Path $docsPath "quality-report.json"
if (Test-Path $qualityPath) {
    $quality = Get-Content -Path $qualityPath -Raw | ConvertFrom-Json
    $overall = Get-ObjectPropertyValue -Object $quality -Name "overall" -Default $null
    if ($overall) {
        $highQuality = [int](Get-ObjectPropertyValue -Object $overall -Name "highQuality" -Default 0)
        $mediumQuality = [int](Get-ObjectPropertyValue -Object $overall -Name "mediumQuality" -Default 0)
        $lowQuality = [int](Get-ObjectPropertyValue -Object $overall -Name "lowQuality" -Default 0)
        $missingDocs = [int](Get-ObjectPropertyValue -Object $overall -Name "missingDocs" -Default 0)
        $totalDocs = [int](Get-ObjectPropertyValue -Object $overall -Name "totalDocs" -Default 0)
        $sum = $highQuality + $mediumQuality + $lowQuality + $missingDocs
        if ($sum -ne $totalDocs) {
            Add-IntegrityIssue -Issues $issues -Code "quality_summary_mismatch" -Message "quality-report overall counts do not sum to totalDocs." -Path $qualityPath
        }
    }
}

$buildEvidencePath = Join-Path $docsPath "evidence\build-cookbook.evidence.json"
if (Test-Path $buildEvidencePath) {
    $buildEvidence = Get-Content -Path $buildEvidencePath -Raw | ConvertFrom-Json
    $records = @(Get-ObjectPropertyValue -Object $buildEvidence -Name "records" -Default @())
    $actualCicdCount = @($records | Where-Object { [string]$_.kind -eq "cicd" }).Count
    $metadata = Get-ObjectPropertyValue -Object $buildEvidence -Name "metadata" -Default $null
    $reportedCicdCount = if ($metadata -ne $null -and $null -ne (Get-ObjectPropertyValue -Object $metadata -Name "cicdCount" -Default $null)) { [int](Get-ObjectPropertyValue -Object $metadata -Name "cicdCount" -Default -1) } else { -1 }
    if ($reportedCicdCount -ne $actualCicdCount) {
        Add-IntegrityIssue -Issues $issues -Code "build_cicd_count_mismatch" -Message ("build-cookbook cicdCount metadata mismatch: expected {0}, got {1}" -f $actualCicdCount, $reportedCicdCount) -Path $buildEvidencePath
    }
}

$overviewTruthPackPath = Join-Path $docsPath "evidence\overview-truth-pack.json"
if (Test-Path $overviewTruthPackPath) {
    $truthPack = Get-Content -Path $overviewTruthPackPath -Raw | ConvertFrom-Json
    $architectureProp = @($truthPack.PSObject.Properties | Where-Object { $_.Name -eq "architecture" } | Select-Object -First 1)
    if ($architectureProp.Count -gt 0 -and $architectureProp[0].Value) {
        $stylesProp = @($architectureProp[0].Value.PSObject.Properties | Where-Object { $_.Name -eq "styles" } | Select-Object -First 1)
        if ($stylesProp.Count -gt 0) {
            $styles = $stylesProp[0].Value
            if (($styles -is [string]) -or (-not ($styles -is [System.Collections.IEnumerable]))) {
                Add-IntegrityIssue -Issues $issues -Code "overview_styles_type" -Message "overview-truth-pack architecture.styles must be an array." -Path $overviewTruthPackPath
            }
        }
    }
}

$startHereEvidencePath = Join-Path $docsPath "evidence\start-here.evidence.json"
if (Test-Path $startHereEvidencePath) {
    $startEvidence = Get-Content -Path $startHereEvidencePath -Raw | ConvertFrom-Json
    $artifactName = [string](Get-ObjectPropertyValue -Object $startEvidence -Name "artifact" -Default "")
    foreach ($record in @(Get-ObjectPropertyValue -Object $startEvidence -Name "records" -Default @())) {
        if (-not $record) { continue }
        $recordArtifact = [string](Get-ObjectPropertyValue -Object $record -Name "artifact" -Default "")
        if ([string]::IsNullOrWhiteSpace($recordArtifact)) {
            Add-IntegrityIssue -Issues $issues -Code "start_here_record_artifact_missing" -Message "start-here evidence record contains empty artifact value." -Path $startHereEvidencePath
            break
        }
        if (-not [string]::IsNullOrWhiteSpace($artifactName) -and $recordArtifact -ne $artifactName) {
            Add-IntegrityIssue -Issues $issues -Code "start_here_record_artifact_mismatch" -Message "start-here evidence record artifact does not match top-level artifact." -Path $startHereEvidencePath
            break
        }
    }
}

if ($issues.Count -gt 0) {
    Write-Host "Documentation integrity gate failed with $($issues.Count) issue(s)." -ForegroundColor Red
    foreach ($issue in $issues) {
        $pathSuffix = if ($issue.path) { " ($($issue.path))" } else { "" }
        Write-Host (" - [{0}] {1}{2}" -f $issue.code, $issue.message, $pathSuffix) -ForegroundColor Yellow
    }
    exit 1
}

Write-Host "Documentation integrity gate passed." -ForegroundColor Green
exit 0
