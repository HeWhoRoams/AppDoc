# The report masthead logo is theme-driven: CMU mark by default, 'none' for no logo, or a custom SVG file.

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:psDir    = Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell'
    $script:report   = Join-Path $script:psDir 'generate-html-report.ps1'
    $script:themeDir = Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'templates') 'html'
    $script:pwsh     = (Get-Process -Id $PID).Path
    $script:tmp      = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-logo-{0}" -f [guid]::NewGuid().ToString('n'))
    $script:target   = Join-Path $script:tmp 'proj'

    New-Item -ItemType Directory -Force -Path (Join-Path $script:target 'docs') | Out-Null
    "# Application Documentation`n`n## Section`n`nBody text.`n" | Set-Content -Path (Join-Path (Join-Path $script:target 'docs') 'application-documentation.md') -Encoding utf8

    function Invoke-Report {
        param([string]$ThemePath)
        $args2 = @('-NoProfile', '-File', $script:report, '-RootPath', $script:target)
        if ($ThemePath) { $args2 += @('-ThemePath', $ThemePath) }
        & $script:pwsh @args2 *> $null
        return (Get-Content (Join-Path (Join-Path $script:target 'docs') 'report.html') -Raw)
    }
}

AfterAll {
    if ($script:tmp -and (Test-Path $script:tmp)) { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'HTML report masthead logo' {
    It 'renders the logo and the default theme''s primary colour' {
        $defaultTheme = Get-Content (Join-Path $script:themeDir 'theme.json') -Raw | ConvertFrom-Json -Depth 30
        $html = Invoke-Report
        $html | Should -Match '<span class="logo"'
        $html | Should -Match ([regex]::Escape([string]$defaultTheme.colors.primary))
    }

    It 'keeps the CMU theme selectable by name (maroon #6a0032)' {
        $cmu = Get-Content (Join-Path $script:themeDir 'theme.json') -Raw | ConvertFrom-Json -Depth 30
        $cmu.colors.primary | Should -Be '#6a0032'
    }

    It 'renders no logo when the theme sets logoSvg to none' {
        $html = Invoke-Report -ThemePath (Join-Path $script:themeDir 'navy-teal.json')
        $html | Should -Not -Match '<span class="logo"'
    }

    It 'inlines a custom SVG referenced by file: relative to the theme' {
        $svg = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><circle id="custom-mark" cx="5" cy="5" r="4"/></svg>'
        Set-Content -Path (Join-Path $script:tmp 'logo.svg') -Value $svg -Encoding utf8
        $theme = Get-Content (Join-Path $script:themeDir 'navy-teal.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 30
        $theme.masthead.logoSvg = 'file:logo.svg'
        $themePath = Join-Path $script:tmp 'custom-theme.json'
        $theme | ConvertTo-Json -Depth 30 | Set-Content -Path $themePath -Encoding utf8
        $html = Invoke-Report -ThemePath $themePath
        $html | Should -Match 'custom-mark'
    }
}

Describe 'HTML report is self-contained by default (offline)' {
    It 'loads no script or font from the network with the default theme' {
        $html = Invoke-Report
        $html | Should -Not -Match '<script[^>]+src="https?:'
        $html | Should -Not -Match 'href="https://fonts\.'
    }
    It 'inlines the vendored Mermaid library' {
        $html = Invoke-Report
        $html | Should -Match '/\*appdoc-vendor:begin mermaid\*/'
        $html | Should -Match 'mermaid\.initialize'
    }
    It 'uses the CDN only when the theme asks for it' {
        $theme = Get-Content (Join-Path $script:themeDir 'theme.json') -Raw | ConvertFrom-Json -AsHashtable -Depth 30
        $theme.assets = 'cdn'
        $themePath = Join-Path $script:tmp 'cdn-theme.json'
        $theme | ConvertTo-Json -Depth 30 | Set-Content -Path $themePath -Encoding utf8
        $html = Invoke-Report -ThemePath $themePath
        $html | Should -Match '<script src="https://cdn\.jsdelivr\.net/npm/mermaid'
    }
}
