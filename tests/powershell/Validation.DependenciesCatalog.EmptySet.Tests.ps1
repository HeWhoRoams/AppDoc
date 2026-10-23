# Regression test: validate-dependencies-catalog.ps1 must not report a false failure when the
# repository has zero dependency records. Under Set-StrictMode -Version Latest, summing an empty
# Measure-Object result used to throw and surface as 'dependencies-evidence-unparseable'.

BeforeAll {
    $script:repoRoot  = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:validator = Join-Path (Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell') 'validate-dependencies-catalog.ps1'

    $script:root = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-deps-empty-{0}" -f [guid]::NewGuid().ToString('n'))
    $evidenceDir = Join-Path (Join-Path $script:root 'docs') 'evidence'
    New-Item -ItemType Directory -Force -Path $evidenceDir | Out-Null

    @'
# Dependencies Catalog

## Dependency Summary

Dependency records in scope: none in this scan

| Name | Critical Path |
|---|---|
'@ | Set-Content -Path (Join-Path (Join-Path $script:root 'docs') 'dependencies-catalog.md') -Encoding utf8

    '{"artifact":"dependencies-catalog","recordCount":0,"records":[],"metadata":{}}' |
        Set-Content -Path (Join-Path $evidenceDir 'dependencies-catalog.evidence.json') -Encoding utf8

    $pwsh = (Get-Process -Id $PID).Path
    $script:output = & $pwsh -NoProfile -File $script:validator -RootPath $script:root 2>&1 | Out-String
    $script:exit = $LASTEXITCODE
}

AfterAll {
    if ($script:root -and (Test-Path $script:root)) { Remove-Item $script:root -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'validate-dependencies-catalog with an empty dependency set' {
    It 'does not report dependencies-evidence-unparseable' {
        $script:output | Should -Not -Match 'dependencies-evidence-unparseable'
    }
    It 'does not report an internal validator error' {
        $script:output | Should -Not -Match 'dependencies-validator-internal-error'
    }
    It 'exits 0' {
        $script:exit | Should -Be 0
    }
}

Describe 'validate-dependencies-catalog with corrupt evidence' {
    It 'still reports dependencies-evidence-unparseable' {
        $evidence = Join-Path (Join-Path (Join-Path $script:root 'docs') 'evidence') 'dependencies-catalog.evidence.json'
        '{ this is not json' | Set-Content -Path $evidence -Encoding utf8
        $pwsh = (Get-Process -Id $PID).Path
        $out = & $pwsh -NoProfile -File $script:validator -RootPath $script:root 2>&1 | Out-String
        $out | Should -Match 'dependencies-evidence-unparseable'
        $LASTEXITCODE | Should -Be 1
    }
}
