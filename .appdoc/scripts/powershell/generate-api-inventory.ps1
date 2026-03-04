#
# generate-api-inventory.ps1
#
# Purpose: Scans the target codebase for API endpoints and populates
#          the api-inventory template.
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

$apiExtractorModule = Join-Path $PSScriptRoot "modules\AppDoc.ApiInventory.Extractor.psm1"
if (-not (Test-Path $apiExtractorModule)) { Write-Error "Required module not found: $apiExtractorModule"; exit 1 }
Import-Module $apiExtractorModule -Force -ErrorAction Stop

$apiRendererModule = Join-Path $PSScriptRoot "modules\AppDoc.ApiInventory.Renderer.psm1"
if (-not (Test-Path $apiRendererModule)) { Write-Error "Required module not found: $apiRendererModule"; exit 1 }
Import-Module $apiRendererModule -Force -ErrorAction Stop

$evidenceGraphModule = Join-Path $PSScriptRoot "modules\AppDoc.EvidenceGraph.psm1"
if (Test-Path $evidenceGraphModule) {
    Import-Module $evidenceGraphModule -Force -ErrorAction SilentlyContinue
}

$architectureModule = Join-Path $PSScriptRoot "modules\AppDoc.ArchitectureFingerprint.psm1"
if (Test-Path $architectureModule) {
    Import-Module $architectureModule -Force -ErrorAction SilentlyContinue
}

function Get-AppDocApiOperationIntent {
    param(
        [string]$Method,
        [string]$Direction
    )

    $normalizedMethod = if ($Method) { $Method.Trim().ToUpperInvariant() } else { "ANY" }
    $normalizedDirection = if ($Direction) { $Direction.Trim().ToLowerInvariant() } else { "inbound" }

    if ($normalizedDirection -eq "outbound") { return "Outbound integration call" }

    switch ($normalizedMethod) {
        "GET" { return "Read/query resource" }
        "POST" { return "Create/submit resource" }
        "PUT" { return "Replace/update resource" }
        "PATCH" { return "Partial update" }
        "DELETE" { return "Delete resource" }
        "SOAP" { return "SOAP operation call" }
        default { return "Endpoint operation" }
    }
}

function Get-AppDocApiAuthBoundary {
    param(
        [string]$Auth,
        [string]$Direction
    )

    $normalizedDirection = if ($Direction) { $Direction.Trim().ToLowerInvariant() } else { "inbound" }
    if ($normalizedDirection -eq "outbound") {
        return "External service boundary"
    }

    if ([string]::IsNullOrWhiteSpace($Auth) -or $Auth -eq "None") {
        return "Public/internal boundary not explicit"
    }

    return [string]$Auth
}

function Get-AppDocApiTimeoutRetryHint {
    param(
        [string]$Direction,
        [string]$SourceType
    )

    $normalizedDirection = if ($Direction) { $Direction.Trim().ToLowerInvariant() } else { "inbound" }
    if ($normalizedDirection -eq "outbound") {
        if ($SourceType -and $SourceType -match 'soap|wcf|client') {
            return "Client timeout/retry policy applies; verify binding/client config"
        }
        return "Integration timeout/retry policy should be verified in client config"
    }

    return "Server-side timeout applies; retry expected at caller"
}

function Get-AppDocApiIdempotencyHint {
    param(
        [string]$Method,
        [string]$Direction
    )

    $normalizedDirection = if ($Direction) { $Direction.Trim().ToLowerInvariant() } else { "inbound" }
    if ($normalizedDirection -eq "outbound") { return "Depends on provider contract" }

    $methodValue = if ($null -ne $Method) { [string]$Method } else { "" }
    switch ($methodValue.Trim().ToUpperInvariant()) {
        "GET" { return "Idempotent" }
        "PUT" { return "Idempotent by contract" }
        "DELETE" { return "Idempotent by contract" }
        "PATCH" { return "Potentially non-idempotent" }
        "POST" { return "Non-idempotent" }
        default { return "Unknown" }
    }
}

function Get-AppDocApiConfidence {
    param(
        [string]$SourceType
    )

    $sourceTypeValue = if ($null -ne $SourceType) { [string]$SourceType } else { "" }
    switch ($sourceTypeValue.Trim().ToLowerInvariant()) {
        "ast" { return "high" }
        "ast-route" { return "high" }
        "ast-openapi" { return "high" }
        "soap-client" { return "medium" }
        "regex" { return "medium" }
        default { return "medium" }
    }
}

