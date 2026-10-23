#requires -Version 7.2
#
# generate-classic-asp-platform.ps1
#
# Purpose: Populate docs/build-cookbook.md (and docs/build-cookbook.evidence.json)
#          for CLASSIC ASP. Classic ASP has no build system; the classic-ASP analog of
#          a build doc is a Platform & Deployment inventory: IIS/ASP indicators, ADO
#          provider versions observed, SQL Server instances (from connection strings),
#          and a file/directory code inventory.
#
# Deterministic: no LLM, no randomness, no network. Framework-gated: only runs when
# framework-detection.json reports Classic ASP or ASP.NET Web Forms.
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
# Required: a missing helpers file must stop here, not fail later with "command not found".
if (-not (Test-Path -LiteralPath $helpersPath)) { Write-Error "Required helpers file not found: $helpersPath"; exit 1 }
. $helpersPath

# --- Evidence + Contracts modules (canonical evidence + manifest) ----------------
$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
$evidenceModule  = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if ((Test-Path $contractsModule) -and (Test-Path $evidenceModule)) {
    Import-Module $contractsModule -Force -ErrorAction SilentlyContinue
    Import-Module $evidenceModule  -Force -ErrorAction SilentlyContinue
}

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$outputPath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "build-cookbook.md"
$evidencePath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) "build-cookbook.evidence.json"

Write-Host "🖥️  Generating Classic ASP platform/deployment inventory..." -ForegroundColor Cyan
if (-not (Get-ClassicAspFrameworkApplicable -RootPath $RootPath)) {
    Write-Host "  Framework not Classic ASP - writing placeholder." -ForegroundColor Yellow
    Write-AppDocNotApplicablePlaceholder -OutputPath $outputPath -Title "Build Cookbook" -ExtraSections ([ordered]@{ 'Build Steps' = 'No build steps were extracted for this framework.'; 'Dependencies' = 'No build dependencies were extracted for this framework.' })
    @() | ConvertTo-Json -Depth 5 | Out-File -FilePath $evidencePath -Encoding UTF8
    exit 0
}

