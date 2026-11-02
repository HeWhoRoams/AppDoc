# Source-file selection and repo-relative paths (AppDoc.Scope).
Import-Module (Join-Path $PSScriptRoot 'AppDoc.Scope.psm1') -ErrorAction Stop
function Get-AppDocOverviewSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "overview" -Set source)
}

function Get-AppDocOverviewData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $codeFiles = @(Get-AppDocOverviewSourceFiles -RootPath $RootPath)
    $languageCount = @{}

    foreach ($file in $codeFiles) {
        $ext = [string]$file.Extension
        if (-not $languageCount.ContainsKey($ext)) {
            $languageCount[$ext] = 0
        }
        $languageCount[$ext]++
    }

    return [ordered]@{
        codeFiles = $codeFiles
        codeFileCount = $codeFiles.Count
        languageCount = $languageCount
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocOverviewData'
)
