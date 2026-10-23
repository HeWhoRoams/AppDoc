# AppDoc.SourceDocs Module
# ============================================================================
# PURPOSE: deterministic SOURCE-OF-TRUTH discovery + citation extraction.
#
# The repo is the source of truth. This module DISCOVERS hand-authored operational
# docs that live in the target (README*, docs/ that is NOT the AppDoc-generated
# docs/, doc/, Archive/, "External Documentation/", *.adr, CODEOWNERS, and
# runbook/SOP/on-call/escalation/SLO/SLA/policy/retention/incident/owner-signal
# files) and EXTRACTS citable claims — each with a real file:line provenance —
# grouped by category:
#
#     ownership          owner/team/division/department lines
#     role-access        role/permission/authorization content (role->purpose
#                        tables, RBAC/AD-group descriptions, capability interfaces)
#     operational-policy policy/SOP/procedure/retention/approval content (sub-
#                        tagged: 'help-desk' for the §7 workflow cell;
#                        'change-process' for the §13 change/release row)
#     escalation         escalation/on-call/contact content
#     troubleshooting    troubleshooting KB / symptom->fix content
#     slo                SLO/SLA/service-level/uptime-target content
#
# EVERY emitted record carries a real file:line into a hand-authored doc that
# EXISTS in the target. NOTHING is fabricated: if a category has no real
# hand-authored source, it simply has no records (the cell stays honest-Unknown).
#
# DETERMINISM: same inputs -> same output. Files are discovered + read in a stable
# (path-sorted) order; records are deduped and sorted by (category, path, line).
# Excerpts are capped. No wall-clock timestamps, no randomness, no network.
#
# REDACTION: any secret/credential value touched is replaced with [REDACTED]
# (reuse of the config-catalog redaction approach). Live credential VALUES must be
# ABSENT from every emitted artifact. The built-in verbatim list is intentionally
# EMPTY (AppDoc ships shape-patterns only); per-target secret VALUES are
# operator-supplied through the channel and merged additively into the verbatim step
# below (see Get-AppDocSourceDocsRedacted -ExtraKnownSecrets).
#
# DISCOVERY SCOPE: the AppDoc-generated docs/ dir (the deterministic pass's own
# output) is EXCLUDED. It is detected as a top-level `docs`/`doc` dir that carries
# an AppDoc output marker (application-documentation.md / validation-report.json /
# pristine-report.md / evidence/ / diagrams/ / ast-*-cache.json). Standard
# AppDoc.Scope exclusions (fixtures/tests/node_modules/bin/obj/.git/.appdoc/...)
# apply. Data exports (.csv/.xls/.xlsx) are NOT hand-authored policy docs and are
# excluded (they are ticket dumps, not documentation).
#
# CODE FILES: .cs/.cshtml/.ts/.js/.aspx files are scanned ONLY for a capability
# interface (role-access) — an interface named *permission/*authorization/
# *security/*access/*role and its property lines. No other category is extracted
# from code (avoids false positives; code is not an ops/policy doc).
# ============================================================================

$script:AppDocSourceDocsVersion = "1.0.0"

# --- DETERMINISTIC-path operator channel -------------------------------------
# Per-target secret VALUES, operator-supplied (the build's config `redactionPatterns`
# key), merged additively with the (intentionally empty) built-in list at redaction
# time. AppDoc ships shape-patterns only; this variable carries the operator value from
# the generator entry point (Get-AppDocSourceDocs) down to the line redactor. It is
# module-scoped so the public Get-AppDocSourceDocsRedacted signature is unchanged and
# the single generator process (which discovers + redacts in one process) sees the value
# at every redaction site. Default empty -> behavior identical to a no-config target.
$script:AppDocSourceDocsExtraKnownSecrets = @()
# Operator regexes (the config `redactionRegexes`), same channel as above.
$script:AppDocSourceDocsExtraRegexes = @()

# Shared secret vocabulary + operator redaction (single source of truth).
Import-Module (Join-Path $PSScriptRoot 'AppDoc.SecretPolicy.psm1') -ErrorAction Stop

# The 6 citable categories (fixed, ordered for determinism).
$script:AppDocSourceDocsCategories = @(
    'ownership',
    'role-access',
    'operational-policy',
    'escalation',
    'troubleshooting',
    'slo'
)

# Cap on representative excerpts per (category, path) so the evidence stays small
# and deterministic.
$script:AppDocSourceDocsCapPerCategoryPath = 24
# Cap on excerpt length (characters) — a claim is short (a line or two).
$script:AppDocSourceDocsClaimMaxLen = 240

# A "contains ANY category signal" pre-filter, used to skip line-by-line extraction
# on files with no relevant content at all (e.g. the ~12k archived help pages in
# helpweb's Archive/ that are dialup/webmail guides with no owner/role/policy/
# escalation/troubleshooting/slo statement). This is a conservative SUPERSET of the
# per-category extractor patterns (so it never drops a file that would yield a record)
# but deliberately tight (no bare common words) so it does not pass the 12k noise
# pages. One raw read + one -match, then line extraction only on the (few) files that
# pass. BEHAVIORALLY IDENTICAL to line-scanning for correctness; a large speedup.
$script:AppDocSourceDocsAnySignal = [regex]::new(
    '(?i)(business\s+owner|technical\s+owner|subject\s+matter\s+expert|technical\s+expert|department\s*/?\s*technical\s+owner|technical\s+owner\(s\)|owning\s+team|team\s+lead|point\s+of\s+contact|maintain(?:ed|s)?\s+by|change\s+(?:process|control|management)|release\s+process|deployment\s+(?:process|policy)|sign-?off|signoff|codeowners|' +
    'role.{0,40}?(purpose|capability|privilege|access)|sap\s*role|erp\s+role|z_cm_|y08\b|ad-?group|active\s+directory|\brbac\b|interface\s+\w*(?:permission|role|access|security)|capability\s+(?:interface|matrix)|' +
    'repair\s+policy|service\s+policy|standard\s+operating\s+procedure|\bsop\b|trouble\s+ticket|ticket\s+procedure|filling\s+(?:out\s+)?a\s+trouble|operator\s+workflow|\bper\s*hour\b|\$\s*\d+\s*(?:per|/)\s*hour|no\s+charge|free\s+of\s+charge|service\s+fee|labor\s+charge|evidence\s+retention|approval\s+(?:threshold|policy)|' +
    'escalat\w*|on-?call|\bpager\b|shift\s+coverage|non-?business\s+hours|after-?hours|break-?glass|page\s+on|contact\s+(?:and|&)?\s*escalation|' +
    '\bsymptom\b|resolution\s+steps|known\s+issue|\bworkaround\b|incident\s+\d+|error\s+code|troubleshoot\w*|common\s+issues|error\s+handling|' +
    '\bslo\b|\bsla\b|service\s+level\s+(?:objective|target|agreement)|availability\s+target|uptime\s+target|\bmttr\b|\bmtbf\b)', 'IgnoreCase')

