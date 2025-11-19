# DiagramIntegration Module
# Purpose: Integrate C4 diagrams into AppDoc documentation
# Author: AppDoc
# Date: 2025-11-14

<#
.SYNOPSIS
    Integrates C4 diagrams into AppDoc documentation output.

.DESCRIPTION
    This module provides functions to save diagram files and embed them
    in Markdown documentation files.
#>

# Module-level variables
$script:DiagramIntegrationVersion = "1.0.0"

<#
.SYNOPSIS
    Saves diagram files to the documentation directory.

.DESCRIPTION
    Saves PlantUML source (.puml) and rendered output (.svg) files to the
    docs/diagrams/ directory.

.PARAMETER DiagramName
    Name of the diagram (e.g., 'c4-context', 'c4-container').

.PARAMETER PlantUMLSource
    PlantUML source code content.

.PARAMETER SVGContent
    SVG content (if rendered). Optional for source-only mode.

.PARAMETER OutputPath
    Base output directory for documentation. Defaults to 'docs'.

.OUTPUTS
    Hashtable with paths to saved files.

.EXAMPLE
    Save-DiagramFiles -DiagramName 'c4-context' -PlantUMLSource $pumlSource -SVGContent $svgContent
#>
function Save-DiagramFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$DiagramName,

        [Parameter(Mandatory=$true)]
        [string]$PlantUMLSource,

        [Parameter(Mandatory=$false)]
        [string]$SVGContent,

        [Parameter(Mandatory=$false)]
        [string]$OutputPath = "docs"
    )

    Write-Verbose "Saving diagram files for: $DiagramName"

    try {
        $diagramsDir = Join-Path $OutputPath "diagrams"
        if (-not (Test-Path $diagramsDir)) {
            New-Item -ItemType Directory -Path $diagramsDir -Force -ErrorAction Stop | Out-Null
            Write-Verbose "Created diagrams directory: $diagramsDir"
        }

        # Copy README template if it doesn't exist
        $readmePath = Join-Path $diagramsDir "README.md"
        if (-not (Test-Path $readmePath)) {
            $templatePath = Join-Path $PSScriptRoot "..\templates\diagrams-readme-template.md"
            if (Test-Path $templatePath) {
                Copy-Item -Path $templatePath -Destination $readmePath -Force -ErrorAction SilentlyContinue
                Write-Verbose "Created diagrams README: $readmePath"
            }
        }

        $pumlPath = Join-Path $diagramsDir "$DiagramName.puml"
        $svgPath = Join-Path $diagramsDir "$DiagramName.svg"

        # Save PlantUML source
        Set-Content -Path $pumlPath -Value $PlantUMLSource -Encoding UTF8 -ErrorAction Stop
        Write-Verbose "Saved PlantUML source: $pumlPath"

        $result = @{
            PlantUMLPath = $pumlPath
            SVGPath = $null
        }

        # Save SVG if provided
        if ($SVGContent) {
            Set-Content -Path $svgPath -Value $SVGContent -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "Saved SVG diagram: $svgPath"
            
            # Check file size (warn if > 500KB)
            $svgFileSize = (Get-Item $svgPath).Length
            $svgFileSizeKB = [math]::Round($svgFileSize / 1024, 2)
            Write-Verbose "SVG file size: $svgFileSizeKB KB"
            
            if ($svgFileSize -gt (500 * 1024)) {
                Write-Warning "SVG file size ($svgFileSizeKB KB) exceeds recommended 500KB target for $DiagramName"
            }
            
            $result.SVGPath = $svgPath
        }
        else {
            Write-Verbose "No SVG content provided (source-only mode)"
        }

        return $result
    }
    catch {
        Write-Error "Failed to save diagram files for ${DiagramName}: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Updates overview.md with Architecture section.

.DESCRIPTION
    Adds or updates an Architecture section in the documentation overview
    file with embedded diagram references.

.PARAMETER OverviewPath
    Path to the overview.md file.

.PARAMETER DiagramReferences
    Array of hashtables containing diagram information (Name, Path, Description).

.OUTPUTS
    Boolean indicating success.

.EXAMPLE
    Update-OverviewMarkdown -OverviewPath "docs/overview.md" -DiagramReferences $diagrams
#>
function Update-OverviewMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$OverviewPath,

        [Parameter(Mandatory=$true)]
        [array]$DiagramReferences
    )

    Write-Verbose "Updating overview markdown: $OverviewPath"

    try {
        # Create overview file if it doesn't exist
        if (-not (Test-Path $OverviewPath)) {
            $overviewDir = Split-Path $OverviewPath -Parent
            if (-not (Test-Path $overviewDir)) {
                New-Item -ItemType Directory -Path $overviewDir -Force -ErrorAction Stop | Out-Null
            }
            
            $initialContent = @"
# System Overview

This document provides an overview of the system architecture and components.

"@
            Set-Content -Path $OverviewPath -Value $initialContent -Encoding UTF8 -ErrorAction Stop
            Write-Verbose "Created new overview file"
        }

        # Read existing content
        $content = Get-Content $OverviewPath -Raw -ErrorAction Stop

        # Generate Architecture section markdown
        $architectureSection = Embed-DiagramReferences -DiagramReferences $DiagramReferences

        # Check if Architecture section already exists
        if ($content -match '##\s+Architecture') {
            # Replace existing Architecture section (use (?s) for multi-line match with .)
            $pattern = '(?s)(##\s+Architecture.*?)(?=##\s+\w+|$)'
            $content = $content -replace $pattern, $architectureSection
            Write-Verbose "Replaced existing Architecture section"
        }
        else {
            # Add Architecture section after overview paragraph
            $content = $content.TrimEnd() + "`n`n" + $architectureSection
            Write-Verbose "Added new Architecture section"
        }

        # Save updated content
        Set-Content -Path $OverviewPath -Value $content -Encoding UTF8 -ErrorAction Stop
        Write-Verbose "Overview markdown updated"

        return $true
    }
    catch {
        Write-Error "Failed to update overview markdown: $_"
        return $false
    }
}

