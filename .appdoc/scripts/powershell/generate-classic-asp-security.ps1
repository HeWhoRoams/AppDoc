#requires -Version 7.2
#
# generate-classic-asp-security.ps1
#
# Purpose: Populate docs/security.md (and docs/security.evidence.json) from
#          CLASSIC ASP source. This is the SECURITY AND OPERATIONAL RISKS
#          artifact. It detects the REAL, grep-verifiable security findings
#          that exist in the current source:
#            (a) hardcoded-credential auth bypass (a literal username +
#                password comparison that sets Session("Authenticated") = 1),
#            (b) hardcoded API-key / Authorization-header literals,
#            (c) a per-user debug backdoor keyed on a specific Session
#                username that dumps raw SQL to the response,
#            (d) generated passwords rendered in the HTML response (a pwd OUT
#                parameter written to Response),
#            (e) On Error Resume Next sites (count + sample files) — reduces
#                diagnostic visibility,
#            (f) string-built SQL (SQL assembled by string concatenation,
#                FixSQL-style, not parameterized),
#            (g) ADO connection strings with embedded credentials (count only).
#
# REDACTION RULE (non-negotiable): every finding is documented with file:line,
# severity, and status, but a REAL secret value (password / API key / GID /
# credential) is NEVER printed — it is emitted as [REDACTED]. A target may declare an
# opaque-token pattern (config `opaqueTokenPattern`) for already-sanitized placeholders,
# which are referenced as-is.
#
# Deterministic: no LLM, no randomness, no network. Framework-gated: only runs
# when framework-detection.json reports Classic ASP or ASP.NET Web Forms.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

$ErrorActionPreference = "Stop"

# Optional per-target opaque-token convention (config `opaqueTokenPattern`): values
# matching it are already-sanitized placeholders and are kept verbatim. Default: none,
# so every secret value is redacted.
$opaqueTokenPattern = ''
$cfgModule = Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Config.psm1'
if (Test-Path $cfgModule) {
    Import-Module $cfgModule -Force -ErrorAction Stop
    $appDocCfg = Get-AppDocConfig -RootPath $RootPath
    if ($appDocCfg -and $appDocCfg.values.opaqueTokenPattern) { $opaqueTokenPattern = [string]$appDocCfg.values.opaqueTokenPattern }
}
$opaqueNote = if ($opaqueTokenPattern) { " Values matching the target's opaque-token pattern (``$opaqueTokenPattern``) are sanitized placeholders and are referenced as-is." } else { '' }
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }
function Write-NotApplicablePlaceholder {
    param([string]$OutputPath, [string]$Title)
    $dir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $body = "# $Title`n`n**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n`n## Summary`n`nNot applicable for this framework. This artifact is produced only for Classic ASP / ASP.NET Web Forms codebases; the detected framework has no matching classic-ASP signal, so no content was extracted.`n`n---"
    $body | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline
}
# Return a value wrapped in literal markdown backticks (for inline code spans).
# Redact: any non-empty secret value becomes [REDACTED]; values matching the target's
# configured opaque-token pattern (if any) pass through unchanged.
function Redact-Value {
    param([string]$v)
    $t = ([string]$v).Trim()
    if ([string]::IsNullOrWhiteSpace($t)) { return "[REDACTED]" }
    if ($opaqueTokenPattern -and $t -match $opaqueTokenPattern) { return $t }
    return "[REDACTED]"
}

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$outputPath  = Join-Path $RootPath "docs\security.md"
$evidencePath = Join-Path $RootPath "docs\security.evidence.json"

Write-Host "🔒 Generating Classic ASP security findings..." -ForegroundColor Cyan
if (-not (Get-ClassicAspFrameworkApplicable -RootPath $RootPath)) {
    Write-Host "  Framework not Classic ASP - writing placeholder." -ForegroundColor Yellow
    Write-NotApplicablePlaceholder -OutputPath $outputPath -Title "Security and Operational Risks"
    @() | ConvertTo-Json -Depth 5 | Out-File -FilePath $evidencePath -Encoding UTF8
    exit 0
}

