#
# generate-build-cookbook.ps1
#
# Purpose: Scans the target codebase for build configurations and populates the build-cookbook
#          template with discovered build, test, and deployment commands.
#
# Usage: .\generate-build-cookbook.ps1 -RootPath <target_codebase_path>
# Output: Populates docs/build-cookbook.md from template
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

Write-Host "🔨 Generating Build Cookbook..." -ForegroundColor Cyan

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Initialize template
$outputPath = Join-Path $RootPath "docs\build-cookbook.md"
$initialized = Initialize-TemplateFile -TemplateName "build-cookbook-template.md" -OutputPath $outputPath -RootPath $RootPath

if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Build Cookbook" -Status "Scanning build files..." -PercentComplete 0

$commands = @()
$prerequisites = @()
$cicdInfo = @()

try {
    # Extract prerequisites from .csproj files
    Write-Progress -Activity "Generating Build Cookbook" -Status "Extracting prerequisites..." -PercentComplete 5
    
    $csprojFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\packages\\)' } |
        Select-Object -First 1  # Check first project for framework version
    
    if ($csprojFiles.Count -gt 0) {
        try {
            [xml]$projXml = Get-Content $csprojFiles[0].FullName -ErrorAction Stop
            
            # Extract TargetFramework or TargetFrameworkVersion
            $targetFramework = $projXml.SelectSingleNode("//TargetFramework")
            $targetFrameworkVersion = $projXml.SelectSingleNode("//TargetFrameworkVersion")
            
            if ($targetFramework) {
                $fwValue = $targetFramework.InnerText
                if ($fwValue -match 'net(\d+\.\d+)') {
                    $prerequisites += ".NET $($Matches[1]) SDK or later"
                } elseif ($fwValue -match 'netcoreapp(\d+\.\d+)') {
                    $prerequisites += ".NET Core $($Matches[1]) SDK or later"
                } elseif ($fwValue -match 'net(\d+)') {
                    $dotnetVersion = $Matches[1]
                    $prerequisites += ".NET $dotnetVersion SDK or later"
                }
            }
            
            if ($targetFrameworkVersion) {
                $fwValue = $targetFrameworkVersion.InnerText
                if ($fwValue -match 'v(\d+\.\d+)') {
                    $version = $Matches[1]
                    $prerequisites += ".NET Framework $version Developer Pack"
                    if ([double]$version -ge 4.8) {
                        $prerequisites += "Visual Studio 2019 or later / MSBuild 16.0+"
                    } elseif ([double]$version -ge 4.5) {
                        $prerequisites += "Visual Studio 2013 or later / MSBuild 12.0+"
                    }
                }
            }
            
            # Check for specific package references that indicate prerequisites
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
        } catch {
            Write-Warning "Failed to parse .csproj for prerequisites: $_"
        }
    }
    
    # Check for package.json for Node.js prerequisites
    $packageJson = Join-Path $RootPath "package.json"
    if (Test-Path $packageJson) {
        try {
            $pkg = Get-Content $packageJson | ConvertFrom-Json
            if ($pkg.engines.node) {
                $prerequisites += "Node.js $($pkg.engines.node)"
            } else {
                $prerequisites += "Node.js (version not specified)"
            }
            if ($pkg.engines.npm) {
                $prerequisites += "npm $($pkg.engines.npm)"
            }
        } catch {
            $prerequisites += "Node.js and npm"
        }
    }
    
    # Scan for CI/CD configuration files
    Write-Progress -Activity "Generating Build Cookbook" -Status "Detecting CI/CD..." -PercentComplete 10
    
    # GitHub Actions
    $ghActionsPath = Join-Path $RootPath ".github\workflows"
    if (Test-Path $ghActionsPath) {
        $workflowFiles = Get-ChildItem -Path $ghActionsPath -Filter "*.yml" -ErrorAction SilentlyContinue
        foreach ($wf in $workflowFiles) {
            try {
                $content = Get-Content $wf.FullName -Raw
                $cicdInfo += @{
                    platform = "GitHub Actions"
                    file = $wf.Name
                    path = ".github\workflows\$($wf.Name)"
                    details = "Workflow: $($wf.BaseName)"
                }
            } catch { }
        }
    }
    
    # GitLab CI
    $gitlabCi = Join-Path $RootPath ".gitlab-ci.yml"
    if (Test-Path $gitlabCi) {
        $cicdInfo += @{
            platform = "GitLab CI/CD"
            file = ".gitlab-ci.yml"
            path = ".gitlab-ci.yml"
            details = "GitLab pipeline configuration"
        }
    }
    
    # Azure Pipelines
    $azurePipelines = Join-Path $RootPath "azure-pipelines.yml"
    if (Test-Path $azurePipelines) {
        $cicdInfo += @{
            platform = "Azure Pipelines"
            file = "azure-pipelines.yml"
            path = "azure-pipelines.yml"
            details = "Azure DevOps pipeline"
        }
    }
    
    # Jenkins
    $jenkinsfile = Join-Path $RootPath "Jenkinsfile"
    if (Test-Path $jenkinsfile) {
        $cicdInfo += @{
            platform = "Jenkins"
            file = "Jenkinsfile"
            path = "Jenkinsfile"
            details = "Jenkins pipeline configuration"
        }
    }
    
    # Check package.json (Node.js/npm)
    Write-Progress -Activity "Generating Build Cookbook" -Status "Scanning package.json..." -PercentComplete 15
    $packageJson = Join-Path $RootPath "package.json"
    if (Test-Path $packageJson) {
        $pkg = Get-Content $packageJson | ConvertFrom-Json
        if ($pkg.scripts) {
            foreach ($script in $pkg.scripts.PSObject.Properties) {
                $commands += @{
                    name = $script.Name
                    command = $script.Value
                    type = "npm"
                    invocation = "npm run $($script.Name)"
                    source = "package.json:scripts.$($script.Name)"
                }
            }
        }
    }

    # Check for .NET solution files (.sln)
    $slnFiles = Get-ChildItem -Path $RootPath -Filter "*.sln" -ErrorAction SilentlyContinue
    foreach ($sln in $slnFiles) {
        $slnName = $sln.BaseName
        
        # Common MSBuild commands for .NET projects
        $dotnetCommands = @(
            @{ name = "Build Solution"; cmd = "dotnet build $($sln.Name)"; desc = "Build all projects in the solution" },
            @{ name = "Restore Packages"; cmd = "dotnet restore $($sln.Name)"; desc = "Restore NuGet packages" },
            @{ name = "Clean Solution"; cmd = "dotnet clean $($sln.Name)"; desc = "Clean build artifacts" },
            @{ name = "Run Tests"; cmd = "dotnet test $($sln.Name)"; desc = "Run all tests in the solution" },
            @{ name = "Publish (Release)"; cmd = "dotnet publish $($sln.Name) -c Release"; desc = "Publish release build" }
        )
        
        # Check if it's .NET Core/5+/6+ or .NET Framework
        $slnContent = Get-Content $sln.FullName -Raw
        $isFramework = $slnContent -match 'Microsoft Visual Studio Solution File'
        
        if ($isFramework) {
            # Add MSBuild commands for .NET Framework
            $msbuildCommands = @(
                @{ name = "Build (MSBuild)"; cmd = "msbuild $($sln.Name) /p:Configuration=Release"; desc = "Build solution using MSBuild" },
                @{ name = "Clean (MSBuild)"; cmd = "msbuild $($sln.Name) /t:Clean"; desc = "Clean using MSBuild" },
                @{ name = "Rebuild (MSBuild)"; cmd = "msbuild $($sln.Name) /t:Rebuild /p:Configuration=Release"; desc = "Clean and rebuild" },
                @{ name = "Restore NuGet"; cmd = "nuget restore $($sln.Name)"; desc = "Restore NuGet packages" }
            )
            
            foreach ($cmd in $msbuildCommands) {
                $commands += @{
                    name = $cmd.name
                    command = $cmd.desc
                    type = "msbuild"
                    invocation = $cmd.cmd
                    source = $sln.Name
                }
            }
        }
        
        # Add dotnet CLI commands (work for both Framework and Core if dotnet CLI installed)
        foreach ($cmd in $dotnetCommands) {
            $commands += @{
                name = $cmd.name
                command = $cmd.desc
                type = "dotnet"
                invocation = $cmd.cmd
                source = $sln.Name
            }
        }
    }
    
    # Check for .csproj files (individual projects)
    $csprojFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*.csproj" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\packages\\)' } |
        Select-Object -First 5  # Limit to avoid overwhelming output
    
    foreach ($proj in $csprojFiles) {
        $projName = $proj.BaseName
        $relativePath = $proj.FullName.Replace($RootPath, "").TrimStart('\', '/')
        
        $commands += @{
            name = "Build $projName"
            command = "Build individual project"
            type = "dotnet-project"
            invocation = "dotnet build `"$relativePath`""
            source = $relativePath
        }
    }

    # Check Makefile
    $makefile = Join-Path $RootPath "Makefile"
    if (Test-Path $makefile) {
        $content = Get-Content $makefile -Raw
        $targets = [regex]::Matches($content, "^(\w+):\s*(?:#\s*(.+))?", [System.Text.RegularExpressions.RegexOptions]::Multiline)
        foreach ($match in $targets) {
            $targetName = $match.Groups[1].Value
            $description = if ($match.Groups[2].Success) { $match.Groups[2].Value } else { "No description" }
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $commands += @{
                name = $targetName
                command = $description
                type = "make"
                invocation = "make $targetName"
                source = "Makefile:$lineNumber"
            }
        }
    }

    # Check build.gradle (Gradle)
    $buildGradle = Join-Path $RootPath "build.gradle"
    if (Test-Path $buildGradle) {
        $content = Get-Content $buildGradle -Raw
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
} catch {
    Write-Warning "Error scanning build files: $_"
}

Write-Progress -Activity "Generating Build Cookbook" -Status "Populating template..." -PercentComplete 50

if ($commands.Count -eq 0) {
    Write-Host "⚠️  No build commands detected!" -ForegroundColor Yellow
}

# Build steps table + placeholder
$buildTablePlaceholder = @"
| Step | Command | Description | Estimated Time |
|------|---------|-------------|----------------|

_No build steps detected. Check for package.json scripts, Makefile, or build configuration files._
"@

$buildStepsContent = if ($commands.Count -gt 0) {
    $tableRows = $commands | ForEach-Object {
        $step = $commands.IndexOf($_) + 1
        $desc = if ($_.command -and $_.command -ne "No description") { $_.command } else { "$($_.type) command" }
        "| $step | ``$($_.invocation)`` | $desc | N/A |"
    }
    ($tableRows -join "`r`n")
} else {
    ""
}

# Update template
$content = Get-Content -Path $outputPath -Raw

# Prerequisites section
$prereqPlaceholder = "_No prerequisites detected. Consult project README or documentation._"
if ($prerequisites.Count -gt 0) {
    $prereqContent = ($prerequisites | ForEach-Object { "- $_" }) -join "`r`n"
    $content = $content -replace [regex]::Escape($prereqPlaceholder), $prereqContent
}

# CI/CD section
$cicdPlaceholder = "_No CI/CD configuration detected. Check for .github/workflows, .gitlab-ci.yml, azure-pipelines.yml, or Jenkinsfile._"
if ($cicdInfo.Count -gt 0) {
    $cicdContent = "**Detected CI/CD Platforms:**`r`n`r`n"
    foreach ($ci in $cicdInfo) {
        $cicdContent += "- **$($ci.platform)**: ``$($ci.path)`` - $($ci.details)`r`n"
    }
    $content = $content -replace [regex]::Escape($cicdPlaceholder), $cicdContent
}

# Build steps
if ($buildStepsContent) {
    # Replace with Windows line endings
    $oldText = "| Step | Command | Description | Estimated Time |`r`n|------|---------|-------------|----------------|`r`n`r`n_No build steps detected. Check for package.json scripts, Makefile, or build configuration files._"
    $newText = "| Step | Command | Description | Estimated Time |`r`n|------|---------|-------------|----------------|`r`n" + $buildStepsContent
    $content = Update-TemplateSection -Content $content -PlaceholderText $oldText -NewContent $newText
}

$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Progress -Activity "Generating Build Cookbook" -Status "Complete" -PercentComplete 100
Write-Host "✅ Build cookbook generated: $outputPath" -ForegroundColor Green
Write-Host "   Commands found: $($commands.Count)" -ForegroundColor Gray
Write-Host "   Prerequisites detected: $($prerequisites.Count)" -ForegroundColor Gray
Write-Host "   CI/CD platforms detected: $($cicdInfo.Count)" -ForegroundColor Gray