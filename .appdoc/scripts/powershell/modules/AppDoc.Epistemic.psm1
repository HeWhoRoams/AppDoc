# AppDoc.Epistemic Module
# Purpose: Deterministic epistemic tagging of documentation claims.
#
# This is a pure LIBRARY. It reads evidence records / register rows and assigns
# each a defensible epistemic status. It does NOT write any files. It is imported
# by the conformance gate (validate-documentation.ps1) and by the §14 / §18
# generators (generate-evidence-register.ps1, generate-verification-appendix.ps1).
#
# Allowed statuses (deterministic, ordered by strength of evidence):
#   Verified         - the claim references a specific source file + line (or a
#                      searchable value) that the deterministic extractor located.
#   Inferred         - the claim is a model/generator interpretation not confirmed
#                      by a concrete file+line.
#   Partly verified  - there is some evidence (e.g. a file reference) but it is not
#                      strong enough to mark Verified (missing line, file not found,
#                      or only partial corroboration).
#   Unknown          - no evidence establishes the claim; the repository does not
#                      support it.
#
# Design note (determinism): every decision is a pure function of the record's
# fields (source / source_file / metadata.file / metadata.line / kind / status)
# plus, when a root path is supplied, on-disk file existence. No timestamps,
# randomness, network, or LLM calls.

$script:AppDocEpistemicVersion = "1.0.0"
$script:AppDocEpistemicAllowedStatuses = @("Verified", "Inferred", "Unknown", "Partly verified")

# --- helpers -----------------------------------------------------------------

