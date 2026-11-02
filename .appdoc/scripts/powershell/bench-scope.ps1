<#
.SYNOPSIS
    Times Get-AppDocSourceFiles on a generated tree (default 10,000 source files plus a
    node_modules folder of the same size). Prints the milliseconds; exits 1 if over -MaxMs.
#>
[CmdletBinding()]
param([int]$Files = 10000, [int]$MaxMs = 1000)
$ErrorActionPreference = 'Stop'
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Scope.psm1') -Force
$root = Join-Path ([System.IO.Path]::GetTempPath()) ('appdoc-bench-' + [guid]::NewGuid().ToString('N'))
try {
    foreach ($top in 'src', 'node_modules') {
        for ($i = 0; $i -lt 100; $i++) {
            $d = Join-Path (Join-Path $root $top) "p$i"
            New-Item -ItemType Directory -Path $d -Force | Out-Null
            for ($j = 0; $j -lt ($Files / 100); $j++) { [System.IO.File]::WriteAllText((Join-Path $d "f$j.ts"), 'x') }
        }
    }
    $null = Get-AppDocSourceFiles -RootPath $root -Include '*.ts'   # warm the policy cache
    $ms = (Measure-Command { $found = @(Get-AppDocSourceFiles -RootPath $root -Include '*.ts') }).TotalMilliseconds
    "{0} files found, {1:N0} ms" -f $found.Count, $ms
    if ($found.Count -ne $Files -or $ms -gt $MaxMs) { exit 1 }
}
finally { Remove-Item $root -Recurse -Force -ErrorAction SilentlyContinue }
