function Invoke-AppDocApiAstParserScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptsRoot,
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $scriptPath = Join-Path $ScriptsRoot $ScriptName
    if (-not (Test-Path $scriptPath)) {
        return $null
    }

    try {
        & $scriptPath -RootPath $RootPath -Json | Out-Null
    }
    catch {
        Write-Verbose "AST parser execution failed ($ScriptName): $($_.Exception.Message)"
        return $null
    }

    $cacheFile = if ($ScriptName -eq "parse-csharp-ast.ps1") { "ast-csharp-cache.json" } else { "ast-typescript-cache.json" }
    $cachePath = Join-Path $RootPath (Join-Path "docs" $cacheFile)
    if (-not (Test-Path $cachePath)) {
        return $null
    }

    try {
        return (Get-Content $cachePath -Raw | ConvertFrom-Json)
    }
    catch {
        Write-Verbose "Unable to parse AST cache ($cacheFile): $($_.Exception.Message)"
        return $null
    }
}

function Add-AppDocAstEndpointsToInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$AstPayload,
        [Parameter(Mandatory = $true)]
        [hashtable]$Inventory,
        [string]$RootPath
    )

    if (-not $AstPayload -or -not $AstPayload.records) {
        return 0
    }

    $added = 0
    foreach ($record in $AstPayload.records) {
        if ($record.kind -ne "endpoint") { continue }
        if (-not $record.metadata) { continue }

        $method = [string]$record.metadata.method
        $path = [string]$record.metadata.path
        if (-not $method -or -not $path) { continue }

        $parameters = "None"
        if ($record.metadata.parameters) {
            if ($record.metadata.parameters -is [System.Array]) {
                $parameters = (($record.metadata.parameters | ForEach-Object { [string]$_ }) -join ', ')
            }
            else {
                $parameters = [string]$record.metadata.parameters
            }
        }

        $filePath = [string]$record.file
        if ($filePath -and (Get-Command Test-AppDocPathIncluded -ErrorAction SilentlyContinue)) {
            $scopeArgs = @{
                Path = $filePath
                Artifact = "api-inventory"
            }
            if ($RootPath) {
                $scopeArgs.RootPath = $RootPath
            }

            if (-not (Test-AppDocPathIncluded @scopeArgs)) { continue }
        }
        $fileName = if ($filePath) { [System.IO.Path]::GetFileName($filePath) } else { "unknown" }

        $Inventory.endpoints += @{
            method = $method.ToUpper()
            path = $path
            file = $fileName
            filePath = $filePath
            lineNumber = if ($record.lineNumber) { [int]$record.lineNumber } else { 1 }
            parameters = if ($parameters) { $parameters } else { "None" }
            returnType = if ($record.metadata.returnType) { [string]$record.metadata.returnType } else { "unknown" }
            auth = if ($record.metadata.auth) { [string]$record.metadata.auth } else { "None" }
            description = if ($record.metadata.description) { [string]$record.metadata.description } else { "AST extracted endpoint" }
            example = $null
            controller = if ($record.metadata.controller) { [string]$record.metadata.controller } else { "Other" }
            schema = if ($parameters -and $parameters -ne "None") { "See parameters" } else { "N/A" }
            sourceType = "ast"
        }
        $added++
    }

    return $added
}

function Get-AppDocApiRelativePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    if (Get-Command Get-AppDocRelativePath -ErrorAction SilentlyContinue) {
        return (Get-AppDocRelativePath -RootPath $RootPath -Path $Path)
    }

    return $Path.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
}

function Get-AppDocApiScopedFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string[]]$Include
    )

    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "api-inventory" -Include $Include)
    }

    return @(
        (Get-ChildItem -Path $RootPath -Recurse -Include $Include -File -ErrorAction SilentlyContinue) | Where-Object {
            $normalized = $_.FullName -replace '/', '\\'
            $normalized -notmatch '(?i)(\\node_modules\\|\\bin\\|\\obj\\|\\dist\\|\\build\\|\\docs\\|\\\.git\\|\\test\\|\\tests\\|\\spec\\|\\specs\\|\\__tests__\\|\\fixture\\|\\fixtures\\|\\mock\\|\\mocks\\|\\sample\\|\\samples\\|\\example\\|\\examples\\)'
        }
    )
}

function Test-AppDocApiGeneratedProxyPath {
    [CmdletBinding()]
    param(
        [string]$Path,
        [string]$RootPath
    )

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return $false
    }

    if (Get-Command Test-AppDocGeneratedProxyPath -ErrorAction SilentlyContinue) {
        return (Test-AppDocGeneratedProxyPath -Path $Path -RootPath $RootPath)
    }

    return ($Path -match '(?i)(?:^|[\\/])(Service References|Connected Services|Web References)(?:[\\/]|$)' -or
        $Path -match '(?i)(?:^|[\\/])Reference\.cs$')
}

function Get-AppDocApiEndpointDirectionLocal {
    [CmdletBinding()]
    param(
        [string]$SourceType,
        [string]$Path,
        [string]$FilePath,
        [string]$RootPath
    )

    $sourceTypeNorm = if ($SourceType) { ([string]$SourceType).ToLowerInvariant() } else { "" }
    $pathNorm = if ($Path) { [string]$Path } else { "" }

    if ($sourceTypeNorm -eq "soap-client" -or $pathNorm -match '^/soap-client/') {
        return "outbound"
    }

    if ($FilePath -and (Test-AppDocApiGeneratedProxyPath -Path $FilePath -RootPath $RootPath)) {
        return "outbound"
    }

    return "inbound"
}

