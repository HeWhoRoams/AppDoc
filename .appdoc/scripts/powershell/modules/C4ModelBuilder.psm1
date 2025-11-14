# C4ModelBuilder Module
# Purpose: Extract C4 model entities from .NET codebases
# Author: AppDoc
# Date: 2025-11-14

<#
.SYNOPSIS
    Builds C4 model entities (Systems, Containers, Components) from codebase analysis.

.DESCRIPTION
    This module provides functions to analyze .NET solution and project files,
    extracting architecture information to build C4 model entities.
#>

# Module-level variables
$script:C4ModelBuilderVersion = "1.0.0"

#region Helper Functions

<#
.SYNOPSIS
    Gets all project files from a solution or directory.

.DESCRIPTION
    Scans for .csproj files in the specified path. If a .sln file is provided,
    parses the solution file to find project references.

.PARAMETER Path
    Path to .sln file or directory containing projects.

.OUTPUTS
    Array of project file paths.

.EXAMPLE
    Get-ProjectFiles -Path "C:\Code\MyApp\MyApp.sln"
#>
function Get-ProjectFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    Write-Verbose "Scanning for project files in: $Path"

    try {
        if (-not (Test-Path $Path)) {
            Write-Warning "Path not found: $Path"
            return @()
        }

        if (Test-Path $Path -PathType Leaf) {
            if ($Path -like "*.sln") {
                # Parse solution file
                $slnContent = Get-Content $Path -Raw -ErrorAction Stop
                $projectPattern = 'Project\("\{[^}]+\}"\)\s*=\s*"[^"]+",\s*"([^"]+\.csproj)"'
                $matches = [regex]::Matches($slnContent, $projectPattern)
                
                $slnDir = Split-Path $Path -Parent
                $projects = $matches | ForEach-Object {
                    $relPath = $_.Groups[1].Value
                    Join-Path $slnDir $relPath
                }
                
                Write-Verbose "Found $($projects.Count) projects in solution"
                return $projects
            }
        }
        
        # Scan directory for .csproj files
        $projects = Get-ChildItem -Path $Path -Filter "*.csproj" -Recurse -ErrorAction Stop | Select-Object -ExpandProperty FullName
        Write-Verbose "Found $($projects.Count) project files"
        return $projects
    }
    catch {
        Write-Warning "Error scanning for project files: $_"
        return @()
    }
}

<#
.SYNOPSIS
    Reads and parses a .csproj file.

.DESCRIPTION
    Loads a C# project file as XML and returns structured data including
    packages, project references, and properties.

.PARAMETER ProjectPath
    Path to the .csproj file.

.OUTPUTS
    Hashtable containing project metadata.

.EXAMPLE
    Read-CsprojFile -ProjectPath "C:\Code\MyApp\Web\Web.csproj"
