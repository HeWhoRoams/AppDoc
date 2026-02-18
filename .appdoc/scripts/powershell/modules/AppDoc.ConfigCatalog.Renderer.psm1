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
        "_No configuration sources detected. System may use hardcoded values or external configuration service._"
    }

    $configOptionsContent = if ($Configs.Count -gt 0) {
        $tableHeader = "| Name | Type | Default | Description | Required | Source |`n|------|------|---------|-------------|----------|--------|"
        $tableRows = $Configs | ForEach-Object {
            $key = Sanitize-AppDocConfigMarkdownCell -Value $_.key -MaxLength 140
            $displayValue = Sanitize-AppDocConfigMarkdownCell -Value $_.value -MaxLength 80
            $type = Sanitize-AppDocConfigMarkdownCell -Value $_.type -MaxLength 50
            $source = Sanitize-AppDocConfigMarkdownCell -Value $_.source -MaxLength 140
            $description = if ($key -match '\w+\.\w+') { "Nested configuration option" } else { "Configuration setting" }
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
            $sensitive = if ($envKey -imatch "password|secret|key|token") { "Yes" } else { "No" }
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
        configSourcesPlaceholder = "_No configuration sources detected. System may use hardcoded values or external configuration service._"
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
    if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.configTablePlaceholder -NewContent $sections.configOptionsContent
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.envTablePlaceholder -NewContent $sections.envVarsContent
    }
    else {
        $updated = Update-AppDocLiteralTemplateSection -Content $updated -PlaceholderText $sections.configTablePlaceholder -NewContent $sections.configOptionsContent
        $updated = Update-AppDocLiteralTemplateSection -Content $updated -PlaceholderText $sections.envTablePlaceholder -NewContent $sections.envVarsContent
    }

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
        '(?s)(##\s+Environment Variables\s*\r?\n\r?\n).*?(?=\r?\n##\s+Configuration Validation\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.envVarsContent + "`r`n")
        }
    )

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocConfigCatalogTemplateContent',
    'Get-AppDocConfigCatalogMarkdown',
    'Update-AppDocConfigCatalogContent'
)
