#
# generate-api-inventory.ps1
# 
# Purpose: Scans the target codebase for API endpoints (routes, controllers) and populates
#          the api-inventory template with discovered HTTP endpoints, methods, paths,
#          authentication requirements, and schemas.
#
# Usage: .\generate-api-inventory.ps1 -RootPath <target_codebase_path>
# Output: Populates docs/api-inventory.md from template
#

param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Import template helpers
$helpersPath = Join-Path (Split-Path $PSScriptRoot -Parent) "powershell\template-helpers.ps1"
if (Test-Path $helpersPath) {
    . $helpersPath
}

$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
if (Test-Path $scopeModule) {
    Import-Module $scopeModule -Force -ErrorAction Stop
}

$contractsModule = Join-Path $PSScriptRoot "modules\AppDoc.Contracts.psm1"
if (Test-Path $contractsModule) {
    Import-Module $contractsModule -Force -ErrorAction Stop
}

$evidenceModule = Join-Path $PSScriptRoot "modules\AppDoc.Evidence.psm1"
if (Test-Path $evidenceModule) {
    Import-Module $evidenceModule -Force -ErrorAction Stop
}

Write-Host "📡 Generating API Inventory..." -ForegroundColor Cyan

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Initialize template
$outputPath = Join-Path $RootPath "docs\api-inventory.md"
$initialized = Initialize-TemplateFile -TemplateName "api-inventory-template.md" -OutputPath $outputPath -RootPath $RootPath

if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating API Inventory" -Status "Scanning for APIs..." -PercentComplete 0

$inventory = @{
    endpoints = @()
}

function Invoke-AstParserScript {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptName,
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $scriptPath = Join-Path $PSScriptRoot $ScriptName
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

function Add-AstEndpointsToInventory {
    param(
        [object]$AstPayload,
        [Parameter(Mandatory=$true)]
        [hashtable]$Inventory
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
        }
        $added++
    }

    return $added
}

