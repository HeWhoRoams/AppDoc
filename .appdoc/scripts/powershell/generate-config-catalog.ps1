#
# generate-config-catalog.ps1
#
# Purpose: Scans the target codebase for configuration files (.env, config.json, appsettings.json,
#          Web.config, App.config, etc.) and populates the config-catalog template with
#          discovered configuration options.
#
# Usage: .\generate-config-catalog.ps1 -RootPath <target_codebase_path>
# Output: Populates docs/config-catalog.md from template
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

Write-Host "⚙️  Generating Config Catalog..." -ForegroundColor Cyan

# Helper function to classify if a config is likely required (heuristic-based)
function Test-IsRequiredConfig {
    param(
        [string]$Key,
        [string]$Value,
        [string]$Type
    )
    
    # Required patterns
    $requiredKeywords = @(
        'Connection', 'Database', 'DB', 'DataSource',
        'Host', 'Server', 'Port', 'Url', 'BaseUrl', 'ApiUrl',
        'Secret', 'Key', 'Token', 'Auth',
        'Required', 'Mandatory'
    )
    
    # Optional patterns
    $optionalKeywords = @(
        'Debug', 'Trace', 'Log', 'Cache', 'Timeout',
        'Optional', 'Feature', 'Enable', 'Disable'
    )
    
    # Check if key contains required keywords
    foreach ($keyword in $requiredKeywords) {
        if ($Key -match $keyword) {
            return $true
        }
    }
    
    # Check if key contains optional keywords
    foreach ($keyword in $optionalKeywords) {
        if ($Key -match $keyword) {
            return $false
        }
    }
    
    # Connection strings are always required
    if ($Type -match 'Connection String') {
        return $true
    }
    
    # Default to optional for safety
    return $false
}

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Initialize template
$outputPath = Join-Path $RootPath "docs\config-catalog.md"
$initialized = Initialize-TemplateFile -TemplateName "config-catalog-template.md" -OutputPath $outputPath -RootPath $RootPath

if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Config Catalog" -Status "Scanning configs..." -PercentComplete 0

$configs = @()

# Common config file patterns
$configPatterns = @(
    @{ Pattern = ".env*"; Type = "Environment Variable" },
    @{ Pattern = "config.json"; Type = "JSON Configuration" },
    @{ Pattern = "config.js"; Type = "JavaScript Configuration" },
    @{ Pattern = "appsettings*.json"; Type = "ASP.NET Core Settings" },
    @{ Pattern = "settings.json"; Type = "JSON Configuration" },
    @{ Pattern = "Web.config"; Type = ".NET Web Configuration" },
    @{ Pattern = "App.config"; Type = ".NET Application Configuration" },
    @{ Pattern = "web.*.config"; Type = ".NET Web Transform" },
    @{ Pattern = "*.csproj"; Type = "MSBuild Project Configuration" }
)

