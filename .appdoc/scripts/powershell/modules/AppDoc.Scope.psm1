# Output folder resolution (config outputDir).
Import-Module (Join-Path $PSScriptRoot 'AppDoc.Paths.psm1') -ErrorAction Stop
# Shared object accessor (Get-AppDocValue).
Import-Module (Join-Path $PSScriptRoot 'AppDoc.Values.psm1') -ErrorAction Stop

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

# Scratch / backup copies of source files (by file NAME): *_copy*, copy_*, *_old*, *_test*,
# testing*, *bak*. Classic-ASP sites accumulate these next to live pages; they are not the
# application. Single definition shared by the generators and the composer.
$script:AppDocScratchFileNamePattern = '(?i).*_copy.*|.*copy_.*|.*_old.*|.*_test.*|^testing.*|.*bak.*'
function Test-AppDocScratchFile {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][AllowEmptyString()][string]$Path)
    $name = [System.IO.Path]::GetFileName($Path)
    return ($name -match $script:AppDocScratchFileNamePattern)
}

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
                '(?:^|\\)(?:mock|mocks)(?:\\|$)'
            )
        }
        artifactProfiles = [ordered]@{
            'default' = [ordered]@{}
            'overview' = [ordered]@{ includeTests = $false; includeFixtures = $false; patternSets = [ordered]@{ 'source' = @('*.cs','*.js','*.ts','*.py','*.java') } }
            'start-here' = [ordered]@{ includeTests = $false; includeFixtures = $false; patternSets = [ordered]@{ 'source' = @('*.cs','*.js','*.ts','*.py','*.java') } }
            'api-inventory' = [ordered]@{ includeTests = $false; includeFixtures = $false; patternSets = [ordered]@{ 'source' = @('*.js','*.ts','*.cs','*.py','*.java','*.svc','*.asmx') } }
            'data-model' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'config-catalog' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'test-catalog' = [ordered]@{ includeTests = $true; includeFixtures = $false; patternSets = [ordered]@{ 'source' = @('*.test.js','*.test.ts','*.spec.js','*.spec.ts','*Test.cs','*Tests.cs','test_*.py','*_test.py'); 'signalSource' = @('*.cs','*.ts','*.js','*.py','*.java','*.go','*.feature'); 'signalProjects' = @('*.csproj','*.vbproj','*.fsproj') } }
            'build-cookbook' = [ordered]@{ includeTests = $false; includeFixtures = $false }
            'dependencies-catalog' = [ordered]@{ includeTests = $false; includeFixtures = $false; patternSets = [ordered]@{ 'signals' = @('*.csproj','*.vbproj','packages.config','package.json','pom.xml','build.gradle','build.gradle.kts','requirements.txt','Pipfile','poetry.lock','*.nuspec') } }
            'debt-register' = [ordered]@{ includeTests = $false; includeFixtures = $false; patternSets = [ordered]@{ 'source' = @('*.js','*.ts','*.cs','*.py','*.java') } }
            'dependency-graph' = [ordered]@{ includeTests = $false; includeFixtures = $false; patternSets = [ordered]@{ 'source' = @('*.js','*.ts','*.jsx','*.tsx') } }
            'external-call' = [ordered]@{ includeTests = $false; includeFixtures = $false; patternSets = [ordered]@{ 'source' = @('*.ts','*.js','*.cs','*.py','*.java') } }
        }
    }
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
    $script:AppDocScopeFilterCache.Clear()
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
            if ($loaded -and (Get-AppDocValue -IgnoreCase -Object $loaded -Name 'defaults') -and (Get-AppDocValue -IgnoreCase -Object $loaded -Name 'artifactProfiles')) {
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

    $defaults = Get-AppDocValue -IgnoreCase -Object $Policy -Name 'defaults' -Default @{}
    $profiles = Get-AppDocValue -IgnoreCase -Object $Policy -Name 'artifactProfiles' -Default @{}

    $profileName = if ([string]::IsNullOrWhiteSpace($Artifact)) { 'default' } else { $Artifact }
    $profile = Get-AppDocValue -IgnoreCase -Object $profiles -Name $profileName
    if ($null -eq $profile) {
        $profileName = 'default'
        $profile = Get-AppDocValue -IgnoreCase -Object $profiles -Name $profileName -Default @{}
    }

    $defaultPatterns = @(Get-AppDocValue -IgnoreCase -Object $defaults -Name 'excludePatterns' -Default @())
    $profilePatterns = @(Get-AppDocValue -IgnoreCase -Object $profile -Name 'excludePatterns' -Default @())

    return [ordered]@{
        artifact = $Artifact
        profileName = $profileName
        includeDocs = (Get-AppDocScopeBoolValue -Value (Get-AppDocValue -IgnoreCase -Object $profile -Name 'includeDocs' -Default (Get-AppDocValue -IgnoreCase -Object $defaults -Name 'includeDocs' -Default $false)))
        includeAppDocTools = (Get-AppDocScopeBoolValue -Value (Get-AppDocValue -IgnoreCase -Object $profile -Name 'includeAppDocTools' -Default (Get-AppDocValue -IgnoreCase -Object $defaults -Name 'includeAppDocTools' -Default $false)))
        includeFixtures = (Get-AppDocScopeBoolValue -Value (Get-AppDocValue -IgnoreCase -Object $profile -Name 'includeFixtures' -Default (Get-AppDocValue -IgnoreCase -Object $defaults -Name 'includeFixtures' -Default $false)))
        includeTests = (Get-AppDocScopeBoolValue -Value (Get-AppDocValue -IgnoreCase -Object $profile -Name 'includeTests' -Default (Get-AppDocValue -IgnoreCase -Object $defaults -Name 'includeTests' -Default $false)))
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

    $excludedPatterns = @(Get-AppDocValue -IgnoreCase -Object $Profile -Name 'excludePatterns' -Default @())

    $effectiveIncludeDocs = if ($PSBoundParameters.ContainsKey('IncludeDocs')) { [bool]$IncludeDocs } else { Get-AppDocScopeBoolValue -Value (Get-AppDocValue -IgnoreCase -Object $Profile -Name 'includeDocs' -Default $false) }
    $effectiveIncludeAppDocTools = if ($PSBoundParameters.ContainsKey('IncludeAppDocTools')) { [bool]$IncludeAppDocTools } else { Get-AppDocScopeBoolValue -Value (Get-AppDocValue -IgnoreCase -Object $Profile -Name 'includeAppDocTools' -Default $false) }
    $effectiveIncludeFixtures = if ($PSBoundParameters.ContainsKey('IncludeFixtures')) { [bool]$IncludeFixtures } else { Get-AppDocScopeBoolValue -Value (Get-AppDocValue -IgnoreCase -Object $Profile -Name 'includeFixtures' -Default $false) }
    $effectiveIncludeTests = if ($PSBoundParameters.ContainsKey('IncludeTests')) { [bool]$IncludeTests } else { Get-AppDocScopeBoolValue -Value (Get-AppDocValue -IgnoreCase -Object $Profile -Name 'includeTests' -Default $false) }

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

$script:AppDocScopeFilterCache = @{}

function New-AppDocScopeFilter {
    # Everything Test-AppDocPathIncluded needs, built once: the full root, the output folder,
    # one compiled regex over every exclusion pattern (All) and one over the folder-only
    # patterns (Dir). A folder pattern is one that ends in (?:\\|$) with no lookaround: if it
    # matches a folder path it also matches every file below it, so the walk can skip the
    # whole folder without changing the result.
    [CmdletBinding()]
    param(
        [string]$RootPath = '',
        [string]$Artifact = 'default',
        [switch]$IncludeDocs,
        [switch]$IncludeAppDocTools,
        [switch]$IncludeFixtures,
        [switch]$IncludeTests,
        [string[]]$AdditionalExcludePatterns = @()
    )

    $key = '{0}|{1}|{2}{3}{4}{5}|{6}' -f $RootPath, $Artifact, [int][bool]$IncludeDocs, [int][bool]$IncludeAppDocTools, [int][bool]$IncludeFixtures, [int][bool]$IncludeTests, ($AdditionalExcludePatterns -join "`n")
    if ($script:AppDocScopeFilterCache.ContainsKey($key)) { return $script:AppDocScopeFilterCache[$key] }

    $policy = Get-AppDocScopePolicy -RootPath $RootPath
    $profile = Resolve-AppDocScopeProfile -Policy $policy -Artifact $Artifact
    $excludeArgs = @{ Profile = $profile; AdditionalExcludePatterns = $AdditionalExcludePatterns }
    if ($PSBoundParameters.ContainsKey('IncludeDocs')) { $excludeArgs.IncludeDocs = $IncludeDocs }
    if ($PSBoundParameters.ContainsKey('IncludeAppDocTools')) { $excludeArgs.IncludeAppDocTools = $IncludeAppDocTools }
    if ($PSBoundParameters.ContainsKey('IncludeFixtures')) { $excludeArgs.IncludeFixtures = $IncludeFixtures }
    if ($PSBoundParameters.ContainsKey('IncludeTests')) { $excludeArgs.IncludeTests = $IncludeTests }
    $patterns = @(Get-AppDocScopeExclusionPatterns @excludeArgs)

    # PowerShell's -match is case-insensitive, so the compiled regexes are too.
    $options = [System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant
    $timeout = [timespan]::FromSeconds(5)
    $dirPatterns = @($patterns | Where-Object { ([string]$_).EndsWith('(?:\\|$)') -and ([string]$_) -notmatch '\(\?[=!<]' })
    $filter = [pscustomobject]@{
        Root   = if ($RootPath) { [System.IO.Path]::GetFullPath($RootPath) } else { '' }
        OutDir = ''
        All    = if ($patterns.Count) { [regex]::new((($patterns | ForEach-Object { "(?:$_)" }) -join '|'), $options, $timeout) } else { $null }
        Dir    = if ($dirPatterns.Count) { [regex]::new((($dirPatterns | ForEach-Object { "(?:$_)" }) -join '|'), $options, $timeout) } else { $null }
    }
    # AppDoc's own output folder (config outputDir; default docs) is never target source.
    if ($RootPath -and -not $IncludeDocs) {
        $filter.OutDir = ((Get-AppDocDocsDirName -RootPath $RootPath) -replace '/', '\').Trim('\')
    }
    $script:AppDocScopeFilterCache[$key] = $filter
    return $filter
}

function Test-AppDocScopeRelativePath {
    # $Relative uses backslashes. Returns $true when the path is in scope.
    param([Parameter(Mandatory=$true)]$Filter, [Parameter(Mandatory=$true)][string]$Relative)
    if ($Filter.OutDir) {
        $norm = $Relative.TrimStart('\')
        if ($norm -eq $Filter.OutDir -or $norm.StartsWith($Filter.OutDir + '\', [System.StringComparison]::OrdinalIgnoreCase)) { return $false }
    }
    if ($Filter.All -and $Filter.All.IsMatch($Relative)) { return $false }
    return $true
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

    $filterArgs = @{ RootPath = $RootPath; Artifact = $Artifact; AdditionalExcludePatterns = $AdditionalExcludePatterns }
    if ($PSBoundParameters.ContainsKey('IncludeDocs')) { $filterArgs.IncludeDocs = $IncludeDocs }
    if ($PSBoundParameters.ContainsKey('IncludeAppDocTools')) { $filterArgs.IncludeAppDocTools = $IncludeAppDocTools }
    if ($PSBoundParameters.ContainsKey('IncludeFixtures')) { $filterArgs.IncludeFixtures = $IncludeFixtures }
    if ($PSBoundParameters.ContainsKey('IncludeTests')) { $filterArgs.IncludeTests = $IncludeTests }
    $filter = New-AppDocScopeFilter @filterArgs

    $normalized = $Path -replace '/', '\'
    if ($RootPath) {
        try {
            $normalized = [System.IO.Path]::GetRelativePath($filter.Root, [System.IO.Path]::GetFullPath($Path)) -replace '/', '\'
        }
        catch {
            $rootNorm = $RootPath.TrimEnd([char[]]@(92, 47))
            $pathNorm = $Path.TrimEnd([char[]]@(92, 47))
            if ($pathNorm.StartsWith($rootNorm, [System.StringComparison]::OrdinalIgnoreCase)) {
                $normalized = $pathNorm.Substring($rootNorm.Length).TrimStart([char[]]@(92, 47)) -replace '/', '\'
            }
        }
    }

    return (Test-AppDocScopeRelativePath -Filter $filter -Relative $normalized)
}

function Get-AppDocScopePatterns {
    # File-name patterns for one named set of an artifact (for example debt-register / source),
    # read from the scope policy. A repo-local policy written before pattern sets existed falls
    # back to the built-in set, so an older .appdoc/policies/scope.v1.json keeps working.
    [CmdletBinding()]
    param(
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Artifact,
        [Parameter(Mandatory=$true)]
        [string]$Set
    )

    $policies = @((Get-AppDocScopePolicy -RootPath $RootPath), (Get-AppDocDefaultScopePolicy))
    foreach ($policy in $policies) {
        $profiles = Get-AppDocValue -IgnoreCase -Object $policy -Name 'artifactProfiles' -Default @{}
        $profile = Get-AppDocValue -IgnoreCase -Object $profiles -Name $Artifact
        $sets = Get-AppDocValue -IgnoreCase -Object $profile -Name 'patternSets'
        $patterns = @(Get-AppDocValue -IgnoreCase -Object $sets -Name $Set -Default @())
        if ($patterns.Count -gt 0) { return $patterns }
    }
    throw "Scope policy has no pattern set '$Set' for artifact '$Artifact'."
}

function Get-AppDocSourceFiles {
    [CmdletBinding(DefaultParameterSetName='Include')]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true, ParameterSetName='Include')]
        [string[]]$Include,
        # Named pattern set from the scope policy (see Get-AppDocScopePatterns), instead of -Include.
        [Parameter(Mandatory=$true, ParameterSetName='Set')]
        [string]$Set,
        [string]$Artifact = 'default',
        [switch]$IncludeDocs,
        [switch]$IncludeAppDocTools,
        [switch]$IncludeFixtures,
        [switch]$IncludeTests,
        [string[]]$AdditionalExcludePatterns = @()
    )

    if ($PSCmdlet.ParameterSetName -eq 'Set') { $Include = @(Get-AppDocScopePatterns -RootPath $RootPath -Artifact $Artifact -Set $Set) }

    $filterArgs = @{ RootPath = $RootPath; Artifact = $Artifact; AdditionalExcludePatterns = $AdditionalExcludePatterns }
    foreach ($name in 'IncludeDocs', 'IncludeAppDocTools', 'IncludeFixtures', 'IncludeTests') {
        if ($PSBoundParameters.ContainsKey($name)) { $filterArgs[$name] = [bool]$PSBoundParameters[$name] }
    }
    $filter = New-AppDocScopeFilter @filterArgs
    $root = $filter.Root
    if (-not [System.IO.Directory]::Exists($root)) { return @() }

    # One walk: folders that an exclusion pattern covers are never entered (a 'node_modules'
    # folder is skipped, not listed and then filtered file by file). Hidden entries are skipped
    # (the .NET default), as Get-ChildItem does without -Force.
    $options = [System.IO.EnumerationOptions]::new()
    $wildcards = @($Include | ForEach-Object { [System.Management.Automation.WildcardPattern]::new($_, [System.Management.Automation.WildcardOptions]::IgnoreCase) })
    $all = $filter.All
    $outDir = $filter.OutDir
    $found = [System.Collections.Generic.List[System.IO.FileInfo]]::new()
    $stack = [System.Collections.Generic.Stack[System.IO.DirectoryInfo]]::new()
    $stack.Push([System.IO.DirectoryInfo]::new($root))
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        foreach ($sub in $dir.EnumerateDirectories('*', $options)) {
            if ($sub.Attributes -band [System.IO.FileAttributes]::ReparsePoint) { continue }
            $rel = [System.IO.Path]::GetRelativePath($root, $sub.FullName) -replace '/', '\'
            if ($filter.OutDir -and ($rel -eq $filter.OutDir -or $rel.StartsWith($filter.OutDir + '\', [System.StringComparison]::OrdinalIgnoreCase))) { continue }
            if ($filter.Dir -and $filter.Dir.IsMatch($rel)) { continue }
            $stack.Push($sub)
        }
        foreach ($file in $dir.EnumerateFiles('*', $options)) {
            $name = $file.Name
            $wanted = $false
            foreach ($wildcard in $wildcards) { if ($wildcard.IsMatch($name)) { $wanted = $true; break } }
            if (-not $wanted) { continue }
            # Same test as Test-AppDocScopeRelativePath, inlined: this runs once per file.
            $rel = [System.IO.Path]::GetRelativePath($root, $file.FullName) -replace '/', '\'
            if ($outDir -and $rel.StartsWith($outDir + '\', [System.StringComparison]::OrdinalIgnoreCase)) { continue }
            if ($all -and $all.IsMatch($rel)) { continue }
            $found.Add($file)
        }
    }

    # Ordinal order, so the result does not depend on the file system's listing order.
    $sorted = $found.ToArray()
    $keys = [string[]]::new($sorted.Length)
    for ($i = 0; $i -lt $sorted.Length; $i++) { $keys[$i] = $sorted[$i].FullName }
    [System.Array]::Sort([System.Array]$keys, [System.Array]$sorted, [System.StringComparer]::Ordinal)
    return $sorted
}

function Get-AppDocRelativePath {
    # Repo-relative path with forward slashes. Single implementation:
    # ConvertTo-AppDocRelativePath (AppDoc.Determinism); paths outside the root are
    # reported as "<external>/<leaf>" so no host path leaks into the output.
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    if (-not (Get-Command ConvertTo-AppDocRelativePath -ErrorAction SilentlyContinue)) {
        Import-Module (Join-Path $PSScriptRoot 'AppDoc.Determinism.psm1') -ErrorAction Stop
    }
    $p = $Path
    if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $RootPath $p }
    return (ConvertTo-AppDocRelativePath -Path $p -RootPath $RootPath)
}

Export-ModuleMember -Function @(
    'Test-AppDocScratchFile',
    'Get-AppDocDefaultScopePolicy',
    'Clear-AppDocScopePolicyCache',
    'Get-AppDocScopePolicy',
    'Get-AppDocGeneratedProxyExcludePatterns',
    'Test-AppDocGeneratedProxyPath',
    'Resolve-AppDocScopeProfile',
    'Get-AppDocScopeExclusionPatterns',
    'Test-AppDocPathIncluded',
    'Get-AppDocSourceFiles',
    'Get-AppDocScopePatterns',
    'Get-AppDocRelativePath'
)
