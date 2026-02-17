# AppDoc.Profiles Module
# Purpose: Load documentation profiles and optional plugins

$script:AppDocProfilesVersion = "1.0.0"

function Get-AppDocProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [string]$Profile = "default"
    )

    $profileDir = Join-Path (Join-Path $RootPath ".appdoc") "profiles"
    $profilePath = if ([System.IO.Path]::IsPathRooted($Profile)) { 
        $Profile 
    } else { 
        Join-Path $profileDir ("{0}.json" -f $Profile) 
    }

    if (Test-Path $profilePath) {
        try {
            return (Get-Content $profilePath -Raw | ConvertFrom-Json)
        }
        catch {
            Write-Warning "Failed to parse profile file: $profilePath"
        }
    }

    return [pscustomobject]@{
        profile = "default"
        sections = @("overview", "api-inventory", "data-model", "config-catalog", "build-cookbook", "test-catalog", "debt-register", "dependencies-catalog")
        api_grouping = "by-controller"
        include_examples = $true
        diagram_types = @("architecture")
        enhancement_mode = "optional"
    }
}

function Get-AppDocPlugins {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $pluginDir = Join-Path (Join-Path $RootPath ".appdoc") "plugins"
    if (-not (Test-Path $pluginDir)) {
        return @()
    }

    $pluginFiles = Get-ChildItem -Path (Join-Path $pluginDir '*') -File -ErrorAction SilentlyContinue | Where-Object { $_.Extension -in '.ps1', '.psm1' }
    return @($pluginFiles | Select-Object -ExpandProperty FullName)
}

function Invoke-PluginHook {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Hook,
        [hashtable]$Context = @{}
    )

    $plugins = Get-AppDocPlugins -RootPath $RootPath
    foreach ($plugin in $plugins) {
        try {
            if ($plugin -like "*.psm1") {
                Import-Module $plugin -Force -ErrorAction Stop
            }
            else {
                . $plugin
            }

            # Check for plugin-specific hook function (distinct from this module's function)
            $hookFunction = "Invoke-AppDocPlugin"
            if (Get-Command $hookFunction -ErrorAction SilentlyContinue) {
                & $hookFunction -Hook $Hook -Context $Context | Out-Null
            }
        }
        catch {
            Write-Warning "Plugin hook failed for ${plugin}: $($_.Exception.Message)"
        }
    }
}

# Alias for backward compatibility
New-Alias -Name "Invoke-AppDocPluginHook" -Value "Invoke-PluginHook" -Scope Script

Export-ModuleMember -Function @(
    'Get-AppDocProfile',
    'Get-AppDocPlugins',
    'Invoke-PluginHook'
)
