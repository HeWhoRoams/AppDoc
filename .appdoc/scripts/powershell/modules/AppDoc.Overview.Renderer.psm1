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

function ConvertTo-AppDocOverviewArray {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) {
        return @()
    }

    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @([string]$Value)
    }

    if ($Value -is [System.Collections.IEnumerable]) {
        $items = @()
        foreach ($entry in $Value) {
            if ($null -ne $entry) {
                $items += $entry
            }
        }
        return @($items)
    }

    return @($Value)
}

function ConvertTo-AppDocOverviewInlineRefList {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]]$EvidenceRefs = @()
    )

    $refs = @(
        $EvidenceRefs |
            Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } |
            ForEach-Object { [string]$_ } |
            Select-Object -Unique
    )

    if ($refs.Count -eq 0) {
        return ""
    }

    return " (evidence: " + (($refs | ForEach-Object { [string]$_ }) -join ", ") + ")"
}

function Get-AppDocOverviewEvidenceRefs {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$TruthPack = $null,
        [string]$Kind = "",
        [string]$Artifact = "",
        [int]$Limit = 4
    )

    $records = @(Get-AppDocOverviewRendererValue -Object $TruthPack -Name "evidence_refs" -Default @())
    $ids = New-Object System.Collections.Generic.List[string]

    foreach ($record in $records) {
        if (-not $record) { continue }
        $recordKind = [string](Get-AppDocOverviewRendererValue -Object $record -Name "kind" -Default "")
        $recordArtifact = [string](Get-AppDocOverviewRendererValue -Object $record -Name "artifact" -Default "")
        $recordId = [string](Get-AppDocOverviewRendererValue -Object $record -Name "id" -Default "")
        if ([string]::IsNullOrWhiteSpace($recordId)) { continue }

        if (-not [string]::IsNullOrWhiteSpace($Kind) -and $recordKind -ne $Kind) { continue }
        if (-not [string]::IsNullOrWhiteSpace($Artifact) -and $recordArtifact -ne $Artifact) { continue }

        if (-not $ids.Contains($recordId)) {
            $ids.Add($recordId) | Out-Null
        }
        if ($ids.Count -ge $Limit) { break }
    }

    return @($ids)
}

function ConvertTo-AppDocOverviewEscapedCell {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) {
        return ""
    }

    return ($text -replace '\|', '\\|')
}

function Set-AppDocOverviewSectionContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$SectionName,
        [Parameter(Mandatory=$true)]
        [string]$SectionContent
    )

    $nl = ($Content -match "\r\n") ? "`r`n" : (( $Content -match "\n" ) ? "`n" : [Environment]::NewLine)
    $headerPattern = "(?im)^##\s+" + [regex]::Escape($SectionName) + "\s*$"
    if ([regex]::IsMatch($Content, $headerPattern)) {
        $pattern = '(?is)(##\s+' + [regex]::Escape($SectionName) + '\s*\r?\n\r?\n).*?(?=(\r?\n##\s+[^\r\n]+|\z))'
        $sectionRegex = [regex]::new($pattern, [System.Text.RegularExpressions.RegexOptions]::Multiline)
        return $sectionRegex.Replace(
            $Content,
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Groups[1].Value + $SectionContent + $nl)
            },
            1
        )
    }

    Write-Warning "$SectionName section header not found. Appending section to end of document."
    return ($Content + $nl + "## $SectionName" + $nl + $nl + $SectionContent + $nl)
}

