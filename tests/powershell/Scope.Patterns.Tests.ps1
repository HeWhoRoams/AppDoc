# File-name patterns live in the scope policy (patternSets), not in each extractor.

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:repoRoot = $repoRoot
    $modules = Join-Path (Join-Path (Join-Path (Join-Path $repoRoot '.appdoc') 'scripts') 'powershell') 'modules'
    Import-Module (Join-Path $modules 'AppDoc.Scope.psm1') -Force
    $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ('appdoc-scope-' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $script:work -Force | Out-Null
}

AfterAll {
    if ($script:work -and (Test-Path $script:work)) { Remove-Item $script:work -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Get-AppDocScopePatterns' {
    It 'reads a set from the repo policy' {
        @(Get-AppDocScopePatterns -RootPath $script:repoRoot -Artifact 'debt-register' -Set 'source') | Should -Contain '*.cs'
    }
    It 'falls back to the built-in set when the target has no policy file' {
        @(Get-AppDocScopePatterns -RootPath $script:work -Artifact 'dependency-graph' -Set 'source') | Should -Contain '*.tsx'
    }
    It 'falls back when a repo-local policy predates pattern sets' {
        $policyDir = Join-Path (Join-Path $script:work '.appdoc') 'policies'
        New-Item -ItemType Directory -Path $policyDir -Force | Out-Null
        '{"version":"1.0.0","defaults":{"excludePatterns":[]},"artifactProfiles":{"debt-register":{}}}' | Set-Content (Join-Path $policyDir 'scope.v1.json')
        Clear-AppDocScopePolicyCache
        @(Get-AppDocScopePatterns -RootPath $script:work -Artifact 'debt-register' -Set 'source') | Should -Contain '*.java'
        Remove-Item (Join-Path $script:work '.appdoc') -Recurse -Force
        Clear-AppDocScopePolicyCache
    }
    It 'throws for an unknown set' {
        { Get-AppDocScopePatterns -RootPath $script:work -Artifact 'debt-register' -Set 'nope' } | Should -Throw
    }
}

Describe 'Get-AppDocSourceFiles -Set' {
    It 'returns the same files as the equivalent -Include list' {
        New-Item -ItemType Directory -Path (Join-Path $script:work 'src') -Force | Out-Null
        'x' | Set-Content (Join-Path (Join-Path $script:work 'src') 'a.cs')
        'x' | Set-Content (Join-Path (Join-Path $script:work 'src') 'b.txt')
        $bySet = @(Get-AppDocSourceFiles -RootPath $script:work -Artifact 'debt-register' -Set 'source')
        $byInclude = @(Get-AppDocSourceFiles -RootPath $script:work -Artifact 'debt-register' -Include @('*.js','*.ts','*.cs','*.py','*.java'))
        $bySet.Name | Should -Be $byInclude.Name
        $bySet.Name | Should -Contain 'a.cs'
        $bySet.Name | Should -Not -Contain 'b.txt'
    }
    It 'applies the exclusion policy to every artifact that has a source set' -ForEach @(
        @{ Artifact = 'overview' }, @{ Artifact = 'start-here' }, @{ Artifact = 'api-inventory' },
        @{ Artifact = 'debt-register' }, @{ Artifact = 'dependency-graph' }, @{ Artifact = 'external-call' }
    ) {
        $dir = Join-Path $script:work 'node_modules'
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
        'x' | Set-Content (Join-Path $dir 'skipped.js')
        $names = @(Get-AppDocSourceFiles -RootPath $script:work -Artifact $Artifact -Set 'source').Name
        $names | Should -Not -Contain 'skipped.js'
    }
}