function Get-AppDocSoapReferenceNameFromPath {
    [CmdletBinding()]
    param([string]$Path)

    if ([string]::IsNullOrWhiteSpace($Path)) {
        return ""
    }

    if ($Path -match '(?i)(?:Service References|Connected Services|Web References)[\\/]+([^\\/]+)[\\/]+Reference\.cs$') {
        return [string]$Matches[1]
    }
    if ($Path -match '(?i)(?:Service References|Connected Services|Web References)[\\/]+([^\\/]+)(?:[\\/]|$)') {
        return [string]$Matches[1]
    }

    return ""
}

function Get-AppDocSoapClientConfigEndpoints {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $configFiles = @()
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        $configFiles = @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "config-catalog" -Include @("*.config"))
    }
    else {
        $configFiles = @(Get-ChildItem -Path $RootPath -Recurse -File -Include @("*.config") -ErrorAction SilentlyContinue)
    }

    if (-not $configFiles -or @($configFiles).Count -eq 0) {
        return @()
    }

    $entries = @()
    foreach ($file in $configFiles) {
        $raw = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $raw) { continue }

        try {
            [xml]$xml = $raw
        }
        catch {
            continue
        }

        $nodes = $null
        try {
            $nodes = $xml.SelectNodes("//*[local-name()='system.serviceModel']/*[local-name()='client']/*[local-name()='endpoint']")
        }
        catch {
            $nodes = $null
        }
        if (-not $nodes) { continue }

        $relativePath = Get-AppDocApiRelativePath -RootPath $RootPath -Path $file.FullName
        foreach ($node in $nodes) {
            if (-not $node) { continue }

            $address = [string]$node.address
            if ([string]::IsNullOrWhiteSpace($address)) { continue }

            $safeAddress = $address -replace '://([^:/@]+):([^@/]+)@', '://$1:[REDACTED]@'
            $entries += [ordered]@{
                address = $safeAddress
                name = if ($node.name) { [string]$node.name } else { "" }
                contract = if ($node.contract) { [string]$node.contract } else { "" }
                binding = if ($node.binding) { [string]$node.binding } else { "" }
                sourcePath = $relativePath
            }
        }
    }

    $entryByKey = @{}
    foreach ($entry in $entries) {
        $dedupeKey = "{0}|{1}|{2}|{3}" -f ([string]$entry.address).ToLowerInvariant(), ([string]$entry.name).ToLowerInvariant(), ([string]$entry.contract).ToLowerInvariant(), ([string]$entry.sourcePath).ToLowerInvariant()
        if (-not $entryByKey.ContainsKey($dedupeKey)) {
            $entryByKey[$dedupeKey] = $entry
        }
    }

    return @(
        $entryByKey.Values |
            Sort-Object @{ Expression = { [string]$_.contract } }, @{ Expression = { [string]$_.name } }, @{ Expression = { [string]$_.address } }, @{ Expression = { [string]$_.sourcePath } }
    )
}

function Resolve-AppDocSoapClientConfigEndpoint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Endpoint,
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$ConfigEndpoints
    )

    if (-not $ConfigEndpoints -or @($ConfigEndpoints).Count -eq 0) {
        return $null
    }

    $controller = if ($Endpoint.controller) { [string]$Endpoint.controller } else { "" }
    $serviceReference = if ($Endpoint.serviceReference) { [string]$Endpoint.serviceReference } else { "" }
    $contractName = if ($Endpoint.contractName) { [string]$Endpoint.contractName } else { "" }
    $filePath = if ($Endpoint.filePath) { [string]$Endpoint.filePath } else { "" }
    $sourceRoot = if ($filePath -and $filePath -match '^([^\\/]+)[\\/]') { [string]$Matches[1] } else { "" }

    if (-not $serviceReference -and $filePath) {
        $serviceReference = Get-AppDocSoapReferenceNameFromPath -Path $filePath
    }

    $scored = @()
    foreach ($cfg in $ConfigEndpoints) {
        $score = 0
        $cfgContract = if ($cfg.contract) { [string]$cfg.contract } else { "" }
        $cfgName = if ($cfg.name) { [string]$cfg.name } else { "" }
        $cfgSource = if ($cfg.sourcePath) { [string]$cfg.sourcePath } else { "" }

        if ($contractName) {
            if ($cfgContract -eq $contractName) { $score += 25 }
            elseif ($cfgContract -like "*$contractName") { $score += 16 }
            elseif ($cfgContract -match [regex]::Escape($contractName)) { $score += 10 }
        }

        if ($controller) {
            if ($cfgContract -match "(?i)\b$([regex]::Escape($controller))\b") { $score += 10 }
            if ($cfgName -match "(?i)\b$([regex]::Escape($controller))\b") { $score += 7 }
        }

        if ($serviceReference) {
            if ($cfgName -match "(?i)\b$([regex]::Escape($serviceReference))\b") { $score += 14 }
            if ($cfgContract -match "(?i)\b$([regex]::Escape($serviceReference))\b") { $score += 11 }
            if ($cfgSource -match "(?i)\b$([regex]::Escape($serviceReference))\b") { $score += 6 }
        }

        if ($sourceRoot -and $cfgSource -match "(?i)^$([regex]::Escape($sourceRoot))(?:[\\/]|$)") {
            $score += 4
        }

        if ($score -ge 10) {
            $scored += [ordered]@{
                score = $score
                contract = $cfgContract
                name = $cfgName
                sourcePath = $cfgSource
                entry = $cfg
            }
        }
    }

    if (-not $scored -or @($scored).Count -eq 0) {
        return $null
    }

    return @(
        $scored |
            Sort-Object @{ Expression = { -[int]$_.score } }, @{ Expression = { [string]$_.contract } }, @{ Expression = { [string]$_.name } }, @{ Expression = { [string]$_.sourcePath } }
    )[0].entry
}