function Get-AppDocOverviewRendererValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Object,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [AllowNull()]
        [object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Get-AppDocOverviewArchitectureContent {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$TruthPack = $null
    )

    if (-not $TruthPack) {
        return "_Architecture analysis pending. Review code structure and dependencies._"
    }

    $arch = Get-AppDocOverviewRendererValue -Object $TruthPack -Name "architecture" -Default @{}
    $counts = Get-AppDocOverviewRendererValue -Object $TruthPack -Name "counts" -Default @{}
    $style = [string](Get-AppDocOverviewRendererValue -Object $arch -Name "primaryStyle" -Default "unknown")
    $frameworksRaw = Get-AppDocOverviewRendererValue -Object $arch -Name "frameworks" -Default @()
    $frameworks = @(
        ConvertTo-AppDocOverviewArray -Value $frameworksRaw |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )

    $inboundCount = [int](Get-AppDocOverviewRendererValue -Object $counts -Name "inboundEndpoints" -Default 0)
    $outboundCount = [int](Get-AppDocOverviewRendererValue -Object $counts -Name "outboundEndpoints" -Default 0)
    $mappedOutboundCount = [int](Get-AppDocOverviewRendererValue -Object $counts -Name "outboundMappedEndpoints" -Default 0)

    $summaryRefs = @(Get-AppDocOverviewEvidenceRefs -TruthPack $TruthPack -Artifact "overview" -Limit 2)
    $endpointRefs = @(Get-AppDocOverviewEvidenceRefs -TruthPack $TruthPack -Kind "endpoint" -Limit 4)
    $bullets = @()

    if (-not [string]::IsNullOrWhiteSpace($style) -and $style -ne "unknown") {
        $bullets += "- Primary architectural style appears to be $style.$(ConvertTo-AppDocOverviewInlineRefList -EvidenceRefs $summaryRefs)"
    }

    if (($inboundCount + $outboundCount) -gt 0) {
        $bullets += "- API flow includes $inboundCount inbound endpoint(s) and $outboundCount outbound integration endpoint(s).$(ConvertTo-AppDocOverviewInlineRefList -EvidenceRefs $endpointRefs)"
    }

    if ($outboundCount -gt 0) {
        $bullets += "- Outbound URL mapping coverage is $mappedOutboundCount/$outboundCount endpoint(s).$(ConvertTo-AppDocOverviewInlineRefList -EvidenceRefs $endpointRefs)"
    }

    if ($frameworks.Count -gt 0) {
        $bullets += "- Detected framework signals: $($frameworks -join ', ').$(ConvertTo-AppDocOverviewInlineRefList -EvidenceRefs $summaryRefs)"
    }

    if ($bullets.Count -eq 0) {
        return "_Architecture analysis pending. Review code structure and dependencies._"
    }

    return ($bullets -join [Environment]::NewLine)
}

function Get-AppDocOverviewKeyComponentsContent {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$TruthPack = $null
    )

    if (-not $TruthPack) {
        return "_Components not yet cataloged. Scan codebase for module structure._"
    }

    $records = @(Get-AppDocOverviewRendererValue -Object $TruthPack -Name "evidence_refs" -Default @())
    $componentIndex = @{}
    $modelProjectIndex = @{}

    foreach ($record in $records) {
        if (-not $record) { continue }

        $kind = [string](Get-AppDocOverviewRendererValue -Object $record -Name "kind" -Default "")
        $id = [string](Get-AppDocOverviewRendererValue -Object $record -Name "id" -Default "")
        if ([string]::IsNullOrWhiteSpace($id)) { continue }

        if ($kind -eq "endpoint") {
            $metadata = Get-AppDocOverviewRendererValue -Object $record -Name "metadata" -Default @{}
            $controller = [string](Get-AppDocOverviewRendererValue -Object $metadata -Name "controller" -Default "")
            $direction = [string](Get-AppDocOverviewRendererValue -Object $metadata -Name "direction" -Default "")
            $sourceType = [string](Get-AppDocOverviewRendererValue -Object $metadata -Name "sourceType" -Default "")
            $name = [string](Get-AppDocOverviewRendererValue -Object $record -Name "name" -Default "")

            if ([string]::IsNullOrWhiteSpace($controller) -and $name -match '^/soap-client/([^/]+)/') {
                $controller = [string]$Matches[1]
            }
            elseif ([string]::IsNullOrWhiteSpace($controller) -and $name -match '^/([^/]+)/') {
                $controller = [string]$Matches[1]
            }

            if ([string]::IsNullOrWhiteSpace($controller)) { continue }
            $componentName = $controller.Trim()
            if (-not $componentIndex.ContainsKey($componentName)) {
                $category = if ($direction -eq "outbound" -or $sourceType -eq "soap-client") { "Outbound Integration" } else { "Inbound API" }
                $componentIndex[$componentName] = [ordered]@{
                    component = $componentName
                    category = $category
                    count = 0
                    refs = @()
                }
            }

            $entry = $componentIndex[$componentName]
            $entry.count = [int]$entry.count + 1
            if (-not (@($entry.refs) -contains $id)) {
                $entry.refs = @($entry.refs + $id)
            }
        }
        elseif ($kind -eq "model") {
            $source = [string](Get-AppDocOverviewRendererValue -Object $record -Name "source" -Default "")
            if ([string]::IsNullOrWhiteSpace($source)) { continue }
            $pathParts = $source -split '[\\/]'
            if ($pathParts.Count -eq 0) { continue }
            $projectName = [string]$pathParts[0]
            if ([string]::IsNullOrWhiteSpace($projectName)) { continue }

            if (-not $modelProjectIndex.ContainsKey($projectName)) {
                $modelProjectIndex[$projectName] = [ordered]@{
                    component = $projectName
                    category = "Data Model"
                    count = 0
                    refs = @()
                }
            }

            $entry = $modelProjectIndex[$projectName]
            $entry.count = [int]$entry.count + 1
            if (-not (@($entry.refs) -contains $id)) {
                $entry.refs = @($entry.refs + $id)
            }
        }
    }

    $rows = @()
    $rows += @($componentIndex.Values | Sort-Object @{ Expression = { [int]$_.count }; Descending = $true }, @{ Expression = { [string]$_.component }; Descending = $false } | Select-Object -First 6)
    $rows += @($modelProjectIndex.Values | Sort-Object @{ Expression = { [int]$_.count }; Descending = $true }, @{ Expression = { [string]$_.component }; Descending = $false } | Select-Object -First 3)
    $rows = @($rows | Select-Object -First 8)

    if ($rows.Count -eq 0) {
        return "_Components not yet cataloged. Scan codebase for module structure._"
    }

    $lines = @()
    $lines += "The following components appear most frequently in extracted endpoint and model evidence and are likely the highest-impact areas for change planning."
    $lines += ""
    $lines += "| Component | Category | Responsibility | Evidence |"
    $lines += "|---|---|---|---|"

    foreach ($row in $rows) {
        $component = ConvertTo-AppDocOverviewEscapedCell -Value $row.component
        $category = ConvertTo-AppDocOverviewEscapedCell -Value $row.category
        $responsibility = "Observed in $([int]$row.count) record(s)"
        $evidence = @($row.refs | Select-Object -First 3) -join ", "
        $lines += "| $component | $category | $responsibility | $evidence |"
    }

    return ($lines -join [Environment]::NewLine)
}

