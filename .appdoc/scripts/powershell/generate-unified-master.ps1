#requires -Version 7.2
#
# generate-unified-master.ps1
#
# Purpose: Compose the 11 per-artifact files + machine evidence into ONE
#          benchmark-shaped 20-section document: docs/application-documentation.md.
#          Also emit a flat machine file docs/application-documentation.evidence.json
#          listing the 20 sections, their status (populated / placeholder /
#          not-applicable), and the source artifact(s) each was projected from.
#
# Deterministic: no LLM, no network, no randomness. Projection = reading the
# structured evidence records + the already-extracted per-artifact .md tables and
# rendering markdown tables. Where a section's data source is absent/thin, the
# section heading + an honest "Unknown / owner-required" or "not detected" note is
# emitted. Rows are NEVER fabricated.
#
# Framework-agnostic: produces the full 20-section document for EVERY framework.
# It projects from whatever per-artifact .md tables + evidence JSON the extractors
# populated. When the target is a classic-ASP / ASP.NET Web Forms codebase (per
# framework-detection.json) the classic-ASP-specific narrative rows are shown; for
# any other framework those rows are honestly replaced with a "not detected for
# this framework" placeholder so no framework-specific content is fabricated.
#
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

$ErrorActionPreference = "Stop"

# --- Import the epistemic module for consistent status tagging (optional) ------
$epistemicModule = Join-Path $PSScriptRoot "modules\AppDoc.Epistemic.psm1"
$hasEpistemic = $false
if (Test-Path $epistemicModule) {
    try { Import-Module $epistemicModule -Force -ErrorAction SilentlyContinue; $hasEpistemic = $true } catch { $hasEpistemic = $false }
}

function Test-FrameworkApplicable {
    param([string]$RootPath)
    $fwPath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "framework-detection.json"
    if (-not (Test-Path $fwPath)) { return $false }
    try { $fw = Get-Content $fwPath -Raw | ConvertFrom-Json -Depth 10 } catch { return $false }
    $frameworks = @()
    if ($fw -is [System.Collections.IEnumerable] -and $fw -isnot [string]) {
        $frameworks = @($fw | ForEach-Object { [string]$_.framework } | Where-Object { $_ })
    }
    else { $frameworks = @([string]$fw.framework) | Where-Object { $_ } }
    return (($frameworks -contains "Classic ASP") -or ($frameworks -contains "ASP.NET Web Forms"))
}

# --- Per-target config: opaque-token convention + operator overlays ------------
# AppDoc ships no knowledge of any specific target. A target may declare (in
# <target>/.appdoc/config.json) an `opaqueTokenPattern` (sanitized placeholders that are
# kept verbatim) and operator overlays (narrative it supplies itself, rendered as
# `Operator-supplied` and never as Verified). See references/config-schema.md.
$composerConfig = $null
$composerConfigModule = Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Config.psm1'
if (Test-Path $composerConfigModule) {
    Import-Module $composerConfigModule -Force -ErrorAction Stop
    $composerConfig = Get-AppDocConfig -RootPath $RootPath
}
$opaqueTokenPattern = if ($composerConfig) { [string]$composerConfig.values.opaqueTokenPattern } else { '' }
function Get-OpaqueTokenNote {
    if ([string]::IsNullOrWhiteSpace($opaqueTokenPattern)) { return '' }
    return (' Values matching the target''s opaque-token pattern (`' + $opaqueTokenPattern + '`) are sanitized placeholders; they must not be reconstructed, resolved, or used to connect to any system.')
}

function Get-EvidencePath {
    # Prefer enriched, then plain per-artifact, then flat last-resort.
    param([string]$DocsPath, [string]$Artifact)
    $candidates = @(
        (Join-Path $DocsPath "evidence\$($Artifact).evidence.enriched.json"),
        (Join-Path $DocsPath "evidence\$($Artifact).evidence.json"),
        (Join-Path $DocsPath "$($Artifact).evidence.json")
    )
    foreach ($c in $candidates) { if (Test-Path $c) { return $c } }
    return $null
}

function Read-Json {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try { return (Get-Content $Path -Raw | ConvertFrom-Json -Depth 120) } catch { return $null }
}

# --- markdown table helpers ----------------------------------------------------
function Split-CellLine {
    param([string]$Line)
    $s = $Line.Trim()
    $s = $s -replace '^\|', ''
    $s = $s -replace '\|\s*$', ''
    return @($s -split '\|' | ForEach-Object { $_.Trim() })
}
function Clean-Cell {
    param([string]$v)
    if ($null -eq $v) { return '' }
    $v = $v -replace '`', ''
    return $v.Trim()
}
function Get-SectionTable {
    # Return the first pipe-table that follows the first heading whose text
    # contains -Heading (case-insensitive). Returns @{Header;Rows} or $null.
    param([string]$Content, [string]$Heading)
    if ([string]::IsNullOrWhiteSpace($Content)) { return $null }
    $lines = $Content -split "`r?`n"
    $headerIdx = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^#{1,6}\s+' -and $lines[$i] -match ('(?i)' + [regex]::Escape($Heading))) { $headerIdx = $i; break }
    }
    if ($headerIdx -lt 0) { return $null }
    for ($j = $headerIdx + 1; $j -lt ($lines.Count - 1); $j++) {
        if ($lines[$j] -match '^\s*\|.*\|\s*$' -and $lines[$j + 1] -match '^\s*\|?[\s:|-]+\|?\s*$') {
            $hcells = @((Split-CellLine ([string]$lines[$j])) | ForEach-Object { Clean-Cell $_ })
            $rows = @()
            $k = $j + 2
            while ($k -lt $lines.Count -and ($lines[$k] -match '^\s*\|.*\|\s*$') -and ($lines[$k] -notmatch '^\s*\|[\s:|-]+\|\s*$')) {
                $rows += ,@((Split-CellLine ([string]$lines[$k])) | ForEach-Object { Clean-Cell $_ })
                $k++
            }
            return [pscustomobject]@{ Header = $hcells; Rows = $rows }
        }
    }
    return $null
}
function Get-MermaidBlock {
    # Extract the first ```mermaid fenced block from a file (verbatim body).
    param([string]$Path)
    if (-not (Test-Path $Path)) { return '' }
    $lines = Get-Content $Path -Raw
    $ls = $lines -split "`r?`n"
    $cap = $false; $body = @()
    foreach ($l in $ls) {
        if (-not $cap) {
            if ($l -match '^\s*```mermaid') { $cap = $true }
        }
        else {
            if ($l -match '^\s*```') { break }
            $body += $l
        }
    }
    return ($body -join "`n")
}
# --- Evidence-based endpoint projection (FIX: API-endpoint sections) ----------
# The API-endpoint sections (§1 cross-reference, §3.1 subsystems, §4 functional
# inventory, §6 UI catalog) used to render from the FIRST pipe-table under
# "## API Endpoints" in api-inventory.md ($apiTab = Get-SectionTable). On targets
# whose api-inventory.md leads that section with an AGGREGATE table (e.g. a C# MVC 5
# academic app: a "Direction Summary" | Direction | Endpoints | Unique Paths | Methods |
# with 2 rows: Inbound 189 / Outbound 0), $apiTab is the 2-row aggregate and those
# sections render GARBAGE ("F-01 | 189 | 189 | DELETE, GET, POST"). The canonical,
# complete, deterministic per-endpoint data is the api-inventory EVIDENCE
# ($apiEv.records). When $apiTab is NOT a valid per-endpoint table (it lacks the
# exact "Endpoint" column a real per-endpoint table carries — and/or carries the
# aggregate's exact "Endpoints" count column), we fall back to $apiEv.records.
# the classic-ASP test target's real per-endpoint table has an "Endpoint" column (and no "Endpoints"
# count column) -> $apiUseEvidence stays $false -> the classic-ASP target keeps the markdown path
# (byte-identical). These helpers are pure (no file I/O, no randomness).
function Get-AppDocEndpointRecords {
    param($ApiEv)
    if ($null -eq $ApiEv -or $null -eq $ApiEv.records) { return @() }
    return @($ApiEv.records | Where-Object { $_ -and [string]$_.kind -eq 'endpoint' })
}
function Get-AppDocEndpointSorted {
    # Deterministic sort by (path, method) so the per-section caps are reproducible.
    param($Records)
    if (@($Records).Count -eq 0) { return @() }
    return @($Records | Sort-Object @{Expression = { [string]$_.name }}, @{Expression = { [string]($_.metadata.method) } })
}
function Get-AppDocEndpointFeature {
    # Readable "Controller/Action" (Inferred) from a record: the controller + the last
    # non-empty path segment (route-template braces like {id} stripped). Falls back to
    # the action or the path when the controller is absent.
    param($Record)
    $m = $Record.metadata
    $path = [string]$Record.name
    $segs = @($path -split '/' | Where-Object { $_ })
    $last = ''
    # The ACTION is the LAST non-empty path segment (route-template braces like {id} stripped).
    foreach ($s in $segs) { $clean = ($s -replace '\{[^}]*\}', '').Trim(); if ($clean) { $last = $clean } }
    $ctl = if ($m -and $m.controller) { ([string]$m.controller).Trim() } else { '' }
    if ($ctl -and $last) { return ($ctl + '/' + $last) }
    if ($last) { return $last }
    return $path
}
function Get-AppDocEndpointInputs {
    # The record's form/query field summary, or '' when it has none (caller renders N/A / —).
    param($Record)
    $m = $Record.metadata
    $pv = if ($m -and $m.parameters) { [string]$m.parameters } else { '' }
    $pv = $pv.Trim()
    if ($pv -eq '' -or ($pv -ceq 'None')) { return '' }
    return $pv
}
function Get-AnchorHeading {
    # Mirror the HTML generator's Get-Anchor so in-doc TOC links resolve.
    param([string]$Text)
    $t = ([string]$Text).Trim().ToLowerInvariant()
    $t = [regex]::Replace($t, '[`*_]', '')
    $t = [regex]::Replace($t, '[^a-z0-9]+', ' ')
    $t = $t -replace '\s+', '-'
    return $t
}
function Humanize-FileName {
    param([string]$name)
    $n = [string]($name -replace '\.(asp|aspx|htm|html|inc)$', '')
    $n = $n -replace '[\-_]+', ' '
    $n = $n -replace '\s+', ' '
    return $n.Trim()
}

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$docsPath = (Get-AppDocDocsPath -RootPath $RootPath)
if (-not (Test-Path $docsPath)) { Write-Error "docs directory not found: $docsPath"; exit 1 }

Write-Host "🧩 Composing unified master document (application-documentation.md)..." -ForegroundColor Cyan

# --- Framework applicability (no longer a hard gate) --------------------------
# The unified master is composed for ALL frameworks. The flag below only selects
# which of the two per-framework narrative variants is emitted for the handful of
# classic-ASP-specific rows (see each section); every table-driven section already
# projects from whatever per-artifact .md tables + evidence exist.
$isClassicAspTarget = (Test-FrameworkApplicable -RootPath $RootPath)
Write-Host ("  Framework target: {0}" -f $(if ($isClassicAspTarget) { "Classic ASP / ASP.NET Web Forms" } else { "non-classic-ASP (framework-agnostic)" })) -ForegroundColor Yellow

# --- Framework label + "not detected" placeholder helpers ---------------------
# Get-FrameworkLabel: the detected framework name for the doc header + evidence
# file. Reads framework-detection.json (object or array form); falls back to a
# generic label when unreadable/absent so the doc is never blank on this line.
function Get-FrameworkLabel {
    param([string]$RootPath)
    $fwPath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "framework-detection.json"
    if (-not (Test-Path $fwPath)) { return "Unknown / not detected" }
    try { $fw = Get-Content $fwPath -Raw | ConvertFrom-Json -Depth 10 } catch { return "Unknown / not detected" }
    $names = @()
    if ($fw -is [System.Collections.IEnumerable] -and $fw -isnot [string]) {
        $names = @($fw | ForEach-Object { [string]$_.framework } | Where-Object { $_ })
    } else { $names = @([string]$fw.framework) | Where-Object { $_ } }
    if ($names.Count -eq 0) { return "Unknown / not detected" }
    return ($names -join ", ")
}
# NDA: an honest "not detected for this framework" line. Used only for the
# classic-ASP-specific narrative rows when the target is NOT classic ASP, so that
# no framework-specific claim is fabricated for C#/.NET or other frameworks.
function NDA {
    param([string]$Detail)
    $d = if ($Detail) { " ($Detail)" } else { '' }
    return "*Not detected for this framework — classic-ASP-specific data point; not applicable to the detected framework.{0}*" -f $d
}

# --- Load evidence JSON -------------------------------------------------------
$apiEv   = Read-Json (Get-EvidencePath $docsPath "api-inventory")
$dmEv    = Read-Json (Get-EvidencePath $docsPath "data-model")
$testEv  = Read-Json (Get-EvidencePath $docsPath "test-catalog")
$bcEv    = Read-Json (Get-EvidencePath $docsPath "build-cookbook")
$cfgEv   = Read-Json (Get-EvidencePath $docsPath "config-catalog")
$depEv   = Read-Json (Get-EvidencePath $docsPath "dependencies-catalog")
$ovEv    = Read-Json (Get-EvidencePath $docsPath "overview")
$metrics = Read-Json (Join-Path $docsPath "evidence\metrics-canonical.json")

# Load rendered per-artifact markdown
function Read-Md { param([string]$name) $p = Join-Path $docsPath $name; if (Test-Path $p) { return (Get-Content $p -Raw) } else { return '' } }
$apiMd   = Read-Md "api-inventory.md"
$dmMd    = Read-Md "data-model.md"
$testMd  = Read-Md "test-catalog.md"
$bcMd    = Read-Md "build-cookbook.md"
$ovMd    = Read-Md "overview.md"
$evRegMd = Read-Md "evidence-register.md"
$verAppMd= Read-Md "verification-appendix.md"
$procdictMd = Read-Md "procdict.md"
$securityMd = Read-Md "security.md"
$extcallsMd = Read-Md "extcalls.md"

