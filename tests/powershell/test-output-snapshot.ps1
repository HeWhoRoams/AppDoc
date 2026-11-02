#requires -Version 7.2
<#
.SYNOPSIS
    Output snapshot harness: proves a change leaves every generated file unchanged.

.DESCRIPTION
    For each fixture under tests/fixtures/ the harness copies the fixture to a temp folder,
    runs run-appdoc-build.ps1 on the copy, normalises content that changes from run to run,
    and hashes every file the build wrote under docs/. It then compares the hashes, the
    build exit code and the gate result against the committed baseline for this environment.

    The golden suites assert structure. This harness asserts bytes, so a refactor that is meant
    to change nothing can prove it. A change that is meant to alter output updates the baseline
    in the same pull request (-Update), and the reviewer reads the difference with -SaveTree and
    -CompareTree.

    Baselines live in tests/powershell/snapshots/<profile>/<fixture>.json. The profile is
    'dotnet' when the dotnet CLI is on PATH (the C# AST parser can run) and 'no-dotnet'
    otherwise (the regex fallback runs), because the two paths write different evidence.
    Only 'no-dotnet' baselines are committed so far; CI runs the harness on its no-dotnet leg.
    The node CLI also changes one field (the TypeScript provider note), so the baseline records
    whether node was present, along with the platform and PowerShell version.

    The repository's own docs/ is not covered here: every code change moves line numbers and
    TODOs in it. The CI "drift" job covers it.

.PARAMETER Fixture
    Fixture folder names to run. Default: every folder under tests/fixtures/ that is a build
    target (mock-llm-semantic-output is input data for another test, not a target).

.PARAMETER Update
    Write the current result as the baseline instead of comparing.

.PARAMETER SaveTree
    Also write the normalised files to this folder (one subfolder per fixture), so two runs
    can be compared file by file.

.PARAMETER CompareTree
    A folder written earlier with -SaveTree. Every file that differs from it is shown as a diff.

.PARAMETER KeepWork
    Keep the temp copies for inspection instead of deleting them.

.OUTPUTS
    Exit 0: every fixture matches its baseline (or -Update wrote them).
    Exit 1: at least one fixture differs from its baseline.
    Exit 2: the harness could not run (missing baseline, build produced no docs/, bad argument).

.EXAMPLE
    pwsh -NoProfile -File tests/powershell/test-output-snapshot.ps1

.EXAMPLE
    # Review an intended change: save the tree on the base commit, then compare on the branch.
    pwsh -NoProfile -File tests/powershell/test-output-snapshot.ps1 -SaveTree ../snap-base
    pwsh -NoProfile -File tests/powershell/test-output-snapshot.ps1 -CompareTree ../snap-base
#>
[CmdletBinding()]
param(
    [string[]]$Fixture,
    [switch]$Update,
    [string]$SaveTree,
    [string]$CompareTree,
    [switch]$KeepWork
)

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version 3.0

$repoRoot     = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$fixturesRoot = Join-Path (Join-Path $repoRoot 'tests') 'fixtures'
$buildScript  = Join-Path (Join-Path (Join-Path (Join-Path $repoRoot '.appdoc') 'scripts') 'powershell') 'run-appdoc-build.ps1'
$pwshPath     = (Get-Process -Id $PID).Path
$notTargets   = @('mock-llm-semantic-output', 'secret-in-comments-sample')
$formatVersion = 1

$profileName  = if (Get-Command dotnet -ErrorAction SilentlyContinue) { 'dotnet' } else { 'no-dotnet' }
# Other tools whose presence changes the output. Recorded in the baseline so a difference can
# be traced to the environment rather than to the code.
$environment = [ordered]@{
    platform = if ($IsWindows) { 'windows' } elseif ($IsMacOS) { 'macos' } else { 'linux' }
    pwsh     = $PSVersionTable.PSVersion.ToString()
    node     = [bool](Get-Command node -ErrorAction SilentlyContinue)
}
$baselineRoot = Join-Path (Join-Path $PSScriptRoot 'snapshots') $profileName

# --- normalisation -------------------------------------------------------------------------
# Every rule below exists because two identical builds disagreed on it. Each rule names what it
# hides, so a reviewer can tell what the harness does not see. The hidden values are covered
# elsewhere: a content hash hides nothing the hashed file's own entry does not show.
$script:TextRules = @(
    # Wall-clock stamps, in the three forms the build writes: ISO-8601 ("Generated At"),
    # "2026-10-23 11:52:09" ("**Generated**", HTML footer) and the current culture's short form
    # ("**Evidence date**", "generatedAt" in the composed evidence).
    @{ name = 'iso-timestamp';     pattern = '\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(\.\d+)?(Z|[+-]\d{2}:\d{2})?'; replacement = '<TIMESTAMP>' }
    @{ name = 'local-timestamp';   pattern = '\d{4}-\d{2}-\d{2} \d{2}:\d{2}(:\d{2})?'; replacement = '<TIMESTAMP>' }
    @{ name = 'culture-timestamp'; pattern = '\b\d{1,2}/\d{1,2}/\d{4} \d{1,2}:\d{2}(:\d{2})?(\s?[AP]M)?'; replacement = '<TIMESTAMP>' }
    # A new GUID per run in the narrative context pack.
    @{ name = 'run-id';            pattern = '("run_id"\s*:\s*")[0-9a-fA-F-]{36}(")'; replacement = '${1}<GUID>${2}' }
    # Run time of the overview narrative step.
    @{ name = 'duration';          pattern = '("durationMs"\s*:\s*)[0-9.]+'; replacement = '${1}0' }
    # SHA-256 values (contentHash, determinismHash, manifest sha256): they hash files that
    # contain timestamps, so they change every run.
    @{ name = 'sha256';            pattern = '\b[0-9a-fA-F]{64}\b'; replacement = '<SHA256>' }
)

function Write-CanonicalJson {
    # JSON objects come out of the build in a different key order on each run: many are built
    # from unordered hashtables, and .NET randomises string hashing per process. This writes a
    # canonical form: object keys sorted (ordinal), arrays in their original order, numbers as
    # written, strings re-encoded with one escaping rule, two-space indent. It uses
    # System.Text.Json directly, so it does not depend on the PowerShell version's
    # ConvertTo-Json formatting or its date conversion.
    param([System.Text.Json.JsonElement]$Element, [System.Text.StringBuilder]$Builder, [int]$Indent)
    $pad = ' ' * ($Indent + 2)
    switch ($Element.ValueKind) {
        'Object' {
            $props = @($Element.EnumerateObject())
            if ($props.Count -eq 0) { [void]$Builder.Append('{}'); return }
            # Sort an index, not the properties: PowerShell copies arrays it passes to a
            # generic .NET overload, so a two-array Array.Sort would not move the values.
            $order = [System.Collections.Generic.List[int]]::new()
            for ($i = 0; $i -lt $props.Count; $i++) { $order.Add($i) }
            $order.Sort([System.Comparison[int]] { param($x, $y)
                $c = [string]::CompareOrdinal($props[$x].Name, $props[$y].Name)
                if ($c -eq 0) { $c = $x.CompareTo($y) }
                return $c
            })
            [void]$Builder.Append("{`n")
            for ($n = 0; $n -lt $order.Count; $n++) {
                $p = $props[$order[$n]]
                [void]$Builder.Append($pad).Append('"').Append((ConvertTo-JsonStringBody $p.Name)).Append('": ')
                Write-CanonicalJson -Element $p.Value -Builder $Builder -Indent ($Indent + 2)
                if ($n -lt $order.Count - 1) { [void]$Builder.Append(',') }
                [void]$Builder.Append("`n")
            }
            [void]$Builder.Append(' ' * $Indent).Append('}')
        }
        'Array' {
            $values = @($Element.EnumerateArray())
            if ($values.Count -eq 0) { [void]$Builder.Append('[]'); return }
            [void]$Builder.Append("[`n")
            for ($i = 0; $i -lt $values.Count; $i++) {
                [void]$Builder.Append($pad)
                Write-CanonicalJson -Element $values[$i] -Builder $Builder -Indent ($Indent + 2)
                if ($i -lt $values.Count - 1) { [void]$Builder.Append(',') }
                [void]$Builder.Append("`n")
            }
            [void]$Builder.Append(' ' * $Indent).Append(']')
        }
        'String' { [void]$Builder.Append('"').Append((ConvertTo-JsonStringBody $Element.GetString())).Append('"') }
        default  { [void]$Builder.Append($Element.GetRawText()) }
    }
}

function ConvertTo-JsonStringBody {
    param([string]$Value)
    return [System.Text.Json.JsonEncodedText]::Encode($Value, [System.Text.Encodings.Web.JavaScriptEncoder]::UnsafeRelaxedJsonEscaping).ToString()
}

function ConvertTo-SnapshotText {
    param([string]$Text, [string]$WorkRoot, [string]$RelativePath)
    $t = $Text -replace "`r`n", "`n" -replace "`r", "`n"
    # Temp-folder paths, in the forms the build writes them.
    foreach ($p in @($WorkRoot, ($WorkRoot -replace '\\', '/'), ($WorkRoot -replace '\\', '\\'))) {
        if ($p) { $t = $t.Replace($p, '<WORK>') }
    }
    $t = $t.Replace($repoRoot, '<TOOL>').Replace(($repoRoot -replace '\\', '/'), '<TOOL>')
    foreach ($r in $script:TextRules) { $t = [regex]::Replace($t, $r.pattern, $r.replacement) }
    if ($RelativePath -like '*.json') {
        try {
            $options = [System.Text.Json.JsonDocumentOptions]::new()
            $options.MaxDepth = 512
            $doc = [System.Text.Json.JsonDocument]::Parse($t, $options)
            try {
                $sb = [System.Text.StringBuilder]::new()
                Write-CanonicalJson -Element $doc.RootElement -Builder $sb -Indent 0
                $t = $sb.ToString()
            }
            finally { $doc.Dispose() }
        }
        catch {
            # Not valid JSON: compare it as text.
            Write-Verbose "Not valid JSON, compared as text: $RelativePath"
        }
    }
    return $t
}

function Get-Sha256 {
    param([string]$Text)
    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    return ([System.BitConverter]::ToString([System.Security.Cryptography.SHA256]::HashData($bytes)) -replace '-', '').ToLowerInvariant()
}

function Get-RelativeSlashPath {
    param([string]$Base, [string]$Path)
    return ([System.IO.Path]::GetRelativePath($Base, $Path) -replace '\\', '/')
}

function Get-GateSummary {
    param([string]$DocsPath)
    $vrPath = Join-Path $DocsPath 'validation-report.json'
    if (-not (Test-Path -LiteralPath $vrPath)) { return $null }
    $vr = Get-Content -LiteralPath $vrPath -Raw | ConvertFrom-Json -Depth 60
    return [ordered]@{ status = [string]$vr.status; overallScore = $vr.overallScore }
}

function Invoke-FixtureSnapshot {
    param([string]$Name, [string]$WorkParent)

    $source = Join-Path $fixturesRoot $Name
    $target = Join-Path $WorkParent $Name
    Copy-Item -LiteralPath $source -Destination $target -Recurse -Force

    # Files that exist in the fixture before the build are inputs, not output.
    $docsPath = Join-Path $target 'docs'
    $inputs = @{}
    if (Test-Path -LiteralPath $docsPath) {
        foreach ($f in Get-ChildItem -LiteralPath $docsPath -Recurse -File) {
            $inputs[(Get-RelativeSlashPath -Base $docsPath -Path $f.FullName)] = (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash
        }
    }

    $log = Join-Path $WorkParent "$Name.build.log"
    & $pwshPath -NoProfile -File $buildScript -Path $target *> $log
    $exitCode = $LASTEXITCODE
    if (-not (Test-Path -LiteralPath $docsPath)) {
        throw "Build for '$Name' produced no docs/ folder (exit $exitCode). Log: $log"
    }

    $files = [ordered]@{}
    foreach ($f in (Get-ChildItem -LiteralPath $docsPath -Recurse -File | Sort-Object FullName)) {
        $rel = Get-RelativeSlashPath -Base $docsPath -Path $f.FullName
        if ($inputs.ContainsKey($rel) -and $inputs[$rel] -eq (Get-FileHash -LiteralPath $f.FullName -Algorithm SHA256).Hash) { continue }
        $text = ConvertTo-SnapshotText -Text ([System.IO.File]::ReadAllText($f.FullName)) -WorkRoot $target -RelativePath $rel
        $files[$rel] = [ordered]@{ sha256 = (Get-Sha256 -Text $text); lines = @($text -split "`n").Count; text = $text }
    }

    return [ordered]@{
        fixture  = $Name
        exitCode = $exitCode
        gate     = Get-GateSummary -DocsPath $docsPath
        files    = $files
        log      = $log
    }
}

function ConvertTo-Baseline {
    param($Result)
    $entries = [ordered]@{}
    foreach ($k in $Result.files.Keys) { $entries[$k] = [ordered]@{ sha256 = $Result.files[$k].sha256; lines = $Result.files[$k].lines } }
    return [ordered]@{
        formatVersion = $formatVersion
        fixture       = $Result.fixture
        profile       = $profileName
        environment   = $environment
        exitCode      = $Result.exitCode
        gate          = $Result.gate
        normalisation = [ordered]@{
            textRules = @($script:TextRules | ForEach-Object { $_.name })
            json      = 'keys sorted, arrays in order'
            paths     = 'temp folder -> <WORK>, AppDoc repo -> <TOOL>, CRLF -> LF'
        }
        files         = $entries
    }
}

function Compare-WithBaseline {
    param($Result, $Baseline)
    $problems = [System.Collections.Generic.List[string]]::new()
    if ([int]$Baseline.exitCode -ne [int]$Result.exitCode) { $problems.Add("build exit code: baseline $($Baseline.exitCode), now $($Result.exitCode)") }
    $bGate = "$($Baseline.gate.status)/$($Baseline.gate.overallScore)"
    $rGate = "$($Result.gate.status)/$($Result.gate.overallScore)"
    if ($bGate -ne $rGate) { $problems.Add("gate: baseline $bGate, now $rGate") }

    $baseFiles = @{}
    foreach ($p in $Baseline.files.PSObject.Properties) { $baseFiles[$p.Name] = $p.Value }
    foreach ($k in $Result.files.Keys) {
        if (-not $baseFiles.ContainsKey($k)) { $problems.Add("new file: $k"); continue }
        if ($baseFiles[$k].sha256 -ne $Result.files[$k].sha256) { $problems.Add("changed: $k (lines $($baseFiles[$k].lines) -> $($Result.files[$k].lines))") }
    }
    foreach ($k in $baseFiles.Keys) {
        if (-not $Result.files.Contains($k)) { $problems.Add("missing file: $k") }
    }
    return $problems
}

# --- run ------------------------------------------------------------------------------------
function Stop-Harness {
    # Write-Error would throw under ErrorActionPreference=Stop and exit 1; this keeps exit 2.
    param([string]$Message)
    [Console]::Error.WriteLine("test-output-snapshot: $Message")
    exit 2
}
if (-not (Test-Path -LiteralPath $buildScript)) { Stop-Harness "build script not found: $buildScript" }
if ($CompareTree -and -not (Test-Path -LiteralPath $CompareTree)) { Stop-Harness "CompareTree folder not found: $CompareTree" }

$allFixtures = @(Get-ChildItem -LiteralPath $fixturesRoot -Directory | Where-Object { $notTargets -notcontains $_.Name } | Sort-Object Name | ForEach-Object { $_.Name })
# "-Fixture a,b" arrives as one string under pwsh -File; accept both forms.
$Fixture = @($Fixture | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
if ($Fixture.Count -eq 0) { $Fixture = $allFixtures }
foreach ($f in $Fixture) {
    if ($allFixtures -notcontains $f) { Stop-Harness "unknown fixture '$f'. Known: $($allFixtures -join ', ')" }
}

$workParent = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-snapshot-{0}" -f [guid]::NewGuid().ToString('n'))
New-Item -ItemType Directory -Force -Path $workParent | Out-Null

Write-Host "Output snapshot harness · profile '$profileName' · $($Fixture.Count) fixture(s)"
$failed = $false
$harnessError = $false
try {
    foreach ($name in $Fixture) {
        $started = Get-Date
        try {
            $result = Invoke-FixtureSnapshot -Name $name -WorkParent $workParent
        }
        catch {
            Write-Host "  [error] $name : $($_.Exception.Message)" -ForegroundColor Red
            $harnessError = $true
            continue
        }
        $secs = [int]((Get-Date) - $started).TotalSeconds

        if ($SaveTree) {
            foreach ($k in $result.files.Keys) {
                $out = Join-Path (Join-Path $SaveTree $name) $k
                New-Item -ItemType Directory -Force -Path (Split-Path $out -Parent) | Out-Null
                [System.IO.File]::WriteAllText($out, $result.files[$k].text, [System.Text.UTF8Encoding]::new($false))
            }
        }

        if ($CompareTree) {
            $treeDir = Join-Path $CompareTree $name
            foreach ($k in $result.files.Keys) {
                $old = Join-Path $treeDir $k
                $oldText = if (Test-Path -LiteralPath $old) { [System.IO.File]::ReadAllText($old) } else { $null }
                if ($oldText -cne $result.files[$k].text) {
                    $tmpNew = Join-Path $workParent ("cmp-" + [guid]::NewGuid().ToString('n'))
                    [System.IO.File]::WriteAllText($tmpNew, $result.files[$k].text, [System.Text.UTF8Encoding]::new($false))
                    $oldArg = if ($oldText -ne $null) { $old } else { '/dev/null' }
                    Write-Host "--- $name/$k" -ForegroundColor Yellow
                    if (Get-Command git -ErrorAction SilentlyContinue) {
                        & git --no-pager diff --no-index --no-color -U2 -- $oldArg $tmpNew | Select-Object -Skip 4 | Select-Object -First 80 | ForEach-Object { Write-Host $_ }
                    }
                }
            }
        }

        $baselinePath = Join-Path $baselineRoot "$name.json"
        if ($Update) {
            New-Item -ItemType Directory -Force -Path $baselineRoot | Out-Null
            $json = (ConvertTo-Baseline -Result $result) | ConvertTo-Json -Depth 10
            [System.IO.File]::WriteAllText($baselinePath, ($json -replace "`r`n", "`n") + "`n", [System.Text.UTF8Encoding]::new($false))
            Write-Host ("  [updated] {0} · {1} files · exit {2} · gate {3}/{4} · {5}s" -f $name, $result.files.Count, $result.exitCode, $result.gate.status, $result.gate.overallScore, $secs)
            continue
        }

        if (-not (Test-Path -LiteralPath $baselinePath)) {
            $known = @(Get-ChildItem -LiteralPath (Join-Path $PSScriptRoot 'snapshots') -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.Name })
            Write-Host "  [error] $name : no baseline for profile '$profileName' (tests/powershell/snapshots/$profileName/$name.json). Baselines exist for: $($known -join ', '). Run where the environment matches one of them (for 'no-dotnet', with dotnet off PATH), or take a new baseline with -Update only where that path really runs." -ForegroundColor Red
            $harnessError = $true
            continue
        }
        $baseline = Get-Content -LiteralPath $baselinePath -Raw | ConvertFrom-Json -Depth 20
        if ($baseline.environment) {
            foreach ($key in 'platform', 'node', 'pwsh') {
                if ([string]$baseline.environment.$key -ne [string]$environment[$key]) {
                    Write-Host "  [note] $name : baseline was taken with $key=$($baseline.environment.$key), this run has $key=$($environment[$key])." -ForegroundColor Yellow
                }
            }
        }
        $problems = @(Compare-WithBaseline -Result $result -Baseline $baseline)
        if ($problems.Count -eq 0) {
            Write-Host ("  [ok] {0} · {1} files · {2}s" -f $name, $result.files.Count, $secs) -ForegroundColor Green
        }
        else {
            $failed = $true
            Write-Host ("  [differs] {0} · {1} difference(s) · {2}s" -f $name, $problems.Count, $secs) -ForegroundColor Red
            $problems | ForEach-Object { Write-Host "      $_" }
        }
    }
}
finally {
    if ($KeepWork) { Write-Host "Work folder kept: $workParent" }
    else { Remove-Item -LiteralPath $workParent -Recurse -Force -ErrorAction SilentlyContinue }
}

if ($harnessError) { exit 2 }
if ($failed) {
    Write-Host "Output changed. If the change is intended, run with -Update, review the difference with -SaveTree/-CompareTree, and commit the new baseline in the same PR."
    exit 1
}
exit 0
