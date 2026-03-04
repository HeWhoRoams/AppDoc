param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

function Get-OverviewSectionContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$Heading
    )

    $pattern = '(?ims)^##\s+' + [regex]::Escape($Heading) + '\s*$\r?\n(.*?)(?=^##\s+[^\r\n]+|\z)'
    $match = [regex]::Match($Content, $pattern)
    if ($match.Success) {
        return [string]$match.Groups[1].Value
    }
    return ""
}

function Get-OverviewSubsectionContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$SectionContent,
        [Parameter(Mandatory=$true)]
        [string]$SubHeading
    )

    $pattern = '(?ims)^###\s+' + [regex]::Escape($SubHeading) + '\s*$\r?\n(.*?)(?=^###\s+[^\r\n]+|\z)'
    $match = [regex]::Match($SectionContent, $pattern)
    if ($match.Success) {
        return [string]$match.Groups[1].Value
    }
    return ""
}

function Get-OverviewValue {
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

Write-Progress -Activity "Validating Overview" -Status "Checking overview sections..." -PercentComplete 0

$overviewPath = Join-Path $RootPath "docs\overview.md"
if (-not (Test-Path $overviewPath)) {
    Write-Error "overview.md not found at $overviewPath"
    exit 1
}

$overview = Get-Content $overviewPath -Raw
$issues = @()

$requiredSections = @(
    "System Boundary",
    "Runtime Path",
    "Inputs→Processing→Outputs",
    "External Systems",
    "Confidence Notes"
)

foreach ($section in $requiredSections) {
    if (-not [regex]::IsMatch($overview, "(?im)^##\s+" + [regex]::Escape($section) + "\b")) {
        $issues += "missing-section:$section"
    }
}

$fingerprintPath = Join-Path $RootPath "docs\architecture-fingerprint.json"
if (Test-Path $fingerprintPath) {
    try {
        $fingerprint = Get-Content $fingerprintPath -Raw | ConvertFrom-Json -Depth 40
        $primaryStyle = [string](Get-OverviewValue -Object $fingerprint -Name "primaryStyle" -Default "")
        if (-not [string]::IsNullOrWhiteSpace($primaryStyle) -and $overview -notmatch [regex]::Escape($primaryStyle)) {
            $issues += "architecture-statement-missing-primary-style"
        }
    }
    catch {
        $issues += "architecture-fingerprint-unparseable"
    }
}

if ($overview -match '(?im)\b(contradiction unresolved|architecture contradiction|conflicting architecture)\b') {
    $issues += "unresolved-contradiction-language-present"
}

$truthPackPath = Join-Path $RootPath "docs\evidence\overview-truth-pack.json"
$graphPath = Join-Path $RootPath "docs\evidence\evidence-graph.json"
if ((Test-Path $truthPackPath) -and (Test-Path $graphPath)) {
    try {
        $truthPack = Get-Content $truthPackPath -Raw | ConvertFrom-Json -Depth 100
        $graph = Get-Content $graphPath -Raw | ConvertFrom-Json -Depth 100

        $counts = Get-OverviewValue -Object $truthPack -Name "counts" -Default @{}
        $graphMetrics = Get-OverviewValue -Object $graph -Name "metrics" -Default @{}

        $truthInbound = [int](Get-OverviewValue -Object $counts -Name "inboundEndpoints" -Default 0)
        $truthOutbound = [int](Get-OverviewValue -Object $counts -Name "outboundEndpoints" -Default 0)
        $truthModel = [int](Get-OverviewValue -Object $counts -Name "modelRecords" -Default 0)
        $truthConfig = [int](Get-OverviewValue -Object $counts -Name "configurationRecords" -Default 0)
        $truthDependency = [int](Get-OverviewValue -Object $counts -Name "dependencyRecords" -Default 0)

        $graphInbound = [int](Get-OverviewValue -Object $graphMetrics -Name "inboundEndpointCount" -Default 0)
        $graphOutbound = [int](Get-OverviewValue -Object $graphMetrics -Name "outboundEndpointCount" -Default 0)
        $graphModel = [int](Get-OverviewValue -Object $graphMetrics -Name "modelCount" -Default 0)
        $graphConfig = [int](Get-OverviewValue -Object $graphMetrics -Name "configCount" -Default 0)
        $graphDependency = [int](Get-OverviewValue -Object $graphMetrics -Name "dependencyCount" -Default 0)

        if ($truthInbound -ne $graphInbound) { $issues += "graph-count-mismatch:inboundEndpoints:$truthInbound/$graphInbound" }
        if ($truthOutbound -ne $graphOutbound) { $issues += "graph-count-mismatch:outboundEndpoints:$truthOutbound/$graphOutbound" }
        if ($truthModel -ne $graphModel) { $issues += "graph-count-mismatch:modelRecords:$truthModel/$graphModel" }
        if ($truthConfig -ne $graphConfig) { $issues += "graph-count-mismatch:configurationRecords:$truthConfig/$graphConfig" }
        if ($truthDependency -ne $graphDependency) { $issues += "graph-count-mismatch:dependencyRecords:$truthDependency/$graphDependency" }
    }
    catch {
        $issues += "graph-or-truth-pack-parse-error: $($_.Exception.Message)"
    }
}

Write-Progress -Activity "Validating Overview" -Status "Complete" -PercentComplete 100

if ($issues.Count -gt 0) {
    Write-Host "Overview validation failed:" -ForegroundColor Red
    foreach ($issue in $issues) {
        Write-Host " - $issue" -ForegroundColor Red
    }
    exit 1
}

Write-Host "Overview validation passed" -ForegroundColor Green
