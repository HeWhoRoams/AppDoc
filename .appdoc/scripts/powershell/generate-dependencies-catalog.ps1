#
# generate-dependencies-catalog.ps1
#
# Purpose: Scans project files and populates the dependencies-catalog template.
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

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

$depsExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.DependenciesCatalog.Extractor.psm1"
if (-not (Test-Path $depsExtractorModule)) { Write-Error "Required module not found: $depsExtractorModule"; exit 1 }
Import-Module $depsExtractorModule -Force -ErrorAction Stop

$depsRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.DependenciesCatalog.Renderer.psm1"
if (-not (Test-Path $depsRendererModule)) { Write-Error "Required module not found: $depsRendererModule"; exit 1 }
Import-Module $depsRendererModule -Force -ErrorAction Stop

Write-Host "📦 Generating Dependencies Catalog..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\dependencies-catalog.md"
$initialized = Initialize-TemplateFile -TemplateName "dependencies-catalog-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}


Write-Progress -Activity "Generating Dependencies Catalog" -Status "Scanning project files..." -PercentComplete 10
try {
    $depData = Get-AppDocDependenciesCatalogData -RootPath $RootPath
} catch {
    Write-Error "[DependenciesCatalog] Exception during dependencies catalog extraction: $($_.Exception.Message)"
    $depData = $null
}

if ($null -eq $depData) {
    Write-Error "[DependenciesCatalog] Failed to extract dependencies catalog data. Extraction returned null or missing required properties."
    exit 1
}

$hasDependencies = $false
$hasProjects = $false
if ($depData -is [hashtable] -or $depData -is [System.Collections.Specialized.OrderedDictionary]) {
    $hasDependencies = $depData.Contains('dependencies')
    $hasProjects = $depData.Contains('projects')
} else {
    $hasDependencies = ($depData.PSObject.Properties.Name -contains 'dependencies')
    $hasProjects = ($depData.PSObject.Properties.Name -contains 'projects')
}

if (-not $hasDependencies -or -not $hasProjects) {
    Write-Error "[DependenciesCatalog] Failed to extract dependencies catalog data. Extraction returned null or missing required properties."
    exit 1
}

$dependencies = @($depData.dependencies)
$projects = @($depData.projects)

Write-Progress -Activity "Generating Dependencies Catalog" -Status "Populating template..." -PercentComplete 60
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocDependenciesCatalogContent -Content $content -Dependencies $dependencies -Projects $projects
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "dependencies-catalog"
$contract = Get-AppDocArtifactContract -Artifact $artifact
if ($null -eq $contract) {
    $contract = @{
        requiredEvidenceKeys = @()
        requiredSections = @()
    }
}

$evidenceRecords = @(
    $dependencies | ForEach-Object {
        $src = $_.source
        $name = $_.name
        $ver = $_.version
        $typ = $_.type
        $proj = $_.project
        if ($src -eq $null -or $name -eq $null) {
            Write-Warning "[DependenciesCatalog] Skipping dependency record with missing source or name: $($_ | ConvertTo-Json -Compress)"
            return
        }
        New-AppDocExtractionRecord -Artifact $artifact -Source $src -Name $name -Kind "dependency" -Confidence 0.85 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            version = $ver
            type = $typ
            project = $proj
        }
    }
)

$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    projectCount = $projects.Count
    dependencyCount = $dependencies.Count
    generator = "generate-dependencies-catalog.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-dependencies-catalog.ps1"
    })
}

Write-Progress -Activity "Generating Dependencies Catalog" -Status "Complete" -PercentComplete 100
Write-Host "✅ Dependencies catalog generated: $outputPath" -ForegroundColor Green
Write-Host "   Projects: $($projects.Count), Dependencies: $($dependencies.Count)" -ForegroundColor Gray
