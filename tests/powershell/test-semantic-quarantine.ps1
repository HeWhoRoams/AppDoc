# test-semantic-quarantine.ps1
#
# Phase 2a — end-to-end proof of the DETERMINISTIC semantic-enrichment quarantine
# (the SAFE, provider-agnostic substrate). Runs the real AppDoc pipeline on the small
# csharp-webforms-sample fixture (its web.config carries the fake secret FakeP@ss123),
# feeds a HAND-CRAFTED MOCK LLM output (no real LLM, no API key, no network), and asserts
# the quarantine + redaction + zero-regression hard bars.
#
#   pwsh ./tests/powershell/test-semantic-quarantine.ps1
#
# Exit code 0 = all proofs pass. This is test scaffolding (mock fixture lives at
# tests/fixtures/mock-llm-semantic-output/); it does NOT touch the gate or the real targets.

[CmdletBinding()]
param(
    [string]$RepoRoot = ((Join-Path $PSScriptRoot "..\.."))
)

# NOTE: do NOT Set-StrictMode / EAP=Stop globally here — the real pipeline scripts
# (run-all-generators.ps1 et al.) are not StrictMode-safe and emit internal non-terminating
# warnings; we verify by asserting on the produced artifacts, so the pipeline stages run
# under $ErrorActionPreference=Continue (real failures surface via missing/incorrect
# outputs, and the fail-closed apply is wrapped in its own try/catch).
$ErrorActionPreference = "Continue"

$RepoRoot = (Resolve-Path $RepoRoot).Path
$ps = Join-Path $RepoRoot ".appdoc\scripts\powershell"
$orch  = Join-Path $ps "run-all-generators.ps1"
$enrich= Join-Path $ps "run-appdoc-enrich.ps1"
$build = Join-Path $ps "run-appdoc-build.ps1"
$fixture = Join-Path $RepoRoot "tests\fixtures\csharp-webforms-sample"
$mockOut = Join-Path $RepoRoot "tests\fixtures\mock-llm-semantic-output\data-model.semantic.output.json"

