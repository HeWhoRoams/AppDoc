function Test-AppDocRequiredConfig {
    [CmdletBinding()]
    param(
        [string]$Key,
        [string]$Value,
        [string]$Type
    )

    $requiredKeywords = @(
        'Connection', 'Database', 'DB', 'DataSource',
        'Host', 'Server', 'Port', 'Url', 'BaseUrl', 'ApiUrl',
        'Secret', 'Key', 'Token', 'Auth',
        'Required', 'Mandatory'
    )
    $optionalKeywords = @(
        'Debug', 'Trace', 'Log', 'Cache', 'Timeout',
        'Optional', 'Feature', 'Enable', 'Disable'
    )

    foreach ($keyword in $requiredKeywords) {
        $escaped = [regex]::Escape($keyword)
        $pattern = "\b$escaped\b"
        if ($Key -match $pattern) { return $true }
    }
    foreach ($keyword in $optionalKeywords) {
        $escaped = [regex]::Escape($keyword)
        $pattern = "\b$escaped\b"
        if ($Key -match $pattern) { return $false }
    }
    if ($Type -match 'Connection String') { return $true }
    return $false
}

function Test-AppDocSensitiveConfigKey {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Key,
        [AllowNull()]
        [string]$Type
    )

    $combined = ("{0} {1}" -f ($Key ?? ""), ($Type ?? "")).ToLowerInvariant()
    return ($combined -match '(password|passwd|pwd|secret|token|api[_-]?key|client[_-]?secret|private[_-]?key|connectionstring|connection string|sas(?:token)?|thumbprint|cert(?:ificate)?[_-]?(password|secret|key))')
}

function Test-AppDocSecretLikeValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Key,
        [AllowNull()]
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return $false }
    $trimmed = $Value.Trim()
    $keyHint = ($Key ?? "").ToLowerInvariant()
    $looksLikeIdentifier = (
        $trimmed -match '^\d{6,}$' -or
        $trimmed -match '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[1-5][0-9a-fA-F]{3}-[89abAB][0-9a-fA-F]{3}-[0-9a-fA-F]{12}$' -or
        (($keyHint -match '(?:^|[._-])(id|identifier|workflowid|workflow_id|configid|config_id|runid|run_id|jobid|job_id|buildid|build_id)(?:$|[._-])') -and
            $trimmed -match '^[A-Za-z0-9_-]{4,}$')
    )
    if ($looksLikeIdentifier) { return $false }

    if ($trimmed -match '^(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}$') { return $true }
    if ($trimmed -match '^eyJ[A-Za-z0-9_-]+\.[A-Za-z0-9._-]+\.[A-Za-z0-9._-]+$') { return $true }
    if ($trimmed -match '^[A-Za-z0-9+/]{32,}={0,2}$') { return $true }
    if ($trimmed -match '^[A-Fa-f0-9]{32,}$') { return $true }

    return $false
}

function Protect-AppDocConfigValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Key,
        [AllowNull()]
        [object]$Value,
        [AllowNull()]
        [string]$Type
    )

    if ($null -eq $Value) { return "" }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return "" }

    if (Test-AppDocSensitiveConfigKey -Key $Key -Type $Type) { return "[REDACTED]" }
    if (Test-AppDocSecretLikeValue -Key $Key -Value $text) { return "[REDACTED]" }
    return $text
}

function ConvertTo-AppDocFlattenedPairs {
    [CmdletBinding()]
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
            $pairs += ConvertTo-AppDocFlattenedPairs -Data $Data[$key] -Prefix $childPrefix
        }
    }
    elseif ($Data -is [System.Collections.IEnumerable] -and -not ($Data -is [string])) {
        $index = 0
        foreach ($item in $Data) {
            $childPrefix = if ($Prefix) { "$Prefix[$index]" } else { "[$index]" }
            $pairs += ConvertTo-AppDocFlattenedPairs -Data $item -Prefix $childPrefix
            $index++
        }
    }
    else {
        $pairs += @{ Key = $Prefix; Value = $Data }
    }

    return $pairs
}

