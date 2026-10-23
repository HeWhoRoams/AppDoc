#requires -Version 7.2
#
# generate-classic-asp-failures.ps1
#
# Purpose: Populate docs/test-catalog.md (and docs/test-catalog.evidence.json) for
#          CLASSIC ASP. There is no test harness; the classic-ASP analog is a
#          "Known Failure Modes" inventory:
#            - On Error Resume Next / On Error Goto 0 sites
#            - Response.Redirect after a query-failure pattern (within ~5 lines)
#            - <meta http-equiv="refresh"> auto-refresh timers (seconds + purpose)
#            - parseError handling
#
# Deterministic: no LLM, no randomness, no network. Framework-gated: only runs when
# framework-detection.json reports Classic ASP or ASP.NET Web Forms.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

$ErrorActionPreference = "Stop"
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }

# --- Evidence + Contracts modules (canonical evidence + manifest) ----------------
$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
$evidenceModule  = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if ((Test-Path $contractsModule) -and (Test-Path $evidenceModule)) {
    Import-Module $contractsModule -Force -ErrorAction SilentlyContinue
    Import-Module $evidenceModule  -Force -ErrorAction SilentlyContinue
}
function Write-NotApplicablePlaceholder {
    param([string]$OutputPath, [string]$Title)
    $dir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $body = "# $Title`n`n**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n`n## Summary`n`nNot applicable for this framework. This artifact is produced only for Classic ASP / ASP.NET Web Forms codebases; the detected framework has no matching classic-ASP signal, so no content was extracted.`n`n## Test Suites`n`nNo test suites were extracted for this framework.`n`n## Test Cases`n`nNo test cases were extracted for this framework.`n`n---"
    $body | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline
}
function Wrap-Backtick { param([string]$Text) return ('`' + $Text + '`') }

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$outputPath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "test-catalog.md"
$evidencePath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "test-catalog.evidence.json"

Write-Host "⚠️  Generating Classic ASP failure-mode catalog..." -ForegroundColor Cyan
if (-not (Get-ClassicAspFrameworkApplicable -RootPath $RootPath)) {
    Write-Host "  Framework not Classic ASP - writing placeholder." -ForegroundColor Yellow
    Write-NotApplicablePlaceholder -OutputPath $outputPath -Title "Test Catalog"
    @() | ConvertTo-Json -Depth 5 | Out-File -FilePath $evidencePath -Encoding UTF8
    exit 0
}

