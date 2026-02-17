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

$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
if (Test-Path $scopeModule) {
    Import-Module $scopeModule -Force -ErrorAction Stop
}

$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
if (Test-Path $contractsModule) {
    Import-Module $contractsModule -Force -ErrorAction Stop
}

$evidenceModule = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (Test-Path $evidenceModule) {
    Import-Module $evidenceModule -Force -ErrorAction Stop
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

function ConvertTo-FlattenedPairs {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Data,
        [string]$Prefix = ""
    )

    $pairs = @()

    if ($null -eq $Data) {
        return @(@{ Key = $Prefix; Value = $null })
    }

    if ($Data -is [System.Collections.IDictionary]) {
        foreach ($key in $Data.Keys) {
            $childPrefix = if ($Prefix) { "$Prefix.$key" } else { $key }
            $pairs += ConvertTo-FlattenedPairs -Data $Data[$key] -Prefix $childPrefix
        }
    }
    elseif ($Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string])) {
        $index = 0
        foreach ($item in $Data) {
            $childPrefix = if ($Prefix) { "$Prefix[$index]" } else { "[$index]" }
            $pairs += ConvertTo-FlattenedPairs -Data $item -Prefix $childPrefix
            $index++
        }
    }
    else {
        $pairs += @{ Key = $Prefix; Value = $Data }
    }

    return $pairs
}

function Get-RelativePathSafe {
    param(
        [Parameter(Mandatory=$true)]
        [string]$BasePath,
        [Parameter(Mandatory=$true)]
        [string]$TargetPath
    )

    try {
        $baseFull = (Resolve-Path $BasePath).Path
        $targetFull = (Resolve-Path $TargetPath).Path
        return [System.IO.Path]::GetRelativePath($baseFull, $targetFull).Replace('\\', '/')
    }
    catch {
        return $TargetPath
    }
}

function Sanitize-MarkdownCell {
    param(
        [AllowNull()]
        [object]$Value,
        [int]$MaxLength = 80
    )

    if ($null -eq $Value) { return "" }

    $text = [string]$Value
    $text = $text -replace '[\r\n\t]+', ' '
    $text = $text -replace '\|', '\\|'
    $text = $text.Trim()

    if ($text.Length -gt $MaxLength) {
        return $text.Substring(0, $MaxLength - 3) + "..."
    }

    return $text
}

function Sanitize-ConfigKey {
    param([string]$Key)

    if (-not $Key) { return "" }

    $clean = [string]$Key
    $clean = $clean -replace '[\r\n\t]+', ' '
    $clean = $clean -replace '\s+', ' '
    $clean = $clean -replace '^\.+', ''
    $clean = $clean.Trim()

    return $clean
}

function Convert-ConfigKeyToEnvVarName {
    param([string]$Key)

    if (-not $Key) { return "" }

    $normalized = [string]$Key
    $normalized = $normalized -replace '^appsettings\.', ''
    $normalized = $normalized -replace '\[\d+\]', ''
    $normalized = $normalized -replace '\.', '__'
    $normalized = $normalized -replace ':', '__'
    $normalized = $normalized -replace '[^A-Za-z0-9_]', '_'
    $normalized = $normalized -replace '_{2,}', '__'
    $normalized = $normalized.Trim('_')

    if (-not $normalized) { return "" }
    return $normalized.ToUpperInvariant()
}

function Get-DerivedEnvironmentVariables {
    param(
        [Parameter(Mandatory=$true)]
        [array]$Configs,
        [int]$MaxCount = 80
    )

    $derived = @()
    $seen = @{}
    $candidatePattern = '(?i)(connection|string|database|db|server|host|port|url|endpoint|api|token|secret|password|key|username|user|environment|mode|timeout|cache|redis|queue|smtp|proxy)'

    foreach ($config in $Configs) {
        if (-not $config.key) { continue }
        if (-not ($config.key -match $candidatePattern)) { continue }

        $envName = Convert-ConfigKeyToEnvVarName -Key ([string]$config.key)
        if (-not $envName) { continue }
        if ($seen.ContainsKey($envName)) { continue }

        $seen[$envName] = $true
        $derived += @{
            key = $envName
            value = if ($config.value) { [string]$config.value } else { "" }
            required = [bool]$config.required
            description = "Derived from config key '$([string]$config.key)'"
            type = "Derived Environment Variable"
        }

        if ($derived.Count -ge $MaxCount) {
            break
        }
    }

    return $derived
}

function Update-LiteralTemplateSection {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$PlaceholderText,
        [Parameter(Mandatory=$true)]
        [AllowEmptyString()]
        [string]$NewContent
    )

    if ($Content.Contains($PlaceholderText)) {
        return $Content.Replace($PlaceholderText, $NewContent)
    }

    return $Content
}

