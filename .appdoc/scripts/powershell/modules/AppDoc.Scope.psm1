# Cross-version Windows OS detection
if ($null -eq $script:IsWindowsOS) {
    $script:IsWindowsOS = $false
    if ($PSVersionTable -and $PSVersionTable.PSEdition -eq 'Desktop') {
        $script:IsWindowsOS = $true
    } elseif ($PSVersionTable -and $PSVersionTable.Platform -eq 'Win32NT') {
        $script:IsWindowsOS = $true
    } elseif ($env:OS -match 'Windows_NT') {
        $script:IsWindowsOS = $true
    } elseif ($IsWindows) {
        $script:IsWindowsOS = $true
    }
}
# AppDoc.Scope Module
# Purpose: Centralized source scoping and exclusion policy for deterministic extraction.

$script:AppDocScopeVersion = "1.2.0"
$script:AppDocScopePolicyCache = @{}

function Get-AppDocDefaultScopePolicy {
    [CmdletBinding()]
    param()

    return [ordered]@{
        version = "1.0.0"
        defaults = [ordered]@{
            includeDocs = $false
            includeAppDocTools = $false
            includeFixtures = $false
            includeTests = $false
            excludePatterns = @(
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
                '(?:^|\\)generated-doc(?:\\|$)',
                '(?:^|\\)(?:test|tests|spec|specs)(?:\\|$)',
                '(?:^|\\)[^\\]*(?:\.Tests?|Tests?|Testing)(?:\\|$)',
                '(?:^|\\)__tests__(?:\\|$)',
                '(?:^|\\)__mocks__(?:\\|$)',
                '(?:^|\\)(?:fixture|fixtures)(?:\\|$)',
                '(?:^|\\)(?:mock|mocks)(?:\\|$)',
                '(?:^|\\)(?:sample|samples|example|examples)(?:\\|$)'
            )
        }
        artifactProfiles = [ordered]@{
            "default" = [ordered]@{}
            "overview" = [ordered]@{
                includeTests = $false
                includeFixtures = $false
            }
            "start-here" = [ordered]@{
                includeTests = $false
                includeFixtures = $false
            }
            "api-inventory" = [ordered]@{
                includeTests = $false
                includeFixtures = $false
            }
            "data-model" = [ordered]@{
                includeTests = $false
                includeFixtures = $false
            }
            "config-catalog" = [ordered]@{
                includeTests = $false
                includeFixtures = $false
            }
            "test-catalog" = [ordered]@{
                includeTests = $true
                includeFixtures = $false
            }
            "build-cookbook" = [ordered]@{
                includeTests = $false
                includeFixtures = $false
            }
            "dependencies-catalog" = [ordered]@{
                includeTests = $false
                includeFixtures = $false
            }
            "debt-register" = [ordered]@{
                includeTests = $false
                includeFixtures = $false
            }
            "dependency-graph" = [ordered]@{
                includeTests = $false
                includeFixtures = $false
            }
        }
    }
}


# Clears the module-level AppDocScopePolicyCache so policies can be refreshed
function Clear-AppDocScopePolicyCache {
    [CmdletBinding()]
    param()
    $script:AppDocScopePolicyCache.Clear()
}

function Get-AppDocScopePolicy {
    [CmdletBinding()]
    param(
        [string]$RootPath,
        [switch]$Force
    )

    # Use canonical absolute path for cache key to avoid collisions on case-sensitive systems
    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $cacheKey = "__default__"
    } else {
        try {
            $resolvedPath = (Resolve-Path -Path $RootPath -ErrorAction Stop).Path
        } catch {
            try {
                $resolvedPath = (Get-Item -Path $RootPath -ErrorAction Stop).FullName
            } catch {
                $resolvedPath = $RootPath
            }
        }
        if ($script:IsWindowsOS) {
            $cacheKey = $resolvedPath.ToLowerInvariant()
        } else {
            $cacheKey = $resolvedPath
        }
    }
    if (-not $Force -and $script:AppDocScopePolicyCache.ContainsKey($cacheKey)) {
        return $script:AppDocScopePolicyCache[$cacheKey]
    }

    $defaultPolicy = Get-AppDocDefaultScopePolicy
    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        $candidates += (Join-Path $RootPath ".appdoc\policies\scope.v1.json")
    }

    # NOTE: The following triple Split-Path assumes the module is located at:
    #   <repo-root>/.appdoc/scripts/powershell/modules/AppDoc.Scope.psm1
    # and is intended to resolve <repo-root> as the repository/module root.
    # If the directory layout changes, this logic may need to be updated.
    $moduleAppDocRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    if ($moduleAppDocRoot) {
        $candidates += (Join-Path $moduleAppDocRoot "policies\scope.v1.json")
    }

    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (-not (Test-Path $candidate)) { continue }
        try {
            $loaded = Get-Content $candidate -Raw | ConvertFrom-Json -Depth 30
            if ($loaded -and $loaded.defaults -and $loaded.artifactProfiles) {
                $script:AppDocScopePolicyCache[$cacheKey] = $loaded
                return $loaded
            }
        }
        catch {
            Write-Verbose "Unable to parse scope policy '$candidate': $($_.Exception.Message)"
        }
    }

    $script:AppDocScopePolicyCache[$cacheKey] = $defaultPolicy
    return $defaultPolicy
}

