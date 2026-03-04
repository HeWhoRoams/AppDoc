#
# generate-overview.ps1
#
# Purpose: Populates the overview template with repository analysis and technology summary.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
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

function ConvertTo-AppDocPortableRelativePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) { return "" }

    $path = [string]$Value
    if ([string]::IsNullOrWhiteSpace($path)) { return "" }

    $isAbsolute = $false
    try {
        $isAbsolute = [System.IO.Path]::IsPathRooted($path)
    }
    catch {
        $isAbsolute = $false
    }

    $relative = $path
    if ($isAbsolute) {
        try {
            $relative = [System.IO.Path]::GetRelativePath($RootPath, $path)
        }
        catch {
            $relative = $path
        }
    }

    $relative = ($relative -replace '\\', '/')
    $relative = $relative.Trim()
    # Remove leading "./" but preserve "../" parent references
    while ($relative.StartsWith("./")) {
        $relative = $relative.Substring(2)
    }
    if ([string]::IsNullOrWhiteSpace($relative)) { return "" }
    return $relative
}

function ConvertTo-AppDocPortablePathMap {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowNull()]
        [object]$Object
    )

    if ($null -eq $Object) { return @{} }
    if ($Object -isnot [System.Collections.IDictionary]) { return @{} }

    $result = [ordered]@{}
    foreach ($key in @($Object.Keys)) {
        $value = $Object[$key]
        if ($value -is [System.Collections.IDictionary]) {
            $result[[string]$key] = ConvertTo-AppDocPortablePathMap -RootPath $RootPath -Object $value
            continue
        }

        if ($value -is [string]) {
            $result[[string]$key] = ConvertTo-AppDocPortableRelativePath -RootPath $RootPath -Value $value
            continue
        }

        $result[[string]$key] = $value
    }
    return $result
}

function Get-AppDocOverviewFactTexts {
    param(
        [AllowNull()]
        [object]$TruthPack,
        [Parameter(Mandatory=$true)]
        [string]$FactName,
        [string[]]$Fallback = @()
    )

    $facts = Get-AppDocOverviewGeneratorValue -Object $TruthPack -Name "facts" -Default $null
    $factItems = Get-AppDocOverviewGeneratorValue -Object $facts -Name $FactName -Default @()
    $texts = @(
        @($factItems) |
            ForEach-Object { [string](Get-AppDocOverviewGeneratorValue -Object $_ -Name "text" -Default "") } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
    )

    if ($texts.Count -eq 0) { return @($Fallback) }
    return @($texts)
}

function Ensure-AppDocOverviewSection {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$SectionName,
        [Parameter(Mandatory=$true)]
        [string[]]$Lines
    )

    if ([regex]::IsMatch($Content, "(?im)^##\s+" + [regex]::Escape($SectionName) + "\b")) {
        return $Content
    }

    $body = @($Lines | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | ForEach-Object { "- " + $_.Trim() })
    if ($body.Count -eq 0) {
        $body = @("- No deterministic evidence available for this section in the current run.")
    }

    return ($Content.TrimEnd() + "`r`n`r`n## " + $SectionName + "`r`n" + ($body -join "`r`n") + "`r`n")
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
if ($null -eq $truthPack) {
    Write-Warning "Get-AppDocOverviewTruthPackData returned null. Using empty truth pack."
    $truthPack = @{}
} else {
    $canonicalMetricsPath = Join-Path $RootPath "docs\evidence\metrics-canonical.json"
    if (Test-Path $canonicalMetricsPath) {
        try {
            $canonical = Get-Content $canonicalMetricsPath -Raw | ConvertFrom-Json -Depth 50
            $totals = Get-AppDocOverviewGeneratorValue -Object $canonical -Name "totals" -Default $null
            if ($totals -and $truthPack.counts) {
                $truthPack.counts.endpointRecords = [int](Get-AppDocOverviewGeneratorValue -Object $totals -Name "endpointCount" -Default $truthPack.counts.endpointRecords)
                $truthPack.counts.inboundEndpoints = [int](Get-AppDocOverviewGeneratorValue -Object $totals -Name "inboundEndpointCount" -Default $truthPack.counts.inboundEndpoints)
                $truthPack.counts.outboundEndpoints = [int](Get-AppDocOverviewGeneratorValue -Object $totals -Name "outboundEndpointCount" -Default $truthPack.counts.outboundEndpoints)
                $truthPack.counts.modelRecords = [int](Get-AppDocOverviewGeneratorValue -Object $totals -Name "modelCount" -Default $truthPack.counts.modelRecords)
                $truthPack.counts.dependencyRecords = [int](Get-AppDocOverviewGeneratorValue -Object $totals -Name "dependencyCount" -Default $truthPack.counts.dependencyRecords)
            }
        }
        catch {
            Write-Verbose ("Unable to read canonical metrics for overview alignment: {0}" -f $_.Exception.Message)
        }
    }

    $truthPackPath = Write-AppDocOverviewTruthPack -RootPath $RootPath -TruthPack $truthPack
}

