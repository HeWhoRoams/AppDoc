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

    $profileDir = Join-Path $RootPath ".appdoc\profiles"
    $profilePath = if (Test-Path $Profile) { $Profile } else { Join-Path $profileDir ("{0}.json" -f $Profile) }

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

    $pluginDir = Join-Path $RootPath ".appdoc\plugins"
    if (-not (Test-Path $pluginDir)) {
        return @()
    }

    $pluginFiles = Get-ChildItem -Path $pluginDir -File -Include "*.ps1", "*.psm1" -ErrorAction SilentlyContinue
    return @($pluginFiles | Select-Object -ExpandProperty FullName)
}

function Invoke-AppDocPluginHook {
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

            if (Get-Command "Invoke-AppDocPluginHook" -ErrorAction SilentlyContinue) {
                Invoke-AppDocPluginHook -Hook $Hook -Context $Context | Out-Null
            }
        }
        catch {
            Write-Warning "Plugin hook failed for ${plugin}: $($_.Exception.Message)"
        }
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocProfile',
    'Get-AppDocPlugins',
    'Invoke-AppDocPluginHook'
)