#>
function Read-CsprojFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectPath
    )

    Write-Verbose "Reading project file: $ProjectPath"

    if (-not (Test-Path $ProjectPath)) {
        Write-Warning "Project file not found: $ProjectPath"
        return $null
    }

    try {
        [xml]$projectXml = Get-Content $ProjectPath -Raw
        
        $projectData = @{
            Path = $ProjectPath
            Name = [System.IO.Path]::GetFileNameWithoutExtension($ProjectPath)
            Sdk = $projectXml.Project.Sdk
            OutputType = $projectXml.Project.PropertyGroup.OutputType
            TargetFramework = $projectXml.Project.PropertyGroup.TargetFramework
            Packages = @()
            ProjectReferences = @()
        }

        # Extract NuGet packages (SDK-style projects)
        $packageRefs = $projectXml.SelectNodes("//PackageReference")
        foreach ($pkg in $packageRefs) {
            $projectData.Packages += @{
                Name = $pkg.Include
                Version = $pkg.Version
            }
        }

        # Extract NuGet packages (legacy .NET Framework projects with HintPath to packages folder)
        # Note: XPath doesn't work reliably with namespaces, so iterate through ItemGroups
        foreach ($itemGroup in $projectXml.Project.ItemGroup) {
            if ($itemGroup.Reference) {
                foreach ($ref in $itemGroup.Reference) {
                    $hintPath = $ref.HintPath
                    if ($hintPath -and $hintPath -match '\\packages\\') {
                        # Extract package name from path like "..\packages\Newtonsoft.Json.11.0.2\lib\..."
                        if ($hintPath -match '\\packages\\([^\\]+)\\') {
                            $packageFolder = $matches[1]
                            # Split package folder into name and version (e.g., "Newtonsoft.Json.11.0.2" -> "Newtonsoft.Json", "11.0.2")
                            if ($packageFolder -match '^(.+?)\.(\d+\..+)$') {
                                $packageName = $matches[1]
                                $packageVersion = $matches[2]
                                # Avoid duplicates
                                if (-not ($projectData.Packages | Where-Object { $_.Name -eq $packageName })) {
                                    $projectData.Packages += @{
                                        Name = $packageName
                                        Version = $packageVersion
                                    }
                                }
                            }
                        }
                    }
                }
            }
            
            # Extract project references (also use ItemGroup iteration for namespace compatibility)
            if ($itemGroup.ProjectReference) {
                foreach ($projRef in $itemGroup.ProjectReference) {
                    if ($projRef.Include) {
                        $projectData.ProjectReferences += $projRef.Include
                    }
                }
            }
        }

        Write-Verbose "Project: $($projectData.Name), Packages: $($projectData.Packages.Count), References: $($projectData.ProjectReferences.Count)"
        return $projectData
    }
    catch {
        Write-Warning "Failed to parse project file: $_"
        return $null
    }
}

<#
.SYNOPSIS
    Gets system information from a solution file.

.DESCRIPTION
    Extracts system name and metadata from a .NET solution file.

.PARAMETER SolutionPath
    Path to the .sln file.

.OUTPUTS
    Hashtable with system information.

.EXAMPLE
    Get-SolutionInfo -SolutionPath "C:\Code\MyApp\MyApp.sln"
#>
function Get-SolutionInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SolutionPath
    )

    Write-Verbose "Reading solution file: $SolutionPath"

    if (-not (Test-Path $SolutionPath)) {
        Write-Warning "Solution file not found: $SolutionPath"
        return $null
    }

    $solutionName = [System.IO.Path]::GetFileNameWithoutExtension($SolutionPath)
    
    $systemInfo = @{
        Name = $solutionName
        Path = $SolutionPath
        Description = "Software system: $solutionName"
    }

    Write-Verbose "System: $($systemInfo.Name)"
    return $systemInfo
}

#endregion

#region C4 Model Building Functions

<#
.SYNOPSIS
    Extracts system information from a solution file.

.DESCRIPTION
    Analyzes a solution file to extract system name and generate a description.
    This is the top-level C4 System entity.

.PARAMETER SolutionPath
    Path to the .sln file.

.OUTPUTS
    Hashtable representing a C4 System.

.EXAMPLE
    Get-SystemInfo -SolutionPath "C:\Code\MyApp\MyApp.sln"
#>
function Get-SystemInfo {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SolutionPath
    )

    $baseInfo = Get-SolutionInfo -SolutionPath $SolutionPath
    if (-not $baseInfo) {
        return $null
    }

    # Create C4 System object
    $system = @{
        Id = $baseInfo.Name.ToLower() -replace '[^a-z0-9]', '_'
        Name = $baseInfo.Name
        Description = $baseInfo.Description
        Type = 'SoftwareSystem'
        Containers = @()
        ExternalSystems = @()
    }

    return $system
}

<#
.SYNOPSIS
    Finds external systems referenced by the codebase.

.DESCRIPTION
    Scans project files for NuGet packages and code patterns that indicate
    external system integrations (databases, APIs, message queues).

.PARAMETER ProjectFiles
    Array of project file paths to scan.

.OUTPUTS
    Array of hashtables representing external C4 Systems.

.EXAMPLE
    Find-ExternalSystems -ProjectFiles $projects
