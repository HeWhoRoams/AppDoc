param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [switch]$Strict,
    [ValidateRange(1,100)]
    [int]$Threshold = 80,
    [switch]$Json,
    # --- PRISTINE GATE (Deliverable B) — OPT-IN, default OFF ------------------
    # -PristineGate OFF (DEFAULT): report-only — the pristine check is a DEPTH
    #   measurement that NEVER blocks; pristineGate.enabled=false.
    # -PristineGate ON (OPT-IN): the pristine check becomes a real gate that BLOCKS
    #   the run when any section is EMPTY (emptyCount>0) OR pristine subScore < floor.
    #   OWNER_REQUIRED cells are EXCLUDED (pending /appdoc.enhance, not failures).
    # -PristineFloor: the floor the pristine sub-score must meet (default 80).
    [switch]$PristineGate,
    [ValidateRange(1,100)]
    [int]$PristineFloor = 80
)

$diagnosticsModule = Join-Path $PSScriptRoot "modules\AppDoc.Diagnostics.psm1"
$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
$validationCoreModule = Join-Path $PSScriptRoot "modules\AppDoc.Validation.Core.psm1"
$architectureModule = Join-Path $PSScriptRoot "modules\AppDoc.ArchitectureFingerprint.psm1"

# Required modules - fail fast if any are missing
if (-not (Test-Path $diagnosticsModule)) {
    Write-Error "Required module not found: $diagnosticsModule"
    exit 1
}
Import-Module $diagnosticsModule -Force -ErrorAction Stop

if (-not (Test-Path $scopeModule)) {
    Write-Error "Required module not found: $scopeModule"
    exit 1
}
Import-Module $scopeModule -Force -ErrorAction Stop

if (-not (Test-Path $contractsModule)) {
    Write-Error "Required module not found: $contractsModule"
    exit 1
}
Import-Module $contractsModule -Force -ErrorAction Stop

if (-not (Test-Path $validationCoreModule)) {
    Write-Error "Required module not found: $validationCoreModule"
    exit 1
}
Import-Module $validationCoreModule -Force -ErrorAction Stop

if (Test-Path $architectureModule) {
    Import-Module $architectureModule -Force -ErrorAction Stop
}

$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }

# Epistemic-tagging library (deterministic claim-status resolution + coverage).
# Used by the conformance gate's three discipline sub-checks. Absent on older
# checkouts is non-fatal: the sub-checks degrade to 0 and are reported.
$epistemicModule = Join-Path $PSScriptRoot "modules\AppDoc.Epistemic.psm1"
if (Test-Path $epistemicModule) {
    Import-Module $epistemicModule -Force -ErrorAction SilentlyContinue
}

# Pristine-check library (Step 1b). Pure, deterministic per-section rubric that
# scores the 20 composed sections against the HELP_DESK benchmark. It is imported
# here to add a NON-BLOCKING, ADDITIVE `pristine` sub-score to the scorecard
# (reported in docs/validation-report.json). It NEVER changes status (pass/fail)
# or overallScore — the structural conformance composite below is untouched.
$pristineModule = Join-Path $PSScriptRoot "modules\AppDoc.Pristine.psm1"
$hasPristine = $false
if (Test-Path $pristineModule) {
    try { Import-Module $pristineModule -Force -ErrorAction SilentlyContinue; $hasPristine = (Get-Command Get-AppDocPristineAssessment -ErrorAction SilentlyContinue) -ne $null } catch { $hasPristine = $false }
}

$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) {
    Write-Error "docs directory not found: $docsPath"
    exit 1
}

if (Get-Command Initialize-AppDocDiagnostics -ErrorAction SilentlyContinue) {
    Initialize-AppDocDiagnostics -RootPath $RootPath -OutputPath $docsPath -Reset
}

$artifactFiles = @(Get-AppDocValidationArtifacts)

$missing = @()
foreach ($artifact in $artifactFiles) {
    $path = Join-Path $docsPath $artifact
    if (-not (Test-Path $path)) {
        $missing += $artifact
        Write-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Warning" -Message "Artifact missing: $artifact" -Component "validation" -FilePath $path | Out-Null
    }
}

$expectedEvidenceArtifacts = @(Get-AppDocValidationEvidenceArtifacts)

$evidenceRoot = Join-Path $docsPath "evidence"
$manifestPath = Join-Path $evidenceRoot "manifest.json"
$missingEvidence = @()
$evidenceIndex = @{}

if (Test-Path $manifestPath) {
    try {
        $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json
        foreach ($item in @($manifest.artifacts)) {
            if ($null -ne $item -and $item.artifact) {
                $evidenceIndex[[string]$item.artifact] = $item
            }
        }
    }
    catch {
        Write-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Evidence manifest is invalid JSON" -Component "validation" -FilePath $manifestPath -Details @{ exception = $_.Exception.Message } | Out-Null
    }
}
else {
    Write-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Warning" -Message "Evidence manifest missing" -Component "validation" -FilePath $manifestPath | Out-Null
}

foreach ($artifact in $expectedEvidenceArtifacts) {
    $evidencePath = Join-Path $evidenceRoot ("{0}.evidence.json" -f $artifact)

    if ($evidenceIndex.ContainsKey($artifact)) {
        $manifestEntry = $evidenceIndex[$artifact]
        if ($manifestEntry.path) {
            $candidate = [string]$manifestEntry.path
            if ([System.IO.Path]::IsPathRooted($candidate)) {
                $evidencePath = $candidate
            }
            else {
                $evidencePath = Join-Path $RootPath $candidate
            }
        }
    }

    if (-not (Test-Path $evidencePath)) {
        $missingEvidence += $artifact
        Write-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Warning" -Message "Evidence missing: $artifact" -Component "validation" -FilePath $evidencePath | Out-Null
    }
}

$validatorScripts = @(Get-AppDocValidatorScripts)

$artifactMap = @{
    "overview" = "overview.md"
    "api-inventory" = "api-inventory.md"
    "data-model" = "data-model.md"
    "config-catalog" = "config-catalog.md"
    "build-cookbook" = "build-cookbook.md"
    "test-catalog" = "test-catalog.md"
    "debt-register" = "debt-register.md"
    "dependencies-catalog" = "dependencies-catalog.md"
}

function Get-AppDocValidationContentValue {
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

function Get-AppDocValidationContentExpectations {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$DocsPath
    )

    $overviewTruthPath = Join-Path $DocsPath "evidence\overview-truth-pack.json"
    $overviewTruth = $null
    if (Test-Path $overviewTruthPath) {
        try {
            $overviewTruth = Get-Content $overviewTruthPath -Raw | ConvertFrom-Json -Depth 80
        }
        catch {
            $overviewTruth = $null
        }
    }

    $apiCount = 0
    $modelCount = 0
    $dependencyCount = 0
    $testRecordCount = 0
    $debtRecordCount = 0
    if ($overviewTruth -and $overviewTruth.counts) {
        $apiCount = [int]($overviewTruth.counts.endpointRecords ?? 0)
        $modelCount = [int]($overviewTruth.counts.modelRecords ?? 0)
        $dependencyCount = [int]($overviewTruth.counts.dependencyRecords ?? 0)
    }

    $dependencyEvidencePath = Join-Path $DocsPath "evidence\dependencies-catalog.evidence.json"
    if ($dependencyCount -eq 0 -and (Test-Path $dependencyEvidencePath)) {
        try {
            $dependencyPayload = Get-Content $dependencyEvidencePath -Raw | ConvertFrom-Json -Depth 80
            $dependencyCount = @($dependencyPayload.records | Where-Object { $_ -and [string]$_.kind -eq "dependency" }).Count
        }
        catch {
            $dependencyCount = 0
        }
    }

    $testEvidencePath = Join-Path $DocsPath "evidence\test-catalog.evidence.json"
    if (Test-Path $testEvidencePath) {
        try {
            $testPayload = Get-Content $testEvidencePath -Raw | ConvertFrom-Json -Depth 80
            $testRecordCount = @($testPayload.records | Where-Object { $_ -and [string]$_.kind -in @("test-case","test-suite") }).Count
        }
        catch {
            $testRecordCount = 0
        }
    }

    $debtEvidencePath = Join-Path $DocsPath "evidence\debt-register.evidence.json"
    if (Test-Path $debtEvidencePath) {
        try {
            $debtPayload = Get-Content $debtEvidencePath -Raw | ConvertFrom-Json -Depth 80
            $debtRecordCount = @($debtPayload.records | Where-Object { $_ -and [string]$_.kind -in @("technical-debt","debt-item") }).Count
        }
        catch {
            $debtRecordCount = 0
        }
    }

    $architectureFingerprint = $null
    if (Get-Command Get-AppDocArchitectureFingerprint -ErrorAction SilentlyContinue) {
        $architectureFingerprint = Get-AppDocArchitectureFingerprint -RootPath $RootPath
    }

    $primaryStyle = if ($architectureFingerprint -and $architectureFingerprint.primaryStyle) { [string]$architectureFingerprint.primaryStyle } else { "" }
    if ([string]::IsNullOrWhiteSpace($primaryStyle) -and $overviewTruth -and $overviewTruth.architecture -and $overviewTruth.architecture.primaryStyle) {
        $primaryStyle = [string]$overviewTruth.architecture.primaryStyle
    }

    $apiSurfaceExpected = $true
    if ($architectureFingerprint -and $null -ne $architectureFingerprint.apiSurfaceExpected) {
        $apiSurfaceExpected = [bool]$architectureFingerprint.apiSurfaceExpected
    }
    elseif ($primaryStyle -eq "no-api-surface") {
        $apiSurfaceExpected = $false
    }

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
                }
        )
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
    $debtExtensions = @("*.js","*.ts","*.cs","*.py","*.java","*.go","*.rb","*.php","*.kt","*.kts","*.swift")
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        $debtSignalCandidates = @(
            Get-AppDocSourceFiles -RootPath $RootPath -Artifact "debt-register" -Include $debtExtensions
        )
    }
    else {
        $debtSignalCandidates = @(
            Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include $debtExtensions -ErrorAction SilentlyContinue
        )
    }
    $debtSignalCount = 0
    foreach ($file in @($debtSignalCandidates | Select-Object -First 300)) {
        if ((Get-Item $file.FullName).Length -gt 1MB) { continue }
        try {
            Get-Content -Path $file.FullName -ErrorAction SilentlyContinue | ForEach-Object {
                $debtSignalCount += ([regex]::Matches($_, '(?im)\b(TODO|FIXME|HACK|XXX)\b')).Count
            }
        } catch {}
    }

    $dependencySurfaceExpected = ($dependencyCount -gt 0 -or $dependencySignalCount -gt 0)
    $testSurfaceExpected = ($testRecordCount -gt 0 -or $testSignalCount -gt 0)
    $debtSurfaceExpected = ($debtRecordCount -gt 0 -or $debtSignalCount -gt 0)
    $allowNoDependencySurface = (-not $dependencySurfaceExpected) -and ($dependencyCount -eq 0)
    $allowNoTestSurface = (-not $testSurfaceExpected) -and ($testRecordCount -eq 0)
    $allowNoDebtSurface = (-not $debtSurfaceExpected) -and ($debtRecordCount -eq 0)

    return [ordered]@{
        primaryStyle = $primaryStyle
        apiSurfaceExpected = [bool]$apiSurfaceExpected
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

$script:AppDocValidationContentExpectations = Get-AppDocValidationContentExpectations -RootPath $RootPath -DocsPath $docsPath

function Test-ArtifactContractSections {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Artifact,
        [Parameter(Mandatory=$true)]
        [string]$DocPath
    )

    $contract = Get-AppDocArtifactContract -Artifact $Artifact
    if (-not $contract) {
        return [ordered]@{ artifact = $Artifact; passed = $false; score = 0; missingSections = @("contract-not-found"); bannedPatterns = @() }
    }

    if (-not (Test-Path $DocPath)) {
        return [ordered]@{ artifact = $Artifact; passed = $false; score = 0; missingSections = @("document-not-found"); bannedPatterns = @() }
    }

    $content = Get-Content $DocPath -Raw
    $missingSections = @()
    $allowNoApiSurface = [bool]($script:AppDocValidationContentExpectations.allowNoApiSurface ?? $false)
    $allowNoModelSurface = [bool]($script:AppDocValidationContentExpectations.allowNoModelSurface ?? $false)
    $allowNoDependencySurface = [bool]($script:AppDocValidationContentExpectations.allowNoDependencySurface ?? $false)
    $allowNoTestSurface = [bool]($script:AppDocValidationContentExpectations.allowNoTestSurface ?? $false)
    $allowNoDebtSurface = [bool]($script:AppDocValidationContentExpectations.allowNoDebtSurface ?? $false)
    foreach ($requiredSection in @($contract.requiredSections)) {
        if (-not ([regex]::IsMatch($content, "(?im)^##\s+" + [regex]::Escape([string]$requiredSection) + "\b"))) {
            $missingSections += [string]$requiredSection
            Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Required section missing ($Artifact): $requiredSection" -Component "validation" -FilePath $DocPath | Out-Null
        }
    }

    $bannedHits = @()
    # Map artifact to allow flag variable
    $artifactAllowMap = @{
        'api-inventory'      = $allowNoApiSurface
        'data-model'         = $allowNoModelSurface
        'test-catalog'       = $allowNoTestSurface
        'dependencies-catalog' = $allowNoDependencySurface
        'debt-register'      = $allowNoDebtSurface
    }
    foreach ($pattern in @(Get-AppDocBannedContentPatterns)) {
        $allowFlag = $artifactAllowMap[$Artifact]
        if ($allowFlag -and $pattern -match '(?i)_No .* detected') {
            continue
        }
        if ([regex]::IsMatch($content, $pattern)) {
            $bannedHits += $pattern
            Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Banned placeholder pattern found ($Artifact)" -Component "validation" -FilePath $DocPath -Details @{ pattern = $pattern } | Out-Null
        }
    }

    $score = 100
    $score -= ($missingSections.Count * 20)
    $score -= ($bannedHits.Count * 10)
    $score = [Math]::Max(0, $score)

    return [ordered]@{
        artifact = $Artifact
        passed = ($missingSections.Count -eq 0 -and $bannedHits.Count -eq 0)
        score = $score
        missingSections = $missingSections
        bannedPatterns = $bannedHits
    }
}

