#requires -Version 7.2
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
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
    [switch]$SkipSyntaxGate,
    # --- PRISTINE GATE (Deliverable B) — OPT-IN, default OFF ------------------
    # -PristineGate OFF (DEFAULT): report-only — the pristine check is a DEPTH
    #   measurement that NEVER blocks; status/overallScore unchanged.
    # -PristineGate ON (OPT-IN): the pristine check becomes a real gate that BLOCKS
    #   the run when any section is EMPTY (emptyCount>0) OR pristine subScore < floor.
    #   OWNER_REQUIRED cells are EXCLUDED (pending /appdoc.enhance, not failures).
    # Passed through to validate-documentation.ps1, which records the decision in
    # validation-report.json as `pristineGate`.
    [Parameter(Mandatory=$false)]
    [switch]$PristineGate,
    [Parameter(Mandatory=$false)]
    [ValidateRange(1,100)]
    [int]$PristineFloor = 80
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

<#
.SYNOPSIS
    Runs all documentation generators with optional quality assessment.

.DESCRIPTION
    This script executes all AppDoc documentation generators and optionally
    runs quality assessment against sample outputs.

.PARAMETER RootPath
    Root path of the project to analyze.

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

.PARAMETER PristineGate
    OPT-IN (default OFF): make the PRISTINE CHECK a real gate that BLOCKS the run
    when any section is EMPTY (emptyCount>0) OR the pristine sub-score < -PristineFloor.
    OWNER_REQUIRED cells are EXCLUDED (pending /appdoc.enhance, not failures). When
    OFF (default), the pristine check is report-only (a non-blocking DEPTH measurement;
    status/overallScore are unchanged). The decision is recorded in
    docs/validation-report.json as `pristineGate`.

.PARAMETER PristineFloor
    The floor the pristine sub-score must meet when -PristineGate is ON (default 80).

.EXAMPLE
    .\run-all-generators.ps1 -RootPath "c:\myproject"
    .\run-all-generators.ps1 -RootPath "c:\myproject" -SkipDiagrams
#>

$diagnosticsModule = Join-Path $PSScriptRoot "modules\AppDoc.Diagnostics.psm1"
$frameworkModule = Join-Path $PSScriptRoot "modules\AppDoc.FrameworkDetection.psm1"
$architectureModule = Join-Path $PSScriptRoot "modules\AppDoc.ArchitectureFingerprint.psm1"
$profilesModule = Join-Path $PSScriptRoot "modules\AppDoc.Profiles.psm1"
$evidenceGraphModule = Join-Path $PSScriptRoot "modules\AppDoc.EvidenceGraph.psm1"
if (Test-Path $diagnosticsModule) {
    Import-Module $diagnosticsModule -Force -ErrorAction Stop
}
if (Test-Path $frameworkModule) {
    Import-Module $frameworkModule -Force -ErrorAction Stop
}
if (Test-Path $architectureModule) {
    Import-Module $architectureModule -Force -ErrorAction Stop
}
if (Test-Path $profilesModule) {
    Import-Module $profilesModule -Force -ErrorAction Stop
}
if (Test-Path $evidenceGraphModule) {
    Import-Module $evidenceGraphModule -Force -ErrorAction Stop
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

function Get-AppDocValidationObjectValue {
    param(
        [AllowNull()]
        [object]$Object,
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

function Get-AppDocValidationExpectations {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowNull()]
        [object]$ArchitectureFingerprint = $null
    )

    $docsPath = (Get-AppDocDocsPath -RootPath $RootPath)
    $overviewTruthPath = Join-Path $docsPath "evidence\overview-truth-pack.json"
    $apiEvidencePath = Join-Path $docsPath "evidence\api-inventory.evidence.json"
    $modelEvidencePath = Join-Path $docsPath "evidence\data-model.evidence.json"
    $dependencyEvidencePath = Join-Path $docsPath "evidence\dependencies-catalog.evidence.json"
    $testEvidencePath = Join-Path $docsPath "evidence\test-catalog.evidence.json"
    $debtEvidencePath = Join-Path $docsPath "evidence\debt-register.evidence.json"

    $overviewTruth = $null
    if (Test-Path $overviewTruthPath) {
        try { $overviewTruth = Get-Content $overviewTruthPath -Raw | ConvertFrom-Json -Depth 80 } catch { $overviewTruth = $null }
    }

    $apiCount = 0
    $modelCount = 0
    $dependencyCount = 0
    $testRecordCount = 0
    $debtRecordCount = 0
    $counts = Get-AppDocValidationObjectValue -Object $overviewTruth -Name "counts" -Default $null
    if ($counts) {
        $apiCount = [int](Get-AppDocValidationObjectValue -Object $counts -Name "endpointRecords" -Default 0)
        $modelCount = [int](Get-AppDocValidationObjectValue -Object $counts -Name "modelRecords" -Default 0)
        $dependencyCount = [int](Get-AppDocValidationObjectValue -Object $counts -Name "dependencyRecords" -Default 0)
    }

    if ($apiCount -eq 0 -and (Test-Path $apiEvidencePath)) {
        try {
            $apiPayload = Get-Content $apiEvidencePath -Raw | ConvertFrom-Json -Depth 50
            $apiCount = @($apiPayload.records | Where-Object { $_ -and [string]$_.kind -eq "endpoint" }).Count
        }
        catch {}
    }

    if ($modelCount -eq 0 -and (Test-Path $modelEvidencePath)) {
        try {
            $modelPayload = Get-Content $modelEvidencePath -Raw | ConvertFrom-Json -Depth 50
            $modelCount = @($modelPayload.records | Where-Object { $_ -and [string]$_.kind -eq "model" }).Count
        }
        catch {}
    }

    if ($dependencyCount -eq 0 -and (Test-Path $dependencyEvidencePath)) {
        try {
            $dependencyPayload = Get-Content $dependencyEvidencePath -Raw | ConvertFrom-Json -Depth 50
            $dependencyCount = @($dependencyPayload.records | Where-Object { $_ -and [string]$_.kind -eq "dependency" }).Count
        }
        catch {}
    }

    if (Test-Path $testEvidencePath) {
        try {
            $testPayload = Get-Content $testEvidencePath -Raw | ConvertFrom-Json -Depth 50
            $testRecordCount = @($testPayload.records | Where-Object { $_ -and [string]$_.kind -in @("test-case","test-suite") }).Count
        }
        catch {}
    }

    if (Test-Path $debtEvidencePath) {
        try {
            $debtPayload = Get-Content $debtEvidencePath -Raw | ConvertFrom-Json -Depth 50
            $debtRecordCount = @($debtPayload.records | Where-Object { $_ -and [string]$_.kind -in @("technical-debt","debt-item") }).Count
        }
        catch {}
    }

    $primaryStyle = ""
    $apiSurfaceExpected = $null
    if ($ArchitectureFingerprint) {
        $primaryStyle = [string](Get-AppDocValidationObjectValue -Object $ArchitectureFingerprint -Name "primaryStyle" -Default "")
        $apiSurfaceExpected = Get-AppDocValidationObjectValue -Object $ArchitectureFingerprint -Name "apiSurfaceExpected" -Default $null
    }
    if ([string]::IsNullOrWhiteSpace($primaryStyle)) {
        $architectureBlock = Get-AppDocValidationObjectValue -Object $overviewTruth -Name "architecture" -Default $null
        $primaryStyle = [string](Get-AppDocValidationObjectValue -Object $architectureBlock -Name "primaryStyle" -Default "")
    }

    if ($null -eq $apiSurfaceExpected) {
        if ($primaryStyle -eq "no-api-surface") {
            $apiSurfaceExpected = $false
        }
        else {
            $apiSurfaceExpected = $true
        }
    }

    $apiSurfaceExpected = [bool]$apiSurfaceExpected
    $allowNoApiSurface = (-not $apiSurfaceExpected) -and ($apiCount -eq 0)
    $modelSurfaceExpected = ($apiSurfaceExpected -or $apiCount -gt 0)
    if ($primaryStyle -eq "no-api-surface" -and $apiCount -eq 0) {
        $modelSurfaceExpected = $false
    }
    $allowNoModelSurface = (-not $modelSurfaceExpected) -and ($modelCount -eq 0)

    $dependencySignalFiles = @()
    $dependencySignalPatterns = @(
        "*.csproj",
        "*.vbproj",
        "packages.config",
        "package.json",
        "pom.xml",
        "build.gradle",
        "build.gradle.kts",
        "requirements.txt",
        "Pipfile",
        "poetry.lock",
        "*.nuspec"
    )
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        $dependencySignalFiles = @(
            Get-AppDocSourceFiles -RootPath $RootPath -Artifact "dependencies-catalog" -Include $dependencySignalPatterns
        )
    }
    else {
        $dependencySignalFiles = @(
            Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include $dependencySignalPatterns -ErrorAction SilentlyContinue
        )
    }
    $dependencySignalCount = @($dependencySignalFiles).Count

    $testSignalCandidates = @()
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        $testSignalCandidates = @(
            Get-AppDocSourceFiles -RootPath $RootPath -Artifact "test-catalog" -Include @("*.cs","*.ts","*.js","*.py","*.java","*.go","*.feature")
        )
    }
    else {
        $testSignalCandidates = @(
            Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include @("*.cs","*.ts","*.js","*.py","*.java","*.go","*.feature") -ErrorAction SilentlyContinue
        )
    }
    $testSignalFiles = @(
        $testSignalCandidates |
            Where-Object {
                $p = [string]$_.FullName
                $p -match '(?i)(?:^|[\\/])(?:test|tests|spec|specs|__tests__)(?:[\\/]|$)' -or
                $p -match '(?i)(?:^|[\\/]).*(?:\.test|\.tests|\.spec|_test|_tests)\.[A-Za-z0-9]+$'
            }
    )
    $testProjectSignals = @()
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        $testProjectSignals = @(
            Get-AppDocSourceFiles -RootPath $RootPath -Artifact "test-catalog" -Include @("*.csproj","*.vbproj","*.fsproj") |
                Where-Object {
                    $p = [string]$_.FullName
                    $n = [string]$_.Name
                    $p -match '(?i)(?:^|[\\/])(?:test|tests|spec|specs)(?:[\\/]|$)' -or
                    $n -match '(?i)\.(tests?|specs?)\.(csproj|vbproj|fsproj)$'
                Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Syntax gate passed" -Component "Validation" -FilePath $syntaxGateScriptPath -Details @{ checkedFiles = $checkedFilesCount }
            }        )
    }
    else {
        $testProjectSignals = @(
            Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include @("*.csproj","*.vbproj","*.fsproj") -ErrorAction SilentlyContinue |
                Where-Object {
                    $p = [string]$_.FullName
                    $n = [string]$_.Name
                    $p -match '(?i)(?:^|[\\/])(?:test|tests|spec|specs)(?:[\\/]|$)' -or
                    $n -match '(?i)\.(tests?|specs?)\.(csproj|vbproj|fsproj)$'
                }
        )
    }
    $testSignalCount = @($testSignalFiles).Count + @($testProjectSignals).Count

    $debtSignalCandidates = @()
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        $debtSignalCandidates = @(
            Get-AppDocSourceFiles -RootPath $RootPath -Artifact "debt-register" -Include @("*.js","*.ts","*.cs","*.py","*.java")
        )
    }
    else {
        $debtSignalCandidates = @(
            Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include @("*.js","*.ts","*.cs","*.py","*.java") -ErrorAction SilentlyContinue
        )
    }

    # Configurable file size threshold (in bytes, e.g., 1MB)
    $maxDebtFileSize = 1MB
    $debtSignalCount = 0
    $filesToCheck = @($debtSignalCandidates | Select-Object -First 300)
    $debtSignalResults = $filesToCheck | ForEach-Object -Parallel {
        $file = $_
        if ($file.Length -gt $using:maxDebtFileSize) { return 0 }
        $raw = Get-Content -Path $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $raw) { return 0 }
        $count = ([regex]::Matches($raw, '(?im)\b(TODO|FIXME|HACK|XXX)\b')).Count
        return $count
    }
    $debtSignalCountRaw = ($debtSignalResults | Measure-Object -Sum).Sum
    $debtSignalCount = if ($null -eq $debtSignalCountRaw) { 0 } else { [int]$debtSignalCountRaw }
    $dependencySurfaceExpected = ($dependencyCount -gt 0 -or $dependencySignalCount -gt 0)
    $testSurfaceExpected = ($testRecordCount -gt 0 -or $testSignalCount -gt 0)
    $debtSurfaceExpected = ($debtRecordCount -gt 0 -or $debtSignalCount -gt 0)
    $allowNoDependencySurface = (-not $dependencySurfaceExpected) -and ($dependencyCount -eq 0)
    $allowNoTestSurface = (-not $testSurfaceExpected) -and ($testRecordCount -eq 0)
    $allowNoDebtSurface = (-not $debtSurfaceExpected) -and ($debtRecordCount -eq 0)

    return [ordered]@{
        primaryStyle = $primaryStyle
        apiSurfaceExpected = $apiSurfaceExpected
        modelSurfaceExpected = [bool]$modelSurfaceExpected
        dependencySurfaceExpected = [bool]$dependencySurfaceExpected
        testSurfaceExpected = [bool]$testSurfaceExpected
        debtSurfaceExpected = [bool]$debtSurfaceExpected
        allowNoApiSurface = [bool]$allowNoApiSurface
        allowNoModelSurface = [bool]$allowNoModelSurface
        allowNoDependencySurface = [bool]$allowNoDependencySurface
        allowNoTestSurface = [bool]$allowNoTestSurface
        allowNoDebtSurface = [bool]$allowNoDebtSurface
        endpointRecordCount = [int]$apiCount
        modelRecordCount = [int]$modelCount
        dependencyRecordCount = [int]$dependencyCount
        testRecordCount = [int]$testRecordCount
        debtRecordCount = [int]$debtRecordCount
        dependencySignalCount = [int]$dependencySignalCount
        testSignalCount = [int]$testSignalCount
        debtSignalCount = [int]$debtSignalCount
    }
}

