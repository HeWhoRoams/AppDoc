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

Export-ModuleMember -Function @(
    'Sanitize-AppDocMarkdownCell',
    'Get-AppDocNormalizedEndpointPath',
    'Get-AppDocEndpointStatusHint',
    'Get-AppDocEndpointDomain',
    'Get-AppDocEndpointDescription',
    'Get-AppDocEndpointFamilyPath',
    'Get-AppDocSemanticEndpointFamily'
)
