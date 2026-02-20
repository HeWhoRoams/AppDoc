#
# generate-overview.ps1
#
# Purpose: Populates the overview template with repository analysis and technology summary.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [ValidateSet("Auto","Agent","ApiKey","Deterministic")]
    [string]$AIMode = "Auto",
    [Parameter(Mandatory=$false)]
    [switch]$RequireAI,
    [Parameter(Mandatory=$false)]
    [switch]$NoAI
)

function Get-AppDocOverviewGeneratorValue {
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

$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) {
    . $helpersPath
}

$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
if (-not (Test-Path $scopeModule)) { Write-Error "Required module not found: $scopeModule"; exit 1 }
Import-Module $scopeModule -Force -ErrorAction Stop

$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
if (-not (Test-Path $contractsModule)) { Write-Error "Required module not found: $contractsModule"; exit 1 }
Import-Module $contractsModule -Force -ErrorAction Stop

$evidenceModule = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (-not (Test-Path $evidenceModule)) { Write-Error "Required module not found: $evidenceModule"; exit 1 }
Import-Module $evidenceModule -Force -ErrorAction Stop

$overviewExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.Overview.Extractor.psm1"
if (-not (Test-Path $overviewExtractorModule)) { Write-Error "Required module not found: $overviewExtractorModule"; exit 1 }
Import-Module $overviewExtractorModule -Force -ErrorAction Stop

$overviewRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.Overview.Renderer.psm1"
if (-not (Test-Path $overviewRendererModule)) { Write-Error "Required module not found: $overviewRendererModule"; exit 1 }
Import-Module $overviewRendererModule -Force -ErrorAction Stop

$overviewTruthPackModule = Join-Path $PSScriptRoot "modules\AppDoc.Overview.TruthPack.psm1"
if (-not (Test-Path $overviewTruthPackModule)) { Write-Error "Required module not found: $overviewTruthPackModule"; exit 1 }
Import-Module $overviewTruthPackModule -Force -ErrorAction Stop

$overviewNarrativeModule = Join-Path $PSScriptRoot "modules\AppDoc.Overview.Narrative.psm1"
if (-not (Test-Path $overviewNarrativeModule)) { Write-Error "Required module not found: $overviewNarrativeModule"; exit 1 }
Import-Module $overviewNarrativeModule -Force -ErrorAction Stop

$overviewContextPackModule = Join-Path $PSScriptRoot "modules\AppDoc.Overview.ContextPack.psm1"
if (-not (Test-Path $overviewContextPackModule)) { Write-Error "Required module not found: $overviewContextPackModule"; exit 1 }
Import-Module $overviewContextPackModule -Force -ErrorAction Stop

$overviewPromptCompilerModule = Join-Path $PSScriptRoot "modules\AppDoc.Overview.PromptCompiler.psm1"
if (-not (Test-Path $overviewPromptCompilerModule)) { Write-Error "Required module not found: $overviewPromptCompilerModule"; exit 1 }
Import-Module $overviewPromptCompilerModule -Force -ErrorAction Stop

$overviewPipelineModule = Join-Path $PSScriptRoot "modules\AppDoc.Overview.Pipeline.psm1"
if (-not (Test-Path $overviewPipelineModule)) { Write-Error "Required module not found: $overviewPipelineModule"; exit 1 }
Import-Module $overviewPipelineModule -Force -ErrorAction Stop

Write-Host "📊 Generating System Overview..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\overview.md"
$initialized = Initialize-TemplateFile -TemplateName "overview-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating System Overview" -Status "Analyzing repository..." -PercentComplete 10

$overviewData = Get-AppDocOverviewData -RootPath $RootPath
if (-not $overviewData) {
    Write-Error "Get-AppDocOverviewData returned null. Cannot continue overview generation."
    exit 1
}
$languageCount = $overviewData.languageCount

$truthPack = Get-AppDocOverviewTruthPackData -RootPath $RootPath -OverviewData $overviewData
$truthPackPath = Write-AppDocOverviewTruthPack -RootPath $RootPath -TruthPack $truthPack

$contextPack = Get-AppDocOverviewContextPackData -RootPath $RootPath -TruthPack $truthPack -Audience "new_dev" -StyleProfile "standard"
$contextPackPath = Write-AppDocOverviewContextPack -RootPath $RootPath -ContextPack $contextPack

$welcomeNarrativeResult = Get-AppDocOverviewWelcomeNarrativeFromPipeline -RootPath $RootPath -TruthPack $truthPack -ContextPack $contextPack -Audience "new_dev" -StyleProfile "standard" -AIMode $AIMode -RequireAI:$RequireAI -NoAI:$NoAI
$welcomeNarrative = $welcomeNarrativeResult.narrative

