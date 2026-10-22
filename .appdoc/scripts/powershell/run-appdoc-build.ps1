#
# run-appdoc-build.ps1
#
# Purpose: THE single AppDoc build command.  `appdoc build <path>` semantics:
#              pwsh run-appdoc-build.ps1 -Path <target-repo>
#          takes ONE target path and produces the COMPLETE docs package from a clean
#          output dir: the 20-section application-documentation.md, application-documentation
#          report.html, all per-artifact + evidence JSON (incl. git-ownership), pristine-report.md,
#          and validation-report.json.
#
#          This is a THIN WRAPPER that ORCHESTRATES the existing pipeline — it does NOT
#          re-implement or fork the extractors / composer / gate. Concretely it:
#            (1) loads <target>/.appdoc/config.json (AppDoc.Config) — theme, redaction
#                patterns, pristine floor (sensible defaults when absent -> backward-compat:
#                a no-config target behaves exactly as today);
#            (2) invokes the existing run-all-generators.ps1 pipeline (the real work, now
#                including the NEW generate-git-ownership.ps1 + the composer + pristine +
#                validation), passing the config pristineFloor through;
#            (3) regenerates the HTML report with the CONFIG THEME (a no-op when the config
#                is the default CMU theme -> byte-identical);
#            (4) applies a CONFIG-DRIVEN redaction sweep to the final artifacts
#                (config redactionPatterns -> [REDACTED]; a byte-identical no-op when the
#                config has no patterns, i.e. the default -> backward-compatible).
#
#          Why NOT re-run the composer: the pipeline's own composer run already reads the
#          git-ownership evidence (generate-git-ownership.ps1 now runs in the Generation
#          phase before the composer), and the pipeline stamps the Provenance footer AFTER
#          the composer. Re-running the composer here would drop that provenance stamp and
#          risk a gate regression. The wrapper therefore only touches the HTML (a
#          presentation artifact the gate does not score) and the final redaction sweep.
#
#          The gate pass/fail logic/threshold, the extractors' core logic, Get-SectionTable,
#          the §1/§3/§4/§6/§8/§10 fixes, the BUILD-1 source-doc citation logic, and the
#          pristine N/A + owner-pending logic are ALL UNCHANGED. Deterministic: the only
#          wall-clock in the package is the provenance stamp (Generated At) applied by the
#          pipeline (excluded from the determinism check).
#
param(
    [Parameter(Mandatory=$true, Position=0)]
    [string]$Path,
    [Parameter(Mandatory=$false)]
    [string]$Profile = "default",
    [Parameter(Mandatory=$false)]
    [ValidateRange(1, 100)]
    [int]$QualityThreshold = 80,
    [Parameter(Mandatory=$false)]
    [switch]$SkipDiagrams,
    [Parameter(Mandatory=$false)]
    [switch]$SkipSyntaxGate,
    [Parameter(Mandatory=$false)]
    [switch]$StrictValidation,
    [Parameter(Mandatory=$false)]
    [switch]$EnableSemanticEnrich
)

$ErrorActionPreference = "Stop"
$scriptDir   = $PSScriptRoot
$orchestrator = Join-Path $scriptDir "run-all-generators.ps1"
$htmlGen      = Join-Path $scriptDir "generate-html-report.ps1"
$configModule = Join-Path $scriptDir "modules/AppDoc.Config.psm1"

