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
    
    # Ensure output directory exists
    $outputDir = Split-Path $OutputPath -Parent
    if (-not (Test-Path $outputDir)) {
        New-Item -ItemType Directory -Path $outputDir -Force | Out-Null
    }
    
    # If output file doesn't exist, copy template
    if (-not (Test-Path $OutputPath)) {
        # Find template in .AppDoc/templates/
        $templatePath = Join-Path $RootPath ".AppDoc\templates\$TemplateName"
        
        if (-not (Test-Path $templatePath)) {
            Write-Warning "Template not found: $templatePath"
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
    
    $updatedContent = $Content -replace [regex]::Escape($PlaceholderText), $NewContent
    
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
    
    # Add generation timestamp after the first header if not present
    if ($Content -notmatch '\*\*Generated\*\*:') {
        # Find first header line
        if ($Content -match '(#[^\n]+)\n') {
            $header = $Matches[1]
            $newContent = $Content -replace "($([regex]::Escape($header)))\n", "`$1`n`n**Generated**: $timestamp`n"
            return $newContent
        }
    } else {
        # Update existing timestamp
        $newContent = $Content -replace '\*\*Generated\*\*:\s*[^\n]+', "**Generated**: $timestamp"
        return $newContent
    }
    
    return $Content
}

