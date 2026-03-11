param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$evidenceGraphModulePath = Join-Path $PSScriptRoot "modules\AppDoc.EvidenceGraph.psm1"
if (Test-Path $evidenceGraphModulePath) {
    try {
        Import-Module $evidenceGraphModulePath -Force -ErrorAction SilentlyContinue | Out-Null
    }
    catch {
        Write-Verbose ("Unable to import AppDoc.EvidenceGraph module: {0}" -f $_.Exception.Message)
    }
}

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

function Get-EvidencePayload {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) { return $null }
    try {
        return (Get-Content -Path $Path -Raw | ConvertFrom-Json -Depth 120)
    }
    catch {
        return $null
    }
}

function Get-EvidenceRecordsByKind {
    param(
        [AllowNull()]
        [object]$Payload,
        [string]$Kind
    )

    if (-not $Payload) { return @() }
    $records = @(Get-ObjectPropertyValue -Object $Payload -Name "records" -Default @())
    if ([string]::IsNullOrWhiteSpace($Kind)) { return @($records) }
    return @($records | Where-Object { [string]$_.kind -eq $Kind })
}

function Test-SourceLooksLikeFixtureOrTest {
    param(
        [string]$Source
    )

    if ([string]::IsNullOrWhiteSpace($Source)) { return $false }
    $normalized = $Source.Replace('\','/').ToLowerInvariant()
    $patterns = @(
        '/tests/',
        '/test/',
        '/fixtures/',
        '/fixture/',
        '/sample-dotnet-app/',
        '/samples/'
    )
    foreach ($pattern in $patterns) {
        if ($normalized.Contains($pattern)) { return $true }
    }
    return $false
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

$apiEvidencePath = Join-Path $docsPath "evidence\api-inventory.evidence.json"
$modelEvidencePath = Join-Path $docsPath "evidence\data-model.evidence.json"
$configEvidencePath = Join-Path $docsPath "evidence\config-catalog.evidence.json"
$dependencyEvidencePath = Join-Path $docsPath "evidence\dependencies-catalog.evidence.json"

$apiEvidence = Get-EvidencePayload -Path $apiEvidencePath
$modelEvidence = Get-EvidencePayload -Path $modelEvidencePath
$configEvidence = Get-EvidencePayload -Path $configEvidencePath
$dependencyEvidence = Get-EvidencePayload -Path $dependencyEvidencePath

 $apiEndpointRecords = @(Get-EvidenceRecordsByKind -Payload $apiEvidence -Kind "endpoint")
 $modelRecords = @(Get-EvidenceRecordsByKind -Payload $modelEvidence -Kind "model")
 $configRecords = @(Get-EvidenceRecordsByKind -Payload $configEvidence -Kind "configuration")
 $dependencyRecords = @(Get-EvidenceRecordsByKind -Payload $dependencyEvidence -Kind "dependency")

 $outboundRecords = @(
     $apiEndpointRecords |
         Where-Object {
             $meta = Get-ObjectPropertyValue -Object $_ -Name "metadata" -Default @{}
             $direction = [string](Get-ObjectPropertyValue -Object $meta -Name "direction" -Default "")
             $sourceType = [string](Get-ObjectPropertyValue -Object $meta -Name "sourceType" -Default "")
             $name = [string](Get-ObjectPropertyValue -Object $_ -Name "name" -Default "")
             ($direction -eq "outbound") -or
             ($sourceType -in @("soap-client","wcf-client","asmx-client","proxy-client")) -or
             ($name -match '^/soap-client/')
         }
 )

 $truthPack = $null

if ($truthPack) {
    $counts = Get-ObjectPropertyValue -Object $truthPack -Name "counts" -Default $null
    if ($counts) {
        $reportedEndpointCount = [int](Get-ObjectPropertyValue -Object $counts -Name "endpointRecords" -Default -1)
        $reportedModelCount = [int](Get-ObjectPropertyValue -Object $counts -Name "modelRecords" -Default -1)
        $reportedConfigCount = [int](Get-ObjectPropertyValue -Object $counts -Name "configurationRecords" -Default -1)
        $reportedDependencyCount = [int](Get-ObjectPropertyValue -Object $counts -Name "dependencyRecords" -Default -1)
        $reportedOutboundCount = [int](Get-ObjectPropertyValue -Object $counts -Name "outboundEndpoints" -Default -1)

        if ($reportedEndpointCount -ne $apiEndpointRecords.Count) {
            Add-IntegrityIssue -Issues $issues -Code "overview_endpoint_count_mismatch" -Message ("overview-truth-pack endpointRecords mismatch: expected {0}, got {1}" -f $apiEndpointRecords.Count, $reportedEndpointCount) -Path $overviewTruthPackPath
        }
        if ($reportedModelCount -ne $modelRecords.Count) {
            Add-IntegrityIssue -Issues $issues -Code "overview_model_count_mismatch" -Message ("overview-truth-pack modelRecords mismatch: expected {0}, got {1}" -f $modelRecords.Count, $reportedModelCount) -Path $overviewTruthPackPath
        }
        if ($reportedConfigCount -ne $configRecords.Count) {
            Add-IntegrityIssue -Issues $issues -Code "overview_config_count_mismatch" -Message ("overview-truth-pack configurationRecords mismatch: expected {0}, got {1}" -f $configRecords.Count, $reportedConfigCount) -Path $overviewTruthPackPath
        }
        if ($reportedDependencyCount -ne $dependencyRecords.Count) {
            Add-IntegrityIssue -Issues $issues -Code "overview_dependency_count_mismatch" -Message ("overview-truth-pack dependencyRecords mismatch: expected {0}, got {1}" -f $dependencyRecords.Count, $reportedDependencyCount) -Path $overviewTruthPackPath
        }
        if ($reportedOutboundCount -ne $outboundRecords.Count) {
            Add-IntegrityIssue -Issues $issues -Code "overview_outbound_count_mismatch" -Message ("overview-truth-pack outboundEndpoints mismatch: expected {0}, got {1}" -f $outboundRecords.Count, $reportedOutboundCount) -Path $overviewTruthPackPath
        }
    }
}

if (Test-Path $overviewPath) {
    $overviewContent = Get-Content -Path $overviewPath -Raw
    if ($outboundRecords.Count -gt 0 -and $overviewContent -match '(?i)No clear external system integration evidence was detected') {
        Add-IntegrityIssue -Issues $issues -Code "overview_external_systems_contradiction" -Message "Overview says no external integrations while outbound API evidence exists." -Path $overviewPath
    }
}

$contaminationArtifactPaths = @(
    $apiEvidencePath,
    $modelEvidencePath,
    $configEvidencePath,
    $dependencyEvidencePath,
    $buildEvidencePath
) | Where-Object { Test-Path $_ }

foreach ($artifactPath in $contaminationArtifactPaths) {
    $payload = Get-EvidencePayload -Path $artifactPath
    if (-not $payload) { continue }
    $artifactName = [string](Get-ObjectPropertyValue -Object $payload -Name "artifact" -Default "")
    if ($artifactName -eq "test-catalog") { continue }

    foreach ($record in @(Get-ObjectPropertyValue -Object $payload -Name "records" -Default @())) {
        if (-not $record) { continue }
        $source = [string](Get-ObjectPropertyValue -Object $record -Name "source" -Default "")
        if (Test-SourceLooksLikeFixtureOrTest -Source $source) {
            Add-IntegrityIssue -Issues $issues -Code "fixture_test_contamination" -Message ("Fixture/test path leaked into evidence record source '{0}'." -f $source) -Path $artifactPath
            break
        }
    }
}

$evidenceGraphPath = Join-Path $docsPath "evidence\evidence-graph.json"
if (Get-Command Test-AppDocEvidenceGraphIntegrity -ErrorAction SilentlyContinue) {
    try {
        $graphIntegrity = Test-AppDocEvidenceGraphIntegrity -RootPath $RootPath
        if (-not $graphIntegrity.passed) {
            foreach ($issue in @($graphIntegrity.issues)) {
                Add-IntegrityIssue -Issues $issues -Code "evidence_graph_integrity" -Message ([string]$issue) -Path $evidenceGraphPath
            }
        }
        foreach ($warning in @($graphIntegrity.warnings)) {
            Write-Host ("Evidence graph warning: {0}" -f [string]$warning) -ForegroundColor DarkYellow
        }
    }
    catch {
        Add-IntegrityIssue -Issues $issues -Code "evidence_graph_validation_error" -Message ("Failed to validate evidence graph: {0}" -f $_.Exception.Message) -Path $evidenceGraphPath
    }
} elseif (Test-Path $evidenceGraphPath) {
    Add-IntegrityIssue -Issues $issues -Code "validator_unavailable" -Message ("Validator Test-AppDocEvidenceGraphIntegrity is unavailable; evidence graph validation skipped for $evidenceGraphPath.") -Path $evidenceGraphPath
} elseif (-not (Test-Path $evidenceGraphPath)) {
    Add-IntegrityIssue -Issues $issues -Code "evidence_graph_missing" -Message "Canonical evidence graph is missing." -Path $evidenceGraphPath
}

$diagramStabilityScriptPath = Join-Path $PSScriptRoot "ci-diagram-stability-gate.ps1"
if (Test-Path $diagramStabilityScriptPath) {
    try {
        $stabilityJson = & $diagramStabilityScriptPath -RootPath $RootPath -Iterations 2 -SkipC4 -Json
        $stability = if ($stabilityJson) { $stabilityJson | ConvertFrom-Json -Depth 20 } else { $null }
        if ($stability -and -not $stability.passed) {
            Add-IntegrityIssue -Issues $issues -Code "diagram_stability_failed" -Message ("Diagram stability gate failed: {0}" -f ((@($stability.issues) -join "; "))) -Path $diagramStabilityScriptPath
        }
    }
    catch {
        Add-IntegrityIssue -Issues $issues -Code "diagram_stability_error" -Message ("Diagram stability gate execution failed: {0}" -f $_.Exception.Message) -Path $diagramStabilityScriptPath
    }
}
else {
    Add-IntegrityIssue -Issues $issues -Code "diagram_stability_script_missing" -Message "Diagram stability gate script is missing." -Path $diagramStabilityScriptPath
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
