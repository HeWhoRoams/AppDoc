#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Generate architecture diagrams in Mermaid format.

.DESCRIPTION
    Analyzes codebase structure and generates visual architecture diagrams
    showing component relationships, data flow, and system architecture.

.PARAMETER RootPath
    Root path of the codebase to analyze (default: current directory)

.PARAMETER OutputPath
    Path to output the diagram file (default: docs/diagrams/architecture.md)

.PARAMETER ExportJson
    Also export diagram data in JSON format compatible with ReactFlow/Davia

.EXAMPLE
    .\generate-architecture-diagram.ps1 -RootPath "C:\MyProject"
    .\generate-architecture-diagram.ps1 -RootPath "." -ExportJson
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$RootPath = ".",
    
    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "docs/diagrams",
    
    [Parameter(Mandatory=$false)]
    [switch]$ExportJson
)

# Resolve absolute path
$RootPath = Resolve-Path $RootPath -ErrorAction Stop
Write-Host "Analyzing codebase at: $RootPath" -ForegroundColor Cyan

# Ensure output directory exists
$OutputDir = Join-Path $RootPath $OutputPath
if (-not (Test-Path $OutputDir)) {
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
}

# Data structures for diagram generation
$Projects = @()
$Components = @()
$Relationships = @()
$ExternalSystems = @()

# Helper function to detect project type
function Get-ProjectType {
    param([string]$ProjectPath, [string]$ProjectName)
    
    $files = Get-ChildItem -Path $ProjectPath -File -Recurse -Depth 2 | Select-Object -ExpandProperty Name
    
    if ($files -contains "angular.json" -or $ProjectName -match "\.UI$|^Web\.UI$") {
        return "angular-ui"
    }
    if ($files -match "Controller\.cs$") {
        return "webapi"
    }
    if ($files -match "Service\.cs$" -and $ProjectName -match "ProcessingService|BackgroundService") {
        return "background-service"
    }
    if ($ProjectName -match "^Common$|\.Common$") {
        return "library"
    }
    if ($ProjectName -match "Persistence|\.Dal$|\.Data$") {
        return "persistence"
    }
    if ($ProjectName -match "\.Tests$") {
        return "test"
    }
    
    return "library"
}

# Helper function to detect external integrations
function Get-ExternalIntegrations {
    param([string]$ProjectPath)
    
    $integrations = @()
    
    # Check for common integration patterns
    $csFiles = Get-ChildItem -Path $ProjectPath -Filter "*.cs" -Recurse -ErrorAction SilentlyContinue | Select-Object -First 100
    
    foreach ($file in $csFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        # Blackboard API
        if ($content -match "Blackboard|BlackBoardService|BbSoapClient") {
            if ($integrations -notcontains "Blackboard LMS") {
                $integrations += "Blackboard LMS"
            }
        }
        
        # SAP
        if ($content -match "SAP|SapEvent|SapService") {
            if ($integrations -notcontains "SAP") {
                $integrations += "SAP"
            }
        }
        
        # SOAP Services
        if ($content -match "\[WebService\]|\[SoapDocumentMethod\]|SoapClient") {
            if ($integrations -notcontains "SOAP Services") {
                $integrations += "SOAP Services"
            }
        }
        
        # External Databases
        if ($content -match "AuthDB|AuthDatabase|ExternalDb") {
            if ($integrations -notcontains "AuthDB") {
                $integrations += "AuthDB"
            }
        }
    }
    
    return $integrations
}

# Scan for projects
Write-Host "Scanning for projects..." -ForegroundColor Yellow

# Look for .csproj, .vbproj, package.json, or folder structure
$projectFiles = Get-ChildItem -Path $RootPath -Filter "*.csproj" -Recurse -Depth 3 -ErrorAction SilentlyContinue
$solutionFiles = Get-ChildItem -Path $RootPath -Filter "*.sln" -File -ErrorAction SilentlyContinue

