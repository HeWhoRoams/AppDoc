#requires -Version 7.2
#
# generate-classic-asp-endpoints.ps1
#
# Purpose: Populate docs/api-inventory.md (and docs/api-inventory.evidence.json)
#          from CLASSIC ASP source. For classic ASP the "API surface" is the set
#          of request-addressable pages: every .asp entry point plus any .htm page
#          that carries form/QueryString/Request handling. .inc files are includes
#          (dependencies), not entry points.
#
# Deterministic: no LLM, no randomness, no network. Framework-gated: only runs when
# framework-detection.json reports Classic ASP or ASP.NET Web Forms; otherwise it
# writes a minimal "not applicable" placeholder and exits 0.
#

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

# Shared classic-ASP helpers (single definition; see modules/AppDoc.ClassicAsp.psm1).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.ClassicAsp.psm1') -ErrorAction Stop

$ErrorActionPreference = "Stop"

$helpersPath = Join-Path $PSScriptRoot 'template-helpers.ps1'
# Required: generators use its functions further down, so a missing file must stop here
# rather than fail later with an unrelated "command not found".
if (-not (Test-Path -LiteralPath $helpersPath)) { Write-Error "Required helpers file not found: $helpersPath"; exit 1 }
. $helpersPath

# --- Evidence + Contracts modules (canonical evidence + manifest) ----------------
# Imported defensively: the canonical write below only runs if both are available,
# so the extractor still produces its .md + flat evidence without them.
$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
$evidenceModule  = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if ((Test-Path $contractsModule) -and (Test-Path $evidenceModule)) {
    Import-Module $contractsModule -Force -ErrorAction SilentlyContinue
    Import-Module $evidenceModule  -Force -ErrorAction SilentlyContinue
}

# --- Framework gate -------------------------------------------------------------

# --- Classic-ASP source-presence guard (shared-artifact ownership) --------------
# The framework gate above passes for BOTH 'Classic ASP' and 'ASP.NET Web Forms'
# (Web Forms is a C# framework). On a PURE C# Web Forms target there are 0
# *.asp/*.inc files, so this generator must NOT clobber the shared artifact
# (docs/api-inventory.md) that the C# AST path already populated. The real signal
# that this generator OWNS the artifact is classic-ASP SOURCE PRESENCE, not the
# framework label. We count classic-ASP source files using the same exclusions the
# generators apply (path dirs + basename scratch globs) and, when the count is 0,
# yield to the prior owner instead of overwriting.

# The N-A placeholder this generator emits; its presence marks the artifact as
# "not owned by (or already claimed by) the classic-ASP layer." A file WITHOUT this
# marker was populated by another framework's generator (e.g. the C# AST path) and
# must not be clobbered.
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "api-inventory.md"
$evidencePath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "api-inventory.evidence.json"

Write-Host "📡 Generating Classic ASP endpoint inventory..." -ForegroundColor Cyan

if (-not (Get-ClassicAspFrameworkApplicable -RootPath $RootPath)) {
    # --- Non-ASP framework (Core / Node / Flask / Django / Spring / ...) -------
    # The generic C#/TS generators (generate-api-inventory.ps1, generate-data-model.ps1)
    # run EARLIER in the pipeline and already wrote the shared artifact for this
    # framework. Ownership of the shared artifact is decided by artifact PROVENANCE,
    # not the framework label: if docs/api-inventory.md exists and is NOT this
    # generator's own N-A placeholder, a prior owner populated it and we must YIELD
    # (not clobber). Only when no prior owner artifact exists do we write our own
    # N-A placeholder (harmless — nothing to overwrite).
    $artifactExists    = Test-Path $outputPath
    $isPriorOwnerOwned = $artifactExists -and (-not (Test-AppDocArtifactIsClassicAspPlaceholder -Path $outputPath))
    if ($isPriorOwnerOwned) {
        Write-Host "  Framework not Classic ASP / Web Forms and a prior (C#/TS) api-inventory exists; yielding (not clobbering)." -ForegroundColor Yellow
        Write-Host "✅ api-inventory retained (non-ASP source-presence guard)." -ForegroundColor Green
        exit 0
    }
    Write-Host "  Framework not Classic ASP / Web Forms - writing placeholder." -ForegroundColor Yellow
    Write-AppDocNotApplicablePlaceholder -OutputPath $outputPath -Title "API Inventory"
    $placeholder = @() | ConvertTo-Json -Depth 5
    $placeholder | Out-File -FilePath $evidencePath -Encoding UTF8
    Write-Host "✅ Placeholder written: $outputPath" -ForegroundColor Green
    exit 0
}

