# AppDoc.Overview.TruthPack Module
# Purpose: Build deterministic overview truth data used by narrative rendering.

$script:AppDocOverviewTruthPackVersion = "1.1.0"

function Get-AppDocOverviewObjectValue {
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
    if ($null -ne $prop) {
        return $prop.Value
    }

    return $Default
}

function Read-AppDocOverviewJsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (-not (Test-Path $Path)) {
        return $null
    }

    try {
        return (Get-Content $Path -Raw | ConvertFrom-Json -Depth 50)
    }
    catch {
        Write-Verbose "Unable to parse JSON file '$Path': $($_.Exception.Message)"
        return $null
    }
}

function Get-AppDocOverviewEvidenceRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [string[]]$Artifacts = @("overview", "api-inventory", "data-model", "config-catalog", "dependencies-catalog", "build-cookbook")
    )

    $records = @()
    foreach ($artifact in @($Artifacts | Where-Object { $_ })) {
        $evidencePath = Join-Path $RootPath (Join-Path "docs" (Join-Path "evidence" ("{0}.evidence.json" -f [string]$artifact)))
        $payload = Read-AppDocOverviewJsonFile -Path $evidencePath
        if (-not $payload -or -not $payload.records) { continue }

        foreach ($record in @($payload.records)) {
            if (-not $record) { continue }

            $records += [ordered]@{
                artifact = [string]$artifact
                kind = [string](Get-AppDocOverviewObjectValue -Object $record -Name "kind" -Default "")
                name = [string](Get-AppDocOverviewObjectValue -Object $record -Name "name" -Default "")
                source = [string](Get-AppDocOverviewObjectValue -Object $record -Name "source" -Default "")
                metadata = (Get-AppDocOverviewObjectValue -Object $record -Name "metadata" -Default @{})
            }
        }
    }

    return @(
        $records |
            Sort-Object @{ Expression = { [string]$_.artifact } }, @{ Expression = { [string]$_.kind } }, @{ Expression = { [string]$_.name } }, @{ Expression = { [string]$_.source } }
    )
}

function Get-AppDocOverviewDistinctValues {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [array]$Values = @(),
        [int]$Limit = 8
    )

    if (-not $Values -or @($Values).Count -eq 0) {
        return @()
    }

    $normalized = @()
    foreach ($value in @($Values | Where-Object { $_ })) {
        $text = [string]$value
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        $normalized += $text.Trim()
    }

    if ($normalized.Count -eq 0) { return @() }

    return @(
        $normalized |
            Group-Object |
            Sort-Object -Property @(
                @{ Expression = "Count"; Descending = $true },
                @{ Expression = "Name"; Descending = $false }
            ) |
            Select-Object -First $Limit |
            ForEach-Object { [string]$_.Name }
    )
}

function ConvertTo-AppDocOverviewStringArray {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) { return @() }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return @() }
        return @([string]$Value)
    }

    $values = @()
    if ($Value -is [System.Collections.IEnumerable]) {
        foreach ($entry in $Value) {
            if ($null -eq $entry) { continue }
            $text = [string]$entry
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            $values += $text.Trim()
        }
        return @($values)
    }

    $textValue = [string]$Value
    if ([string]::IsNullOrWhiteSpace($textValue)) { return @() }
    return @($textValue.Trim())
}

function Get-AppDocOverviewCompactMetadata {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Metadata,
        [string]$Kind = ""
    )

    $meta = if ($null -eq $Metadata) { @{} } else { $Metadata }
    $result = [ordered]@{}

    $allowKeys = switch ($Kind) {
        "endpoint" { @("method","path","controller","domain","direction","sourceType","integrationUrl","returnType","parameters","authRequired") }
        "model" { @("type","namespace","description","fieldCount") }
        "configuration" { @("required","source","defaultValue","classification","sourceFile") }
        "dependency" { @("version","type","license","project") }
        "summary" { @("text","count","category","primaryStyle") }
        default { @("source","description","count") }
    }

    foreach ($key in $allowKeys) {
        $value = Get-AppDocOverviewObjectValue -Object $meta -Name $key -Default $null
        if ($null -eq $value) { continue }

        if ($value -is [bool] -or $value -is [int] -or $value -is [long] -or $value -is [double]) {
            $result[$key] = $value
            continue
        }

        $text = [string]$value
        if ([string]::IsNullOrWhiteSpace($text)) { continue }
        if ($text.Length -gt 240) { $text = $text.Substring(0,240) + "..." }
        $result[$key] = $text.Trim()
    }

    return $result
}

