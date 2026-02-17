# AppDoc.Scope Module
# Purpose: Centralized source scoping and exclusion policy for deterministic extraction.

$script:AppDocScopeVersion = "1.0.0"

function Test-AppDocPathIncluded {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [switch]$IncludeDocs,
        [switch]$IncludeAppDocTools,
        [switch]$IncludeFixtures
    )

    $normalized = $Path -replace '/', '\\'

    $excludedPatterns = @(
        '(?:^|\\)\.git(?:\\|$)',
        '(?:^|\\)node_modules(?:\\|$)',
        '(?:^|\\)bower_components(?:\\|$)',
        '(?:^|\\)bin(?:\\|$)',
        '(?:^|\\)obj(?:\\|$)',
        '(?:^|\\)target(?:\\|$)',
        '(?:^|\\)build(?:\\|$)',
        '(?:^|\\)dist(?:\\|$)',
        '(?:^|\\)__pycache__(?:\\|$)',
        '(?:^|\\)\.venv(?:\\|$)',
        '(?:^|\\)\.tox(?:\\|$)',
        '(?:^|\\)docuwriter(?:\\|$)',
        '(?:^|\\)generated-doc(?:\\|$)'
    )

    if (-not $IncludeDocs) {
        $excludedPatterns += '(?:^|\\)docs(?:\\|$)'
    }

    if (-not $IncludeAppDocTools) {
        $excludedPatterns += '(?:^|\\)\.appdoc\\tools(?:\\|$)'
    }

    if (-not $IncludeFixtures) {
        $excludedPatterns += '(?:^|\\)tests\\powershell\\fixtures(?:\\|$)'
    }

    foreach ($pattern in $excludedPatterns) {
        if ($normalized -match $pattern) {
            return $false
        }
    }

    return $true
}

function Get-AppDocSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string[]]$Include,
        [switch]$IncludeDocs,
        [switch]$IncludeAppDocTools,
        [switch]$IncludeFixtures
    )

    $files = Get-ChildItem -Path $RootPath -Recurse -File -Include $Include -ErrorAction SilentlyContinue

    return @(
        $files | Where-Object {
            Test-AppDocPathIncluded -Path $_.FullName -IncludeDocs:$IncludeDocs -IncludeAppDocTools:$IncludeAppDocTools -IncludeFixtures:$IncludeFixtures
        }
    )
}

function Get-AppDocRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    return $Path.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
}

Export-ModuleMember -Function @(
    'Test-AppDocPathIncluded',
    'Get-AppDocSourceFiles',
    'Get-AppDocRelativePath'
)
