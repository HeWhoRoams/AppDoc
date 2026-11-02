#requires -Version 7.2
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
#          This is a THIN WRAPPER that ORCHESTRATES the existing pipeline; it does not
#          re-implement the extractors / composer / gate. Steps:
#            (1) load <target>/.appdoc/config.json (AppDoc.Config) - theme, redaction
#                patterns, pristine floor (defaults when absent);
#            (2) run-all-generators.ps1 (the real work: extractors, git-ownership, composer,
#                pristine, validation);
#            (3) second pass: composer + pristine + validation once diagrams exist;
#            (4) HTML report with the config theme;
#            (5) redaction sweep over the final artifacts (fail-closed);
#            (6) semantic (LLM) enrichment stage (always runs; emits the redacted input and
#                applies any output the surrounding AI session wrote).
#
# Exit codes (see docs/adr/0003-sub-validator-failure-policy.md):
#   0  gate passed (or -AllowGateFail was given)
#   1  tool error (bad path, missing module, invalid config, a pipeline generator crashed,
#      no validation report)
#   2  gate failed: docs were written but did not pass the gate
#   3  fail-closed stop: the redaction sweep or the semantic secret-redaction gate blocked
#
[CmdletBinding()]
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
    [switch]$AllowGateFail
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

$ErrorActionPreference = "Stop"
$scriptDir   = $PSScriptRoot
$orchestrator = Join-Path $scriptDir "run-all-generators.ps1"
$htmlGen      = Join-Path $scriptDir "generate-html-report.ps1"
$configModule = Join-Path $scriptDir "modules/AppDoc.Config.psm1"

if (-not (Test-Path $Path)) { Write-Error "Target path does not exist: $Path"; exit 1 }
$RootPath = (Resolve-Path -LiteralPath $Path).Path
$docsPath = (Get-AppDocDocsPath -RootPath $RootPath)

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host " AppDoc build  (single command)" -ForegroundColor Cyan
Write-Host " target: $RootPath" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan

# --- (1) load config (sensible defaults when absent) -------------------------
$themePath = ''
$redactionPatterns = @()
$redactionRegexes = @()
$pristineFloor = 80
$cfg = $null
if (Test-Path $configModule) {
    Import-Module $configModule -Force -ErrorAction Stop
    $cfg = Get-AppDocConfig -RootPath $RootPath
    if ($cfg -and $cfg.error) {
        Write-Error "[Config] $($cfg.error). Fix the file (or remove it to use defaults); refusing to build without the operator's redaction settings." -ErrorAction Continue
        exit 1
    }
    if ($cfg) {
        $themePath = [string]$cfg.themePath
        $redactionPatterns = @($cfg.values.redactionPatterns | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $redactionRegexes = @($cfg.values.redactionRegexes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) })
        $pristineFloor = [int]$cfg.values.pristineFloor
        Write-Host "   config: $($cfg.configPath) (loaded=$([bool]$cfg.loaded))  theme=$([string]$cfg.values.theme)  pristineFloor=$pristineFloor  redactionPatterns=$($redactionPatterns.Count)  redactionRegexes=$($redactionRegexes.Count)" -ForegroundColor Gray
    }
} else {
    Write-Error "AppDoc.Config module not found: $configModule"; exit 1
}

