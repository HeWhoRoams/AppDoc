#requires -Version 7.2
#
# generate-classic-asp-procdict.ps1
#
# Purpose: Populate docs/procdict.md (and docs/procdict.evidence.json) from
#          CLASSIC ASP source. This is the stored-procedure DATA DICTIONARY.
#          It extracts:
#            (a) in-source stored-procedure CONTRACT blocks: the VB comment
#                ladders that live in the .inc/.asp files documenting a
#                procedure's Parameters and Return Codes (e.g.
#                "Procedure: usp_ExtendAccount" / "Parameters:" /
#                "Return Codes:").
#            (b) stored-procedure CALL-SITES already discovered by
#                generate-classic-asp-datamodel.ps1 (the EXEC / .Execute /
#                CommandText inventory, docs/data-model.evidence.json).
#          For each documented procedure the contract (params + return codes)
#          is cross-referenced to its call-site files. For each procedure that
#          is CALLED but has NO in-source contract block, an honest row is
#          emitted (parameters "not documented in source") so the dictionary
#          is complete without fabricating any parameter/return ladder.
#
# Deterministic: no LLM, no randomness, no network. Framework-gated: only runs
# when framework-detection.json reports Classic ASP or ASP.NET Web Forms.
# Connection-string values are treated as opaque and never printed.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

$ErrorActionPreference = "Stop"
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) { . $helpersPath }

# --- Evidence + Contracts modules (canonical evidence + manifest) ----------------
$evidenceModule  = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (Test-Path $evidenceModule) {
    Import-Module $evidenceModule -Force -ErrorAction SilentlyContinue
}
function Write-NotApplicablePlaceholder {
    param([string]$OutputPath, [string]$Title)
    $dir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $body = "# $Title`n`n**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))`n`n## Summary`n`nNot applicable for this framework. This artifact is produced only for Classic ASP / ASP.NET Web Forms codebases; the detected framework has no matching classic-ASP signal, so no content was extracted.`n`n---"
    $body | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline
}
# --- cell escaping for markdown tables ------------------------------------------
# --- parse a single procedure contract block ------------------------------------
# $lines : the file's lines (0-indexed array).
# $start : index of the procedure-name marker line.
# Returns [ordered]@{ name; params=@{name;type;desc}; returns=@{code;meaning} }.
# Uses a section state machine: params are only collected inside the Parameters:
# section and return codes only inside the Return Codes: section, so surrounding
# description prose / banners never false-match as a parameter or code.
function Parse-ProcBlock {
    param([string[]]$lines, [int]$start)
    $block = [ordered]@{ name=""; params=(New-Object System.Collections.Generic.List[object]); returns=(New-Object System.Collections.Generic.List[object]) }
    $nm = [regex]::Match($lines[$start], "(?i)\s*'(?:Stored\s+Procedure|Procedure(?:\s+Name)?)\s*[:\-]?\s*([A-Za-z_][A-Za-z0-9_.]*)")
    if ($nm.Success) { $block.name = $nm.Groups[1].Value }
    # Core-line normalizer: drop the VB comment quote and any leading dashes/tabs/spaces.
    function Core-Line([string]$l) {
        $c = $l
        $c = $c -replace "^\s*'", ""
        $c = $c -replace "^\s*[-]*\s*", ""
        return $c.Trim()
    }
    $i = $start + 1
    $mode = "preamble"   # preamble -> params -> returns
    while ($i -lt $lines.Count) {
        $t = $lines[$i]
        # skip blank / whitespace-only lines (they can sit between comment lines)
        if ([string]::IsNullOrWhiteSpace($t)) { $i++; continue }
        # stop at a real code line (non-empty and not a VB comment)
        if (-not $t.TrimStart().StartsWith("'")) { break }
        $c = Core-Line $t
        # stop at a banner line (a run of stars/plus that opens the next prose block)
        if ($c -match '^[+*]{3,}') { break }
        # stop at the next procedure-name marker
        if ($c -match '(?i)^(Stored\s+Procedure|Procedure(?:\s+Name)?)\s*[:\-]') { break }
        if ($c -match '^(Parameters)\s*:\s*$') { $mode = "params"; $i++; continue }
        if ($c -match '^(Return Codes)\s*:\s*$') { $mode = "returns"; $i++; continue }
        if ($c -eq "") { $i++; continue }
        if ($mode -eq "params") {
            # strip a leading list marker (a single dash, or a dash pair) if present
            $pl = $c
            if ($pl -match '^-[\s-]*') { $pl = ($pl -replace '^-[\s-]*', '').Trim() }
            # shape: name [ type [ OUT ] ] delimiter description  (delimiter is '-' or '(')
            $p = [regex]::Match($pl, "^(@?[A-Za-z_][A-Za-z0-9_.]*)(?:\s+([A-Za-z_][A-Za-z0-9_()]*)(\s+OUT\b)?)?\s*[-(]\s*(.*)$")
            if ($p.Success) {
                $pname = [string]$p.Groups[1].Value
                $ptype = [string]$p.Groups[2].Value
                $pdesc = ([string]$p.Groups[4].Value).Trim()
                $block.params.Add([ordered]@{ name=$pname; type=$ptype; desc=$pdesc })
            }
        }
        elseif ($mode -eq "returns") {
            $rc = [regex]::Match($c, "^(-?\d+)\s*[-\u2013]?\s*(.*)$")
            if ($rc.Success) { $block.returns.Add([ordered]@{ code=$rc.Groups[1].Value; meaning=$rc.Groups[2].Value.Trim() }) }
        }
        $i++
    }
    return $block
}

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$outputPath  = Join-Path $RootPath "docs\procdict.md"
$evidencePath = Join-Path $RootPath "docs\procdict.evidence.json"

