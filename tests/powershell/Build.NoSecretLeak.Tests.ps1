# A secret written in a source comment must not reach any generated file.

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:build = Join-Path (Join-Path (Join-Path (Join-Path $repoRoot '.appdoc') 'scripts') 'powershell') 'run-appdoc-build.ps1'
    $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ('appdoc-leak-' + [guid]::NewGuid().ToString('N'))
    Copy-Item -Recurse -LiteralPath (Join-Path (Join-Path (Join-Path $repoRoot 'tests') 'fixtures') 'secret-in-comments-sample') -Destination $script:work
    & git -C $script:work init -q 2>$null
    $pwshPath = (Get-Process -Id $PID).Path
    & $pwshPath -NoProfile -File $script:build -Path $script:work *> $null
    $script:exit = $LASTEXITCODE
}

AfterAll {
    if ($script:work -and (Test-Path $script:work)) { Remove-Item $script:work -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Build with secrets in comments' {
    It 'finishes without a tool error' { $script:exit | Should -BeIn @(0, 2) }
    It 'writes <Secret> to no generated file' -ForEach @(
        @{ Secret = 'AKIAIOSFODNN7EXAMPLE' }, @{ Secret = 'hunter2hunter2xyz' }, @{ Secret = 'ghp_abcdefghijklmnopqrstuvwxyz0123456789' }
    ) {
        $hits = @(Get-ChildItem -Path (Join-Path $script:work 'docs') -Recurse -File | Select-String -SimpleMatch $Secret -List)
        $hits.Count | Should -Be 0
    }
    It 'still lists the debt item with a [REDACTED] marker' {
        (Get-Content (Join-Path (Join-Path $script:work 'docs') 'debt-register.md') -Raw) | Should -Match 'password = "\[REDACTED\]"'
    }
}
