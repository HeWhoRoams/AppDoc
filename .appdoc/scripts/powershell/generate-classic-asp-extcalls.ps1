#requires -Version 7.2
#
# generate-classic-asp-extcalls.ps1
#
# Purpose: Populate docs/extcalls.md (and docs/extcalls.evidence.json) from
#          CLASSIC ASP source. This is the EXTERNAL CALL REGISTER's HTTP/XML
#          boundary + the Email/COM/file-system boundaries. It detects the
#          REAL, grep-verifiable external-call sites that exist in the source:
#            (a) HTTP / XML / cross-application endpoints: an outbound URL
#                literal + the XML-HTTP mechanism that issues it
#                (Msxml2.ServerXMLHTTP.6.0 / MSXML2.FreeThreadedDOMDocument.Load
#                / plain URL link-redirect), cited at file:line.
#            (b) stored-proc EMAIL calls: EXEC ... send_mail @address,@Subject,@MSG.
#            (c) distinct COM objects instantiated via Server.CreateObject(...)
#                / CreateObject(...) (object name + occurrence count + sample file).
#            (d) file-system / UNC boundaries: literal \\server\share paths
#                (counted and cited by file; the paths themselves are not printed).
#
# The ADO boundary (ADODB.Connection/Command/Recordset) is referenced as a
# boundary CLASS (the DB boundary; the full register is in section 9.1) rather
# than being re-listed here.
#
# REDACTION RULE (non-negotiable): a REAL secret value (API key / Authorization
# header literal / embedded credential) is NEVER printed. It is emitted as
# [REDACTED]. URLs are shown as-is (they are destinations, not credentials).
#
# Deterministic: no LLM, no randomness, no network. Framework-gated: only runs
# when framework-detection.json reports Classic ASP or ASP.NET Web Forms.
# Scratch/copy/old/test/bak files are excluded by BASENAME.
#

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

$ErrorActionPreference = "Stop"
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }
function Write-NotApplicablePlaceholder {
    param([string]$OutputPath, [string]$Title)
    $dir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $body = "# $Title`n`n**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n`n## Summary`n`nNot applicable for this framework. This artifact is produced only for Classic ASP / ASP.NET Web Forms codebases; the detected framework has no matching classic-ASP external-call signal, so no content was extracted.`n`n---"
    $body | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline
}
# Join-Row: build a markdown table row from cleaned cells (no -f formatting).
function Join-Row {
    param([string[]]$Cells)
    $c = @()
    foreach ($x in $Cells) { $c += [string]$x }
    return ('| ' + ($c -join ' | ') + ' |')
}

# Scratch / copy / old / test / bak files are excluded by BASENAME.
function Test-ScratchFile {
    param([string]$Path)
    $name = Split-Path $Path -Leaf
    return ($name -match '(?i).*_copy.*|.*copy_.*|.*_old.*|.*_test.*|^testing.*|.*bak.*')
}

# Sanitize a string before it is written: redact any real Authorization/Apikey
# header value and any bearer/token credential.
# Defense-in-depth: even if a real value is captured, it is redacted here.
function ConvertTo-SafeText {
    param([string]$t)
    if ($null -eq $t) { return '' }
    # Apikey / Authorization / Bearer header literals -> redact the value.
    $t = [regex]::Replace($t, '(?i)(Apikey|apikey)\s+[A-Za-z0-9][A-Za-z0-9\-_.]{6,}', '$1 [REDACTED]')
    $t = [regex]::Replace($t, '(?i)(Authorization"\s*,\s*")[^"]+(")', '$1[REDACTED]$2')
    $t = [regex]::Replace($t, '(?i)(Bearer|Token|Password|Pwd)\s*[:=]\s*[A-Za-z0-9][A-Za-z0-9\-_.]{5,}', '$1: [REDACTED]')
    return $t
}

