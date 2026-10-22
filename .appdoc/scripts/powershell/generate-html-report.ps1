#
# generate-html-report.ps1
#
# Purpose: Render the AppDoc markdown artifacts into a SINGLE self-contained,
#          branded HTML report (docs/report.html) in the CMU maroon/gold theme.
#
#          - theme: .appdoc/templates/html/theme.json (override with -ThemePath)
#          - input: the content .md files + evidence-register.md +
#                   verification-appendix.md + index.md (whichever exist)
#          - output: <RootPath>/docs/report.html
#
#          The MD->HTML conversion is a deterministic, line-based parser for the
#          subset AppDoc actually emits: h1-h4, pipe-tables, fenced code blocks
#          (with a language tag), ```mermaid blocks, unordered/ordered lists,
#          blockquotes, and paragraphs. It intentionally does NOT try to be a
#          full CommonMark engine. Deterministic. No network at build time
#          (fonts + Mermaid load from CDN at view time; the file is otherwise
#          self-contained). No LLM.
#
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [string]$ThemePath
)

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }

$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) { Write-Error "docs directory not found: $docsPath"; exit 1 }

$defaultThemePath = Join-Path $PSScriptRoot "..\..\templates\html\theme.json"
if ([string]::IsNullOrWhiteSpace($ThemePath)) { $ThemePath = $defaultThemePath }
if (-not (Test-Path $ThemePath)) { Write-Error "Theme file not found: $ThemePath"; exit 1 }

Write-Host "🎨  Generating styled HTML report (report.html)..." -ForegroundColor Cyan

$theme = Get-Content -LiteralPath $ThemePath -Raw | ConvertFrom-Json -Depth 30
$C = $theme.colors
$F = $theme.fonts
$L = $theme.layout
$M = $theme.masthead
$MermaidCdn = $theme.mermaid.cdn
$GoogleFonts = $F.googleFontsUrl

