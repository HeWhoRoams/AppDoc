# Regression test (P-03): theme resolution honours names, absolute and target-relative
# paths; an unknown name warns; a missing explicit file is an error (not a silent CMU).

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    Import-Module (Join-Path (Join-Path (Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell') 'modules') 'AppDoc.Config.psm1') -Force
    $script:themeDir = Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'templates') 'html'
    $script:root = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-theme-{0}" -f [guid]::NewGuid().ToString('n'))
    New-Item -ItemType Directory -Force -Path (Join-Path $script:root 'branding') | Out-Null
    Copy-Item (Join-Path $script:themeDir 'navy-teal.json') (Join-Path (Join-Path $script:root 'branding') 'ours.json')
}

AfterAll {
    if ($script:root -and (Test-Path $script:root)) { Remove-Item $script:root -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Theme resolution' {
    It 'maps the name cmu to the default theme file' {
        Resolve-AppDocThemePath -ThemeName 'cmu' | Should -Be (Resolve-Path (Join-Path $script:themeDir 'theme.json')).Path
    }
    It 'resolves a bundled theme by name' {
        Resolve-AppDocThemePath -ThemeName 'navy-teal' | Should -Match 'navy-teal\.json$'
    }
    It 'accepts an absolute path in theme' {
        $abs = Join-Path (Join-Path $script:root 'branding') 'ours.json'
        Resolve-AppDocThemePath -ThemeName $abs | Should -Be (Resolve-Path $abs).Path
    }
    It 'resolves a path in theme relative to the target root' {
        Resolve-AppDocThemePath -ThemeName 'branding/ours.json' -RootPath $script:root | Should -Match 'ours\.json$'
    }
    It 'warns and uses the default for an unknown theme name' {
        $w = $null
        $r = Resolve-AppDocThemePath -ThemeName 'no-such-theme' -WarningVariable w -WarningAction SilentlyContinue
        $r | Should -Match 'theme\.json$'
        ($w -join ' ') | Should -Match 'not found'
    }
    It 'fails for a missing explicit theme file' {
        { Resolve-AppDocThemePath -ThemePath (Join-Path $script:root 'missing.json') } | Should -Throw '*not found*'
    }
    It 'reports a missing theme file through the config error (the build stops)' {
        New-Item -ItemType Directory -Force -Path (Join-Path $script:root '.appdoc') | Out-Null
        '{ "themeFile": "nope.json" }' | Set-Content (Join-Path (Join-Path $script:root '.appdoc') 'config.json')
        (Get-AppDocConfig -RootPath $script:root).error | Should -Match 'Theme file not found'
    }
}
