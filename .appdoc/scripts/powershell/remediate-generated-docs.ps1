param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

$helpersPath = Join-Path $PSScriptRoot "template-helpers.ps1"
if (Test-Path $helpersPath) {
    . $helpersPath
}

$docsPath = Join-Path $RootPath "docs"
if (-not (Test-Path $docsPath)) {
    Write-Error "docs directory not found: $docsPath"
    exit 1
}

$docFiles = @(
    "start-here.md",
    "overview.md",
    "api-inventory.md",
    "data-model.md",
    "config-catalog.md",
    "build-cookbook.md",
    "test-catalog.md",
    "task-guides.md",
    "debt-register.md",
    "dependencies-catalog.md"
) | ForEach-Object { Join-Path $docsPath $_ } | Where-Object { Test-Path $_ }

if ($docFiles.Count -eq 0) {
    Write-Host "No generated docs found to remediate." -ForegroundColor Yellow
    exit 0
}

function Get-AppDocArtifactFromDocFile {
    param(
        [Parameter(Mandatory=$true)]
        [string]$DocFileName
    )

    switch -Regex ($DocFileName.ToLowerInvariant()) {
        '^start-here\.md$' { return 'start-here' }
        '^overview\.md$' { return 'overview' }
        '^api-inventory\.md$' { return 'api-inventory' }
        '^data-model\.md$' { return 'data-model' }
        '^config-catalog\.md$' { return 'config-catalog' }
        '^build-cookbook\.md$' { return 'build-cookbook' }
        '^test-catalog\.md$' { return 'test-catalog' }
        '^task-guides\.md$' { return 'task-guides' }
        '^debt-register\.md$' { return 'debt-register' }
        '^dependencies-catalog\.md$' { return 'dependencies-catalog' }
        default { return $null }
    }
}

function Add-AppDocEvidenceTraceabilitySection {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Markdown,
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$DocFileName
    )

    $artifact = Get-AppDocArtifactFromDocFile -DocFileName $DocFileName
    if (-not $artifact) { return $Markdown }

    $evidencePath = Join-Path (Join-Path (Join-Path $RootPath 'docs') 'evidence') ("{0}.evidence.json" -f $artifact)
    if (-not (Test-Path $evidencePath)) { return $Markdown }

    try {
        $evidence = Get-Content -Path $evidencePath -Raw | ConvertFrom-Json
    }
    catch {
        return $Markdown
    }

    $recordCount = if ($evidence.recordCount -ne $null) { [int]$evidence.recordCount } else { @($evidence.records).Count }
    $generator = if ($evidence.metadata -and $evidence.metadata.generator) { [string]$evidence.metadata.generator } else { 'unknown' }
    $requiredKeys = if ($evidence.metadata -and $evidence.metadata.requiredEvidenceKeys) { @($evidence.metadata.requiredEvidenceKeys) -join ', ' } else { 'N/A' }

    $relativeEvidencePath = "evidence/{0}.evidence.json" -f $artifact
    $traceabilitySection = @"

## Evidence Traceability

| Field | Value |
|------|-------|
| Evidence Artifact | $relativeEvidencePath |
| Record Count | $recordCount |
| Generator | $generator |
| Required Evidence Keys | $requiredKeys |
| Grounding Mode | Deterministic extraction records |
"@

    $updated = [regex]::Replace($Markdown, '(?is)\r?\n##\s+Evidence Traceability\s*\r?\n.*?(?=\r?\n##\s+|\r?\n---\s*\r?\n|\z)', "")

    if ($updated -match '(?m)^---\s*$') {
        return [regex]::Replace($updated, '(?m)^---\s*$', ($traceabilitySection + "`r`n---"), 1)
    }

    return ($updated.TrimEnd() + $traceabilitySection + "`r`n`r`n---")
}

function Protect-AppDocSensitiveMarkdown {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Markdown
    )

    $lines = $Markdown -split "`r?`n"
    $outputLines = New-Object System.Collections.Generic.List[string]

    foreach ($line in $lines) {
        if ($line -notmatch '^\|') {
            [void]$outputLines.Add($line)
            continue
        }

        $trimmed = $line.Trim()
        if ($trimmed -match '^\|\s*[-:]+\s*(\|\s*[-:]+\s*)+\|$') {
            [void]$outputLines.Add($line)
            continue
        }

        $parts = $line -split '\|', -1
        if ($parts.Count -lt 4) {
            [void]$outputLines.Add($line)
            continue
        }

        $cells = @()
        for ($i = 1; $i -lt ($parts.Count - 1); $i++) {
            $cells += $parts[$i].Trim()
        }

        if ($cells.Count -lt 2) {
            [void]$outputLines.Add($line)
            continue
        }

        $keyCell = ($cells[0] -replace '`', '')
        $typeCell = if ($cells.Count -ge 2) { ($cells[1] -replace '`', '') } else { '' }
        $isSensitive = ($keyCell -match '(?i)password|passwd|pwd|secret|token|api[_-]?key|client[_-]?secret|private[_-]?key|connection\s*string' -or
                       $typeCell -match '(?i)connection\s*string')

        $defaultIndex = -1
        if ($cells.Count -ge 6) {
            $defaultIndex = 2
        }
        elseif ($cells.Count -ge 5) {
            $defaultIndex = 1
        }

        if ($defaultIndex -ge 0 -and $defaultIndex -lt $cells.Count) {
            $defaultCellRaw = ($cells[$defaultIndex] -replace '`', '')
            $hasInlineCredentials = ($defaultCellRaw -match '://[^/\s:@]+:[^/\s@]+@')
            if ($isSensitive -or $hasInlineCredentials) {
                $cells[$defaultIndex] = '`[REDACTED]`'
            }
        }

        $normalizedRow = '| ' + ($cells -join ' | ') + ' |'
        [void]$outputLines.Add($normalizedRow)
    }

    return ($outputLines -join "`r`n")
}

foreach ($file in $docFiles) {
    $content = Get-Content -Path $file -Raw
    $fileName = [System.IO.Path]::GetFileName($file)

    $content = [regex]::Replace($content, '(?is)\r?\n##\s+Population Guide\s*\r?\n.*?(?=\r?\n---\s*\r?\n|\z)', "`r`n")
    if (Get-Command Normalize-AppDocTemplateInstructionText -ErrorAction SilentlyContinue) {
        $content = Normalize-AppDocTemplateInstructionText -Content $content
    }

    $content = [regex]::Replace($content, '(?im)^\s*_No\s+[^_]+(?:detected|available|documented)\.[^_]*_\s*$', 'No deterministic evidence found in this section for the current scan.')
    $content = [regex]::Replace($content, '(?im)(No deterministic evidence found in this section for the current scan\.)(##\s+)', "$1`r`n`r`n$2")

    if ($fileName -ieq 'config-catalog.md') {
        $content = Protect-AppDocSensitiveMarkdown -Markdown $content
    }

    $content = Add-AppDocEvidenceTraceabilitySection -Markdown $content -RootPath $RootPath -DocFileName $fileName

    $content = [regex]::Replace($content, '(?im)^\s*\*\*Generated by AppDoc Framework\*\*\s*$', '**Generated by AppDoc Framework**')
    $content = [regex]::Replace($content, '(?s)(\r?\n){3,}', "`r`n`r`n")

    $content | Out-File -FilePath $file -Encoding UTF8 -NoNewline
}

Write-Host "Remediation complete. Updated $($docFiles.Count) documentation files." -ForegroundColor Green
