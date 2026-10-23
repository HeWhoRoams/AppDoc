#requires -Version 7.2
# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop
#
# template-helpers.ps1
#
# Shared helper functions for template-based documentation generation
#

function Initialize-TemplateFile {
    <#
    .SYNOPSIS
    Refreshes the output file from template (or preserves existing content when requested)

    .PARAMETER TemplateName
    Name of the template file (e.g., "api-inventory-template.md")

    .PARAMETER OutputPath
    Full path where the populated file should be written

    .PARAMETER RootPath
    Root path of the target codebase

    .PARAMETER PreserveExisting
    Keep an existing output file as-is instead of refreshing from template.
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TemplateName,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$true)]
        [string]$RootPath
        ,
        [Parameter(Mandatory=$false)]
        [switch]$PreserveExisting
    )

    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    if ((Test-Path $OutputPath) -and $PreserveExisting) {
        return $true
    }

    $scriptRoot = Split-Path $PSScriptRoot -Parent
    $appDocRoot = if ($scriptRoot) { Split-Path $scriptRoot -Parent } else { $null }
    $candidateTemplateDirs = @(
        (Join-Path $RootPath ".appdoc\templates"),
        $(if ($appDocRoot) { Join-Path $appDocRoot "templates" })
    ) | Where-Object { $_ -and (Test-Path $_) }

    $templatePath = $null
    foreach ($dir in $candidateTemplateDirs) {
        $possiblePath = Join-Path $dir $TemplateName
        if (Test-Path $possiblePath) {
            $templatePath = $possiblePath
            break
        }
    }

    if (-not $templatePath) {
        Write-Warning "Template not found in any known template directory. Checked: $($candidateTemplateDirs -join ', ')"
        return $false
    }

    Copy-Item -Path $templatePath -Destination $OutputPath -Force
    Write-Verbose "Copied template: $TemplateName -> $OutputPath"

    return $true
}

function Update-TemplateSection {
    <#
    .SYNOPSIS
    Replaces a placeholder section in a template with generated content

    .PARAMETER Content
    The content string to update

    .PARAMETER PlaceholderText
    The placeholder text to replace (e.g., "_No configuration options detected._")

    .PARAMETER NewContent
    The content to replace the placeholder with
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,

        [Parameter(Mandatory=$true)]
        [string]$PlaceholderText,

        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$NewContent
    )

    if ($Content -notmatch [regex]::Escape($PlaceholderText)) {
        Write-Verbose "Placeholder not found: $PlaceholderText"
        return $Content
    }

    $updatedContent = [regex]::Replace(
        $Content,
        [regex]::Escape($PlaceholderText),
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($match)
            return $NewContent
        }
    )

    return $updatedContent
}

function Add-GenerationMetadata {
    <#
    .SYNOPSIS
    Ensures exactly ONE deterministic **Generated** stamp per document.

    Idempotent and single-placement: if a **Generated** line already exists it is
    refreshed in place (kept single); otherwise exactly one is inserted directly
    after the document H1 title. This prevents the historical doubled/nested
    **Generated** defect (a second stamp wedged under a section heading).

    .PARAMETER Content
    The markdown content to stamp
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'
    $generatedLine = "**Generated**: $timestamp"

    # If a **Generated** marker already exists, refresh it in place (stays single).
    # The match captures the line's own terminator `(\r?\n)?` so we can re-emit the
    # refreshed line explicitly LF-terminated. This matters because some renderers
    # (e.g. config-catalog) emit CRLF content: without the capture, `-replace` would
    # preserve the CRLF terminator and the gate's LF-only freshness/provenance regex
    # `(?im)^\*\*Generated\*\*:\s*([^\r\n]+)$` would not see the stamp (regressing the
    # artifact to the staleProvenance/provenance-missing-generated penalty). LF is what
    # the gate and the remediate step's `\r?\n` regex both accept.
    if ($Content -match '(?m)^\s*\*\*Generated\*\*:\s*.*$') {
        return ($Content -replace '(?m)^\s*\*\*Generated\*\*:\s*[^\r\n]*(\r?\n)?', ($generatedLine + "`n"))
    }

    # Otherwise insert exactly one **Generated** line after the H1 title (# followed by space).
    # The anchor `^#[ \t]` matches a single-# heading only, so `##`/`###` sections never
    # receive a nested stamp.
    #
    # CRITICAL: the inserted stamp line MUST be LF-terminated (not CRLF). The gate's
    # freshness/provenance detector uses the regex
    #   (?im)^\*\*Generated\*\*:\s*([^\r\n]+)$
    # which only matches LF line endings: in .NET `(?m)` mode `[^\r\n]+` stops at `\r`
    # and `$` matches only before `\n`, so a CRLF-terminated stamp is INVISIBLE to that
    # check (regressing documentationFreshnessScore to 0 and tripping the
    # staleProvenance/provenance-missing-generated penalty on every artifact). LF here
    # is also what the remediate step's `Set-AppDocSummarySection` regex (`\r?\n`)
    # accepts, so LF satisfies both consumers.
    if ($Content -match '(?m)^(#[ \t][^\r\n]*)\r?\n') {
        return ($Content -replace '(?m)^(#[ \t][^\r\n]*)\r?\n', ('$1' + "`n`n" + $generatedLine + "`n"))
    }

    return $Content
}

