# AppDoc.Pristine Module
# Purpose: the PRISTINE CHECK (Step 1b) — a per-section rubric that scores each of
# the 20 composed sections against AppDoc's reference structure, so "up to the
# standard" is MEASURABLE per section (not a single gate score).
#
# This is a PURE LIBRARY. It reads the composed docs/application-documentation.md +
# the machine evidence artifacts (docs/evidence/*.evidence.json) and classifies each
# of the 20 sections into exactly one status:
#
#   PASS            structurally present (heading) + populated with REAL content +
#                   epistemic-tagged + re-verifiable + at benchmark depth.
#   WEAK            present + populated but BELOW benchmark depth (a source-grounded
#                   section with real rows but fewer than the source supports), OR
#                   missing epistemic tags, OR a thin placeholder where parseable
#                   content EXISTS. A real finding.
#   EMPTY           present (heading) but NO real content, and the source DOES support
#                   content. A real finding.
#   OWNER_REQUIRED  a KNOWN owner-pending cell (capability matrix 5.2, policy/
#                   escalation 7, escalation paths 11, ownership/on-call/SLO 13, open
#                   questions 17) — correctly tagged Unknown, pending owner input,
#                   NOT a failure.
#   NA              a FRAMEWORK-N/A section: the section documents a capability that
#                   only exists in classic-ASP codebases (today, ONLY the
#                   'Stored-procedure data dictionary' — ADO stored procedures
#                   transcribed from live `.inc` files). When the target has NO ADO
#                   data surface (0 ADO databases / 0 ADO procedures / 0 procdict
#                   records), that section is N/A: EXCLUDED from the pristine
#                   sub-score denominator (not summed, not counted), and NOT treated
#                   as EMPTY (a gap). It is the honest classification for a framework
#                   that has no such surface — we do not fabricate content or force a
#                   PASS. N/A sections are reported in a `NA` count and the adjusted
#                   denominator (scored sections = all minus N/A).
#
# DESIGN (determinism): every decision is a pure function of the section body + the
# evidence counts. No timestamps, no randomness, no network, no LLM. The pristine
# sub-score is a DEPTH measurement. It is reported in validation-report.json as a
# `pristine` field (and a `pristineGate` field for the gate decision).
#
# MODES (the pristine check is a DEPTH measurement, NOT a structural-conformance gate;
# two modes are EXPLICIT and the default is unambiguous):
#
#   REPORT-ONLY  (DEFAULT, the pipeline's normal run)
#       pristine.blocking=False, pristineGate.mode='report-only', pristineGate.enabled=
#       false, pristineGate.blocked=false. The pristine sub-score is PURELY additive: it
#       NEVER changes status (pass/fail) or overallScore (the structural conformance
#       composite is untouched). This is the default for every run; the mode default is
#       trivially verifiable from the `pristineGate` field in validation-report.json.
#
#   BLOCKING     (OPT-IN, only when the operator passes -PristineGate)
#       pristineGate.mode='blocking', pristineGate.enabled=true. The pristine check
#       becomes a real gate that BLOCKS the run when (i) any section classifies EMPTY
#       (emptyCount>0) OR (ii) the pristine subScore < floor (floor default 80, via
#       -PristineFloor). OWNER_REQUIRED cells are EXCLUDED from the gate (they are
#       pending owner input, NOT failures — a doc with correctly-pending owner cells
#       must NOT be blocked); N/A is already excluded from the sub-score denominator.
#       When it blocks, a NEW additive blocking condition flips the run's status to
#       'blocked' (overallScore is UNCHANGED — the structural conformance composite is
#       not touched). This is the decision Test-AppDocPristineGate computes (a pure
#       function, so it is unit-testable).
#
# BENCHMARK MAPPING: the 18-section reference structure maps 1:1 to the 18 shared
# spine sections; the 2 "discipline additions" (Evidence Register, Verification
# Appendix) have their own criterion (populated with real, re-runnable evidence).

$script:AppDocPristineVersion = "1.0.0"
$script:AppDocPristineBenchmark = "AppDoc 20-section reference structure (18 shared sections + 2 discipline additions)"
# The pristine check's MODES. The DEFAULT is REPORT-ONLY (non-blocking depth
# measurement). BLOCKING is OPT-IN (only when the operator passes -PristineGate).
$script:AppDocPristineModeReportOnly = "report-only"   # DEFAULT
$script:AppDocPristineModeBlocking   = "blocking"      # OPT-IN

# --- helpers -----------------------------------------------------------------

# Is a cell a placeholder (not real content)?
function Test-AppDocPristineCellPlaceholder {
    param([string]$Cell)
    $c = ($Cell -replace '`', '').Trim()
    if ([string]::IsNullOrWhiteSpace($c)) { return $true }
    if ($c -in @('-', '—', '-', 'none', 'n/a', 'n/a.', '—', 'unknown', 'not detected', 'not detected.', '—', 'unknown / owner-required')) { return $true }
    if ($c -match '^(—|none|n/a|unknown|not detected|—|\*no|no (data|rows|records|term|screen|finding|procedure|endpoint|diagram|diagrams|open questions|recurring|outbound|email))\.?$', 'IgnoreCase') { return $true }
    if ($c -match '^not detected for this framework', 'IgnoreCase') { return $true }
    if ($c -match '^—$', 'IgnoreCase') { return $true }
    return $false
}