function ConvertFrom-AppDocYamlFallback {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$YamlText
    )

    $flattened = @{}
    $stack = @(@{ indent = -1; prefix = "" })
    $lines = $YamlText -split "`r?`n"

    foreach ($line in $lines) {
        if ([string]::IsNullOrWhiteSpace($line)) { continue }
        $trimmed = $line.Trim()
        if ($trimmed -match '^(#|---|\.\.\.)') { continue }

        $indent = $line.Length - $line.TrimStart().Length
        while ($stack.Count -gt 1 -and $indent -le $stack[$stack.Count - 1].indent) {
            $stack = @($stack[0..($stack.Count - 2)])
        }
        $parentPrefix = $stack[$stack.Count - 1].prefix

        if ($trimmed -match '^([A-Za-z0-9_.-]+)\s*:\s*(.*)$') {
            $key = $Matches[1]
            $value = $Matches[2]
            $fullKey = if ($parentPrefix) { "$parentPrefix.$key" } else { $key }

            if ([string]::IsNullOrWhiteSpace($value) -or $value -in @("|", ">")) {
                $stack += @{ indent = $indent; prefix = $fullKey }
                continue
            }

            $normalizedValue = $value.Trim() -replace "^['""](.+)['""]$", '$1'
            $flattened[$fullKey] = $normalizedValue
            continue
        }

        if ($trimmed -match '^-+\s*(.+)$' -and $parentPrefix) {
            $index = 0
            while ($flattened.ContainsKey("${parentPrefix}[$index]")) { $index++ }
            $flattened["${parentPrefix}[$index]"] = $Matches[1].Trim()
        }
    }

    return $flattened
}

function Get-AppDocConfigRelativePath {
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

    try {
        $rootFull = (Resolve-Path $RootPath).Path
        $pathFull = (Resolve-Path $Path).Path
        return [System.IO.Path]::GetRelativePath($rootFull, $pathFull).Replace('\', '/')
    }
    catch {
        return $Path.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
    }
}

function Sanitize-AppDocConfigKey {
    [CmdletBinding()]
    param([string]$Key)

    if (-not $Key) { return "" }

    $clean = [string]$Key
    $clean = $clean -replace '[\r\n\t]+', ' '
    $clean = $clean -replace '\s+', ' '
    $clean = $clean -replace '^\.+', ''
    return $clean.Trim()
}

function Convert-AppDocConfigKeyToEnvVarName {
    [CmdletBinding()]
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

function Get-AppDocDerivedEnvironmentVariables {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Configs,
        [int]$MaxCount = 80
    )

    $derived = @()
    foreach ($config in $Configs) {
        if ($derived.Count -ge $MaxCount) { return $derived }
        if ($null -ne $config.key) {
            $envVar = Convert-AppDocConfigKeyToEnvVarName $config.key
            $derived += $envVar
        }
    }
    return $derived
}

function Get-AppDocConfigSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string[]]$Include
    )

    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "config-catalog" -Include $Include)
    }

    return @(Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include $Include -ErrorAction SilentlyContinue)
}

