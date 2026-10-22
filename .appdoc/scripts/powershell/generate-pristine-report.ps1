#
# generate-pristine-report.ps1
#
# Purpose: emit the PRISTINE CHECK report (Step 1b) — a per-section rubric that
# scores each of the 20 composed sections against the HELP_DESK benchmark, so
# "up to the standard" is MEASURABLE per section (not a single gate score).
#
# Reads:   docs/application-documentation.md + docs/evidence/*.evidence.json
# Writes:  docs/pristine-report.md            (human-readable: 20-row table + summary)
#          docs/evidence/pristine.evidence.json (machine record: per-section records
#                                                   + overall pristine sub-score + determinism)
# Prints:  the pristine sub-score as the last stdout line (machine-parsable, e.g.
#          "PRISTINE_SUBSCORE 82") so the orchestrator can pick it up additively.
#
# Deterministic: pure function of the composed doc + evidence artifacts. No wall-clock
# timestamp, no network, no randomness. The report date is derived from the composed
# doc's "Evidence date" marker (the same deterministic source the composer uses), so
# two runs over identical inputs produce byte-identical output.
#
# The pristine sub-score is a DEPTH measurement, NOT a structural-conformance gate.
# Two MODES are explicit: REPORT-ONLY (the DEFAULT — additive; never changes status or
# overallScore) and BLOCKING (OPT-IN, only when the operator passes -PristineGate — see
# the "Gate mode" footer below). By default this report is report-only output.
#
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) { Write-Error "docs directory not found: $docsPath"; exit 1 }

# --- Import the pristine rubric module ---------------------------------------
$pristineModule = Join-Path $PSScriptRoot "modules\AppDoc.Pristine.psm1"
if (-not (Test-Path $pristineModule)) {
    Write-Error "Required module not found: $pristineModule"
    exit 1
}
Import-Module $pristineModule -Force -ErrorAction Stop

# --- Run the rubric (pure function of the docs/ inputs) ----------------------
$assessment = Get-AppDocPristineAssessment -DocsPath $docsPath

# Deterministic report date: derived from the composed doc's "Evidence date" marker
# (falls back to the evidence canonical metrics' generatedAt, then an empty string).
$reportDate = ''
$mdPath = Join-Path $docsPath 'application-documentation.md'
if (Test-Path -LiteralPath $mdPath) {
    $master = Get-Content -LiteralPath $mdPath -Raw
    $m = [regex]::Match($master, '(?im)^\*\*Evidence date\*\*:\s*([^\r\n]+?)\s*$')
    if ($m.Success) { $reportDate = [string]$m.Groups[1].Value.Trim() }
}
if ([string]::IsNullOrWhiteSpace($reportDate)) {
    $metricsPath = Join-Path $docsPath 'evidence\metrics-canonical.json'
    if (Test-Path -LiteralPath $metricsPath) {
        try {
            $metrics = Get-Content -LiteralPath $metricsPath -Raw | ConvertFrom-Json -Depth 20
            if ($metrics.generatedAt) { $reportDate = [string]$metrics.generatedAt }
        } catch { $reportDate = '' }
    }
}
if ([string]::IsNullOrWhiteSpace($reportDate)) { $reportDate = 'n/a' }