function Sanitize-MarkdownCell {
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

function Get-NormalizedEndpointPath {
    param(
        [AllowNull()]
        [string]$Path,
        [AllowNull()]
        [string]$Controller,
        [AllowNull()]
        [string]$Method
    )

    $normalized = ""
    if ($Path) {
        $normalized = [string]$Path
    }

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

function Get-EndpointStatusHint {
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

function Get-EndpointDomain {
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

function Get-EndpointDescription {
    param(
        [string]$Description,
        [string]$Method,
        [string]$Path
    )

    $candidate = Sanitize-MarkdownCell -Value $Description -MaxLength 180
    if ($candidate -and $candidate -notmatch '^(API endpoint|endpoint)$') {
        return $candidate
    }

    return ("{0} {1} endpoint" -f (($Method ?? "ANY").ToUpperInvariant()), $Path)
}

function Get-EndpointFamilyPath {
    param([string]$Path)

    if (-not $Path) { return "/unknown" }

    $normalized = [string]$Path
    $normalized = $normalized -replace '/\d+(?=/|$)', '/{id}'
    $normalized = $normalized -replace '/[0-9a-fA-F]{8}-[0-9a-fA-F-]{27,35}(?=/|$)', '/{id}'
    $normalized = $normalized -replace '/[A-Za-z0-9_-]{24,}(?=/|$)', '/{value}'
    $normalized = $normalized -replace '/{2,}', '/'

    return $normalized.ToLowerInvariant()
}

function Get-SemanticEndpointFamily {
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

# Scan for API files (Express.js, ASP.NET, Flask, FastAPI, Django, Spring, etc.)
try {
    $astCSharp = Invoke-AstParserScript -ScriptName "parse-csharp-ast.ps1" -RootPath $RootPath
    $astTs = Invoke-AstParserScript -ScriptName "parse-typescript-ast.ps1" -RootPath $RootPath

    $astEndpointCount = 0
    $astEndpointCount += Add-AstEndpointsToInventory -AstPayload $astCSharp -Inventory $inventory
    $astEndpointCount += Add-AstEndpointsToInventory -AstPayload $astTs -Inventory $inventory
    if ($astEndpointCount -gt 0) {
        Write-Host "  Added $astEndpointCount AST endpoint records" -ForegroundColor Gray
    }

    $apiFiles = Get-AppDocSourceFiles -RootPath $RootPath -Include @("*.js","*.ts","*.cs","*.py","*.java")

    Write-Host "  Found $($apiFiles.Count) potential API files" -ForegroundColor Gray

    foreach ($file in $apiFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        $relativePath = Get-AppDocRelativePath -RootPath $RootPath -Path $file.FullName
        
        # Detect Express.js/Router routes with parameter extraction
        # Pattern: handler.METHOD('/path', (req, res) => { ... })
        $pattern = '(?<handler>(?:app|router|\w+Router|\w+Routes))\.(get|post|put|delete|patch)\s*\([' + "'" + '"' + ']([^' + "'" + '"' + ']+)[' + "'" + '"' + ']\s*,\s*(?:async\s+)?(?:function\s*)?\(([^)]*)\)'
        $expressRoutes = [regex]::Matches($content, $pattern)
        foreach ($match in $expressRoutes) {
            $method = $match.Groups[2].Value.ToUpper()
            $path = $match.Groups[3].Value
            $params = $match.Groups[4].Value
            
            # Calculate line number from match index
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            
            # Extract parameter types from function signature or JSDoc comments
            $paramTypes = @()
            $returnType = "void"
            
            # Look for TypeScript type annotations in parameters
            if ($params -match ':\s*(\w+(?:<[^>]+>)?)') {
                $paramTypes += $Matches[1]
            }
            
            # Extract query/body parameters from req.query or req.body usage
            $methodContext = $content.Substring([Math]::Max(0, $match.Index), [Math]::Min(500, $content.Length - $match.Index))
            $queryParams = [regex]::Matches($methodContext, 'req\.query\.([^\s;,)]+)')
            $bodyParams = [regex]::Matches($methodContext, 'req\.body\.([^\s;,)]+)')
            $pathParams = [regex]::Matches($path, ':([^\s/]+)')
            
            # Build parameter list
            $allParams = @()
            foreach ($p in $pathParams) { $allParams += "$($p.Groups[1].Value)" + ": string (path)" }
            foreach ($p in $queryParams | Select-Object -First 5 -Unique) { 
                $paramName = $p.Groups[1].Value
                if ($allParams -notcontains "$paramName*") {
                    $allParams += "${paramName}: string (query)" 
                }
            }
            foreach ($p in $bodyParams | Select-Object -First 5 -Unique) { 
                $paramName = $p.Groups[1].Value
                if ($allParams -notcontains "$paramName*") {
                    $allParams += "${paramName}: object (body)" 
                }
            }
            
            # Check for res.json() to determine return type
            if ($methodContext -match 'res\.json\s*\(') {
                $returnType = "application/json"
            } elseif ($methodContext -match 'res\.send\s*\(') {
                $returnType = "text/plain"
            }
            
            # Detect authentication middleware
            $auth = "None"
            if ($methodContext -match 'authenticate|requireAuth|isAuthenticated|verifyToken') {
                $auth = "Required (JWT/Token)"
            } elseif ($methodContext -match 'apiKey|api_key') {
                $auth = "API Key"
            }
            
            # Extract example usage from comments or test-like code
            $example = $null
            if ($methodContext -match '//\s*Example:|/\*\*?\s*@example') {
                # Try to extract example from JSDoc or comments
                if ($methodContext -match '@example\s+([\s\S]{1,300}?)(?:\*/|@)') {
                    $example = $Matches[1].Trim()
                }
            }
            # Look for test-like assertions or sample data
            if (-not $example -and $methodContext -match 'expect\([^)]+\)\.toEqual\(([^)]+)\)') {
                $example = "Expected response: $($Matches[1].Trim())"
            }
            # Look for res.json calls with literal objects
            if (-not $example -and $methodContext -match 'res\.json\s*\(\s*\{([^}]{1,200})\}') {
                $sampleJson = "{$($Matches[1].Trim())}"
                $example = "Sample response: ``$sampleJson``"
            }
            
            # Extract description from JSDoc or comments before the route
            $description = "API endpoint"
            $lookBehind = $content.Substring([Math]::Max(0, $match.Index - 300), [Math]::Min(300, $match.Index))
            if ($lookBehind -match '(?://|/\*\*)\s*(.{10,100})\s*(?:\*/)?\s*$') {
                $description = $Matches[1].Trim() -replace '^[@*\s]+', '' -replace '\s+', ' '
            }
            
            $inventory.endpoints += @{
                method = $method
                path = $path
                file = $file.Name
                filePath = $relativePath
                lineNumber = $lineNumber
                parameters = if ($allParams.Count -gt 0) { $allParams -join ', ' } else { "None" }
                returnType = $returnType
                auth = $auth
                description = $description
                example = $example
                controller = if ($file.Name -match '(\w+)(?:Controller|Router|Api)') { $Matches[1] } else { "Other" }
                schema = if ($allParams.Count -gt 0) { "See parameters" } else { "N/A" }
            }
        }
        
        # Detect ASP.NET routes with parameter and return type extraction
        # Pattern: [HttpMETHOD("path")] or [HttpMETHOD] public ReturnType MethodName(ParamType param1, ...)
        $pattern = '\[Http(Get|Post|Put|Delete|Patch)(?:\([' + "'" + '"' + ']([^' + "'" + '"' + ']+)[' + "'" + '"' + ']\))?\]\s*(?:\[\w+\]\s*)*public\s+(?:async\s+)?(?:Task<)?([^>\s]+)\>?\s+(\w+)\s*\(([^)]*)\)'
        $aspRoutes = [regex]::Matches($content, $pattern)
        foreach ($match in $aspRoutes) {
            $method = $match.Groups[1].Value.ToUpper()
            $path = if ($match.Groups[2].Success) { $match.Groups[2].Value } else { "" }
            $returnType = $match.Groups[3].Value
            $methodName = $match.Groups[4].Value
            $paramString = $match.Groups[5].Value
            
            # Calculate line number from match index
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            
            # Parse parameter types from C# signature
            $allParams = @()
            if ($paramString.Trim()) {
                $paramParts = $paramString -split ','
                foreach ($part in $paramParts) {
                    if ($part -match '(?:^|\s)([\w<>?\[\]]+)\s+(\w+)') {
                        $paramType = $Matches[1]
                        $paramName = $Matches[2]
                        
                        # Determine parameter source
                        $source = "body"
                        if ($part -match '\[FromQuery\]') { $source = "query" }
                        elseif ($part -match '\[FromRoute\]|\[FromPath\]') { $source = "path" }
                        elseif ($part -match '\[FromHeader\]') { $source = "header" }
                        
                        $allParams += "${paramName}: ${paramType} ($source)"
                    }
                }
            }
            
            # Detect authorization attributes
            $auth = "None"
            $methodContext = $content.Substring([Math]::Max(0, $match.Index - 200), [Math]::Min(400, $content.Length - [Math]::Max(0, $match.Index - 200)))
            if ($methodContext -match '\[Authorize(?:\([^)]+\))?\]') {
                $auth = "Required (Authorization)"
            } elseif ($methodContext -match 'ApiKey|RequireApiKey') {
                $auth = "API Key"
            }
            
            # Extract example from XML documentation comments
            $example = $null
            if ($methodContext -match '///\s*<example>([\s\S]{1,300}?)</example>') {
                $example = $Matches[1].Trim() -replace '<[^>]+>', '' -replace '\s+', ' '
            }
            # Look for return statements with sample data
            if (-not $example -and $methodContext -match 'return\s+(?:Ok|new\s+OkObjectResult)\(([^;]{1,150})\)') {
                $sampleData = $Matches[1].Trim()
                if ($sampleData -match '\bnew\b') {
                    $example = "Sample response: ``$sampleData``"
                }
            }
            
            # Extract description from XML /// <summary> comments
            # Improved to handle multi-line comments and attributes between comment and method
            $description = "API endpoint"
            $lookBehind = $content.Substring([Math]::Max(0, $match.Index - 500), [Math]::Min(500, $match.Index))
            
            # Extract all XML doc lines (///) before the method
            $xmlDocLines = @()
            $lines = ($lookBehind -split "`n")
            for ($idx = $lines.Count - 1; $idx -ge 0; $idx--) {
                if ($lines[$idx] -match '^\s*///') {
                    $xmlDocLines = @($lines[$idx]) + $xmlDocLines
                } elseif ($lines[$idx] -match '^\s*\[' -or $lines[$idx] -match '^\s*$') {
                    # Skip attribute lines and blank lines
                    continue
                } else {
                    break
                }
            }
            
            if ($xmlDocLines.Count -gt 0) {
                $xmlDoc = $xmlDocLines -join "`n"
                # Extract summary content
                if ($xmlDoc -match '///\s*<summary>\s*([\s\S]+?)</summary>') {
                    $summaryContent = $Matches[1].Trim()
                    # Remove XML tags and triple slashes
                    $description = $summaryContent -replace '///\s*', '' -replace '<[^>]+>', '' -replace '\s+', ' ' -replace '^\s+', ''
                }
                # If no summary tag, try to extract first meaningful comment line
                elseif ($xmlDoc -match '///\s*([^<@][^\n]{10,})') {
                    $description = $Matches[1].Trim()
                }
            }
            
            $inventory.endpoints += @{
                method = $method
                path = $path
                file = $file.Name
                filePath = $relativePath
                lineNumber = $lineNumber
                parameters = if ($allParams.Count -gt 0) { $allParams -join ', ' } else { "None" }
                returnType = $returnType
                auth = $auth
                description = $description
                example = $example
                controller = if ($file.Name -match '(\w+)Controller') { $Matches[1] } else { "Other" }
                schema = if ($allParams.Count -gt 0) { "See parameters" } else { "N/A" }
            }
        }
        
        # Detect ASP.NET MVC 5 routes (without path in attribute)
        # Pattern: [HttpMETHOD] public ActionResult MethodName(params)
        # Updated to handle [Route] and other attributes between [HttpMETHOD] and public
        $mvcPattern = '\[(Http(?:Get|Post|Put|Delete|Patch))\][\s\S]{0,300}?public\s+(?:virtual\s+)?(?:async\s+)?(?:Task<)?(?:ActionResult|JsonResult|ViewResult|PartialViewResult|ContentResult|FileResult)(?:<[^>]+>)?\>?\s+(\w+)\s*\(([^)]*)\)'
        $mvcRoutes = [regex]::Matches($content, $mvcPattern)
        foreach ($match in $mvcRoutes) {
            $method = $match.Groups[1].Value.Replace('Http', '').ToUpper()
            $methodName = $match.Groups[2].Value
            $paramString = $match.Groups[3].Value
            
            # Calculate line number
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $relativePath = $file.FullName.Replace($RootPath, "").TrimStart('\', '/')
            
            # Infer route from controller and action name
            $controllerName = if ($file.Name -match '(\w+)Controller\.cs') { $Matches[1] } else { "Unknown" }
            
            # Look for [Route("...")] attribute near the method
            $methodContext = $content.Substring([Math]::Max(0, $match.Index - 300), [Math]::Min(600, $content.Length - [Math]::Max(0, $match.Index - 300)))
            $routePattern = '\[Route\(["' + "'" + ']([^"' + "'" + ']+)["' + "'" + ']\)\]'
            if ($methodContext -match $routePattern) {
                $path = $Matches[1]
                # Replace route parameters like {id:int} with {id}
                $path = $path -replace '\{(\w+):[^}]+\}', '{$1}'
            } else {
                $path = "/$controllerName/$methodName"
            }
            
            # Parse parameters
            $allParams = @()
            if ($paramString.Trim()) {
                $paramParts = $paramString -split ','
                foreach ($part in $paramParts) {
                    if ($part -match '(?:^|\s)([\w<>?\[\]]+)\s+(\w+)') {
                        $paramType = $Matches[1]
                        $paramName = $Matches[2]
                        
                        # MVC 5 parameter binding inference
                        $source = "query"
                        if ($paramType -match 'int|long|guid' -and $method -eq 'GET') { $source = "route" }
                        elseif ($paramType -notmatch 'string|int|long|bool|datetime|guid') { $source = "body" }
                        
                        $allParams += "${paramName}: ${paramType} ($source)"
                    }
                }
            }
            
            # Check for authorization
            $auth = "None"
            $methodContext = $content.Substring([Math]::Max(0, $match.Index - 200), [Math]::Min(400, $content.Length - [Math]::Max(0, $match.Index - 200)))
            if ($methodContext -match '\[Authorize(?:\([^)]+\))?\]') {
                $auth = "Required (Authorization)"
            }
            
            # Extract XML doc comments
            $example = $null
            if ($methodContext -match '///\s*<example>([\s\S]{1,300}?)</example>') {
                $example = $Matches[1].Trim() -replace '<[^>]+>', '' -replace '\s+', ' '
            }
            
            # Extract description from XML /// <summary> comments
            $description = "API endpoint"
            if ($methodContext -match '///\s*<summary>\s*([^<]+)</summary>') {
                $description = $Matches[1].Trim() -replace '///\s*', '' -replace '\s+', ' '
            }
            
            # Determine return type from ActionResult
            $returnType = "HTML View"
            if ($match.Groups[0].Value -match 'JsonResult') { $returnType = "application/json" }
            elseif ($match.Groups[0].Value -match 'ContentResult') { $returnType = "text/plain" }
            elseif ($match.Groups[0].Value -match 'FileResult') { $returnType = "file download" }
            
            $inventory.endpoints += @{
                method = $method
                path = $path
                file = $file.Name
                filePath = $relativePath
                lineNumber = $lineNumber
                parameters = if ($allParams.Count -gt 0) { $allParams -join ', ' } else { "None" }
                returnType = $returnType
                auth = $auth
                description = $description
                example = $example
                controller = $controllerName
                schema = if ($allParams.Count -gt 0) { "See parameters" } else { "N/A" }
            }
        }

        if ($file.Extension -eq ".py") {
            # Flask blueprints (@app.route) with optional methods argument
            $flaskPattern = '@(?<bp>[\w\.]+)\.route\(\s*[' + "'" + '"' + '](?<path>[^' + "'" + '"' + ']+)[' + "'" + '"' + '](?:\s*,\s*methods\s*=\s*\[(?<methods>[^\]]+)\])?'
            $flaskRoutes = [regex]::Matches($content, $flaskPattern)
            foreach ($match in $flaskRoutes) {
                $ctxStart = $match.Index
                $lineNumber = ($content.Substring(0, $ctxStart) -split "`n").Count
                $methodContext = $content.Substring($ctxStart, [Math]::Min(500, $content.Length - $ctxStart))
                $functionName = "handler"
                $paramString = ""
                if ($methodContext -match 'def\s+(\w+)\s*\(([^)]*)\)') {
                    $functionName = $Matches[1]
                    $paramString = $Matches[2]
                }
                $paramList = @()
                if ($paramString) {
                    foreach ($param in ($paramString -split ',')) {
                        $trim = $param.Trim()
                        if ($trim) { $paramList += $trim }
                    }
                }
                $methodsRaw = if ($match.Groups['methods'].Success) { $match.Groups['methods'].Value } else { "" }
                $verbs = if ($methodsRaw) { ($methodsRaw -split ',' | ForEach-Object { $_.Trim(" `'""") } | Where-Object { $_ }) } else { @("GET") }
                if (-not $verbs -or $verbs.Count -eq 0) { $verbs = @("GET") }
                $auth = "None"
                $preContext = $content.Substring([Math]::Max(0, $ctxStart - 200), [Math]::Min(200, $ctxStart))
                if ($preContext -match '@login_required|@jwt_required|@token_required') {
                    $auth = "Auth Decorator"
                }
                foreach ($verb in $verbs) {
                    $inventory.endpoints += @{
                        method = $verb.ToUpper()
                        path = $match.Groups['path'].Value
                        file = $file.Name
                        filePath = $relativePath
                        lineNumber = $lineNumber
                        parameters = if ($paramList.Count -gt 0) { $paramList -join ', ' } else { "request" }
                        returnType = "Flask Response"
                        auth = $auth
                        description = "$functionName Flask route"
                        example = "Call $verb $($match.Groups['path'].Value)"
                        controller = $match.Groups['bp'].Value
                        schema = "N/A"
                    }
                }
            }

            # FastAPI router (@router.get/post/etc)
            $fastPattern = '@(?<router>\w+)\.(?<verb>get|post|put|delete|patch|options|head)\s*\(\s*[' + "'" + '"' + '](?<path>[^' + "'" + '"' + ']+)[' + "'" + '"' + ']'
            $fastRoutes = [regex]::Matches($content, $fastPattern, 'IgnoreCase')
            foreach ($match in $fastRoutes) {
                $ctxStart = $match.Index
                $lineNumber = ($content.Substring(0, $ctxStart) -split "`n").Count
                $methodContext = $content.Substring($ctxStart, [Math]::Min(600, $content.Length - $ctxStart))
                $functionName = "handler"
                $paramString = ""
                if ($methodContext -match 'def\s+(\w+)\s*\(([^)]*)\)') {
                    $functionName = $Matches[1]
                    $paramString = $Matches[2]
                }
                $responseModel = "N/A"
                if ($methodContext -match 'response_model\s*=\s*([\w\.]+)') {
                    $responseModel = $Matches[1]
                }
                $auth = "None"
                if ($methodContext -match 'Depends\([^)]*get_current_user') {
                    $auth = "Depends(get_current_user)"
                }
                $paramList = @()
                if ($paramString) {
                    foreach ($param in ($paramString -split ',')) {
                        $trim = $param.Trim()
                        if (-not $trim) { continue }
                        if ($trim -match '(\w+)\s*:\s*([\w\[\]\.]+)') {
                            $paramList += "$($Matches[1]): $($Matches[2])"
                        }
                        else {
                            $paramList += $trim
                        }
                    }
                }
                $inventory.endpoints += @{
                    method = $match.Groups['verb'].Value.ToUpper()
                    path = $match.Groups['path'].Value
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    parameters = if ($paramList.Count -gt 0) { $paramList -join ', ' } else { "request" }
                    returnType = $responseModel
                    auth = $auth
                    description = "$functionName FastAPI endpoint"
                    example = "Call $($match.Groups['verb'].Value.ToUpper()) $($match.Groups['path'].Value)"
                    controller = $match.Groups['router'].Value
                    schema = $responseModel
                }
            }

            # Django path / re_path definitions
            $djangoPattern = '(?<func>(?:path|re_path))\(\s*[' + "'" + '"' + '](?<path>[^' + "'" + '"' + ']+)[' + "'" + '"' + ']\s*,\s*(?<target>[\w\.]+)'
            $djangoRoutes = [regex]::Matches($content, $djangoPattern)
            foreach ($match in $djangoRoutes) {
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $inventory.endpoints += @{
                    method = "ANY"
                    path = $match.Groups['path'].Value
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    parameters = "Request"
                    returnType = "Django View"
                    auth = "Configured in view"
                    description = "Django route to $($match.Groups['target'].Value)"
                    example = "$($match.Groups['func'].Value)('$($match.Groups['path'].Value)', $($match.Groups['target'].Value))"
                    controller = $match.Groups['target'].Value
                    schema = "N/A"
                }
            }
        }

        if ($file.Extension -eq ".java") {
            # Spring @GetMapping/@PostMapping, etc.
            $springPattern = '@(?<annotation>(?:Get|Post|Put|Delete|Patch)Mapping)\s*(?:\(\s*[' + "'" + '"' + '](?<path>[^' + "'" + '"' + ']+)[' + "'" + '"' + ']\s*\))?'
            $springRoutes = [regex]::Matches($content, $springPattern)
            foreach ($match in $springRoutes) {
                $verb = $match.Groups['annotation'].Value.Replace("Mapping","").ToUpper()
                $path = if ($match.Groups['path'].Success) { $match.Groups['path'].Value } else { "" }
                $ctxStart = $match.Index
                $lineNumber = ($content.Substring(0, $ctxStart) -split "`n").Count
                $methodContext = $content.Substring($ctxStart, [Math]::Min(600, $content.Length - $ctxStart))
                $methodName = "method"
                $paramsString = ""
                if ($methodContext -match '(public|protected|private)\s+[<>\w\s]+\s+(\w+)\s*\(([^)]*)\)') {
                    $methodName = $Matches[2]
                    $paramsString = $Matches[3]
                }
                $paramList = @()
                if ($paramsString) {
                    foreach ($param in ($paramsString -split ',')) {
                        if ($param -match '(@\w+\s+)?([\w<>]+)\s+(\w+)') {
                            $annotation = $Matches[1]
                            $source = switch -Regex ($annotation) {
                                '@PathVariable' { "path" }
                                '@RequestParam' { "query" }
                                '@RequestBody' { "body" }
                                '@RequestHeader' { "header" }
                                default { "arg" }
                            }
                            $paramList += "$($Matches[3]): $($Matches[2]) ($source)"
                        }
                    }
                }
                $inventory.endpoints += @{
                    method = $verb
                    path = if ($path) { $path } else { "/$methodName" }
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    parameters = if ($paramList.Count -gt 0) { $paramList -join ', ' } else { "None" }
                    returnType = "Spring Response"
                    auth = "Spring Security"
                    description = "$methodName Spring endpoint"
                    example = "Call $verb $path"
                    controller = (Split-Path $file.Name -LeafBase)
                    schema = "N/A"
                }
            }

            $requestMappingPattern = '@RequestMapping\s*\((?<params>[^)]*)\)'
            $requestMappings = [regex]::Matches($content, $requestMappingPattern)
            foreach ($match in $requestMappings) {
                $paramText = $match.Groups['params'].Value
                $path = ""
                if ($paramText -match 'value\s*=\s*[' + "'" + '"' + '](?<path>[^' + "'" + '"' + ']+)[' + "'" + '"' + ']') {
                    $path = $Matches['path']
                } elseif ($paramText -match 'path\s*=\s*[' + "'" + '"' + '](?<pathAlt>[^' + "'" + '"' + ']+)[' + "'" + '"' + ']') {
                    $path = $Matches['pathAlt']
                }
                $method = "ANY"
                if ($paramText -match 'RequestMethod\.(?<verb>\w+)') {
                    $method = $Matches['verb'].ToUpper()
                }
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $inventory.endpoints += @{
                    method = $method
                    path = if ($path) { $path } else { "/" }
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    parameters = "See method signature"
                    returnType = "Spring Response"
                    auth = "Spring Security"
                    description = "@RequestMapping endpoint"
                    example = "Call $method $path"
                    controller = (Split-Path $file.Name -LeafBase)
                    schema = "N/A"
                }
            }
        }
    }
    
    # Scan for external API dependencies (HttpClient usage in service layer)
    Write-Progress -Activity "Generating API Inventory" -Status "Scanning for external API calls..." -PercentComplete 35
    
    $externalApis = @()
    $serviceFiles = Get-AppDocSourceFiles -RootPath $RootPath -Include @("*.cs","*.ts","*.js") |
        Where-Object { $_.Name -match "Service|Client|Api|Provider" }
    
    foreach ($file in $serviceFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        $relativePath = $file.FullName.Replace($RootPath, "").TrimStart('\', '/')
        
        # C# HttpClient patterns
        if ($file.Extension -eq '.cs') {
            # Pattern: httpClient.GetAsync("url") or PostAsync, PutAsync, DeleteAsync
            $httpCalls = [regex]::Matches($content, '(?:httpClient|_client|client)\.(Get|Post|Put|Delete|Patch)Async\s*\(\s*[\''"]([^\''"]+)[\''"]')
            foreach ($match in $httpCalls) {
                $method = $match.Groups[1].Value.Replace('Async', '').ToUpper()
                $url = $match.Groups[2].Value
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                
                $externalApis += @{
                    method = $method
                    url = $url
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    type = "HttpClient"
                }
            }
            
            # Pattern: new HttpRequestMessage(HttpMethod.METHOD, "url")
            $httpRequests = [regex]::Matches($content, 'new\s+HttpRequestMessage\s*\(\s*HttpMethod\.(Get|Post|Put|Delete|Patch)\s*,\s*"([^"]+)"')
            foreach ($match in $httpRequests) {
                $method = $match.Groups[1].Value.ToUpper()
                $url = $match.Groups[2].Value
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                
                if ($externalApis | Where-Object { $_.url -eq $url -and $_.lineNumber -eq $lineNumber }) {
                    continue # Skip duplicates
                }
                
                $externalApis += @{
                    method = $method
                    url = $url
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    type = "HttpRequestMessage"
                }
            }
        }
        
        # JavaScript/TypeScript axios, fetch patterns
        if ($file.Extension -in @('.ts', '.js')) {
            # Pattern: axios.get('url') or fetch('url', { method: 'POST' })
            $axiosCalls = [regex]::Matches($content, 'axios\\.(get|post|put|delete|patch)\\s*\\(\\s*["\' + "'" + ']([^"' + "'" + ']+)["\' + "'" + ']')
            foreach ($match in $axiosCalls) {
                $method = $match.Groups[1].Value.ToUpper()
                $url = $match.Groups[2].Value
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                
                $externalApis += @{
                    method = $method
                    url = $url
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    type = "axios"
                }
            }
            
            $fetchCalls = [regex]::Matches($content, 'fetch\\s*\\(\\s*["\' + "'" + ']([^"' + "'" + ']+)["\' + "'" + ']')
            foreach ($match in $fetchCalls) {
                $url = $match.Groups[1].Value
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                
                $externalApis += @{
                    method = "GET" # Default, could be enhanced
                    url = $url
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    type = "fetch"
                }
            }
        }
    }
    
    # Scan Startup.cs for OAuth/Authentication middleware
    Write-Progress -Activity "Generating API Inventory" -Status "Detecting authentication..." -PercentComplete 40
    
    $authInfo = @{
        oauth = $false
        jwtBearer = $false
        apiKey = $false
        basic = $false
        details = @()
    }
    
    $startupFiles = Get-ChildItem -Path $RootPath -Recurse -Include "Startup.cs","Program.cs" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '(\\bin\\|\\obj\\)' }
    
    foreach ($file in $startupFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        # Detect JWT Bearer authentication
        if ($content -match 'AddJwtBearer|UseJwtBearerAuthentication') {
            $authInfo.jwtBearer = $true
            $authInfo.details += "JWT Bearer authentication configured in $($file.Name)"
            
            # Extract authority/issuer if present
            if ($content -match 'Authority\s*=\s*[\''"]([^\''"]+)[\''"]') {
                $authInfo.details += "JWT Authority: $($Matches[1])"
            }
        }
        
        # Detect OAuth
        if ($content -match 'AddOAuth|UseOAuthAuthentication') {
            $authInfo.oauth = $true
            $authInfo.details += "OAuth configured in $($file.Name)"
        }
        
        # Detect API Key middleware
        if ($content -match 'UseApiKey|ApiKeyAuthentication') {
            $authInfo.apiKey = $true
            $authInfo.details += "API Key authentication configured in $($file.Name)"
        }
        
        # Detect Basic Auth
        if ($content -match 'UseBasicAuthentication|AddBasicAuth') {
            $authInfo.basic = $true
            $authInfo.details += "Basic authentication configured in $($file.Name)"
        }
        
        # Detect authorization policies
        $policies = [regex]::Matches($content, 'AddPolicy\((["''])([^"'']+)\1')
        if ($policies.Count -gt 0) {
            $policyNames = $policies | ForEach-Object { $_.Groups[1].Value }
            $authInfo.details += "Authorization Policies: $($policyNames -join ', ')"
        }
    }
    
} catch {
    Write-Warning "Error scanning API files: $_"
}

# Normalize, remove invalid endpoints, then dedupe by method/path/file/line
$normalizedEndpoints = @()
foreach ($endpoint in $inventory.endpoints) {
    $method = if ($endpoint.method) { ([string]$endpoint.method).ToUpperInvariant() } else { "ANY" }
    $controller = if ($endpoint.controller) { [string]$endpoint.controller } else { "Other" }
    $path = Get-NormalizedEndpointPath -Path ([string]$endpoint.path) -Controller $controller -Method $method

    if (-not $path -or $path -eq "/") {
        continue
    }

    $description = Get-EndpointDescription -Description ([string]$endpoint.description) -Method $method -Path $path
    $statusCodes = Get-EndpointStatusHint -Method $method

    $normalizedEndpoints += @{
        method = $method
        path = $path
        file = if ($endpoint.file) { [string]$endpoint.file } else { "unknown" }
        filePath = if ($endpoint.filePath) { [string]$endpoint.filePath } else { "unknown" }
        lineNumber = if ($endpoint.lineNumber) { [int]$endpoint.lineNumber } else { 1 }
        parameters = if ($endpoint.parameters) { [string]$endpoint.parameters } else { "None" }
        returnType = if ($endpoint.returnType) { [string]$endpoint.returnType } else { "unknown" }
        auth = if ($endpoint.auth) { [string]$endpoint.auth } else { "None" }
        description = $description
        example = $endpoint.example
        controller = $controller
        schema = if ($endpoint.schema) { [string]$endpoint.schema } else { "N/A" }
        statusCodes = $statusCodes
        domain = Get-EndpointDomain -Path $path -Controller $controller
    }
}

$uniqueEndpoints = @()
$endpointSeen = @{}
foreach ($endpoint in $normalizedEndpoints) {
    $dedupeKey = "{0}|{1}|{2}|{3}" -f $endpoint.method, $endpoint.path.ToLowerInvariant(), $endpoint.filePath, $endpoint.lineNumber
    if (-not $endpointSeen.ContainsKey($dedupeKey)) {
        $uniqueEndpoints += $endpoint
        $endpointSeen[$dedupeKey] = $true
    }
}

$inventory.endpoints = @($uniqueEndpoints | Sort-Object @{Expression = { $_.domain }}, @{Expression = { $_.path }}, @{Expression = { $_.method }})

Write-Progress -Activity "Generating API Inventory" -Status "Creating inventory..." -PercentComplete 50

# Generate markdown
$markdown = "# API Inventory`n`n"
$markdown += "**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
$markdown += "## Discovered Endpoints ($($inventory.endpoints.Count))`n`n"

# Add diagnostic information
if ($inventory.endpoints.Count -eq 0) {
    Write-Host "⚠️  No API endpoints detected!" -ForegroundColor Yellow
    Write-Host "   Searched in: $RootPath" -ForegroundColor Gray
    Write-Host "   File extensions: *.js, *.ts, *.cs, *.py, *.java" -ForegroundColor Gray
    Write-Host "   Patterns: Express/Router, ASP.NET Core & MVC, Flask, FastAPI, Django path(), Spring @*Mapping" -ForegroundColor Gray
}

Write-Progress -Activity "Generating API Inventory" -Status "Populating template..." -PercentComplete 80

# Build endpoint table + placeholder
$endpointTablePlaceholder = @"
| Name | Path | Method | Description | Parameters | Return Type | Status Codes | Auth Required |
|------|------|--------|-------------|------------|------------|--------------|---------------|

_No API endpoints detected. This codebase may not expose HTTP APIs, or uses patterns not yet recognized by the scanner._
"@

$endpointContent = if ($inventory.endpoints.Count -gt 0) {
    $routeFamilyRows = @($inventory.endpoints | ForEach-Object {
        [pscustomobject]@{
            family = Get-EndpointFamilyPath -Path ([string]$_.path)
            method = [string]$_.method
            domain = [string]$_.domain
        }
    })

    $routeFamilySummary = @($routeFamilyRows | Group-Object -Property family | Sort-Object Count -Descending)
    $routeFamilyTableHeader = "| Route Family | Endpoints | Methods | Primary Domain |`n|--------------|-----------|---------|----------------|"
    $routeFamilyTableRows = @($routeFamilySummary | Select-Object -First 40 | ForEach-Object {
        $methods = @($_.Group | Select-Object -ExpandProperty method -Unique | Sort-Object)
        $domain = ($_.Group | Group-Object -Property domain | Sort-Object Count -Descending | Select-Object -First 1).Name
        $family = Sanitize-MarkdownCell -Value $_.Name -MaxLength 120
        "| ``$family`` | $($_.Count) | $($methods -join ', ') | $domain |"
    })

    $domainSummaryRows = @($inventory.endpoints | Group-Object -Property domain | Sort-Object Count -Descending)
    $domainSummaryTableHeader = "| Domain | Endpoints | Unique Paths | Methods |`n|--------|-----------|--------------|---------|"
    $domainSummaryTableRows = @($domainSummaryRows | ForEach-Object {
        $uniquePaths = @($_.Group | Select-Object -ExpandProperty path -Unique).Count
        $methods = @($_.Group | Select-Object -ExpandProperty method -Unique | Sort-Object)
        "| $($_.Name) | $($_.Count) | $uniquePaths | $($methods -join ', ') |"
    })

    $semanticFamilyRows = @($inventory.endpoints | ForEach-Object {
        [pscustomobject]@{
            semanticFamily = Get-SemanticEndpointFamily -Path ([string]$_.path)
            path = [string]$_.path
            method = [string]$_.method
            domain = [string]$_.domain
        }
    })

    $semanticFamilySummary = @($semanticFamilyRows | Group-Object -Property semanticFamily | Sort-Object Count -Descending)
    $semanticFamilyTableHeader = "| Semantic Family | Endpoints | Unique Paths | Methods | Primary Domain | Examples |`n|-----------------|-----------|--------------|---------|----------------|----------|"
    $semanticFamilyTableRows = @($semanticFamilySummary | Select-Object -First 30 | ForEach-Object {
        $groupRows = @($_.Group)
        $methods = @($groupRows | Select-Object -ExpandProperty method -Unique | Sort-Object)
        $domains = @($groupRows | Group-Object -Property domain | Sort-Object Count -Descending)
        $primaryDomain = if ($domains.Count -gt 0) { [string]$domains[0].Name } else { "general" }
        $uniquePathValues = @($groupRows | Select-Object -ExpandProperty path -Unique)
        $examples = @($uniquePathValues | Select-Object -First 3 | ForEach-Object { Sanitize-MarkdownCell -Value $_ -MaxLength 80 })
        $semanticFamily = Sanitize-MarkdownCell -Value $_.Name -MaxLength 80
        "| ``$semanticFamily`` | $($groupRows.Count) | $($uniquePathValues.Count) | $($methods -join ', ') | $primaryDomain | $($examples -join '; ') |"
    })

    $tableHeader = "| Name | Path | Method | Description | Parameters | Return Type | Status Codes | Auth Required |`n|------|------|--------|-------------|------------|------------|--------------|---------------|"
    $groupBlocks = @()
    $groups = $inventory.endpoints | Group-Object -Property domain
    foreach ($group in $groups) {
        $groupName = if ([string]::IsNullOrWhiteSpace([string]$group.Name)) { "general" } else { [string]$group.Name }
        $rows = @($group.Group | ForEach-Object {
            $name = Sanitize-MarkdownCell -Value ("{0}.{1}" -f $_.controller, $_.method) -MaxLength 100
            $path = Sanitize-MarkdownCell -Value $_.path -MaxLength 140
            $desc = Sanitize-MarkdownCell -Value $_.description -MaxLength 180
            $params = if ($_.parameters -and $_.parameters -ne "None") { Sanitize-MarkdownCell -Value $_.parameters -MaxLength 160 } else { "None" }
            $returnType = Sanitize-MarkdownCell -Value $_.returnType -MaxLength 80
            $statusCodes = Sanitize-MarkdownCell -Value $_.statusCodes -MaxLength 80
            $auth = Sanitize-MarkdownCell -Value $_.auth -MaxLength 80
            "| ``$name`` | ``$path`` | $($_.method) | $desc | ``$params`` | ``$returnType`` | $statusCodes | $auth |"
        })

        $groupBlocks += "### Domain: $groupName`n`n$tableHeader`n$($rows -join "`n")"
    }

    @(
        "### Route Families`n`n$routeFamilyTableHeader`n$($routeFamilyTableRows -join "`n")"
        "### Semantic Families`n`n$semanticFamilyTableHeader`n$($semanticFamilyTableRows -join "`n")"
        "### Domain Summary`n`n$domainSummaryTableHeader`n$($domainSummaryTableRows -join "`n")"
        "### Detailed Endpoints`n`n$($groupBlocks -join "`n`n")"
    ) -join "`n`n"
} else {
    $endpointTablePlaceholder
}

# Update template sections
$content = Get-Content -Path $outputPath -Raw
$content = Update-TemplateSection -Content $content -PlaceholderText $endpointTablePlaceholder -NewContent $endpointContent

$apiSectionPattern = '(?s)(##\s+API Endpoints\s*\r?\n\r?\n).*?(?=\r?\n##\s+Data Models\b)'
$content = [regex]::Replace(
    $content,
    $apiSectionPattern,
    [System.Text.RegularExpressions.MatchEvaluator]{
        param($m)
        return ($m.Groups[1].Value + $endpointContent + "`r`n")
    }
)

$content = Normalize-AppDocTemplateInstructionText -Content $content
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

$artifact = "api-inventory"
$contract = Get-AppDocArtifactContract -Artifact $artifact
$evidenceRecords = @(
    $inventory.endpoints | ForEach-Object {
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
        }
    }
)
$evidencePath = Write-AppDocEvidenceArtifact -RootPath $RootPath -Artifact $artifact -Records $evidenceRecords -Metadata @{
    requiredEvidenceKeys = @($contract.requiredEvidenceKeys)
    requiredSections = @($contract.requiredSections)
    generator = "generate-api-inventory.ps1"
}
if ($evidencePath) {
    [void](Update-AppDocEvidenceManifest -RootPath $RootPath -Artifact $artifact -EvidencePath $evidencePath -RecordCount $evidenceRecords.Count -Metadata @{
        generator = "generate-api-inventory.ps1"
    })
}

Write-Progress -Activity "Generating API Inventory" -Status "Complete" -PercentComplete 100
Write-Host "✅ API inventory generated: $outputPath" -ForegroundColor Green
Write-Host "   Endpoints found: $($inventory.endpoints.Count)" -ForegroundColor Gray
