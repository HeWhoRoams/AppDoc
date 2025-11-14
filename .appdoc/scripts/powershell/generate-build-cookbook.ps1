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

try {
    # Check package.json (Node.js/npm)
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