# --- Build the human-readable report ----------------------------------------
$out = New-Object System.Collections.Generic.List[string]
$out.Add('# Pristine Check Report')
$out.Add('')
$out.Add("**Benchmark**: $($assessment.benchmarkRef)  ")
$out.Add("**Report date**: $reportDate  ")
$out.Add("**Composed doc**: `docs/application-documentation.md` (20 sections)  ")
$out.Add('')
$out.Add('> **What this is:** a per-section rubric that scores each of the 20 composed sections against the HELP_DESK benchmark, so "up to the standard" is MEASURABLE per section. Each section is classified exactly once:')
$out.Add('>   ')
$out.Add('>   | Status | Meaning |')
$out.Add('>   |--------|---------|')
$out.Add('>   | **PASS** | structurally present + populated with REAL content + epistemic-tagged + re-verifiable + at benchmark depth |')
$out.Add('>   | **WEAK** | present + populated but BELOW benchmark depth (a source-grounded section with real rows but fewer than the source/benchmark cap supports), or missing epistemic tags — a real finding |')
$out.Add('>   | **EMPTY** | present (heading) but NO real content, and the source DOES support content — a real finding |')
$out.Add('>   | **OWNER_REQUIRED** | a KNOWN owner-pending cell (capability matrix 5.2, policy/escalation 7, escalation paths 11, ownership/on-call/SLO 13, open questions 17) — correctly tagged `Unknown`, pending `/appdoc.enhance`, NOT a failure |')
$out.Add('>   | **N/A** | a FRAMEWORK-N/A section: it documents a capability that only exists in classic-ASP codebases (today, only the Stored-procedure data dictionary — ADO stored procedures transcribed from live `.inc` files). When the target has NO ADO data surface, it is **excluded from the sub-score denominator** (not summed, not counted) and NOT treated as EMPTY — the honest classification, not a gap |')
$out.Add('>   ')
$out.Add('>   **Depth rule (objective):** a TABLE section is populated iff it carries >=1 real data row (not a header + a `_No ... detected._` placeholder); a TEXT/DIAGRAM section iff it carries >=1 substantive paragraph / list-item / mermaid block. WEAK vs PASS compares the surfaced rows to the **benchmark cap** (the composer-designed representative sample, e.g. Functional Inventory capped at 60) CAPPED by the real source count (from the evidence artifacts), so a thin source is never a false finding.')
$out.Add('')
$out.Add('> **Non-blocking / additive:** the overall pristine sub-score below is a DEPTH measurement. It is reported in `docs/validation-report.json` (a `pristine` field) but does NOT change `status` (pass/fail) or `overallScore` (the structural conformance composite is untouched). It is not a gate and cannot be gamed into a pass.')
$out.Add('')

# --- per-section table (20 rows, in spine order) -----------------------------
$out.Add('## Per-section rubric (20 sections)')
$out.Add('')
$out.Add('| # | Section | Status | Reason (one line) | Rows | Benchmark ref |')
$out.Add('|---|---------|--------|-------------------|------|---------------|')
$idx = 1
foreach ($rec in $assessment.records) {
    $statusBadge = switch ($rec.status) {
        'PASS'           { 'PASS' }
        'WEAK'           { 'WEAK' }
        'EMPTY'          { 'EMPTY' }
        'OWNER_REQUIRED' { 'OWNER-REQUIRED' }
        'NA'             { 'N/A' }
    }
    $reason = [string]$rec.reason
    # keep the reason on one line and pipe-safe for the markdown table
    $reason = ($reason -replace '\|', '\|') -replace "`r?`n", ' '
    $out.Add("| $idx | $($rec.section) | **$statusBadge** | $reason | $($rec.rowCount) | $($rec.benchmarkRef) |")
    $idx++
}
$out.Add('')

# --- summary ------------------------------------------------------------------
$counts = $assessment.counts
$passN  = [int]$counts.PASS
$weakN  = [int]$counts.WEAK
$emptyN = [int]$counts.EMPTY
$ownerN = [int]$counts.OWNER_REQUIRED
$naN    = [int]$counts.NA
# scoredN = the denominator (every section EXCEPT N/A; N/A is excluded from both the
# sum and the denominator). totalN = all 20 sections (scored + N/A).
$scoredN = $passN + $weakN + $emptyN + $ownerN
$totalN  = $scoredN + $naN
$subScore = $assessment.subScore