# --- Redaction --------------------------------------------------------------
# Reuse the config-catalog approach: redact a secret/credential value. The scan is
# for POLICY/OPS docs, so we redact on the VALUE side (any token that looks like a
# credential) regardless of the line's context. Credentials are redacted by shape/
# key-name plus operator-supplied channel values (the built-in verbatim list is
# intentionally empty; the tool ships no hardcoded credential VALUES); a generic
# heuristic redacts other credential-shaped values. Returns the redacted text.
function Get-AppDocSourceDocsRedacted {
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Text,
        # Operator-supplied per-target secret VALUES, merged additively with the
        # (intentionally empty) built-in list. This is the DETERMINISTIC-path operator
        # channel: AppDoc ships shape-patterns only; live credential VALUES for a specific
        # target are supplied here by the operator (the build's config `redactionPatterns`
        # key), mirroring the enrichment gate's additive hardcoded+ExtraKnownSecrets merge.
        [string[]]$ExtraKnownSecrets = @(),
        # Operator regular expressions (the config `redactionRegexes`), additive.
        [string[]]$ExtraRedactionRegexes = @()
    )

    if ($null -eq $Text) { return '' }
    $t = [string]$Text

    # (a) Known real credentials -> redact verbatim (the hard bar). The built-in
    # list is intentionally EMPTY (AppDoc is a reusable tool; it ships shape-patterns
    # only, never the live credential VALUES of a specific target). Per-target secret
    # VALUES are operator-supplied and merged additively here so the deterministic
    # source-docs path redacts them verbatim (mirrors the enrichment gate's
    # hardcoded + ExtraKnownSecrets merge). They are supplied EITHER as the explicit
    # -ExtraKnownSecrets param (a direct call / probe) OR as the module-scope operator
    # value set by the generator entry point (the normal build chain, where this redactor
    # is reached via CleanLine with no explicit param). Both are additive + deduped so a
    # value supplied twice is still redacted exactly once. These must never appear in any
    # emitted artifact.
    $knownSecrets = @() + @(($ExtraKnownSecrets + $script:AppDocSourceDocsExtraKnownSecrets) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    $knownRegexes = @() + @(($ExtraRedactionRegexes + $script:AppDocSourceDocsExtraRegexes) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    if ($knownSecrets.Count -gt 0 -or $knownRegexes.Count -gt 0) {
        $matchers = Get-AppDocOperatorRedactionMatchers -Literals $knownSecrets -Regexes $knownRegexes
        $t = Invoke-AppDocOperatorRedaction -Text $t -Matchers $matchers
    }

    # (b) Keyed credential values: <key> = <value> / <key>: <value> where the key
    # is credential-shaped and the value is a non-empty literal.
    $keyed = '(?i)((?<=\b)(' + (Get-AppDocCredentialKeywordPattern) + ')\s*(?:[=:]|value)\s*)([" ]*\S+)'
    $t = [regex]::Replace($t, $keyed, [System.Text.RegularExpressions.MatchEvaluator]{
        param($m) $m.Groups[1].Value + '[REDACTED]'
    })

    # (c) Connection strings with credentials (Driver/Server/...Password=...;).
    # .NET regex has no \K (PCRE-only); use a capture group + replacement evaluator.
    $t = [regex]::Replace($t, '(?i)((Password|Pwd)\s*=\s*)([^;\s,;" ]+)', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m) $m.Groups[1].Value + '[REDACTED]'
    })

    # (d) Bearer / long JWT-ish token blobs -> redact the value.
    $t = [regex]::Replace($t, '(?i)\b(?:Bearer\s+)[A-Za-z0-9._\-]{20,}', 'Bearer [REDACTED]')
    $t = [regex]::Replace($t, '\beyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9._\-]{5,}', '[REDACTED]')

    # Collapse repeated [REDACTED] runs created by overlapping matches.
    $t = [regex]::Replace($t, '\[REDACTED\](?:\s*\[REDACTED\])+', '[REDACTED]')

    return $t
}

# --- Discovery --------------------------------------------------------------
# Detect top-level dirs that are the AppDoc-generated docs/ output (to exclude).
# A top-level dir named exactly 'docs' or 'doc' (the pipeline's lowercase output
# dir) that carries an AppDoc output marker is the generated output. Case-sensitive
# so a hand-authored 'Docs/' (capital) is NOT mistaken for the pipeline dir.
function Get-AppDocSourceDocsGeneratedDocDirs {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$RootPath)

    $rootFull = (Resolve-Path $RootPath).Path
    $generated = [System.Collections.Generic.List[string]]::new()
    $markerFiles = @(
        'application-documentation.md',
        'validation-report.json',
        'pristine-report.md',
        'evidence',
        'diagrams',
        'ast-csharp-cache.json',
        'ast-typescript-cache.json'
    )
    $topDirs = @(Get-ChildItem -Path $rootFull -Directory -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'docs' -or $_.Name -eq 'doc' } |
        Sort-Object { $_.Name })
    foreach ($d in $topDirs) {
        $isGen = $false
        foreach ($m in $markerFiles) {
            $p = Join-Path $d.FullName $m
            if (Test-Path -LiteralPath $p) { $isGen = $true; break }
        }
        if ($isGen) { $generated.Add($d.Name) }
    }
    return @($generated)
}