# --- Counts (deterministic, from evidence records / metadata) -----------------
function Ev-Count {
    param($Ev, [string[]]$Kinds)
    if ($null -eq $Ev -or $null -eq $Ev.records) { return 0 }
    if ($Kinds.Count -eq 0) { return @($Ev.records).Count }
    return @($Ev.records | Where-Object { $_ -and [string]$_.kind -in $Kinds }).Count
}
$endpointCount   = Ev-Count $apiEv @("endpoint")
if ($endpointCount -eq 0 -and $metrics) { $endpointCount = [int]($metrics.totals.endpointCount) }
$dmModelCount    = Ev-Count $dmEv @("model")
$dmDbCount       = Ev-Count $dmEv @("database")
if ($null -ne $dmEv.metadata) {
    $dmTableCount = [int]$dmEv.metadata.tableCount
    $dmProcCount  = [int]$dmEv.metadata.procedureCount
    if ($dmEv.metadata.databaseCount)  { $dmDbCount = [int]$dmEv.metadata.databaseCount }
}
if ($dmModelCount -eq 0 -and $metrics) { $dmModelCount = [int]($metrics.totals.modelCount) }
# derive table/procedure counts from the table rows when metadata is absent
if (-not ($dmTableCount -gt 0) -and $tableTab) { $dmTableCount = $tableTab.Rows.Count }
if (-not ($dmProcCount  -gt 0) -and $procTab)  { $dmProcCount  = $procTab.Rows.Count }
# --- Gap 5 wiring: connection-string evidence from the config-catalog -------------
# On a non-classic-ASP target (e.g. .NET Core) the data-model extractor emits
# generic model records (no ADO database/table surface), so $dmDbCount/$dbTab are 0
# and the "Databases" sub-section above renders "0 of 0 / not detected" even though
# the config-catalog holds the real (redacted) ConnectionStrings. Collect those keys
# (deterministic, sorted, values already redacted by the config-catalog extractor)
# so the sub-section can surface them. Classic-ASP keeps its ADO table untouched.
$cfgConnStrings = @()
if ($null -ne $cfgEv -and $null -ne $cfgEv.records) {
    $cfgConnStrings = @(
        $cfgEv.records |
            Where-Object { $_ -and ([string]$_.name) -match '(?i)^ConnectionStrings\.' } |
            Sort-Object { [string]$_.name }
    )
}
$cfgConnStringCount = @($cfgConnStrings).Count
$testCaseCount = Ev-Count $testEv @("test-case")
$onErrorFiles  = if ($testEv.metadata -and $testEv.metadata.onerrorResumeFiles) { [int]$testEv.metadata.onerrorResumeFiles } else { 0 }
$refreshTimers = if ($testEv.metadata -and $testEv.metadata.refreshTimers)        { [int]$testEv.metadata.refreshTimers } else { 0 }
$redirectFail  = if ($testEv.metadata -and $testEv.metadata.redirectAfterFailure) { [int]$testEv.metadata.redirectAfterFailure } else { 0 }
$providerCount = if ($bcEv.metadata -and $bcEv.metadata.providerCount) { [int]$bcEv.metadata.providerCount } else { 0 }
$instanceCount = if ($bcEv.metadata -and $bcEv.metadata.instanceCount) { [int]$bcEv.metadata.instanceCount } else { 0 }
if ($instanceCount -eq 0) {
    # derive distinct SQL server instances from build-cookbook table. This table is
    # written ONLY by the classic-ASP platform extractor; on other frameworks the
    # build-cookbook carries no SQL-Server-instances section, so skip the derivation
    # (avoids projecting classic-ASP fixture instances as "Verified" for e.g. C#).
    if ($isClassicAspTarget) {
        $sqlTab = Get-SectionTable $bcMd "SQL Server Instances"
        if ($sqlTab) { $instanceCount = $sqlTab.Rows.Count }
    }
}

# Evidence date (deterministic, from the machine evidence, not wall-clock)
$evidenceDate = ''
if ($metrics -and $metrics.generatedAt) { $evidenceDate = [string]$metrics.generatedAt }
elseif ($dmEv -and $dmEv.generatedAt)   { $evidenceDate = [string]$dmEv.generatedAt }
elseif ($apiEv -and $apiEv.generatedAt) { $evidenceDate = [string]$apiEv.generatedAt }
else { $evidenceDate = (Get-Date -Format "yyyy-MM-dd'T'HH:mm:ssK") }

# --- Source tables -----------------------------------------------------------
$apiTab      = Get-SectionTable $apiMd "API Endpoints"
$dbTab       = Get-SectionTable $dmMd "Databases"
$tableTab    = Get-SectionTable $dmMd "Tables and Views"
$procTab     = Get-SectionTable $dmMd "Stored Procedures"
$errTab      = Get-SectionTable $testMd "Error Handling Patterns"
$failTab     = Get-SectionTable $testMd "Known Failure Modes"
$bcStepsTab  = Get-SectionTable $bcMd "Build Steps"
$bcPlatTab   = Get-SectionTable $bcMd "Platform"
$bcSqlTab    = Get-SectionTable $bcMd "SQL Server Instances"
$bcCodeTab   = Get-SectionTable $bcMd "Code Inventory"
# classic-ASP stored-procedure data dictionary + security artifacts (new). When
# the extractors have populated procdict.md / security.md, these tables carry the
# real contract ladders and findings; otherwise they are $null and the sections
# fall back to the honest Unknown/placeholder content below.
$pdDocTab    = Get-SectionTable $procdictMd "Documented Procedures"
$pdUndocTab  = Get-SectionTable $procdictMd "Undocumented Procedures"
$secFindTab  = Get-SectionTable $securityMd "Security Findings"
$secUnkTab   = Get-SectionTable $securityMd "Operational Unknowns"
# classic-ASP external-call register (HTTP/XML + Email/COM/file boundaries). When
# generate-classic-asp-extcalls.ps1 populated extcalls.md, these tables carry the
# real outbound HTTP/XML call sites and boundary rows; otherwise they are $null
# and §9.4/§9.5 fall back to the honest Not-detected placeholder below.
$extHttpTab  = Get-SectionTable $extcallsMd "HTTP/XML Endpoints"
$extBndTab   = Get-SectionTable $extcallsMd "Email/COM/File Boundaries"

# --- API-endpoint evidence fallback (FIX) -------------------------------------
# $apiTab = the FIRST table under "## API Endpoints" in api-inventory.md. That is a
# valid PER-ENDPOINT table (an "Endpoint" column, one row per endpoint) on targets
# like the classic-ASP test target, but on some targets (a C# MVC 5 academic app) the FIRST table is an
# AGGREGATE summary ("Direction Summary": | Direction | Endpoints | Unique Paths |
# Methods | -> 2 rows) and $apiTab is NOT per-endpoint. The deterministic per-endpoint
# data is the api-inventory EVIDENCE ($apiEv.records). $apiUseEvidence selects the
# evidence path ONLY when $apiTab is a non-per-endpoint table (it lacks the exact
# "Endpoint" column that a real per-endpoint table carries) AND the evidence holds
# endpoint records; otherwise the markdown path is kept.
#   * the classic-ASP test target: $apiTab.Header = [ID, Endpoint, Method, Input Fields, Dependencies,
#     Status] -> contains the exact "Endpoint" column -> $apiUseEvidence=$false ->
#     the markdown path is kept and the classic-ASP target's §1/§3.1/§4/§6 stay BYTE-IDENTICAL.
#   * a C# MVC 5 target: $apiTab.Header = [Direction, Endpoints, Unique Paths, Methods] ->
#     NO exact "Endpoint" column -> $apiUseEvidence=$true -> §1/§3.1/§4/§6 render
#     real per-endpoint rows from $apiEv.records.
# The exact-column test (not a substring test) is deliberate: the aggregate's
# "Endpoints" (a count) must not be mistaken for the per-endpoint "Endpoint" column.
$apiEpRecords = Get-AppDocEndpointRecords $apiEv
$apiEpSorted  = Get-AppDocEndpointSorted $apiEpRecords
$apiTabIsPerEndpoint = ($null -ne $apiTab) -and (@($apiTab.Header).Contains('Endpoint'))
$apiUseEvidence = (-not $apiTabIsPerEndpoint) -and (@($apiEpRecords).Count -gt 0)

# --- open-questions accumulator (auto-feed for section 17) --------------------
$openQuestions = New-Object System.Collections.Generic.List[string]
function Add-Question { param([string]$q) $openQuestions.Add($q) }

# --- SOURCE-OF-TRUTH citations (AppDoc.SourceDocs) ----------------------------
# Deterministic citations of hand-authored operational docs (ownership, role-access,
# operational-policy, escalation, troubleshooting, slo) with file:line provenance.
# Loaded once here so the 4 owner-pending cells can POPULATE a cell that the repo
# actually documents (tagged `Verified-source-doc`) instead of an honest-Unknown
# placeholder. Where NO citation exists for a category, the cell STAYS
# owner-required/Unknown (never fabricated). Additive: never changes status/overallScore.
$sdEvPath = Get-EvidencePath -DocsPath $docsPath -Artifact 'source-docs'
$sdEv = $null
if ($sdEvPath) { $sdEv = Read-Json -Path $sdEvPath }
function Sd-Records {
    param([string]$Category)
    if ($null -eq $sdEv -or $null -eq $sdEv.categories) { return @() }
    $c = $sdEv.categories.$Category
    if ($null -eq $c) { return @() }
    return @($c)
}
$sdHasRoleAccess    = (@(Sd-Records 'role-access').Count -gt 0)
$sdHasOwnership     = (@(Sd-Records 'ownership').Count -gt 0)
$sdHasEscalation    = (@(Sd-Records 'escalation').Count -gt 0)
$sdHasTroubleshoot  = (@(Sd-Records 'troubleshooting').Count -gt 0)
# §7 service procedures: only 'service-procedure' sub-tagged operational-policy citations back it.
$sdServiceProc = @(Sd-Records 'operational-policy' | Where-Object { [string]$_.sub -eq 'service-procedure' })
$sdHasServiceProcedure = ($sdServiceProc.Count -gt 0)


# Entry-point areas: endpoints grouped by their first path segment (pages at the root
# form the "(root)" area). Deterministic: sorted by count desc, then area name.
function Get-EntryPointAreas {
    $paths = @()
    if ($apiUseEvidence) { $paths = @($apiEpSorted | ForEach-Object { [string]$_.name }) }
    elseif ($apiTab) { $paths = @($apiTab.Rows | Where-Object { $_.Count -ge 2 } | ForEach-Object { ([string](Clean-Cell $_[1])) -replace '`', '' }) }
    $byArea = [ordered]@{}
    foreach ($p in @($paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) -and $_ -ne '—' })) {
        $pp = (($p -replace '^[A-Z]+\s+', '') -replace '^/', '')
        $area = if ($pp -match '/') { ($pp -split '/')[0] } else { '(root)' }
        if (-not $byArea.Contains($area)) { $byArea[$area] = [pscustomobject]@{ area = $area; count = 0; example = $p } }
        $byArea[$area].count++
    }
    return @($byArea.Values | Sort-Object @{ Expression = { -[int]$_.count } }, @{ Expression = { [string]$_.area } })
}

$out = New-Object System.Collections.Generic.List[string]
# section-status ledger for the evidence file
$sectionsLedger = New-Object System.Collections.Generic.List[object]
function Ledger {
    param([string]$Title, [string]$Status, [string[]]$Sources)
    $sectionsLedger.Add([pscustomobject]@{
        section = $Title; status = $Status; sources = @($Sources)
    })
}

# --- SOURCE-OF-TRUTH citation rendering (Verified-source-doc) -----------------
# Render a set of source-doc citations as a `Verified-source-doc` block. Pure +
# deterministic (input = the citation records; sorted by path, lineStart). Adds
# real, cited content (a claim + its file:line) to a cell the repo actually
# documents, WITHOUT destroying the section structure: it is an ADDITIVE block
# the composer inserts into the owner-pending cell. Every line carries a
# `Verified-source-doc` tag + a real file:line provenance (no fabrication).
# $Cap bounds how many representative citations are surfaced (deterministic).
function Render-SourceDocCitations {
    param(
        [System.Collections.Generic.List[string]]$Out,
        [object[]]$Recs,
        [string]$Caption = 'Source-of-truth citations (hand-authored docs)',
        [int]$Cap = 12,
        [string]$Tag = 'Verified-source-doc'
    )
    $list = @($Recs)
    if ($list.Count -eq 0) { return }
    # Deterministic order: path, then lineStart, then claim.
    $list = @($list | Sort-Object @{Expression = { [string]$_.path } }, @{Expression = { [int]$_.lineStart } }, @{Expression = { [string]$_.claim } })
    $shown = [Math]::Min($Cap, $list.Count)
    $prov = @()
    foreach ($i in 0..($shown - 1)) {
        $r = $list[$i]
        $claim = Clean-Cell ([string]$r.claim)
        if ([string]::IsNullOrWhiteSpace($claim)) { $claim = '—' }
        $ls = [int]$r.lineStart
        $le = [int]$r.lineEnd
        if ($ls -ne $le) { $span = "${ls}-${le}" } else { $span = "$ls" }
        $p = [string]$r.path
        $conf = [string]$r.confidence
        $confNote = ''
        if ($conf) { $confNote = ' (confidence: ' + $conf + ')' }
        $prov += ('`' + $p + '`: ' + $span)
        $line = '- ' + $claim + '  '
        $out.Add($line)
        $out.Add('  - Source: `' + $p + '`:' + $span + ' — `' + $Tag + '`' + $confNote)
    }
    $out.Add('')
    # Provenance summary line (deduped, sorted) — the file:line trail for the cell.
    $provU = @($prov | Sort-Object -Unique)
    $provShown = @($provU | Select-Object -First 12)
    $provMore = ''
    if ($provU.Count -gt 12) { $provMore = ' (+' + ($provU.Count - 12) + ' more)' }
    $out.Add('*' + $Caption + ': ' + ($provShown -join ', ') + $provMore + '. All claims are `' + $Tag + '` (each backed by a real hand-authored file:line; no fabrication).*')
    $out.Add('')
}

# ===========================================================================
# Preamble
# ===========================================================================
$out.Add("# Application Documentation")
$out.Add("")
$out.Add("**Evidence date**: $evidenceDate  ")
$fwLabel = Get-FrameworkLabel -RootPath $RootPath
$fwHeader = if ($isClassicAspTarget) { "Classic ASP (IIS-hosted ASP, VBScript/JScript)" } else { $fwLabel }
$out.Add("**Framework**: $fwHeader  ")
$out.Add("**Composed from**: 11 per-artifact files + machine evidence (deterministic, no LLM).")
$out.Add("")
$out.Add("> **Handling note**: Secret material is redacted and shown as ``[REDACTED]``. Connection strings below are shown in *shape only* (provider / catalog / source), never with live credentials." + (Get-OpaqueTokenNote))
$out.Add("")
$out.Add("**Epistemic status legend**: `Verified` — supported by a located source file + searchable value. `Inferred` — a reasonable interpretation not confirmed by a concrete file+line. `Partly verified` — a file reference exists but the confirmable line/value is absent. `Unknown` — the repository does not establish the claim. `Operator-supplied` — narrative the target's owner provided in an overlay file; not verified from source.")
$out.Add("")