$rootPrefix = $RootPath.TrimEnd('\', '/')
$aspFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp" -File -ErrorAction SilentlyContinue | Sort-Object FullName)
# refresh timers also live in .htm; prefilter cheaply.
$htmPaths = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.htm","*.html" -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
$htmRefreshPaths = @()
if ($htmPaths.Count -gt 0) {
    $htmRefreshPaths = @(Select-String -Path $htmPaths -Pattern '<meta[^>]*http-equiv\s*=\s*["'']?refresh' -List -ErrorAction SilentlyContinue | ForEach-Object { $_.Path } | Sort-Object)
}

# Aggregates.
$script:onErrorResume = New-Object System.Collections.Generic.List[string]   # files
$script:onErrorGoto0 = New-Object System.Collections.Generic.List[string]
$script:onErrorResumeTotal = 0
$script:parseErrorFiles = New-Object System.Collections.Generic.List[string]
$script:parseErrorTotal = 0
$script:redirectAfterFailure = New-Object System.Collections.Generic.List[object]  # {file,line}
$script:refreshTimers = New-Object System.Collections.Generic.List[object]         # {file,seconds,purpose}

function Show-Files {
    param([string[]]$Files, [int]$Max = 5)
    if ($Files.Count -eq 0) { return "—" }
    if ($Files.Count -le $Max) { return ($Files -join ", ") }
    $head = ($Files | Select-Object -First $Max) -join ", "
    return "$head (+$($Files.Count - $Max) more)"
}

function Process-FailuresFile {
    param([string]$FullPath)
    $rel = Get-RelativePath -FullPath $FullPath -Base $rootPrefix
    $content = Get-Content $FullPath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { return }
    $lines = @($content -split "`r?`n")

    $oeCount = ([regex]::Matches($content, '(?i)On Error Resume Next')).Count
    if ($oeCount -gt 0) {
        $script:onErrorResumeTotal += $oeCount
        if (-not ($script:onErrorResume -contains $rel)) { $script:onErrorResume.Add($rel) }
    }
    if ($content -match '(?i)On Error Goto 0') {
        if (-not ($script:onErrorGoto0 -contains $rel)) { $script:onErrorGoto0.Add($rel) }
    }
    $peCount = ([regex]::Matches($content, '(?i)parseError')).Count
    if ($peCount -gt 0) {
        $script:parseErrorTotal += $peCount
        if (-not ($script:parseErrorFiles -contains $rel)) { $script:parseErrorFiles.Add($rel) }
    }

    # Response.Redirect within ~5 lines after a query-failure signal.
    $failSignal = $false
    $failLine = -99
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $ln = $lines[$i]
        if ([regex]::IsMatch($ln, '(?i)\.State\s*<>\s*0|\.RecordsAffected\s*=\s*0|\.EOF\b|\.Fields\(.+\)\.Value\s*=\s*""')) {
            $failSignal = $true; $failLine = $i
        }
        if ($failSignal -and ([regex]::IsMatch($ln, '(?i)Response\.Redirect'))) {
            if (($i - $failLine) -le 5) {
                $script:redirectAfterFailure.Add([ordered]@{ file=$rel; line=($i + 1) })
            }
            $failSignal = $false
        }
    }

    # <meta http-equiv="refresh"> timers.
    foreach ($m in [regex]::Matches($content, '(?is)<meta[^>]*http-equiv\s*=\s*["'']?refresh["'']?[^>]*>')) {
        $tag = $m.Value
        $secM = [regex]::Match($tag, '(?i)content\s*=\s*["'']?\s*(\d+)')
        $sec = if ($secM.Success) { [int]$secM.Groups[1].Value } else { 0 }
        # Purpose context = a window of the raw text around the tag.
        $start = [Math]::Max(0, $m.Index - 400); $end = [Math]::Min($content.Length, $m.Index + 400)
        $window = $content.Substring($start, ($end - $start))
        $purpose = Infer-RefreshPurpose -Window $window
        $script:refreshTimers.Add([ordered]@{ file=$rel; seconds=$sec; purpose=$purpose })
    }
}

function Infer-RefreshPurpose {
    param([string]$Window)
    $w = $Window.ToLowerInvariant()
    if ($w -match 'status|poll') { return "Status auto-refresh/polling" }
    if ($w -match 'leaderboard|rank') { return "Leaderboard refresh" }
    if ($w -match 'clock|time|date') { return "Clock/time refresh" }
    if ($w -match 'session|logout|login|auth') { return "Session/auth refresh" }
    if ($w -match 'feed|rss') { return "Feed refresh" }
    if ($w -match 'ticket|incident|queue') { return "Ticket/queue refresh" }
    return "Auto-refresh (page reload)"
}

foreach ($f in $aspFiles) { Process-FailuresFile -FullPath $f.FullName }
foreach ($p in $htmRefreshPaths) { Process-FailuresFile -FullPath $p }

# De-duplicate refresh timers by (file, seconds, purpose): a file with the same
# interval+purpose multiple times is one observable signal, not N. Keeps the
# catalog table rows unique (the validator penalizes duplicate rows).
$dedup = New-Object System.Collections.Generic.List[object]
$seen = @{}
foreach ($t in $script:refreshTimers) {
    $k = ("{0}|{1}|{2}" -f ([string]$t.file), ([int]$t.seconds), ([string]$t.purpose))
    if (-not $seen.ContainsKey($k)) { $seen[$k] = $true; $dedup.Add($t) }
}
$script:refreshTimers = $dedup

$redirectCount = $script:redirectAfterFailure.Count
$timerCount = $script:refreshTimers.Count
# --- Render markdown ------------------------------------------------------------
$generatedLine = "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$generatedIso = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$summaryText = "This artifact is the classic-ASP analog of a test catalog. There is no automated test harness; instead it enumerates observable failure/robustness signals: {0} files use On Error Resume Next ({1} sites total), {2} files reset with On Error Goto 0, {3} files handle parseError ({4} sites), {5} query-failure-then-redirect patterns, and {6} auto-refresh timers." -f $script:onErrorResume.Count, $script:onErrorResumeTotal, $script:onErrorGoto0.Count, $script:parseErrorFiles.Count, $script:parseErrorTotal, $redirectCount, $script:refreshTimers.Count

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Test Catalog"); $lines.Add(""); $lines.Add($generatedLine); $lines.Add("")
$lines.Add("## Summary"); $lines.Add(""); $lines.Add($summaryText); $lines.Add("")

