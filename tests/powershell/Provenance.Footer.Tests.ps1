# Regression test (P-12, S-07): after a build, every generated Markdown file under docs/
# carries exactly one "## Provenance" section and it is the last section; generated files
# use LF line endings with no BOM. Hand-authored files (docs/adr/**, or files carrying
# <!-- appdoc:hand-authored -->) are left untouched.

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:build = Join-Path (Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell') 'run-appdoc-build.ps1'
    $script:pwsh  = (Get-Process -Id $PID).Path
    $script:root  = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-prov-{0}" -f [guid]::NewGuid().ToString('n'))
    Copy-Item -Path (Join-Path (Join-Path (Join-Path $script:repoRoot 'tests') 'fixtures') 'python-flask-sample') -Destination $script:root -Recurse
    $docs = Join-Path $script:root 'docs'
    New-Item -ItemType Directory -Force -Path (Join-Path $docs 'adr') | Out-Null
    $script:handAuthored = "# Team notes`r`n<!-- appdoc:hand-authored -->`r`nKeep me exactly as written.`r`n"
    [System.IO.File]::WriteAllText((Join-Path $docs 'team-notes.md'), $script:handAuthored)
    [System.IO.File]::WriteAllText((Join-Path (Join-Path $docs 'adr') '0001-x.md'), "# ADR`n`nText.`n")
    & $script:pwsh -NoProfile -File $script:build -Path $script:root *> $null
    $script:docs = $docs
    $script:generatedMd = @(Get-ChildItem $docs -Recurse -File -Filter '*.md' | Where-Object {
        $_.FullName -notmatch '[\\/]adr[\\/]' -and $_.Name -ne 'team-notes.md' })
}

AfterAll {
    if ($script:root -and (Test-Path $script:root)) { Remove-Item $script:root -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Provenance footer and line endings' {
    It 'finds generated Markdown, including in subfolders' {
        $script:generatedMd.Count | Should -BeGreaterThan 10
        @($script:generatedMd | Where-Object { $_.FullName -match '[\\/](diagrams|evidence)[\\/]' }).Count | Should -BeGreaterThan 0
    }
    It 'gives every generated .md exactly one Provenance section, as the last section' {
        $bad = foreach ($f in $script:generatedMd) {
            $c = Get-Content -LiteralPath $f.FullName -Raw
            $count = ([regex]::Matches($c, '(?m)^## Provenance\s*$')).Count
            $last = ([regex]::Matches($c, '(?m)^## .*$') | Select-Object -Last 1).Value.Trim()
            if ($count -ne 1 -or $last -ne '## Provenance') { "$($f.Name): count=$count last='$last'" }
        }
        @($bad) | Should -BeNullOrEmpty
    }
    It 'writes generated text files with LF only and no BOM' {
        $bad = foreach ($f in Get-ChildItem $script:docs -Recurse -File -Include '*.md', '*.json', '*.html') {
            if ($f.Name -eq 'team-notes.md') { continue }
            $b = [System.IO.File]::ReadAllBytes($f.FullName)
            if (($b.Length -ge 3 -and $b[0] -eq 0xEF -and $b[1] -eq 0xBB) -or ($b -contains 13)) { $f.Name }
        }
        @($bad) | Should -BeNullOrEmpty
    }
    It 'leaves hand-authored files untouched' {
        [System.IO.File]::ReadAllText((Join-Path $script:docs 'team-notes.md')) | Should -BeExactly $script:handAuthored
        (Get-Content (Join-Path (Join-Path $script:docs 'adr') '0001-x.md') -Raw) | Should -Not -Match 'Provenance'
    }
}
