#
# AppDoc.ClassicAsp.psm1
#
# Helpers shared by the generate-classic-asp-*.ps1 generators. Each of these used to be
# copied into several scripts, and the copies had started to drift (the extcalls copy of
# the source-file count ignored the fixtures/node_modules/... exclusions the others used).
#

Import-Module (Join-Path $PSScriptRoot 'AppDoc.Paths.psm1') -ErrorAction Stop
Import-Module (Join-Path $PSScriptRoot 'AppDoc.Scope.psm1') -ErrorAction Stop

# Directory exclusions used when counting classic-ASP source files. They mirror the
# framework detector. fixtures is excluded but test/tests is NOT: real classic-ASP sites
# often ship live test/ pages, so excluding tests would silently drop content.
$script:AppDocClassicAspPathExclusion = '(?i)([\\/](fixtures|node_modules|bin|obj|dist|build|__pycache__|\.venv|target)[\\/])'

function Test-AppDocClassicAspTarget {
    <#
    .SYNOPSIS
        True when framework-detection.json reports Classic ASP or ASP.NET Web Forms.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$RootPath)
    $fwPath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) 'framework-detection.json'
    if (-not (Test-Path -LiteralPath $fwPath)) { return $false }
    try { $fw = Get-Content -LiteralPath $fwPath -Raw | ConvertFrom-Json -Depth 10 } catch { return $false }
    $frameworks = @(@($fw) | ForEach-Object { [string]$_.framework } | Where-Object { $_ })
    return (($frameworks -contains 'Classic ASP') -or ($frameworks -contains 'ASP.NET Web Forms'))
}

function Get-AppDocClassicAspSourceFileCount {
    <#
    .SYNOPSIS
        Counts *.asp / *.inc source files (excluding tool/vendor folders and scratch copies).
        Used as the "does the classic-ASP layer own this artifact" signal.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$RootPath)
    $files = @(Get-ChildItem -Path $RootPath -Recurse -Include '*.asp', '*.inc' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch $script:AppDocClassicAspPathExclusion } |
        Where-Object { -not (Test-AppDocScratchFile -Path $_.Name) })
    return $files.Count
}

function Write-AppDocNotApplicablePlaceholder {
    <#
    .SYNOPSIS
        Writes the standard "not applicable for this framework" artifact. ExtraSections adds
        the empty required sections a given artifact's validator expects.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$OutputPath,
        [Parameter(Mandatory = $true)][string]$Title,
        # Words inserted before "signal", e.g. "classic-ASP external-call".
        [string]$Signal = 'classic-ASP',
        [System.Collections.Specialized.OrderedDictionary]$ExtraSections = $null
    )
    $dir = Split-Path $OutputPath -Parent
    if (-not (Test-Path -LiteralPath $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
    $lines = [System.Collections.Generic.List[string]]::new()
    $lines.Add("# $Title"); $lines.Add('')
    $lines.Add("**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"); $lines.Add('')
    $lines.Add('## Summary'); $lines.Add('')
    $lines.Add("Not applicable for this framework. This artifact is produced only for Classic ASP / ASP.NET Web Forms codebases; the detected framework has no matching $Signal signal, so no content was extracted.")
    $lines.Add('')
    if ($ExtraSections) {
        foreach ($k in $ExtraSections.Keys) { $lines.Add("## $k"); $lines.Add(''); $lines.Add([string]$ExtraSections[$k]); $lines.Add('') }
    }
    $lines.Add('---')
    ($lines -join "`n") | Out-File -FilePath $OutputPath -Encoding UTF8 -NoNewline
}

function Remove-SurroundingQuotes {
    <#
    .SYNOPSIS
        Strips matching outer quotes (repeatedly) and any dangling quote at either end.
    #>
    [CmdletBinding()]
    param([AllowNull()][AllowEmptyString()][string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return '' }
    $t = $Text.Trim()
    while ($t.Length -ge 2) {
        $first = $t.Substring(0, 1)
        $last = $t.Substring($t.Length - 1, 1)
        if (($first -eq '"' -and $last -eq '"') -or ($first -eq "'" -and $last -eq "'")) { $t = $t.Substring(1, $t.Length - 2) }
        else { break }
    }
    # Connection strings often end with a single quote that has no opening partner.
    while ($t.Length -gt 0 -and $t.Substring($t.Length - 1, 1) -in @('"', "'")) { $t = $t.Substring(0, $t.Length - 1) }
    while ($t.Length -gt 0 -and $t.Substring(0, 1) -in @('"', "'")) { $t = $t.Substring(1) }
    return $t.Trim()
}

Export-ModuleMember -Function @(
    'Test-AppDocClassicAspTarget',
    'Get-AppDocClassicAspSourceFileCount',
    'Write-AppDocNotApplicablePlaceholder',
    'Remove-SurroundingQuotes'
)
