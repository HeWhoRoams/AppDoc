#requires -Version 7.2
#
# generate-evidence-register.ps1
#
# Purpose: Produce the §14 Evidence Register (docs/evidence-register.md) from the
#          deterministic evidence layer. Each evidence record becomes one row:
#          | Finding | Status | Supporting Artifact | Limitation |.
#
#          Status is assigned deterministically via AppDoc.Epistemic.psm1:
#            Verified         - concrete file + line (or searchable value) evidence
#            Inferred         - generator/model interpretation, no file+line
#            Partly verified  - file reference without a confirmable line/value
#            Unknown          - no evidence establishes the claim
#
#          Reads docs/evidence/*.evidence.enriched.json first and falls back to
#          docs/evidence/*.evidence.json so it works whether or not enrichment has
#          been run. Deterministic. No network. No LLM.
#
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

$epistemicModule = Join-Path $PSScriptRoot "modules\AppDoc.Epistemic.psm1"
if (-not (Test-Path $epistemicModule)) {
    Write-Error "Required module not found: $epistemicModule"
    exit 1
}
Import-Module $epistemicModule -Force -ErrorAction Stop
$helpersPath = Join-Path $PSScriptRoot 'template-helpers.ps1'
# Required: a missing helpers file must stop here, not fail later with "command not found".
if (-not (Test-Path -LiteralPath $helpersPath)) { Write-Error "Required helpers file not found: $helpersPath"; exit 1 }
. $helpersPath

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$docsPath = (Get-AppDocDocsPath -RootPath $RootPath)
if (-not (Test-Path $docsPath)) {
    New-Item -Path $docsPath -ItemType Directory -Force | Out-Null
}
$evidencePath = Join-Path $docsPath "evidence"
$outputPath = Join-Path $docsPath "evidence-register.md"

Write-Host "🧾  Generating Evidence Register (section 14)..." -ForegroundColor Cyan

# --- collect evidence files: enriched preferred, base fallback ----------------
$enriched = @()
$base = @()
if (Test-Path $evidencePath) {
    $enriched = @(Get-ChildItem -Path $evidencePath -Filter "*.evidence.enriched.json" -File -ErrorAction SilentlyContinue | Sort-Object Name)
    $base = @(Get-ChildItem -Path $evidencePath -Filter "*.evidence.json" -File -ErrorAction SilentlyContinue | Sort-Object Name)
}
# Reports ABOUT the generated documentation are not source evidence and are written after
# this register (pristine scores the composed doc). Including them made a re-run list the
# previous run's report rows, so a first run and a re-run differed.
$derivedReportArtifacts = @('pristine')
$isSourceEvidence = { param($f) $k = ([IO.Path]::GetFileNameWithoutExtension($f.Name) -replace '\.evidence(\.enriched)?$', ''); $derivedReportArtifacts -notcontains $k }
$enriched = @($enriched | Where-Object { & $isSourceEvidence $_ })
$base = @($base | Where-Object { & $isSourceEvidence $_ })

# Build an artifact-keyed list of source files to read (enriched wins over base).
$enrichedArtifacts = @{}
foreach ($f in $enriched) {
    $key = [IO.Path]::GetFileNameWithoutExtension($f.Name) -replace '\.evidence\.enriched$', ''
    $enrichedArtifacts[$key] = $f.FullName
}
$filesToRead = @()
foreach ($f in $base) {
    $key = [IO.Path]::GetFileNameWithoutExtension($f.Name) -replace '\.evidence$', ''
    if ($enrichedArtifacts.ContainsKey($key)) { $filesToRead += $enrichedArtifacts[$key] }
    else { $filesToRead += $f.FullName }
}
# Include enriched files that have no base counterpart.
foreach ($key in @($enrichedArtifacts.Keys | Sort-Object)) {
    $covered = $false
    foreach ($f in $base) {
        $bkey = [IO.Path]::GetFileNameWithoutExtension($f.Name) -replace '\.evidence$', ''
        if ($bkey -eq $key) { $covered = $true; break }
    }
    if (-not $covered) { $filesToRead += $enrichedArtifacts[$key] }
}

# --- load records -------------------------------------------------------------
$allRecords = @()
foreach ($file in $filesToRead) {
    try {
        $payload = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -Depth 120
    }
    catch {
        Write-Warning "Could not parse evidence file: $file ($($_.Exception.Message))"
        continue
    }
    if ($null -eq $payload) { continue }
    $records = @($payload.records)
    foreach ($rec in $records) {
        if ($null -eq $rec) { continue }
        $rec | Add-Member -NotePropertyName "_artifact" -NotePropertyValue ([string]$payload.artifact) -Force -ErrorAction SilentlyContinue
        $allRecords += $rec
    }
}

