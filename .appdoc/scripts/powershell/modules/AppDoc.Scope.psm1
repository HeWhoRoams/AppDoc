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

$script:AppDocScopeVersion = '1.2.0'
$script:AppDocScopePolicyCache = @{}
$script:AppDocGeneratedProxyPatterns = @(
    '(?i)(?:^|\\)(Service References|Connected Services|Web References)(?:\\|$)',
    '(?i)(?:^|\\)Reference\.cs$',
    '(?i)\.(svcmap|svcinfo|wsdl|disco)$'
)

function Get-AppDocDefaultScopePolicy {
    [CmdletBinding()]
    param()

    return [ordered]@{
        version = '1.0.0'
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
                '(?:^|\\)\.appdoc(?:\\|$)',
                '(?:^|\\)docuwriter(?:\\|$)',
                '(?:^|\\)docs?(?:\\|$)',
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
            'default' = [ordered]@{}
            'overview' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'start-here' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'api-inventory' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'data-model' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'config-catalog' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'test-catalog' = [ordered]@{ includeTests = $true; includeFixtures = $false }
            'build-cookbook' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'dependencies-catalog' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'debt-register' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'dependency-graph' = [ordered]@{ includeTests = $false; includeFixtures = $false }
        }
    }
}

function Get-AppDocScopePropertyValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Object,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }

        foreach ($key in @($Object.Keys)) {
            if ([string]::Equals([string]$key, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                return $Object[$key]
            }
        }

        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $Default
}

function Get-AppDocScopeBoolValue {
    [CmdletBinding()]
    param(
        [object]$Value,
        [bool]$Default = $false
    )

    if ($null -eq $Value) { return $Default }
    if ($Value -is [bool]) { return [bool]$Value }

    $text = ([string]$Value).Trim()
    if ([string]::IsNullOrWhiteSpace($text)) { return $Default }

    switch -Regex ($text.ToLowerInvariant()) {
        '^(1|true|yes|y|on)$' { return $true }
        '^(0|false|no|n|off)$' { return $false }
        default { return $Default }
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

    if ([string]::IsNullOrWhiteSpace($RootPath)) {
        $cacheKey = '__default__'
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
        $candidates += (Join-Path $RootPath '.appdoc\policies\scope.v1.json')
    }

    $moduleAppDocRoot = Split-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) -Parent
    if ($moduleAppDocRoot) {
        $candidates += (Join-Path $moduleAppDocRoot 'policies\scope.v1.json')
    }

    foreach ($candidate in @($candidates | Select-Object -Unique)) {
        if (-not (Test-Path $candidate)) { continue }
        try {
            $loaded = Get-Content $candidate -Raw | ConvertFrom-Json -Depth 30 -ErrorAction Stop
            if ($loaded -and (Get-AppDocScopePropertyValue -Object $loaded -Name 'defaults') -and (Get-AppDocScopePropertyValue -Object $loaded -Name 'artifactProfiles')) {
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

function Get-AppDocGeneratedProxyExcludePatterns {
    [CmdletBinding()]
    param()

    return @($script:AppDocGeneratedProxyPatterns)
}

function Test-AppDocGeneratedProxyPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string]$RootPath = ''
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $normalized = $Path -replace '/', '\'
    if ($RootPath) {
        try {
            $resolvedRoot = (Resolve-Path -Path $RootPath -ErrorAction Stop).Path
            $resolvedPath = (Resolve-Path -Path $Path -ErrorAction Stop).Path
            $normalized = [System.IO.Path]::GetRelativePath($resolvedRoot, $resolvedPath) -replace '/', '\'
        }
        catch {
            $rootNorm = $RootPath.TrimEnd([char[]]@(92, 47))
            $pathNorm = $Path.TrimEnd([char[]]@(92, 47))
            if ($pathNorm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
                $normalized = $pathNorm.Substring($rootNorm.Length).TrimStart([char[]]@(92, 47)) -replace '/', '\'
            }
        }
    }

    foreach ($pattern in $script:AppDocGeneratedProxyPatterns) {
        if ($normalized -match $pattern) {
            return $true
        }
    }

    return $false
}

function Resolve-AppDocScopeProfile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Policy,
        [string]$Artifact = 'default'
    )

    $defaults = Get-AppDocScopePropertyValue -Object $Policy -Name 'defaults' -Default @{}
    $profiles = Get-AppDocScopePropertyValue -Object $Policy -Name 'artifactProfiles' -Default @{}

    $profileName = if ([string]::IsNullOrWhiteSpace($Artifact)) { 'default' } else { $Artifact }
    $profile = Get-AppDocScopePropertyValue -Object $profiles -Name $profileName
    if ($null -eq $profile) {
        $profileName = 'default'
        $profile = Get-AppDocScopePropertyValue -Object $profiles -Name $profileName -Default @{}
    }

    $defaultPatterns = @(Get-AppDocScopePropertyValue -Object $defaults -Name 'excludePatterns' -Default @())
    $profilePatterns = @(Get-AppDocScopePropertyValue -Object $profile -Name 'excludePatterns' -Default @())

    return [ordered]@{
        artifact = $Artifact
        profileName = $profileName
        includeDocs = (Get-AppDocScopeBoolValue -Value (Get-AppDocScopePropertyValue -Object $profile -Name 'includeDocs' -Default (Get-AppDocScopePropertyValue -Object $defaults -Name 'includeDocs' -Default $false)))
        includeAppDocTools = (Get-AppDocScopeBoolValue -Value (Get-AppDocScopePropertyValue -Object $profile -Name 'includeAppDocTools' -Default (Get-AppDocScopePropertyValue -Object $defaults -Name 'includeAppDocTools' -Default $false)))
        includeFixtures = (Get-AppDocScopeBoolValue -Value (Get-AppDocScopePropertyValue -Object $profile -Name 'includeFixtures' -Default (Get-AppDocScopePropertyValue -Object $defaults -Name 'includeFixtures' -Default $false)))
        includeTests = (Get-AppDocScopeBoolValue -Value (Get-AppDocScopePropertyValue -Object $profile -Name 'includeTests' -Default (Get-AppDocScopePropertyValue -Object $defaults -Name 'includeTests' -Default $false)))
        excludePatterns = @($defaultPatterns + $profilePatterns | Where-Object { $_ } | Select-Object -Unique)
    }
}

