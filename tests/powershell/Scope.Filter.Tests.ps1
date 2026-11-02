# Get-AppDocSourceFiles prunes excluded folders during the walk; the result must equal
# "list every file, then test each with Test-AppDocPathIncluded", in a stable order.

BeforeAll {
    $repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $modules = Join-Path (Join-Path (Join-Path (Join-Path $repoRoot '.appdoc') 'scripts') 'powershell') 'modules'
    Import-Module (Join-Path $modules 'AppDoc.Scope.psm1') -Force
    $script:work = Join-Path ([System.IO.Path]::GetTempPath()) ('appdoc-filter-' + [guid]::NewGuid().ToString('N'))
    $dirs = 'src', 'src/app', 'node_modules/x', 'docs/sub', 'tests/unit', 'bin/Debug', 'obj', 'vendor/lib', 'tests/fixtures/a', '.appdoc/scripts'
    foreach ($d in $dirs) { New-Item -ItemType Directory -Path (Join-Path $script:work $d) -Force | Out-Null }
    foreach ($d in $dirs + @('.')) {
        foreach ($f in 'a.cs', 'b.py', 'c.ts', 'd.md', 'x.min.js') { Set-Content -Path (Join-Path (Join-Path $script:work $d) $f) 'x' }
    }
    $script:include = '*.cs', '*.py', '*.ts', '*.js'
}

AfterAll {
    if ($script:work -and (Test-Path $script:work)) { Remove-Item $script:work -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Get-AppDocSourceFiles' {
    It 'returns the same files as list-then-filter' {
        $new = @(Get-AppDocSourceFiles -RootPath $script:work -Include $script:include | ForEach-Object FullName) | Sort-Object
        $old = @(Get-ChildItem -Path $script:work -Recurse -File -Include $script:include |
            Where-Object { Test-AppDocPathIncluded -Path $_.FullName -RootPath $script:work } | ForEach-Object FullName) | Sort-Object
        $new.Count | Should -BeGreaterThan 0
        $new | Should -Be $old
    }
    It 'never enters node_modules, bin, obj, the output folder or tests' {
        $rel = @(Get-AppDocSourceFiles -RootPath $script:work -Include $script:include | ForEach-Object { $_.FullName.Substring($script:work.Length) })
        $rel | Where-Object { $_ -match 'node_modules|[\\/]bin[\\/]|[\\/]obj[\\/]|[\\/]docs[\\/]|[\\/]tests[\\/]' } | Should -BeNullOrEmpty
    }
    It 'returns files in ordinal path order' {
        $names = @(Get-AppDocSourceFiles -RootPath $script:work -Include $script:include | ForEach-Object FullName)
        $sorted = [string[]]$names.Clone()
        [System.Array]::Sort($sorted, [System.StringComparer]::Ordinal)
        $names | Should -Be $sorted
    }
    It 'returns nothing for a missing root' {
        @(Get-AppDocSourceFiles -RootPath (Join-Path $script:work 'nope') -Include '*.cs').Count | Should -Be 0
    }
}
