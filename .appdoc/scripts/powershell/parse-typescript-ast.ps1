param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [switch]$NoCache,
    [switch]$Json
)

# Import the scope module for its working Get-AppDocSourceFiles / Get-AppDocRelativePath.
# (This mirrors parse-csharp-ast.ps1. A previous revision defined broken local fallbacks
# here that referenced an undefined `$files` and shadowed the module's implementations, so
# the parser produced 0 records when invoked from within the generic extractor session.)
$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
if (Test-Path $scopeModule) { 
    Import-Module $scopeModule -Force -ErrorAction Stop 
}
else {
    Write-Warning "AppDoc.Scope module not found at '$scopeModule'. Using fallback implementations."
}

$cachePath = Join-Path $RootPath "docs\ast-typescript-cache.json"
if (-not $NoCache -and (Test-Path $cachePath)) {
    $cached = Get-Content $cachePath -Raw
    if ($Json) { $cached } else { Write-Output $cached }
    exit 0
}


# Always report the current provider as 'regex-fallback'.
$nodeExists = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
$provider = "regex-fallback"
# If Node.js is available, indicate a pending provider for future use.
$pendingProvider = if ($nodeExists) { "typescript-compiler-bridge-pending" } else { $null }

$records = @()
$tsFiles = Get-AppDocSourceFiles -RootPath $RootPath -Include @("*.ts","*.tsx","*.js","*.jsx")

function Get-LineNumber {
    param(
        [string]$Content,
        [int]$Index
    )

    if ($Index -lt 0) { return 1 }
    return ($Content.Substring(0, $Index) -split "`n").Count
}