# Compile operator redaction now so an invalid regex stops the build before any output is
# written (fail-closed, exit 3).
$secretPolicyModule = Join-Path $scriptDir "modules/AppDoc.SecretPolicy.psm1"
try {
    Import-Module $secretPolicyModule -Force -ErrorAction Stop
    $operatorMatchers = Get-AppDocOperatorRedactionMatchers -Literals $redactionPatterns -Regexes $redactionRegexes
}
catch {
    Write-Error "[Redaction] FAIL-CLOSED: $($_.Exception.Message)" -ErrorAction Continue
    exit 3
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
# The orchestrator's own exit code is not used: native commands it runs (git) also set
# $LASTEXITCODE, so the value is ambiguous. The authoritative outcome is the final
# validation-report.json, which decides the build exit code at the end of this script.
# A throw from the orchestrator (failed syntax pre-check, another run active, a strict-mode check, a
# missing module) means the pipeline did not finish, so the build stops here with a tool error. It
# used to be reported as a warning and the build carried on.
try {
    & $orchestrator @pipelineArgs
} catch {
    Write-Error "[Pipeline] The pipeline stopped: $($_.Exception.Message) (exit 1)" -ErrorAction Continue
    # Remove a run lock that this aborted run left behind. Never remove one held by another live run.
    $lockPath = Join-Path $docsPath '.appdoc-run.session.json'
    if (Test-Path -LiteralPath $lockPath) {
        $lockPid = 0
        try { $lockPid = [int]((Get-Content -LiteralPath $lockPath -Raw | ConvertFrom-Json).pid) } catch { $lockPid = 0 }
        if ($lockPid -le 0 -or $lockPid -eq $PID -or -not (Get-Process -Id $lockPid -ErrorAction SilentlyContinue)) {
            Remove-Item -LiteralPath $lockPath -Force -ErrorAction SilentlyContinue
        }
    }
    exit 1
}
$global:LASTEXITCODE = 0

# Crashes in this script's own generator steps (second pass, themed report, enrichment) are recorded here
# and added to the orchestrator's list at close-out (ADR 0003 section 4).
$buildFailures = @()

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
# Provenance: the composer re-run rewrites the composed master without a footer; step
# (4b) below re-stamps every generated doc, so the final package always carries one. This additive 2nd pass does NOT change status/overallScore
# (both are frozen before the pristine fold); it makes the composed doc + pristine report
# reflect the complete, diagram-populated package (section 14 PASS instead of EMPTY).
$composer     = Join-Path $scriptDir "generate-unified-master.ps1"
$pristineGen  = Join-Path $scriptDir "generate-pristine-report.ps1"
$validate     = Join-Path $scriptDir "validate-documentation.ps1"

Write-Host "`n[2nd pass] re-running composer + pristine + validation (diagrams are now present) ..." -ForegroundColor Cyan
if (Test-Path $composer) {
    try { & $composer -RootPath $RootPath } catch {
        Write-Warning "Composer 2nd-pass re-run failed: $($_.Exception.Message)"
        $buildFailures += [ordered]@{ phase = '2nd pass'; script = 'generate-unified-master.ps1'; error = $_.Exception.Message }
    }
}
if (Test-Path $pristineGen) {
    try { & $pristineGen -RootPath $RootPath } catch {
        Write-Warning "Pristine 2nd-pass re-run failed: $($_.Exception.Message)"
        $buildFailures += [ordered]@{ phase = '2nd pass'; script = 'generate-pristine-report.ps1'; error = $_.Exception.Message }
    }
}
if (Test-Path $validate) {
    try {
        if ($StrictValidation) { & $validate -RootPath $RootPath -Strict -Threshold $QualityThreshold -PristineFloor $pristineFloor -Json | Out-Null }
        else { & $validate -RootPath $RootPath -Threshold $QualityThreshold -PristineFloor $pristineFloor -Json | Out-Null }
    } catch {
        Write-Warning "Structured validation 2nd-pass re-run failed: $($_.Exception.Message)"
        $buildFailures += [ordered]@{ phase = '2nd pass'; script = 'validate-documentation.ps1'; error = $_.Exception.Message }
    }
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
    } catch {
        Write-Warning "HTML report generation failed: $($_.Exception.Message)"
        $buildFailures += [ordered]@{ phase = 'themed report'; script = 'generate-html-report.ps1'; error = $_.Exception.Message }
    }
}

# --- (4b) Provenance footer on every generated doc (final stamp) -------------
# The second composer pass above rewrote application-documentation.md without a footer;
# stamp every generated docs/**/*.md now (idempotent; hand-authored files are skipped).
$provenanceModule = Join-Path $scriptDir "modules/AppDoc.Provenance.psm1"
Import-Module $provenanceModule -Force -ErrorAction Stop
$stampedCount = Set-AppDocProvenanceFooter -RootPath $RootPath -DocsPath $docsPath -Profile $Profile
Write-Host "[Provenance] footer stamped on $stampedCount generated Markdown file(s)." -ForegroundColor Gray

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
# FAIL-CLOSED: if the redaction module cannot be loaded the build stops (exit 3); it never
# continues without the built-in URI-credential patterns.
$uriCredPatterns = @()
try {
    if (-not (Test-Path $semanticRedactionModule)) { throw "module not found: $semanticRedactionModule" }
    Import-Module $semanticRedactionModule -Force -ErrorAction Stop
    $uriCredPatterns = @(Get-AppDocSemanticUriCredentialPatterns)
    if ($uriCredPatterns.Count -eq 0) { throw "no URI-credential patterns returned" }
}
catch {
    Write-Error "[Redaction] FAIL-CLOSED: cannot load the redaction module ($($_.Exception.Message)). The final docs were NOT swept; do not publish them." -ErrorAction Continue
    exit 3
}