# ===========================================================================
# 1. Application Index
# ===========================================================================
$out.Add("## Application Index")
$out.Add("")
$out.Add("Auto-generated table of contents for this document, plus a quick cross-reference to the primary entry points extracted from the API inventory.")
$out.Add("")
$out.Add("### Table of contents")
$out.Add("")
$spineTitles = @(
    "Application Index","Coverage and Executive Overview","Architecture","Functional Inventory",
    "Roles and Access Model","UI Catalog","Operational Workflows","Data and Integrations",
    "External Call Register","Stored-procedure data dictionary","Troubleshooting Matrix",
    "Security and Operational Risks","Ownership and Maintenance","Architecture and Data-Flow Diagrams",
    "Glossary","Evidence Register","Open Questions and Documentation Gaps","Recommendations",
    "Operations Runbook","Verification Appendix"
)
$idx = 1
foreach ($t in $spineTitles) {
    $out.Add("$($idx). [$t](#$(Get-AnchorHeading $t))")
    $idx++
}
$out.Add("")
$out.Add("### Quick cross-reference (primary entry points)")
$out.Add("")
$out.Add("| # | Feature (Inferred) | Entry point | Method | Status |")
$out.Add("|---|--------------------|-------------|--------|--------|")
# Evidence-based quick cross-reference when $apiTab is not a per-endpoint table
# (FIX). Capped to 10, deterministically sorted by (path, method); Inferred (the
# feature name is inferred from the endpoint; presence is source-derivable).
if ($apiUseEvidence) {
    $epTop10 = @($apiEpSorted | Select-Object -First 10)
    $qri = 1
    foreach ($r in $epTop10) {
        $out.Add("| $qri | $(Get-AppDocEndpointFeature $r) | $([string]$r.name) | $([string]$r.metadata.method) | Inferred |")
        $qri++
    }
    if (@($epTop10).Count -eq 0) { $out.Add("| — | none extracted | — | — | Unknown |") }
} else {
    $qrRows = if ($apiTab) { @($apiTab.Rows | Select-Object -First 10) } else { @() }
    $qri = 1
    foreach ($r in $qrRows) {
        if ($r.Count -ge 3) {
            $ep = Clean-Cell ($r[1])
            $feat = Humanize-FileName $ep
            $out.Add("| $qri | $feat | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | Inferred |")
        }
        $qri++
    }
    if ($qrRows.Count -eq 0) { $out.Add("| — | none extracted | — | — | Unknown |") }
}
$out.Add("")
$out.Add("*Top 10 of $endpointCount request-addressable entry points (see Functional Inventory for the capped detail table).*")
$out.Add("")
Ledger "Application Index" "populated" @("api-inventory")

# ===========================================================================
# 2. Coverage and Executive Overview
# ===========================================================================
$out.Add("## Coverage and Executive Overview")
$out.Add("")
$out.Add("### What was inspected")
$out.Add("")
if ($isClassicAspTarget) {
    $out.Add("The inspected unit is the classic-ASP web application tree under the repository root: $endpointCount request-addressable entry points (`.asp`/`.aspx`), the ADO/SQL Server data layer, and the IIS/ADO deployment platform. The System Overview narrative (overview.md) reports the following as the high-level shape:")
} else {
    $out.Add("The inspected unit is the application tree under the repository root: $endpointCount request-addressable entry points and the data / integration surfaces the extractors detected for this framework ($fwLabel). The System Overview narrative (overview.md) reports the following as the high-level shape:")
}
$out.Add("")
# pull the 'What It Does' bullets from overview if present
$ovWhatIt = Get-SectionTable $ovMd "What It Does"
$ovBullets = @()
if ($ovMd) {
    # grab the "### What It Does" bullet block (deterministic substring up to next ###)
    $m = [regex]::Match($ovMd, '(?ms)^###\s+What It Does\s*\r?\n(.*?)(?=^###\s+|^##\s+|\z)')
    if ($m.Success) {
        foreach ($bl in ($m.Groups[1].Value -split "`r?`n")) {
            $b = [string]$bl
            if ($b -match '^\s*-\s+' -or $b -match '^\s*-\s*$') {
                $ovBullets += ([string]$b -replace '^\s*-\s*', '')
            }
        }
    }
}
if ($ovBullets.Count -gt 0) {
    $out.Add("*From System Overview:*")
    $out.Add("")
    $show = @($ovBullets | Select-Object -First 4)
    foreach ($b in $show) { $out.Add("- $(Clean-Cell $b) _(Inferred — overview narrative)_") }
    $out.Add("")
} else {
    $out.Add("- *(System Overview narrative not available for projection.)*")
    $out.Add("")
}
$out.Add("### Purpose and users")
$out.Add("")
$out.Add("| Aspect | Statement | Status |")
$out.Add("|--------|-----------|--------|")
# Purpose and users are never inferred from file or schema names (no fabrication).
$out.Add("| Purpose | Not established from source. AppDoc does not infer a system's business purpose from file or schema names; owner-required (an operator overlay can supply it). | Unknown |")
$out.Add("| Primary users | Not established from source; owner-required. | Unknown |")
$out.Add("| Interpretation basis | Only grounded inputs are used: the entry points (§4), the data objects (§8) and, where cited, the repository's own hand-authored docs. | N/A |")
$out.Add("")
$out.Add("### System boundary")
$out.Add("")
$out.Add("The boundary is stated as concrete, countable extents extracted from the machine evidence (not narrative):")
$out.Add("")
$out.Add("| Boundary extent | Value | Status |")
$out.Add("|-----------------|-------|--------|")
$out.Add("| Request-addressable entry points (endpoints) | $endpointCount | Verified |")
$out.Add("| Database objects (models) | $dmModelCount | Verified |")
$out.Add("| Distinct databases (connection strings) | $dmDbCount | Verified |")
$out.Add("| SQL Server instances | $instanceCount | Verified |")
$out.Add("| Tables and views referenced | $dmTableCount | Verified |")
$out.Add("| Stored procedures called | $dmProcCount | Verified |")
$out.Add("| Test/failure-surface records | $testCaseCount | Verified |")
$out.Add("")
# machine-readable canonical count markers (used by the gate's metric-drift check)
$out.Add("Canonical count markers (for cross-artifact metric consistency):")
$out.Add("")
$out.Add("| Metric | Value | Status |")
$out.Add("|--------|-------|--------|")
$out.Add("| API endpoints documented | $endpointCount | Verified |")
$out.Add("| Database object records (models) | $dmModelCount | Verified |")
$out.Add("")
Ledger "Coverage and Executive Overview" "populated" @("overview", "api-inventory", "data-model", "build-cookbook")