Write-Progress -Activity "Generating System Overview" -Status "Populating template..." -PercentComplete 60
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocOverviewContent -Content $content -CodeFileCount ([int]$overviewData.codeFileCount) -LanguageCount $languageCount -WelcomeNarrative $welcomeNarrative -TruthPack $truthPack
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "overview"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @()

$systemPurpose = "This codebase contains $($overviewData.codeFileCount) code files across $($languageCount.Keys.Count) language(s). Full analysis available in linked documentation."
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "repository" -Name "system-purpose" -Kind "summary" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
    text = $systemPurpose
    fileCount = [int]$overviewData.codeFileCount
    languageCount = [int]$languageCount.Keys.Count
}

foreach ($lang in $languageCount.Keys) {
    $evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "repository" -Name ([string]$lang) -Kind "technology" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
        extension = [string]$lang
        count = [int]$languageCount[$lang]
    }
}

if ($welcomeNarrative) {
    $welcomeSectionOrder = @(
        "what_it_does",
        "inputs",
        "processing_steps",
        "outputs",
        "external_systems",
        "confidence_notes"
    )

    foreach ($section in $welcomeSectionOrder) {
        $items = @(Get-AppDocOverviewGeneratorValue -Object $welcomeNarrative -Name $section -Default @())

        $itemIndex = 0
        foreach ($item in $items) {
            if (-not $item) { continue }
            $text = [string]$item.text
            if ([string]::IsNullOrWhiteSpace($text)) { continue }

            $itemIndex++
            $evidenceRefs = @($item.evidence_refs | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique)
            $confidence = if ($evidenceRefs.Count -gt 0) { 0.9 } else { 0.6 }
            $providerType = if ($welcomeNarrativeResult.usedAI) { "llm" } else { "deterministic" }

            $evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "overview-welcome" -Name ("{0}-{1:00}" -f $section, $itemIndex) -Kind "welcome-summary" -Confidence $confidence -Provider ([string]$welcomeNarrativeResult.provider) -ProviderType $providerType -Metadata @{
                section = $section
                text = $text
                evidenceRefs = $evidenceRefs
                usedAI = [bool]$welcomeNarrativeResult.usedAI
            }
        }
    }
}

$evidenceMetadata = @{
    generator = "generate-overview.ps1"
    truthPackPath = $truthPackPath
    contextPackPath = $contextPackPath
    welcomeNarrativeProvider = [string]$welcomeNarrativeResult.provider
    welcomeNarrativeUsedAI = [bool]$welcomeNarrativeResult.usedAI
    welcomeNarrativeAIModeRequested = [string](Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.runReport -Name "aiModeRequested" -Default "")
    welcomeNarrativeAIModeResolved = [string](Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.runReport -Name "aiModeResolved" -Default "")
    welcomeNarrativeAIProvider = [string](Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.runReport -Name "aiProvider" -Default "")
    welcomeNarrativeVerified = [bool]$welcomeNarrativeResult.verification.passed
    welcomeNarrativeIssues = @($welcomeNarrativeResult.verification.issues)
    welcomeSectionCoveragePassed = [bool]$welcomeNarrativeResult.sectionCoverage.passed
    welcomeSectionCoverageIssues = @($welcomeNarrativeResult.sectionCoverage.issues)
    welcomeStyleGatePassed = [bool]$welcomeNarrativeResult.styleGate.passed
    welcomeStyleGateIssues = @($welcomeNarrativeResult.styleGate.issues)
    welcomeStyleGateMetrics = $welcomeNarrativeResult.styleGate.metrics
    narrativeReviewRequired = [bool]$welcomeNarrativeResult.narrativeReviewRequired
    welcomeNarrativePassSources = $welcomeNarrativeResult.passSources
    narrativeArtifacts = $welcomeNarrativeResult.artifactPaths
    narrativeRunReport = $welcomeNarrativeResult.runReport
}
if ($contract) {
    $evidenceMetadata.requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    $evidenceMetadata.requiredSections = @($contract.requiredSections)
}

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata $evidenceMetadata
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-overview.ps1"
    })
}

Write-Progress -Activity "Generating System Overview" -Status "Complete" -PercentComplete 100
Write-Host "✅ System overview generated: $outputPath" -ForegroundColor Green
Write-Host "   Code files analyzed: $($overviewData.codeFileCount)" -ForegroundColor Gray
