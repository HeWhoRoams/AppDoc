param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [switch]$Strict,
    [ValidateRange(1,100)]
    [int]$Threshold = 80,
    [switch]$Json
)

$diagnosticsModule = Join-Path $PSScriptRoot "modules\AppDoc.Diagnostics.psm1"
$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"

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

$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) {
    Write-Error "docs directory not found: $docsPath"
    exit 1
}

if (Get-Command Initialize-AppDocDiagnostics -ErrorAction SilentlyContinue) {
    Initialize-AppDocDiagnostics -RootPath $RootPath -OutputPath $docsPath -Reset
}

$artifactFiles = @(
    "start-here.md",
    "overview.md",
    "api-inventory.md",
    "data-model.md",
    "config-catalog.md",
    "build-cookbook.md",
    "test-catalog.md",
    "task-guides.md",
    "debt-register.md",
    "dependencies-catalog.md"
)

$missing = @()
foreach ($artifact in $artifactFiles) {
    $path = Join-Path $docsPath $artifact
    if (-not (Test-Path $path)) {
        $missing += $artifact
        Write-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Warning" -Message "Artifact missing: $artifact" -Component "validation" -FilePath $path | Out-Null
    }
}

$expectedEvidenceArtifacts = @(
    "start-here",
    "overview",
    "api-inventory",
    "data-model",
    "config-catalog",
    "build-cookbook",
    "test-catalog",
    "task-guides",
    "debt-register",
    "dependencies-catalog"
)

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

$validatorScripts = @(
    @{ script = "validate-start-here.ps1"; artifact = "start-here.md" },
    @{ script = "validate-overview.ps1"; artifact = "overview.md" },
    @{ script = "validate-api-inventory.ps1"; artifact = "api-inventory.md" },
    @{ script = "validate-data-model.ps1"; artifact = "data-model.md" },
    @{ script = "validate-config-catalog.ps1"; artifact = "config-catalog.md" },
    @{ script = "validate-build-cookbook.ps1"; artifact = "build-cookbook.md" },
    @{ script = "validate-test-catalog.ps1"; artifact = "test-catalog.md" },
    @{ script = "validate-task-guides.ps1"; artifact = "task-guides.md" },
    @{ script = "validate-debt-register.ps1"; artifact = "debt-register.md" },
    # dependencies-catalog is validated via generic contract validation rather than a dedicated script
    @{ script = "validate-dependencies-catalog.ps1"; artifact = "dependencies-catalog.md" }
)