function Get-AppDocScopeExclusionPatterns {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Profile,
        [switch]$IncludeDocs,
        [switch]$IncludeAppDocTools,
        [switch]$IncludeFixtures,
        [switch]$IncludeTests,
        [string[]]$AdditionalExcludePatterns = @()
    )

    $excludedPatterns = @(Get-AppDocScopePropertyValue -Object $Profile -Name 'excludePatterns' -Default @())

    $effectiveIncludeDocs = if ($PSBoundParameters.ContainsKey('IncludeDocs')) { [bool]$IncludeDocs } else { Get-AppDocScopeBoolValue -Value (Get-AppDocScopePropertyValue -Object $Profile -Name 'includeDocs' -Default $false) }
    $effectiveIncludeAppDocTools = if ($PSBoundParameters.ContainsKey('IncludeAppDocTools')) { [bool]$IncludeAppDocTools } else { Get-AppDocScopeBoolValue -Value (Get-AppDocScopePropertyValue -Object $Profile -Name 'includeAppDocTools' -Default $false) }
    $effectiveIncludeFixtures = if ($PSBoundParameters.ContainsKey('IncludeFixtures')) { [bool]$IncludeFixtures } else { Get-AppDocScopeBoolValue -Value (Get-AppDocScopePropertyValue -Object $Profile -Name 'includeFixtures' -Default $false) }
    $effectiveIncludeTests = if ($PSBoundParameters.ContainsKey('IncludeTests')) { [bool]$IncludeTests } else { Get-AppDocScopeBoolValue -Value (Get-AppDocScopePropertyValue -Object $Profile -Name 'includeTests' -Default $false) }

    if ($effectiveIncludeDocs) {
        $excludedPatterns = @($excludedPatterns | Where-Object { ([string]$_) -notmatch 'docs?' })
    }

    if ($effectiveIncludeAppDocTools) {
        $excludedPatterns = @($excludedPatterns | Where-Object {
            ([string]$_) -notmatch '(^|\\)\.appdoc' -and
            ([string]$_) -notmatch 'docuwriter' -and
            ([string]$_) -notmatch 'generated-doc'
        })
    }

    if ($effectiveIncludeTests) {
        $excludedPatterns = @($excludedPatterns | Where-Object {
            ([string]$_) -notmatch 'test\|tests\|spec\|specs' -and
            ([string]$_) -notmatch '\.Tests?\|Tests?\|Testing' -and
            ([string]$_) -notmatch '__tests__'
        })
    }

    if ($effectiveIncludeFixtures) {
        $excludedPatterns = @($excludedPatterns | Where-Object {
            ([string]$_) -notmatch 'fixture\|fixtures' -and
            ([string]$_) -notmatch 'sample\|samples\|example\|examples' -and
            ([string]$_) -notmatch 'mock\|mocks' -and
            ([string]$_) -notmatch 'tests\\powershell\\fixtures'
        })
    }

    if ($AdditionalExcludePatterns -and $AdditionalExcludePatterns.Count -gt 0) {
        $excludedPatterns += @($AdditionalExcludePatterns | Where-Object { $_ })
    }

    return @($excludedPatterns | Select-Object -Unique)
}