# --- build rows ---------------------------------------------------------------
$limitationForStatus = {
    param([string]$Status)
    switch ($Status) {
        'Verified'        { 'Runtime behavior not executed' }
        'Inferred'        { 'Interpretation not confirmed by runtime' }
        'Partly verified' { 'File reference present; line/value not confirmed' }
        'Unknown'         { 'Not established by repository' }
        default           { 'Not established by repository' }
    }
}
$rowLines = @()
$rowLines += '| Finding | Status | Supporting Artifact | Limitation |'
$rowLines += '|---|---|---|---|'

$statusTally = @{}
foreach ($rec in $allRecords) {
    $status = [string](Resolve-AppDocEpistemicStatus -Record $rec -RootPath $RootPath)

    # Finding: human-readable label from the record.
    $finding = [string]$rec.name
    if ([string]::IsNullOrWhiteSpace($finding)) { $finding = [string]$rec.kind }
    if ([string]::IsNullOrWhiteSpace($finding)) { $finding = '(unnamed record)' }

    # Supporting artifact: the file (and line, when known).
    $file = Resolve-AppDocEpistemicFile -Record $rec
    $line = Resolve-AppDocEpistemicLine -Record $rec
    $artifact = ''
    if (-not [string]::IsNullOrWhiteSpace($file)) {
        if ($line -ne $null) { $artifact = ($file + ':' + $line) }
        else { $artifact = $file }
    }
    else {
        $src = [string]$rec.source
        if ([string]::IsNullOrWhiteSpace($src)) { $src = '(no source reference)' }
        $artifact = $src
    }

    $limitation = (& $limitationForStatus $status)

    if ($null -eq $statusTally[$status]) { $statusTally[$status] = 0 }
    $statusTally[$status] = $statusTally[$status] + 1

    $rowLines += ('| ' + (ConvertTo-AppDocMarkdownCell $finding) + ' | ' + (ConvertTo-AppDocMarkdownCell $status) + ' | ' + (ConvertTo-AppDocMarkdownCell $artifact) + ' | ' + (ConvertTo-AppDocMarkdownCell $limitation) + ' |')
}

# --- framework note ------------------------------------------------------------
$fwPath = Join-Path $docsPath "framework-detection.json"
$frameworkLine = 'No framework detection recorded.'
if (Test-Path $fwPath) {
    try {
        $fw = Get-Content -LiteralPath $fwPath -Raw | ConvertFrom-Json -Depth 60
        $fwName = [string]$fw.framework
        $fwLang = [string]$fw.language
        $fwSupport = [string]$fw.supportLevel
        $fwPct = $fw.coveragePercent
        $frameworkLine = ('Framework detected: **{0}** ({1}); support level: {2}; extraction coverage: {3}%.' -f $fwName, $fwLang, $fwSupport, $fwPct)
    }
    catch {
        $frameworkLine = 'Framework detection present but could not be parsed.'
    }
}

# --- render markdown -----------------------------------------------------------
$md = @()
$md += '# Evidence Register'
$md += ''
$md += '**Status model:** `Verified` — directly supported by inspected source (file + line or a searchable value). `Inferred` — a reasonable interpretation not confirmed by runtime. `Partly verified` — a file reference exists but the confirmable line/value is absent. `Unknown` — the repository does not establish the claim.'
$md += ''
$md += ('**Records:** ' + $allRecords.Count + ' across ' + $filesToRead.Count + ' evidence files.')
$md += ''
$md += $frameworkLine
$md += ''
if ($allRecords.Count -eq 0) {
    $md += '_No evidence records were detected for this repository. The register is empty because the deterministic extractors found no concrete source-backed findings._'
    $md += ''
}
else {
    $md += $rowLines
    $md += ''
    $summary = @()
    foreach ($k in @('Verified','Inferred','Partly verified','Unknown')) {
        if ($statusTally.ContainsKey($k) -and $statusTally[$k] -gt 0) {
            $summary += ($k + ' (' + $statusTally[$k] + ')')
        }
    }
    $md += ('**Status breakdown:** ' + ($summary -join ', '))
    $md += ''
}
$md += '> **Limitation note:** Every row is source-level. A `Verified` row proves the cited file/line exists; it does not prove runtime behavior, production configuration, or database procedure logic. Re-runnable commands for each `Verified` claim are in the Verification Appendix.'
$md += ''

$md -join "`n" | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$verifiedCount = if ($statusTally.ContainsKey('Verified')) { $statusTally['Verified'] } else { 0 }
Write-Host "   Evidence records: $($allRecords.Count) (Verified: $verifiedCount)" -ForegroundColor Gray
Write-Host "✅ Evidence register generated: $outputPath" -ForegroundColor Green