# --- Shared-artifact ownership guard (mirrors generate-classic-asp-endpoints.ps1) --
# The generic non-ASP external-call register (generate-external-calls.ps1, which runs
# EARLIER in the pipeline) writes the SAME shared artifact (docs/extcalls.md) for
# non-classic-ASP frameworks. Ownership of the shared artifact is decided by artifact
# PROVENANCE, not the framework label: if docs/extcalls.md exists and is NOT a classic-
# ASP "not applicable" placeholder, a prior owner (the generic extractor) populated it
# and this generator must YIELD (not clobber). This is the external-call analog of the
# api-inventory no-clobber guard.
# Classic-ASP SOURCE PRESENCE: the real signal this generator OWNS extcalls.md is the
# presence of TRUE classic-ASP source (*.asp / *.inc), not the framework label and not
# *.aspx. This mirrors generate-classic-asp-endpoints.ps1's Get-ClassicAspSourceFileCount
# EXACTLY (which counts only *.asp/*.inc, not *.aspx). Web Forms is a C# framework that
# is "framework-applicable" and ships *.aspx + *.cs code-behind files: on such a target
# there are 0 true classic-ASP (*.asp/*.inc) files, so the generic extractor (which reads
# *.cs) is the real owner of extcalls.md and this generator must yield. We apply the same
# scratch basename exclusions this generator already uses.
function Get-ClassicAspSourceFileCount {
    param([string]$RootPath)
    $files = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp","*.inc" -File -ErrorAction SilentlyContinue |
        Where-Object { -not (Test-ScratchFile $_.FullName) })
    return $files.Count
}

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$outputPath   = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "extcalls.md"
$evidencePath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "extcalls.evidence.json"

Write-Host "🌐 Generating Classic ASP external-call register (HTTP/XML + Email/COM/file boundaries)..." -ForegroundColor Cyan
if (-not (Get-ClassicAspFrameworkApplicable -RootPath $RootPath)) {
    # --- Non-ASP framework (Node / Core / Flask / Django / Spring / ...) --------
    # The generic extractor (generate-external-calls.ps1) ran EARLIER and already
    # wrote the shared artifact for this framework. If docs/extcalls.md exists and is
    # NOT this generator's own "not applicable" placeholder, a prior owner populated
    # it and we must YIELD (not clobber). Only when no prior owner artifact exists do
    # we write our own placeholder (harmless — nothing to overwrite).
    $artifactExists    = Test-Path $outputPath
    $isPriorOwnerOwned = $artifactExists -and (-not (Test-AppDocArtifactIsClassicAspPlaceholder -Path $outputPath))
    if ($isPriorOwnerOwned) {
        Write-Host "  Framework not Classic ASP and a prior (generic) external-call register exists; yielding (not clobbering)." -ForegroundColor Yellow
        Write-Host "✅ extcalls.md retained (non-ASP source-presence guard)." -ForegroundColor Green
        exit 0
    }
    Write-Host "  Framework not Classic ASP - writing placeholder." -ForegroundColor Yellow
    Write-NotApplicablePlaceholder -OutputPath $outputPath -Title "External Call Register"
    @() | ConvertTo-Json -Depth 5 | Out-File -FilePath $evidencePath -Encoding UTF8
    exit 0
}