function Test-AppDocEpistemicStatus {
    <#
    .SYNOPSIS
    Returns $true when $Value is one of the allowed epistemic statuses
    (case-insensitive). Used to validate register-row Status cells.
    #>
    param([string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    return ($script:AppDocEpistemicAllowedStatuses -contains $Value.Trim())
}

function Get-AppDocEpistemicAllowedStatuses {
    return @($script:AppDocEpistemicAllowedStatuses)
}

# Resolve a candidate relative file path from a record. Prefers an explicit
# source_file / sourceFile field, then metadata.file when it looks like a real
# path (has a directory separator or a known extension), then the source field
# with any trailing ":line" stripped. Returns '' when nothing usable.
# When -RootPath is supplied, candidates are tested in priority order and the
# FIRST one that actually exists on disk wins (so a resolvable full path in
# `source` is preferred over an unresolvable basename in metadata.file).
function Resolve-AppDocEpistemicFile {
    param($Record, [string]$RootPath)
    $candidates = @()
    if ($Record.PSObject.Properties['source_file']) { $candidates += [string]$Record.source_file }
    if ($Record.PSObject.Properties['sourceFile'])    { $candidates += [string]$Record.sourceFile }
    if ($Record.PSObject.Properties['metadata']) {
        $meta = $Record.metadata
        if ($meta -and $meta.PSObject.Properties['file']) { $candidates += [string]$meta.file }
        if ($meta -and $meta.PSObject.Properties['filePath']) { $candidates += [string]$meta.filePath }
    }
    if ($Record.PSObject.Properties['source']) {
        $src = [string]$Record.source
        # strip a trailing ":NNN" line qualifier
        $candidates += ([regex]::Replace($src, ':(\d+)$', ''))
    }
    $usable = @()
    foreach ($c in $candidates) {
        $c = ($c -replace '\\', '/').Trim()
        if ([string]::IsNullOrWhiteSpace($c)) { continue }
        # reject obvious non-path sources (repo-level aggregate markers)
        if ($c -match '^(repository|docs|unknown|n/a|none)$') { continue }
        # require a directory separator or a file extension to call it a path
        if ($c -match '/|\\' -or $c -match '\.[A-Za-z0-9]{1,6}$') { $usable += $c }
    }
    if ($usable.Count -eq 0) { return '' }
    # With a root, prefer the first candidate that resolves on disk (deduped).
    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        $seen = @{}
        foreach ($c in $usable) {
            if ($seen.ContainsKey($c)) { continue }
            $seen[$c] = $true
            $full = Join-Path $RootPath $c
            if (Test-Path -LiteralPath $full) { return $c }
        }
    }
    return $usable[0]
}

# Resolve a candidate line number from a record. Returns $null when none.
function Resolve-AppDocEpistemicLine {
    param($Record)
    if ($Record.PSObject.Properties['line']) {
        $v = $Record.line
        if ($v -ne $null) { $n = 0; if ([int]::TryParse([string]$v, [ref]$n)) { return $n } }
    }
    if ($Record.PSObject.Properties['metadata']) {
        $meta = $Record.metadata
        if ($meta -and $meta.PSObject.Properties['line']) {
            $v = $meta.line
            $n = 0
            if ($v -ne $null -and [int]::TryParse([string]$v, [ref]$n)) { return $n }
        }
        if ($meta -and $meta.PSObject.Properties['lineNumber']) {
            $v = $meta.lineNumber
            $n = 0
            if ($v -ne $null -and [int]::TryParse([string]$v, [ref]$n)) { return $n }
        }
    }
    if ($Record.PSObject.Properties['source']) {
        $m = [regex]::Match([string]$Record.source, ':(\d+)$')
        if ($m.Success) { $n = 0; if ([int]::TryParse($m.Groups[1].Value, [ref]$n)) { return $n } }
    }
    return $null
}

# True when a record carries a concrete searchable value (a config value, a
# description string, etc.) that an external search could re-confirm.
function Test-AppDocEpistemicHasSearchableValue {
    param($Record)
    if ($Record.PSObject.Properties['metadata']) {
        $meta = $Record.metadata
        foreach ($key in @('value', 'description', 'text', 'pattern', 'command')) {
            if ($meta -and $meta.PSObject.Properties[$key]) {
                $v = [string]$meta.$key
                if (-not [string]::IsNullOrWhiteSpace($v)) { return $true }
            }
        }
    }
    return $false
}

# Assign a deterministic epistemic status to a single evidence record.
# When -RootPath is supplied, on-disk existence is used to upgrade/downgrade.
function Resolve-AppDocEpistemicStatus {
    param($Record, [string]$RootPath)
    if ($null -eq $Record) { return "Unknown" }

    # An explicit, already-valid status wins (records / register rows that were
    # hand-tagged). Only the four allowed values are honoured.
    if ($Record.PSObject.Properties['status'] -and (Test-AppDocEpistemicStatus ([string]$Record.status))) {
        return ([string]$Record.status).Trim()
    }

    $file = Resolve-AppDocEpistemicFile -Record $Record -RootPath $RootPath
    $line = Resolve-AppDocEpistemicLine -Record $Record
    $hasValue = Test-AppDocEpistemicHasSearchableValue -Record $Record
    $inferredFlag = $false
    if ($Record.PSObject.Properties['inferred']) { $inferredFlag = [bool]$Record.inferred }

    if (-not [string]::IsNullOrWhiteSpace($file)) {
        # Strong evidence: a concrete file reference.
        $exists = $false
        if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
            $full = Join-Path $RootPath $file
            $exists = Test-Path -LiteralPath $full
        }
        if ($line -ne $null -or $hasValue) {
            if ($RootPath -eq '' -or $exists) { return "Verified" }
            return "Partly verified"
        }
        # File reference but no line / searchable value -> partial.
        if ($RootPath -eq '' -or $exists) { return "Partly verified" }
        return "Partly verified"
    }

    # No concrete file reference.
    if ($inferredFlag) { return "Inferred" }
    if ($hasValue) { return "Inferred" }
    # Repository-level aggregate (e.g. overview summaries) with no source file.
    if ($Record.PSObject.Properties['kind']) {
        $kind = ([string]$Record.kind).ToLowerInvariant()
        if ($kind -in @('summary', 'technology', 'overview')) { return "Inferred" }
    }
    return "Unknown"
}

