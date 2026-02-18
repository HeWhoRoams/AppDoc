function Get-AppDocOverviewSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "overview" -Include @("*.cs","*.js","*.ts","*.py","*.java"))
    }

    return @(Get-ChildItem -Path "$RootPath\*" -Recurse -File -Include @("*.cs","*.js","*.ts","*.py","*.java") -ErrorAction SilentlyContinue)
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
