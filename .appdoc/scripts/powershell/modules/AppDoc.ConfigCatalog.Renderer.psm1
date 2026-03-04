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
            "- **$($_.Name)**: $($_.Count) files"
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
            return "Display-only command allowlist entry; not required for security-critical automation."
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
        $isToolingConfig = {
            param($cfg)
            $src = [string]($cfg.source ?? "")
            $key = [string]($cfg.key ?? "")
            return (
                $src -match '(?i)(\.vscode|tasks\.json|launch\.json|workflow|github|pipeline|ci|editorconfig|copilot)' -or
                $key -match '(?i)(chat\.tools|copilot|pipeline|workflow|build|test)'
            )
        }

        $maskValue = {
            param($key, $value)
            $k = [string]($key ?? "")
            $v = [string]($value ?? "")
            if ($k -match '(?i)\b(password|secret|token|credential|key|apikey|private|certificate|cert|passwd|pwd)\b') {
                return "***masked***"
            }
            return (Sanitize-AppDocConfigMarkdownCell -Value $v -MaxLength 80)
        }

        $renderRows = {
            param([array]$rows)
            foreach ($item in $rows) {
                $key = Sanitize-AppDocConfigMarkdownCell -Value $item.key -MaxLength 120
                $displayValue = & $maskValue $item.key $item.value
                $type = Sanitize-AppDocConfigMarkdownCell -Value (Infer-AppDocConfigType $item.value) -MaxLength 40
                $source = Sanitize-AppDocConfigMarkdownCell -Value $item.source -MaxLength 120
                $parent = $null
                if ($key -match '^(.*?)\.[^.]+$') { $parent = $Matches[1] }
                $description = Synthesize-AppDocConfigDescription $key $parent $settingsComments
                $required = if ($item.required) { "Yes" } else { "No" }
                $whereUsed = if ($source -match '(?i)appsettings|web\.config|app\.config|\.env') { "Runtime path" } else { "Tooling/workflow" }
                $environmentReq = if ($source -match '(?i)\.env|appsettings\.[^.]+\.json|transform') { "Environment-specific" } else { "Shared default" }
                "| $key | $type | $displayValue | $description | $required | $whereUsed | $environmentReq | $source |"
            }
        }

        $runtimeConfigs = @($Configs | Where-Object { -not (& $isToolingConfig $_) })
        $toolingConfigs = @($Configs | Where-Object { (& $isToolingConfig $_) })

        $tableHeader = "| Name | Type | Default | Description | Required | Where Used | Environment Requirement | Source |`n|------|------|---------|-------------|----------|------------|--------------------------|--------|"
        $runtimeRows = @(& $renderRows $runtimeConfigs)
        $toolingRows = @(& $renderRows $toolingConfigs)

        @(
            "### Runtime Configuration (Priority)",
            "",
            $(if ($runtimeRows.Count -gt 0) { $tableHeader + "`n" + ($runtimeRows -join "`n") } else { "No runtime configuration entries detected." }),
            "",
            "### Tooling and Workflow Configuration",
            "",
            $(if ($toolingRows.Count -gt 0) { $tableHeader + "`n" + ($toolingRows -join "`n") } else { "No tooling/workflow configuration entries detected." }),
            "",
            "Masking policy: secret-like keys are masked in defaults to reduce accidental leakage."
        ) -join "`n"
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
        'Security Considerations' = 'Trust model: auto-approve entries execute with local user privileges and should only target trusted scripts under validated repository paths. This workflow enforces repository scope filtering but does not provide cryptographic file-integrity attestation; protect repos and runners accordingly. Restrict auto-approve patterns to least privilege, avoid broad wildcards, and keep display-only commands such as Write-Host non-required from a security perspective.'
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

    $requiredCriteriaContent = @"
Use least-privilege auto-approve rules for trusted automation paths only:

- `chat.tools.terminal.autoApprove.**/generate-assessment-report.ps1`
- `chat.tools.terminal.autoApprove.**/synthesize-assessment-report.ps1`

Do not treat `chat.tools.terminal.autoApprove.Write-Host` as a required security control. `Write-Host` is a display/UI command and should remain optional.
"@
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Required configuration criteria\s*\r?\n\r?\n).*?(?=(\r?\n##\s+)|\z)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $requiredCriteriaContent + "`r`n")
        }
    )

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocConfigCatalogTemplateContent',
    'Get-AppDocConfigCatalogMarkdown',
    'Update-AppDocConfigCatalogContent'
)