#>
function Find-ExternalSystems {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string[]]$ProjectFiles
    )

    Write-Verbose "Scanning for external systems in $($ProjectFiles.Count) projects..."

    $externalSystems = @{}

    foreach ($projPath in $ProjectFiles) {
        $projData = Read-CsprojFile -ProjectPath $projPath
        if (-not $projData) { continue }

        # Scan NuGet packages for external system indicators
        foreach ($pkg in $projData.Packages) {
            $pkgName = $pkg.Name

            # Database systems
            if ($pkgName -match 'EntityFramework|NHibernate|Dapper') {
                if (-not $externalSystems.ContainsKey('database')) {
                    $externalSystems['database'] = @{
                        Id = 'database'
                        Name = 'Database'
                        Description = 'Persistent data storage'
                        Type = 'ExternalSystem'
                    }
                }
            }

            if ($pkgName -match 'SqlClient|Npgsql|MySql|Oracle') {
                $dbType = switch -Regex ($pkgName) {
                    'SqlClient' { 'SQL Server' }
                    'Npgsql' { 'PostgreSQL' }
                    'MySql' { 'MySQL' }
                    'Oracle' { 'Oracle' }
                    default { 'Database' }
                }
                $key = "database_$dbType" -replace ' ', '_'
                if (-not $externalSystems.ContainsKey($key)) {
                    $externalSystems[$key] = @{
                        Id = $key.ToLower()
                        Name = $dbType
                        Description = "$dbType database system"
                        Type = 'ExternalSystem'
                    }
                }
            }

            # HTTP clients
            if ($pkgName -match 'System\.Net\.Http|RestSharp|Flurl') {
                if (-not $externalSystems.ContainsKey('external_api')) {
                    $externalSystems['external_api'] = @{
                        Id = 'external_api'
                        Name = 'External API'
                        Description = 'Third-party REST API'
                        Type = 'ExternalSystem'
                    }
                }
            }

            # Message queues
            if ($pkgName -match 'RabbitMQ|Azure\.Messaging|MassTransit') {
                $mqType = switch -Regex ($pkgName) {
                    'RabbitMQ' { 'RabbitMQ' }
                    'Azure' { 'Azure Service Bus' }
                    default { 'Message Queue' }
                }
                $key = "mq_$mqType" -replace ' ', '_'
                if (-not $externalSystems.ContainsKey($key)) {
                    $externalSystems[$key] = @{
                        Id = $key.ToLower()
                        Name = $mqType
                        Description = "$mqType message broker"
                        Type = 'ExternalSystem'
                    }
                }
            }
        }
    }

    $result = @($externalSystems.Values)
    Write-Verbose "Found $($result.Count) external systems"
    return $result
}

<#
.SYNOPSIS
    Builds a complete C4 System Context model.

.DESCRIPTION
    Combines system information and external systems into a complete
    C4 Level 1 model ready for PlantUML generation.

.PARAMETER SolutionPath
    Path to the solution file.

.OUTPUTS
    Hashtable representing complete C4 System Context.

.EXAMPLE
    Build-SystemContextModel -SolutionPath "C:\Code\MyApp\MyApp.sln"
#>
function Build-SystemContextModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SolutionPath
    )

    Write-Verbose "Building System Context model..."

    # Get system information
    $system = Get-SystemInfo -SolutionPath $SolutionPath
    if (-not $system) {
        Write-Warning "Could not extract system information"
        return $null
    }

    # Get project files
    $projects = Get-ProjectFiles -Path $SolutionPath
    if (-not $projects -or $projects.Count -eq 0) {
        Write-Warning "No project files found"
        return $system
    }

    # Find external systems
    $externalSystems = Find-ExternalSystems -ProjectFiles $projects
    $system.ExternalSystems = $externalSystems

    Write-Verbose "System Context model complete: $($system.Name) with $($externalSystems.Count) external systems"
    return $system
}

<#
.SYNOPSIS
    Determines the container type for a .NET project.

.DESCRIPTION
    Analyzes a project file to classify it as WebApp, Service, Database, or Library
    based on SDKs, packages, and output type.

.PARAMETER ProjectPath
    Path to the .csproj file.

.OUTPUTS
    String indicating container type: WebApp, Service, Database, or Library.

