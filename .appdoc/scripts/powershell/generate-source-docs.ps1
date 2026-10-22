#
# generate-source-docs.ps1
#
# Purpose: run the SOURCE-OF-TRUTH discovery + citation module (AppDoc.SourceDocs)
#          over the target and emit:
#            docs/evidence/source-docs.evidence.json  (machine citation records by
#                                                       category; deterministic)
#            docs/source-docs.md                      (readable "Cited Source
#                                                       Documents" appendix)
#
# Reads:   hand-authored docs in $RootPath (README*, docs/ EXCLUDING the
#          AppDoc-generated docs/, doc/, Archive/, "External Documentation/",
#          *.adr, CODEOWNERS, operational-signal files). Excludes fixtures/tests/
#          node_modules/bin/obj + user-generated forum paths per the AppDoc.Scope
#          conventions.
# Writes:  docs/evidence/source-docs.evidence.json + docs/source-docs.md
#
# Determinism: pure function of the target hand-authored docs. No wall-clock
# timestamp (the date is derived from the deterministic evidence date when present,
# else an explicit 'n/a'), no network, no LLM, no randomness. Two runs over the same
# target produce byte-identical output.
#
# Redaction: every claim is redacted before it is written (no secrets). Credentials
# are redacted by shape/key-name plus operator-supplied channel values; the tool
# ships no hardcoded verbatim list. They are ABSENT from both emitted artifacts.
#
# Wiring: run by run-all-generators.ps1 in the Generation phase, AFTER the other
#          evidence generators and BEFORE generate-unified-master.ps1 (the composer),
#          so the composer + pristine check can read the citations. It is additive:
#          it never changes status/overallScore.
#
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    # Operator-supplied per-target secret VALUES (the config `redactionPatterns`), forwarded
    # additively into the source-docs redaction (Get-AppDocSourceDocs -ExtraKnownSecrets).
    # A no-config / no-CLI target passes empty -> behavior identical to before. This closes
    # the DETERMINISTIC-path operator channel so a per-target live credential value is
    # redacted in source-docs output even though AppDoc ships shape-patterns only.
    [string[]]$RedactionPatterns = @()
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) { Write-Error "docs directory not found: $docsPath"; exit 1 }

$modulePath = Join-Path $PSScriptRoot "modules/AppDoc.SourceDocs.psm1"
if (-not (Test-Path $modulePath)) { Write-Error "Required module not found: $modulePath"; exit 1 }
Import-Module $modulePath -Force -ErrorAction Stop