function Convert-RequiredKeyToKinds {
    param([string]$Key)

    $map = @{
        "endpoints" = @("endpoint")
        "models" = @("model")
        "configurations" = @("configuration")
        "commands" = @("command", "build-command")
        "testsuites" = @("test-suite", "test-case")
        "debtitems" = @("technical-debt", "debt-item")
        "dependencies" = @("dependency")
        "tasks" = @("task-guide", "task")
        "summary" = @("summary")
        "technologies" = @("technology")
    }

    $keyNorm = ($Key -replace '\s', '').ToLowerInvariant()
    if ($map.ContainsKey($keyNorm)) {
        return @($map[$keyNorm])
    }

    $kinds = @($keyNorm)
    if ($keyNorm.EndsWith("ies")) {
        $kinds += ($keyNorm.Substring(0, $keyNorm.Length - 3) + "y")
    }
    elseif ($keyNorm.EndsWith("s")) {
        $kinds += $keyNorm.Substring(0, $keyNorm.Length - 1)
    }

    return @($kinds | Select-Object -Unique)
}

function Test-ArtifactEvidenceContract {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Artifact,
        [Parameter(Mandatory=$true)]
        [string]$EvidencePath
    )

    $contract = Get-AppDocArtifactContract -Artifact $Artifact
    if (-not $contract) {
        return [ordered]@{ artifact = $Artifact; passed = $false; score = 0; issues = @("contract-not-found") }
    }

    if (-not (Test-Path $EvidencePath)) {
        return [ordered]@{ artifact = $Artifact; passed = $false; score = 0; issues = @("evidence-not-found") }
    }

    try {
        $evidence = Get-Content $EvidencePath -Raw | ConvertFrom-Json
    }
    catch {
        return [ordered]@{ artifact = $Artifact; passed = $false; score = 0; issues = @("evidence-invalid-json") }
    }

    $issues = @()
    $metaKeys = @()
    $metaSections = @()

    if ($evidence.metadata -and $evidence.metadata.requiredEvidenceKeys) {
        $metaKeys = @($evidence.metadata.requiredEvidenceKeys | ForEach-Object { [string]$_ })
    }
    if ($evidence.metadata -and $evidence.metadata.requiredSections) {
        $metaSections = @($evidence.metadata.requiredSections | ForEach-Object { [string]$_ })
    }

    foreach ($requiredKey in @($contract.requiredEvidenceKeys)) {
        if (-not ($metaKeys -contains [string]$requiredKey)) {
            $issues += "missing-metadata-requiredEvidenceKey:$requiredKey"
        }
    }
    foreach ($requiredSection in @($contract.requiredSections)) {
        if (-not ($metaSections -contains [string]$requiredSection)) {
            $issues += "missing-metadata-requiredSection:$requiredSection"
        }
    }

    $records = @($evidence.records)
    if ($records.Count -gt 0) {
        $recordKinds = @($records | ForEach-Object { [string]$_.kind } | Where-Object { $_ } | ForEach-Object { $_.ToLowerInvariant() })
        foreach ($requiredKey in @($contract.requiredEvidenceKeys)) {
            $candidateKinds = Convert-RequiredKeyToKinds -Key ([string]$requiredKey)
            $hasKind = $false
            foreach ($kind in $candidateKinds) {
                if ($recordKinds -contains $kind) {
                    $hasKind = $true
                    break
                }
            }
            if (-not $hasKind) {
                $issues += "missing-record-kind-for-key:$requiredKey"
            }
        }
    }

    $score = [Math]::Max(0, (100 - ($issues.Count * 15)))
    return [ordered]@{
        artifact = $Artifact
        passed = ($issues.Count -eq 0)
        score = $score
        issues = $issues
    }
}

$validatorResults = @()
foreach ($validator in $validatorScripts) {
    $scriptName = $validator.script
    $artifactName = $validator.artifact
    $scriptPath = Join-Path $PSScriptRoot $scriptName

    if ($missing -contains $artifactName) {
        $validatorResults += @{ script = $scriptName; passed = $false; message = "Skipped (artifact missing)" }
        continue
    }

    if (-not (Test-Path $scriptPath)) {
        $validatorResults += @{ script = $scriptName; passed = $false; message = "Missing" }
        Write-AppDocDiagnostic -Category "IO_ERROR" -Severity "Warning" -Message "Validator script missing: $scriptName" -Component "validation" -FilePath $scriptPath | Out-Null
        continue
    }

    try {
        & $scriptPath -RootPath $RootPath -ErrorAction Stop | Out-Null
        $validatorResults += @{ script = $scriptName; passed = $true; message = "OK" }
    }
    catch {
        $validatorResults += @{ script = $scriptName; passed = $false; message = $_.Exception.Message }
        Write-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Validator failed: $scriptName" -Component "validation" -FilePath $scriptPath -Details @{ exception = $_.Exception.Message } | Out-Null
    }
}

$contractValidationResults = @()
foreach ($artifact in $expectedEvidenceArtifacts) {
    $docName = [string]$artifactMap[$artifact]
    $docPath = Join-Path $docsPath $docName
    $contractValidationResults += Test-ArtifactContractSections -Artifact $artifact -DocPath $docPath
}

$evidenceContractResults = @()
foreach ($artifact in $expectedEvidenceArtifacts) {
    $evidencePath = Join-Path $evidenceRoot ("{0}.evidence.json" -f $artifact)
    if ($evidenceIndex.ContainsKey($artifact)) {
        $manifestEntry = $evidenceIndex[$artifact]
        if ($manifestEntry.path) {
            $candidate = [string]$manifestEntry.path
            if ([System.IO.Path]::IsPathRooted($candidate)) {
                $evidencePath = $candidate
            }
            else {
                $evidencePath = Join-Path $RootPath $candidate
            }
        }
    }

    $evidenceContractResults += Test-ArtifactEvidenceContract -Artifact $artifact -EvidencePath $evidencePath
}

function Get-DocRouteCount {
    param([string]$ApiDocPath)
    if (-not (Test-Path $ApiDocPath)) { return 0 }


    # Compute evidence path by walking up from $ApiDocPath
    $parent = Split-Path $ApiDocPath -Parent
    $evidencePath = $null
    while ($parent -and -not $evidencePath) {
        $candidate = Join-Path $parent "docs\evidence\api-inventory.evidence.json"
        if (Test-Path $candidate) { $evidencePath = $candidate; break }
        $parent = Split-Path $parent -Parent
    }
    if ($evidencePath) {
        try {
            $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
            $fromEvidence = @($evidence.records | Where-Object { [string]$_.kind -eq "endpoint" }).Count
            if ($fromEvidence -gt 0) { return $fromEvidence }
        }
        catch {
            Write-Warning "[validate-documentation] Failed to parse evidence at ${evidencePath}: $($_.Exception.Message)"
        }
    }

    $content = Get-Content $ApiDocPath -Raw
    return ([regex]::Matches(
        $content,
        '(?im)^\|\s*`[^|]+`\s*\|\s*`/[^|]+`\s*\|\s*(GET|POST|PUT|DELETE|PATCH|ANY|SOAP)\s*\|'
    )).Count
}

function Get-CodeRouteCount {
    param([string]$RootPath)
    $files = Get-AppDocSourceFiles -RootPath $RootPath -Include @("*.cs","*.js","*.ts","*.py","*.java")
    $count = 0
    foreach ($file in $files) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $count += ([regex]::Matches($content, 'app\.(get|post|put|delete|patch)|router\.(get|post|put|delete|patch)|\[Http(Get|Post|Put|Delete|Patch)|@app\.route|@router\.(get|post|put|delete|patch)|@(Get|Post|Put|Delete|Patch)Mapping|path\(', 'IgnoreCase')).Count
    }
    return $count
}

# --- Framework-aware classic-ASP coverage (per-framework calibration) -----------
# The composite's configCoverage/dataModelCoverage components were C#-calibrated
# (appsettings.json keys / C# model classes) and score ~0 against a classic-ASP
# target whose config + data-model artifacts are genuinely populated. These helpers
# measure the classic-ASP artifacts as a documented/expected ratio (mirroring the
# apiCoverage convention: min(documented,expected)/expected, 100 when expected==0).
# They are only invoked when framework-detection.json reports Classic ASP /
# ASP.NET Web Forms; every other framework keeps the C# path unchanged.

function Get-AppDocIsClassicAspTarget {
    param([string]$RootPath)
    $fwPath = Join-Path $RootPath "docs\framework-detection.json"
    if (-not (Test-Path $fwPath)) { return $false }
    try { $fw = Get-Content $fwPath -Raw | ConvertFrom-Json -Depth 10 } catch { return $false }
    $frameworks = @()
    if ($fw -is [System.Collections.IEnumerable] -and $fw -isnot [string]) {
        $frameworks = @($fw | ForEach-Object { [string]$_.framework } | Where-Object { $_ })
    } else { $frameworks = @([string]$fw.framework) | Where-Object { $_ } }
    return (($frameworks -contains "Classic ASP") -or ($frameworks -contains "ASP.NET Web Forms"))
}

function Test-AppDocClassicAspConnValue {
    # Mirror of the datamodel extractor's Normalize-ConnValue so the gate's
    # connection identity matches what data-model.md actually documents.
    param([string]$Raw)
    $dq = [char]34; $sq = [char]39
    $v = if ([string]::IsNullOrWhiteSpace($Raw)) { "" } else { $Raw.Trim() }
    while ($v.Length -ge 2) {
        $first = $v.Substring(0, 1); $last = $v.Substring($v.Length - 1, 1)
        if (($first -eq $dq -or $first -eq $sq) -and ($last -eq $first)) { $v = $v.Substring(1, $v.Length - 2) } else { break }
    }
    while ($v.Length -gt 0 -and ($v.Substring($v.Length - 1, 1) -eq $dq -or $v.Substring($v.Length - 1, 1) -eq $sq)) { $v = $v.Substring(0, $v.Length - 1) }
    while ($v.Length -gt 0 -and ($v.Substring(0, 1) -eq $dq -or $v.Substring(0, 1) -eq $sq)) { $v = $v.Substring(1) }
    $v = $v.Trim()
    if ($v -match ' & ' -or $v -match '^\s*&' -or $v -match '"\s*&' -or $v -match '\s*&\s*$') { return "dynamic" }
    if ($v.Length -gt 60) { return "dynamic" }
    if ([string]::IsNullOrWhiteSpace($v)) { return "unknown" }
    return $v
}

# Classic-ASP config surface = distinct config keys in the source's configuration
# files: (a) <add key=...> / <add name=...> under appSettings/connectionStrings in
# *.config files, and (b) Key=Value option names in *.ini files. Documented set =
# the expected keys represented in docs/config-catalog.md.
function Get-ClassicAspConfigCoverage {
    param([string]$RootPath, [string]$ConfigDocPath)
    $expected = New-Object System.Collections.Generic.HashSet[string]
    # (a) .NET config files
    $configFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.config" -File -ErrorAction SilentlyContinue)
    foreach ($f in $configFiles) {
        $c = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $c) { continue }
        foreach ($m in [regex]::Matches($c, '(?is)<appSettings>.*?</appSettings>')) {
            foreach ($k in [regex]::Matches($m.Value, '(?i)<add\s+[^>]*\bkey\s*=\s*"([^"]+)"')) { [void]$expected.Add($k.Groups[1].Value.ToLowerInvariant()) }
        }
        foreach ($m in [regex]::Matches($c, '(?is)<connectionStrings>.*?</connectionStrings>')) {
            foreach ($k in [regex]::Matches($m.Value, '(?i)<add\s+[^>]*\bname\s*=\s*"([^"]+)"')) { [void]$expected.Add($k.Groups[1].Value.ToLowerInvariant()) }
        }
    }
    # (b) INI option names
    $iniFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.ini" -File -ErrorAction SilentlyContinue)
    foreach ($f in $iniFiles) {
        $c = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $c) { continue }
        foreach ($line in ($c -split "`r?`n")) {
            if ($line -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*') { [void]$expected.Add($Matches[1].ToLowerInvariant()) }
        }
    }
    $expectedCount = $expected.Count
    $calibration = [ordered]@{ artifact = "config-catalog.md"; framework = "classic-asp"; expectedCount = $expectedCount; documentedCount = 0; score = 100.0; samples = @() }
    if ($expectedCount -eq 0) { $script:ClassicAspCalibration.config = $calibration; return 100 }
    $doc = if (Test-Path $ConfigDocPath) { Get-Content $ConfigDocPath -Raw } else { "" }
    $documented = 0; $missing = @()
    foreach ($key in @($expected)) {
        if ($doc -and $doc -match [regex]::Escape($key)) { $documented++ } else { $missing += $key }
    }
    $score = [Math]::Round(([Math]::Min($documented, $expectedCount) / [Math]::Max(1, $expectedCount)) * 100, 1)
    $calibration.documentedCount = $documented
    $calibration.score = $score
    $calibration.samples = @($missing | Select-Object -First 8)
    $script:ClassicAspCalibration.config = $calibration
    return $score
}