# Count real (non-placeholder) data rows in a section body. A real row is a pipe
# table row that is not the header (first) or separator row and whose first cell is
# not a placeholder marker. (The header row is always excluded; only the first
# data-shaped row per table is dropped as the header.)
function Get-AppDocPristineRealRows {
    param([string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return 0 }
    $lines = $Content -split "`r?`n"
    $real = 0
    $i = 0
    while ($i -lt $lines.Count) {
        $line = $lines[$i].Trim()
        if ($line -match '^\|.*\|$') {
            # start of a table block: line 0 = header, line 1 = separator, then rows
            # Find the separator (|---|---|).
            $sepIdx = -1
            for ($j = $i + 1; $j -lt [Math]::Min($i + 4, $lines.Count); $j++) {
                if ($lines[$j].Trim() -match '^\|[\s:\-|]+\|$') { $sepIdx = $j; break }
            }
            if ($sepIdx -ge 0) {
                $k = $sepIdx + 1
                while ($k -lt $lines.Count) {
                    $r = $lines[$k].Trim()
                    if ($r -notmatch '^\|.*\|$') { break }
                    if ($r -match '^\|[\s:\-|]+\|$') { $k++; continue }
                    # first cell
                    $first = ($r.TrimStart('|') -split '\|')[0].Trim()
                    if (-not (Test-AppDocPristineCellPlaceholder -Cell $first)) {
                        $real++
                    }
                    $k++
                }
                $i = $k
                continue
            }
            else {
                # no separator -> not a well-formed table; skip the line
                $i++
                continue
            }
        }
        else { $i++ }
    }
    return $real
}

# Count substantive paragraphs / list-items (text-section population).
function Get-AppDocPristineTextPopulation {
    param([string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return 0 }
    $n = 0
    foreach ($l in ($Content -split "`r?`n")) {
        $t = $l.Trim()
        if ($t -match '^\s*[-*]\s+\S' -and $t.Length -ge 8) { $n++ }
        elseif ($t -match '^\s*\d+\.\s+\S' -and $t.Length -ge 8) { $n++ }
        elseif ($t -notmatch '^#' -and $t -notmatch '^\|' -and $t -notmatch '^```' -and $t.Length -ge 40 -and $t -notmatch '^(Showing|Totals:|\*No|\*This|Projected|Deterministic|Parameter|The (data|following|full|inspection))' -and $t -notmatch '^>?\s*$') {
            # a genuine prose paragraph line (not a table/heading/code/note marker)
            $n++
        }
    }
    return $n
}

# Does the section carry at least one valid epistemic tag?
function Test-AppDocPristineEpistemicTagged {
    param([string]$Content)
    if ([string]::IsNullOrWhiteSpace($Content)) { return $false }
    return ($Content -match '(?i)\b(Verified|Inferred|Unknown|Partly verified|Recommendation)\b')
}

# --- evidence counts (the "what the source supports" reference) --------------
function Read-AppDocPristineEvidence {
    param([string]$DocsPath, [string]$Artifact)
    $candidates = @(
        (Join-Path $DocsPath "evidence/$($Artifact).evidence.enriched.json"),
        (Join-Path $DocsPath "evidence/$($Artifact).evidence.json"),
        (Join-Path $DocsPath "$($Artifact).evidence.json")
    )
    foreach ($c in $candidates) {
        if (Test-Path -LiteralPath $c) {
            try { return (Get-Content -LiteralPath $c -Raw | ConvertFrom-Json -Depth 120) } catch { return $null }
        }
    }
    return $null
}

# Read the framework label from docs/framework-detection.json (same source the
# composer's Get-FrameworkLabel uses). Returns a comma-joined list of the detected
# framework names (e.g. "Classic ASP" or "ASP.NET MVC 5, ASP.NET Web Forms,
# Classic ASP"), or '' when the file is absent / unparseable. This is the label
# shown in a framework-N/A reason.
function Get-AppDocPristineFrameworkLabel {
    param([string]$DocsPath)
    # framework-detection.json lives in docs/ (= $DocsPath); also probe the parent
    # root as a fallback (matches the composer's Get-FrameworkLabel which reads
    # $RootPath/docs/framework-detection.json).
    $root = Split-Path $DocsPath -Parent
    $candidates = @(
        (Join-Path $DocsPath 'framework-detection.json'),
        (Join-Path $root 'framework-detection.json')
    )
    $fwPath = $null
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { $fwPath = $c; break } }
    if (-not $fwPath) { return '' }
    try { $fw = Get-Content -LiteralPath $fwPath -Raw | ConvertFrom-Json -Depth 10 } catch { return '' }
    $names = @()
    if ($fw -is [System.Collections.IEnumerable] -and $fw -isnot [string]) {
        $names = @($fw | ForEach-Object { [string]$_.framework } | Where-Object { $_ })
    } else { $names = @([string]$fw.framework) | Where-Object { $_ } }
    if ($names.Count -eq 0) { return '' }
    return ($names -join ', ')
}

# Return the PRIMARY (dominant) framework name — the entry with the highest
# coveragePercent, tie-broken by original list order (deterministic). Used in the
# framework-N/A reason so it names the real framework the target is built on, not
# the full (possibly false-positive-laden) detected list.
function Get-AppDocPristineFrameworkPrimary {
    param([string]$DocsPath)
    $root = Split-Path $DocsPath -Parent
    $candidates = @(
        (Join-Path $DocsPath 'framework-detection.json'),
        (Join-Path $root 'framework-detection.json')
    )
    $fwPath = $null
    foreach ($c in $candidates) { if (Test-Path -LiteralPath $c) { $fwPath = $c; break } }
    if (-not $fwPath) { return '' }
    try { $fw = Get-Content -LiteralPath $fwPath -Raw | ConvertFrom-Json -Depth 10 } catch { return '' }
    $entries = @()
    if ($fw -is [System.Collections.IEnumerable] -and $fw -isnot [string]) { $entries = @($fw | Where-Object { $_ -and [string]$_.framework }) }
    else { if ($fw -and [string]$fw.framework) { $entries = @($fw) } }
    if ($entries.Count -eq 0) { return '' }
    $best = $entries[0]
    $bestCov = if ($null -ne $best.coveragePercent) { [double]$best.coveragePercent } else { 0 }
    for ($i = 1; $i -lt $entries.Count; $i++) {
        $cov = if ($null -ne $entries[$i].coveragePercent) { [double]$entries[$i].coveragePercent } else { 0 }
        if ($cov -gt $bestCov) { $bestCov = $cov; $best = $entries[$i] }
    }
    return [string]$best.framework
}

function Get-AppDocPristineSourceSupport {
    # Return the counts the SOURCE supports (from the machine evidence), keyed by the
    # per-section source keys used by the rubric. Pure function of the evidence files.
    param([string]$DocsPath)

    $api  = Read-AppDocPristineEvidence -DocsPath $DocsPath -Artifact 'api-inventory'
    $dm   = Read-AppDocPristineEvidence -DocsPath $DocsPath -Artifact 'data-model'
    $cfg  = Read-AppDocPristineEvidence -DocsPath $DocsPath -Artifact 'config-catalog'
    $bc   = Read-AppDocPristineEvidence -DocsPath $DocsPath -Artifact 'build-cookbook'
    $test = Read-AppDocPristineEvidence -DocsPath $DocsPath -Artifact 'test-catalog'
    $dep  = Read-AppDocPristineEvidence -DocsPath $DocsPath -Artifact 'dependencies-catalog'
    $ext  = Read-AppDocPristineEvidence -DocsPath $DocsPath -Artifact 'extcalls'
    $pd   = Read-AppDocPristineEvidence -DocsPath $DocsPath -Artifact 'procdict'

    function Get-EvidenceKindCount {
        param($Ev, [string[]]$Kinds)
        if ($null -eq $Ev -or $null -eq $Ev.records) { return 0 }
        return @($Ev.records | Where-Object { $_ -and [string]$_.kind -in $Kinds }).Count
    }

    $endpoints = Get-EvidenceKindCount $api @('endpoint')
    $models    = Get-EvidenceKindCount $dm  @('model')
    $databases = Get-EvidenceKindCount $dm  @('database')
    $deps      = Get-EvidenceKindCount $dep @('dependency')
    $testCases = Get-EvidenceKindCount $test @('test-case', 'test', 'parameterized test')

    $tables = 0; $procs = 0; $dbCount = $databases
    if ($dm -and $dm.metadata) {
        if ($null -ne $dm.metadata.tableCount)      { $tables = [int]$dm.metadata.tableCount }
        if ($null -ne $dm.metadata.procedureCount)  { $procs  = [int]$dm.metadata.procedureCount }
        if ($null -ne $dm.metadata.databaseCount)   { $dbCount = [int]$dm.metadata.databaseCount }
    }
    # If metadata is absent, derive from distinct names in records.
    if ($tables -eq 0) { $tables = @($dm.records | Where-Object { $_ -and [string]$_.kind -eq 'model' } | ForEach-Object { [string]$_.name } | Where-Object { $_ } | Select-Object -Unique).Count }
    if ($procs  -eq 0) { $procs  = @($dm.records | Where-Object { $_ -and ([string]$_.kind -eq 'procedure' -or [string]$_.kind -eq 'stored-procedure') } | ForEach-Object { [string]$_.name } | Where-Object { $_ } | Select-Object -Unique).Count }

    $dbSupport = $dbCount
    if ($dbSupport -eq 0) { $dbSupport = $databases }

    $sqlInstances = 0
    if ($bc -and $bc.metadata) { if ($null -ne $bc.metadata.instanceCount) { $sqlInstances = [int]$bc.metadata.instanceCount } }
    if ($sqlInstances -eq 0) { $sqlInstances = @($bc.records | Where-Object { $_ -and [string]$_.kind -eq 'instance' }).Count }

    $extHttp = @($ext.records | Where-Object { $_ -and ([string]$_.kind -eq 'http' -or [string]$_.kind -eq 'http-xml' -or [string]$_.kind -eq 'outbound-http') }).Count
    if ($extHttp -eq 0) { $extHttp = @($ext.records | Where-Object { $_ -and [string]$_.kind }).Count }
    $procdictDoc = @($pd.records | Where-Object { $_ -and ([string]$_.kind -in @('procedure','documented-procedure','procedure-dictionary','stored-procedure')) }).Count
    if ($procdictDoc -eq 0) { $procdictDoc = @($pd.records | Where-Object { $_ -and [string]$_.kind }).Count }

    return [ordered]@{
        endpointCount  = $endpoints
        modelCount     = $models
        databaseCount  = $dbSupport
        tableCount     = $tables
        procedureCount = $procs
        dependencyCount= $deps
        testCaseCount  = $testCases
        sqlInstances   = $sqlInstances
        extCallCount   = $extHttp
        procdictCount  = $procdictDoc
    }
}

# --- the 20-section rubric ----------------------------------------------------
# section     : exact composed heading text (matches the composer's $spineTitles)
# type        : 'table' | 'text' | 'mixed' | 'diagram' | 'list'
# ownerPending: the known owner-pending cells (composed-spine numbering, per the
#               composer's own Add-Question markers): 5.2 capability matrix, 7
#               policy/escalation, 11 escalation paths, 13 ownership/SLO, 17 open
#               questions. These are correctly tagged Unknown, pending
#               owner input — NOT a failure (they classify OWNER_REQUIRED even
#               when they also carry verified source-derivable content).
# sourceKeys  : which evidence counts feed the "what the source supports" depth.
# benchmark   : the composer's DESIGNED representative cap for the section (e.g. §4
#               is `Select-Object -First 60`). Effective depth benchmark =
#               min(benchmark, sourceSupport): a table is at-depth when it surfaces
#               at least that many real rows (capped by the real source count, so a
#               thin source is never a false finding).
# benchmarkRef: which benchmark section (1-18) this maps to, or 'discipline-addition'.
function Get-AppDocPristineRubric {
    return @(
        @{ section = 'Application Index';                     type = 'mixed';   ownerPending = $false; benchmark = 10;  sourceKeys = @('endpointCount');           benchmarkRef = '1' }
        @{ section = 'Coverage and Executive Overview';       type = 'mixed';   ownerPending = $false; benchmark = 15;  sourceKeys = @('endpointCount','modelCount','databaseCount'); benchmarkRef = '2' }
        @{ section = 'Architecture';                          type = 'mixed';   ownerPending = $false; benchmark = 15;  sourceKeys = @('endpointCount');           benchmarkRef = '3' }
        @{ section = 'Functional Inventory';                  type = 'table';   ownerPending = $false; benchmark = 60;  sourceKeys = @('endpointCount');           benchmarkRef = '4' }
        @{ section = 'Roles and Access Model';                type = 'mixed';   ownerPending = $true;  benchmark = 0;   sourceKeys = @();                          benchmarkRef = '5 (5.2 owner-required)' }
        @{ section = 'UI Catalog';                            type = 'table';   ownerPending = $false; benchmark = 40;  sourceKeys = @('endpointCount');           benchmarkRef = '6' }
        @{ section = 'Operational Workflows';                 type = 'mixed';   ownerPending = $true;  benchmark = 0;   sourceKeys = @('procedureCount');          benchmarkRef = '7 (7.x policy/escalation owner-required)' }
        @{ section = 'Data and Integrations';                 type = 'table';   ownerPending = $false; benchmark = 40;  sourceKeys = @('modelCount','databaseCount','procedureCount'); benchmarkRef = '8' }
        @{ section = 'External Call Register';                type = 'table';   ownerPending = $false; benchmark = 60;  sourceKeys = @('databaseCount','procdictCount','extCallCount'); benchmarkRef = '8A' }
        @{ section = 'Stored-procedure data dictionary';      type = 'table';   ownerPending = $false; benchmark = 40;  sourceKeys = @('procdictCount','procedureCount'); benchmarkRef = '8B'; frameworkNA = $true; frameworkNAReason = 'stored-procedure data dictionary is classic-ASP-specific (ADO stored procedures transcribed from live `.inc` files)' }
        @{ section = 'Troubleshooting Matrix';                type = 'table';   ownerPending = $true;  benchmark = 0;   sourceKeys = @('testCaseCount');           benchmarkRef = '9 (11 escalation-paths owner-required)' }
        @{ section = 'Security and Operational Risks';        type = 'mixed';   ownerPending = $false; benchmark = 10;  sourceKeys = @('databaseCount','procedureCount'); benchmarkRef = '10' }
        @{ section = 'Ownership and Maintenance';             type = 'mixed';   ownerPending = $true;  benchmark = 0;   sourceKeys = @();                          benchmarkRef = '11 (13 ownership/SLO owner-required)' }
        @{ section = 'Architecture and Data-Flow Diagrams';   type = 'diagram'; ownerPending = $false; benchmark = 1;   sourceKeys = @();                          benchmarkRef = '12' }
        @{ section = 'Glossary';                              type = 'table';   ownerPending = $false; benchmark = 5;   sourceKeys = @();                          benchmarkRef = '13 (Glossary)' }
        @{ section = 'Evidence Register';                     type = 'table';   ownerPending = $false; benchmark = 50;  sourceKeys = @();                          benchmarkRef = 'discipline-addition (14)' }
        @{ section = 'Open Questions and Documentation Gaps'; type = 'list';    ownerPending = $true;  benchmark = 0;   sourceKeys = @();                          benchmarkRef = '17' }
        @{ section = 'Recommendations';                       type = 'table';   ownerPending = $false; benchmark = 5;   sourceKeys = @();                          benchmarkRef = '16' }
        @{ section = 'Operations Runbook';                    type = 'mixed';   ownerPending = $false; benchmark = 15;  sourceKeys = @('sqlInstances','testCaseCount'); benchmarkRef = '17 (Ops Runbook)' }
        @{ section = 'Verification Appendix';                 type = 'table';   ownerPending = $false; benchmark = 50;  sourceKeys = @();                          benchmarkRef = 'discipline-addition (18)' }
    )
}

# Map an owner-pending section to the AppDoc.SourceDocs citation categories that
# can back it. The composer POPULATES a cell only when ≥1 citation exists in a
# backing category AND it rendered the cell (additive Verified-source-doc / Inferred
# block). §17 (Open Questions) has NO source-doc category — it is ALWAYS
# owner-pending (the repo's hand-authored docs cannot resolve open questions).
# This is the single source of truth for the section→category backing map.
function Get-AppDocPristineSectionSourceCats {
    param([string]$Section)
    $map = @{
        'Roles and Access Model'              = @('role-access')
        'Operational Workflows'               = @('operational-policy')   # service-procedure sub-tag
        'Troubleshooting Matrix'              = @('escalation','troubleshooting')
        'Ownership and Maintenance'           = @('ownership')
        'Open Questions and Documentation Gaps' = @()
    }
    if ($map.ContainsKey($Section)) { return @($map[$Section]) }
    return @()
}

# Decide whether a section's body was ACTUALLY populated by a source-doc citation
# block the composer rendered (the "cited from hand-authored docs" marker). This is
# the "rendered" half of the pristine backing rule: a citation only counts when the
# composer surfaced it (additive block present in the section body).
function Test-AppDocPristineSectionRenderedSourceDoc {
    param([string]$Body)
    if ([string]::IsNullOrWhiteSpace($Body)) { return $false }
    return ($Body -match '(?i)cited from hand-authored docs')
}

# Count of source-doc citation records backing a section (>=1 = source-backed).
# Reads docs/evidence/source-docs.evidence.json (pure; deterministic).
#   $SubTag : when non-empty, only count records whose 'sub' field equals it
#             (e.g. 'service-procedure' for the §7 cell). Empty = all.
function Get-AppDocPristineSectionSourceCitations {
    param([string]$DocsPath, [string]$Section, [string]$SubTag = '')
    $cats = @(Get-AppDocPristineSectionSourceCats -Section $Section)
    if ($cats.Count -eq 0) { return @() }
    if ([string]::IsNullOrWhiteSpace($DocsPath)) { return @() }
    $evPath = Join-Path $DocsPath 'evidence/source-docs.evidence.json'
    if (-not (Test-Path -LiteralPath $evPath)) { return @() }
    $ev = $null
    try { $ev = Get-Content -LiteralPath $evPath -Raw | ConvertFrom-Json -Depth 120 } catch { $ev = $null }
    if ($null -eq $ev -or $null -eq $ev.categories) { return @() }
    $recs = @()
    foreach ($c in $cats) {
        $arr = $ev.categories.$c
        if ($null -eq $arr) { continue }
        foreach ($r in @($arr)) {
            if ($SubTag -ne '' -and [string]$r.sub -ne $SubTag) { continue }
            $recs += $r
        }
    }
    return @($recs)
}

# Extract the body of a ## section from the composed document. Returns '' when absent.
function Get-AppDocPristineSectionBody {
    param([string]$Content, [string]$SectionName)
    if ([string]::IsNullOrWhiteSpace($Content)) { return '' }
    $lines = $Content -split "`r?`n"
    $start = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match ('^##\s+' + [regex]::Escape($SectionName) + '\s*$')) { $start = $i; break }
    }
    if ($start -lt 0) { return '' }
    $end = $lines.Count
    for ($j = $start + 1; $j -lt $lines.Count; $j++) {
        if ($lines[$j] -match '^##\s+') { $end = $j; break }
    }
    $startIdx = $start + 1
    $endIdx = [Math]::Min($end, $lines.Count) - 1
    if ($endIdx -lt $startIdx) { return '' }
    return (($lines[$startIdx..$endIdx]) -join "`n")
}