$work = Join-Path $env:TEMP ("p2a-quarantine-{0}" -f [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $work | Out-Null
$target = Join-Path $work "target"
Copy-Item -Path $fixture -Destination $target -Recurse

$failures = [System.Collections.Generic.List[string]]::new()
function Assert {
    param([bool]$cond, [string]$what)
    if ($cond) { Write-Host ("  PASS  " + $what) -ForegroundColor Green }
    else       { Write-Host ("  FAIL  " + $what) -ForegroundColor Red; $script:failures.Add($what) }
}
function Read-Records {
    param([string]$path)
    $d = Get-Content $path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $r = $d.records
    # records may be a single hashtable (1-record collapsed to an object) or an
    # Object[]/array. Normalize to an array of records (callers index [0] or iterate).
    if ($r -is [hashtable]) { return @($r) }
    if ($null -eq $r) { return @() }
    return @($r)   # Object[]/IList -> @() enumerates each element
}

Write-Host "`n[1] Deterministic pipeline (the gate-able core) on the fixture..." -ForegroundColor Cyan
& $orch -RootPath $target *> $null

Write-Host "`n[2] Bootstrap + apply (quarantine) with the MOCK LLM output..." -ForegroundColor Cyan
$outDir = Join-Path $target "docs\evidence\semantic\output"
New-Item -ItemType Directory -Force -Path $outDir | Out-Null
Copy-Item $mockOut (Join-Path $outDir "data-model.semantic.output.json") -Force
if (-not (Test-Path (Join-Path $outDir "data-model.semantic.output.json"))) { throw "mock output copy failed" }
& $enrich -RootPath $target -SkipGate -SkipReRender *> $null

$applied = Join-Path $target "docs\evidence\semantic\applied\data-model.semantic.applied.json"
if (-not (Test-Path $applied)) { throw "applied envelope not produced: $applied" }
$ticket  = @(Read-Records -Path $applied)[0]
if ($null -eq $ticket) { throw "no data-model record in applied envelope (join key mismatch?)" }
$refusalPath = Join-Path $target "docs\evidence\semantic\quarantine-refusals.json"
$refusals = if (Test-Path $refusalPath) { Get-Content $refusalPath -Raw | ConvertFrom-Json -Depth 100 } else { [pscustomobject]@{ refusalCount = 0; refusals = @() } }

Write-Host "`n=== PROOF 2: provenance tagging (mock -> tagged applied envelope) ===" -ForegroundColor Cyan
Assert ($ticket.provenance.role -eq 'llm')                 "role tagged 'llm' (mock overrode the Infer-Entity heuristic)"
Assert ($ticket.provenance.businessPurpose -eq 'llm')      "businessPurpose tagged 'llm' (mock open-fill)"
Assert ($ticket.provenance.schemaSource -eq 'deterministic') "schemaSource tagged 'deterministic' (Verified, not LLM)"

Write-Host "`n=== PROOF 3: Verified-fact lock (override REFUSED, heuristic override APPLIED) ===" -ForegroundColor Cyan
Assert ($ticket.schemaSource -eq 'Ticket.cs')              "Verified schemaSource KEPT = 'Ticket.cs' (mock's WRONG-PATH refused)"
Assert ($refusals.refusalCount -ge 1)                      "quarantine-refusals.json records the refused override"
Assert (($refusals.refusals | Where-Object { $_.field -eq 'schemaSource' }).action -eq 'refused') "refusal entry action=refused for schemaSource"
Assert ($ticket.role -eq 'DTO')                            "heuristic override APPLIED: role = 'DTO' (LLM wins over heuristic)"

Write-Host "`n=== PROOF 4: no-fabrication (un-provided fields stay open/Unknown) ===" -ForegroundColor Cyan
Assert ($null -eq $ticket.usageFrequency)                  "usageFrequency null (mock left it open -> not invented)"
Assert ($ticket.provenance.usageFrequency -eq 'open')      "usageFrequency provenance = 'open'"
Assert ($null -eq $ticket.projectRole)                     "projectRole null (not invented)"
Assert ($null -eq $ticket.relationships)                   "relationships null (not invented)"

Write-Host "`n=== PROOF 1: redaction hard-gate (0 fixture secrets in semantic/input/) ===" -ForegroundColor Cyan
$inDir = Join-Path $target "docs\evidence\semantic\input"
$leaks = 0
Get-ChildItem $inDir -Filter "*.json" -File | ForEach-Object {
    $t = Get-Content $_.FullName -Raw
    $leaks += ([regex]::Matches($t, [regex]::Escape('FakeP@ss123'))).Count
}
Assert ($leaks -eq 0)                                       "0 occurrences of 'FakeP@ss123' across all input/ files (redacted)"

Write-Host "`n=== PROOF 5: input-hash cache (HIT on unchanged, MISS on changed) ===" -ForegroundColor Cyan
# re-apply with the SAME input -> the Ticket record (unchanged) must be a cache HIT.
& $enrich -RootPath $target -SkipGate -SkipReRender *> $null
$ticket2 = @(Read-Records -Path $applied)[0]
Assert ($ticket2.cacheState -eq 'hit')                      "2nd apply: Ticket input-hash cache HIT (skips the LLM call)"
# change the extracted input metadata -> the Ticket record must be a cache MISS.
$dmEv = Join-Path $target "docs\evidence\data-model.evidence.json"
$d = Get-Content $dmEv -Raw | ConvertFrom-Json -AsHashtable -Depth 100
$dmRecur = @(Read-Records -Path $dmEv)
$dmRecur[0].metadata['propertyCount'] = 99
# write back preserving structure
$d.records = @($dmRecur)
$d | ConvertTo-Json -Depth 100 | Out-File $dmEv -Encoding UTF8
& $enrich -RootPath $target -SkipGate -SkipReRender *> $null
$ticket3 = @(Read-Records -Path $applied)[0]
Assert ($ticket3.cacheState -eq 'miss')                     "3rd apply (input changed): cache MISS (re-enriches)"

Write-Host "`n=== PROOF 1b: FAIL-CLOSED gate (a surviving secret BLOCKS the stage; input not written) ===" -ForegroundColor Cyan
$fc = Join-Path $work "failclosed"
New-Item -ItemType Directory -Force -Path (Join-Path $fc "docs\evidence") | Out-Null
'{"artifact":"config-catalog","records":[{"name":"LegacyToken","kind":"configuration","source":"Legacy.config:appSettings/LegacyToken","confidence":1.0,"metadata":{"value":"SYNTHETIC-CMU-SECRET-zz123","file":"Legacy.config","type":"x"}}]}' | Out-File (Join-Path $fc "docs\evidence\config-catalog.evidence.json") -Encoding UTF8
& $enrich -RootPath $fc -SkipGate -SkipReRender -SkipSemanticApply *> $null
$blocked = $false
$errMsg = ''
try {
    & (Join-Path $ps "run-appdoc-semantic-enrich.ps1") -RootPath $fc -RedactionPatterns "SYNTHETIC-CMU-SECRET-zz123" *> $null
} catch {
    $blocked = $true
    $errMsg = $_.Exception.Message
}
$fcInputCount = (Get-ChildItem (Join-Path $fc "docs\evidence\semantic\input") -Filter "*.json" -File -ErrorAction SilentlyContinue | Measure-Object).Count
Assert $blocked                                              "fail-closed gate THREW on the surviving secret (stage blocked)"
Assert ($errMsg -match "HARD GATE BLOCKED")                  "block message is the explicit HARD GATE error"
Assert ($fcInputCount -eq 0)                                 "input NOT written (blocked before the un-redacted write)"

Write-Host "`n=== PROOF 6: opt-in no-op (enrichment OFF = deterministic-only; ON w/o LLM = 0 llm fields) ===" -ForegroundColor Cyan
# OFF: a fresh build with NO -EnableSemanticEnrich must not create the semantic dir.
$off = Join-Path $work "off"
Copy-Item $fixture $off -Recurse
& $build -Path $off *> $null
$offSemanticDir = Test-Path (Join-Path $off "docs\evidence\semantic")
Assert (-not $offSemanticDir)                                "enrichment OFF (default): no semantic/ dir created (clean no-op)"
# ON but no LLM output present: 0 llm-tagged fields applied.
$on = Join-Path $work "on-noLLM"
Copy-Item $fixture $on -Recurse
& $build -Path $on -EnableSemanticEnrich *> $null
$llmCount = 0
$detCount = 0
Get-ChildItem (Join-Path $on "docs\evidence\semantic\applied") -Filter "*.json" -File -ErrorAction SilentlyContinue | ForEach-Object {
    @(Read-Records -Path $_.FullName) | ForEach-Object {
        $_.provenance.PSObject.Properties | ForEach-Object {
            if ($_.Value -eq 'llm') { $script:llmCount++ } elseif ($_.Value -eq 'deterministic') { $script:detCount++ }
        }
    }
}
Assert ($llmCount -eq 0)                                     "ON but no LLM output: 0 'llm'-tagged fields applied (no-op to deterministic-only)"
Assert ($detCount -gt 0)                                      "deterministic fields still present (the gate-able core)"

Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue

Write-Host "`n========================================" -ForegroundColor Cyan
if ($failures.Count -eq 0) {
    Write-Host "ALL SEMANTIC-QUARANTINE PROOFS PASSED (1b/2/3/4/5/6)" -ForegroundColor Green
    exit 0
} else {
    Write-Host ("{0} PROOF(S) FAILED:" -f $failures.Count) -ForegroundColor Red
    $failures | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red }
    exit 1
}
