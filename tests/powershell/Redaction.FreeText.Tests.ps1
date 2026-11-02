# Free-text redaction: vendor secret shapes and `key = value` for credential key names.

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $modules = Join-Path (Join-Path (Join-Path (Join-Path $repoRoot '.appdoc') 'scripts') 'powershell') 'modules'
    Import-Module (Join-Path $modules 'AppDoc.SecretPolicy.psm1') -Force
}

Describe 'Protect-AppDocFreeText' {
    It 'redacts <Name>' -ForEach @(
        @{ Name = 'an AWS access key id';  Text = 'rotate AKIAIOSFODNN7EXAMPLE now';                         Secret = 'AKIAIOSFODNN7EXAMPLE' }
        @{ Name = 'a GitHub token';        Text = 'token ghp_abcdefghijklmnopqrstuvwxyz0123456789 ci';       Secret = 'ghp_abcdefghijklmnopqrstuvwxyz0123456789' }
        @{ Name = 'a Slack token';         Text = 'xoxb-1234567890-abcdefghij';                              Secret = 'xoxb-1234567890-abcdefghij' }
        @{ Name = 'a named password';      Text = 'password = "hunter2hunter2xyz" is hardcoded';             Secret = 'hunter2hunter2xyz' }
        @{ Name = 'a bearer token';        Text = 'Authorization: Bearer abcdefghijklmnopqrstuvwxyz123';     Secret = 'abcdefghijklmnopqrstuvwxyz123' }
        @{ Name = 'a private key block';   Text = "-----BEGIN RSA PRIVATE KEY-----`nMIIabc`n-----END RSA PRIVATE KEY-----"; Secret = 'MIIabc' }
    ) {
        $out = Protect-AppDocFreeText -Text $Text
        $out | Should -Not -Match ([regex]::Escape($Secret))
        $out | Should -Match '\[REDACTED\]'
    }
    It 'keeps the key name of a named credential' {
        Protect-AppDocFreeText -Text 'password = "hunter2hunter2xyz"' | Should -Be 'password = "[REDACTED]"'
    }
    It 'leaves <Text> unchanged' -ForEach @(
        @{ Text = 'src/token/TokenService.cs' }, @{ Text = 'api_key_name' }, @{ Text = 'AKIA alone' },
        @{ Text = 'Token handling: see the auth guide' }, @{ Text = 'plain comment text' }
    ) {
        Protect-AppDocFreeText -Text $Text | Should -Be $Text
    }
    It 'is idempotent' {
        $once = Protect-AppDocFreeText -Text 'password = "hunter2hunter2xyz" AKIAIOSFODNN7EXAMPLE'
        Protect-AppDocFreeText -Text $once | Should -Be $once
    }
    It 'Test-AppDocVendorSecret is false after redaction' {
        Test-AppDocVendorSecret -Text 'AKIAIOSFODNN7EXAMPLE' | Should -BeTrue
        Test-AppDocVendorSecret -Text (Protect-AppDocFreeText -Text 'AKIAIOSFODNN7EXAMPLE') | Should -BeFalse
    }
}