function Write-AppDocApiInventoryAppendix {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [AllowEmptyCollection()]
        [Parameter(Mandatory=$true)]
        [array]$Endpoints
    )

    $appendixPath = Join-Path $RootPath "docs\api-inventory.appendix.md"
    $appendixDir = Split-Path $appendixPath -Parent
    if (-not (Test-Path $appendixDir)) {
        New-Item -ItemType Directory -Path $appendixDir -Force | Out-Null
    }
    $inbound = @($Endpoints | Where-Object {
        $directionValue = if ($null -ne $_.direction) { [string]$_.direction } else { "inbound" }
        $directionValue.ToLowerInvariant() -ne "outbound"
    })
    $outbound = @($Endpoints | Where-Object {
        $directionValue = if ($null -ne $_.direction) { [string]$_.direction } else { "inbound" }
        $directionValue.ToLowerInvariant() -eq "outbound"
    })

    $toRows = {
        param([array]$Rows)
        foreach ($row in @($Rows | Sort-Object @{ Expression = { [string]$_.controller } }, @{ Expression = { [string]$_.path } }, @{ Expression = { [string]$_.method } })) {
            $direction = if ($row.direction) { [string]$row.direction } else { "inbound" }
            $sourceType = if ($row.sourceType) { [string]$row.sourceType } else { "regex" }
            $name = if ($row.controller) { "{0}.{1}" -f [string]$row.controller, [string]$row.method } else { [string]$row.method }
            $path = if ($row.path) { [string]$row.path } else { "N/A" }
            $operationIntent = Get-AppDocApiOperationIntent -Method ([string]$row.method) -Direction $direction
            $authBoundary = Get-AppDocApiAuthBoundary -Auth ([string]$row.auth) -Direction $direction
            $timeoutRetry = Get-AppDocApiTimeoutRetryHint -Direction $direction -SourceType $sourceType
            $idempotency = Get-AppDocApiIdempotencyHint -Method ([string]$row.method) -Direction $direction
            $confidence = Get-AppDocApiConfidence -SourceType $sourceType
            "| ``$name`` | ``$path`` | $([string]$row.method) | $operationIntent | $authBoundary | $timeoutRetry | $idempotency | $confidence |"
        }
    }

    $inboundRows = @(& $toRows $inbound)
    $outboundRows = @(& $toRows $outbound)
    $appendixHeader = "| Name | Path | Method | Operation Intent | Auth Boundary | Timeout/Retry | Idempotency | Confidence |`n|------|------|--------|------------------|---------------|---------------|-------------|------------|"

    $inboundContent = if ($inboundRows.Count -gt 0) {
        "$appendixHeader`n$($inboundRows -join "`n")"
    }
    else {
        "$appendixHeader`n| N/A | N/A | N/A | N/A | N/A | N/A | N/A | medium |"
    }

    $outboundContent = if ($outboundRows.Count -gt 0) {
        "$appendixHeader`n$($outboundRows -join "`n")"
    }
    else {
        "$appendixHeader`n| N/A | N/A | N/A | N/A | N/A | N/A | N/A | medium |"
    }

    $appendixContent = @(
        "# API Inventory Appendix",
        "",
        "This appendix contains the full endpoint catalog and operational annotations used for architecture and reliability review.",
        "",
        "## Inbound Endpoints",
        "",
        $inboundContent,
        "",
        "## Outbound Integrations",
        "",
        $outboundContent,
        "",
        "---",
        "",
        "**Generated**: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))"
    ) -join "`r`n"

    $appendixContent | Out-File -FilePath $appendixPath -Encoding UTF8 -NoNewline
    return $appendixPath
}

Write-Host "📡 Generating API Inventory..." -ForegroundColor Cyan

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$outputPath = Join-Path $RootPath "docs\api-inventory.md"
$initialized = Initialize-TemplateFile -TemplateName "api-inventory-template.md" -OutputPath $outputPath -RootPath $RootPath
if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating API Inventory" -Status "Scanning for APIs..." -PercentComplete 10
$apiData = Get-AppDocApiInventoryData -ScriptsRoot $PSScriptRoot -RootPath $RootPath
$inventory = $apiData.inventory
$endpoints = @(if ($inventory -and $inventory.endpoints) { $inventory.endpoints } else { @() })

if ($apiData.astEndpointCount -gt 0) {
    Write-Host "  Added $($apiData.astEndpointCount) AST endpoint records" -ForegroundColor Gray
}
Write-Host "  Scanned $($apiData.scannedApiFileCount) potential API files" -ForegroundColor Gray

$apiSurfaceExpected = $true
if (Get-Command Get-AppDocArchitectureFingerprint -ErrorAction SilentlyContinue) {
    try {
        $fingerprint = Get-AppDocArchitectureFingerprint -RootPath $RootPath
        if ($null -ne $fingerprint -and $null -ne $fingerprint.apiSurfaceExpected) {
            $apiSurfaceExpected = [bool]$fingerprint.apiSurfaceExpected
        }
    }
    catch {
        Write-Verbose ("Get-AppDocArchitectureFingerprint failed for RootPath {0}: {1}. apiSurfaceExpected will remain default true." -f $RootPath, $_.Exception.Message)
        # Keep default expected=true when fingerprinting fails.
    }
}