function Test-AppDocEndpointCandidate {
    [CmdletBinding()]
    param(
        [string]$Method,
        [string]$Path,
        [string]$FilePath,
        [string]$RootPath
    )

    if (-not $Method) { return $false }
    if ($Method.ToUpperInvariant() -notin @("GET","POST","PUT","PATCH","DELETE","OPTIONS","HEAD","ANY","SOAP")) { return $false }
    if (-not $Path -or $Path -eq "/") { return $false }
    if ($Path -match '^/(get|post|put|patch|delete)$') { return $false }
    if ($Path -match '^/[^/]+/(get|post|put|patch|delete)$') { return $false }
    if ($Path -match '(?i)/(test|tests|spec|specs|fixture|fixtures|mock|mocks|sample|samples|example|examples)(/|$)') { return $false }

    if ($FilePath -and (Get-Command Test-AppDocPathIncluded -ErrorAction SilentlyContinue)) {
        $scopeArgs = @{
            Path = $FilePath
            Artifact = "api-inventory"
        }
        if ($RootPath) {
            $scopeArgs.RootPath = $RootPath
        }

        if (-not (Test-AppDocPathIncluded @scopeArgs)) { return $false }
    }

    return $true
}

function Get-AppDocEndpointSignalScore {
    [CmdletBinding()]
    param($Endpoint)

    $score = 0
    $sourceType = if ($Endpoint.sourceType) { [string]$Endpoint.sourceType } else { "regex" }
    if ($sourceType -eq "ast") { $score += 20 }
    elseif ($sourceType -in @("wcf", "asmx")) { $score += 16 }
    elseif ($sourceType -eq "soap-client") { $score += 12 }
    else { $score += 10 }
    if ($Endpoint.auth -and $Endpoint.auth -ne "None") { $score += 5 }
    if ($Endpoint.parameters -and $Endpoint.parameters -ne "None") { $score += 3 }
    if ($Endpoint.description -and $Endpoint.description -notmatch '^((GET|POST|PUT|PATCH|DELETE|ANY|SOAP)\s+/.+\s+endpoint|API endpoint)$') { $score += 2 }
    if ($Endpoint.lineNumber -and [int]$Endpoint.lineNumber -gt 0) { $score += 1 }
    return $score
}