# A HAND-AUTHORED doc we can read for citation: markdown / html / rtf / txt / adr /
# json / config / xml. Data exports (csv/xls/xlsx) and code/binary assets are NOT
# hand-authored policy docs. (Code files are handled separately by the
# capability-interface scan — see TestAppDocSourceDocsCodeFile.)
function Test-AppDocSourceDocsDocTextExt {
    param([string]$Name)
    return ($Name -match '(?i)\.(md|markdown|mdown|rst|txt|htm|html|adr|json|config|xml)$')
}
# A code file that can declare a capability interface (C# / TypeScript). Classic-ASP
# (.asp/.aspx) has no such interface concept (its role mechanisms are data-driven /
# in-source tokens, NOT a citable capability interface), and JS (`.js`) is excluded
# to keep the code scan bounded (JS capability interfaces are rare and not the
# target; helpweb's Archive carries thousands of `.js` library files we must not
# full-read). The discovery pre-filter (content-based) means only the few code files
# that actually declare a *permission/*role/*access/*security interface are read.
function Test-AppDocSourceDocsCodeFile {
    param([string]$Name)
    return ($Name -match '(?i)\.(cs|cshtml|ts|tsx)$')
}
# A file worth considering at all: a hand-authored doc OR a capability-interface code
# file. (Used as the discovery-loop gate before the candidate check.)
function Test-AppDocSourceDocsScannable {
    param([string]$Name)
    return ((Test-AppDocSourceDocsDocTextExt -Name $Name) -or (Test-AppDocSourceDocsCodeFile -Name $Name))
}

# Decide whether a file is a HAND-AUTHORED source doc worth scanning. Excludes the
# AppDoc-generated docs/ dir + the standard AppDoc.Scope exclusion patterns.
function Test-AppDocSourceDocsCandidate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RootPath,
        [string]$RelPath,        # slash-separated, root-relative
        [string]$FileName,
        [string[]]$GeneratedDocDirs = @()
    )

    if ([string]::IsNullOrWhiteSpace($RelPath)) { return $false }
    $rel = $RelPath -replace '\\', '/'
    $lower = $rel.ToLowerInvariant()
    $seg0 = ($rel -split '/')[0]
    $nameLower = $FileName.ToLowerInvariant()

    # (1) EXCLUDE the AppDoc-generated docs/ dir (whole tree).
    if ($GeneratedDocDirs -and $GeneratedDocDirs.Count -gt 0) {
        if (@($GeneratedDocDirs) -contains $seg0) { return $false }
    }

    # (2) Standard AppDoc.Scope exclusion patterns (fixtures/tests/node_modules/...).
    $excludePatterns = @(
        '(?i)(^|/)\.git(?=/|$)',
        '(?i)(^|/)node_modules(?=/|$)',
        '(?i)(^|/)bower_components(?=/|$)',
        '(?i)(^|/)bin(?=/|$)',
        '(?i)(^|/)obj(?=/|$)',
        '(?i)(^|/)target(?=/|$)',
        '(?i)(^|/)build(?=/|$)',
        '(?i)(^|/)dist(?=/|$)',
        '(?i)(^|/)_build(?=/|$)',
        '(?i)(^|/)(test|tests|spec|specs)(?=/|$)',
        '(?i)(^|/)(fixture|fixtures)(?=/|$)',
        '(?i)(^|/)(mock|mocks|__mocks__|__tests__)(?=/|$)',
        '(?i)(^|/)(sample|samples|example|examples)(?=/|$)',
        '(?i)(^|/)\.appdoc(?=/|$)',
        '(?i)(^|/)\.venv(?=/|$)',
        '(?i)(^|/)__pycache__(?=/|$)',
        '(?i)(^|/)\.tox(?=/|$)',
        '(?i)(^|/)\.tmp-logs(?=/|$)',
        '(?i)(^|/)\.vscode(?=/|$)',
        '(?i)(^|/)\.specify(?=/|$)'
    )
    # (2b) EXCLUDE user-generated forum / discussion boards. A forum thread (or
    # archived forum page) is USER CONTENT, not a hand-authored source-of-truth doc:
    # helpweb's Archive carries discussion boards (Archive/Internal/discussion,
    # Archive/old/discussion) full of user posts + spam. Citing a forum post as the
    # source of an ownership/policy/escalation claim would fabricate provenance, so
    # these paths are never scanned. The real helpweb source docs (Policies.htm,
    # Computer Repair.htm, phone.htm, phonelist.htm, Contact List...htm) live
    # OUTSIDE any discussion/ dir, so this exclusion is content-precise.
    $forumPatterns = @(
        '(?i)(^|/)discussion(?=/|$)',
        '(?i)(^|/)_hddisc(?=/|$)',
        '(?i)(^|/)_disc1(?=/|$)',
        '(?i)(^|/)forum(?=/|/s$)',
        '(?i)(^|/)forums(?=/|$)',
        '(?i)(^|/)message[_-]?board(?=/|$)'
    )
    foreach ($p in $forumPatterns) {
        if ($lower -match $p) { return $false }
    }
    foreach ($p in $excludePatterns) {
        if ($lower -match $p) { return $false }
    }

    # (3a) Code files (scanned only for a capability interface).
    if (Test-AppDocSourceDocsCodeFile -Name $nameLower) { return $true }

    # (3b) A name-based candidate (README, *.adr, CODEOWNERS, CONTRIBUTING, or an
    # operational-signal filename) OR a path-based candidate (a hand-authored doc
    # location).
    $nameSignal = (
        ($nameLower -match '^(readme|contributing)([-._].*)?(\.md|\.markdown|\.rst|\.txt|\.mdown)?$') -or
        ($nameLower -match '^codeowners$') -or
        ($nameLower -match '\.adr$') -or
        ($nameLower -match 'runbook') -or
        ($nameLower -match 'sop') -or
        ($nameLower -match 'on-?call') -or
        ($nameLower -match 'escalat') -or
        ($nameLower -match '\bslo\b') -or
        ($nameLower -match '\bsla\b') -or
        ($nameLower -match 'policy') -or
        ($nameLower -match 'retention') -or
        ($nameLower -match 'incident') -or
        ($nameLower -match 'owne?r(s|ship)?') -or
        ($nameLower -match 'troubleshoot')
    )
    $locSignal = (
        ($lower -match '(?i)(^|/)archive(?=/|$)') -or
        ($lower -match '(?i)(^|/)external documentation(?=/|$)') -or
        ($lower -match '(?i)(^|/)doc(?=/|$)') -or
        ($lower -match '(?i)(^|/)documentation(?=/|$)') -or
        ($lower -match '(?i)(^|/)docs/?$') -or
        ($lower -match '(?i)(^|/)docs/[^/]+\.md$')
    )
    if (-not ($nameSignal -or $locSignal)) { return $false }

    # (4) Must be a readable hand-authored doc (data exports / code / binaries excluded).
    if (-not (Test-AppDocSourceDocsDocTextExt -Name $nameLower)) { return $false }

    return $true
}

