<#
.SYNOPSIS
    Generates C4 architecture diagrams in Mermaid format.

.DESCRIPTION
    Analyzes a .NET solution and generates Mermaid-based C4 diagrams
    (System Context and Container) as Markdown files in docs/diagrams.

.PARAMETER CodebasePath
    Path to the solution file (.sln) or codebase directory.

.PARAMETER OutputPath
    Output directory for generated documentation artifacts. Defaults to 'docs'.

.PARAMETER DiagramLevels
    Which C4 diagram levels to generate: 'Context', 'Container', or 'All'.

.PARAMETER Force
    Force regeneration of diagrams even if output files already exist.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$CodebasePath,

    [Parameter(Mandatory=$false)]
    [string]$OutputPath = "docs",

    [Parameter(Mandatory=$false)]
    [ValidateSet('Context', 'Container', 'All')]
    [string]$DiagramLevels = 'All',

    [Parameter(Mandatory=$false)]
    [switch]$Force
)

$modulesPath = Join-Path $PSScriptRoot "modules"
Import-Module (Join-Path $modulesPath "C4ModelBuilder.psm1") -Force

function ConvertTo-MermaidNodeId {
    param([string]$Text)

    if (-not $Text) { return "node" }
    $normalized = $Text.ToLower() -replace '[^a-z0-9_]', '_'
    if ($normalized -match '^[0-9]') {
        return "n_$normalized"
    }
    return $normalized
}

function ConvertTo-C4Text {
    param([string]$Text)
    if ([string]::IsNullOrWhiteSpace($Text)) { return "" }
    return (($Text -replace '"', "'") -replace '\r?\n', ' ').Trim()
}

function Test-AppDocOutboundEndpointRecord {
    param(
        [AllowNull()]
        [object]$Record
    )

    if (-not $Record) { return $false }
    $metadata = if ($Record.PSObject.Properties["metadata"]) { $Record.metadata } else { $null }
    $direction = if ($metadata -and $metadata.PSObject.Properties["direction"]) { [string]$metadata.direction } else { "" }
    $sourceType = if ($metadata -and $metadata.PSObject.Properties["sourceType"]) { [string]$metadata.sourceType } else { "" }
    $name = if ($Record.PSObject.Properties["name"]) { [string]$Record.name } else { "" }

    if ($direction -eq "outbound") { return $true }
    if ($sourceType -in @("soap-client","wcf-client","asmx-client","proxy-client")) { return $true }
    if ($name -match '^/soap-client/') { return $true }
    return $false
}

function Get-AppDocApiEvidenceExternalSystems {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $evidencePath = Join-Path $RootPath "docs/evidence/api-inventory.evidence.json"
    if (-not (Test-Path $evidencePath)) { return @() }

    $payload = $null
    try {
        $payload = Get-Content -Path $evidencePath -Raw | ConvertFrom-Json -Depth 80
    }
    catch {
        Write-Verbose "Unable to parse api-inventory evidence for C4 enrichment: $($_.Exception.Message)"
        return @()
    }

    $records = @($payload.records | Where-Object { $_ -and [string]$_.kind -eq "endpoint" })
    if ($records.Count -eq 0) { return @() }

    $externalByName = @{}
    foreach ($record in $records) {
        if (-not (Test-AppDocOutboundEndpointRecord -Record $record)) { continue }

        $metadata = if ($record.PSObject.Properties["metadata"]) { $record.metadata } else { $null }
        $integrationUrl = if ($metadata -and $metadata.PSObject.Properties["integrationUrl"]) { [string]$metadata.integrationUrl } else { "" }
        $path = if ($metadata -and $metadata.PSObject.Properties["path"]) { [string]$metadata.path } else { "" }
        $recordName = if ($record.PSObject.Properties["name"]) { [string]$record.name } else { "" }

        $extName = ""
        if (-not [string]::IsNullOrWhiteSpace($integrationUrl)) {
            try {
                $uri = [Uri]$integrationUrl
                if ($uri -and $uri.Host) {
                    $extName = [string]$uri.Host
                }
            }
            catch {
                $extName = $integrationUrl
            }
        }

        if ([string]::IsNullOrWhiteSpace($extName)) {
            $candidate = if (-not [string]::IsNullOrWhiteSpace($path)) { $path } else { $recordName }
            if ($candidate -match '^/soap-client/([^/]+)') {
                $extName = [string]$Matches[1]
            }
            elseif ($candidate -match '^https?://([^/]+)') {
                $extName = [string]$Matches[1]
            }
            else {
                $extName = $candidate
            }
        }

        if ([string]::IsNullOrWhiteSpace($extName)) { continue }
        $extName = ConvertTo-C4Text -Text $extName
        if ([string]::IsNullOrWhiteSpace($extName)) { continue }

        $nameKey = $extName.ToLowerInvariant()
        if ($externalByName.ContainsKey($nameKey)) { continue }

        $description = "External integration inferred from outbound API evidence"
        if (-not [string]::IsNullOrWhiteSpace($integrationUrl)) {
            $description = "External integration derived from outbound endpoint URL"
        }
        elseif ($recordName -match '^/soap-client/') {
            $description = "Legacy SOAP/WCF integration inferred from client endpoint evidence"
        }

        $externalByName[$nameKey] = @{
            Id = ("api_" + (ConvertTo-MermaidNodeId -Text $extName))
            Name = $extName
            Description = $description
            Type = "ExternalSystem"
        }
    }

    return @(
        $externalByName.Values |
            Sort-Object @{ Expression = { [string]$_.Name } }
    )
}

