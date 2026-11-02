# Regression test (ADR 0003): run-appdoc-build.ps1 exit codes.
#   0 = gate passed (or -AllowGateFail), 1 = a generator crashed, 2 = gate failed,
#   3 = fail-closed redaction stop.

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:pwsh     = (Get-Process -Id $PID).Path
    $script:tmp      = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-exit-{0}" -f [guid]::NewGuid().ToString('n'))
    $fixture         = Join-Path (Join-Path (Join-Path $script:repoRoot 'tests') 'fixtures') 'python-flask-sample'
    New-Item -ItemType Directory -Force -Path $script:tmp | Out-Null

    function Invoke-Build {
        param([string]$SkillRoot, [string]$Target, [string[]]$ExtraArgs = @())
        $build = Join-Path (Join-Path (Join-Path (Join-Path $SkillRoot '.appdoc') 'scripts') 'powershell') 'run-appdoc-build.ps1'
        & $script:pwsh -NoProfile -File $build -Path $Target @ExtraArgs *> $null
        return $LASTEXITCODE
    }

    $script:target = Join-Path $script:tmp 'proj'
    Copy-Item -Path $fixture -Destination $script:target -Recurse

    $script:codePass     = Invoke-Build -SkillRoot $script:repoRoot -Target $script:target
    $script:codeFail     = Invoke-Build -SkillRoot $script:repoRoot -Target $script:target -ExtraArgs @('-QualityThreshold', '100', '-SkipDiagrams')
    $script:codeAllowed  = Invoke-Build -SkillRoot $script:repoRoot -Target $script:target -ExtraArgs @('-QualityThreshold', '100', '-SkipDiagrams', '-AllowGateFail')

    # A copy of the skill with the redaction module removed must stop fail-closed.
    $script:brokenSkill = Join-Path $script:tmp 'skill'
    New-Item -ItemType Directory -Force -Path $script:brokenSkill | Out-Null
    Copy-Item -Path (Join-Path $script:repoRoot '.appdoc') -Destination $script:brokenSkill -Recurse
    Remove-Item (Join-Path (Join-Path (Join-Path (Join-Path (Join-Path $script:brokenSkill '.appdoc') 'scripts') 'powershell') 'modules') 'AppDoc.SemanticRedaction.psm1') -Force
    $target2 = Join-Path $script:tmp 'proj2'
    Copy-Item -Path $fixture -Destination $target2 -Recurse
    $script:codeNoRedaction = Invoke-Build -SkillRoot $script:brokenSkill -Target $target2 -ExtraArgs @('-SkipDiagrams')

    # A copy of the skill where one generator throws must report a tool error, even with -AllowGateFail.
    $script:crashSkill = Join-Path $script:tmp 'skill-crash'
    New-Item -ItemType Directory -Force -Path $script:crashSkill | Out-Null
    Copy-Item -Path (Join-Path $script:repoRoot '.appdoc') -Destination $script:crashSkill -Recurse
    $crashing = Join-Path (Join-Path (Join-Path (Join-Path $script:crashSkill '.appdoc') 'scripts') 'powershell') 'generate-debt-register.ps1'
    Set-Content -LiteralPath $crashing -Value "param([string]`$RootPath)`nthrow 'simulated generator crash'" -Encoding utf8
    $target3 = Join-Path $script:tmp 'proj3'
    Copy-Item -Path $fixture -Destination $target3 -Recurse
    $script:codeCrash = Invoke-Build -SkillRoot $script:crashSkill -Target $target3 -ExtraArgs @('-SkipDiagrams', '-AllowGateFail')

    function New-SkillCopy {
        param([string]$Name)
        $dir = Join-Path $script:tmp $Name
        New-Item -ItemType Directory -Force -Path $dir | Out-Null
        Copy-Item -Path (Join-Path $script:repoRoot '.appdoc') -Destination $dir -Recurse
        return $dir
    }
    function Get-SkillScript {
        param([string]$SkillDir, [string]$Name)
        return (Join-Path (Join-Path (Join-Path (Join-Path $SkillDir '.appdoc') 'scripts') 'powershell') $Name)
    }

    # A PowerShell syntax error in the skill must stop the build (exit 1) and must not leave a run lock.
    $syntaxSkill = New-SkillCopy -Name 'skill-syntax'
    Add-Content -LiteralPath (Get-SkillScript -SkillDir $syntaxSkill -Name 'generate-debt-register.ps1') -Value "`nfunction { broken(" -Encoding utf8
    $script:syntaxTarget = Join-Path $script:tmp 'proj-syntax'
    Copy-Item -Path $fixture -Destination $script:syntaxTarget -Recurse
    $script:codeSyntax = Invoke-Build -SkillRoot $syntaxSkill -Target $script:syntaxTarget -ExtraArgs @('-AllowGateFail')

    # Another run holding the lock (a live PID) must stop the build, and the lock must stay.
    $script:lockTarget = Join-Path $script:tmp 'proj-lock'
    Copy-Item -Path $fixture -Destination $script:lockTarget -Recurse
    New-Item -ItemType Directory -Force -Path (Join-Path $script:lockTarget 'docs') | Out-Null
    $script:lockFile = Join-Path (Join-Path $script:lockTarget 'docs') '.appdoc-run.session.json'
    Set-Content -LiteralPath $script:lockFile -Value ('{{ "pid": {0} }}' -f $PID) -Encoding utf8
    $script:codeLock = Invoke-Build -SkillRoot $script:repoRoot -Target $script:lockTarget -ExtraArgs @('-AllowGateFail')

    # A crash in a generator outside the phase loop (the C4 diagrams) is a tool error too.
    $c4Skill = New-SkillCopy -Name 'skill-c4'
    Set-Content -LiteralPath (Get-SkillScript -SkillDir $c4Skill -Name 'generate-c4-mermaid-diagrams.ps1') -Value "param([string]`$CodebasePath, [string]`$OutputPath, [string]`$DiagramLevels)`nthrow 'simulated C4 crash'" -Encoding utf8
    $c4Target = Join-Path $script:tmp 'proj-c4'
    Copy-Item -Path $fixture -Destination $c4Target -Recurse
    $script:codeC4Crash = Invoke-Build -SkillRoot $c4Skill -Target $c4Target -ExtraArgs @('-AllowGateFail')

    # On a target that is not Classic ASP, the test catalog from the generic generator must survive.
    $script:testsTarget = Join-Path $script:tmp 'proj-tests'
    Copy-Item -Path $fixture -Destination $script:testsTarget -Recurse
    New-Item -ItemType Directory -Force -Path (Join-Path $script:testsTarget 'tests') | Out-Null
    Set-Content -LiteralPath (Join-Path (Join-Path $script:testsTarget 'tests') 'test_auth.py') -Value "def test_login_ok():`n    assert True`n`ndef test_logout_ok():`n    assert True`n" -Encoding utf8
    $script:codeTests = Invoke-Build -SkillRoot $script:repoRoot -Target $script:testsTarget
}

