#requires -Version 7.2
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,

    # Also render every Mermaid block with mmdc (needs mmdc and a headless browser).
    [switch]$Render
)

# Static checks for docs/pipeline/: hand-authored drill-down pages that describe a build.
# It reads files and never runs a build. It catches structural drift (broken links, unknown
# gate IDs, diagrams that GitHub cannot render or that grow too large, named code that no
# longer exists). It cannot tell whether a diagram is true; the pull request checklist does that.

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$root = (Resolve-Path -LiteralPath $RootPath).Path
$pagesDir = Join-Path (Join-Path $root 'docs') 'pipeline'
$marker = '<!-- appdoc:hand-authored -->'
$issues = [System.Collections.Generic.List[string]]::new()

function Add-PageIssue {
    param([string]$Code, [string]$Page, [string]$Message)
    $issues.Add(("[{0}] {1}: {2}" -f $Code, $Page, $Message)) | Out-Null
}

function Get-RelativePage {
    param([string]$FullName)
    return ([System.IO.Path]::GetRelativePath($pagesDir, $FullName) -replace '\\', '/')
}

function Get-HeadingSlug {
    param([string]$Heading)
    $slug = $Heading.Trim().ToLowerInvariant()
    $slug = [regex]::Replace($slug, '[^\p{L}\p{N}\s_-]', '')
    return ($slug -replace '\s', '-')
}

function Get-PageAnchors {
    param([string]$Content)
    $set = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($m in [regex]::Matches($Content, '(?m)^#{1,6}\s+(.+?)\s*$')) {
        [void]$set.Add((Get-HeadingSlug -Heading $m.Groups[1].Value))
    }
    foreach ($m in [regex]::Matches($Content, '<a\s+id="([^"]+)"')) {
        [void]$set.Add($m.Groups[1].Value)
    }
    return $set
}

function Get-FlowchartNodeCount {
    param([string]$Body)
    $ids = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($line in ($Body -split '\r?\n')) {
        $t = $line.Trim()
        if ($t -eq '' -or $t -match '^(flowchart|graph)\b|^accTitle:|^accDescr:|^subgraph\b|^end$|^direction\b|^%%') { continue }
        $t = [regex]::Replace($t, '"[^"]*"', '""')
        $t = [regex]::Replace($t, '\|[^|]*\|', '')
        foreach ($seg in [regex]::Split($t, '\s*(?:-->|-\.->|==>|---|-\.-|--)\s*')) {
            if ($seg -match '^([A-Za-z][A-Za-z0-9_]*)') { [void]$ids.Add($Matches[1]) }
        }
    }
    return $ids.Count
}

function Get-NodeLimit {
    param([string]$Page)
    if ($Page -eq 'README.md') { return 14 }
    if ($Page -match '^\d\d-') { return 12 }
    return 15
}

if (-not (Test-Path -LiteralPath $pagesDir)) {
    Write-Host "Pipeline docs gate failed: docs/pipeline/ is missing." -ForegroundColor Red
    exit 1
}

$pages = @(Get-ChildItem -LiteralPath $pagesDir -Recurse -File -Filter *.md | Sort-Object FullName)
$contentByPage = @{}
foreach ($p in $pages) {
    $contentByPage[(Get-RelativePage -FullName $p.FullName)] = (Get-Content -LiteralPath $p.FullName -Raw)
}

# Known code: script, module and function names under .appdoc/ and tests/.
$codeFiles = @(Get-ChildItem -LiteralPath (Join-Path $root '.appdoc') -Recurse -File -Include *.ps1, *.psm1)
$testsDir = Join-Path $root 'tests'
if (Test-Path -LiteralPath $testsDir) {
    $codeFiles += @(Get-ChildItem -LiteralPath $testsDir -Recurse -File -Include *.ps1, *.psm1)
}
$fileNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
$functionNames = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
foreach ($f in $codeFiles) {
    [void]$fileNames.Add($f.Name)
    foreach ($m in [regex]::Matches((Get-Content -LiteralPath $f.FullName -Raw), '(?im)^\s*function\s+([A-Za-z0-9_-]+)')) {
        [void]$functionNames.Add($m.Groups[1].Value)
    }
}

