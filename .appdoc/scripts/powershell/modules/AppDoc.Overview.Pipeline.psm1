# AppDoc.Overview.Pipeline Module
# Purpose: Execute a persisted, multi-pass narrative workflow on top of deterministic context.

$script:AppDocOverviewPipelineVersion = "1.1.0"

# Ensure AppDoc.Overview.Narrative.psm1 is loaded for deterministic narrative helpers.
$script:AppDocOverviewNarrativeModule = Join-Path $PSScriptRoot "AppDoc.Overview.Narrative.psm1"
if (Test-Path $script:AppDocOverviewNarrativeModule) {
    Import-Module $script:AppDocOverviewNarrativeModule -Force -ErrorAction Stop
}

function Get-AppDocOverviewPipelineValue {
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
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Get-AppDocOverviewDefaultSectionEvidenceMap {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$ContextPack
    )

    $defaults = Get-AppDocOverviewPipelineValue -Object $ContextPack -Name "section_evidence_defaults" -Default @{}
    $map = [ordered]@{}
    foreach ($section in @("what_it_does","inputs","processing_steps","outputs","external_systems","confidence_notes")) {
        $refs = @(
            Get-AppDocOverviewPipelineValue -Object $defaults -Name $section -Default @() |
                ForEach-Object { [string]$_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )
        $map[$section] = $refs
    }
    return $map
}

function Get-AppDocOverviewDeterministicPass1 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$ContextPack
    )

    $sectionEvidenceMap = Get-AppDocOverviewDefaultSectionEvidenceMap -ContextPack $ContextPack
    $outline = [ordered]@{
        overview = "Deterministic orientation synthesized from extracted architecture, API, model, config, and dependency evidence."
        what_it_does = "Summarize core business behavior inferred from API/domain evidence."
        inputs = "Summarize primary inputs from request and configuration evidence."
        processing_steps = "Summarize main internal processing flow from controllers/services/models."
        outputs = "Summarize response/output behavior from endpoint and model evidence."
        external_systems = "Summarize integration and dependency touchpoints."
        confidence_notes = "Summarize evidence coverage and known confidence limits."
    }

    return [ordered]@{
        section_evidence_map = $sectionEvidenceMap
        outline = $outline
        missing_evidence = @()
        provider = "deterministic"
    }
}

function Test-AppDocOverviewPass1Shape {
    [CmdletBinding()]
    param([AllowNull()][object]$Pass1Result)

    if (-not $Pass1Result) { return $false }
    $map = Get-AppDocOverviewPipelineValue -Object $Pass1Result -Name "section_evidence_map" -Default $null
    $outline = Get-AppDocOverviewPipelineValue -Object $Pass1Result -Name "outline" -Default $null
    if (-not $map -or -not $outline) { return $false }

    foreach ($section in @("what_it_does","inputs","processing_steps","outputs","external_systems","confidence_notes")) {
        $mapVal = Get-AppDocOverviewPipelineValue -Object $map -Name $section -Default $null
        $outlineVal = Get-AppDocOverviewPipelineValue -Object $outline -Name $section -Default ""
        if ($null -eq $mapVal -or [string]::IsNullOrWhiteSpace([string]$outlineVal)) {
            return $false
        }
    }

    return $true
}

function Test-AppDocOverviewSectionEvidenceCoverage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Narrative,
        [Parameter(Mandatory=$true)]
        [object]$SectionEvidenceMap
    )

    $issues = @()
    foreach ($section in @("what_it_does","inputs","processing_steps","outputs","external_systems","confidence_notes")) {
        $expectedRefs = @(
            Get-AppDocOverviewPipelineValue -Object $SectionEvidenceMap -Name $section -Default @() |
                ForEach-Object { [string]$_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )

        if ($expectedRefs.Count -eq 0) { continue }
        $items = @(Get-AppDocOverviewPipelineValue -Object $Narrative -Name $section -Default @())
        $actualRefs = @()
        foreach ($item in $items) {
            $actualRefs += @(
                Get-AppDocOverviewPipelineValue -Object $item -Name "evidence_refs" -Default @() |
                    ForEach-Object { [string]$_ } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
            )
        }
        $actualRefs = @($actualRefs | Select-Object -Unique)
        if ($actualRefs.Count -eq 0) {
            $issues += "section-missing-evidence:$section"
            continue
        }

        $intersection = @($actualRefs | Where-Object { $expectedRefs -contains $_ })
        if ($intersection.Count -eq 0) {
            $issues += "section-evidence-mismatch:$section"
        }
    }

    return [ordered]@{
        passed = ($issues.Count -eq 0)
        issues = @($issues | Select-Object -Unique)
    }
}