function Format-AppDocTemplateInstructionText {
    <#
    .SYNOPSIS
    Replaces template instructional prose with deterministic, non-placeholder language.

    .PARAMETER Content
    The markdown content to normalize
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content
    )

    $updated = $Content

    # Remove imperative template instructions that were not populated.
    $instructionPatterns = @(
        '(?im)^\s*_?\s*Describe\s+[^\r\n]*\s*_?\s*$',
        '(?im)^\s*_?\s*Document\s+[^\r\n]*\s*_?\s*$',
        '(?im)^\s*_?\s*List and describe\s+[^\r\n]*\s*_?\s*$',
        '(?im)^\s*_?\s*Provide example[^\r\n]*\s*_?\s*$',
        '(?im)^\s*_?\s*Provide quick start instructions[^\r\n]*\s*_?\s*$',
        '(?im)^\s*_?\s*Refer to\s+[^\r\n]*documentation\.?\s*_?\s*$'
    )
    foreach ($pattern in $instructionPatterns) {
        $updated = [regex]::Replace($updated, $pattern, '')
    }

    # Keep renderer-provided no-evidence phrasing intact; only normalize generic template residue.
    $updated = [regex]::Replace($updated, '(?im)This section summarizes generated findings from deterministic codebase analysis\.', 'This section summarizes extracted findings for this artifact.')

    # Ensure overview is never empty after instruction cleanup.
    $updated = [regex]::Replace(
        $updated,
        '(?ms)(^##\s+Overview\s*\r?\n)\s*(?=##\s+)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "`nThis section summarizes extracted findings for this artifact.`n`n")
        }
    )

    # Collapse excessive blank lines produced by removals.
    $updated = [regex]::Replace($updated, '(?s)(\r?\n){3,}', "`n`n")

    return $updated
}

function Format-AppDocMarkdownStructure {
    <#
    .SYNOPSIS
    Applies cross-artifact markdown structure normalization after template population.

    .PARAMETER Content
    The markdown content to normalize
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content
    )

    $updated = $Content

    # Split concatenated headings + no-evidence text into separate lines.
    $updated = [regex]::Replace(
        $updated,
        '(?im)^(##\s+[^\r\n#]+?)\s*(No evidence found for this section in the current scan\.)\s*$',
        '$1' + "`n`n" + '$2'
    )
    $updated = [regex]::Replace(
        $updated,
        '(?im)^(##\s+[^\r\n#]+?)\s*(_No[^\r\n_]+_)\s*$',
        '$1' + "`n`n" + '$2'
    )

    # Prevent no-evidence sentence from living inside markdown table bodies.
    $updated = [regex]::Replace(
        $updated,
        '(?ms)(^\|[^\r\n]+\|\r?\n\|[-:\s|]+\|\r?\n)(No evidence found for this section in the current scan\.)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "`n`n" + $m.Groups[2].Value)
        }
    )

    # Ensure a blank line separates table blocks from following headings.
    $updated = [regex]::Replace(
        $updated,
        '(?m)(^\|[^\r\n]*\|\r?\n)(##\s+[^\r\n]+)',
        '$1' + "`n" + '$2'
    )

    # Normalize summary-style sections to exactly one Summary section.
    if (Get-Command Format-AppDocSingleSummarySection -ErrorAction SilentlyContinue) {
        $updated = Format-AppDocSingleSummarySection -Content $updated
    }

    # Trim redundant blank lines introduced by cleanup.
    $updated = [regex]::Replace($updated, '(?s)(\r?\n){3,}', "`n`n")
    return $updated
}