# Classify a single section. Returns an ordered record.
function Test-AppDocPristineSection {
    param(
        [Parameter(Mandatory=$true)][hashtable]$Spec,
        [string]$Body,
        [object]$Source,
        [bool]$ReVerifiable,
        [string]$FwLabel,
        [bool]$TargetHasNoAdoSurface,
        [string]$DocsPath = ''
    )

    $section = [string]$Spec.section
    $type    = [string]$Spec.type
    $owner   = [bool]$Spec.ownerPending
    $bref    = [string]$Spec.benchmarkRef
    $bench   = [int]$Spec.benchmark

    $present = (-not [string]::IsNullOrWhiteSpace($Body))
    $realRows   = Get-AppDocPristineRealRows -Content $Body
    $textPop    = Get-AppDocPristineTextPopulation -Content $Body
    $hasMermaid = $Body -match '```mermaid'
    $epistemic  = Test-AppDocPristineEpistemicTagged -Content $Body

    # --- FRAMEWORK-N/A (5th status) -----------------------------------------
    # A section flagged `frameworkNA` documents a capability that only exists in
    # classic-ASP codebases. When the target has NO ADO data surface (0 ADO databases /
    # procedures / procdict records), the section is N/A: excluded from the sub-score
    # denominator and NOT counted EMPTY (a gap). This is the honest classification for
    # a framework with no such surface — we do not fabricate content or force a PASS.
    # (A target that IS classic ASP has an ADO surface, so this never fires for it.)
    $isFrameworkNA = ([bool]($Spec.ContainsKey('frameworkNA')) -and $Spec['frameworkNA']) -and $TargetHasNoAdoSurface
    if ($isFrameworkNA) {
        $naFw = $FwLabel
        if ([string]::IsNullOrWhiteSpace($naFw) -or $naFw -match '(?i)unknown|not detected') { $naFw = 'non-classic-ASP' }
        $naReasonBase = if ([string]($Spec.ContainsKey('frameworkNAReason')) -and $Spec['frameworkNAReason']) { [string]$Spec['frameworkNAReason'] } else { 'capability is classic-ASP-specific' }
        $reason = "framework-N/A ($naReasonBase; target is $naFw — no ADO data surface detected)"
        $score = 0   # excluded from the denominator; never summed
        return [ordered]@{
            section         = $section
            headingPresent  = [bool]$present
            status          = 'NA'
            reason          = $reason
            populated       = [bool]$populated
            rowCount        = [int]$realRows
            textPopulation  = [int]$textPop
            hasMermaid      = [bool]$hasMermaid
            sourceSupport   = [int]0   # N/A: source depth is irrelevant (excluded)
            epistemicTagged = [bool]$epistemic
            reVerifiable    = [bool]$ReVerifiable
            benchmarkRef    = $bref
            ownerPending    = [bool]$owner
            frameworkNA     = $true
            sectionScore    = [int]$score
        }
    }

    # "What the source supports" for this section (sum of its source keys).
    $sourceSupport = 0
    foreach ($k in @($Spec.sourceKeys)) {
        if ($Source.Contains($k)) { $sourceSupport += [int]$Source[$k] }
    }

    # Effective depth benchmark = the composer's designed representative cap,
    # CAPPED by the real source count (a thin source is never a false finding).
    $depthBenchmark = [Math]::Min($bench, $sourceSupport)

    # Population (objective, per section type):
    $populated = $false
    switch ($type) {
        'table'   { $populated = ($realRows -ge 1) }
        'diagram' { $populated = ($hasMermaid -or $realRows -ge 1) }
        'list'    { $populated = ($textPop -ge 1 -or $realRows -ge 1) }
        default   { $populated = ($realRows -ge 1 -or $textPop -ge 1) }   # mixed
    }

    $reason = ''
    $status = ''

    if (-not $present) {
        if ($owner) {
            $status = 'OWNER_REQUIRED'
            $reason = 'owner-pending cell; section heading absent (pending owner input)'
        } else {
            $status = 'EMPTY'
            $reason = 'section heading absent from composed document'
        }
    }
    elseif ($owner) {
        # Owner-pending cell. BASELINE (unchanged): correctly tagged Unknown, pending
        # owner input -> OWNER_REQUIRED even when the section also carries verified
        # source-derivable content (the depth is transparent).
        #
        # SOURCE-OF-TRUTH BACKING (Phase 1 Build 1): when the repo's HAND-AUTHORED docs
        # actually document this cell (>=1 source-doc citation in the cell's backing
        # category) AND the composer RENDERED the cell with that citation (additive
        # "cited from hand-authored docs" block present in the body), the cell is
        # POPULATED with real, cited content + file:line provenance. It then classifies
        # PASS (reason 'Verified-source-doc — populated from <path:line>') instead of
        # OWNER_REQUIRED. A cell with NO citation STAYS OWNER_REQUIRED (genuinely
        # owner-pending — no fabrication). §17 has no backing category, so it is always
        # OWNER_REQUIRED. (PASS and OWNER_REQUIRED both score 100, so the flip is
        # count/reason — additive content-depth, NOT a gamed score.)
        $cmp = [Math]::Max($realRows, $textPop)
        # sub-tag for the §7 cell (service procedures); empty for the other cells.
        $subTag = ''
        if ($section -eq 'Operational Workflows') { $subTag = 'service-procedure' }
        $sdRecs = @(Get-AppDocPristineSectionSourceCitations -DocsPath $DocsPath -Section $section -SubTag $subTag)
        $renderedSd = (Test-AppDocPristineSectionRenderedSourceDoc -Body $Body)
        if (($sdRecs.Count -gt 0) -and $renderedSd) {
            # Source-backed + rendered -> PASS (Verified-source-doc).
            $sdProv = @()
            foreach ($r in $sdRecs) {
                $lp = [string]$r.path
                $ls2 = [int]$r.lineStart
                if (-not [string]::IsNullOrWhiteSpace($lp)) { $sdProv += ('`' + $lp + '`: ' + $ls2) }
            }
            $sdProvU = @($sdProv | Sort-Object -Unique | Select-Object -First 3)
            $sdProvJoin = ($sdProvU -join ', ')
            if ($sdProvU.Count -gt 3) { $sdProvJoin += ' (+ more)' }
            $status = 'PASS'
            $reason = ('Verified-source-doc — populated from {0} (cited hand-authored docs; owner-pending cell resolved from source-of-truth)' -f $sdProvJoin)
        }
        elseif ($cmp -gt 0) {
            $status = 'OWNER_REQUIRED'
            $reason = ('owner-pending cell (correctly Unknown; pending owner input); also carries {0} verified source-derivable row(s)' -f $cmp)
        } else {
            $status = 'OWNER_REQUIRED'
            $reason = 'owner-pending cell (correctly Unknown; pending owner input); no source-derivable content'
        }
    }
    elseif (-not $populated) {
        # No real content.
        if ($sourceSupport -gt 0) {
            $status = 'EMPTY'
            $reason = ('no real content but source supports {0} record(s)' -f $sourceSupport)
        } else {
            $status = 'EMPTY'
            $reason = 'no real content (placeholder only)'
        }
    }
    else {
        # Source-grounded (or discipline) section with real content.
        $atDepth = $true
        # Depth vs the benchmark cap (only when the source supports content).
        if ($depthBenchmark -gt 0) {
            $cmp = [Math]::Max($realRows, $textPop)
            $atDepth = ($cmp -ge $depthBenchmark)
            if (-not $atDepth) {
                $reason = ('only {0}/{1} representative rows surfaced (benchmark cap {2}; source supports {3})' -f $cmp, $depthBenchmark, $bench, $sourceSupport)
            }
        }
        # Epistemic tagging (waived for diagram projections — a mermaid diagram is
        # a source-grounded projection, not a tagged claim).
        if ($type -ne 'diagram' -and -not $epistemic) {
            $atDepth = $false
            if ($reason) { $reason += '; ' } else { $reason = '' }
            $reason += 'missing epistemic tags'
        }
        # Re-verifiability (global: a re-runnable command exists in §18).
        if (-not $ReVerifiable) {
            $atDepth = $false
            if ($reason) { $reason += '; ' } else { $reason = '' }
            $reason += 'no re-runnable verification command in §18'
        }
        if ($atDepth -and -not $reason) { $reason = 'at benchmark depth; real content; epistemic-tagged' }
        $status = if ($atDepth) { 'PASS' } else { 'WEAK' }
    }

    # Score for the additive sub-score (NON-BLOCKING):
    #   PASS=100, WEAK=60, EMPTY=0, OWNER_REQUIRED=100 (correctly pending, not a failure).
    #   NA=0 (excluded from the denominator — never summed; kept as a safety default).
    $score = switch ($status) {
        'PASS'           { 100 }
        'WEAK'           { 60 }
        'EMPTY'          { 0 }
        'OWNER_REQUIRED' { 100 }
        'NA'             { 0 }
        default          { 0 }
    }

    return [ordered]@{
        section         = $section
        headingPresent  = [bool]$present
        status          = $status
        reason          = $reason
        populated       = [bool]$populated
        rowCount        = [int]$realRows
        textPopulation  = [int]$textPop
        hasMermaid      = [bool]$hasMermaid
        sourceSupport   = [int]$sourceSupport
        epistemicTagged = [bool]$epistemic
        reVerifiable    = [bool]$ReVerifiable
        benchmarkRef    = $bref
        ownerPending    = [bool]$owner
        frameworkNA     = $false
        sectionScore    = [int]$score
    }
}