# --- Classic-ASP source-presence guard ------------------------------------------
# Framework-applicable passes for BOTH 'Classic ASP' and 'ASP.NET Web Forms' (Web
# Forms is a C# framework). On a pure C# Web Forms target there are 0 *.asp/*.inc
# files, so this generator would find no ServerXMLHTTP/FreeThreadedDOMDocument sites
# and could CLOBBER the shared artifact the generic extractor (which reads *.cs)
# already populated. When classic-ASP source is absent we yield: leave a non-
# placeholder artifact (written by the generic path) intact; only write our own
# placeholder when no prior owner populated it.
$classicAspSourceCount = Get-ClassicAspSourceFileCount -RootPath $RootPath
if ($classicAspSourceCount -eq 0) {
    $artifactExists    = Test-Path $outputPath
    $isPriorOwnerOwned = $artifactExists -and (-not (Test-AppDocArtifactIsClassicAspPlaceholder -Path $outputPath))
    if ($isPriorOwnerOwned) {
        Write-Host "  No true classic-ASP source (*.asp/*.inc) found; yielding extcalls.md to the prior (generic) owner." -ForegroundColor Yellow
        Write-Host "✅ extcalls.md retained (classic-ASP source-presence guard)." -ForegroundColor Green
        exit 0
    }
    Write-Host "  No classic-ASP source found and no prior owner artifact - writing N-A placeholder." -ForegroundColor Yellow
    Write-NotApplicablePlaceholder -OutputPath $outputPath -Title "External Call Register"
    @() | ConvertTo-Json -Depth 5 | Out-File -FilePath $evidencePath -Encoding UTF8
    exit 0
}

$rootPrefix = $RootPath.TrimEnd('\', '/')
# Collect classic-ASP source files (asp/aspx/inc), EXCLUDING scratch by basename, sorted for determinism.
$allFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp","*.aspx","*.inc" -File -ErrorAction SilentlyContinue |
    Where-Object { -not (Test-ScratchFile $_.FullName) } |
    Sort-Object FullName)
# Scratch set (for the "also present in N copy/test file(s)" note), same scoping.
$allFilesInclScratch = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp","*.aspx","*.inc" -File -ErrorAction SilentlyContinue | Sort-Object FullName)

# Regexes
$quotedUrlRe  = [regex]'"(https?://[^"\s]+)"'
$serverXmlRe  = '(?i)ServerXMLHTTP'
$freeThreadRe = '(?i)FreeThreadedDOMDocument'
$msxmlRe      = '(?i)msxml2'
$authHeaderRe = '(?i)setRequestHeader\s*\(?\s*"Authorization"'
$apiKeyRe     = '(?i)Apikey\s+[A-Za-z0-9][A-Za-z0-9\-_.]{6,}'
$sendMailRe   = [regex]'(?i)\bsend_mail\b'
$createObjRe  = [regex]'(?i)CreateObject\s*\(?\s*"?([^",)\s]+)"?'
# A literal UNC path inside a string: "\\server\share..." (2+ backslashes, a host, a share).
$uncTokenRe   = [regex]'\\\\[A-Za-z0-9_.$-]+\\[A-Za-z0-9_.$-]+'

# ---- Accumulators -----------------------------------------------------------
$endpointHits = New-Object System.Collections.Generic.List[object]   # @{file; line; url; mech; behavior}
$sendMailHits = New-Object System.Collections.Generic.List[object]   # @{file; line; snippet}
$comCounts    = @{}   # normalized object name -> count (primary files only)
$comSample    = @{}   # normalized object name -> first primary file
$adoCount     = 0
$adoFiles     = New-Object System.Collections.Generic.List[string]
$uncCount     = 0
$uncFiles     = New-Object System.Collections.Generic.List[string]
$apiKeyFiles  = New-Object System.Collections.Generic.List[string]