try {
    foreach ($patternInfo in $configPatterns) {
        $pattern = $patternInfo.Pattern
        $fileType = $patternInfo.Type
        
        $configFiles = Get-ChildItem -Path $RootPath -Recurse -Filter $pattern -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\packages\\|\\\.vs\\)' } |
            Select-Object -First 20  # Limit to avoid overwhelming output
        
        foreach ($file in $configFiles) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            $relativePath = $file.FullName.Replace($RootPath, "").TrimStart('\', '/')
            
            # Parse .env files
            if ($file.Name -match "\.env") {
                $lines = $content -split "`n"
                $lineNum = 0
                foreach ($line in $lines) {
                    $lineNum++
                    if ($line -match "^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$") {
                        $key = $matches[1].Trim()
                        $value = $matches[2].Trim()
                        $configs += @{
                            key = $key
                            value = $value
                            file = $relativePath
                            type = "Environment Variable"
                            source = "$relativePath`:$lineNum"
                            required = Test-IsRequiredConfig -Key $key -Value $value -Type "Environment Variable"
                        }
                    }
                }
            }
            # Parse Web.config and App.config (XML)
            elseif ($file.Name -match "(Web|App)\.config$") {
                try {
                    [xml]$xml = $content
                    
                    # Extract appSettings
                    if ($xml.configuration.appSettings) {
                        foreach ($setting in $xml.configuration.appSettings.add) {
                            if ($setting.key) {
                                $configs += @{
                                    key = $setting.key
                                    value = $setting.value
                                    file = $relativePath
                                    type = ".NET appSettings"
                                    source = "$relativePath`:appSettings/$($setting.key)"
                                    required = Test-IsRequiredConfig -Key $setting.key -Value $setting.value -Type ".NET appSettings"
                                }
                            }
                        }
                    }
                    
                    # Extract connectionStrings
                    if ($xml.configuration.connectionStrings) {
                        foreach ($conn in $xml.configuration.connectionStrings.add) {
                            if ($conn.name) {
                                # Mask sensitive parts of connection string - improved to handle more variations
                                $maskedValue = $conn.connectionString `
                                    -replace '(Password|PWD|Pwd|password|pwd)=[^;]+', '$1=***' `
                                    -replace '(User ID|UID|Uid|user id|uid)=[^;]+', '$1=***' `
                                    -replace '(API[_\s]?Key|ApiKey|api[_\s]?key)=[^;]+', '$1=***' `
                                    -replace '(Secret|secret|SECRET)=[^;]+', '$1=***' `
                                    -replace '(Token|token|TOKEN)=[^;]+', '$1=***'
                                
                                # Determine if this is likely a required connection (heuristic based on name)
                                $isRequired = $conn.name -match '(Default|Main|Primary|Production|Prod|Database|DB)' -or `
                                              $conn.connectionString -match 'Initial Catalog|Database='
                                
                                $configs += @{
                                    key = $conn.name
                                    value = $maskedValue
                                    file = $relativePath
                                    type = ".NET Connection String"
                                    source = "$relativePath`:connectionStrings/$($conn.name)"
                                    required = $isRequired
                                }
                            }
                        }
                    }
                    
                    # Extract system.web compilation settings
                    if ($xml.configuration.'system.web'.compilation) {
                        $compilation = $xml.configuration.'system.web'.compilation
                        if ($compilation.debug) {
                            $configs += @{
                                key = "compilation.debug"
                                value = $compilation.debug
                                file = $relativePath
                                type = ".NET Compilation Setting"
                                source = "$relativePath`:system.web/compilation"
                            }
                        }
                        if ($compilation.targetFramework) {
                            $configs += @{
                                key = "targetFramework"
                                value = $compilation.targetFramework
                                file = $relativePath
                                type = ".NET Framework Version"
                                source = "$relativePath`:system.web/compilation"
                            }
                        }
                    }
                } catch {
                    Write-Verbose "Could not parse XML in $($file.Name): $_"
                }
            }
            # Parse .csproj files for configuration
            elseif ($file.Name -match "\.csproj$") {
                try {
                    [xml]$xml = $content
                    
                    # Extract target framework
                    $targetFramework = $xml.Project.PropertyGroup.TargetFramework | Select-Object -First 1
                    if (-not $targetFramework) {
                        $targetFramework = $xml.Project.PropertyGroup.TargetFrameworkVersion | Select-Object -First 1
                    }
                    
                    if ($targetFramework) {
                        $configs += @{
                            key = "TargetFramework"
                            value = $targetFramework
                            file = $relativePath
                            type = "MSBuild Configuration"
                            source = "$relativePath`:PropertyGroup/TargetFramework"
                        }
                    }
                    
                    # Extract output type
                    $outputType = $xml.Project.PropertyGroup.OutputType | Select-Object -First 1
                    if ($outputType) {
                        $configs += @{
                            key = "OutputType"
                            value = $outputType
                            file = $relativePath
                            type = "MSBuild Configuration"
                            source = "$relativePath`:PropertyGroup/OutputType"
                        }
                    }
                } catch {
                    Write-Verbose "Could not parse csproj XML in $($file.Name): $_"
                }
            }
            # Parse JSON config files
            elseif ($file.Name -match "\.json$") {
                try {
                    $json = $content | ConvertFrom-Json
                    $prefix = if ($file.Name -match "appsettings") { "appsettings" } else { "config" }
                    
                    # Recursively extract nested properties (max 2 levels deep)
                    function ExtractJsonProps($obj, $path = "") {
                        foreach ($prop in $obj.PSObject.Properties) {
                            $fullPath = if ($path) { "$path.$($prop.Name)" } else { $prop.Name }
                            
                            if ($prop.Value -is [PSCustomObject] -and $path.Split('.').Count -lt 2) {
                                ExtractJsonProps $prop.Value $fullPath
                            } else {
                                $script:configs += @{
                                    key = $fullPath
                                    value = if ($prop.Value -is [string]) { $prop.Value } else { $prop.Value | ConvertTo-Json -Compress -Depth 1 }
                                    file = $relativePath
                                    type = $fileType
                                    source = "$relativePath`:$fullPath"
                                }
                            }
                        }
                    }
                    
                    ExtractJsonProps $json
                } catch {
                    Write-Verbose "Could not parse JSON in $($file.Name): $_"
                }
            }
        }
    }
} catch {
    Write-Warning "Error scanning config files: $_"
}