# Run the full pristine rubric over the composed document. Returns ordered @{
#   records; counts; subScore; reVerifiable; determinismHash
# }. Pure function of $DocsPath inputs.
function Get-AppDocPristineAssessment {
    param([string]$DocsPath)

    $mdPath = Join-Path $DocsPath 'application-documentation.md'
    $content = ''
    if (Test-Path -LiteralPath $mdPath) { $content = Get-Content -LiteralPath $mdPath -Raw }

    $source = Get-AppDocPristineSourceSupport -DocsPath $DocsPath

    # Re-verifiability: the composed Verification Appendix carries re-runnable
    # commands (a global property; every Verified claim is re-runnable when true).
    $appendixPath = Join-Path $DocsPath 'verification-appendix.md'
    $reVerifiable = $false
    if (Test-Path -LiteralPath $appendixPath) {
        $app = Get-Content -LiteralPath $appendixPath -Raw
        # a re-runnable command = a real command cell (not N/A / —)
        $reVerifiable = ($app -match '(?im)^\|\s*[^|]*\|\s*(Select-String|Get-ChildItem|grep|findstr|python|pwsh|git|dotnet|npm|node|mvn|gradle)' ) -or
                        ($app -match 'Select-String|Get-ChildItem|grep -R|findstr')
    }

    $records = @()
    $counts = [ordered]@{ PASS = 0; WEAK = 0; EMPTY = 0; OWNER_REQUIRED = 0; NA = 0 }

    # --- framework label + ADO-surface flag (framework-N/A discriminator) -----
    # The framework label comes from docs/framework-detection.json (same source the
    # composer's Get-FrameworkLabel uses). ADO-surface presence is an EVIDENCE
    # discriminator (NOT the framework label, which can carry a detector false
    # positive): a target has an ADO data surface when it has ADO databases, ADO
    # procedures, OR documented ADO stored procedures in the procdict. A real
    # classic-ASP target has all three > 0, so its §10 is NEVER
    # N/A; a non-ASP target with no ADO surface (e.g. a C# MVC 5 target: 0/0/0) gets
    # §10 classified N/A. This is deterministic and evidence-grounded.
    $fwLabel = Get-AppDocPristineFrameworkLabel -DocsPath $DocsPath
    # Primary framework (highest coverage) — used in the N/A reason so it names the
    # real framework the target is built on (e.g. "ASP.NET MVC 5"), not the full
    # detected list (which can carry a false-positive "Classic ASP" entry).
    $fwPrimary = Get-AppDocPristineFrameworkPrimary -DocsPath $DocsPath
    $fwLabelForReason = $fwPrimary
    if ([string]::IsNullOrWhiteSpace($fwLabelForReason)) { $fwLabelForReason = $fwLabel }
    $targetHasAdoSurface = ([int]$source.databaseCount -gt 0) -or ([int]$source.procedureCount -gt 0) -or ([int]$source.procdictCount -gt 0)
    $targetHasNoAdoSurface = -not $targetHasAdoSurface

    foreach ($spec in (Get-AppDocPristineRubric)) {
        $body = Get-AppDocPristineSectionBody -Content $content -SectionName $spec.section
        $rec = Test-AppDocPristineSection -Spec $spec -Body $body -Source $source -ReVerifiable $reVerifiable -FwLabel $fwLabelForReason -TargetHasNoAdoSurface $targetHasNoAdoSurface -DocsPath $DocsPath
        $records += $rec
        $counts[$rec.status] = ([int]$counts[$rec.status] + 1)
    }

    # Sub-score: N/A sections are EXCLUDED from both the sum and the denominator
    # (they are neither gaps nor scored cells). Every other section (PASS/WEAK/
    # EMPTY/OWNER_REQUIRED) is scored, so the denominator = total minus N/A.
    #   subScore = Round( Σ(scores of scored sections) / count_of_scored, 1 )
    $scored = @($records | Where-Object { $_.status -ne 'NA' })
    $naN = $records.Count - $scored.Count
    $n = [Math]::Max(1, $scored.Count)
    $sum = 0
    foreach ($r in $scored) { $sum += [int]$r.sectionScore }
    $subScore = [Math]::Round(($sum / $n), 1)

    # Determinism hash over the pure records (no timestamps).
    $hashInput = [ordered]@{
        version  = $script:AppDocPristineVersion
        subScore = $subScore
        counts   = $counts
        records  = $records | ForEach-Object {
            [ordered]@{
                section = $_.section; status = $_.status; reason = $_.reason
                rowCount = $_.rowCount; textPopulation = $_.textPopulation
                sourceSupport = $_.sourceSupport; benchmarkRef = $_.benchmarkRef
            }
        }
    }
    $determinismHash = ''
    try {
        $json = $hashInput | ConvertTo-Json -Depth 30 -Compress
        $sha = [System.Security.Cryptography.SHA256]::Create()
        $hashBytes = $sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($json))
        $determinismHash = ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
        $sha.Dispose()
    } catch { $determinismHash = 'unavailable' }

    return [ordered]@{
        records         = $records
        counts          = $counts
        subScore        = $subScore
        reVerifiable    = [bool]$reVerifiable
        sourceSupport   = $source
        frameworkLabel  = $fwLabel
        targetHasAdoSurface = [bool]$targetHasAdoSurface
        naCount         = [int]$naN
        scoredCount     = [int]$scored.Count
        totalSections   = [int]$records.Count
        benchmarkRef    = $script:AppDocPristineBenchmark
        determinismHash = $determinismHash
    }
}

