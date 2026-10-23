# Regression test (ADR 0003): run-appdoc-build.ps1 exit codes.
#   0 = gate passed (or -AllowGateFail), 2 = gate failed, 3 = fail-closed redaction stop.

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
}

AfterAll {
    if ($script:tmp -and (Test-Path $script:tmp)) { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'run-appdoc-build.ps1 exit codes' {
    It 'exits 0 when the gate passes' { $script:codePass | Should -Be 0 }
    It 'exits 2 when the gate fails' { $script:codeFail | Should -Be 2 }
    It 'exits 0 for a failed gate when -AllowGateFail is given' { $script:codeAllowed | Should -Be 0 }
    It 'exits 3 when the redaction module cannot be loaded (fail-closed)' { $script:codeNoRedaction | Should -Be 3 }
}