AfterAll {
    if ($script:tmp -and (Test-Path $script:tmp)) { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'run-appdoc-build.ps1 exit codes' {
    It 'exits 0 when the gate passes' { $script:codePass | Should -Be 0 }
    It 'exits 2 when the gate fails' { $script:codeFail | Should -Be 2 }
    It 'exits 0 for a failed gate when -AllowGateFail is given' { $script:codeAllowed | Should -Be 0 }
    It 'exits 3 when the redaction module cannot be loaded (fail-closed)' { $script:codeNoRedaction | Should -Be 3 }
    It 'exits 1 when a generator crashes, even with -AllowGateFail' { $script:codeCrash | Should -Be 1 }
    It 'exits 1 when the PowerShell syntax pre-check fails, even with -AllowGateFail' { $script:codeSyntax | Should -Be 1 }
    It 'leaves no run lock behind after a failed pre-check' { Test-Path (Join-Path (Join-Path $script:syntaxTarget 'docs') '.appdoc-run.session.json') | Should -BeFalse }
    It 'exits 1 when another run holds the lock, even with -AllowGateFail' { $script:codeLock | Should -Be 1 }
    It 'keeps a lock that a live run holds' { Test-Path $script:lockFile | Should -BeTrue }
    It 'exits 1 when the C4 diagram generator crashes, even with -AllowGateFail' { $script:codeC4Crash | Should -Be 1 }
    It 'keeps the generic test catalog on a target that is not Classic ASP' {
        $script:codeTests | Should -Be 0
        $catalog = Get-Content -LiteralPath (Join-Path (Join-Path $script:testsTarget 'docs') 'test-catalog.md') -Raw
        $catalog | Should -Match 'test_login_ok'
    }
}