# --- helpers ------------------------------------------------------------------
function Esc-Html {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $Text = $Text -replace '&','&amp;'
    $Text = $Text -replace '<','&lt;'
    $Text = $Text -replace '>','&gt;'
    return $Text
}
# Light inline-markdown pass applied AFTER html-escaping of the raw text.
function Convert-Inline {
    param([string]$Text)
    if ($null -eq $Text) { return '' }
    $Text = Esc-Html $Text
    # `code`
    $Text = [regex]::Replace($Text, '`([^`]+)`', {
        param($m) $inner = $m.Groups[1].Value -replace '<','&lt;' -replace '>','&gt;'
        "<code>$inner</code>"
    })
    # **bold**
    $Text = [regex]::Replace($Text, '\*\*([^*]+)\*\*', '<strong>$1</strong>')
    # *italic* (not part of the bold above)
    $Text = [regex]::Replace($Text, '(?<!\*)\*([^*\n]+)\*(?!\*)', '<em>$1</em>')
    # [text](url)
    $Text = [regex]::Replace($Text, '\[([^\]]+)\]\(([^)\s]+)\)', {
        param($m) "<a href=`"$($m.Groups[2].Value)`">$($m.Groups[1].Value)</a>"
    })
    return $Text
}
function Get-Anchor {
    param([string]$Text)
    $t = ([string]$Text).Trim().ToLowerInvariant()
    $t = [regex]::Replace($t, '[`*_]', '')
    $t = [regex]::Replace($t, '[^a-z0-9]+', ' ')
    $t = $t -replace '\s+', '-'
    return $t
}

# --- CMU logo SVG (inline) ----------------------------------------------------
$cmuLogoSvg = @'
<svg viewBox="0 0 60 60" xmlns="http://www.w3.org/2000/svg"><g><polygon fill="#6a0032" points="6.24,43.23 47.06,43.23 45.82,45.98 5,45.98"/><polygon fill="#ffc82e" points="35.23,19.01 40.43,19.01 40.01,20.15 35.81,20.15 29.42,34.59 28.28,34.65"/><polygon fill="#ffc82e" points="38.23,26.11 51.14,26.11 55,17.85 54.17,17.24 50.56,25.01 38.72,25.01"/><polygon fill="#ffc82e" points="48.7,29.76 49.77,29.76 45.97,38.35 37.62,42 18.03,42 13.75,38.8 14.16,37.91 18.19,40.86 36.98,40.86 45.42,37.28"/><polygon fill="#ffc82e" points="8.29,28.99 7.78,30.05 16.33,30.05 16.8,28.99"/><polygon fill="#ffc82e" points="9.03,33.99 8.52,35.05 14.07,35.05 14.55,33.99"/><polygon fill="#ffc82e" points="47.18,45.06 48.28,45.06 47.05,47.81 6.35,47.81 6.85,46.71 46.44,46.71"/><polygon fill="#ffc82e" points="12.94,20.27 12.44,21.32 20.32,21.32 20.8,20.27"/><polygon fill="#6a0032" points="14.54,33.99 20.35,33.99 20.66,33.29 7.51,33.29 8.38,31.37 15.73,31.37 16.79,28.99 25.52,28.99 25.89,28.16 6.79,28.16 8.01,25.46 18.39,25.46 20.76,20.27 24.67,20.27 25.04,19.47 11.39,19.47 12.13,17.88 21.8,17.88 22.63,16.02 30.02,12.19 48.61,12.19 53.81,16.02 49.94,24.32 36.99,24.32 39.67,18.31 34.59,18.31 27.61,34.1 32.52,34.1 35.35,27.94 48.55,27.93 44.79,36.57 36.35,40.16 18.41,40.16 13.41,36.43"/></g></svg>
'@

# --- input file order (whichever exist) ---------------------------------------
# WS-3: when the composed 20-section unified master exists, it is the SINGLE
# source for report.html (it already contains all 20 sections, the mermaid
# diagrams, the evidence register, and the verification appendix). Otherwise
# fall back to stitching the per-artifact files (backward compatibility).
$unifiedMaster = Join-Path $docsPath "application-documentation.md"
$usesUnifiedMaster = Test-Path $unifiedMaster

$sourceOrder = @(
    "index.md",
    "start-here.md",
    "overview.md",
    "api-inventory.md",
    "data-model.md",
    "config-catalog.md",
    "build-cookbook.md",
    "test-catalog.md",
    "dependencies-catalog.md",
    "debt-register.md",
    "task-guides.md",
    "architecture-diagram.md",
    "evidence-register.md",
    "verification-appendix.md"
)
if ($usesUnifiedMaster) {
    $sourceFiles = @($unifiedMaster)
    Write-Host "   Using composed unified master (application-documentation.md) as the single report source." -ForegroundColor Gray
}
else {
    $sourceFiles = @($sourceOrder | ForEach-Object { Join-Path $docsPath $_ } | Where-Object { Test-Path $_ })
    if ($sourceFiles.Count -eq 0) {
        Write-Error "No markdown artifacts found to render in: $docsPath"
        exit 1
    }
}

# --- parse one file into (html, toc-entries) ----------------------------------
function Convert-MarkdownFile {
    param([string]$Path)
    $content = Get-Content -LiteralPath $Path -Raw
    $lines = $content -split "`r?`n"

    $html = @()
    $toc = @()   # @{ level; text; anchor }
    $usedAnchors = @{}

    function New-UniqueAnchor {
        param([string]$Base, [hashtable]$Used)
        if ([string]::IsNullOrWhiteSpace($Base)) { $Base = 'section' }
        $candidate = $Base
        $n = 2
        while ($Used.ContainsKey($candidate)) { $candidate = "$Base-$n"; $n++ }
        return $candidate
    }

    $i = 0
    $n = $lines.Count
    while ($i -lt $n) {
        $line = $lines[$i]

        # fenced code / mermaid block
        if ($line -match '^\s*```') {
            $lang = ($line -replace '^\s*```', '').Trim()
            $body = @()
            $i++
            while ($i -lt $n -and ($lines[$i] -notmatch '^\s*```')) { $body += $lines[$i]; $i++ }
            $i++   # closing fence
            $escaped = ($body | ForEach-Object { Esc-Html $_ }) -join "`n"
            if ($lang -ieq 'mermaid') {
                $html += "<pre class=""mermaid"">`n$escaped`n</pre>"
            }
            else {
                $cls = if ($lang) { " class=""language-$lang""" } else { '' }
                $html += "<pre$cls><code>$escaped</code></pre>"
            }
            continue
        }

        # heading
        if ($line -match '^(#{1,6})\s+(.*)$') {
            $level = $matches[1].Length
            $text = $matches[2].Trim()
            if ($level -le 4) {
                $anchor = New-UniqueAnchor -Base (Get-Anchor $text) -Used $usedAnchors
                $usedAnchors[$anchor] = $true
                $html += ("<h{0} id=""{1}"">{2}</h{0}>" -f $level, $anchor, (Convert-Inline $text))
                if ($level -le 3) { $toc += [pscustomobject]@{ level = $level; text = $text; anchor = $anchor } }
            }
            else { $html += ("<h{0}>{1}</h{0}>" -f $level, (Convert-Inline $text)) }
            $i++; continue
        }

        # hr
        if ($line -match '^\s*([-*_])\s*(\1\s*){2,}$') { $html += '<hr>'; $i++; continue }

        # blockquote
        if ($line -match '^\s*>\s?') {
            $q = @()
            while ($i -lt $n -and ($lines[$i] -match '^\s*>\s?')) {
                $q += ([string]$lines[$i] -replace '^\s*>\s?', '')
                $i++
            }
            $qHtml = ($q | ForEach-Object { Convert-Inline ([string]$_) }) -join '<br>'
            $html += "<blockquote><p>$qHtml</p></blockquote>"
            continue
        }

        # table
        if ($line -match '^\s*\|.*\|\s*$' -and $i -lt ($n - 1) -and ($lines[$i + 1] -match '^\s*\|?[\s:|-]+\|?\s*$')) {
            $headerLine = $line
            $i += 2
            $rows = @()
            while ($i -lt $n -and ($lines[$i] -match '^\s*\|.*\|\s*$')) { $rows += $lines[$i]; $i++ }
            $hdrCells = (($headerLine.Trim() -replace '^\|', '' -replace '\|\s*$', '') -split '\|' | ForEach-Object { (Convert-Inline ([string]$_).Trim()) })
            $headHtml = ($hdrCells | ForEach-Object { "<th>$_</th>" }) -join ''
            $bodyHtml = @()
            foreach ($r in $rows) {
                $cells = (($r.Trim() -replace '^\|', '' -replace '\|\s*$', '') -split '\|' | ForEach-Object { (Convert-Inline ([string]$_).Trim()) })
                $bodyHtml += ('<tr>' + (($cells | ForEach-Object { "<td>$_</td>" }) -join '') + '</tr>')
            }
            $html += "<div class=""tablewrap""><table><thead><tr>$headHtml</tr></thead><tbody>" + ($bodyHtml -join '') + "</tbody></table></div>"
            continue
        }

        # unordered list
        if ($line -match '^\s*[-*+]\s+') {
            $items = @()
            while ($i -lt $n -and ($lines[$i] -match '^\s*[-*+]\s+')) {
                $items += ([string]$lines[$i] -replace '^\s*[-*+]\s+', '')
                $i++
            }
            $html += '<ul>' + (($items | ForEach-Object { "<li>$(Convert-Inline ([string]$_))</li>" }) -join '') + '</ul>'
            continue
        }

        # ordered list
        if ($line -match '^\s*\d+\.\s+') {
            $items = @()
            while ($i -lt $n -and ($lines[$i] -match '^\s*\d+\.\s+')) {
                $items += ([string]$lines[$i] -replace '^\s*\d+\.\s+', '')
                $i++
            }
            $html += '<ol>' + (($items | ForEach-Object { "<li>$(Convert-Inline ([string]$_))</li>" }) -join '') + '</ol>'
            continue
        }

        # blank line
        if ([string]::IsNullOrWhiteSpace($line)) { $i++; continue }

        # A lone table-row-shaped line with NO separator row following it (e.g. the
        # composer's honest "Not detected for this framework" placeholder, which only
        # appears on non-classic-ASP targets) is not a real table. The table branch
        # above already failed (no separator follows), so without this guard the
        # paragraph fallback below breaks immediately on the |...| pattern without
        # advancing $i -> infinite loop that hangs report.html generation. Emit the
        # lone row as a single-line paragraph and move on. For a REAL table (a
        # separator row follows) this guard does NOT fire, so table rendering is
        # unchanged.
        if ($line -match '^\s*\|.*\|\s*$' -and (-not $lines[$i + 1] -or $lines[$i + 1] -notmatch '^\s*\|?[\s:|-]+\|?\s*$')) {
            $html += "<p>$(Convert-Inline ([string]$line.Trim()))</p>"
            $i++; continue
        }

        # paragraph (collect until blank/structural)
        $para = @()
        while ($i -lt $n) {
            $pl = $lines[$i]
            if ([string]::IsNullOrWhiteSpace($pl) -or $pl -match '^\s*```' -or $pl -match '^#{1,6}\s' -or $pl -match '^\s*\|.*\|\s*$' -or $pl -match '^\s*[-*+]\s+' -or $pl -match '^\s*\d+\.\s+' -or $pl -match '^\s*>\s?') { break }
            $para += ([string]$pl)
            $i++
        }
        if ($para.Count -gt 0) {
            $html += "<p>$(Convert-Inline ($para -join ' '))</p>"
        }
    }

    return [pscustomobject]@{ html = ($html -join "`n"); toc = $toc }
}

# --- render all files, collect content + TOC ----------------------------------
$contentBlocks = @()
$allToc = @()
foreach ($f in $sourceFiles) {
    $r = Convert-MarkdownFile -Path $f
    $contentBlocks += "<!-- source: $(Split-Path $f -Leaf) -->`n" + $r.html
    $allToc += $r.toc
}
$mainHtml = $contentBlocks -join "`n"

# --- build TOC (h2 top-level, h3 nested), balanced ----------------------------
$tocHtml = @()
$tocHtml += '<ul>'
$openSub = $false
foreach ($t in $allToc) {
    if ($t.level -eq 2) {
        if ($openSub) { $tocHtml += '</ul>'; $openSub = $false }
        $link = "<a data-target=""$($t.anchor)"" href=""#$($t.anchor)"">$(Esc-Html $t.text)</a>"
        $tocHtml += "<li>$link"
    }
    elseif ($t.level -eq 3) {
        if (-not $openSub) { $tocHtml += '<ul>'; $openSub = $true }
        $link = "<a data-target=""$($t.anchor)"" href=""#$($t.anchor)"">$(Esc-Html $t.text)</a>"
        $tocHtml += "<li>$link</li>"
    }
}
if ($openSub) { $tocHtml += '</ul>' }
$tocHtml += '</ul>'
$tocListHtml = $tocHtml -join ''

# --- CSS (parameterized by theme) ---------------------------------------------
$css = @"
:root {
  --primary: $($C.primary);
  --primary-dark: $($C.primaryDark);
  --accent: $($C.accent);
  --accent-soft: $($C.accentSoft);
  --ink: $($C.ink);
  --ink-soft: $($C.inkSoft);
  --line: $($C.line);
  --bg: $($C.bg);
  --card: $($C.card);
  --code-bg: $($C.codeBg);
  --pre-bg: $($C.preBg);
  --pre-fg: $($C.preFg);
  --row-alt: $($C.rowAlt);
  --sidebar-w: $($L.sidebarWidth);
}
* { box-sizing: border-box; }
html { scroll-behavior: smooth; scroll-padding-top: 84px; }
body { margin: 0; font-family: "$($F.body)", "Segoe UI", system-ui, sans-serif; font-size: 15.5px; line-height: 1.65; color: var(--ink); background: var(--bg); }
h1, h2, h3, h4 { font-family: "$($F.heading)", "$($F.body)", sans-serif; font-weight: 700; line-height: 1.2; color: var(--primary); }
header.masthead { position: sticky; top: 0; z-index: 50; display: flex; align-items: center; gap: 14px; background: var(--primary); color: #fff; padding: 12px 24px; border-bottom: 4px solid var(--accent); }
header.masthead .logo { width: 40px; height: 40px; flex: 0 0 auto; background: #fff; border-radius: 50%; display: grid; place-items: center; }
header.masthead .logo svg { width: 30px; height: 30px; }
header.masthead h1 { margin: 0; font-size: 24px; color: #fff; letter-spacing: .3px; }
header.masthead .sub { font-size: 12.5px; color: var(--accent); font-family: "$($F.heading)", sans-serif; text-transform: uppercase; letter-spacing: 1.5px; }
header.masthead .spacer { flex: 1; }
header.masthead a.totop { color: #fff; text-decoration: none; font-size: 13px; border: 1px solid rgba(255,255,255,.4); padding: 5px 12px; border-radius: 4px; }
header.masthead a.totop:hover { background: rgba(255,255,255,.12); }
.layout { display: flex; align-items: flex-start; }
nav.toc { width: var(--sidebar-w); flex: 0 0 auto; position: sticky; top: $($L.mastheadTopOffset); max-height: calc(100vh - $($L.mastheadTopOffset)); overflow-y: auto; padding: 20px 18px 40px 22px; border-right: 1px solid var(--line); background: var(--card); font-size: 13.5px; }
nav.toc .toc-title { font-family: "$($F.heading)", sans-serif; font-size: 15px; text-transform: uppercase; letter-spacing: 1.5px; color: var(--ink-soft); margin: 0 0 8px; }
nav.toc ul { list-style: none; margin: 0; padding: 0; }
nav.toc ul ul { padding-left: 14px; }
nav.toc li { margin: 3px 0; }
nav.toc a { color: var(--ink); text-decoration: none; display: block; padding: 3px 8px; border-radius: 4px; border-left: 3px solid transparent; }
nav.toc a:hover { background: var(--code-bg); color: var(--primary); }
nav.toc a.active { background: var(--accent-soft); color: var(--primary); border-left-color: var(--primary); font-weight: 500; }
main { flex: 1; min-width: 0; padding: 34px 48px 90px; max-width: 1080px; }
main h1 { font-size: 34px; margin: 0 0 6px; }
main h2 { font-size: 27px; margin: 46px 0 14px; padding-bottom: 8px; border-bottom: 2px solid var(--accent); }
main h3 { font-size: 21px; margin: 30px 0 10px; }
main h4 { font-size: 17px; margin: 22px 0 8px; }
main p { margin: 10px 0; }
main a { color: var(--primary); }
main a:hover { color: var(--primary-dark); }
main strong { color: var(--primary-dark); }
main hr { border: 0; border-top: 1px solid var(--line); margin: 28px 0; }
main blockquote { margin: 16px 0; padding: 12px 18px; background: var(--accent-soft); border-left: 4px solid var(--accent); border-radius: 0 6px 6px 0; color: var(--ink); }
main blockquote p { margin: 6px 0; }
main code { font-family: "$($F.monospace)", Consolas, monospace; font-size: 13px; background: var(--code-bg); padding: 2px 6px; border-radius: 4px; color: var(--primary-dark); }
main pre { background: var(--pre-bg); color: var(--pre-fg); padding: 16px 18px; border-radius: 8px; overflow-x: auto; font-size: 13px; line-height: 1.5; }
main pre code { background: none; color: inherit; padding: 0; }
.tablewrap { overflow-x: auto; margin: 16px 0; }
main table { border-collapse: collapse; width: 100%; background: var(--card); font-size: 13.5px; box-shadow: 0 1px 3px rgba(35,31,32,.08); border-radius: 8px; overflow: hidden; }
main th { background: var(--primary); color: #fff; font-family: "$($F.heading)", sans-serif; font-size: 14.5px; letter-spacing: .5px; text-align: left; padding: 9px 12px; }
main td { padding: 8px 12px; border-bottom: 1px solid var(--line); vertical-align: top; }
main tbody tr:nth-child(even) { background: var(--row-alt); }
main tbody tr:hover { background: var(--accent-soft); }
main td code, main th code { white-space: nowrap; }
div.mermaid, pre.mermaid { background: var(--card); border: 1px solid var(--line); border-radius: 8px; padding: 18px; margin: 18px 0; text-align: center; overflow-x: auto; color: var(--ink); }
footer { margin-top: 60px; padding-top: 18px; border-top: 2px solid var(--accent); color: var(--ink-soft); font-size: 13px; }
@media (max-width: 900px) { .layout { flex-direction: column; } nav.toc { position: static; width: 100%; max-height: 300px; border-right: 0; border-bottom: 1px solid var(--line); } main { padding: 24px 20px 60px; } }
@media print { header.masthead, nav.toc { display: none; } main { max-width: none; padding: 0; } }
"@

# --- mermaid init (themed) -----------------------------------------------------
$mermaidScript = @"
// Render Mermaid diagrams (themed to the report palette)
if (window.mermaid) {
  mermaid.initialize({ startOnLoad: true, theme: 'base', themeVariables: {
    primaryColor: '$($C.accentSoft)', primaryBorderColor: '$($C.primary)', primaryTextColor: '$($C.ink)',
    lineColor: '$($C.primary)', secondaryColor: '$($C.codeBg)', tertiaryColor: '$($C.card)',
    actorBkg: '$($C.primary)', actorTextColor: '#ffffff', actorBorder: '$($C.primaryDark)',
    signalColor: '$($C.ink)', signalTextColor: '$($C.ink)',
    noteBkgColor: '$($C.accentSoft)', noteBorderColor: '$($C.accent)',
  }});
}
// Highlight the active TOC entry while scrolling
const tocLinks = Array.from(document.querySelectorAll('nav.toc a[href^="#"]'));
const targets = tocLinks
  .map(a => document.getElementById(a.getAttribute('href').slice(1)))
  .filter(Boolean);
const observer = new IntersectionObserver(entries => {
  for (const e of entries) {
    if (e.isIntersecting) {
      tocLinks.forEach(a => a.classList.toggle('active', a.getAttribute('href') === '#' + e.target.id));
    }
  }
}, { rootMargin: '-80px 0px -70% 0px' });
targets.forEach(el => observer.observe(el));
"@

# --- assemble document ---------------------------------------------------------
$docTitle = Esc-Html ([string]$M.title)
$docSub = Esc-Html ([string]$M.sub)
$generatedAt = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

$doc = @()
$doc += '<!DOCTYPE html>'
$doc += '<html lang="en">'
$doc += '<head>'
$doc += '<meta charset="utf-8">'
$doc += '<meta name="viewport" content="width=device-width, initial-scale=1">'
$doc += "<title>$docTitle</title>"
$doc += '<link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>'
$doc += "<link href=""$GoogleFonts"" rel=""stylesheet"">"
$doc += "<script src=""$MermaidCdn""></script>"
$doc += '<style>'
$doc += $css
$doc += '</style>'
$doc += '</head>'
$doc += '<body>'
$doc += '<header class="masthead">'
$doc += '  <span class="logo" aria-hidden="true">'
$doc += $cmuLogoSvg
$doc += '  </span>'
$doc += '  <div>'
$doc += "    <h1>$docTitle</h1>"
$doc += "    <div class=""sub"">$docSub</div>"
$doc += '  </div>'
$doc += '  <span class="spacer"></span>'
$doc += '  <a class="totop" href="#top">Back to top</a>'
$doc += '</header>'
$doc += '<div class="layout" id="top">'
$doc += '  <nav class="toc" aria-label="Table of contents">'
$doc += '    <div class="toc-title">Contents</div>'
$doc += $tocListHtml
$doc += '  </nav>'
$doc += '  <main>'
$doc += $mainHtml
$sourceLabel = if ($usesUnifiedMaster) { "composed unified master rendered (20-section application-documentation.md)" } else { "$($sourceFiles.Count) markdown artifacts rendered" }
$doc += "<footer>Generated by AppDoc &middot; $generatedAt &middot; $sourceLabel.</footer>"
$doc += '  </main>'
$doc += '</div>'
$doc += '<script>'
$doc += $mermaidScript
$doc += '</script>'
$doc += '</body>'
$doc += '</html>'

$outputPath = Join-Path $docsPath "report.html"
$doc -join "`n" | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$sizeBytes = (Get-Item $outputPath).Length
$lineCount = (Get-Content $outputPath).Count
Write-Host "   Rendered $($sourceFiles.Count) markdown artifacts" -ForegroundColor Gray
Write-Host "✅ HTML report generated: $outputPath ($sizeBytes bytes, $lineCount lines)" -ForegroundColor Green