function Resolve-AppDocScopeProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Policy,
        Export-ModuleMember -Function @(
            'Get-AppDocScopePolicy',
            'Clear-AppDocScopePolicyCache',
            'Resolve-AppDocScopeProfile',
            'Get-AppDocDefaultScopePolicy',
            'Get-AppDocScopeExclusionPatterns',
            'Get-AppDocScopeArtifactProfiles',
            'Get-AppDocScopeArtifactProfile',
            'Get-AppDocScopeArtifactProfileName',
            'Get-AppDocScopeArtifactProfileKeys',
            'Get-AppDocScopeArtifactProfileDefaults',
            'Get-AppDocScopeArtifactProfileEffective',
            'Get-AppDocScopeArtifactProfileEffectiveKeys',
            'Get-AppDocScopeArtifactProfileEffectiveDefaults',
            'Get-AppDocScopeArtifactProfileEffectiveExclusions',
            'Get-AppDocScopeArtifactProfileEffectiveInclusions',
            'Get-AppDocScopeArtifactProfileEffectivePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveTestPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveFixturePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveDocPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsExclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsInclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsDefaults',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsKeys',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffective',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveKeys',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveDefaults',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveExclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveInclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectivePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveTestPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveFixturePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveDocPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsExclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsInclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsDefaults',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsKeys',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffective',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveKeys',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveDefaults',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveExclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveInclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectivePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveTestPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveFixturePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveDocPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsExclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsInclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsDefaults',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsKeys',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffective',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveKeys',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveDefaults',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveExclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveInclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectivePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveTestPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveFixturePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveDocPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsExclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsInclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsDefaults',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsKeys',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffective',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveKeys',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveDefaults',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveExclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveInclusions',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectivePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveTestPatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveFixturePatterns',
            'Get-AppDocScopeArtifactProfileEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveAppDocToolsEffectiveDocPatterns'
        )
            '(?:^|\\)(?:sample|samples|example|examples)(?:\\|$)',
            '(?:^|\\)(?:mock|mocks)(?:\\|$)',
            '(?:^|\\)tests\\powershell\\fixtures(?:\\|$)'
        )
    }
    else {
        $excludedPatterns = @($excludedPatterns | Where-Object {
            ([string]$_) -notmatch 'fixture\|fixtures' -and
            ([string]$_) -notmatch 'sample\|samples\|example\|examples' -and
            ([string]$_) -notmatch 'mock\|mocks' -and
            ([string]$_) -notmatch 'tests\\\\powershell\\\\fixtures'
        })
    }

    if ($AdditionalExcludePatterns -and $AdditionalExcludePatterns.Count -gt 0) {
        $excludedPatterns += @($AdditionalExcludePatterns | Where-Object { $_ })
    }

    foreach ($pattern in @($excludedPatterns | Select-Object -Unique)) {
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
        [string]$Artifact = "default",
        [switch]$IncludeDocs,
        [switch]$IncludeAppDocTools,
        [switch]$IncludeFixtures,
        [switch]$IncludeTests,
        [string[]]$AdditionalExcludePatterns = @()
    )

    $files = Get-ChildItem -Path "$RootPath\*" -Recurse -File -Include $Include -ErrorAction SilentlyContinue

    return @(
        $files | Where-Object {
            $pathFilterArgs = @{
                Path = $_.FullName
                RootPath = $RootPath
                Artifact = $Artifact
                AdditionalExcludePatterns = $AdditionalExcludePatterns
            }

            if ($PSBoundParameters.ContainsKey("IncludeDocs")) { $pathFilterArgs.IncludeDocs = [bool]$IncludeDocs }
            if ($PSBoundParameters.ContainsKey("IncludeAppDocTools")) { $pathFilterArgs.IncludeAppDocTools = [bool]$IncludeAppDocTools }
            if ($PSBoundParameters.ContainsKey("IncludeFixtures")) { $pathFilterArgs.IncludeFixtures = [bool]$IncludeFixtures }
            if ($PSBoundParameters.ContainsKey("IncludeTests")) { $pathFilterArgs.IncludeTests = [bool]$IncludeTests }

            Test-AppDocPathIncluded @pathFilterArgs
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

    try {
        $rootFull = (Resolve-Path $RootPath).Path
        $pathFull = (Resolve-Path $Path).Path
        return [System.IO.Path]::GetRelativePath($rootFull, $pathFull).Replace('\', '/')
    }
    catch {
        return $Path.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocScopePolicy',
    'Test-AppDocPathIncluded',
    'Get-AppDocSourceFiles',
    'Get-AppDocRelativePath'
)
