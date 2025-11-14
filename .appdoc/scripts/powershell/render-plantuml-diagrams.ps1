<#
.SYNOPSIS
    Renders PlantUML (.puml) files to SVG diagrams using local PlantUML JAR.

.DESCRIPTION
    Standalone script to convert PlantUML source files to SVG diagrams.
    This script:
    - Downloads PlantUML JAR if not present (one-time setup)
    - Validates Java installation
    - Renders all .puml files in specified directory to SVG

    This is the THIRD step in the AppDoc diagram workflow:
    1. generate-c4-diagrams.ps1 -RenderMode SourceOnly  (generates baseline .puml)
    2. /appdoc.diagrams (AI enhances .puml files)
    3. render-plantuml-diagrams.ps1 (renders enhanced .puml to SVG)

.PARAMETER DiagramPath
    Path to directory containing .puml files to render.
    Default: .\docs\diagrams

.PARAMETER PlantUMLJarPath
    Path where PlantUML JAR should be stored/found.
    Default: .\.appdoc\bin\plantuml.jar

.PARAMETER Force
    Re-render diagrams even if SVG already exists and is newer than .puml source.

.EXAMPLE
    .\render-plantuml-diagrams.ps1
    
    Renders all .puml files in .\docs\diagrams using default JAR location.

.EXAMPLE
    .\render-plantuml-diagrams.ps1 -DiagramPath ".\LmsConnect-master\docs\diagrams"
    
    Renders diagrams from specific path.

.EXAMPLE
    .\render-plantuml-diagrams.ps1 -Force
    
    Forces re-rendering even if SVG files are up-to-date.