function Test-AppDocOverviewNarrativeStyleQuality {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Narrative
    )

    $sectionTexts = [ordered]@{}
    $texts = @()
    foreach ($section in @("what_it_does","inputs","processing_steps","outputs","external_systems","confidence_notes")) {
        $sectionTexts[$section] = @()
        $items = @(Get-AppDocOverviewPipelineValue -Object $Narrative -Name $section -Default @())
        foreach ($item in $items) {
            $text = [string](Get-AppDocOverviewPipelineValue -Object $item -Name "text" -Default "")
            if (-not [string]::IsNullOrWhiteSpace($text)) {
                $clean = $text.Trim()
                $sectionTexts[$section] = @($sectionTexts[$section] + $clean)
                $texts += $clean
            }
        }
    }

    if ($texts.Count -eq 0) {
        return [ordered]@{
            passed = $false
            issues = @("style-empty-narrative")
            metrics = [ordered]@{
                textItemCount = 0
                inventoryLeadCount = 0
                countOnlySentenceCount = 0
                businessVerbHits = 0
                whatItDoesMetricLeadCount = 0
                whatItDoesPurposeVerbHits = 0
                numericDensity = 0.0
            }
        }
    }

    $joined = ($texts -join " ")
    $words = @($joined -split '\s+' | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
    $totalWords = [Math]::Max(1, $words.Count)
    $digitWordCount = @($words | Where-Object { $_ -match '\d' }).Count
    $numericDensity = [Math]::Round(($digitWordCount / $totalWords), 4)

    $inventoryLeadPattern = '(?i)^\s*(the application|it|this application|this codebase)\s+(exposes|contains|operates on|uses)\s+\d+'
    $countOnlyPattern = '(?i)\b(exposes|contains|operates on|uses)\s+\d+\b'
    $businessVerbPattern = '(?i)\b(manage|process|evaluate|audit|assign|generate|validate|integrate|track|report|enforce|orchestrate|support|calculate|determine|store|retrieve|update|advis|plan|approve)\w*\b'
    $purposeVerbPattern = '(?i)\b(help|allow|enable|provide|support|manage|process|evaluate|calculate|determine|assign|track|integrate|report|validate|orchestrate)\w*\b'

    $inventoryLeadCount = 0
    $countOnlySentenceCount = 0
    foreach ($text in $texts) {
        if ($text -match $inventoryLeadPattern) {
            $inventoryLeadCount++
        }
        if ($text -match $countOnlyPattern) {
            $countOnlySentenceCount++
        }
    }

    $businessVerbHits = ([regex]::Matches($joined, $businessVerbPattern)).Count
    $whatItDoesTexts = @($sectionTexts["what_it_does"])
    $whatItDoesMetricLeadCount = 0
    foreach ($text in $whatItDoesTexts) {
        if ($text -match $inventoryLeadPattern) {
            $whatItDoesMetricLeadCount++
        }
    }
    $whatItDoesPurposeVerbHits = ([regex]::Matches(($whatItDoesTexts -join " "), $purposeVerbPattern)).Count

    $issues = @()
    if ($inventoryLeadCount -gt 1) {
        $issues += "style-inventory-lead-overuse:$inventoryLeadCount"
    }
    if ($countOnlySentenceCount -gt 2) {
        $issues += "style-count-only-overuse:$countOnlySentenceCount"
    }
    if ($businessVerbHits -lt 2) {
        $issues += "style-business-verb-coverage-low:$businessVerbHits"
    }
    if ($whatItDoesMetricLeadCount -gt 0) {
        $issues += "style-what-it-does-metric-led:$whatItDoesMetricLeadCount"
    }
    if ($whatItDoesPurposeVerbHits -lt 1) {
        $issues += "style-what-it-does-purpose-verb-low:$whatItDoesPurposeVerbHits"
    }
    if ($numericDensity -gt 0.09) {
        $issues += "style-numeric-density-high:$numericDensity"
    }

    return [ordered]@{
        passed = ($issues.Count -eq 0)
        issues = @($issues)
        metrics = [ordered]@{
            textItemCount = $texts.Count
            inventoryLeadCount = $inventoryLeadCount
            countOnlySentenceCount = $countOnlySentenceCount
            businessVerbHits = $businessVerbHits
            whatItDoesMetricLeadCount = $whatItDoesMetricLeadCount
            whatItDoesPurposeVerbHits = $whatItDoesPurposeVerbHits
            numericDensity = $numericDensity
        }
    }
}

function ConvertTo-AppDocOverviewNarrativeMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$Narrative
    )

    $lines = @()
    foreach ($section in @("what_it_does","inputs","processing_steps","outputs","external_systems","confidence_notes")) {
        $lines += "### $section"
        $items = @(Get-AppDocOverviewPipelineValue -Object $Narrative -Name $section -Default @())
        if ($items.Count -eq 0) {
            $lines += ""
            $lines += "No grounded narrative content generated for this section."
            $lines += ""
            continue
        }

        foreach ($item in $items) {
            $text = [string](Get-AppDocOverviewPipelineValue -Object $item -Name "text" -Default "")
            $refs = @(
                Get-AppDocOverviewPipelineValue -Object $item -Name "evidence_refs" -Default @() |
                    ForEach-Object { [string]$_ } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )

            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            $line = $text.Trim()
            if ($refs.Count -gt 0) {
                $line += " (evidence: " + ($refs -join ", ") + ")"
            }
            $lines += ""
            $lines += $line
            $lines += ""
        }
    }

    return ($lines -join [Environment]::NewLine)
}

function Write-AppDocOverviewNarrativeArtifacts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [object]$Pass1Result,
        [Parameter(Mandatory=$true)]
        [object]$Pass2Narrative,
        [Parameter(Mandatory=$true)]
        [object]$Pass3ReviewNotes,
        [Parameter(Mandatory=$true)]
        [object]$FinalNarrative,
        [Parameter(Mandatory=$true)]
        [object]$RunReport
    )

    $artifactDir = Join-Path $RootPath (Join-Path "docs" (Join-Path "evidence" "narrative"))
    if (-not (Test-Path $artifactDir)) {
        New-Item -Path $artifactDir -ItemType Directory -Force | Out-Null
    }

    $pass1Path = Join-Path $artifactDir "purpose_model.json"
    $pass2Path = Join-Path $artifactDir "narrative_draft.md"
    $pass3Path = Join-Path $artifactDir "review_notes.json"
    $finalPath = Join-Path $artifactDir "narrative_final.json"
    $runReportPath = Join-Path $RootPath (Join-Path "docs" (Join-Path "evidence" "narrative-run-report.json"))

    $compactPass1 = [ordered]@{
        outline = (Get-AppDocOverviewPipelineValue -Object $Pass1Result -Name "outline" -Default @{})
        section_evidence_map = [ordered]@{}
        missing_evidence = @(
            Get-AppDocOverviewPipelineValue -Object $Pass1Result -Name "missing_evidence" -Default @() |
                ForEach-Object { [string]$_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )
        provider = [string](Get-AppDocOverviewPipelineValue -Object $Pass1Result -Name "provider" -Default "deterministic")
    }
    $sectionEvidenceMap = Get-AppDocOverviewPipelineValue -Object $Pass1Result -Name "section_evidence_map" -Default @{}
    foreach ($section in @("what_it_does","inputs","processing_steps","outputs","external_systems","confidence_notes")) {
        $refs = @(
            Get-AppDocOverviewPipelineValue -Object $sectionEvidenceMap -Name $section -Default @() |
                ForEach-Object { [string]$_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique |
                Select-Object -First 20
        )
        $compactPass1.section_evidence_map[$section] = $refs
    }

    function New-AppDocOverviewCompactNarrative {
        param(
            [Parameter(Mandatory=$true)]
            [object]$Narrative
        )

        $maxItemsPerSection = 4
        $maxRefsPerItem = 8
        $maxEvidenceRefs = 120

        $compact = [ordered]@{}
        $usedRefs = New-Object System.Collections.Generic.HashSet[string]

        foreach ($section in @("what_it_does","inputs","processing_steps","outputs","external_systems","confidence_notes")) {
            $items = @(Get-AppDocOverviewPipelineValue -Object $Narrative -Name $section -Default @())
            $normalized = @()
            foreach ($item in ($items | Select-Object -First $maxItemsPerSection)) {
                $text = [string](Get-AppDocOverviewPipelineValue -Object $item -Name "text" -Default "")
                if ([string]::IsNullOrWhiteSpace($text)) { continue }
                $refs = @(
                    Get-AppDocOverviewPipelineValue -Object $item -Name "evidence_refs" -Default @() |
                        ForEach-Object { [string]$_ } |
                        Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                        Select-Object -Unique |
                        Select-Object -First $maxRefsPerItem
                )
                foreach ($refId in $refs) { [void]$usedRefs.Add($refId) }
                $normalized += [ordered]@{
                    text = $text.Trim()
                    evidence_refs = $refs
                }
            }
            $compact[$section] = @($normalized)
        }

        $refMap = @{}
        foreach ($ref in @(Get-AppDocOverviewPipelineValue -Object $Narrative -Name "evidence_refs" -Default @())) {
            $id = [string](Get-AppDocOverviewPipelineValue -Object $ref -Name "id" -Default "")
            if ([string]::IsNullOrWhiteSpace($id)) { continue }
            if (-not $refMap.ContainsKey($id)) { $refMap[$id] = $ref }
        }

        $compactRefs = @()
        foreach ($id in @($usedRefs | Select-Object -First $maxEvidenceRefs)) {
            if ($refMap.ContainsKey($id)) {
                $ref = $refMap[$id]
                $compactRefs += [ordered]@{
                    id = [string](Get-AppDocOverviewPipelineValue -Object $ref -Name "id" -Default "")
                    artifact = [string](Get-AppDocOverviewPipelineValue -Object $ref -Name "artifact" -Default "")
                    kind = [string](Get-AppDocOverviewPipelineValue -Object $ref -Name "kind" -Default "")
                    name = [string](Get-AppDocOverviewPipelineValue -Object $ref -Name "name" -Default "")
                    source = [string](Get-AppDocOverviewPipelineValue -Object $ref -Name "source" -Default "")
                }
            }
        }
        $compact["evidence_refs"] = $compactRefs
        return $compact
    }

    $compactPass2 = New-AppDocOverviewCompactNarrative -Narrative $Pass2Narrative
    $compactFinal = New-AppDocOverviewCompactNarrative -Narrative $FinalNarrative

    $compactPass1 | ConvertTo-Json -Depth 12 | Out-File -FilePath $pass1Path -Encoding UTF8
    (ConvertTo-AppDocOverviewNarrativeMarkdown -Narrative $compactPass2) | Out-File -FilePath $pass2Path -Encoding UTF8
    $Pass3ReviewNotes | ConvertTo-Json -Depth 12 | Out-File -FilePath $pass3Path -Encoding UTF8
    $compactFinal | ConvertTo-Json -Depth 12 | Out-File -FilePath $finalPath -Encoding UTF8
    $RunReport | ConvertTo-Json -Depth 20 | Out-File -FilePath $runReportPath -Encoding UTF8

    return [ordered]@{
        pass1 = $pass1Path
        pass2 = $pass2Path
        pass3 = $pass3Path
        final = $finalPath
        runReport = $runReportPath
    }
}

function Get-AppDocOverviewWelcomeNarrativeFromPipeline {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [object]$TruthPack,
        [Parameter(Mandatory=$true)]
        [object]$ContextPack,
        [ValidateSet("new_dev","senior_dev","sre")]
        [string]$Audience = "new_dev",
        [ValidateSet("concise","standard","pedagogical")]
        [string]$StyleProfile = "standard"
    )


    $startedAt = Get-Date
    $model = "deterministic-local"
    # Compatibility: normalize model identifier for downstream consumers
    $normalizedModel = if ($model -eq 'deterministic-local') { 'local-deterministic' } else { $model }

    $pass1Source = "deterministic"
    $pass1Result = Get-AppDocOverviewDeterministicPass1 -ContextPack $ContextPack
    $deterministicNarrative = Get-AppDocOverviewDeterministicWelcomeNarrative -TruthPack $TruthPack
    $pass2Source = "deterministic"
    $pass2Narrative = $deterministicNarrative

    $pass3Source = "deterministic"
    $reviewNotes = [ordered]@{
        notes = @(
            [ordered]@{
                severity = "info"
                message = "Deterministic narrative retained."
            }
        )
    }
    $finalNarrative = $pass2Narrative

    $groundingVerification = Test-AppDocOverviewNarrativeGrounding -Narrative $finalNarrative -TruthPack $TruthPack
    $sectionEvidenceMap = Get-AppDocOverviewPipelineValue -Object $pass1Result -Name "section_evidence_map" -Default @{}
    $sectionCoverage = Test-AppDocOverviewSectionEvidenceCoverage -Narrative $finalNarrative -SectionEvidenceMap $sectionEvidenceMap
    $styleGate = Test-AppDocOverviewNarrativeStyleQuality -Narrative $finalNarrative

    $narrativeReviewRequired = (-not $groundingVerification.passed) -or (-not $sectionCoverage.passed) -or (-not $styleGate.passed)

    $endedAt = Get-Date
    $runReport = [ordered]@{
        pipelineVersion = $script:AppDocOverviewPipelineVersion
        startedAt = $startedAt.ToString("yyyy-MM-ddTHH:mm:ssK")
        endedAt = $endedAt.ToString("yyyy-MM-ddTHH:mm:ssK")
        durationMs = [Math]::Round(($endedAt - $startedAt).TotalMilliseconds, 0)
        model = $normalizedModel
        executionMode = $normalizedModel
        externalModelCalls = $false
        audience = $Audience
        styleProfile = $StyleProfile
        passSources = [ordered]@{
            pass1 = $pass1Source
            pass2 = $pass2Source
            pass3 = $pass3Source
        }
        grounding = $groundingVerification
        sectionCoverage = $sectionCoverage
        styleGate = $styleGate
        narrativeReviewRequired = $narrativeReviewRequired
        autoPassWithoutHumanEdits = ($groundingVerification.passed -and $sectionCoverage.passed -and $styleGate.passed)
    }

    $artifactPaths = Write-AppDocOverviewNarrativeArtifacts -RootPath $RootPath -Pass1Result $pass1Result -Pass2Narrative $pass2Narrative -Pass3ReviewNotes $reviewNotes -FinalNarrative $finalNarrative -RunReport $runReport

    $provider = "deterministic"

    return [ordered]@{
        narrative = $finalNarrative
        provider = $provider
        verification = $groundingVerification
        sectionCoverage = $sectionCoverage
        styleGate = $styleGate
        narrativeReviewRequired = $narrativeReviewRequired
        passSources = $runReport.passSources
        artifactPaths = $artifactPaths
        runReport = $runReport
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocOverviewWelcomeNarrativeFromPipeline'
)
