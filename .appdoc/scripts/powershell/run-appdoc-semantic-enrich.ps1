param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [switch]$DryRun
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

if (-not (Test-Path $RootPath)) {
    throw "Root path does not exist: $RootPath"
}

$docsPath = Join-Path $RootPath "docs"
$evidenceDir = Join-Path $docsPath "evidence"
if (-not (Test-Path $evidenceDir)) {
    throw "Evidence directory not found: $evidenceDir"
}

$semanticDir = Join-Path $evidenceDir "semantic"
$inputDir = Join-Path $semanticDir "input"
$outputDir = Join-Path $semanticDir "output"
$appliedDir = Join-Path $semanticDir "applied"
$pendingPath = Join-Path $semanticDir "semantic-pending.json"

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $inputDir | Out-Null
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    New-Item -ItemType Directory -Force -Path $appliedDir | Out-Null
}

function Get-FieldValue {
    param(
        [AllowNull()]
        [object]$Record,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Record) { return $Default }

    if ($Record -is [System.Collections.IDictionary]) {
        if ($Record.Contains($Name)) { return $Record[$Name] }
        return $Default
    }

    $prop = $Record.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Set-FieldValue {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Record,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Value
    )

    $Record[$Name] = $Value
}

function To-Hashtable {
    param(
        [Parameter(Mandatory=$true)]
        $InputObject
    )

    if ($InputObject -is [hashtable]) { return $InputObject }
    return ($InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100)
}

function New-SemanticKey {
    param(
        [string]$Source,
        [string]$Name,
        [string]$Kind
    )

    return (("{0}|{1}|{2}" -f ($Source ?? ""), ($Name ?? ""), ($Kind ?? "")).ToLowerInvariant())
}

function Infer-Tier {
    param(
        [string]$Source,
        [string]$Name
    )

    $s = ($Source ?? "").ToLowerInvariant()
    $n = ($Name ?? "").ToLowerInvariant()

    if ($s -match '(\.vscode|\.csproj|packages\.config|tasks\.json|launch\.json)' -or $n -match '(copilot|autoapprove|build|test|targetframework|outputtype)') {
        return 'build-tooling'
    }

    if ($s -match '(workflow|github/workflows|ci|pipeline|\.ya?ml|appsettings\.[^.]+\.json|\.env\.[^.]+|transform)' -or $n -match '(connection|string|smtp|host|server|apiurl|baseurl|environment)') {
        return 'deployment'
    }

    return 'runtime'
}

function Infer-RequiredForDeployment {
    param(
        [string]$Name,
        [object]$Metadata
    )

    $n = ($Name ?? "").ToLowerInvariant()
    if ($n -match '(connection|string|smtp|host|server|apiurl|baseurl|token|secret|key)') { return $true }

    if ($null -ne $Metadata) {
        $required = Get-FieldValue -Record $Metadata -Name 'required' -Default $null
        if ($null -ne $required) { return [bool]$required }
    }

    return $false
}

function Infer-DependencyKind {
    param([string]$Type)

    $t = ($Type ?? "").ToLowerInvariant()
    if ($t -match '^nuget') { return 'nuget' }
    if ($t -match 'assembly|gac') { return 'assembly-reference' }
    if ($t -match 'npm') { return 'npm' }
    if ($t -match 'python|pip') { return 'system' }
    if ($t -match 'maven|gradle|java') { return 'system' }
    return 'system'
}

function Infer-CriticalPath {
    param(
        [string]$Name,
        [string]$Project,
        [string]$Kind
    )

    $n = ($Name ?? "").ToLowerInvariant()
    if ($Kind -eq 'dependency') {
        if ($n -match '(microsoft\.extensions|newtonsoft|entityframework|system\.data|sqlclient|auth|security)') { return $true }
    }

    return $false
}

function Build-TestDiagnosis {
    param(
        [string]$Status,
        [string]$Kind,
        [object]$Metadata
    )

    $coverageLevel = 'none'
    $zeroReason = 'unknown'

    if (($Status ?? '') -eq 'Detected') {
        $coverageLevel = 'medium'
        $zeroReason = $null
    }
    elseif ($Kind -in @('summary','task-guide')) {
        $coverageLevel = 'none'
        $zeroReason = 'scope-failure'
    }

    return [ordered]@{
        coverageLevel = $coverageLevel
        discoveryMethod = 'deterministic-scan'
        zeroTestReason = $zeroReason
        underservedAreas = @('core-domain')
    }
}

