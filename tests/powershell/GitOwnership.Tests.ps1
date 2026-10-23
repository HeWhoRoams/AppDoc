# Regression test (P-14): git ownership lists only files that exist in the current tree and
# shows author names without email addresses unless the target opts in.

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:gen  = Join-Path (Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell') 'generate-git-ownership.ps1'
    $script:pwsh = (Get-Process -Id $PID).Path
    $script:root = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-own-{0}" -f [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Force -Path (Join-Path $script:root 'src') | Out-Null
    Push-Location $script:root
    try {
        git init -q
        git config user.name 'Ada Example'
        git config user.email 'ada@example.org'
        'a' | Set-Content src/keep.txt; 'b' | Set-Content src/gone.txt; 'c' | Set-Content src/old.txt
        git add -A; git commit -qm one
        git rm -q src/gone.txt; git mv src/old.txt src/new.txt; 'x' | Add-Content src/keep.txt
        git commit -qam two
    } finally { Pop-Location }
    New-Item -ItemType Directory -Force -Path (Join-Path $script:root 'docs') | Out-Null

    function Invoke-Ownership {
        & $script:pwsh -NoProfile -File $script:gen -RootPath $script:root *> $null
        return @{
            md = Get-Content (Join-Path (Join-Path $script:root 'docs') 'git-ownership.md') -Raw
            ev = Get-Content (Join-Path (Join-Path (Join-Path $script:root 'docs') 'evidence') 'git-ownership.evidence.json') -Raw
        }
    }
    $script:default = Invoke-Ownership
    New-Item -ItemType Directory -Force -Path (Join-Path $script:root '.appdoc') | Out-Null
    '{ "ownership": { "showEmails": true } }' | Set-Content (Join-Path (Join-Path $script:root '.appdoc') 'config.json')
    $script:optIn = Invoke-Ownership
}

AfterAll {
    if ($script:root -and (Test-Path $script:root)) { Remove-Item $script:root -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Git ownership' {
    It 'lists files that exist now' {
        $script:default.md | Should -Match 'src/keep\.txt'
        $script:default.md | Should -Match 'src/new\.txt'
    }
    It 'does not list deleted or renamed-away files' {
        $script:default.md | Should -Not -Match 'src/gone\.txt'
        $script:default.md | Should -Not -Match 'src/old\.txt'
    }
    It 'shows author names but no email addresses by default' {
        $script:default.md | Should -Match 'Ada Example'
        $script:default.md | Should -Not -Match '@'
        $script:default.ev | Should -Not -Match 'ada@example\.org'
    }
    It 'shows email addresses when the target sets ownership.showEmails' {
        $script:optIn.md | Should -Match 'ada@example\.org'
    }
}