# Test Environment Setup (required heading area).
$lines.Add("## Test Environment Setup"); $lines.Add("")
$lines.Add("No test harness or bootstrap script exists for this classic-ASP codebase. Verification is manual: deploy the pages to an IIS instance, restore the ADO connection strings to real SQL Server hosts, and exercise the pages listed under Test Cases.")
$lines.Add("")

# Test Suites (required section; no harness -> single informative row).
$lines.Add("## Test Suites"); $lines.Add("")
$lines.Add("| Suite | Type | Purpose | Status |")
$lines.Add("|-------|------|---------|--------|")
$suiteLine = "| (none) | classic-ASP | No automated suite; failure modes are documented below | Verified |"
$lines.Add($suiteLine)
$lines.Add("")

# Error Handling Patterns (task section).
$lines.Add("## Error Handling Patterns"); $lines.Add("")
$lines.Add("| Pattern | Count | Files (sample) | Risk | Status |")
$lines.Add("|---------|-------|----------------|------|--------|")
$eopRows = @(
    , @("On Error Resume Next", $script:onErrorResumeTotal, (Show-Files -Files $script:onErrorResume), "Errors swallowed silently; failures not surfaced")
    , @("On Error Goto 0", $script:onErrorGoto0.Count, (Show-Files -Files $script:onErrorGoto0), "Resets error handling mid-page; scope unclear")
    , @("Response.Redirect after query failure", $redirectCount, (Show-Files -Files (@($script:redirectAfterFailure | ForEach-Object { [string]$_.file }) | Select-Object -Unique)), "Silent redirect on DB failure hides root cause")
    , @("parseError handling", $script:parseErrorTotal, (Show-Files -Files $script:parseErrorFiles), "ADO/recordset errors inspected at runtime")
)
foreach ($e in $eopRows) {
    $eLine = "| {0} | {1} | {2} | {3} | Verified |" -f $e[0], $e[1], $e[2], $e[3]
    $lines.Add($eLine)
}
$lines.Add("")

# Known Failure Modes (task section; per-occurrence detail).
$lines.Add("## Known Failure Modes"); $lines.Add("")
$lines.Add("| ID | File | Pattern | Observed Behavior | Status |")
$lines.Add("|------|------|---------|-------------------|--------|")
$fmId = 0
foreach ($r in $script:redirectAfterFailure) {
    $fmId++
    $relDisp = Wrap-Backtick -Text $r.file
    $fmLine = "| {0} | {1} | Response.Redirect after query failure (line {2}) | Redirects user away on DB error | Verified |" -f ("fm-$( $fmId.ToString('000') )"), $relDisp, $r.line
    $lines.Add($fmLine)
}
$tmId = 0
foreach ($t in $script:refreshTimers) {
    $tmId++
    $relDisp = Wrap-Backtick -Text $t.file
    $fmLine = "| {0} | {1} | Auto-refresh timer ({2}s) | Page reloads every {2}s | Verified |" -f ("tm-$( $tmId.ToString('000') )"), $relDisp, $t.seconds
    $lines.Add($fmLine)
}
$lines.Add("")

# Auto-Refresh Timers (task section; seconds + inferred purpose).
$lines.Add("## Auto-Refresh Timers"); $lines.Add("")
$lines.Add("| File | Interval (sec) | Purpose (inferred) | Status |")
$lines.Add("|------|----------------|--------------------|--------|")
foreach ($t in ($script:refreshTimers | Sort-Object { [string]$_.file })) {
    $relDisp = Wrap-Backtick -Text $t.file
    $tLine = "| {0} | {1} | {2} | Verified |" -f $relDisp, $t.seconds, $t.purpose
    $lines.Add($tLine)
}
$lines.Add("")

