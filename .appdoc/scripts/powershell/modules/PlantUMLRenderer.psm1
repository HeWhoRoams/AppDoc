# PlantUMLRenderer Module
# Purpose: Render C4 models to PlantUML diagrams and SVG
# Author: AppDoc
# Date: 2025-11-14

<#
.SYNOPSIS
    Renders C4 models to PlantUML syntax and generates SVG diagrams.

.DESCRIPTION
    This module provides functions to convert C4 model entities into PlantUML
    diagram syntax and render them to SVG using local JAR, online service, or source-only fallback.
#>

# Module-level variables
$script:PlantUMLRendererVersion = "1.0.0"
$script:PlantUMLJarUrl = "https://github.com/plantuml/plantuml/releases/download/v1.2023.12/plantuml-1.2023.12.jar"
$script:PlantUMLOnlineService = "https://www.plantuml.com/plantuml"

#region Java and PlantUML Detection

<#
.SYNOPSIS
    Tests if Java is installed and available.

.DESCRIPTION
    Checks for Java installation by running 'java -version' command.

.OUTPUTS
    Boolean indicating whether Java is available.

.EXAMPLE
    Test-JavaInstallation
#>
function Test-JavaInstallation {
    [CmdletBinding()]
    param()

    Write-Verbose "Checking for Java installation..."

    try {
        $javaVersion = & java -version 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Verbose "Java found: $($javaVersion[0])"
            return $true
        }
    }
    catch {
        Write-Verbose "Java not found: $_"
    }

    Write-Verbose "Java is not installed or not in PATH"
    return $false
}

<#
.SYNOPSIS
    Gets or downloads the PlantUML JAR file.

.DESCRIPTION
    Checks if PlantUML JAR exists in the expected location. If not found and
    -Download is specified, downloads it from GitHub releases.

.PARAMETER Download
    If specified, downloads PlantUML JAR if not found locally.

.OUTPUTS
    Path to PlantUML JAR file, or $null if not found/downloaded.

.EXAMPLE
    Get-PlantUMLJar -Download
#>
function Get-PlantUMLJar {
    [CmdletBinding()]
    param(
        [switch]$Download
    )

    $jarPath = Join-Path $PSScriptRoot "..\..\..\bin\plantuml.jar"
    $jarDir = Split-Path $jarPath -Parent

    Write-Verbose "Checking for PlantUML JAR at: $jarPath"

    if (Test-Path $jarPath) {
        Write-Verbose "PlantUML JAR found"
        return $jarPath
    }

    if ($Download) {
        Write-Verbose "PlantUML JAR not found, attempting download..."
        
        try {
            if (-not (Test-Path $jarDir)) {
                New-Item -ItemType Directory -Path $jarDir -Force | Out-Null
            }

            Write-Host "Downloading PlantUML JAR (one-time setup, ~10MB)..."
            Invoke-WebRequest -Uri $script:PlantUMLJarUrl -OutFile $jarPath -UseBasicParsing
            
            if (Test-Path $jarPath) {
                Write-Verbose "PlantUML JAR downloaded successfully"
                return $jarPath
            }
        }
        catch {
            Write-Warning "Failed to download PlantUML JAR: $_"
        }
    }

    Write-Verbose "PlantUML JAR not available"
    return $null
}

<#
.SYNOPSIS
    Selects the appropriate rendering mode based on available tools.

.DESCRIPTION
    Determines the best rendering mode (Local, Online, SourceOnly) based on
    Java availability, PlantUML JAR presence, and user preferences.

.PARAMETER PreferredMode
    User's preferred rendering mode. Will fallback if not available.

.OUTPUTS
    Selected rendering mode: 'Local', 'Online', or 'SourceOnly'.

.EXAMPLE
    Select-RenderMode -PreferredMode 'Local'
#>
function Select-RenderMode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$false)]
        [ValidateSet('Local', 'Online', 'SourceOnly')]
        [string]$PreferredMode = 'Local'
    )

    Write-Verbose "Selecting render mode (preferred: $PreferredMode)..."

    if ($PreferredMode -eq 'SourceOnly') {
        Write-Verbose "User requested source-only mode"
        return 'SourceOnly'
    }

    if ($PreferredMode -eq 'Local') {
        $hasJava = Test-JavaInstallation
        $jarPath = Get-PlantUMLJar -Download
        
        if ($hasJava -and $jarPath) {
            Write-Verbose "Local rendering available (Java + PlantUML JAR)"
            return 'Local'
        }
        
        Write-Verbose "Local rendering not available, checking online fallback"
    }

    if ($PreferredMode -eq 'Online' -or $PreferredMode -eq 'Local') {
        # Check internet connectivity (simple test)
        try {
            $null = Test-Connection -ComputerName "www.plantuml.com" -Count 1 -Quiet -ErrorAction Stop
            Write-Verbose "Online rendering available"
            return 'Online'
        }
        catch {
            Write-Verbose "Online rendering not available (no internet connection)"
        }
    }

    Write-Verbose "Falling back to source-only mode"
    return 'SourceOnly'
}