function Test-AppDocPathIncluded {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [string]$RootPath = '',
        [string]$Artifact = 'default',
        [switch]$IncludeDocs,
        [switch]$IncludeAppDocTools,
        [switch]$IncludeFixtures,
        [switch]$IncludeTests,
        [string[]]$AdditionalExcludePatterns = @()
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    $normalized = $Path -replace '/', '\'
    if ($RootPath) {
        try {
            $resolvedRoot = (Resolve-Path -Path $RootPath -ErrorAction Stop).Path
            $resolvedPath = (Resolve-Path -Path $Path -ErrorAction Stop).Path
            $relative = [System.IO.Path]::GetRelativePath($resolvedRoot, $resolvedPath)
            $normalized = $relative -replace '/', '\'
        }
        catch {
            $rootNorm = $RootPath.TrimEnd([char[]]@(92, 47))
            $pathNorm = $Path.TrimEnd([char[]]@(92, 47))
            if ($pathNorm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
                $normalized = $pathNorm.Substring($rootNorm.Length).TrimStart([char[]]@(92, 47)) -replace '/', '\'
            }
        }
    }

    $policy = Get-AppDocScopePolicy -RootPath $RootPath
    $profile = Resolve-AppDocScopeProfile -Policy $policy -Artifact $Artifact
    $excludedPatterns = Get-AppDocScopeExclusionPatterns -Profile $profile -AdditionalExcludePatterns $AdditionalExcludePatterns -IncludeDocs:$IncludeDocs -IncludeAppDocTools:$IncludeAppDocTools -IncludeFixtures:$IncludeFixtures -IncludeTests:$IncludeTests

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
        [string]$Artifact = 'default',
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

            if ($PSBoundParameters.ContainsKey('IncludeDocs')) { $pathFilterArgs.IncludeDocs = [bool]$IncludeDocs }
            if ($PSBoundParameters.ContainsKey('IncludeAppDocTools')) { $pathFilterArgs.IncludeAppDocTools = [bool]$IncludeAppDocTools }
            if ($PSBoundParameters.ContainsKey('IncludeFixtures')) { $pathFilterArgs.IncludeFixtures = [bool]$IncludeFixtures }
            if ($PSBoundParameters.ContainsKey('IncludeTests')) { $pathFilterArgs.IncludeTests = [bool]$IncludeTests }

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
        return $Path.Replace($RootPath, '').TrimStart([char[]]@(92, 47))
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocDefaultScopePolicy',
    'Clear-AppDocScopePolicyCache',
    'Get-AppDocScopePolicy',
    'Get-AppDocGeneratedProxyExcludePatterns',
    'Test-AppDocGeneratedProxyPath',
    'Resolve-AppDocScopeProfile',
    'Get-AppDocScopeExclusionPatterns',
    'Test-AppDocPathIncluded',
    'Get-AppDocSourceFiles',
    'Get-AppDocRelativePath'
)