foreach ($f in $allFiles) {
    $rel = Get-RelativePath -FullPath $f.FullName -Base $rootPrefix
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) { continue }
    $lines = @($content -split "`r?`n")

    $hasServerXml = ($content -match $serverXmlRe)
    $hasFreeThread = ($content -match $freeThreadRe)
    $hasMsxml = ($content -match $msxmlRe)
    $hasAuthHeader = ($content -match $authHeaderRe)
    $hasApiKey = ($content -match $apiKeyRe)
    # The HTTP/XML endpoint register is scoped to files that ISSUE an outbound
    # request via a real XML-HTTP object (ServerXMLHTTP / FreeThreadedDOMDocument).
    # This excludes files that merely reference the MSXML2 namespace or that carry
    # hundreds of asset/CDN URL literals (which are not external-call boundaries).
    $isOutboundFile = ($hasServerXml -or $hasFreeThread)

    # ---- (a) HTTP / XML endpoints -------------------------------------------
    if ($isOutboundFile) {
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $L = $lines[$i]
        if ($L -notmatch 'https?://') { continue }
        $ms = $quotedUrlRe.Matches($L)
        if ($ms.Count -eq 0) { continue }
        foreach ($m in $ms) {
            $url = $m.Groups[1].Value
            # mechanism from the file-level XML-HTTP object
            if ($hasFreeThread) { $mech = 'MSXML2.FreeThreadedDOMDocument.Load' }
            else { $mech = 'Msxml2.ServerXMLHTTP.6.0' }
            # behavior from observed tokens (bounded, not fabricated)
            $beh = ''
            if ($L -match '(?i)\.load\b') { $beh = 'loads remote XML document' }
            elseif ($L -match '(?i)\.open\b') { $beh = 'outbound HTTP request' }
            else { $beh = 'outbound HTTP/XML request (call site)' }
            if ($hasAuthHeader -or $hasApiKey) { $beh += '; sends hardcoded Authorization header (Apikey [REDACTED])' }
            $endpointHits.Add([pscustomobject]@{ file=$rel; line=($i + 1); url=$url; mech=$mech; behavior=$beh })
        }
    }
    }

    # ---- (b) stored-proc email (send_mail) -----------------------------------
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($sendMailRe.IsMatch($lines[$i])) {
            $snippet = ([string]$lines[$i]).Trim()
            if ($snippet.Length -gt 90) { $snippet = $snippet.Substring(0, 90) + '…' }
            $sendMailHits.Add([pscustomobject]@{ file=$rel; line=($i + 1); snippet=$snippet })
        }
    }

    # ---- (c) COM objects -----------------------------------------------------
    foreach ($m in $createObjRe.Matches($content)) {
        $obj = ([string]$m.Groups[1].Value).Trim()
        if ([string]::IsNullOrWhiteSpace($obj)) { continue }
        $key = $obj.ToLowerInvariant()
        if (-not $comCounts.ContainsKey($key)) { $comCounts[$key] = 0; $comSample[$key] = $rel; $comCounts[$key] = 0 }
        $comCounts[$key]++
        # keep ADO family tracked for the boundary-class row
        if ($key -match '^adodb\.(connection|command|recordset)$') {
            $adoCount++
            if (-not ($adoFiles -contains $rel)) { $adoFiles.Add($rel) }
        }
    }
    if ($hasApiKey) { if (-not ($apiKeyFiles -contains $rel)) { $apiKeyFiles.Add($rel) } }

    # ---- (d) file-system / UNC ----------------------------------------------
    $uncHits = $uncTokenRe.Matches($content).Count
    if ($uncHits -gt 0) {
        $uncCount += $uncHits
        if (-not ($uncFiles -contains $rel)) { $uncFiles.Add($rel) }
    }
}

# ---- scratch "also present" note for endpoints ------------------------------
# Count scratch-file hits per URL so a primary row can note duplicate copies.
$scratchUrlCounts = @{}
foreach ($f in $allFilesInclScratch) {
    if (-not (Test-ScratchFile $f.FullName)) { continue }
    $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
    if ([string]::IsNullOrWhiteSpace($content)) { continue }
    foreach ($m in $quotedUrlRe.Matches($content)) {
        $u = $m.Groups[1].Value
        if ($scratchUrlCounts.ContainsKey($u)) { $scratchUrlCounts[$u]++ } else { $scratchUrlCounts[$u] = 1 }
    }
}