# Gate anchors and finding tags defined in gates.md.
$gatesContent = if ($contentByPage.ContainsKey('gates.md')) { $contentByPage['gates.md'] } else { '' }
$gateAnchors = [System.Collections.Generic.HashSet[string]]::new()
foreach ($m in [regex]::Matches($gatesContent, '<a\s+id="(g\d+[ab]?)"')) { [void]$gateAnchors.Add($m.Groups[1].Value) }
$gapTags = [System.Collections.Generic.HashSet[string]]::new()
foreach ($m in [regex]::Matches($gatesContent, '(?m)^\|\s*\*\*([PT]-\d+)\*\*\s*\|')) { [void]$gapTags.Add($m.Groups[1].Value) }
if ($gateAnchors.Count -eq 0) { Add-PageIssue -Code 'gates-missing' -Page 'gates.md' -Message 'no gate anchors (<a id="g1a"></a> and so on) found' }

$diagramCount = 0
$anchorCache = @{}

foreach ($page in $contentByPage.Keys | Sort-Object) {
    $content = $contentByPage[$page]
    $pageFull = Join-Path $pagesDir $page
    $pageDir = Split-Path -Parent $pageFull

    # Marker, heading and question line.
    if (-not $content.StartsWith($marker)) {
        Add-PageIssue -Code 'marker-missing' -Page $page -Message "first line must be $marker (otherwise the build rewrites the page)"
    }
    if ($content -notmatch '(?m)^# \S') { Add-PageIssue -Code 'h1-missing' -Page $page -Message 'no level-1 heading' }
    if ($content -notmatch '(?m)^\*\*.+\?\*\*\s*$') { Add-PageIssue -Code 'question-missing' -Page $page -Message 'no bold one-line question under the title' }

    # Diagrams.
    $blocks = [regex]::Matches($content, '(?ms)^```mermaid\r?\n(.*?)^```\s*$')
    $blockIndex = 0
    foreach ($b in $blocks) {
        $blockIndex++
        $diagramCount++
        $label = "$page diagram $blockIndex"
        $block = $b.Groups[1].Value
        $body = $block
        $frontMatter = [regex]::Match($block, '(?s)\A---\r?\n(.*?)\r?\n---\r?\n')
        if ($frontMatter.Success) {
            if ($frontMatter.Groups[1].Value -notmatch '(?m)^title:\s*\S') { Add-PageIssue -Code 'diagram-title' -Page $label -Message 'front matter has no title' }
            $body = $block.Substring($frontMatter.Length)
        }
        else {
            Add-PageIssue -Code 'diagram-title' -Page $label -Message 'no front-matter title'
        }
        if ($body -notmatch '(?m)^\s*accTitle:[ \t]*\S') { Add-PageIssue -Code 'diagram-acc' -Page $label -Message 'missing accTitle' }
        if ($body -notmatch '(?m)^\s*accDescr:[ \t]*\S') { Add-PageIssue -Code 'diagram-acc' -Page $label -Message 'missing accDescr' }
        if ($body -match '(?m)^\s*click\s|fa:fa-|%%\{|(?m)^\s*(style|classDef|class|linkStyle)\s') {
            Add-PageIssue -Code 'diagram-portability' -Page $label -Message 'uses click, fa: icons, %%{init or custom style rules'
        }
        $first = (($body -split '\r?\n') | Where-Object { $_.Trim() -ne '' } | Select-Object -First 1)
        if ($first -match '^\s*flowchart\b') {
            $count = Get-FlowchartNodeCount -Body $body
            $limit = Get-NodeLimit -Page $page
            if ($count -gt $limit) { Add-PageIssue -Code 'diagram-size' -Page $label -Message "$count nodes, limit $limit" }
        }
        elseif ($first -match '^\s*sequenceDiagram\b') {
            $messages = @([regex]::Matches($body, '(?m)^\s*\S+\s*(?:-->>|->>|-->|->)\s*\S+\s*:')).Count
            if ($messages -gt 20) { Add-PageIssue -Code 'diagram-size' -Page $label -Message "$messages messages, limit 20" }
        }
        else {
            Add-PageIssue -Code 'diagram-type' -Page $label -Message 'only flowchart and sequenceDiagram are used in these pages'
        }
    }

    # Relative links and anchors.
    $textNoFences = [regex]::Replace($content, '(?ms)^```.*?^```', '')
    foreach ($m in [regex]::Matches($textNoFences, '\[[^\]]*\]\(([^)\s]+)\)')) {
        $target = $m.Groups[1].Value
        if ($target -match '^(https?:|mailto:)') { continue }
        $pathPart = $target
        $anchor = ''
        if ($target.Contains('#')) {
            $pathPart = $target.Substring(0, $target.IndexOf('#'))
            $anchor = $target.Substring($target.IndexOf('#') + 1)
        }
        $resolved = if ($pathPart -eq '') { $pageFull } else { [System.IO.Path]::GetFullPath((Join-Path $pageDir $pathPart)) }
        if (-not (Test-Path -LiteralPath $resolved)) {
            Add-PageIssue -Code 'link-broken' -Page $page -Message "link target not found: $target"
            continue
        }
        if ($anchor -ne '' -and $resolved -like '*.md') {
            if (-not $anchorCache.ContainsKey($resolved)) {
                $anchorCache[$resolved] = Get-PageAnchors -Content (Get-Content -LiteralPath $resolved -Raw)
            }
            if (-not $anchorCache[$resolved].Contains($anchor)) {
                Add-PageIssue -Code 'anchor-broken' -Page $page -Message "anchor not found: $target"
            }
        }
    }

    # Gate IDs and finding tags.
    foreach ($m in [regex]::Matches($content, '\bG(\d+[ab]?)\b')) {
        $id = ('g' + $m.Groups[1].Value)
        $isGroup = ($id -eq 'g1' -and $gateAnchors.Contains('g1a') -and $gateAnchors.Contains('g1b'))
        if (-not $gateAnchors.Contains($id) -and -not $isGroup) {
            Add-PageIssue -Code 'gate-unknown' -Page $page -Message "gate $($m.Value) has no row in gates.md"
        }
    }
    foreach ($m in [regex]::Matches($content, '\b([PT]-\d+)\b')) {
        if (-not $gapTags.Contains($m.Groups[1].Value)) {
            Add-PageIssue -Code 'gap-unknown' -Page $page -Message "finding tag $($m.Groups[1].Value) is not listed in gates.md"
        }
    }

    # Named code: files, functions and bare script names.
    foreach ($m in [regex]::Matches($content, '\b([A-Za-z0-9_.-]+\.(?:ps1|psm1))\b')) {
        if (-not $fileNames.Contains($m.Groups[1].Value)) {
            Add-PageIssue -Code 'code-missing' -Page $page -Message "script or module not found under .appdoc/ or tests/: $($m.Groups[1].Value)"
        }
    }
    foreach ($m in [regex]::Matches($content, '`((?:generate|validate|run|extract|analyze|remediate|ci)-[a-z0-9-]+)`')) {
        if (-not $fileNames.Contains($m.Groups[1].Value + '.ps1')) {
            Add-PageIssue -Code 'code-missing' -Page $page -Message "script not found: $($m.Groups[1].Value).ps1"
        }
    }
    foreach ($m in [regex]::Matches($content, '`((?:Get|Set|Test|Write|Invoke|Protect|Convert|Add)-AppDoc\w+)`')) {
        if (-not $functionNames.Contains($m.Groups[1].Value)) {
            Add-PageIssue -Code 'code-missing' -Page $page -Message "function not found: $($m.Groups[1].Value)"
        }
    }

    # Optional rendering.
    if ($Render -and $blocks.Count -gt 0) {
        $mmdc = Get-Command mmdc -ErrorAction SilentlyContinue
        if (-not $mmdc) {
            Add-PageIssue -Code 'render-unavailable' -Page $page -Message '-Render was given but mmdc is not installed'
        }
        else {
            $i = 0
            foreach ($b in $blocks) {
                $i++
                $tmpIn = Join-Path ([System.IO.Path]::GetTempPath()) ("pd-{0}-{1}.mmd" -f [guid]::NewGuid().ToString('N'), $i)
                $tmpOut = [System.IO.Path]::ChangeExtension($tmpIn, '.svg')
                Set-Content -LiteralPath $tmpIn -Value $b.Groups[1].Value -Encoding utf8
                $mmdcArgs = @('-i', $tmpIn, '-o', $tmpOut)
                if ($env:PUPPETEER_CONFIG) { $mmdcArgs = @('-p', $env:PUPPETEER_CONFIG) + $mmdcArgs }
                $null = & $mmdc.Source @mmdcArgs 2>&1
                if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $tmpOut)) {
                    Add-PageIssue -Code 'render-failed' -Page "$page diagram $i" -Message 'mmdc could not render this diagram'
                }
                Remove-Item -LiteralPath $tmpIn, $tmpOut -Force -ErrorAction SilentlyContinue
            }
        }
    }
}