$out.Add('## Summary')
$out.Add('')
$out.Add('| Status | Count | Meaning |')
$out.Add('|--------|-------|---------|')
$out.Add("| **PASS** | $passN | at benchmark depth, real content, epistemic-tagged |")
$out.Add("| **WEAK** | $weakN | populated but below benchmark depth / missing tags (real finding) |")
$out.Add("| **EMPTY** | $emptyN | no real content where the source supports it (real finding) |")
$out.Add("| **OWNER-REQUIRED** | $ownerN | known owner-pending cell, correctly `Unknown`, pending `/appdoc.enhance` (NOT a failure) |")
$out.Add("| **N/A** | $naN | framework-N/A (capability is classic-ASP-specific; target has no ADO surface) — EXCLUDED from the sub-score denominator |")
$out.Add("| **Scored (denominator)** | $scoredN | every section except N/A; the sub-score is `Round(Σ(scores) / $scoredN, 1)` |")
$out.Add("| **Total** | $totalN | all sections (scored + N/A) |")
$out.Add('')
$out.Add('| Metric | Value |')
$out.Add('|--------|-------|')
$out.Add("| **Overall pristine sub-score** | **$subScore / 100** |")
$out.Add("| **Denominator (scored sections, excl. N/A)** | $scoredN |")
$out.Add('| PASS ratio (of scored) | {0}% |' -f [Math]::Round(($passN / [Math]::Max(1, $scoredN)) * 100, 1))
$out.Add('| Re-verifiable (>=1 re-runnable command in Verification Appendix) | ' + $(if ($assessment.reVerifiable) { 'yes' } else { 'no' }) + ' |')
$out.Add('| Determinism hash (over the per-section records, excl. timestamp) | `' + $($assessment.determinismHash) + '` |')
$out.Add('')
# --- OWNER-PENDING CHECKLIST (Deliverable C) --------------------------------
# A clean, human-readable checklist of the 5 OWNER-REQUIRED cells — the
# 'what's left for a human' complement to the source-derivable (auto) content.
# Reuses the rubric's OWNER_REQUIRED classification (the SAME 5 cells this run
# actually classified), so it is framework-agnostic + deterministic. Additive:
# it does NOT change the 20-row table, the sub-score, or the gate.
$checklist = @(Get-AppDocPristineOwnerPendingChecklist -records $assessment.records)
$out.Add('')
$out.Add('## Owner-pending checklist (`/appdoc.enhance`)')
$out.Add('')
$out.Add('> **What this is:** the cells that are correctly tagged `Unknown` and pending `/appdoc.enhance` — the complement to the source-derivable (auto) content. These are **NOT failures** (they classify `OWNER_REQUIRED`, not `EMPTY`). This is the deterministic, framework-agnostic "what is left for a human" checklist. It is ADDED on every run regardless of the pristine gate mode.')
$out.Add('')
if ($checklist.Count -eq 0) {
    $out.Add('_No OWNER-REQUIRED cells this run (no owner-pending cells to fill)._')
} else {
    $out.Add('| # | Section | Benchmark ref | What''s missing | Owner must provide | `/appdoc.enhance` target |')
    $out.Add('|---|---------|---------------|-----------------|--------------------|--------------------------|')
    $cidx = 1
    foreach ($cell in $checklist) {
        $what = ([string]$cell.whatsMissing -replace '\|', '\|') -replace "`r?`n", ' '
        $must = ([string]$cell.ownerMustProvide -replace '\|', '\|') -replace "`r?`n", ' '
        $tgt  = ([string]$cell.enhanceTarget -replace '\|', '\|') -replace "`r?`n", ' '
        $out.Add("| $cidx | $($cell.section) | $($cell.sectionRef) | $what | $must | $tgt |")
        $cidx++
    }
}
$out.Add('')

# --- mode footer (Deliverable A) ---------------------------------------------
# The pristine check is a DEPTH measurement, NOT a structural-conformance gate.
# Two modes are EXPLICIT: REPORT-ONLY (DEFAULT, the pipeline's normal run) and
# BLOCKING (OPT-IN, only when the operator passes -PristineGate). This report is
# ALWAYS report-only output; the BLOCKING decision is computed by the gate
# (validate-documentation.ps1) and recorded in validation-report.json's pristineGate.
# (Mode names mirror AppDoc.Pristine.psm1: report-only = DEFAULT, blocking = OPT-IN.)
$out.Add('---')
$out.Add('')
$out.Add('### Gate mode')
$out.Add('')
$out.Add('| Mode | Status | Effect |')
$out.Add('|------|--------|--------|')
$out.Add('| **`report-only`** (DEFAULT) | on for every pipeline run | the pristine sub-score is a DEPTH measurement: additive only — does NOT change `status` (pass/fail) or `overallScore` (the structural conformance composite is untouched). The run is never blocked by the pristine check. |')
$out.Add('| **`blocking`** (OPT-IN) | only with `-PristineGate` on `run-all-generators.ps1` | the pristine check becomes a real gate that BLOCKS the run when any section is `EMPTY` (emptyCount>0) OR the sub-score < floor (`-PristineFloor`, default 80). OWNER_REQUIRED cells are EXCLUDED (pending `/appdoc.enhance`, not failures). The decision is the pure function `Test-AppDocPristineGate`; the result is recorded in `validation-report.json` as `pristineGate`. |')
$out.Add('')
$out.Add('*Default = report-only. This report is the human-readable companion; the machine-readable gate decision (`mode` / `enabled` / `blocked`) lives in `docs/validation-report.json` -> `pristineGate`.*')
$out.Add('')
$out.Add('---')
$out.Add('')
$out.Add('*Generated by `generate-pristine-report.ps1` (pure function of the composed doc + evidence artifacts; no LLM, no network, no randomness). The pristine sub-score is a DEPTH measurement: by default it is NON-BLOCKING / additive (report-only) and does not change `status` or `overallScore` in `docs/validation-report.json`; it blocks only under the OPT-IN `blocking` mode (`-PristineGate`).*')