function Merge-AppDocExternalSystemsByName {
    param(
        [AllowEmptyCollection()]
        [array]$Primary = @(),
        [AllowEmptyCollection()]
        [array]$Secondary = @()
    )

    $byName = @{}
    foreach ($ext in @($Primary + $Secondary)) {
        if (-not $ext) { continue }
        $name = ConvertTo-C4Text -Text ([string]$ext.Name)
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $key = $name.ToLowerInvariant()
        if ($byName.ContainsKey($key)) { continue }
        $byName[$key] = $ext
    }

    return @(
        $byName.Values |
            Sort-Object @{ Expression = { [string]$_.Name } }
    )
}

function New-ContextMermaid {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$SystemModel
    )

    $systemId = ConvertTo-MermaidNodeId -Text $SystemModel.Id
    $systemName = ConvertTo-C4Text -Text $SystemModel.Name
    $systemDescription = ConvertTo-C4Text -Text $SystemModel.Description
    if ([string]::IsNullOrWhiteSpace($systemDescription)) {
        $systemDescription = "Primary software system"
    }

    $externalSystems = @($SystemModel.ExternalSystems)
    $hasSpecificDatabase = @(
        $externalSystems |
            Where-Object { ([string]$_.Name) -match '(?i)sql\s*server|postgres|mysql|oracle' }
    ).Count -gt 0

    $seenNames = @{}
    $lines = @(
        "C4Context"
        "title $systemName - System Context"
        "Person(user, `"User`", `"Primary caller of the system`")"
        "System($systemId, `"$systemName`", `"$systemDescription`")"
        "Rel(user, $systemId, `"Uses`")"
    )

    foreach ($ext in $externalSystems) {
        $extName = ConvertTo-C4Text -Text ([string]$ext.Name)
        if ([string]::IsNullOrWhiteSpace($extName)) { continue }
        if ($hasSpecificDatabase -and $extName -match '^(?i)database$') { continue }

        $nameKey = $extName.ToLowerInvariant()
        if ($seenNames.ContainsKey($nameKey)) { continue }
        $seenNames[$nameKey] = $true

        $extId = ConvertTo-MermaidNodeId -Text ([string]$ext.Id)
        if ([string]::IsNullOrWhiteSpace($extId)) {
            $extId = ConvertTo-MermaidNodeId -Text $extName
        }
        $extDescription = ConvertTo-C4Text -Text ([string]$ext.Description)
        if ([string]::IsNullOrWhiteSpace($extDescription)) {
            $extDescription = "External system"
        }

        $lines += "System_Ext($extId, `"$extName`", `"$extDescription`")"
        $lines += "Rel($systemId, $extId, `"Integrates with`")"
    }

    return ($lines -join "`n")
}

