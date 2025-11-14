<#
.SYNOPSIS
    Generates C4 architecture diagrams from .NET codebases.

.DESCRIPTION
    Analyzes a .NET solution and generates C4 Model architecture diagrams
    (System Context, Container, Component levels) using PlantUML.

.PARAMETER CodebasePath
    Path to the solution file (.sln) or codebase directory.

.PARAMETER OutputPath
    Output directory for generated diagrams. Defaults to 'docs'.

.PARAMETER RenderMode
    Rendering mode: 'Local' (uses Java + PlantUML JAR), 'Online' (uses PlantUML service),
    or 'SourceOnly' (generates .puml files only).

.PARAMETER DiagramLevels
    Which C4 diagram levels to generate: 'Context', 'Container', 'Component', or 'All'.

.PARAMETER Force
    Force regeneration of diagrams even if output files already exist.

.EXAMPLE
    .\generate-c4-diagrams.ps1 -CodebasePath "C:\Code\MyApp\MyApp.sln"

.EXAMPLE
    .\generate-c4-diagrams.ps1 -CodebasePath "C:\Code\MyApp" -RenderMode SourceOnly -Force

.NOTES
    Author: AppDoc
    Date: 2025-11-14
    Version: 1.0.0
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CodebasePath,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "docs",

    [Parameter(Mandatory=$false)]
    [ValidateSet('Local', 'Online', 'SourceOnly')]
    [string]$RenderMode = 'Local',

    [Parameter(Mandatory=$false)]
    [ValidateSet('Context', 'Container', 'Component', 'All')]
    [string]$DiagramLevels = 'Context',

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

# Import required modules
$modulesPath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulesPath "C4ModelBuilder.psm1") -Force
Import-Module (Join-Path $modulesPath "PlantUMLRenderer.psm1") -Force
Import-Module (Join-Path $modulesPath "DiagramIntegration.psm1") -Force

# Start performance tracking
$startTime = Get-Date

Write-Host "=== AppDoc C4 Diagram Generator ===" -ForegroundColor Cyan
Write-Host "Codebase: $CodebasePath"
Write-Host "Output: $OutputPath"
Write-Host "Render Mode: $RenderMode"
Write-Host ""

# Track generated diagrams for documentation integration
$script:GeneratedDiagrams = @()

# Validate codebase path
if (-not (Test-Path $CodebasePath)) {
    Write-Error "Codebase path not found: $CodebasePath"
    exit 1
}

# Find solution file
$solutionFile = $null
if ($CodebasePath -like "*.sln") {
    $solutionFile = $CodebasePath
}
else {
    $slnFiles = Get-ChildItem -Path $CodebasePath -Filter "*.sln" -File
    if ($slnFiles.Count -eq 0) {
        Write-Error "No solution file found in: $CodebasePath"
        exit 1
    }
    $solutionFile = $slnFiles[0].FullName
    Write-Host "Found solution: $($slnFiles[0].Name)" -ForegroundColor Green
}

# Select rendering mode
$selectedMode = Select-RenderMode -PreferredMode $RenderMode
if ($selectedMode -ne $RenderMode) {
    Write-Warning "Preferred render mode '$RenderMode' not available, using '$selectedMode'"
}

# Generate System Context Diagram
if ($DiagramLevels -in @('Context', 'All')) {
    Write-Host "`nGenerating System Context Diagram..." -ForegroundColor Yellow
    
    # Check if diagram already exists
    $contextPath = Join-Path $OutputPath "diagrams\c4-context.puml"
    if ((Test-Path $contextPath) -and -not $Force) {
        Write-Host "  Context diagram already exists (use -Force to regenerate)" -ForegroundColor Gray
    }
    else {
        try {
            # Build C4 model
            $systemModel = Build-SystemContextModel -SolutionPath $solutionFile -Verbose
        
        if ($systemModel) {
            Write-Host "  System: $($systemModel.Name)" -ForegroundColor Green
            Write-Host "  External Systems: $($systemModel.ExternalSystems.Count)" -ForegroundColor Green
            
            # Generate PlantUML
            $templatePath = Join-Path $PSScriptRoot "templates\c4\c4-context-template.puml"
            $pumlSource = ConvertTo-PlantUMLContext -SystemModel $systemModel -TemplatePath $templatePath -Verbose
            
            # Render to SVG (if not source-only)
            $svgContent = $null
            if ($selectedMode -ne 'SourceOnly') {
                $svgContent = Invoke-PlantUMLRender -PlantUMLSource $pumlSource -RenderMode $selectedMode -Verbose
            }
            
            # Save files
            $saved = Save-DiagramFiles -DiagramName "c4-context" -PlantUMLSource $pumlSource -SVGContent $svgContent -OutputPath $OutputPath -Verbose
            
            Write-Host "  Saved: $($saved.PlantUMLPath)" -ForegroundColor Green
            if ($saved.SVGPath) {
                Write-Host "  Saved: $($saved.SVGPath)" -ForegroundColor Green
            }
            else {
                Write-Host "  PlantUML source saved (no SVG rendering)" -ForegroundColor Yellow
                Write-Host "  To render manually: java -jar plantuml.jar -tsvg $($saved.PlantUMLPath)" -ForegroundColor Gray
            }

            # Track for documentation integration
            $script:GeneratedDiagrams += @{
                Title = "System Context Diagram"
                Description = "Shows the $($systemModel.Name) system in its environment, including external systems and integrations."
                FileName = "c4-context.svg"
                HasSVG = ($null -ne $saved.SVGPath)
            }
        }
        else {
            Write-Warning "Failed to build System Context model"
        }
    }
    catch {
        Write-Error "Error generating System Context diagram: $_"
    }
  }
}