# Classic-ASP data-model surface = distinct data objects detected from ADO/SQL
# signals (same signals as generate-classic-asp-datamodel.ps1): distinct DBs
# (provider/server/catalog connection identity), tables/views (SELECT/INSERT/
# UPDATE/DELETE targets), stored procedures (EXEC call sites). Documented set =
# those objects present in docs/data-model.md.
function Get-ClassicAspDataModelCoverage {
    param([string]$RootPath, [string]$ModelDocPath)
    $dbs = New-Object System.Collections.Generic.HashSet[string]
    $objects = New-Object System.Collections.Generic.HashSet[string]
    $procs = New-Object System.Collections.Generic.HashSet[string]
    $kwProcs = @("select","insert","update","delete","set","if","end","open","close","waitfor","print","return")
    $rootPrefix = $RootPath.TrimEnd('\', '/')

    $aspFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp" -File -ErrorAction SilentlyContinue)
    $incFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.inc" -File -ErrorAction SilentlyContinue)
    $htmSignal = @()
    $htmAll = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.htm","*.html" -File -ErrorAction SilentlyContinue)
    foreach ($h in $htmAll) {
        $hc = Get-Content $h.FullName -Raw -ErrorAction SilentlyContinue
        if ($hc -match 'Data Source|Initial Catalog|(?i)\bSELECT\s|(?i)\bINSERT\s+INTO|(?i)\bEXEC(UTE)?\s') { $htmSignal += $h.FullName }
    }

    $script:ProcessCoverageFile = {
        param([string]$FullPath, $DbSet, $ObjSet, $ProcSet, $Kw)
        $content = Get-Content $FullPath -Raw -ErrorAction SilentlyContinue
        if ($null -eq $content) { return }
        foreach ($line in ($content -split "`r?`n")) {
            if ($line -notmatch '(?i)Data Source\s*=') { continue }
            $provM = [regex]::Match($line, '(?i)Provider\s*=\s*([A-Za-z0-9._]+)')
            $catM  = [regex]::Match($line, '(?i)Initial Catalog\s*=\s*([^;&"]+)')
            $srcM  = [regex]::Match($line, '(?i)Data Source\s*=\s*([^;&"]+)')
            $provider = if ($provM.Success) { $provM.Groups[1].Value } else { "unknown" }
            $catalog = if ($catM.Success) { $catM.Groups[1].Value } else { "" }
            $server  = if ($srcM.Success) { $srcM.Groups[1].Value } else { "" }
            if ([string]::IsNullOrWhiteSpace($catalog) -and $line -match '(?i)Initial Catalog\s*=\s*["&]') { $catalog = "dynamic" }
            if ([string]::IsNullOrWhiteSpace($server)  -and $line -match '(?i)Data Source\s*=\s*["&]')     { $server  = "dynamic" }
            $catalog = Test-AppDocClassicAspConnValue -Raw $catalog
            $server  = Test-AppDocClassicAspConnValue -Raw $server
            [void]$DbSet.Add(("{0}|{1}|{2}" -f $provider, $server, $catalog).ToLowerInvariant())
        }
        foreach ($m in [regex]::Matches($content, '(?is)\bSELECT\b[^;]{0,500}?\bFROM\s+([A-Za-z_][A-Za-z0-9_.$]*)')) {
            $n = $m.Groups[1].Value.Trim(); if ($n.Length -ge 2) { [void]$ObjSet.Add($n.ToLowerInvariant()) }
        }
        foreach ($m in [regex]::Matches($content, '(?i)\bINSERT\s+INTO\s+([A-Za-z_][A-Za-z0-9_.$]*)'))   { $n = $m.Groups[1].Value.Trim(); if ($n.Length -ge 2) { [void]$ObjSet.Add($n.ToLowerInvariant()) } }
        foreach ($m in [regex]::Matches($content, '(?i)\bUPDATE\s+([A-Za-z_][A-Za-z0-9_.$]*)\s+(SET|FROM)')) { $n = $m.Groups[1].Value.Trim(); if ($n.Length -ge 2) { [void]$ObjSet.Add($n.ToLowerInvariant()) } }
        foreach ($m in [regex]::Matches($content, '(?i)\bDELETE\s+FROM\s+([A-Za-z_][A-Za-z0-9_.$]*)'))   { $n = $m.Groups[1].Value.Trim(); if ($n.Length -ge 2) { [void]$ObjSet.Add($n.ToLowerInvariant()) } }
        foreach ($m in [regex]::Matches($content, '(?i)\bEXEC(UTE)?\s+([A-Za-z_][A-Za-z0-9_.$]*)')) {
            $p = $m.Groups[2].Value.Trim(); if ($p.Length -ge 2 -and ($Kw -notcontains $p.ToLowerInvariant())) { [void]$ProcSet.Add($p.ToLowerInvariant()) }
        }
    }
    foreach ($f in $aspFiles) { & $script:ProcessCoverageFile $f.FullName $dbs $objects $procs $kwProcs }
    foreach ($f in $incFiles) { & $script:ProcessCoverageFile $f.FullName $dbs $objects $procs $kwProcs }
    foreach ($p in $htmSignal) { & $script:ProcessCoverageFile $p $dbs $objects $procs $kwProcs }

    $expectedCount = ($dbs.Count + $objects.Count + $procs.Count)
    $calibration = [ordered]@{ artifact = "data-model.md"; framework = "classic-asp"; expectedCount = $expectedCount; dbCount = $dbs.Count; tableCount = $objects.Count; procCount = $procs.Count; documentedCount = 0; score = 100.0; samples = @() }
    if ($expectedCount -eq 0) { $script:ClassicAspCalibration.dataModel = $calibration; return 100 }

    # Documented set: parse data-model.md rows (db-XXX / obj-XXX / proc-XXX).
    $docDbs = New-Object System.Collections.Generic.HashSet[string]
    $docObjs = New-Object System.Collections.Generic.HashSet[string]
    $docProcs = New-Object System.Collections.Generic.HashSet[string]
    if (Test-Path $ModelDocPath) {
        $doc = Get-Content $ModelDocPath -Raw
        foreach ($line in ($doc -split "`r?`n")) {
            if ($line -match '^\|\s*(db-|obj-|proc-)\d+\s*\|') {
                $cells = @($line -split '\|' | ForEach-Object { $_.Trim() })
                # cells[1]=id  cells[2]=provider|db  cells[3]=server|object  cells[4]=catalog|type
                if ($cells[1] -match '^db-')   { [void]$docDbs.Add(("{0}|{1}|{2}" -f $cells[2], $cells[3], $cells[4]).ToLowerInvariant()) }
                elseif ($cells[1] -match '^obj-') { [void]$docObjs.Add($cells[3].ToLowerInvariant()) }
                elseif ($cells[1] -match '^proc-') { [void]$docProcs.Add($cells[3].ToLowerInvariant()) }
            }
        }
    }
    $documented = 0; $missing = @()
    foreach ($k in @($dbs))   { if ($docDbs.Contains($k)) { $documented++ } else { $missing += ("db:" + $k) } }
    foreach ($k in @($objects)) { if ($docObjs.Contains($k)) { $documented++ } else { $missing += ("table:" + $k) } }
    foreach ($k in @($procs)) { if ($docProcs.Contains($k)) { $documented++ } else { $missing += ("proc:" + $k) } }
    $score = [Math]::Round(([Math]::Min($documented, $expectedCount) / [Math]::Max(1, $expectedCount)) * 100, 1)
    $calibration.documentedCount = $documented
    $calibration.score = $score
    $calibration.samples = @($missing | Select-Object -First 8)
    $script:ClassicAspCalibration.dataModel = $calibration
    return $score
}

function Get-ConfigKeyCoverage {
    param([string]$RootPath, [string]$ConfigDocPath)
    if (-not (Test-Path $ConfigDocPath)) { return 100 }

    $doc = Get-Content $ConfigDocPath -Raw
    $docKeys = [regex]::Matches($doc, '(?im)^\|\s*`{0,2}([^|`\r\n]+?)`{0,2}\s*\|') | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -Unique
    if (-not $docKeys -or $docKeys.Count -eq 0) { return 100 }

    $configContent = @()
    foreach ($pattern in @("appsettings*.json", "Web.config", "App.config", ".env*")) {
        $configContent += Get-AppDocSourceFiles -RootPath $RootPath -Include @($pattern) | ForEach-Object { Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue }
    }

    if ($configContent.Count -eq 0) { return 100 }
    $joined = $configContent -join "`n"
    $matched = 0
    foreach ($key in $docKeys) {
        if ($joined -match [regex]::Escape($key)) { $matched++ }
    }
    return [Math]::Round(($matched / [Math]::Max(1, $docKeys.Count)) * 100, 1)
}

function Get-DataModelCoverage {
    param([string]$RootPath, [string]$ModelDocPath)
    if (-not (Test-Path $ModelDocPath)) { return 100 }

    $modelNames = @()
    $evidencePath = Join-Path $RootPath "docs\evidence\data-model.evidence.json"
    if (Test-Path $evidencePath) {
        try {
            $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
            $modelNames = @(
                $evidence.records |
                    Where-Object { [string]$_.kind -eq "model" } |
                    ForEach-Object { [string]$_.name } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )
        }
        catch { }
    }

    if ($modelNames.Count -eq 0) {
        $doc = Get-Content $ModelDocPath -Raw
        $modelNames = [regex]::Matches(
            $doc,
            '(?im)^\|\s*`([^|`]+)`\s*\|\s*\d+\s*\|'
        ) | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -Unique
    }

    if ($modelNames.Count -eq 0) { return 100 }

    $codeFiles = Get-AppDocSourceFiles -RootPath $RootPath -Include @("*.cs","*.ts","*.js","*.py","*.java")
    $found = 0
    foreach ($name in $modelNames) {
        $exists = $false
        foreach ($file in $codeFiles) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match "class\s+$([regex]::Escape($name))\b|interface\s+$([regex]::Escape($name))\b") {
                $exists = $true
                break
            }
        }
        if ($exists) { $found++ }
    }
    return [Math]::Round(($found / [Math]::Max(1, $modelNames.Count)) * 100, 1)
}

function Get-RedactionSafetyScore {
    param([string]$ConfigDocPath)

    if (-not (Test-Path $ConfigDocPath)) { return 100 }

    $content = Get-Content $ConfigDocPath -Raw
    if (-not $content) { return 100 }

    $sensitiveRows = [regex]::Matches(
        $content,
        '(?im)^\|[^\r\n]*(password|passwd|pwd|secret|token|api[_-]?key|client[_-]?secret|private[_-]?key|connection\s*string)[^\r\n]*\|[^\r\n]*$'
    )

    if ($sensitiveRows.Count -eq 0) { return 100 }

    $unredacted = 0
    foreach ($row in $sensitiveRows) {
        if ([string]$row.Value -notmatch '\[REDACTED\]') {
            $unredacted++
        }
    }

    return [Math]::Max(0, (100 - ($unredacted * 10)))
}

function Get-ConformanceScore {
    param([string]$DocsPath)

    $docNames = @(
        "overview.md",
        "api-inventory.md",
        "data-model.md",
        "config-catalog.md",
        "build-cookbook.md",
        "test-catalog.md",
        "debt-register.md",
        "dependencies-catalog.md"
    )

    $existing = @($docNames | ForEach-Object { Join-Path $DocsPath $_ } | Where-Object { Test-Path $_ })
    if ($existing.Count -eq 0) { return 0 }

    $summarySections = 0
    $linkCount = 0
    $placeholderHits = 0
    $oversizedTables = 0

    foreach ($doc in $existing) {
        $content = Get-Content $doc -Raw
        if (-not $content) { continue }

        if ($content -match '(?im)^##\s+(Summary|Executive Summary|15-Minute Orientation)\b') {
            $summarySections++
        }

        $linkCount += ([regex]::Matches($content, '\[[^\]]+\]\([^)]+\)')).Count
        $placeholderHits += ([regex]::Matches(
            $content,
            '(?im)^\s*(Describe\s+[^\r\n]*|Document\s+[^\r\n]*|List and describe\s+[^\r\n]*|Provide example[^\r\n]*|Provide quick start instructions[^\r\n]*|Refer to .* documentation\.?)\s*$|\[TODO\]|\[TBD\]'
        )).Count

        $tableRows = ([regex]::Matches($content, '(?im)^\|[^\r\n]+\|\s*$')).Count
        if ($tableRows -gt 250) {
            $oversizedTables++
        }
    }

    $summaryScore = [Math]::Round((($summarySections / [Math]::Max(1, $existing.Count)) * 100), 1)
    $linkTarget = [Math]::Max(1, ($existing.Count * 3))
    $linkScore = [Math]::Round(([Math]::Min($linkCount, $linkTarget) / $linkTarget) * 100, 1)
    $placeholderScore = [Math]::Max(0, (100 - ($placeholderHits * 10)))
    $densityScore = [Math]::Max(0, (100 - ($oversizedTables * 20)))

    return [Math]::Round((($summaryScore + $linkScore + $placeholderScore + $densityScore) / 4), 1)
}

# --- Conformance gate: three discipline sub-checks ---------------------------
# Each returns 0..100 and is averaged into the overall composite (18 components).