# ---- Build the HTTP/XML endpoint table (dedup by url+file, stable order) ----
$endpointRows = New-Object System.Collections.Generic.List[object]
$seenEndpoint = @{}
foreach ($h in ($endpointHits | Sort-Object @{Expression = { $_.url } }, @{Expression = { $_.file } }, @{Expression = { $_.line } })) {
    $key = "$($h.url)|$($h.file)"
    if ($seenEndpoint.ContainsKey($key)) { continue }
    $seenEndpoint[$key] = $true
    $scratchNote = ''
    if ($scratchUrlCounts.ContainsKey($h.url)) { $scratchNote = " [also present in $($scratchUrlCounts[$h.url]) copy/test file(s)]" }
    $evidence = (Format-CodeSpan $h.file) + " line " + $h.line + $scratchNote
    $endpointRows.Add([pscustomobject]@{
        id=''; endpoint=$h.url; mechanism=$h.mech; evidence=$evidence; behavior=$h.behavior; status='Verified'
    })
}
$eIdx = 1
foreach ($er in $endpointRows) { $er.id = "HTTP-$($eIdx.ToString('00'))"; $eIdx++ }

# ---- COM objects table (primary files, by count desc, then name) -------------
$comRows = New-Object System.Collections.Generic.List[object]
foreach ($key in ($comCounts.Keys | Sort-Object @{Expression = { $comCounts[$_] }; Descending = $true }, @{Expression = { $_ } })) {
    $comRows.Add([pscustomobject]@{ object=$key; count=$comCounts[$key]; sample=$comSample[$key]; status='Verified' })
}
$comShow = @($comRows | Select-Object -First 20)

# ---- Email / COM / File boundary rows ----------------------------------------
$boundaryRows = New-Object System.Collections.Generic.List[object]
# (1) stored-proc email: one row per distinct primary file
$seenMailFile = @{}
foreach ($h in ($sendMailHits | Sort-Object @{Expression = { $_.file } }, @{Expression = { $_.line } })) {
    if ($seenMailFile.ContainsKey($h.file)) { continue }
    $seenMailFile[$h.file] = $true
    $boundaryRows.Add([pscustomobject]@{
        id=''; btype='Email (stored procedure)'; call=(Format-CodeSpan (ConvertTo-SafeText ([string]$h.snippet)));
        evidence=(Format-CodeSpan $h.file) + " line " + $h.line;
        behavior='Sends email through a stored-procedure `send_mail` call'; status='Verified'
    })
}
# (2) ADO boundary class (DB boundary; register in 9.1)
if ($adoCount -gt 0) {
    $boundaryRows.Add([pscustomobject]@{
        id=''; btype='ADO boundary'; call='`ADODB.Connection` / `ADODB.Command` / `ADODB.Recordset`';
        evidence=("$adoCount instantiations across $($adoFiles.Count) files (register in §9.1)");
        behavior='Database boundary — the SQL Server data plane (see External Call Register 9.1)'; status='Verified'
    })
}
# (3) file-system / UNC boundary
if ($uncCount -gt 0) {
    $boundaryRows.Add([pscustomobject]@{
        id=''; btype='File-system / UNC'; call='`\\server\share` UNC paths (not printed)';
        evidence=("$uncCount UNC path occurrences across $($uncFiles.Count) files; e.g. " + (Format-CodeSpan $uncFiles[0]));
        behavior='UNC file-share boundary'; status='Verified'
    })
}
$bIdx = 1
foreach ($br in $boundaryRows) { $br.id = "BND-$($bIdx.ToString('00'))"; $bIdx++ }