# --- DETERMINISTIC-path operator channel (the config `redactionPatterns`) ------
# Self-contained read (mirrors run-appdoc-semantic-enrich.ps1): the generator reads
# <target>/.appdoc/config.json for any operator-supplied per-target secret VALUES and
# merges them additively with the CLI -RedactionPatterns into the source-docs redaction.
# A no-config / no-CLI target yields an EMPTY list -> behavior identical to before
# (AppDoc ships shape-patterns only; the built-in verbatim list is intentionally empty).
$sourceDocsExtra = @()
$configModule = Join-Path $PSScriptRoot "modules/AppDoc.Config.psm1"
if (Test-Path $configModule) {
    try {
        Import-Module $configModule -Force -ErrorAction SilentlyContinue
        $cfg = Get-AppDocConfig -RootPath $RootPath
        if ($cfg) { $sourceDocsExtra = @($cfg.values.redactionPatterns | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) }
    } catch { /* config read is additive; a failure falls back to CLI-only */ }
}
$sourceDocsExtra = @($sourceDocsExtra + @($RedactionPatterns) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
if ($sourceDocsExtra.Count -gt 0) {
    Write-Host ("   Source-docs operator channel: {0} redactionPattern(s) forwarded into the redactor (shape-patterns only; per-target values operator-supplied)." -f $sourceDocsExtra.Count) -ForegroundColor Gray
}

# Deterministic evidence date (no wall-clock): reuse the composed doc's "Evidence
# date" marker when present, else the canonical metrics generatedAt, else 'n/a'.
# (generate-source-docs.ps1 runs BEFORE the composer, so we prefer the canonical
# metrics + any pre-existing composed doc; both are stable across two runs.)
$reportDate = 'n/a'
$metricsPath = Join-Path $docsPath 'evidence/metrics-canonical.json'
if (Test-Path -LiteralPath $metricsPath) {
    try {
        $metrics = Get-Content -LiteralPath $metricsPath -Raw | ConvertFrom-Json -Depth 20
        if ($metrics.generatedAt) { $reportDate = [string]$metrics.generatedAt }
    } catch { $reportDate = 'n/a' }
}
$mdPathIn = Join-Path $docsPath 'application-documentation.md'
if (Test-Path -LiteralPath $mdPathIn) {
    try {
        $master = Get-Content -LiteralPath $mdPathIn -Raw
        $m = [regex]::Match($master, '(?im)^\*\*Evidence date\*\*:\s*([^\r\n]+?)\s*$')
        if ($m.Success) { $reportDate = [string]$m.Groups[1].Value.Trim() }
    } catch { }
}

# --- Discover + extract (deterministic) --------------------------------------
$result = Get-AppDocSourceDocs -RootPath $RootPath -ExtraKnownSecrets $sourceDocsExtra
$categories = $result.categories
$records    = @($result.records)
$byFile     = $result.byFile
$fileCount  = [int]$result.fileCount
$citedCategories = @(Get-AppDocSourceDocsCitedCategories -Result $result)
$totalRecords = @($records).Count

$plural = if ($citedCategories.Count -eq 1) { 'category' } else { 'categories' }
Write-Host ("  Source docs: scanned {0} hand-authored file(s); {1} citation record(s) across {2} {3}." -f $fileCount, $totalRecords, $citedCategories.Count, $plural) -ForegroundColor Cyan

# --- Build the machine evidence record ---------------------------------------
# Each record: { category, claim (REDACTED), path, lines, lineStart, lineEnd,
#   sub, provenance, confidence }. Sorted by (category, path, lineStart). Deterministic.
$cats = @('ownership','role-access','operational-policy','escalation','troubleshooting','slo')
$catMap = [ordered]@{}
foreach ($cat in $cats) {
    $recs = @($categories[$cat])
    $mapped = @()
    foreach ($r in $recs) {
        $mapped += [ordered]@{
            category    = [string]$r.category
            claim       = [string]$r.claim
            path        = [string]$r.path
            lines       = @([int[]]$r.lines)
            lineStart   = [int]$r.lineStart
            lineEnd     = [int]$r.lineEnd
            sub         = [string]$r.sub
            provenance  = (Get-AppDocSourceDocsProvenance $r)
            confidence  = [string]$r.confidence
        }
    }
    $catMap[$cat] = @($mapped)
}
$filesIndex = [ordered]@{}
foreach ($p in @($byFile.Keys | Sort-Object)) {
    $filesIndex[$p] = @($byFile[$p])
}
$evOut = [ordered]@{
    artifact        = 'source-docs'
    generator       = 'generate-source-docs.ps1'
    module          = 'AppDoc.SourceDocs.psm1'
    version         = $result.version
    reportDate      = $reportDate
    fileCount       = [int]$fileCount
    totalRecords    = [int]$totalRecords
    citedCategories = @($citedCategories)
    categories      = $catMap
    files           = $filesIndex
}
$evDir = Join-Path $docsPath 'evidence'
if (-not (Test-Path $evDir)) { New-Item -Path $evDir -ItemType Directory -Force | Out-Null }
$evPath = Join-Path $evDir 'source-docs.evidence.json'
$evOut | ConvertTo-Json -Depth 20 | Out-File -FilePath $evPath -Encoding UTF8

# --- Build the readable appendix ---------------------------------------------
$md = New-Object System.Collections.Generic.List[string]
$md.Add('# Cited Source Documents (Source-of-Truth Appendix)')
$md.Add('')
$md.Add("**Report date**: $reportDate  ")
$md.Add("**Source**: hand-authored operational docs in the target (README* / docs (excl. AppDoc-generated) / doc / Archive / External Documentation / `*.adr` / CODEOWNERS + operational-signal files).  ")
$md.Add('')
$md.Add('> **What this is:** the deterministic source-of-truth citations the AppDoc pipeline found in the target hand-authored docs. Every cited fact below carries a **file:line** provenance into a hand-authored doc that exists in the target. This is the evidence that backs the owner-pending cells (ownership section 13, roles and access section 5.2, help-desk policy section 7, troubleshooting/escalation section 11) with `Verified-source-doc` provenance - so a cell the repo actually documents is *populated with the citation* instead of an honest-Unknown placeholder. Where the repo has NO hand-authored source for a category, that category is listed as **not found** and the corresponding cell stays honest-Unknown (never fabricated). All values are **redacted** (no secrets).')
$md.Add('')
$scannedLine = "**Scanned**: $fileCount hand-authored file(s); **citations**: $totalRecords across $($citedCategories.Count) $plural."
$md.Add($scannedLine)
$md.Add('')

# Per-category readable listings.
$catTitles = [ordered]@{
    'ownership'          = 'Ownership (owners / teams / divisions / department)'
    'role-access'        = 'Roles & Access (roles / permissions / authorization)'
    'operational-policy' = 'Operational Policy (policy / SOP / procedure / retention / approval)'
    'escalation'         = 'Escalation (on-call / contacts / escalation)'
    'troubleshooting'    = 'Troubleshooting (KB / symptom-to-fix)'
    'slo'                = 'SLO / SLA (service-level / uptime targets)'
}
$notFoundLine = "_Not found in the target hand-authored docs - the corresponding owner cell stays `Unknown` / owner-required (honest, not fabricated)._"
foreach ($cat in @('ownership','role-access','operational-policy','escalation','troubleshooting','slo')) {
    $catRecs = @($categories[$cat])
    $md.Add("## $($catTitles[$cat])")
    $md.Add('')
    if ($catRecs.Count -eq 0) {
        $md.Add($notFoundLine)
        $md.Add('')
        continue
    }
    $foundLine = "**Found** in $($catRecs.Count) citation record(s):"
    $md.Add($foundLine)
    $md.Add('')
    # group by file for readability, deterministic (path, lineStart)
    $byPath = [ordered]@{}
    foreach ($r in $catRecs) {
        $pk = [string]$r.path
        if (-not $byPath.Contains($pk)) { $byPath[$pk] = @() }
        $byPath[$pk] += ,@($r)
    }
    foreach ($p in @($byPath.Keys)) {
        $md.Add('### `' + $p + '`')
        $md.Add('')
        foreach ($r in $byPath[$p]) {
            $ls = [int]$r.lineStart
            $le = [int]$r.lineEnd
            $span = "$ls-$le"
            if ($ls -eq $le) { $span = "$ls" }
            $claim = [string]$r.claim
            $conf  = [string]$r.confidence
            $bullet = "- $claim  "
            $srcLine = '  - Source: `' + $p + '`:' + $span + ' (confidence: ' + $conf + ')'
            $md.Add($bullet)
            $md.Add($srcLine)
        }
        $md.Add('')
    }
}

# Provenance index (which file backed which category).
$md.Add('## Provenance index (file to categories)')
$md.Add('')
if ($filesIndex.Count -eq 0) {
    $md.Add("_No hand-authored operational docs with citable claims were found._")
    $md.Add('')
} else {
    $md.Add('| File | Categories backed |')
    $md.Add('|------|-------------------|')
    foreach ($p in @($filesIndex.Keys)) {
        $catsJoined = ($filesIndex[$p] -join ', ')
        $row = '|' + ' `' + $p + '` ' + '| ' + $catsJoined + ' |'
        $md.Add($row)
    }
    $md.Add('')
}

$md.Add('---')
$md.Add('')
$footer = '*Generated by `generate-source-docs.ps1` (module `AppDoc.SourceDocs.psm1`) - a pure function of the target hand-authored docs. Deterministic (no wall-clock timestamp, no network, no LLM, no randomness); every claim is redacted. A cell is `Verified-source-doc` only when a real hand-authored file:line citation exists; otherwise it stays `Unknown` / owner-required.*'
$md.Add($footer)

$mdPathOut = Join-Path $docsPath 'source-docs.md'
($md -join "`r`n") | Out-File -FilePath $mdPathOut -Encoding UTF8 -NoNewline

$citedJoined = ($citedCategories -join ', ')
Write-Host "   Wrote docs/source-docs.md + docs/evidence/source-docs.evidence.json ($totalRecords citation(s); cited: $citedJoined)" -ForegroundColor Gray
