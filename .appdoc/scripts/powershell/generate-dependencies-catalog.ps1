#
# generate-dependencies-catalog.ps1
#
# Purpose: Scans project files and populates the dependencies-catalog template with NuGet packages,
#          project references, and dependency information.
#
# Usage: .\generate-dependencies-catalog.ps1 -RootPath <target_codebase_path>
# Output: Populates docs/dependencies-catalog.md from template
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Import template helpers
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) {
    . $helpersPath
}

Write-Host "📦 Generating Dependencies Catalog..." -ForegroundColor Cyan

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Initialize template
$outputPath = Join-Path $RootPath "docs\dependencies-catalog.md"
$initialized = Initialize-TemplateFile -TemplateName "dependencies-catalog-template.md" -OutputPath $outputPath -RootPath $RootPath

if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Dependencies Catalog" -Status "Scanning project files..." -PercentComplete 0

$dependencies = @()
$projects = @()

try {
    # Find all .csproj files
    $csprojFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\packages\\)' }
    
    foreach ($proj in $csprojFiles) {
        $content = Get-Content $proj.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        $relativePath = $proj.FullName.Replace($RootPath, "").TrimStart('\', '/')
        $projectName = $proj.BaseName
        
        try {
            [xml]$xml = $content
            
            # Extract PackageReference (SDK-style .csproj)
            $packageRefs = $xml.Project.ItemGroup.PackageReference
            foreach ($pkg in $packageRefs) {
                if ($pkg.Include) {
                    $dependencies += @{
                        name = $pkg.Include
                        version = if ($pkg.Version) { $pkg.Version } else { "Latest" }
                        type = "NuGet Package"
                        project = $projectName
                        source = $relativePath
                    }
                }
            }
            
            # Extract Reference (classic .NET Framework)
            $references = $xml.Project.ItemGroup.Reference
            foreach ($ref in $references) {
                if ($ref.Include -and $ref.Include -notmatch '^(System|Microsoft\.CSharp|mscorlib)') {
                    $refName = $ref.Include -replace ',.*$', ''  # Remove version/culture info
                    $version = if ($ref.Include -match 'Version=([^,]+)') { $Matches[1] } else { "Unspecified" }
                    
                    $dependencies += @{
                        name = $refName
                        version = $version
                        type = if ($ref.Include -match 'PublicKeyToken') { "GAC Assembly" } else { "Assembly Reference" }
                        project = $projectName
                        source = $relativePath
                    }
                }
            }
            
            # Extract ProjectReference
            $projectRefs = $xml.Project.ItemGroup.ProjectReference
            foreach ($projRef in $projectRefs) {
                if ($projRef.Include) {
                    $refName = [System.IO.Path]::GetFileNameWithoutExtension($projRef.Include)
                    $dependencies += @{
                        name = $refName
                        version = "Project"
                        type = "Project Reference"
                        project = $projectName
                        source = $relativePath
                    }
                }
            }
            
            # Track project info
            $targetFramework = $xml.Project.PropertyGroup.TargetFramework | Select-Object -First 1
            if (-not $targetFramework) {
                $targetFramework = $xml.Project.PropertyGroup.TargetFrameworkVersion | Select-Object -First 1
            }
            
            $projects += @{
                name = $projectName
                framework = $targetFramework
                path = $relativePath
                dependencyCount = ($packageRefs.Count + $references.Count + $projectRefs.Count)
            }
        } catch {
            Write-Verbose "Could not parse $($proj.Name): $_"
        }
    }
    
    # Check for packages.config files (older NuGet format)
    $packagesConfigs = Get-ChildItem -Path $RootPath -Recurse -Filter "packages.config" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\)' }
    
    foreach ($pkgConfig in $packagesConfigs) {
        $content = Get-Content $pkgConfig.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        $relativePath = $pkgConfig.FullName.Replace($RootPath, "").TrimStart('\', '/')
        $projectName = $pkgConfig.Directory.Name
        
        try {
            [xml]$xml = $content
            foreach ($pkg in $xml.packages.package) {
                if ($pkg.id) {
                    $dependencies += @{
                        name = $pkg.id
                        version = $pkg.version
                        type = "NuGet Package"
                        project = $projectName
                        source = $relativePath
                    }
                }
            }
        } catch {
            Write-Verbose "Could not parse packages.config: $_"
        }
    }
} catch {
    Write-Warning "Error scanning dependencies: $_"
}

Write-Progress -Activity "Generating Dependencies Catalog" -Status "Populating template..." -PercentComplete 50