$rootPrefix = $RootPath.TrimEnd('\', '/')
$aspFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp" -File -ErrorAction SilentlyContinue | Sort-Object FullName)
$incFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.inc" -File -ErrorAction SilentlyContinue | Sort-Object FullName)

$findings = New-Object System.Collections.Generic.List[object]
$onErrorFiles = New-Object System.Collections.Generic.List[string]
$onErrorCount = 0
$stringSqlFiles = New-Object System.Collections.Generic.List[string]
$adoCredCount = 0
$adoCredFiles = New-Object System.Collections.Generic.List[string]

function Add-Finding {
    param([string]$Id, [string]$Finding, [string]$Evidence, [string]$Severity, [string]$Secret, [string]$Status)
    $script:findings.Add([ordered]@{ id=$Id; finding=$Finding; evidence=$Evidence; severity=$Severity; secret=$Secret; status=$Status })
}

foreach ($list in @($incFiles, $aspFiles)) {
    foreach ($f in $list) {
        $rel = Get-RelativePath -FullPath $f.FullName -Base $rootPrefix
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if ($null -eq $content) { continue }
        $lines = @($content -split "`r?`n")

        # ---- (a) hardcoded-credential auth bypass -----------------------------
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $L = $lines[$i]
            if ($L -notmatch '(?i)USERPASSWORD') { continue }
            if ($L -match '(?i)USERPASSWORD"\)\s*=\s*"([A-Za-z0-9._-]+)"') {
                $userLiteral = ""
                if ($L -match '(?i)USERNAME"\)\s*=\s*"([A-Za-z0-9._-]+)"') { $userLiteral = $Matches[1] }
                $authSet = $false; $setLine = -1
                for ($j = $i; $j -lt [Math]::Min($i + 5, $lines.Count); $j++) {
                    if ($lines[$j] -match '(?i)Session\("Authenticated"\)\s*=\s*1') { $authSet = $true; $setLine = $j + 1; break }
                }
                if ($authSet) {
                    $idNum = ($findings.Count + 1)
                    $fid = "SEC-$( $idNum.ToString('000') )"
                    $ev = (Md-Back $rel) + (" line {0} (auth set line {1})" -f ($i + 1), $setLine)
                    Add-Finding -Id $fid -Finding "A hardcoded guest login bypasses `SimpleVerify` — a fixed username/password pair authenticates before the normal verify path." -Evidence $ev -Severity "Critical" -Secret "username=$userLiteral; password=[REDACTED]" -Status "Verified"
                }
            }
        }

        # ---- (b) hardcoded API key / Authorization header literal --------------
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $L = $lines[$i]
            if ($L -notmatch '(?i)setRequestHeader\s+"Authorization"') { continue }
            $idNum = ($findings.Count + 1)
            $fid = "SEC-$( $idNum.ToString('000') )"
            $ev = (Md-Back $rel) + " line " + ($i + 1)
            Add-Finding -Id $fid -Finding "A hardcoded authorization header is present (a credential is sent on an outbound HTTP request)." -Evidence $ev -Severity "Critical" -Secret "apikey=[REDACTED]" -Status "Verified"
        }

        # ---- (c) per-user debug backdoor that dumps raw SQL --------------------
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $L = $lines[$i]
            if ($L -match '(?i)Session\("Username"\)\s*=\s*"([A-Za-z0-9._-]+)"') {
                $dump = $false
                for ($j = $i; $j -lt [Math]::Min($i + 5, $lines.Count); $j++) {
                    if ($lines[$j] -match '(?i)response\.write\s+SQLState') { $dump = $true; break }
                }
                if ($dump) {
                    $idNum = ($findings.Count + 1)
                    $fid = "SEC-$( $idNum.ToString('000') )"
                    $ev = (Md-Back $rel) + " line " + ($i + 1)
                    Add-Finding -Id $fid -Finding "A per-user debug backdoor dumps raw SQL to the response for one specific operator Global ID." -Evidence $ev -Severity "High" -Secret "operatorGid=[REDACTED]" -Status "Verified"
                }
            }
        }

        # ---- (d) generated password rendered in the HTML response --------------
        $hasPwdOut = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '(?i)CreateParameter\("@?[A-Za-z0-9_]*pwd",\s*[A-Za-z_0-9]*,\s*adParamOutput') { $hasPwdOut = $true }
        }
        $rendersPwd = $false
        for ($i = 0; $i -lt $lines.Count; $i++) {
            if ($lines[$i] -match '(?i)(Password:|password is:|new password is:)' -and $lines[$i] -match 'response\.write') { $rendersPwd = $true; break }
            if ($lines[$i] -match '(?i)response\.write\s+"[^"]*(Password|password)' -and $lines[$i] -match 'cmd\(') { $rendersPwd = $true; break }
        }
        if ($hasPwdOut -and $rendersPwd) {
            $idNum = ($findings.Count + 1)
            $fid = "SEC-$( $idNum.ToString('000') )"
            Add-Finding -Id $fid -Finding "Generated passwords are rendered in the HTML response (a password OUT parameter is written to the page)." -Evidence (Md-Back $rel) -Severity "High" -Secret "generatedPassword=[REDACTED]" -Status "Verified"
        }

        # ---- (e) On Error Resume Next ------------------------------------------
        $oeCount = ([regex]::Matches($content, '(?i)\bOn\s+Error\s+Resume\s+Next\b')).Count
        if ($oeCount -gt 0) {
            $onErrorCount += $oeCount
            $onErrorFiles.Add($rel)
        }

        # ---- (f) string-built SQL (concatenation into a SQL string) ------------
        $sqlBuilt = ([regex]::Matches($content, '(?is)\b(Open|CommandText)\b[^;\r\n]*\s&\s')).Count
        $sqlBuilt = $sqlBuilt + ([regex]::Matches($content, '(?i)SQLState\s*=\s*".*&')).Count
        if ($sqlBuilt -gt 0) { $stringSqlFiles.Add($rel) }

        # ---- (g) ADO connection strings with embedded credentials --------------
        foreach ($L in $lines) {
            if ($L -match '(?i)\b(Provider|Data\s+Source|Initial\s+Catalog|Server)\s*=' -and $L -match '(?i)\b(Password|User\s+ID|UID|PWD)\s*=') {
                $adoCredCount++
                if (-not ($adoCredFiles -contains $rel)) { $adoCredFiles.Add($rel) }
            }
        }
    }
}