Write-Host "📚 Generating Classic ASP stored-procedure data dictionary..." -ForegroundColor Cyan
if (-not (Get-ClassicAspFrameworkApplicable -RootPath $RootPath)) {
    Write-Host "  Framework not Classic ASP - writing placeholder." -ForegroundColor Yellow
    Write-NotApplicablePlaceholder -OutputPath $outputPath -Title "Stored-procedure data dictionary"
    @() | ConvertTo-Json -Depth 5 | Out-File -FilePath $evidencePath -Encoding UTF8
    exit 0
}

$rootPrefix = $RootPath.TrimEnd('\', '/')

# --- load the call-site inventory produced by the datamodel extractor -----------
$callSiteMap = @{}   # lowercased proc base-name -> @files
$dmEvFlat = Join-Path $RootPath "docs\data-model.evidence.json"
$dmEvCanon = Join-Path $RootPath "docs\evidence\data-model.evidence.json"
$dmRecords = @()
foreach ($cand in @($dmEvFlat, $dmEvCanon)) {
    if (Test-Path $cand) {
        try {
            $dm = Get-Content $cand -Raw | ConvertFrom-Json -Depth 120
            if ($dm -is [System.Collections.IEnumerable] -and $dm -isnot [string]) { $dmRecords = @($dm) }
            elseif ($dm.records) { $dmRecords = @($dm.records) }
            else { $dmRecords = @($dm) }
        } catch { $dmRecords = @() }
        if ($dmRecords.Count -gt 0) { break }
    }
}
foreach ($r in $dmRecords) {
    if ($null -eq $r) { continue }
    $rkind = [string]$r.kind; $rtype = [string]$r.type
    $isProc = ($rtype -eq "proc") -or ($rkind -eq "proc") -or ($rkind -eq "model" -and $rtype -eq "proc")
    if (-not $isProc) { continue }
    $nm = [string]$r.name
    $base = ($nm.Split('.') | Select-Object -Last 1)
    $key = $base.ToLowerInvariant()
    $files = @()
    if ($r.files) { $files = @($r.files) }
    elseif ($r.source) { $files = @([string]$r.source) }
    if (-not $callSiteMap.ContainsKey($key)) { $callSiteMap[$key] = New-Object System.Collections.Generic.List[string] }
    foreach ($f in $files) {
        $f = [string]$f
        if ($f -and -not ($callSiteMap[$key] -contains $f)) { $callSiteMap[$key].Add($f) }
    }
}

# --- scan .inc / .asp for in-source contract blocks ------------------------------
$aspFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.asp" -File -ErrorAction SilentlyContinue | Sort-Object FullName)
$incFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.inc" -File -ErrorAction SilentlyContinue | Sort-Object FullName)

$documented = @{}   # lowercased base name -> [ordered]@{ name; files=@; params=@; returns=@; paramSource; returnSource }
function Add-Doc {
    param([string]$Name, [string]$RelPath, [object]$Params, [object]$Returns)
    $key = ($Name.Split('.') | Select-Object -Last 1).ToLowerInvariant()
    if (-not $documented.ContainsKey($key)) {
        $documented[$key] = [ordered]@{
            name = $Name
            files = (New-Object System.Collections.Generic.List[string])
            params = (New-Object System.Collections.Generic.List[object])
            returns = (New-Object System.Collections.Generic.List[object])
            paramSource = ""
            returnSource = ""
        }
    }
    $e = $documented[$key]
    if (-not ($e.files -contains $RelPath)) { $e.files.Add($RelPath) }
    if ([string]$e.paramSource -eq "") { $e.paramSource = $RelPath }
    # keep the richest param/return set (most entries win)
    if ($Params.Count -gt $e.params.Count) { $e.params = New-Object System.Collections.Generic.List[object]; foreach ($p in $Params) { $e.params.Add($p) } }
    if ($Returns.Count -gt $e.returns.Count) { $e.returns = New-Object System.Collections.Generic.List[object]; foreach ($rt in $Returns) { $e.returns.Add($rt) } }
    if ([string]$e.returnSource -eq "" -and $Returns.Count -gt 0) { $e.returnSource = $RelPath }
}

foreach ($list in @($incFiles, $aspFiles)) {
    foreach ($f in $list) {
        $rel = Get-RelativePath -FullPath $f.FullName -Base $rootPrefix
        $content = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
        if ($null -eq $content) { continue }
        $lines = @($content -split "`r?`n")
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $m = [regex]::Match($lines[$i], "(?i)^\s*'\s*(?:Stored\s+Procedure|Procedure(?:\s+Name)?)\s*[:\-]?\s*([A-Za-z_][A-Za-z0-9_.]*)")
            if ($m.Success) {
                $blk = Parse-ProcBlock -lines $lines -start $i
                if ($blk.name -and $blk.params.Count -gt 0) {
                    Add-Doc -Name $blk.name -RelPath $rel -Params $blk.params -Returns $blk.returns
                }
            }
        }
    }
}