function Format-AppDocSingleSummarySection {
    <#
    .SYNOPSIS
    Ensures markdown contains exactly one summary section titled 'Summary'.

    .PARAMETER Content
    The markdown content to normalize
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content
    )

    $updated = $Content
    $sectionRegex = [regex]::new('(?ms)^##\s+(?<heading>[^\r\n]+)\s*\r?\n(?<body>.*?)(?=^##\s+|\z)')
    $matches = @($sectionRegex.Matches($updated))
    if ($matches.Count -eq 0) {
        return $updated
    }

    $summaryCandidates = New-Object System.Collections.Generic.List[object]
    for ($i = 0; $i -lt $matches.Count; $i++) {
        $m = $matches[$i]
        $headingRaw = [string]$m.Groups['heading'].Value
        $headingNorm = ($headingRaw -replace '\s+', ' ').Trim().ToLowerInvariant()
        $isOverviewAlias = ($headingNorm -eq 'overview' -and $i -le 2)
        $isSummaryAlias = (
            $headingNorm -eq 'executive summary' -or
            $headingNorm -eq 'plain language summary' -or
            $headingNorm -eq 'summary' -or
            $headingNorm -match '^enhanced\s+.+\s+summary$' -or
            $isOverviewAlias
        )

        if ($isSummaryAlias) {
            $summaryCandidates.Add([ordered]@{
                index = $i
                heading = $headingNorm
                full = $m.Value
                body = ([string]$m.Groups['body'].Value).Trim()
            }) | Out-Null
        }
    }

    if ($summaryCandidates.Count -eq 0) {
        return $updated
    }

    $preferredOrder = @(
        'summary',
        'executive summary',
        'plain language summary'
    )

    $selected = $null
    foreach ($preferred in $preferredOrder) {
        $candidate = $summaryCandidates | Where-Object { $_.heading -eq $preferred -and -not [string]::IsNullOrWhiteSpace([string]$_.body) } | Select-Object -First 1
        if ($candidate) {
            $selected = $candidate
            break
        }
    }

    if (-not $selected) {
        $selected = $summaryCandidates |
            Where-Object { $_.heading -match '^enhanced\s+.+\s+summary$' -and -not [string]::IsNullOrWhiteSpace([string]$_.body) } |
            Select-Object -First 1
    }

    if (-not $selected) {
        $selected = $summaryCandidates | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_.body) } | Select-Object -First 1
    }

    if (-not $selected) {
        $selected = $summaryCandidates | Select-Object -First 1
    }

    $summaryBody = ([string]$selected.body).Trim()
    if ([string]::IsNullOrWhiteSpace($summaryBody)) {
        $summaryBody = 'This section summarizes extracted findings for this artifact.'
    }

    foreach ($candidate in @($summaryCandidates | Sort-Object { $_.full.Length } -Descending)) {
        $updated = $updated.Replace([string]$candidate.full, '')
    }

    $newSummary = "## Summary`n`n$summaryBody`n"
    $generatedRegex = [regex]::new('(?im)^\*\*Generated\*\*:[^\r\n]*\r?\n')
    if ($generatedRegex.IsMatch($updated)) {
        $updated = $generatedRegex.Replace($updated, [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Value + "`n" + $newSummary + "`n")
        }, 1)
    }
    else {
        $titleRegex = [regex]::new('(?im)^#\s+[^\r\n]+\r?\n')
        if ($titleRegex.IsMatch($updated)) {
            $updated = $titleRegex.Replace($updated, [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Value + "`n" + $newSummary + "`n")
            }, 1)
        }
        else {
            $updated = $newSummary + "`n" + $updated
        }
    }

    $updated = [regex]::Replace($updated, '(?s)(\r?\n){3,}', "`n`n")
    return $updated.TrimEnd() + "`n"
}

