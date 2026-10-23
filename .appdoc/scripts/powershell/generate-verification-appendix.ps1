#requires -Version 7.2
#
# generate-verification-appendix.ps1
#
# Purpose: Produce the §18 Verification Appendix (docs/verification-appendix.md)
#          from the deterministic evidence layer. For every evidence record whose
#          epistemic status is "Verified", emit a re-runnable PowerShell command
#          that, when run from the repository root, returns a non-empty match that
#          proves the claim:
#
#              | Claim | Status | Command |
#
#          The command is CONSTRUCTED from the record's own file + pattern fields:
#            - Select-String -Path '<relative-file>' -SimpleMatch '<pattern>'
#          The pattern is taken (first non-empty wins):
#            1. metadata.pattern
#            2. the first quoted identifier in metadata.description
#            3. the record name, when it looks like a searchable key/identifier
#          If no usable pattern + file can be produced, the row's Command becomes
#          'N/A — insufficient evidence detail' and its Status is downgraded to
#          'Partly verified' (per the discipline layer's honesty boundary).
#
#          Reads docs/evidence/*.evidence.enriched.json first and falls back to
#          docs/evidence/*.evidence.json. Deterministic. No network. No LLM.
#
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

$epistemicModule = Join-Path $PSScriptRoot "modules\AppDoc.Epistemic.psm1"
if (-not (Test-Path $epistemicModule)) {
    Write-Error "Required module not found: $epistemicModule"
    exit 1
}
Import-Module $epistemicModule -Force -ErrorAction Stop
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) { New-Item -Path $docsPath -ItemType Directory -Force | Out-Null }
$evidencePath = Join-Path $docsPath "evidence"
$outputPath = Join-Path $docsPath "verification-appendix.md"

Write-Host "🔎  Generating Verification Appendix (section 18)..." -ForegroundColor Cyan

$naCommand = 'N/A — insufficient evidence detail'

# --- collect evidence files: enriched preferred, base fallback ----------------
$enriched = @()
$base = @()
if (Test-Path $evidencePath) {
    $enriched = @(Get-ChildItem -Path $evidencePath -Filter "*.evidence.enriched.json" -File -ErrorAction SilentlyContinue | Sort-Object Name)
    $base = @(Get-ChildItem -Path $evidencePath -Filter "*.evidence.json" -File -ErrorAction SilentlyContinue | Sort-Object Name)
}
$enrichedArtifacts = @{}
foreach ($f in $enriched) {
    $key = [IO.Path]::GetFileNameWithoutExtension($f.Name) -replace '\.evidence\.enriched$', ''
    $enrichedArtifacts[$key] = $f.FullName
}
$filesToRead = @()
foreach ($f in $base) {
    $key = [IO.Path]::GetFileNameWithoutExtension($f.Name) -replace '\.evidence$', ''
    if ($enrichedArtifacts.ContainsKey($key)) { $filesToRead += $enrichedArtifacts[$key] } else { $filesToRead += $f.FullName }
}
foreach ($key in $enrichedArtifacts.Keys) {
    $covered = $false
    foreach ($f in $base) {
        $bkey = [IO.Path]::GetFileNameWithoutExtension($f.Name) -replace '\.evidence$', ''
        if ($bkey -eq $key) { $covered = $true; break }
    }
    if (-not $covered) { $filesToRead += $enrichedArtifacts[$key] }
}

$allRecords = @()
foreach ($file in $filesToRead) {
    try { $payload = Get-Content -LiteralPath $file -Raw | ConvertFrom-Json -Depth 120 } catch { $payload = $null }
    if ($null -eq $payload) { continue }
    foreach ($rec in @($payload.records)) {
        if ($null -eq $rec) { continue }
        $rec | Add-Member -NotePropertyName "_artifact" -NotePropertyValue ([string]$payload.artifact) -Force -ErrorAction SilentlyContinue
        $allRecords += $rec
    }
}

# --- helpers -------------------------------------------------------------------
function Esc-Quote {
    param([string]$Text)
    # single-quoted PS string: escape embedded single quotes by doubling them.
    if ($null -eq $Text) { $Text = '' }
    return ($Text -replace "'","''")
}
function Test-AppDocRegexSafe {
    param([string]$Text)
    # If the pattern contains regex metacharacters, use -Pattern with a regex-
    # escaped version; otherwise -SimpleMatch is the safe, deterministic choice.
    return ($Text -notmatch '[.\\[\](){}*+?^$|]')
}