#endregion

#region PlantUML Generation Functions

<#
.SYNOPSIS
    Converts a C4 System Context model to PlantUML syntax.

.DESCRIPTION
    Generates PlantUML diagram source code from a C4 System Context model
    using the C4-PlantUML library conventions.

.PARAMETER SystemModel
    Hashtable representing the C4 System Context model.

.PARAMETER TemplatePath
    Path to the PlantUML template file. Optional.

.OUTPUTS
    String containing PlantUML source code.

.EXAMPLE
    ConvertTo-PlantUMLContext -SystemModel $model
#>
function ConvertTo-PlantUMLContext {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$SystemModel,

        [Parameter(Mandatory=$false)]
        [string]$TemplatePath
    )

    Write-Verbose "Generating PlantUML Context diagram..."

    # Load template or use default
    if ($TemplatePath -and (Test-Path $TemplatePath)) {
        $template = Get-Content $TemplatePath -Raw
    }
    else {
        # Use embedded default template
        $template = @"
@startuml C4_Context
!include https://raw.githubusercontent.com/plantuml-stdlib/C4-PlantUML/master/C4_Context.puml

LAYOUT_WITH_LEGEND()

title System Context diagram for {{SYSTEM_NAME}}

System({{SYSTEM_ID}}, "{{SYSTEM_NAME}}", "{{SYSTEM_DESCRIPTION}}")

{{EXTERNAL_SYSTEM_DEFINITIONS}}

{{RELATIONSHIPS}}

@enduml
"@
    }

    # Replace tokens
    $puml = $template -replace '{{SYSTEM_ID}}', $SystemModel.Id
    $puml = $puml -replace '{{SYSTEM_NAME}}', $SystemModel.Name
    $puml = $puml -replace '{{SYSTEM_DESCRIPTION}}', $SystemModel.Description

    # Generate external system definitions
    $externalDefs = ""
    $relationships = ""
    foreach ($ext in $SystemModel.ExternalSystems) {
        $externalDefs += "System_Ext($($ext.Id), `"$($ext.Name)`", `"$($ext.Description)`")`n"
        $relationships += "Rel($($SystemModel.Id), $($ext.Id), `"Uses`", `"HTTPS`")`n"
    }

    $puml = $puml -replace '{{EXTERNAL_SYSTEM_DEFINITIONS}}', $externalDefs.TrimEnd()
    $puml = $puml -replace '{{RELATIONSHIPS}}', $relationships.TrimEnd()
    $puml = $puml -replace '{{PERSON_DEFINITIONS}}', ""  # No persons in basic model

    Write-Verbose "PlantUML Context diagram generated ($($puml.Length) characters)"
    return $puml
}

<#
.SYNOPSIS
    Renders PlantUML source to SVG format.

.DESCRIPTION
    Attempts to render PlantUML to SVG using local JAR (if Java available)
    or online PlantUML service as fallback.

.PARAMETER PlantUMLSource
    PlantUML source code to render.

.PARAMETER RenderMode
    Rendering mode: 'Local', 'Online', or 'SourceOnly'.

.OUTPUTS
    String containing SVG content, or $null if rendering failed/skipped.

.EXAMPLE
    Invoke-PlantUMLRender -PlantUMLSource $puml -RenderMode 'Local'
#>
function Invoke-PlantUMLRender {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$PlantUMLSource,

        [Parameter(Mandatory=$false)]
        [ValidateSet('Local', 'Online', 'SourceOnly')]
        [string]$RenderMode = 'Local'
    )

    Write-Verbose "Rendering PlantUML diagram (mode: $RenderMode)..."

    if ($RenderMode -eq 'SourceOnly') {
        Write-Verbose "Source-only mode: skipping SVG generation"
        return $null
    }

    # Try local rendering first
    if ($RenderMode -eq 'Local') {
        $hasJava = Test-JavaInstallation
        $jarPath = Get-PlantUMLJar -Download
        
        if ($hasJava -and $jarPath) {
            try {
                # Create temp file for PlantUML source
                $tempFile = [System.IO.Path]::GetTempFileName()
                $pumlFile = "$tempFile.puml"
                $svgFile = "$tempFile.svg"
                
                Set-Content -Path $pumlFile -Value $PlantUMLSource -Encoding UTF8
                
                # Render with PlantUML JAR
                $output = & java -jar $jarPath -tsvg $pumlFile 2>&1
                
                if (Test-Path $svgFile) {
                    $svgContent = Get-Content $svgFile -Raw
                    
                    # Cleanup temp files
                    Remove-Item $tempFile -ErrorAction SilentlyContinue
                    Remove-Item $pumlFile -ErrorAction SilentlyContinue
                    Remove-Item $svgFile -ErrorAction SilentlyContinue
                    
                    Write-Verbose "Local rendering successful ($($svgContent.Length) characters)"
                    return $svgContent
                }
            }
            catch {
                Write-Warning "Local rendering failed: $_"
            }
        }
    }

    # Fallback to online rendering
    if ($RenderMode -in @('Local', 'Online')) {
        Write-Verbose "Attempting online rendering..."
        try {
            # Note: Online rendering would require encoding PlantUML source
            # For MVP, we'll return null and rely on source-only fallback
            Write-Warning "Online rendering not yet implemented"
            return $null
        }
        catch {
            Write-Warning "Online rendering failed: $_"
        }
    }

    Write-Verbose "Rendering failed or unavailable"
    return $null
}

