# Unit tests for Get-AppDocValue, the single accessor for fields on hashtables and PSObjects.

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $modules = Join-Path (Join-Path (Join-Path (Join-Path $repoRoot '.appdoc') 'scripts') 'powershell') 'modules'
    Import-Module (Join-Path $modules 'AppDoc.Values.psm1') -Force
}

Describe 'Get-AppDocValue' {
    It 'reads a key from a hashtable' {
        Get-AppDocValue @{ a = 1 } 'a' | Should -Be 1
    }
    It 'reads a key from an ordered dictionary' {
        Get-AppDocValue ([ordered]@{ a = 'x' }) 'a' | Should -Be 'x'
    }
    It 'reads a property from a PSObject' {
        Get-AppDocValue ([pscustomobject]@{ a = 2 }) 'a' | Should -Be 2
    }
    It 'returns the default for a missing name' {
        Get-AppDocValue @{ a = 1 } 'b' 'fallback' | Should -Be 'fallback'
        Get-AppDocValue ([pscustomobject]@{ a = 1 }) 'b' 'fallback' | Should -Be 'fallback'
    }
    It 'returns null for a missing name when no default is given' {
        Get-AppDocValue @{ a = 1 } 'b' | Should -BeNullOrEmpty
    }
    It 'returns the default for a null object' {
        Get-AppDocValue $null 'a' 'fallback' | Should -Be 'fallback'
    }
    It 'keeps a present value that is null instead of using the default' {
        Get-AppDocValue @{ a = $null } 'a' 'fallback' | Should -BeNullOrEmpty
    }
    It 'matches hashtable keys case-sensitively unless -IgnoreCase is given' {
        $h = [ordered]@{ Name = 'v' }
        Get-AppDocValue $h 'name' 'none' | Should -Be 'v'   # ordered dictionaries compare ignoring case by default
        $strict = [System.Collections.Hashtable]::new([System.StringComparer]::Ordinal)
        $strict['Name'] = 'v'
        Get-AppDocValue $strict 'name' 'none' | Should -Be 'none'
        Get-AppDocValue $strict 'name' 'none' -IgnoreCase | Should -Be 'v'
    }
    It 'does not unroll an array value' {
        $r = Get-AppDocValue @{ a = @(1, 2, 3) } 'a'
        @($r).Count | Should -Be 3
    }
}