function Get-AppDocOverviewParameterNames {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [array]$EndpointRefs = @(),
        [int]$Limit = 8
    )

    $names = @()
    foreach ($endpoint in @($EndpointRefs | Where-Object { $_ })) {
        $metadata = Get-AppDocOverviewObjectValue -Object $endpoint -Name "metadata" -Default @{}
        $parameterString = [string](Get-AppDocOverviewObjectValue -Object $metadata -Name "parameters" -Default "")
        if ([string]::IsNullOrWhiteSpace($parameterString) -or $parameterString -eq "None") { continue }

        foreach ($part in ($parameterString -split ',')) {
            $trimmed = [string]$part
            if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
            $candidate = $trimmed.Trim()

            if ($candidate -match '^\s*([A-Za-z_][A-Za-z0-9_]*)\s*:') {
                $names += $Matches[1]
            }
            elseif ($candidate -match '([A-Za-z_][A-Za-z0-9_]*)\s*$') {
                $names += $Matches[1]
            }
        }
    }

    return (Get-AppDocOverviewDistinctValues -Values $names -Limit $Limit)
}

function Get-AppDocOverviewIntegrationHosts {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [array]$EndpointRefs = @(),
        [int]$Limit = 6
    )

    $hosts = @()
    foreach ($endpoint in @($EndpointRefs | Where-Object { $_ })) {
        $metadata = Get-AppDocOverviewObjectValue -Object $endpoint -Name "metadata" -Default @{}
        $url = [string](Get-AppDocOverviewObjectValue -Object $metadata -Name "integrationUrl" -Default "")
        if ([string]::IsNullOrWhiteSpace($url)) { continue }

        try {
            $uri = [Uri]$url
            if ($uri -and $uri.Host) {
                $hosts += [string]$uri.Host
            }
        }
        catch {
            continue
        }
    }

    return (Get-AppDocOverviewDistinctValues -Values $hosts -Limit $Limit)
}

function New-AppDocOverviewFact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text,
        [AllowEmptyCollection()]
        [string[]]$EvidenceRefs = @()
    )

    return [ordered]@{
        text = $Text.Trim()
        evidence_refs = @($EvidenceRefs | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    }
}

function ConvertTo-AppDocOverviewFriendlyLabel {
    [CmdletBinding()]
    param(
        [string]$Value
    )

    if ([string]::IsNullOrWhiteSpace($Value)) { return "" }
    $label = [string]$Value
    $label = ($label -replace '\s+', ' ').Trim()

    $segments = @($label -split '\s+' | Where-Object { $_ })
    if ($segments.Count -ge 3) {
        $shortSegmentCount = @($segments | Where-Object { $_.Length -le 2 }).Count
        if ($shortSegmentCount -ge [Math]::Ceiling($segments.Count * 0.6)) {
            $label = ($segments -join '')
        }
    }

    $label = $label -replace '(?i)(Controller|Service|Api)$', ''
    $label = $label -replace '[_\-/\\\.]+', ' '
    $label = $label -creplace '([a-z])([A-Z])', '$1 $2'
    $label = ($label -replace '\s+', ' ').Trim()
    if ([string]::IsNullOrWhiteSpace($label)) { return "" }
    return $label
}

function ConvertTo-AppDocOverviewNaturalList {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [string[]]$Values = @(),
        [int]$Limit = 4
    )

    $items = @(
        $Values |
            ForEach-Object { [string]$_ } |
            Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
            Select-Object -Unique
    )
    if ($items.Count -eq 0) { return "" }

    if ($items.Count -gt $Limit) {
        $items = @($items | Select-Object -First $Limit)
    }

    if ($items.Count -eq 1) { return [string]$items[0] }
    if ($items.Count -eq 2) { return ("{0} and {1}" -f $items[0], $items[1]) }

    return ((@($items[0..($items.Count - 2)]) -join ", ") + ", and " + $items[$items.Count - 1])
}