# ---- dedup: collapse findings that differ only by scratch/copy/old/test files or line ---
# A "scratch" file is a copy/old/test/bak file (per iteration spec). For each finding
# TYPE (finding text) we keep ONE canonical row per distinct PRIMARY (non-scratch) FILE:
#   - the first primary file:line is the canonical citation;
#   - any ADDITIONAL primary occurrences of the same finding in the SAME file are folded in
#     as "(+N more instance(s) in this file)" rather than separate rows;
#   - the scratch copies are NOT emitted as separate rows; they are noted as "also present
#     in N copy/test file(s)".
# Distinct primary files each keep their own row (e.g. the same API-key literal in four
# different status/feeds files is four real exposures, not a scratch dup).
function Is-ScratchFile {
    param([string]$Path)
    $name = Split-Path $Path -Leaf
    return ($name -match '(?i).*_copy.*|.*copy_.*|.*_old.*|.*_test.*|^testing.*|.*bak.*')
}
# group findings by type (finding text), preserving first-seen order
$byType = New-Object System.Collections.Generic.List[object]
$groupSeen = @{}
foreach ($fnd in $findings) {
    if (-not $groupSeen.ContainsKey($fnd.finding)) {
        $groupSeen[$fnd.finding] = $true
        $byType.Add([pscustomobject]@{ finding = $fnd.finding; items = New-Object System.Collections.Generic.List[object] })
    }
    foreach ($g in $byType) { if ($g.finding -eq $fnd.finding) { $g.items.Add($fnd); break } }
}
$findings = New-Object System.Collections.Generic.List[object]
foreach ($grp in $byType) {
    $primaryItems = @($grp.items | Where-Object { -not (Is-ScratchFile ([string]$_.evidence)) })
    $scratchItems = @($grp.items | Where-Object { Is-ScratchFile ([string]$_.evidence) })
    $scratchNote = ''
    if ($scratchItems.Count -gt 0) { $scratchNote = " [also present in $($scratchItems.Count) copy/test file(s)]" }
    # one row per distinct primary FILE (stable order)
    $seenFile = @{}
    foreach ($it in $primaryItems) {
        $ev0 = [string]$it.evidence
        $mfile = [regex]::Match($ev0, '`([^`]+)`')
        $fname = if ($mfile.Success) { $mfile.Groups[1].Value } else { $ev0 }
        if ($seenFile.ContainsKey($fname)) { continue }
        $seenFile[$fname] = $true
        # count ALL primary items of this finding that live in this same file
        $sameFile = @($primaryItems | ForEach-Object {
            $mm = [regex]::Match([string]$_.evidence, '`([^`]+)`')
            $ff = if ($mm.Success) { $mm.Groups[1].Value } else { [string]$_.evidence }
            if ($ff -eq $fname) { $true } else { $null }
        })
        $total = @($sameFile | Where-Object { $_ }).Count
        $instNote = if ($total -gt 1) { " (+$($total - 1) more instance(s) in this file)" } else { '' }
        $findings.Add([ordered]@{ id = $it.id; finding = $it.finding; evidence = ($ev0 + $instNote + $scratchNote); severity = $it.severity; secret = $it.secret; status = $it.status })
    }
    # if a finding type appears ONLY in scratch files, keep the first scratch row (with note)
    if ($seenFile.Count -eq 0 -and $scratchItems.Count -gt 0) {
        $it = $scratchItems[0]
        $findings.Add([ordered]@{ id = $it.id; finding = $it.finding; evidence = ([string]$it.evidence + " [also present in $($scratchItems.Count) copy/test file(s); no primary file found]"); severity = $it.severity; secret = $it.secret; status = $it.status })
    }
}
# re-assign stable IDs in order (SEC-001, SEC-002, ...)
$secIdx = 1
foreach ($f in $findings) { $f.id = "SEC-$($secIdx.ToString('000'))"; $secIdx++ }

