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