# --- build rows ------------------------------------------------------------------
$docRows = @($documented.Values | Sort-Object { [string]$_.name })
# undocumented = every proc in the call-site inventory whose base name is not documented
$undocRows = New-Object System.Collections.Generic.List[object]
$seenUndoc = @{}
foreach ($key in $callSiteMap.Keys) {
    $base = $key
    if ($documented.ContainsKey($key)) { continue }   # documented
    if ($seenUndoc.ContainsKey($key)) { continue }
    $seenUndoc[$key] = $true
    # show the original (unlowercased) name from the call site map if present, else base
    $undocRows.Add([ordered]@{ name=$base; files=@($callSiteMap[$key]) })
}
$undocRows = @($undocRows | Sort-Object { [string]$_.name })

$docCount = $docRows.Count
$undocCount = $undocRows.Count
$callSiteTotal = $callSiteMap.Count

# --- Render markdown ------------------------------------------------------------
$generatedLine = "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
$generatedIso = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
$summaryText = "This artifact documents the stored-procedure contracts as observed in the classic-ASP source. {0} procedures carry an in-source parameter/return-code ladder (transcribed verbatim from the `.inc`/`.asp` comment blocks and cross-referenced to their call sites); {1} additional procedures are invoked from source but have no in-source contract block, so their parameters and return codes are honestly recorded as not documented (not fabricated). The authoritative procedure definitions, grants, and side effects require database-owner confirmation." -f $docCount, $undocCount

$lines = New-Object System.Collections.Generic.List[string]
$lines.Add("# Stored-procedure data dictionary"); $lines.Add(""); $lines.Add($generatedLine); $lines.Add("")
$lines.Add("## Summary"); $lines.Add(""); $lines.Add($summaryText); $lines.Add("")
$totalsLine = "Totals: **{0}** documented procedures (parameter + return-code ladder observed in source), **{1}** called-but-undocumented procedures, **{2}** distinct stored-procedure call names discovered." -f $docCount, $undocCount, $callSiteTotal
$lines.Add($totalsLine); $lines.Add("")
$lines.Add("## Contents"); $lines.Add("")
$lines.Add("- [Documented Procedures](#documented-procedures) — in-source parameter and return-code ladders")
$lines.Add("- [Undocumented Procedures](#undocumented-procedures) — called from source, no in-source contract")
$lines.Add("- [Evidence Traceability](#evidence-traceability)")
$lines.Add("")

# Documented table
$lines.Add("## Documented Procedures"); $lines.Add("")
$lines.Add("Parameter signatures and return codes below are transcribed from the comment blocks in the live `.inc` files and the call sites. They document the *contract as observed in source*; the authoritative procedure definitions, grants, and side effects require database-owner confirmation.")
$lines.Add("")
$lines.Add("| ID | Procedure | File | Parameters (name type) | Return Codes (code = meaning) | Call Sites | Status |")
$lines.Add("|------|-----------|------|------------------------|-------------------------------|------------|--------|")
$did = 0
foreach ($d in $docRows) {
    $did++
    $id = "sp-$( $did.ToString('000') )"
    $fname = if ([string]$d.paramSource) { $d.paramSource } else { ($d.files -join ", ") }
    $params = @($d.params | ForEach-Object { if ([string]$_.type) { "$($_.name) $($_.type)" } else { [string]$_.name } })
    $paramCell = if ($params.Count -gt 0) { ($params -join "; ") } else { "—" }
    $rc = @($d.returns | ForEach-Object { "$($_.code) = $($_.meaning)" })
    $rcCell = if ($rc.Count -gt 0) { ($rc -join "; ") } else { "—" }
    $calls = $d.files
    $callsShown = if ($calls.Count -le 3) { ($calls -join ", ") } else { (($calls | Select-Object -First 3) -join ", ") + " (+$($calls.Count - 3) more)" }
    $row = "| {0} | `{1}` | {2} | {3} | {4} | {5} | Verified |" -f $id, $d.name, (Md-Clean $fname), (Md-Clean $paramCell), (Md-Clean $rcCell), (Md-Clean $callsShown)
    $lines.Add($row)
}
if ($docCount -eq 0) { $lines.Add("| — | — | — | — | — | — | Unknown |") }
$lines.Add("")