function Get-AppDocTemplateContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$TemplateName,
        [Parameter(Mandatory=$true)]
        [string]$FallbackPath
    )

    $scriptRoot = Split-Path $PSScriptRoot -Parent
    $appDocRoot = if ($scriptRoot) { Split-Path $scriptRoot -Parent } else { $null }
    $candidateTemplateDirs = @(
        (Join-Path $RootPath ".appdoc\templates"),
        $(if ($appDocRoot) { Join-Path $appDocRoot "templates" })
    ) | Where-Object { $_ -and (Test-Path $_) }

    foreach ($dir in $candidateTemplateDirs) {
        $path = Join-Path $dir $TemplateName
        if (Test-Path $path) {
            return (Get-Content -Path $path -Raw)
        }
    }

    return (Get-Content -Path $FallbackPath -Raw)
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
$discoveredConfigFiles = @()

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
    @{ Pattern = "*.csproj"; Type = "MSBuild Project Configuration" },
    @{ Pattern = "*.yaml"; Type = "YAML Configuration" },
    @{ Pattern = "*.yml"; Type = "YAML Configuration" },
    @{ Pattern = "*.toml"; Type = "TOML Configuration" },
    @{ Pattern = "*.ini"; Type = "INI Configuration" },
    @{ Pattern = "*.properties"; Type = "Properties Configuration" }
)