function Get-AppDocCanonicalMetricCount {
    param(
        [Parameter(Mandatory=$true)]
        [string]$EvidencePath,
        [Parameter(Mandatory=$true)]
        [string[]]$Kinds
    )

    if (-not (Test-Path $EvidencePath)) { return 0 }
    try {
        $payload = Get-Content $EvidencePath -Raw | ConvertFrom-Json -Depth 80
        return @(
            @($payload.records) |
                Where-Object { $_ -and ($Kinds -contains ([string]$_.kind)) }
        ).Count
    }
    catch {
        return 0
    }
}

function Write-AppDocCanonicalMetrics {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$DocsPath
    )

    $evidencePath = Join-Path $DocsPath "evidence"
    if (-not (Test-Path $evidencePath)) {
        New-Item -Path $evidencePath -ItemType Directory -Force | Out-Null
    }

    $apiEvidencePath = Join-Path $evidencePath "api-inventory.evidence.json"
    $modelEvidencePath = Join-Path $evidencePath "data-model.evidence.json"
    $dependencyEvidencePath = Join-Path $evidencePath "dependencies-catalog.evidence.json"
    $testEvidencePath = Join-Path $evidencePath "test-catalog.evidence.json"
    $graphPath = Join-Path $evidencePath "evidence-graph.json"
    $overviewTruthPath = Join-Path $evidencePath "overview-truth-pack.json"

    $endpointCount = Get-AppDocCanonicalMetricCount -EvidencePath $apiEvidencePath -Kinds @("endpoint")
    $modelCount = Get-AppDocCanonicalMetricCount -EvidencePath $modelEvidencePath -Kinds @("model")
    $dependencyCount = Get-AppDocCanonicalMetricCount -EvidencePath $dependencyEvidencePath -Kinds @("dependency")
    $testCaseCount = Get-AppDocCanonicalMetricCount -EvidencePath $testEvidencePath -Kinds @("test-case", "test", "parameterized test")
    $testSuiteCount = Get-AppDocCanonicalMetricCount -EvidencePath $testEvidencePath -Kinds @("test-suite", "suite")

    $inboundEndpointCount = 0
    $outboundEndpointCount = 0
    if (Test-Path $apiEvidencePath) {
        try {
            $apiPayload = Get-Content $apiEvidencePath -Raw | ConvertFrom-Json -Depth 80
            $inboundEndpointCount = @(
                @($apiPayload.records) |
                    Where-Object {
                        $_ -and [string]$_.kind -eq 'endpoint' -and
                        [string](Get-AppDocValidationObjectValue -Object $_.metadata -Name 'direction' -Default 'inbound') -ne 'outbound'
                    }
            ).Count
            $outboundEndpointCount = @(
                @($apiPayload.records) |
                    Where-Object {
                        $_ -and [string]$_.kind -eq 'endpoint' -and
                        [string](Get-AppDocValidationObjectValue -Object $_.metadata -Name 'direction' -Default '') -eq 'outbound'
                    }
            ).Count
        }
        catch {
            $inboundEndpointCount = 0
            $outboundEndpointCount = 0
        }
    }

    $graphMetrics = @{}
    if (Test-Path $graphPath) {
        try {
            $graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 80
            $graphMetrics = Get-AppDocValidationObjectValue -Object $graph -Name "metrics" -Default @{}
        }
        catch {
            $graphMetrics = @{}
        }
    }

    $truthPackCounts = @{}
    if (Test-Path $overviewTruthPath) {
        try {
            $truthPack = Get-Content $overviewTruthPath -Raw | ConvertFrom-Json -Depth 80
            $truthPackCounts = Get-AppDocValidationObjectValue -Object $truthPack -Name "counts" -Default @{}
        }
        catch {
            $truthPackCounts = @{}
        }
    }

    $payload = [ordered]@{
        schemaVersion = "appdoc-metrics-canonical/v1"
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        source = [ordered]@{
            endpoint = "$(Get-AppDocDocsDirName -RootPath $RootPath)/evidence/api-inventory.evidence.json"
            model = "$(Get-AppDocDocsDirName -RootPath $RootPath)/evidence/data-model.evidence.json"
            dependency = "$(Get-AppDocDocsDirName -RootPath $RootPath)/evidence/dependencies-catalog.evidence.json"
            test = "$(Get-AppDocDocsDirName -RootPath $RootPath)/evidence/test-catalog.evidence.json"
        }
        totals = [ordered]@{
            endpointCount = [int]$endpointCount
            inboundEndpointCount = [int]$inboundEndpointCount
            outboundEndpointCount = [int]$outboundEndpointCount
            modelCount = [int]$modelCount
            dependencyCount = [int]$dependencyCount
            testCaseCount = [int]$testCaseCount
            testSuiteCount = [int]$testSuiteCount
        }
        crossChecks = [ordered]@{
            evidenceGraph = [ordered]@{
                endpointCount = [int](Get-AppDocValidationObjectValue -Object $graphMetrics -Name "endpointCount" -Default 0)
                inboundEndpointCount = [int](Get-AppDocValidationObjectValue -Object $graphMetrics -Name "inboundEndpointCount" -Default 0)
                outboundEndpointCount = [int](Get-AppDocValidationObjectValue -Object $graphMetrics -Name "outboundEndpointCount" -Default 0)
                modelCount = [int](Get-AppDocValidationObjectValue -Object $graphMetrics -Name "modelCount" -Default 0)
                dependencyCount = [int](Get-AppDocValidationObjectValue -Object $graphMetrics -Name "dependencyCount" -Default 0)
                testCaseCount = [int](Get-AppDocValidationObjectValue -Object $graphMetrics -Name "testCaseCount" -Default 0)
            }
            overviewTruthPack = [ordered]@{
                endpointCount = [int](Get-AppDocValidationObjectValue -Object $truthPackCounts -Name "endpointRecords" -Default 0)
                modelCount = [int](Get-AppDocValidationObjectValue -Object $truthPackCounts -Name "modelRecords" -Default 0)
                dependencyCount = [int](Get-AppDocValidationObjectValue -Object $truthPackCounts -Name "dependencyRecords" -Default 0)
            }
        }
    }

    $metricsPath = Join-Path $evidencePath "metrics-canonical.json"
    $payload | ConvertTo-Json -Depth 20 | Out-File -FilePath $metricsPath -Encoding UTF8
    return $metricsPath
}

