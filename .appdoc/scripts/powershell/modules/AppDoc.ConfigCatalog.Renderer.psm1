function Sanitize-AppDocConfigMarkdownCell {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,
        [int]$MaxLength = 80
    )

    if ($null -eq $Value) { return "" }

    $text = [string]$Value
    $text = $text -replace '[\r\n\t]+', ' '
    $text = $text -replace '\|', '\\|'
    $text = $text -replace '\s+', ' '
    $text = $text.Trim()

    if ($text.Length -gt $MaxLength) {
        if ($MaxLength -lt 4) { return "..." }
        return $text.Substring(0, $MaxLength - 3) + "..."
    }

    return $text
}

function Update-AppDocLiteralTemplateSection {
    [CmdletBinding()]
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

function Get-AppDocConfigCatalogTemplateContent {
    [CmdletBinding()]
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

    if (-not (Test-Path $FallbackPath)) {
        throw "Template fallback path does not exist: $FallbackPath. Template '$TemplateName' could not be found."
    }
    return (Get-Content -Path $FallbackPath -Raw)
}

function Get-AppDocConfigCatalogMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$Configs,
        [Parameter(Mandatory=$true)]
        [array]$DiscoveredConfigFiles,
        [Parameter(Mandatory=$true)]
        [array]$EnvVars
    )

    $configTablePlaceholder = @"
| Name | Type | Default | Description | Required | Source |
|------|------|---------|-------------|----------|--------|

_No configuration options detected. Check for config files (.env, appsettings.json, etc.)._
"@

    $envTablePlaceholder = @"
| Variable | Default | Description | Sensitive | Required |
|----------|---------|-------------|-----------|----------|

_No environment variables detected. System may use configuration files or defaults._
"@

    $configSourcesContent = if ($DiscoveredConfigFiles.Count -gt 0) {
        ($DiscoveredConfigFiles | Group-Object -Property type | ForEach-Object {
            "- **$($_.Name)**: $($_.Count) file(s)"
        }) -join "`n"
    } else {
        "No scoped configuration source files were detected in this scan. Verify repository scope and environment-specific config locations."
    }

    # Helper: Infer type from value
    function Infer-AppDocConfigType($value) {
        if ($null -eq $value) { return "unknown" }
        if ($value -is [bool] -or $value -eq $true -or $value -eq $false) { return "boolean" }
        if ($value -is [int] -or $value -match '^-?\d+$') { return "integer" }
        if ($value -is [double] -or $value -match '^-?\d+\.\d+$') { return "number" }
        if ($value -is [string] -and ($value -eq "true" -or $value -eq "false")) { return "boolean" }
        if ($value -is [string] -and $value -match '^-?\d+$') { return "integer" }
        if ($value -is [string] -and $value -match '^-?\d+\.\d+$') { return "number" }
        if ($value -is [string] -and $value.StartsWith("[")) { return "array" }
        if ($value -is [string] -and $value.StartsWith("{")) { return "object" }
        return "string"
    }

    # Helper: Synthesize description for config key
    function Synthesize-AppDocConfigDescription($key, $parent, $settingsComments) {
        # Try to find a comment for this key
        $lookup = $key
        if ($parent) { $lookup = "$parent.$key" }
        $lookup = ($lookup -replace '\s+', '').ToLowerInvariant()
        if ($settingsComments.ContainsKey($lookup)) { return $settingsComments[$lookup] }
        # Fallbacks for known patterns
        if ($key -match 'autoApprove') {
            return "If true, allows Copilot or automation to run $key commands/scripts without manual approval."
        }
        if ($key -match 'Write-Host') {
            return "If true, allows scripts to use Write-Host for CLI output in automated runs."
        }
        if ($key -match 'executions.enabled') {
            return "Enables Copilot chat command execution features."
        }
        if ($key -match 'list') {
            return "If true, allows listing files without manual approval."
        }
        if ($key -match 'read') {
            return "If true, allows reading files without manual approval."
        }
        if ($key -match 'ErrorAction') {
            return "Controls the default PowerShell -ErrorAction for Copilot/automation commands."
        }
        # Generic fallback
        return "Auto-generated: Controls $key behavior."
    }

    # Parse settings.json for comments (if available)
    $settingsPath = Join-Path (Split-Path $PSScriptRoot -Parent) "..\..\..\.vscode\settings.json"
    $settingsComments = @{}
    if (Test-Path $settingsPath) {
        $lines = Get-Content $settingsPath -Raw | Select-String -Pattern "^\s*//" -AllMatches | ForEach-Object { $_.Line }
        foreach ($line in $lines) {
            # Example: // key: comment
            if ($line -match '^\s*//\s*([^:]+):\s*(.+)$') {
                $rawKey = $Matches[1]
                $comment = $Matches[2].Trim()
                $normKey = ($rawKey -replace '\s+', '').ToLowerInvariant()
                $settingsComments[$normKey] = $comment
            }
        }
    }

    $configOptionsContent = if ($Configs.Count -gt 0) {
        $tableHeader = "| Name | Type | Default | Description | Required | Source |`n|------|------|---------|-------------|----------|--------|"
        $tableRows = $Configs | ForEach-Object {
            $key = Sanitize-AppDocConfigMarkdownCell -Value $_.key -MaxLength 140
            $displayValue = Sanitize-AppDocConfigMarkdownCell -Value $_.value -MaxLength 80
            $type = Infer-AppDocConfigType $_.value
            $type = Sanitize-AppDocConfigMarkdownCell -Value $type -MaxLength 50
            $source = Sanitize-AppDocConfigMarkdownCell -Value $_.source -MaxLength 140
            $parent = $null
            if ($key -match '^(.*?)\.[^.]+$') { $parent = $Matches[1] }
            $description = Synthesize-AppDocConfigDescription $key $parent $settingsComments
            $required = if ($_.required) { "Yes" } else { "No" }
            "| $key | $type | $displayValue | $description | $required | $source |"
        }
        $tableHeader + "`n" + ($tableRows -join "`n")
    } else {
        $configTablePlaceholder
    }

    $envVarsContent = if ($EnvVars.Count -gt 0) {
        $tableHeader = "| Variable | Default | Description | Sensitive | Required |`n|----------|---------|-------------|-----------|----------|"
        $tableRows = $EnvVars | ForEach-Object {
            $envKey = Sanitize-AppDocConfigMarkdownCell -Value $_.key -MaxLength 120
            $displayValue = Sanitize-AppDocConfigMarkdownCell -Value $_.value -MaxLength 80
            $description = if ($_.description) { Sanitize-AppDocConfigMarkdownCell -Value $_.description -MaxLength 120 } else { "Environment variable" }
            $sensitivePattern = '(?i)\b(password|secret|key|token|credential|auth|apikey|api[_-]?key|private|cert|certificate|passwd|pwd|rsa|pem)\b'
            $sensitive = if ($envKey -match $sensitivePattern) { "Yes" } else { "No" }
            $required = if ($_.required) { "Yes" } else { "No" }
            "| $envKey | $displayValue | $description | $sensitive | $required |"
        }
        $tableHeader + "`n" + ($tableRows -join "`n")
    } else {
        $envTablePlaceholder
    }

    return [ordered]@{
        configSourcesContent = $configSourcesContent
        configOptionsContent = $configOptionsContent
        envVarsContent = $envVarsContent
        configTablePlaceholder = $configTablePlaceholder
        envTablePlaceholder = $envTablePlaceholder
        configSourcesPlaceholder = "No scoped configuration source files were detected in this scan. Verify repository scope and environment-specific config locations."
    }
}