foreach ($file in $tsFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $relativePath = Get-AppDocRelativePath -RootPath $RootPath -Path $file.FullName

    $exports = [regex]::Matches($content, '\bexport\s+(class|interface|function|const)\s+(\w+)')
    foreach ($match in $exports) {
        $lineNumber = Get-LineNumber -Content $content -Index $match.Index

        $records += [ordered]@{
            file = $relativePath
            kind = $match.Groups[1].Value
            name = $match.Groups[2].Value
            lineNumber = $lineNumber
            metadata = @{ language = "TypeScript" }
            provider = $provider
            confidence = if ($provider -eq "typescript-compiler-bridge-pending") { 0.8 } else { 0.55 }
        }

        if ($match.Groups[1].Value -in @("class", "interface")) {
            $modelProperties = @()
            # Use balanced-brace parser to extract full class/interface body
            $classBodyContent = $null
            $searchStart = $match.Index
            $braceCounter = 0
            $braceStart = -1
            
            for ($i = $searchStart; $i -lt $content.Length; $i++) {
                if ($content[$i] -eq '{') {
                    if ($braceStart -eq -1 -and $i -ge $searchStart) {
                        $braceStart = $i
                    }
                    $braceCounter++
                }
                elseif ($content[$i] -eq '}') {
                    $braceCounter--
                    if ($braceCounter -eq 0 -and $braceStart -ne -1) {
                        # Extract the body between the opening and closing braces
                        $classBodyContent = $content.Substring($braceStart + 1, $i - $braceStart - 1)
                        break
                    }
                }
            }
            
            if ($classBodyContent) {
                $propMatches = [regex]::Matches($classBodyContent, '(?m)^\s*(\w+)\??\s*:\s*([\w<>\[\]\|]+)')
                foreach ($property in $propMatches) {
                    $modelProperties += "$($property.Groups[1].Value): $($property.Groups[2].Value)"
                }
            }

            $records += [ordered]@{
                file = $relativePath
                kind = "model"
                name = $match.Groups[2].Value
                lineNumber = $lineNumber
                metadata = @{ modelType = $match.Groups[1].Value; properties = $modelProperties; language = "TypeScript" }
                provider = $provider
                confidence = if ($provider -eq "typescript-compiler-bridge-pending") { 0.82 } else { 0.58 }
            }
        }
    }

    $decorators = [regex]::Matches($content, '@(Controller|Get|Post|Put|Delete|Patch|Injectable)\b')
    foreach ($match in $decorators) {
        $lineNumber = Get-LineNumber -Content $content -Index $match.Index
        $records += [ordered]@{
            file = $relativePath
            kind = "decorator"
            name = $match.Groups[1].Value
            lineNumber = $lineNumber
            metadata = @{ language = "TypeScript" }
            provider = $provider
            confidence = if ($provider -eq "typescript-compiler-bridge-pending") { 0.78 } else { 0.5 }
        }
    }

    # Inline handler pattern: matches router.get('/path', (req, res) => { ... }) or router.get('/path', async function(req, res) { ... })
    # The function-parameter list is captured as the `params` group; the match ends at the closing paren of the param list.
    $expressPatternInline = '(?<handler>(?:app|router|\w+Router|\w+Routes))\.(?<verb>get|post|put|delete|patch)\s*\(\s*["''](?<path>[^"'']+)["'']\s*,\s*(?:async\s+)?(?:function\s*)?\((?<params>[^)]*)\)'
    $expressRoutesInline = [regex]::Matches($content, $expressPatternInline, 'IgnoreCase')
    # Controller-idiom pattern: matches router.get('/path', handlerFn) or router.get('/path', mw1, handlerFn) or router.post('/path', upload.single("image"), handlerFn)
    # The args group captures everything after the path string up to (but not including) the closing paren of the router.method() call.
    # The negative lookahead (?!\s*(?:async|function)\b) prevents double-matching inline handlers.
    # \w+ at the start requires the first arg to be an identifier (not a paren or async/function keyword).
    # (?:[^()]|\([^()]*\))* handles one level of nested calls (e.g. upload.single("image")).
    $expressPatternCtrl = '(?<handler>(?:app|router|\w+Router|\w+Routes))\.(?<verb>get|post|put|delete|patch)\s*\(\s*["''](?<path>[^"'']+)["'']\s*,\s*(?<args>(?!\s*(?:async|function)\b)\w+(?:[^()]|\([^()]*\))*)\)'
    $expressRoutesCtrl = [regex]::Matches($content, $expressPatternCtrl, 'IgnoreCase')

    foreach ($route in $expressRoutesInline) {
        $lineNumber = Get-LineNumber -Content $content -Index $route.Index
        $paramList = @()
        if ($route.Groups['params'].Value) {
            foreach ($param in ($route.Groups['params'].Value -split ',')) {
                $trimmed = $param.Trim()
                if ($trimmed) { $paramList += $trimmed }
            }
        }

        $records += [ordered]@{
            file = $relativePath
            kind = "endpoint"
            name = "$($route.Groups['handler'].Value).$($route.Groups['verb'].Value.ToUpper())"
            lineNumber = $lineNumber
            metadata = @{
                language = "TypeScript"
                method = $route.Groups['verb'].Value.ToUpper()
                path = $route.Groups['path'].Value
                controller = $route.Groups['handler'].Value
                returnType = "application/json"
                parameters = $paramList
                auth = "None"
                description = "AST extracted endpoint"
            }
            provider = $provider
            confidence = if ($pendingProvider) { 0.84 } else { 0.62 }
        }
    }

    foreach ($route in $expressRoutesCtrl) {
        $lineNumber = Get-LineNumber -Content $content -Index $route.Index
        $argsStr = $route.Groups['args'].Value
        # The last argument is the actual handler/controller function (e.g. `register` in `authLimiter, register`)
        $argParts = [regex]::Split($argsStr, ',\s*(?=[^,]*$)')
        $controllerFn = $argParts[$argParts.Length - 1].Trim()

        $records += [ordered]@{
            file = $relativePath
            kind = "endpoint"
            name = "$($route.Groups['handler'].Value).$($route.Groups['verb'].Value.ToUpper())"
            lineNumber = $lineNumber
            metadata = @{
                language = "TypeScript"
                method = $route.Groups['verb'].Value.ToUpper()
                path = $route.Groups['path'].Value
                controller = $controllerFn
                returnType = "application/json"
                parameters = @()
                auth = "None"
                description = "AST extracted endpoint (controller idiom)"
            }
            provider = $provider
            confidence = if ($pendingProvider) { 0.84 } else { 0.62 }
        }
    }
}


# NOTE: The brace-balancing loop (using $searchStart, $braceCounter, $braceStart, $classBodyContent) does NOT skip braces inside string literals or comments. This can cause mis-parsing of class/interface bodies if braces appear inside quoted strings or comments. This is a known limitation of the lightweight regex fallback parser.
$payload = [ordered]@{
    generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    provider = $provider
    providerReady = $nodeExists
    records = $records
    note = if ($nodeExists) {
        "TypeScript Compiler API integration pending. Current output uses fallback parser contract. Known limitation: brace-balancing loop does not skip braces inside strings/comments."
    } else {
        "Node.js not available; using regex fallback. Known limitation: brace-balancing loop does not skip braces inside strings/comments."
    }
}
# Add pendingProvider field if Node.js is available
if ($pendingProvider) { $payload["pendingProvider"] = $pendingProvider }

# Ensure the cache directory exists before writing
$cacheDir = Split-Path -Parent $cachePath
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}

$payload | ConvertTo-Json -Depth 20 | Out-File -FilePath $cachePath -Encoding UTF8

if ($Json) {
    $payload | ConvertTo-Json -Depth 20
}
else {
    Write-Host "TypeScript AST parse scaffold complete. Records: $($records.Count). Provider: $provider"
}