# (a) Section-spine coverage: the generated docs must collectively cover the
#     benchmark's 20-section spine. Matched by heading text (numbering/prefix
#     tolerant) across the content + register/appendix artifacts.
function Get-SectionSpineCoverageScore {
    param([string]$DocsPath)

    $spine = @(
        "Application Index",
        "Coverage and Executive Overview",
        "Architecture",
        "Functional Inventory",
        "Roles and Access Model",
        "UI Catalog",
        "Help Desk Workflows",
        "Data and Integrations",
        "External Call Register",
        "Stored-procedure data dictionary",
        "Troubleshooting Matrix",
        "Security and Operational Risks",
        "Ownership and Maintenance",
        "Architecture and Data-Flow Diagrams",
        "Glossary",
        "Evidence Register",
        "Open Questions and Documentation Gaps",
        "Recommendations",
        "Operations Runbook",
        "Verification Appendix"
    )

    # The composed 20-section unified master is the CANONICAL spine source; the
    # per-artifact files remain in the set for backward compatibility (they never
    # hurt the score — a title is found if it appears in ANY of the files).
    $files = @(
        "application-documentation.md",
        "overview.md",
        "index.md",
        "start-here.md",
        "api-inventory.md",
        "data-model.md",
        "config-catalog.md",
        "build-cookbook.md",
        "test-catalog.md",
        "debt-register.md",
        "dependencies-catalog.md",
        "task-guides.md",
        "architecture-diagram.md",
        "evidence-register.md",
        "verification-appendix.md"
    ) | ForEach-Object { Join-Path $DocsPath $_ } | Where-Object { Test-Path $_ }

    if ($files.Count -eq 0) { return 0 }

    $allText = ($files | ForEach-Object { Get-Content $_ -Raw } | Where-Object { $_ }) -join "`n"

    $found = 0
    foreach ($title in $spine) {
        # Match the title as a heading (## / ### / #) with optional numbering or
        # a letter-suffix (e.g. "8A"), tolerant of case.
        $pattern = ('(?im)^#{1,6}\s+(?:\d{1,2}[A-Za-z]?\s*[.:]\s*)?' + [regex]::Escape($title) + '\b')
        if ($allText -match $pattern) { $found++ }
    }

    return [Math]::Round((($found / [Math]::Max(1, $spine.Count)) * 100), 1)
}

# (b) Epistemic coverage: across the 4 content artifacts + the evidence register,
#     what fraction of countable claims carry a valid epistemic tag.
function Get-EpistemicCoverageScore {
    param([string]$DocsPath)

    if (-not (Get-Command Get-EpistemicCoverage -ErrorAction SilentlyContinue)) { return 0 }

    $artifacts = @(
        "api-inventory.md",
        "data-model.md",
        "build-cookbook.md",
        "test-catalog.md",
        "evidence-register.md"
    ) | ForEach-Object { Join-Path $DocsPath $_ } | Where-Object { Test-Path $_ }

    if ($artifacts.Count -eq 0) { return 0 }

    $cov = Get-EpistemicCoverage -Artifacts $artifacts
    return [Math]::Round([double]$cov.coveragePercent, 1)
}

# (c) Re-verifiability: for every "Verified" claim in the verification appendix,
#     its Command must not be "N/A". Score = (verified-with-command / total
#     verified) * 100. Zero verified claims => 100 (vacuous; flagged as a warning).
function Get-ReVerifiabilityScore {
    param([string]$DocsPath)

    $appendixPath = Join-Path $DocsPath "verification-appendix.md"
    if (-not (Test-Path $appendixPath)) { return 100 }

    $content = Get-Content $appendixPath -Raw
    if ([string]::IsNullOrWhiteSpace($content)) { return 100 }

    $verifiedCount = 0
    $withCommand = 0
    foreach ($line in ($content -split "`r?`n")) {
        # Only the data rows of the appendix table (Claim | Status | Command).
        if ($line -notmatch '^\s*\|.*\|\s*$') { continue }
        $cells = (($line.Trim() -replace '^\|', '' -replace '\|\s*$', '') -split '\|' | ForEach-Object { $_.Trim() })
        if ($cells.Count -lt 3) { continue }
        if (($cells -join ',') -match '^[\s:-]*$') { continue }   # separator row
        $status = $cells[1]
        $cmd = $cells[2]
        if ($status -notmatch '^(Verified|Partly verified)$') { continue }
        if ($status -eq 'Verified') {
            $verifiedCount++
            if ($cmd -notmatch 'N/A') { $withCommand++ }
        }
    }

    if ($verifiedCount -eq 0) { return 100 }
    return [Math]::Round((($withCommand / $verifiedCount) * 100), 1)
}

function Get-ClaimGroundingScore {
    param([string]$DocsPath)

    $docNames = @(
        "overview.md",
        "api-inventory.md",
        "data-model.md",
        "config-catalog.md",
        "build-cookbook.md",
        "test-catalog.md",
        "debt-register.md",
        "dependencies-catalog.md"
    )

    $existing = @($docNames | ForEach-Object { Join-Path $DocsPath $_ } | Where-Object { Test-Path $_ })
    if ($existing.Count -eq 0) { return 0 }

    $grounded = 0
    foreach ($doc in $existing) {
        $content = Get-Content $doc -Raw
        if ($content -match '(?im)^##\s+Evidence Traceability\b') {
            $grounded++
        }
    }

    return [Math]::Round((($grounded / [Math]::Max(1, $existing.Count)) * 100), 1)
}

function Get-DocumentationFreshnessScore {
    param([string]$DocsPath)

    $docNames = @(
        "overview.md",
        "api-inventory.md",
        "data-model.md",
        "config-catalog.md",
        "build-cookbook.md",
        "test-catalog.md",
        "debt-register.md",
        "dependencies-catalog.md"
    )

    $existing = @($docNames | ForEach-Object { Join-Path $DocsPath $_ } | Where-Object { Test-Path $_ })
    if ($existing.Count -eq 0) { return 0 }

    $freshCount = 0
    foreach ($doc in $existing) {
        $content = Get-Content $doc -Raw
        $m = [regex]::Match($content, '(?im)^\*\*Generated\*\*:\s*([^\r\n]+)')
        if (-not $m.Success) { continue }

        try {
            $generated = [datetime]::Parse($m.Groups[1].Value.Trim())
            $ageHours = ((Get-Date) - $generated).TotalHours
            if ($ageHours -le 72) {
                $freshCount++
            }
        }
        catch {
            continue
        }
    }

    return [Math]::Round((($freshCount / [Math]::Max(1, $existing.Count)) * 100), 1)
}

function Get-ContradictionAnalysis {
    param(
        [string]$DocsPath,
        [string]$EvidenceRoot
    )

    $issues = @()
    $allowNoApiSurface = [bool]($script:AppDocValidationContentExpectations.allowNoApiSurface ?? $false)
    $allowNoModelSurface = [bool]($script:AppDocValidationContentExpectations.allowNoModelSurface ?? $false)

    $docToArtifact = [ordered]@{
        "overview.md" = "overview"
        "api-inventory.md" = "api-inventory"
        "data-model.md" = "data-model"
        "config-catalog.md" = "config-catalog"
        "build-cookbook.md" = "build-cookbook"
        "test-catalog.md" = "test-catalog"
        "debt-register.md" = "debt-register"
        "dependencies-catalog.md" = "dependencies-catalog"
    }

    $evidenceCounts = @{}
    foreach ($entry in $docToArtifact.GetEnumerator()) {
        $artifact = [string]$entry.Value
        $evidencePath = Join-Path $EvidenceRoot ("{0}.evidence.json" -f $artifact)
        if (-not (Test-Path $evidencePath)) { continue }
        try {
            $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json
            $count = if ($evidence.recordCount -ne $null) { [int]$evidence.recordCount } else { @($evidence.records).Count }
            $evidenceCounts[$artifact] = $count
        }
        catch {
            $issues += "evidence-unreadable:$artifact"
        }
    }

    foreach ($entry in $docToArtifact.GetEnumerator()) {
        $docFile = [string]$entry.Key
        $artifact = [string]$entry.Value
        $docPath = Join-Path $DocsPath $docFile
        if (-not (Test-Path $docPath)) { continue }
        if (-not $evidenceCounts.ContainsKey($artifact)) { continue }

        $content = Get-Content $docPath -Raw
        $mTrace = [regex]::Match($content, '(?im)^\|\s*Record Count\s*\|\s*(\d+)\s*\|')
        if ($mTrace.Success) {
            $docCount = [int]$mTrace.Groups[1].Value
            $evidenceCount = [int]$evidenceCounts[$artifact]
            if ($docCount -ne $evidenceCount) {
                $issues += "traceability-record-count-mismatch:${artifact}:$docCount/$evidenceCount"
            }
        }
    }

    $startHerePath = Join-Path $DocsPath "start-here.md"
    if (Test-Path $startHerePath) {
        try {
            $startHere = Get-Content $startHerePath -Raw
            $mApi = [regex]::Match($startHere, '(?im)^-\s+API endpoints documented:\s*\*\*(\d+)\*\*')
            if ($mApi.Success) {
                $startHereApi = [int]$mApi.Groups[1].Value
                $apiEvidencePath = Join-Path $EvidenceRoot "api-inventory.evidence.json"
                if (Test-Path $apiEvidencePath) {
                    $apiEvidence = Get-Content $apiEvidencePath -Raw | ConvertFrom-Json
                    $apiEvidenceCount = @($apiEvidence.records | Where-Object { [string]$_.kind -eq 'endpoint' }).Count
                    if ((-not $allowNoApiSurface) -and [Math]::Abs($startHereApi - $apiEvidenceCount) -gt 0) {
                        $issues += "start-here-api-signal-mismatch:$startHereApi/$apiEvidenceCount"
                    }
                }
            }

            $mModel = [regex]::Match($startHere, '(?im)^-\s+Data model headings detected:\s*\*\*(\d+)\*\*')
            if ($mModel.Success) {
                $startHereModels = [int]$mModel.Groups[1].Value
                $modelEvidencePath = Join-Path $EvidenceRoot "data-model.evidence.json"
                if (Test-Path $modelEvidencePath) {
                    $modelEvidence = Get-Content $modelEvidencePath -Raw | ConvertFrom-Json
                    $modelEvidenceCount = @($modelEvidence.records | Where-Object { [string]$_.kind -eq 'model' }).Count
                    if ((-not $allowNoModelSurface) -and [Math]::Abs($startHereModels - $modelEvidenceCount) -gt 0) {
                        $issues += "start-here-model-signal-mismatch:$startHereModels/$modelEvidenceCount"
                    }
                }
            }
        }
        catch {
            $issues += "start-here-unreadable"
        }
    }

    $score = [Math]::Max(0, (100 - ($issues.Count * 20)))
    return [ordered]@{
        score = $score
        passed = ($issues.Count -eq 0)
        issues = $issues
    }
}

function Get-ArchitectureContradictionAnalysis {
    param(
        [string]$RootPath,
        [string]$DocsPath
    )

    $issues = @()
    $signals = [ordered]@{
        primaryStyle = "unknown"
        frameworkHints = @()
        apiInventoryRestRows = 0
        apiInventorySoapRows = 0
        overviewRestMentions = 0
        overviewSoapMentions = 0
    }

    $fingerprintPath = Join-Path $DocsPath "architecture-fingerprint.json"
    $frameworkPath = Join-Path $DocsPath "framework-detection.json"
    $apiPath = Join-Path $DocsPath "api-inventory.md"
    $overviewPath = Join-Path $DocsPath "overview.md"

    $fingerprint = $null
    if (Test-Path $fingerprintPath) {
        try {
            $fingerprint = Get-Content $fingerprintPath -Raw | ConvertFrom-Json -Depth 50
        }
        catch {
            $issues += "architecture-contradiction:fingerprint-unreadable"
        }
    }

    $primaryStyle = if ($fingerprint -and $fingerprint.primaryStyle) { [string]$fingerprint.primaryStyle } else { "unknown" }
    $signals.primaryStyle = $primaryStyle

    $frameworkHints = @()
    if (Test-Path $frameworkPath) {
        try {
            $frameworkRows = @(Get-Content $frameworkPath -Raw | ConvertFrom-Json -Depth 50)
            $frameworkHints = @(
                $frameworkRows |
                    ForEach-Object { [string]$_.framework } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )
        }
        catch {
            $issues += "architecture-contradiction:framework-detection-unreadable"
        }
    }
    $signals.frameworkHints = @($frameworkHints)

    $apiInventoryContent = ""
    if (Test-Path $apiPath) {
        $apiInventoryContent = Get-Content $apiPath -Raw
        $restRows = ([regex]::Matches($apiInventoryContent, '(?im)^\|\s*`[^|]+`\s*\|\s*`/[^|]+`\s*\|\s*(GET|POST|PUT|DELETE|PATCH|ANY)\s*\|')).Count
        $soapRows = ([regex]::Matches($apiInventoryContent, '(?im)^\|\s*`[^|]+`\s*\|\s*`/[^|]+`\s*\|\s*SOAP\s*\|')).Count
        $signals.apiInventoryRestRows = [int]$restRows
        $signals.apiInventorySoapRows = [int]$soapRows
    }

    $overviewContent = ""
    if (Test-Path $overviewPath) {
        $overviewContent = Get-Content $overviewPath -Raw
        $signals.overviewRestMentions = ([regex]::Matches($overviewContent, '(?i)\bREST\b|\bHTTP API\b|\bApiController\b')).Count
        $signals.overviewSoapMentions = ([regex]::Matches($overviewContent, '(?i)\bSOAP\b|\bWCF\b|\bServiceContract\b|\bOperationContract\b')).Count
    }

    $isSoapPrimary = ($primaryStyle -match '(?i)^(WCF-first|SOAP-first|wcf-service|asmx-service|soap-client)$')
    $isRestPrimary = ($primaryStyle -match '(?i)^rest-http')
    $isNoApiPrimary = ($primaryStyle -eq 'no-api-surface')
    $soapFrameworkHint = (@($frameworkHints | Where-Object { $_ -match '(?i)\bWCF\b|SOAP|ASMX' }).Count -gt 0)
    $restFrameworkHint = (@($frameworkHints | Where-Object { $_ -match '(?i)ASP\.NET\s+Core|ASP\.NET\s+MVC|Web API' }).Count -gt 0)

    if ($isSoapPrimary -and $signals.apiInventoryRestRows -gt 0 -and $signals.apiInventorySoapRows -eq 0) {
        $issues += "architecture-contradiction:soap-primary-vs-rest-api-inventory"
    }
    if ($isRestPrimary -and $signals.apiInventorySoapRows -gt 0 -and $signals.apiInventoryRestRows -eq 0) {
        $issues += "architecture-contradiction:rest-primary-vs-soap-api-inventory"
    }
    if ($isNoApiPrimary -and ($signals.apiInventoryRestRows -gt 0 -or $signals.apiInventorySoapRows -gt 0)) {
        $issues += "architecture-contradiction:no-api-primary-vs-api-inventory"
    }

    if ($isSoapPrimary -and $signals.overviewRestMentions -gt 0 -and $signals.overviewSoapMentions -eq 0) {
        $issues += "architecture-contradiction:soap-primary-vs-overview-rest-language"
    }
    if ($isRestPrimary -and $signals.overviewSoapMentions -gt 0 -and $signals.overviewRestMentions -eq 0) {
        $issues += "architecture-contradiction:rest-primary-vs-overview-soap-language"
    }

    if ($isSoapPrimary -and $restFrameworkHint -and -not $soapFrameworkHint -and $signals.apiInventorySoapRows -eq 0) {
        $issues += "architecture-contradiction:soap-primary-vs-framework-rest-only"
    }
    if ($isRestPrimary -and $soapFrameworkHint -and -not $restFrameworkHint -and $signals.apiInventoryRestRows -eq 0) {
        $issues += "architecture-contradiction:rest-primary-vs-framework-soap-only"
    }

    $score = [Math]::Max(0, (100 - ($issues.Count * 35)))
    return [ordered]@{
        score = [Math]::Round($score, 1)
        passed = ($issues.Count -eq 0)
        issues = @($issues)
        signals = $signals
    }
}

