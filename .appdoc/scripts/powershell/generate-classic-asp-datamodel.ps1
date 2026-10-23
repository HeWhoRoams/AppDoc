#requires -Version 7.2
#
# generate-classic-asp-datamodel.ps1
#
# Purpose: Populate docs/data-model.md (and docs/data-model.evidence.json) from
#          CLASSIC ASP source. Extracts:
#            (a) ADO connection strings  -> distinct (provider, server, catalog) DB inventory
#            (b) SQL statements          -> distinct tables/views referenced
#            (c) stored-proc calls       -> distinct procedures + call-site files
#
# Deterministic: no LLM, no randomness, no network. Framework-gated: only runs when
# framework-detection.json reports Classic ASP or ASP.NET Web Forms. Sanitized
# @@HELPWEB_...@@ tokens are treated as opaque values (structure is parsed, values ignored).
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

$ErrorActionPreference = "Stop"
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }

# --- Evidence + Contracts modules (canonical evidence + manifest) ----------------
$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
$evidenceModule  = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if ((Test-Path $contractsModule) -and (Test-Path $evidenceModule)) {
    Import-Module $contractsModule -Force -ErrorAction SilentlyContinue
    Import-Module $evidenceModule  -Force -ErrorAction SilentlyContinue
}

function Trim-Quotes {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    $t = $Text.Trim()
    while ($t.Length -ge 2) {
        $first = $t.Substring(0, 1)
        $last = $t.Substring($t.Length - 1, 1)
        if (($first -eq "`"" -and $last -eq "`"") -or ($first -eq "'" -and $last -eq "'")) { $t = $t.Substring(1, $t.Length - 2) }
        else { break }
    }
    # Also strip a dangling quote at either end (connection strings end with a single
    # double-quote that is not paired with an opening one in the segment).
    while ($t.Length -gt 0 -and $t.Substring($t.Length - 1, 1) -in @("`"", "'")) { $t = $t.Substring(0, $t.Length - 1) }
    while ($t.Length -gt 0 -and $t.Substring(0, 1) -in @("`"", "'")) { $t = $t.Substring(1) }
    return $t.Trim()
}
# Connection-string values are often built with VBScript string concatenation
# (Data Source=" & dbHost & "), so a literal value may not be present. Detect and
# mark those as dynamic rather than leaking raw concatenation tokens into the doc.
function Normalize-ConnValue {
    param([string]$Raw)
    $v = if ([string]::IsNullOrWhiteSpace($Raw)) { "" } else { Trim-Quotes -Text $Raw }
    # Strip a trailing VBScript concatenation operator fragment ( & ...) if present.
    if ($v -match ' & \S') { $v = $v -replace '\s*&\s*$' -replace '(?s).*&\s*', '' }
    if ($v -match ' & ' -or $v -match '^\s*&' -or $v -match '"\s*&' -or $v -match '^\s*"' -or $v -match '\s*&\s*$') {
        return "dynamic"
    }
    if ($v.Length -gt 60) { return "dynamic" }
    if ([string]::IsNullOrWhiteSpace($v)) { return "unknown" }
    return $v
}
function Write-NotApplicablePlaceholder {
    param([string]$OutputPath, [string]$Title)
    $dir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $body = "# $Title`r`n`r`n**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`r`n`r`n## Summary`r`n`r`nNot applicable for this framework. This artifact is produced only for Classic ASP / ASP.NET Web Forms codebases; the detected framework has no matching classic-ASP signal, so no content was extracted.`r`n`r`n---"
    $body | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline
}

# --- Classic-ASP source-presence guard (shared-artifact ownership) --------------
# The framework gate above passes for BOTH 'Classic ASP' and 'ASP.NET Web Forms'
# (Web Forms is a C# framework). On a PURE C# Web Forms target there are 0
# *.asp/*.inc files, so this generator must NOT clobber the shared artifact
# (docs/data-model.md) that the C# AST path already populated. The real signal
# that this generator OWNS the artifact is classic-ASP SOURCE PRESENCE, not the
# framework label. We count classic-ASP source files using the same exclusions the
# generators apply (path dirs + basename scratch globs) and, when the count is 0,
# yield to the prior owner instead of overwriting.
function Get-ClassicAspSourceFileCount {
    param([string]$RootPath)
    # Path-dir exclusions (mirror the framework detector $aspExcl EXACTLY so the
    # guard's "source presence" matches what the detector itself counted). NOTE:
    # fixtures is excluded but test/tests is NOT — real classic-ASP apps ship live
    # test/ pages (the classic-ASP test target has test/), so excluding tests would silently drop content.
    $pathExcl  = '(?i)([\\/](fixtures|node_modules|bin|obj|dist|build|__pycache__|\.venv|target)[\\/])'
    # Basename scratch globs (mirror generate-unified-master.ps1 $scratchRe):
    # *_copy*, copy_*, *_old*, *_test*, testing*, *bak*
    $scratchRe = '(?i).*_copy.*|.*copy_.*|.*_old.*|.*_test.*|^testing.*|.*bak.*'
    $files = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp","*.inc" -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $pathExcl } |
        Where-Object { $_.Name -notmatch $scratchRe })
    return $files.Count
}

# The N-A placeholder this generator emits; its presence marks the artifact as
# "not owned by (or already claimed by) the classic-ASP layer." A file WITHOUT this
# marker was populated by another framework's generator (e.g. the C# AST path) and
# must not be clobbered.
if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$outputPath = Join-Path $RootPath "docs\data-model.md"
$evidencePath = Join-Path $RootPath "docs\data-model.evidence.json"

Write-Host "🗄️  Generating Classic ASP data model..." -ForegroundColor Cyan
if (-not (Get-ClassicAspFrameworkApplicable -RootPath $RootPath)) {
    # --- Non-ASP framework (Core / Node / Flask / Django / Spring / ...) -------
    # The generic C#/TS generators (generate-api-inventory.ps1, generate-data-model.ps1)
    # run EARLIER in the pipeline and already wrote the shared artifact for this
    # framework. Ownership of the shared artifact is decided by artifact PROVENANCE,
    # not the framework label: if docs/data-model.md exists and is NOT this
    # generator's own N-A placeholder, a prior owner populated it and we must YIELD
    # (not clobber). Only when no prior owner artifact exists do we write our own
    # N-A placeholder (harmless — nothing to overwrite).
    $artifactExists    = Test-Path $outputPath
    $isPriorOwnerOwned = $artifactExists -and (-not (Test-AppDocArtifactIsClassicAspPlaceholder -Path $outputPath))
    if ($isPriorOwnerOwned) {
        Write-Host "  Framework not Classic ASP / Web Forms and a prior (C#/TS) data-model exists; yielding (not clobbering)." -ForegroundColor Yellow
        Write-Host "✅ data-model retained (non-ASP source-presence guard)." -ForegroundColor Green
        exit 0
    }
    Write-Host "  Framework not Classic ASP / Web Forms - writing placeholder." -ForegroundColor Yellow
    Write-NotApplicablePlaceholder -OutputPath $outputPath -Title "Data Model"
    @() | ConvertTo-Json -Depth 5 | Out-File -FilePath $evidencePath -Encoding UTF8
    exit 0
}

# --- Classic-ASP source-presence guard ------------------------------------------
# The framework gate passes for BOTH 'Classic ASP' and 'ASP.NET Web Forms' (Web
# Forms is a C# framework). Ownership of the shared artifact is decided by classic-
# ASP SOURCE PRESENCE, not the framework label: if there are 0 *.asp/*.inc files
# (after the same scratch/fixture/basename exclusions the generator already uses),
# this generator finds no ADO/SQL and would CLOBBER the C# AST path's populated
# docs/data-model.md with an empty classic-ASP table. When classic-ASP source is
# absent we yield: leave a non-placeholder artifact (written by the C# path) intact,
# and only write the N-A placeholder when no prior owner populated it.
$classicAspSourceCount = Get-ClassicAspSourceFileCount -RootPath $RootPath
if ($classicAspSourceCount -eq 0) {
    $artifactExists    = Test-Path $outputPath
    $isPriorOwnerOwned = $artifactExists -and (-not (Test-AppDocArtifactIsClassicAspPlaceholder -Path $outputPath))
    if ($isPriorOwnerOwned) {
        Write-Host "  No classic-ASP source (*.asp/*.inc) found; yielding data-model.md to the prior framework's generator." -ForegroundColor Yellow
        Write-Host "✅ data-model.md retained (classic-ASP source-presence guard)." -ForegroundColor Green
        exit 0
    }
    Write-Host "  No classic-ASP source found and no prior owner artifact - writing N-A placeholder." -ForegroundColor Yellow
    Write-NotApplicablePlaceholder -OutputPath $outputPath -Title "Data Model"
    @() | ConvertTo-Json -Depth 5 | Out-File -FilePath $evidencePath -Encoding UTF8
    Write-Host "✅ Placeholder written: $outputPath" -ForegroundColor Green
    exit 0
}

$rootPrefix = $RootPath.TrimEnd('\', '/')
$aspFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp" -File -ErrorAction SilentlyContinue | Sort-Object FullName)
$incFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.inc" -File -ErrorAction SilentlyContinue | Sort-Object FullName)
$htmPaths = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.htm","*.html" -File -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
# .htm almost never carries ADO/SQL (verified on this codebase); prefilter cheaply.
$htmSignalPaths = @()
if ($htmPaths.Count -gt 0) {
    $htmSignalPaths = @(Select-String -Path $htmPaths -Pattern 'Data Source|Initial Catalog|(?i)\bSELECT\s|(?i)\bINSERT\s+INTO|(?i)\bEXEC(UTE)?\s' -List -ErrorAction SilentlyContinue | ForEach-Object { $_.Path } | Sort-Object)
}

# Aggregates (key -> object) for deterministic dedup + ordering.
$script:dbs = @{}            # key "provider|server|catalog" -> {provider,server,catalog,files=[...]}
$script:objects = @{}        # lowercased name -> {name, type, files=[...], qualified}
$script:procCalls = @{}      # lowercased proc -> {name, files=[...]}
$script:executeCallSites = 0
$script:openCallSites = 0

function Add-FileRef {
    param([hashtable]$Map, [string]$Key, [string]$RelPath)
    $files = $Map[$Key].files
    if ($files -isnot [System.Collections.Generic.List[string]]) { $Map[$Key].files = New-Object System.Collections.Generic.List[string] }
    if (-not ($Map[$Key].files -contains $RelPath)) { $Map[$Key].files.Add($RelPath) }
}

function Process-DataModelFile {
    param([string]$FullPath)
    $rel = Get-RelativePath -FullPath $FullPath -Base $rootPrefix
    $content = Get-Content $FullPath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { return }

    # (a) Connection strings: per-line capture of provider / initial catalog / data source.
    # Values are captured up to a ;, &, or " so VBScript concatenation and trailing
    # ", conn fragments do not leak into the inventory.
    foreach ($line in ($content -split "`r?`n")) {
        if ($line -notmatch '(?i)Data Source\s*=') { continue }
        $provM = [regex]::Match($line, '(?i)Provider\s*=\s*([A-Za-z0-9._]+)')
        $catM  = [regex]::Match($line, '(?i)Initial Catalog\s*=\s*([^;&"]+)')
        $srcM  = [regex]::Match($line, '(?i)Data Source\s*=\s*([^;&"]+)')
        $provider = if ($provM.Success) { $provM.Groups[1].Value } else { "unknown" }
        $catalog = if ($catM.Success) { $catM.Groups[1].Value } else { "" }
        $server  = if ($srcM.Success) { $srcM.Groups[1].Value } else { "" }
        # If the value was empty, the line likely builds it by concatenation (" & x & ").
        if ([string]::IsNullOrWhiteSpace($catalog) -and $line -match '(?i)Initial Catalog\s*=\s*["&]') { $catalog = "dynamic" }
        if ([string]::IsNullOrWhiteSpace($server)  -and $line -match '(?i)Data Source\s*=\s*["&]')     { $server  = "dynamic" }
        $catalog = Normalize-ConnValue -Raw $catalog
        $server  = Normalize-ConnValue -Raw $server
        $key = ("{0}|{1}|{2}" -f $provider, $server, $catalog).ToLowerInvariant()
        if (-not $script:dbs.ContainsKey($key)) {
            $script:dbs[$key] = [ordered]@{ provider=$provider; server=$server; catalog=$catalog; files=(New-Object System.Collections.Generic.List[string]) }
        }
        if (-not ($script:dbs[$key].files -contains $rel)) { $script:dbs[$key].files.Add($rel) }
    }

    # (b) SQL objects.
    foreach ($m in [regex]::Matches($content, '(?is)\bSELECT\b[^;]{0,500}?\bFROM\s+([A-Za-z_][A-Za-z0-9_.$]*)')) {
        Add-SqlObject -Name $m.Groups[1].Value -Type "table/view" -RelPath $rel
    }
    foreach ($m in [regex]::Matches($content, '(?i)\bINSERT\s+INTO\s+([A-Za-z_][A-Za-z0-9_.$]*)')) {
        Add-SqlObject -Name $m.Groups[1].Value -Type "table" -RelPath $rel
    }
    foreach ($m in [regex]::Matches($content, '(?i)\bUPDATE\s+([A-Za-z_][A-Za-z0-9_.$]*)\s+(SET|FROM)')) {
        Add-SqlObject -Name $m.Groups[1].Value -Type "table" -RelPath $rel
    }
    # DELETE FROM x
    foreach ($m in [regex]::Matches($content, '(?i)\bDELETE\s+FROM\s+([A-Za-z_][A-Za-z0-9_.$]*)')) {
        Add-SqlObject -Name $m.Groups[1].Value -Type "table/view" -RelPath $rel
    }

    # (c) Stored procedures via EXEC/EXECUTE.
    foreach ($m in [regex]::Matches($content, '(?i)\bEXEC(UTE)?\s+([A-Za-z_][A-Za-z0-9_.$]*)')) {
        $procName = $m.Groups[2].Value
        if ($procName -match '(?i)^(SELECT|INSERT|UPDATE|DELETE|SET|IF|END|OPEN|CLOSE|WAITFOR|PRINT|RETURN)$') { continue }
        Add-Proc -Name $procName -RelPath $rel
    }

    # ADO method call sites (informational counts).
    $script:executeCallSites += ([regex]::Matches($content, '\.Execute\s*\(')).Count
    $script:openCallSites    += ([regex]::Matches($content, '\.Open\s*\(')).Count
}

function Add-SqlObject {
    param([string]$Name, [string]$Type, [string]$RelPath)
    $clean = $Name.Trim()
    if ($clean.Length -lt 2) { return }
    $key = $clean.ToLowerInvariant()
    if (-not $script:objects.ContainsKey($key)) {
        $seg = $clean.Split('.')
        $db = if ($seg.Count -ge 2) { $seg[0] } else { "" }
        $script:objects[$key] = [ordered]@{ name=$clean; type=$Type; db=$db; files=(New-Object System.Collections.Generic.List[string]) }
    }
    # Promote type if a stronger signal (table beats table/view).
    if ($script:objects[$key].type -eq "table/view" -and $Type -eq "table") { $script:objects[$key].type = "table" }
    if (-not ($script:objects[$key].files -contains $RelPath)) { $script:objects[$key].files.Add($RelPath) }
}

function Add-Proc {
    param([string]$Name, [string]$RelPath)
    $clean = $Name.Trim()
    if ($clean.Length -lt 2) { return }
    $key = $clean.ToLowerInvariant()
    if ($key -in @("select","insert","update","delete","set","if","end","open","close","waitfor","print","return")) { return }
    if (-not $script:procCalls.ContainsKey($key)) {
        $seg = $clean.Split('.')
        $db = if ($seg.Count -ge 2) { $seg[0] } else { "" }
        $script:procCalls[$key] = [ordered]@{ name=$clean; type="proc"; db=$db; files=(New-Object System.Collections.Generic.List[string]) }
    }
    if (-not ($script:procCalls[$key].files -contains $RelPath)) { $script:procCalls[$key].files.Add($RelPath) }
}

foreach ($f in $aspFiles) { Process-DataModelFile -FullPath $f.FullName }
foreach ($f in $incFiles) { Process-DataModelFile -FullPath $f.FullName }
foreach ($p in $htmSignalPaths) { Process-DataModelFile -FullPath $p }

# Sort aggregates deterministically.
# Sort by the full dedup key (provider|server|catalog) so rows with the same
# provider + catalog but different server are NOT ties: Sort-Object is stable and
# would otherwise preserve the non-deterministic hashtable enumeration order of
# $script:dbs.Values, swapping row IDs across runs.
$dbRows = @($script:dbs.Values | Sort-Object { ("{0}|{1}|{2}" -f ([string]$_.provider).ToLowerInvariant(), ([string]$_.server).ToLowerInvariant(), ([string]$_.catalog).ToLowerInvariant()) })
$objRows = @($script:objects.Values | Sort-Object { [string]$_.name })
$procRows = @($script:procCalls.Values | Sort-Object { [string]$_.name })

# Assign stable IDs.
$did = 0
foreach ($d in $dbRows) { $did++; $d.id = "db-$( $did.ToString('000') )" }
$oid = 0
foreach ($o in $objRows) { $oid++; $o.id = "obj-$( $oid.ToString('000') )" }
$pid_ = 0
foreach ($p in $procRows) { $pid_++; $p.id = "proc-$( $pid_.ToString('000') )" }

# --- Render markdown ------------------------------------------------------------
$generatedLine = "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$generatedIso = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$summaryText = "This artifact documents the data layer for the classic-ASP codebase: {0} distinct database connection shapes (ADO provider / server / catalog) and {1} distinct SQL objects (tables, views, stored procedures) referenced across source. Connection-string values are redacted in this snapshot, so Server/Database show the sanitized token or unknown; the structure (which provider, which catalog, which objects) is deterministic." -f $dbRows.Count, ($objRows.Count + $procRows.Count)

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Data Model"); $lines.Add(""); $lines.Add($generatedLine); $lines.Add("")
$lines.Add("## Summary"); $lines.Add(""); $lines.Add($summaryText); $lines.Add("")
$totalsLine = "Totals: **{0}** connection shapes, **{1}** tables/views, **{2}** stored procedures. ADO method call sites observed: {3} .Execute( and {4} .Open(. Deterministic evidence: docs/data-model.evidence.json." -f $dbRows.Count, $objRows.Count, $procRows.Count, $script:executeCallSites, $script:openCallSites
$lines.Add($totalsLine); $lines.Add("")
$lines.Add("## Contents"); $lines.Add("")
$lines.Add("- [Data Models](#data-models) — databases, tables/views, stored procedures (sub-sections: Databases, Tables and Views, Stored Procedures)")
$lines.Add("- [Relationships](#relationships)")
$lines.Add("- [Evidence Traceability](#evidence-traceability)")
$lines.Add("")

# Data Models section = combined tables/views + procs (kept under the required heading).
$lines.Add("## Data Models"); $lines.Add("")
$lines.Add("### Databases (connection-string inventory)"); $lines.Add("")
$lines.Add("| ID | Provider | Server | Database | Connection-String Shape | Files Referencing | Status |")
$lines.Add("|------|----------|--------|----------|-------------------------|-------------------|--------|")
foreach ($d in $dbRows) {
    $filesShown = if ($d.files.Count -le 3) { ($d.files -join ", ") } else { (($d.files | Select-Object -First 3) -join ", ") + " (+$($d.files.Count - 3) more)" }
    $shape = "Provider={0} / Catalog={1} / Source={2}" -f $d.provider, $d.catalog, $d.server
    $dbRowLine = "| {0} | {1} | {2} | {3} | {4} | {5} | Verified |" -f $d.id, $d.provider, $d.server, $d.catalog, $shape, $filesShown
    $lines.Add($dbRowLine)
}
$lines.Add("")
$lines.Add("### Tables and Views"); $lines.Add("")
$lines.Add("| ID | DB | Object | Type | Referenced From | Status |")
$lines.Add("|------|----|--------|------|-----------------|--------|")
foreach ($o in $objRows) {
    $filesShown = if ($o.files.Count -le 3) { ($o.files -join ", ") } else { (($o.files | Select-Object -First 3) -join ", ") + " (+$($o.files.Count - 3) more)" }
    $dbShown = if ([string]$o.db) { $o.db } else { "—" }
    $objRowLine = "| {0} | {1} | {2} | {3} | {4} | Verified |" -f $o.id, $dbShown, $o.name, $o.type, $filesShown
    $lines.Add($objRowLine)
}
$lines.Add("")
$lines.Add("### Stored Procedures"); $lines.Add("")
$lines.Add("| ID | DB | Procedure | Type | Call Sites (files) | Status |")
$lines.Add("|------|----|-----------|------|--------------------|--------|")
foreach ($p in $procRows) {
    $filesShown = if ($p.files.Count -le 3) { ($p.files -join ", ") } else { (($p.files | Select-Object -First 3) -join ", ") + " (+$($p.files.Count - 3) more)" }
    $dbShown = if ([string]$p.db) { $p.db } else { "—" }
    $procRowLine = "| {0} | {1} | {2} | {3} | {4} | Verified |" -f $p.id, $dbShown, $p.name, $p.type, $filesShown
    $lines.Add($procRowLine)
}
$lines.Add("")
$lines.Add("## Relationships"); $lines.Add("")
$lines.Add("Column-level relationships are not deterministically derivable from classic-ASP source; the object inventory above is the authoritative surface."); $lines.Add("")
$lines.Add("## Evidence Traceability"); $lines.Add("")
$lines.Add("| Field | Value |"); $lines.Add("|------|-------|")
$lines.Add("| Evidence Artifact | docs/data-model.evidence.json |")
$recordCount = ($dbRows.Count + $objRows.Count + $procRows.Count)
$recordCountLine = "| Record Count | {0} |" -f $recordCount
$lines.Add($recordCountLine)
$lines.Add("| Generator | generate-classic-asp-datamodel.ps1 |")
$lines.Add("| Required Evidence Keys | models |")
$lines.Add("| Grounding Mode | Deterministic extraction records |")
$lines.Add("")
$lines.Add("---"); $lines.Add("")
$lines.Add("## Provenance"); $lines.Add("")
$lines.Add("- Generator Version: appdoc-run-all-generators/3.0.0"); $lines.Add("- Commit Hash: unknown")
$lines.Add("- Generated At: $generatedIso"); $lines.Add("- Profile: default"); $lines.Add("- Scope: .")
$lines.Add("- Confidence/Inference Flags: deterministic, evidence-backed")
$md = ($lines -join "`r`n")
$md | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

# --- Flat evidence --------------------------------------------------------------
$evidence = New-Object System.Collections.Generic.List[object]
foreach ($d in $dbRows) {
    $evidence.Add([ordered]@{ id=$d.id; kind="database"; name=("{0}/{1}" -f $d.server,$d.catalog); provider=$d.provider; server=$d.server; catalog=$d.catalog; files=@($d.files); status="Verified" })
}
foreach ($o in $objRows) {
    $evidence.Add([ordered]@{ id=$o.id; kind="model"; name=$o.name; type=$o.type; db=$o.db; files=@($o.files); status="Verified" })
}
foreach ($p in $procRows) {
    $evidence.Add([ordered]@{ id=$p.id; kind="model"; name=$p.name; type="proc"; db=$p.db; files=@($p.files); status="Verified" })
}
$evidence | ConvertTo-Json -Depth 12 | Out-File -FilePath $evidencePath -Encoding UTF8

# --- Canonical evidence (docs/evidence/data-model.evidence.json) + manifest -------
# Reuses the flat records (kinds: database/model); satisfies the data-model contract
# (requiredEvidenceKeys=models -> record kind "model") and aligns the doc Record Count.
if ((Get-Command Get-AppDocArtifactContract -ErrorAction SilentlyContinue) -and (Get-Command Write-AppDocEvidenceArtifact -ErrorAction SilentlyContinue)) {
    $dmContract = Get-AppDocArtifactContract -Artifact "data-model"
    $canonPath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact "data-model" -Records $evidence.ToArray() -Metadata @{
        requiredEvidenceKeys = @($dmContract.requiredEvidenceKeys)
        requiredSections     = @($dmContract.requiredSections)
        generator            = "generate-classic-asp-datamodel.ps1"
        databaseCount        = [int]$dbRows.Count
        tableCount           = [int]$objRows.Count
        procedureCount       = [int]$procRows.Count
    }
    if ($canonPath -and (Get-Command Update-AppDocEvidenceManifest -ErrorAction SilentlyContinue)) {
        [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact "data-model" -EvidencePath $canonPath -RecordCount $evidence.Count -Metadata @{
            generator = "generate-classic-asp-datamodel.ps1"
        })
    }
}

Write-Host "✅ Classic ASP data model generated: $outputPath" -ForegroundColor Green
Write-Host "   Databases: $($dbRows.Count) | Tables/Views: $($objRows.Count) | Procedures: $($procRows.Count)" -ForegroundColor Gray
Write-Host "   Evidence: $evidencePath" -ForegroundColor Gray