if ($endpoints.Count -eq 0) {
    if ($apiSurfaceExpected) {
        Write-Host "⚠️  No API endpoints detected!" -ForegroundColor Yellow
        Write-Host "   Searched in: $RootPath" -ForegroundColor Gray
        Write-Host "   File extensions: *.js, *.ts, *.cs, *.py, *.java, *.svc, *.asmx" -ForegroundColor Gray
    }
    else {
        Write-Host "ℹ️  No API endpoints detected (architecture fingerprint indicates no inbound API surface)." -ForegroundColor Gray
    }
}

Write-Progress -Activity "Generating API Inventory" -Status "Populating template..." -PercentComplete 80
$content = Get-Content -Path $outputPath -Raw
$content = Update-AppDocApiInventoryContent -Content $content -Endpoints $endpoints
$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Normalize-AppDocMarkdownStructure -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$appendixPath = Write-AppDocApiInventoryAppendix -RootPath $RootPath -Endpoints $endpoints

$artifact = "api-inventory"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$graphContract = $null
if (Get-Command Get-AppDocEvidenceGraphContract -ErrorAction SilentlyContinue) {
    $graphContract = Get-AppDocEvidenceGraphContract
}
$inboundCount = @($endpoints | Where-Object { $_.direction -ne "outbound" }).Count
$outboundCount = @($endpoints | Where-Object { $_.direction -eq "outbound" }).Count
$canonicalEndpointCount = [int]$endpoints.Count
$canonicalInboundCount = [int]$inboundCount
$canonicalOutboundCount = [int]$outboundCount
$canonicalMetricsPath = Join-Path $RootPath "docs\evidence\metrics-canonical.json"
if (Test-Path $canonicalMetricsPath) {
    try {
        $canonical = Get-Content $canonicalMetricsPath -Raw | ConvertFrom-Json -Depth 40
        if ($canonical.totals) {
            $canonicalEndpointCount = [int]($canonical.totals.endpointCount ?? $canonicalEndpointCount)
            $canonicalInboundCount = [int]($canonical.totals.inboundEndpointCount ?? $canonicalInboundCount)
            $canonicalOutboundCount = [int]($canonical.totals.outboundEndpointCount ?? $canonicalOutboundCount)
        }
    }
    catch {
        Write-Verbose ("Unable to read canonical metrics for API inventory alignment: {0}" -f $_.Exception.Message)
    }
}
$evidenceRecords = @(
    $endpoints | ForEach-Object {
        $sourcePath = if ([string]::IsNullOrWhiteSpace([string]$_.filePath)) { "unknown" } else { [string]$_.filePath }
        $endpointName = if ([string]::IsNullOrWhiteSpace([string]$_.path)) { "{0}:{1}" -f [string]$_.method, [string]$_.controller } else { [string]$_.path }
        New-AppDocExtractionRecord -Artifact $artifact -Source $sourcePath -Name $endpointName -Kind "endpoint" -Confidence 0.8 -Provider "generator" -ProviderType "deterministic" -Metadata @{
            method = [string]$_.method
            controller = [string]$_.controller
            lineNumber = [int]$_.lineNumber
            returnType = [string]$_.returnType
            parameters = [string]$_.parameters
            auth = [string]$_.auth
            description = [string]$_.description
            direction = if ($_.direction) { [string]$_.direction } else { "inbound" }
            sourceType = if ($_.sourceType) { [string]$_.sourceType } else { "regex" }
            integrationUrl = if ($_.integrationUrl) { [string]$_.integrationUrl } else { "" }
            integrationContract = if ($_.integrationContract) { [string]$_.integrationContract } elseif ($_.contractName) { [string]$_.contractName } else { "" }
        }
    }
)
$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    generator = "generate-api-inventory.ps1"
    endpointCount = [int]$canonicalEndpointCount
    inboundEndpointCount = [int]$canonicalInboundCount
    outboundEndpointCount = [int]$canonicalOutboundCount
    graphSchemaTarget = if ($graphContract) { [string]$graphContract.schemaVersion } else { "" }
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-api-inventory.ps1"
    })
}

Write-Progress -Activity "Generating API Inventory" -Status "Complete" -PercentComplete 100
Write-Host "✅ API inventory generated: $outputPath" -ForegroundColor Green
Write-Host "   Appendix generated: $appendixPath" -ForegroundColor Gray
Write-Host "   Endpoints found: $($endpoints.Count)" -ForegroundColor Gray