function Get-QualityPenaltyBreakdown {
    param(
        [string]$DocsPath,
        [string[]]$Contradictions = @()
    )

    $docMap = [ordered]@{
        "overview" = "overview.md"
        "api-inventory" = "api-inventory.md"
        "data-model" = "data-model.md"
        "config-catalog" = "config-catalog.md"
        "build-cookbook" = "build-cookbook.md"
        "test-catalog" = "test-catalog.md"
        "debt-register" = "debt-register.md"
        "dependencies-catalog" = "dependencies-catalog.md"
    }

    $perArtifact = [ordered]@{}
    foreach ($artifact in $docMap.Keys) {
        $perArtifact[$artifact] = [ordered]@{
            total = 0
            contradiction = 0
            duplicateRows = 0
            misclassification = 0
            staleProvenance = 0
            verbosityOverflow = 0
            reasons = [System.Collections.ArrayList]@()
        }
    }

    function Add-AppDocPenalty {
        param(
            [string]$Artifact,
            [string]$Category,
            [int]$Points,
            [string]$Reason
        )

        if (-not $perArtifact.Contains($Artifact)) { return }
        $entry = $perArtifact[$Artifact]
        $entry.total = [int]$entry.total + $Points
        $entry[$Category] = [int]$entry[$Category] + $Points
        if (-not $entry.reasons) {
            $entry.reasons = [System.Collections.ArrayList]@()
        }
        $null = $entry.reasons.Add($Reason)
        $perArtifact[$Artifact] = $entry
    }

    foreach ($issue in @($Contradictions)) {
        if ([string]$issue -notmatch '^architecture-contradiction:') { continue }

        $targets = @("overview", "api-inventory")
        if ([string]$issue -match 'overview') { $targets = @("overview") }
        elseif ([string]$issue -match 'api-inventory') { $targets = @("api-inventory", "start-here") }

        foreach ($target in $targets) {
            Add-AppDocPenalty -Artifact $target -Category "contradiction" -Points 30 -Reason $issue
        }

        Add-AppDocPenalty -Artifact "overview" -Category "misclassification" -Points 10 -Reason "misclassification:$issue"
        Add-AppDocPenalty -Artifact "api-inventory" -Category "misclassification" -Points 10 -Reason "misclassification:$issue"
    }

    foreach ($artifact in $docMap.Keys) {
        $docPath = Join-Path $DocsPath $docMap[$artifact]
        if (-not (Test-Path $docPath)) { continue }
        $content = Get-Content $docPath -Raw

        $rows = @([regex]::Matches($content, '(?im)^\|[^\r\n]+\|\s*$') | ForEach-Object { [string]$_.Value.Trim() })
        if ($rows.Count -gt 2) {
            # Count duplicate DATA rows only. A document can hold MULTIPLE tables
            # (each with its own header + separator row), so a header/separator row
            # that repeats across tables is NOT a duplicated data row — it is a
            # structural artifact of multi-table layout. Exclude every table
            # header (a row immediately followed by a separator row) and every
            # separator row before grouping. Genuinely duplicated DATA rows are
            # still detected and penalized (this only removes the header/separator
            # false positive, not the duplicate-row check itself).
            $sepRowRe = [regex]'^\|(?:\s*:?-{2,}:?\s*\|)+$'
            $dataRows = @()
            for ($ri = 0; $ri -lt $rows.Count; $ri++) {
                $row = $rows[$ri]
                if ($sepRowRe.IsMatch($row)) { continue }
                if ($ri -lt $rows.Count - 1 -and $sepRowRe.IsMatch($rows[$ri + 1])) { continue }
                $dataRows += $row
            }
            $dupeCount = @($dataRows | Group-Object | Where-Object { $_.Count -gt 1 }).Count
            if ($dupeCount -gt 0) {
                Add-AppDocPenalty -Artifact $artifact -Category "duplicateRows" -Points ($dupeCount * 8) -Reason "duplicate-rows:$dupeCount"
            }
        }

        $generatedMatch = [regex]::Match($content, '(?im)^\*\*Generated\*\*:\s*([^\r\n]+)')
        if (-not $generatedMatch.Success) {
            Add-AppDocPenalty -Artifact $artifact -Category "staleProvenance" -Points 8 -Reason "provenance-missing-generated"
        }
        else {
            try {
                $generatedAt = [datetime]::Parse($generatedMatch.Groups[1].Value.Trim())
                $ageHours = ((Get-Date) - $generatedAt).TotalHours
                if ($ageHours -gt 72) {
                    Add-AppDocPenalty -Artifact $artifact -Category "staleProvenance" -Points 8 -Reason "provenance-stale-hours:$([Math]::Round($ageHours,1))"
                }
            }
            catch {
                Add-AppDocPenalty -Artifact $artifact -Category "staleProvenance" -Points 8 -Reason "provenance-invalid-generated"
            }
        }

        $lineCount = @($content -split "`n").Count
        $hasQuickLinks = [regex]::IsMatch($content, '(?im)^##\s+(Quick Links|Contents|Table of Contents)\b')
        if ($lineCount -gt 350 -and -not $hasQuickLinks) {
            Add-AppDocPenalty -Artifact $artifact -Category "verbosityOverflow" -Points 6 -Reason "verbosity-overflow-lines:$lineCount"
        }
    }

    $categoryTotals = [ordered]@{
        contradiction = 0
        duplicateRows = 0
        misclassification = 0
        staleProvenance = 0
        verbosityOverflow = 0
    }
    $categoryKeys = @($categoryTotals.Keys)
    $totalPenaltyPoints = 0
    foreach ($artifact in $perArtifact.Keys) {
        $entry = $perArtifact[$artifact]
        foreach ($category in $categoryKeys) {
            $categoryTotals[$category] = [int]$categoryTotals[$category] + [int]$entry[$category]
        }
        $totalPenaltyPoints += [int]$entry.total
    }

    return [ordered]@{
        totalPenaltyPoints = [int]$totalPenaltyPoints
        categoryTotals = $categoryTotals
        perArtifact = $perArtifact
        artifactCount = [int]$perArtifact.Keys.Count
    }
}

# Read the composed unified master's canonical count markers (the table that
# generate-unified-master.ps1 emits under "## Coverage and Executive Overview"):
#   | API endpoints documented | N | ... |
#   | Database object records (models) | N | ... |
# Returns @{ endpointCount; modelCount; present } — present is $false when the
# composed doc is absent/unparseable (backward-compat path keeps the per-artifact
# references in that case).
function Get-AppDocUnifiedMasterCounts {
    param([string]$DocsPath)
    $masterPath = Join-Path $DocsPath "application-documentation.md"
    $result = [ordered]@{ endpointCount = $null; modelCount = $null; present = $false }
    if (-not (Test-Path $masterPath)) { return $result }
    try {
        $master = Get-Content $masterPath -Raw
        $mApi = [regex]::Match($master, '(?im)^\|\s*API endpoints documented\s*\|\s*(\d+)\s*\|')
        $mModel = [regex]::Match($master, '(?im)^\|\s*Database object records \(models\)\s*\|\s*(\d+)\s*\|')
        if ($mApi.Success -and $mModel.Success) {
            $result.endpointCount = [int]$mApi.Groups[1].Value
            $result.modelCount    = [int]$mModel.Groups[1].Value
            $result.present       = $true
        }
    }
    catch { $result.present = $false }
    return $result
}

function Get-CrossArtifactMetricDriftAnalysis {
    param(
        [string]$DocsPath
    )

    $issues = @()
    $signals = [ordered]@{}
    $canonicalPath = Join-Path $DocsPath "evidence\metrics-canonical.json"
    if (-not (Test-Path $canonicalPath)) {
        return [ordered]@{
            score = 0
            passed = $false
            issues = @("cross-artifact-metric-drift:canonical-metrics-missing")
            signals = $signals
        }
    }

    $canonical = $null
    try {
        $canonical = Get-Content $canonicalPath -Raw | ConvertFrom-Json -Depth 80
    }
    catch {
        return [ordered]@{
            score = 0
            passed = $false
            issues = @("cross-artifact-metric-drift:canonical-metrics-unparseable")
            signals = $signals
        }
    }

    $totals = Get-AppDocValidationContentValue -Object $canonical -Name "totals" -Default @{}
    $canonicalEndpointCount = [int](Get-AppDocValidationContentValue -Object $totals -Name "endpointCount" -Default 0)
    $canonicalModelCount = [int](Get-AppDocValidationContentValue -Object $totals -Name "modelCount" -Default 0)
    $canonicalDependencyCount = [int](Get-AppDocValidationContentValue -Object $totals -Name "dependencyCount" -Default 0)
    $canonicalTestCaseCount = [int](Get-AppDocValidationContentValue -Object $totals -Name "testCaseCount" -Default 0)

    $signals.canonical = [ordered]@{
        endpointCount = $canonicalEndpointCount
        modelCount = $canonicalModelCount
        dependencyCount = $canonicalDependencyCount
        testCaseCount = $canonicalTestCaseCount
    }

    # --- Composed unified master = canonical count source (WS-3) --------------
    # The 20-section master (application-documentation.md) is the canonical count
    # reference: it reports the real classic-ASP counts. Cross-check it against the
    # machine-evidence canonical (they should agree); a mismatch is a real drift.
    # When the master is present it SUPERSEDES the C#-centric start-here.md stub as
    # the count source, so that stub's 0-count is no longer flagged as a false
    # positive (the stub is only compared below when the master is absent, for
    # backward compatibility). No thresholds are changed and no legitimate check is
    # removed — the machine-evidence canonical is still the ground truth we check.
    $masterCounts = Get-AppDocUnifiedMasterCounts -DocsPath $DocsPath
    $signals.unifiedMaster = [ordered]@{
        endpointCount = $masterCounts.endpointCount
        modelCount    = $masterCounts.modelCount
        present       = [bool]$masterCounts.present
    }
    $masterIsCanonical = [bool]$masterCounts.present
    if ($masterIsCanonical) {
        if ([int]$masterCounts.endpointCount -ne $canonicalEndpointCount) {
            $issues += ("cross-artifact-metric-drift:unified-master-endpoint-count:{0}/{1}" -f $masterCounts.endpointCount, $canonicalEndpointCount)
        }
        if ([int]$masterCounts.modelCount -ne $canonicalModelCount) {
            $issues += ("cross-artifact-metric-drift:unified-master-model-count:{0}/{1}" -f $masterCounts.modelCount, $canonicalModelCount)
        }
    }

    $overviewTruthPath = Join-Path $DocsPath "evidence\overview-truth-pack.json"
    if (Test-Path $overviewTruthPath) {
        try {
            $truthPack = Get-Content $overviewTruthPath -Raw | ConvertFrom-Json -Depth 80
            $counts = Get-AppDocValidationContentValue -Object $truthPack -Name "counts" -Default @{}
            $overviewEndpoint = [int](Get-AppDocValidationContentValue -Object $counts -Name "endpointRecords" -Default 0)
            $overviewModel = [int](Get-AppDocValidationContentValue -Object $counts -Name "modelRecords" -Default 0)
            $overviewDependency = [int](Get-AppDocValidationContentValue -Object $counts -Name "dependencyRecords" -Default 0)
            $signals.overviewTruthPack = [ordered]@{
                endpointCount = $overviewEndpoint
                modelCount = $overviewModel
                dependencyCount = $overviewDependency
            }

            if ($overviewEndpoint -ne $canonicalEndpointCount) { $issues += ("cross-artifact-metric-drift:overview-endpoint-count:{0}/{1}" -f $overviewEndpoint, $canonicalEndpointCount) }
            if ($overviewModel -ne $canonicalModelCount) { $issues += ("cross-artifact-metric-drift:overview-model-count:{0}/{1}" -f $overviewModel, $canonicalModelCount) }
            if ($overviewDependency -ne $canonicalDependencyCount) { $issues += ("cross-artifact-metric-drift:overview-dependency-count:{0}/{1}" -f $overviewDependency, $canonicalDependencyCount) }
        }
        catch {
            $issues += "cross-artifact-metric-drift:overview-truth-pack-unparseable"
        }
    }

    $startHerePath = Join-Path $DocsPath "start-here.md"
    # The start-here.md count markers are the CANONICAL count reference ONLY when
    # the composed unified master is absent (backward compatibility). When the
    # master is present it supersedes the C#-centric stub, so the stub's 0-count
    # is no longer flagged as a false positive.
    if ((Test-Path $startHerePath) -and (-not $masterIsCanonical)) {
        try {
            $startHere = Get-Content $startHerePath -Raw
            $mApi = [regex]::Match($startHere, '(?im)^-\s+API endpoints documented:\s*\*\*(\d+)\*\*')
            $mModel = [regex]::Match($startHere, '(?im)^-\s+Data models documented:\s*\*\*(\d+)\*\*')
            if ($mApi.Success) {
                $startHereApi = [int]$mApi.Groups[1].Value
                $signals.startHereApiCount = $startHereApi
                if ($startHereApi -ne $canonicalEndpointCount) { $issues += ("cross-artifact-metric-drift:start-here-endpoint-count:{0}/{1}" -f $startHereApi, $canonicalEndpointCount) }
            }
            if ($mModel.Success) {
                $startHereModel = [int]$mModel.Groups[1].Value
                $signals.startHereModelCount = $startHereModel
                if ($startHereModel -ne $canonicalModelCount) { $issues += ("cross-artifact-metric-drift:start-here-model-count:{0}/{1}" -f $startHereModel, $canonicalModelCount) }
            }
        }
        catch {
            $issues += "cross-artifact-metric-drift:start-here-unparseable"
        }
    }

    $testEvidencePath = Join-Path $DocsPath "evidence\test-catalog.evidence.json"
    if (Test-Path $testEvidencePath) {
        try {
            $testEvidence = Get-Content $testEvidencePath -Raw | ConvertFrom-Json -Depth 80
            $testCaseCount = @(@($testEvidence.records) | Where-Object { $_ -and [string]$_.kind -in @("test-case", "test", "parameterized test") }).Count
            $signals.testEvidenceCaseCount = $testCaseCount
            if ($testCaseCount -ne $canonicalTestCaseCount) { $issues += ("cross-artifact-metric-drift:test-case-count:{0}/{1}" -f $testCaseCount, $canonicalTestCaseCount) }
        }
        catch {
            $issues += "cross-artifact-metric-drift:test-evidence-unparseable"
        }
    }

    $dependencyEvidencePath = Join-Path $DocsPath "evidence\dependencies-catalog.evidence.json"
    if (Test-Path $dependencyEvidencePath) {
        try {
            $dependencyEvidence = Get-Content $dependencyEvidencePath -Raw | ConvertFrom-Json -Depth 80
            $dependencyCount = @(@($dependencyEvidence.records) | Where-Object { $_ -and [string]$_.kind -eq "dependency" }).Count
            $signals.dependencyEvidenceCount = $dependencyCount
            if ($dependencyCount -ne $canonicalDependencyCount) { $issues += ("cross-artifact-metric-drift:dependency-count:{0}/{1}" -f $dependencyCount, $canonicalDependencyCount) }
        }
        catch {
            $issues += "cross-artifact-metric-drift:dependency-evidence-unparseable"
        }
    }

    $score = [Math]::Max(0, (100 - (@($issues).Count * 35)))
    return [ordered]@{
        score = [Math]::Round($score, 1)
        passed = (@($issues).Count -eq 0)
        issues = @($issues)
        signals = $signals
    }
}

