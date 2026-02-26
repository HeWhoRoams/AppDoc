function Get-AppDocDependenciesSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string[]]$Include
    )


    if (-not (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue)) {
        $scopeModulePath = Join-Path $PSScriptRoot "AppDoc.Scope.psm1"
        if (Test-Path $scopeModulePath) {
            try {
                Import-Module $scopeModulePath -Force
            } catch {
                Write-Verbose "Failed to import AppDoc.Scope.psm1 from $scopeModulePath: $_"
                # Optionally, use a logger if available: $AppDocLogger?.LogError(...)
            }
        }
        if (-not (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue)) {
            Write-Verbose "Get-AppDocSourceFiles is not available after attempting to import AppDoc.Scope.psm1 from $scopeModulePath. Falling back to Get-ChildItem."
        }
    }

    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "dependencies-catalog" -Include $Include)
    }
    $files = @(Get-ChildItem -Path (Join-Path $RootPath '') -Recurse -File -Include $Include -ErrorAction SilentlyContinue)
    if (Get-Command Test-AppDocPathIncluded -ErrorAction SilentlyContinue) {
        return @(
            $files | Where-Object {
                Test-AppDocPathIncluded -Path $_.FullName -RootPath $RootPath -Artifact "dependencies-catalog"
            }
        )
    }

    return $files
}

function Get-AppDocDependenciesRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (Get-Command Get-AppDocRelativePath -ErrorAction SilentlyContinue) {
        return (Get-AppDocRelativePath -RootPath $RootPath -Path $Path)
    }

    # Normalize path separators to '\' and trim trailing separators
    $rootNorm = $RootPath -replace '/', '\'
    $rootNorm = $rootNorm.TrimEnd('\')
    $pathToCheck = $Path -replace '/', '\'
    $pathToCheck = $pathToCheck.TrimEnd('\')
    # Perform a case-insensitive prefix check
    if ($pathToCheck -eq $rootNorm) {
        return ''
    }
    $rootWithSep = $rootNorm + '\'
    if ($pathToCheck.StartsWith($rootWithSep, [System.StringComparison]::OrdinalIgnoreCase)) {
        return $pathToCheck.Substring($rootWithSep.Length)
    }
    return $pathToCheck
}

function Get-AppDocDependenciesCatalogData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $dependencies = @()
    $projects = @()

    $csprojFiles = Get-AppDocDependenciesSourceFiles -RootPath $RootPath -Include @("*.csproj")
    foreach ($proj in $csprojFiles) {
        $content = Get-Content $proj.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $relativePath = Get-AppDocDependenciesRelativePath -RootPath $RootPath -Path $proj.FullName
        $projectName = $proj.BaseName

        try {
            [xml]$xml = $content

            $packageRefs = @($xml.Project.ItemGroup.PackageReference) | Where-Object { $_ }
            foreach ($pkg in $packageRefs) {
                if ($pkg.Include) {
                    $dependencies += @{
                        name = [string]$pkg.Include
                        version = if ($pkg.Version) { [string]$pkg.Version } else { "Latest" }
                        type = "NuGet Package"
                        project = $projectName
                        source = $relativePath
                    }
                }
            }

            $references = @($xml.Project.ItemGroup.Reference) | Where-Object { $_ }
            foreach ($ref in $references) {
                if ($ref.Include -and $ref.Include -notmatch '^(System|Microsoft\.CSharp|mscorlib)') {
                    $refName = ([string]$ref.Include) -replace ',.*$', ''
                    $version = if ($ref.Include -match 'Version=([^,]+)') { [string]$Matches[1] } else { "Unspecified" }
                    $dependencies += @{
                        name = $refName
                        version = $version
                        type = if ($ref.Include -match 'PublicKeyToken') { "GAC Assembly" } else { "Assembly Reference" }
                        project = $projectName
                        source = $relativePath
                    }
                }
            }

            $projectRefs = @($xml.Project.ItemGroup.ProjectReference) | Where-Object { $_ }
            foreach ($projRef in $projectRefs) {
                if ($projRef.Include) {
                    $refName = [System.IO.Path]::GetFileNameWithoutExtension([string]$projRef.Include)
                    $dependencies += @{
                        name = $refName
                        version = "Project"
                        type = "Project Reference"
                        project = $projectName
                        source = $relativePath
                    }
                }
            }

            $targetFramework = $xml.Project.PropertyGroup.TargetFramework | Select-Object -First 1
            if (-not $targetFramework) {
                $targetFramework = $xml.Project.PropertyGroup.TargetFrameworkVersion | Select-Object -First 1
            }

            $projects += @{
                name = $projectName
                framework = [string]$targetFramework
                path = $relativePath
                dependencyCount = ($packageRefs.Count + $references.Count + $projectRefs.Count)
            }
        }
        catch {
            Write-Verbose "Could not parse $($proj.Name): $($_.Exception.Message)"
        }
    }

    $packagesConfigs = Get-AppDocDependenciesSourceFiles -RootPath $RootPath -Include @("packages.config")
    foreach ($pkgConfig in $packagesConfigs) {
        $content = Get-Content $pkgConfig.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $relativePath = Get-AppDocDependenciesRelativePath -RootPath $RootPath -Path $pkgConfig.FullName
        $projectName = $pkgConfig.Directory.Name

        try {
            [xml]$xml = $content
            foreach ($pkg in $xml.packages.package) {
                if ($pkg.id) {
                    $version = [string]$pkg.version
                    if ([string]::IsNullOrWhiteSpace($version)) { $version = "Latest" }
                    $dependencies += @{
                        name = [string]$pkg.id
                        version = $version
                        type = "NuGet Package"
                        project = $projectName
                        source = $relativePath
                    }
                }
            }
        }
        catch {
            Write-Verbose "Could not parse packages.config '$relativePath': $($_.Exception.Message)"
        }
    }

    $dedupedDependencies = @(
        $dependencies |
            Group-Object { "{0}|{1}|{2}|{3}|{4}" -f [string]$_.name, [string]$_.version, [string]$_.type, [string]$_.project, [string]$_.source } |
            ForEach-Object { $_.Group | Select-Object -First 1 } |
            Sort-Object @{ Expression = { [string]$_.type } }, @{ Expression = { [string]$_.name } }, @{ Expression = { [string]$_.project } }
    )

    $dedupedProjects = @(
        $projects |
            Group-Object { [string]$_.path } |
            ForEach-Object { $_.Group | Select-Object -First 1 } |
            Sort-Object @{ Expression = { [string]$_.name } }
    )

    return [ordered]@{
        dependencies = $dedupedDependencies
        projects = $dedupedProjects
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocDependenciesCatalogData'
)
