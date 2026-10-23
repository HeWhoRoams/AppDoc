# Regression test (P-01): config outputDir moves the whole package; the default stays docs/.

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:build = Join-Path (Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell') 'run-appdoc-build.ps1'
    $script:pwsh  = (Get-Process -Id $PID).Path
    $script:root  = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-outdir-{0}" -f [guid]::NewGuid().ToString('n'))
    Copy-Item -Path (Join-Path (Join-Path (Join-Path $script:repoRoot 'tests') 'fixtures') 'python-flask-sample') -Destination $script:root -Recurse
    # The fixture ships a docs/ folder with AST caches; remove it so "nothing under docs/" is testable.
    Remove-Item (Join-Path $script:root 'docs') -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Force -Path (Join-Path $script:root '.appdoc') | Out-Null
    '{ "outputDir": "documentation" }' | Set-Content (Join-Path (Join-Path $script:root '.appdoc') 'config.json')
    & $script:pwsh -NoProfile -File $script:build -Path $script:root -SkipDiagrams *> $null
    $script:exit = $LASTEXITCODE

    $script:escape = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-outdir-esc-{0}" -f [guid]::NewGuid().ToString('n'))
    Copy-Item -Path (Join-Path (Join-Path (Join-Path $script:repoRoot 'tests') 'fixtures') 'python-flask-sample') -Destination $script:escape -Recurse
    New-Item -ItemType Directory -Force -Path (Join-Path $script:escape '.appdoc') | Out-Null
    '{ "outputDir": "../outside" }' | Set-Content (Join-Path (Join-Path $script:escape '.appdoc') 'config.json')
    & $script:pwsh -NoProfile -File $script:build -Path $script:escape -SkipDiagrams *> $null
}

AfterAll {
    foreach ($p in @($script:root, $script:escape)) { if ($p -and (Test-Path $p)) { Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue } }
}

Describe 'outputDir' {
    It 'builds successfully' { $script:exit | Should -Be 0 }
    It 'writes the package to the configured folder' {
        Test-Path (Join-Path (Join-Path $script:root 'documentation') 'validation-report.json') | Should -BeTrue
        Test-Path (Join-Path (Join-Path $script:root 'documentation') 'application-documentation.md') | Should -BeTrue
    }
    It 'writes nothing to docs/' {
        Test-Path (Join-Path $script:root 'docs') | Should -BeFalse
    }
    It 'refuses a folder outside the target and falls back to docs/' {
        Test-Path (Join-Path (Split-Path $script:escape -Parent) 'outside') | Should -BeFalse
        Test-Path (Join-Path (Join-Path $script:escape 'docs') 'validation-report.json') | Should -BeTrue
    }
}