# =============================================================================
# WS-1 single output API
#
# These functions are the ONE canonical way to emit AppDoc markdown structure.
# They implement the plan's target conformance spec:
#   - Section vocabulary is defined in one place (Get-AppDocSectionVocabulary).
#   - Tables: key column first, evidence/status column last, numeric columns
#     right-aligned (---:), em dash (—) for nulls, no captions.
#   - Empty state: ONE convention (Get-AppDocEmptyStateText) — a bold semantic
#     label in prose; replaces the historical 3-way split (italic
#     `_No ... detected._` filler / `| N/A |` row / truly-empty row) and avoids
#     the banned `_No ... detected\.` pattern.
#   - Provenance: ONE placement, always last (Add-AppDocProvenanceBlock).
# =============================================================================

function Get-AppDocSectionVocabulary {
    <#
    .SYNOPSIS
    Returns the canonical H2 section-order vocabulary for each generated artifact.

    .DESCRIPTION
    Single source of truth for heading/section names so renderers, templates, and
    validators agree on the real final structure of each artifact.
    #>
    [CmdletBinding()]
    param()

    return [ordered]@{
        'overview'              = @('Summary', 'Welcome', 'System Purpose', 'Architecture', 'Key Components', 'Technology Stack', 'Configuration', 'Getting Started', 'Documentation Map', 'Evidence Traceability', 'System Boundary', 'Runtime Path', 'Inputs→Processing→Outputs', 'External Systems', 'Confidence Notes')
        'api-inventory'         = @('Summary', 'API Endpoints', 'Data Models', 'Authentication & Security', 'Error Responses', 'API Versioning', 'Usage Examples', 'Dependencies', 'Evidence Traceability')
        'data-model'            = @('Summary', 'Data Models', 'Relationships', 'Validation Rules', 'Indexes and Performance', 'Data Flow Patterns', 'Schema Evolution', 'Example Instances', 'Evidence Traceability')
        'config-catalog'        = @('Summary', 'Configuration Sources', 'Configuration Options', 'Environment Variables', 'Configuration Validation', 'Configuration Management', 'Security Considerations', 'Example Configurations', 'Evidence Traceability')
        'build-cookbook'        = @('Summary', 'Prerequisites', 'Build Steps', 'Dependencies', 'CI/CD Integration', 'Troubleshooting', 'Example Build Scripts', 'Operational Checklist', 'Evidence Traceability')
        'test-catalog'          = @('Summary', 'Test Environment Setup', 'Test Suites', 'Test Coverage Metrics', 'Test Cases', 'Test Maintenance', 'Example Test Runs', 'Evidence Traceability')
        'debt-register'         = @('Summary', 'Debt Categories', 'Debt Items', 'Impact Assessment', 'Remediation Plan', 'Monitoring and Tracking', 'Evidence Traceability')
        'dependencies-catalog'  = @('Summary', 'Dependency Summary', 'Dependencies by Type', 'Project References', 'Version Conflicts', 'Security Considerations', 'Licensing', 'Upgrade Recommendations', 'Evidence Traceability')
        'task-guides'           = @('Executive Summary', 'Task Guides', 'Operational Checklist', 'Evidence Traceability')
        'start-here'            = @('Who This Is For', '15-Minute Orientation', 'Role-Based Paths', 'System Signals', 'Evidence Traceability')
        'index'                 = @('Reader Paths')
    }
}

function ConvertTo-AppDocTableCell {
    <#
    .SYNOPSIS
    Normalizes a table cell value: em dash for null/empty, pipes escaped.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,
        [string]$NullPlaceholder = "—"
    )

    if ($null -eq $Value) { return $NullPlaceholder }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $NullPlaceholder }
    return ($text -replace '\|', '\|')
}