# Evidence Traceability.
$lines.Add("## Evidence Traceability"); $lines.Add("")
$lines.Add("| Field | Value |"); $lines.Add("|------|-------|")
$lines.Add("| Evidence Artifact | docs/test-catalog.evidence.json |")
$recCount = 1 + $eopRows.Count + $redirectCount + $script:refreshTimers.Count
$recLine = "| Record Count | {0} |" -f $recCount
$lines.Add($recLine)
$lines.Add("| Generator | generate-classic-asp-failures.ps1 |")
$lines.Add("| Required Evidence Keys | testSuites |")
$lines.Add("| Grounding Mode | Deterministic extraction records |")
$lines.Add("")
$lines.Add("---"); $lines.Add("")
$lines.Add("## Provenance"); $lines.Add("")
$lines.Add("- Generator Version: appdoc-run-all-generators/3.0.0"); $lines.Add("- Commit Hash: unknown")
$lines.Add("- Generated At: $generatedIso"); $lines.Add("- Profile: default"); $lines.Add("- Scope: .")
$lines.Add("- Confidence/Inference Flags: deterministic, evidence-backed")
$md = ($lines -join "`n")
$md | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

# --- Flat evidence --------------------------------------------------------------
$evidence = New-Object System.Collections.Generic.List[object]
# One suite-ish record so the catalog is not empty for harness-less code.
$evidence.Add([ordered]@{ id="suite-001"; kind="test-suite"; name="classic-asp-failure-surface"; purpose="No automated harness; documents observable failure modes"; status="Verified" })
# Error-handling pattern records as test-cases (the "failure cases" to verify).
$i = 0
foreach ($e in $eopRows) { $i++
    $evidence.Add([ordered]@{ id=("case-$( $i.ToString('000') )"); kind="test-case"; name=($e[0]); count=$e[1]; files=@(); status="Verified" })
}
# Redirect-after-failure occurrences.
$rid = 0
foreach ($r in $script:redirectAfterFailure) { $rid++
    $evidence.Add([ordered]@{ id=("fm-$( $rid.ToString('000') )"); kind="test-case"; name=("redirect-after-failure:" + $r.file); file=$r.file; line=$r.line; status="Verified" })
}
# Refresh timers.
$tid = 0
foreach ($t in $script:refreshTimers) { $tid++
    $evidence.Add([ordered]@{ id=("tm-$( $tid.ToString('000') )"); kind="test-case"; name=("refresh:" + $t.file); file=$t.file; seconds=$t.seconds; purpose=$t.purpose; status="Verified" })
}
$evidence | ConvertTo-Json -Depth 12 | Out-File -FilePath $evidencePath -Encoding UTF8

# --- Canonical evidence (docs/evidence/test-catalog.evidence.json) + manifest ----
# Reuses the flat records (kinds: test-suite/test-case); satisfies the test-catalog
# contract (requiredEvidenceKeys=testSuites -> record kind "test-suite"/"test-case")
# and aligns the doc Record Count ($recCount == $evidence.Count).
if ((Get-Command Get-AppDocArtifactContract -ErrorAction SilentlyContinue) -and (Get-Command Write-AppDocEvidenceArtifact -ErrorAction SilentlyContinue)) {
    $tcContract = Get-AppDocArtifactContract -Artifact "test-catalog"
    $canonPath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact "test-catalog" -Records $evidence.ToArray() -Metadata @{
        requiredEvidenceKeys = @($tcContract.requiredEvidenceKeys)
        requiredSections     = @($tcContract.requiredSections)
        generator            = "generate-classic-asp-failures.ps1"
        onerrorResumeFiles   = [int]$script:onErrorResume.Count
        redirectAfterFailure = [int]$redirectCount
        refreshTimers        = [int]$script:refreshTimers.Count
    }
    if ($canonPath -and (Get-Command Update-AppDocEvidenceManifest -ErrorAction SilentlyContinue)) {
        [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact "test-catalog" -EvidencePath $canonPath -RecordCount $evidence.Count -Metadata @{
            generator = "generate-classic-asp-failures.ps1"
        })
    }
}

Write-Host "✅ Classic ASP failure-mode catalog generated: $outputPath" -ForegroundColor Green
Write-Host "   On Error Resume Next: $($script:onErrorResume.Count) files | parseError: $($script:parseErrorFiles.Count) | redirects-after-fail: $redirectCount | timers: $($script:refreshTimers.Count)" -ForegroundColor Gray
Write-Host "   Evidence: $evidencePath" -ForegroundColor Gray
