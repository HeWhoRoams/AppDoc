#requires -Version 7.2
#
# generate-external-calls.ps1
#
# Purpose: Populate docs/extcalls.md (+ docs/extcalls.evidence.json) with the
#          GENERIC, framework-agnostic OUTBOUND-HTTP register for NON-ASP targets
#          (Node/TS, Python, Java, C#). It is the external-call analog of
#          generate-api-inventory.ps1 + AppDoc.ApiInventory.Extractor.psm1:
#          a generic extractor that scans *.ts/*.js/*.cs/*.py/*.java and emits
#          real, grep-verifiable outbound HTTP call sites.
#
#          It emits the SAME "## HTTP/XML Endpoints" table the classic-ASP
#          external-call register writes (| ID | Endpoint/URL | Mechanism |
#          Source file:line | Data/behavior | Status |) so the unified-master
#          composer's section 9.4 picks it up UNCHANGED (the composer is already
#          framework-agnostic: it reads docs/extcalls.md and renders the rows it
#          finds, falling back to the honest NDA note only when there are none).
#
#          OWNERSHIP / NO-CLOBBER (mirrors generate-api-inventory.ps1 +
#          generate-classic-asp-endpoints.ps1):
#            * This generic generator is the PRIMARY owner of extcalls.md, exactly as
#              generate-api-inventory.ps1 is the primary owner of api-inventory.md:
#              it runs on EVERY framework and always writes the artifact from the
#              generic extractor (which reads *.ts/*.js/*.cs/*.py/*.java). On a
#              classic-ASP target it finds 0 C#/TS/Python/Java sources, so it writes
#              the honest "no outbound calls detected" register (no fabricated rows).
#            * The classic-ASP external-call register (generate-classic-asp-extcalls.ps1)
#              runs LATER and is the SECONDARY owner: it carries the same no-clobber
#              guards as generate-classic-asp-endpoints.ps1 (yield when a prior owner
#              populated the shared artifact and classic-ASP source is absent), and on
#              a real classic-ASP target it overwrites the generic register with the
#              ServerXMLHTTP/FreeThreadedDOMDocument/COM/UNC rows. The two never fight:
#              one always writes, the other only overwrites when it truly owns it.
#
#          HONESTY: if no outbound call is detectable, extcalls.md is written
#          WITHOUT the "HTTP/XML Endpoints" table (an honest "no outbound calls
#          detected" note), so the composer's section 9.4 renders the honest NDA
#          row for that framework rather than fabricated rows.
#
#          DETERMINISTIC: no LLM, no network, no randomness. Records are deduped
#          and sorted; only the Provenance timestamp may differ between runs.
#
#          REDACTION: any real secret in a URL (token/apikey/password/userinfo)
#          is redacted to [REDACTED] before output (defense-in-depth).
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

$ErrorActionPreference = "Stop"

$extractorModule = Join-Path $PSScriptRoot "modules\AppDoc.ExternalCall.Extractor.psm1"
if (-not (Test-Path $extractorModule)) { Write-Error "Required module not found: $extractorModule"; exit 1 }
Import-Module $extractorModule -Force -ErrorAction Stop
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }
if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$outputPath   = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "extcalls.md"
$evidencePath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "extcalls.evidence.json"

Write-Host "🌐 Generating generic external-call register (outbound HTTP for non-ASP frameworks)..." -ForegroundColor Cyan

# NOTE: this generator is the PRIMARY owner of extcalls.md (mirrors
# generate-api-inventory.ps1): it ALWAYS writes the artifact. On a classic-ASP
# target the generic extractor finds 0 C#/TS/Python/Java sources, so it writes the
# honest "no outbound calls detected" register; the classic-ASP register
# (generate-classic-asp-extcalls.ps1) runs later and overwrites it with the real
# ServerXMLHTTP/COM/UNC rows (it owns the artifact when classic-ASP source is present).
# No yield here — see generate-classic-asp-extcalls.ps1 for the secondary-owner guards.

# --- Run the generic extractor -------------------------------------------------
$data = Get-AppDocExternalCallData -RootPath $RootPath
$records = @($data.records)

Write-Host "  Scanned $($data.scannedFileCount) source files (*.ts/*.js/*.cs/*.py/*.java); found $($records.Count) outbound HTTP call site(s)." -ForegroundColor Gray

# --- Build the HTTP/XML endpoint rows (same shape as the classic-ASP register) --
$endpointRows = New-Object System.Collections.Generic.List[object]
$evidence = New-Object System.Collections.Generic.List[object]
$eIdx = 1
foreach ($r in $records) {
    $id = "HTTP-$($eIdx.ToString('00'))"
    $evidenceCell = (Md-Back $r.file) + " line " + $r.line
    # Data/behavior: the epistemic tag for the URL (Literal / Inferred / Relative).
    $behavior = "Outbound HTTP call site; URL " + $r.urlKind
    $endpointRows.Add([pscustomobject]@{
        id = $id
        endpoint = (Sanitize-AppDocExternalCallUrl -t ([string]$r.endpoint))
        mechanism = (Sanitize-AppDocExternalCallUrl -t ([string]$r.mechanism))
        evidence = $evidenceCell
        behavior = $behavior
        status = "Verified"
        method = [string]$r.method
        file = [string]$r.file
        line = [int]$r.line
        urlKind = [string]$r.urlKind
        sourceType = "regex"
    })
    $evidence.Add([ordered]@{
        kind = "http-endpoint"
        id = $id
        endpoint = (Sanitize-AppDocExternalCallUrl -t ([string]$r.endpoint))
        mechanism = (Sanitize-AppDocExternalCallUrl -t ([string]$r.mechanism))
        method = [string]$r.method
        evidence = $evidenceCell
        behavior = $behavior
        status = "Verified"
        file = [string]$r.file
        line = [int]$r.line
        urlKind = [string]$r.urlKind
        sourceType = "regex"
    })
    $eIdx++
}