function Add-AppDocJsonConfigProperties {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [psobject]$JsonObject,
        [Parameter(Mandatory=$true)]
        [string]$RelativePath,
        [Parameter(Mandatory=$true)]
        [string]$FileType,
        [string]$Path = "",
        [int]$Depth = 0,
        [int]$MaxDepth = 2
    )

    $results = @()
    foreach ($prop in $JsonObject.PSObject.Properties) {
        $fullPath = if ($Path) { "$Path.$($prop.Name)" } else { $prop.Name }
        if ($prop.Value -is [PSCustomObject] -and $Depth -lt $MaxDepth) {
            $results += Add-AppDocJsonConfigProperties -JsonObject $prop.Value -RelativePath $RelativePath -FileType $FileType -Path $fullPath -Depth ($Depth + 1) -MaxDepth $MaxDepth
            continue
        }

        $value = if ($prop.Value -is [string]) { $prop.Value } else { ($prop.Value | ConvertTo-Json -Compress -Depth 3) }
        $normPath = ($RelativePath -replace '\\+', '/') -replace '/+', '/'
        $normFull = ("${normPath}:$fullPath" -replace '\\+', '/') -replace '/+', '/'
        $results += @{
            key = Sanitize-AppDocConfigKey -Key $fullPath
            value = Protect-AppDocConfigValue -Key $fullPath -Value $value -Type $FileType
            file = $normPath
            type = $FileType
            source = $normFull
            name = $normFull
            required = Test-AppDocRequiredConfig -Key $fullPath -Value ([string]$value) -Type $FileType
        }
    }

    return $results
}