.NOTES
    Author: AppDoc
    Date: 2025-11-14
    Requires: Java 8+ installed and in PATH
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$false)]
    [string]$DiagramPath = ".\docs\diagrams",
    
    [Parameter(Mandatory=$false)]
    [string]$PlantUMLJarPath = ".\.appdoc\bin\plantuml.jar",
    
    [Parameter(Mandatory=$false)]
    [switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

#region Helper Functions

function Write-ColorText {
    param(
        [string]$Message,
        [ConsoleColor]$Color = 'White'
    )
    Write-Host $Message -ForegroundColor $Color
}

function Test-JavaInstallation {
    try {
        $javaVersion = & java -version 2>&1
        if ($LASTEXITCODE -eq 0) {
            return @{
                Available = $true
                Version = $javaVersion[0]
            }
        }
    }
    catch {
        # Java not found
    }
    
    return @{
        Available = $false
        Version = $null
    }
}

function Get-PlantUMLJar {
    param(
        [string]$JarPath
    )
    
    $binDir = Split-Path $JarPath -Parent
    
    # Create bin directory if needed
    if (-not (Test-Path $binDir)) {
        New-Item -ItemType Directory -Path $binDir -Force | Out-Null
        Write-ColorText "Created directory: $binDir" -Color Green
    }
    
    # Check if JAR exists
    if (Test-Path $JarPath) {
        $jarSize = (Get-Item $JarPath).Length / 1MB
        Write-ColorText "✓ PlantUML JAR found: $JarPath ($([math]::Round($jarSize, 2)) MB)" -Color Green
        return $JarPath
    }
    
    # Download PlantUML JAR
    Write-ColorText "`nDownloading PlantUML JAR..." -Color Cyan
    Write-Host "  Source: https://github.com/plantuml/plantuml/releases"
    Write-Host "  Size: ~10 MB (one-time download)"
    Write-Host "  Target: $JarPath"
    Write-Host ""
    
    $jarUrl = "https://github.com/plantuml/plantuml/releases/download/v1.2024.7/plantuml-1.2024.7.jar"
    
    try {
        Invoke-WebRequest -Uri $jarUrl -OutFile $JarPath -UseBasicParsing
        
        if (Test-Path $JarPath) {
            $jarSize = (Get-Item $JarPath).Length / 1MB
            Write-ColorText "✓ Download complete ($([math]::Round($jarSize, 2)) MB)" -Color Green
            return $JarPath
        }
        else {
            throw "JAR file not created after download"
        }
    }
    catch {
        Write-ColorText "✗ Download failed: $_" -Color Red
        throw
    }
}

function Test-DiagramNeedsRendering {
    param(
        [System.IO.FileInfo]$PumlFile,
        [bool]$Force
    )
    
    if ($Force) {
        return $true
    }
    
    $svgFile = $PumlFile.FullName -replace '\.puml$', '.svg'
    
    if (-not (Test-Path $svgFile)) {
        return $true
    }
    
    $svgLastWrite = (Get-Item $svgFile).LastWriteTime
    if ($PumlFile.LastWriteTime -gt $svgLastWrite) {
        return $true
    }
    
    return $false
}

#endregion

#region Main Script

Write-ColorText "`n=== PlantUML Diagram Renderer ===" -Color Cyan
Write-Host "Diagram Path: $DiagramPath"
Write-Host "PlantUML JAR: $PlantUMLJarPath"
Write-Host ""

# Validate diagram path exists
if (-not (Test-Path $DiagramPath)) {
    Write-ColorText "✗ Diagram path not found: $DiagramPath" -Color Red
    Write-Host "`nPlease provide a valid path containing .puml files."
    exit 1
}

# Check Java installation
Write-Host "Checking prerequisites..."
$javaCheck = Test-JavaInstallation

if (-not $javaCheck.Available) {
    Write-ColorText "✗ Java not found in PATH" -Color Red
    Write-Host "`nPlantUML requires Java 8 or higher to render diagrams."
    Write-Host "Please install Java and ensure it's available in your PATH."
    Write-Host "`nDownload Java from: https://adoptium.net/"
    exit 1
}

Write-ColorText "✓ Java detected: $($javaCheck.Version)" -Color Green

# Get or download PlantUML JAR
try {
    $jarPath = Get-PlantUMLJar -JarPath $PlantUMLJarPath
}
catch {
    Write-ColorText "`n✗ Failed to obtain PlantUML JAR" -Color Red
    Write-Host "Error: $_"
    exit 1
}

# Find .puml files
Write-Host "`nScanning for PlantUML files..."
$pumlFiles = Get-ChildItem -Path $DiagramPath -Filter "*.puml" -File | Sort-Object Name

if ($pumlFiles.Count -eq 0) {
    Write-ColorText "✗ No .puml files found in: $DiagramPath" -Color Yellow
    Write-Host "`nExpected workflow:"
    Write-Host "  1. generate-c4-diagrams.ps1 -RenderMode SourceOnly  (creates .puml files)"
    Write-Host "  2. /appdoc.diagrams                                  (AI enhances .puml files)"
    Write-Host "  3. render-plantuml-diagrams.ps1                      (renders to SVG)"
    exit 0
}

Write-ColorText "✓ Found $($pumlFiles.Count) diagram(s)" -Color Green
foreach ($file in $pumlFiles) {
    Write-Host "  - $($file.Name)"
}

# Determine which files need rendering
$filesToRender = @()
foreach ($file in $pumlFiles) {
    if (Test-DiagramNeedsRendering -PumlFile $file -Force $Force) {
        $filesToRender += $file
    }
}

if ($filesToRender.Count -eq 0) {
    Write-ColorText "`n✓ All diagrams are up-to-date (SVG newer than .puml)" -Color Green
    Write-Host "Use -Force to re-render anyway."
    exit 0
}

# Render diagrams
Write-ColorText "`nRendering $($filesToRender.Count) diagram(s)..." -Color Cyan

$successCount = 0
$failCount = 0

foreach ($file in $filesToRender) {
    $fileName = $file.Name
    $svgFileName = $fileName -replace '\.puml$', '.svg'
    
    Write-Host "`n  $fileName" -NoNewline
    
    try {
        # Render with PlantUML JAR
        $output = & java -jar $jarPath -tsvg -charset UTF-8 $file.FullName 2>&1
        
        # Check if SVG was created
        $svgFile = $file.FullName -replace '\.puml$', '.svg'
        
        if (Test-Path $svgFile) {
            $svgSize = (Get-Item $svgFile).Length / 1KB
            Write-Host " → $svgFileName " -NoNewline
            Write-ColorText "✓ ($([math]::Round($svgSize, 2)) KB)" -Color Green
            $successCount++
        }
        else {
            Write-ColorText " ✗ SVG not created" -Color Red
            Write-Host "    Output: $output"
            $failCount++
        }
    }
    catch {
        Write-ColorText " ✗ Error: $_" -Color Red
        $failCount++
    }
}

# Summary
Write-Host ""
Write-ColorText "=== Rendering Complete ===" -Color Cyan
Write-Host "Success: $successCount"
if ($failCount -gt 0) {
    Write-Host "Failed:  $failCount" -ForegroundColor Red
}
Write-Host "Output:  $DiagramPath"
Write-Host ""

if ($successCount -gt 0) {
    Write-ColorText "✓ SVG diagrams ready for use!" -Color Green
    Write-Host "`nTo view diagrams:"
    Write-Host "  Invoke-Item `"$DiagramPath\*.svg`""
}

exit $(if ($failCount -eq 0) { 0 } else { 1 })

#endregion
