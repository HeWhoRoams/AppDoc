# Regression tests (Phase 3 / P-02, P-16): operator redaction.
#   redactionPatterns = exact VALUES (matched literally); redactionRegexes = regexes.
#   An invalid regex stops the build (exit 3). The semantic gate scans raw strings, so a
#   secret containing a quote or a backslash cannot slip past JSON escaping.

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $ps = Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell'
    $script:build = Join-Path $ps 'run-appdoc-build.ps1'
    $script:pwsh  = (Get-Process -Id $PID).Path
    $script:tmp   = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-redact-{0}" -f [guid]::NewGuid().ToString('n'))
    $fixture      = Join-Path (Join-Path (Join-Path $script:repoRoot 'tests') 'fixtures') 'python-flask-sample'
    New-Item -ItemType Directory -Force -Path $script:tmp | Out-Null

    Import-Module (Join-Path (Join-Path $ps 'modules') 'AppDoc.SecretPolicy.psm1') -Force
    Import-Module (Join-Path (Join-Path $ps 'modules') 'AppDoc.SemanticRedaction.psm1') -Force -WarningAction SilentlyContinue

    function New-Target {
        param([string]$Name, [hashtable]$Config)
        $t = Join-Path $script:tmp $Name
        Copy-Item -Path $fixture -Destination $t -Recurse
        $cfgDir = Join-Path $t '.appdoc'
        New-Item -ItemType Directory -Force -Path $cfgDir | Out-Null
        $Config | ConvertTo-Json -Depth 5 | Set-Content -Path (Join-Path $cfgDir 'config.json') -Encoding utf8
        return $t
    }
    function Get-DocsText {
        param([string]$Target)
        (Get-ChildItem (Join-Path $Target 'docs') -Recurse -File -Include '*.md', '*.html', '*.json' | ForEach-Object { Get-Content -LiteralPath $_.FullName -Raw }) -join "`n"
    }

    # The flask fixture's .env has DB_HOST=tickets.internal and
    # SUPPORT_API_URL=https://support.internal/itsm/api; both appear in the built docs.
    $script:redacted = New-Target -Name 'redacted' -Config @{
        redactionPatterns = @('support.internal/itsm')
        redactionRegexes  = @('tickets\.[a-z]+')
    }
    & $script:pwsh -NoProfile -File $script:build -Path $script:redacted -SkipDiagrams *> $null
    $script:redactedExit = $LASTEXITCODE
    $script:redactedText = Get-DocsText -Target $script:redacted

    $script:badRegex = New-Target -Name 'badregex' -Config @{ redactionRegexes = @('([unclosed') }
    & $script:pwsh -NoProfile -File $script:build -Path $script:badRegex -SkipDiagrams *> $null
    $script:badRegexExit = $LASTEXITCODE

    $script:badJson = Join-Path $script:tmp 'badjson'
    Copy-Item -Path $fixture -Destination $script:badJson -Recurse
    New-Item -ItemType Directory -Force -Path (Join-Path $script:badJson '.appdoc') | Out-Null
    '{ "redactionPatterns": [ "x", }' | Set-Content -Path (Join-Path (Join-Path $script:badJson '.appdoc') 'config.json') -Encoding utf8
    & $script:pwsh -NoProfile -File $script:build -Path $script:badJson -SkipDiagrams *> $null
    $script:badJsonExit = $LASTEXITCODE
}

AfterAll {
    if ($script:tmp -and (Test-Path $script:tmp)) { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Operator redaction in the build' {
    It 'builds successfully with operator patterns' { $script:redactedExit | Should -Be 0 }
    It 'redacts a redactionPatterns value literally' {
        $script:redactedText | Should -Not -Match ([regex]::Escape('support.internal/itsm'))
    }
    It 'redacts every match of a redactionRegexes entry' {
        $script:redactedText | Should -Not -Match ([regex]::Escape('tickets.internal'))
    }
    It 'stops fail-closed (exit 3) on an invalid regex' { $script:badRegexExit | Should -Be 3 }
    It 'stops (exit 1) when config.json exists but is not valid JSON' { $script:badJsonExit | Should -Be 1 }
}

Describe 'Shared secret policy' {
    It 'matches redactionPatterns literally (regex metacharacters are not interpreted)' {
        $m = Get-AppDocOperatorRedactionMatchers -Literals @('a.c')
        Invoke-AppDocOperatorRedaction -Text 'abc a.c' -Matchers $m | Should -Be 'abc [REDACTED]'
    }
    It 'throws on an invalid regex' {
        { Get-AppDocOperatorRedactionMatchers -Regexes @('([x') } | Should -Throw '*invalid regular expression*'
    }
}

Describe 'Semantic redaction gate scans raw strings' {
    It 'blocks a secret that contains a quote and a backslash' {
        $secret = 'p@ss"wo\rd'
        $envelope = @{ records = @(@{ name = 'x'; metadata = @{ value = $secret } }) }
        (Test-AppDocSemanticRedactionGate -Envelope $envelope -ExtraKnownSecrets @($secret)).blocked | Should -BeTrue
    }
    It 'blocks on an operator regex match' {
        (Test-AppDocSemanticRedactionGate -Envelope @{ a = 'token-ABC-123' } -ExtraRedactionRegexes @('token-[A-Z]{3}-\d+')).blocked | Should -BeTrue
    }
    It 'does not report the secret value in its hits' {
        $secret = 'SYNTH-SECRET-42'
        $r = Test-AppDocSemanticRedactionGate -Envelope @{ a = $secret } -ExtraKnownSecrets @($secret)
        ($r.hits | ConvertTo-Json -Depth 5) | Should -Not -Match $secret
    }
    It 'passes a clean envelope' {
        (Test-AppDocSemanticRedactionGate -Envelope @{ a = 'nothing here' } -ExtraKnownSecrets @('zzz')).blocked | Should -BeFalse
    }
}