$onErrorFileCount = $onErrorFiles.Count
$stringSqlFileCount = @($stringSqlFiles | Select-Object -Unique).Count

# ---- Render markdown ------------------------------------------------------------
$generatedLine = "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$generatedIso = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$critCount = @($findings | Where-Object { $_.severity -eq "Critical" }).Count
$highCount = @($findings | Where-Object { $_.severity -eq "High" }).Count
$medCount  = @($findings | Where-Object { $_.severity -eq "Medium" }).Count
$summaryText = "This artifact lists the security findings actually present in the classic-ASP source, each with its file:line evidence, severity, and epistemic status. Every REAL secret value (password, API key, credential) is **redacted** and emitted as ``[REDACTED]``.$opaqueNote Severity reflects the blast radius of the exposure, not runtime reachability (which is Unknown)."

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Security and Operational Risks"); $lines.Add(""); $lines.Add($generatedLine); $lines.Add("")
$lines.Add("## Summary"); $lines.Add(""); $lines.Add($summaryText); $lines.Add("")
$totalsLine = "Totals: **{0}** Critical, **{1}** High, **{2}** Medium findings; plus {3} files with `On Error Resume Next`, {4} files with string-built SQL, and {5} ADO connection-string lines carrying embedded credentials (values redacted)." -f $critCount, $highCount, $medCount, $onErrorFileCount, $stringSqlFileCount, $adoCredCount
$lines.Add($totalsLine); $lines.Add("")
$lines.Add("## Contents"); $lines.Add("")
$lines.Add("- [Security Findings](#security-findings) — verified, grep-verifiable findings with redacted secrets")
$lines.Add("- [Operational Unknowns That Must Not Be Treated As Controls](#operational-unknowns-that-must-not-be-treated-as-controls)")
$lines.Add("- [Evidence Traceability](#evidence-traceability)")
$lines.Add("")