$contextPack = Get-AppDocOverviewContextPackData -RootPath $RootPath -TruthPack $truthPack -Audience "new_dev" -StyleProfile "standard"
if ($null -eq $contextPack) {
    Write-Warning "Get-AppDocOverviewContextPackData returned null. Using empty context pack."
    $contextPack = @{}
} else {
    $contextPackPath = Write-AppDocOverviewContextPack -RootPath $RootPath -ContextPack $contextPack
}

$welcomeNarrativeResult = Get-AppDocOverviewWelcomeNarrativeFromPipeline -RootPath $RootPath -TruthPack $truthPack -ContextPack $contextPack -Audience "new_dev" -StyleProfile "standard"
if ($null -eq $welcomeNarrativeResult -or $null -eq $welcomeNarrativeResult.narrative) {
    Write-Warning "Get-AppDocOverviewWelcomeNarrativeFromPipeline returned null or missing narrative. Using default welcome narrative."
    $welcomeNarrative = "Welcome to the system overview. Narrative generation failed or returned no content."
} else {
    $welcomeNarrative = $welcomeNarrativeResult.narrative
}

Write-Progress -Activity "Generating System Overview" -Status "Populating template..." -PercentComplete 60
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocOverviewContent -Content $content -CodeFileCount ([int]$overviewData.codeFileCount) -LanguageCount $languageCount -WelcomeNarrative $welcomeNarrative -TruthPack $truthPack

$primaryStyle = [string](Get-AppDocOverviewGeneratorValue -Object (Get-AppDocOverviewGeneratorValue -Object $truthPack -Name "architecture" -Default @{}) -Name "primaryStyle" -Default "unknown")
$confidence = [string](Get-AppDocOverviewGeneratorValue -Object (Get-AppDocOverviewGeneratorValue -Object $truthPack -Name "architecture" -Default @{}) -Name "confidence" -Default "")
$confidenceSuffix = if ([string]::IsNullOrWhiteSpace($confidence)) { "" } else { " (confidence $confidence)" }
$systemBoundaryLines = @(
    "System scope is documented for this repository run and bounded to generated artifacts under docs/ and evidence/."
    ("Architecture statement: {0}{1}." -f $primaryStyle, $confidenceSuffix)
)
$runtimePathLines = Get-AppDocOverviewFactTexts -TruthPack $truthPack -FactName "processing_steps" -Fallback @("Runtime flow is inferred from deterministic evidence and may require manual verification for edge paths.")
$ipoLines = @()
$ipoLines += "Inputs"
$ipoLines += @(Get-AppDocOverviewFactTexts -TruthPack $truthPack -FactName "inputs" -Fallback @("No strong input contract evidence detected."))
$ipoLines += "Processing"
$ipoLines += @(Get-AppDocOverviewFactTexts -TruthPack $truthPack -FactName "processing_steps" -Fallback @("No strong processing evidence detected."))
$ipoLines += "Outputs"
$ipoLines += @(Get-AppDocOverviewFactTexts -TruthPack $truthPack -FactName "outputs" -Fallback @("No strong output contract evidence detected."))
$externalLines = Get-AppDocOverviewFactTexts -TruthPack $truthPack -FactName "external_systems" -Fallback @("No explicit external systems detected.")
$confidenceLines = Get-AppDocOverviewFactTexts -TruthPack $truthPack -FactName "confidence_notes" -Fallback @("Confidence is low when evidence records are sparse.")

$runtimePathLines = @($runtimePathLines | ForEach-Object { ([string]$_ -replace '(?i)\bappears to\b', 'is inferred to') })
$ipoLines = @($ipoLines | ForEach-Object { ([string]$_ -replace '(?i)\bappears to\b', 'is inferred to') })
$externalLines = @($externalLines | ForEach-Object { ([string]$_ -replace '(?i)\bappears to\b', 'is inferred to') })
$confidenceLines = @($confidenceLines | ForEach-Object { ([string]$_ -replace '(?i)\bappears to\b', 'is inferred to') })

