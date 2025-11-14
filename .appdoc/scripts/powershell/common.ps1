# Common PowerShell functions for AppDoc Framework
# Shared utilities for all documentation generation scripts

param(
    [switch]$Help
)

if ($Help) {
    Write-Host @"
AppDoc Framework - Common PowerShell Functions

This script provides shared utilities for documentation generation:

Functions:
  - Get-ProjectMetadata: Extract project info from manifest files
  - Find-SourceFiles: Locate source code files by language
  - Test-AppDocConfig: Check for .AppDoc.json
  - Write-JsonOutput: Format output as JSON for parsing
  - Get-GitInfo: Extract git repository information
  - Invoke-AIAgent: Call configured AI agent API

Usage:
  . .\common.ps1  # Dot-source to import functions
"@
    exit 0
}

# Export all functions for dot-sourcing
$ErrorActionPreference = "Stop"

# Get project metadata from manifest files
function Get-ProjectMetadata {
    param(
        [string]$RootPath = (Get-Location).Path,
        [switch]$Json
    )

    $metadata = @{
        Name = ""
        Description = ""
        Version = ""
        Language = ""
        Dependencies = @()
        Scripts = @{}
        Author = ""
        License = ""
    }

    # Try package.json (Node.js)
    $packageJson = Join-Path $RootPath "package.json"
    if (Test-Path $packageJson) {
        $pkg = Get-Content $packageJson | ConvertFrom-Json
        $metadata.Name = $pkg.name
        $metadata.Description = $pkg.description
        $metadata.Version = $pkg.version
        $metadata.Language = "JavaScript/TypeScript"
        $metadata.Dependencies = @($pkg.dependencies.PSObject.Properties.Name)
        $metadata.Scripts = $pkg.scripts
        $metadata.Author = $pkg.author
        $metadata.License = $pkg.license
    }

    # Try pyproject.toml (Python)
    $pyproject = Join-Path $RootPath "pyproject.toml"
    if (Test-Path $pyproject) {
        $metadata.Language = "Python"
        # Basic TOML parsing (full parser would be better)
        $content = Get-Content $pyproject -Raw
        if ($content -match 'name\s*=\s*"([^"]+)"') { $metadata.Name = $Matches[1] }
        if ($content -match 'version\s*=\s*"([^"]+)"') { $metadata.Version = $Matches[1] }
        if ($content -match 'description\s*=\s*"([^"]+)"') { $metadata.Description = $Matches[1] }
    }

    # Try Cargo.toml (Rust)
    $cargoToml = Join-Path $RootPath "Cargo.toml"
    if (Test-Path $cargoToml) {
        $metadata.Language = "Rust"
        $content = Get-Content $cargoToml -Raw
        if ($content -match 'name\s*=\s*"([^"]+)"') { $metadata.Name = $Matches[1] }
        if ($content -match 'version\s*=\s*"([^"]+)"') { $metadata.Version = $Matches[1] }
        if ($content -match 'description\s*=\s*"([^"]+)"') { $metadata.Description = $Matches[1] }
    }

    # Fallback to directory name
    if (-not $metadata.Name) {
        $metadata.Name = Split-Path $RootPath -Leaf
    }

    if ($Json) {
        return $metadata | ConvertTo-Json -Depth 10
    }
    return $metadata
}

# Find source files by language patterns
function Find-SourceFiles {
    param(
        [string]$RootPath = (Get-Location).Path,
        [string[]]$Languages = @("typescript", "javascript", "python", "java"),
        [string[]]$ExcludePatterns = @("node_modules", "dist", "build", ".venv", "target", "vendor"),
        [switch]$Json
    )

    $languagePatterns = @{
        "typescript" = "*.ts", "*.tsx"
        "javascript" = "*.js", "*.jsx"
        "python" = "*.py"
        "java" = "*.java"
        "csharp" = "*.cs"
        "go" = "*.go"
        "rust" = "*.rs"
        "ruby" = "*.rb"
        "php" = "*.php"
    }

    $patterns = @()
    foreach ($lang in $Languages) {
        if ($languagePatterns.ContainsKey($lang)) {
            $patterns += $languagePatterns[$lang]
        }
    }

    $files = Get-ChildItem -Path $RootPath -Include $patterns -Recurse -File -ErrorAction SilentlyContinue |
        Where-Object {
            $exclude = $false
            foreach ($pattern in $ExcludePatterns) {
                if ($_.FullName -like "*\$pattern\*" -or $_.FullName -like "*/$pattern/*") {
                    $exclude = $true
                    break
                }
            }
            -not $exclude
        }

    $result = @{
        TotalFiles = $files.Count
        FilesByLanguage = @{}
        Files = @($files | ForEach-Object { $_.FullName })
    }

    foreach ($lang in $Languages) {
        $langFiles = $files | Where-Object {
            $ext = $_.Extension
            $languagePatterns[$lang] -contains "*$ext"
        }
        $result.FilesByLanguage[$lang] = $langFiles.Count
    }

    if ($Json) {
        return $result | ConvertTo-Json -Depth 10
    }
    return $result
}

