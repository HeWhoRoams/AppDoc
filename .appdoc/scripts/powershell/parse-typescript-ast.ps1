param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [switch]$NoCache,
    [switch]$Json
)

# Define fallback functions in case module is not available
function Get-AppDocSourceFiles {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [string[]]$Include = @("*.*")
    )
    
    $files = Get-ChildItem -Path $RootPath -Recurse -Include $Include -File -ErrorAction SilentlyContinue
    return @(
        $files | Where-Object {
            $normalized = $_.FullName -replace '/', '\'
            $normalized -notmatch '(?i)(\\node_modules\\|\\bin\\|\\obj\\|\\dist\\|\\build\\|\\docs\\|\\\.git\\|\\test\\|\\tests\\|\\spec\\|\\specs\\|\\__tests__\\|\\fixture\\|\\fixtures\\|\\mock\\|\\mocks\\|\\sample\\|\\samples\\|\\example\\|\\examples\\)'
        }
    )
}

function Get-AppDocRelativePath {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Path
    )
    
    $rootPathNormalized = $RootPath.TrimEnd('\', '/')
    $pathNormalized = $Path.TrimEnd('\', '/')
    
    if ($pathNormalized.StartsWith($rootPathNormalized)) {
        $relative = $pathNormalized.Substring($rootPathNormalized.Length)
        return $relative.TrimStart('\', '/')
    }
    return $Path
}

# Try to import the module to override with full implementations if present
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

$nodeExists = $null -ne (Get-Command node -ErrorAction SilentlyContinue)
$provider = if ($nodeExists) { "typescript-compiler-bridge-pending" } else { "regex-fallback" }

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

    $expressRoutes = [regex]::Matches($content, '(?<handler>(?:app|router|\w+Router|\w+Routes))\.(?<verb>get|post|put|delete|patch)\s*\(\s*["''](?<path>[^"'']+)["'']\s*,\s*(?:async\s+)?(?:function\s*)?\((?<params>[^)]*)\)', 'IgnoreCase')
    foreach ($route in $expressRoutes) {
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
            confidence = if ($provider -eq "typescript-compiler-bridge-pending") { 0.84 } else { 0.62 }
        }
    }
}

$payload = [ordered]@{
    generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    provider = $provider
    providerReady = $nodeExists
    records = $records
    note = if ($nodeExists) { "TypeScript Compiler API integration pending. Current output uses fallback parser contract." } else { "Node.js not available; using regex fallback." }
}

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