# Prepare placeholder texts from template
$summaryTablePlaceholder = @"
| Package Manager | Total Dependencies | Direct | Transitive |
|-----------------|-------------------|--------|------------|

_No dependencies detected. System may be self-contained or use alternative dependency management._
"@

$nugetPlaceholder = "_No NuGet packages detected._"
$projectRefsPlaceholder = "_No project references detected._"
$versionConflictsPlaceholder = "_No version conflicts detected._"

# Build Dependency Summary table
$nugetCount = ($dependencies | Where-Object { $_.type -eq 'NuGet Package' }).Count
$projectRefCount = ($dependencies | Where-Object { $_.type -eq 'Project Reference' }).Count
$assemblyRefCount = ($dependencies | Where-Object { $_.type -in @('GAC Assembly', 'Assembly Reference') }).Count

$summaryContent = if ($dependencies.Count -gt 0) {
    @"
| Package Manager | Total Dependencies | Direct | Transitive |
|-----------------|-------------------|--------|------------|
| NuGet | $nugetCount | $nugetCount | 0 |
| Project References | $projectRefCount | $projectRefCount | 0 |
| Assembly References | $assemblyRefCount | $assemblyRefCount | 0 |

**Projects**: $($projects.Count)
"@
} else {
    $summaryTablePlaceholder
}

# Build NuGet Packages section
$nugetPackages = $dependencies | Where-Object { $_.type -eq 'NuGet Package' }
$nugetContent = if ($nugetPackages.Count -gt 0) {
    $rows = $nugetPackages | Group-Object -Property name | Sort-Object Name | ForEach-Object {
        $versions = ($_.Group.version | Sort-Object -Unique) -join ', '
        $usedBy = ($_.Group.project | Sort-Object -Unique | Select-Object -First 3) -join ', '
        "| ``$($_.Name)`` | $versions | $usedBy | NuGet package |"
    }
    
    @"
| Package | Version | Used By | Purpose |
|---------|---------|---------|---------|
$($rows -join "`n")

**Total NuGet Packages**: $($nugetPackages.Count -eq ($nugetPackages | Group-Object name).Count ? $nugetPackages.Count : ($nugetPackages | Group-Object name).Count)
"@
} else {
    $nugetPlaceholder
}

# Build Project References section
$projectRefs = $dependencies | Where-Object { $_.type -eq 'Project Reference' }
$projectRefsContent = if ($projectRefs.Count -gt 0) {
    $rows = $projectRefs | Group-Object -Property name | Sort-Object Name | ForEach-Object {
        $usedBy = ($_.Group.project | Sort-Object -Unique) -join ', '
        "- **``$($_.Name)``** referenced by: $usedBy"
    }
    
    @"
Internal project dependencies:

$($rows -join "`n")

**Total Project References**: $(($projectRefs | Group-Object name).Count)
"@
} else {
    $projectRefsPlaceholder
}

# Build Version Conflicts section
$versionConflicts = $dependencies | Group-Object -Property name | 
    Where-Object { ($_.Group.version | Sort-Object -Unique).Count -gt 1 -and $_.Group[0].type -eq 'NuGet Package' }

$versionConflictsContent = if ($versionConflicts.Count -gt 0) {
    $conflicts = $versionConflicts | ForEach-Object {
        $versions = $_.Group | ForEach-Object { "  - **$($_.project)**: $($_.version)" }
        "- **``$($_.Name)``**:`n$($versions -join "`n")"
    }
    
    @"
⚠️ **$($versionConflicts.Count) package(s) with version conflicts detected:**

$($conflicts -join "`n`n")
"@
} else {
    $versionConflictsPlaceholder
}

# Update template sections
$content = Get-Content -Path $outputPath -Raw
$content = Update-TemplateSection -Content $content -PlaceholderText $summaryTablePlaceholder -NewContent $summaryContent
$content = Update-TemplateSection -Content $content -PlaceholderText $nugetPlaceholder -NewContent $nugetContent
$content = Update-TemplateSection -Content $content -PlaceholderText $projectRefsPlaceholder -NewContent $projectRefsContent
$content = Update-TemplateSection -Content $content -PlaceholderText $versionConflictsPlaceholder -NewContent $versionConflictsContent
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Progress -Activity "Generating Dependencies Catalog" -Status "Complete" -PercentComplete 100
Write-Host "✅ Dependencies catalog generated: $outputPath" -ForegroundColor Green
Write-Host "   Projects: $($projects.Count), Dependencies: $($dependencies.Count)" -ForegroundColor Gray