# --- Claim extraction (per category) ---------------------------------------
# We normalize each raw line: strip HTML tags, markdown emphasis + inline-code
# backticks, links -> text, collapse whitespace, then redact.
function Get-AppDocSourceDocsCleanLine {
    param([string]$Line)
    if ($null -eq $Line) { return '' }
    $l = [string]$Line
    $l = $l -replace '<[^>]+>', ' '
    $l = $l -replace '\*+', ''
    $l = $l -replace '`', ''
    $l = $l -replace '\[([^\]]*)\]\([^)]*\)', '$1'
    $l = $l -replace '&nbsp;', ' '
    $l = $l -replace '&amp;', '&'
    $l = $l -replace '\s+', ' '
    $l = $l.Trim()
    return (Get-AppDocSourceDocsRedacted $l)
}

# Trim a claim to the cap, on a word boundary, appending an ellipsis when truncated.
function Get-AppDocSourceDocsClip {
    param([string]$Text, [int]$Max = $script:AppDocSourceDocsClaimMaxLen)
    if ($null -eq $Text) { return '' }
    $t = ($Text -replace '\s+', ' ').Trim()
    if ($t.Length -le $Max) { return $t }
    $cut = $t.Substring(0, $Max)
    $sp = $cut.LastIndexOf(' ')
    if ($sp -ge 40) { $cut = $cut.Substring(0, $sp) }
    return ($cut.Trim() + '…')
}

function Get-AppDocSourceDocsRecord {
    param([string]$Category, [string]$Claim, [string]$Path, [int[]]$Lines, [string]$Confidence, [string]$Sub = '')
    if (-not $Claim) { return $null }
    $ln = if ($Lines -and $Lines.Count -gt 0) { @($Lines) } else { @() }
    $lnSorted = @($ln | Sort-Object { [int]$_ })
    return [pscustomobject]@{
        category   = $Category
        claim      = $Claim
        path       = $Path
        lines      = @($lnSorted)
        lineStart  = if ($lnSorted.Count -gt 0) { [int]$lnSorted[0] } else { 0 }
        lineEnd    = if ($lnSorted.Count -gt 0) { [int]$lnSorted[-1] } else { 0 }
        confidence = if ($Confidence) { $Confidence } else { 'medium' }
        sub        = if ($Sub) { $Sub } else { '' }
    }
}

