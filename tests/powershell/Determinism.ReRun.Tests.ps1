# Regression test (P-08): SKILL.md promises that "the gate result and the 4 gate-scored .md
# catalogs are stable across re-runs". Build the SAME folder twice and compare.
# Only wall-clock lines ("**Generated**", "- Generated At", timestamps) may differ.

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:build    = Join-Path (Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell') 'run-appdoc-build.ps1'
    $script:pwsh     = (Get-Process -Id $PID).Path
    $script:tmp      = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-rerun-{0}" -f [guid]::NewGuid().ToString('n'))
    $script:catalogs = @('config-catalog.md', 'data-model.md', 'debt-register.md', 'dependencies-catalog.md')

    function Get-Stable {
        param([string]$Path)
        $lines = (Get-Content -LiteralPath $Path -Raw) -replace "`r", '' -split "`n"
        ($lines | Where-Object { $_ -notmatch 'Generated|Evidence date|generatedAt|timestamp' }) -join "`n"
    }

    function Get-GateSummary {
        param([string]$Root)
        $vr = Get-Content (Join-Path (Join-Path $Root 'docs') 'validation-report.json') -Raw | ConvertFrom-Json -Depth 30
        [ordered]@{
            status       = $vr.status
            overallScore = $vr.overallScore
            validators   = (@($vr.validators | ForEach-Object { "$($_.script)=$($_.passed)" }) -join ',')
            sections     = (@($vr.pristine.sections | ForEach-Object { "$($_.section):$($_.rowCount)" }) -join ',')
        } | ConvertTo-Json -Compress
    }

    $script:results = @{}
    foreach ($fixture in @('python-flask-sample', 'classic-asp-sample')) {
        $root = Join-Path $script:tmp $fixture
        New-Item -ItemType Directory -Force -Path $script:tmp | Out-Null
        Copy-Item -Path (Join-Path (Join-Path (Join-Path $script:repoRoot 'tests') 'fixtures') $fixture) -Destination $root -Recurse
        $runs = @()
        foreach ($i in 1, 2) {
            & $script:pwsh -NoProfile -File $script:build -Path $root *> $null
            $docs = Join-Path $root 'docs'
            $runs += [ordered]@{
                gate     = Get-GateSummary -Root $root
                master   = Get-Stable -Path (Join-Path $docs 'application-documentation.md')
                catalogs = @($script:catalogs | ForEach-Object { Get-Stable -Path (Join-Path $docs $_) })
            }
        }
        $script:results[$fixture] = $runs
    }
}

AfterAll {
    if ($script:tmp -and (Test-Path $script:tmp)) { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'A re-run of the same folder gives the same result' {
    It '<fixture>: gate result is identical' -ForEach @(@{ fixture = 'python-flask-sample' }, @{ fixture = 'classic-asp-sample' }) {
        $r = $script:results[$fixture]
        $r[1].gate | Should -BeExactly $r[0].gate
    }
    It '<fixture>: the 4 gate-scored catalogs are identical' -ForEach @(@{ fixture = 'python-flask-sample' }, @{ fixture = 'classic-asp-sample' }) {
        $r = $script:results[$fixture]
        for ($i = 0; $i -lt $script:catalogs.Count; $i++) {
            $r[1].catalogs[$i] | Should -BeExactly $r[0].catalogs[$i] -Because $script:catalogs[$i]
        }
    }
    It '<fixture>: the composed master document is identical' -ForEach @(@{ fixture = 'python-flask-sample' }, @{ fixture = 'classic-asp-sample' }) {
        $r = $script:results[$fixture]
        $r[1].master | Should -BeExactly $r[0].master
    }
}
