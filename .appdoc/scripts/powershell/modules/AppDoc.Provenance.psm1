#
# AppDoc.Provenance.psm1
#
# The last word on every generated file under docs/:
#   Set-AppDocProvenanceFooter  stamps a "## Provenance" footer on every generated
#                               Markdown file (recursively) and a `provenance` object on
#                               the top-level JSON reports. Idempotent: an existing footer
#                               is replaced, never duplicated, and is always the last
#                               section.
#   Convert-AppDocDocsLineEndings  rewrites generated text files as UTF-8 (no BOM) with LF
#                               line endings and one final newline, matching .gitattributes
#                               (`*.md eol=lf`). On Windows, ConvertTo-Json / Out-File emit
#                               CRLF, so this pass is what makes the output byte-stable
#                               across operating systems.
#
# Hand-authored files that live in docs/ are left alone:
#   - anything under docs/adr/
#   - any file containing the marker  <!-- appdoc:hand-authored -->
#
# Deterministic apart from the wall-clock "Generated At" stamp.
#

$script:AppDocHandAuthoredMarker = '<!-- appdoc:hand-authored -->'
$script:AppDocGeneratorVersion = 'appdoc-run-all-generators/3.0.0'

function Test-AppDocHandAuthoredDoc {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][string]$DocsPath,
        [AllowNull()][string]$Content = $null
    )
    $rel = [System.IO.Path]::GetRelativePath($DocsPath, $Path) -replace '\\', '/'
    if ($rel -match '^adr/') { return $true }
    if ($null -eq $Content) { $Content = Get-Content -LiteralPath $Path -Raw -ErrorAction SilentlyContinue }
    return ([string]$Content).Contains($script:AppDocHandAuthoredMarker)
}

function Get-AppDocProvenanceCommitHash {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$RootPath)
    try {
        $hash = (& git -C $RootPath rev-parse --short HEAD 2>$null | Out-String).Trim()
        if ([string]::IsNullOrWhiteSpace($hash)) { return 'unknown' }
        return $hash
    }
    catch { return 'unknown' }
    finally { $global:LASTEXITCODE = 0 }
}

function Write-AppDocTextFile {
    <#
    .SYNOPSIS
        Writes text as UTF-8 without BOM, LF line endings, exactly one final newline.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$Path,
        [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Content
    )
    $norm = (($Content -replace "`r`n", "`n") -replace "`r", "`n").TrimEnd("`n") + "`n"
    [System.IO.File]::WriteAllText($Path, $norm, [System.Text.UTF8Encoding]::new($false))
}

function Set-AppDocProvenanceFooter {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)][string]$RootPath,
        [Parameter(Mandatory = $true)][string]$DocsPath,
        [string]$Profile = 'default'
    )
    if (-not (Test-Path -LiteralPath $DocsPath)) { return 0 }

    $timestamp = (Get-Date).ToString('yyyy-MM-ddTHH:mm:ssK')
    $commitHash = Get-AppDocProvenanceCommitHash -RootPath $RootPath
    $inferenceFlags = @('deterministic', 'evidence-backed')
    $block = @(
        '## Provenance',
        '',
        "- Generator Version: $($script:AppDocGeneratorVersion)",
        "- Commit Hash: $commitHash",
        "- Generated At: $timestamp",
        "- Profile: $Profile",
        '- Scope: .',
        "- Confidence/Inference Flags: $($inferenceFlags -join ', ')"
    ) -join "`n"

    $stamped = 0
    $markdownFiles = @(Get-ChildItem -LiteralPath $DocsPath -Filter '*.md' -File -Recurse -ErrorAction SilentlyContinue | Sort-Object FullName)
    foreach ($file in $markdownFiles) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        if ($null -eq $content) { $content = '' }
        if (Test-AppDocHandAuthoredDoc -Path $file.FullName -DocsPath $DocsPath -Content $content) { continue }
        $content = $content -replace "`r`n", "`n"
        # Remove every existing Provenance section (wherever it is), then append one at the end.
        $content = [regex]::Replace($content, '(?ms)^##\s+Provenance\s*$.*?(?=^##\s+|\z)', '')
        $content = $content.TrimEnd()
        # A trailing horizontal rule left behind by the removal is dropped as well.
        $content = [regex]::Replace($content, '(?s)\n---\s*\z', '').TrimEnd()
        Write-AppDocTextFile -Path $file.FullName -Content ($content + "`n`n" + $block)
        $stamped++
    }

    # Top-level JSON reports carry a provenance object (evidence/*.json keep their own).
    $provenance = [ordered]@{
        generatorVersion         = $script:AppDocGeneratorVersion
        commitHash               = $commitHash
        generatedAt              = $timestamp
        profile                  = $Profile
        scope                    = '.'
        confidenceInferenceFlags = $inferenceFlags
    }
    foreach ($file in @(Get-ChildItem -LiteralPath $DocsPath -Filter '*.json' -File -ErrorAction SilentlyContinue | Sort-Object FullName)) {
        try {
            $obj = Get-Content -LiteralPath $file.FullName -Raw | ConvertFrom-Json -Depth 120
            if ($obj -is [System.Collections.IDictionary]) { $obj['provenance'] = $provenance }
            elseif ($obj -is [System.Management.Automation.PSCustomObject]) { $obj | Add-Member -NotePropertyName 'provenance' -NotePropertyValue $provenance -Force }
            else { continue }   # arrays: no place for a provenance object
            Write-AppDocTextFile -Path $file.FullName -Content ($obj | ConvertTo-Json -Depth 100)
        }
        catch { Write-Warning ("Skipping provenance for unreadable JSON: {0}" -f $file.FullName) }
    }
    return $stamped
}

function Convert-AppDocDocsLineEndings {
    [CmdletBinding()]
    param([Parameter(Mandatory = $true)][string]$DocsPath)
    if (-not (Test-Path -LiteralPath $DocsPath)) { return 0 }
    $changed = 0
    $files = @(Get-ChildItem -LiteralPath $DocsPath -File -Recurse -Include '*.md', '*.json', '*.html', '*.mmd', '*.puml' -ErrorAction SilentlyContinue | Sort-Object FullName)
    foreach ($f in $files) {
        $bytes = [System.IO.File]::ReadAllBytes($f.FullName)
        $hasBom = ($bytes.Length -ge 3 -and $bytes[0] -eq 0xEF -and $bytes[1] -eq 0xBB -and $bytes[2] -eq 0xBF)
        $text = [System.Text.Encoding]::UTF8.GetString($bytes, $(if ($hasBom) { 3 } else { 0 }), $bytes.Length - $(if ($hasBom) { 3 } else { 0 }))
        if (Test-AppDocHandAuthoredDoc -Path $f.FullName -DocsPath $DocsPath -Content $text) { continue }
        $needs = $hasBom -or $text.Contains("`r") -or -not $text.EndsWith("`n") -or $text.EndsWith("`n`n")
        if (-not $needs) { continue }
        Write-AppDocTextFile -Path $f.FullName -Content $text
        $changed++
    }
    return $changed
}

Export-ModuleMember -Function @(
    'Set-AppDocProvenanceFooter',
    'Convert-AppDocDocsLineEndings',
    'Write-AppDocTextFile',
    'Test-AppDocHandAuthoredDoc'
)