try {
    foreach ($patternInfo in $configPatterns) {
        $pattern = $patternInfo.Pattern
        $fileType = $patternInfo.Type
        
        $configFiles = Get-ChildItem -Path $RootPath -Recurse -Filter $pattern -ErrorAction SilentlyContinue |
            Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\packages\\|\\\.vs\\|\\\.git\\|\\docs\\|\\\.appdoc\\|\\specs\\|\\\.vscode\\|\\tests\\fixtures\\)' }
        
        foreach ($file in $configFiles) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }
            
            $relativePath = Get-RelativePathSafe -BasePath $RootPath -TargetPath $file.FullName
            $discoveredConfigFiles += @{
                path = $relativePath
                type = $fileType
            }
            
            # Parse .env files
            if ($file.Name -match "\.env") {
                $lines = $content -split "`n"
                $lineNum = 0
                foreach ($line in $lines) {
                    $lineNum++
                    if ($line -match "^\s*([A-Z_][A-Z0-9_]*)\s*=\s*(.*)$") {
                        $key = Sanitize-ConfigKey -Key $matches[1].Trim()
                        $value = Sanitize-MarkdownCell -Value $matches[2].Trim() -MaxLength 120
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
                                    key = Sanitize-ConfigKey -Key ([string]$setting.key)
                                    value = Sanitize-MarkdownCell -Value ([string]$setting.value) -MaxLength 120
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
                                    key = Sanitize-ConfigKey -Key ([string]$conn.name)
                                    value = Sanitize-MarkdownCell -Value $maskedValue -MaxLength 140
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
                                value = Sanitize-MarkdownCell -Value $compilation.debug
                                file = $relativePath
                                type = ".NET Compilation Setting"
                                source = "$relativePath`:system.web/compilation"
                            }
                        }
                        if ($compilation.targetFramework) {
                            $configs += @{
                                key = "targetFramework"
                                value = Sanitize-MarkdownCell -Value $compilation.targetFramework
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
                            value = Sanitize-MarkdownCell -Value $targetFramework
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
                            value = Sanitize-MarkdownCell -Value $outputType
                            file = $relativePath
                            type = "MSBuild Configuration"
                            source = "$relativePath`:PropertyGroup/OutputType"
                        }
                    }
                } catch {
                    Write-Verbose "Could not parse csproj XML in $($file.Name): $_"
                }
            }
            # Parse YAML/YML files
            elseif ($file.Name -match "\.ya?ml$") {
                try {
                    $yamlDocuments = ConvertFrom-Yaml -Yaml $content -ErrorAction Stop
                    if ($null -eq $yamlDocuments) { continue }
                    if (-not ($yamlDocuments -is [System.Collections.IEnumerable])) {
                        $yamlDocuments = @($yamlDocuments)
                    }

                    $docIndex = 0
                    foreach ($doc in $yamlDocuments) {
                        $pairs = ConvertTo-FlattenedPairs -Data $doc
                        foreach ($pair in $pairs) {
                            if (-not $pair.Key) { continue }
                            $valueString = if ($pair.Value -is [string]) { $pair.Value } elseif ($null -eq $pair.Value) { "null" } else { ($pair.Value | ConvertTo-Json -Compress -Depth 3) }
                            $configs += @{
                                key = Sanitize-ConfigKey -Key ([string]$pair.Key)
                                value = Sanitize-MarkdownCell -Value $valueString -MaxLength 120
                                file = $relativePath
                                type = $fileType
                                source = "$relativePath`:yaml[$docIndex]/$($pair.Key)"
                                required = Test-IsRequiredConfig -Key $pair.Key -Value $valueString -Type $fileType
                            }
                        }
                        $docIndex++
                    }
                } catch {
                    Write-Verbose "Could not parse YAML in $($file.Name): $_"
                }
            }
            # Parse INI / TOML / properties files
            elseif ($file.Name -match "\.(toml|ini|conf|properties)$") {
                $section = ""
                $lines = $content -split "`n"
                $lineNum = 0
                foreach ($line in $lines) {
                    $lineNum++
                    $trimmed = $line.Trim()
                    if (-not $trimmed) { continue }
                    if ($trimmed -match '^[#;]') { continue }
                    if ($trimmed -match '^\[(.+?)\]\s*$') {
                        $section = $Matches[1].Trim()
                        continue
                    }
                    if ($trimmed -match '^([^=:#]+)\s*[:=]\s*(.+)$') {
                        $key = $Matches[1].Trim()
                        $value = $Matches[2].Trim()
                        $fullKey = if ($section) { "$section.$key" } else { $key }
                        $configs += @{
                            key = Sanitize-ConfigKey -Key $fullKey
                            value = Sanitize-MarkdownCell -Value $value -MaxLength 120
                            file = $relativePath
                            type = $fileType
                            source = "$relativePath`:$lineNum"
                            required = Test-IsRequiredConfig -Key $fullKey -Value $value -Type $fileType
                        }
                    }
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
                                    key = Sanitize-ConfigKey -Key $fullPath
                                    value = if ($prop.Value -is [string]) { Sanitize-MarkdownCell -Value $prop.Value -MaxLength 120 } else { Sanitize-MarkdownCell -Value ($prop.Value | ConvertTo-Json -Compress -Depth 1) -MaxLength 120 }
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
$configSourcesContent = if ($discoveredConfigFiles.Count -gt 0) {
    $sources = $discoveredConfigFiles | Group-Object -Property type | ForEach-Object {
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
        $key = Sanitize-MarkdownCell -Value $_.key -MaxLength 140
        $displayValue = Sanitize-MarkdownCell -Value $_.value -MaxLength 80
        $type = Sanitize-MarkdownCell -Value $_.type -MaxLength 50
        $source = Sanitize-MarkdownCell -Value $_.source -MaxLength 140
        $description = if ($key -match '\w+\.\w+') { "Nested configuration option" } else { "Configuration setting" }
        $required = if ($_.required) { "Yes" } else { "No" }
        "| $key | $type | $displayValue | $description | $required | $source |"
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

$explicitEnvVars = @($configs | Where-Object { $_.key -match "^env\.|Environment" -or $_.type -in @(".env","Environment Variable") })
$derivedEnvVars = @()
if ($explicitEnvVars.Count -eq 0) {
    $derivedEnvVars = @(Get-DerivedEnvironmentVariables -Configs $configs)
}

$envVars = @($explicitEnvVars)
if ($derivedEnvVars.Count -gt 0) {
    $envVars += $derivedEnvVars
}

$envVars = @($envVars | Sort-Object -Property key -Unique)

$envVarsContent = if ($envVars.Count -gt 0) {
    $tableHeader = "| Variable | Default | Description | Sensitive | Required |`n|----------|---------|-------------|-----------|----------|"
    $tableRows = $envVars | ForEach-Object {
        $envKey = Sanitize-MarkdownCell -Value $_.key -MaxLength 120
        $displayValue = Sanitize-MarkdownCell -Value $_.value -MaxLength 80
        $description = if ($_.description) { Sanitize-MarkdownCell -Value $_.description -MaxLength 120 } else { "Environment variable" }
        $sensitive = if ($envKey -match "password|secret|key|token") { "Yes" } else { "No" }
        $required = if ($_.required) { "Yes" } else { "No" }
        "| $envKey | $displayValue | $description | $sensitive | $required |"
    }
    $tableHeader + "`n" + ($tableRows -join "`n")
} else {
    $envTablePlaceholder
}

# Update template sections (always begin from fresh template content)
$content = Get-AppDocTemplateContent -RootPath $RootPath -TemplateName "config-catalog-template.md" -FallbackPath $outputPath

$content = Update-LiteralTemplateSection -Content $content -PlaceholderText "_No configuration sources detected. System may use hardcoded values or external configuration service._" -NewContent $configSourcesContent
$content = Update-LiteralTemplateSection -Content $content -PlaceholderText $configTablePlaceholder -NewContent $configOptionsContent
$content = Update-LiteralTemplateSection -Content $content -PlaceholderText $envTablePlaceholder -NewContent $envVarsContent

$content = Normalize-AppDocTemplateInstructionText -Content $content
# Add generation metadata
$content = Add-GenerationMetadata -Content $content

# Write back
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "config-catalog"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @(
    $configs | ForEach-Object {
        New-AppDocExtractionRecord -Artifact $artifact -Source ([string]$_.source) -Name ([string]$_.key) -Kind "configuration" -Confidence 0.85 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            value = [string]$_.value
            file = [string]$_.file
            type = [string]$_.type
            required = [bool]$_.required
        }
    }
)
$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    configCount = $configs.Count
    generator = "generate-config-catalog.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-config-catalog.ps1"
    })
}

Write-Progress -Activity "Generating Config Catalog" -Status "Complete" -PercentComplete 100
Write-Host "✅ Config catalog generated: $outputPath" -ForegroundColor Green
Write-Host "   Configurations found: $($configs.Count)" -ForegroundColor Gray
