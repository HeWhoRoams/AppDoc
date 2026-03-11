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
    Adds/updates generation timestamp and metadata in the template

    .PARAMETER Content
    The content string to update
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content
    )

    $timestamp = Get-Date -Format 'yyyy-MM-dd HH:mm:ss'

    if ($Content -notmatch '\*\*Generated\*\*:') {
        if ($Content -match '(#[^\n]+)\n') {
            $header = $Matches[1]
            $newContent = $Content -replace "($([regex]::Escape($header)))\n", "`$1`n`n**Generated**: $timestamp`n"
            return $newContent
        }
    }
    else {
        $newContent = $Content -replace '\*\*Generated\*\*:\s*[^\n]+', "**Generated**: $timestamp"
        return $newContent
    }

    return $Content
}

function Normalize-AppDocTemplateInstructionText {
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
            return ($m.Groups[1].Value + "`r`nThis section summarizes extracted findings for this artifact.`r`n`r`n")
        }
    )

    # Collapse excessive blank lines produced by removals.
    $updated = [regex]::Replace($updated, '(?s)(\r?\n){3,}', "`r`n`r`n")

    return $updated
}

function Normalize-AppDocMarkdownStructure {
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
        '$1' + "`r`n`r`n" + '$2'
    )
    $updated = [regex]::Replace(
        $updated,
        '(?im)^(##\s+[^\r\n#]+?)\s*(_No[^\r\n_]+_)\s*$',
        '$1' + "`r`n`r`n" + '$2'
    )

    # Prevent no-evidence sentence from living inside markdown table bodies.
    $updated = [regex]::Replace(
        $updated,
        '(?ms)(^\|[^\r\n]+\|\r?\n\|[-:\s|]+\|\r?\n)(No evidence found for this section in the current scan\.)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "`r`n`r`n" + $m.Groups[2].Value)
        }
    )

    # Ensure a blank line separates table blocks from following headings.
    $updated = [regex]::Replace(
        $updated,
        '(?m)(^\|[^\r\n]*\|\r?\n)(##\s+[^\r\n]+)',
        '$1' + "`r`n" + '$2'
    )

    # Normalize summary-style sections to exactly one Summary section.
    if (Get-Command Normalize-AppDocSingleSummarySection -ErrorAction SilentlyContinue) {
        $updated = Normalize-AppDocSingleSummarySection -Content $updated
    }

    # Trim redundant blank lines introduced by cleanup.
    $updated = [regex]::Replace($updated, '(?s)(\r?\n){3,}', "`r`n`r`n")
    return $updated
}

function Normalize-AppDocSingleSummarySection {
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

    $newSummary = "## Summary`r`n`r`n$summaryBody`r`n"
    $generatedRegex = [regex]::new('(?im)^\*\*Generated\*\*:[^\r\n]*\r?\n')
    if ($generatedRegex.IsMatch($updated)) {
        $updated = $generatedRegex.Replace($updated, [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Value + "`r`n" + $newSummary + "`r`n")
        }, 1)
    }
    else {
        $titleRegex = [regex]::new('(?im)^#\s+[^\r\n]+\r?\n')
        if ($titleRegex.IsMatch($updated)) {
            $updated = $titleRegex.Replace($updated, [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Value + "`r`n" + $newSummary + "`r`n")
            }, 1)
        }
        else {
            $updated = $newSummary + "`r`n" + $updated
        }
    }

    $updated = [regex]::Replace($updated, '(?s)(\r?\n){3,}', "`r`n`r`n")
    return $updated.TrimEnd() + "`r`n"
}