.EXAMPLE
    Get-ContainerType -ProjectPath "C:\Code\MyApp\Web\Web.csproj"
#>
function Get-ContainerType {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectPath
    )

    $projData = Read-CsprojFile -ProjectPath $ProjectPath
    if (-not $projData) {
        return "Library"
    }

    # Read full project XML for legacy project type detection
    [xml]$projectXml = Get-Content $ProjectPath -Raw
    
    # Check for legacy ASP.NET Web Application (ProjectTypeGuids)
    $projectTypeGuids = $projectXml.SelectSingleNode("//ProjectTypeGuids")
    if ($projectTypeGuids) {
        $guids = $projectTypeGuids.InnerText
        # {349c5851-65df-11da-9384-00065b846f21} = ASP.NET Web Application
        # {E3E379DF-F4C6-4180-9B81-6769533ABE47} = ASP.NET MVC 4
        if ($guids -match '349c5851-65df-11da-9384-00065b846f21|E3E379DF-F4C6-4180-9B81-6769533ABE47') {
            return "WebApp"
        }
    }

    # Check SDK (modern .NET)
    if ($projData.Sdk -match 'Microsoft\.NET\.Sdk\.Web') {
        return "WebApp"
    }

    # Check for service indicators (Windows Service, Background Service, etc.)
    if ($projData.OutputType -eq 'WinExe' -or $projData.OutputType -eq 'Exe') {
        # Check for service-related packages
        $servicePackages = $projData.Packages | Where-Object {
            $_.Name -match 'WindowsService|BackgroundService|Hosting\.WindowsServices|System\.ServiceProcess'
        }
        if ($servicePackages) {
            return "Service"
        }
        
        # If it's an executable, assume it's a service (console apps are usually workers/services in enterprise apps)
        return "Service"
    }

    # Check for web-related packages (modern ASP.NET Core or legacy ASP.NET)
    $webPackages = $projData.Packages | Where-Object {
        $_.Name -match 'AspNetCore|Microsoft\.AspNet\.|System\.Web\.Mvc|Microsoft\.Owin'
    }
    if ($webPackages) {
        return "WebApp"
    }

    # Check for database indicators (EF migrations project, SQL project, etc.)
    $dbPackages = $projData.Packages | Where-Object {
        $_.Name -match 'EntityFramework\.Design|FluentMigrator|DbUp'
    }
    if ($dbPackages) {
        return "Database"
    }

    # Default to Library
    return "Library"
}

<#
.SYNOPSIS
    Finds project dependencies from a .csproj file.

.DESCRIPTION
    Extracts project references and returns project names (without paths/extensions).

.PARAMETER ProjectPath
    Path to the .csproj file.

.OUTPUTS
    Array of project names that this project depends on.

.EXAMPLE
    Find-ProjectDependencies -ProjectPath "C:\Code\MyApp\Web\Web.csproj"
#>
function Find-ProjectDependencies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ProjectPath
    )

    $projData = Read-CsprojFile -ProjectPath $ProjectPath
    if (-not $projData -or -not $projData.ProjectReferences) {
        return @()
    }

    $dependencies = $projData.ProjectReferences | ForEach-Object {
        # Extract project name from relative path
        # e.g., "..\Common\Common.csproj" -> "Common"
        $refPath = $_
        $fileName = Split-Path $refPath -Leaf
        [System.IO.Path]::GetFileNameWithoutExtension($fileName)
    }

    return @($dependencies)
}

<#
.SYNOPSIS
    Builds C4 Container model from project files.

.DESCRIPTION
    Analyzes all projects in a solution to create Container entities
    with appropriate types and technologies.

.PARAMETER SolutionPath
    Path to the solution file.

.OUTPUTS
    Array of container hashtables.

.EXAMPLE
    Build-ContainerModel -SolutionPath "C:\Code\MyApp\MyApp.sln"
