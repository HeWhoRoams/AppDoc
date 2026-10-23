# Regression tests: generated documentation must be host-independent.
#   1. No absolute host paths (drive letters, /home, /tmp, /persistent, the build root) in docs/**.
#   2. The evidence manifest stores repo-relative paths.
#   3. Building the same fixture from two different absolute locations yields semantically
#      identical evidence packs (ignoring volatile timestamps/hashes).

BeforeAll {
    $script:repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $script:build    = Join-Path (Join-Path (Join-Path (Join-Path $script:repoRoot '.appdoc') 'scripts') 'powershell') 'run-appdoc-build.ps1'
    $script:fixture  = Join-Path (Join-Path (Join-Path $script:repoRoot 'tests') 'fixtures') 'python-flask-sample'
    $script:pwsh     = (Get-Process -Id $PID).Path
    $script:tmp      = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-portable-{0}" -f [guid]::NewGuid().ToString('n'))

    # Same leaf name ("proj") in two different parents so project name is identical.
    $script:rootA = Join-Path (Join-Path $script:tmp 'a') 'proj'
    $script:rootB = Join-Path (Join-Path (Join-Path $script:tmp 'b') 'deeper') 'proj'
    foreach ($r in @($script:rootA, $script:rootB)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $r -Parent) | Out-Null
        Copy-Item -Path $script:fixture -Destination $r -Recurse
        & $script:pwsh -NoProfile -File $script:build -Path $r *> $null
    }

    function Remove-Volatile {
        param($Node)
        $volatile = @('timestamp', 'updatedAt', 'generatedAt', 'generated_at', 'run_id', 'sha256', 'contentHash')
        if ($Node -is [System.Collections.IDictionary]) {
            $out = [ordered]@{}
            foreach ($k in ($Node.Keys | Sort-Object)) {
                if ($volatile -contains [string]$k) { continue }
                $out[[string]$k] = Remove-Volatile -Node $Node[$k]
            }
            return $out
        }
        if ($Node -is [System.Collections.IEnumerable] -and $Node -isnot [string]) {
            return @($Node | ForEach-Object { Remove-Volatile -Node $_ })
        }
        return $Node
    }

    function Read-Canonical {
        param([string]$Path)
        $obj = Get-Content $Path -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        return (Remove-Volatile -Node $obj | ConvertTo-Json -Depth 100 -Compress)
    }
}

AfterAll {
    if ($script:tmp -and (Test-Path $script:tmp)) { Remove-Item $script:tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

Describe 'Generated docs are host-independent' {
    It 'embeds no build-root or drive-letter absolute paths in docs/**' {
        $rootEsc = [regex]::Escape($script:rootA)
        $hits = Get-ChildItem (Join-Path $script:rootA 'docs') -Recurse -File |
            Select-String -Pattern $rootEsc, '/persistent/', '/home/[A-Za-z0-9_.-]+/', '(?<![A-Za-z])[A-Za-z]:\\(Users|Github|Windows)' -List
        @($hits | ForEach-Object { $_.Path }) | Should -BeNullOrEmpty
    }

    It 'stores repo-relative paths in the evidence manifest' {
        $manifest = Get-Content (Join-Path (Join-Path (Join-Path $script:rootA 'docs') 'evidence') 'manifest.json') -Raw | ConvertFrom-Json
        foreach ($a in $manifest.artifacts) {
            [System.IO.Path]::IsPathRooted([string]$a.path) | Should -BeFalse -Because "artifact '$($a.artifact)' path '$($a.path)' must be relative"
        }
    }
}

Describe 'Evidence packs are location-independent' {
    It '<file> is semantically identical when built from two different roots' -ForEach @(
        @{ file = 'manifest.json' }
        @{ file = 'overview-truth-pack.json' }
        @{ file = 'diagram-truth-pack.json' }
        @{ file = 'narrative-context-pack.json' }
        @{ file = 'evidence-graph.json' }
    ) {
        $a = Read-Canonical -Path (Join-Path (Join-Path (Join-Path $script:rootA 'docs') 'evidence') $file)
        $b = Read-Canonical -Path (Join-Path (Join-Path (Join-Path $script:rootB 'docs') 'evidence') $file)
        $a | Should -BeExactly $b
    }
}
