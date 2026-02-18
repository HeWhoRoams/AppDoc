#
# template-helpers.ps1
#
# Shared helper functions for template-based documentation generation
#

function Initialize-TemplateFile {
    <#
    .SYNOPSIS
    Copies a template file to the output location if it doesn't exist

    .PARAMETER TemplateName
    Name of the template file (e.g., "api-inventory-template.md")

    .PARAMETER OutputPath
    Full path where the populated file should be written

    .PARAMETER RootPath
    Root path of the target codebase
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$TemplateName,

        [Parameter(Mandatory=$true)]
        [string]$OutputPath,

        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }

    if (-not (Test-Path $OutputPath)) {
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
    }

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

    # Normalize placeholder/no-evidence wording to a single deterministic sentence.
    $updated = [regex]::Replace($updated, '(?im)^\s*_No\s+[^_]+(?:detected|available|documented)\.[^_]*_\s*$', 'No deterministic evidence found in this section for the current scan.')
    $updated = [regex]::Replace($updated, '(?im)^\s*Current scan found 0 items for this section\.?\s*$', 'No deterministic evidence found in this section for the current scan.')

    # Ensure overview is never empty after instruction cleanup.
    $updated = [regex]::Replace(
        $updated,
        '(?ms)(^##\s+Overview\s*\r?\n)\s*(?=##\s+)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "`r`nThis section summarizes generated findings from deterministic codebase analysis.`r`n`r`n")
        }
    )

    # Collapse excessive blank lines produced by removals.
    $updated = [regex]::Replace($updated, '(?s)(\r?\n){3,}', "`r`n`r`n")

    return $updated
}