<#
.SYNOPSIS
    Converts a C4 Container model to PlantUML syntax.

.DESCRIPTION
    Takes a hashtable representing a C4 Container model and generates
    PlantUML diagram syntax using the C4-PlantUML library.

.PARAMETER Model
    Hashtable containing SystemName, Containers, Relationships, and ExternalSystems.

.PARAMETER TemplatePath
    Optional path to custom PlantUML template file.

.OUTPUTS
    String containing PlantUML diagram source code.

.EXAMPLE
    ConvertTo-PlantUMLContainer -Model $containerModel
#>
function ConvertTo-PlantUMLContainer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Model,

        [Parameter(Mandatory=$false)]
        [string]$TemplatePath
    )

    Write-Verbose "Generating PlantUML Container diagram..."

    # Load template
    if ($TemplatePath -and (Test-Path $TemplatePath)) {
        $template = Get-Content $TemplatePath -Raw
    }
    else {
        # Find default template
        $defaultTemplate = Join-Path $PSScriptRoot "..\templates\c4\c4-container-template.puml"
        if (Test-Path $defaultTemplate) {
            $template = Get-Content $defaultTemplate -Raw
        }
        else {
            Write-Warning "Container template not found at: $defaultTemplate"
            return $null
        }
    }

    # Replace system name
    $puml = $template -replace '{{SYSTEM_NAME}}', $Model.SystemName

    # Generate person definitions (if any)
    $personDefs = ""
    if ($Model.Persons) {
        foreach ($person in $Model.Persons) {
            $personDefs += "Person($($person.Id), `"$($person.Name)`", `"$($person.Description)`")`n"
        }
    }
    $puml = $puml -replace '{{PERSON_DEFINITIONS}}', $personDefs.TrimEnd()

    # Generate container definitions
    $containerDefs = ""
    foreach ($container in $Model.Containers) {
        $containerFunc = switch ($container.Type) {
            "Database" { "ContainerDb" }
            "Queue" { "ContainerQueue" }
            default { "Container" }
        }
        
        $id = $container.Id
        $name = $container.Name
        $tech = $container.Technology
        $desc = $container.Description
        
        $containerDefs += "    $containerFunc($id, `"$name`", `"$tech`", `"$desc`")`n"
    }
    $puml = $puml -replace '{{CONTAINER_DEFINITIONS}}', $containerDefs.TrimEnd()

    # Generate external system definitions
    $externalDefs = ""
    foreach ($ext in $Model.ExternalSystems) {
        $externalDefs += "System_Ext($($ext.Id), `"$($ext.Name)`", `"$($ext.Description)`")`n"
    }
    $puml = $puml -replace '{{EXTERNAL_SYSTEM_DEFINITIONS}}', $externalDefs.TrimEnd()

    # Generate relationships
    $relDefs = ""
    foreach ($rel in $Model.Relationships) {
        $source = $rel.Source
        $target = $rel.Target
        $desc = $rel.Description
        $protocol = if ($rel.Protocol) { $rel.Protocol } else { "" }
        
        if ($protocol) {
            $relDefs += "Rel($source, $target, `"$desc`", `"$protocol`")`n"
        }
        else {
            $relDefs += "Rel($source, $target, `"$desc`")`n"
        }
    }
    $puml = $puml -replace '{{RELATIONSHIPS}}', $relDefs.TrimEnd()

    Write-Verbose "PlantUML Container diagram generated ($($puml.Length) characters)"
    return $puml
}

#endregion

# Export module members
Export-ModuleMember -Function Test-JavaInstallation, Get-PlantUMLJar, Select-RenderMode, ConvertTo-PlantUMLContext, Invoke-PlantUMLRender, ConvertTo-PlantUMLContainer