# Check for AppDoc configuration
function Test-AppDocConfig {
    param(
        [string]$RootPath = (Get-Location).Path,
        [switch]$Json
    )

    $configPath = Join-Path $RootPath ".AppDoc.json"
    $exists = Test-Path $configPath

    $result = @{
        Exists = $exists
        Path = $configPath
        Config = $null
    }

    if ($exists) {
        try {
            $result.Config = Get-Content $configPath | ConvertFrom-Json
        } catch {
            $result.Config = $null
            $result.Error = "Invalid JSON in config file"
        }
    }

    if ($Json) {
        return $result | ConvertTo-Json -Depth 10
    }
    return $result
}

# Format output as JSON for command parsing
function Write-JsonOutput {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Data
    )

    $json = $Data | ConvertTo-Json -Depth 10 -Compress
    Write-Output $json
}

# Get git repository information
function Get-GitInfo {
    param(
        [string]$RootPath = (Get-Location).Path,
        [switch]$Json
    )

    Push-Location $RootPath
    try {
        $isRepo = $null -ne (git rev-parse --git-dir 2>$null)

        $result = @{
            IsRepository = $isRepo
            Branch = ""
            RemoteUrl = ""
            HasUncommitted = $false
        }

        if ($isRepo) {
            $result.Branch = git rev-parse --abbrev-ref HEAD 2>$null
            $result.RemoteUrl = git remote get-url origin 2>$null
            $status = git status --porcelain 2>$null
            $result.HasUncommitted = ($status.Length -gt 0)
        }

        if ($Json) {
            return $result | ConvertTo-Json -Depth 10
        }
        return $result
    } finally {
        Pop-Location
    }
}

# Get AI agent configuration
function Get-AIAgentConfig {
    param(
        [string]$RootPath = (Get-Location).Path
    )

    $config = Test-AppDocConfig -RootPath $RootPath
    if ($config.Exists -and $config.Config) {
        return $config.Config.agent
    }

    # Default to Copilot if no config
    return @{
        primary = "copilot"
        fallback = "claude"
    }
}

# Test if running in VSCode environment
function Test-VSCodeEnvironment {
    $vscode = $env:TERM_PROGRAM -eq "vscode" -or $env:VSCODE_PID -ne $null
    return $vscode
}

# Get absolute path handling both Windows and Unix paths
function Get-AbsolutePath {
    param(
        [Parameter(Mandatory)]
        [string]$Path,
        [string]$BasePath = (Get-Location).Path
    )

    if ([System.IO.Path]::IsPathRooted($Path)) {
        return $Path
    }

    return Join-Path $BasePath $Path
}

# Helper function to wrap long text for better readability
function Format-WrappedText {
    param(
        [string]$Text,
        [int]$MaxWidth = 80
    )
    
    if ($Text.Length -le $MaxWidth) {
        return $Text
    }
    
    $words = $Text -split '\s+'
    $lines = @()
    $currentLine = ""
    
    foreach ($word in $words) {
        if (($currentLine + " " + $word).Length -le $MaxWidth) {
            if ($currentLine) {
                $currentLine += " " + $word
            } else {
                $currentLine = $word
            }
        } else {
            if ($currentLine) {
                $lines += $currentLine
            }
            $currentLine = $word
        }
    }
    
    if ($currentLine) {
        $lines += $currentLine
    }
    
    return $lines -join "`n  "
}

# Helper function to truncate text with ellipsis
function Format-TruncatedText {
    param(
        [string]$Text,
        [int]$MaxLength = 100
    )
    
    if ($Text.Length -le $MaxLength) {
        return $Text
    }
    
    return $Text.Substring(0, $MaxLength - 3) + "..."
}

# Functions are available when dot-sourced