function Get-TaskGuideOutcomeMetrics {
    param(
        [string]$DocsPath,
        [string]$EvidenceRoot
    )

    $taskGuidesPath = Join-Path $DocsPath "task-guides.md"
    if (-not (Test-Path $taskGuidesPath)) {
        return [ordered]@{
            actionabilityScore = 100
            evidenceCoverageScore = 100
            estimatedCompletionMinutes = 0
            taskCompletionTimeScore = 100
            issues = @()
        }
    }

    $content = Get-Content $taskGuidesPath -Raw
    $issues = @()

    $guideMatches = [regex]::Matches($content, '(?im)^###\s+')
    $guideCount = $guideMatches.Count
    if ($guideCount -lt 4) {
        $issues += "task-guide-count-low:$guideCount"
    }

    $guideBlocks = [regex]::Matches($content, '(?ims)^###\s+[^\r\n]+\s*\r?\n(.*?)(?=^###\s+|^##\s+Operational Checklist|\z)')
    $stepCounts = @()
    $snapshotCounts = @()
    foreach ($block in $guideBlocks) {
        $text = [string]$block.Groups[1].Value
        $stepCounts += ([regex]::Matches($text, '(?im)^\d+\.\s+')).Count

        $snapshotMatch = [regex]::Match($text, '(?ims)\*\*Evidence snapshot\*\*:\s*(.*)$')
        if ($snapshotMatch.Success) {
            $snapshotCounts += ([regex]::Matches($snapshotMatch.Groups[1].Value, '(?im)^-\s+')).Count
        }
        else {
            $snapshotCounts += 0
        }
    }

    $avgSteps = if ($stepCounts.Count -gt 0) { ($stepCounts | Measure-Object -Average).Average } else { 0 }
    $avgSnapshots = if ($snapshotCounts.Count -gt 0) { ($snapshotCounts | Measure-Object -Average).Average } else { 0 }
    $checklistCount = ([regex]::Matches($content, '(?im)^-\s+')).Count

    $guideCountScore = [Math]::Round(([Math]::Min($guideCount, 4) / 4) * 100, 1)
    $stepScore = [Math]::Round(([Math]::Min($avgSteps, 4) / 4) * 100, 1)
    $snapshotScore = [Math]::Round(([Math]::Min($avgSnapshots, 3) / 3) * 100, 1)
    $checklistScore = [Math]::Round(([Math]::Min($checklistCount, 5) / 5) * 100, 1)
    $actionabilityScore = [Math]::Round((($guideCountScore + $stepScore + $snapshotScore + $checklistScore) / 4), 1)
    $expectedSnapshotMinimum = 2

    if ($avgSteps -lt 3) {
        $issues += "task-guide-steps-low:$([Math]::Round($avgSteps,1))"
    }

    $evidenceCoverageScore = 0
    $taskGuidesEvidencePath = Join-Path $EvidenceRoot "task-guides.evidence.json"
    if (Test-Path $taskGuidesEvidencePath) {
        try {
            $evidence = Get-Content $taskGuidesEvidencePath -Raw | ConvertFrom-Json
            $taskGuideRecords = @($evidence.records | Where-Object { [string]$_.kind -eq 'task-guide' })
            # Get single summary record (Select-Object -First 1 returns a single object or $null)
            $summaryRecord = $evidence.records | Where-Object { [string]$_.kind -eq 'summary' } | Select-Object -First 1

            $taskRecordScore = [Math]::Round(([Math]::Min($taskGuideRecords.Count, 4) / 4) * 100, 1)

            $evidenceKeysSatisfied = 0
            $nonZeroSurfaceSignals = 0
            # Treat $summaryRecord as a single object, not an array
            if ($summaryRecord -and $summaryRecord.metadata) {
                $meta = $summaryRecord.metadata
                foreach ($key in @('endpointCount', 'buildCommandCount', 'dependencyCount', 'debtCount', 'testCount')) {
                    if ($meta.$key -and [int]$meta.$key -gt 0) {
                        $evidenceKeysSatisfied++
                        $nonZeroSurfaceSignals++
                    }
                }

                if ($nonZeroSurfaceSignals -le 0) {
                    $expectedSnapshotMinimum = 0
                }
                elseif ($nonZeroSurfaceSignals -eq 1) {
                    $expectedSnapshotMinimum = 1
                }
                # If metadata is absent or unreadable, do not override $expectedSnapshotMinimum (preserve default)
            }
            $referenceEvidenceScore = [Math]::Round(($evidenceKeysSatisfied / 5) * 100, 1)
            $evidenceCoverageScore = [Math]::Round((($taskRecordScore + $referenceEvidenceScore) / 2), 1)
        }
        catch {
            $issues += "task-guides-evidence-unreadable"
        }
    }
    else {
        $issues += "task-guides-evidence-missing"
    }

    if ($avgSnapshots -lt $expectedSnapshotMinimum) {
        $issues += "task-guide-evidence-snapshot-low:$([Math]::Round($avgSnapshots,1))"
    }

    $estimatedCompletionMinutes = [Math]::Round(($avgSteps * 3), 1)
    $taskCompletionTimeScore = [Math]::Max(0, (100 - ([Math]::Abs(12 - $estimatedCompletionMinutes) * 5)))

    return [ordered]@{
        actionabilityScore = $actionabilityScore
        evidenceCoverageScore = $evidenceCoverageScore
        estimatedCompletionMinutes = $estimatedCompletionMinutes
        taskCompletionTimeScore = [Math]::Round($taskCompletionTimeScore, 1)
        issues = $issues
    }
}
function Get-MarkdownTableDataRows {
    param([string]$SectionContent)

    if (-not $SectionContent) { return @() }

    $rows = @()
    foreach ($line in ($SectionContent -split "`n")) {
        $trimmed = $line.Trim()
        if ($trimmed -match '^\|.+\|$' -and $trimmed -notmatch '^\|\s*-+') {
            $rows += $trimmed
        }
    }

    if ($rows.Count -le 1) { return @() }
    return @($rows | Select-Object -Skip 1)
}

