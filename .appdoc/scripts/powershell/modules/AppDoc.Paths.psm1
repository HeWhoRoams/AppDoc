#
# AppDoc.Paths.psm1
#
# Where AppDoc writes its output for a target. Default: <target>/docs. A target can change
# the folder name with `outputDir` in <target>/.appdoc/config.json (a single folder name
# or a relative path inside the target; it can never point outside the target).
#
# Every script and module resolves the output folder through Get-AppDocDocsPath, so the
# setting is honoured whether the build runs end to end or a single generator is run on
# its own. The scope policy also excludes the configured folder from source scanning.
#

$script:AppDocDocsDirCache = @{}

function Get-AppDocDocsDirName {
    <#
    .SYNOPSIS
        Returns the output folder (relative to the target root, forward slashes), e.g. "docs".
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$RootPath)

    $key = $RootPath
    if ($script:AppDocDocsDirCache.ContainsKey($key)) { return $script:AppDocDocsDirCache[$key] }

    $name = 'docs'
    $cfgPath = Join-Path (Join-Path $RootPath '.appdoc') 'config.json'
    if (Test-Path -LiteralPath $cfgPath -PathType Leaf) {
        try {
            $raw = Get-Content -LiteralPath $cfgPath -Raw | ConvertFrom-Json -Depth 10
            if ($raw.PSObject.Properties['outputDir'] -and -not [string]::IsNullOrWhiteSpace([string]$raw.outputDir)) {
                $candidate = ([string]$raw.outputDir).Trim() -replace '\\', '/'
                $candidate = $candidate.TrimEnd('/')
                # Must stay inside the target: no rooted path, no drive, no "..".
                if ([System.IO.Path]::IsPathRooted($candidate) -or $candidate -match '(^|/)\.\.(/|$)' -or $candidate -match ':' -or $candidate -eq '' -or $candidate -eq '.') {
                    Write-Warning "[Config] outputDir '$($raw.outputDir)' must be a folder inside the target; using 'docs'."
                }
                else {
                    $name = $candidate
                }
            }
        }
        catch {
            # An unreadable config is reported (and stops the build) by AppDoc.Config; here we
            # only need a folder name, so fall back to the default.
            $name = 'docs'
        }
    }
    $script:AppDocDocsDirCache[$key] = $name
    return $name
}

function Get-AppDocDocsPath {
    <#
    .SYNOPSIS
        Returns the absolute output folder for a target, e.g. <target>/docs.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$RootPath)
    $rel = Get-AppDocDocsDirName -RootPath $RootPath
    $path = $RootPath
    foreach ($seg in ($rel -split '/')) { if ($seg) { $path = Join-Path $path $seg } }
    return $path
}

function Clear-AppDocDocsPathCache {
    [CmdletBinding()]
    param()
    $script:AppDocDocsDirCache = @{}
}

Export-ModuleMember -Function @('Get-AppDocDocsDirName', 'Get-AppDocDocsPath', 'Clear-AppDocDocsPathCache')