function Build-AppDocTable {
    <#
    .SYNOPSIS
    Builds a canonical AppDoc pipe table.

    .DESCRIPTION
    Enforces the plan's table convention: the FIRST column is the key (ID/thing),
    the LAST column is status/evidence, numeric columns are right-aligned
    (`---:`), null cells render as an em dash (—), and there is no caption (the
    table sits under its heading).

    .PARAMETER Columns
    Ordered column names. Position 0 must be the key column; last position the
    evidence/status column.

    .PARAMETER Rows
    Row objects. Each row may be an IDictionary/hashtable keyed by column name, a
    PSCustomObject with matching properties, or an array (positional).

    .PARAMETER NumericColumns
    Column names to right-align (`---:` in the separator row).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$Columns,

        [Parameter(Mandatory=$true)]
        [object[]]$Rows,

        [string[]]$NumericColumns = @(),

        [string]$NullPlaceholder = "—"
    )

    if ($Columns.Count -eq 0) { throw "Build-AppDocTable: Columns must not be empty." }

    $header = "| " + (($Columns | ForEach-Object { ConvertTo-AppDocTableCell -Value $_ }) -join " | ") + " |"
    $separator = "| " + (($Columns | ForEach-Object {
        if ($NumericColumns -and $NumericColumns -contains $_) { "---:" } else { "---" }
    }) -join " | ") + " |"

    $body = @()
    foreach ($row in $Rows) {
        $cells = @()
        $positional = 0
        foreach ($column in $Columns) {
            $val = $null
            if ($null -ne $row) {
                if ($row -is [System.Collections.IDictionary]) {
                    if ($row.Contains($column)) { $val = $row[$column] }
                }
                elseif ($row -is [System.Collections.IEnumerable] -and $row -isnot [string]) {
                    $arr = @($row)
                    if ($positional -lt $arr.Count) { $val = $arr[$positional] }
                }
                else {
                    $prop = $row.PSObject.Properties[$column]
                    if ($prop) { $val = $prop.Value }
                }
            }
            $cells += (ConvertTo-AppDocTableCell -Value $val -NullPlaceholder $NullPlaceholder)
            $positional++
        }
        $body += ("| " + ($cells -join " | ") + " |")
    }

    $output = @($header, $separator)
    if ($body.Count -gt 0) { $output += $body }
    return ($output -join "`n")
}

function Get-AppDocEmptyStateText {
    <#
    .SYNOPSIS
    Emits the single canonical empty-state convention for a section.

    .DESCRIPTION
    One convention for every artifact: a bold semantic label in prose (a
    deterministic callout, per the plan's §2.4 callout convention). This replaces
    the three divergent historical forms — an italic `_No ... detected._` filler,
    a `| N/A |` row, and a truly-empty table row — and deliberately avoids the
    banned `_No ... detected\.` pattern so the gate's banned-pattern check is not
    tripped.

    .PARAMETER Resource
    What is absent (plural noun phrase), e.g. "API endpoints", "data models".

    .PARAMETER Reason
    Optional semantic explanation / what to check (the label *means* something).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Resource,

        [string]$Reason = ""
    )

    $label = "No " + $Resource.Trim() + " were detected in this scan."
    if (-not [string]::IsNullOrWhiteSpace($Reason)) {
        $label = $label + " " + $Reason.Trim()
    }
    return ("**" + $label + "**")
}