function Get-AppDocOverviewWelcomeMarkdown {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$WelcomeNarrative = $null
    )

    $sectionOrder = @(
        "what_it_does",
        "inputs",
        "processing_steps",
        "outputs",
        "external_systems",
        "confidence_notes"
    )

    $lines = @("## Welcome")
    foreach ($sectionName in $sectionOrder) {
        $lines += ""
        $lines += "### $sectionName"

        $items = @()
        if ($WelcomeNarrative) {
            $items = @(Get-AppDocOverviewRendererValue -Object $WelcomeNarrative -Name $sectionName -Default @())
        }

        if ($items.Count -eq 0) {
            $lines += "- Evidence for this section is limited in this scan; review linked artifacts and source for additional context."
            continue
        }

        foreach ($item in $items) {
            if (-not $item) { continue }
            $text = [string]$item.text
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            $refs = @($item.evidence_refs)
            $lines += "- $($text.Trim())$(ConvertTo-AppDocOverviewInlineRefList -EvidenceRefs $refs)"
        }
    }

    $lines += ""
    $lines += "### evidence_refs"
    $lines += "| ID | Artifact | Kind | Name | Source |"
    $lines += "|---|---|---|---|---|"

    $evidenceRows = @()
    $evidenceRows = @(Get-AppDocOverviewRendererValue -Object $WelcomeNarrative -Name "evidence_refs" -Default @())

    if ($evidenceRows.Count -eq 0) {
        $lines += "| ev-0000 | overview | summary | none | none |"
    }
    else {
        foreach ($row in $evidenceRows) {
            if (-not $row) { continue }
            $id = [string]$row.id
            $artifact = [string]$row.artifact
            $kind = [string]$row.kind
            $name = [string]$row.name
            $source = [string]$row.source

            if ([string]::IsNullOrWhiteSpace($id)) { continue }
            $safeName = $name -replace '\|', '\\|'
            $safeSource = $source -replace '\|', '\\|'
            $lines += "| $id | $artifact | $kind | $safeName | $safeSource |"
        }
    }

    return (($lines -join [Environment]::NewLine) + [Environment]::NewLine)
}