# ---- Render markdown --------------------------------------------------------
$generatedLine = "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$generatedIso  = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$summaryText = "This artifact lists the external-call boundaries actually present in the classic-ASP source, each with its file:line evidence and epistemic status. **HTTP/XML endpoints** are the outbound URL + XML-HTTP mechanism sites. **Email/COM/file boundaries** are stored-procedure email calls, the ADO database boundary (class), and UNC/file-system paths. Every REAL secret value (API key / Authorization header / embedded credential) is **redacted** and emitted as ``[REDACTED]``. Status ``Verified`` means the call site is present in the current source, not that the target is reachable in production (that is Unknown)."

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# External Call Register"); $lines.Add(""); $lines.Add($generatedLine); $lines.Add("")
$lines.Add("## Summary"); $lines.Add(""); $lines.Add($summaryText); $lines.Add("")
$totalsLine = "Totals: **$($endpointRows.Count)** HTTP/XML endpoint site(s), **$($boundaryRows.Count)** Email/COM/file boundary row(s), **$($comCounts.Count)** distinct COM object type(s) (top $($comShow.Count) shown); $adoCount ADO boundary instantiation(s) across $($adoFiles.Count) file(s), $uncCount UNC path occurrence(s), $($apiKeyFiles.Count) file(s) with a hardcoded Authorization header (Apikey [REDACTED])."
$lines.Add($totalsLine); $lines.Add("")
$lines.Add("## Contents"); $lines.Add("")
$lines.Add("- [HTTP/XML Endpoints](#httpxml-endpoints) — outbound URL + XML-HTTP mechanism sites")
$lines.Add("- [Email/COM/File Boundaries](#emailcomfile-boundaries)")
$lines.Add("- [COM Objects Used](#com-objects-used)")
$lines.Add("- [Evidence Traceability](#evidence-traceability)")
$lines.Add("")

$lines.Add("## HTTP/XML Endpoints"); $lines.Add("")
$lines.Add("Each row is an outbound HTTP/XML call site verified against the source at the cited location. The **Mechanism** is the XML-HTTP object that issues the request; the **Behavior** is derived from the URL path + observed tokens (Inferred). Status `Verified` = call site present in source (runtime reachability is Unknown)."); $lines.Add("")
$lines.Add("| ID | Endpoint/URL | Mechanism | Source file:line | Data/behavior | Status |")
$lines.Add("|----|--------------|-----------|------------------|---------------|--------|")
foreach ($er in $endpointRows) {
    $cells = @($er.id, (Format-MarkdownCellText (Format-CodeSpan $er.endpoint)), (Format-MarkdownCellText (Format-CodeSpan $er.mechanism)), (Format-MarkdownCellText $er.evidence), (Format-MarkdownCellText $er.behavior), $er.status)
    $lines.Add((Join-Row $cells))
}
if ($endpointRows.Count -eq 0) { $lines.Add("| — | none detected | — | — | — | Unknown |") }
$lines.Add("")

$lines.Add("## Email/COM/File Boundaries"); $lines.Add("")
$lines.Add("Non-HTTP external boundaries: stored-procedure email calls, the ADO database boundary (class — full register in section 9.1), and UNC/file-system paths."); $lines.Add("")
$lines.Add("| ID | Boundary type | Observed call | Source file:line | Behavior | Status |")
$lines.Add("|----|---------------|---------------|------------------|----------|--------|")
foreach ($br in $boundaryRows) {
    $cells = @($br.id, (Format-MarkdownCellText $br.btype), (Format-MarkdownCellText $br.call), (Format-MarkdownCellText $br.evidence), (Format-MarkdownCellText $br.behavior), $br.status)
    $lines.Add((Join-Row $cells))
}
if ($boundaryRows.Count -eq 0) { $lines.Add("| — | none detected | — | — | — | Unknown |") }
$lines.Add("")

$lines.Add("## COM Objects Used"); $lines.Add("")
$lines.Add("Distinct COM objects instantiated via `CreateObject`/`Server.CreateObject` in the classic-ASP source (scratch/copy/old/test/bak files excluded). Count = total instantiations in primary files; sample file is the first primary file observed."); $lines.Add("")
$lines.Add("| COM object | Count | Sample file | Status |")
$lines.Add("|------------|-------|-------------|--------|")
foreach ($cr in $comShow) {
    $cells = @((Format-MarkdownCellText (Format-CodeSpan $cr.object)), $cr.count, (Format-MarkdownCellText (Format-CodeSpan $cr.sample)), $cr.status)
    $lines.Add((Join-Row $cells))
}
if ($comRows.Count -eq 0) { $lines.Add("| — | none detected | — | Unknown |") }
$lines.Add("")
if ($comRows.Count -gt $comShow.Count) { $lines.Add("*Showing $($comShow.Count) of $($comRows.Count) distinct COM objects (by usage count).*"); $lines.Add("") }