$generatedLine = "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$generatedIso  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# External Call Register"); $lines.Add(""); $lines.Add($generatedLine); $lines.Add("")
$lines.Add("## Summary"); $lines.Add("")
if ($endpointRows.Count -gt 0) {
    $summaryText = "This artifact lists the outbound HTTP call sites actually present in the source, extracted by the generic framework-agnostic extractor. Each row is an outbound HTTP call site verified against the source at the cited file:line. The **Mechanism** is the calling API (e.g. ``fetch()``, ``requests.put``, ``restTemplate.postForObject``, ``client.PostAsync``); the **Data/behavior** carries the epistemic tag for the endpoint: ``Literal`` = a string-literal URL was captured, ``Inferred`` = the URL is derived from a variable/config (the base is cited when a real http(s):// literal is present in the same file; otherwise the URL is recorded as ``from <variable>`` and is NOT fabricated), ``Relative path`` = a relative path literal (base comes from client config). Any real secret in a URL is emitted as ``[REDACTED]``. Status ``Verified`` = the call site is present in the current source; runtime reachability of the target is Unknown."
}
else {
    $summaryText = "No outbound HTTP call sites were detected in this codebase by the generic extractor (fetch/axios/XMLHttpRequest/http(s).request/got for TS-JS; requests/httpx/urllib/aiohttp/http.client for Python; RestTemplate/WebClient/HttpClient/OkHttp for Java; HttpClient/WebClient/HttpWebRequest/RestClient for C#). Rows are never fabricated; section 9.4 of the master document therefore carries the honest not-detected note."
}
$lines.Add($summaryText); $lines.Add("")
$lines.Add("Totals: **$($endpointRows.Count)** outbound HTTP call site(s).")
$lines.Add("")

if ($endpointRows.Count -gt 0) {
    $lines.Add("## HTTP/XML Endpoints"); $lines.Add("")
    $lines.Add("Each row is an outbound HTTP call site verified against the source at the cited location. The **Mechanism** is the calling API; the **Data/behavior** carries the URL epistemic tag (`Literal` / `Inferred` / `Relative path`). Status `Verified` = call site present in source (runtime reachability is Unknown)."); $lines.Add("")
    $lines.Add("| ID | Endpoint/URL | Mechanism | Source file:line | Data/behavior | Status |")
    $lines.Add("|----|--------------|-----------|------------------|---------------|--------|")
    foreach ($er in $endpointRows) {
        $cells = @($er.id, (Md-Clean (Md-Back $er.endpoint)), (Md-Clean (Md-Back $er.mechanism)), (Md-Clean $er.evidence), (Md-Clean $er.behavior), $er.status)
        $lines.Add('| ' + ($cells -join ' | ') + ' |')
    }
    $lines.Add("")
}

$lines.Add("## Provenance"); $lines.Add("")
$lines.Add("- Generator Version: appdoc-run-all-generators/3.0.0"); $lines.Add("- Commit Hash: unknown")
$lines.Add("- Generated At: $generatedIso"); $lines.Add("- Profile: default"); $lines.Add("- Scope: .")
$lines.Add("- Confidence/Inference Flags: deterministic, evidence-backed, secrets redacted")

$md = ($lines -join "`n")
$md | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

# --- Flat evidence -------------------------------------------------------------
$evidence | ConvertTo-Json -Depth 14 | Out-File -FilePath $evidencePath -Encoding UTF8

# --- Canonical evidence (docs/evidence/extcalls.evidence.json) ------------------
$canonDir = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "evidence"
if (-not (Test-Path $canonDir)) { New-Item -ItemType Directory -Path $canonDir -Force | Out-Null }
$canonPath = Join-Path $canonDir "extcalls.evidence.json"
$recArr = @($evidence | ForEach-Object { $_ })
$canon = [ordered]@{
    artifact = "extcalls"
    generatedAt = $generatedIso
    recordCount = $recArr.Count
    records = $recArr
    metadata = @{
        generator = "generate-external-calls.ps1"
        httpEndpointCount = [int]$endpointRows.Count
        scannedFileCount = [int]$data.scannedFileCount
        httpEndpointSamples = @($endpointRows | Select-Object -First 5 | ForEach-Object { [string]$_.endpoint })
    }
    determinism = @{ mode = "deterministic" }
}
$canon | ConvertTo-Json -Depth 14 | Out-File -FilePath $canonPath -Encoding UTF8

Write-Host "✅ Generic external calls generated: $outputPath" -ForegroundColor Green
Write-Host "   Outbound HTTP call sites: $($endpointRows.Count)" -ForegroundColor Gray
Write-Host "   Evidence: $evidencePath" -ForegroundColor Gray