function Get-AppDocConfigCatalogData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $configs = @()
    $discoveredConfigFiles = @()
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

    foreach ($patternInfo in $configPatterns) {
        $pattern = [string]$patternInfo.Pattern
        $fileType = [string]$patternInfo.Type
        $configFiles = Get-AppDocConfigSourceFiles -RootPath $RootPath -Include @($pattern)

        foreach ($file in $configFiles) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }

            $relativePath = Get-AppDocConfigRelativePath -RootPath $RootPath -Path $file.FullName
            $discoveredConfigFiles += @{
                path = $relativePath
                type = $fileType
            }

            if ($file.Name -match "\.env") {
                $lines = $content -split "`n"
                $lineNum = 0
                foreach ($line in $lines) {
                    $lineNum++
                    if ($line -match "^\s*([A-Za-z_][A-Za-z0-9_]*)\s*=\s*(.*)$") {
                        $key = Sanitize-AppDocConfigKey -Key $Matches[1].Trim()
                        $rawValue = $Matches[2].Trim()
                        $configs += @{
                            key = $key
                            value = Protect-AppDocConfigValue -Key $key -Value $rawValue -Type "Environment Variable"
                            file = $relativePath
                            type = "Environment Variable"
                            source = "$relativePath`:$lineNum"
                            required = Test-AppDocRequiredConfig -Key $key -Value $rawValue -Type "Environment Variable"
                        }
                    }
                }
                continue
            }

            if ($file.Name -match "(Web|App)\.config$") {
                try {
                    [xml]$xml = $content
                    if ($xml.configuration.appSettings) {
                        foreach ($setting in $xml.configuration.appSettings.add) {
                            if (-not $setting.key) { continue }
                            $settingKey = [string]$setting.key
                            $settingValue = [string]$setting.value
                            $configs += @{
                                key = Sanitize-AppDocConfigKey -Key $settingKey
                                value = Protect-AppDocConfigValue -Key $settingKey -Value $settingValue -Type ".NET appSettings"
                                file = $relativePath
                                type = ".NET appSettings"
                                source = "$relativePath`:appSettings/$settingKey"
                                required = Test-AppDocRequiredConfig -Key $settingKey -Value $settingValue -Type ".NET appSettings"
                            }
                        }
                    }

                    if ($xml.configuration.connectionStrings) {
                        foreach ($conn in $xml.configuration.connectionStrings.add) {
                            if (-not $conn.name) { continue }
                            $connName = [string]$conn.name
                            $connValue = [string]$conn.connectionString
                            $isRequired = $connName -match '(Default|Main|Primary|Production|Prod|Database|DB)' -or $connValue -match 'Initial Catalog|Database='
                            $configs += @{
                                key = Sanitize-AppDocConfigKey -Key $connName
                                value = Protect-AppDocConfigValue -Key $connName -Value $connValue -Type ".NET Connection String"
                                file = $relativePath
                                type = ".NET Connection String"
                                source = "$relativePath`:connectionStrings/$connName"
                                required = $isRequired
                            }
                        }
                    }

                    if ($xml.configuration.'system.web'.compilation) {
                        $compilation = $xml.configuration.'system.web'.compilation
                        if ($compilation.debug) {
                            $configs += @{
                                key = "compilation.debug"
                                value = Protect-AppDocConfigValue -Key "compilation.debug" -Value $compilation.debug -Type ".NET Compilation Setting"
                                file = $relativePath
                                type = ".NET Compilation Setting"
                                source = "$relativePath`:system.web/compilation"
                                required = $false
                            }
                        }
                        if ($compilation.targetFramework) {
                            $configs += @{
                                key = "targetFramework"
                                value = Protect-AppDocConfigValue -Key "targetFramework" -Value $compilation.targetFramework -Type ".NET Framework Version"
                                file = $relativePath
                                type = ".NET Framework Version"
                                source = "$relativePath`:system.web/compilation"
                                required = $false
                            }
                        }
                    }
                }
                catch {
                    Write-Verbose "Could not parse XML in $($file.Name): $($_.Exception.Message)"
                }
                continue
            }

            if ($file.Name -match "\.csproj$") {
                try {
                    [xml]$xml = $content
                    $targetFramework = $xml.Project.PropertyGroup.TargetFramework | Select-Object -First 1
                    if (-not $targetFramework) {
                        $targetFramework = $xml.Project.PropertyGroup.TargetFrameworkVersion | Select-Object -First 1
                    }
                    if ($targetFramework) {
                        $configs += @{
                            key = "TargetFramework"
                            value = Protect-AppDocConfigValue -Key "TargetFramework" -Value $targetFramework -Type "MSBuild Configuration"
                            file = $relativePath
                            type = "MSBuild Configuration"
                            source = "$relativePath`:PropertyGroup/TargetFramework"
                            required = $false
                        }
                    }

                    $outputType = $xml.Project.PropertyGroup.OutputType | Select-Object -First 1
                    if ($outputType) {
                        $configs += @{
                            key = "OutputType"
                            value = Protect-AppDocConfigValue -Key "OutputType" -Value $outputType -Type "MSBuild Configuration"
                            file = $relativePath
                            type = "MSBuild Configuration"
                            source = "$relativePath`:PropertyGroup/OutputType"
                            required = $false
                        }
                    }
                }
                catch {
                    Write-Verbose "Could not parse csproj XML in $($file.Name): $($_.Exception.Message)"
                }
                continue
            }

            if ($file.Name -match "\.ya?ml$") {
                $yamlCmd = Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue
                if (-not $yamlCmd) {
                    try {
                        Import-Module powershell-yaml -ErrorAction Stop
                        $yamlCmd = Get-Command ConvertFrom-Yaml -ErrorAction SilentlyContinue
                    }
                    catch {
                        $yamlCmd = $null
                    }
                }
                if (-not $yamlCmd) {
                    $fallbackPairs = ConvertFrom-AppDocYamlFallback -YamlText $content
                    foreach ($pairKey in $fallbackPairs.Keys) {
                        $valueString = [string]$fallbackPairs[$pairKey]
                        $configs += @{
                            key = Sanitize-AppDocConfigKey -Key ([string]$pairKey)
                            value = Protect-AppDocConfigValue -Key ([string]$pairKey) -Value $valueString -Type $fileType
                            file = $relativePath
                            type = $fileType
                            source = "$relativePath`:yaml/$pairKey"
                            required = Test-AppDocRequiredConfig -Key ([string]$pairKey) -Value ([string]$valueString) -Type $fileType
                        }
                    }
                    continue
                }

                try {
                    $yamlDocuments = ConvertFrom-Yaml -Yaml $content -ErrorAction Stop
                    if ($null -eq $yamlDocuments) { continue }
                    if (-not ($yamlDocuments -is [System.Collections.IEnumerable])) {
                        $yamlDocuments = @($yamlDocuments)
                    }

                    $docIndex = 0
                    foreach ($doc in $yamlDocuments) {
                        $pairs = ConvertTo-AppDocFlattenedPairs -Data $doc
                        foreach ($pair in $pairs) {
                            if (-not $pair.Key) { continue }
                            $valueString = if ($pair.Value -is [string]) { $pair.Value } elseif ($null -eq $pair.Value) { "null" } else { ($pair.Value | ConvertTo-Json -Compress -Depth 3) }
                            $configs += @{
                                key = Sanitize-AppDocConfigKey -Key ([string]$pair.Key)
                                value = Protect-AppDocConfigValue -Key ([string]$pair.Key) -Value $valueString -Type $fileType
                                file = $relativePath
                                type = $fileType
                                source = "$relativePath`:yaml[$docIndex]/$($pair.Key)"
                                required = Test-AppDocRequiredConfig -Key ([string]$pair.Key) -Value ([string]$valueString) -Type $fileType
                            }
                        }
                        $docIndex++
                    }
                }
                catch {
                    Write-Verbose "Could not parse YAML in $($file.Name): $($_.Exception.Message)"
                }
                continue
            }

            if ($file.Name -match "\.(toml|ini|conf|properties)$") {
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
                            key = Sanitize-AppDocConfigKey -Key $fullKey
                            value = Protect-AppDocConfigValue -Key $fullKey -Value $value -Type $fileType
                            file = $relativePath
                            type = $fileType
                            source = "$relativePath`:$lineNum"
                            required = Test-AppDocRequiredConfig -Key $fullKey -Value $value -Type $fileType
                        }
                    }
                }
                continue
            }

            if ($file.Name -match "\.json$") {
                try {
                    $json = $content | ConvertFrom-Json
                    $configs += Add-AppDocJsonConfigProperties -JsonObject $json -RelativePath $relativePath -FileType $fileType
                }
                catch {
                    Write-Verbose "Could not parse JSON in $($file.Name): $($_.Exception.Message)"
                }
            }
        }
    }

    $dedupedConfigs = @(
        $configs |
            Where-Object { $_.key -and $_.source } |
            Group-Object { "{0}|{1}|{2}|{3}" -f [string]$_.file, [string]$_.source, [string]$_.key, [string]$_.type } |
            ForEach-Object { $_.Group | Select-Object -First 1 } |
            Sort-Object @{ Expression = { [string]$_.file } }, @{ Expression = { [string]$_.key } }, @{ Expression = { [string]$_.source } }, @{ Expression = { [string]$_.type } }
    )

    $dedupedSources = @(
        $discoveredConfigFiles |
            Where-Object { $_.path -and $_.type } |
            Group-Object { "{0}|{1}" -f [string]$_.type, [string]$_.path } |
            ForEach-Object { $_.Group | Select-Object -First 1 } |
            Sort-Object @{ Expression = { [string]$_.type } }, @{ Expression = { [string]$_.path } }
    )

    $explicitEnvVars = @($dedupedConfigs | Where-Object { $_.key -match "^env\.|Environment" -or $_.type -in @(".env","Environment Variable") })
    $derivedEnvVars = @()
    if ($explicitEnvVars.Count -eq 0) {
        $derivedEnvVars = @(Get-AppDocDerivedEnvironmentVariables -Configs $dedupedConfigs)
    }
    $envVars = @(
        @($explicitEnvVars + $derivedEnvVars) |
            Group-Object { [string]$_.key } |
            ForEach-Object { $_.Group | Select-Object -First 1 } |
            Sort-Object @{ Expression = { [string]$_.key } }
    )

    return [ordered]@{
        configs = $dedupedConfigs
        discoveredConfigFiles = $dedupedSources
        envVars = $envVars
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocConfigCatalogData'
)