$lines.Add("## Evidence Traceability"); $lines.Add("")
$lines.Add("| Field | Value |"); $lines.Add("|------|-------|")
$lines.Add("| Evidence Artifact | docs/extcalls.evidence.json |")
$lines.Add("| Record Count | $($endpointRows.Count + $boundaryRows.Count + $comRows.Count) |")
$lines.Add("| Generator | generate-classic-asp-extcalls.ps1 |")
$lines.Add("| Grounding Mode | Deterministic pattern detection (grep-verifiable) |")
$lines.Add("| Redaction | All real secret values (API key / Authorization header / credential) emitted as [REDACTED] |")
$lines.Add("")
$lines.Add("---"); $lines.Add("")
$lines.Add("## Provenance"); $lines.Add("")
$lines.Add("- Generator Version: appdoc-run-all-generators/3.0.0"); $lines.Add("- Commit Hash: unknown")
$lines.Add("- Generated At: $generatedIso"); $lines.Add("- Profile: default"); $lines.Add("- Scope: .")
$lines.Add("- Confidence/Inference Flags: deterministic, evidence-backed, secrets redacted")

# Sanitize the full markdown (defense-in-depth) before writing.
$md = ($lines -join "`n")
$md = ConvertTo-SafeText $md
$md | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

# ---- Flat evidence ----------------------------------------------------------
$evidence = New-Object System.Collections.Generic.List[object]
foreach ($er in $endpointRows) {
    $evidence.Add([ordered]@{ kind="http-endpoint"; id=$er.id; endpoint=(ConvertTo-SafeText $er.endpoint); mechanism=$er.mechanism; evidence=(ConvertTo-SafeText $er.evidence); behavior=(ConvertTo-SafeText $er.behavior); status=$er.status })
}
foreach ($br in $boundaryRows) {
    $evidence.Add([ordered]@{ kind="boundary"; id=$br.id; btype=$br.btype; call=(ConvertTo-SafeText $br.call); evidence=(ConvertTo-SafeText $br.evidence); behavior=(ConvertTo-SafeText $br.behavior); status=$br.status })
}
foreach ($cr in $comRows) {
    $evidence.Add([ordered]@{ kind="com-object"; object=$cr.object; count=$cr.count; sample=$cr.sample; status=$cr.status })
}
$evidence | ConvertTo-Json -Depth 14 | Out-File -FilePath $evidencePath -Encoding UTF8

# ---- Canonical evidence (docs/evidence/extcalls.evidence.json) --------------
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
        generator = "generate-classic-asp-extcalls.ps1"
        httpEndpointCount = [int]$endpointRows.Count
        boundaryCount = [int]$boundaryRows.Count
        comObjectCount = [int]$comCounts.Count
        adoInstantiations = [int]$adoCount
        adoFileCount = [int]$adoFiles.Count
        sendMailFileCount = [int]$seenMailFile.Count
        uncTokenCount = [int]$uncCount
        uncFileCount = [int]$uncFiles.Count
        apiKeyFileCount = [int]$apiKeyFiles.Count
        httpEndpointSamples = @($endpointRows | Select-Object -First 5 | ForEach-Object { [string]$_.endpoint })
    }
    determinism = @{ mode = "deterministic" }
}
$canon | ConvertTo-Json -Depth 14 | Out-File -FilePath $canonPath -Encoding UTF8

Write-Host "✅ Classic ASP external calls generated: $outputPath" -ForegroundColor Green
Write-Host "   HTTP/XML endpoints: $($endpointRows.Count) | Boundaries: $($boundaryRows.Count) | COM objects: $($comCounts.Count) (ADO $adoCount / UNC $uncCount) | API-key files (redacted): $($apiKeyFiles.Count)" -ForegroundColor Gray
Write-Host "   Evidence: $evidencePath" -ForegroundColor Gray