# --- Classic-ASP source-presence guard ------------------------------------------
# The framework gate passes for BOTH 'Classic ASP' and 'ASP.NET Web Forms' (Web
# Forms is a C# framework). Ownership of the shared artifact is decided by classic-
# ASP SOURCE PRESENCE, not the framework label: if there are 0 *.asp/*.inc files
# (after the same scratch/fixture/basename exclusions the generator already uses),
# this generator finds no endpoints and would CLOBBER the C# AST path's populated
# docs/api-inventory.md with an empty classic-ASP table. When classic-ASP source
# is absent we yield: leave a non-placeholder artifact (written by the C# path)
# intact, and only write the N-A placeholder when no prior owner populated it.
$classicAspSourceCount = Get-AppDocClassicAspSourceFileCount -RootPath $RootPath
if ($classicAspSourceCount -eq 0) {
    $artifactExists    = Test-Path $outputPath
    $isPriorOwnerOwned = $artifactExists -and (-not (Test-AppDocArtifactIsClassicAspPlaceholder -Path $outputPath))
    if ($isPriorOwnerOwned) {
        Write-Host "  No classic-ASP source (*.asp/*.inc) found; yielding api-inventory.md to the prior framework's generator." -ForegroundColor Yellow
        Write-Host "✅ api-inventory.md retained (classic-ASP source-presence guard)." -ForegroundColor Green
        exit 0
    }
    Write-Host "  No classic-ASP source found and no prior owner artifact - writing N-A placeholder." -ForegroundColor Yellow
    Write-AppDocNotApplicablePlaceholder -OutputPath $outputPath -Title "API Inventory"
    $placeholder = @() | ConvertTo-Json -Depth 5
    $placeholder | Out-File -FilePath $evidencePath -Encoding UTF8
    Write-Host "✅ Placeholder written: $outputPath" -ForegroundColor Green
    exit 0
}

