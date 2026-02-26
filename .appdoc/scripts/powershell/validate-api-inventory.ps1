param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-ApiValidationValue {
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

function Get-ApiSectionContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$SectionName
    )

    $pattern = '(?ims)^##\s+' + [regex]::Escape($SectionName) + '\s*$\r?\n(.*?)(?=^##\s+[^\r\n]+|\z)'
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return [string]$match.Groups[1].Value
    }
    return ""
}

Write-Progress -Activity "Validating API Inventory" -Status "Checking inventory..." -PercentComplete 0

$inventoryPath = Join-Path $RootPath "docs\api-inventory.md"
if (-not (Test-Path $inventoryPath)) {
    Write-Error "API inventory file not found at $inventoryPath"
    exit 1
}

$content = Get-Content $inventoryPath -Raw
if ($content -notmatch '(?im)^#\s+API Inventory\b') {
    Write-Error "Invalid API inventory format (missing title)."
    exit 1
}

$issues = @()
$warnings = @()

$apiSurfaceExpected = $true
$fingerprintPath = Join-Path $RootPath "docs\architecture-fingerprint.json"
if (Test-Path $fingerprintPath) {
    try {
        $fingerprint = Get-Content $fingerprintPath -Raw | ConvertFrom-Json -Depth 80
        if ($null -ne $fingerprint.apiSurfaceExpected) {
            $apiSurfaceExpected = [bool]$fingerprint.apiSurfaceExpected
        }
    }
    catch {
        $warnings += "architecture-fingerprint-unparseable"
    }
}

$evidencePath = Join-Path $RootPath "docs\evidence\api-inventory.evidence.json"
$evidenceEndpointCount = 0
$evidenceInboundCount = 0
$evidenceOutboundCount = 0
if (Test-Path $evidencePath) {
    try {
        $evidence = Get-Content $evidencePath -Raw | ConvertFrom-Json -Depth 120
        $endpointRecords = @(
            Get-ApiValidationValue -Object $evidence -Name "records" -Default @() |
                Where-Object { $_ -and [string]$_.kind -eq "endpoint" }
        )
        $evidenceEndpointCount = $endpointRecords.Count
        foreach ($record in $endpointRecords) {
            $metadata = Get-ApiValidationValue -Object $record -Name "metadata" -Default @{}
            $direction = [string](Get-ApiValidationValue -Object $metadata -Name "direction" -Default "")
            if ([string]::IsNullOrWhiteSpace($direction)) {
                $sourceType = [string](Get-ApiValidationValue -Object $metadata -Name "sourceType" -Default "")
                $name = [string](Get-ApiValidationValue -Object $record -Name "name" -Default "")
                if ($sourceType -match '^(?i)(soap-client|wcf-client|asmx-client|proxy-client)$' -or $name -match '^/soap-client/') {
                    $direction = "outbound"
                }
                else {
                    $direction = "inbound"
                }
            }

            if ($direction -eq "outbound") {
                $evidenceOutboundCount++
            }
            else {
                $evidenceInboundCount++
            }
        }
    }
    catch {
        $issues += "api-evidence-unparseable"
    }
}
else {
    $issues += "api-evidence-missing"
}

$graphPath = Join-Path $RootPath "docs\evidence\evidence-graph.json"
$graphInboundCount = -1
$graphOutboundCount = -1
$graphEndpointCount = -1
if (Test-Path $graphPath) {
    try {
        $graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 120
        $metrics = Get-ApiValidationValue -Object $graph -Name "metrics" -Default @{}
        $graphInboundCount = [int](Get-ApiValidationValue -Object $metrics -Name "inboundEndpointCount" -Default 0)
        $graphOutboundCount = [int](Get-ApiValidationValue -Object $metrics -Name "outboundEndpointCount" -Default 0)
        $graphEndpointCount = $graphInboundCount + $graphOutboundCount
    }
    catch {
        $issues += "evidence-graph-unparseable"
    }
}
else {
    $warnings += "evidence-graph-missing"
}

