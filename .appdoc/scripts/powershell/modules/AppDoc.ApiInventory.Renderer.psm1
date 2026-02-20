function Format-AppDocMarkdownCell {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,
        [int]$MaxLength = 140
    )

    if ($null -eq $Value) { return "" }

    $text = [string]$Value
    $text = $text -replace '[\r\n\t]+', ' '
    $text = $text -replace '\|', '\\|'
    $text = $text -replace '\s+', ' '
    $text = $text.Trim()

    if ($text.Length -gt $MaxLength) {
        return $text.Substring(0, $MaxLength - 3) + "..."
    }

    return $text
}

function Get-AppDocNormalizedEndpointPath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$Path,
        [AllowNull()]
        [string]$Controller,
        [AllowNull()]
        [string]$Method
    )

    $normalized = if ($Path) { [string]$Path } else { "" }
    $normalized = $normalized.Trim()
    $normalized = $normalized -replace '\\', '/'

    if (-not $normalized) {
        $controllerPart = if ($Controller) { ([string]$Controller).Trim() } else { "endpoint" }
        $methodPart = if ($Method) { ([string]$Method).Trim().ToLowerInvariant() } else { "action" }
        $normalized = "/$controllerPart/$methodPart"
    }

    if ($normalized -notmatch '^(https?://|/)') {
        $normalized = "/$normalized"
    }

    $normalized = $normalized -replace '/{2,}', '/'
    $normalized = $normalized -replace '/\s+', '/'
    $normalized = $normalized.Trim()

    if (-not $normalized.StartsWith('/')) {
        $normalized = "/$normalized"
    }

    return $normalized
}

function Get-AppDocEndpointStatusHint {
    [CmdletBinding()]
    param([string]$Method)

    switch (($Method ?? "").ToUpperInvariant()) {
        "GET" { return "200, 404, 500" }
        "POST" { return "201, 400, 401, 500" }
        "PUT" { return "200, 400, 404, 500" }
        "PATCH" { return "200, 400, 404, 500" }
        "DELETE" { return "204, 404, 500" }
        "SOAP" { return "200, SOAP Fault, 500" }
        default { return "200, 400, 500" }
    }
}

function Get-AppDocEndpointDomain {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$Controller
    )

    if ($Path -match '^/([^/\{\?]+)') {
        return $Matches[1]
    }

    if ($Controller -and $Controller -ne "Other") {
        return $Controller
    }

    return "general"
}

function Get-AppDocEndpointDescription {
    [CmdletBinding()]
    param(
        [string]$Description,
        [string]$Method,
        [string]$Path
    )

    $candidate = Format-AppDocMarkdownCell -Value $Description -MaxLength 180
    if ($candidate -and $candidate -notmatch '^(API endpoint|endpoint)$') {
        return $candidate
    }

    return ("{0} {1} endpoint" -f (($Method ?? "ANY").ToUpperInvariant()), $Path)
}

function Get-AppDocEndpointFamilyPath {
    [CmdletBinding()]
    param([string]$Path)

    if (-not $Path) { return "/unknown" }

    $normalized = [string]$Path
    $normalized = $normalized -replace '/\d+(?=/|$)', '/{id}'
    $normalized = $normalized -replace '/[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,35}(?=/|$)', '/{id}'
    $normalized = $normalized -replace '/[A-Za-z0-9_-]{24,}(?=/|$)', '/{value}'
    $normalized = $normalized -replace '/{2,}', '/'

    return $normalized.ToLowerInvariant()
}

function Get-AppDocSemanticEndpointFamily {
    [CmdletBinding()]
    param([string]$Path)

    if (-not $Path) { return "/unknown" }

    $normalized = ([string]$Path).ToLowerInvariant()
    $normalized = $normalized -replace '\\', '/'
    $normalized = $normalized -replace '\?.*$', ''

    $segments = @($normalized -split '/' | Where-Object { $_ -and $_.Trim() })
    if ($segments.Count -eq 0) { return "/unknown" }

    $actionTokens = @(
        'get','post','put','patch','delete','remove','index','list','create','update',
        'save','set','edit','add','commit','assign','reassign','bulk','map','report'
    )
    $actionPrefixPattern = '^(get|post|put|patch|delete|remove|create|update|save|set|edit|add|commit|assign|reassign)'

    $root = [string]$segments[0]
    if ($root -match '^\{.+\}$' -or $root -match '^:') {
        return "/unknown"
    }

    if ($segments.Count -eq 1) {
        return "/$root"
    }

    $second = [string]$segments[1]
    if ($second -match '^\{.+\}$' -or $second -match '^:') {
        return "/$root"
    }

    if (($actionTokens -contains $second) -or ($second -match $actionPrefixPattern)) {
        return "/$root"
    }

    return "/$root/$second"
}