function Ensure-ConfidenceNote {
    param(
        [hashtable]$Record
    )

    $confidenceRaw = Get-FieldValue -Record $Record -Name 'confidence' -Default $null
    if ($null -eq $confidenceRaw) { return }

    [double]$confidence = 0.0
    if (-not [double]::TryParse([string]$confidenceRaw, [ref]$confidence)) { return }

    if ($confidence -lt 0.8) {
        $note = [string](Get-FieldValue -Record $Record -Name 'confidenceNote' -Default '')
        if ([string]::IsNullOrWhiteSpace($note)) {
            $source = [string](Get-FieldValue -Record $Record -Name 'source' -Default 'source file')
            Set-FieldValue -Record $Record -Name 'confidenceNote' -Value ("Low-confidence signal from deterministic scan; review {0}." -f $source)
        }
    }
}

$requiredSemanticFields = @(
    'confidenceNote','role','businessPurpose','isGenerated','tier','dependencyKind','criticalPath',
    'upgradeUrgency','requiredForDeployment','schemaSource','integrationTargets','relationships',
    'operationalProfile','projectRole','usageFrequency','testDiagnosis'
)

$enrichedFiles = @(Get-ChildItem -Path $evidenceDir -Filter '*.evidence.enriched.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
$pending = @()
$updatedFiles = 0

foreach ($file in $enrichedFiles) {
    $payload = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $artifact = [string](Get-FieldValue -Record $payload -Name 'artifact' -Default '')
    $records = @((Get-FieldValue -Record $payload -Name 'records' -Default @()))

    $semanticInput = [ordered]@{
        artifact = $artifact
        generatedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
        source = $file.Name
        records = @(
            $records | ForEach-Object {
                $record = To-Hashtable -InputObject $_
                [ordered]@{
                    source = [string](Get-FieldValue -Record $record -Name 'source' -Default '')
                    name = [string](Get-FieldValue -Record $record -Name 'name' -Default '')
                    kind = [string](Get-FieldValue -Record $record -Name 'kind' -Default '')
                    confidence = (Get-FieldValue -Record $record -Name 'confidence' -Default $null)
                    metadata = (Get-FieldValue -Record $record -Name 'metadata' -Default $null)
                    expectedFields = $requiredSemanticFields
                }
            }
        )
    }

    $inputPath = Join-Path $inputDir ($file.Name.Replace('.evidence.enriched.json', '.semantic.input.json'))
    if (-not $DryRun) {
        $semanticInput | ConvertTo-Json -Depth 100 | Out-File -FilePath $inputPath -Encoding UTF8
    }

    $outputPath = Join-Path $outputDir ($file.Name.Replace('.evidence.enriched.json', '.semantic.output.json'))
    $outputLookup = @{}
    $outputApplied = $false

    if (Test-Path $outputPath) {
        try {
            $semanticOutput = Get-Content -Path $outputPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($outRecord in @((Get-FieldValue -Record $semanticOutput -Name 'records' -Default @()))) {
                $outHash = To-Hashtable -InputObject $outRecord
                $key = New-SemanticKey -Source ([string](Get-FieldValue -Record $outHash -Name 'source' -Default '')) -Name ([string](Get-FieldValue -Record $outHash -Name 'name' -Default '')) -Kind ([string](Get-FieldValue -Record $outHash -Name 'kind' -Default ''))
                $outputLookup[$key] = $outHash
            }
            $outputApplied = $outputLookup.Count -gt 0
        }
        catch {
            Write-Warning "Invalid semantic output file skipped: $outputPath"
        }
    }

    $updatedRecords = @(
        $records | ForEach-Object {
            $record = To-Hashtable -InputObject $_
            $source = [string](Get-FieldValue -Record $record -Name 'source' -Default '')
            $name = [string](Get-FieldValue -Record $record -Name 'name' -Default '')
            $kind = [string](Get-FieldValue -Record $record -Name 'kind' -Default '')
            $metadata = Get-FieldValue -Record $record -Name 'metadata' -Default $null
            $key = New-SemanticKey -Source $source -Name $name -Kind $kind

            if ($outputLookup.ContainsKey($key)) {
                $outRec = $outputLookup[$key]
                foreach ($field in $requiredSemanticFields) {
                    $outValue = Get-FieldValue -Record $outRec -Name $field -Default $null
                    if ($null -ne $outValue) {
                        Set-FieldValue -Record $record -Name $field -Value $outValue
                    }
                }
            }

            if ([string]::IsNullOrWhiteSpace([string](Get-FieldValue -Record $record -Name 'businessPurpose' -Default ''))) {
                Set-FieldValue -Record $record -Name 'businessPurpose' -Value ("Purpose unclear from available evidence — review {0}." -f $source)
            }

            if ($kind -eq 'configuration') {
                if ([string]::IsNullOrWhiteSpace([string](Get-FieldValue -Record $record -Name 'tier' -Default ''))) {
                    Set-FieldValue -Record $record -Name 'tier' -Value (Infer-Tier -Source $source -Name $name)
                }

                if ($null -eq (Get-FieldValue -Record $record -Name 'requiredForDeployment' -Default $null)) {
                    Set-FieldValue -Record $record -Name 'requiredForDeployment' -Value (Infer-RequiredForDeployment -Name $name -Metadata $metadata)
                }
            }

            if ($kind -eq 'dependency') {
                if ([string]::IsNullOrWhiteSpace([string](Get-FieldValue -Record $record -Name 'dependencyKind' -Default ''))) {
                    $depType = [string](Get-FieldValue -Record $metadata -Name 'type' -Default '')
                    Set-FieldValue -Record $record -Name 'dependencyKind' -Value (Infer-DependencyKind -Type $depType)
                }

                if ($null -eq (Get-FieldValue -Record $record -Name 'criticalPath' -Default $null)) {
                    $project = [string](Get-FieldValue -Record $metadata -Name 'project' -Default '')
                    Set-FieldValue -Record $record -Name 'criticalPath' -Value (Infer-CriticalPath -Name $name -Project $project -Kind $kind)
                }
            }

            if ($kind -in @('test-case','test-suite') -or $artifact -eq 'task-guides') {
                if ($null -eq (Get-FieldValue -Record $record -Name 'testDiagnosis' -Default $null)) {
                    $status = [string](Get-FieldValue -Record $record -Name 'status' -Default '')
                    Set-FieldValue -Record $record -Name 'testDiagnosis' -Value (Build-TestDiagnosis -Status $status -Kind $kind -Metadata $metadata)
                }
            }

            Ensure-ConfidenceNote -Record $record

            $record
        }
    )

    $payload['records'] = $updatedRecords
    $meta = To-Hashtable -InputObject (Get-FieldValue -Record $payload -Name 'metadata' -Default @{})
    $meta['enriched'] = $true
    $meta['enrichmentMode'] = 'semantic-applied'
    $meta['semanticInputPath'] = $inputPath.Replace($RootPath, '.').TrimStart('\\').Replace('\\','/')
    $meta['semanticOutputPath'] = if (Test-Path $outputPath) { $outputPath.Replace($RootPath, '.').TrimStart('\\').Replace('\\','/') } else { '' }
    $meta['semanticOutputApplied'] = $outputApplied
    $meta['semanticAppliedAt'] = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
    $payload['metadata'] = $meta

    $missing = @()
    foreach ($rec in $updatedRecords) {
        foreach ($field in $requiredSemanticFields) {
            if ($null -eq (Get-FieldValue -Record $rec -Name $field -Default $null)) {
                $missing += [ordered]@{
                    artifact = $artifact
                    source = [string](Get-FieldValue -Record $rec -Name 'source' -Default '')
                    name = [string](Get-FieldValue -Record $rec -Name 'name' -Default '')
                    kind = [string](Get-FieldValue -Record $rec -Name 'kind' -Default '')
                    field = $field
                }
            }
        }
    }

    if (-not $DryRun) {
        $payload | ConvertTo-Json -Depth 100 | Out-File -FilePath $file.FullName -Encoding UTF8
        $appliedSnapshot = Join-Path $appliedDir ($file.Name.Replace('.evidence.enriched.json', '.semantic.applied.json'))
        $payload | ConvertTo-Json -Depth 100 | Out-File -FilePath $appliedSnapshot -Encoding UTF8
    }

    $pending += $missing
    $updatedFiles++
}

$pendingPayload = [ordered]@{
    generatedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
    rootPath = $RootPath
    enrichedFilesChecked = $enrichedFiles.Count
    enrichedFilesUpdated = $updatedFiles
    pendingFieldCount = $pending.Count
    pending = $pending
}

if (-not $DryRun) {
    $pendingPayload | ConvertTo-Json -Depth 100 | Out-File -FilePath $pendingPath -Encoding UTF8
}

Write-Host "Semantic enrichment apply complete." -ForegroundColor Cyan
Write-Host ("Enriched files updated: {0}" -f $updatedFiles) -ForegroundColor Gray
Write-Host ("Pending semantic fields: {0}" -f $pending.Count) -ForegroundColor Gray
if ($pending.Count -gt 0) {
    Write-Host ("Pending report: {0}" -f $pendingPath) -ForegroundColor Gray
}