function Get-AppDocApiNormalizedEndpointPathLocal {
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

function Get-AppDocApiEndpointStatusHintLocal {
    [CmdletBinding()]
    param([string]$Method)

    $methodNormalized = if ([string]::IsNullOrEmpty($Method)) { "" } else { $Method }
    switch ($methodNormalized.ToUpperInvariant()) {
        "GET" { return "200, 404, 500" }
        "POST" { return "201, 400, 401, 500" }
        "PUT" { return "200, 400, 404, 500" }
        "PATCH" { return "200, 400, 404, 500" }
        "DELETE" { return "204, 404, 500" }
        "SOAP" { return "200, SOAP Fault, 500" }
        default { return "200, 400, 500" }
    }
}

function Get-AppDocApiEndpointDomainLocal {
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

function Get-AppDocApiEndpointDescriptionLocal {
    [CmdletBinding()]
    param(
        [string]$Description,
        [string]$Method,
        [string]$Path
    )

    $candidate = if ($Description) { ([string]$Description).Trim() } else { "" }
    if ($candidate -and $candidate -notmatch '^(API endpoint|endpoint)$') {
        return $candidate
    }

    $methodNormalized = if ($Method) { $Method } else { "ANY" }
    return ("{0} {1} endpoint" -f ($methodNormalized.ToUpperInvariant()), $Path)
}

function Add-AppDocRegexEndpointsToInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [AllowEmptyCollection()]
        [array]$ApiFiles,
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [hashtable]$Inventory
    )

    if (-not $ApiFiles -or @($ApiFiles).Count -eq 0) {
        return 0
    }

    $added = 0
    foreach ($file in $ApiFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $relativePath = Get-AppDocApiRelativePath -RootPath $RootPath -Path $file.FullName

        # WCF/ASMX host descriptor files
        if ($file.Extension -in @(".svc", ".asmx")) {
            $descriptorClass = ""
            if ($content -match '(?i)\b(?:Service|Class)\s*=\s*"([^"]+)"') {
                $descriptorClass = [string]$Matches[1]
            }
            $serviceName = if ($descriptorClass) {
                $parts = $descriptorClass -split '\.'
                $parts[$parts.Length - 1]
            } else {
                [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
            }
            $hostPath = "/" + (($relativePath -replace '\\', '/').TrimStart('/'))

            $Inventory.endpoints += @{
                method = "SOAP"
                path = $hostPath
                file = $file.Name
                filePath = $relativePath
                lineNumber = 1
                parameters = "SOAP body"
                returnType = "SOAP envelope"
                auth = "Service policy"
                description = if ($file.Extension -eq ".svc") { "WCF service host descriptor" } else { "ASMX service host descriptor" }
                example = $null
                controller = $serviceName
                actionName = "ServiceEndpoint"
                schema = "WSDL contract"
                sourceType = if ($file.Extension -eq ".svc") { "wcf" } else { "asmx" }
            }
            $added++
        }

        # Express.js / Router
        $pattern = '(?<handler>(?:app|router|\w+Router|\w+Routes))\.(get|post|put|delete|patch)\s*\([' + "'" + '"' + ']([^' + "'" + '"' + ']+)[' + "'" + '"' + ']\s*,\s*(?:async\s+)?(?:function\s*)?\(([^)]*)\)'
        $expressRoutes = [regex]::Matches($content, $pattern)
        foreach ($match in $expressRoutes) {
            $method = $match.Groups[2].Value.ToUpper()
            $path = $match.Groups[3].Value
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $methodContext = $content.Substring([Math]::Max(0, $match.Index), [Math]::Min(500, $content.Length - $match.Index))

            $queryParams = [regex]::Matches($methodContext, 'req\.query\.([^\s;,)]+)')
            $bodyParams = [regex]::Matches($methodContext, 'req\.body\.([^\s;,)]+)')
            $pathParams = [regex]::Matches($path, ':([^\s/]+)')
            $allParams = @()
            foreach ($p in $pathParams) { $allParams += "$($p.Groups[1].Value): string (path)" }
            foreach ($p in $queryParams | Select-Object -Unique -First 5) { $allParams += "$($p.Groups[1].Value): string (query)" }
            foreach ($p in $bodyParams | Select-Object -Unique -First 5) { $allParams += "$($p.Groups[1].Value): object (body)" }
            $allParams = @($allParams | Select-Object -Unique)

            $returnType = if ($methodContext -match 'res\.json\s*\(') { "application/json" } elseif ($methodContext -match 'res\.send\s*\(') { "text/plain" } else { "void" }
            $auth = if ($methodContext -match 'authenticate|requireAuth|isAuthenticated|verifyToken') { "Required (JWT/Token)" } elseif ($methodContext -match 'apiKey|api_key') { "API Key" } else { "None" }
            $description = "API endpoint"
            $lookBehind = $content.Substring([Math]::Max(0, $match.Index - 300), [Math]::Min(300, $match.Index))
            if ($lookBehind -match '(?://|/\*\*)\s*(.{10,100})\s*(?:\*/)?\s*$') {
                $description = $Matches[1].Trim() -replace '^[@*\s]+', '' -replace '\s+', ' '
            }

            $Inventory.endpoints += @{
                method = $method
                path = $path
                file = $file.Name
                filePath = $relativePath
                lineNumber = $lineNumber
                parameters = if ($allParams.Count -gt 0) { $allParams -join ', ' } else { "None" }
                returnType = $returnType
                auth = $auth
                description = $description
                example = $null
                controller = if ($file.Name -match '(\w+)(?:Controller|Router|Api)') { $Matches[1] } else { "Other" }
                schema = if ($allParams.Count -gt 0) { "See parameters" } else { "N/A" }
                sourceType = "regex"
            }
            $added++
        }

        # ASP.NET Core attributes
        $aspPattern = '\[Http(Get|Post|Put|Delete|Patch)(?:\([' + "'" + '"' + ']([^' + "'" + '"' + ']+)[' + "'" + '"' + ']\))?\]\s*(?:\[\w+\]\s*)*public\s+(?:async\s+)?(?:Task<)?([^>\s]+)\>?\s+(\w+)\s*\(([^)]*)\)'
        $aspRoutes = [regex]::Matches($content, $aspPattern)
        foreach ($match in $aspRoutes) {
            $method = $match.Groups[1].Value.ToUpper()
            $path = if ($match.Groups[2].Success) { $match.Groups[2].Value } else { "" }
            $returnType = $match.Groups[3].Value
            $methodName = $match.Groups[4].Value
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $paramString = $match.Groups[5].Value

            $allParams = @()
            if ($paramString.Trim()) {
                $paramParts = $paramString -split ','
                foreach ($part in $paramParts) {
                    if ($part -match '(?:^|\s)([\w<>?\[\]]+)\s+(\w+)') {
                        $paramType = $Matches[1]
                        $paramName = $Matches[2]
                        $source = "body"
                        if ($part -match '\[FromQuery\]') { $source = "query" }
                        elseif ($part -match '\[FromRoute\]|\[FromPath\]') { $source = "path" }
                        elseif ($part -match '\[FromHeader\]') { $source = "header" }
                        $allParams += "${paramName}: ${paramType} ($source)"
                    }
                }
            }

            $methodContext = $content.Substring([Math]::Max(0, $match.Index - 200), [Math]::Min(400, $content.Length - [Math]::Max(0, $match.Index - 200)))
            $auth = if ($methodContext -match '\[Authorize(?:\([^)]+\))?\]') { "Required (Authorization)" } elseif ($methodContext -match 'ApiKey|RequireApiKey') { "API Key" } else { "None" }

            $description = "API endpoint"
            $lookBehind = $content.Substring([Math]::Max(0, $match.Index - 500), [Math]::Min(500, $match.Index))
            if ($lookBehind -match '///\s*<summary>\s*([\s\S]+?)</summary>') {
                $description = $Matches[1].Trim() -replace '///\s*', '' -replace '<[^>]+>', '' -replace '\s+', ' '
            }

            if (-not $path) {
                $controllerName = if ($file.Name -match '(\w+)Controller') { $Matches[1] } else { "api" }
                $path = "/$controllerName/$methodName"
            }

            $Inventory.endpoints += @{
                method = $method
                path = $path
                file = $file.Name
                filePath = $relativePath
                lineNumber = $lineNumber
                parameters = if ($allParams.Count -gt 0) { $allParams -join ', ' } else { "None" }
                returnType = $returnType
                auth = $auth
                description = $description
                example = $null
                controller = if ($file.Name -match '(\w+)Controller') { $Matches[1] } else { "Other" }
                schema = if ($allParams.Count -gt 0) { "See parameters" } else { "N/A" }
                sourceType = "regex"
            }
            $added++
        }

        # ASP.NET MVC 5 routes
        $mvcPattern = '\[(Http(?:Get|Post|Put|Delete|Patch))\][\s\S]{0,300}?public\s+(?:virtual\s+)?(?:async\s+)?(?:Task<)?(?:ActionResult|JsonResult|ViewResult|PartialViewResult|ContentResult|FileResult)(?:<[^>]+>)?\>?\s+(\w+)\s*\(([^)]*)\)'
        $mvcRoutes = [regex]::Matches($content, $mvcPattern)
        foreach ($match in $mvcRoutes) {
            $method = $match.Groups[1].Value.Replace('Http', '').ToUpper()
            $methodName = $match.Groups[2].Value
            $paramString = $match.Groups[3].Value
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $controllerName = if ($file.Name -match '(\w+)Controller\.cs') { $Matches[1] } else { "Unknown" }

            $methodContext = $content.Substring([Math]::Max(0, $match.Index - 300), [Math]::Min(600, $content.Length - [Math]::Max(0, $match.Index - 300)))
            $routePattern = '\[Route\(["' + "'" + ']([^"' + "'" + ']+)["' + "'" + ']\)\]'
            if ($methodContext -match $routePattern) {
                $path = $Matches[1] -replace '\{(\w+):[^}]+\}', '{$1}'
            }
            else {
                $path = "/$controllerName/$methodName"
            }

            $allParams = @()
            if ($paramString.Trim()) {
                $paramParts = $paramString -split ','
                foreach ($part in $paramParts) {
                    if ($part -match '(?:^|\s)([\w<>?\[\]]+)\s+(\w+)') {
                        $paramType = $Matches[1]
                        $paramName = $Matches[2]
                        $source = "query"
                        if ($paramType -match 'int|long|guid' -and $method -eq 'GET') { $source = "route" }
                        elseif ($paramType -notmatch 'string|int|long|bool|datetime|guid') { $source = "body" }
                        $allParams += "${paramName}: ${paramType} ($source)"
                    }
                }
            }

            $auth = if ($methodContext -match '\[Authorize(?:\([^)]+\))?\]') { "Required (Authorization)" } else { "None" }
            $returnType = if ($match.Groups[0].Value -match 'JsonResult') { "application/json" } elseif ($match.Groups[0].Value -match 'ContentResult') { "text/plain" } elseif ($match.Groups[0].Value -match 'FileResult') { "file download" } else { "HTML View" }
            $description = "API endpoint"
            if ($methodContext -match '///\s*<summary>\s*([^<]+)</summary>') {
                $description = $Matches[1].Trim() -replace '///\s*', '' -replace '\s+', ' '
            }

            $Inventory.endpoints += @{
                method = $method
                path = $path
                file = $file.Name
                filePath = $relativePath
                lineNumber = $lineNumber
                parameters = if ($allParams.Count -gt 0) { $allParams -join ', ' } else { "None" }
                returnType = $returnType
                auth = $auth
                description = $description
                example = $null
                controller = $controllerName
                schema = if ($allParams.Count -gt 0) { "See parameters" } else { "N/A" }
                sourceType = "regex"
            }
            $added++
        }

        # WCF / ASMX service operations
        if ($file.Extension -eq ".cs") {
            $isGeneratedServiceReference = (Test-AppDocApiGeneratedProxyPath -Path $relativePath -RootPath $RootPath)
            if (-not $isGeneratedServiceReference) {
                $serviceName = if ($file.BaseName) { [string]$file.BaseName } else { "Service" }

                $serviceContractMatch = [regex]::Match(
                    $content,
                    '\[(?:[\w\.]+)?ServiceContract(?:Attribute)?(?:\([^\)]*\))?\][\s\r\n]*(?:\[[^\]]+\][\s\r\n]*)*(?:public\s+)?(?:interface|class)\s+([A-Za-z_]\w*)',
                    'IgnoreCase'
                )
                if ($serviceContractMatch.Success) {
                    $serviceName = [string]$serviceContractMatch.Groups[1].Value
                    if ($serviceName.StartsWith("I") -and $serviceName.Length -gt 1 -and [char]::IsUpper($serviceName[1])) {
                        $serviceName = $serviceName.Substring(1)
                    }
                }

                $wcfPattern = '\[(?:[\w\.]+)?OperationContract(?:Attribute)?(?:\([^\)]*\))?\][\s\r\n]*(?:\[[^\]]+\][\s\r\n]*)*(?:public\s+)?(?:async\s+)?([A-Za-z_][\w<>\[\],\.\?]*)\s+([A-Za-z_]\w*)\s*\(([^)]*)\)'
                $wcfMatches = [regex]::Matches($content, $wcfPattern, 'IgnoreCase')
                foreach ($match in $wcfMatches) {
                    $operationName = [string]$match.Groups[2].Value
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                    $paramSignature = if ($match.Groups[3].Value) { ([string]$match.Groups[3].Value -replace '\s+', ' ').Trim() } else { "None" }
                    $path = "/svc/$serviceName/$operationName"

                    $Inventory.endpoints += @{
                        method = "SOAP"
                        path = $path
                        file = $file.Name
                        filePath = $relativePath
                        lineNumber = $lineNumber
                        parameters = $paramSignature
                        returnType = [string]$match.Groups[1].Value
                        auth = "Service policy"
                        description = "WCF operation contract"
                        example = $null
                        controller = $serviceName
                        actionName = $operationName
                        schema = if ($paramSignature -ne "None") { "See operation signature" } else { "N/A" }
                        sourceType = "wcf"
                    }
                    $added++
                }

                $asmxServiceName = $serviceName
                $asmxClassMatch = [regex]::Match(
                    $content,
                    'class\s+([A-Za-z_]\w*)\s*:\s*WebService\b',
                    'IgnoreCase'
                )
                if ($asmxClassMatch.Success) {
                    $asmxServiceName = [string]$asmxClassMatch.Groups[1].Value
                }

                $asmxPattern = '\[(?:[\w\.]+)?WebMethod(?:Attribute)?(?:\([^\)]*\))?\][\s\r\n]*(?:\[[^\]]+\][\s\r\n]*)*(?:public\s+)?(?:async\s+)?([A-Za-z_][\w<>\[\],\.\?]*)\s+([A-Za-z_]\w*)\s*\(([^)]*)\)'
                $asmxMatches = [regex]::Matches($content, $asmxPattern, 'IgnoreCase')
                foreach ($match in $asmxMatches) {
                    $operationName = [string]$match.Groups[2].Value
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                    $paramSignature = if ($match.Groups[3].Value) { ([string]$match.Groups[3].Value -replace '\s+', ' ').Trim() } else { "None" }
                    $path = "/asmx/$asmxServiceName.asmx/$operationName"

                    $Inventory.endpoints += @{
                        method = "SOAP"
                        path = $path
                        file = $file.Name
                        filePath = $relativePath
                        lineNumber = $lineNumber
                        parameters = $paramSignature
                        returnType = [string]$match.Groups[1].Value
                        auth = "Service policy"
                        description = "ASMX web method"
                        example = $null
                        controller = $asmxServiceName
                        actionName = $operationName
                        schema = if ($paramSignature -ne "None") { "See operation signature" } else { "N/A" }
                        sourceType = "asmx"
                    }
                    $added++
                }
            }
            else {
                # SOAP client proxy interface operations (generated service references)
                $serviceInterfaces = [regex]::Matches(
                    $content,
                    '\[(?:[\w\.]+)?ServiceContract(?:Attribute)?(?:\([^\)]*\))?\][\s\r\n]*(?:\[[^\]]+\][\s\r\n]*)*(?:public\s+)?interface\s+([A-Za-z_]\w*)[^{]*\{(?<body>[\s\S]*?)\}',
                    'IgnoreCase'
                )
                foreach ($serviceInterface in $serviceInterfaces) {
                    $serviceName = [string]$serviceInterface.Groups[1].Value
                    $serviceReferenceName = Get-AppDocSoapReferenceNameFromPath -Path $relativePath
                    $contractName = ""
                    if ([string]$serviceInterface.Value -match '(?i)\bConfigurationName\s*=\s*"([^"]+)"') {
                        $contractName = [string]$Matches[1]
                    }
                    $interfaceBody = [string]$serviceInterface.Groups['body'].Value
                    $operationMatches = [regex]::Matches(
                        $interfaceBody,
                        '\[(?:[\w\.]+)?OperationContract(?:Attribute)?(?:\([^\)]*\))?\][\s\r\n]*(?:\[[^\]]+\][\s\r\n]*)*(?:[A-Za-z_][\w<>\[\],\.\?]*\s+)?([A-Za-z_]\w*)\s*\(([^)]*)\)\s*;',
                        'IgnoreCase'
                    )
                    foreach ($operation in $operationMatches) {
                        $operationName = [string]$operation.Groups[1].Value
                        $paramSignature = if ($operation.Groups[2].Value) { ([string]$operation.Groups[2].Value -replace '\s+', ' ').Trim() } else { "None" }
                        # Find the actual position of the body within the interface match
                        $bodyStartInInterface = $serviceInterface.Value.IndexOf($interfaceBody)
                        $lineOffset = [Math]::Max(0, $serviceInterface.Index + $bodyStartInInterface + $operation.Index)
                        $lineNumber = ($content.Substring(0, $lineOffset) -split "`n").Count
                        $path = "/soap-client/$serviceName/$operationName"

                        $Inventory.endpoints += @{
                            method = "SOAP"
                            path = $path
                            file = $file.Name
                            filePath = $relativePath
                            lineNumber = $lineNumber
                            parameters = $paramSignature
                            returnType = "SOAP envelope"
                            auth = "Client binding"
                            description = "Outbound SOAP client operation"
                            example = $null
                            controller = $serviceName
                            actionName = $operationName
                            serviceReference = $serviceReferenceName
                            contractName = $contractName
                            schema = if ($paramSignature -ne "None") { "See operation signature" } else { "WSDL contract" }
                            sourceType = "soap-client"
                        }
                        $added++
                    }
                }
            }
        }

        # Python routes
        if ($file.Extension -eq ".py") {
            $flaskPattern = '@(?<bp>[\w\.]+)\.route\(\s*[' + "'" + '"' + '](?<path>[^' + "'" + '"' + ']+)[' + "'" + '"' + '](?:\s*,\s*methods\s*=\s*\[(?<methods>[^\]]+)\])?'
            $flaskRoutes = [regex]::Matches($content, $flaskPattern)
            foreach ($match in $flaskRoutes) {
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $methodsRaw = if ($match.Groups['methods'].Success) { $match.Groups['methods'].Value } else { "" }
                $verbs = if ($methodsRaw) { ($methodsRaw -split ',' | ForEach-Object { $_.Trim(" `'""") } | Where-Object { $_ }) } else { @("GET") }
                foreach ($verb in $verbs) {
                    $Inventory.endpoints += @{
                        method = $verb.ToUpper()
                        path = $match.Groups['path'].Value
                        file = $file.Name
                        filePath = $relativePath
                        lineNumber = $lineNumber
                        parameters = "request"
                        returnType = "Flask Response"
                        auth = "None"
                        description = "Flask route"
                        example = $null
                        controller = $match.Groups['bp'].Value
                        schema = "N/A"
                        sourceType = "regex"
                    }
                    $added++
                }
            }

            $fastPattern = '@(?<router>\w+)\.(?<verb>get|post|put|delete|patch|options|head)\s*\(\s*[' + "'" + '"' + '](?<path>[^' + "'" + '"' + ']+)[' + "'" + '"' + ']'
            $fastRoutes = [regex]::Matches($content, $fastPattern, 'IgnoreCase')
            foreach ($match in $fastRoutes) {
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $Inventory.endpoints += @{
                    method = $match.Groups['verb'].Value.ToUpper()
                    path = $match.Groups['path'].Value
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    parameters = "request"
                    returnType = "N/A"
                    auth = "None"
                    description = "FastAPI endpoint"
                    example = $null
                    controller = $match.Groups['router'].Value
                    schema = "N/A"
                    sourceType = "regex"
                }
                $added++
            }
        }

        # Spring Java
        if ($file.Extension -eq ".java") {
            $springPattern = '@(?<annotation>(?:Get|Post|Put|Delete|Patch)Mapping)\s*(?:\(\s*[' + "'" + '"' + '](?<path>[^' + "'" + '"' + ']+)[' + "'" + '"' + ']\s*\))?'
            $springRoutes = [regex]::Matches($content, $springPattern)
            foreach ($match in $springRoutes) {
                $verb = $match.Groups['annotation'].Value.Replace("Mapping","").ToUpper()
                $path = if ($match.Groups['path'].Success) { $match.Groups['path'].Value } else { "/" }
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $Inventory.endpoints += @{
                    method = $verb
                    path = $path
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    parameters = "See method signature"
                    returnType = "Spring Response"
                    auth = "Spring Security"
                    description = "Spring endpoint"
                    example = $null
                    controller = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    schema = "N/A"
                    sourceType = "regex"
                }
                $added++
            }

            $requestMappingPattern = '@RequestMapping\s*\((?<params>[^)]*)\)'
            $requestMappings = [regex]::Matches($content, $requestMappingPattern)
            foreach ($match in $requestMappings) {
                $paramText = $match.Groups['params'].Value
                $path = ""
                if ($paramText -match 'value\s*=\s*[' + "'" + '"' + '](?<path>[^' + "'" + '"' + ']+)[' + "'" + '"' + ']') {
                    $path = $Matches['path']
                }
                elseif ($paramText -match 'path\s*=\s*[' + "'" + '"' + '](?<pathAlt>[^' + "'" + '"' + ']+)[' + "'" + '"' + ']') {
                    $path = $Matches['pathAlt']
                }
                $method = "ANY"
                if ($paramText -match 'RequestMethod\.(?<verb>\w+)') {
                    $method = $Matches['verb'].ToUpper()
                }
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $Inventory.endpoints += @{
                    method = $method
                    path = if ($path) { $path } else { "/" }
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    parameters = "See method signature"
                    returnType = "Spring Response"
                    auth = "Spring Security"
                    description = "@RequestMapping endpoint"
                    example = $null
                    controller = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                    schema = "N/A"
                    sourceType = "regex"
                }
                $added++
            }
        }
    }

    return $added
}

function Get-AppDocApiInventoryData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptsRoot,
        [Parameter(Mandatory = $true)]
        [string]$RootPath,
        [hashtable]$Inventory = @{ endpoints = @() }
    )

    if (-not $Inventory.ContainsKey("endpoints")) {
        $Inventory.endpoints = @()
    }

    $astCSharp = Invoke-AppDocApiAstParserScript -ScriptsRoot $ScriptsRoot -ScriptName "parse-csharp-ast.ps1" -RootPath $RootPath
    $astTs = Invoke-AppDocApiAstParserScript -ScriptsRoot $ScriptsRoot -ScriptName "parse-typescript-ast.ps1" -RootPath $RootPath

    $astEndpointCount = 0
    $astEndpointCount += Add-AppDocAstEndpointsToInventory -AstPayload $astCSharp -Inventory $Inventory -RootPath $RootPath
    $astEndpointCount += Add-AppDocAstEndpointsToInventory -AstPayload $astTs -Inventory $Inventory -RootPath $RootPath

    $apiFiles = @(Get-AppDocApiScopedFiles -RootPath $RootPath -Include @("*.js","*.ts","*.cs","*.py","*.java","*.svc","*.asmx"))
    $regexEndpointCount = Add-AppDocRegexEndpointsToInventory -ApiFiles $apiFiles -RootPath $RootPath -Inventory $Inventory

    $soapClientConfigEndpoints = @(Get-AppDocSoapClientConfigEndpoints -RootPath $RootPath)

    $normalizedEndpoints = @()
    foreach ($endpoint in $Inventory.endpoints) {
        $method = if ($endpoint.method) { ([string]$endpoint.method).ToUpperInvariant() } else { "ANY" }
        $controller = if ($endpoint.controller) { [string]$endpoint.controller } else { "Other" }
        $path = Get-AppDocApiNormalizedEndpointPathLocal -Path ([string]$endpoint.path) -Controller $controller -Method $method
        $sourcePath = if ($endpoint.filePath) { [string]$endpoint.filePath } else { "unknown" }
        $sourceType = if ($endpoint.sourceType) { [string]$endpoint.sourceType } else { "regex" }

        if (-not (Test-AppDocEndpointCandidate -Method $method -Path $path -FilePath $sourcePath -RootPath $RootPath)) {
            continue
        }

        $description = Get-AppDocApiEndpointDescriptionLocal -Description ([string]$endpoint.description) -Method $method -Path $path
        $statusCodes = Get-AppDocApiEndpointStatusHintLocal -Method $method
        $direction = Get-AppDocApiEndpointDirectionLocal -SourceType $sourceType -Path $path -FilePath $sourcePath -RootPath $RootPath

        $integrationUrl = $null
        $integrationName = $null
        $integrationContract = $null
        $integrationSource = $null
        if ($direction -eq "outbound" -and $method -eq "SOAP") {
            $configMatch = Resolve-AppDocSoapClientConfigEndpoint -Endpoint $endpoint -ConfigEndpoints $soapClientConfigEndpoints
            if ($configMatch) {
                $integrationUrl = if ($configMatch.address) { [string]$configMatch.address } else { $null }
                $integrationName = if ($configMatch.name) { [string]$configMatch.name } else { $null }
                $integrationContract = if ($configMatch.contract) { [string]$configMatch.contract } else { $null }
                $integrationSource = if ($configMatch.sourcePath) { [string]$configMatch.sourcePath } else { $null }
            }
        }

        $normalizedEndpoints += @{
            method = $method
            path = $path
            file = if ($endpoint.file) { [string]$endpoint.file } else { "unknown" }
            filePath = $sourcePath
            lineNumber = if ($endpoint.lineNumber) { [int]$endpoint.lineNumber } else { 1 }
            parameters = if ($endpoint.parameters) { [string]$endpoint.parameters } else { "None" }
            returnType = if ($endpoint.returnType) { [string]$endpoint.returnType } else { "unknown" }
            auth = if ($endpoint.auth) { [string]$endpoint.auth } else { "None" }
            description = $description
            example = $endpoint.example
            controller = $controller
            schema = if ($endpoint.schema) { [string]$endpoint.schema } else { "N/A" }
            statusCodes = $statusCodes
            domain = Get-AppDocApiEndpointDomainLocal -Path $path -Controller $controller
            sourceType = $sourceType
            direction = $direction
            actionName = if ($endpoint.actionName) { [string]$endpoint.actionName } elseif ($endpoint.methodName) { [string]$endpoint.methodName } else { $null }
            serviceReference = if ($endpoint.serviceReference) { [string]$endpoint.serviceReference } else { $null }
            contractName = if ($endpoint.contractName) { [string]$endpoint.contractName } else { $null }
            integrationUrl = $integrationUrl
            integrationName = $integrationName
            integrationContract = $integrationContract
            integrationSource = $integrationSource
        }
    }

    $endpointByKey = @{}
    foreach ($endpoint in $normalizedEndpoints) {
        $dedupeKey = "{0}|{1}|{2}|{3}" -f $endpoint.method, $endpoint.path.ToLowerInvariant(), $endpoint.controller.ToLowerInvariant(), $endpoint.direction
        if (-not $endpointByKey.ContainsKey($dedupeKey)) {
            $endpointByKey[$dedupeKey] = $endpoint
            continue
        }

        $existing = $endpointByKey[$dedupeKey]
        if ((Get-AppDocEndpointSignalScore -Endpoint $endpoint) -gt (Get-AppDocEndpointSignalScore -Endpoint $existing)) {
            $endpointByKey[$dedupeKey] = $endpoint
        }
    }

    $Inventory.endpoints = @(
        $endpointByKey.Values |
            Sort-Object @{ Expression = { if ([string]$_.direction -eq "inbound") { 0 } else { 1 } } }, @{ Expression = { [string]$_.domain } }, @{ Expression = { [string]$_.path } }, @{ Expression = { [string]$_.method } }
    )

    return [ordered]@{
        inventory = $Inventory
        astEndpointCount = $astEndpointCount
        regexEndpointCount = $regexEndpointCount
        soapConfigEndpointCount = $soapClientConfigEndpoints.Count
        scannedApiFileCount = $apiFiles.Count
    }
}

Export-ModuleMember -Function @(
    'Invoke-AppDocApiAstParserScript',
    'Add-AppDocAstEndpointsToInventory',
    'Get-AppDocApiInventoryData'
)
