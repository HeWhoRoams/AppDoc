#requires -Version 7.2
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [switch]$NoCache,
    [switch]$Json
)

$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
if (Test-Path $scopeModule) { Import-Module $scopeModule -Force -ErrorAction Stop }

$cachePath = Join-Path $RootPath "docs\ast-csharp-cache.json"
if (-not $NoCache -and (Test-Path $cachePath)) {
    $cached = Get-Content $cachePath -Raw
    if ($Json) { $cached } else { Write-Output $cached }
    exit 0
}

$dotnetExists = $null -ne (Get-Command dotnet -ErrorAction SilentlyContinue)
$provider = if ($dotnetExists) { "roslyn" } else { "regex-fallback" }

function Invoke-RoslynProvider {
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    if (-not $dotnetExists) {
        return $null
    }

    $appDocRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
    $toolProjectPath = Join-Path $appDocRoot "tools\AppDoc.CSharpAstParser\AppDoc.CSharpAstParser.csproj"
    if (-not (Test-Path $toolProjectPath)) {
        return $null
    }

    try {
        $jsonOutput = (& dotnet run --project $toolProjectPath --configuration Release -- $RootPath | Out-String).Trim()
        if (-not $jsonOutput) {
            return $null
        }

        $firstBrace = $jsonOutput.IndexOf('{')
        $lastBrace = $jsonOutput.LastIndexOf('}')
        if ($firstBrace -lt 0 -or $lastBrace -lt 0 -or $lastBrace -le $firstBrace) {
            Write-Verbose "Roslyn provider output does not contain JSON payload."
            return $null
        }

        $jsonOutput = $jsonOutput.Substring($firstBrace, ($lastBrace - $firstBrace + 1))

        $parsed = $jsonOutput | ConvertFrom-Json -ErrorAction Stop
        return $parsed
    }
    catch {
        Write-Verbose "Roslyn provider failed: $($_.Exception.Message)"
        return $null
    }
}

$roslynPayload = Invoke-RoslynProvider -RootPath $RootPath
if ($null -ne $roslynPayload -and $null -ne $roslynPayload.records) {
    $roslynPayload | ConvertTo-Json -Depth 20 | Out-File -FilePath $cachePath -Encoding UTF8

    if ($Json) {
        $roslynPayload | ConvertTo-Json -Depth 20
    }
    else {
        Write-Host "C# AST parse complete via Roslyn. Records: $($roslynPayload.records.Count)."
    }
    exit 0
}

# Roslyn output was unavailable, so this run is regex fallback.
$provider = "regex-fallback"
$records = @()
$csFiles = Get-AppDocSourceFiles -RootPath $RootPath -Include @("*.cs")

function Get-LineNumber {
    param(
        [string]$Content,
        [int]$Index
    )

    # Handle null or empty content
    if ([string]::IsNullOrEmpty($Content)) {
        return 1
    }

    # Handle negative index
    if ($Index -lt 0) {
        return 1
    }

    # Clamp index to valid range (0 to Content.Length)
    if ($Index -gt $Content.Length) {
        $Index = $Content.Length
    }

    return ($Content.Substring(0, $Index) -split "`n").Count
}