# Generate Container Diagram
if ($DiagramLevels -in @('Container', 'All')) {
    Write-Host "`nGenerating Container Diagram..." -ForegroundColor Yellow
    
    # Check if diagram already exists
    $containerPath = Join-Path $OutputPath "diagrams\c4-container.puml"
    if ((Test-Path $containerPath) -and -not $Force) {
        Write-Host "  Container diagram already exists (use -Force to regenerate)" -ForegroundColor Gray
    }
    else {
        try {
            # Build Container model
            $containerModel = Build-ContainerModel -SolutionPath $solutionFile -Verbose
        
        if ($containerModel -and $containerModel.Containers.Count -gt 0) {
            Write-Host "  System: $($containerModel.SystemName)" -ForegroundColor Green
            Write-Host "  Containers: $($containerModel.Containers.Count)" -ForegroundColor Green
            Write-Host "  Relationships: $($containerModel.Relationships.Count)" -ForegroundColor Green
            
            # Generate PlantUML
            $templatePath = Join-Path $PSScriptRoot "templates\c4\c4-container-template.puml"
            $pumlSource = ConvertTo-PlantUMLContainer -Model $containerModel -TemplatePath $templatePath -Verbose
            
            # Render to SVG (if not source-only)
            $svgContent = $null
            if ($selectedMode -ne 'SourceOnly') {
                $svgContent = Invoke-PlantUMLRender -PlantUMLSource $pumlSource -RenderMode $selectedMode -Verbose
            }
            
            # Save files
            $saved = Save-DiagramFiles -DiagramName "c4-container" -PlantUMLSource $pumlSource -SVGContent $svgContent -OutputPath $OutputPath -Verbose
            
            Write-Host "  Saved: $($saved.PlantUMLPath)" -ForegroundColor Green
            if ($saved.SVGPath) {
                Write-Host "  Saved: $($saved.SVGPath)" -ForegroundColor Green
            }
            else {
                Write-Host "  PlantUML source saved (no SVG rendering)" -ForegroundColor Yellow
                Write-Host "  To render manually: java -jar plantuml.jar -tsvg $($saved.PlantUMLPath)" -ForegroundColor Gray
            }

            # Track for documentation integration
            $script:GeneratedDiagrams += @{
                Title = "Container Diagram"
                Description = "Shows the major containers within the $($containerModel.SystemName) system and their relationships."
                FileName = "c4-container.svg"
                HasSVG = ($null -ne $saved.SVGPath)
            }
        }
        else {
            Write-Warning "Failed to build Container model or no containers found"
        }
    }
    catch {
        Write-Error "Error generating Container diagram: $_"
    }
  }
}

if ($DiagramLevels -in @('Component', 'All')) {
    Write-Host "`nComponent diagrams not yet implemented (coming in Phase 6)" -ForegroundColor Gray
}

Write-Host "`n=== Generation Complete ===" -ForegroundColor Cyan
Write-Host "Diagrams saved to: $OutputPath\diagrams\" -ForegroundColor Green

# Calculate and display performance metrics
$endTime = Get-Date
$duration = $endTime - $startTime
Write-Host "`nPerformance Metrics:" -ForegroundColor Cyan
Write-Host "  Generation Time: $($duration.TotalSeconds) seconds" -ForegroundColor Gray
Write-Host "  Diagrams Generated: $($script:GeneratedDiagrams.Count)" -ForegroundColor Gray

# Update documentation with diagram embeds
if ($script:GeneratedDiagrams.Count -gt 0) {
    Write-Host "`nIntegrating diagrams into documentation..." -ForegroundColor Yellow
    
    $overviewPath = Join-Path $OutputPath "overview.md"
    try {
        Update-OverviewMarkdown -OverviewPath $overviewPath -DiagramReferences $script:GeneratedDiagrams -Verbose
        Write-Host "  Updated: $overviewPath" -ForegroundColor Green
    }
    catch {
        Write-Warning "Failed to update overview.md: $_"
    }
}

Write-Host "`n✓ C4 diagram generation complete!" -ForegroundColor Green