function Get-AppDocEndpointActionId {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [PSObject]$Endpoint
    )

    if ($Endpoint -is [System.Collections.IDictionary]) {
        if ($Endpoint.Contains("actionName") -and $Endpoint["actionName"]) {
            return [string]$Endpoint["actionName"]
        }
        if ($Endpoint.Contains("methodName") -and $Endpoint["methodName"]) {
            return [string]$Endpoint["methodName"]
        }
    }

    if ($Endpoint.PSObject.Properties["actionName"] -and $Endpoint.actionName) {
        return $Endpoint.actionName
    }
    if ($Endpoint.PSObject.Properties["methodName"] -and $Endpoint.methodName) {
        return $Endpoint.methodName
    }
    return $Endpoint.method
}

function Get-AppDocApiInventoryMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Endpoints,
        [int]$MaxDetailedRows = 120
    )

    $endpointTablePlaceholder = @"
| Name | Path | Method | Description | Parameters | Return Type | Status Codes | Auth Required |
|------|------|--------|-------------|------------|------------|--------------|---------------|

_No API endpoints detected. This codebase may not expose HTTP APIs, or uses patterns not yet recognized by the scanner._
"@

    if (-not $Endpoints -or $Endpoints.Count -eq 0) {
        return [ordered]@{
            endpointContent = $endpointTablePlaceholder
            endpointTablePlaceholder = $endpointTablePlaceholder
        }
    }

    $directionResolver = {
        param($endpoint)
        $direction = ""
        if ($endpoint -is [System.Collections.IDictionary]) {
            if ($endpoint.Contains("direction")) {
                $direction = [string]$endpoint["direction"]
            }
        }
        elseif ($endpoint.PSObject.Properties["direction"]) {
            $direction = [string]$endpoint.direction
        }

        if (-not $direction) {
            if ($endpoint -is [System.Collections.IDictionary]) {
                $sourceType = if ($endpoint.Contains("sourceType") -and $endpoint["sourceType"]) { [string]$endpoint["sourceType"] } else { "" }
                $path = if ($endpoint.Contains("path") -and $endpoint["path"]) { [string]$endpoint["path"] } else { "" }
            }
            else {
                $sourceType = if ($endpoint.PSObject.Properties["sourceType"] -and $endpoint.sourceType) { [string]$endpoint.sourceType } else { "" }
                $path = if ($endpoint.PSObject.Properties["path"] -and $endpoint.path) { [string]$endpoint.path } else { "" }
            }
            if ($sourceType -eq "soap-client" -or $path -match '^/soap-client/') {
                $direction = "outbound"
            }
            else {
                $direction = "inbound"
            }
        }

        return $direction.ToLowerInvariant()
    }

    $inboundEndpoints = @($Endpoints | Where-Object { (& $directionResolver $_) -eq "inbound" })
    $outboundEndpoints = @($Endpoints | Where-Object { (& $directionResolver $_) -eq "outbound" })

    $directionSummaryHeader = "| Direction | Endpoints | Unique Paths | Methods |`n|-----------|-----------|--------------|---------|"
    $directionSummaryRows = @(
        @(
            @{ name = "Inbound"; rows = $inboundEndpoints },
            @{ name = "Outbound"; rows = $outboundEndpoints }
        ) | ForEach-Object {
            $rows = @($_.rows)
            $methods = @($rows | Select-Object -ExpandProperty method -Unique | Sort-Object)
            $uniquePaths = @($rows | Select-Object -ExpandProperty path -Unique).Count
            "| $($_.name) | $($rows.Count) | $uniquePaths | $(if ($methods.Count -gt 0) { $methods -join ', ' } else { "N/A" }) |"
        }
    )

    $domainSummaryRows = @($Endpoints | Group-Object -Property domain | Sort-Object Count -Descending)
    $domainSummaryTableHeader = "| Domain | Endpoints | Unique Paths | Methods |`n|--------|-----------|--------------|---------|"
    $domainSummaryTableRows = @($domainSummaryRows | ForEach-Object {
        $uniquePaths = @($_.Group | Select-Object -ExpandProperty path -Unique).Count
        $methods = @($_.Group | Select-Object -ExpandProperty method -Unique | Sort-Object)
        "| $($_.Name) | $($_.Count) | $uniquePaths | $($methods -join ', ') |"
    })

    $methodDistributionHeader = "| Method | Endpoints |`n|--------|-----------|"
    $methodDistributionRows = @(
        $Endpoints |
            Group-Object -Property method |
            Sort-Object Count -Descending |
            ForEach-Object { "| $($_.Name) | $($_.Count) |" }
    )

    $authSensitiveHeader = "| Name | Path | Method | Auth | Source |`n|------|------|--------|------|--------|"
    $authSensitiveRows = @(
        $Endpoints |
            Where-Object {
                $_.auth -and
                $_.auth -ne "None" -and
                $_.auth -ne "Client binding" -and
                $_.auth -ne "Service policy"
            } |
            Sort-Object @{Expression = { $_.domain }}, @{Expression = { $_.path }}, @{Expression = { $_.method }} |
            Select-Object -First 30 |
            ForEach-Object {
                $actionId = Get-AppDocEndpointActionId -Endpoint $_
                $name = Format-AppDocMarkdownCell -Value ("{0}.{1}" -f $_.controller, $actionId) -MaxLength 100
                $path = Format-AppDocMarkdownCell -Value $_.path -MaxLength 120
                $auth = Format-AppDocMarkdownCell -Value $_.auth -MaxLength 80
                $source = if ($_.filePath) { "{0}:{1}" -f [string]$_.filePath, [int]$_.lineNumber } else { "unknown" }
                $source = Format-AppDocMarkdownCell -Value $source -MaxLength 120
                "| ``$name`` | ``$path`` | $($_.method) | $auth | ``$source`` |"
            }
    )
    $authSensitiveContent = if ($authSensitiveRows.Count -gt 0) {
        "$authSensitiveHeader`n$($authSensitiveRows -join "`n")"
    } else {
        "No endpoints with explicit authentication markers were detected."
    }

    $methodPriority = @{
        "POST" = 1
        "PUT" = 2
        "PATCH" = 3
        "DELETE" = 4
        "GET" = 5
        "SOAP" = 6
        "ANY" = 7
    }

    $inboundLimit = if ($inboundEndpoints.Count -gt 0 -and $outboundEndpoints.Count -gt 0) { [Math]::Max(20, [int][Math]::Floor($MaxDetailedRows * 0.6)) } else { $MaxDetailedRows }
    $outboundLimit = if ($inboundEndpoints.Count -gt 0 -and $outboundEndpoints.Count -gt 0) { [Math]::Max(15, ($MaxDetailedRows - $inboundLimit)) } else { $MaxDetailedRows }

    $inboundDetailedEndpoints = @(
        $inboundEndpoints |
            Sort-Object `
                @{ Expression = { if ($_.auth -and $_.auth -ne "None") { 0 } else { 1 } } }, `
                @{ Expression = { if ($methodPriority.ContainsKey([string]$_.method)) { $methodPriority[[string]$_.method] } else { 99 } } }, `
                @{ Expression = { [string]$_.domain } }, `
                @{ Expression = { [string]$_.path } } |
            Select-Object -First $inboundLimit
    )

    $outboundDetailedEndpoints = @(
        $outboundEndpoints |
            Sort-Object `
                @{ Expression = { if ($_.integrationUrl) { 0 } else { 1 } } }, `
                @{ Expression = { [string]$_.integrationUrl } }, `
                @{ Expression = { [string]$_.controller } }, `
                @{ Expression = { [string]$_.path } } |
            Select-Object -First $outboundLimit
    )

    $inboundTableHeader = "| Name | Path | Method | Description | Parameters | Return Type | Status Codes | Auth Required | Source |`n|------|------|--------|-------------|------------|------------|--------------|---------------|--------|"
    $inboundTableRows = @($inboundDetailedEndpoints | ForEach-Object {
        $actionId = Get-AppDocEndpointActionId -Endpoint $_
        $name = Format-AppDocMarkdownCell -Value ("{0}.{1}" -f $_.controller, $actionId) -MaxLength 100
        $path = Format-AppDocMarkdownCell -Value $_.path -MaxLength 140
        $desc = Format-AppDocMarkdownCell -Value $_.description -MaxLength 180
        if ($desc -match '^(GET|POST|PUT|PATCH|DELETE|ANY|SOAP)\s+/.+\s+endpoint$' -or $desc -eq 'AST extracted endpoint' -or $desc -eq 'API endpoint') {
            if ($actionId -and ($actionId -notin @("GET","POST","PUT","PATCH","DELETE","ANY","SOAP"))) {
                $desc = "Action method: $actionId"
            }
            else {
                $desc = "Controller action endpoint"
            }
        }
        $params = if ($_.parameters -and $_.parameters -ne "None") { Format-AppDocMarkdownCell -Value $_.parameters -MaxLength 160 } else { "None" }
        $returnType = Format-AppDocMarkdownCell -Value $_.returnType -MaxLength 80
        $statusCodes = Format-AppDocMarkdownCell -Value $_.statusCodes -MaxLength 80
        $auth = Format-AppDocMarkdownCell -Value $_.auth -MaxLength 80
        $source = if ($_.filePath) { "{0}:{1}" -f [string]$_.filePath, [int]$_.lineNumber } else { "unknown" }
        $source = Format-AppDocMarkdownCell -Value $source -MaxLength 120
        "| ``$name`` | ``$path`` | $($_.method) | $desc | ``$params`` | ``$returnType`` | $statusCodes | $auth | ``$source`` |"
    })
    $inboundContent = if ($inboundTableRows.Count -gt 0) {
        "$inboundTableHeader`n$($inboundTableRows -join "`n")"
    }
    else {
        "No inbound API endpoints detected in this scan."
    }

    $outboundTableHeader = "| Name | Path | Method | Target URL | Contract | Parameters | Source |`n|------|------|--------|------------|----------|------------|--------|"
    $outboundTableRows = @($outboundDetailedEndpoints | ForEach-Object {
        $actionId = Get-AppDocEndpointActionId -Endpoint $_
        $name = Format-AppDocMarkdownCell -Value ("{0}.{1}" -f $_.controller, $actionId) -MaxLength 100
        $path = Format-AppDocMarkdownCell -Value $_.path -MaxLength 140
        $targetUrl = if ($_.integrationUrl) { [string]$_.integrationUrl } else { "Not mapped in config" }
        $targetUrl = Format-AppDocMarkdownCell -Value $targetUrl -MaxLength 180
        $contract = if ($_.integrationContract) { [string]$_.integrationContract } elseif ($_.contractName) { [string]$_.contractName } else { "N/A" }
        $contract = Format-AppDocMarkdownCell -Value $contract -MaxLength 120
        $params = if ($_.parameters -and $_.parameters -ne "None") { Format-AppDocMarkdownCell -Value $_.parameters -MaxLength 150 } else { "None" }
        $source = if ($_.filePath) { "{0}:{1}" -f [string]$_.filePath, [int]$_.lineNumber } else { "unknown" }
        $source = Format-AppDocMarkdownCell -Value $source -MaxLength 120
        "| ``$name`` | ``$path`` | $($_.method) | ``$targetUrl`` | ``$contract`` | ``$params`` | ``$source`` |"
    })
    $outboundContent = if ($outboundTableRows.Count -gt 0) {
        "$outboundTableHeader`n$($outboundTableRows -join "`n")"
    }
    else {
        "No outbound API integrations detected in this scan."
    }

    $mappedOutboundCount = @($outboundEndpoints | Where-Object { $_.integrationUrl }).Count

    $endpointContent = @(
        "### Coverage Snapshot`n`n- Total endpoints detected: **$($Endpoints.Count)**`n- Inbound endpoints: **$($inboundEndpoints.Count)**`n- Outbound API integrations: **$($outboundEndpoints.Count)**`n- Outbound integrations mapped to config URL: **$mappedOutboundCount**`n- Domains detected: **$($domainSummaryRows.Count)**"
        "### Direction Summary`n`n$directionSummaryHeader`n$($directionSummaryRows -join "`n")"
        "### Domain Summary`n`n$domainSummaryTableHeader`n$($domainSummaryTableRows -join "`n")"
        "### Method Distribution`n`n$methodDistributionHeader`n$($methodDistributionRows -join "`n")"
        "### Auth-Sensitive Endpoints`n`n$authSensitiveContent"
        "### Inbound Endpoint Catalog`n`n$inboundContent"
        "### Outbound API Integrations`n`n$outboundContent`n`n_Detailed catalogs are capped for readability. Full endpoint evidence is preserved in_ ``docs/evidence/api-inventory.evidence.json``."
    ) -join "`n`n"

    return [ordered]@{
        endpointContent = $endpointContent
        endpointTablePlaceholder = $endpointTablePlaceholder
    }
}

function Update-AppDocApiInventoryContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Endpoints
    )

    $sections = Get-AppDocApiInventoryMarkdown -Endpoints $Endpoints
    $updated = $Content

    if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.endpointTablePlaceholder -NewContent $sections.endpointContent
    }
    else {
        $updated = $updated.Replace($sections.endpointTablePlaceholder, $sections.endpointContent)
    }

    $apiSectionPattern = '(?s)(##\s+API Endpoints\s*\r?\n\r?\n).*?(?=(\r?\n##\s+|$))'
    $before = $updated
    $after = [regex]::Replace(
        $updated,
        $apiSectionPattern,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $sections.endpointContent + "`n")
        }
    )
    if ($before -eq $after -and $after -notmatch '(?im)^##\s+API Endpoints\b') {
        $after = $after.TrimEnd() + "`r`n`r`n## API Endpoints`r`n`r`n" + $sections.endpointContent + "`r`n"
    }

    $sectionFallbacks = [ordered]@{
        'Overview' = 'This inventory is extracted from controller/action evidence and is intended for implementation impact analysis, integration planning, and endpoint ownership review.'
        'Data Models' = 'Data model contracts are documented in [Data Model](data-model.md). Use that catalog for field-level structure and model ownership.'
        'Authentication & Security' = 'Authentication and authorization behavior was not extracted into a normalized API-security section in this run. Review controller attributes, middleware, and config policy in source for enforcement details.'
        'Error Responses' = 'Standardized error response contracts were not explicitly extracted. Validate error semantics in controller branches, exception handling paths, and API consumers before changing behavior.'
        'API Versioning' = 'No explicit versioning mechanism was detected in extracted routes. Treat route and payload compatibility as a release-management concern and document breaking changes explicitly.'
        'Usage Examples' = 'Example request/response payloads were not deterministically captured in this pass. Use endpoint signatures in this file plus controller implementations to author scenario-specific examples during feature work.'
        'Dependencies' = 'No outbound API dependency contract was extracted from route evidence in this run. Review [Dependencies Catalog](dependencies-catalog.md) and configuration URL entries when tracing integration behavior.'
    }
    foreach ($header in $sectionFallbacks.Keys) {
        $sectionPattern = "(?s)(##\s+$([regex]::Escape($header))\s*\r?\n\r?\n)(.*?)(?=(\r?\n##\s+)|\z)"
        $sectionBody = [string]$sectionFallbacks[$header]
        $after = [regex]::Replace(
            $after,
            $sectionPattern,
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                $existingBody = $m.Groups[3].Value.Trim()
                $isPlaceholder = ($existingBody -eq "" -or $existingBody -eq $sectionBody)
                if ($isPlaceholder) {
                    return ($m.Groups[1].Value + $sectionBody + "`r`n")
                } else {
                    return $m.Value
                }
            }
        )
    }

    return $after
}

Export-ModuleMember -Function @(
    'Format-AppDocMarkdownCell',
    'Get-AppDocNormalizedEndpointPath',
    'Get-AppDocEndpointStatusHint',
    'Get-AppDocEndpointDomain',
    'Get-AppDocEndpointDescription',
    'Get-AppDocEndpointFamilyPath',
    'Get-AppDocSemanticEndpointFamily',
    'Get-AppDocApiInventoryMarkdown',
    'Update-AppDocApiInventoryContent'
)