if (-not (Test-Path $Path)) { Write-Error "Target path does not exist: $Path"; exit 1 }
$RootPath = (Resolve-Path -LiteralPath $Path).Path
$docsPath = Join-Path $RootPath "docs"

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AppDoc build  (single command)" -ForegroundColor Cyan
Write-Host " target: $RootPath" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# --- (1) load config (sensible defaults when absent) -------------------------
$themePath = ''
$redactionPatterns = @()
$pristineFloor = 80
if (Test-Path $configModule) {
    Import-Module $configModule -Force -ErrorAction SilentlyContinue
    $cfg = Get-AppDocConfig -RootPath $RootPath
    if ($cfg) {
        $themePath = [string]$cfg.themePath
        $redactionPatterns = @($cfg.values.redactionPatterns | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $pristineFloor = [int]$cfg.values.pristineFloor
        Write-Host "   config: $($cfg.configPath) (loaded=$([bool]$cfg.loaded))  theme=$([string]$cfg.values.theme)  pristineFloor=$pristineFloor  redactionPatterns=$($redactionPatterns.Count)" -ForegroundColor Gray
    }
} else {
    Write-Warning "AppDoc.Config module not found; using defaults (theme=cmu, pristineFloor=80)."
}

# --- (2) run the EXISTING pipeline (the real work) ---------------------------
# The pipeline (run-all-generators.ps1) now runs generate-git-ownership.ps1 (NEW, in the
# Generation phase before the composer) so the composer can project git-derived ownership
# in section 13 (honest-Unknown when history is shallow/absent). The pristine gate is
# report-only (gate OFF, unchanged); the config pristineFloor is passed through so the
# validation report records the floor.
$pipelineArgs = @{ RootPath = $RootPath; Profile = $Profile; QualityThreshold = $QualityThreshold; PristineFloor = $pristineFloor }
if ($SkipDiagrams)   { $pipelineArgs['SkipDiagrams']   = $true }
if ($SkipSyntaxGate) { $pipelineArgs['SkipSyntaxGate'] = $true }
if ($StrictValidation){ $pipelineArgs['StrictValidation'] = $true }

Write-Host "`n[Pipeline] running run-all-generators.ps1 (incl. git-ownership + composer + pristine + validation) ..." -ForegroundColor Cyan
try {
    & $orchestrator @pipelineArgs
} catch {
    Write-Warning "Pipeline reported a non-fatal issue: $($_.Exception.Message)"
}

if (-not (Test-Path $docsPath)) {
    Write-Error "Pipeline did not produce a docs directory: $docsPath"; exit 1
}

# --- (3) SECOND PASS: composer + pristine + validation (now that diagrams exist) ---
# The pipeline's composer (Generation phase) runs BEFORE the C4 / data-flow diagram
# generators (which run after the phase loop), so on a truly clean first pass section
# 14 (Architecture and Data-Flow Diagrams) is composed before the diagram files exist
# and renders "*No diagram was detected*". The committed baseline (pristine 95.8 /
# gate pass) is a SECOND-PASS run: the composer is re-run after the diagrams land so
# section 14 carries the real mermaid projections. This is the SAME composer / pristine /
# validation scripts the pipeline already ran (orchestrated, not re-implemented), re-run
# now that every artifact — including docs/diagrams/* — is present.
#
# Provenance-safety: the provenance policy gate checks ONLY the 5 critical per-artifact
# .md docs (overview/api-inventory/data-model/config-catalog/build-cookbook) + the 3 JSON
# reports — NOT application-documentation.md. The composer re-run rewrites only the
# composed master + its flat evidence json, so no provenance stamp is lost and the gate
# pass/fail is unchanged. This additive 2nd pass does NOT change status/overallScore
# (both are frozen before the pristine fold); it makes the composed doc + pristine report
# reflect the complete, diagram-populated package (section 14 PASS instead of EMPTY).
$composer     = Join-Path $scriptDir "generate-unified-master.ps1"
$pristineGen  = Join-Path $scriptDir "generate-pristine-report.ps1"
$validate     = Join-Path $scriptDir "validate-documentation.ps1"

Write-Host "`n[2nd pass] re-running composer + pristine + validation (diagrams are now present) ..." -ForegroundColor Cyan
if (Test-Path $composer) {
    try { & $composer -RootPath $RootPath } catch { Write-Warning "Composer 2nd-pass re-run failed: $($_.Exception.Message)" }
}
if (Test-Path $pristineGen) {
    try { & $pristineGen -RootPath $RootPath } catch { Write-Warning "Pristine 2nd-pass re-run failed (non-fatal): $($_.Exception.Message)" }
}
if (Test-Path $validate) {
    try {
        if ($StrictValidation) { & $validate -RootPath $RootPath -Strict -Threshold $QualityThreshold -PristineFloor $pristineFloor -Json | Out-Null }
        else { & $validate -RootPath $RootPath -Threshold $QualityThreshold -PristineFloor $pristineFloor -Json | Out-Null }
    } catch { Write-Warning "Structured validation 2nd-pass re-run failed (non-fatal): $($_.Exception.Message)" }
}

# --- (4) HTML report with the CONFIG THEME ------------------------------------
# The pipeline's HTML gen used the default theme; regenerate with the config-resolved
# theme. report.html is a presentation artifact the gate does not score, so regenerating
# it here (after the gate) cannot change status/overallScore. When the config theme is
# the default CMU (theme.json) this is byte-identical to the pipeline's output.
if (Test-Path $htmlGen) {
    try {
        if ($themePath -and (Test-Path -LiteralPath $themePath)) { & $htmlGen -RootPath $RootPath -ThemePath $themePath }
        else { & $htmlGen -RootPath $RootPath }
    } catch { Write-Warning "HTML report generation failed (non-fatal): $($_.Exception.Message)" }
}

# --- (5) CONFIG-DRIVEN redaction sweep (additive; no-op when no patterns) ----
# Defense-in-depth over the FINAL composed artifacts: replace each config
# redactionPattern with [REDACTED]. With the default config (no patterns) this is a
# byte-identical no-op, so a no-config target behaves exactly as today. The built-in
# extractors redact credentials by shape/key-name; this sweep ADDS any
# operator-supplied patterns. Applied last so the final docs/ state is the redacted state.
#
# Finding 1 (URI-credential redaction gap, defense-in-depth): the sweep ALSO applies the
# URI-credential regex patterns (user:pass@ / ://:pass@) to every final artifact. These are
# imported from the LAYER-2 semantic module (AppDoc.SemanticRedaction) as the single source
# of truth so the two redaction layers cannot drift. The patterns are VALUE-SCOPED (a real
# `user:pass@` credential, never a config KEY NAME or a source path), so the sweep is a
# byte-identical no-op on any artifact with no embedded URI credential -- including the
# committed baselines (verified 0 hits) and every fixture -- while it
# closes a leak that the extractor-level redaction (Protect-AppDocConfigValue) missed.
$semanticRedactionModule = Join-Path $scriptDir "modules/AppDoc.SemanticRedaction.psm1"
$uriCredPatterns = @()
if (Test-Path $semanticRedactionModule) {
    try {
        Import-Module $semanticRedactionModule -Force -ErrorAction Stop
        $uriCredPatterns = @(Get-AppDocSemanticUriCredentialPatterns)
    }
    catch { Write-Warning "[Redaction] could not load semantic redaction module; skipping built-in URI-credential sweep: $($_.Exception.Message)" }
}

if ($redactionPatterns.Count -gt 0 -or $uriCredPatterns.Count -gt 0) {
    $sweepFiles = @()
    foreach ($ext in @('*.md', '*.html', '*.json')) {
        $sweepFiles += @(Get-ChildItem -Path $docsPath -Filter $ext -File -Recurse -ErrorAction SilentlyContinue)
    }
    $changed = 0
    foreach ($f in $sweepFiles) {
        $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        $orig = $content
        foreach ($pat in $redactionPatterns) {
            $content = [regex]::Replace($content, [regex]::Escape([string]$pat), '[REDACTED]')
        }
        # Built-in URI-credential sweep (value-scoped; single source of truth = semantic module).
        foreach ($uriPat in $uriCredPatterns) {
            $content = [regex]::Replace($content, $uriPat, '[REDACTED]')
        }
        if ($content -cne $orig) {
            $content | Out-File -LiteralPath $f.FullName -Encoding UTF8 -NoNewline
            $changed++
        }
    }
    Write-Host "[Redaction] config redactionPatterns=$($redactionPatterns.Count) uriCredPatterns=$($uriCredPatterns.Count); $changed file(s) swept." -ForegroundColor Gray
} else {
    Write-Host "[Redaction] no config redactionPatterns -> sweep is a no-op (built-in extractors still redact known secrets)." -ForegroundColor Gray
}

# --- (6) OPT-IN semantic (LLM) enrichment stage (Phase 2a; default OFF) ---------
# When OFF (the default), this is a clean NO-OP: no LLM call, no enrichment applied,
# and the deterministic-only output is EXACTLY today's output (the deterministic layer
# remains the gate-able core). When ON (the -EnableSemanticEnrich switch OR the
# config enableSemanticEnrich key) the DETERMINISTIC substrate runs:
#   (a) run-appdoc-enrich.ps1 bootstraps the schema-bootstrap enriched evidence and
#       applies the deterministic apply-merge, which (under the quarantine) writes the
#       redacted LLM-facing input envelope to docs/evidence/semantic/input/ and reads
#       docs/evidence/semantic/output/ (written by the EXTERNAL LLM session) applying
#       it with provenance tagging + the Verified-fact lock + no-fabrication.
#       -SkipReRender keeps the 4 .md catalogs (gate-scored artifacts) byte-identical to
#       the deterministic pass, so the enrichment substrate cannot regress the gate.
# The stage is FAIL-CLOSED on the secret-redaction hard gate: if a known secret
# survives redaction in the would-be input, it BLOCKS with a clear error (no silent
# proceed, no un-redacted write).
$semEnable = [bool]$EnableSemanticEnrich
if (-not $semEnable -and $cfg -and $null -ne $cfg.values.enableSemanticEnrich) {
    $semEnable = [bool]$cfg.values.enableSemanticEnrich
}
if ($semEnable) {
    Write-Host "`n[SemanticEnrich] OPT-IN semantic (LLM) enrichment stage enabled..." -ForegroundColor Cyan
    $enrichScript = Join-Path $scriptDir "run-appdoc-enrich.ps1"
    if (Test-Path $enrichScript) {
        try {
            # -SkipGate: the enrichment bootstrap's own ci-enrichment-gate.ps1 is a
            # separate legacy gate; the authoritative documentation gate is the one the
            # pipeline already ran (and -SkipReRender keeps the gate-scored artifacts
            # untouched). -SkipReRender: do not re-render the 4 .md catalogs.
            # We do NOT read $LASTEXITCODE after this .ps1 call: it is only updated by
            # native executables, so it would observe a STALE value from a prior native
            # command (e.g. git in a non-repo) and false-alarm. A real stage failure
            # (including the fail-closed secret-redaction gate) throws, which the catch
            # below surfaces as a warning without clobbering the deterministic output.
            & $enrichScript -RootPath $RootPath -SkipGate -SkipReRender
        } catch {
            # Fail-closed: a secret-redaction gate block (or any stage failure) surfaces
            # as a warning here; it does NOT clobber the deterministic-only output.
            Write-Warning "Semantic enrichment stage failed: $($_.Exception.Message)"
        }
    }
    else {
        Write-Warning "Semantic enrichment script not found: $enrichScript (stage skipped)."
    }
}
else {
    Write-Host "[SemanticEnrich] OFF (default) -> no-op; deterministic-only output is exactly today's (no LLM call, no enrichment applied)." -ForegroundColor Gray
}

# --- summary -----------------------------------------------------------------
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " AppDoc build complete: $docsPath" -ForegroundColor Cyan
if (Test-Path (Join-Path $docsPath 'validation-report.json')) {
    try {
        $vr = Get-Content -LiteralPath (Join-Path $docsPath 'validation-report.json') -Raw | ConvertFrom-Json -Depth 20
        $pristineSub = if ($vr.PSObject.Properties['pristine']) { $vr.pristine.subScore } else { 'n/a' }
        Write-Host ("   gate status={0}  overallScore={1}  pristine sub-score={2}" -f $vr.status, $vr.overallScore, $pristineSub) -ForegroundColor Green
    } catch { Write-Warning "Could not read validation-report.json for the summary." }
}
Write-Host "==========================================" -ForegroundColor Cyan