foreach ($file in $csFiles) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if (-not $content) { continue }

    $relativePath = Get-AppDocRelativePath -RootPath $RootPath -Path $file.FullName

    $classes = [regex]::Matches($content, '\b(class|interface)\s+(\w+)')
    foreach ($match in $classes) {
        $className = $match.Groups[2].Value
        $lineNumber = Get-LineNumber -Content $content -Index $match.Index
        $classBody = ""

        $braceStart = $content.IndexOf('{', $match.Index)
        if ($braceStart -ge 0) {
            $depth = 0
            for ($position = $braceStart; $position -lt $content.Length; $position++) {
                $char = $content[$position]
                if ($char -eq '{') { $depth++ }
                elseif ($char -eq '}') { $depth-- }

                if ($depth -eq 0) {
                    if ($position -gt $braceStart) {
                        $classBody = $content.Substring($braceStart + 1, $position - $braceStart - 1)
                    }
                    break
                }
            }
        }

        $properties = @()
        if ($classBody) {
            $propertyMatches = [regex]::Matches($classBody, '(?m)^\s*(public|protected|internal)\s+(?:virtual\s+)?([\w<>\[\]\?]+)\s+(\w+)\s*\{\s*get')
            foreach ($property in $propertyMatches) {
                $properties += "$($property.Groups[3].Value): $($property.Groups[2].Value)"
            }
        }

        $records += [ordered]@{
            file = $relativePath
            kind = $match.Groups[1].Value
            name = $className
            lineNumber = $lineNumber
            metadata = @{ properties = $properties; language = "C#" }
            provider = $provider
            confidence = 0.5        }

        $records += [ordered]@{
            file = $relativePath
            kind = "model"
            name = $className
            lineNumber = $lineNumber
            metadata = @{ modelType = $match.Groups[1].Value; properties = $properties; language = "C#" }
            provider = $provider
            confidence = if ($provider -eq "roslyn") { 0.82 } else { 0.56 }
        }
    }

    $methods = [regex]::Matches($content, '(public|private|protected|internal)\s+(?:async\s+)?(?:[\w<>\[\]]+)\s+(\w+)\s*\(([^)]*)\)')
    foreach ($match in $methods) {
        $lineNumber = Get-LineNumber -Content $content -Index $match.Index
        $records += [ordered]@{
            file = $relativePath
            kind = "method"
            name = $match.Groups[2].Value
            signature = $match.Groups[0].Value.Trim()
            lineNumber = $lineNumber
            metadata = @{ parameters = $match.Groups[3].Value; language = "C#" }
            provider = $provider
            confidence = if ($provider -eq "roslyn") { 0.75 } else { 0.45 }
        }
    }

    # --- ASP.NET endpoint attributes ------------------------------------------
    # CORE (file has [ApiController]): modern pattern that tolerates [HttpXxx] with
    #   ANY arguments (Name = nameof(...), Order = N, ...) and composes the
    #   controller-level [Route("api/.../[controller]")] template + propagates the
    #   class-level [Authorize] (the modern ASP.NET Core idiom the legacy pattern
    #   silently dropped). Additive: only fires on Core controllers.
    # NON-CORE (MVC 5 / Web Forms / other): the proven legacy pattern + behavior,
    #   kept byte-identical so a convention/attribute MVC 5 surface is unchanged.
    $isApiController = [bool]([regex]::IsMatch($content, '\[ApiController\]'))
    if ($isApiController) {
        # NEW Core pattern. g1=verb g2=args(bounded to the single attribute) g3=return
        # g4=method g5=params. Bounded args group (1-level balanced parens) so
        # nameof(...) / typeof(X<Y>) do not defeat the match, and the intervening-
        # attribute class [\w+...] with args (e.g. [ProducesResponseType(...)]) is tolerated.
        $aspPatternCore = '\[Http(Get|Post|Put|Delete|Patch)(?:\(((?:[^()]|\((?:[^()]*)\))*)\))?\]\s*(?:\[[^\]]+\]\s*)*public\s+(?:async\s+)?(?:Task<)?([^>\s]+)\>?\s+(\w+)\s*\(([^)]*)\)'
        $aspRoutes = [regex]::Matches($content, $aspPatternCore)
        # Controller-level [Route] template + class-level [Authorize]: read the region
        # directly above the controller class declaration (bounded to the class keyword).
        $controllerClassDecl = [regex]::Match($content, '\bclass\s+([A-Za-z_]\w*Controller)\b')
        $coreRouteTemplate = ''
        $coreClassAuthorize = $false
        if ($controllerClassDecl.Success) {
            $coreRegionStart = [Math]::Max(0, $controllerClassDecl.Index - 600)
            $coreRegion = $content.Substring($coreRegionStart, $controllerClassDecl.Index - $coreRegionStart)
            $coreRouteM = [regex]::Match($coreRegion, '\bRoute\s*\(\s*[' + "'" + '"' + ']([^' + "'" + '"' + ']+)[' + "'" + '"' + ']')
            if ($coreRouteM.Success) { $coreRouteTemplate = $coreRouteM.Groups[1].Value }
            $coreClassAuthorize = [bool]([regex]::IsMatch($coreRegion, '\[Authorize\b'))
        }
        foreach ($route in $aspRoutes) {
            $controller = if ($file.Name -match '(\w+)Controller\.cs') { $Matches[1] } else { "Other" }
            $methodName = $route.Groups[4].Value
            $methodArgs = if ($route.Groups[2].Success) { $route.Groups[2].Value } else { '' }
            # first quoted string literal in the args = the route path (empty if none)
            $coreMethodPath = ''
            if ($methodArgs -match '[' + "'" + '"' + ']([^' + "'" + '"' + ']+)[' + "'" + '"' + ']') { $coreMethodPath = $Matches[1] }
            # Gap 3: compose the controller-level [Route] template (resolve [controller]/[action]).
            # Gap 2: a bare-verb (no path) method composes to the conventional segment.
            $composedTemplate = $coreRouteTemplate -replace '\[controller\]', $controller -replace '\[action\]', $methodName
            $routeSegment = if ($coreMethodPath) { $coreMethodPath } else { $methodName }
            if ($composedTemplate) {
                $composedPath = '/' + ($composedTemplate.Trim('/') + '/' + $routeSegment.Trim('/')).TrimStart('/')
            }
            else {
                $composedPath = if ($coreMethodPath) { '/' + $coreMethodPath.TrimStart('/') } else { '/' + $controller + '/' + $methodName }
            }
            $composedPath = ($composedPath -replace '/{2,}', '/')
            if ($composedPath.Length -gt 1 -and $composedPath.EndsWith('/')) { $composedPath = $composedPath.TrimEnd('/') }
            # Gap 4: class-level [Authorize] propagates unless a method-level
            # [AllowAnonymous] (in this method's attribute block, a few lines above)
            # or an explicit method [Authorize] overrides.
            $coreAboveStart = [Math]::Max(0, $route.Index - 400)
            $coreAbove = $content.Substring($coreAboveStart, $route.Index - $coreAboveStart)
            $coreAllowAnonymous = [bool]([regex]::IsMatch($coreAbove, '\[AllowAnonymous\b'))
            $coreMethodAuthorize = [bool]([regex]::IsMatch($route.Value, '\[Authorize\b'))
            $coreAuth = if ($coreAllowAnonymous) { "None" } elseif ($coreClassAuthorize -or $coreMethodAuthorize) { "Required (Authorization)" } else { "None" }
            $lineNumber = Get-LineNumber -Content $content -Index $route.Index
            $parameters = @()
            $paramString = $route.Groups[5].Value
            if ($paramString.Trim()) {
                foreach ($part in ($paramString -split ',')) {
                    $trimmed = $part.Trim()
                    if (-not $trimmed) { continue }
                    if ($trimmed -match '(?:^|\s)([\w<>?\[\]]+)\s+(\w+)') {
                        $parameters += "$($Matches[2]): $($Matches[1])"
                    }
                }
            }
            $records += [ordered]@{
                file = $relativePath
                kind = "endpoint"
                name = $methodName
                lineNumber = $lineNumber
                metadata = @{
                    language = "C#"
                    method = $route.Groups[1].Value.ToUpper()
                    path = $composedPath
                    controller = $controller
                    returnType = $route.Groups[3].Value
                    parameters = $parameters
                    auth = $coreAuth
                    description = "AST extracted endpoint"
                    routeTemplate = $coreRouteTemplate
                }
                provider = $provider
                confidence = if ($provider -eq "roslyn") { 0.86 } else { 0.6 }
            }
        }
    }
    else {
        $aspPattern = '\[Http(Get|Post|Put|Delete|Patch)(?:\(["'']([^"'']+)["'']\))?\]\s*(?:\[\w+[^\]]*\]\s*)*public\s+(?:async\s+)?(?:Task<)?([^>\s]+)\>?\s+(\w+)\s*\(([^)]*)\)'
        $aspRoutes = [regex]::Matches($content, $aspPattern)
        foreach ($route in $aspRoutes) {
            $controller = if ($file.Name -match '(\w+)Controller\.cs') { $Matches[1] } else { "Other" }
            $lineNumber = Get-LineNumber -Content $content -Index $route.Index
            $parameters = @()
            $paramString = $route.Groups[5].Value
            if ($paramString.Trim()) {
                foreach ($part in ($paramString -split ',')) {
                    $trimmed = $part.Trim()
                    if (-not $trimmed) { continue }
                    if ($trimmed -match '(?:^|\s)([\w<>?\[\]]+)\s+(\w+)') {
                        $parameters += "$($Matches[2]): $($Matches[1])"
                    }
                }
            }
            $records += [ordered]@{
                file = $relativePath
                kind = "endpoint"
                name = $route.Groups[4].Value
                lineNumber = $lineNumber
                metadata = @{
                    language = "C#"
                    method = $route.Groups[1].Value.ToUpper()
                    path = if ($route.Groups[2].Success) { $route.Groups[2].Value } else { "" }
                    controller = $controller
                    returnType = $route.Groups[3].Value
                    parameters = $parameters
                    auth = if ($route.Value -match '\[Authorize') { "Required (Authorization)" } else { "None" }
                    description = "AST extracted endpoint"
                }
                provider = $provider
                confidence = if ($provider -eq "roslyn") { 0.86 } else { 0.6 }
            }
        }
    }
}

$payload = [ordered]@{
    generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    provider = $provider
    providerReady = $dotnetExists
    records = $records
    note = if ($dotnetExists) { "Roslyn provider unavailable at runtime; using regex fallback." } else { "dotnet SDK not available; using regex fallback." }
}

$cacheDir = Split-Path $cachePath -Parent
if (-not (Test-Path $cacheDir)) {
    New-Item -ItemType Directory -Path $cacheDir -Force | Out-Null
}
$payload | ConvertTo-Json -Depth 20 | Out-File -FilePath $cachePath -Encoding UTF8
if ($Json) {
    $payload | ConvertTo-Json -Depth 20
}
else {
    Write-Host "C# AST parse scaffold complete. Records: $($records.Count). Provider: $provider"
}