$rootPrefix = $RootPath.TrimEnd('\', '/')

# Never count AppDoc's own output (docs/), the skill folder (.appdoc/) or VCS metadata as
# target source: on a re-run, docs/report.html from the previous run was being counted as
# an .html source file, so a first run and a re-run produced different inventories.
$platformOutputDirRe = '^(docs|\.appdoc|\.git)([\\/]|$)'
function Get-PlatformTargetFiles {
    param([string[]]$Include, [string]$Filter = '')
    $gciArgs = @{ Path = $RootPath; Recurse = $true; File = $true; ErrorAction = 'SilentlyContinue' }
    if ($Filter) { $gciArgs['Filter'] = $Filter } else { $gciArgs['Include'] = $Include }
    @(Get-ChildItem @gciArgs | Where-Object {
        $rel = [System.IO.Path]::GetRelativePath($RootPath, $_.FullName)
        $rel -notmatch $platformOutputDirRe
    })
}

# --- File inventory (counts by type + top-level dirs) ---------------------------
$extCounts = @{}
foreach ($ext in @("asp","aspx","inc","htm","html","js","css","asa","gif","jpg")) {
    $n = @(Get-PlatformTargetFiles -Filter "*.$ext").Count
    $extCounts[$ext] = $n
}
$topDirs = New-Object System.Collections.Generic.List[object]
$topDirItems = Get-ChildItem -Path $RootPath -Directory -ErrorAction SilentlyContinue | Sort-Object Name
foreach ($d in $topDirItems) {
    if ($d.Name -match '^(docs|\.appdoc|\.git)$') { continue }
    $fileCount = @(Get-ChildItem -Path $d.FullName -Recurse -File -ErrorAction SilentlyContinue).Count
    if ($fileCount -gt 0) {
        $topDirs.Add([ordered]@{ name = $d.Name; fileCount = $fileCount })
    }
}
$topDirs = @($topDirs | Sort-Object { -[int]$_.fileCount })

# --- IIS / ASP indicators -------------------------------------------------------
$webConfigs = @(Get-PlatformTargetFiles -Filter "web.config" | ForEach-Object { Get-RelativePath -FullPath $_.FullName -Base $rootPrefix })
$globalAsa = @(Get-PlatformTargetFiles -Filter "global.asa" | ForEach-Object { Get-RelativePath -FullPath $_.FullName -Base $rootPrefix })

# --- ADO provider versions + SQL Server instances (from connection strings) -----
$script:providers = @{}        # provider -> filecount
$script:instances = @{}        # host -> {host, catalogs=[...], files=[...]}
$script:sqlFiles = New-Object System.Collections.Generic.List[string]

$aspFiles = @(Get-PlatformTargetFiles -Include "*.asp" | Sort-Object FullName)
$incFiles = @(Get-PlatformTargetFiles -Include "*.inc" | Sort-Object FullName)
$htmPaths = @(Get-PlatformTargetFiles -Include "*.htm","*.html" | ForEach-Object { $_.FullName })
$htmSignalPaths = @()
if ($htmPaths.Count -gt 0) {
    $htmSignalPaths = @(Select-String -Path $htmPaths -Pattern 'Provider\s*=|Data Source\s*=|Initial Catalog\s*=' -List -ErrorAction SilentlyContinue | ForEach-Object { $_.Path } | Sort-Object)
}

function Invoke-PlatformFileScan {
    param([string]$FullPath)
    $rel = Get-RelativePath -FullPath $FullPath -Base $rootPrefix
    $content = Get-Content $FullPath -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { return }
    $hasConn = $false
    foreach ($line in ($content -split "`r?`n")) {
        if ($line -notmatch '(?i)Data Source\s*=') { continue }
        $hasConn = $true
        $provM = [regex]::Match($line, '(?i)Provider\s*=\s*([A-Za-z0-9._]+)')
        if ($provM.Success) {
            $prov = $provM.Groups[1].Value
            if (-not $script:providers.ContainsKey($prov)) { $script:providers[$prov] = 0 }
            $script:providers[$prov]++
        }
        $srcM = [regex]::Match($line, '(?i)Data Source\s*=\s*([^;&"]+)')
        $catM = [regex]::Match($line, '(?i)Initial Catalog\s*=\s*([^;&"]+)')
        $server = if ($srcM.Success) { Remove-SurroundingQuotes -Text $srcM.Groups[1].Value } else { "" }
        $catalog = if ($catM.Success) { Remove-SurroundingQuotes -Text $catM.Groups[1].Value } else { "" }
        if ($server -match '^\s*"' -or $server -match ' & ' -or $server.Length -gt 60) { $server = "dynamic" }
        if ([string]::IsNullOrWhiteSpace($server)) { $server = "unknown" }
        if ($catalog -match '^\s*"' -or $catalog -match ' & ' -or $catalog.Length -gt 60) { $catalog = "dynamic" }
        if ([string]::IsNullOrWhiteSpace($catalog)) { $catalog = "unknown" }
        if (-not $script:instances.ContainsKey($server)) {
            $script:instances[$server] = [ordered]@{ host=$server; catalogs=(New-Object System.Collections.Generic.List[string]); files=(New-Object System.Collections.Generic.List[string]) }
        }
        $inst = $script:instances[$server]
        if ($catalog -and ($catalog -notin $inst.catalogs)) { $inst.catalogs.Add($catalog) }
        if (-not ($inst.files -contains $rel)) { $inst.files.Add($rel) }
    }
    if ($hasConn -and -not ($script:sqlFiles -contains $rel)) { $script:sqlFiles.Add($rel) }
}

foreach ($f in $aspFiles) { Invoke-PlatformFileScan -FullPath $f.FullName }
foreach ($f in $incFiles) { Invoke-PlatformFileScan -FullPath $f.FullName }
foreach ($p in $htmSignalPaths) { Invoke-PlatformFileScan -FullPath $p }

$providerRows = @($script:providers.GetEnumerator() | Sort-Object { -[int]$_.Value } | ForEach-Object { [ordered]@{ provider=$_.Key; count=$_.Value } })
$instanceRows = @($script:instances.Values | Sort-Object { [string]$_.host })
$insId = 0
foreach ($i in $instanceRows) { $insId++; $i.id = "sql-$( $insId.ToString('000') )" }

# --- Render markdown ------------------------------------------------------------
$generatedLine = "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$generatedIso = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$aspTotal = [int]$extCounts["asp"] + [int]$extCounts["aspx"] + [int]$extCounts["inc"]
$summaryText = "This artifact documents the runtime platform and deployment surface for the classic-ASP codebase: IIS-hosted ASP pages served with ADODB over SQL Server. There is no compiler/build step; deployment is file copy plus IIS/ADO configuration. Observed: {0} ASP entry points ({1} .asp, {2} .aspx), {3} ADO provider shape(s), and {4} distinct SQL Server host token(s) across {5} files with connection strings." -f $aspTotal, $extCounts["asp"], $extCounts["aspx"], $providerRows.Count, $instanceRows.Count, $script:sqlFiles.Count

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Build Cookbook"); $lines.Add(""); $lines.Add($generatedLine); $lines.Add("")
$lines.Add("## Summary"); $lines.Add(""); $lines.Add($summaryText); $lines.Add("")

# Build Steps (required section; classic-ASP deployment steps).
$lines.Add("## Build Steps"); $lines.Add("")
$lines.Add("Classic ASP is interpreted by IIS; there is no compile/publish step. The following deployment steps are the classic-ASP analog of build steps (all ``Verified`` from observed file layout).")
$lines.Add("")
$lines.Add("| Step | Action | Evidence | Status |")
$lines.Add("|------|--------|----------|--------|")
$deployHostSummary = (($instanceRows | ForEach-Object { [string]$_.host }) | Select-Object -First 4) -join ", "
$buildStepsData = @(
    , @("1", "Copy the .asp/.htm/.js/.css tree into the IIS virtual directory", "$aspTotal .asp/.aspx pages; $($extCounts['inc']) .inc includes")
    , @("2", "Configure IIS to enable ASP (Classic) and the matching app pool", "$($globalAsa.Count) global.asa, $($webConfigs.Count) web.config indicator(s)")
    , @("3", "Install the observed ADO provider(s)", (($providerRows | ForEach-Object { [string]$_.provider }) -join ", "))
    , @("4", "Point ADO connection strings at the observed SQL Server host(s)", $deployHostSummary)
)
foreach ($b in $buildStepsData) {
    $bsLine = "| {0} | {1} | {2} | Verified |" -f $b[0], $b[1], $b[2]
    $lines.Add($bsLine)
}
$lines.Add("")

# Platform (task-required section).
$lines.Add("## Platform"); $lines.Add("")
$lines.Add("| Component | Version/Shape | Evidence | Status |")
$lines.Add("|-----------|---------------|----------|--------|")
$platformRows = @(
    , @("IIS / Classic ASP", "IIS-hosted ASP (VBScript/JScript)", "$aspTotal .asp/.aspx entry points")
    , @("ADO providers", (($providerRows | ForEach-Object { "$($_.provider) x$($_.count)" }) -join ", ") -replace ' x(\d+)$',''), $("$($providerRows.Count) provider shape(s) across $($script:sqlFiles.Count) files")
    , @("global.asa application events", "$($globalAsa.Count) file(s)", ($globalAsa | Select-Object -First 3) -join ", ")
    , @("web.config present", "$($webConfigs.Count) file(s)", ($webConfigs | Select-Object -First 3) -join ", ")
)
foreach ($p in $platformRows) {
    $pfLine = "| {0} | {1} | {2} | Verified |" -f $p[0], $p[1], $p[2]
    $lines.Add($pfLine)
}
# per-provider rows
foreach ($pv in $providerRows) {
    $provName = "ADO provider " + $pv.provider
    $pvLine = "| {0} | {1} usage(s) | Provider={2} in connection strings | Verified |" -f $provName, $pv.count, $pv.provider
    $lines.Add($pvLine)
}
$lines.Add("")

# SQL Server Instances (task-required section).
$lines.Add("## SQL Server Instances"); $lines.Add("")
$lines.Add("| ID | Server | Databases | Files | Status |")
$lines.Add("|------|--------|-----------|-------|--------|")
foreach ($i in $instanceRows) {
    $catShown = if ($i.catalogs.Count -le 4) { ($i.catalogs -join ", ") } else { (($i.catalogs | Select-Object -First 4) -join ", ") + " (+$($i.catalogs.Count - 4) more)" }
    $fileShown = if ($i.files.Count -le 3) { ($i.files -join ", ") } else { (($i.files | Select-Object -First 3) -join ", ") + " (+$($i.files.Count - 3) more)" }
    $instLine = "| {0} | {1} | {2} | {3} | Verified |" -f $i.id, $i.host, $catShown, $fileShown
    $lines.Add($instLine)
}
$lines.Add("")

# Code Inventory (task-required section).
$lines.Add("## Code Inventory"); $lines.Add("")
$lines.Add("| File Type | Count | Primary Directories | Status |")
$lines.Add("|-----------|-------|---------------------|--------|")
$invTypes = @("asp","aspx","inc","htm","html","js","css","asa")
foreach ($t in $invTypes) {
    if ($extCounts[$t] -gt 0) {
        $prim = ($topDirs | Select-Object -First 3 | ForEach-Object { [string]$_.name }) -join ", "
        $invLine = "| .{0} | {1} | {2} | Verified |" -f $t, $extCounts[$t], $prim
        $lines.Add($invLine)
    }
}
$lines.Add("")

# Dependencies (required section).
$lines.Add("## Dependencies"); $lines.Add("")
$lines.Add("| Dependency | Version/Shape | Purpose | Status |")
$lines.Add("|------------|---------------|---------|--------|")
$depRows = @(
    , @("Microsoft IIS", "Classic ASP runtime", "Hosts and interprets the ASP pages")
    , @("ADO provider", (($providerRows | ForEach-Object { [string]$_.provider }) -join ", "), "Data access layer to SQL Server")
    , @("SQL Server", ($instanceRows | ForEach-Object { [string]$_.host } | Select-Object -Unique) -join ", ", "Back-end data store")
)
foreach ($dp in $depRows) {
    $dpLine = "| {0} | {1} | {2} | Verified |" -f $dp[0], $dp[1], $dp[2]
    $lines.Add($dpLine)
}
$lines.Add("")

# Evidence Traceability.
$lines.Add("## Evidence Traceability"); $lines.Add("")
$lines.Add("| Field | Value |"); $lines.Add("|------|-------|")
$lines.Add("| Evidence Artifact | docs/build-cookbook.evidence.json |")
$totalRecs = $providerRows.Count + $instanceRows.Count + $buildStepsData.Count + $depRows.Count
$recLine = "| Record Count | {0} |" -f $totalRecs
$lines.Add($recLine)
$lines.Add("| Generator | generate-classic-asp-platform.ps1 |")
$lines.Add("| Required Evidence Keys | commands |")
$lines.Add("| Grounding Mode | Deterministic extraction records |")
$lines.Add("")
$lines.Add("---"); $lines.Add("")
$lines.Add("## Provenance"); $lines.Add("")
$lines.Add("- Generator Version: appdoc-run-all-generators/3.0.0"); $lines.Add("- Commit Hash: unknown")
$lines.Add("- Generated At: $generatedIso"); $lines.Add("- Profile: default"); $lines.Add("- Scope: .")
$lines.Add("- Confidence/Inference Flags: deterministic, evidence-backed")
$md = ($lines -join "`n")
$md | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

# --- Flat evidence --------------------------------------------------------------
$evidence = New-Object System.Collections.Generic.List[object]
$bid = 0
foreach ($b in $buildStepsData) { $bid++; $evidence.Add([ordered]@{ id="step-$( $bid.ToString('000') )"; kind="command"; name=($b[1]); evidence=($b[2]); status="Verified" }) }
foreach ($pv in $providerRows) { $evidence.Add([ordered]@{ id="provider-$( $pv.provider )".Replace(' ','_'); kind="technology"; name=$pv.provider; count=$pv.count; status="Verified" }) }
foreach ($i in $instanceRows) { $evidence.Add([ordered]@{ id=$i.id; kind="instance"; name=$i.host; databases=@($i.catalogs); files=@($i.files); status="Verified" }) }
foreach ($dp in $depRows) { $evidence.Add([ordered]@{ id=("dep-" + ($dp[0] -replace '[^A-Za-z0-9]','_')); kind="technology"; name=$dp[0]; evidence=$dp[1]; purpose=$dp[2]; status="Verified" }) }
$evidence | ConvertTo-Json -Depth 12 | Out-File -FilePath $evidencePath -Encoding UTF8

# --- Canonical evidence (docs/evidence/build-cookbook.evidence.json) + manifest ---
# Reuses the flat records (kinds: command/technology/instance); satisfies the
# build-cookbook contract (requiredEvidenceKeys=commands -> record kind "command")
# and aligns the doc Record Count.
if ((Get-Command Get-AppDocArtifactContract -ErrorAction SilentlyContinue) -and (Get-Command Write-AppDocEvidenceArtifact -ErrorAction SilentlyContinue)) {
    $bcContract = Get-AppDocArtifactContract -Artifact "build-cookbook"
    $canonPath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact "build-cookbook" -Records $evidence.ToArray() -Metadata @{
        requiredEvidenceKeys = @($bcContract.requiredEvidenceKeys)
        requiredSections     = @($bcContract.requiredSections)
        generator            = "generate-classic-asp-platform.ps1"
        providerCount        = [int]$providerRows.Count
        instanceCount        = [int]$instanceRows.Count
        # Same metadata contract as generate-build-cookbook.ps1 (the integrity gate
        # cross-checks it against the records): classic-ASP emits no "cicd" records.
        cicdCount            = [int]@($evidence | Where-Object { [string]$_.kind -eq 'cicd' }).Count
    }
    if ($canonPath -and (Get-Command Update-AppDocEvidenceManifest -ErrorAction SilentlyContinue)) {
        [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact "build-cookbook" -EvidencePath $canonPath -RecordCount $evidence.Count -Metadata @{
            generator = "generate-classic-asp-platform.ps1"
        })
    }
}

Write-Host "✅ Classic ASP platform/deployment inventory generated: $outputPath" -ForegroundColor Green
Write-Host "   Providers: $($providerRows.Count) | SQL instances: $($instanceRows.Count) | .asp: $($extCounts['asp'])" -ForegroundColor Gray
Write-Host "   Evidence: $evidencePath" -ForegroundColor Gray