function Get-AppDocOverviewDomainNames {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [array]$EndpointRefs = @(),
        [int]$Limit = 6
    )

    $domains = @()
    foreach ($endpoint in @($EndpointRefs | Where-Object { $_ })) {
        $metadata = Get-AppDocOverviewObjectValue -Object $endpoint -Name "metadata" -Default @{}
        $controller = [string](Get-AppDocOverviewObjectValue -Object $metadata -Name "controller" -Default "")
        $name = [string](Get-AppDocOverviewObjectValue -Object $endpoint -Name "name" -Default "")

        $candidate = ""
        if (-not [string]::IsNullOrWhiteSpace($controller)) {
            $candidate = ConvertTo-AppDocOverviewFriendlyLabel -Value $controller
        }
        elseif ($name -match '^/([^/{]+)/') {
            $candidate = ConvertTo-AppDocOverviewFriendlyLabel -Value ([string]$Matches[1])
        }

        if (-not [string]::IsNullOrWhiteSpace($candidate)) {
            $domains += $candidate
        }
    }

    return @(Get-AppDocOverviewDistinctValues -Values $domains -Limit $Limit)
}

function Get-AppDocOverviewTruthPackData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowNull()]
        [object]$OverviewData = $null
    )

    $docsPath = Join-Path $RootPath "docs"
    $projectName = Split-Path $RootPath -Leaf

    $frameworkDetectionPath = Join-Path $docsPath "framework-detection.json"
    $architectureFingerprintPath = Join-Path $docsPath "architecture-fingerprint.json"
    $frameworks = Read-AppDocOverviewJsonFile -Path $frameworkDetectionPath
    $architecture = Read-AppDocOverviewJsonFile -Path $architectureFingerprintPath

    $baseRecords = @(Get-AppDocOverviewEvidenceRecords -RootPath $RootPath)
    $baseRecords = @(
        $baseRecords |
            Where-Object { @("summary","endpoint","model","configuration","dependency") -contains ([string]$_.kind) } |
            Select-Object -First 2500
    )
    $indexedRecords = @()
    $counter = 1
    foreach ($record in $baseRecords) {
        $indexedRecords += [ordered]@{
            id = ("ev-{0}" -f $counter.ToString("0000"))
            artifact = [string]$record.artifact
            kind = [string]$record.kind
            name = [string]$record.name
            source = [string]$record.source
            metadata = (Get-AppDocOverviewCompactMetadata -Metadata (Get-AppDocOverviewObjectValue -Object $record -Name "metadata" -Default @{}) -Kind ([string]$record.kind))
        }
        $counter++
    }

    $summaryRecords = @($indexedRecords | Where-Object { [string]$_.kind -eq "summary" })
    $endpointRecords = @($indexedRecords | Where-Object { [string]$_.kind -eq "endpoint" })
    $modelRecords = @($indexedRecords | Where-Object { [string]$_.kind -eq "model" })
    $configRecords = @($indexedRecords | Where-Object { [string]$_.kind -eq "configuration" })
    $dependencyRecords = @($indexedRecords | Where-Object { [string]$_.kind -eq "dependency" })

    $inboundEndpoints = @()
    $outboundEndpoints = @()
    foreach ($endpoint in $endpointRecords) {
        $metadata = Get-AppDocOverviewObjectValue -Object $endpoint -Name "metadata" -Default @{}
        $direction = [string](Get-AppDocOverviewObjectValue -Object $metadata -Name "direction" -Default "")
        $name = [string](Get-AppDocOverviewObjectValue -Object $endpoint -Name "name" -Default "")
        $sourceType = [string](Get-AppDocOverviewObjectValue -Object $metadata -Name "sourceType" -Default "")

        if ([string]::IsNullOrWhiteSpace($direction)) {
            if ($sourceType -eq "soap-client" -or $name -match '^/soap-client/') {
                $direction = "outbound"
            }
            else {
                $direction = "inbound"
            }
        }

        if ($direction -eq "outbound") {
            $outboundEndpoints += $endpoint
        }
        else {
            $inboundEndpoints += $endpoint
        }
    }

    $mappedOutbound = @(
        $outboundEndpoints | Where-Object {
            $meta = Get-AppDocOverviewObjectValue -Object $_ -Name "metadata" -Default @{}
            -not [string]::IsNullOrWhiteSpace([string](Get-AppDocOverviewObjectValue -Object $meta -Name "integrationUrl" -Default ""))
        }
    )

    $defaultRefIds = @()
    if ($summaryRecords.Count -gt 0) {
        $defaultRefIds = @($summaryRecords | Select-Object -First 2 | ForEach-Object { [string]$_.id })
    }
    elseif ($indexedRecords.Count -gt 0) {
        $defaultRefIds = @($indexedRecords | Select-Object -First 2 | ForEach-Object { [string]$_.id })
    }

    $inputParams = Get-AppDocOverviewParameterNames -EndpointRefs $endpointRecords -Limit 8
    $returnTypes = Get-AppDocOverviewDistinctValues -Values @(
        $endpointRecords | ForEach-Object {
            $meta = Get-AppDocOverviewObjectValue -Object $_ -Name "metadata" -Default @{}
            [string](Get-AppDocOverviewObjectValue -Object $meta -Name "returnType" -Default "")
        }
    ) -Limit 6
    $controllerNames = Get-AppDocOverviewDistinctValues -Values @(
        $endpointRecords | ForEach-Object {
            $meta = Get-AppDocOverviewObjectValue -Object $_ -Name "metadata" -Default @{}
            [string](Get-AppDocOverviewObjectValue -Object $meta -Name "controller" -Default "")
        }
    ) -Limit 8
    $domainNames = @(Get-AppDocOverviewDomainNames -EndpointRefs $endpointRecords -Limit 6)
    $modelNames = @(Get-AppDocOverviewDistinctValues -Values @(
        $modelRecords | ForEach-Object { ConvertTo-AppDocOverviewFriendlyLabel -Value ([string](Get-AppDocOverviewObjectValue -Object $_ -Name "name" -Default "")) }
    ) -Limit 8)
    $integrationHosts = Get-AppDocOverviewIntegrationHosts -EndpointRefs $outboundEndpoints -Limit 6

    $topDependencies = Get-AppDocOverviewDistinctValues -Values @(
        $dependencyRecords | ForEach-Object { [string](Get-AppDocOverviewObjectValue -Object $_ -Name "name" -Default "") }
    ) -Limit 8

    $languageCount = @{}
    if ($OverviewData -and (Get-AppDocOverviewObjectValue -Object $OverviewData -Name "languageCount")) {
        $languageCount = Get-AppDocOverviewObjectValue -Object $OverviewData -Name "languageCount" -Default @{}
    }

    $whatItDoes = @()
    $inputs = @()
    $processingSteps = @()
    $outputs = @()
    $externalSystems = @()
    $confidenceNotes = @()

    if ($domainNames.Count -gt 0) {
        $domainPhrase = ConvertTo-AppDocOverviewNaturalList -Values $domainNames -Limit 4
        $whatItDoes += New-AppDocOverviewFact -Text ("This application appears to support {0} workflows and expose that behavior through its service interfaces." -f $domainPhrase) -EvidenceRefs @($endpointRecords | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    elseif ($endpointRecords.Count -gt 0) {
        $whatItDoes += New-AppDocOverviewFact -Text "This application exposes operational workflows through endpoint-driven service interfaces." -EvidenceRefs @($endpointRecords | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    if ($modelNames.Count -gt 0) {
        $modelPhrase = ConvertTo-AppDocOverviewNaturalList -Values $modelNames -Limit 4
        $whatItDoes += New-AppDocOverviewFact -Text ("Its business behavior is centered on application records such as {0}." -f $modelPhrase) -EvidenceRefs @($modelRecords | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    if ($whatItDoes.Count -eq 0) {
        $codeFileCount = if ($OverviewData) { [int](Get-AppDocOverviewObjectValue -Object $OverviewData -Name "codeFileCount" -Default 0) } else { 0 }
        $whatItDoes += New-AppDocOverviewFact -Text ("The repository contains implementation code, but current deterministic evidence is not strong enough to confidently describe business behavior yet (files scanned: {0})." -f $codeFileCount) -EvidenceRefs $defaultRefIds
    }

    if ($inputParams.Count -gt 0) {
        $inputPhrase = ConvertTo-AppDocOverviewNaturalList -Values $inputParams -Limit 6
        $inputs += New-AppDocOverviewFact -Text ("Requests are primarily shaped by parameters such as {0}." -f $inputPhrase) -EvidenceRefs @($endpointRecords | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    if ($configRecords.Count -gt 0) {
        $inputs += New-AppDocOverviewFact -Text "Runtime behavior is also influenced by environment and application configuration values loaded at startup." -EvidenceRefs @($configRecords | Select-Object -First 3 | ForEach-Object { [string]$_.id })
    }
    if ($inputs.Count -eq 0) {
        $inputs += New-AppDocOverviewFact -Text "Input contracts were not strongly detected in deterministic evidence for this scan." -EvidenceRefs $defaultRefIds
    }

    if ($controllerNames.Count -gt 0) {
        $friendlyControllers = @(
            $controllerNames |
                ForEach-Object { ConvertTo-AppDocOverviewFriendlyLabel -Value ([string]$_) } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) }
        )
        $controllerPhrase = ConvertTo-AppDocOverviewNaturalList -Values $friendlyControllers -Limit 6
        if (-not [string]::IsNullOrWhiteSpace($controllerPhrase)) {
            $processingSteps += New-AppDocOverviewFact -Text ("Processing logic is organized around components such as {0}, where requests are validated and routed through domain logic." -f $controllerPhrase) -EvidenceRefs @($endpointRecords | Select-Object -First 5 | ForEach-Object { [string]$_.id })
        }
    }
    if ($modelRecords.Count -gt 0) {
        $processingSteps += New-AppDocOverviewFact -Text "Core processing includes mapping request data into internal models and returning structured results for consumers." -EvidenceRefs @($modelRecords | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    if ($processingSteps.Count -eq 0) {
        $processingSteps += New-AppDocOverviewFact -Text "Processing flow could not be inferred beyond repository-level summaries in this scan." -EvidenceRefs $defaultRefIds
    }

    if ($returnTypes.Count -gt 0) {
        $returnPhrase = ConvertTo-AppDocOverviewNaturalList -Values $returnTypes -Limit 5
        $outputs += New-AppDocOverviewFact -Text ("Callers receive structured response payloads represented by types such as {0}." -f $returnPhrase) -EvidenceRefs @($endpointRecords | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    if ($outboundEndpoints.Count -gt 0) {
        $outputs += New-AppDocOverviewFact -Text "Some flows produce side effects by sending data to external systems through outbound integration calls." -EvidenceRefs @($outboundEndpoints | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    if ($outputs.Count -eq 0) {
        $outputs += New-AppDocOverviewFact -Text "Output contracts are not strongly represented in current deterministic evidence." -EvidenceRefs $defaultRefIds
    }

    if ($integrationHosts.Count -gt 0) {
        $hostPhrase = ConvertTo-AppDocOverviewNaturalList -Values $integrationHosts -Limit 4
        $externalSystems += New-AppDocOverviewFact -Text ("Outbound integrations connect to external hosts such as {0}." -f $hostPhrase) -EvidenceRefs @($mappedOutbound | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    if ($topDependencies.Count -gt 0) {
        $dependencyPhrase = ConvertTo-AppDocOverviewNaturalList -Values $topDependencies -Limit 5
        $externalSystems += New-AppDocOverviewFact -Text ("The runtime and build surface rely on key libraries including {0}." -f $dependencyPhrase) -EvidenceRefs @($dependencyRecords | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    if ($externalSystems.Count -eq 0) {
        $externalSystems += New-AppDocOverviewFact -Text "No clear external system integration evidence was detected." -EvidenceRefs $defaultRefIds
    }

    $confidenceNotes += New-AppDocOverviewFact -Text ("Evidence coverage includes {0} endpoint records, {1} model records, {2} configuration records, and {3} dependency records." -f $endpointRecords.Count, $modelRecords.Count, $configRecords.Count, $dependencyRecords.Count) -EvidenceRefs @($indexedRecords | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    if ($outboundEndpoints.Count -gt 0) {
        $confidenceNotes += New-AppDocOverviewFact -Text ("Outbound endpoint URL mapping coverage is {0}/{1}." -f $mappedOutbound.Count, $outboundEndpoints.Count) -EvidenceRefs @($outboundEndpoints | Select-Object -First 4 | ForEach-Object { [string]$_.id })
    }
    if ($architecture) {
        $primaryStyle = [string](Get-AppDocOverviewObjectValue -Object $architecture -Name "primaryStyle" -Default "unknown")
        $confidenceValue = [double](Get-AppDocOverviewObjectValue -Object $architecture -Name "confidence" -Default 0.0)
        $confidenceNotes += New-AppDocOverviewFact -Text ("Architecture fingerprint indicates '{0}' style with confidence {1}." -f $primaryStyle, $confidenceValue) -EvidenceRefs $defaultRefIds
    }

    $frameworkList = @()
    foreach ($framework in @($frameworks)) {
        $frameworkName = [string](Get-AppDocOverviewObjectValue -Object $framework -Name "framework" -Default "")
        if (-not [string]::IsNullOrWhiteSpace($frameworkName)) {
            $frameworkList += $frameworkName
        }
    }
    $frameworkList = @(Get-AppDocOverviewDistinctValues -Values $frameworkList -Limit 10)

    $architectureStyles = @()
    if ($architecture) {
        $architectureStyles = @(
            ConvertTo-AppDocOverviewStringArray -Value (Get-AppDocOverviewObjectValue -Object $architecture -Name "styles" -Default @()) |
                ForEach-Object { [string]$_ } |
                Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                Select-Object -Unique
        )
        if ($architectureStyles.Count -eq 0) {
            $fallbackStyle = [string](Get-AppDocOverviewObjectValue -Object $architecture -Name "primaryStyle" -Default "")
            if (-not [string]::IsNullOrWhiteSpace($fallbackStyle)) {
                $architectureStyles = @($fallbackStyle)
            }
        }
    }

    $truthPack = [ordered]@{
        version = $script:AppDocOverviewTruthPackVersion
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        projectName = $projectName
        rootPath = $RootPath
        architecture = [ordered]@{
            primaryStyle = if ($architecture) { [string](Get-AppDocOverviewObjectValue -Object $architecture -Name "primaryStyle" -Default "unknown") } else { "unknown" }
            styles = [string[]]$architectureStyles
            frameworks = @($frameworkList)
        }
        counts = [ordered]@{
            codeFiles = if ($OverviewData) { [int](Get-AppDocOverviewObjectValue -Object $OverviewData -Name "codeFileCount" -Default 0) } else { 0 }
            endpointRecords = $endpointRecords.Count
            inboundEndpoints = $inboundEndpoints.Count
            outboundEndpoints = $outboundEndpoints.Count
            outboundMappedEndpoints = $mappedOutbound.Count
            modelRecords = $modelRecords.Count
            configurationRecords = $configRecords.Count
            dependencyRecords = $dependencyRecords.Count
        }
        languageCount = $languageCount
        facts = [ordered]@{
            what_it_does = @($whatItDoes)
            inputs = @($inputs)
            processing_steps = @($processingSteps)
            outputs = @($outputs)
            external_systems = @($externalSystems)
            confidence_notes = @($confidenceNotes)
        }
        evidence_refs = @($indexedRecords)
    }

    return $truthPack
}

function Write-AppDocOverviewTruthPack {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [hashtable]$TruthPack
    )

    $evidenceDir = Join-Path $RootPath (Join-Path "docs" "evidence")
    if (-not (Test-Path $evidenceDir)) {
        New-Item -Path $evidenceDir -ItemType Directory -Force | Out-Null
    }

    $outputPath = Join-Path $evidenceDir "overview-truth-pack.json"
    $payload = [ordered]@{}
    foreach ($key in @($TruthPack.Keys)) {
        $payload[$key] = $TruthPack[$key]
    }

    if (Get-Command Get-AppDocDeterministicHash -ErrorAction SilentlyContinue) {
        $excludeKeys = @("generatedAt", "updatedAt", "timestamp")
        $payload.determinism = [ordered]@{
            hashAlgorithm = "SHA256"
            excludeKeys = $excludeKeys
            contentHash = (Get-AppDocDeterministicHash -InputObject $payload -ExcludeKeys $excludeKeys)
        }
    }

    $payload | ConvertTo-Json -Depth 40 | Out-File -FilePath $outputPath -Encoding UTF8
    return $outputPath
}

Export-ModuleMember -Function @(
    'Get-AppDocOverviewTruthPackData',
    'Write-AppDocOverviewTruthPack'
)