# --- OWNER-PENDING CHECKLIST (Step 1b complement) ----------------------------
# A deterministic, framework-agnostic checklist of the 5 OWNER-REQUIRED cells: the
# cells that are correctly tagged Unknown and pending owner input (NOT failures).
# This is the 'what's left for a human' complement to the source-derivable (auto)
# content. It REUSES the rubric's ownerPending classification (the SAME 5 cells the
# rubric flags) — we do NOT hardcode a divergent list. For each cell: what's missing
# (one line), what the owner must provide (concrete), and where to supply it (overlay).
function Get-AppDocPristineOwnerPendingChecklist {
    # $records: the per-section records from Get-AppDocPristineAssessment (optional).
    # When provided, the checklist is restricted to the sections ACTUALLY classified
    # OWNER_REQUIRED this run (reusing the classification, not a hardcoded list).
    # When omitted (or $null), it returns the full rubric ownerPending set.
    param([object[]]$records)

    # Per-section human detail, keyed by the exact composed section heading. The KEY
    # set is derived from the rubric (single source of truth); this table only supplies
    # the per-cell human text (what's-missing / owner-must-provide).
    $meta = [ordered]@{
        'Roles and Access Model' = [ordered]@{
            whatsMissing   = 'The role/permission capability matrix (§5.2): which roles exist, their concrete permissions, and how access is granted/revoked. Source code shows the role TYPES but not the authoritative policy.'
            ownerMustProvide = 'Authoritative role catalog + per-role permission matrix (who can do what), plus the access-control policy (RBAC/claims) with owner sign-off.'
        }
        'Operational Workflows' = [ordered]@{
            whatsMissing   = 'The §7.3 sequencing/policy content: the steps of each workflow and their order, who may perform each action, and the escalation thresholds/SLAs. Source shows entry points and procedure contracts, not the policy the owner sets.'
            ownerMustProvide = 'Workflow steps + authorization + escalation policy for each operational workflow (owner-set, not derivable from source); can be supplied as an operator overlay (.appdoc/overlays/operational-workflows.md).'
        }
        'Troubleshooting Matrix' = [ordered]@{
            whatsMissing   = 'The §11 escalation paths: the human escalation routes, on-call contacts, and the triage decision tree. Source shows the diagnostics, not who to escalate to or the path taken.'
            ownerMustProvide = 'Escalation paths + on-call/contacts + triage decision tree (owner-operational knowledge, not derivable from source).'
        }
        'Ownership and Maintenance' = [ordered]@{
            whatsMissing   = 'The §13 ownership/SLO/on-call details: owning team, SLO targets, and on-call rotation. Source shows the components, not who owns them or the SLOs.'
            ownerMustProvide = 'Owning team(s), SLO targets/definitions, and on-call rotation (org knowledge, not derivable from source).'
        }
        'Open Questions and Documentation Gaps' = [ordered]@{
            whatsMissing   = 'The §17 open-questions resolution: answers/owners for each documented gap. The gaps are auto-surfaced, but their RESOLUTIONS + owners are owner-provided.'
            ownerMustProvide = 'For each open gap: the answer (or "unresolved"), a named owner, and a due date/next action.'
        }
    }

    # Derive the cell set from the rubric's ownerPending flag (single source of truth).
    $rubricSections = @(Get-AppDocPristineRubric | Where-Object { [bool]$_.ownerPending })

    $out = New-Object System.Collections.Generic.List[object]
    foreach ($spec in $rubricSections) {
        $section = [string]$spec.section
        if (-not $meta.Contains($section)) { continue }
        # If $records were provided, only emit the cells actually classified
        # OWNER_REQUIRED this run (reuse the classification; drop cells that are,
        # e.g., N/A this run). If none classified OR records absent, emit the full set.
        if ($null -ne $records) {
            $classifiedOR = @($records | Where-Object { [string]$_.section -eq $section -and [string]$_.status -eq 'OWNER_REQUIRED' })
            if ($classifiedOR.Count -eq 0) { continue }
        }
        $m = $meta[$section]
        $out.Add([ordered]@{
            section         = $section
            sectionRef      = [string]$spec.benchmarkRef
            whatsMissing    = [string]$m.whatsMissing
            ownerMustProvide = [string]$m.ownerMustProvide
            # Where the owner records it: an operator overlay for the section (rendered
            # as Operator-supplied). See references/config-schema.md.
            supplyVia       = ('.appdoc/overlays/{0}.md' -f (($section.ToLowerInvariant() -replace '[^a-z0-9]+', '-').Trim('-')))
        })
    }
    return $out
}