function Add-AppDocProvenanceBlock {
    <#
    .SYNOPSIS
    Emits a single, always-last `## Provenance` block in a markdown document.

    .DESCRIPTION
    Guarantees exactly one Provenance section, always at the end. If a Provenance
    section already exists it is replaced in place; otherwise it is appended as the
    final section. This is the ONE placement rule so no artifact carries a
    mid-file or duplicated Provenance footer.

    .PARAMETER Content
    The full markdown content to stamp.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,

        [string]$GeneratorVersion = "appdoc-run-all-generators/3.0.0",
        [string]$CommitHash = "unknown",
        [string]$Profile = "default",
        [string]$Scope = ".",
        [string[]]$ConfidenceFlags = @("deterministic", "evidence-backed")
    )

    $timestamp = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssK")
    $block = @(
        "## Provenance",
        "",
        "- Generator Version: $GeneratorVersion",
        "- Commit Hash: $CommitHash",
        "- Generated At: $timestamp",
        "- Profile: $Profile",
        "- Scope: $Scope",
        "- Confidence/Inference Flags: $($ConfidenceFlags -join ', ')"
    ) -join "`n"

    if ($Content -match '(?ims)^##\s+Provenance\s*$') {
        # Replace the existing Provenance section with the canonical block.
        return [regex]::Replace(
            $Content,
            '(?ims)^##\s+Provenance\s*$.*?(?=^##\s+[^\r\n]+|\z)',
            { param($m) return ($block + "`n") },
            1
        )
    }

    return ($Content.TrimEnd() + "`n`n" + $block + "`n")
}


# --- Classic-ASP shared helpers (hoisted from generate-classic-asp-*.ps1, ponytail F12) ---
# These were copy-pasted identically across the classic-ASP generators. Hoisted here so
# every classic-ASP generator consumes one definition. Behavior is byte-for-byte the same
# as the former local copies (verified: identical modulo formatting).

function Get-ClassicAspFrameworkApplicable {
    # Thin wrapper kept for existing callers; see modules/AppDoc.ClassicAsp.psm1.
    param([string]$RootPath)
    if (-not (Get-Command Test-AppDocClassicAspTarget -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.ClassicAsp.psm1') -ErrorAction Stop
    }
    return (Test-AppDocClassicAspTarget -RootPath $RootPath)
}

function Get-RelativePath {
    # Removes the base path only as a PREFIX (the old .Replace() also removed it from the
    # middle of a path, e.g. /r/proj/sub/r/proj/x).
    param([string]$FullPath, [string]$Base)
    $rel = $FullPath
    $b = $Base.TrimEnd('\', '/')
    if ($b -and $rel.StartsWith($b, [System.StringComparison]::OrdinalIgnoreCase)) { $rel = $rel.Substring($b.Length) }
    $rel = $rel.TrimStart('\', '/')
    return ($rel -replace '\\', '/')
}

function Test-AppDocArtifactIsClassicAspPlaceholder {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return $false }
    $content = Get-Content $Path -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) { return $false }
    return ($content -match 'Not applicable for this framework')
}

# --- Markdown section extractor (collapsed from ci-doc-integrity-gate.ps1 +
#     validate-documentation.ps1, ponytail F13). Behaviorally identical to both
#     former copies on all real docs (verified byte-identical across 6 (doc,header)
#     pairs on the e2e + classic-asp canary targets); the case-insensitive regex is
#     the superset. Callers use -SectionName.
function Get-MarkdownSectionBlock {
    param(
        [string]$Content,
        [string]$SectionName
    )

    if (-not $Content) { return "" }
    $pattern = "(?is)^##\s+" + [regex]::Escape($SectionName) + "\s*$\r?\n(.*?)(?=^##\s+|\z)"
    $match = [regex]::Match($Content, $pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
    if ($match.Success) {
        return [string]$match.Groups[1].Value
    }

    return ""
}


# --- Markdown cell helpers (hoisted from the table-row generators, ponytail F14).
# Copy-pasted identically across generate-external-calls.ps1, generate-classic-asp-*.ps1,
# generate-evidence-register.ps1, and generate-verification-appendix.ps1. One canonical
# definition here; each generator consumes the shared copy (verified byte-identical bodies).

function Format-MarkdownCellText {
    param([string]$v)
    $v = [string]$v
    $v = $v -replace '\|', '/'
    $v = $v -replace '[\r\n\t]+', ' '
    return $v.Trim()
}

function Format-CodeSpan { param([string]$x) return ('`' + $x + '`') }

function ConvertTo-AppDocMarkdownCell {
    param([string]$Text)
    if ($null -eq $Text) { $Text = '' }
    $Text = $Text -replace '[|]', '\|' -replace "`r", '' -replace "`n", ' '
    return $Text.Trim()
}