function Get-PolicyGateAnalysis {
    param(
        [string]$DocsPath,
        [string]$RootPath
    )

    $blockingIssues = @()
    $warnings = @()
    $allowNoApiSurface = [bool]($script:AppDocValidationContentExpectations.allowNoApiSurface ?? $false)
    $architectureFingerprint = $null
    $apiSurfaceExpected = $true
    if ($RootPath -and (Get-Command Get-AppDocArchitectureFingerprint -ErrorAction SilentlyContinue)) {
        $architectureFingerprint = Get-AppDocArchitectureFingerprint -RootPath $RootPath
        if ($null -ne $architectureFingerprint.apiSurfaceExpected) {
            $apiSurfaceExpected = [bool]$architectureFingerprint.apiSurfaceExpected
        }
    }

    $criticalDocs = @(
        "overview.md",
        "api-inventory.md",
        "data-model.md",
        "config-catalog.md",
        "build-cookbook.md"
    )

    $templatePattern = '(?im)(^\s*Describe\s+[^\r\n]*$|^\s*Document\s+[^\r\n]*$|^\s*List and describe\s+[^\r\n]*$|Current scan found 0 items for this section\.|\[TODO\]|\[TBD\]|Population Guide)'

    foreach ($docName in $criticalDocs) {
        $path = Join-Path $DocsPath $docName
        if (-not (Test-Path $path)) {
            $blockingIssues += "critical-doc-missing:$docName"
            continue
        }

        $content = Get-Content $path -Raw
        $placeholderHits = ([regex]::Matches($content, $templatePattern)).Count
        if ($placeholderHits -gt 0) {
            $blockingIssues += ("template-residue:{0}:{1}" -f $docName, $placeholderHits)
        }

        $requiredProvenanceLines = @(
            "Generator Version:",
            "Commit Hash:",
            "Generated At:",
            "Profile:",
            "Scope:",
            "Confidence/Inference Flags:"
        )
        if ($content -notmatch '(?im)^##\s+Provenance\s*$') {
            $blockingIssues += "provenance-missing:$docName"
        }
        else {
            foreach ($line in $requiredProvenanceLines) {
                if ($content -notmatch [regex]::Escape($line)) {
                    $blockingIssues += ("provenance-field-missing:{0}:{1}" -f $docName, $line)
                }
            }
        }
    }

    foreach ($jsonName in @("quality-report.json","validation-report.json","diagnostics-report.json")) {
        $jsonPath = Join-Path $DocsPath $jsonName
        if (-not (Test-Path $jsonPath)) { continue }
        try {
            $payload = Get-Content $jsonPath -Raw | ConvertFrom-Json -Depth 120
            if ($null -eq $payload.provenance) {
                $blockingIssues += "provenance-missing:$jsonName"
                continue
            }
            $requiredJsonFields = @("generatorVersion","commitHash","generatedAt","profile","scope","confidenceInferenceFlags")
            foreach ($field in $requiredJsonFields) {
                if ($null -eq $payload.provenance.$field) {
                    $blockingIssues += ("provenance-field-missing:{0}:{1}" -f $jsonName, $field)
                }
            }
        }
        catch {
            $blockingIssues += ("provenance-json-unparseable:{0}" -f $jsonName)
        }
    }

    $overviewPath = Join-Path $DocsPath "overview.md"
    if (Test-Path $overviewPath) {
        $overviewContent = Get-Content $overviewPath -Raw
        $requiredOverviewSections = @(
            "System Boundary",
            "Runtime Path",
            "Inputs→Processing→Outputs",
            "External Systems",
            "Confidence Notes"
        )
        foreach ($section in $requiredOverviewSections) {
            if (-not [regex]::IsMatch($overviewContent, "(?im)^##\s+" + [regex]::Escape($section) + "\b")) {
                $blockingIssues += "overview-section-missing:$section"
            }
        }
    }
    else {
        if (-not ($blockingIssues -contains "critical-doc-missing:overview.md")) {
            $blockingIssues += "overview-doc-missing"
        }
    }

    $apiPath = Join-Path $DocsPath "api-inventory.md"
    if (Test-Path $apiPath) {
        $apiContent = Get-Content $apiPath -Raw
        $apiSection = Get-MarkdownSectionBlock -Content $apiContent -SectionName "API Endpoints"
        $apiRows = Get-MarkdownTableDataRows -SectionContent $apiSection
        if ($apiRows.Count -eq 0) {
            if ($apiSurfaceExpected) {
                $blockingIssues += "api-endpoints-table-empty"
            }
            elseif (-not $allowNoApiSurface) {
                $styleLabel = if ($architectureFingerprint -and $architectureFingerprint.primaryStyle) { [string]$architectureFingerprint.primaryStyle } else { "unknown" }
                $warnings += "api-endpoints-table-empty-nonblocking:$styleLabel"
            }
        }

        $blankPathRows = @($apiRows | Where-Object { $_ -match '^\|\s*``?[^|]+``?\s*\|\s*``?\s*``?\s*\|' })
        if ($blankPathRows.Count -gt 0) {
            $blockingIssues += "api-endpoints-blank-paths:$($blankPathRows.Count)"
        }

        if ($apiContent -notmatch '(?im)\[API Inventory Appendix\]\(api-inventory\.appendix\.md\)') {
            $blockingIssues += "api-appendix-link-missing"
        }

        $apiAppendixPath = Join-Path $DocsPath "api-inventory.appendix.md"
        if (-not (Test-Path $apiAppendixPath)) {
            $blockingIssues += "api-appendix-missing"
        }
        else {
            $appendixContent = Get-Content $apiAppendixPath -Raw
            $requiredAppendixColumns = @(
                "Operation Intent",
                "Auth Boundary",
                "Timeout/Retry",
                "Idempotency",
                "Confidence"
            )
            foreach ($column in $requiredAppendixColumns) {
                if ($appendixContent -notmatch [regex]::Escape($column)) {
                    $blockingIssues += "api-appendix-column-missing:$column"
                }
            }

            $appendixRows = @(
                [regex]::Matches($appendixContent, '(?im)^\|\s*``?[^|]+\|.*\|\s*$') |
                ForEach-Object {
                    $row = [string]$_.Value
                    # Exclude header and separator rows
                    if ($row -match '^[|\s-:]+$') { return }
                    if ($row -match '^\|\s*Case Name\s*\|') { return }
                    if ($row -match '^\|\s*-+\s*\|') { return }
                    return $row
                }
            )
            $appendixRows = @($appendixRows | Where-Object { $_ })
            if ($apiSurfaceExpected -and $appendixRows.Count -eq 0) {
                $blockingIssues += "api-appendix-empty"
            }
        }
    }

    $configPath = Join-Path $DocsPath "config-catalog.md"
    if (Test-Path $configPath) {
        $configContent = Get-Content $configPath -Raw
        $configSection = Get-MarkdownSectionBlock -Content $configContent -SectionName "Configuration Options"
        $configRows = Get-MarkdownTableDataRows -SectionContent $configSection
        if ($configRows.Count -eq 0) {
            $blockingIssues += "config-options-table-empty"
        }

        $badColumnRows = @($configRows | Where-Object { ([regex]::Matches($_, '\|')).Count -lt 7 })
        if ($badColumnRows.Count -gt 0) {
            $blockingIssues += "config-options-malformed-rows:$($badColumnRows.Count)"
        }

        $envSection = Get-MarkdownSectionBlock -Content $configContent -SectionName "Environment Variables"
        $envRows = Get-MarkdownTableDataRows -SectionContent $envSection
        if ($envRows.Count -eq 0) {
            $warnings += "environment-variables-table-empty"
        }
    }

    $manifestPath = Join-Path $DocsPath "evidence\manifest.json"
    if (Test-Path $manifestPath) {
        try {
            $manifest = Get-Content $manifestPath -Raw | ConvertFrom-Json -Depth 120
            if ($null -eq $manifest.markdownChecksums -or @($manifest.markdownChecksums).Count -eq 0) {
                $blockingIssues += "manifest-markdown-checksums-missing"
            }
            if ($null -eq $manifest.signoff) {
                $blockingIssues += "manifest-signoff-missing"
            }
        }
        catch {
            $blockingIssues += "manifest-unparseable"
        }
    }

    $evidenceGraphPath = Join-Path $DocsPath "evidence\evidence-graph.json"
    if (Test-Path $evidenceGraphPath) {
        try {
            $graph = Get-Content $evidenceGraphPath -Raw | ConvertFrom-Json -Depth 120
            $entities = @($graph.entities)
            $missingEnrichment = @(
                $entities | Where-Object {
                    $null -eq $_.inferred -or
                    [string]::IsNullOrWhiteSpace([string]$_.dedupeKey) -or
                    [string]::IsNullOrWhiteSpace([string]$_.ownership) -or
                    [string]::IsNullOrWhiteSpace([string]$_.runtimeRelevance) -or
                    [string]::IsNullOrWhiteSpace([string]$_.sensitivity)
                }
            )
            if ($missingEnrichment.Count -gt 0) {
                $blockingIssues += ("evidence-graph-enrichment-missing:{0}" -f $missingEnrichment.Count)
            }
        }
        catch {
            $blockingIssues += "evidence-graph-unparseable"
        }
    }

    $score = [Math]::Max(0, (100 - ($blockingIssues.Count * 20) - ($warnings.Count * 5)))
    return [ordered]@{
        score = [Math]::Round($score, 1)
        passed = ($blockingIssues.Count -eq 0)
        blockingIssues = $blockingIssues
        warnings = $warnings
    }
}

$apiDocCount = Get-DocRouteCount -ApiDocPath (Join-Path $docsPath "api-inventory.md")
$apiCodeCount = Get-CodeRouteCount -RootPath $RootPath
$apiCoverage = if ($apiCodeCount -eq 0) { if ($apiDocCount -eq 0) { 100 } else { 0 } } else { [Math]::Round(([Math]::Min($apiDocCount, $apiCodeCount) / $apiCodeCount) * 100, 1) }
# Framework-aware calibration: for Classic ASP / ASP.NET Web Forms, config + data-model
# coverage measure the classic-ASP artifacts (config-file keys; ADO/SQL data objects)
# as a documented/expected ratio. All other frameworks keep the C#-calibrated scorers.
$script:ClassicAspCalibration = [ordered]@{ config = $null; dataModel = $null }
$isClassicAspTarget = Get-AppDocIsClassicAspTarget -RootPath $RootPath
if ($isClassicAspTarget) {
    $configCoverage = Get-ClassicAspConfigCoverage -RootPath $RootPath -ConfigDocPath (Join-Path $docsPath "config-catalog.md")
    $dataCoverage = Get-ClassicAspDataModelCoverage -RootPath $RootPath -ModelDocPath (Join-Path $docsPath "data-model.md")
} else {
    $configCoverage = Get-ConfigKeyCoverage -RootPath $RootPath -ConfigDocPath (Join-Path $docsPath "config-catalog.md")
    $dataCoverage = Get-DataModelCoverage -RootPath $RootPath -ModelDocPath (Join-Path $docsPath "data-model.md")
}
$redactionSafetyScore = Get-RedactionSafetyScore -ConfigDocPath (Join-Path $docsPath "config-catalog.md")
$conformanceScore = Get-ConformanceScore -DocsPath $docsPath
# Discipline-layer sub-checks (added by the conformance gate). Each 0..100.
$sectionSpineCoverageScore = Get-SectionSpineCoverageScore -DocsPath $docsPath
$epistemicCoverageScore = Get-EpistemicCoverageScore -DocsPath $docsPath
$reVerifiabilityScore = Get-ReVerifiabilityScore -DocsPath $docsPath
$claimGroundingScore = Get-ClaimGroundingScore -DocsPath $docsPath
$documentationFreshnessScore = Get-DocumentationFreshnessScore -DocsPath $docsPath
$contradictionAnalysis = Get-ContradictionAnalysis -DocsPath $docsPath -EvidenceRoot $evidenceRoot
$architectureContradictionAnalysis = Get-ArchitectureContradictionAnalysis -RootPath $RootPath -DocsPath $docsPath
$allContradictionIssues = @($contradictionAnalysis.issues + $architectureContradictionAnalysis.issues)
$contradictionConsistencyScore = [Math]::Min([double]$contradictionAnalysis.score, [double]$architectureContradictionAnalysis.score)
$taskGuideOutcomes = Get-TaskGuideOutcomeMetrics -DocsPath $docsPath -EvidenceRoot $evidenceRoot
$taskGuideActionabilityScore = [double]$taskGuideOutcomes.actionabilityScore
$taskGuideEvidenceCoverageScore = [double]$taskGuideOutcomes.evidenceCoverageScore
$taskGuideTimeScore = [double]$taskGuideOutcomes.taskCompletionTimeScore
$metricDriftAnalysis = Get-CrossArtifactMetricDriftAnalysis -DocsPath $docsPath
$metricDriftScore = [double]$metricDriftAnalysis.score
${policyGatesRaw} = Get-PolicyGateAnalysis -DocsPath $docsPath -RootPath $RootPath
$compositePolicyGate = [ordered]@{
    blockingIssues = @($policyGatesRaw.blockingIssues)
    score = [double]$policyGatesRaw.score
    passed = $policyGatesRaw.passed
}
if (@($architectureContradictionAnalysis.issues).Count -gt 0) {
    $compositePolicyGate.blockingIssues += $architectureContradictionAnalysis.issues
    $compositePolicyGate.passed = $false
    $compositePolicyGate.score = [Math]::Max(0, ($compositePolicyGate.score - (@($architectureContradictionAnalysis.issues).Count * 20)))
}
if (@($metricDriftAnalysis.issues).Count -gt 0) {
    $compositePolicyGate.blockingIssues += $metricDriftAnalysis.issues
    $compositePolicyGate.passed = $false
    $compositePolicyGate.score = [Math]::Max(0, ($compositePolicyGate.score - (@($metricDriftAnalysis.issues).Count * 10)))
}
$policyGates = $compositePolicyGate
$policyGateScore = [double]$policyGates.score

foreach ($issue in @($allContradictionIssues)) {
    Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Cross-artifact contradiction detected: $issue" -Component "validation" -FilePath $docsPath | Out-Null
}

foreach ($issue in @($metricDriftAnalysis.issues)) {
    Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Cross-artifact metric drift detected: $issue" -Component "validation" -FilePath $docsPath | Out-Null
}

foreach ($issue in @($taskGuideOutcomes.issues)) {
    Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Task outcome issue detected: $issue" -Component "validation" -FilePath (Join-Path $docsPath "task-guides.md") | Out-Null
}

foreach ($issue in @($policyGates.blockingIssues)) {
    Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Policy gate blocking issue: $issue" -Component "validation" -FilePath $docsPath | Out-Null
}

foreach ($warning in @($policyGates.warnings)) {
    Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Policy gate warning: $warning" -Component "validation" -FilePath $docsPath | Out-Null
}

$evidencePresence = [Math]::Round(((($expectedEvidenceArtifacts.Count - $missingEvidence.Count) / [Math]::Max(1, $expectedEvidenceArtifacts.Count)) * 100), 1)
$semanticValues = @($contractValidationResults | ForEach-Object { [double]$_.score })
$evidenceValues = @($evidenceContractResults | ForEach-Object { [double]$_.score })
$semanticContractScore = if ($semanticValues.Count -gt 0) { [Math]::Round((($semanticValues | Measure-Object -Average).Average), 1) } else { 0 }
$evidenceContractScore = if ($evidenceValues.Count -gt 0) { [Math]::Round((($evidenceValues | Measure-Object -Average).Average), 1) } else { 0 }

$validatorPassRate = [Math]::Round(((@($validatorResults | Where-Object { $_.passed }).Count / [Math]::Max(1, $validatorResults.Count)) * 100), 1)
$artifactPresence = [Math]::Round(((($artifactFiles.Count - $missing.Count) / [Math]::Max(1, $artifactFiles.Count)) * 100), 1)
$overallScoreRaw = [Math]::Round((($validatorPassRate + $artifactPresence + $evidencePresence + $semanticContractScore + $evidenceContractScore + $apiCoverage + $configCoverage + $dataCoverage + $redactionSafetyScore + $conformanceScore + $sectionSpineCoverageScore + $epistemicCoverageScore + $reVerifiabilityScore + $claimGroundingScore + $documentationFreshnessScore + $contradictionConsistencyScore + $metricDriftScore + $policyGateScore) / 18), 1)

# Flag a vacuously-true re-verifiability score (no Verified claims to re-run).
if ($reVerifiabilityScore -ge 100 -and (Test-Path (Join-Path $docsPath "verification-appendix.md"))) {
    $appendixContent = Get-Content (Join-Path $docsPath "verification-appendix.md") -Raw
    if ($appendixContent -notmatch '(?m)\| Verified \|') {
        Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Re-verifiability is vacuously 100: the Verification Appendix contains no 'Verified' rows to re-run." -Component "validation" -FilePath (Join-Path $docsPath "verification-appendix.md") | Out-Null
    }
}

$qualityPenaltyBreakdown = Get-QualityPenaltyBreakdown -DocsPath $docsPath -Contradictions $allContradictionIssues
$penaltyDeduction = [Math]::Round([Math]::Min(45, ($qualityPenaltyBreakdown.totalPenaltyPoints / [Math]::Max(1, $qualityPenaltyBreakdown.artifactCount))), 1)
$overallScore = [Math]::Max(0, [Math]::Round(($overallScoreRaw - $penaltyDeduction), 1))