#>
function Build-ContainerModel {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SolutionPath
    )

    Write-Verbose "Building Container model..."

    $projects = Get-ProjectFiles -Path $SolutionPath
    if (-not $projects -or $projects.Count -eq 0) {
        Write-Warning "No project files found"
        return @()
    }

    $containers = @()

    foreach ($projPath in $projects) {
        $projData = Read-CsprojFile -ProjectPath $projPath
        if (-not $projData) { continue }

        # Skip test projects
        if ($projData.Name -match '\.Tests?$|\.Test$|Test\.|Tests\.') {
            Write-Verbose "Skipping test project: $($projData.Name)"
            continue
        }

        $containerType = Get-ContainerType -ProjectPath $projPath
        
        # Determine technology
        $technology = switch ($containerType) {
            "WebApp" { 
                if ($projData.Sdk -match 'Web') { "ASP.NET Core" }
                else { "ASP.NET" }
            }
            "Service" { "Windows Service" }
            "Database" { "Database Scripts" }
            "Library" { ".NET Library" }
            default { ".NET" }
        }

        # Skip pure libraries from container view (they're components)
        if ($containerType -eq "Library") {
            Write-Verbose "Skipping library project: $($projData.Name)"
            continue
        }

        $container = @{
            Id = $projData.Name.ToLower() -replace '\.', '_'
            Name = $projData.Name
            Type = $containerType
            Technology = $technology
            Description = "$containerType implemented in $technology"
            ProjectPath = $projPath
        }

        $containers += $container
        Write-Verbose "Container: $($container.Name) ($($container.Type))"
    }

    Write-Verbose "Built $($containers.Count) containers"
    
    # Return early if no containers found
    if ($containers.Count -eq 0) {
        Write-Warning "No containers detected. All projects were classified as libraries or tests."
        
        # Get system info for minimal model
        $systemInfo = Get-SolutionInfo -SolutionPath $SolutionPath
        
        return @{
            SystemName = $systemInfo.Name
            SystemDescription = $systemInfo.Description
            Containers = @()
            Relationships = @()
        }
    }
    
    # Build relationships between containers
    $relationships = Build-ContainerRelationships -Containers $containers -SolutionPath $SolutionPath
    
    # Get system info
    $systemInfo = Get-SolutionInfo -SolutionPath $SolutionPath
    
    # Return complete container model
    return @{
        SystemName = $systemInfo.Name
        SystemDescription = $systemInfo.Description
        Containers = $containers
        Relationships = $relationships
    }
}

<#
.SYNOPSIS
    Builds relationships between containers.

.DESCRIPTION
    Analyzes project references to create relationship objects between containers.

.PARAMETER Containers
    Array of container objects.

.PARAMETER SolutionPath
    Path to the solution file.

.OUTPUTS
    Array of relationship hashtables.

.EXAMPLE
    Build-ContainerRelationships -Containers $containers -SolutionPath "MyApp.sln"
#>
function Build-ContainerRelationships {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Containers,
        
        [Parameter(Mandatory=$true)]
        [string]$SolutionPath
    )

    Write-Verbose "Building Container relationships..."

    $relationships = @()

    foreach ($container in $Containers) {
        $dependencies = Find-ProjectDependencies -ProjectPath $container.ProjectPath
        
        foreach ($depName in $dependencies) {
            # Find the target container
            $targetContainer = $Containers | Where-Object { $_.Name -eq $depName }
            
            if ($targetContainer) {
                # Infer relationship description based on types
                $description = switch ($container.Type) {
                    "WebApp" { "Uses" }
                    "Service" { "Depends on" }
                    default { "Uses" }
                }

                $relationship = @{
                    Source = $container.Id
                    SourceName = $container.Name
                    Target = $targetContainer.Id
                    TargetName = $targetContainer.Name
                    Description = $description
                    Protocol = "Internal"
                }

                $relationships += $relationship
                Write-Verbose "Relationship: $($container.Name) -> $($targetContainer.Name)"
            }
        }
    }

    Write-Verbose "Built $($relationships.Count) relationships"
    return $relationships
}

#endregion

# Export module members
Export-ModuleMember -Function Get-ProjectFiles, Read-CsprojFile, Get-SolutionInfo, Get-SystemInfo, Find-ExternalSystems, Build-SystemContextModel, Get-ContainerType, Find-ProjectDependencies, Build-ContainerModel, Build-ContainerRelationships