$artifactMap = @{
    "start-here" = "start-here.md"
    "overview" = "overview.md"
    "api-inventory" = "api-inventory.md"
    "data-model" = "data-model.md"
    "config-catalog" = "config-catalog.md"
    "build-cookbook" = "build-cookbook.md"
    "test-catalog" = "test-catalog.md"
    "task-guides" = "task-guides.md"
    "debt-register" = "debt-register.md"
    "dependencies-catalog" = "dependencies-catalog.md"
}

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
    foreach ($requiredSection in @($contract.requiredSections)) {
        if (-not ([regex]::IsMatch($content, "(?im)^##\s+" + [regex]::Escape([string]$requiredSection) + "\b"))) {
            $missingSections += [string]$requiredSection
            Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Required section missing ($Artifact): $requiredSection" -Component "validation" -FilePath $DocPath | Out-Null
        }
    }

    $bannedHits = @()
    foreach ($pattern in @(Get-AppDocBannedContentPatterns)) {
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
    $content = Get-Content $ApiDocPath -Raw
    return ([regex]::Matches($content, '^\|\s*``?[^|]+\|\s*``?/[^|]+\|\s*(GET|POST|PUT|DELETE|PATCH|ANY)', 'Multiline,IgnoreCase')).Count
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

function Get-ConfigKeyCoverage {
    param([string]$RootPath, [string]$ConfigDocPath)
    if (-not (Test-Path $ConfigDocPath)) { return 100 }

    $doc = Get-Content $ConfigDocPath -Raw
    $docKeys = [regex]::Matches($doc, '(?im)^\|\s*`{0,2}([^|`\r\n]+?)`{0,2}\s*\|') | ForEach-Object { $_.Groups[1].Value.Trim() } | Select-Object -Unique
    if (-not $docKeys -or $docKeys.Count -eq 0) { return 100 }

    $configContent = @()
    foreach ($pattern in @("appsettings*.json", "Web.config", "App.config", ".env*")) {
        $configContent += Get-ChildItem -Path $RootPath -Recurse -Filter $pattern -File -ErrorAction SilentlyContinue | ForEach-Object { Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue }
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

    $doc = Get-Content $ModelDocPath -Raw
    $modelNames = [regex]::Matches($doc, '^##\s+([A-Za-z_][\w]+)', 'Multiline') | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique
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

function Get-HumanUsabilityScore {
    param([string]$DocsPath)

    $docNames = @(
        "start-here.md",
        "overview.md",
        "api-inventory.md",
        "data-model.md",
        "config-catalog.md",
        "build-cookbook.md",
        "test-catalog.md",
        "task-guides.md",
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

        if ($content -match '(?im)^##\s+(Executive Summary|15-Minute Orientation)\b') {
            $summarySections++
        }

        $linkCount += ([regex]::Matches($content, '\[[^\]]+\]\([^)]+\)')).Count
        $placeholderHits += ([regex]::Matches($content, '(?im)Describe the purpose|Document\s+(the|where|how)|Check for|Consult|Review|\[TODO\]|\[TBD\]')).Count

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

function Get-ClaimGroundingScore {
    param([string]$DocsPath)

    $docNames = @(
        "start-here.md",
        "overview.md",
        "api-inventory.md",
        "data-model.md",
        "config-catalog.md",
        "build-cookbook.md",
        "test-catalog.md",
        "task-guides.md",
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
        "start-here.md",
        "overview.md",
        "api-inventory.md",
        "data-model.md",
        "config-catalog.md",
        "build-cookbook.md",
        "test-catalog.md",
        "task-guides.md",
        "debt-register.md",
        "dependencies-catalog.md"
    )

    $existing = @($docNames | ForEach-Object { Join-Path $DocsPath $_ } | Where-Object { Test-Path $_ })
    if ($existing.Count -eq 0) { return 0 }

    $freshCount = 0
    foreach ($doc in $existing) {
        $content = Get-Content $doc -Raw
        $m = [regex]::Match($content, '(?im)^\*\*Generated\*\*:\s*([^\r\n]+)$')
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

    $docToArtifact = [ordered]@{
        "start-here.md" = "start-here"
        "overview.md" = "overview"
        "api-inventory.md" = "api-inventory"
        "data-model.md" = "data-model"
        "config-catalog.md" = "config-catalog"
        "build-cookbook.md" = "build-cookbook"
        "test-catalog.md" = "test-catalog"
        "task-guides.md" = "task-guides"
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
                    if ([Math]::Abs($startHereApi - $apiEvidenceCount) -gt 0) {
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
                    if ([Math]::Abs($startHereModels - $modelEvidenceCount) -gt 0) {
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

function Get-TaskGuideOutcomeMetrics {
    param(
        [string]$DocsPath,
        [string]$EvidenceRoot
    )

    $taskGuidesPath = Join-Path $DocsPath "task-guides.md"
    if (-not (Test-Path $taskGuidesPath)) {
        return [ordered]@{
            actionabilityScore = 0
            evidenceCoverageScore = 0
            estimatedCompletionMinutes = 0
            taskCompletionTimeScore = 0
            issues = @("task-guides-missing")
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

    if ($avgSteps -lt 3) {
        $issues += "task-guide-steps-low:$([Math]::Round($avgSteps,1))"
    }
    if ($avgSnapshots -lt 2) {
        $issues += "task-guide-evidence-snapshot-low:$([Math]::Round($avgSnapshots,1))"
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
            # Treat $summaryRecord as a single object, not an array
            if ($summaryRecord -and $summaryRecord.metadata) {
                $meta = $summaryRecord.metadata
                foreach ($key in @('endpointCount', 'buildCommandCount', 'dependencyCount', 'debtCount', 'testCount')) {
                    if ($meta.$key -and [int]$meta.$key -gt 0) {
                        $evidenceKeysSatisfied++
                    }
                }
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

function Get-MarkdownSectionBlock {
    param(
        [string]$Content,
        [string]$SectionName
    )

    if (-not $Content) { return "" }
    $pattern = "(?is)^##\s+" + [regex]::Escape($SectionName) + "\s*$\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($match.Success) {
        return [string]$match.Groups[1].Value
    }

    return ""
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
    param([string]$DocsPath)

    $blockingIssues = @()
    $warnings = @()

    $criticalDocs = @(
        "overview.md",
        "start-here.md",
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
    }

    $apiPath = Join-Path $DocsPath "api-inventory.md"
    if (Test-Path $apiPath) {
        $apiContent = Get-Content $apiPath -Raw
        $apiSection = Get-MarkdownSectionBlock -Content $apiContent -SectionName "API Endpoints"
        $apiRows = Get-MarkdownTableDataRows -SectionContent $apiSection
        if ($apiRows.Count -eq 0) {
            $blockingIssues += "api-endpoints-table-empty"
        }

        $blankPathRows = @($apiRows | Where-Object { $_ -match '^\|\s*``?[^|]+``?\s*\|\s*``?\s*``?\s*\|' })
        if ($blankPathRows.Count -gt 0) {
            $blockingIssues += "api-endpoints-blank-paths:$($blankPathRows.Count)"
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
$configCoverage = Get-ConfigKeyCoverage -RootPath $RootPath -ConfigDocPath (Join-Path $docsPath "config-catalog.md")
$dataCoverage = Get-DataModelCoverage -RootPath $RootPath -ModelDocPath (Join-Path $docsPath "data-model.md")
$redactionSafetyScore = Get-RedactionSafetyScore -ConfigDocPath (Join-Path $docsPath "config-catalog.md")
$humanUsabilityScore = Get-HumanUsabilityScore -DocsPath $docsPath
$claimGroundingScore = Get-ClaimGroundingScore -DocsPath $docsPath
$documentationFreshnessScore = Get-DocumentationFreshnessScore -DocsPath $docsPath
$contradictionAnalysis = Get-ContradictionAnalysis -DocsPath $docsPath -EvidenceRoot $evidenceRoot
$contradictionConsistencyScore = [double]$contradictionAnalysis.score
$taskGuideOutcomes = Get-TaskGuideOutcomeMetrics -DocsPath $docsPath -EvidenceRoot $evidenceRoot
$taskGuideActionabilityScore = [double]$taskGuideOutcomes.actionabilityScore
$taskGuideEvidenceCoverageScore = [double]$taskGuideOutcomes.evidenceCoverageScore
$taskGuideTimeScore = [double]$taskGuideOutcomes.taskCompletionTimeScore
$policyGates = Get-PolicyGateAnalysis -DocsPath $docsPath
$policyGateScore = [double]$policyGates.score

foreach ($issue in @($contradictionAnalysis.issues)) {
    Write-AppDocDiagnostic -Category "DETECTION_PATTERN_MISMATCH" -Severity "Warning" -Message "Cross-artifact contradiction detected: $issue" -Component "validation" -FilePath $docsPath | Out-Null
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
$overallScore = [Math]::Round((($validatorPassRate + $artifactPresence + $evidencePresence + $semanticContractScore + $evidenceContractScore + $apiCoverage + $configCoverage + $dataCoverage + $redactionSafetyScore + $humanUsabilityScore + $claimGroundingScore + $documentationFreshnessScore + $contradictionConsistencyScore + $taskGuideActionabilityScore + $taskGuideEvidenceCoverageScore + $taskGuideTimeScore + $policyGateScore) / 17), 1)

$result = [ordered]@{
    timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    strict = $Strict.IsPresent
    threshold = $Threshold
    overallScore = $overallScore
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
        humanUsabilityScore = $humanUsabilityScore
        claimGroundingScore = $claimGroundingScore
        documentationFreshnessScore = $documentationFreshnessScore
        contradictionConsistencyScore = $contradictionConsistencyScore
        taskGuideActionabilityScore = $taskGuideActionabilityScore
        taskGuideEvidenceCoverageScore = $taskGuideEvidenceCoverageScore
        taskGuideTimeToCompleteMinutes = $taskGuideOutcomes.estimatedCompletionMinutes
        taskGuideTimeScore = $taskGuideTimeScore
        policyGateScore = $policyGateScore
    }
    missingArtifacts = $missing
    missingEvidenceArtifacts = $missingEvidence
    validators = $validatorResults
    contractValidation = $contractValidationResults
    evidenceContractValidation = $evidenceContractResults
    contradictions = @($contradictionAnalysis.issues)
    taskGuideOutcomes = $taskGuideOutcomes
    policyGates = $policyGates
}

$reportPath = Join-Path $docsPath "validation-report.json"
$result | ConvertTo-Json -Depth 20 | Out-File -FilePath $reportPath -Encoding UTF8

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