<#
.SYNOPSIS
    Generates markdown with embedded diagram references.

.DESCRIPTION
    Creates markdown syntax for embedding SVG diagrams with proper relative paths.

.PARAMETER DiagramReferences
    Array of hashtables containing diagram information.

.OUTPUTS
    String containing markdown with diagram embeds.

.EXAMPLE
    Embed-DiagramReferences -DiagramReferences $diagrams
#>
function Embed-DiagramReferences {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$DiagramReferences
    )

    Write-Verbose "Generating diagram embed markdown for $($DiagramReferences.Count) diagrams"

    $markdown = @"
## Architecture

The following diagrams illustrate the system architecture using the C4 model:

"@

    foreach ($diagram in $DiagramReferences) {
        $markdown += "`n### $($diagram.Title)`n`n"
        
        if ($diagram.Description) {
            $markdown += "$($diagram.Description)`n`n"
        }

        # Use relative path from docs/ to diagrams/
        $relativePath = "diagrams/$($diagram.FileName)"
        
        if ($diagram.HasSVG) {
            $markdown += "![${diagram.Title}]($relativePath)`n`n"
        }
        else {
            # Link to PlantUML source if no SVG
            $pumlPath = "diagrams/$($diagram.FileName -replace '\.svg$', '.puml')"
            $markdown += "*Diagram source: [$pumlPath]($pumlPath)*`n`n"
            $markdown += "To render this diagram, use PlantUML: `java -jar plantuml.jar -tsvg $pumlPath``n`n"
        }
    }

    return $markdown
}

# Export module members
Export-ModuleMember -Function Save-DiagramFiles, Update-OverviewMarkdown, Embed-DiagramReferences
