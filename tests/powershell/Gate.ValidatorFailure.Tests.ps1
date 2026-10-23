# Regression test (ADR 0003): a sub-validator that reports failed checks with `exit 1` must be
# recorded as failed by the gate (validate-documentation.ps1), not as "OK".

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $ps = Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell'
    $script:build    = Join-Path $ps 'run-appdoc-build.ps1'
    $script:validate = Join-Path $ps 'validate-documentation.ps1'
    $script:pwsh     = (Get-Process -Id $PID).Path
    $script:root     = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-gate-{0}" -f [guid]::NewGuid().ToString('n'))
    Copy-Item -Path (Join-Path (Join-Path (Join-Path $script:repoRoot 'tests') 'fixtures') 'python-flask-sample') -Destination $script:root -Recurse
    & $script:pwsh -NoProfile -File $script:build -Path $script:root *> $null

    function Get-Report { Get-Content (Join-Path (Join-Path $script:root 'docs') 'validation-report.json') -Raw | ConvertFrom-Json -Depth 20 }
    $script:clean = Get-Report

    $evidence = Join-Path (Join-Path (Join-Path $script:root 'docs') 'evidence') 'dependencies-catalog.evidence.json'
    '{ this is not json' | Set-Content -Path $evidence -Encoding utf8
    & $script:pwsh -NoProfile -File $script:validate -RootPath $script:root -Json *> $null
    $script:broken = Get-Report
}

AfterAll {
    if ($script:root -and (Test-Path $script:root)) { Remove-Item $script:root -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Gate records sub-validator results truthfully' {
    It 'reports every validator as passed on a clean build' {
        @($script:clean.validators | Where-Object { -not $_.passed }).Count | Should -Be 0
        $script:clean.metrics.validatorPassRate | Should -Be 100
    }
    It 'records the dependencies validator as failed when its evidence is corrupt' {
        $dep = @($script:broken.validators | Where-Object { $_.script -eq 'validate-dependencies-catalog.ps1' })[0]
        $dep.passed | Should -BeFalse
        $dep.exitCode | Should -Be 1
        $dep.message | Should -Match 'dependencies-evidence-unparseable'
    }
    It 'lowers validatorPassRate below 100' {
        $script:broken.metrics.validatorPassRate | Should -BeLessThan 100
    }
    It 'does not treat a reported validation failure as an internal error' {
        @($script:broken.validatorInternalErrors).Count | Should -Be 0
    }
}