$hasBlockingIssues = (@($policyGates.blockingIssues).Count -gt 0)
$weakCoverage = ($evidencePresence -lt 70 -or $semanticContractScore -lt 65 -or $evidenceContractScore -lt 65 -or $claimGroundingScore -lt 50 -or $sectionSpineCoverageScore -lt 50 -or $epistemicCoverageScore -lt 50 -or $reVerifiabilityScore -lt 50)
$validationStatus = if ($hasBlockingIssues -or $overallScore -lt $Threshold) {
    "fail"
}
elseif ($weakCoverage) {
    "pass-with-weak-coverage"
}
else {
    "pass"
}

$result = [ordered]@{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    strict = $Strict.IsPresent
    threshold = $Threshold
    status = $validationStatus
    overallScore = $overallScore
    overallScoreRaw = $overallScoreRaw
    penaltyDeduction = $penaltyDeduction
    metrics = [ordered]@{
        validatorPassRate = $validatorPassRate
        artifactPresence = $artifactPresence
        evidencePresence = $evidencePresence
        semanticContractScore = $semanticContractScore
        evidenceContractScore = $evidenceContractScore
        apiCoverage = $apiCoverage
        configCoverage = $configCoverage
        dataModelCoverage = $dataCoverage
        redactionSafetyScore = $redactionSafetyScore
        conformanceScore = $conformanceScore
        sectionSpineCoverageScore = $sectionSpineCoverageScore
        epistemicCoverageScore = $epistemicCoverageScore
        reVerifiabilityScore = $reVerifiabilityScore
        claimGroundingScore = $claimGroundingScore
        documentationFreshnessScore = $documentationFreshnessScore
        contradictionConsistencyScore = $contradictionConsistencyScore
        taskGuideActionabilityScore = $taskGuideActionabilityScore
        taskGuideEvidenceCoverageScore = $taskGuideEvidenceCoverageScore
        taskGuideTimeToCompleteMinutes = $taskGuideOutcomes.estimatedCompletionMinutes
        taskGuideTimeScore = $taskGuideTimeScore
        metricDriftScore = $metricDriftScore
        policyGateScore = $policyGateScore
    }
    qualityPenaltyBreakdown = $qualityPenaltyBreakdown
    missingArtifacts = $missing
    missingEvidenceArtifacts = $missingEvidence
    validators = $validatorResults
    contractValidation = $contractValidationResults
    evidenceContractValidation = $evidenceContractResults
    contradictions = @($allContradictionIssues)
    architectureContradiction = $architectureContradictionAnalysis
    metricDrift = $metricDriftAnalysis
    taskGuideOutcomes = $taskGuideOutcomes
    policyGates = $policyGates
    coverageCalibration = [ordered]@{
        path = if ($isClassicAspTarget) { "classic-asp" } else { "csharp-default" }
        framework = if ($isClassicAspTarget) { "Classic ASP" } else { "csharp" }
        note = if ($isClassicAspTarget) { "config + data-model coverage measured against classic-ASP source artifacts (config-file keys; ADO/SQL data objects) as documented/expected ratios." } else { "config + data-model coverage measured with the C#-calibrated scorers (appsettings/config keys; model classes)." }
        config = $script:ClassicAspCalibration.config
        dataModel = $script:ClassicAspCalibration.dataModel
    }
}

# --- PRISTINE CHECK (Step 1b) — DEPTH measurement + OPT-IN gate --------------
# A per-section DEPTH measurement of the 20 composed sections against the
# HELP_DESK benchmark. It is computed here (pure, deterministic function of the
# composed doc + evidence artifacts) and added to the scorecard PURELY for
# reporting: it is added to $result AFTER status (line ~2131) and overallScore
# (line ~2127) are computed and frozen above, so the DEPTH measurement CANNOT
# change the structural conformance status (pass/fail) or overallScore.
#
# MODES (Deliverable A): the pristine check has two EXPLICIT modes.
#   REPORT-ONLY (DEFAULT, -PristineGate OFF): the sub-score is purely additive —
#       pristine.blocking=false, pristineGate.mode='report-only', enabled=false,
#       blocked=false. NEVER changes status or overallScore.
#   BLOCKING (OPT-IN, -PristineGate ON): the pristine check becomes a real gate
#       that BLOCKS the run when emptyCount>0 OR subScore<floor (-PristineFloor).
#       OWNER_REQUIRED cells are EXCLUDED (pending /appdoc.enhance, not failures).
#       The decision is the PURE FUNCTION Test-AppDocPristineGate (unit-testable).
#       When it blocks, status flips to 'blocked' (a NEW additive blocking
#       condition); overallScore is UNCHANGED (structural conformance untouched).
# If the pristine module is absent or errors, the fields are honest records so the
# scorecard shape stays stable and the check is never silently skipped.
if ($hasPristine) {
    try {
        $pristineAssessment = Get-AppDocPristineAssessment -DocsPath $docsPath
        # pristine.blocking is MODE-EXPLICIT: false in report-only (DEFAULT), true in
        # blocking (OPT-IN). It reflects the mode, not a per-run outcome.
        $result['pristine'] = [ordered]@{
            blocking       = [bool]$PristineGate
            mode           = if ($PristineGate) { 'blocking' } else { 'report-only' }
            additive       = $true
            note           = if ($PristineGate) { 'Per-section depth measurement vs the HELP_DESK benchmark (Step 1b). MODE=blocking (OPT-IN, -PristineGate): the pristine gate may block the run (see pristineGate). overallScore is still untouched.' } else { 'Per-section depth measurement vs the HELP_DESK benchmark (Step 1b). MODE=report-only (DEFAULT): NON-BLOCKING — does not change status or overallScore.' }
            subScore       = $pristineAssessment.subScore
            counts         = [ordered]@{
                PASS           = [int]$pristineAssessment.counts.PASS
                WEAK           = [int]$pristineAssessment.counts.WEAK
                EMPTY          = [int]$pristineAssessment.counts.EMPTY
                OWNER_REQUIRED = [int]$pristineAssessment.counts.OWNER_REQUIRED
                NA             = [int]$pristineAssessment.counts.NA
                scored         = [int]$pristineAssessment.scoredCount
                total          = [int]$pristineAssessment.totalSections
            }
            naSections     = @($pristineAssessment.records | Where-Object { [bool]$_.frameworkNA } | ForEach-Object { [string]$_.section })
            reVerifiable   = [bool]$pristineAssessment.reVerifiable
            sections       = @($pristineAssessment.records | ForEach-Object {
                [ordered]@{
                    section      = [string]$_.section
                    status       = [string]$_.status
                    reason       = [string]$_.reason
                    rowCount     = [int]$_.rowCount
                    sourceSupport= [int]$_.sourceSupport
                    benchmarkRef = [string]$_.benchmarkRef
                    ownerPending = [bool]$_.ownerPending
                    frameworkNA  = [bool]$_.frameworkNA
                }
            })
            report         = 'docs/pristine-report.md'
            evidence       = 'docs/evidence/pristine.evidence.json'
            determinismHash= [string]$pristineAssessment.determinismHash
        }

        # --- PRISTINE GATE decision (Deliverable B) — ADDITIVE, OPT-IN ---------
        # The gate decision is a PURE FUNCTION (Test-AppDocPristineGate) so it is
        # unit-testable without a real target. OWNER_REQUIRED is EXCLUDED (it is
        # passed in but the function never uses it to block). N/A is already
        # excluded from subScore. The gate is ADDITIVE: it NEVER changes overallScore
        # (the structural conformance composite); it only MAY flip status to 'blocked'
        # when enabled (blocking mode) AND a violation exists.
        $pristineGateMode    = if ($PristineGate) { 'blocking' } else { 'report-only' }
        $pristineGateEnabled = [bool]$PristineGate
        # Precompute the gate inputs into plain typed vars (the pure decision fn takes
        # primitives). OWNER_REQUIRED is passed in but the fn NEVER uses it to block.
        $pgEmpty = [int]$pristineAssessment.counts.EMPTY
        $pgSub   = [double]$pristineAssessment.subScore
        $pgOwner = [int]$pristineAssessment.counts.OWNER_REQUIRED
        $pristineGateDec = Test-AppDocPristineGate -EmptyCount $pgEmpty -SubScore $pgSub -Floor $PristineFloor -OwnerRequiredCount $pgOwner -Enabled $pristineGateEnabled
        $result['pristineGate'] = [ordered]@{
            mode           = $pristineGateMode
            enabled        = $pristineGateEnabled
            floor          = [int]$PristineFloor
            emptyCount     = [int]$pgEmpty
            subScore       = [double]$pgSub
            floorMet       = [bool]$pristineGateDec.floorMet
            blocked        = [bool]$pristineGateDec.blocked
            blockingIssues = @($pristineGateDec.blockingIssues)
            note           = if ($pristineGateEnabled) { 'BLOCKING mode (OPT-IN, -PristineGate): the run is blocked when emptyCount>0 OR subScore<floor; OWNER_REQUIRED is excluded (pending /appdoc.enhance, not a failure).' } else { 'REPORT-ONLY mode (DEFAULT): depth measurement, never blocks — pristineGate.blocked=false; status/overallScore unchanged.' }
        }
        # BLOCK path (additive): when blocking mode AND a violation, flip the run's
        # status to 'blocked' (a NEW blocking condition). overallScore is UNCHANGED —
        # the structural conformance composite + pass/fail logic above are untouched.
        if ($pristineGateEnabled -and $pristineGateDec.blocked) {
            $result['status'] = 'blocked'
            $pgIssues = (@($pristineGateDec.blockingIssues) -join '; ')
            Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Error" -Message "Pristine gate BLOCKED the run (mode=blocking): $pgIssues" -Component "validation" -FilePath $docsPath | Out-Null
        }
    } catch {
        $result['pristine'] = [ordered]@{ blocking = [bool]$PristineGate; mode = if ($PristineGate) { 'blocking' } else { 'report-only' }; additive = $true; error = [string]$_.Exception.Message }
        $result['pristineGate'] = [ordered]@{ mode = if ($PristineGate) { 'blocking' } else { 'report-only' }; enabled = [bool]$PristineGate; floor = [int]$PristineFloor; error = [string]$_.Exception.Message }
    }
} else {
    $result['pristine'] = [ordered]@{ blocking = [bool]$PristineGate; mode = if ($PristineGate) { 'blocking' } else { 'report-only' }; additive = $true; error = 'AppDoc.Pristine.psm1 not present' }
    $result['pristineGate'] = [ordered]@{ mode = if ($PristineGate) { 'blocking' } else { 'report-only' }; enabled = [bool]$PristineGate; floor = [int]$PristineFloor; error = 'AppDoc.Pristine.psm1 not present' }
}


# Write only the JSON payload to the output file, suppressing any console/table output.
# Ensure the scratch dir exists (fresh checkouts may not have tmp/logs) and guard
# the write so a failure to log the temp file can never block the canonical report.
$jsonOutPath = Join-Path $RootPath "tmp\logs\validate-documentation.out.json"
$jsonOutDir = Split-Path $jsonOutPath -Parent
if (-not (Test-Path $jsonOutDir)) {
    try { New-Item -Path $jsonOutDir -ItemType Directory -Force | Out-Null } catch { }
}
try {
    $result | ConvertTo-Json -Depth 20 | Out-File -FilePath $jsonOutPath -Encoding UTF8
}
catch {
    Write-Warning ("Could not write scratch validation log {0}: {1}" -f $jsonOutPath, $_.Exception.Message)
}

# Write the CANONICAL validation report to docs/validation-report.json. This is the
# authoritative, committed validation result (referenced by the prompts, the
# provenance policy gate, and the companion-summary generator). It must be rewritten
# on every run so the three committed reports (quality-report.json, validation-report.json,
# diagnostics-report.json) come from the SAME run and agree. The provenance block below
# is self-contained (computed here) so the canonical report is internally consistent
# regardless of whether the root-level provenance footer is applied by the orchestrator.
$reportCommitHash = "unknown"
try {
    $reportCommitHash = (& git -C $RootPath rev-parse --short HEAD 2>$null | Out-String).Trim()
    if ([string]::IsNullOrWhiteSpace($reportCommitHash)) { $reportCommitHash = "unknown" }
}
catch {
    $reportCommitHash = "unknown"
}
$reportProvenance = [ordered]@{
    generatorVersion = "appdoc-validate-documentation/3.0.0"
    commitHash = $reportCommitHash
    generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    profile = "default"
    scope = "."
    confidenceInferenceFlags = @("deterministic", "evidence-backed")
}
$canonicalReport = [ordered]@{}
foreach ($key in $result.Keys) { $canonicalReport[$key] = $result[$key] }
$canonicalReport["provenance"] = $reportProvenance
$canonicalReportPath = Join-Path $docsPath "validation-report.json"
$canonicalReport | ConvertTo-Json -Depth 20 | Out-File -FilePath $canonicalReportPath -Encoding UTF8

if (Get-Command Export-AppDocDiagnostics -ErrorAction SilentlyContinue) {
    Export-AppDocDiagnostics -Path (Join-Path $docsPath "validation-diagnostics.json") -AdditionalData @{ validation = $result } | Out-Null
}

if ($Json) {
    $result | ConvertTo-Json -Depth 20
}
else {
    Write-Host "Validation score: $overallScore" -ForegroundColor Cyan
    Write-Host "Validation report: $reportPath"
}

if ($Strict -and $overallScore -lt $Threshold) {
    Write-Error "Validation score $overallScore is below threshold $Threshold"
    exit 1
}

if ($Strict -and @($policyGates.blockingIssues).Count -gt 0) {
    $issueSummary = (@($policyGates.blockingIssues) -join "; ")
    Write-Error "Validation policy gates failed: $issueSummary"
    exit 1
}

if ($Strict -and $validationStatus -eq "pass-with-weak-coverage") {
    Write-Error "Validation status is pass-with-weak-coverage; strict mode requires full pass."
    exit 1
}