function Update-AppDocConfigCatalogContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [array]$Configs,
        [Parameter(Mandatory=$true)]
        [array]$DiscoveredConfigFiles,
        [Parameter(Mandatory=$true)]
        [array]$EnvVars
    )

    $sections = Get-AppDocConfigCatalogMarkdown -Configs $Configs -DiscoveredConfigFiles $DiscoveredConfigFiles -EnvVars $EnvVars

    $updated = Update-AppDocLiteralTemplateSection -Content $Content -PlaceholderText $sections.configSourcesPlaceholder -NewContent $sections.configSourcesContent
    $updated = Update-AppDocLiteralTemplateSection -Content $updated -PlaceholderText $sections.configTablePlaceholder -NewContent $sections.configOptionsContent
    $updated = Update-AppDocLiteralTemplateSection -Content $updated -PlaceholderText $sections.envTablePlaceholder -NewContent $sections.envVarsContent

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Configuration Sources\s*\r?\n\r?\n).*?(?=\r?\n##\s+Configuration Options\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.configSourcesContent + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Configuration Options\s*\r?\n\r?\n).*?(?=\r?\n##\s+Environment Variables\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.configOptionsContent + "`r`n")
        }
    )
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Environment Variables\s*\r?\n\r?\n).*?(?=(\r?\n##\s+)|\z)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.envVarsContent + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Overview\s*\r?\n\r?\n).*?(?=\r?\n##\s+Configuration Sources\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "This catalog is assembled from Web.config/App.config, project files, and pipeline YAML to show where runtime and deployment behavior are controlled." + "`r`n")
        }
    )

    $sectionFallbacks = [ordered]@{
        'Configuration Validation' = 'This run extracted configuration keys and sources but not a full validation matrix. Treat required-key checks, value-shape checks, and environment overrides as mandatory pre-release validation tasks.'
        'Configuration Management' = 'Configuration is distributed across application config files, transforms, project metadata, and pipeline settings. Manage changes with environment-specific promotion controls and explicit review for sensitive settings.'
        'Security Considerations' = 'No direct security classification was inferred for each key in this pass. Treat connection strings, credentials, tokens, and endpoint URLs as sensitive-by-default and validate redaction before publishing artifacts.'
        'Example Configurations' = 'Environment-specific examples are not emitted automatically to avoid accidental secret leakage. Build examples from non-sensitive templates and validate with the required configuration criteria below.'
    }
    foreach ($header in $sectionFallbacks.Keys) {
        $sectionPattern = "(?s)(##\s+$([regex]::Escape($header))\s*\r?\n\r?\n).*?(?=(\r?\n##\s+)|\z)"
        $updated = [regex]::Replace(
            $updated,
            $sectionPattern,
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Groups[1].Value + [string]$sectionFallbacks[$header] + "`r`n")
            }
        )
    }

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocConfigCatalogTemplateContent',
    'Get-AppDocConfigCatalogMarkdown',
    'Update-AppDocConfigCatalogContent'
)
