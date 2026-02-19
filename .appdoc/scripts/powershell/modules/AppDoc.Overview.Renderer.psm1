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

    $nl = [Environment]::NewLine
    $techStackContent = if ($techStackRows.Count -gt 0) {
        "| Category | Technology | Version | Purpose |$nl|----------|-----------|---------|---------|$nl" + ($techStackRows -join $nl)
    } else {
        "| Category | Technology | Version | Purpose |${nl}|----------|-----------|---------|---------|${nl}${nl}_Technology stack not yet identified. Analyze package files and code._"
    }

    return [ordered]@{
        systemPurposeContent = $systemPurposeContent
        techStackContent = $techStackContent
        systemPurposePlaceholder = "_System purpose not yet documented. Analyze README and code structure to determine._"
        techStackPlaceholder = "| Category | Technology | Version | Purpose |${nl}|----------|-----------|---------|---------|${nl}${nl}_Technology stack not yet identified. Analyze package files and code._"
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


    $placeholdersFound = $false
    if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
        $before = $updated
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.systemPurposePlaceholder -NewContent $sections.systemPurposeContent
        if ($before -ne $updated) { $placeholdersFound = $true }
        $before = $updated
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.techStackPlaceholder -NewContent $sections.techStackContent
        if ($before -ne $updated) { $placeholdersFound = $true }
    } else {
        $before = $updated
        $updated = $updated.Replace($sections.systemPurposePlaceholder, $sections.systemPurposeContent)
        if ($before -ne $updated) { $placeholdersFound = $true }
        $before = $updated
        $updated = $updated.Replace($sections.techStackPlaceholder, $sections.techStackContent)
        if ($before -ne $updated) { $placeholdersFound = $true }
    }

    # Only run regex-based section replacement if placeholders were not found/applied

    if (-not $placeholdersFound) {
        # Detect line ending style from $updated
        $nl = ($updated -match "\r\n") ? "`r`n" : (( $updated -match "\n" ) ? "`n" : [Environment]::NewLine)

        # System Purpose section replacement or append (regex fallback)
        $sysPurposeHeaderPattern = '##\s+System Purpose\s*\r?\n\r?\n'
        $sysPurposeReplacePattern = '(?s)(##\s+System Purpose\s*\r?\n\r?\n).*?(?=(\r?\n##\s+Architecture\b|$))'
        if ($updated -match $sysPurposeHeaderPattern) {
            $updated = [regex]::Replace(
                $updated,
                $sysPurposeReplacePattern,
                [System.Text.RegularExpressions.MatchEvaluator]{
                    param($m)
                    $nl = ($m.Input -match "\r\n") ? "`r`n" : (( $m.Input -match "\n" ) ? "`n" : [Environment]::NewLine)
                    return ($m.Groups[1].Value + $sections.systemPurposeContent + $nl)
                }
            )
        } else {
            Write-Warning "System Purpose section header not found. Appending section to end of document."
            $updated += $nl + "## System Purpose" + $nl + $nl + $sections.systemPurposeContent + $nl
        }

        # Technology Stack section replacement or append (regex fallback)
        $techStackHeaderPattern = '##\s+Technology Stack\s*\r?\n\r?\n'
        $techStackReplacePattern = '(?s)(##\s+Technology Stack\s*\r?\n\r?\n).*?(?=(\r?\n##\s+Configuration\b|$))'
        if ($updated -match $techStackHeaderPattern) {
            $updated = [regex]::Replace(
                $updated,
                $techStackReplacePattern,
                [System.Text.RegularExpressions.MatchEvaluator]{
                    param($m)
                    $nl = ($m.Input -match "\r\n") ? "`r`n" : (( $m.Input -match "\n" ) ? "`n" : [Environment]::NewLine)
                    return ($m.Groups[1].Value + $sections.techStackContent + $nl)
                }
            )
        } else {
            Write-Warning "Technology Stack section header not found. Appending section to end of document."
            $updated += $nl + "## Technology Stack" + $nl + $nl + $sections.techStackContent + $nl
        }
    }

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocOverviewMarkdown',
    'Update-AppDocOverviewContent'
)