Write-Progress -Activity "Generating Config Catalog" -Status "Creating catalog..." -PercentComplete 50

# Build content sections
$configSourcesContent = if ($configFiles.Count -gt 0) {
    $sources = $configFiles | Group-Object -Property type | ForEach-Object {
        "- **$($_.Name)**: $($_.Count) file(s)"
    }
    $sources -join "`n"
} else {
    "_No configuration sources detected. System may use hardcoded values or external configuration service._"
}

# Build Configuration Options table + placeholder replacement
$configTablePlaceholder = @"
| Name | Type | Default | Description | Required | Source |
|------|------|---------|-------------|----------|--------|

_No configuration options detected. Check for config files (.env, appsettings.json, etc.)._
"@

$configOptionsContent = if ($configs.Count -gt 0) {
    # Build comprehensive table
    $tableHeader = "| Name | Type | Default | Description | Required | Source |`n|------|------|---------|-------------|----------|--------|"
    $tableRows = $configs | ForEach-Object {
        $displayValue = if ($_.value.Length -gt 50) { $_.value.Substring(0, 47) + "..." } else { $_.value }
        $description = if ($_.key -match '\w+\.\w+') { "Nested configuration option" } else { "Configuration setting" }
        $required = "No" # Could be enhanced to detect required configs
        "| ``$($_.key)`` | $($_.type) | ``$displayValue`` | $description | $required | ``$($_.source)`` |"
    }
    $tableHeader + "`n" + ($tableRows -join "`n")
} else {
    $configTablePlaceholder
}

# Build Environment Variables table + placeholder replacement  
$envTablePlaceholder = @"
| Variable | Default | Description | Sensitive | Required |
|----------|---------|-------------|-----------|----------|

_No environment variables detected. System may use configuration files or defaults._
"@

$envVars = $configs | Where-Object { $_.key -match "^env\.|Environment" -or $_.type -eq ".env" }
$envVarsContent = if ($envVars.Count -gt 0) {
    $tableHeader = "| Variable | Default | Description | Sensitive | Required |`n|----------|---------|-------------|-----------|----------|"
    $tableRows = $envVars | ForEach-Object {
        $displayValue = if ($_.value.Length -gt 50) { $_.value.Substring(0, 47) + "..." } else { $_.value }
        $sensitive = if ($_.key -match "password|secret|key|token") { "Yes" } else { "No" }
        "| ``$($_.key)`` | ``$displayValue`` | Environment variable | $sensitive | No |"
    }
    $tableHeader + "`n" + ($tableRows -join "`n")
} else {
    $envTablePlaceholder
}

# Update template sections
$content = Get-Content -Path $outputPath -Raw

$content = Update-TemplateSection -Content $content -PlaceholderText "_No configuration sources detected. System may use hardcoded values or external configuration service._" -NewContent $configSourcesContent
$content = Update-TemplateSection -Content $content -PlaceholderText $configTablePlaceholder -NewContent $configOptionsContent  
$content = Update-TemplateSection -Content $content -PlaceholderText $envTablePlaceholder -NewContent $envVarsContent

# Add generation metadata
$content = Add-GenerationMetadata -Content $content

# Write back
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Progress -Activity "Generating Config Catalog" -Status "Complete" -PercentComplete 100
Write-Host "✅ Config catalog generated: $outputPath" -ForegroundColor Green
Write-Host "   Configurations found: $($configs.Count)" -ForegroundColor Gray