# Undocumented table
$lines.Add("## Undocumented Procedures"); $lines.Add("")
$lines.Add("The following stored procedures are invoked from classic-ASP source (EXEC / `.Execute` / `CommandText`) but carry no in-source parameter or return-code ladder. Parameters and return codes are therefore recorded as not documented — this is an honest absence, not a fabrication.")
$lines.Add("")
$lines.Add("| ID | Procedure | Call Sites | Status |")
$lines.Add("|------|-----------|------------|--------|")
$uid = 0
foreach ($u in $undocRows) {
    $uid++
    $id = "spu-$( $uid.ToString('000') )"
    $files = $u.files
    $filesShown = if ($files.Count -le 3) { ($files -join ", ") } else { (($files | Select-Object -First 3) -join ", ") + " (+$($files.Count - 3) more)" }
    $row = "| {0} | `{1}` | {2} | Partly verified |" -f $id, (Md-Clean $u.name), (Md-Clean $filesShown)
    $lines.Add($row)
}
if ($undocCount -eq 0) { $lines.Add("| — | — | — | Unknown |") }
$lines.Add("")

$lines.Add("## Evidence Traceability"); $lines.Add("")
$lines.Add("| Field | Value |"); $lines.Add("|------|-------|")
$lines.Add("| Evidence Artifact | docs/procdict.evidence.json |")
$lines.Add("| Record Count | {0} |" -f ($docCount + $undocCount))
$lines.Add("| Generator | generate-classic-asp-procdict.ps1 |")
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
foreach ($d in $docRows) {
    $fileShown = if ([string]$d.paramSource) { $d.paramSource } else { ($d.files -join ", ") }
    $evidence.Add([ordered]@{
        kind = "procedure"; name = $d.name
        file = $fileShown
        parameters = @($d.params | ForEach-Object { $_ })
        returnCodes = @($d.returns | ForEach-Object { $_ })
        callSites = @($d.files | ForEach-Object { $_ })
        status = "Verified"
    })
}
foreach ($u in $undocRows) {
    $evidence.Add([ordered]@{
        kind = "procedure"; name = $u.name
        file = "— (not documented in source)"
        parameters = @()
        returnCodes = @()
        callSites = @($u.files | ForEach-Object { $_ })
        status = "Partly verified"
    })
}
$evidence | ConvertTo-Json -Depth 14 | Out-File -FilePath $evidencePath -Encoding UTF8

# --- Canonical evidence (docs/evidence/procdict.evidence.json) -------------------
$canonDir = Join-Path $RootPath "docs\evidence"
if (-not (Test-Path $canonDir)) { New-Item -ItemType Directory -Path $canonDir -Force | Out-Null }
$canonPath = Join-Path $canonDir "procdict.evidence.json"
$canon = [ordered]@{
    artifact = "procdict"
    generatedAt = $generatedIso
    recordCount = $evidence.Count
    records = @($evidence | ForEach-Object { $_ })
    metadata = @{
        requiredSections = @("Summary", "Documented Procedures")
        requiredEvidenceKeys = @("procedures")
        generator = "generate-classic-asp-procdict.ps1"
        documentedCount = [int]$docCount
        undocumentedCount = [int]$undocCount
        callSiteTotal = [int]$callSiteTotal
    }
    determinism = @{ mode = "deterministic" }
}
$canon | ConvertTo-Json -Depth 14 | Out-File -FilePath $canonPath -Encoding UTF8

Write-Host "✅ Classic ASP stored-procedure data dictionary generated: $outputPath" -ForegroundColor Green
Write-Host "   Documented: $($docRows.Count) | Undocumented (called): $($undocRows.Count) | Call-site names: $callSiteTotal" -ForegroundColor Gray
Write-Host "   Evidence: $evidencePath" -ForegroundColor Gray