if ($graphEndpointCount -ge 0 -and $graphEndpointCount -ne $evidenceEndpointCount -and ($issues -notcontains 'api-evidence-unparseable') -and ($issues -notcontains 'api-evidence-missing')) {
    $issues += ("graph-evidence-endpoint-mismatch:{0}/{1}" -f $graphEndpointCount, $evidenceEndpointCount)
}
if ($graphInboundCount -ge 0 -and $graphInboundCount -ne $evidenceInboundCount -and ($issues -notcontains 'api-evidence-unparseable') -and ($issues -notcontains 'api-evidence-missing')) {
    $issues += ("graph-evidence-inbound-mismatch:{0}/{1}" -f $graphInboundCount, $evidenceInboundCount)
}
if ($graphOutboundCount -ge 0 -and $graphOutboundCount -ne $evidenceOutboundCount -and ($issues -notcontains 'api-evidence-unparseable') -and ($issues -notcontains 'api-evidence-missing')) {
    $issues += ("graph-evidence-outbound-mismatch:{0}/{1}" -f $graphOutboundCount, $evidenceOutboundCount)
}

$apiSection = Get-ApiSectionContent -Content $content -SectionName "API Endpoints"
$noEndpointTextPresent = ($apiSection -match '(?i)_No API endpoints detected')
if ($evidenceEndpointCount -gt 0 -and $noEndpointTextPresent) {
    $issues += "placeholder-present-with-nonzero-evidence"
}
if ($evidenceEndpointCount -eq 0 -and $apiSurfaceExpected -and $noEndpointTextPresent) {
    $issues += "api-surface-expected-but-empty"
}
if ($evidenceEndpointCount -eq 0 -and -not $apiSurfaceExpected -and -not $noEndpointTextPresent) {
    $warnings += "no-api-surface-but-missing-explicit-empty-note"
}

$snapshotMatch = [regex]::Match(
    $content,
    '(?im)^\s*-\s*Total endpoints detected:\s*\*\*(\d+)\*\*\s*$[\r\n]+^\s*-\s*Inbound endpoints:\s*\*\*(\d+)\*\*\s*$[\r\n]+^\s*-\s*Outbound API integrations:\s*\*\*(\d+)\*\*\s*$'
)
if ($snapshotMatch.Success) {
    $snapshotTotal = [int]$snapshotMatch.Groups[1].Value
    $snapshotInbound = [int]$snapshotMatch.Groups[2].Value
    $snapshotOutbound = [int]$snapshotMatch.Groups[3].Value

    if ($snapshotTotal -ne $evidenceEndpointCount) {
        $issues += ("snapshot-total-mismatch:{0}/{1}" -f $snapshotTotal, $evidenceEndpointCount)
    }
    if ($snapshotInbound -ne $evidenceInboundCount) {
        $issues += ("snapshot-inbound-mismatch:{0}/{1}" -f $snapshotInbound, $evidenceInboundCount)
    }
    if ($snapshotOutbound -ne $evidenceOutboundCount) {
        $issues += ("snapshot-outbound-mismatch:{0}/{1}" -f $snapshotOutbound, $evidenceOutboundCount)
    }
}
elseif ($evidenceEndpointCount -gt 0) {
    $issues += "coverage-snapshot-missing"
}

Write-Progress -Activity "Validating API Inventory" -Status "Complete" -PercentComplete 100

if ($issues.Count -gt 0) {
    Write-Host "API inventory validation failed:" -ForegroundColor Red
    foreach ($issue in ($issues | Select-Object -Unique)) {
        Write-Host (" - {0}" -f $issue) -ForegroundColor Red
    }
    exit 1
}

foreach ($warning in ($warnings | Select-Object -Unique)) {
    Write-Warning ("[validate-api-inventory] {0}" -f $warning)
}

Write-Host ("API inventory validated: {0} endpoints found ({1} inbound, {2} outbound)" -f $evidenceEndpointCount, $evidenceInboundCount, $evidenceOutboundCount)