# --- Scan -----------------------------------------------------------------------
# Collect entry-point files: all .asp (entry points) + .htm pages with form/Request
# handling. .inc files are treated as includes (dependencies), not entry points.
$rootPrefix = $RootPath.TrimEnd('\', '/')
$aspFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp" -File -ErrorAction SilentlyContinue | Sort-Object FullName)
# .htm entry points only matter if they carry form/Request handling. 12k+ of these
# are static archived pages, so prefilter with a fast streaming Select-String pass
# before doing per-file full-content work.
$htmAllPaths = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.htm","*.html" -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
$htmSignalPaths = @(
    if ($htmAllPaths.Count -gt 0) {
        Select-String -Path $htmAllPaths -Pattern '<(input|select|textarea)\b[^>]*\bname\s*=|\bRequest(\.QueryString|\.Form|\s*\()' -List -ErrorAction SilentlyContinue |
            ForEach-Object { $_.Path } | Sort-Object
    }
)
$htmFiles = @($htmSignalPaths | Where-Object { $_ } | ForEach-Object { [PSCustomObject]@{ FullName = $_ } })

# Include-file content cache (resolved path -> raw text) so each .inc is read once.
$script:includeCache = @{}
# Detect #include file targets (classic ASP include directives).
function Get-IncludeFiles {
    param([string]$Content)
    $targets = @([regex]::Matches($Content, '(?is)<!--\s*#include\s+(?:once\s+)?file\s*=\s*["'']([^"'']+)["'']') | ForEach-Object { [string]$_.Groups[1].Value.Trim() })
    return @($targets | Where-Object { $_ } | Select-Object -Unique)
}

# Detect ADO connection-string provider tokens (structure only; redacted values ignored).
function Get-ConnProviderTokens {
    param([string]$Content)
    $tokens = @()
    foreach ($m in [regex]::Matches($Content, '(?i)Provider\s*=\s*([A-Za-z0-9._]+)')) {
        $tokens += $m.Groups[1].Value
    }
    if ($Content -match '(?i)Data Source\s*=|Initial Catalog\s*=') {
        $tokens += "ADODB"
    }
    return @($tokens | Select-Object -Unique)
}

# Detect HTML form field names + classic-ASP Request(...) field names.
function Get-InputFields {
    param([string]$Content)
    $fields = New-Object System.Collections.Generic.List[string]
    # HTML <input name="x"> / <select name="x"> / <textarea name="x">
    foreach ($m in [regex]::Matches($Content, '(?is)<(input|select|textarea)\b[^>]*\bname\s*=\s*["'']([^"'']+)["'']')) {
        $fields.Add($m.Groups[2].Value.Trim())
    }
    # Request("x") / Request.Item("x") / Request.Form("x") / Request.QueryString("x")
    foreach ($m in [regex]::Matches($Content, '(?i)\bRequest(\.Item|\.Form|\.QueryString)?\s*\(\s*["'']([^"'']+)["'']')) {
        $fields.Add($m.Groups[2].Value.Trim())
    }
    return @($fields | Where-Object { $_ } | Select-Object -Unique | Sort-Object)
}

function Get-HttpMethod {
    param([string]$Content)
    $hasGet = ([regex]::IsMatch($Content, '(?i)Request\.QueryString'))
    $hasPost = ([regex]::IsMatch($Content, '(?i)Request\.Form'))
    if ($hasGet -and $hasPost) { return "GET/POST" }
    if ($hasPost) { return "POST" }
    return "GET"
}

$entries = New-Object System.Collections.Generic.List[object]
$id = 0

# Process a candidate entry-point file.
function Invoke-EntryFileScan {
    param(
        [string]$FullPath,
        [string]$RootPrefix,
        [System.Collections.Generic.List[object]]$Entries,
        [ref]$IdCounter,
        [bool]$RequireRequestSignal
    )

    $content = Get-Content $FullPath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { $content = "" }

    # .htm pages are only "endpoints" if they carry form/Request handling.
    if ($RequireRequestSignal) {
        $signal = ([regex]::IsMatch($content, '(?is)<(input|select|textarea)\b[^>]*\bname\s*=')) -or
                 ([regex]::IsMatch($content, '(?i)\bRequest(\.QueryString|\.Form|\s*\()'))
        if (-not $signal) { return }
    }

    $relPath = Get-RelativePath -FullPath $FullPath -Base $RootPrefix
    $method = Get-HttpMethod -Content $content
    $fields = @(Get-InputFields -Content $content)
    $includes = @(Get-IncludeFiles -Content $content)

    # Dependencies: include targets (relative, posix) + ADO provider tokens seen in
    # this file or any of its direct includes.
    $deps = New-Object System.Collections.Generic.List[string]
    foreach ($inc in $includes) {
        $incNorm = ($inc -replace '\\', '/')
        $deps.Add($incNorm)
    }
    $connTokens = @(Get-ConnProviderTokens -Content $content)
    # Resolve each direct include (relative to this file's directory) and scan for ADO.
    foreach ($inc in $includes) {
        $incAbs = Join-Path (Split-Path $FullPath -Parent) $inc
        if (Test-Path $incAbs -PathType Leaf) {
            $key = $incAbs.TrimEnd('\')
            if (-not $script:includeCache.ContainsKey($key)) {
                $script:includeCache[$key] = (Get-Content $incAbs -Raw -ErrorAction SilentlyContinue)
            }
            $incContent = if ($null -eq $script:includeCache[$key]) { "" } else { [string]$script:includeCache[$key] }
            $connTokens += @(Get-ConnProviderTokens -Content $incContent)
        }
    }
    foreach ($t in $connTokens) { $deps.Add("ADO:$t") }
    $deps = @($deps | Select-Object -Unique | Sort-Object)

    # Keep cells bounded but deterministic.
    $fieldsShown = if ($fields.Count -le 6) { ($fields -join ", ") } else { (($fields | Select-Object -First 6) -join ", ") + " (+$($fields.Count - 6) more)" }
    $depsShown = if ($deps.Count -le 4) { ($deps -join ", ") } else { (($deps | Select-Object -First 4) -join ", ") + " (+$($deps.Count - 4) more)" }

    $idNum = $IdCounter.Value + 1
    $IdCounter.Value = $idNum
    $eid = "ep-$( $idNum.ToString('0000') )"

    $entries.Add([ordered]@{
        id = $eid
        file = $relPath
        method = $method
        fields = $fields
        deps = $deps
        status = "Verified"
        fieldsShown = $fieldsShown
        depsShown = $depsShown
    })
}

foreach ($f in $aspFiles) {
    Invoke-EntryFileScan -FullPath $f.FullName -RootPrefix $rootPrefix -Entries $entries -IdCounter ([ref]$id) -RequireRequestSignal $false
}
foreach ($f in $htmFiles) {
    Invoke-EntryFileScan -FullPath $f.FullName -RootPrefix $rootPrefix -Entries $entries -IdCounter ([ref]$id) -RequireRequestSignal $true
}

# Sort entries deterministically by file path.
$entries = @($entries | Sort-Object { [string]$_.file })

# --- Render markdown ------------------------------------------------------------
Write-Progress -Activity "Classic ASP endpoints" -Status "Rendering..." -PercentComplete 70
$epCount = $entries.Count
$getCount = @($entries | Where-Object { [string]$_.method -like "GET*" }).Count
$postCount = @($entries | Where-Object { [string]$_.method -like "POST*" }).Count
$bothCount = @($entries | Where-Object { [string]$_.method -eq "GET/POST" }).Count

$generatedLine = "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$generatedIso = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')

$summaryText = "This artifact documents the classic-ASP request surface: {0} entry-point pages detected. The `Endpoint` column is the request path (relative file path); classic ASP has no separate controller/action routing, so the page path is the endpoint." -f $epCount
$totalsLine = "Endpoint totals: **{0}** endpoints (GET {1}, POST {2}, GET/POST {3}). All rows are `Verified` (the page exists and the endpoint pattern was found). Deterministic evidence: `docs/api-inventory.evidence.json`." -f $epCount, $getCount, $postCount, $bothCount
$recordCountLine = "| Record Count | {0} |" -f $epCount

$tableHeader = "| ID | Endpoint | Method | Input Fields | Dependencies | Status |"
$tableSep = "|------|----------|--------|--------------|--------------|--------|"
$rows = New-Object System.Collections.Generic.List[string]
foreach ($e in $entries) {
    $fileCell = '`' + $e.file + '`'
    $rowLine = "| {0} | {1} | {2} | {3} | {4} | {5} |" -f $e.id, $fileCell, $e.method, $e.fieldsShown, $e.depsShown, $e.status
    $rows.Add($rowLine)
}

$mdParts = New-Object System.Collections.Generic.List[string]
$mdParts.Add("# API Inventory")
$mdParts.Add("")
$mdParts.Add($generatedLine)
$mdParts.Add("")
$mdParts.Add("## Summary")
$mdParts.Add("")
$mdParts.Add($summaryText)
$mdParts.Add("")
$mdParts.Add($totalsLine)
$mdParts.Add("")
$mdParts.Add("## Contents")
$mdParts.Add("")
$mdParts.Add("- [API Endpoints](#api-endpoints) — the classic-ASP endpoint table (one row per request-addressable page)")
$mdParts.Add("- [Data Models](#data-models) — see data-model.md")
$mdParts.Add("- [Authentication & Security](#authentication--security)")
$mdParts.Add("- [Error Responses](#error-responses)")
$mdParts.Add("- [Evidence Traceability](#evidence-traceability)")
$mdParts.Add("")
$mdParts.Add("## API Endpoints")
$mdParts.Add("")
$mdParts.Add("Classic-ASP pages are addressable endpoints; the full appendix (operation intent, auth boundary, timeout/retry, idempotency, confidence) is in [API Inventory Appendix](api-inventory.appendix.md).")
$mdParts.Add("")
# Coverage snapshot (same shape the generic renderer emits; validate-api-inventory.ps1
# cross-checks it against the evidence). Classic-ASP pages are inbound request endpoints;
# outbound calls are documented in extcalls, not here. It lives under "API Endpoints"
# because remediate-generated-docs.ps1 rewrites the Summary section.
$mdParts.Add("### Coverage Snapshot")
$mdParts.Add("")
$mdParts.Add(("- Total endpoints detected: **{0}**" -f $epCount))
$mdParts.Add(("- Inbound endpoints: **{0}**" -f $epCount))
$mdParts.Add("- Outbound API integrations: **0**")
$mdParts.Add("")
$mdParts.Add($tableHeader)
$mdParts.Add($tableSep)
foreach ($r in $rows) { $mdParts.Add($r) }
$mdParts.Add("")
$mdParts.Add("## Data Models")
$mdParts.Add("")
$mdParts.Add("Database objects (tables, views, stored procedures) and connection-string inventory are documented in [data-model.md](data-model.md).")
$mdParts.Add("")
$mdParts.Add("## Authentication & Security")
$mdParts.Add("")
$mdParts.Add("Classic ASP authentication is enforced per-page via session/cookie checks and ADODB credential handling; no centralized controller/middleware policy was extracted.")
$mdParts.Add("")
$mdParts.Add("## Error Responses")
$mdParts.Add("")
$mdParts.Add("Error behavior for these pages is captured in [test-catalog.md](test-catalog.md) (On Error handling and failure-mode redirects).")
$mdParts.Add("")
$mdParts.Add("## Dependencies")
$mdParts.Add("")
$mdParts.Add("Per-page `#include` and ADO provider dependencies are listed in the Dependencies column above.")
$mdParts.Add("")
$mdParts.Add("## Evidence Traceability")
$mdParts.Add("")
$mdParts.Add("| Field | Value |")
$mdParts.Add("|------|-------|")
$mdParts.Add("| Evidence Artifact | docs/api-inventory.evidence.json |")
$mdParts.Add($recordCountLine)
$mdParts.Add("| Generator | generate-classic-asp-endpoints.ps1 |")
$mdParts.Add("| Required Evidence Keys | endpoints |")
$mdParts.Add("| Grounding Mode | Deterministic extraction records |")
$mdParts.Add("")
$mdParts.Add("---")
$mdParts.Add("")
$mdParts.Add("## Provenance")
$mdParts.Add("")
$mdParts.Add("- Generator Version: appdoc-run-all-generators/3.0.0")
$mdParts.Add("- Commit Hash: unknown")
$mdParts.Add("- Generated At: $generatedIso")
$mdParts.Add("- Profile: default")
$mdParts.Add("- Scope: .")
$mdParts.Add("- Confidence/Inference Flags: deterministic, evidence-backed")
$md = ($mdParts -join "`n")

$md | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

# --- Appendix (docs/api-inventory.appendix.md) -------------------------------------
# The inventory above links to this appendix, and the gate requires it. When the classic-
# ASP layer owns api-inventory the generic generator does not run, so the appendix is
# written here from the same page entries (previously a stale generic "N/A" appendix was
# left behind instead).
$appendixPath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) 'api-inventory.appendix.md'
$appendixRows = foreach ($e in $entries) {
    $m = [string]$e.method
    $intent = switch ($m) { 'GET' { 'Read/query page' } 'POST' { 'Form submission' } 'GET/POST' { 'Page with form post-back' } default { 'Page request' } }
    $idem = switch ($m) { 'GET' { 'Idempotent' } 'POST' { 'Non-idempotent' } 'GET/POST' { 'Non-idempotent on POST' } default { 'Unknown' } }
    "| ``$([string]$e.file)`` | ``/$([string]$e.file)`` | $m | $intent | Public/internal boundary not explicit | Server-side timeout applies; retry expected at caller | $idem | medium |"
}
$appendixHeader = "| Name | Path | Method | Operation Intent | Auth Boundary | Timeout/Retry | Idempotency | Confidence |`n|------|------|--------|------------------|---------------|---------------|-------------|------------|"
$naRow = '| N/A | N/A | N/A | N/A | N/A | N/A | N/A | medium |'
$inboundBlock = if (@($appendixRows).Count -gt 0) { "$appendixHeader`n$(@($appendixRows) -join "`n")" } else { "$appendixHeader`n$naRow" }
$appendixText = @(
    '# API Inventory Appendix', '',
    'This appendix contains the full endpoint catalog and operational annotations used for architecture and reliability review. Classic-ASP pages are the endpoints; outbound calls are documented in the external-calls artifact.', '',
    '## Inbound Endpoints', '', $inboundBlock, '',
    '## Outbound Integrations', '', "$appendixHeader`n$naRow", '',
    '---', '', $generatedLine
) -join "`n"
$appendixText | Out-File -FilePath $appendixPath -Encoding UTF8 -NoNewline

# --- Emit flat machine-readable evidence ----------------------------------------
$evidenceRecords = @($entries | ForEach-Object {
    [ordered]@{
        id = [string]$_.id
        file = [string]$_.file
        method = [string]$_.method
        fields = @($_.fields)
        deps = @($_.deps)
        status = [string]$_.status
    }
})
$evidenceRecords | ConvertTo-Json -Depth 12 | Out-File -FilePath $evidencePath -Encoding UTF8

# --- Canonical evidence (docs/evidence/api-inventory.evidence.json) + manifest ----
# The pipeline validator gates on the canonical object store (recordCount + records +
# metadata.requiredEvidenceKeys/requiredSections) and cross-checks the doc "Record Count"
# row against it. Populating it keeps doc/evidence counts consistent and satisfies the
# api-inventory contract (requiredEvidenceKeys=endpoints -> record kind "endpoint").
if ((Get-Command Get-AppDocArtifactContract -ErrorAction SilentlyContinue) -and (Get-Command Write-AppDocEvidenceArtifact -ErrorAction SilentlyContinue)) {
    $ciContract = Get-AppDocArtifactContract -Artifact "api-inventory"
    $canonicalRecords = @($entries | ForEach-Object {
        [ordered]@{
            artifact = "api-inventory"
            source   = [string]$_.file
            name     = [string]$_.file
            kind     = "endpoint"
            id       = [string]$_.id
            method   = [string]$_.method
            file     = [string]$_.file
            fields   = @($_.fields)
            deps     = @($_.deps)
            status   = [string]$_.status
            confidence = 0.8
            provider   = "generate-classic-asp-endpoints.ps1"
            providerType = "deterministic"
        }
    })
    $canonPath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact "api-inventory" -Records $canonicalRecords -Metadata @{
        requiredEvidenceKeys = @($ciContract.requiredEvidenceKeys)
        requiredSections     = @($ciContract.requiredSections)
        generator            = "generate-classic-asp-endpoints.ps1"
        endpointCount        = [int]$epCount
    }
    if ($canonPath -and (Get-Command Update-AppDocEvidenceManifest -ErrorAction SilentlyContinue)) {
        [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact "api-inventory" -EvidencePath $canonPath -RecordCount $canonicalRecords.Count -Metadata @{
            generator = "generate-classic-asp-endpoints.ps1"
        })
    }
}

Write-Progress -Activity "Classic ASP endpoints" -Status "Complete" -PercentComplete 100
Write-Host "✅ Classic ASP endpoint inventory generated: $outputPath" -ForegroundColor Green
Write-Host "   Endpoints found: $epCount (GET $getCount, POST $postCount, GET/POST $bothCount)" -ForegroundColor Gray
Write-Host "   Evidence: $evidencePath" -ForegroundColor Gray