function New-ContainerMermaid {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$ContainerModel,
        [Parameter(Mandatory=$false)]
        [AllowEmptyCollection()]
        [array]$ExternalSystems = @()
    )

    $systemName = ConvertTo-C4Text -Text ([string]$ContainerModel.SystemName)
    if ([string]::IsNullOrWhiteSpace($systemName)) { $systemName = "System" }

    $lines = @("C4Container")
    $lines += "title $systemName - Container View"
    $lines += "Person(user, `"User`", `"Primary caller of the system`")"
    $lines += "System_Boundary(system_boundary, `"$systemName`") {"

    foreach ($container in @($ContainerModel.Containers)) {
        $containerId = ConvertTo-MermaidNodeId -Text $container.Id
        $containerName = ConvertTo-C4Text -Text ([string]$container.Name)
        $containerTech = ConvertTo-C4Text -Text ([string]$container.Technology)
        $containerDesc = ConvertTo-C4Text -Text ([string]$container.Description)
        if ([string]::IsNullOrWhiteSpace($containerDesc)) { $containerDesc = "Application container" }
        $lines += "  Container($containerId, `"$containerName`", `"$containerTech`", `"$containerDesc`")"
    }

    if ($ContainerModel.Containers.Count -eq 0) {
        $lines += "  Container(no_containers, `"No deployable containers detected`", `"N/A`", `"Detection fallback`")"
    }
    $lines += "}"

    $primaryContainerId = @(
        $ContainerModel.Containers |
            Sort-Object @{ Expression = { if (([string]$_.Type) -eq "WebApp") { 0 } elseif (([string]$_.Type) -eq "Service") { 1 } else { 2 } } }, @{ Expression = { [string]$_.Name } } |
            Select-Object -First 1 |
            ForEach-Object { ConvertTo-MermaidNodeId -Text ([string]$_.Id) }
    )
    if ($primaryContainerId.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$primaryContainerId[0])) {
        $lines += "Rel(user, $($primaryContainerId[0]), `"Uses`")"
    } else {
        $lines += "Rel(user, no_containers, `"Inspects`")"
    }

    $externalByName = @{}
    foreach ($ext in @($ExternalSystems)) {
        $extName = ConvertTo-C4Text -Text ([string]$ext.Name)
        if ([string]::IsNullOrWhiteSpace($extName)) { continue }
        $nameKey = $extName.ToLowerInvariant()
        if ($externalByName.ContainsKey($nameKey)) { continue }
        $externalByName[$nameKey] = $ext
    }

    foreach ($ext in @($externalByName.Values | Sort-Object @{ Expression = { [string]$_.Name } })) {
        $extName = ConvertTo-C4Text -Text ([string]$ext.Name)
        $extDesc = ConvertTo-C4Text -Text ([string]$ext.Description)
        if ([string]::IsNullOrWhiteSpace($extDesc)) { $extDesc = "External system" }
        $extId = "ext_" + (ConvertTo-MermaidNodeId -Text ([string]$ext.Id))
        if ([string]::IsNullOrWhiteSpace($extId) -or $extId -eq "ext_node") {
            $extId = "ext_" + (ConvertTo-MermaidNodeId -Text $extName)
        }

        $lines += "System_Ext($extId, `"$extName`", `"$extDesc`")"

        $relText = "Calls"
        $relProtocol = ""
        if ($extName -match '(?i)sql|postgres|mysql|oracle|database') {
            $relText = "Reads/Writes"
            $relProtocol = "SQL"
        }
        elseif ($extName -match '(?i)rabbitmq|queue|service bus|broker') {
            $relText = "Publishes/Subscribes"
            $relProtocol = "AMQP"
        }
        elseif ($extName -match '(?i)api|service|http') {
            $relText = "Calls"
            $relProtocol = "HTTPS"
        }

        if ($primaryContainerId.Count -gt 0 -and -not [string]::IsNullOrWhiteSpace([string]$primaryContainerId[0])) {
            if ([string]::IsNullOrWhiteSpace($relProtocol)) {
                $lines += "Rel($($primaryContainerId[0]), $extId, `"$relText`")"
            }
            else {
                $lines += "Rel($($primaryContainerId[0]), $extId, `"$relText`", `"$relProtocol`")"
            }
        }
    }

    foreach ($rel in @($ContainerModel.Relationships)) {
        $sourceId = ConvertTo-MermaidNodeId -Text $rel.Source
        $targetId = ConvertTo-MermaidNodeId -Text $rel.Target
        $label = if ($rel.Description) { (ConvertTo-C4Text -Text ([string]$rel.Description)) } else { "Uses" }
        $protocol = if ($rel.Protocol) { (ConvertTo-C4Text -Text ([string]$rel.Protocol)) } else { "" }
        if ([string]::IsNullOrWhiteSpace($protocol)) {
            $lines += "Rel($sourceId, $targetId, `"$label`")"
        }
        else {
            $lines += "Rel($sourceId, $targetId, `"$label`", `"$protocol`")"
        }
    }

    return ($lines -join "`n")
}