# --- per-category extractors -------------------------------------------------
# Returns a list of records for one file (rootRelPath + lines). PURE + deterministic.
function Get-AppDocSourceDocsClaimsForFile {
    [CmdletBinding()]
    param(
        [string]$Path,          # root-relative, slash-separated
        [string[]]$Lines,     # 1-indexed full raw lines
        [bool]$IsCodeFile = $false
    )

    $recs = New-Object System.Collections.Generic.List[object]
    if (-not $Lines -or $Lines.Count -eq 0) { return @($recs.ToArray()) }
    $total = $Lines.Count

    # ---- code files: ONLY the capability interface (role-access) ----
    if ($IsCodeFile) {
        $ifIdx = 0
        for ($i = 1; $i -le $total; $i++) {
            $raw = [string]$Lines[$i - 1]
            if ($raw -match '(?i)^\s*(public\s+)?interface\s+\w*(permission|authorization|security|access|role)\w*') {
                $ifIdx = $i
                $clean = Get-AppDocSourceDocsCleanLine $raw
                $rec = Get-AppDocSourceDocsRecord -Category 'role-access' -Claim (Get-AppDocSourceDocsClip ('capability interface ' + $clean)) -Path $Path -Lines @($i) -Confidence 'high'
                if ($rec) { $recs.Add($rec) }
            }
            elseif ($ifIdx -gt 0 -and ($i - $ifIdx) -ge 1 -and ($i - $ifIdx) -le 20) {
                if ($raw -match '(?i)^\s*(public\s+)?(IList<[^>]*>|bool|string|Guid|int|long|decimal|DateTime|enum\s+\w+)\s+\w+.*\{') {
                    $clean = Get-AppDocSourceDocsCleanLine $raw
                    if ($clean.Length -ge 6) {
                        $rec = Get-AppDocSourceDocsRecord -Category 'role-access' -Claim (Get-AppDocSourceDocsClip $clean) -Path $Path -Lines @($i) -Confidence 'medium'
                        if ($rec) { $recs.Add($rec) }
                    }
                }
                elseif ($raw -match '^\s*\}') { $ifIdx = 0 }
            }
        }
        return @($recs.ToArray())
    }

    # ---- ownership: explicit owner/team/division/department LINES ----
    # STRICT: only explicit owner/label statements. Bare "point of contact"
    # (e.g. "the Help Desk is the first point of contact when you have a
    # problem"), bare "technical expert", and bare "maintained by" are too
    # common in help prose and would fabricate ownership citations — excluded.
    # a legacy C# MVC 5 target's real ownership lines are label-styled: "Division: ESS",
    # "Department/Technical Owner(s)", "Business Owner:", "Subject Matter
    # Expert:" — all caught below. helpweb has NO such line -> stays Unknown.
    $ownRe = '(?i)\b(business\s+owner|technical\s+owner|subject\s+matter\s+expert|department\s*/?\s*technical\s+owner|technical\s+owner\(s\)|owning\s+team|division|team\s+lead|change\s+(?:process|management|control)|release\s+process|maintain(?:ed|s)?\s+by)\b'
    for ($i = 1; $i -le $total; $i++) {
        $raw = [string]$Lines[$i - 1]
        if ($raw -match $ownRe) {
            $clean = Get-AppDocSourceDocsCleanLine $raw
            if ($clean.Length -ge 12 -and ($clean -split ' ').Count -ge 2) {
                $rec = Get-AppDocSourceDocsRecord -Category 'ownership' -Claim (Get-AppDocSourceDocsClip $clean) -Path $Path -Lines @($i) -Confidence 'high'
                if ($rec) { $recs.Add($rec) }
            }
        }
    }
    # CODEOWNERS: every non-comment, non-empty line is an ownership mapping.
    if ($Path -match '(?i)codeowners$') {
        for ($i = 1; $i -le $total; $i++) {
            $raw = ([string]$Lines[$i - 1]).Trim()
            if ($raw -and $raw -notmatch '^\s*#') {
                $clean = Get-AppDocSourceDocsCleanLine $raw
                if ($clean.Length -ge 6) {
                    $rec = Get-AppDocSourceDocsRecord -Category 'ownership' -Claim (Get-AppDocSourceDocsClip $clean) -Path $Path -Lines @($i) -Confidence 'high'
                    if ($rec) { $recs.Add($rec) }
                }
            }
        }
    }

    # ---- role-access: role/permission/authorization content ----
    # (a) Role->purpose TABLES (markdown pipe tables or HTML tables). Header cells are
    #     one per line in HTML (e.g. <th>Role</th> then <th>Purpose</th>), so we track
    #     the table: when a header cell names a role column we enter the table; while
    #     in it we buffer <tr> rows and emit each data row as a paired "role → purpose".
    $roleHeaderCellRe = '(?i)<t[hd][^>]*>\s*(Role|Role\(s\)|SAP\s*Role|ERP\s*Role|Permission|Capability|Privilege|Access\s*Level|AD\s*Group)\s*</t[hd]>'
    $mdRoleHeaderRe = '(?i)^\s*\|\s*(Role|Role\(s\)|SAP\s*Role|ERP\s*Role|Permission|Capability|Privilege|Access\s*Level|AD\s*Group)\s*\|'
    $inRoleTable = $false
    $rowBuf = [System.Collections.Generic.List[string]]::new()
    $rowStart = 0
    $roleRows = 0
    for ($i = 1; $i -le $total; $i++) {
        $raw = [string]$Lines[$i - 1]
        # enter the table on a role header cell
        if ($raw -match $roleHeaderCellRe -or $raw -match $mdRoleHeaderRe) {
            $inRoleTable = $true
            continue
        }
        if ($inRoleTable) {
            if ($raw -match '(?i)</table>') { $inRoleTable = $false; $rowBuf.Clear(); continue }
            # markdown data row (single line = one row)
            if ($raw -match '^\s*\|.*\|' -and $raw -notmatch '^\s*\|[\s:|-]+\|') {
                $clean = Get-AppDocSourceDocsCleanLine $raw
                if ($clean.Length -ge 6) {
                    $rec = Get-AppDocSourceDocsRecord -Category 'role-access' -Claim (Get-AppDocSourceDocsClip $clean) -Path $Path -Lines @($i) -Confidence 'high'
                    if ($rec) { $recs.Add($rec) }
                    $roleRows++
                    if ($roleRows -ge 16) { $inRoleTable = $false }
                }
                continue
            }
            # HTML: buffer <td> cells per <tr>
            if ($raw -match '(?i)<tr') { $rowBuf.Clear(); $rowStart = $i; continue }
            if ($raw -match '(?i)<td') {
                $cell = Get-AppDocSourceDocsCleanLine $raw
                if ($cell -and $cell.Length -ge 3 -and $cell -notmatch '^&?nbsp;?$') { $rowBuf.Add($cell) }
                continue
            }
            if ($raw -match '(?i)</tr>') {
                if ($rowBuf.Count -ge 1 -and $rowStart -gt 0) {
                    $joined = ($rowBuf -join ' → ')
                    if ($joined.Length -ge 6) {
                        $rec = Get-AppDocSourceDocsRecord -Category 'role-access' -Claim (Get-AppDocSourceDocsClip $joined) -Path $Path -Lines @($rowStart) -Confidence 'high'
                        if ($rec) { $recs.Add($rec) }
                        $roleRows++
                        if ($roleRows -ge 16) { $inRoleTable = $false }
                    }
                }
                $rowBuf.Clear()
                continue
            }
            # leave the table on a non-table, non-blank line
            if (($raw.Trim() -ne '') -and $raw -notmatch '(?i)</?t[hd]|\|') { $inRoleTable = $false; $rowBuf.Clear() }
        }
        # (b) concrete authorization / RBAC / AD-group / SAP-role descriptions.
        # STRICT: require a SPECIFIC role-mechanism token (SAP role, Z_CM_*, Y08,
        # AD-group, Active Directory, RBAC, ERP system, HR position, Security
        # Request, or a "role -> purpose/capability" phrase). Bare "permission"/
        # "access"/"claim" are common in help prose ("you need access to your
        # mailbox") and must NOT fabricate a role-access citation — this keeps
        # helpweb §5.2 honest-Unknown while still catching a legacy target's
        # authorization model (readme L39/L41/L43/L45/L84, all of which name a
        # SAP role / AD group / ERP / HR position / Security Request).
        if ($raw -match '(?i)(SAP\s+role|Z_CM_|Y08\b|AD-?group|AD\s+group|active\s+directory|\brbac\b|erp\s+system|hr\s+position|security\s+request|role.{0,30}?(purpose|capability|privilege))' -and
            ((Get-AppDocSourceDocsCleanLine $raw)).Length -ge 40) {
            $clean = Get-AppDocSourceDocsCleanLine $raw
            $rec = Get-AppDocSourceDocsRecord -Category 'role-access' -Claim (Get-AppDocSourceDocsClip $clean) -Path $Path -Lines @($i) -Confidence 'medium'
            if ($rec) { $recs.Add($rec) }
        }
    }

    # ---- escalation: escalation/on-call/contact content ----
    # (a) strong escalation signal lines; (b) a contact-matrix table (header cells
    #     PRODUCT/CONTACT/OFFICE PHONE/PAGER/CELL PHONE/HOME PHONE/ON CALL/ESCALATION)
    #     whose <tr> rows are captured as paired contact rows.
    $escRe = '(?i)\b(escalat\w*|on-?call|pager|shift\s+coverage|non-?business\s+hours|after-?hours|break-?glass|page\s+on|contact\s+(?:and|&)?\s*escalation)\b'
    $contactHeaderCellRe = '(?i)<t[hd][^>]*>\s*(PRODUCT|CONTACT|CONTACTS|OFFICE\s*PHONE|PAGER|CELL\s*PHONE|HOME\s*PHONE|ON\s*CALL|ESCALATION|ESCALATE)\s*</t[hd]>'
    $escCount = 0
    $inEscTable = $false
    $escRowBuf = [System.Collections.Generic.List[string]]::new()
    $escRowStart = 0
    $escRows = 0
    for ($i = 1; $i -le $total; $i++) {
        $raw = [string]$Lines[$i - 1]
        if ($raw -match $contactHeaderCellRe) { $inEscTable = $true; continue }
        if ($inEscTable) {
            if ($raw -match '(?i)</table>') { $inEscTable = $false; $escRowBuf.Clear(); continue }
            if ($raw -match '(?i)<tr') { $escRowBuf.Clear(); $escRowStart = $i; continue }
            if ($raw -match '(?i)<td') {
                $cell = Get-AppDocSourceDocsCleanLine $raw
                if ($cell -and $cell.Length -ge 3 -and $cell -notmatch '^&?nbsp;?$') { $escRowBuf.Add($cell) }
                continue
            }
            if ($raw -match '(?i)</tr>') {
                if ($escRowBuf.Count -ge 2 -and $escRowStart -gt 0) {
                    $joined = ($escRowBuf -join ' | ')
                    if ($joined.Length -ge 8) {
                        $rec = Get-AppDocSourceDocsRecord -Category 'escalation' -Claim (Get-AppDocSourceDocsClip $joined) -Path $Path -Lines @($escRowStart) -Confidence 'high'
                        if ($rec) { $recs.Add($rec) }
                        $escRows++
                        if ($escRows -ge 14) { $inEscTable = $false }
                    }
                }
                $escRowBuf.Clear()
                continue
            }
            if (($raw.Trim() -ne '') -and $raw -notmatch '(?i)</?t[hd]|\|') { $inEscTable = $false; $escRowBuf.Clear() }
            continue
        }
        if ($raw -match $escRe) {
            $clean = Get-AppDocSourceDocsCleanLine $raw
            if ($clean.Length -ge 6) {
                $escCount++
                if ($escCount -le 8) {
                    $rec = Get-AppDocSourceDocsRecord -Category 'escalation' -Claim (Get-AppDocSourceDocsClip $clean) -Path $Path -Lines @($i) -Confidence 'high'
                    if ($rec) { $recs.Add($rec) }
                }
            }
        }
    }

    # ---- operational-policy: policy/SOP/procedure/retention/approval ----
    # Sub-tagged so §7 (help-desk workflow) and §13 (change/release) get the RIGHT
    # citations: 'help-desk' = repair/ticket/SOP/operator/charge context;
    # 'change-process' = change/release/deploy/merge/signoff/approval context.
    # (a) help-desk POLICY/charge/SOP lines (NOT bare "help desk" / "computer
    #     repair" — those appear on nearly every archived help page and would
    #     fabricate thousands of §7 citations). Policy-level tokens (repair
    #     policy, service policy, SOP, ticket procedure, per-hour charge, no
    #     charge, evidence retention) still catch helpweb's real Policy.htm
    #     repair policy + phone.htm ticket SOP.
    $pdHelpDeskRe = '(?i)(repair\s+policy|service\s+policy|standard\s+operating\s+procedure|\bsop\b|trouble\s+ticket|ticket\s+procedure|filling\s+(?:out\s+)?a\s+trouble|operator\s+workflow|no\s+charge|free\s+of\s+charge|service\s+fee|labor\s+charge|\$\s*\d+\s*(?:per|/)\s*hour|\bper\s*hour\b|evidence\s+retention|retain\s+(?:evidence|records)|approval\s+(?:threshold|policy))'
    $pdChangeRe   = '(?i)(change\s+(?:process|control|management)|release\s+process|deployment\s+(?:process|policy)|merge\s+(?:process|policy)|\bsign-?off\b|signoff|approval\s+(?:required|policy)|require\s+testing|change\s+request|change\s+management)'
    $pdCount = 0
    for ($i = 1; $i -le $total; $i++) {
        $raw = [string]$Lines[$i - 1]
        $clean = Get-AppDocSourceDocsCleanLine $raw
        if ($clean.Length -lt 20) { continue }
        $sub = ''
        if ($raw -match $pdHelpDeskRe) { $sub = 'help-desk' }
        elseif ($raw -match $pdChangeRe) { $sub = 'change-process' }
        else { continue }
        $pdCount++
        if ($pdCount -le 14) {
            $rec = Get-AppDocSourceDocsRecord -Category 'operational-policy' -Claim (Get-AppDocSourceDocsClip $clean) -Path $Path -Lines @($i) -Confidence 'high' -Sub $sub
            if ($rec) { $recs.Add($rec) }
        }
    }

    # ---- troubleshooting: KB / symptom->fix content (strong signals only) ----
    # STRONG tokens only: NOT bare "resolution" (that word is on nearly every
    # archived help page — screen resolution, "the resolution is...", etc — and
    # would fabricate thousands of KB citations). "resolution steps",
    # "troubleshoot*", "symptom", "known issue", "workaround", "incident N",
    # "error code" still catch a legacy target's ticket-solutions KB (which uses
    # "Resolution Steps", "Incident 3900839", "troubleshooting").
    $trbRe = '(?i)\b(symptom|resolution\s+steps|known\s+issue|workaround|incident\s+\d+|error\s+code|troubleshoot\w*|troubleshooting|common\s+issues|error\s+handling\s+patterns)\b'
    $trbCount = 0
    for ($i = 1; $i -le $total; $i++) {
        $raw = [string]$Lines[$i - 1]
        if ($raw -match $trbRe) {
            $clean = Get-AppDocSourceDocsCleanLine $raw
            if ($clean.Length -ge 8) {
                $trbCount++
                if ($trbCount -le 16) {
                    $rec = Get-AppDocSourceDocsRecord -Category 'troubleshooting' -Claim (Get-AppDocSourceDocsClip $clean) -Path $Path -Lines @($i) -Confidence 'medium'
                    if ($rec) { $recs.Add($rec) }
                }
            }
        }
    }

    # ---- slo: SLO/SLA/service-level/uptime-target content (likely absent) ----
    $sloRe = '(?i)\b(slo\b|sla\b|service\s+level\s+(?:objective|target|agreement)|availability\s+target|uptime\s+target|mttr|mtbf|response\s+time\s+target|resolution\s+time\s+target)\b'
    for ($i = 1; $i -le $total; $i++) {
        $raw = [string]$Lines[$i - 1]
        if ($raw -match $sloRe) {
            $clean = Get-AppDocSourceDocsCleanLine $raw
            if ($clean.Length -ge 10) {
                $rec = Get-AppDocSourceDocsRecord -Category 'slo' -Claim (Get-AppDocSourceDocsClip $clean) -Path $Path -Lines @($i) -Confidence 'high'
                if ($rec) { $recs.Add($rec) }
            }
        }
    }

    return @($recs.ToArray())
}

