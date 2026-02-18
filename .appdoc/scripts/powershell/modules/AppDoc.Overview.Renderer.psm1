function Get-AppDocOverviewTechnologyName {
    [CmdletBinding()]
    param([string]$Extension)

    switch ($Extension) {
        ".cs" { return "C# / .NET" }
        ".js" { return "JavaScript" }
        ".ts" { return "TypeScript" }
        ".py" { return "Python" }
        ".java" { return "Java" }
        default { return $Extension }
    }
}

function Get-AppDocOverviewMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$CodeFileCount,
        [Parameter(Mandatory=$true)]
        [hashtable]$LanguageCount
    )

    $systemPurposeContent = if ($CodeFileCount -gt 0) {
        "This codebase contains $CodeFileCount code files across $($LanguageCount.Keys.Count) language(s). Full analysis available in linked documentation."
    } else {
        "_System purpose not yet documented. Analyze README and code structure to determine._"
    }

    $techStackRows = if ($LanguageCount.Keys.Count -gt 0) {
        @(
            $LanguageCount.GetEnumerator() |
                Sort-Object Value -Descending |
                ForEach-Object {
                    "| Language | $(Get-AppDocOverviewTechnologyName -Extension ([string]$_.Key)) | - | Application code |"
                }
        )
    } else {
        @()
    }

    $techStackContent = if ($techStackRows.Count -gt 0) {
        "| Category | Technology | Version | Purpose |`n|----------|-----------|---------|---------|`n" + ($techStackRows -join "`n")
    } else {
        "| Category | Technology | Version | Purpose |`n|----------|-----------|---------|---------|`n`n_Technology stack not yet identified. Analyze package files and code._"
    }

    return [ordered]@{
        systemPurposeContent = $systemPurposeContent
        techStackContent = $techStackContent
        systemPurposePlaceholder = "_System purpose not yet documented. Analyze README and code structure to determine._"
        techStackPlaceholder = "| Category | Technology | Version | Purpose |`r`n|----------|-----------|---------|---------|`r`n`r`n_Technology stack not yet identified. Analyze package files and code._"
    }
}

function Update-AppDocOverviewContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [int]$CodeFileCount,
        [Parameter(Mandatory=$true)]
        [hashtable]$LanguageCount
    )

    $sections = Get-AppDocOverviewMarkdown -CodeFileCount $CodeFileCount -LanguageCount $LanguageCount
    $updated = $Content

    if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.systemPurposePlaceholder -NewContent $sections.systemPurposeContent
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.techStackPlaceholder -NewContent $sections.techStackContent
    } else {
        $updated = $updated.Replace($sections.systemPurposePlaceholder, $sections.systemPurposeContent)
        $updated = $updated.Replace($sections.techStackPlaceholder, $sections.techStackContent)
    }

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+System Purpose\s*\r?\n\r?\n).*?(?=\r?\n##\s+Architecture\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.systemPurposeContent + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Technology Stack\s*\r?\n\r?\n).*?(?=\r?\n##\s+Configuration\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.techStackContent + "`r`n")
        }
    )

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocOverviewMarkdown',
    'Update-AppDocOverviewContent'
)