# --- Overview truth-pack -> canonical re-alignment -----------------------------
# The overview generator (generate-overview.ps1) runs EARLIER in the Generation phase
# than the classic-ASP endpoint/datamodel generators and than this canonical-metrics
# write. Its truth-pack counts are therefore computed from the per-artifact evidence
# files as they exist at THAT point. For frameworks whose endpoint/model evidence is
# populated AFTER generate-overview runs (notably Classic ASP), the truth pack is
# frozen at 0 endpoints / 0 models while the canonical metrics (computed here, after
# the evidence is complete) reflect the real counts -> a cross-artifact metric drift
# (overview-endpoint-count:0/N / overview-model-count:0/M).
#
# The canonical metrics are the ground-truth count source. This re-alignment makes the
# overview-truth-pack counts mirror the canonical totals, using the SAME mapping that
# generate-overview.ps1 applies when the canonical is present (its alignment block),
# but executed at the correct pipeline point (after the canonical metrics exist).
# It is a surgical no-op: it only rewrites the truth pack when a count actually
# disagrees with the canonical, so already-consistent frameworks are byte-untouched.
# It does NOT change the canonical metrics, the gate check, or any threshold.
function Realign-AppDocOverviewTruthPackToCanonical {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$DocsPath
    )

    $evidencePath = Join-Path $DocsPath "evidence"
    $canonicalPath = Join-Path $evidencePath "metrics-canonical.json"
    $truthPackPath = Join-Path $evidencePath "overview-truth-pack.json"

    if (-not (Test-Path $canonicalPath)) { return $false }
    if (-not (Test-Path $truthPackPath)) { return $false }

    $canonical = Get-Content $canonicalPath -Raw | ConvertFrom-Json -Depth 80
    $totals = Get-AppDocValidationObjectValue -Object $canonical -Name "totals" -Default @{}
    if (-not $totals) { return $false }

    $canonicalEndpoint   = [int](Get-AppDocValidationObjectValue -Object $totals -Name "endpointCount" -Default 0)
    $canonicalInbound    = [int](Get-AppDocValidationObjectValue -Object $totals -Name "inboundEndpointCount" -Default 0)
    $canonicalOutbound   = [int](Get-AppDocValidationObjectValue -Object $totals -Name "outboundEndpointCount" -Default 0)
    $canonicalModel      = [int](Get-AppDocValidationObjectValue -Object $totals -Name "modelCount" -Default 0)
    $canonicalDependency = [int](Get-AppDocValidationObjectValue -Object $totals -Name "dependencyCount" -Default 0)

    $truthPack = Get-Content $truthPackPath -Raw | ConvertFrom-Json -Depth 80
    $counts = Get-AppDocValidationObjectValue -Object $truthPack -Name "counts" -Default @{}
    if (-not $counts) {
        $counts = [ordered]@{}
        $truthPack | Add-Member -NotePropertyName "counts" -NotePropertyValue $counts
    }

    # Current truth-pack counts (-1 sentinel so a missing key is treated as "differ").
    $currentEndpoint   = [int](Get-AppDocValidationObjectValue -Object $counts -Name "endpointRecords" -Default -1)
    $currentInbound    = [int](Get-AppDocValidationObjectValue -Object $counts -Name "inboundEndpoints" -Default -1)
    $currentOutbound   = [int](Get-AppDocValidationObjectValue -Object $counts -Name "outboundEndpoints" -Default -1)
    $currentModel      = [int](Get-AppDocValidationObjectValue -Object $counts -Name "modelRecords" -Default -1)
    $currentDependency = [int](Get-AppDocValidationObjectValue -Object $counts -Name "dependencyRecords" -Default -1)

    $needsAlign = ($currentEndpoint   -ne $canonicalEndpoint) -or
                  ($currentInbound    -ne $canonicalInbound) -or
                  ($currentOutbound   -ne $canonicalOutbound) -or
                  ($currentModel      -ne $canonicalModel) -or
                  ($currentDependency -ne $canonicalDependency)
    if (-not $needsAlign) { return $false }

    # Align the overview truth-pack counts to the canonical totals (ground-truth source).
    $truthPack.counts.endpointRecords   = [int]$canonicalEndpoint
    $truthPack.counts.inboundEndpoints  = [int]$canonicalInbound
    $truthPack.counts.outboundEndpoints = [int]$canonicalOutbound
    $truthPack.counts.modelRecords      = [int]$canonicalModel
    $truthPack.counts.dependencyRecords = [int]$canonicalDependency

    $truthPack | ConvertTo-Json -Depth 50 | Out-File -FilePath $truthPackPath -Encoding UTF8

    # Keep the canonical's informational crossCheck (a snapshot of the truth pack taken
    # earlier, before this realign) consistent with the now-aligned truth pack. This is a
    # display-only field (not scored by the gate); the totals remain the ground truth.
    if ($canonical.PSObject.Properties["crossChecks"]) {
        $cc = $canonical.crossChecks
        if ($cc -and $cc.PSObject.Properties["overviewTruthPack"]) {
            $cc.overviewTruthPack.endpointCount   = [int]$canonicalEndpoint
            $cc.overviewTruthPack.modelCount      = [int]$canonicalModel
            $cc.overviewTruthPack.dependencyCount = [int]$canonicalDependency
            $canonical | ConvertTo-Json -Depth 20 | Out-File -FilePath $canonicalPath -Encoding UTF8
        }
    }

    return $true
}

function Set-AppDocRootProvenance {
    # Thin wrapper kept for the existing call sites: the footer logic lives in
    # modules/AppDoc.Provenance.psm1 (recursive over docs/**, idempotent, LF, skips
    # hand-authored files). run-appdoc-build.ps1 calls it again as its final step so the
    # second composer pass cannot leave the master document without a footer.
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$DocsPath,
        [Parameter(Mandatory=$true)]
        [string]$Profile
    )
    Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Provenance.psm1') -Force -ErrorAction Stop
    [void](Set-AppDocProvenanceFooter -RootPath $RootPath -DocsPath $DocsPath -Profile $Profile)
}

function Write-AppDocJsonCompanionSummaries {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DocsPath
    )

    $targets = @(
        "evidence/diagram-truth-pack.json",
        "evidence/evidence-graph.json",
        "evidence/manifest.json",
        "evidence/narrative-context-pack.json",
        "evidence/narrative-run-report.json",
        "evidence/overview-truth-pack.json",
        "quality-report.json",
        "validation-report.json"
    )

    foreach ($target in $targets) {
        $jsonPath = Join-Path $DocsPath $target
        if (-not (Test-Path $jsonPath)) { continue }

        $summaryPath = [System.IO.Path]::ChangeExtension($jsonPath, ".summary.md")
        $displayName = Split-Path $jsonPath -Leaf
        $changed = "Generated/updated in this run"
        $why = "Provides deterministic machine-readable state for validation, trust, and reproducibility workflows."
        $next = "Review key metrics and issues, then trace to linked evidence for remediation."
        $verify = "Compare against source markdown and evidence entries; confirm no contradiction/drift findings."

        try {
            $payload = Get-Content $jsonPath -Raw | ConvertFrom-Json -Depth 120
            $issueCount = 0
            if ($payload.issues) { $issueCount = @($payload.issues).Count }
            $metricHints = @()
            if ($payload.metrics) {
                foreach ($p in @($payload.metrics.PSObject.Properties | Select-Object -First 4)) {
                    $metricHints += ("{0}={1}" -f $p.Name, $p.Value)
                }
            }
            if ($issueCount -gt 0) {
                $next = "Address $issueCount issue(s) captured in $displayName, then regenerate and revalidate."
            }
            if ($metricHints.Count -gt 0) {
                $why += " Key metrics: $($metricHints -join '; ')."
            }
        }
        catch {
            $verify = "File could not be parsed in summary generation; validate JSON syntax before relying on this artifact."
        }

        $summaryContent = @(
            "# Companion Summary — $displayName",
            "",
            "## What changed",
            "- $changed",
            "",
            "## Why it matters",
            "- $why",
            "",
            "## What to do next",
            "- $next",
            "",
            "## Trust but verify",
            "- $verify"
        ) -join "`n"

        $summaryContent | Out-File -FilePath $summaryPath -Encoding UTF8 -NoNewline
    }
}

