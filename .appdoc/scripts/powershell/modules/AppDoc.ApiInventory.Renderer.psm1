function Sanitize-AppDocMarkdownCell {
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

    $candidate = Sanitize-AppDocMarkdownCell -Value $Description -MaxLength 180
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
            Where-Object { $_.auth -and $_.auth -ne "None" } |
            Sort-Object @{Expression = { $_.domain }}, @{Expression = { $_.path }}, @{Expression = { $_.method }} |
            Select-Object -First 30 |
            ForEach-Object {
                $actionId = Get-AppDocEndpointActionId -Endpoint $_
                $name = Sanitize-AppDocMarkdownCell -Value ("{0}.{1}" -f $_.controller, $actionId) -MaxLength 100
                $path = Sanitize-AppDocMarkdownCell -Value $_.path -MaxLength 120
                $auth = Sanitize-AppDocMarkdownCell -Value $_.auth -MaxLength 80
                $source = if ($_.filePath) { "{0}:{1}" -f [string]$_.filePath, [int]$_.lineNumber } else { "unknown" }
                $source = Sanitize-AppDocMarkdownCell -Value $source -MaxLength 120
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
        "ANY" = 6
    }

    $detailedEndpoints = @(
        $Endpoints |
            Sort-Object `
                @{ Expression = { if ($_.auth -and $_.auth -ne "None") { 0 } else { 1 } } }, `
                @{ Expression = { if ($methodPriority.ContainsKey([string]$_.method)) { $methodPriority[[string]$_.method] } else { 99 } } }, `
                @{ Expression = { [string]$_.domain } }, `
                @{ Expression = { [string]$_.path } } |
            Select-Object -First $MaxDetailedRows
    )

    $tableHeader = "| Name | Path | Method | Description | Parameters | Return Type | Status Codes | Auth Required |`n|------|------|--------|-------------|------------|------------|--------------|---------------|"
    $tableRows = @($detailedEndpoints | ForEach-Object {
        $actionId = Get-AppDocEndpointActionId -Endpoint $_
        $name = Sanitize-AppDocMarkdownCell -Value ("{0}.{1}" -f $_.controller, $actionId) -MaxLength 100
        $path = Sanitize-AppDocMarkdownCell -Value $_.path -MaxLength 140
        $desc = Sanitize-AppDocMarkdownCell -Value $_.description -MaxLength 180
        if ($desc -match '^(GET|POST|PUT|PATCH|DELETE|ANY)\s+/.+\s+endpoint$' -or $desc -eq 'AST extracted endpoint') {
            $descSource = if ($_.filePath) { "{0}:{1}" -f [string]$_.filePath, [int]$_.lineNumber } else { "unknown source" }
            $desc = "Source: $descSource"
        }
        $params = if ($_.parameters -and $_.parameters -ne "None") { Sanitize-AppDocMarkdownCell -Value $_.parameters -MaxLength 160 } else { "None" }
        $returnType = Sanitize-AppDocMarkdownCell -Value $_.returnType -MaxLength 80
        $statusCodes = Sanitize-AppDocMarkdownCell -Value $_.statusCodes -MaxLength 80
        $auth = Sanitize-AppDocMarkdownCell -Value $_.auth -MaxLength 80
        "| ``$name`` | ``$path`` | $($_.method) | $desc | ``$params`` | ``$returnType`` | $statusCodes | $auth |"
    })

    $endpointContent = @(
        "### Coverage Snapshot`n`n- Total endpoints detected: **$($Endpoints.Count)**`n- Domains detected: **$($domainSummaryRows.Count)**`n- Endpoints with explicit auth markers: **$(@($Endpoints | Where-Object { $_.auth -and $_.auth -ne 'None' }).Count)**"
        "### Domain Summary`n`n$domainSummaryTableHeader`n$($domainSummaryTableRows -join "`n")"
        "### Method Distribution`n`n$methodDistributionHeader`n$($methodDistributionRows -join "`n")"
        "### Auth-Sensitive Endpoints`n`n$authSensitiveContent"
        "### Endpoint Catalog`n`n$tableHeader`n$($tableRows -join "`n")`n`n_Detailed catalog is capped to first $($detailedEndpoints.Count) endpoints for readability. Full endpoint evidence is preserved in_ ``docs/evidence/api-inventory.evidence.json``."
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
    if ($before -eq $after) {
        Write-Warning "API Endpoints section not found or could not be updated (no matching heading or delimiter)."
    }
    return $after
}

Export-ModuleMember -Function @(
    'Sanitize-AppDocMarkdownCell',
    'Get-AppDocNormalizedEndpointPath',
    'Get-AppDocEndpointStatusHint',
    'Get-AppDocEndpointDomain',
    'Get-AppDocEndpointDescription',
    'Get-AppDocEndpointFamilyPath',
    'Get-AppDocSemanticEndpointFamily',
    'Get-AppDocApiInventoryMarkdown',
    'Update-AppDocApiInventoryContent'
)