# If solution file exists, parse it for project references
if ($solutionFiles) {
    $slnContent = Get-Content $solutionFiles[0].FullName -Raw
    $projectMatches = [regex]::Matches($slnContent, 'Project\("{[^}]+}"\)\s*=\s*"([^"]+)"\s*,\s*"([^"]+)"')
    
    foreach ($match in $projectMatches) {
        $projectName = $match.Groups[1].Value
        $projectRelPath = $match.Groups[2].Value
        
        if ($projectRelPath -match "\.csproj$") {
            $projectFullPath = Join-Path $RootPath $projectRelPath
            $projectDir = Split-Path $projectFullPath -Parent
            
            if (Test-Path $projectFullPath) {
                $projectType = Get-ProjectType -ProjectPath $projectDir -ProjectName $projectName
                
                # Skip test projects for main architecture diagram
                if ($projectType -ne "test") {
                    $Projects += @{
                        Name = $projectName
                        Path = $projectRelPath
                        Type = $projectType
                        FullPath = $projectDir
                    }
                }
            }
        }
    }
} else {
    # Fallback: scan for .csproj files
    foreach ($proj in $projectFiles) {
        $projectName = $proj.BaseName
        $projectType = Get-ProjectType -ProjectPath $proj.DirectoryName -ProjectName $projectName
        
        if ($projectType -ne "test") {
            $Projects += @{
                Name = $projectName
                Path = $proj.FullName.Replace($RootPath, "").TrimStart('\', '/')
                Type = $projectType
                FullPath = $proj.DirectoryName
            }
        }
    }
}

Write-Host "Found $($Projects.Count) projects" -ForegroundColor Green

# Detect project relationships (references)
Write-Host "Analyzing project dependencies..." -ForegroundColor Yellow

foreach ($project in $Projects) {
    $csprojPath = Get-ChildItem -Path $project.FullPath -Filter "*.csproj" -ErrorAction SilentlyContinue | Select-Object -First 1
    
    if ($csprojPath) {
        [xml]$csprojXml = Get-Content $csprojPath.FullName -ErrorAction SilentlyContinue
        
        # Find ProjectReference elements
        $projectRefs = $csprojXml.Project.ItemGroup.ProjectReference
        
        foreach ($ref in $projectRefs) {
            if ($ref.Include) {
                $refName = [System.IO.Path]::GetFileNameWithoutExtension($ref.Include)
                
                $Relationships += @{
                    From = $project.Name
                    To = $refName
                    Type = "uses"
                }
            }
        }
    }
}

# Detect external integrations
Write-Host "Detecting external integrations..." -ForegroundColor Yellow

$allExternalSystems = @()
foreach ($project in $Projects) {
    $integrations = Get-ExternalIntegrations -ProjectPath $project.FullPath
    foreach ($integration in $integrations) {
        if ($allExternalSystems -notcontains $integration) {
            $allExternalSystems += $integration
            $ExternalSystems += @{
                Name = $integration
                Type = "external"
            }
        }
        
        # Add relationship
        $Relationships += @{
            From = $project.Name
            To = $integration
            Type = "integrates"
        }
    }
}

Write-Host "Found $($ExternalSystems.Count) external integrations" -ForegroundColor Green

# Generate Mermaid diagram
Write-Host "`nGenerating Mermaid diagram..." -ForegroundColor Cyan

$mermaidDiagram = @"
# System Architecture

## Component Overview

This diagram shows the high-level architecture of the system, including all major components and their relationships.

``````mermaid
graph TB
    %% Style definitions
    classDef uiStyle fill:#e1f5ff,stroke:#0288d1,stroke-width:2px
    classDef apiStyle fill:#fff3e0,stroke:#f57c00,stroke-width:2px
    classDef serviceStyle fill:#f3e5f5,stroke:#7b1fa2,stroke-width:2px
    classDef libraryStyle fill:#e8f5e9,stroke:#388e3c,stroke-width:2px
    classDef persistenceStyle fill:#fff9c4,stroke:#f9a825,stroke-width:2px
    classDef externalStyle fill:#ffebee,stroke:#c62828,stroke-width:2px,stroke-dasharray: 5 5

"@

# Add nodes (projects)
foreach ($project in $Projects) {
    $nodeId = $project.Name -replace '[^a-zA-Z0-9]', ''
    $label = $project.Name
    
    $styleClass = switch ($project.Type) {
        "angular-ui" { "uiStyle" }
        "webapi" { "apiStyle" }
        "background-service" { "serviceStyle" }
        "library" { "libraryStyle" }
        "persistence" { "persistenceStyle" }
        default { "libraryStyle" }
    }
    
    $mermaidDiagram += "`n    $nodeId[$label]:::$styleClass"
}

# Add external system nodes
foreach ($external in $ExternalSystems) {
    $nodeId = $external.Name -replace '[^a-zA-Z0-9]', ''
    $mermaidDiagram += "`n    $nodeId{$($external.Name)}:::externalStyle"
}

$mermaidDiagram += "`n"

# Add edges (relationships)
foreach ($rel in $Relationships) {
    $fromId = $rel.From -replace '[^a-zA-Z0-9]', ''
    $toId = $rel.To -replace '[^a-zA-Z0-9]', ''
    
    $arrow = if ($rel.Type -eq "integrates") { "-.->|calls|" } else { "-->|uses|" }
    
    $mermaidDiagram += "`n    $fromId $arrow $toId"
}

$mermaidDiagram += "`n``````"

# Add component details table
$mermaidDiagram += "`n`n## Component Details`n`n"
$mermaidDiagram += "| Component | Type | Purpose |`n"
$mermaidDiagram += "|-----------|------|---------|`n"

foreach ($project in $Projects) {
    $typeLabel = switch ($project.Type) {
        "angular-ui" { "Frontend (Angular)" }
        "webapi" { "Web API" }
        "background-service" { "Background Service" }
        "library" { "Shared Library" }
        "persistence" { "Data Access Layer" }
        default { "Component" }
    }
    
    $mermaidDiagram += "| $($project.Name) | $typeLabel | Located at ``$($project.Path)`` |`n"
}

if ($ExternalSystems.Count -gt 0) {
    $mermaidDiagram += "`n## External Integrations`n`n"
    foreach ($ext in $ExternalSystems) {
        $mermaidDiagram += "- **$($ext.Name)**: External system integration`n"
    }
}

# Write Mermaid output
$mermaidOutputPath = Join-Path $OutputDir "architecture.md"
$mermaidDiagram | Out-File -FilePath $mermaidOutputPath -Encoding UTF8 -Force
Write-Host "✓ Mermaid diagram saved to: $mermaidOutputPath" -ForegroundColor Green

# Generate JSON export (Davia-compatible format)
if ($ExportJson) {
    Write-Host "`nGenerating JSON export..." -ForegroundColor Cyan
    
    $nodes = @()
    $edges = @()
    $x = 100
    $y = 100
    
    # Layout: arrange in grid
    $col = 0
    $row = 0
    $maxCols = 3
    
    foreach ($project in $Projects) {
        $nodeId = $project.Name -replace '[^a-zA-Z0-9]', ''
        
        $nodes += @{
            id = $nodeId
            data = @{
                label = $project.Name
                file_path = $project.Path
                type = $project.Type
            }
            position = @{
                x = $col * 250
                y = $row * 150
            }
        }
        
        $col++
        if ($col -ge $maxCols) {
            $col = 0
            $row++
        }
    }
    
    # Add external systems
    foreach ($external in $ExternalSystems) {
        $nodeId = $external.Name -replace '[^a-zA-Z0-9]', ''
        
        $nodes += @{
            id = $nodeId
            data = @{
                label = $external.Name
                type = "external"
            }
            position = @{
                x = $col * 250
                y = $row * 150
            }
        }
        
        $col++
        if ($col -ge $maxCols) {
            $col = 0
            $row++
        }
    }
    
    # Add edges
    $edgeId = 0
    foreach ($rel in $Relationships) {
        $fromId = $rel.From -replace '[^a-zA-Z0-9]', ''
        $toId = $rel.To -replace '[^a-zA-Z0-9]', ''
        
        $edges += @{
            id = "e$edgeId"
            source = $fromId
            target = $toId
            label = $rel.Type
        }
        $edgeId++
    }
    
    $jsonData = @{
        nodes = $nodes
        edges = $edges
    } | ConvertTo-Json -Depth 10
    
    $jsonOutputPath = Join-Path $OutputDir "architecture.json"
    $jsonData | Out-File -FilePath $jsonOutputPath -Encoding UTF8 -Force
    Write-Host "✓ JSON export saved to: $jsonOutputPath" -ForegroundColor Green
}

Write-Host "`n✓ Architecture diagram generation complete!" -ForegroundColor Green
Write-Host "  View the diagram by opening: $mermaidOutputPath" -ForegroundColor Cyan