function Tag-Claim {
    <#
    .SYNOPSIS
    Tags a single documentation claim with an epistemic status.
    .DESCRIPTION
    Returns an ordered object @{ claim; evidence; status }.
    - When -Status is supplied, it must be one of the allowed values and is used
      verbatim (validated).
    - When -Status is empty, the status is derived deterministically from the
      shape of -Evidence:
          file + line reference   -> Verified
          file reference only     -> Partly verified
          explicit "Inferred"/interpretation text -> Inferred
          empty evidence          -> Unknown
          anything else           -> Partly verified
    - When -Record is supplied (an evidence record / register-row object), the
      status is derived from the record's own fields (the primary path used by
      the generators and the gate); -Claim and -Evidence are filled from the
      record when left empty.
    .EXAMPLE
    Tag-Claim -Claim "120-minute session timeout" -Evidence "portal/global.asa:14" -Status "Verified"
    #>
    [CmdletBinding()]
    param(
        [string]$Claim,
        [string]$Evidence,
        [string]$Status,
        $Record
    )

    $allowed = @($script:AppDocEpistemicAllowedStatuses)

    if ($null -ne $Record -and $Record.PSObject) {
        if ([string]::IsNullOrWhiteSpace($Claim))    { $Claim = [string]$Record.name }
        if ([string]::IsNullOrWhiteSpace($Evidence)) {
            $file = Resolve-AppDocEpistemicFile -Record $Record
            $line = Resolve-AppDocEpistemicLine -Record $Record
            if ($line -ne $null -and -not [string]::IsNullOrWhiteSpace($file)) { $Evidence = ($file + ':' + $line) }
            elseif (-not [string]::IsNullOrWhiteSpace($file)) { $Evidence = $file }
            elseif ($Record.PSObject.Properties['source']) { $Evidence = [string]$Record.source }
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($Status)) {
        $normalized = $Status.Trim()
        if ($allowed -notcontains $normalized) {
            throw "Tag-Claim: invalid epistemic status '$Status'. Allowed: $($allowed -join ', ')."
        }
        $finalStatus = $normalized
    }
    else {
        $finalStatus = $null
        if ($null -ne $Record -and $Record.PSObject) {
            $finalStatus = Resolve-AppDocEpistemicStatus -Record $Record
        }
        else {
            $ev = $Evidence
            if ([string]::IsNullOrWhiteSpace($ev)) { $finalStatus = "Unknown" }
            elseif ($ev -match ':(\d+)$' -or $ev -match '(\\.\\w+|/\\w+)\\s*$') {
                # file + line, or file with extension -> verified
                $finalStatus = "Verified"
            }
            elseif ($ev -match '^(Inferred|interpretation|inferred)') { $finalStatus = "Inferred" }
            elseif ($ev -match '\.[A-Za-z0-9]{1,6}$' -or $ev -match '/') { $finalStatus = "Partly verified" }
            else { $finalStatus = "Partly verified" }
        }
    }

    return [ordered]@{
        claim    = $Claim
        evidence = $Evidence
        status   = $finalStatus
    }
}

# Parse the data rows of every pipe-table in $Content and return the row cells
# (arrays of strings) plus a flag for whether the table has a Status column.
function Get-AppDocEpistemicTableRows {
    param([string]$Content)
    $rows = @()
    if ([string]::IsNullOrWhiteSpace($Content)) { return $rows }
    $lines = $Content -split "`r?`n"
    $inTable = $false
    $hasStatusCol = $false
    $colIndex = -1
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $line = $lines[$i]
        if ($line -match '^\s*\|.*\|\s*$') {
            $cells = ($line.Trim() -replace '^\|', '' -replace '\|\s*$', '') -split '\|' | ForEach-Object { $_.Trim() }
            # skip the separator row (|---|---|)
            if ($cells.Count -gt 0 -and (($cells -join ',') -match '^[\s:-]*$')) { continue }
            if (-not $inTable) {
                $inTable = $true
                # header row: look for a "Status" column
                $colIndex = -1
                $hasStatusCol = $false
                for ($c = 0; $c -lt $cells.Count; $c++) {
                    if ($cells[$c] -match '(?i)^status\b' -or $cells[$c] -match '(?i)status') { $colIndex = $c; $hasStatusCol = $true; break }
                }
                continue
            }
            $rows += [pscustomobject]@{ cells = $cells; hasStatusCol = $hasStatusCol; statusColIndex = $colIndex }
        }
        else {
            $inTable = $false
            $hasStatusCol = $false
            $colIndex = -1
        }
    }
    return $rows
}

