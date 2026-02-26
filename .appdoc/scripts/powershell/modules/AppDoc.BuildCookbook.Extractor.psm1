function Get-AppDocBuildCookbookData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $commands = @()
    $prerequisites = @()
    $cicdInfo = @()

    function Get-AppDocBuildSourceFiles {
        param(
            [string]$RootPath,
            [string[]]$Include
        )

        if (-not (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue)) {
            $scopeModulePath = Join-Path $PSScriptRoot "AppDoc.Scope.psm1"
            if (Test-Path $scopeModulePath) {
                Import-Module $scopeModulePath -Force -ErrorAction SilentlyContinue
                if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
                    Write-Verbose "Successfully imported AppDoc.Scope.psm1 from $scopeModulePath; Get-AppDocSourceFiles is now available."
                } else {
                    Write-Verbose "Attempted to import AppDoc.Scope.psm1 from $scopeModulePath, but Get-AppDocSourceFiles is still unavailable. Import may have failed or the command is missing."
                }
            }
        }

        if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
            return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "build-cookbook" -Include $Include)
        }

        $files = @(Get-ChildItem -Path (Join-Path $RootPath '*') -Recurse -File -Include $Include -ErrorAction SilentlyContinue)
        if (Get-Command Test-AppDocPathIncluded -ErrorAction SilentlyContinue) {
            return @(
                $files | Where-Object {
                    Test-AppDocPathIncluded -Path $_.FullName -RootPath $RootPath -Artifact "build-cookbook"
                }
            )
        }

        return $files
    }

    function Get-AppDocBuildRelativePath {
        param(
            [string]$RootPath,
            [string]$Path
        )

        if (Get-Command Get-AppDocRelativePath -ErrorAction SilentlyContinue) {
            return (Get-AppDocRelativePath -RootPath $RootPath -Path $Path)
        }

        return $Path.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
    }

    # Prerequisites from first project file.
    $csprojForPrereq = Get-AppDocBuildSourceFiles -RootPath $RootPath -Include @("*.csproj") | Select-Object -First 1
    if ($csprojForPrereq.Count -gt 0) {
        try {
            [xml]$projXml = Get-Content $csprojForPrereq[0].FullName -ErrorAction Stop
            $targetFramework = $projXml.SelectSingleNode("//TargetFramework")
            $targetFrameworkVersion = $projXml.SelectSingleNode("//TargetFrameworkVersion")

            if ($targetFramework) {
                $fwValue = $targetFramework.InnerText
                if ($fwValue -match 'netcoreapp(\d+\.\d+)') {
                    $prerequisites += ".NET Core $($Matches[1]) SDK or later"
                }
                elseif ($fwValue -match 'net(\d+\.\d+)') {
                    $prerequisites += ".NET $($Matches[1]) SDK or later"
                }
                elseif ($fwValue -match 'net(\d{2,3})$') {
                    # Legacy .NET Framework TFM: net48, net472, etc.
                    $digits = $Matches[1]
                    $fwVer = if ($digits.Length -eq 2) {
                        # e.g. 48 -> 4.8
                        "{0}.{1}" -f $digits.Substring(0,1), $digits.Substring(1,1)
                    } elseif ($digits.Length -eq 3) {
                        # e.g. 472 -> 4.7.2
                        "{0}.{1}.{2}" -f $digits.Substring(0,1), $digits.Substring(1,1), $digits.Substring(2,1)
                    } else {
                        $digits
                    }
                    $prerequisites += ".NET Framework $fwVer or later"
                }
            }

            if ($targetFrameworkVersion) {
                $fwValue = $targetFrameworkVersion.InnerText
                if ($fwValue -match 'v(\d+\.\d+)') {
                    $version = $Matches[1]
                    $prerequisites += ".NET Framework $version Developer Pack"
                    if ([double]$version -ge 4.8) {
                        $prerequisites += "Visual Studio 2019 or later / MSBuild 16.0+"
                    }
                    elseif ([double]$version -ge 4.5) {
                        $prerequisites += "Visual Studio 2013 or later / MSBuild 12.0+"
                    }
                }
            }

            $packageRefs = $projXml.SelectNodes("//PackageReference")
            foreach ($pkg in $packageRefs) {
                $pkgName = $pkg.GetAttribute("Include")
                if ($pkgName -match 'EntityFramework' -and $prerequisites -notcontains 'SQL Server or compatible database') {
                    $prerequisites += "SQL Server or compatible database"
                }
                if ($pkgName -match 'NHibernate' -and $prerequisites -notcontains 'Database (SQL Server/PostgreSQL/MySQL)') {
                    $prerequisites += "Database (SQL Server/PostgreSQL/MySQL)"
                }
            }
        }
        catch {
            Write-Verbose "Could not parse csproj prerequisites: $($_.Exception.Message)"
        }
    }

    $packageJsonPath = Join-Path $RootPath "package.json"
    $cachedPackageJson = $null
    if (Test-Path $packageJsonPath) {
        try {
            $cachedPackageJson = Get-Content $packageJsonPath | ConvertFrom-Json
            if ($cachedPackageJson.engines.node) { $prerequisites += "Node.js $($cachedPackageJson.engines.node)" }
            else { $prerequisites += "Node.js (version not specified)" }
            if ($cachedPackageJson.engines.npm) { $prerequisites += "npm $($cachedPackageJson.engines.npm)" }
        }
        catch {
            $prerequisites += "Node.js and npm"
        }
    }

    $ghActionsPath = Join-Path $RootPath ".github\workflows"
    if (Test-Path $ghActionsPath) {
        $workflowFiles = @(Get-ChildItem -Path (Join-Path $ghActionsPath '*') -Include "*.yml","*.yaml" -File -ErrorAction SilentlyContinue)
        foreach ($wf in $workflowFiles) {
            $cicdInfo += @{
                platform = "GitHub Actions"
                file = $wf.Name
                path = ".github\workflows\$($wf.Name)"
                details = "Workflow: $($wf.BaseName)"
            }
        }
    }

    foreach ($ci in @(
        @{ file = ".gitlab-ci.yml"; platform = "GitLab CI/CD"; details = "GitLab pipeline configuration" },
        @{ file = "azure-pipelines.yml"; platform = "Azure Pipelines"; details = "Azure DevOps pipeline" },
        @{ file = "Jenkinsfile"; platform = "Jenkins"; details = "Jenkins pipeline configuration" }
    )) {
        $path = Join-Path $RootPath $ci.file
        if (Test-Path $path) {
            $cicdInfo += @{
                platform = $ci.platform
                file = $ci.file
                path = $ci.file
                details = $ci.details
            }
        }
    }

    if ($cachedPackageJson) {
        try {
            if ($cachedPackageJson.scripts) {
                foreach ($script in $cachedPackageJson.scripts.PSObject.Properties) {
                    $commands += @{
                        name = $script.Name
                        command = [string]$script.Value
                        type = "npm"
                        invocation = "npm run $($script.Name)"
                        source = "package.json:scripts.$($script.Name)"
                    }
                }
            }
        }
        catch {
            Write-Verbose "Could not parse package.json scripts: $($_.Exception.Message)"
        }
    }

    $slnFiles = Get-AppDocBuildSourceFiles -RootPath $RootPath -Include @("*.sln")
    foreach ($sln in $slnFiles) {
        $dotnetCommands = @(
            @{ name = "Build Solution"; cmd = "dotnet build $($sln.Name)"; desc = "Build all projects in the solution"; type = "dotnet" },
            @{ name = "Restore Packages"; cmd = "dotnet restore $($sln.Name)"; desc = "Restore NuGet packages"; type = "dotnet" },
            @{ name = "Clean Solution"; cmd = "dotnet clean $($sln.Name)"; desc = "Clean build artifacts"; type = "dotnet" },
            @{ name = "Run Tests"; cmd = "dotnet test $($sln.Name)"; desc = "Run all tests in the solution"; type = "dotnet" },
            @{ name = "Publish (Release)"; cmd = "dotnet publish $($sln.Name) -c Release"; desc = "Publish release build"; type = "dotnet" }
        )

        $slnContent = Get-Content $sln.FullName -Raw -ErrorAction SilentlyContinue
        if ($slnContent -match 'Microsoft Visual Studio Solution File') {
            $dotnetCommands += @(
                @{ name = "Build (MSBuild)"; cmd = "msbuild $($sln.Name) /p:Configuration=Release"; desc = "Build solution using MSBuild"; type = "msbuild" },
                @{ name = "Clean (MSBuild)"; cmd = "msbuild $($sln.Name) /t:Clean"; desc = "Clean using MSBuild"; type = "msbuild" },
                @{ name = "Rebuild (MSBuild)"; cmd = "msbuild $($sln.Name) /t:Rebuild /p:Configuration=Release"; desc = "Clean and rebuild"; type = "msbuild" },
                @{ name = "Restore NuGet"; cmd = "nuget restore $($sln.Name)"; desc = "Restore NuGet packages"; type = "msbuild" }
            )
        }

        foreach ($cmd in $dotnetCommands) {
            $commands += @{
                name = $cmd.name
                command = $cmd.desc
                type = $cmd.type
                invocation = $cmd.cmd
                source = $sln.Name
            }
        }
    }

    $csprojFiles = Get-AppDocBuildSourceFiles -RootPath $RootPath -Include @("*.csproj") | Select-Object -First 5
    foreach ($proj in $csprojFiles) {
        $relativePath = Get-AppDocBuildRelativePath -RootPath $RootPath -Path $proj.FullName
        $commands += @{
            name = "Build $($proj.BaseName)"
            command = "Build individual project"
            type = "dotnet-project"
            invocation = "dotnet build `"$relativePath`""
            source = $relativePath
        }
    }

    $makefile = Join-Path $RootPath "Makefile"
    if (Test-Path $makefile) {
        $content = Get-Content $makefile -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $targets = [regex]::Matches($content, "^(\w+):\s*(?:#\s*(.+))?", [System.Text.RegularExpressions.RegexOptions]::Multiline)
            foreach ($match in $targets) {
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $commands += @{
                    name = $match.Groups[1].Value
                    command = if ($match.Groups[2].Success) { $match.Groups[2].Value } else { "No description" }
                    type = "make"
                    invocation = "make $($match.Groups[1].Value)"
                    source = "Makefile:$lineNumber"
                }
            }
        }
    }

    $buildGradle = Join-Path $RootPath "build.gradle"
    if (Test-Path $buildGradle) {
        $content = Get-Content $buildGradle -Raw -ErrorAction SilentlyContinue
        if ($content) {
            $tasks = [regex]::Matches($content, "task\s+(\w+)")
            foreach ($match in $tasks) {
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $commands += @{
                    name = $match.Groups[1].Value
                    command = "Gradle task"
                    type = "gradle"
                    invocation = "gradle $($match.Groups[1].Value)"
                    source = "build.gradle:$lineNumber"
                }
            }
        }
    }

    $commands = @(
        $commands |
            Group-Object { "{0}|{1}" -f [string]$_.invocation, [string]$_.source } |
            ForEach-Object { $_.Group | Sort-Object name | Select-Object -First 1 } |
            Sort-Object @{ Expression = { [string]$_.type } }, @{ Expression = { [string]$_.invocation } }, @{ Expression = { [string]$_.source } }
    )
    $prerequisites = @($prerequisites | Where-Object { $_ } | Sort-Object -Unique)
    $cicdInfo = @(
        $cicdInfo |
            Group-Object { "{0}|{1}" -f [string]$_.platform, [string]$_.path } |
            ForEach-Object { $_.Group | Select-Object -First 1 } |
            Sort-Object @{ Expression = { [string]$_.platform } }, @{ Expression = { [string]$_.path } }
    )

    return [ordered]@{
        commands = $commands
        prerequisites = $prerequisites
        cicdInfo = $cicdInfo
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocBuildCookbookData'
)