# The overview diagram is copied into the repository README. The two copies must match.
$readmePath = Join-Path $root 'README.md'
if ((Test-Path -LiteralPath $readmePath) -and $contentByPage.ContainsKey('README.md')) {
    $pipelineBlocks = [regex]::Matches((Get-Content -LiteralPath $readmePath -Raw), '(?ms)^```mermaid\r?\n(.*?)^```\s*$')
    $overviewBlock = [regex]::Match($contentByPage['README.md'], '(?ms)^```mermaid\r?\n(.*?)^```\s*$')
    $found = $false
    foreach ($pb in $pipelineBlocks) {
        if (($pb.Groups[1].Value -replace '\r', '') -ceq ($overviewBlock.Groups[1].Value -replace '\r', '')) { $found = $true }
    }
    if (-not $found) {
        Add-PageIssue -Code 'readme-copy' -Page 'README.md' -Message 'the repository README no longer carries the same overview diagram as docs/pipeline/README.md'
    }
}

# Exit codes: the build, ADR 0003 and gates.md must agree on 0, 1, 2 and 3.
$buildScript = Join-Path $root '.appdoc/scripts/powershell/run-appdoc-build.ps1'
$adrFile = Get-ChildItem -LiteralPath (Join-Path (Join-Path $root 'docs') 'adr') -Filter '0003-*.md' -File -ErrorAction SilentlyContinue | Select-Object -First 1
$expected = @('0', '1', '2', '3')
if (Test-Path -LiteralPath $buildScript) {
    $codes = @([regex]::Matches((Get-Content -LiteralPath $buildScript -Raw), '(?m)\bexit\s+(\d+)\b') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    if (($codes -join ',') -ne ($expected -join ',')) {
        Add-PageIssue -Code 'exit-codes' -Page 'run-appdoc-build.ps1' -Message "build exits with {$($codes -join ', ')}; the pages describe {0, 1, 2, 3}"
    }
}
else {
    Add-PageIssue -Code 'exit-codes' -Page 'run-appdoc-build.ps1' -Message 'build script not found'
}
if ($adrFile) {
    $adrCodes = @([regex]::Matches((Get-Content -LiteralPath $adrFile.FullName -Raw), '(?m)^\s*\|\s*(\d)\s*\|') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
    foreach ($c in $expected) {
        if ($adrCodes -notcontains $c) { Add-PageIssue -Code 'exit-codes' -Page $adrFile.Name -Message "exit code $c is not in the ADR table" }
    }
}
$gateCodes = @([regex]::Matches($gatesContent, '(?m)^\|\s*\*\*(\d)\*\*\s*\|') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique)
foreach ($c in $expected) {
    if ($gateCodes -notcontains $c) { Add-PageIssue -Code 'exit-codes' -Page 'gates.md' -Message "exit code $c is not in the exit-codes table" }
}

if ($issues.Count -gt 0) {
    Write-Host "Pipeline docs gate failed with $($issues.Count) issue(s)." -ForegroundColor Red
    foreach ($i in $issues) { Write-Host (" - {0}" -f $i) -ForegroundColor Yellow }
    exit 1
}

Write-Host ("Pipeline docs gate passed ({0} pages, {1} diagrams)." -f $contentByPage.Count, $diagramCount) -ForegroundColor Green
exit 0