# --- PRISTINE GATE decision (Deliverable B) ----------------------------------
# PURE FUNCTION. Decides whether the pristine gate BLOCKS the run. Inputs:
#   -EmptyCount          : number of sections classified EMPTY (source-derivable failure).
#   -SubScore            : the pristine sub-score (N/A already excluded from denominator).
#   -Floor               : the floor the sub-score must meet (default 80, via -PristineFloor).
#   -OwnerRequiredCount  : number of OWNER_REQUIRED cells. IGNORED — NEVER blocks
#                          (they are pending owner input, not failures).
#   -Enabled             : report-only (false, DEFAULT) vs blocking (true, OPT-IN).
# Returns an ordered record: { blocked, floorMet, emptyViolation, blockingIssues }.
#   - Enabled=false (report-only): NEVER blocks (blocked=$false) regardless of counts.
#   - Enabled=true (blocking): blocks iff emptyCount>0 OR subScore<floor.
# This is the single decision point; the gate's status flip in validate-documentation.ps1
# calls THIS, so the decision is unit-testable without touching a real target.
function Test-AppDocPristineGate {
    param(
        [int]$EmptyCount = 0,
        [double]$SubScore = 100.0,
        [int]$Floor = 80,
        [int]$OwnerRequiredCount = 0,
        [bool]$Enabled = $false
    )

    $floorMet = ($SubScore -ge $Floor)
    $emptyViolation = ($EmptyCount -gt 0)

    # OWNER_REQUIRED is EXCLUDED from the gate by construction: $OwnerRequiredCount is
    # never referenced below. A doc with correctly-pending owner cells never blocks.
    $blockingIssues = @()
    $blocked = $false
    if ($Enabled) {
        if ($emptyViolation) {
            $blockingIssues += ("pristine-gate:empty-sections:{0} (EMPTY section(s) present)" -f $EmptyCount)
        }
        if (-not $floorMet) {
            $blockingIssues += ("pristine-gate:below-floor:subScore={0}<{1}" -f $SubScore, $Floor)
        }
        $blocked = ($blockingIssues.Count -gt 0)
    }
    # When NOT enabled (report-only, the DEFAULT): $blocked stays $false and
    # $blockingIssues stays empty — NEVER blocks even if emptyCount>0 / subScore<floor.

    return [ordered]@{
        blocked          = [bool]$blocked
        floorMet         = [bool]$floorMet
        emptyViolation   = [bool]$emptyViolation
        blockingIssues   = @($blockingIssues)
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocPristineAssessment',
    'Test-AppDocPristineSection',
    'Get-AppDocPristineRubric',
    'Get-AppDocPristineSourceSupport',
    'Get-AppDocPristineFrameworkLabel',
    'Get-AppDocPristineFrameworkPrimary',
    'Get-AppDocPristineRealRows',
    'Get-AppDocPristineSectionBody',
    'Test-AppDocPristineEpistemicTagged',
    'Get-AppDocPristineOwnerPendingChecklist',
    'Test-AppDocPristineGate',
    'Get-AppDocPristineSectionSourceCats',
    'Get-AppDocPristineSectionSourceCitations',
    'Test-AppDocPristineSectionRenderedSourceDoc'
)