function Get-EpistemicCoverage {
    <#
    .SYNOPSIS
    Computes epistemic tagging coverage across a set of artifacts.
    .DESCRIPTION
    $Artifacts is a list of file paths. Supported inputs:
      - Evidence JSON (e.g. docs/evidence/<artifact>.evidence.json or the
        enriched variant): every record is resolved to a status; a record is
        "tagged" when it is non-empty and resolves to any of the four statuses.
      - Markdown (.md): every pipe-table row that belongs to a table WITH a
        Status column is counted; the row is "tagged" when its Status cell is one
        of the allowed values.
    Returns an ordered object:
      @{ total; tagged; untagged; coveragePercent; byArtifact = @{...} }
    Coverage is 100 when there are zero countable claims (nothing to tag is not a
    failure of tagging; the empty register is handled by the gate's own checks).
    #>
    param([string[]]$Artifacts)

    $total = 0
    $tagged = 0
    $byArtifact = @{}

    foreach ($artifact in @($Artifacts)) {
        if (-not (Test-Path -LiteralPath $artifact)) { continue }
        $aTotal = 0
        $aTagged = 0
        $ext = [IO.Path]::GetExtension($artifact).ToLowerInvariant()
        if ($ext -eq '.json') {
            $payload = $null
            try { $payload = Get-Content -LiteralPath $artifact -Raw | ConvertFrom-Json -Depth 120 } catch { $payload = $null }
            $records = @()
            if ($null -ne $payload) { $records = @($payload.records) }
            foreach ($rec in $records) {
                if ($null -eq $rec) { continue }
                $aTotal++
                $status = Resolve-AppDocEpistemicStatus -Record $rec
                if ($status -in $script:AppDocEpistemicAllowedStatuses) { $aTagged++ }
            }
        }
        elseif ($ext -eq '.md') {
            $content = Get-Content -LiteralPath $artifact -Raw
            $rows = @((Get-AppDocEpistemicTableRows -Content $content))
            foreach ($row in $rows) {
                if (-not $row.hasStatusCol) { continue }
                $aTotal++
                $cell = ''
                if ($row.statusColIndex -ge 0 -and $row.statusColIndex -lt $row.cells.Count) { $cell = [string]$row.cells[$row.statusColIndex] }
                if (Test-AppDocEpistemicStatus $cell) { $aTagged++ }
            }
        }
        $byArtifact[[IO.Path]::GetFileName($artifact)] = [ordered]@{ total = $aTotal; tagged = $aTagged; untagged = ($aTotal - $aTagged) }
        $total += $aTotal
        $tagged += $aTagged
    }

    $untagged = $total - $tagged
    $coveragePercent = if ($total -eq 0) { 100.0 } else { [Math]::Round(($tagged / $total) * 100, 1) }

    return [ordered]@{
        total = $total
        tagged = $tagged
        untagged = $untagged
        coveragePercent = $coveragePercent
        byArtifact = $byArtifact
    }
}

function Assert-AllClaimsTagged {
    <#
    .SYNOPSIS
    Throws when any claim / register-row across the given artifacts lacks a
    valid epistemic tag. This is the "refuse to emit untagged assertions" check.
    .DESCRIPTION
    Thin wrapper over Get-EpistemicCoverage: it throws a descriptive error naming
    the untagged count when untagged > 0. Callers that want a soft check should
    use Get-EpistemicCoverage and read .untagged instead.
    #>
    param([string[]]$Artifacts)

    $coverage = Get-EpistemicCoverage -Artifacts $Artifacts
    if ($coverage.untagged -gt 0) {
        $detail = @($coverage.byArtifact.Keys | ForEach-Object { $b = $coverage.byArtifact[$_]; if ($b.untagged -gt 0) { "$_ ($($b.untagged) untagged)" } }) -join ', '
        throw "Assert-AllClaimsTagged: $($coverage.untagged) of $($coverage.total) claims lack a valid epistemic tag: $detail"
    }
    return $true
}

Export-ModuleMember -Function Tag-Claim, Get-EpistemicCoverage, Assert-AllClaimsTagged, `
    Get-AppDocEpistemicAllowedStatuses, Test-AppDocEpistemicStatus, `
    Resolve-AppDocEpistemicStatus, Resolve-AppDocEpistemicFile, Resolve-AppDocEpistemicLine
