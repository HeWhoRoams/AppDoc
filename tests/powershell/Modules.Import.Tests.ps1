# Regression test (S-06 / F-12): every module imports without warnings (no unapproved verbs)
# and the deprecated names still resolve through aliases until 1.2.0.

BeforeDiscovery {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:moduleCases = @(Get-ChildItem (Join-Path (Join-Path (Join-Path (Join-Path $repoRoot '.appdoc') 'scripts') 'powershell') 'modules') -Filter '*.psm1' |
        ForEach-Object { @{ Name = $_.Name; Path = $_.FullName } })
}

Describe 'Module import' {
    It '<Name> imports without warnings' -ForEach $script:moduleCases {
        $w = $null
        Import-Module $Path -Force -WarningVariable w -WarningAction SilentlyContinue -ErrorAction Stop
        @($w) | Should -BeNullOrEmpty
    }
}

Describe 'Deprecated aliases' {
    BeforeAll {
        $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
        $mods = Join-Path (Join-Path (Join-Path (Join-Path $repoRoot '.appdoc') 'scripts') 'powershell') 'modules'
        Import-Module (Join-Path $mods 'AppDoc.Epistemic.psm1') -Force -WarningAction SilentlyContinue
        Import-Module (Join-Path $mods 'AppDoc.SemanticRedaction.psm1') -Force -WarningAction SilentlyContinue
    }
    It 'Tag-Claim resolves to Add-AppDocClaimTag' { (Get-Alias Tag-Claim).Definition | Should -Be 'Add-AppDocClaimTag' }
    It 'Redact-AppDocSemanticString resolves to Protect-AppDocSemanticString' { (Get-Alias Redact-AppDocSemanticString).Definition | Should -Be 'Protect-AppDocSemanticString' }
}