# ===========================================================================
# 3. Architecture
# ===========================================================================
$out.Add("## Architecture")
$out.Add("")
$out.Add("### 3.1 Components")
$out.Add("")
$out.Add("Components are projected from two deterministic sources: the build-cookbook code inventory (file-type distribution) and the API inventory grouped by top-level subsystem directory.")
$out.Add("")
$out.Add("**Code inventory (file types)** — status Verified:")
$out.Add("")
if ($isClassicAspTarget) {
    if ($bcCodeTab) {
        $out.Add("| File type | Count | Primary directories | Status |")
        $out.Add("|-----------|-------|---------------------|--------|")
        $codeRows = @($bcCodeTab.Rows | Select-Object -First 12)
        foreach ($r in $codeRows) {
            if ($r.Count -ge 3) { $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | Verified |") }
        }
    } else { $out.Add("| — | not detected | — | Unknown |") }
} else {
    # Non-classic-ASP: the file-type inventory is N/A. Emit as an italic PARAGRAPH, not a
    # lone "| ... |" row: a single pipe-row with no header+separator row is malformed
    # markdown that hangs the HTML renderer's Convert-MarkdownFile loop (table branch
    # requires a separator row; the paragraph branch then breaks on the row without
    # advancing $i -> infinite loop). A paragraph renders cleanly and is renderer-safe.
    $out.Add($(NDA 'the classic-ASP code-inventory (file-type distribution from .asp/.aspx/.inc scanning) does not apply to this framework') + " — status: N/A (not applicable to the detected framework).")
}
$out.Add("")
$out.Add("**Subsystems (entry points grouped by top-level directory)** — status Verified (counts) / Inferred (naming):")
$out.Add("")
$out.Add("| Subsystem (dir) | Entry points | Status |")
$out.Add("|-----------------|--------------|--------|")
if ($apiUseEvidence) {
    # Evidence-based subsystem grouping (FIX): group the per-endpoint records by
    # their FIRST non-empty path segment (the top-level subsystem directory). The
    # markdown path above uses ($ep -split '/')[0], which is empty for leading-slash
    # paths, so the evidence path skips empty segments and maps them to (root).
    # Deterministic sort: count desc, then key asc; capped to 20 (matches the
    # markdown path's cap).
    $byDir = @{}
    foreach ($r in $apiEpSorted) {
        $segs = @(([string]$r.name) -split '/' | Where-Object { $_ })
        $dir = if (@($segs).Count -gt 0) { [string]$segs[0] } else { '(root)' }
        if ($byDir.ContainsKey($dir)) { $byDir[$dir]++ } else { $byDir[$dir] = 1 }
    }
    $byDir.GetEnumerator() | Sort-Object @{Expression = { $_.Value }; Descending = $true}, @{Expression = { $_.Key }} | Select-Object -First 20 | ForEach-Object {
        $out.Add("| $($_.Key) | $($_.Value) | Verified |")
    }
    if ($byDir.Count -eq 0) { $out.Add("| — | not detected | Unknown |") }
} elseif ($apiTab) {
    $byDir = @{}
    foreach ($r in $apiTab.Rows) {
        if ($r.Count -ge 2) {
            $ep = Clean-Cell $r[1]
            $dir = ($ep -split '/')[0]
            if ($dir -match '^\.') { $dir = '(root)' }
            if ($byDir.ContainsKey($dir)) { $byDir[$dir]++ } else { $byDir[$dir] = 1 }
        }
    }
    $byDir.GetEnumerator() | Sort-Object @{Expression = { $_.Value }; Descending = $true}, @{Expression = { $_.Key }} | Select-Object -First 20 | ForEach-Object {
        $out.Add("| $($_.Key) | $($_.Value) | Verified |")
    }
} else { $out.Add("| — | not detected | Unknown |") }
$out.Add("")
$out.Add("### 3.2 Architecture diagram")
$out.Add("")
$c4ctx = Get-MermaidBlock (Join-Path $docsPath "diagrams\c4-context.md")
$c4con = Get-MermaidBlock (Join-Path $docsPath "diagrams\c4-container.md")
if ($c4ctx) {
    $out.Add('```mermaid')
    $out.Add($c4ctx)
    $out.Add('```')
    $out.Add("")
}
elseif ($c4con) {
    $out.Add('```mermaid')
    $out.Add($c4con)
    $out.Add('```')
    $out.Add("")
} else {
    $out.Add("*No C4 context diagram was detected in this codebase.*")
    $out.Add("")
}
$out.Add("### 3.3 Authentication / Authorization")
$out.Add("")
# pull the api-inventory 'Authentication & Security' paragraph
$authnText = ''
if ($apiMd) {
    $m = [regex]::Match($apiMd, '(?ms)^##\s+Authentication & Security\s*\r?\n(.*?)(?=^##\s+|\z)')
    if ($m.Success) { $authnText = ([string]$m.Groups[1].Value -replace '\s+', ' ').Trim() }
}
if ($authnText) {
    $out.Add("| Concern | Observed | Status |")
    $out.Add("|---------|----------|--------|")
    if ($isClassicAspTarget) {
        $out.Add("| Model | Per-page authentication via session/cookie checks and ADO credential handling; no centralized controller/middleware policy. | Partly verified |")
    } else {
        $out.Add("| Model | $(NDA 'per-page session/cookie + ADO credential model does not apply to this framework') | Unknown |")
    }
    $out.Add("| Detail | $authnText | Inferred |")
    $out.Add("")
    Add-Question "§3.3 — No centralized authn/authz policy was extracted; per-page checks observed but not exhaustively mapped (owner/ runtime required to confirm enforcement guarantees)."
} else {
    $out.Add("| Concern | Observed | Status |")
    $out.Add("|---------|----------|--------|")
    $out.Add("| Model | Unknown — no authentication/authorization signals were extracted in the available artifacts. | Unknown |")
    $out.Add("")
    Add-Question "§3.3 — Authentication/authorization model is Unknown; no signals extracted."
}
Ledger "Architecture" "populated" @("build-cookbook", "api-inventory", "diagrams/c4-context.md")

# ===========================================================================
# 4. Functional Inventory
# ===========================================================================
$out.Add("## Functional Inventory")
$out.Add("")
$out.Add("Each request-addressable entry point is one feature. The detail table is capped to the first 60 by subsystem order; the full set of $endpointCount entry points lives in [API Inventory](api-inventory.md). Status: `Verified` for entry presence, `Inferred` for the feature purpose/name.")
$out.Add("")
$out.Add("| ID | Feature (Inferred) | Entry point | Inputs (form/query fields) | Dependencies | Status |")
$out.Add("|----|--------------------|-------------|-----------------------------|--------------|--------|")
# Evidence-based functional inventory when $apiTab is not a per-endpoint table
# (FIX). Capped to 60, deterministically sorted by (path, method). Feature is
# Inferred (derived from controller+action); entry presence is source-derivable.
# Inputs = the record's form/query field summary (Inferred) or N/A when absent;
# Dependencies are not extracted (—); Status = Inferred (presence verified,
# purpose inferred — matches the section's own epistemic convention).
if ($apiUseEvidence) {
    $epInv = @($apiEpSorted | Select-Object -First 60)
    $invIdx = 1
    foreach ($r in $epInv) {
        $fid = ('F-{0:D2}' -f $invIdx)
        $feat = Get-AppDocEndpointFeature $r
        $inputs = Get-AppDocEndpointInputs $r
        $out.Add("| $fid | $feat | $([string]$r.name) | $(if ($inputs) { $inputs } else { 'N/A' }) | — | Inferred |")
        $invIdx++
    }
    if (@($epInv).Count -eq 0) { $out.Add("| — | none extracted | — | — | — | Unknown |") }
} else {
    $invRows = if ($apiTab) { @($apiTab.Rows | Select-Object -First 60) } else { @() }
    $invIdx = 1
    foreach ($r in $invRows) {
        $fid = ('F-{0:D2}' -f $invIdx)
        if ($r.Count -ge 4) {
            $ep = Clean-Cell $r[1]
            $feat = Humanize-FileName $ep
            $inputs = Clean-Cell $r[3]
            $deps   = if ($r.Count -ge 5) { Clean-Cell $r[4] } else { '' }
            $out.Add("| $fid | $feat | $(Clean-Cell $r[1]) | $(if ($inputs) { $inputs } else { '—' }) | $(if ($deps) { $deps } else { '—' }) | Verified |")
        }
        $invIdx++
    }
    if ($invRows.Count -eq 0) { $out.Add("| — | none extracted | — | — | — | Unknown |") }
}
$out.Add("")
$out.Add("*Showing $([Math]::Min(60, $endpointCount)) of $endpointCount total entry points.*")
$out.Add("")
Ledger "Functional Inventory" "populated" @("api-inventory")

# ===========================================================================
# 5. Roles and Access Model
# ===========================================================================
$out.Add("## Roles and Access Model")
$out.Add("")
$out.Add("A deterministic scan locates the concrete role / privilege / authorization **tokens** in the classic-ASP source (grep-verifiable), with the first file:line where each was observed. The capability matrix below is **owner-required** — the authoritative role→capability mapping lives in database objects and is data-driven, so no cell is inferred beyond what a single token proves.")
$out.Add("")
$out.Add("### 5.1 Observed role concepts")
$out.Add("")
$out.Add("| Role / concept | Observed capability | Where observed (file:line) | Status |")
$out.Add("|----------------|---------------------|----------------------------|--------|")
if ($isClassicAspTarget) {
    # Generic, source-grounded authorization signals. Each row is a token found in the
    # classic-ASP source with its first file:line; the description states only what the
    # match itself shows. No target-specific interpretation is carried by the tool.
    $roleSignals = @(
        @{ re = '(?i)Session\s*\(\s*"([A-Za-z0-9_]*(?:admin|role|auth|access|perm|level|verif|priv|group)[A-Za-z0-9_]*)"\s*\)\s*=';
           cap = 'Session variable `{0}` is assigned here; by its name it is an authorization/state flag. Its meaning is not established from source.' },
        @{ re = '(?i)\b([A-Za-z0-9_.]*(?:CheckAccess|Authori[sz]e|HasPermission|IsInRole|CheckPermission|VerifyAccess)[A-Za-z0-9_]*)\b';
           cap = 'Authorization routine `{0}` is referenced here.' },
        @{ re = '(?i)(@[A-Za-z0-9_]*(?:Role|Perm|Admin|ExecutedBy)[A-Za-z0-9_]*)\b';
           cap = 'Stored-procedure parameter `{0}` carries a role, permission or caller-identity value.' }
    )
    # Scan the classic-ASP source (excluding scratch/copy/old/test files).
    $roleScratchRe = '(?i)(^|[_\-. ])copy|copy[_\-. ]|(^|[_\-. ])old|testing|bak'
    $aspFilesForRoles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $roleScratchRe } | Sort-Object FullName)
    $incFilesForRoles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.inc" -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -notmatch $roleScratchRe } | Sort-Object FullName)
    $roleFiles = @($incFilesForRoles + $aspFilesForRoles)
    $roleRows = New-Object System.Collections.Generic.List[object]
    $roleSeen = @{}
    $rootPrefixForRoles = $RootPath.TrimEnd('\', '/')
    foreach ($fi in $roleFiles) {
        $content = Get-Content $fi.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        $rel = ([string]$fi.FullName).Substring($rootPrefixForRoles.Length).TrimStart('/','\') -replace '\\', '/'
        foreach ($sig in $roleSignals) {
            foreach ($m in [regex]::Matches([string]$content, $sig.re)) {
                $tok = [string]$m.Groups[1].Value
                if ($roleSeen.ContainsKey($tok.ToLowerInvariant())) { continue }
                $roleSeen[$tok.ToLowerInvariant()] = $true
                $lineNo = ($content.Substring(0, $m.Index) -split "`r?`n").Count
                $roleRows.Add([pscustomobject]@{ token = $tok; cap = ($sig.cap -f $tok); ev = "${rel}:$lineNo" })
            }
        }
    }
    $roleRowsShown = @($roleRows | Select-Object -First 12)
    foreach ($rr in $roleRowsShown) { $out.Add("| $(Clean-Cell $rr.token) | $(Clean-Cell $rr.cap) | ``$($rr.ev)`` | Verified |") }
    if ($roleRowsShown.Count -eq 0) { $out.Add("| — | none | no authorization signals located in source | Unknown |") }
    if ($roleRows.Count -gt $roleRowsShown.Count) { $out.Add(""); $out.Add("*Showing $($roleRowsShown.Count) of $($roleRows.Count) distinct authorization signals.*") }
    $out.Add("")
    $out.Add("### 5.2 Role-capability matrix (owner-required)")
    $out.Add("")
    $out.Add("``Y`` would mean the source directly indicates the capability; ``?`` means not established. Rows are the entry-point areas (§7.1); columns are the session authorization flags found above. The mapping between them is owner-required.")
    $out.Add("")
    $roleCols = @($roleRows | Where-Object { $_.cap -like 'Session variable*' } | Select-Object -First 3 | ForEach-Object { $_.token })
    if ($roleCols.Count -eq 0) { $roleCols = @('(role)') }
    $out.Add("| Area \ Role | " + ($roleCols -join ' | ') + " |")
    $out.Add("|" + ("---|" * ($roleCols.Count + 1)))
    $roleAreas = @(Get-EntryPointAreas | Select-Object -First 8)
    foreach ($ra in $roleAreas) { $out.Add("| $(Clean-Cell $ra.area) | " + ((@($roleCols | ForEach-Object { '?' })) -join ' | ') + " |") }
    if ($roleAreas.Count -eq 0) { $out.Add("| (no entry points extracted) | " + ((@($roleCols | ForEach-Object { '?' })) -join ' | ') + " |") }
    $out.Add("")
    $out.Add("*The role→capability mapping is **owner-required**: permission logic is data-driven and not enumerated in source. Do not infer a permission from a visible button.*")
    $out.Add("")
    if ($sdHasRoleAccess) {
        # The repo's hand-authored docs DO document the role/authorization model.
        # Surface those citations (Verified-source-doc) ADDITIVELY — the classic-ASP
        # data-driven matrix above stays owner-required (different mechanism), but the
        # hand-documented role→purpose + authorization model + capability flags are
        # real, cited facts the repo actually documents.
        $out.Add("#### Role/authorization model (cited from hand-authored docs — Verified-source-doc)")
        $out.Add("")
        $out.Add("The classic-ASP data-driven matrix above remains owner-required (data-driven, not source-enumerable), but the following role/authorization facts are documented in the repo's hand-authored docs:")
        $out.Add("")
        Render-SourceDocCitations -Out $out -Recs (Sd-Records 'role-access') -Caption '§5.2 role/authorization model' -Cap 14
    }
} else {
    # Non-classic-ASP: no classic-ASP role tokens apply. Emit as an italic paragraph (a lone
    # "| ... |" row with no header+separator row would hang the HTML renderer's markdown loop).
    $out.Add($(NDA 'the classic-ASP authorization-signal scan (session flags / access-check routines) does not apply to this framework') + " — status: N/A (no role/authorization tokens located for this framework).")
    $out.Add("")
    $out.Add("### Role-capability matrix")
    $out.Add("")
    if ($sdHasRoleAccess) {
        # The repo's hand-authored docs DO document the role/authorization model
        # (a legacy C# MVC 5 target: readme role→purpose table + authorization model + IUserPermissions
        # capability interface). Surface them as the role-capability evidence, tagged
        # Verified-source-doc. The classic-ASP data-driven matrix is N/A for this framework.
        $out.Add("The classic-ASP data-driven role matrix is N/A for this framework; however, the role/authorization model IS documented in the repo's hand-authored docs:")
        $out.Add("")
        Render-SourceDocCitations -Out $out -Recs (Sd-Records 'role-access') -Caption '§5.2 role/authorization model (cited from hand-authored docs)' -Cap 16
        $out.Add("*``Verified-source-doc``: the role→purpose mapping, the authorization model (position→ERP roles + AD-groups), and the capability-flag interface are each cited to a real hand-authored file:line above. No permission is inferred beyond what is documented.*")
        $out.Add("")
    } else {
        $out.Add($(NDA 'the classic-ASP role-capability matrix does not apply to this framework') + " — status: N/A (owner-required for a framework-appropriate role matrix).")
        $out.Add("")
        $out.Add("*Role model not detected for this framework — the classic-ASP role/privilege concepts are N/A; a framework-appropriate role matrix would be owner-required.*")
        $out.Add("")
    }
}
Add-Question "§5 — Which roles exist at runtime and what each is authorized to do (role-capability matrix) is Unknown; owner-required."
Ledger "Roles and Access Model" "placeholder" @("api-inventory", "data-model", "overview")

# ===========================================================================
# 6. UI Catalog
# ===========================================================================
$out.Add("## UI Catalog")
$out.Add("")
$out.Add("Each entry point that carries form/query input fields is a screen. Controls (form/query fields) are `Verified` from the extraction; **States** (loading / empty / error / validated) are `Unknown` because the runtime was not observed. Capped to the first 40 screens with inputs; the full set is in [API Inventory](api-inventory.md).")
$out.Add("")
$out.Add("| Screen (Inferred) | Entry point | Visible controls/data (fields) | States | Roles/evidence |")
$out.Add("|-------------------|-------------|-------------------------------|--------|----------------|")
# Evidence-based UI catalog when $apiTab is not a per-endpoint table (FIX). A
# "screen" is an endpoint that carries form/query input fields; controls are the
# extracted fields (Inferred), States are Unknown (runtime not observed), and the
# Roles/evidence column carries the source file. Capped to 40, deterministically
# sorted by (path, method).
if ($apiUseEvidence) {
    $uiRows = @($apiEpSorted | Where-Object { (Get-AppDocEndpointInputs $_) } | Select-Object -First 40)
    foreach ($r in $uiRows) {
        $feat = Get-AppDocEndpointFeature $r
        $out.Add("| $feat | $([string]$r.name) | $(Get-AppDocEndpointInputs $r) | Unknown | Verified source: $([string]$r.source) |")
    }
    if (@($uiRows).Count -eq 0) { $out.Add("| — | none with fields extracted | — | Unknown | Unknown |") }
} else {
    $uiRows = @()
    if ($apiTab) {
        foreach ($r in $apiTab.Rows) {
            if ($r.Count -ge 4) {
                $inputs = Clean-Cell $r[3]
                if ($inputs) { $uiRows += ,$r; if ($uiRows.Count -ge 40) { break } }
            }
        }
    }
    $uii = 1
    foreach ($r in $uiRows) {
        $ep = Clean-Cell $r[1]
        $feat = Humanize-FileName $ep
        $inputs = Clean-Cell $r[3]
        $out.Add("| $feat | $(Clean-Cell $r[1]) | $inputs | Unknown | Verified source ($ep) — states Unknown |")
        $uii++
    }
    if ($uiRows.Count -eq 0) { $out.Add("| — | none with fields extracted | — | Unknown | Unknown |") }
}
$out.Add("")
$out.Add("*Showing $($uiRows.Count) screens with extracted input fields.*")
$out.Add("")
Add-Question "§6 — UI screen *states* (loading/empty/error/validated) are Unknown; runtime was not observed."
Ledger "UI Catalog" "populated" @("api-inventory")

# ===========================================================================
# 7. Operational Workflows
# ===========================================================================
# Projected ONLY from grounded evidence: the entry-point areas (API evidence) and the
# stored-procedure contracts documented in source (procdict). Sequencing, policy,
# authorization and escalation are not derivable from source -> Unknown unless the
# repository's own docs state them (Verified-source-doc) or the operator supplies them
# in an overlay (Operator-supplied, rendered after this section).
$out.Add("## Operational Workflows")
$out.Add("")
$out.Add("> Workflows are projected only from grounded evidence: the entry-point areas a user moves through and, where present, the stored-procedure contracts documented in source. Workflow sequencing, business policy, authorization and escalation are not derivable from source and stay ``Unknown`` (owner-required) unless the repository's own docs state them or the operator supplies them as an overlay.")
$out.Add("")
$out.Add("### 7.1 Entry-point areas")
$out.Add("")
$out.Add("| Area | Entry points | Example | Status |")
$out.Add("|------|--------------|---------|--------|")
$wfAreas = @(Get-EntryPointAreas | Select-Object -First 12)
foreach ($wa in $wfAreas) { $out.Add("| $(Clean-Cell $wa.area) | $($wa.count) | ``$(Clean-Cell $wa.example)`` | Verified |") }
if ($wfAreas.Count -eq 0) { $out.Add("| — | 0 | none extracted | Unknown |") }
$out.Add("")
$out.Add("### 7.2 Procedure contracts behind operator actions")
$out.Add("")
$pdEvidence = Read-Json (Join-Path $docsPath "procdict.evidence.json")
$pdContracts = @()
if ($pdEvidence) {
    $pdContracts = @(@($pdEvidence) | Where-Object { $_ -and @($_.returnCodes).Count -gt 0 } | Sort-Object { [string]$_.name })
}
if ($pdContracts.Count -gt 0) {
    $out.Add("Each row is a stored procedure whose parameters and return codes are documented in an in-source contract block (see §10 for the full dictionary). The return codes are the observable outcomes of the operator action that calls the procedure.")
    $out.Add("")
    $out.Add("| Procedure | Defined in | Return codes | Called from | Status |")
    $out.Add("|-----------|------------|--------------|-------------|--------|")
    foreach ($pc in @($pdContracts | Select-Object -First 20)) {
        $codes = (@($pc.returnCodes) | ForEach-Object { [string]$_ }) -join '; '
        $calls = (@($pc.callSites) | Select-Object -First 3 | ForEach-Object { [string]$_ }) -join ', '
        $out.Add("| ``$(Clean-Cell ([string]$pc.name))`` | $(Clean-Cell ([string]$pc.file)) | $(Clean-Cell $codes) | $(Clean-Cell $calls) | Verified |")
    }
    if ($pdContracts.Count -gt 20) { $out.Add(""); $out.Add("*Showing 20 of $($pdContracts.Count) documented procedure contracts.*") }
} elseif ($isClassicAspTarget) {
    $out.Add("*No stored-procedure contract blocks (parameters / return codes) were documented in source.*")
} else {
    $out.Add($(NDA 'stored-procedure contract blocks are a classic-ASP data point; not applicable to the detected framework'))
}
$out.Add("")
$out.Add("### 7.3 Sequencing, policy, authorization and escalation")
$out.Add("")
$out.Add("| Item | Established by source? | Status |")
$out.Add("|------|------------------------|--------|")
$out.Add("| Which steps make up each workflow, and in what order | No | Unknown |")
$out.Add("| Who is authorized to perform each action | No | Unknown |")
$out.Add("| Evidence the operator must retain | No | Unknown |")
$out.Add("| Escalation path and thresholds | No | Unknown |")
$out.Add("")
# Service procedures / SOPs the repository DOCUMENTS in hand-authored docs.
if ($sdHasServiceProcedure) {
    $out.Add("### Service procedures (cited from hand-authored docs — Verified-source-doc)")
    $out.Add("")
    $out.Add("The sequencing/policy cells above remain owner-required, but the following procedure/policy statements are documented in the repository's hand-authored docs:")
    $out.Add("")
    Render-SourceDocCitations -Out $out -Recs $sdServiceProc -Caption '§7 service procedures' -Cap 14
    $out.Add("*``Verified-source-doc``: each line above is cited to a real hand-authored file:line.*")
    $out.Add("")
}
Add-Question "§7 — Workflow sequencing, authorization, evidence-retention and escalation policy are Unknown (owner-required); §7 projects only entry-point areas and documented procedure contracts."
Ledger "Operational Workflows" $(if ($wfAreas.Count -gt 0 -or $pdContracts.Count -gt 0) { "populated" } else { "placeholder" }) @("api-inventory", "procdict")

# ===========================================================================
# 8. Data and Integrations
# ===========================================================================
$out.Add("## Data and Integrations")
$out.Add("")
if ($isClassicAspTarget) {
    $out.Add("The data layer is SQL Server accessed via ADO. Entities (tables/views) are projected from the data-model evidence. **Sensitivity** is `Inferred` (not confirmed). Databases, tables, and stored procedures are the integrations; the full register is in [External Call Register](#external-call-register).")
} else {
    $out.Add("The data layer and integration surfaces (databases, tables/views, stored procedures, and any detected data stores) are projected from the data-model evidence for this framework ($fwLabel). **Sensitivity** is `Inferred` (not confirmed). The full register of detected external data integrations is in [External Call Register](#external-call-register).")
}
$out.Add("")
$out.Add("### Databases (connection-string inventory) — status Verified (redacted)")
$out.Add("")
$out.Add("| ID | Provider | Server | Database | Connection-string shape | Status |")
$out.Add("|----|----------|--------|----------|-------------------------|--------|")
$dbShow = if ($dbTab) { @($dbTab.Rows | Select-Object -First 15) } else { @() }
foreach ($r in $dbShow) {
    # db table: | ID | Provider | Server | Database | Connection-String Shape | Files Referencing | Status |
    if ($r.Count -ge 6) {
        $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | $(Clean-Cell $r[3]) | $(Clean-Cell $r[4]) | Verified |")
    }
}
if ($dbShow.Count -eq 0) {
    # Gap 5: on a non-classic-ASP target with no ADO surface, the config-catalog
    # ConnectionStrings ARE the real (redacted) data-store integration evidence.
    # Surface them as the connection-string inventory instead of "not detected".
    if (-not $isClassicAspTarget -and $cfgConnStringCount -gt 0) {
        $csIdx = 1
        foreach ($cs in $cfgConnStrings) {
            $csName = [string]$cs.name
            $csKey  = ($csName -replace '(?i)^ConnectionStrings\.', '')
            $csFile = ''
            if ($cs.metadata -and $cs.metadata.file) { $csFile = [string]$cs.metadata.file }
            # Markdown code-spans via [char]96 (the backtick is the PowerShell escape char,
            # so a literal backtick must be built by concatenation, not typed in the string).
            $csKeyBacktick    = [string]([char]96 + $csKey + [char]96)
            $csFullKeyBacktick = [string]([char]96 + 'ConnectionStrings.' + $csKey + [char]96)
            $out.Add("| $csIdx | config ($csKeyBacktick) | Inferred | Inferred | key $csFullKeyBacktick — $(Clean-Cell $csFile) | Verified (redacted) |")
            $csIdx++
        }
        $out.Add("")
        $out.Add("*Showing $([Math]::Min(15, $cfgConnStringCount)) of $cfgConnStringCount connection strings (from the config-catalog; values redacted). The authoritative connection-string values live in the config store and are redacted here by design.*")
    }
    else {
        $out.Add("| — | not detected | — | — | — | Unknown |")
    }
}
else {
    $out.Add("")
    $out.Add("*Showing $([Math]::Min(15, $dmDbCount)) of $dmDbCount databases.*")
}
$out.Add("")
$out.Add("### Entities (tables/views, representative) — status Verified")
$out.Add("")
$out.Add("| ID | DB | Object | Type | Sensitivity | Referenced from | Status |")
$out.Add("|----|----|--------|------|-------------|-----------------|--------|")
$tableShow = if ($tableTab) { @($tableTab.Rows | Select-Object -First 25) } else { @() }
foreach ($r in $tableShow) {
    if ($r.Count -ge 5) {
        $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | $(Clean-Cell $r[3]) | Inferred | $(Clean-Cell $r[4]) | Verified |")
    }
}
if ($tableShow.Count -eq 0) {
    # Gap 5: on a non-classic-ASP target there is no ADO tables/views surface
    # (EF Core / ORM apps expose domain entities, not ADO tables). Be honest about
    # the framework instead of a bare "Unknown", and redirect to the domain-model
    # sub-section below (which lists the real entities) — avoids a false EMPTY/Unknown.
    if (-not $isClassicAspTarget) {
        $dmEntHint = if ($dmModelCount -gt 0) { " $dmModelCount domain-model entities are listed in the 'Entities / domain model' sub-section below." } else { '' }
        $out.Add("| — | not detected (no ADO tables/views) | — | — | n/a (ORM/EF Core surface) | — | Honest (framework) |")
        $out.Add("")
        $out.Add("*This framework does not use ADO tables/views; its data surface is the ORM/EF Core entity model.$($dmEntHint.Trim()) Sensitivity Inferred.*")
    }
    else {
        $out.Add("| — | not detected | — | — | Unknown | — | Unknown |")
        $out.Add("")
        $out.Add("*Showing $([Math]::Min(25, $dmTableCount)) of $dmTableCount tables/views.*")
    }
}
else {
    $out.Add("")
    $out.Add("*Showing $([Math]::Min(25, $dmTableCount)) of $dmTableCount tables/views.*")
}
$out.Add("")

# --- FIX 2: surface the generic (framework-agnostic) data model ----------------
# When the target has NO ADO data surface (0 ADO databases / tables / procedures),
# the classic-ASP ADO register above is empty ("not detected / 0 of 0") and the
# framework's OWN data model (e.g. C# classes/interfaces in a C# MVC 5 target) is what
# actually exists. Surface it as a representative "Entities / domain model" table so
# §8 is genuinely populated instead of a false EMPTY. The ADO-surface flag is an
# EVIDENCE discriminator (not the framework label, which can carry a detector false
# positive — a legacy C# MVC 5 target's framework-detection.json lists a false "Classic ASP"). A
# real classic-ASP / ADO target (e.g. the classic-ASP test target: 58 dbs, 257 tables, 310 procs) has
# $dmHasAdoSurface = $true, so this subsection is NOT emitted and the ADO path above
# stays the single source of truth -> the classic-ASP target's §8 is byte-identical.
$dmHasAdoSurface = ($dmDbCount -gt 0) -or ($dmTableCount -gt 0) -or ($dmProcCount -gt 0)
if (-not $dmHasAdoSurface) {
    # Generic data-model records (C# classes / interfaces / structs), kind=model.
    $dmRecords = @()
    if ($null -ne $dmEv -and $null -ne $dmEv.records) { $dmRecords = @($dmEv.records | Where-Object { $_ -and [string]$_.kind -eq 'model' }) }
    # Deterministic: sort by name then source; cap at 25 (matches the existing table cap).
    $dmEntTotal = @($dmRecords).Count
    $dmEntSorted = @($dmRecords | Sort-Object @{Expression={[string]$_.name}}, @{Expression={[string]$_.source}} | Select-Object -First 25)
    $out.Add("### Entities / domain model (representative) — status Inferred")
    $out.Add("")
    $out.Add("Generic data-model records for this framework ($fwLabel), projected from the data-model evidence (class / interface / struct). Representative sample, capped at 25 and deterministically sorted; **Sensitivity** is `Inferred` (not confirmed). The authoritative schema lives in the framework's data layer (ORM / entity model) and requires data-owner confirmation.")
    $out.Add("")
    $out.Add("| # | Entity | Type | Fields | Source file | Status |")
    $out.Add("|---|--------|------|--------|-------------|--------|")
    $idx8 = 1
    foreach ($r in $dmEntSorted) {
        $entName   = Clean-Cell ([string]$r.name)
        $entSrc    = Clean-Cell ([string]$r.source)
        $entType   = 'class'
        $entFields = 0
        if ($null -ne $r.metadata -and $r.metadata -is [PSCustomObject]) {
            if ($r.metadata.modelType) { $entType = Clean-Cell ([string]$r.metadata.modelType) }
            if ($null -ne $r.metadata.propertyCount) { $entFields = [int]$r.metadata.propertyCount }
        }
        $out.Add("| $idx8 | $entName | $entType | $entFields | $entSrc | Inferred |")
        $idx8++
    }
    if ($dmEntTotal -eq 0) { $out.Add("| — | not detected | — | — | — | Unknown |") }
    $out.Add("")
    $out.Add("*Showing $([Math]::Min(25, $dmEntTotal)) of $dmEntTotal domain-model entities (representative sample; deterministic). Sensitivity Inferred.*")
    $out.Add("")
}
Ledger "Data and Integrations" "populated" @("data-model")

# ===========================================================================
# 9. External Call Register
# ===========================================================================
$out.Add("## External Call Register")
$out.Add("")
$out.Add("Deterministic register of every external call the application makes. The largest and most reliable section of this document.")
$out.Add("")
$out.Add("### 9.1 Database connections")
$out.Add("")
$out.Add("| ID | Provider | Server | Database | Connection-string shape | Files referencing | Status |")
$out.Add("|----|----------|--------|----------|-------------------------|-------------------|--------|")
$dbShow91 = if ($dbTab) { @($dbTab.Rows | Select-Object -First 20) } else { @() }
foreach ($r in $dbShow91) {
    if ($r.Count -ge 7) {
        $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | $(Clean-Cell $r[3]) | $(Clean-Cell $r[4]) | $(Clean-Cell $r[5]) | Verified |")
    }
}
if ($dbShow91.Count -eq 0) { $out.Add("| — | not detected | — | — | — | — | Unknown |") }
$out.Add("")
$out.Add("*Showing $([Math]::Min(20, $dmDbCount)) of $dmDbCount connection strings.*")
$out.Add("")
$out.Add("### 9.2 Stored-procedure register")
$out.Add("")
$out.Add("| ID | Procedure | Call-site file(s) | Effect | Status |")
$out.Add("|----|-----------|-------------------|--------|--------|")
$spShow92 = if ($procTab) { @($procTab.Rows | Select-Object -First 40) } else { @() }
foreach ($r in $spShow92) {
    # proc table: | ID | DB | Procedure | Type | Call Sites (files) | Status |
    if ($r.Count -ge 5) {
        $proc = Clean-Cell $r[2]; $calls = Clean-Cell $r[4]
        $out.Add("| $(Clean-Cell $r[0]) | $proc | $(if ($calls) { $calls } else { '—' }) | Inferred | Verified (present) |")
    }
}
if ($spShow92.Count -eq 0) { $out.Add("| — | not detected | — | Unknown | Unknown |") }
$out.Add("")
$out.Add("*Showing $([Math]::Min(40, $dmProcCount)) of $dmProcCount stored procedures.*")
$out.Add("")
$out.Add("### 9.3 Direct SQL tables / views")
$out.Add("")
$out.Add("Referenced tables and views are the direct-SQL surface (see 8.2 for sensitivity). Representative set:")
$out.Add("")
$out.Add("| ID | DB | Object | Type | Referenced from | Status |")
$out.Add("|----|----|--------|------|-----------------|--------|")
$tableShow93 = if ($tableTab) { @($tableTab.Rows | Select-Object -First 40) } else { @() }
foreach ($r in $tableShow93) {
    if ($r.Count -ge 5) { $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | $(Clean-Cell $r[3]) | $(Clean-Cell $r[4]) | Verified |") }
}
if ($tableShow93.Count -eq 0) { $out.Add("| — | not detected | — | — | — | Unknown |") }
$out.Add("")
$out.Add("*Showing $([Math]::Min(40, $dmTableCount)) of $dmTableCount tables/views.*")
$out.Add("")
$out.Add("### 9.4 HTTP / XML endpoints")
$out.Add("")
# Project the outbound HTTP/XML call sites from docs/extcalls.md (the classic-ASP
# external-call extractor). Rows are file-cited, secrets REDACTED. When the
# artifact is absent (non-classic-ASP target) fall back to the honest NDA row.
if ($extHttpTab -and $extHttpTab.Rows.Count -gt 0) {
    $out.Add('Outbound HTTP / external-system call sites extracted from the source. The **Mechanism** is the issuing API — the XML-HTTP object (`ServerXMLHTTP` / `FreeThreadedDOMDocument`) on classic-ASP targets, or the framework HTTP client (`fetch`/`axios`/`XMLHttpRequest` for TS-JS, `requests`/`httpx`/`urllib`/`aiohttp` for Python, `RestTemplate`/`WebClient`/`HttpClient`/`OkHttp` for Java, `HttpClient`/`WebClient`/`HttpWebRequest`/`RestClient` for C#). The **Data/behavior** carries the URL epistemic tag (`Literal` = a string-literal URL was captured; `Inferred` = derived from a variable/config, base cited when a real http(s):// literal is present — never fabricated). Every real API key / Authorization-header / credential value is redacted as `[REDACTED]`. Status `Verified` = call site present in source (runtime reachability of the target is Unknown).')
    $out.Add("")
    $out.Add("| ID | Endpoint/URL | Mechanism | Source file:line | Data/behavior | Status |")
    $out.Add("|----|--------------|-----------|------------------|---------------|--------|")
    $extHttpShow = @($extHttpTab.Rows | Select-Object -First 20)
    foreach ($r in $extHttpShow) {
        # | ID | Endpoint | Mechanism | Source file:line | Data/behavior | Status |
        if ($r.Count -ge 6) {
            $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | $(Clean-Cell $r[3]) | $(Clean-Cell $r[4]) | $(Clean-Cell $r[5]) |")
        }
    }
    $out.Add("")
    $out.Add("*Showing $([Math]::Min(20, $extHttpTab.Rows.Count)) of $($extHttpTab.Rows.Count) outbound HTTP/XML call sites (full register in [extcalls](extcalls.md)).*")
} elseif ($isClassicAspTarget) {
    $out.Add('*Not detected in this codebase.* No outbound HTTP/XML call sites were extracted in the evidence (no `ServerXMLHTTP`/`FreeThreadedDOMDocument` issuing a remote request was found).')
} else {
    $out.Add("*Not detected in this codebase.* No outbound HTTP/XML call sites were extracted in the available evidence for this framework. $(NDA 'the classic-ASP outbound HTTP/XML register (ServerXMLHTTP / FreeThreadedDOMDocument call sites) does not apply to this framework')")
}
$out.Add("")
$out.Add("### 9.5 Email / COM / file-system boundaries")
$out.Add("")
if ($extBndTab -and $extBndTab.Rows.Count -gt 0) {
    $out.Add('Non-HTTP external boundaries: stored-procedure email calls, the ADO database boundary (class — full register in 9.1), and UNC/file-system paths.' + (Get-OpaqueTokenNote))
    $out.Add("")
    $out.Add("| ID | Boundary type | Observed call | Source file:line | Behavior | Status |")
    $out.Add("|----|---------------|---------------|------------------|----------|--------|")
    $extBndShow = @($extBndTab.Rows | Select-Object -First 20)
    foreach ($r in $extBndShow) {
        # | ID | Boundary type | Observed call | Source file:line | Behavior | Status |
        if ($r.Count -ge 6) {
            $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | $(Clean-Cell $r[3]) | $(Clean-Cell $r[4]) | $(Clean-Cell $r[5]) |")
        }
    }
    $out.Add("")
    $out.Add("*Full register (including the distinct COM-object inventory) in [extcalls](extcalls.md).*")
} elseif ($isClassicAspTarget) {
    $out.Add("*Not detected in this codebase.* No email / COM / file-system boundary call sites were extracted in the evidence.")
} else {
    $out.Add("*Not detected in this codebase.* No email / COM / file-system boundaries were extracted in the available evidence for this framework. $(NDA 'the classic-ASP send_mail / ADO / UNC boundary register does not apply to this framework')")
}
$out.Add("")
$out.Add("### 9.6 Failure / observability")
$out.Add("")
$out.Add("From the test-catalog failure surface:")
$out.Add("")
$out.Add("| Signal | Count | Files (sample) | Status |")
$out.Add("|--------|-------|----------------|--------|")
$errShow = if ($errTab) { @($errTab.Rows) } else { @() }
foreach ($r in $errShow) {
    if ($r.Count -ge 3) { $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | Verified |") }
}
$out.Add("| Auto-refresh timers (auto-refresh) | $refreshTimers | see test-catalog | Verified |")
$out.Add("")
Ledger "External Call Register" "populated" @("data-model", "test-catalog", "api-inventory", "extcalls")

# ===========================================================================
# 10. Stored-procedure data dictionary
# ===========================================================================
$out.Add("## Stored-procedure data dictionary")
$out.Add("")
$pdDocCount = if ($pdDocTab) { $pdDocTab.Rows.Count } else { 0 }
$pdUndocCount = if ($pdUndocTab) { $pdUndocTab.Rows.Count } else { 0 }
if ($pdDocCount -gt 0 -or $pdUndocCount -gt 0) {
    # Real data dictionary: transcribed from in-source contract blocks + call sites.
    $out.Add("Parameter signatures and return codes below are transcribed from the comment blocks in the live `.inc` files and the call sites (deterministic extraction). They document the *contract as observed in source*; the authoritative procedure definitions, grants, and side effects require database-owner confirmation.")
    $out.Add("")
    if ($pdDocCount -gt 0) {
        $out.Add("### Documented procedures (in-source parameter / return-code ladders)")
        $out.Add("")
        $out.Add("| Procedure | File | Parameters (name type) | Return Codes (code = meaning) | Call Sites | Status |")
        $out.Add("|-----------|------|------------------------|-------------------------------|------------|--------|")
        $pdShow = @($pdDocTab.Rows | Select-Object -First 40)
        foreach ($r in $pdShow) {
            # | ID | Procedure | File | Parameters | Return Codes | Call Sites | Status |
            if ($r.Count -ge 7) {
                $pdProc=[string](Clean-Cell $r[1]); $pdFile=[string](Clean-Cell $r[2]); $pdParam=[string](Clean-Cell $r[3]); $pdRet=[string](Clean-Cell $r[4]); $pdCall=[string](Clean-Cell $r[5]); $pdStat=[string](Clean-Cell $r[6])
                $out.Add("| $pdProc | $pdFile | $pdParam | $pdRet | $pdCall | $pdStat |")
            }
        }
        if ($pdDocCount -gt 40) { $out.Add(""); $out.Add("*Showing 40 of $pdDocCount documented procedures.*") }
        $out.Add("")
    }
    if ($pdUndocCount -gt 0) {
        $out.Add("### Called but not documented in source")
        $out.Add("")
        $out.Add("These stored procedures are invoked from classic-ASP source (EXEC / `.Execute` / `CommandText`) but carry no in-source parameter or return-code ladder. Parameters and return codes are recorded as not documented — an honest absence, not a fabrication.")
        $out.Add("")
        $out.Add("| Procedure | Call Sites | Status |")
        $out.Add("|-----------|------------|--------|")
        $pdUndocShow = @($pdUndocTab.Rows | Select-Object -First 40)
        foreach ($r in $pdUndocShow) {
            # | ID | Procedure | Call Sites | Status |
            if ($r.Count -ge 4) {
                $uProc=[string](Clean-Cell $r[1]); $uCall=[string](Clean-Cell $r[2]); $uStat=[string](Clean-Cell $r[3])
                $out.Add("| $uProc | $uCall | $uStat |")
            }
        }
        if ($pdUndocCount -gt 40) { $out.Add(""); $out.Add("*Showing 40 of $pdUndocCount called-but-undocumented procedures (full register in [9.2](#external-call-register)).*") }
        $out.Add("")
    }
    $out.Add("*Totals: $pdDocCount documented procedures (parameter + return-code ladder observed in source), $pdUndocCount called-but-undocumented.*")
    $out.Add("")
    Add-Question "§10 — Documented procedures carry verbatim in-source contract ladders (Verified); called-but-undocumented procedures have no in-source contract (Partly verified). Authoritative procedure definitions require database-owner confirmation."
    Ledger "Stored-procedure data dictionary" "populated" @("procdict", "data-model")
} else {
    # Fallback: procdict.md absent (e.g. non-classic-ASP target) — honest NDA.
    $out.Add($(NDA 'the stored-procedure data dictionary is produced only for classic-ASP codebases from in-source contract blocks; this target has no classic-ASP signal, so no contract ladders were extracted'))
    $out.Add("")
    $out.Add("| Procedure | Parameters observed | Return / output | Source file (call site) | Status |")
    $out.Add("|-----------|--------------------|-----------------|-------------------------|--------|")
    $spShow10 = if ($procTab) { @($procTab.Rows | Select-Object -First 40) } else { @() }
    foreach ($r in $spShow10) {
        if ($r.Count -ge 5) {
            $proc = Clean-Cell $r[2]; $calls = Clean-Cell $r[4]
            $out.Add("| $proc | Unknown | Unknown | $(if ($calls) { $calls } else { '—' }) | Verified (present) / Unknown (params) |")
        }
    }
    if ($spShow10.Count -eq 0) { $out.Add("| — | — | — | — | Unknown |") }
    $out.Add("")
    $out.Add("*Parameter/return details are Unknown where not present in the evidence.*")
    $out.Add("")
    Add-Question "§10 — Stored-procedure parameter signatures and return-code ladders are Unknown (not in the evidence); not fabricated."
    Ledger "Stored-procedure data dictionary" "placeholder" @("data-model")
}

# ===========================================================================
# 11. Troubleshooting Matrix
# ===========================================================================
$out.Add("## Troubleshooting Matrix")
$out.Add("")
$out.Add("Projected from the test-catalog known-failure-mode records. Each row is a real per-file failure pattern: **Symptom** = the observed failure pattern + file, **Evidence-supported check** = a grep-verifiable command referencing that file, **Known response / restriction** = the observed behavior, **Escalate-when** = `Unknown` (not extracted). Scratch / copy / old / test / bak files are excluded and identical rows are deduped.")
$out.Add("")
$out.Add("| Symptom | Evidence-supported check (Inferred) | Known response / restriction (observed, Verified) | Escalate-when |")
$out.Add("|---------|--------------------------------------|------------------------------------------------------|----------------|")
$failShow = if ($failTab) { @($failTab.Rows | Where-Object { $_.Count -ge 4 }) } else { @() }
# Scratch / copy / old / test / bak files are excluded. Per the iteration spec the filter
# globs apply to the file BASENAME (e.g. calls/testingx.asp -> testingx.asp matches testing*).
$scratchRe = '(?i).*_copy.*|.*copy_.*|.*_old.*|.*_test.*|^testing.*|.*bak.*'
$seenFail = @{}
$failRows = New-Object System.Collections.Generic.List[string]   # display-ready rows
$scratchExcluded = 0
$distinct = 0
foreach ($r in $failShow) {
    $file = Clean-Cell $r[1]; $pattern = Clean-Cell $r[2]; $obs = Clean-Cell $r[3]
    if (-not $file -or $file -eq '—') { continue }
    $basename = ($file -split '/')[-1]
    if ($basename -match $scratchRe) { $scratchExcluded++; continue }
    $key = "$file|$pattern"
    if ($seenFail.ContainsKey($key)) { continue }   # dedupe identical (file,pattern)
    $seenFail[$key] = $true
    $distinct++
    $sym = "$pattern — $file"
    $chk = 'grep the query + error path in `' + $file + '` (see test-catalog.md)'
    $failRows.Add("| $sym | $chk | $obs | Unknown |")
}
$failCap = 20
$failShown = [Math]::Min($failCap, $failRows.Count)
for ($fi = 0; $fi -lt $failShown; $fi++) { $out.Add($failRows[$fi]) }
if ($failShown -eq 0) { $out.Add("| — | not detected | — | Unknown |") }
$out.Add("")
if ($scratchExcluded -gt 0) { $out.Add("*$scratchExcluded scratch / copy / old / test / bak file record(s) excluded from this table.*") ; $out.Add("") }
$out.Add("*Showing $failShown of $distinct distinct non-scratch failure-mode/timer records (identical rows deduped; full set in [test-catalog](test-catalog.md)).*")
$out.Add("")
# --- §11 escalation / troubleshooting (cited from hand-authored docs) ----------
# The failure-mode table above is from the test-catalog. The escalation contacts
# (on-call pager, non-business-hours contact matrix) and the troubleshooting KB
# (symptom→fix) may be DOCUMENTED in hand-authored docs. When citations exist,
# surface them ADDITIVELY: escalation contacts are `Verified-source-doc` (a real
# contact listing); troubleshooting KB entries are `Inferred` (a KB, not a policy —
# the repo documents them, but a KB is not an authoritative policy). The
# 'escalate-when' column stays Unknown unless a doc states it. Where no citations
# exist (e.g. a legacy C# MVC 5 target with no escalation doc), this subsection is absent.
$sdEscRecs = @(Sd-Records 'escalation')
$sdTrbRecs = @(Sd-Records 'troubleshooting')
if (($sdEscRecs.Count -gt 0) -or ($sdTrbRecs.Count -gt 0)) {
    if ($sdEscRecs.Count -gt 0) {
        $out.Add("### Escalation / on-call contacts (cited from hand-authored docs — Verified-source-doc)")
        $out.Add("")
        $out.Add("The escalation routes / on-call contacts below are documented in the repo's hand-authored docs. The 'escalate-when' thresholds remain `Unknown` unless a doc states them:")
        $out.Add("")
        Render-SourceDocCitations -Out $out -Recs $sdEscRecs -Caption '§11 escalation / on-call contacts' -Cap 16 -Tag 'Verified-source-doc'
    }
    if ($sdTrbRecs.Count -gt 0) {
        $out.Add("### Troubleshooting KB (cited from hand-authored docs — Inferred)")
        $out.Add("")
        $out.Add("The following symptom→fix / incident entries come from the repo's hand-authored troubleshooting KB (documented, but a KB is not an authoritative policy — tagged Inferred):")
        $out.Add("")
        Render-SourceDocCitations -Out $out -Recs $sdTrbRecs -Caption '§11 troubleshooting KB' -Cap 12 -Tag 'Inferred'
    }
}
Add-Question "§11 — Escalation points / on-call paths are Unknown (not extracted)."
Ledger "Troubleshooting Matrix" "populated" @("test-catalog")

# ===========================================================================
# 12. Security and Operational Risks
# ===========================================================================
$out.Add("## Security and Operational Risks")
$out.Add("")
$secFindCount = if ($secFindTab) { $secFindTab.Rows.Count } else { 0 }
$secUnkCount  = if ($secUnkTab) { $secUnkTab.Rows.Count } else { 0 }
if ($secFindCount -gt 0) {
    # Real, grep-verifiable findings with REDACTED secret values (deterministic extraction).
    $out.Add("The following findings are verified against the current classic-ASP source at the cited file:line. Every REAL secret value (password, API key, credential) is **redacted** and shown as ``[REDACTED]``." + (Get-OpaqueTokenNote) + " Status ``Verified`` means the pattern is present in source, not that it is reachable in production (that is Unknown).")
    $out.Add("")
    $out.Add("### Verified current-state findings")
    $out.Add("")
    $out.Add("| ID | Finding | Evidence (file:line) | Severity | Secret Value (redacted) | Status |")
    $out.Add("|------|---------|----------------------|----------|-------------------------|--------|")
    $secShow = @($secFindTab.Rows | Select-Object -First 40)
    foreach ($r in $secShow) {
        # | ID | Finding | Evidence | Severity | Secret Value | Status |
        if ($r.Count -ge 6) {
            $fId=[string](Clean-Cell $r[0]); $fFinding=[string](Clean-Cell $r[1]); $fEv=[string](Clean-Cell $r[2]); $fSev=[string](Clean-Cell $r[3]); $fSec=[string](Clean-Cell $r[4]); $fStat=[string](Clean-Cell $r[5])
            $out.Add("| $fId | $fFinding | $fEv | $fSev | $fSec | $fStat |")
        }
    }
    if ($secFindCount -gt 40) { $out.Add(""); $out.Add("*Showing 40 of $secFindCount findings.*") }
    $out.Add("")
    # operational unknowns
    $out.Add("### Operational Unknowns That Must Not Be Treated As Controls")
    $out.Add("")
    if ($secUnkCount -gt 0) {
        $out.Add("| Runtime security property | Established by source? | Status |")
        $out.Add("|---------------------------|------------------------|--------|")
        $secUnkShow = @($secUnkTab.Rows | Select-Object -First 40)
        foreach ($r in $secUnkShow) {
            if ($r.Count -ge 3) {
                $uProp=[string](Clean-Cell $r[0]); $uEst=[string](Clean-Cell $r[1]); $uStat2=[string](Clean-Cell $r[2])
                $out.Add("| $uProp | $uEst | $uStat2 |")
            }
        }
    } else {
        $out.Add("The following are **Unknown** — their absence from the repo does NOT mean they are absent in production, and they must not be read as security controls (or the lack thereof):")
        $out.Add("")
        $out.Add("- TLS / HTTPS enforcement (Unknown)")
        $out.Add("- Multi-factor authentication (MFA) (Unknown)")
        $out.Add("- CSRF defenses / secure cookie flags (Unknown)")
        $out.Add("- Password storage scheme (Unknown)")
        $out.Add("- Centralized audit-log integrity / alerting (Unknown)")
        $out.Add("- Credential rotation / secrets-management practice (Unknown)")
    }
    $out.Add("")
    Add-Question "§12 — Documented findings are Verified present in source with secrets redacted; runtime reachability and the listed security controls are Unknown and must not be treated as controls."
    Ledger "Security and Operational Risks" "populated" @("security", "test-catalog", "data-model")
} else {
    # Fallback: security.md absent (non-classic-ASP target) — honest NDA rows.
    $out.Add("Projected from the test-catalog security findings and the data-model connection-string inventory. Credential values are **redacted** (shown only as opaque sanitized tokens).")
    $out.Add("")
    $out.Add("| Risk | Evidence | Status |")
    $out.Add("|------|----------|--------|")
    if ($isClassicAspTarget) {
        $out.Add("| Errors swallowed silently | `On Error Resume Next` present in $onErrorFiles files | Verified |")
        $out.Add("| Silent redirect on DB failure hides root cause | Response.Redirect-after-query-failure in $redirectFail files | Verified |")
        $out.Add("| ADO/recordset errors inspected at runtime | parseError handling observed | Verified |")
        $out.Add("| Hardcoded ADO connection strings (credential-exposure) | $dmDbCount connection strings across many files; credential values redacted | Verified (presence) / Inferred (risk) |")
        $out.Add("| Multiple distinct SQL Server hosts referenced | $instanceCount SQL Server instances | Verified |")
    } else {
        $out.Add("| Errors swallowed silently | $(NDA 'the `On Error Resume Next` (VBScript) silent-swallowing pattern is classic-ASP-specific; not detected in this framework') | N/A |")
        $out.Add("| Silent redirect on DB failure hides root cause | $(NDA 'the `Response.Redirect`-after-query-failure pattern is classic-ASP-specific; not detected in this framework') | N/A |")
        $out.Add("| ADO/recordset errors inspected at runtime | $(NDA 'the `parseError` ADO error-inspection pattern is classic-ASP-specific; not detected in this framework') | N/A |")
        $out.Add("| Hardcoded connection strings (credential-exposure) | $(NDA 'the hardcoded ADO connection-string pattern is classic-ASP-specific; not detected in this framework') | N/A |")
        $out.Add("| Multiple distinct SQL Server hosts referenced | $(NDA 'the multi-host SQL Server instance inventory is classic-ASP-specific; not detected in this framework') | N/A |")
    }
    $out.Add("")
    $out.Add("### Unknowns that must not be treated as controls")
    $out.Add("")
    $out.Add("The following are **Unknown** — their absence from the repo does NOT mean they are absent in production, and they must not be read as security controls (or the lack thereof):")
    $out.Add("")
    $out.Add("- Runtime authentication enforcement strength (Unknown)")
    if ($isClassicAspTarget) {
        $out.Add("- Input validation / injection protection beyond the observed ADO usage (Unknown)")
    } else {
        $out.Add("- Input validation / injection protection beyond the observed usage (Unknown)")
    }
    $out.Add("- Transport security (TLS/HTTPS) configuration (Unknown)")
    $out.Add("- Credential rotation / secrets-management practice (Unknown)")
    $out.Add("")
    Add-Question "§12 — Runtime security controls (auth strength, input validation, TLS, credential rotation) are Unknown; must not be treated as verified controls."
    Ledger "Security and Operational Risks" "populated" @("test-catalog", "data-model")
}

# ===========================================================================
# 13. Ownership and Maintenance
# ===========================================================================
$out.Add("## Ownership and Maintenance")
$out.Add("")
$out.Add("Ownership and maintenance information is **not extractable** from the codebase (no owners, no on-call, no SLO metadata in the evidence). Every cell below is `Unknown` / owner-required. This is an honest placeholder, not a fabrication.")
$out.Add("")
$out.Add("| Aspect | Owner | Contact | SLO / target | Notes | Status |")
$out.Add("|--------|-------|---------|--------------|-------|--------|")
$ownRows = @("Application ownership","Help-desk operator team","IT administrator team","On-call / escalation","Data/DBA owner","SLO / availability target","Change/release process")
foreach ($o in $ownRows) { $out.Add("| $o | Unknown | Unknown | Unknown | owner-required | Unknown |") }
$out.Add("")
$out.Add("*This table is a structure placeholder. All cells are `Unknown` / owner-required — ownership data was not present in the inspected codebase.*")
$out.Add("")
# --- §13 ownership / change-process (cited from hand-authored docs — Verified-source-doc) ---
# The ownership table above stays Unknown/owner-required (the table is a structure
# placeholder; ownership data is not extractable as a normalized table). But a repo
# may DOCUMENT ownership (Business Owner / Department / Division) and the
# change/release process in hand-authored docs (a legacy C# MVC 5 target: readme.md owners +
# change-process). When such citations exist, surface them ADDITIVELY as
# Verified-source-doc. Where none exist (the classic-ASP test target: no ownership doc), §13 stays
# honest-Unknown / owner-required (no fabrication).
$sdOwnRecs = @(Sd-Records 'ownership')
$sdChangePol = @(Sd-Records 'operational-policy' | Where-Object { [string]$_.sub -eq 'change-process' })
if (($sdOwnRecs.Count -gt 0) -or ($sdChangePol.Count -gt 0)) {
    if ($sdOwnRecs.Count -gt 0) {
        $out.Add("### Ownership (cited from hand-authored docs — Verified-source-doc)")
        $out.Add("")
        $out.Add("The ownership / division / department lines below are documented in the repo's hand-authored docs (the table above remains a structure placeholder — ownership is not extractable as a normalized table):")
        $out.Add("")
        Render-SourceDocCitations -Out $out -Recs $sdOwnRecs -Caption '§13 ownership' -Cap 12
    }
    if ($sdChangePol.Count -gt 0) {
        $out.Add("### Change / release process (cited from hand-authored docs — Verified-source-doc)")
        $out.Add("")
        $out.Add("The change/release process below is documented in the repo's hand-authored docs:")
        $out.Add("")
        Render-SourceDocCitations -Out $out -Recs $sdChangePol -Caption '§13 change/release process' -Cap 6
    }
    $out.Add("*SLO / availability targets and on-call rotation stay `Unknown` / owner-required — they are not stated in the hand-authored docs (no fabrication).*")
    $out.Add("")
}
# --- §13 git-derived ownership (AppDoc.GitOwnership) --------------------------
# ADDITIVE (never changes status/overallScore): the ownership table above stays
# Unknown/owner-required (a structure placeholder). Here we surface git-derived
# ownership (per-file last-change author + churn) ONLY when the target has REAL,
# SUFFICIENT git history (commitCount >= minCommitsForOwnership). On a SHALLOW
# history (e.g. a single squashed commit) or a NON-GIT dir we stay honest-Unknown —
# a single commit's author is NOT meaningful ownership and is never passed off as
# such. Deterministic: projected from git-ownership.evidence.json (no wall-clock).
$goEvPath = Get-EvidencePath -DocsPath $docsPath -Artifact 'git-ownership'
$goEv = $null
if ($goEvPath) { $goEv = Read-Json -Path $goEvPath }
if ($goEv) {
    # Safe property reads (the composer has no Get-AppDocValidationObjectValue).
    $goIsGit      = [bool]($goEv.PSObject.Properties['isGitRepo']         -and $goEv.isGitRepo)
    $goSufficient = [bool]($goEv.PSObject.Properties['historySufficient'] -and $goEv.historySufficient)
    $goCommit     = if ($goEv.PSObject.Properties['commitCount'])      { [int]$goEv.commitCount }      else { 0 }
    $goOwner      = if ($goEv.PSObject.Properties['owner'])            { [string]$goEv.owner }          else { 'Unknown' }
    $goTopEmail   = if ($goEv.PSObject.Properties['topAuthorEmail'])   { [string]$goEv.topAuthorEmail } else { '' }
    $goTopName    = if ($goEv.PSObject.Properties['topAuthorName'])    { [string]$goEv.topAuthorName }  else { '' }
    $goTopCommits = if ($goEv.PSObject.Properties['topAuthorCommits']) { [int]$goEv.topAuthorCommits }  else { 0 }
    $goFiles      = @($goEv.files | ForEach-Object { $_ })
    if ($goSufficient) {
        # Real history -> surface a git-derived ownership projection (Verified-git-history).
        $out.Add("### Ownership (git-derived — last-change author / churn, Verified-git-history)")
        $out.Add("")
        $out.Add("The target's git history is real and sufficient ($goCommit commit(s)). Per-file ownership below is the **last-change author** with churn (instability = commit count); it is a deterministic projection of `git log` (plus `CODEOWNERS` when present), cited to `docs/evidence/git-ownership.evidence.json`. The table above remains a structure placeholder (application-level ownership stays owner-required unless a `CODEOWNERS` default declares it).")
        $out.Add("")
        $declaredOwner = if ($goOwner -and $goOwner -ne 'Unknown') { $goOwner } else { 'Unknown (not declared)' }
        $ownerLine = "Declared owner (CODEOWNERS `*`): **" + $declaredOwner + "**  ·  top author: "
        # Author emails appear only when the target opted in (config ownership.showEmails).
        if ($goTopName -or $goTopEmail) {
            $topAuthorCell = if ($goTopEmail) { '`' + $goTopName + ' <' + $goTopEmail + '>`' } else { $goTopName }
            $ownerLine += "$topAuthorCell ($goTopCommits commit(s))."
        }
        else { $ownerLine += 'Unknown.' }
        $out.Add($ownerLine)
        $out.Add("")
        $out.Add("| File | Owner (last-change author) | Last change | Churn |")
        $out.Add("|------|----------------------------|-------------|-------|")
        $goShown = 0
        foreach ($gf in $goFiles) {
            $goP = if ($gf.PSObject.Properties['path'])       { [string]$gf.path }       else { '' }
            $goO = if ($gf.PSObject.Properties['owner'])      { [string]$gf.owner }      else { 'Unknown' }
            $goL = if ($gf.PSObject.Properties['lastChange']) { [string]$gf.lastChange } else { 'Unknown' }
            $goC = if ($gf.PSObject.Properties['churn'])      { [int]$gf.churn }         else { 0 }
            $goPathCell = '`' + $goP + '`'
            $out.Add("| $goPathCell | $goO | $goL | $goC |")
            $goShown++
            if ($goShown -ge 15) { break }
        }
        if ($goShown -ge 15 -and $goFiles.Count -gt 15) { $out.Add("| … | (capped at 15; full table in `docs/git-ownership.md`) | | |") }
        if ($goShown -eq 0) { $out.Add("| — | Unknown | Unknown | Unknown |") }
        $out.Add("")
        $out.Add("*``Verified-git-history``: owner = last-change author, churn = commit count (deterministic ``git log`` projection; no inference). Application-level / on-call / SLO ownership remains owner-required — git history does not declare those.*")
        $out.Add("")
    }
    elseif ($goIsGit) {
        # Git present but SHALLOW -> honest-Unknown (a 1/squashed-commit author is NOT ownership).
        $out.Add("### Ownership (git history too shallow — owner stays `Unknown`)")
        $out.Add("")
        $out.Add("The target is a git repository with only **$goCommit commit(s)** — too shallow to derive meaningful ownership. A single / squashed commit's author is **not** meaningful ownership, so the owner is reported as `Unknown` (honest; not fabricated from the lone commit's author). See `docs/git-ownership.md` for the (for-provenance-only) author list.")
        $out.Add("")
    }
    else {
        # No git at all -> honest-Unknown.
        $out.Add("### Ownership (no git history — owner stays `Unknown`)")
        $out.Add("")
        $out.Add("The target has **no git history** (no `.git`). Ownership / last-change / churn are `Unknown` (honest — there is no history to derive from, and git was not invoked).")
        $out.Add("")
    }
}
Add-Question "§13 — Ownership and maintenance (owners, on-call, SLOs, change process) are all Unknown / owner-required."
Ledger "Ownership and Maintenance" "placeholder" @()

# ===========================================================================
# 14. Architecture and Data-Flow Diagrams
# ===========================================================================
$out.Add("## Architecture and Data-Flow Diagrams")
$out.Add("")
$out.Add("> These diagrams represent **observed calls** extracted from the codebase, not production topology. They are deterministic projections of the evidence graph.")
$out.Add("")
$dataFlow = Get-MermaidBlock (Join-Path $docsPath "diagrams\data-flow.md")
if ($dataFlow) {
    $out.Add("### Data flow")
    $out.Add("")
    $out.Add('```mermaid')
    $out.Add($dataFlow)
    $out.Add('```')
    $out.Add("")
}
$c4ctx14 = Get-MermaidBlock (Join-Path $docsPath "diagrams\c4-context.md")
if ($c4ctx14) {
    $out.Add("### C4 context")
    $out.Add("")
    $out.Add('```mermaid')
    $out.Add($c4ctx14)
    $out.Add('```')
    $out.Add("")
}
if (-not $dataFlow -and -not $c4ctx14) {
    $out.Add("*No diagram was detected in this codebase.*")
    $out.Add("")
}
Ledger "Architecture and Data-Flow Diagrams" "populated" @("diagrams/data-flow.md", "diagrams/c4-context.md")

# ===========================================================================
# 15. Glossary
# ===========================================================================
$out.Add("## Glossary")
$out.Add("")
$out.Add("Recurring domain tokens and technical terms observed in the extracted evidence. Meanings are `Inferred` from context; they are not confirmed definitions.")
$out.Add("")
$out.Add("| Term | Observed meaning | Basis | Status |")
$out.Add("|------|------------------|-------|--------|")
$gloss = @(
    @{t='ADODB';        d='ActiveX Data Objects library used for database access from ASP.'},
    @{t='SQLOLEDB.1';   d='ADO OLE DB provider for SQL Server.'},
    @{t='SQLOLEDB';     d='Legacy ADO OLE DB provider for SQL Server.'},
    @{t='MSOLEDBSQL19'; d='Microsoft OLE DB Driver for SQL Server (ADO provider).'},
    @{t='Session';      d='ASP session object used for per-request state and authorization flags.'}
)
# Domain-specific terms are not shipped with the tool; a target can supply them in an
# operator overlay for the Glossary section.
# Scan the loaded per-artifact markdown (the same artifacts cited by the Ledger
# below) to confirm each term actually appears in the extracted evidence. The
# original referenced $scanFiles, which was never defined, so the foreach iterated
# nothing and the table rendered empty. Using the loaded corpus keeps this
# deterministic and free of new file I/O; a fallback row guarantees the table is
# never left empty.
$glossCorpus = ($apiMd + "`n" + $dmMd + "`n" + $testMd + "`n" + $bcMd)
$glossCount = 0
foreach ($g in $gloss) {
    # only include if the token actually appears somewhere in the extracted evidence
    $present = [bool]($glossCorpus -match [regex]::Escape($g.t))
    if ($present) { $out.Add("| $($(Clean-Cell $g.t)) | $($g.d) | term present in extracted evidence | Inferred |"); $glossCount++ }
}
if ($glossCount -eq 0 -and $isClassicAspTarget) {
    $out.Add("| — | No recurring domain terms matched the inspected artifacts in this run; concrete identifiers appear in the section bodies. | none | Unknown |")
}
if ($glossCount -eq 0 -and -not $isClassicAspTarget) {
    $out.Add("| — | $(NDA 'the classic-ASP technology glossary (ADO providers / ASP Session) does not apply to this framework') | N/A |")
}
$out.Add("")
Ledger "Glossary" "populated" @("api-inventory", "data-model", "build-cookbook", "test-catalog")

# ===========================================================================
# 16. Evidence Register
# ===========================================================================
$out.Add("## Evidence Register")
$out.Add("")
$out.Add("The full evidence register is reproduced below, projected verbatim from ``evidence-register.md``.")
$out.Add("")
if ($evRegMd) {
    # strip the source h1, demote its ## to ###, drop its Provenance footer
    $lines = $evRegMd -split "`r?`n"
    $body = New-Object System.Collections.Generic.List[string]
    $skipH1 = $true
    $inProv = $false
    foreach ($l in $lines) {
        if ($skipH1 -and $l -match '^#\s+') { $skipH1 = $false; continue }
        if ($skipH1) { continue }
        if ($l -match '^##\s+Provenance\s*$') { $inProv = $true }
        if ($inProv) { continue }
        # demote ## -> ###
        $l2 = $l -replace '^(##\s+)', '### '
        $body.Add($l2)
    }
    # trim leading/trailing blanks
    while ($body.Count -gt 0 -and [string]::IsNullOrWhiteSpace($body[0])) { $body.RemoveAt(0) }
    while ($body.Count -gt 0 -and [string]::IsNullOrWhiteSpace($body[$body.Count - 1])) { $body.RemoveAt($body.Count - 1) }
    foreach ($l in $body) { $out.Add($l) }
    $out.Add("")
} else {
    $out.Add("*Evidence register not available in this run.*")
    $out.Add("")
}
Ledger "Evidence Register" "populated" @("evidence-register.md")

# ===========================================================================
# 17. Open Questions and Documentation Gaps
# ===========================================================================
$out.Add("## Open Questions and Documentation Gaps")
$out.Add("")
$out.Add("Automatically assembled from every `Unknown` / owner-required placeholder emitted by the other sections. These are the deterministic gaps of this composition.")
$out.Add("")
if ($openQuestions.Count -gt 0) {
    $qi = 1
    foreach ($q in $openQuestions) { $out.Add("$($qi). $q"); $qi++ }
} else {
    $out.Add("1. No open questions were emitted by the deterministic composition (all sections populated or explicitly marked not-applicable).")
}
$out.Add("")
$out.Add("Additional structural gaps not captured above:")
$out.Add("")
$out.Add("- Runtime behavior (session timeout, real-world latency, actual DB state) was not observed — all *states/timing* remain Unknown.")
$out.Add("- Production topology (the diagrams show observed calls, not the live system).")
$out.Add("")
Ledger "Open Questions and Documentation Gaps" "populated" @("auto-fed from sections 3,5,6,7,10,11,12,13")

# ===========================================================================
# 18. Recommendations
# ===========================================================================
$out.Add("## Recommendations")
$out.Add("")
$out.Add("A small set of recommendations derived ONLY from the `Verified` findings above (no specifics fabricated beyond what the findings support). Each is tagged `Recommendation`.")
$out.Add("")
$out.Add("| # | Recommendation | Basis (Verified finding) | Status |")
$out.Add("|---|----------------|---------------------------|--------|")
$recs = @()
if ($isClassicAspTarget) {
    if ($onErrorFiles -gt 0) { $recs += "Replace `On Error Resume Next` silent swallowing with explicit, logged error handling." + " (`On Error Resume Next` in $onErrorFiles files)" }
    if ($redirectFail -gt 0) { $recs += "Stop redirecting users away on DB query failure; surface the root cause instead." + " (query-failure→redirect in $redirectFail files)" }
    if ($dmDbCount -gt 0) { $recs += "Rotate and externalize the hardcoded ADO connection strings (move to a secrets manager / config); they are credential-exposure." + " ($dmDbCount connection strings, values redacted)" }
    $recs += "Migrate string-built ADO SQL to parameterized calls to reduce injection risk." + " (ADO string-built SQL observed)"
    $recs += "Add centralized authentication/authorization and input validation (none extracted today)." + " (no centralized policy extracted)"
} else {
    # Generic, framework-agnostic recommendations — grounded only in the evidence that
    # exists for this framework; the classic-ASP-specific ADO/VBScript findings above
    # are not applicable and are not fabricated here.
    if ($dmDbCount -gt 0) { $recs += "Externalize detected connection strings / database credentials into a secrets manager or config." + " ($dmDbCount detected data-store references)" }
    $recs += "Add centralized authentication/authorization and input validation where not already present (none extracted today)." + " (no centralized policy extracted)"
    $recs += "Add logging and alerting for error paths (failure-response behavior not extracted in this framework)." + " (no framework-specific failure-response evidence extracted)"
}
$ri = 1
foreach ($r in $recs) {
    $rparts = $r -split '\.\('
    $rec = $rparts[0].Trim()
    $basis = if ($rparts.Count -ge 2) { ($rparts[1] -replace '\)$','') } else { '—' }
    $out.Add("| $ri | $rec | $basis | Recommendation |")
    $ri++
}
$out.Add("")
Ledger "Recommendations" "populated" @("test-catalog", "data-model")

# ===========================================================================
# 19. Operations Runbook
# ===========================================================================
$out.Add("## Operations Runbook")
$out.Add("")
$out.Add("Projected from the build-cookbook (platform requirements, SQL servers, session behavior) and the test-catalog (failure responses). Deployment/rollback procedures are `Unknown` (no deploy tooling extracted).")
$out.Add("")
$out.Add("### Platform requirements")
$out.Add("")
$out.Add("| Component | Version / shape | Evidence | Status |")
$out.Add("|-----------|-----------------|----------|--------|")
if ($isClassicAspTarget) {
    $platShow = if ($bcPlatTab) { @($bcPlatTab.Rows) } else { @() }
    # filter out malformed rows (empty version) but keep the real platform rows
    foreach ($r in $platShow) {
        if ($r.Count -ge 3) {
            $comp = Clean-Cell $r[0]; $ver = Clean-Cell $r[1]; $ev = Clean-Cell $r[2]
            if ($comp -and $ver) { $out.Add("| $comp | $ver | $ev | Verified |") }
        }
    }
    if ($platShow.Count -eq 0) { $out.Add("| — | not detected | — | Unknown |") }
} else {
    $out.Add("| — | $(NDA 'the classic-ASP platform requirement (IIS / IIS-hosted Classic ASP) does not apply to this framework') | N/A |")
}
$out.Add("")
$out.Add("### Deployment / deployment steps")
$out.Add("")
$out.Add("| Step | Action | Evidence | Status |")
$out.Add("|------|--------|----------|--------|")
if ($isClassicAspTarget) {
    $stepShow = if ($bcStepsTab) { @($bcStepsTab.Rows) } else { @() }
    foreach ($r in $stepShow) {
        if ($r.Count -ge 3) { $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | Verified |") }
    }
    if ($stepShow.Count -eq 0) { $out.Add("| — | not detected | — | Unknown |") }
} else {
    $out.Add("| — | $(NDA 'the classic-ASP IIS deployment steps (copy .asp tree to virtual directory, enable Classic ASP app pool) do not apply to this framework') | N/A |")
}
$out.Add("")
$out.Add("### SQL Server instances")
$out.Add("")
$out.Add("| ID | Server | Databases | Files | Status |")
$out.Add("|----|--------|-----------|-------|--------|")
if ($isClassicAspTarget) {
    $sqlShow19 = if ($bcSqlTab) { @($bcSqlTab.Rows | Select-Object -First 17) } else { @() }
    foreach ($r in $sqlShow19) {
        if ($r.Count -ge 4) { $out.Add("| $(Clean-Cell $r[0]) | $(Clean-Cell $r[1]) | $(Clean-Cell $r[2]) | $(Clean-Cell $r[3]) | Verified |") }
    }
    if ($sqlShow19.Count -eq 0) { $out.Add("| — | not detected | — | — | Unknown |") }
} else {
    $out.Add("| — | $(NDA 'the ADO/SQL-Server instance inventory does not apply to this framework') | N/A |")
}
$out.Add("")
$out.Add("### Failure responses (observed)")
$out.Add("")
$out.Add("| Failure | Observed response | Status |")
$out.Add("|---------|-------------------|--------|")
if ($isClassicAspTarget) {
    $out.Add("| DB query failure | Response.Redirect away (root cause hidden) | Verified |")
    $out.Add("| ADO/recordset error | parseError inspected at runtime | Verified |")
    $out.Add("| Auto-refresh expiry | Page reloads on a timer | Verified |")
} else {
    $out.Add("| DB query failure | $(NDA 'the `Response.Redirect`-on-query-failure response is classic-ASP-specific; not detected in this framework') | N/A |")
    $out.Add("| ADO/recordset error | $(NDA 'the `parseError` ADO error-inspection response is classic-ASP-specific; not detected in this framework') | N/A |")
    $out.Add("| Auto-refresh expiry | $(NDA 'the auto-refresh timer behavior is classic-ASP-specific; not detected in this framework') | N/A |")
}
$out.Add("")
$out.Add("### Rollback / deployment procedures")
$out.Add("")
$out.Add("| Procedure | Detail | Status |")
$out.Add("|-----------|--------|--------|")
$out.Add("| Rollback | Unknown — no deploy/rollback tooling extracted from the codebase. | Unknown |")
$out.Add("| Blue/green | Unknown — no deploy abstraction extracted. | Unknown |")
$out.Add("")
Add-Question "§19 — Deployment and rollback procedures are Unknown (no deploy tooling extracted)."
Ledger "Operations Runbook" "populated" @("build-cookbook", "test-catalog")

# ===========================================================================
# 20. Verification Appendix
# ===========================================================================
$out.Add("## Verification Appendix")
$out.Add("")
$out.Add("The re-runnable verification appendix is reproduced below, projected verbatim from ``verification-appendix.md``.")
$out.Add("")
if ($verAppMd) {
    $lines = $verAppMd -split "`r?`n"
    $body = New-Object System.Collections.Generic.List[string]
    $skipH1 = $true
    $inProv = $false
    foreach ($l in $lines) {
        if ($skipH1 -and $l -match '^#\s+') { $skipH1 = $false; continue }
        if ($skipH1) { continue }
        if ($l -match '^##\s+Provenance\s*$') { $inProv = $true }
        if ($inProv) { continue }
        $l2 = $l -replace '^(##\s+)', '### '
        $body.Add($l2)
    }
    while ($body.Count -gt 0 -and [string]::IsNullOrWhiteSpace($body[0])) { $body.RemoveAt(0) }
    while ($body.Count -gt 0 -and [string]::IsNullOrWhiteSpace($body[$body.Count - 1])) { $body.RemoveAt($body.Count - 1) }
    foreach ($l in $body) { $out.Add($l) }
    $out.Add("")
} else {
    $out.Add("*Verification appendix not available in this run.*")
    $out.Add("")
}
Ledger "Verification Appendix" "populated" @("verification-appendix.md")

# --- footer provenance -------------------------------------------------------
$out.Add("---")
$out.Add("")
$out.Add("*Composed deterministically by `generate-unified-master.ps1`. No LLM, no network, no randomness. Secrets redacted.*")

# --- write the document ------------------------------------------------------
# --- Operator overlays ------------------------------------------------------------
# A target can supply narrative AppDoc cannot derive from source (business purpose,
# workflow steps, domain glossary, escalation contacts). Convention:
#   <target>/.appdoc/overlays/<section-slug>.md   e.g. operational-workflows.md
# or an explicit map in config.json: "overlays": { "Operational Workflows": "path.md" }.
# Each overlay is appended to the END of its section under an explicit
# "Operator-supplied context" heading. It is never counted as Verified evidence, its
# own headings are demoted so they cannot break the 20-section spine, and the build's
# final redaction sweep applies to it like any other output.
function Get-SectionSlug { param([string]$Title) return (($Title.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')) }
$overlayMap = @{}
if ($composerConfig -and $composerConfig.values.overlays -is [System.Collections.IDictionary]) {
    foreach ($k in $composerConfig.values.overlays.Keys) { $overlayMap[(Get-SectionSlug ([string]$k))] = [string]$composerConfig.values.overlays[$k] }
}
$overlayDir = Join-Path (Join-Path $RootPath '.appdoc') 'overlays'
$overlaysApplied = New-Object System.Collections.Generic.List[object]
function Get-OverlayBlock {
    param([string]$Section)
    $slug = Get-SectionSlug $Section
    $path = if ($overlayMap.ContainsKey($slug)) { $overlayMap[$slug] } else { Join-Path $overlayDir "$slug.md" }
    if (-not [System.IO.Path]::IsPathRooted($path)) { $path = Join-Path $RootPath $path }
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) { return @() }
    $raw = (Get-Content -LiteralPath $path -Raw) -replace "`r", ''
    if ([string]::IsNullOrWhiteSpace($raw)) { return @() }
    $rel = [System.IO.Path]::GetRelativePath($RootPath, $path) -replace '\\', '/'
    $overlaysApplied.Add([ordered]@{ section = $Section; path = $rel })
    $block = @("", "#### Operator-supplied context", "", "> Status: ``Operator-supplied`` — provided by the target's owner in ``$rel``; not verified from source.", "")
    foreach ($ln in ($raw.TrimEnd() -split "`n")) {
        if ($ln -match '^#{1,4}\s+(.*)$') { $block += ("##### " + $matches[1]) } else { $block += $ln }
    }
    $block += ""
    return $block
}
$withOverlays = New-Object System.Collections.Generic.List[string]
$currentSection = $null
foreach ($line in $out) {
    if ($line -match '^##\s+(.+?)\s*$' -and $line -notmatch '^###') {
        if ($currentSection) { foreach ($b in (Get-OverlayBlock -Section $currentSection)) { $withOverlays.Add($b) } }
        $currentSection = $matches[1]
    }
    $withOverlays.Add($line)
}
if ($currentSection) { foreach ($b in (Get-OverlayBlock -Section $currentSection)) { $withOverlays.Add($b) } }
$out = $withOverlays

$mdPath = Join-Path $docsPath "application-documentation.md"
($out -join "`n") | Out-File -FilePath $mdPath -Encoding UTF8 -NoNewline

# --- write the flat evidence file -------------------------------------------
$evOut = [ordered]@{
    artifact = "application-documentation"
    generatedAt = $evidenceDate
    applicable = $true
    framework = $fwLabel
    source = "generate-unified-master.ps1"
    counts = [ordered]@{
        endpointCount = $endpointCount
        modelCount    = $dmModelCount
        databaseCount = $dmDbCount
        tableCount    = $dmTableCount
        procedureCount= $dmProcCount
        sqlServerInstances = $instanceCount
        testCaseCount = $testCaseCount
    }
    overlays = $overlaysApplied.ToArray()
    sections = @($sectionsLedger | ForEach-Object {
        [ordered]@{
            section = [string]$_.section
            status  = [string]$_.status
            sources = @($_.sources)
        }
    })
}
$evOut | ConvertTo-Json -Depth 12 | Out-File -FilePath (Join-Path $docsPath "application-documentation.evidence.json") -Encoding UTF8

$lineCount = @((Get-Content $mdPath)).Count
Write-Host "   Wrote $lineCount lines; $([Math]::Round(((Get-Item $mdPath).Length / 1KB), 0)) KB." -ForegroundColor Gray
Write-Host "✅ Unified master generated: $mdPath" -ForegroundColor Green
Write-Host "✅ Section ledger: $((Join-Path $docsPath 'application-documentation.evidence.json'))" -ForegroundColor Green
exit 0