$lines.Add("## Security Findings"); $lines.Add("")
$lines.Add("Each row is a finding verified against the source at the cited location. The **Secret Value** column shows only the redacted placeholder — the actual value is deliberately omitted. Status `Verified` means the pattern is present in the current source (not that it is reachable in production; that is Unknown).")
$lines.Add("")
$lines.Add("| ID | Finding | Evidence (file:line) | Severity | Secret Value (redacted) | Status |")
$lines.Add("|------|---------|----------------------|----------|-------------------------|--------|")
foreach ($fnd in $findings) {
    $row = "| {0} | {1} | {2} | {3} | {4} | {5} |" -f $fnd.id, (Md-Clean $fnd.finding), (Md-Clean $fnd.evidence), $fnd.severity, (Md-Clean $fnd.secret), $fnd.status
    $lines.Add($row)
}
if ($findings.Count -eq 0) { $lines.Add("| — | none detected | — | — | — | Unknown |") }
$lines.Add("")
$lines.Add("## Operational Unknowns That Must Not Be Treated As Controls"); $lines.Add("")
$lines.Add("The following runtime security properties are **NOT established by the supplied source repository**. Their absence from the code does not mean they are absent in production, and they must not be read as security controls (or the lack thereof). Status for each is `Unknown`."); $lines.Add("")
$lines.Add("| Runtime security property | Established by source? | Status |")
$lines.Add("|---------------------------|------------------------|--------|")
$unknowns = @(
    "TLS / HTTPS enforcement",
    "Multi-factor authentication (MFA)",
    "CSRF (cross-site request forgery) defenses",
    "Secure / HttpOnly cookie flags",
    "Password storage scheme (hashing / salting)",
    "Centralized audit-log integrity",
    "Alerting on failed authentication or privileged action",
    "Credential rotation / production secret management",
    "Backup / recovery and vulnerability-scanning posture"
)
foreach ($u in $unknowns) {
    $lines.Add("| {0} | No — not derivable from source | Unknown |" -f (Md-Clean $u))
}
$lines.Add("")
$lines.Add("## Evidence Traceability"); $lines.Add("")
$lines.Add("| Field | Value |"); $lines.Add("|------|-------|")
$lines.Add("| Evidence Artifact | docs/security.evidence.json |")
$lines.Add("| Record Count | {0} |" -f $findings.Count)
$lines.Add("| Generator | generate-classic-asp-security.ps1 |")
$lines.Add("| Grounding Mode | Deterministic pattern detection (grep-verifiable) |")
$lines.Add("| Redaction | All real secret values emitted as [REDACTED] |")
$lines.Add("")
$lines.Add("---"); $lines.Add("")
$lines.Add("## Provenance"); $lines.Add("")
$lines.Add("- Generator Version: appdoc-run-all-generators/3.0.0"); $lines.Add("- Commit Hash: unknown")
$lines.Add("- Generated At: $generatedIso"); $lines.Add("- Profile: default"); $lines.Add("- Scope: .")
$lines.Add("- Confidence/Inference Flags: deterministic, evidence-backed, secrets redacted")
$md = ($lines -join "`n")
$md | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

# ---- Flat evidence --------------------------------------------------------------
$evidence = New-Object System.Collections.Generic.List[object]
foreach ($fnd in $findings) {
    $evidence.Add([ordered]@{ kind="finding"; id=$fnd.id; finding=$fnd.finding; evidence=$fnd.evidence; severity=$fnd.severity; secret=$fnd.secret; status=$fnd.status })
}
$evidence.Add([ordered]@{ kind="operational-unknown"; finding="Runtime security properties not established by source"; evidence="—"; severity="Unknown"; secret="—"; status="Unknown" })
$evidence | ConvertTo-Json -Depth 14 | Out-File -FilePath $evidencePath -Encoding UTF8

# ---- Canonical evidence (docs/evidence/security.evidence.json) ------------------
$canonDir = Join-Path $RootPath "docs\evidence"
if (-not (Test-Path $canonDir)) { New-Item -ItemType Directory -Path $canonDir -Force | Out-Null }
$canonPath = Join-Path $canonDir "security.evidence.json"
$recArr = @($evidence | ForEach-Object { $_ })
$canon = [ordered]@{
    artifact = "security"
    generatedAt = $generatedIso
    recordCount = $recArr.Count
    records = $recArr
    metadata = @{
        requiredSections = @("Summary", "Security Findings")
        requiredEvidenceKeys = @("findings")
        generator = "generate-classic-asp-security.ps1"
        criticalCount = [int]$critCount
        highCount = [int]$highCount
        mediumCount = [int]$medCount
        onerrorResumeFiles = [int]$onErrorFileCount
        stringSqlFiles = [int]$stringSqlFileCount
        adoCredConnLines = [int]$adoCredCount
        onerrorSamples = @($onErrorFiles | Select-Object -First 5)
    }
    determinism = @{ mode = "deterministic" }
}
$canon | ConvertTo-Json -Depth 14 | Out-File -FilePath $canonPath -Encoding UTF8

Write-Host "✅ Classic ASP security findings generated: $outputPath" -ForegroundColor Green
Write-Host "   Findings: $($findings.Count) (Critical $critCount / High $highCount / Medium $medCount) | On Error files: $onErrorFileCount | String-SQL files: $stringSqlFileCount | ADO cred lines: $adoCredCount" -ForegroundColor Gray
Write-Host "   Evidence: $evidencePath" -ForegroundColor Gray
