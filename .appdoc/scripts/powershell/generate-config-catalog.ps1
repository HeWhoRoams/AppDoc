#
# generate-config-catalog.ps1
#
# Purpose: Scans the target codebase for configuration files and populates the
#          config-catalog template with discovered configuration options.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) {
    . $helpersPath
}

function Import-RequiredModule {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RelativePath
    )

    $modulePath = Join-Path $PSScriptRoot $RelativePath
    if (-not (Test-Path $modulePath)) {
        Write-Error "Required module not found: $modulePath"
        exit 1
    }

    Import-Module $modulePath -Force -ErrorAction Stop
}

Import-RequiredModule -RelativePath "modules\AppDoc.Scope.psm1"
Import-RequiredModule -RelativePath "modules\AppDoc.Contracts.psm1"
Import-RequiredModule -RelativePath "modules\AppDoc.Evidence.psm1"
Import-RequiredModule -RelativePath "modules\AppDoc.ConfigCatalog.Extractor.psm1"
Import-RequiredModule -RelativePath "modules\AppDoc.ConfigCatalog.Renderer.psm1"

Write-Host "⚙️  Generating Config Catalog..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\config-catalog.md"
$initialized = Initialize-TemplateFile -TemplateName "config-catalog-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}


Write-Progress -Activity "Generating Config Catalog" -Status "Scanning configs..." -PercentComplete 10
try {
    $configData = Get-AppDocConfigCatalogData -RootPath $RootPath
} catch {
    Write-Error "[ConfigCatalog] Exception during config catalog extraction: $($_.Exception.Message)"
    $configData = $null
}

if ($null -eq $configData) {
    Write-Error "[ConfigCatalog] Failed to extract config catalog data. Extraction returned null or missing required properties."
    exit 1
}

$hasConfigs = $false
if ($configData -is [hashtable] -or $configData -is [System.Collections.Specialized.OrderedDictionary]) {
    $hasConfigs = $configData.Contains('configs')
} else {
    $hasConfigs = ($configData.PSObject.Properties.Name -contains 'configs')
}

if (-not $hasConfigs) {
    Write-Error "[ConfigCatalog] Failed to extract config catalog data. Extraction returned null or missing required properties."
    exit 1
}

$configs = @($configData.configs | Where-Object { $_ -ne $null })
$discoveredConfigFiles = @($configData.discoveredConfigFiles | Where-Object { $_ -ne $null })
$envVars = @($configData.envVars | Where-Object { $_ -ne $null })

function Set-AppDocFieldValue {
    param(
        [Parameter(Mandatory=$true)]
        [object]$Target,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Value
    )

    if ($Target -is [System.Collections.IDictionary]) {
        $Target[$Name] = $Value
        return
    }

    $existing = $Target.PSObject.Properties[$Name]
    if ($existing) {
        $existing.Value = $Value
    }
    else {
        Add-Member -InputObject $Target -MemberType NoteProperty -Name $Name -Value $Value -Force
    }
}

$enrichedEvidencePath = Join-Path $RootPath "docs\evidence\config-catalog.evidence.enriched.json"
if (Test-Path $enrichedEvidencePath) {
    try {
        $enrichedPayload = Get-Content -Path $enrichedEvidencePath -Raw | ConvertFrom-Json -Depth 80
        $enrichedRecords = @($enrichedPayload.records | Where-Object { $_ -and [string]$_.kind -eq 'configuration' })
        if ($enrichedRecords.Count -gt 0) {
            $lookup = @{}
            foreach ($record in $enrichedRecords) {
                $recordSource = [string]$record.source
                $recordName = [string]$record.name
                $lookupKey = ("{0}|{1}" -f $recordSource.ToLowerInvariant(), $recordName.ToLowerInvariant())
                $lookup[$lookupKey] = $record
            }

            foreach ($cfg in $configs) {
                $cfgSource = [string]$cfg.source
                $cfgKey = [string]$cfg.key
                $lookupKey = ("{0}|{1}" -f $cfgSource.ToLowerInvariant(), $cfgKey.ToLowerInvariant())
                if ($lookup.ContainsKey($lookupKey)) {
                    $record = $lookup[$lookupKey]
                    Set-AppDocFieldValue -Target $cfg -Name 'tier' -Value $record.tier
                    Set-AppDocFieldValue -Target $cfg -Name 'businessPurpose' -Value $record.businessPurpose
                    Set-AppDocFieldValue -Target $cfg -Name 'isGenerated' -Value $record.isGenerated
                    Set-AppDocFieldValue -Target $cfg -Name 'requiredForDeployment' -Value $record.requiredForDeployment
                    Set-AppDocFieldValue -Target $cfg -Name 'confidence' -Value $record.confidence
                    Set-AppDocFieldValue -Target $cfg -Name 'confidenceNote' -Value $record.confidenceNote
                }
            }

            Write-Host "   Applied enriched config records: $($enrichedRecords.Count)" -ForegroundColor Gray
        }
    }
    catch {
        Write-Warning "Failed to apply enriched config evidence: $($_.Exception.Message)"
    }
}

Write-Progress -Activity "Generating Config Catalog" -Status "Populating template..." -PercentComplete 60
$scriptRoot = Split-Path $PSScriptRoot -Parent
$appDocRoot = if ($scriptRoot) { Split-Path $scriptRoot -Parent } else { $null }
$templateFallbackPath = if ($appDocRoot) { Join-Path $appDocRoot "templates\config-catalog-template.md" } else { $null }
$content = Get-AppDocConfigCatalogTemplateContent -RootPath $RootPath -TemplateName "config-catalog-template.md" -FallbackPath $templateFallbackPath
$content = Update-AppDocConfigCatalogContent -Content $content -Configs $configs -DiscoveredConfigFiles $discoveredConfigFiles -EnvVars $envVars
$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Normalize-AppDocMarkdownStructure -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "config-catalog"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @(
    $configs | ForEach-Object {
        New-AppDocExtractionRecord -Artifact $artifact -Source ([string]$_.source) -Name ([string]$_.key) -Kind "configuration" -Confidence 0.85 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            value = [string]$_.value
            file = [string]$_.file
            type = [string]$_.type
            required = [bool]$_.required
        }
    }
)

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    configCount = $configs.Count
    generator = "generate-config-catalog.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-config-catalog.ps1"
    })
}

Write-Progress -Activity "Generating Config Catalog" -Status "Complete" -PercentComplete 100
Write-Host "✅ Config catalog generated: $outputPath" -ForegroundColor Green
Write-Host "   Configurations found: $($configs.Count)" -ForegroundColor Gray
Write-Host "   Configuration sources: $($discoveredConfigFiles.Count)" -ForegroundColor Gray
Write-Host "   Environment variables: $($envVars.Count)" -ForegroundColor Gray