# The built-in shapes are never empty, so the sweep always runs.
if ($true) {
    $sweepFiles = @()
    foreach ($ext in @('*.md', '*.html', '*.json')) {
        $sweepFiles += @(Get-ChildItem -Path $docsPath -Filter $ext -File -Recurse -ErrorAction SilentlyContinue)
    }
    $changed = 0
    foreach ($f in $sweepFiles) {
        $content = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        # Hand-authored files (docs/adr/, or carrying the hand-authored marker) are not build
        # output; rewriting them would corrupt prose such as a documented `user:pass@` example.
        if (Test-AppDocHandAuthoredDoc -Path $f.FullName -DocsPath $docsPath -Content $content) { continue }
        $orig = $content
        # Vendored third-party blocks (e.g. the inlined Mermaid library in report.html) are
        # skipped: they cannot hold target secrets, and the regexes would corrupt them.
        $parts = [regex]::Split($content, '(/\*appdoc-vendor:begin [a-z0-9-]+\*/.*?/\*appdoc-vendor:end [a-z0-9-]+\*/)', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        for ($pi = 0; $pi -lt $parts.Count; $pi++) {
            if ($parts[$pi].StartsWith('/*appdoc-vendor:begin ')) { continue }
            # Operator redaction: redactionPatterns (literal values) + redactionRegexes.
            $parts[$pi] = Invoke-AppDocOperatorRedaction -Text $parts[$pi] -Matchers $operatorMatchers
            # Built-in URI-credential sweep (value-scoped; single source of truth = semantic module).
            foreach ($uriPat in $uriCredPatterns) {
                $parts[$pi] = [regex]::Replace($parts[$pi], $uriPat, '[REDACTED]')
            }
            # Vendor key shapes, `key = value` for credential key names, Bearer tokens.
            $parts[$pi] = Protect-AppDocFreeText -Text $parts[$pi]
        }
        $content = -join $parts
        if ($content -cne $orig) {
            $content | Out-File -LiteralPath $f.FullName -Encoding UTF8 -NoNewline
            $changed++
        }
    }
    Write-Host "[Redaction] config redactionPatterns=$($redactionPatterns.Count) redactionRegexes=$($redactionRegexes.Count) uriCredPatterns=$($uriCredPatterns.Count); $changed file(s) swept." -ForegroundColor Gray
    # Fail-closed post-check: a vendor secret shape that survived the sweep stops the build.
    $leaks = @()
    foreach ($f in $sweepFiles) {
        $c = Get-Content -LiteralPath $f.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        if (Test-AppDocHandAuthoredDoc -Path $f.FullName -DocsPath $docsPath -Content $c) { continue }
        $visible = [regex]::Replace($c, '/\*appdoc-vendor:begin [a-z0-9-]+\*/.*?/\*appdoc-vendor:end [a-z0-9-]+\*/', '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
        if (Test-AppDocVendorSecret -Text $visible) { $leaks += $f.FullName.Substring($docsPath.Length).TrimStart('\','/') }
    }
    if ($leaks.Count -gt 0) {
        Write-Error "[Redaction] FAIL-CLOSED: a secret shape survived the sweep in: $($leaks -join ', '). Do not publish these docs." -ErrorAction Continue
        exit 3
    }
}

# --- (6) semantic (LLM) enrichment stage (Phase 2a; always runs) ---------------
# The stage is a required part of every build. It makes no LLM call itself: the DETERMINISTIC
# substrate runs, and the surrounding AI session fills the output between two builds. With no
# output present nothing is applied and the deterministic layer remains the gate-able core.
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
Write-Host "`n[SemanticEnrich] semantic (LLM) enrichment stage ..." -ForegroundColor Cyan
$enrichScript = Join-Path $scriptDir "run-appdoc-enrich.ps1"
if (Test-Path $enrichScript) {
    try {
        # -SkipGate: the enrichment bootstrap's own ci-enrichment-gate.ps1 is a
        # separate legacy gate; the authoritative documentation gate is the one the
        # pipeline already ran. -SkipReRender keeps the 4 gate-scored .md catalogs
        # untouched. A fail-closed secret-redaction block throws; it stops the build
        # with exit 3 (the deterministic docs remain, the LLM input is NOT written).
        & $enrichScript -RootPath $RootPath -SkipGate -SkipReRender
    } catch {
        if ($_.Exception.Message -match 'SECRET-REDACTION HARD GATE') {
            Write-Error "[SemanticEnrich] FAIL-CLOSED: $($_.Exception.Message)" -ErrorAction Continue
            exit 3
        }
        Write-Warning "Semantic enrichment stage failed: $($_.Exception.Message)"
        $buildFailures += [ordered]@{ phase = 'enrichment'; script = 'run-appdoc-enrich.ps1'; error = $_.Exception.Message }
    }
    $global:LASTEXITCODE = 0
}
else {
    Write-Warning "Semantic enrichment script not found: $enrichScript (stage skipped)."
    $buildFailures += [ordered]@{ phase = 'enrichment'; script = 'run-appdoc-enrich.ps1'; error = 'script not found' }
}

# --- (7) line endings: UTF-8 (no BOM), LF, one final newline -----------------
# Matches .gitattributes (*.md eol=lf). ConvertTo-Json / Out-File emit CRLF on Windows,
# so this last pass is what makes the output identical on every OS.
$lfCount = Convert-AppDocDocsLineEndings -DocsPath $docsPath
Write-Host "[LineEndings] normalized $lfCount file(s) to LF." -ForegroundColor Gray

# --- summary + exit code -----------------------------------------------------
Write-Host "`n==========================================" -ForegroundColor Cyan
Write-Host " AppDoc build complete: $docsPath" -ForegroundColor Cyan
$reportPath = Join-Path $docsPath 'validation-report.json'
if (-not (Test-Path $reportPath)) {
    Write-Error "No validation-report.json was produced; the build cannot be trusted." -ErrorAction Continue
    exit 1
}
try {
    $vr = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json -Depth 20
} catch {
    Write-Error "validation-report.json is unreadable: $($_.Exception.Message)" -ErrorAction Continue
    exit 1
}
$pristineSub = if ($vr.PSObject.Properties['pristine']) { $vr.pristine.subScore } else { 'n/a' }
Write-Host ("   gate status={0}  overallScore={1}  pristine sub-score={2}" -f $vr.status, $vr.overallScore, $pristineSub) -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Cyan

# A generator that crashed is a tool error even when the gate passes: the docs it should have
# written are missing or stale, and the gate cannot always tell. (This used to be a warning only.)
$diagPath = Join-Path $docsPath 'diagnostics-report.json'
$failedScripts = @()
$diag = $null
if (Test-Path -LiteralPath $diagPath) {
    try {
        $diag = Get-Content -LiteralPath $diagPath -Raw | ConvertFrom-Json -Depth 20
        $failedScripts = @($diag.metadata.scriptFailures | Where-Object { $_ })
    }
    catch {
        Write-Error "diagnostics-report.json is unreadable: $($_.Exception.Message)" -ErrorAction Continue
        exit 1
    }
}
if ($buildFailures.Count -gt 0) {
    $failedScripts += @($buildFailures)
    # Keep the diagnostics report complete: add this script's failures to metadata.scriptFailures.
    if ($diag) {
        try {
            $diag.metadata.scriptFailures = @($failedScripts)
            $diagJson = ($diag | ConvertTo-Json -Depth 20) -replace "`r`n", "`n"
            [System.IO.File]::WriteAllText($diagPath, $diagJson + "`n", [System.Text.UTF8Encoding]::new($false))
        }
        catch { Write-Warning "Could not add the build's generator failures to diagnostics-report.json: $($_.Exception.Message)" }
    }
}
if ($failedScripts.Count -gt 0) {
    foreach ($f in $failedScripts) { Write-Warning ("Generator failed: {0} ({1})" -f $f.script, (([string]$f.error) -split "`n")[0]) }
    Write-Error "$($failedScripts.Count) generator(s) failed; the output is incomplete (exit 1)." -ErrorAction Continue
    exit 1
}

$gatePassed = ($vr.status -eq 'pass') -or ((-not $StrictValidation) -and $vr.status -eq 'pass-with-weak-coverage')
if (-not $gatePassed) {
    if ($AllowGateFail) {
        Write-Warning "Gate status is '$($vr.status)'; continuing because -AllowGateFail was given."
        exit 0
    }
    Write-Warning "Gate status is '$($vr.status)'. The docs were written but did not pass the gate (exit 2)."
    exit 2
}
exit 0