function Get-DocSpecificIssues {
    param(
        [string]$DocType,
        [string]$Content,
        [AllowNull()]
        [hashtable]$Expectations = @{}
    )

    $issues = @()
    $allowNoApiSurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoApiSurface" -Default $false)
    $allowNoModelSurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoModelSurface" -Default $false)
    $allowNoDependencySurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoDependencySurface" -Default $false)
    $allowNoTestSurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoTestSurface" -Default $false)
    $allowNoDebtSurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoDebtSurface" -Default $false)

    switch ($DocType) {
        "Overview" {
            $welcomeSection = Get-MarkdownSectionContent -Content $Content -Section "Welcome"
            if (-not $welcomeSection) {
                $issues += "Welcome section missing"
            }
            else {
                $requiredWelcomeSubsections = @(
                    "what_it_does",
                    "inputs",
                    "processing_steps",
                    "outputs",
                    "external_systems",
                    "confidence_notes",
                    "evidence_refs"
                )

                foreach ($subsection in $requiredWelcomeSubsections) {
                    if (-not [regex]::IsMatch($welcomeSection, "(?im)^###\s+" + [regex]::Escape($subsection) + "\b")) {
                        $issues += "Welcome subsection missing: $subsection"
                    }
                }

                $evidenceRefHits = ([regex]::Matches($welcomeSection, '(?i)ev-\d{4}')).Count
                if ($evidenceRefHits -eq 0) {
                    $issues += "Welcome evidence references are missing"
                }
            }
        }
        "API Inventory" {
            $section = Get-MarkdownSectionContent -Content $Content -Section "API Endpoints"
            if (-not $section) {
                $issues += "API Endpoints section missing"
            }
            elseif (-not $allowNoApiSurface -and $section -match '_No API endpoints detected') {
                $issues += "API Endpoints section still contains placeholder text"
            }
            elseif (-not $allowNoApiSurface -and (Get-MarkdownDataRowCount -SectionContent $section) -eq 0) {
                $issues += "API Endpoints table has no populated rows"
            }
        }
        "Data Model" {
            $section = Get-MarkdownSectionContent -Content $Content -Section "Data Models"
            if (-not $section) {
                $issues += "Data Models section missing"
            }
            elseif (-not $allowNoModelSurface -and $section -match '_No data models detected') {
                $issues += "Data Models section still contains placeholder text"
            }
            elseif (-not $allowNoModelSurface -and (Get-MarkdownDataRowCount -SectionContent $section) -eq 0) {
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
            if (-not $allowNoTestSurface -and (-not $suiteSection -or $suiteSection -match '_No test suites detected')) {
                $issues += "Test Suites section missing or empty"
            }
            elseif (-not $allowNoTestSurface -and (Get-MarkdownDataRowCount -SectionContent $suiteSection) -eq 0) {
                $issues += "Test Suites table has no populated rows"
            }

            $casesSection = Get-MarkdownSectionContent -Content $Content -Section "Test Cases"
            if ($casesSection) {
                if (-not $allowNoTestSurface -and $casesSection -match '_No test cases detected') {
                    $issues += "Test Cases placeholder text remains"
                }
                elseif (-not $allowNoTestSurface -and (Get-MarkdownDataRowCount -SectionContent $casesSection) -eq 0) {
                    $issues += "Test Cases table has no populated rows"
                }
            }
        }
        "Debt Register" {
            $debtSection = Get-MarkdownSectionContent -Content $Content -Section "Debt Items"
            if (-not $allowNoDebtSurface -and (-not $debtSection -or $debtSection -match '_No technical debt items detected')) {
                $issues += "Debt Items section missing actionable entries"
            }
            elseif (-not $allowNoDebtSurface -and (Get-MarkdownDataRowCount -SectionContent $debtSection) -eq 0) {
                $issues += "Debt Items table has no populated rows"
            }
        }
        "Dependencies Catalog" {
            $summarySection = Get-MarkdownSectionContent -Content $Content -Section "Dependency Summary"
            if (-not $allowNoDependencySurface -and (-not $summarySection -or $summarySection -match '_No dependencies detected')) {
                $issues += "Dependency summary not populated"
            }
            elseif (-not $allowNoDependencySurface -and (Get-MarkdownDataRowCount -SectionContent $summarySection) -eq 0) {
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
        [string]$DocType,
        [AllowNull()]
        [hashtable]$Expectations = @{}
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
    $allowNoApiSurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoApiSurface" -Default $false)
    $allowNoModelSurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoModelSurface" -Default $false)
    $allowNoDependencySurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoDependencySurface" -Default $false)
    $allowNoTestSurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoTestSurface" -Default $false)
    $allowNoDebtSurface = [bool](Get-AppDocValidationObjectValue -Object $Expectations -Name "allowNoDebtSurface" -Default $false)
    
    # Detect common placeholder patterns
    $placeholderPatterns = @(
        @{ Pattern = '_No .* detected'; Description = "Empty detection placeholder" }
        @{ Pattern = '(?im)^\s*Describe\s+the\s+.+\s+section\.?\s*$'; Description = "Template instruction remaining" }
        @{ Pattern = '(?im)^\s*Document\s+the\s+following(?:\s+.+)?\.?\s*$'; Description = "Template instruction remaining" }
        @{ Pattern = '(?im)^\s*List and describe\s+(?:the\s+)?(?:following\s+)?(?:components|items|sections|services|dependencies|configurations)\b[^\r\n]*$'; Description = "Template instruction remaining" }
        @{ Pattern = '(?im)^\s*Provide\s+(?:an\s+)?example\s+(?:for|of|showing)\b[^\r\n]*$'; Description = "Template instruction remaining" }
        @{ Pattern = '(?im)^\s*Provide\s+quick\s+start\s+instructions\s+(?:for|to)\b[^\r\n]*$'; Description = "Template instruction remaining" }
        @{ Pattern = '(?im)^\s*Refer to .* documentation\.?$'; Description = "Template instruction remaining" }
        @{ Pattern = '\[PLACEHOLDER\]|\[TODO\]|\[TBD\]'; Description = "Explicit placeholder marker" }
        @{ Pattern = '(?im)^\s*This (section|codebase) may'; Description = "Uncertain filler text" }
    )
    
    foreach ($pattern in $placeholderPatterns) {
        $patternMatches = [regex]::Matches($content, $pattern.Pattern)
        if ($pattern.Description -eq "Empty detection placeholder") {
            if ($DocType -eq "API Inventory" -and $allowNoApiSurface) { continue }
            if ($DocType -eq "Data Model" -and $allowNoModelSurface) { continue }
            if ($DocType -eq "Test Catalog" -and $allowNoTestSurface) { continue }
            if ($DocType -eq "Dependencies Catalog" -and $allowNoDependencySurface) { continue }
            if ($DocType -eq "Debt Register" -and $allowNoDebtSurface) { continue }
        }
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
        if (($DocType -eq "Test Catalog" -and $allowNoTestSurface) -or ($DocType -eq "Dependencies Catalog" -and $allowNoDependencySurface)) {
            # Allowed no-surface placeholder table for this artifact.
        }
        else {
            $issues += "Empty table with placeholder"
        }
    }
    
    if ($tableRowCount -le 2 -and $DocType -in @('API Inventory', 'Data Model', 'Config Catalog', 'Test Catalog')) {
        if ($DocType -eq "API Inventory" -and $allowNoApiSurface) {
            # Allowed in no-API-surface repositories.
        }
        elseif ($DocType -eq "Data Model" -and $allowNoModelSurface) {
            # Allowed in no-model-surface repositories.
        }
        elseif ($DocType -eq "Test Catalog" -and $allowNoTestSurface) {
            # Allowed in no-test-surface repositories.
        }
        else {
            $issues += "Table has no data rows (header only)"
        }
    }

    # Doc-type specific structural checks
    $issues += Get-DocSpecificIssues -DocType $DocType -Content $content -Expectations $Expectations
    
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

function Get-AppDocFrameworkNames {
    param(
        [AllowEmptyCollection()]
        [array]$DetectedFrameworks = @()
    )

    return @(
        $DetectedFrameworks |
            ForEach-Object {
                $entry = $_
                if ($null -eq $entry) {
                    ""
                }
                elseif ($entry -is [System.Collections.IDictionary]) {
                    if ($entry.Contains("framework")) { [string]$entry["framework"] } else { "" }
                }
                elseif ($entry -is [psobject]) {
                    $frameworkProp = @($entry.PSObject.Properties | Where-Object { $_.Name -eq "framework" } | Select-Object -First 1)
                    if ($frameworkProp.Count -gt 0 -and $frameworkProp[0].Value) { [string]$frameworkProp[0].Value } else { "" }
                }
                else {
                    ""
                }
            } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
}
$docsPath = (Get-AppDocDocsPath -RootPath $RootPath)
if (-not (Test-Path $docsPath)) {
    New-Item -Path $docsPath -ItemType Directory -Force | Out-Null
}

$runSessionPath = Join-Path $docsPath ".appdoc-run.session.json"
if (-not $DryRun) {
    foreach ($markerPath in @($runSessionPath)) {
        if (Test-Path $markerPath) {
            $activePid = 0
            try {
                $sessionPayload = Get-Content -Path $markerPath -Raw | ConvertFrom-Json -Depth 8
                $activePid = [int]$sessionPayload.pid
            }
            catch {
                $activePid = 0
            }

            if ($activePid -gt 0 -and (Get-Process -Id $activePid -ErrorAction SilentlyContinue)) {
                Write-Error "Another AppDoc run is already active for this output path (PID $activePid). Stop that run first."
                exit 1
            }
        }
    }

    [ordered]@{
        pid = $PID
        startedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        rootPath = $RootPath
        docsPath = $docsPath
    } | ConvertTo-Json -Depth 6 | Out-File -FilePath $runSessionPath -Encoding UTF8
}

if (Get-Command Initialize-AppDocDiagnostics -ErrorAction SilentlyContinue) {
    Initialize-AppDocDiagnostics -RootPath $RootPath -OutputPath $docsPath -Reset
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Deterministic execution configured (local-only)" -Component "orchestrator"
}

$syntaxGateScriptPath = Join-Path $PSScriptRoot "ci-syntax-gate.ps1"
if (-not $SkipSyntaxGate) {
    if (Test-Path $syntaxGateScriptPath) {
        if ($DryRun) {
            Write-Host "[DryRun] Would execute ci-syntax-gate.ps1" -ForegroundColor Gray
            Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Dry run skipped syntax gate" -Component "Validation" -FilePath $syntaxGateScriptPath
        }
        else {
            try {
                Write-Host "Running syntax gate..."
                $global:LASTEXITCODE = 0
                $syntaxGateResultJson = & $syntaxGateScriptPath -RootPath $RootPath -Include @($PSScriptRoot) -Json
                $syntaxGateExitCode = [int]$LASTEXITCODE
                $syntaxGateResult = $null

                if ($syntaxGateResultJson) {
                    $syntaxGateResult = $syntaxGateResultJson | ConvertFrom-Json
                }

                $syntaxGatePassedByPayload = ($syntaxGateResult -and $syntaxGateResult.passed)
                $syntaxGateFailed = (-not $syntaxGatePassedByPayload) -and ($syntaxGateExitCode -ne 0 -or -not $syntaxGateResult)
                if ($syntaxGateFailed) {
                    $errorCount = if ($syntaxGateResult) { [int]$syntaxGateResult.errorCount } else { -1 }
                    throw "Syntax gate failed (exit=$syntaxGateExitCode, errors=$errorCount)."
                }

                $checkedFilesCount = if ($null -ne $syntaxGateResult.checkedFiles) { [int]$syntaxGateResult.checkedFiles } else { 0 }
                Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Syntax gate passed" -Component "Validation" -FilePath $syntaxGateScriptPath -Details @{ checkedFiles = $checkedFilesCount }            }
            catch {
                Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Error" -Message "Syntax gate failed" -Component "Validation" -FilePath $syntaxGateScriptPath -Details @{ exception = $_.Exception.Message }
                throw
            }
        }
    }
    else {
        Add-AppDocDiagnostic -Category "IO_ERROR" -Severity "Warning" -Message "Syntax gate script not found" -Component "Validation" -FilePath $syntaxGateScriptPath
    }
}

$activeProfile = $null
if (Get-Command Get-AppDocProfile -ErrorAction SilentlyContinue) {
    $activeProfile = Get-AppDocProfile -RootPath $RootPath -Profile $Profile
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Loaded documentation profile" -Component "orchestrator" -Details @{ profile = $activeProfile.profile }
}

$detectedFrameworks = @()
$architectureFingerprint = $null
if (Get-Command Get-AppDocArchitectureFingerprint -ErrorAction SilentlyContinue) {
    $architectureFingerprint = Get-AppDocArchitectureFingerprint -RootPath $RootPath
    $fingerprintReportPath = Join-Path $docsPath "architecture-fingerprint.json"
    $architectureFingerprint | ConvertTo-Json -Depth 20 | Out-File -FilePath $fingerprintReportPath -Encoding UTF8
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Architecture fingerprint computed" -Component "analysis" -Details @{
        primaryStyle = [string]$architectureFingerprint.primaryStyle
        apiSurfaceExpected = [bool]$architectureFingerprint.apiSurfaceExpected
        confidence = [double]$architectureFingerprint.confidence
    }
}
if (Get-Command Get-AppDocDetectedFrameworks -ErrorAction SilentlyContinue) {
    $detectedFrameworks = Get-AppDocDetectedFrameworks -RootPath $RootPath
    $frameworkNames = @(Get-AppDocFrameworkNames -DetectedFrameworks $detectedFrameworks)
    if ($detectedFrameworks.Count -eq 0) {
        Add-AppDocDiagnostic -Category "UNSUPPORTED_FRAMEWORK" -Severity "Warning" -Message "No supported framework signatures detected" -Component "analysis"
    }
    else {
        Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Frameworks detected" -Component "analysis" -Details @{ frameworks = $frameworkNames }
        $frameworkReportPath = Join-Path $docsPath "framework-detection.json"
        $detectedFrameworks | ConvertTo-Json -Depth 10 | Out-File -FilePath $frameworkReportPath -Encoding UTF8
    }
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Warning" -Message "PowerShell 7+ is recommended for AppDoc generators" -Details @{ version = $PSVersionTable.PSVersion.ToString() }
}

# Determinism across re-runs: some generators (overview, start-here) read DERIVED evidence
# that this pipeline only rebuilds later in the run (the evidence graph, the canonical
# metrics). On a first run those files do not exist yet; on a re-run a stale copy from the
# previous run would be read instead, so the two runs produced different counts. Remove the
# stale copies up front so every run sees the same inputs in the same order.
foreach ($staleDerived in @('evidence-graph.json', 'metrics-canonical.json')) {
    $stalePath = Join-Path (Join-Path $docsPath 'evidence') $staleDerived
    if (Test-Path -LiteralPath $stalePath) { Remove-Item -LiteralPath $stalePath -Force }
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
            "generate-api-inventory.ps1",
            "generate-data-model.ps1",
            "generate-config-catalog.ps1",
            "generate-build-cookbook.ps1",
            "generate-test-catalog.ps1",
            "generate-debt-register.ps1",
            "generate-dependencies-catalog.ps1",
            "generate-overview.ps1",
            "generate-start-here.ps1",
            "generate-task-guides.ps1",
            "generate-docs-index.ps1",
            "generate-classic-asp-endpoints.ps1",
            "generate-classic-asp-datamodel.ps1",
            "generate-classic-asp-platform.ps1",
            "generate-classic-asp-failures.ps1",
            "generate-classic-asp-procdict.ps1",
            "generate-classic-asp-security.ps1",
            "generate-external-calls.ps1",
            "generate-classic-asp-extcalls.ps1",
            "generate-source-docs.ps1",
            "generate-git-ownership.ps1",
            # The evidence register and verification appendix summarise EVERY evidence
            # file, so they run after all evidence producers (extcalls, source-docs,
            # git-ownership, ...). Running them earlier made a first run and a re-run differ.
            "generate-evidence-register.ps1",
            "generate-verification-appendix.ps1",
            "generate-unified-master.ps1"
        )
    }
)
$scriptFailures = @()

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
            $scriptFailures += [ordered]@{
                phase = $phase.Name
                script = $script
                error = $_.Exception.Message
            }
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

# Generate deterministic internal/data-flow Mermaid diagrams (unless skipped)
if (-not $SkipDiagrams) {
    Write-Host "Generating deterministic internal/data-flow Mermaid diagrams..."
    $diagramSuiteScript = Join-Path $PSScriptRoot "generate-mermaid-architecture-suite.ps1"
    if (Test-Path $diagramSuiteScript) {
        if ($DryRun) {
            Write-Host "[DryRun] Would execute generate-mermaid-architecture-suite.ps1" -ForegroundColor Gray
            Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Dry run skipped deterministic architecture diagram suite generation" -Component "Generation" -FilePath $diagramSuiteScript
        }
        else {
            try {
                & $diagramSuiteScript -RootPath $RootPath
                Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Deterministic architecture diagram suite generated" -Component "Generation" -FilePath $diagramSuiteScript
            }
            catch {
                Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to generate deterministic architecture diagram suite" -Component "Generation" -FilePath $diagramSuiteScript -Details @{ exception = $_.Exception.Message }
                Write-Warning "Failed to generate deterministic architecture diagram suite: $_"
            }
        }
    }
    else {
        Add-AppDocDiagnostic -Category "IO_ERROR" -Severity "Info" -Message "Deterministic architecture diagram suite generator not found (optional feature)" -Component "Generation" -FilePath $diagramSuiteScript
        Write-Verbose "Deterministic architecture diagram suite generator not found (optional feature)"
    }
}

# Validate diagrams after generation (unless skipped)
if (-not $SkipDiagrams) {
    $diagramValidationScript = Join-Path $PSScriptRoot "validate-diagrams.ps1"
    if (Test-Path $diagramValidationScript) {
        if ($DryRun) {
            Write-Host "[DryRun] Would execute validate-diagrams.ps1" -ForegroundColor Gray
            Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Dry run skipped diagram validation" -Component "Validation" -FilePath $diagramValidationScript
        }
        else {
            try {
                $diagramValidationJson = & $diagramValidationScript -RootPath $RootPath -Json
                $diagramValidation = if ($diagramValidationJson) { $diagramValidationJson | ConvertFrom-Json } else { $null }
                if ($diagramValidation -and -not $diagramValidation.passed) {
                    Add-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Diagram validation reported issues" -Component "Validation" -FilePath $diagramValidationScript -Details @{ issues = @($diagramValidation.issues) }
                    Write-Warning ("Diagram validation reported issues: {0}" -f (@($diagramValidation.issues) -join ", "))
                }
                else {
                    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Diagram validation passed" -Component "Validation" -FilePath $diagramValidationScript
                }
            }
            catch {
                Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to run diagram validation" -Component "Validation" -FilePath $diagramValidationScript -Details @{ exception = $_.Exception.Message }
                Write-Warning "Failed to run diagram validation: $_"
            }
        }
    }
    else {
        Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Diagram validation skipped: validate-diagrams.ps1 not found" -Component "Validation" -FilePath $diagramValidationScript
        Write-Host "Diagram validation skipped: validate-diagrams.ps1 not found" -ForegroundColor Gray
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

$evidenceGraphPath = Join-Path $docsPath "evidence\evidence-graph.json"
$evidenceGraphIntegrity = $null
$evidenceGraphMetrics = $null
if (Get-Command Write-AppDocEvidenceGraph -ErrorAction SilentlyContinue) {
    Write-Host "`n[Evidence Graph]" -ForegroundColor Cyan
    Write-Host "Compiling canonical evidence graph..."
    try {
        $evidenceGraphData = Get-AppDocEvidenceGraphData -RootPath $RootPath
        $evidenceGraphPath = Write-AppDocEvidenceGraph -RootPath $RootPath -GraphData $evidenceGraphData
        $evidenceGraphMetrics = Get-AppDocValidationObjectValue -Object $evidenceGraphData -Name "metrics" -Default $null
        $evidenceGraphIntegrity = Test-AppDocEvidenceGraphIntegrity -RootPath $RootPath -GraphData $evidenceGraphData

        if ($evidenceGraphIntegrity -and -not $evidenceGraphIntegrity.passed) {
            $severity = if ($StrictValidation) { "Error" } else { "Warning" }
            Add-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity $severity -Message "Evidence graph integrity failed" -Component "Validation" -FilePath $evidenceGraphPath -Details @{
                issues = @($evidenceGraphIntegrity.issues)
            }
            if ($StrictValidation) {
                throw ("Evidence graph integrity failed: {0}" -f (@($evidenceGraphIntegrity.issues) -join "; "))
            }
            Write-Warning ("Evidence graph integrity failed (soft mode): {0}" -f (@($evidenceGraphIntegrity.issues) -join "; "))
        }
        elseif ($evidenceGraphIntegrity -and $evidenceGraphIntegrity.warnings -and @($evidenceGraphIntegrity.warnings).Count -gt 0) {
            Add-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Evidence graph integrity warnings" -Component "Validation" -FilePath $evidenceGraphPath -Details @{
                warnings = @($evidenceGraphIntegrity.warnings)
            }
        }
        else {
            Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Evidence graph compiled" -Component "Generation" -FilePath $evidenceGraphPath -Details @{
                entityCount = [int](Get-AppDocValidationObjectValue -Object $evidenceGraphMetrics -Name "entityCount" -Default 0)
                edgeCount = [int](Get-AppDocValidationObjectValue -Object $evidenceGraphMetrics -Name "edgeCount" -Default 0)
            }
        }
    }
    catch {
        Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Evidence graph compilation failed" -Component "Generation" -FilePath $evidenceGraphPath -Details @{ exception = $_.Exception.Message }
        Write-Warning ("Evidence graph compilation failed: {0}" -f $_.Exception.Message)
    }
}
else {
    Add-AppDocDiagnostic -Category "IO_ERROR" -Severity "Info" -Message "Evidence graph module unavailable; skipping canonical graph generation" -Component "Generation" -FilePath $evidenceGraphModule
}

$canonicalMetricsPath = $null
try {
    $canonicalMetricsPath = Write-AppDocCanonicalMetrics -RootPath $RootPath -DocsPath $docsPath
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Canonical metrics generated" -Component "Generation" -FilePath $canonicalMetricsPath
    Write-Host "📄 Canonical metrics generated: $canonicalMetricsPath" -ForegroundColor Cyan
}
catch {
    Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to generate canonical metrics" -Component "Generation" -Details @{ exception = $_.Exception.Message }
    Write-Warning ("Failed to generate canonical metrics: {0}" -f $_.Exception.Message)
}

# Re-align the overview truth-pack counts to the canonical metrics now that they exist.
# (generate-overview.ps1 ran earlier, before classic-ASP endpoint/model evidence was
# populated, so its counts can be stale; the canonical metrics are the ground-truth
# count source. This is a no-op when they already agree.)
if (Test-Path $canonicalMetricsPath) {
    try {
        $realignedOverview = Realign-AppDocOverviewTruthPackToCanonical -RootPath $RootPath -DocsPath $docsPath
        if ($realignedOverview) {
            Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Overview truth-pack re-aligned to canonical metrics" -Component "Generation" -FilePath (Join-Path $docsPath "evidence\overview-truth-pack.json")
            Write-Host "📄 Overview truth-pack counts re-aligned to canonical metrics." -ForegroundColor Cyan
        }
    }
    catch {
        Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to re-align overview truth-pack to canonical" -Details @{ exception = $_.Exception.Message }
        Write-Warning ("Failed to re-align overview truth-pack to canonical: {0}" -f $_.Exception.Message)
    }

    # start-here.md carries "API endpoints documented: N" / "Data models documented: M"
    # signal lines. generate-start-here.ps1 ran earlier (before the classic-ASP
    # endpoint/model evidence was populated), so on classic-ASP targets those lines are
    # stale at 0 while the canonical + evidence hold the real counts. Now that the
    # evidence and canonical metrics are complete, re-run the start-here generator so its
    # counts reflect the populated evidence (it derives counts from the same evidence
    # records the gate cross-checks, so this makes start-here consistent and is a
    # no-op when the counts already agree).
    $startHereGenerator = Join-Path $PSScriptRoot "generate-start-here.ps1"
    if (Test-Path $startHereGenerator) {
        try {
            & $startHereGenerator -RootPath $RootPath
            Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Start-here re-generated with populated classic-ASP evidence" -Component "Generation" -FilePath (Join-Path $docsPath "start-here.md")
        }
        catch {
            Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to re-generate start-here" -Details @{ exception = $_.Exception.Message }
            Write-Warning ("Failed to re-generate start-here: {0}" -f $_.Exception.Message)
        }
    }
}

$integrityGateScriptPath = Join-Path $PSScriptRoot "ci-doc-integrity-gate.ps1"
if (Test-Path $integrityGateScriptPath) {
    Write-Host "`n[Integrity Gate]" -ForegroundColor Cyan
    Write-Host "Running ci-doc-integrity-gate.ps1..."
    & $integrityGateScriptPath -RootPath $RootPath
    $integrityExitCode = $LASTEXITCODE
    if ($integrityExitCode -ne 0) {
        $severity = if ($StrictValidation) { "Error" } else { "Warning" }
        Add-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity $severity -Message "Documentation integrity gate failed" -Component "Validation" -FilePath $integrityGateScriptPath -Details @{ exitCode = $integrityExitCode }
        if ($StrictValidation) {
            throw "Documentation integrity gate failed with exit code $integrityExitCode."
        }
        Write-Warning "Documentation integrity gate failed (soft mode)."
        $global:LASTEXITCODE = 0
    }
    else {
        Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Documentation integrity gate passed" -Component "Validation" -FilePath $integrityGateScriptPath
        $global:LASTEXITCODE = 0
    }
}
else {
    Add-AppDocDiagnostic -Category "IO_ERROR" -Severity "Info" -Message "Documentation integrity gate script not found; skipping integrity gate" -Component "Validation" -FilePath $integrityGateScriptPath
}

Write-Host "`n=== Documentation Quality Report ===" -ForegroundColor Cyan

# Validate all generated documents
$validationResults = @()
$validationExpectations = Get-AppDocValidationExpectations -RootPath $RootPath -ArchitectureFingerprint $architectureFingerprint
Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Validation expectations computed" -Component "Validation" -Details @{
    primaryStyle = [string](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "primaryStyle" -Default "")
    apiSurfaceExpected = [bool](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "apiSurfaceExpected" -Default $true)
    allowNoApiSurface = [bool](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "allowNoApiSurface" -Default $false)
    allowNoModelSurface = [bool](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "allowNoModelSurface" -Default $false)
    dependencySurfaceExpected = [bool](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "dependencySurfaceExpected" -Default $true)
    testSurfaceExpected = [bool](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "testSurfaceExpected" -Default $true)
    allowNoDependencySurface = [bool](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "allowNoDependencySurface" -Default $false)
    allowNoTestSurface = [bool](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "allowNoTestSurface" -Default $false)
    allowNoDebtSurface = [bool](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "allowNoDebtSurface" -Default $false)
    endpointRecordCount = [int](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "endpointRecordCount" -Default 0)
    modelRecordCount = [int](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "modelRecordCount" -Default 0)
    dependencyRecordCount = [int](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "dependencyRecordCount" -Default 0)
    testRecordCount = [int](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "testRecordCount" -Default 0)
    debtRecordCount = [int](Get-AppDocValidationObjectValue -Object $validationExpectations -Name "debtRecordCount" -Default 0)
}

$documents = @(
    @{ File = "overview.md"; Type = "Overview" }
    @{ File = "api-inventory.md"; Type = "API Inventory" }
    @{ File = "data-model.md"; Type = "Data Model" }
    @{ File = "config-catalog.md"; Type = "Config Catalog" }
    @{ File = "build-cookbook.md"; Type = "Build Cookbook" }
    @{ File = "test-catalog.md"; Type = "Test Catalog" }
    @{ File = "debt-register.md"; Type = "Debt Register" }
    @{ File = "dependencies-catalog.md"; Type = "Dependencies Catalog" }
    # Navigational artifacts produced by the default pipeline. They are validated
    # below (so the quality report reflects everything the pipeline produces) but
    # are NOT scored in the pass/fail gate (Gated = $false). Reason: task-guides can
    # be thin/empty on small codebases and index.md is a link list, so including them
    # in the gate would add noise. The authoritative pass/fail boundary is
    # validate-documentation.ps1's fixed 15-component composite, which is unchanged by
    # producing these artifacts.
    @{ File = "start-here.md"; Type = "Start Here"; Gated = $false }
    @{ File = "task-guides.md"; Type = "Task Guides"; Gated = $false }
    @{ File = "index.md"; Type = "Documentation Index"; Gated = $false }
)

foreach ($doc in $documents) {
    $filePath = Join-Path $docsPath $doc.File
    $result = Test-GeneratedDoc -FilePath $filePath -DocType $doc.Type -Expectations $validationExpectations
    # Carry the gate flag through (Test-GeneratedDoc returns a plain hashtable).
    # Contract artifacts default to Gated = $true; the 3 navigational ones are $false.
    $result["gated"] = [bool]($doc.Gated ?? $true)
    $validationResults += $result
}

# Pass/fail gate anchor: only the contract artifacts (gated = $true) feed the inline
# Test-AppDocValidationGate, matching validate-documentation.ps1's fixed composite.
# The 3 navigational artifacts stay informational (reported above, excluded here).
$gatedValidationResults = @($validationResults | Where-Object { [bool]$_.gated })

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
$highQuality = (@($validationResults | Where-Object { ([string]$_.quality).Trim().ToUpperInvariant() -eq "HIGH" })).Count
$mediumQuality = (@($validationResults | Where-Object { ([string]$_.quality).Trim().ToUpperInvariant() -eq "MEDIUM" })).Count
$lowQuality = (@($validationResults | Where-Object { ([string]$_.quality).Trim().ToUpperInvariant() -eq "LOW" })).Count
$missingDocs = (@($validationResults | Where-Object { ([string]$_.quality).Trim().ToUpperInvariant() -eq "MISSING" })).Count
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

# Save quality report JSON (written after structured validation is merged)
$qualityReportPath = Join-Path $docsPath "quality-report.json"
$reportData = @{
    timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    overall = @{
        totalDocs = $totalDocs
        highQuality = $highQuality
        mediumQuality = $mediumQuality
        lowQuality = $lowQuality
        missingDocs = $missingDocs
        averageScore = $avgScore
        adjustedAverageScore = $avgScore
        hardPenaltyApplied = $false
        hardPenaltyReasons = @()
    }
    documents = $validationResults
    status = "pass"
    penaltyBreakdown = @{}
}

# Stamp root provenance on the generated artifacts BEFORE structured validation runs.
# The provenance-missing policy gate requires every critical artifact to carry a
# Provenance footer (Generator Version / Commit Hash / Generated At / Profile / Scope /
# Confidence-flags). Stamping happens here, right after generation, so the validation
# gate can verify it. The trailing re-application further down refreshes the timestamp
# to the final run moment for the committed reports (idempotent; content is identical).
try {
    $provenanceProfileEarly = if ($activeProfile) { [string]$activeProfile.profile } else { [string]$Profile }
    Set-AppDocRootProvenance -RootPath $RootPath -DocsPath $docsPath -Profile $provenanceProfileEarly
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Root artifact provenance applied pre-validation" -Component "Generation" -FilePath $docsPath
}
catch {
    Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to apply pre-validation provenance" -Component "Generation" -Details @{ exception = $_.Exception.Message }
}

# --- LAST GENERATOR: branded MD -> styled-HTML report -------------------------
# Runs after all content + evidence + verification artifacts exist (and after the
# early provenance stamp) and before structured validation, so report.html always
# reflects the latest content. Failure is non-fatal (HTML is a presentation layer;
# it must not block the deterministic docs or the conformance gate).
$htmlReportScriptPath = Join-Path $PSScriptRoot "generate-html-report.ps1"
if (Test-Path $htmlReportScriptPath) {
    if ($DryRun) {
        Write-Host "[DryRun] Would execute generate-html-report.ps1" -ForegroundColor Gray
        Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Dry run skipped HTML report generation" -Component "Generation" -FilePath $htmlReportScriptPath
    }
    else {
        try {
            & $htmlReportScriptPath -RootPath $RootPath
        }
        catch {
            Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to generate HTML report: $_" -Component "Generation" -FilePath $htmlReportScriptPath -Details @{ exception = $_.Exception.Message }
            Write-Warning "Failed to generate HTML report: $_"
        }
    }
}
else {
    Write-Verbose "HTML report generator not found (optional feature): $htmlReportScriptPath"
}

$structuredValidationPath = Join-Path $PSScriptRoot "validate-documentation.ps1"
$structuredValidationResult = $null
if (Test-Path $structuredValidationPath) {
    try {
        $structuredValidationOutput = if ($StrictValidation) {
            & $structuredValidationPath -RootPath $RootPath -Strict -Threshold $QualityThreshold -Json -PristineGate:$PristineGate -PristineFloor $PristineFloor
        }
        else {
            & $structuredValidationPath -RootPath $RootPath -Threshold $QualityThreshold -Json -PristineGate:$PristineGate -PristineFloor $PristineFloor
        }

        $structuredValidationText = ($structuredValidationOutput | Out-String).Trim()
        if ($structuredValidationText) {
            # Use last standalone '{' line to skip any preceding non-JSON output
            $jsonStarts = [regex]::Matches($structuredValidationText, '(?m)^\{\s*')
            # Fallback: use last opening brace if no regex match (to match intended 'last brace' behavior)
            $jsonStartIndex = if ($jsonStarts.Count -gt 0) { $jsonStarts[$jsonStarts.Count - 1].Index } else { $structuredValidationText.LastIndexOf('{') }
            if ($jsonStartIndex -ge 0) {
                # The -Json switch emits the verdict object as the TRAILING success-stream
                # output (any progress prose precedes it). So the verdict JSON runs from the
                # last '{'-line to the end of the string — no brace matching needed. (The
                # former brace-depth counter was brittle: it mis-counted braces inside string
                # literals. Trailing-substring is robust and byte-identical on real output.)
                $structuredValidationJson = $structuredValidationText.Substring($jsonStartIndex)
                $structuredValidationResult = $structuredValidationJson | ConvertFrom-Json
                Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Structured validation completed" -Component "Validation"
            } else {
                throw "Structured validation did not produce a parseable JSON payload."
            }
        }
    }
    catch {
        Add-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Structured validation reported issues" -Component "Validation" -Details @{ exception = $_.Exception.Message }
    }
}

# --- PRISTINE CHECK report (Step 1b) -----------------------------------------
# Non-blocking, additive: runs AFTER the pipeline + gate (so it reads the composed
# doc + the gate scorecard) and writes docs/pristine-report.md + the machine record
# docs/evidence/pristine.evidence.json. It is a DEPTH measurement of the 20 composed
# sections vs the HELP_DESK benchmark. The additive `pristine` sub-score is folded
# into docs/validation-report.json by validate-documentation.ps1 itself (after
# status/overallScore are frozen), so emitting the human-readable report here cannot
# change status (pass/fail) or overallScore. Failure is non-fatal (the report is a
# presentation/depth layer; it must not block the deterministic docs or the gate).
$pristineReportScriptPath = Join-Path $PSScriptRoot "generate-pristine-report.ps1"
if (Test-Path $pristineReportScriptPath) {
    if ($DryRun) {
        Write-Host "[DryRun] Would execute generate-pristine-report.ps1" -ForegroundColor Gray
        Add-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Info" -Message "Dry run skipped pristine report generation" -Component "Validation" -FilePath $pristineReportScriptPath
    }
    else {
        try {
            & $pristineReportScriptPath -RootPath $RootPath
            Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Pristine check report generated (non-blocking depth measurement)" -Component "Validation" -FilePath $pristineReportScriptPath
        }
        catch {
            Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to generate pristine report: $_" -Component "Validation" -FilePath $pristineReportScriptPath
            Write-Warning "Failed to generate pristine report: $_"
        }
    }
}
else {
    Write-Verbose "Pristine report generator not found (optional feature): $pristineReportScriptPath"
}

if ($structuredValidationResult) {
    $reportData.status = if ($structuredValidationResult.status) { [string]$structuredValidationResult.status } else { "pass" }
    if ($structuredValidationResult.qualityPenaltyBreakdown) {
        $reportData.penaltyBreakdown = $structuredValidationResult.qualityPenaltyBreakdown
    }

    $hardPenaltyReasons = @()
    $contradictionIssues = @($structuredValidationResult.contradictions)
    if (@($contradictionIssues | Where-Object { [string]$_ -match '^architecture-contradiction:' }).Count -gt 0) {
        $hardPenaltyReasons += "architecture-contradiction"
    }

    $adjustedScore = [double]$avgScore
    if ($structuredValidationResult.overallScore -ne $null) {
        $adjustedScore = [double]$structuredValidationResult.overallScore
    }

    $reportData.overall.adjustedAverageScore = [Math]::Round($adjustedScore, 1)
    $reportData.overall.hardPenaltyApplied = ($hardPenaltyReasons.Count -gt 0)
    $reportData.overall.hardPenaltyReasons = @($hardPenaltyReasons)
}

$reportData | ConvertTo-Json -Depth 20 | Out-File -FilePath $qualityReportPath -Encoding UTF8
Write-Host "`n📄 Quality report saved: $qualityReportPath" -ForegroundColor Cyan

$narrativeReviewRequired = $false
$narrativeReviewReasons = @()
$narrativeRunReportPath = Join-Path $docsPath "evidence\narrative-run-report.json"
if (Test-Path $narrativeRunReportPath) {
    try {
        $narrativeRunReport = Get-Content $narrativeRunReportPath -Raw | ConvertFrom-Json
        if ($null -ne $narrativeRunReport.narrativeReviewRequired) {
            $narrativeReviewRequired = [bool]$narrativeRunReport.narrativeReviewRequired
        }

        if ($null -ne $narrativeRunReport.grounding -and $narrativeRunReport.grounding.issues) {
            $narrativeReviewReasons += @($narrativeRunReport.grounding.issues | ForEach-Object { [string]$_ })
        }
        if ($null -ne $narrativeRunReport.sectionCoverage -and $narrativeRunReport.sectionCoverage.issues) {
            $narrativeReviewReasons += @($narrativeRunReport.sectionCoverage.issues | ForEach-Object { [string]$_ })
        }
        if ($null -ne $narrativeRunReport.styleGate -and $narrativeRunReport.styleGate.issues) {
            $narrativeReviewReasons += @($narrativeRunReport.styleGate.issues | ForEach-Object { [string]$_ })
        }
        $narrativeReviewReasons = @($narrativeReviewReasons | Select-Object -Unique)

        if ($narrativeReviewRequired) {
            Add-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Narrative review required by overview pipeline gates" -Component "Narrative" -FilePath $narrativeRunReportPath -Details @{ reasons = $narrativeReviewReasons }
            Write-Host "⚠️ Narrative review required (overview narrative gates)." -ForegroundColor Yellow
        }
    }
    catch {
        Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to parse narrative run report" -Component "Narrative" -FilePath $narrativeRunReportPath -Details @{ exception = $_.Exception.Message }
    }
}

$validationGate = $null
if (Get-Command Test-AppDocValidationGate -ErrorAction SilentlyContinue) {
    $validationGate = Test-AppDocValidationGate -ValidationResults $gatedValidationResults -QualityThreshold $QualityThreshold -Strict:$StrictValidation

    if ($structuredValidationResult) {
        $scorePass = ([double]$structuredValidationResult.overallScore -ge [double]$QualityThreshold)
        $policyPass = $true
        if ($null -ne $structuredValidationResult.policyGates -and $null -ne $structuredValidationResult.policyGates.passed) {
            $policyPass = [bool]$structuredValidationResult.policyGates.passed
        }
        # Pristine gate (Deliverable B, OPT-IN): when -PristineGate is ON (blocking mode)
        # and the pure decision blocked the run (pristineGate.blocked=true), the
        # structured pass must FAIL so the run's gate reflects the block. This is
        # ADDITIVE — the pristine gate is a separate condition layered on top; in the
        # DEFAULT (report-only, gate OFF) pristineGate.blocked=false so this is $true and
        # the structural conformance pass/fail is UNCHANGED.
        $pristineGatePass = $true
        if ($null -ne $structuredValidationResult.pristineGate -and $null -ne $structuredValidationResult.pristineGate.blocked) {
            $pristineGatePass = -not [bool]$structuredValidationResult.pristineGate.blocked
        }
        $structuredPass = ($scorePass -and $policyPass -and $pristineGatePass)
        $validationGate = [ordered]@{
            passed = $structuredPass
            reason = if ($structuredPass) { "Structured validation gate passed" } elseif (-not $pristineGatePass) { "Pristine gate blocked the run (mode=blocking, OPT-IN -PristineGate)" } else { "Structured validation gate failed (score and/or policy gates)" }
            averageScore = [double]$structuredValidationResult.overallScore
            belowThreshold = if ($structuredPass) { 0 } else { 1 }
            strict = $StrictValidation.IsPresent
            qualityThreshold = $QualityThreshold
            evaluatedDocuments = if ($structuredValidationResult.validators) { @($structuredValidationResult.validators).Count } else { 0 }
        }
    }

    Write-Host "`nValidation Gate:" -ForegroundColor Cyan
    $modeString = if ($StrictValidation) { 'Strict' } else { 'Soft' }
    Write-Host "  Mode: $modeString" -ForegroundColor White
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
    $frameworkNames = @(Get-AppDocFrameworkNames -DetectedFrameworks $detectedFrameworks)
    $metadata = @{
        rootPath = $RootPath
        outputPath = $docsPath
        strictValidation = $StrictValidation.IsPresent
        qualityThreshold = $QualityThreshold
        validationGate = $validationGate
        profile = if ($activeProfile) { $activeProfile.profile } else { $Profile }
        localOnly = $true
        frameworks = $frameworkNames
        architecture = if ($architectureFingerprint) { $architectureFingerprint } else { $null }
        scriptFailures = @($scriptFailures)
        narrativeReviewRequired = $narrativeReviewRequired
        narrativeReviewReasons = @($narrativeReviewReasons)
        narrativeRunReportPath = if (Test-Path $narrativeRunReportPath) { $narrativeRunReportPath } else { "" }
        evidenceGraphPath = if ($evidenceGraphPath) { $evidenceGraphPath } else { "" }
        evidenceGraphMetrics = if ($evidenceGraphMetrics) { $evidenceGraphMetrics } else { $null }
        evidenceGraphIntegrity = if ($evidenceGraphIntegrity) { $evidenceGraphIntegrity } else { $null }
    }
    Export-AppDocDiagnostics -Path $diagnosticsPath -AdditionalData $metadata | Out-Null
    Write-Host "📄 Diagnostics report saved: $diagnosticsPath" -ForegroundColor Cyan
}

try {
    $provenanceProfile = if ($activeProfile) { [string]$activeProfile.profile } else { [string]$Profile }
    Set-AppDocRootProvenance -RootPath $RootPath -DocsPath $docsPath -Profile $provenanceProfile
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "Root artifact provenance applied" -Component "Generation" -FilePath $docsPath
}
catch {
    Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to apply provenance" -Component "Generation" -Details @{ exception = $_.Exception.Message }
    Write-Warning ("Failed to apply root provenance: {0}" -f $_.Exception.Message)
}

try {
    Write-AppDocJsonCompanionSummaries -DocsPath $docsPath
    Add-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "JSON companion summaries generated" -Component "Generation" -FilePath (Join-Path $docsPath "evidence")
}
catch {
    Add-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Failed to generate JSON companion summaries" -Component "Generation" -Details @{ exception = $_.Exception.Message }
    Write-Warning ("Failed to generate JSON companion summaries: {0}" -f $_.Exception.Message)
}

# Exit with warning if majority are low quality
if ($lowQuality -gt ($totalDocs / 2)) {
    Write-Host "`n⚠️  WARNING: More than 50% of documentation is LOW quality!" -ForegroundColor Red
    Write-Host "   Consider running AppDoc enhancement workflow or manual review." -ForegroundColor Yellow
}

if ($scriptFailures.Count -gt 0) {
    Write-Host "`n⚠️  Script failures detected: $($scriptFailures.Count)" -ForegroundColor Yellow
    foreach ($failure in $scriptFailures) {
        Write-Host "   - [$($failure.phase)] $($failure.script): $($failure.error)" -ForegroundColor DarkYellow
    }
}

Write-Host "`nAll generators completed." -ForegroundColor Green
Write-Host "Next step: bootstrap enriched evidence with run-appdoc-enrich.ps1." -ForegroundColor Cyan
Write-Host "  pwsh ./.appdoc/scripts/powershell/run-appdoc-enrich.ps1 -RootPath \"$RootPath\"" -ForegroundColor Gray
Write-Host "After enrichment, run /appdoc.enhance for editorial polish." -ForegroundColor Cyan

if (-not $DryRun) {
    Remove-Item -Path $runSessionPath -Force -ErrorAction SilentlyContinue
}

if ($StrictValidation -and $validationGate -and -not $validationGate.passed) {
    exit 1
}

# Pristine gate block (Deliverable B, OPT-IN): when -PristineGate is ON (blocking mode)
# and the pure decision blocked the run, exit 1 — the pristine gate is a NEW, ADDITIVE,
# opt-in blocking condition layered on top of the structural conformance pass/fail.
# Default (report-only, gate OFF) NEVER reaches here (pristineGate.blocked=false).
if ($PristineGate -and $structuredValidationResult -and $structuredValidationResult.pristineGate -and [bool]$structuredValidationResult.pristineGate.blocked) {
    Write-Host "`n🚫 Pristine gate BLOCKED the run (mode=blocking; OPT-IN -PristineGate)." -ForegroundColor Red
    $pgIssueSummary = (@($structuredValidationResult.pristineGate.blockingIssues) -join "; ")
    Write-Host "   Reason: $pgIssueSummary" -ForegroundColor DarkYellow
    Write-Host "   The pristine gate is a DEPTH gate: it does not change overallScore (structural conformance untouched)." -ForegroundColor Gray
    exit 1
}
