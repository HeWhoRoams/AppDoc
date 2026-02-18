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

function Get-AppDocScopePolicy {
    [CmdletBinding()]
    param(
        [string]$RootPath
    )

    $cacheKey = if ([string]::IsNullOrWhiteSpace($RootPath)) { "__default__" } else { $RootPath.ToLowerInvariant() }
    if ($script:AppDocScopePolicyCache.ContainsKey($cacheKey)) {
        return $script:AppDocScopePolicyCache[$cacheKey]
    }

    $defaultPolicy = Get-AppDocDefaultScopePolicy
    $candidates = @()

    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        $candidates += (Join-Path $RootPath ".appdoc\policies\scope.v1.json")
    }

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
        [string]$Artifact = "default"
    )

    $defaults = $Policy.defaults
    $resolved = [ordered]@{
        includeDocs = [bool]$defaults.includeDocs
        includeAppDocTools = [bool]$defaults.includeAppDocTools
        includeFixtures = [bool]$defaults.includeFixtures
        includeTests = [bool]$defaults.includeTests
        excludePatterns = @($defaults.excludePatterns | ForEach-Object { [string]$_ })
    }

    $profileName = if ([string]::IsNullOrWhiteSpace($Artifact)) { "default" } else { $Artifact }
    $profileProp = $Policy.artifactProfiles.PSObject.Properties | Where-Object { $_.Name -eq $profileName } | Select-Object -First 1
    if (-not $profileProp) {
        $profileProp = $Policy.artifactProfiles.PSObject.Properties | Where-Object { $_.Name -eq "default" } | Select-Object -First 1
    }

    if ($profileProp) {
        $profile = $profileProp.Value
        foreach ($key in @("includeDocs", "includeAppDocTools", "includeFixtures", "includeTests")) {
            $prop = $profile.PSObject.Properties | Where-Object { $_.Name -eq $key } | Select-Object -First 1
            if ($prop) {
                $resolved[$key] = [bool]$prop.Value
            }
        }

        $profileExcludes = $profile.PSObject.Properties | Where-Object { $_.Name -eq "excludePatterns" } | Select-Object -First 1
        if ($profileExcludes -and $profileExcludes.Value) {
            $resolved.excludePatterns += @($profileExcludes.Value | ForEach-Object { [string]$_ })
        }
    }

    $resolved.excludePatterns = @($resolved.excludePatterns | Where-Object { $_ } | Select-Object -Unique)
    return $resolved
}

function Test-AppDocPathIncluded {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string]$RootPath,
        [string]$Artifact = "default",
        [switch]$IncludeDocs,
        [switch]$IncludeAppDocTools,
        [switch]$IncludeFixtures,
        [switch]$IncludeTests,
        [string[]]$AdditionalExcludePatterns = @()
    )

    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    $normalized = $Path -replace '/', '\\'

    $policy = Get-AppDocScopePolicy -RootPath $RootPath
    $scope = Resolve-AppDocScopeProfile -Policy $policy -Artifact $Artifact

    $useIncludeDocs = if ($PSBoundParameters.ContainsKey("IncludeDocs")) { [bool]$IncludeDocs.IsPresent } else { [bool]$scope.includeDocs }
    $useIncludeAppDocTools = if ($PSBoundParameters.ContainsKey("IncludeAppDocTools")) { [bool]$IncludeAppDocTools.IsPresent } else { [bool]$scope.includeAppDocTools }
    $useIncludeFixtures = if ($PSBoundParameters.ContainsKey("IncludeFixtures")) { [bool]$IncludeFixtures.IsPresent } else { [bool]$scope.includeFixtures }
    $useIncludeTests = if ($PSBoundParameters.ContainsKey("IncludeTests")) { [bool]$IncludeTests.IsPresent } else { [bool]$scope.includeTests }

    $excludedPatterns = @($scope.excludePatterns)

    if (-not $useIncludeDocs) {
        $excludedPatterns += '(?:^|\\)docs(?:\\|$)'
    }
    if (-not $useIncludeAppDocTools) {
        $excludedPatterns += '(?:^|\\)\.appdoc\\tools(?:\\|$)'
    }
    if (-not $useIncludeTests) {
        $excludedPatterns += @(
            '(?:^|\\)(?:test|tests|spec|specs)(?:\\|$)',
            '(?:^|\\)[^\\]*(?:\.Tests?|Tests?|Testing)(?:\\|$)',
            '(?:^|\\)__tests__(?:\\|$)',
            '(?:^|\\)__mocks__(?:\\|$)'
        )
    }
    else {
        $excludedPatterns = @($excludedPatterns | Where-Object {
            ([string]$_) -notmatch 'test\|tests\|spec\|specs' -and
            ([string]$_) -notmatch 'Tests\?\|Testing' -and
            ([string]$_) -notmatch '__tests__' -and
            ([string]$_) -notmatch '__mocks__'
        })
    }

    if (-not $useIncludeFixtures) {
        $excludedPatterns += @(
            '(?:^|\\)(?:fixture|fixtures)(?:\\|$)',
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
