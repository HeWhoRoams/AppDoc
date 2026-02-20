# AppDoc.Overview.Pipeline Module
# Purpose: Execute a persisted, multi-pass narrative workflow on top of deterministic context.

$script:AppDocOverviewPipelineVersion = "1.1.0"

$script:AppDocOverviewAIProviderModule = Join-Path $PSScriptRoot "AppDoc.AI.Provider.psm1"
if (Test-Path $script:AppDocOverviewAIProviderModule) {
    Import-Module $script:AppDocOverviewAIProviderModule -Force -ErrorAction Stop
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

    $artifactDir = Join-Path $RootPath "docs\evidence\narrative"
    if (-not (Test-Path $artifactDir)) {
        New-Item -Path $artifactDir -ItemType Directory -Force | Out-Null
    }

    $pass1Path = Join-Path $artifactDir "purpose_model.json"
    $pass2Path = Join-Path $artifactDir "narrative_draft.md"
    $pass3Path = Join-Path $artifactDir "review_notes.json"
    $finalPath = Join-Path $artifactDir "narrative_final.json"
    $runReportPath = Join-Path $RootPath "docs\evidence\narrative-run-report.json"

    $Pass1Result | ConvertTo-Json -Depth 40 | Out-File -FilePath $pass1Path -Encoding UTF8
    (ConvertTo-AppDocOverviewNarrativeMarkdown -Narrative $Pass2Narrative) | Out-File -FilePath $pass2Path -Encoding UTF8
    $Pass3ReviewNotes | ConvertTo-Json -Depth 40 | Out-File -FilePath $pass3Path -Encoding UTF8
    $FinalNarrative | ConvertTo-Json -Depth 40 | Out-File -FilePath $finalPath -Encoding UTF8
    $RunReport | ConvertTo-Json -Depth 40 | Out-File -FilePath $runReportPath -Encoding UTF8

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
        [string]$StyleProfile = "standard",
        [ValidateSet("Auto","Agent","ApiKey","Deterministic")]
        [string]$AIMode = "Auto",
        [switch]$RequireAI,
        [switch]$NoAI
    )

    if ($NoAI -and $RequireAI) {
        throw "Invalid AI options: -NoAI and -RequireAI cannot be used together."
    }

    $startedAt = Get-Date
    $model = if ($env:APPDOC_OPENAI_MODEL) { $env:APPDOC_OPENAI_MODEL } else { "gpt-4o-mini" }
    $requestedAIMode = if ($NoAI) { "Deterministic" } else { $AIMode }
    $aiPassTimeoutSeconds = 180
    $parsedTimeout = 0
    if ([int]::TryParse(([string]$env:APPDOC_AI_TIMEOUT_SECONDS), [ref]$parsedTimeout) -and $parsedTimeout -gt 0) {
        $aiPassTimeoutSeconds = $parsedTimeout
    }

    $aiResolution = [ordered]@{
        requestedMode = $requestedAIMode
        resolvedMode = "Deterministic"
        provider = "deterministic"
        reason = "AI provider module unavailable."
        apiKeyAvailable = $false
        agentEnabled = $false
    }
    if (Get-Command Resolve-AppDocAIMode -ErrorAction SilentlyContinue) {
        try {
            $aiResolution = Resolve-AppDocAIMode -RequestedMode $requestedAIMode -RequireAI:$RequireAI
        }
        catch {
            if ($RequireAI) { throw }
            $aiResolution = [ordered]@{
                requestedMode = $requestedAIMode
                resolvedMode = "Deterministic"
                provider = "deterministic"
                reason = "AI resolution failed: $($_.Exception.Message)"
                apiKeyAvailable = $false
                agentEnabled = $false
            }
        }
    }

    $resolvedAIMode = [string](Get-AppDocOverviewPipelineValue -Object $aiResolution -Name "resolvedMode" -Default "Deterministic")
    $aiEnabled = ($resolvedAIMode -ne "Deterministic")
    if ($aiEnabled -and -not (Get-Command Invoke-AppDocAIJsonPass -ErrorAction SilentlyContinue)) {
        if ($RequireAI) {
            throw "AI mode '$resolvedAIMode' was selected, but Invoke-AppDocAIJsonPass is unavailable."
        }
        $aiEnabled = $false
        $resolvedAIMode = "Deterministic"
        $aiResolution = [ordered]@{
            requestedMode = $requestedAIMode
            resolvedMode = "Deterministic"
            provider = "deterministic"
            reason = "AI invoker unavailable; deterministic fallback applied."
            apiKeyAvailable = $false
            agentEnabled = $false
        }
    }
    $aiProvidersObserved = @()
    $aiPassFailures = @()

    $promptSet = Get-AppDocOverviewPromptSet -ContextPack $ContextPack -Audience $Audience -StyleProfile $StyleProfile

    $pass1Source = "deterministic"
    $pass1Result = Get-AppDocOverviewDeterministicPass1 -ContextPack $ContextPack
    if ($aiEnabled) {
        $pass1Call = Invoke-AppDocAIJsonPass -RootPath $RootPath -PassName "overview-pass1" -SystemPrompt ([string]$promptSet.pass1.system) -UserPrompt ([string]$promptSet.pass1.user) -AIMode $requestedAIMode -Model $model -TimeoutSeconds $aiPassTimeoutSeconds -RequireAI:$RequireAI
        if ($pass1Call -and $pass1Call.provider) {
            $aiProvidersObserved += [string]$pass1Call.provider
        }
        if ($pass1Call -and $pass1Call.success) {
            $pass1Ai = Get-AppDocOverviewPipelineValue -Object $pass1Call -Name "result" -Default $null
            if (Test-AppDocOverviewPass1Shape -Pass1Result $pass1Ai) {
                $pass1Result = $pass1Ai
                $pass1Source = "ai:$([string]$pass1Call.provider)"
            }
            else {
                $aiPassFailures += "overview-pass1:invalid-shape"
                if ($RequireAI) {
                    throw "AI pass 'overview-pass1' returned an invalid result shape."
                }
            }
        }
        elseif ($pass1Call) {
            $aiPassFailures += "overview-pass1:$([string](Get-AppDocOverviewPipelineValue -Object $pass1Call -Name "error" -Default "ai-pass-failed"))"
            if ($RequireAI) {
                throw "AI pass 'overview-pass1' failed: $([string](Get-AppDocOverviewPipelineValue -Object $pass1Call -Name "error" -Default "unknown error"))"
            }
        }
    }

    $deterministicNarrative = Get-AppDocOverviewDeterministicWelcomeNarrative -TruthPack $TruthPack
    $pass2Source = "deterministic"
    $pass2Narrative = $deterministicNarrative
    if ($aiEnabled) {
        $pass2Prompt = ([string]$promptSet.pass2.user) + [Environment]::NewLine + [Environment]::NewLine + "Pass 1 result:" + [Environment]::NewLine + ($pass1Result | ConvertTo-Json -Depth 40)
        $pass2Call = Invoke-AppDocAIJsonPass -RootPath $RootPath -PassName "overview-pass2" -SystemPrompt ([string]$promptSet.pass2.system) -UserPrompt $pass2Prompt -AIMode $requestedAIMode -Model $model -TimeoutSeconds $aiPassTimeoutSeconds -RequireAI:$RequireAI
        if ($pass2Call -and $pass2Call.provider) {
            $aiProvidersObserved += [string]$pass2Call.provider
        }

        if ($pass2Call -and $pass2Call.success) {
            $pass2Ai = Get-AppDocOverviewPipelineValue -Object $pass2Call -Name "result" -Default $null
            $pass2Verify = Test-AppDocOverviewNarrativeGrounding -Narrative $pass2Ai -TruthPack $TruthPack
            if ($pass2Verify.passed) {
                $pass2Narrative = $pass2Ai
                $pass2Source = "ai:$([string]$pass2Call.provider)"
            }
            else {
                $aiPassFailures += "overview-pass2:grounding-failed"
                if ($RequireAI) {
                    throw "AI pass 'overview-pass2' failed grounding checks: $($pass2Verify.issues -join ", ")"
                }
            }
        }
        elseif ($pass2Call) {
            $aiPassFailures += "overview-pass2:$([string](Get-AppDocOverviewPipelineValue -Object $pass2Call -Name "error" -Default "ai-pass-failed"))"
            if ($RequireAI) {
                throw "AI pass 'overview-pass2' failed: $([string](Get-AppDocOverviewPipelineValue -Object $pass2Call -Name "error" -Default "unknown error"))"
            }
        }
    }

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
    $retryCount = 0
    $styleRetryUsed = $false
    if ($aiEnabled) {
        $pass3Prompt = ([string]$promptSet.pass3.user) + [Environment]::NewLine + [Environment]::NewLine + "Pass 2 narrative:" + [Environment]::NewLine + ($pass2Narrative | ConvertTo-Json -Depth 40)
        $pass3Call = Invoke-AppDocAIJsonPass -RootPath $RootPath -PassName "overview-pass3" -SystemPrompt ([string]$promptSet.pass3.system) -UserPrompt $pass3Prompt -AIMode $requestedAIMode -Model $model -TimeoutSeconds $aiPassTimeoutSeconds -RequireAI:$RequireAI
        if ($pass3Call -and $pass3Call.provider) {
            $aiProvidersObserved += [string]$pass3Call.provider
        }

        if ($pass3Call -and $pass3Call.success) {
            $pass3Ai = Get-AppDocOverviewPipelineValue -Object $pass3Call -Name "result" -Default $null
            $candidateNarrative = Get-AppDocOverviewPipelineValue -Object $pass3Ai -Name "narrative" -Default $null
            $candidateNotes = Get-AppDocOverviewPipelineValue -Object $pass3Ai -Name "review_notes" -Default @()
            if ($candidateNarrative) {
                $pass3Verify = Test-AppDocOverviewNarrativeGrounding -Narrative $candidateNarrative -TruthPack $TruthPack
                if ($pass3Verify.passed) {
                    $finalNarrative = $candidateNarrative
                    $pass3Source = "ai:$([string]$pass3Call.provider)"
                    $reviewNotes = [ordered]@{
                        notes = @($candidateNotes)
                    }
                }
                else {
                    $aiPassFailures += "overview-pass3:grounding-failed"
                    if ($RequireAI) {
                        throw "AI pass 'overview-pass3' failed grounding checks: $($pass3Verify.issues -join ", ")"
                    }
                }
            }
            elseif ($RequireAI) {
                throw "AI pass 'overview-pass3' did not return a narrative payload."
            }
        }
        elseif ($pass3Call) {
            $aiPassFailures += "overview-pass3:$([string](Get-AppDocOverviewPipelineValue -Object $pass3Call -Name "error" -Default "ai-pass-failed"))"
            if ($RequireAI) {
                throw "AI pass 'overview-pass3' failed: $([string](Get-AppDocOverviewPipelineValue -Object $pass3Call -Name "error" -Default "unknown error"))"
            }
        }
    }

    $groundingVerification = Test-AppDocOverviewNarrativeGrounding -Narrative $finalNarrative -TruthPack $TruthPack
    $sectionEvidenceMap = Get-AppDocOverviewPipelineValue -Object $pass1Result -Name "section_evidence_map" -Default @{}
    $sectionCoverage = Test-AppDocOverviewSectionEvidenceCoverage -Narrative $finalNarrative -SectionEvidenceMap $sectionEvidenceMap
    $styleGate = Test-AppDocOverviewNarrativeStyleQuality -Narrative $finalNarrative

    if ($aiEnabled -and (-not $styleGate.passed) -and $groundingVerification.passed -and $sectionCoverage.passed) {
        $retryCount = 1
        $styleRetryUsed = $true
        $styleIssuesText = if ($styleGate.issues.Count -gt 0) { ($styleGate.issues -join ", ") } else { "style-quality-unknown" }
        $styleRewritePrompt = @"
$([string]$promptSet.pass3.user)

Style rewrite requirements:
- Reduce inventory/count-heavy phrasing.
- Improve business-purpose clarity and readable developer orientation.
- Keep grounding intact; do not invent facts.
- Preserve section structure and evidence references.

Known style issues from gate:
$styleIssuesText

Current narrative:
$($finalNarrative | ConvertTo-Json -Depth 40)

Section evidence map:
$($sectionEvidenceMap | ConvertTo-Json -Depth 20)
"@
        $styleRetryCall = Invoke-AppDocAIJsonPass -RootPath $RootPath -PassName "overview-style-retry" -SystemPrompt ([string]$promptSet.pass3.system) -UserPrompt $styleRewritePrompt -AIMode $requestedAIMode -Model $model -TimeoutSeconds $aiPassTimeoutSeconds -RequireAI:$false
        if ($styleRetryCall -and $styleRetryCall.provider) {
            $aiProvidersObserved += [string]$styleRetryCall.provider
        }

        $styleRetryResult = $null
        if ($styleRetryCall -and $styleRetryCall.success) {
            $styleRetryResult = Get-AppDocOverviewPipelineValue -Object $styleRetryCall -Name "result" -Default $null
        }
        elseif ($styleRetryCall) {
            $aiPassFailures += "overview-style-retry:$([string](Get-AppDocOverviewPipelineValue -Object $styleRetryCall -Name "error" -Default "ai-pass-failed"))"
        }

        $styleRetryNarrative = $null
        if ($styleRetryResult) {
            $styleRetryNarrative = Get-AppDocOverviewPipelineValue -Object $styleRetryResult -Name "narrative" -Default $styleRetryResult
        }

        if ($styleRetryNarrative) {
            $retryGrounding = Test-AppDocOverviewNarrativeGrounding -Narrative $styleRetryNarrative -TruthPack $TruthPack
            $retryCoverage = Test-AppDocOverviewSectionEvidenceCoverage -Narrative $styleRetryNarrative -SectionEvidenceMap $sectionEvidenceMap
            $retryStyle = Test-AppDocOverviewNarrativeStyleQuality -Narrative $styleRetryNarrative
            if ($retryGrounding.passed -and $retryCoverage.passed -and $retryStyle.passed) {
                $finalNarrative = $styleRetryNarrative
                $groundingVerification = $retryGrounding
                $sectionCoverage = $retryCoverage
                $styleGate = $retryStyle
                $pass3Source = "ai:$([string](Get-AppDocOverviewPipelineValue -Object $styleRetryCall -Name "provider" -Default "unknown"))/style-retry"
                $retryNotes = Get-AppDocOverviewPipelineValue -Object $styleRetryResult -Name "review_notes" -Default @()
                $reviewNotes = [ordered]@{
                    notes = @($retryNotes)
                }
            }
        }
    }

    $narrativeReviewRequired = (-not $groundingVerification.passed) -or (-not $sectionCoverage.passed) -or (-not $styleGate.passed)

    $endedAt = Get-Date
    $runReport = [ordered]@{
        pipelineVersion = $script:AppDocOverviewPipelineVersion
        startedAt = $startedAt.ToString("yyyy-MM-ddTHH:mm:ssK")
        endedAt = $endedAt.ToString("yyyy-MM-ddTHH:mm:ssK")
        durationMs = [Math]::Round(($endedAt - $startedAt).TotalMilliseconds, 0)
        model = $model
        aiModeRequested = $requestedAIMode
        aiModeResolved = $resolvedAIMode
        aiProvider = [string](Get-AppDocOverviewPipelineValue -Object $aiResolution -Name "provider" -Default "deterministic")
        aiResolutionReason = [string](Get-AppDocOverviewPipelineValue -Object $aiResolution -Name "reason" -Default "")
        aiAttempted = $aiEnabled
        aiProvidersObserved = @($aiProvidersObserved | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        aiPassFailures = @($aiPassFailures | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
        requireAI = $RequireAI.IsPresent
        noAI = $NoAI.IsPresent
        audience = $Audience
        styleProfile = $StyleProfile
        passSources = [ordered]@{
            pass1 = $pass1Source
            pass2 = $pass2Source
            pass3 = $pass3Source
        }
        retryCount = $retryCount
        styleRetryUsed = $styleRetryUsed
        grounding = $groundingVerification
        sectionCoverage = $sectionCoverage
        styleGate = $styleGate
        narrativeReviewRequired = $narrativeReviewRequired
        autoPassWithoutHumanEdits = ($groundingVerification.passed -and $sectionCoverage.passed -and $styleGate.passed)
    }

    $artifactPaths = Write-AppDocOverviewNarrativeArtifacts -RootPath $RootPath -Pass1Result $pass1Result -Pass2Narrative $pass2Narrative -Pass3ReviewNotes $reviewNotes -FinalNarrative $finalNarrative -RunReport $runReport

    $usedAI = ($pass2Source -like "ai:*" -or $pass3Source -like "ai:*")
    $provider = if ($usedAI) { "ai-multipass" } else { "deterministic" }

    return [ordered]@{
        narrative = $finalNarrative
        provider = $provider
        usedAI = $usedAI
        aiAttempted = $aiEnabled
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
