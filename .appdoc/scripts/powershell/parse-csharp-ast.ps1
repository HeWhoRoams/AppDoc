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

$payload = [ordered]@{
    generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    provider = "regex-fallback"
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
