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

function Test-AppDocEndpointCandidate {
    [CmdletBinding()]
    param(
        [string]$Method,
        [string]$Path,
        [string]$FilePath,
        [string]$RootPath
    )

    if (-not $Method) { return $false }
    if ($Method.ToUpperInvariant() -notin @("GET","POST","PUT","PATCH","DELETE","OPTIONS","HEAD","ANY")) { return $false }
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
    if (($Endpoint.sourceType ?? "regex") -eq "ast") { $score += 20 } else { $score += 10 }
    if ($Endpoint.auth -and $Endpoint.auth -ne "None") { $score += 5 }
    if ($Endpoint.parameters -and $Endpoint.parameters -ne "None") { $score += 3 }
    if ($Endpoint.description -and $Endpoint.description -notmatch '^((GET|POST|PUT|PATCH|DELETE|ANY)\s+/.+\s+endpoint|API endpoint)$') { $score += 2 }
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

    switch (($Method ?? "").ToUpperInvariant()) {
        "GET" { return "200, 404, 500" }
        "POST" { return "201, 400, 401, 500" }
        "PUT" { return "200, 400, 404, 500" }
        "PATCH" { return "200, 400, 404, 500" }
        "DELETE" { return "204, 404, 500" }
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

    return ("{0} {1} endpoint" -f (($Method ?? "ANY").ToUpperInvariant()), $Path)
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
            foreach ($p in $queryParams | Select-Object -First 5 -Unique) { $allParams += "$($p.Groups[1].Value): string (query)" }
            foreach ($p in $bodyParams | Select-Object -First 5 -Unique) { $allParams += "$($p.Groups[1].Value): object (body)" }
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
                    controller = (Split-Path $file.Name -LeafBase)
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
                    controller = (Split-Path $file.Name -LeafBase)
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

    $apiFiles = @(Get-AppDocApiScopedFiles -RootPath $RootPath -Include @("*.js","*.ts","*.cs","*.py","*.java"))
    $regexEndpointCount = Add-AppDocRegexEndpointsToInventory -ApiFiles $apiFiles -RootPath $RootPath -Inventory $Inventory

    $normalizedEndpoints = @()
    foreach ($endpoint in $Inventory.endpoints) {
        $method = if ($endpoint.method) { ([string]$endpoint.method).ToUpperInvariant() } else { "ANY" }
        $controller = if ($endpoint.controller) { [string]$endpoint.controller } else { "Other" }
        $path = Get-AppDocApiNormalizedEndpointPathLocal -Path ([string]$endpoint.path) -Controller $controller -Method $method
        $sourcePath = if ($endpoint.filePath) { [string]$endpoint.filePath } else { "unknown" }

        if (-not (Test-AppDocEndpointCandidate -Method $method -Path $path -FilePath $sourcePath -RootPath $RootPath)) {
            continue
        }

        $description = Get-AppDocApiEndpointDescriptionLocal -Description ([string]$endpoint.description) -Method $method -Path $path
        $statusCodes = Get-AppDocApiEndpointStatusHintLocal -Method $method

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
            sourceType = if ($endpoint.sourceType) { [string]$endpoint.sourceType } else { "regex" }
        }
    }

    $endpointByKey = @{}
    foreach ($endpoint in $normalizedEndpoints) {
        $dedupeKey = "{0}|{1}|{2}" -f $endpoint.method, $endpoint.path.ToLowerInvariant(), $endpoint.controller.ToLowerInvariant()
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
            Sort-Object @{ Expression = { [string]$_.domain } }, @{ Expression = { [string]$_.path } }, @{ Expression = { [string]$_.method } }
    )

    return [ordered]@{
        inventory = $Inventory
        astEndpointCount = $astEndpointCount
        regexEndpointCount = $regexEndpointCount
        scannedApiFileCount = $apiFiles.Count
    }
}

Export-ModuleMember -Function @(
    'Invoke-AppDocApiAstParserScript',
    'Add-AppDocAstEndpointsToInventory',
    'Get-AppDocApiInventoryData'
)