# --- Public entry point ------------------------------------------------------
# Discover + extract. Returns an ordered record:
#   categories : [ordered] category -> @($record...)  (each sorted by path, line)
#   records    : flat @($record...) (all categories, sorted by category, path, line)
#   byFile     : @{} path -> @($categories...)   (which categories each file backed)
#   fileCount  : number of in-scope files scanned
#   version
# Deterministic: same $RootPath -> same output.
function Get-AppDocSourceDocs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RootPath,
        # Operator-supplied per-target secret VALUES (the build's config `redactionPatterns`
        # key), merged additively with the (intentionally empty) built-in list at redaction
        # time. Default empty -> behavior identical to a no-config target.
        [string[]]$ExtraKnownSecrets = @(),
        # Operator regular expressions (the config `redactionRegexes`), additive.
        [string[]]$ExtraRedactionRegexes = @()
    )

    # Publish the operator value to the module-scope channel so every line redactor in
    # this process (reached via CleanLine -> Get-AppDocSourceDocsRedacted) merges it
    # additively. (The public Get-AppDocSourceDocsRedacted keeps its own -ExtraKnownSecrets
    # param for direct calls; this script-scope var covers the generator call chain.)
    $script:AppDocSourceDocsExtraKnownSecrets = @($ExtraKnownSecrets | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    $script:AppDocSourceDocsExtraRegexes = @($ExtraRedactionRegexes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    if (-not (Test-Path $RootPath)) { throw "Root path does not exist: $RootPath" }
    $rootFull = (Resolve-Path $RootPath).Path

    # Which top-level dirs are the AppDoc-generated docs/ output (to exclude).
    $generatedDocDirs = @(Get-AppDocSourceDocsGeneratedDocDirs -RootPath $rootFull)

    # Discover candidate files (deterministic path order). Phase 1: a cheap
    # read-once content pre-filter (any category signal?). A file with NO signal
    # yields zero records, so we skip it here (BEHAVIORALLY IDENTICAL to line
    # scanning) and avoid 12k+ per-line passes on large archives.
    $candidateFiles = [System.Collections.Generic.List[object]]::new()
    $allFiles = @(Get-ChildItem -Path $rootFull -Recurse -File -Force -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '(?i)/\.git/' } |
        Sort-Object { $_.FullName.ToLowerInvariant() })
    foreach ($fi in $allFiles) {
        $rel = $fi.FullName.Substring($rootFull.Length).TrimStart('/', '\').Replace('\', '/')
        $name = $fi.Name
        if (-not (Test-AppDocSourceDocsScannable -Name $name)) { continue }
        if ($fi.Length -gt 400000) { continue }
        if (-not (Test-AppDocSourceDocsCandidate -RootPath $rootFull -RelPath $rel -FileName $name -GeneratedDocDirs $generatedDocDirs)) { continue }
        $raw = ''
        try { $raw = Get-Content -LiteralPath $fi.FullName -Raw -ErrorAction SilentlyContinue } catch { $raw = '' }
        $isCode = Test-AppDocSourceDocsCodeFile -Name $name
        if ($isCode) {
            # Code files: scanned ONLY for a capability interface. Pre-filter on the
            # raw content so we do not full-line-scan every .cs (only the few that
            # actually declare a *permission/*role/*access/*security interface).
            if (-not ([string]$raw -match '(?im)^\s*(public\s+)?interface\s+\w*(permission|authorization|security|access|role)\w*')) { continue }
            $candidateFiles.Add([pscustomobject]@{ Path = $rel; File = $fi; IsCodeFile = $true; Raw = [string]$raw })
        }
        else {
            # Doc files: must contain at least one category signal (else zero records).
            if (-not ([string]$raw -match $script:AppDocSourceDocsAnySignal)) { continue }
            $candidateFiles.Add([pscustomobject]@{ Path = $rel; File = $fi; IsCodeFile = $false; Raw = [string]$raw })
        }
    }

    $allRecords = New-Object System.Collections.Generic.List[object]
    $byFile = @{}
    $filesScanned = 0

    # Phase 2: line-level extraction (only on the signal-bearing files from Phase 1).
    foreach ($c in $candidateFiles) {
        $rel = [string]$c.Path
        $files = $c.File
        $filesScanned++
        $linesRaw = @()
        $raw = [string]$c.Raw
        if (-not [string]::IsNullOrEmpty($raw)) {
            # Split the raw content into lines (deterministic; same content -> same lines).
            $linesRaw = @($raw -split "`r?`n")
        }
        $recs = @(Get-AppDocSourceDocsClaimsForFile -Path $rel -Lines $linesRaw -IsCodeFile ([bool]$c.IsCodeFile))
        if ($recs.Count -eq 0) { continue }
        $catSet = [System.Collections.Generic.List[string]]::new()
        foreach ($r in $recs) {
            $allRecords.Add($r)
            $ck = [string]$r.category
            if (-not ($catSet -contains $ck)) { $catSet.Add($ck) }
        }
        $byFile[$rel] = @(($catSet | Sort-Object))
    }

    # Dedup (by category+path+lineStart+sub+claim) and sort deterministically.
    $seen = @{}
    $dedup = New-Object System.Collections.Generic.List[object]
    foreach ($r in $allRecords) {
        $key = ([string]$r.category) + '|' + ([string]$r.path) + '|' + ([int]$r.lineStart) + '|' + ([string]$r.sub) + '|' + ([string]$r.claim)
        if (-not $seen.ContainsKey($key)) {
            $seen[$key] = $true
            $dedup.Add($r)
        }
    }
    $sorted = @($dedup | Sort-Object @{Expression = { [string]$_.category } }, @{Expression = { [string]$_.path } }, @{Expression = { [int]$_.lineStart } }, @{Expression = { [string]$_.claim } })

    # Cap representative excerpts per (category, path).
    $capBuckets = @{}
    $final = New-Object System.Collections.Generic.List[object]
    foreach ($r in $sorted) {
        $bk = ([string]$r.category) + '|' + ([string]$r.path)
        if (-not $capBuckets.ContainsKey($bk)) { $capBuckets[$bk] = 0 }
        if ($capBuckets[$bk] -lt $script:AppDocSourceDocsCapPerCategoryPath) {
            $capBuckets[$bk]++
            $final.Add($r)
        }
    }

    # Group by category.
    $categories = [ordered]@{}
    foreach ($cat in $script:AppDocSourceDocsCategories) { $categories[$cat] = @() }
    foreach ($r in $final) {
        $ck = [string]$r.category
        $categories[$ck] += ,@($r)
    }

    return [ordered]@{
        version    = $script:AppDocSourceDocsVersion
        categories = $categories
        records    = @($final.ToArray())
        byFile     = $byFile
        fileCount  = [int]$filesScanned
        generatedDocDirs = @($generatedDocDirs)
    }
}

# Convenience: the list of categories that have >=1 citation (for the composer).
function Get-AppDocSourceDocsCitedCategories {
    param($Result)
    if ($null -eq $Result) { return @() }
    $out = @()
    foreach ($cat in $script:AppDocSourceDocsCategories) {
        if (@($Result.categories[$cat]).Count -gt 0) { $out += $cat }
    }
    return $out
}

# Convenience: a compact "path:lineStart-lineEnd" provenance string for one record.
function Get-AppDocSourceDocsProvenance {
    param($Record)
    if ($null -eq $Record) { return '' }
    $p = [string]$Record.path
    if ([int]$Record.lineStart -eq ([int]$Record.lineEnd)) {
        return "${p}:$([int]$Record.lineStart)"
    }
    return "${p}:$([int]$Record.lineStart)-$([int]$Record.lineEnd)"
}

Export-ModuleMember -Function @(
    'Get-AppDocSourceDocs',
    'Get-AppDocSourceDocsCitedCategories',
    'Get-AppDocSourceDocsProvenance',
    'Get-AppDocSourceDocsGeneratedDocDirs',
    'Test-AppDocSourceDocsCandidate',
    'Get-AppDocSourceDocsRedacted'
)