# Pick a searchable pattern for a record ('' when none).
function Get-AppDocSearchPattern {
    param($Record)
    $meta = $null
    if ($Record.PSObject.Properties['metadata']) { $meta = $Record.metadata }
    if ($meta -and $meta.PSObject.Properties['pattern']) {
        $p = [string]$meta.pattern
        if (-not [string]::IsNullOrWhiteSpace($p)) { return $p }
    }
    $desc = ''
    if ($meta -and $meta.PSObject.Properties['description']) { $desc = [string]$meta.description }
    if (-not [string]::IsNullOrWhiteSpace($desc)) {
        $m = [regex]::Match($desc, "'([^']{2,60})'")
        if (-not $m.Success) { $m = [regex]::Match($desc, '"([^"]{2,60})"') }
        if ($m.Success) { return $m.Groups[1].Value }
    }
    $name = [string]$Record.name
    $kind = ''
    if ($Record.PSObject.Properties['kind']) { $kind = [string]$Record.kind }
    # A bare identifier that is likely searchable in the cited file.
    if ($name -match '^[A-Za-z_][A-Za-z0-9_.\-]{1,63}$') {
        if ($kind -in @('configuration','config','endpoint','model') -or ($meta -and $meta.PSObject.Properties['value'])) {
            return $name
        }
    }
    return ''
}

# --- build rows ---------------------------------------------------------------
$rowLines = @()
$rowLines += '| Claim | Status | Command |'
$rowLines += '|---|---|---|'

$verifiedCount = 0
$withCommand = 0
$downgraded = 0
foreach ($rec in $allRecords) {
    $status = [string](Resolve-AppDocEpistemicStatus -Record $rec -RootPath $RootPath)
    if ($status -ne 'Verified') { continue }   # only Verified claims get a command
    $verifiedCount++

    $file = Resolve-AppDocEpistemicFile -Record $rec -RootPath $RootPath
    $pattern = Get-AppDocSearchPattern -Record $rec

    $finding = [string]$rec.name
    if ([string]::IsNullOrWhiteSpace($finding)) { $finding = [string]$rec.kind }
    if ([string]::IsNullOrWhiteSpace($finding)) { $finding = '(unnamed record)' }
    $artifactName = [string]$rec._artifact

    # A "Verified" row must carry a command that actually re-runs from the repo
    # root. So require (a) a file path that resolves on disk and (b) a searchable
    # pattern. Anything less is honestly "Partly verified" with N/A.
    $fileExists = $false
    if (-not [string]::IsNullOrWhiteSpace($file)) {
        $fileExists = Test-Path -LiteralPath (Join-Path $RootPath $file)
    }

    if ($fileExists -and -not [string]::IsNullOrWhiteSpace($pattern)) {
        $fileEsc = Esc-Quote $file
        if (Test-AppDocRegexSafe $pattern) {
            $cmd = ("Select-String -Path '{0}' -SimpleMatch '{1}'" -f $fileEsc, (Esc-Quote $pattern))
        }
        else {
            $regexEsc = [regex]::Escape($pattern)
            $cmd = ("Select-String -Path '{0}' -Pattern '{1}'" -f $fileEsc, (Esc-Quote $regexEsc))
        }
        $rowStatus = 'Verified'
        $withCommand++
    }
    else {
        $cmd = $naCommand
        $rowStatus = 'Partly verified'
        $downgraded++
    }

    $claimText = $finding
    if (-not [string]::IsNullOrWhiteSpace($artifactName)) { $claimText = ($finding + '  ' + '[' + $artifactName + ']') }

    $rowLines += ('| ' + (Esc-MdCell $claimText) + ' | ' + (Esc-MdCell $rowStatus) + ' | ' + (Esc-MdCell $cmd) + ' |')
}

# --- render markdown -----------------------------------------------------------
$md = @()
$md += '# Verification Appendix'
$md += ''
$md += ('This appendix lists the exact, re-runnable PowerShell commands used to verify each `Verified` claim in the Evidence Register. All commands are run **from the repository root** (`<repo-root>`). A non-empty `Select-String` result proves the cited source-level fact.')
$md += ''
$md += ('**Verified claims:** ' + $verifiedCount + '  ' + '|  **Re-runnable commands:** ' + $withCommand + '  ' + '|  **Insufficient detail (downgraded):** ' + $downgraded)
$md += ''
if ($verifiedCount -eq 0) {
    $md += '_No `Verified` claims were found in the evidence layer, so there are no commands to run. Every finding in the Evidence Register is `Inferred`, `Partly verified`, or `Unknown`._'
    $md += ''
}
else {
    $md += $rowLines
    $md += ''
}
$md += ('**Scope note:** These commands verify *source-level* facts only. They do not verify runtime behavior, production configuration, or database procedure logic. A row marked `Partly verified` has a command field of `' + $naCommand + '` because the deterministic extractor recorded a file reference but not a confirmable searchable token.')
$md += ''

$md -join "`n" | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Host "   Verified claims: $verifiedCount (commands: $withCommand; downgraded: $downgraded)" -ForegroundColor Gray
Write-Host "✅ Verification appendix generated: $outputPath" -ForegroundColor Green
