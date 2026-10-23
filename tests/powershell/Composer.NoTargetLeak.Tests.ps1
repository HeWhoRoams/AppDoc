# Regression tests (Phase 2 / S-01): the composer carries no knowledge of any specific
# target. Target-specific narrative comes only from the target itself (source, its own
# docs, or an operator overlay rendered as Operator-supplied).

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:build = Join-Path (Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell') 'run-appdoc-build.ps1'
    $script:pwsh  = (Get-Process -Id $PID).Path
    $script:tmp   = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-leak-{0}" -f [guid]::NewGuid().ToString('n'))
    $fixture      = Join-Path (Join-Path (Join-Path $script:repoRoot 'tests') 'fixtures') 'classic-asp-sample'
    New-Item -ItemType Directory -Force -Path $script:tmp | Out-Null

    # (1) plain fixture
    $script:plain = Join-Path $script:tmp 'plain'
    Copy-Item -Path $fixture -Destination $script:plain -Recurse
    & $script:pwsh -NoProfile -File $script:build -Path $script:plain -SkipDiagrams *> $null
    $script:plainDoc = Get-Content (Join-Path (Join-Path $script:plain 'docs') 'application-documentation.md') -Raw

    # (2) fixture + an authorization signal in source + operator overlays
    $script:rich = Join-Path $script:tmp 'rich'
    Copy-Item -Path $fixture -Destination $script:rich -Recurse
    @(
        '<%'
        'Session("IsAdmin") = 1'
        'If Session("IsAdmin") = 1 Then'
        '    Call AccessControl_CheckAccess(Session("CurrentUser"), "admin")'
        'End If'
        '%>'
    ) | Set-Content -Path (Join-Path $script:rich 'admin-gate.asp') -Encoding utf8
    $overlays = Join-Path (Join-Path $script:rich '.appdoc') 'overlays'
    New-Item -ItemType Directory -Force -Path $overlays | Out-Null
    @(
        '# Ticket triage'
        'Analysts triage new tickets within one business day (OVERLAY-MARKER-7F3A).'
    ) | Set-Content -Path (Join-Path $overlays 'operational-workflows.md') -Encoding utf8
    & $script:pwsh -NoProfile -File $script:build -Path $script:rich -SkipDiagrams *> $null
    $script:richDoc = Get-Content (Join-Path (Join-Path $script:rich 'docs') 'application-documentation.md') -Raw
    $script:richEvidence = Get-Content (Join-Path (Join-Path $script:rich 'docs') 'application-documentation.evidence.json') -Raw | ConvertFrom-Json -Depth 20

    function Get-Section {
        param([string]$Doc, [string]$Title)
        $m = [regex]::Match($Doc, '(?ms)^##\s+' + [regex]::Escape($Title) + '\s*$(.*?)(?=^##\s+|\z)')
        return $m.Groups[1].Value
    }
}

AfterAll {
    if ($script:tmp -and (Test-Path $script:tmp)) { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Composer carries no target-specific knowledge' {
    It 'contains no terms from any real target' {
        $script:plainDoc | Should -Not -Match '(?i)helpweb|frontcounter|hdemp|hdgid|peregrine|bradford|resnet|talisma|bomgar|CALLE0A|\bSSN\b|AlwaysAdmin'
    }
    It 'uses the generic "Operational Workflows" section' {
        $script:plainDoc | Should -Match '(?m)^## Operational Workflows\s*$'
        $script:plainDoc | Should -Not -Match '(?m)^## Help Desk Workflows'
    }
    It 'does not infer a business purpose' {
        $script:plainDoc | Should -Match '\| Purpose \| Not established from source'
    }
    It 'does not mention an opaque-token convention unless one is configured' {
        $script:plainDoc | Should -Not -Match '@@'
    }
}

Describe 'Grounded authorization signals and operator overlays' {
    It 'lists a session authorization flag found in source with its file:line' {
        (Get-Section -Doc $script:richDoc -Title 'Roles and Access Model') | Should -Match '\| IsAdmin \|.*admin-gate\.asp:\d+.*\| Verified \|'
    }
    It 'lists an access-check routine found in source' {
        (Get-Section -Doc $script:richDoc -Title 'Roles and Access Model') | Should -Match 'AccessControl_CheckAccess'
    }
    It 'renders the overlay inside its section, marked Operator-supplied' {
        $sec = Get-Section -Doc $script:richDoc -Title 'Operational Workflows'
        $sec | Should -Match 'Operator-supplied context'
        $sec | Should -Match 'OVERLAY-MARKER-7F3A'
        $sec | Should -Match 'Operator-supplied'
    }
    It 'demotes overlay headings so they cannot break the section spine' {
        $script:richDoc | Should -Not -Match '(?m)^# Ticket triage'
        $script:richDoc | Should -Match '(?m)^##### Ticket triage'
    }
    It 'records the overlay in the section evidence' {
        @($script:richEvidence.overlays | Where-Object { $_.section -eq 'Operational Workflows' }).Count | Should -Be 1
    }
}