function Save-MermaidMarkdown {
    param(
        [Parameter(Mandatory=$true)]
        [string]$FilePath,
        [Parameter(Mandatory=$true)]
        [string]$Title,
        [Parameter(Mandatory=$true)]
        [string]$Mermaid,
        [Parameter(Mandatory=$true)]
        [string[]]$Summary
    )

    $directory = Split-Path -Parent $FilePath
    if (-not (Test-Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $summaryBullets = $Summary | ForEach-Object { "- $_" }
    $markdownLines = @()
    $markdownLines += "# $Title"
    $markdownLines += ''
    $markdownLines += "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss', [System.Globalization.CultureInfo]::InvariantCulture))"
    $markdownLines += ''
    $markdownLines += '## Summary'
    $markdownLines += ''
    $markdownLines += $summaryBullets
    $markdownLines += ''
    $markdownLines += '## Diagram'
    $markdownLines += ''
    $markdownLines += '```mermaid'
    $markdownLines += $Mermaid
    $markdownLines += '```'
    $markdownLines += ''
    $markdownLines += '---'
    $markdownLines += ''
    $markdownLines += '**Generated by AppDoc Framework**'
    $markdown = $markdownLines -join "`n"

    $markdown | Out-File -FilePath $FilePath -Encoding UTF8 -NoNewline
}

function Update-OverviewArchitectureSection {
    param(
        [Parameter(Mandatory=$true)]
        [string]$OverviewPath,
        [Parameter(Mandatory=$true)]
        [string[]]$References
    )

    if (-not (Test-Path $OverviewPath)) {
        return
    }

    $content = Get-Content -Path $OverviewPath -Raw
    $architectureSection = @(
        "## Architecture",
        "",
        "Generated C4 Mermaid diagrams:",
        ""
    ) + ($References | ForEach-Object { "- $_" })

    $sectionText = $architectureSection -join "`n"

    if ($content -match '(?s)##\s+Architecture\s*.*?(?=\n##\s+[^\n]+|\z)') {
        $content = [regex]::Replace($content, '(?s)##\s+Architecture\s*.*?(?=\n##\s+[^\n]+|\z)', $sectionText)
    }
    else {
        $content = $content.TrimEnd() + "`n`n" + $sectionText + "`n"
    }

    $content | Out-File -FilePath $OverviewPath -Encoding UTF8 -NoNewline
}

Write-Host "=== AppDoc Mermaid C4 Diagram Generator ===" -ForegroundColor Cyan
Write-Host "Codebase: $CodebasePath"
Write-Host "Output: $OutputPath"
Write-Host ""

if (-not (Test-Path $CodebasePath)) {
    Write-Error "Codebase path not found: $CodebasePath"
    exit 1
}

$diagramsPath = Join-Path $OutputPath "diagrams"
if (-not (Test-Path $diagramsPath)) {
    New-Item -Path $diagramsPath -ItemType Directory -Force | Out-Null
}

$analysisRoot = if (Test-Path $CodebasePath -PathType Leaf) { Split-Path $CodebasePath -Parent } else { $CodebasePath }
$apiEvidenceExternalSystems = Get-AppDocApiEvidenceExternalSystems -RootPath $analysisRoot

$solutionFile = $null
if ($CodebasePath -like "*.sln") {
    $solutionFile = $CodebasePath
}
else {
    $slnFiles = Get-ChildItem -Path $CodebasePath -Filter "*.sln" -File -Recurse -ErrorAction SilentlyContinue
    if ($slnFiles.Count -eq 0) {
        Write-Warning "No solution file found in: $CodebasePath. Generating placeholder Mermaid diagrams."
        $generatedFiles = @()
        if ($DiagramLevels -in @('Context', 'All')) {
            $contextOutput = Join-Path $diagramsPath "c4-context.md"
            Save-MermaidMarkdown -FilePath $contextOutput -Title "C4 System Context" -Mermaid "C4Context`ntitle System Context`nPerson(user, `"User`", `"Primary caller`")`nSystem(system, `"System`", `"Application boundary`")`nRel(user, system, `"Uses`")" -Summary @(
                "System detection unavailable (no solution file found)",
                "External systems detected: 0",
                "Scope: high-level system context"
            )
            $generatedFiles += "[C4 Context](diagrams/c4-context.md)"
        }

        if ($DiagramLevels -in @('Container', 'All')) {
            $containerOutput = Join-Path $diagramsPath "c4-container.md"
            Save-MermaidMarkdown -FilePath $containerOutput -Title "C4 Container" -Mermaid "C4Container`ntitle Container View`nPerson(user, `"User`", `"Primary caller`")`nContainer(no_containers, `"No deployable containers detected`", `"N/A`", `"Detection fallback`")`nRel(user, no_containers, `"Inspects`")" -Summary @(
                "System detection unavailable (no solution file found)",
                "Containers detected: 0",
                "Relationships detected: 0"
            )
            $generatedFiles += "[C4 Container](diagrams/c4-container.md)"
        }

        $overviewPath = Join-Path $OutputPath "overview.md"
        if ($generatedFiles.Count -gt 0) {
            Update-OverviewArchitectureSection -OverviewPath $overviewPath -References $generatedFiles
        }

        Write-Host "✓ Mermaid C4 placeholder diagram generation complete" -ForegroundColor Green
        exit 0
    }

    if ($slnFiles.Count -gt 1) {
        Write-Warning ("Multiple solution files found in $CodebasePath. The following .sln files were detected:")
        $slnFiles | ForEach-Object { Write-Warning ("  - " + $_.FullName) }
        Write-Warning ("Using the first solution file: $($slnFiles[0].FullName)")
    }
    $solutionFile = $slnFiles[0].FullName
    Write-Host "Found solution: $($slnFiles[0].Name)" -ForegroundColor Green
}

$generatedFiles = @()
$contextModelForContainer = $null

if ($DiagramLevels -in @('Context', 'All')) {
    $contextOutput = Join-Path $diagramsPath "c4-context.md"
    if ((Test-Path $contextOutput) -and -not $Force) {
        Write-Host "Context diagram already exists (use -Force to regenerate)" -ForegroundColor Gray
    }
    else {
        $systemModel = Build-SystemContextModel -SolutionPath $solutionFile
        if ($systemModel) {
            $systemModel.ExternalSystems = Merge-AppDocExternalSystemsByName -Primary @($systemModel.ExternalSystems) -Secondary $apiEvidenceExternalSystems
            $contextModelForContainer = $systemModel
            $mermaid = New-ContextMermaid -SystemModel $systemModel
            Save-MermaidMarkdown -FilePath $contextOutput -Title "C4 System Context" -Mermaid $mermaid -Summary @(
                "System: $($systemModel.Name)",
                "External systems detected: $($systemModel.ExternalSystems.Count)",
                "Scope: high-level system context"
            )
            $generatedFiles += "[C4 Context](diagrams/c4-context.md)"
            Write-Host "Generated: $contextOutput" -ForegroundColor Green
        }
    }
}

if ($DiagramLevels -in @('Container', 'All')) {
    $containerOutput = Join-Path $diagramsPath "c4-container.md"
    if ((Test-Path $containerOutput) -and -not $Force) {
        Write-Host "Container diagram already exists (use -Force to regenerate)" -ForegroundColor Gray
    }
    else {
        $containerModel = Build-ContainerModel -SolutionPath $solutionFile
        if ($containerModel) {
            if (-not $contextModelForContainer) {
                $contextModelForContainer = Build-SystemContextModel -SolutionPath $solutionFile
                if ($contextModelForContainer) {
                    $contextModelForContainer.ExternalSystems = Merge-AppDocExternalSystemsByName -Primary @($contextModelForContainer.ExternalSystems) -Secondary $apiEvidenceExternalSystems
                }
            }


            $externalSystems = @()
            if ($contextModelForContainer -and $contextModelForContainer.ExternalSystems) {
                $externalSystems = @($contextModelForContainer.ExternalSystems)
            } elseif ($apiEvidenceExternalSystems) {
                $externalSystems = Merge-AppDocExternalSystemsByName -Primary $externalSystems -Secondary $apiEvidenceExternalSystems
            }

            $mermaid = New-ContainerMermaid -ContainerModel $containerModel -ExternalSystems $externalSystems
            Save-MermaidMarkdown -FilePath $containerOutput -Title "C4 Container" -Mermaid $mermaid -Summary @(
                "System: $($containerModel.SystemName)",
                "Containers detected: $($containerModel.Containers.Count)",
                "Relationships detected: $($containerModel.Relationships.Count)",
                "External systems mapped: $($externalSystems.Count)"
            )
            $generatedFiles += "[C4 Container](diagrams/c4-container.md)"
            Write-Host "Generated: $containerOutput" -ForegroundColor Green
        }
    }
}

$overviewPath = Join-Path $OutputPath "overview.md"
if ($generatedFiles.Count -gt 0) {
    Update-OverviewArchitectureSection -OverviewPath $overviewPath -References $generatedFiles
    Write-Host "Updated overview architecture section" -ForegroundColor Green
}

Write-Host "`n✓ Mermaid C4 diagram generation complete" -ForegroundColor Green