function Get-AppDocOverviewMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [int]$CodeFileCount,
        [Parameter(Mandatory=$true)]
        [hashtable]$LanguageCount,
        [AllowNull()]
        [object]$TruthPack = $null
    )

    $systemPurposeContent = if ($CodeFileCount -gt 0) {
        "The repository contains $CodeFileCount code files across $($LanguageCount.Keys.Count) language(s) and reflects the implementation surface analyzed in this documentation set. Use this overview for orientation, then move to API, data model, config, build, and dependency artifacts for implementation detail."
    } else {
        "Source inventory was not detected in this scan. Verify repository scope and rerun generation."
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

    $architectureContent = Get-AppDocOverviewArchitectureContent -TruthPack $TruthPack
    $keyComponentsContent = Get-AppDocOverviewKeyComponentsContent -TruthPack $TruthPack

    return [ordered]@{
        systemPurposeContent = $systemPurposeContent
        architectureContent = $architectureContent
        keyComponentsContent = $keyComponentsContent
        techStackContent = $techStackContent
        systemPurposePlaceholder = "_System purpose not yet documented. Analyze README and code structure to determine._"
        architecturePlaceholder = "_Architecture analysis pending. Review code structure and dependencies._"
        keyComponentsPlaceholder = "_Components not yet cataloged. Scan codebase for module structure._"
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
        [hashtable]$LanguageCount,
        [AllowNull()]
        [object]$WelcomeNarrative = $null,
        [AllowNull()]
        [object]$TruthPack = $null
    )

    $sections = Get-AppDocOverviewMarkdown -CodeFileCount $CodeFileCount -LanguageCount $LanguageCount -TruthPack $TruthPack
    $updated = $Content


    $placeholdersFound = $false
    if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
        $before = $updated
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.systemPurposePlaceholder -NewContent $sections.systemPurposeContent
        if ($before -ne $updated) { $placeholdersFound = $true }
        $before = $updated
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.techStackPlaceholder -NewContent $sections.techStackContent
        if ($before -ne $updated) { $placeholdersFound = $true }
        $before = $updated
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.architecturePlaceholder -NewContent $sections.architectureContent
        if ($before -ne $updated) { $placeholdersFound = $true }
        $before = $updated
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.keyComponentsPlaceholder -NewContent $sections.keyComponentsContent
        if ($before -ne $updated) { $placeholdersFound = $true }
    } else {
        $before = $updated
        $updated = $updated.Replace($sections.systemPurposePlaceholder, $sections.systemPurposeContent)
        if ($before -ne $updated) { $placeholdersFound = $true }
        $before = $updated
        $updated = $updated.Replace($sections.techStackPlaceholder, $sections.techStackContent)
        if ($before -ne $updated) { $placeholdersFound = $true }
        $before = $updated
        $updated = $updated.Replace($sections.architecturePlaceholder, $sections.architectureContent)
        if ($before -ne $updated) { $placeholdersFound = $true }
        $before = $updated
        $updated = $updated.Replace($sections.keyComponentsPlaceholder, $sections.keyComponentsContent)
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

    $updated = Set-AppDocOverviewSectionContent -Content $updated -SectionName "Architecture" -SectionContent $sections.architectureContent
    $updated = Set-AppDocOverviewSectionContent -Content $updated -SectionName "Key Components" -SectionContent $sections.keyComponentsContent
    $updated = Set-AppDocOverviewSectionContent -Content $updated -SectionName "Configuration" -SectionContent "Configuration is primarily file-based (`Web.config`, transforms, and project/YAML settings). Use [Configuration Catalog](config-catalog.md) for required keys, environment-sensitive values, and validation guidance."
    $updated = Set-AppDocOverviewSectionContent -Content $updated -SectionName "Getting Started" -SectionContent "Start with [Start Here](start-here.md), then run the minimal command set from [Build Cookbook](build-cookbook.md). After first successful build/test, use [Task Guides](task-guides.md) to execute common maintenance flows safely."

    if ($null -ne $WelcomeNarrative) {
        $welcomeMarkdown = Get-AppDocOverviewWelcomeMarkdown -WelcomeNarrative $WelcomeNarrative
        $hasWelcome = [regex]::IsMatch($updated, '(?im)^##\s+Welcome\b')

        if ($hasWelcome) {
            $welcomeRegex = [regex]::new('(?is)^##\s+Welcome\s*$\r?\n.*?(?=^##\s+[^\r\n]+|\z)', [System.Text.RegularExpressions.RegexOptions]::Multiline)
            $updated = $welcomeRegex.Replace(
                $updated,
                [System.Text.RegularExpressions.MatchEvaluator]{
                    param($m)
                    return $welcomeMarkdown
                },
                1
            )
        }
        elseif ([regex]::IsMatch($updated, '(?im)^##\s+Executive Summary\b')) {
            $executiveSummaryRegex = [regex]::new('(?im)^##\s+Executive Summary\b')
            $updated = $executiveSummaryRegex.Replace(
                $updated,
                [System.Text.RegularExpressions.MatchEvaluator]{
                    param($m)
                    return ($welcomeMarkdown + [Environment]::NewLine + $m.Value)
                },
                1
            )
        }
        else {
            $updated = ($welcomeMarkdown + [Environment]::NewLine + $updated)
        }
    }

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocOverviewWelcomeMarkdown',
    'Get-AppDocOverviewMarkdown',
    'Update-AppDocOverviewContent'
)