$reportPath = Join-Path $docsPath 'pristine-report.md'
($out -join "`r`n") | Out-File -FilePath $reportPath -Encoding UTF8 -NoNewline

# --- machine evidence record --------------------------------------------------
$evidenceDir = Join-Path $docsPath 'evidence'
if (-not (Test-Path $evidenceDir)) { New-Item -Path $evidenceDir -ItemType Directory -Force | Out-Null }

$evOut = [ordered]@{
    artifact          = 'pristine-report'
    generator         = 'generate-pristine-report.ps1'
    module            = 'AppDoc.Pristine.psm1'
    reportDate        = $reportDate
    benchmarkRef      = $assessment.benchmarkRef
    subScore          = $assessment.subScore
    counts            = [ordered]@{
        PASS = [int]$counts.PASS
        WEAK = [int]$counts.WEAK
        EMPTY = [int]$counts.EMPTY
        OWNER_REQUIRED = [int]$counts.OWNER_REQUIRED
        NA = [int]$counts.NA
        scored = $scoredN
        total = $totalN
    }
    frameworkLabel    = [string]$assessment.frameworkLabel
    targetHasAdoSurface = [bool]$assessment.targetHasAdoSurface
    naCount           = [int]$assessment.naCount
    scoredCount       = [int]$assessment.scoredCount
    totalSections     = [int]$assessment.totalSections
    reVerifiable      = [bool]$assessment.reVerifiable
    sourceSupport     = $assessment.sourceSupport
    # Owner-pending checklist (Deliverable C): the machine-readable complement to the
    # source-derivable content — the 5 OWNER_REQUIRED cells, each with what's-missing /
    # owner-must-provide / enhance-target. Reuses the rubric's classification (the SAME
    # 5 cells this run actually classified OWNER_REQUIRED), so it is deterministic +
    # framework-agnostic. Additive — it does NOT change subScore, counts, or the gate.
    ownerPendingChecklist = @($checklist | ForEach-Object {
        [ordered]@{
            section          = [string]$_.section
            sectionRef       = [string]$_.sectionRef
            whatsMissing     = [string]$_.whatsMissing
            ownerMustProvide = [string]$_.ownerMustProvide
            enhanceTarget    = [string]$_.enhanceTarget
        }
    })
    records           = @($assessment.records | ForEach-Object {
        [ordered]@{
            section         = [string]$_.section
            headingPresent  = [bool]$_.headingPresent
            status          = [string]$_.status
            reason          = [string]$_.reason
            populated       = [bool]$_.populated
            rowCount        = [int]$_.rowCount
            textPopulation  = [int]$_.textPopulation
            hasMermaid      = [bool]$_.hasMermaid
            sourceSupport   = [int]$_.sourceSupport
            epistemicTagged = [bool]$_.epistemicTagged
            reVerifiable    = [bool]$_.reVerifiable
            benchmarkRef    = [string]$_.benchmarkRef
            ownerPending    = [bool]$_.ownerPending
            frameworkNA     = [bool]$_.frameworkNA
            sectionScore    = [int]$_.sectionScore
        }
    })
    determinismHash   = $assessment.determinismHash
}
$evPath = Join-Path $evidenceDir 'pristine.evidence.json'
$evOut | ConvertTo-Json -Depth 12 | Out-File -FilePath $evPath -Encoding UTF8

Write-Host "   Wrote pristine-report.md ($totalN sections; sub-score $subScore/100)." -ForegroundColor Gray
Write-Host "   Wrote evidence: $evPath" -ForegroundColor Gray
Write-Host "PRISTINE_SUBSCORE $subScore"
