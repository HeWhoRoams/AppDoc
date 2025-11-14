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

# Scan for API files (Express.js, ASP.NET, Flask, etc.)
try {
    $apiFiles = Get-ChildItem -Path $RootPath -Recurse -Include "*.js","*.ts","*.cs","*.py" -ErrorAction Stop | 
        Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\__pycache__)' -and 
                       ($_.Name -match "route|api|controller|endpoint") }

    Write-Host "  Found $($apiFiles.Count) potential API files" -ForegroundColor Gray

    foreach ($file in $apiFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        # Detect Express.js routes with parameter extraction
        # Pattern: app.METHOD('/path', (req, res) => { ... }) or app.METHOD('/path', function(req, res) { ... })
        $pattern = 'app\.(get|post|put|delete|patch)\s*\([' + "'" + '"' + ']([^' + "'" + '"' + ']+)[' + "'" + '"' + ']\s*,\s*(?:async\s+)?(?:function\s*)?\(([^)]*)\)'
        $expressRoutes = [regex]::Matches($content, $pattern)
        foreach ($match in $expressRoutes) {
            $method = $match.Groups[1].Value.ToUpper()
            $path = $match.Groups[2].Value
            $params = $match.Groups[3].Value
            
            # Calculate line number from match index
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $relativePath = $file.FullName.Replace($RootPath, "").TrimStart('\', '/')
            
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
            $relativePath = $file.FullName.Replace($RootPath, "").TrimStart('\', '/')
            
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
                if ($lines[$idx] -match '^\\s*///') {
                    $xmlDocLines = @($lines[$idx]) + $xmlDocLines
                } elseif ($lines[$idx] -match '^\\s*\\[' -or $lines[$idx] -match '^\\s*$') {
                    # Skip attribute lines and blank lines
                    continue
                } else {
                    break
                }
            }
            
            if ($xmlDocLines.Count -gt 0) {
                $xmlDoc = $xmlDocLines -join "`n"
                # Extract summary content
                if ($xmlDoc -match '///\\s*<summary>\\s*([\\s\\S]+?)</summary>') {
                    $summaryContent = $Matches[1].Trim()
                    # Remove XML tags and triple slashes
                    $description = $summaryContent -replace '///\\s*', '' -replace '<[^>]+>', '' -replace '\\s+', ' ' -replace '^\\s+', ''
                }
                # If no summary tag, try to extract first meaningful comment line
                elseif ($xmlDoc -match '///\\s*([^<@][^\\n]{10,})') {
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
    }
    
    # Scan for external API dependencies (HttpClient usage in service layer)
    Write-Progress -Activity "Generating API Inventory" -Status "Scanning for external API calls..." -PercentComplete 35
    
    $externalApis = @()
    $serviceFiles = Get-ChildItem -Path $RootPath -Recurse -Include "*.cs","*.ts","*.js" -ErrorAction Stop |
        Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\__pycache__)' -and
                       ($_.Name -match "Service|Client|Api|Provider") }
    
    foreach ($file in $serviceFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        $relativePath = $file.FullName.Replace($RootPath, "").TrimStart('\', '/')
        
        # C# HttpClient patterns
        if ($file.Extension -eq '.cs') {
            # Pattern: httpClient.GetAsync("url") or PostAsync, PutAsync, DeleteAsync
            $httpCalls = [regex]::Matches($content, '(?:httpClient|_client|client)\.(Get|Post|Put|Delete|Patch)Async\s*\(\s*["\']([^"\']+)["\']')
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
            $httpRequests = [regex]::Matches($content, 'new\\s+HttpRequestMessage\\s*\\(\\s*HttpMethod\\.(Get|Post|Put|Delete|Patch)\\s*,\\s*["\']([^"\']+)["\']')
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
            if ($content -match 'Authority\\s*=\\s*["\']([^"\']+)["\']') {
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
        $policies = [regex]::Matches($content, 'AddPolicy\\(["\']([^"\']+)["\']')
        if ($policies.Count -gt 0) {
            $policyNames = $policies | ForEach-Object { $_.Groups[1].Value }
            $authInfo.details += "Authorization Policies: $($policyNames -join ', ')"
        }
    }
    
} catch {
    Write-Warning "Error scanning API files: $_"
}

Write-Progress -Activity "Generating API Inventory" -Status "Creating inventory..." -PercentComplete 50

# Generate markdown
$markdown = "# API Inventory`n`n"
$markdown += "**Generated**: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n`n"
$markdown += "## Discovered Endpoints ($($inventory.endpoints.Count))`n`n"

# Add diagnostic information
if ($inventory.endpoints.Count -eq 0) {
    Write-Host "⚠️  No API endpoints detected!" -ForegroundColor Yellow
    Write-Host "   Searched in: $RootPath" -ForegroundColor Gray
    Write-Host "   File extensions: *.js, *.ts, *.cs" -ForegroundColor Gray
    Write-Host "   Patterns: Express.js (app.METHOD), ASP.NET Core ([HttpMETHOD('route')]), ASP.NET MVC ([HttpMETHOD])" -ForegroundColor Gray
}

Write-Progress -Activity "Generating API Inventory" -Status "Populating template..." -PercentComplete 80

# Build endpoint table + placeholder
$endpointTablePlaceholder = @"
| Name | Path | Method | Description | Parameters | Return Type | Status Codes | Auth Required |
|------|------|--------|-------------|------------|------------|--------------|---------------|

_No API endpoints detected. This codebase may not expose HTTP APIs, or uses patterns not yet recognized by the scanner._
"@

$endpointContent = if ($inventory.endpoints.Count -gt 0) {
    $tableHeader = "| Name | Path | Method | Description | Parameters | Return Type | Status Codes | Auth Required |`n|------|------|--------|-------------|------------|------------|--------------|---------------|"
    $tableRows = $inventory.endpoints | ForEach-Object {
        $name = "$($_.controller).$($_.method)"
        $params = if ($_.parameters -and $_.parameters -ne "None") { $_.parameters } else { "None" }
        $desc = if ($_.description) { $_.description } else { "API endpoint" }
        $statusCodes = "200, 400, 500" # Could be enhanced to detect actual status codes
        "| ``$name`` | ``$($_.path)`` | $($_.method) | $desc | ``$params`` | ``$($_.returnType)`` | $statusCodes | $($_.auth) |"
    }
    $tableHeader + "`n" + ($tableRows -join "`n")
} else {
    $endpointTablePlaceholder
}

# Update template sections
$content = Get-Content -Path $outputPath -Raw
$content = Update-TemplateSection -Content $content -PlaceholderText $endpointTablePlaceholder -NewContent $endpointContent
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Progress -Activity "Generating API Inventory" -Status "Complete" -PercentComplete 100
Write-Host "✅ API inventory generated: $outputPath" -ForegroundColor Green
Write-Host "   Endpoints found: $($inventory.endpoints.Count)" -ForegroundColor Gray