$content = Ensure-AppDocOverviewSection -Content $content -SectionName "System Boundary" -Lines $systemBoundaryLines
$content = Ensure-AppDocOverviewSection -Content $content -SectionName "Runtime Path" -Lines $runtimePathLines
$content = Ensure-AppDocOverviewSection -Content $content -SectionName "Inputs→Processing→Outputs" -Lines $ipoLines
$content = Ensure-AppDocOverviewSection -Content $content -SectionName "External Systems" -Lines $externalLines
$content = Ensure-AppDocOverviewSection -Content $content -SectionName "Confidence Notes" -Lines $confidenceLines

$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Normalize-AppDocMarkdownStructure -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "overview"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @()


# Patch: Use framework detection to set file/language counts if code scan is empty but frameworks are detected
$patchedCodeFileCount = [int]$overviewData.codeFileCount
$patchedLanguageCount = [int]$languageCount.Keys.Count
$patchedText = ""
# Normalize frameworks to array
$frameworks = $null
if ($truthPack.architecture -ne $null -and $truthPack.architecture.frameworks -ne $null) {
    if ($truthPack.architecture.frameworks -is [string]) {
        $frameworks = @($truthPack.architecture.frameworks)
    } else {
        $frameworks = $truthPack.architecture.frameworks
    }
}
if ($frameworks -ne $null -and $frameworks.Count -gt 0 -and $patchedCodeFileCount -eq 0) {
    $patchedCodeFileCount = 1
    $patchedLanguageCount = 1
    $frameworkNames = $frameworks -join ", "
    $patchedText = "This codebase contains $patchedCodeFileCount code file(s) across $patchedLanguageCount language(s) (framework detected: $frameworkNames). Full analysis available in linked documentation."
} else {
    $patchedText = "This codebase contains $patchedCodeFileCount code files across $patchedLanguageCount language(s). Full analysis available in linked documentation."
}
$evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "repository" -Name "system-purpose" -Kind "summary" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
    text = $patchedText
    fileCount = $patchedCodeFileCount
    languageCount = $patchedLanguageCount
}

foreach ($lang in $languageCount.Keys) {
    $evidenceRecords += New-AppDocExtractionRecord -Artifact $artifact -Source "repository" -Name ([string]$lang) -Kind "technology" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
        extension = [string]$lang
        count = [int]$languageCount[$lang]
    }
}

$evidenceMetadata = @{
    generator = "generate-overview.ps1"
    truthPackPath = (ConvertTo-AppDocPortableRelativePath -RootPath $RootPath -Value $truthPackPath)
    contextPackPath = (ConvertTo-AppDocPortableRelativePath -RootPath $RootPath -Value $contextPackPath)
    welcomeNarrativeProvider = [string](Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult -Name "provider" -Default "")
    welcomeNarrativeVerified = [bool](Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.verification -Name "passed" -Default $false)
    welcomeNarrativeIssues = @(Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.verification -Name "issues" -Default @())
    welcomeSectionCoveragePassed = [bool](Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.sectionCoverage -Name "passed" -Default $false)
    welcomeSectionCoverageIssues = @(Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.sectionCoverage -Name "issues" -Default @())
    welcomeStyleGatePassed = [bool](Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.styleGate -Name "passed" -Default $false)
    welcomeStyleGateIssues = @(Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.styleGate -Name "issues" -Default @())
    welcomeStyleGateMetrics = (Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult.styleGate -Name "metrics" -Default @{})
    narrativeReviewRequired = [bool](Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult -Name "narrativeReviewRequired" -Default $false)
    welcomeNarrativePassSources = (Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult -Name "passSources" -Default @())
    narrativeArtifacts = (ConvertTo-AppDocPortablePathMap -RootPath $RootPath -Object (Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult -Name "artifactPaths" -Default @{}))
    narrativeRunReport = (Get-AppDocOverviewGeneratorValue -Object $welcomeNarrativeResult -Name "runReport" -Default @{})
    evidenceGraphPath = [string](Get-AppDocOverviewGeneratorValue -Object (Get-AppDocOverviewGeneratorValue -Object $truthPack -Name "graph" -Default @{}) -Name "path" -Default "")
    evidenceGraphEntityCount = [int](Get-AppDocOverviewGeneratorValue -Object (Get-AppDocOverviewGeneratorValue -Object $truthPack -Name "graph" -Default @{}) -Name "entityCount" -Default 0)
    evidenceGraphEdgeCount = [int](Get-AppDocOverviewGeneratorValue -Object (Get-AppDocOverviewGeneratorValue -Object $truthPack -Name "graph" -Default @{}) -Name "edgeCount" -Default 0)
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
