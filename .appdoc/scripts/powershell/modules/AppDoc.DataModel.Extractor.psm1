function Invoke-AppDocDataModelAstParserScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$ScriptsRoot,
        [Parameter(Mandatory=$true)]
        [string]$ScriptName,
        [Parameter(Mandatory=$true)]
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


    # Deterministic mapping from script name to cache filename
    $cacheFileMap = @{
        'parse-csharp-ast.ps1'    = 'ast-csharp-cache.json'
        'parse-typescript-ast.ps1' = 'ast-typescript-cache.json'
        # Add new parsers here as needed
    }
    if ($cacheFileMap.ContainsKey($ScriptName)) {
        $cacheFile = $cacheFileMap[$ScriptName]
    } else {
        Write-Verbose "Unknown AST parser script: $ScriptName. No cache file mapping found."
        return $null
    }
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

function Add-AppDocAstModels {
    [CmdletBinding()]
    param(
        [object]$AstPayload,
        [Parameter(Mandatory=$true)]
        [ref]$Models
    )

    if (-not $AstPayload -or -not $AstPayload.records) {
        return 0
    }

    $added = 0
    foreach ($record in $AstPayload.records) {
        if ($record.kind -ne "model") { continue }

        $filePath = [string]$record.file
        $fileName = if ($filePath) { [System.IO.Path]::GetFileName($filePath) } else { "unknown" }
        $modelType = if ($record.metadata -and $record.metadata.modelType) { [string]$record.metadata.modelType } else { "class" }

        $properties = @()
        if ($record.metadata -and $record.metadata.properties) {
            if ($record.metadata.properties -is [System.Array]) {
                $properties = @($record.metadata.properties | ForEach-Object { [string]$_ })
            }
            else {
                $properties = @([string]$record.metadata.properties)
            }
        }

        $Models.Value += @{
            type = $modelType
            name = [string]$record.name
            file = $fileName
            filePath = $filePath
            lineNumber = if ($record.lineNumber) { [int]$record.lineNumber } else { 1 }
            properties = $properties
            example = $null
            sourceType = "ast"
        }
        $added++
    }

    return $added
}

function Get-AppDocDataModelSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string[]]$Include
    )

    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "data-model" -Include $Include)
    }

    return @(Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include $Include -ErrorAction SilentlyContinue)
}

function Get-AppDocDataModelRelativePath {
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

function Test-AppDocDataModelCandidate {
    [CmdletBinding()]
    param(
        $Model,
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    if (-not $Model -or -not $Model.name) { return $false }

    $name = [string]$Model.name
    $path = if ($Model.filePath) { [string]$Model.filePath } else { "" }
    $type = if ($Model.type) { ([string]$Model.type).ToLowerInvariant() } else { "class" }
    $propertyCount = @($Model.properties).Count

    if (Get-Command Test-AppDocPathIncluded -ErrorAction SilentlyContinue) {
        if ($path -and -not (Test-AppDocPathIncluded -Path $path -RootPath $RootPath -Artifact "data-model")) { return $false }
    }

    if ($name -match '(?i)^(test|mock|fake|stub|sample|fixture)') { return $false }
    if ($name -match '(?i)(test|mock|fake|stub|sample|fixture)$') { return $false }
    if ($name -match '(?i)(controller|service|repository|helper|startup|program)$') { return $false }
    if ($path -match '(?i)(^|[\\/])(migrations?|seed|seeds|scripts?)([\\/]|$)') { return $false }
    if ($path -match '(?i)(^|[\\/])(ui|views?|components?|pages?)([\\/]|$)' -and $propertyCount -eq 0) { return $false }
    if ($propertyCount -eq 0 -and $type -in @("class", "record", "entity")) { return $false }

    return $true
}

function Get-AppDocDataModelSignalScore {
    [CmdletBinding()]
    param($Model)

    $score = 0
    if (($Model.sourceType ?? "regex") -eq "ast") { $score += 15 } else { $score += 8 }
    $score += [Math]::Min(10, @($Model.properties).Count)
    if ($Model.example) { $score += 2 }
    if ($Model.lineNumber -and [int]$Model.lineNumber -gt 0) { $score += 1 }
    return $score
}

function Select-AppDocCanonicalDataModels {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Models,
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    if (-not $Models -or @($Models).Count -eq 0) {
        return @()
    }

    $filtered = @($Models | Where-Object { Test-AppDocDataModelCandidate -Model $_ -RootPath $RootPath })
    $modelByKey = @{}

    foreach ($model in $filtered) {
        $pathKey = if ($model.filePath) { (([string]$model.filePath).Replace('\', '/')).ToLowerInvariant() } else { "unknown" }
        $dedupeKey = "{0}|{1}" -f ([string]$model.name).ToLowerInvariant(), $pathKey
        if (-not $modelByKey.ContainsKey($dedupeKey)) {
            $modelByKey[$dedupeKey] = $model
            continue
        }

        $existing = $modelByKey[$dedupeKey]
        if ((Get-AppDocDataModelSignalScore -Model $model) -gt (Get-AppDocDataModelSignalScore -Model $existing)) {
            $modelByKey[$dedupeKey] = $model
        }
    }

    return @(
        $modelByKey.Values |
            Sort-Object @{ Expression = { [string]$_.name } }, @{ Expression = { [string]$_.filePath } }, @{ Expression = { [int]$_.lineNumber } }
    )
}

function Get-AppDocDataModelData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [string]$ScriptsRoot = "",
        [array]$Models
    )

    $workingModels = @()
    $astModelCount = 0
    $potentialModelFileCount = 0

    if ($Models -and $Models.Count -gt 0) {
        $workingModels = @($Models)
    }
    else {
        if (-not $ScriptsRoot) {
            $ScriptsRoot = Split-Path $PSScriptRoot -Parent
        }

        $astCSharp = Invoke-AppDocDataModelAstParserScript -ScriptsRoot $ScriptsRoot -ScriptName "parse-csharp-ast.ps1" -RootPath $RootPath
        $astTs = Invoke-AppDocDataModelAstParserScript -ScriptsRoot $ScriptsRoot -ScriptName "parse-typescript-ast.ps1" -RootPath $RootPath
        $astModelCount += Add-AppDocAstModels -AstPayload $astCSharp -Models ([ref]$workingModels)
        $astModelCount += Add-AppDocAstModels -AstPayload $astTs -Models ([ref]$workingModels)

        $modelFiles = Get-AppDocDataModelSourceFiles -RootPath $RootPath -Include @("*.ts","*.js","*.cs","*.py") | Where-Object { $_.Name -match "model|entity|schema|type" }
        $potentialModelFileCount = $modelFiles.Count

        foreach ($file in $modelFiles) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if (-not $content) { continue }

            if ($file.Extension -in @('.ts', '.js')) {
                $headerPattern = "(?:export\s+)?(?:class|interface)\s+(\w+)(?:\s+extends\s+\w+)?(?:\s+implements\s+[\w,\s]+)?\s*\{";
                $headerMatches = [regex]::Matches($content, $headerPattern)
                foreach ($match in $headerMatches) {
                    $name = $match.Groups[1].Value
                    $startIdx = $content.IndexOf('{', $match.Index)
                    if ($startIdx -lt 0) { continue }
                    $depth = 0
                    $endIdx = -1
                    for ($i = $startIdx; $i -lt $content.Length; $i++) {
                        if ($content[$i] -eq '{') { $depth++ }
                        elseif ($content[$i] -eq '}') { $depth-- }
                        if ($depth -eq 0) { $endIdx = $i; break }
                    }
                    if ($endIdx -le $startIdx) { continue }
                    $classBody = $content.Substring($startIdx + 1, $endIdx - $startIdx - 1)
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                    $relativePath = Get-AppDocDataModelRelativePath -RootPath $RootPath -Path $file.FullName
                    $properties = @()
                    $propMatches = [regex]::Matches($classBody, "(\w+)\s*(\?)?\s*:\s*([^;\n]+)")
                    foreach ($prop in $propMatches) {
                        $propName = $prop.Groups[1].Value
                        if ($prop.Groups[2].Success) { $propName += '?' }
                        $propType = $prop.Groups[3].Value.Trim()
                        $properties += "$propName: $propType"
                    }
                    $workingModels += @{
                        type = if ($match.Value -match 'interface') { 'interface' } else { 'class' }
                        name = $name
                        file = $file.Name
                        filePath = $relativePath
                        lineNumber = $lineNumber
                        properties = $properties
                        example = $null
                        sourceType = "regex"
                    }
                }
            }

            if ($file.Extension -eq ".cs") {
                $lines = $content -split "`n"
                $relativePath = Get-AppDocDataModelRelativePath -RootPath $RootPath -Path $file.FullName
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    $line = $lines[$i]
                    if ($line -match '^\s*(?:public|internal|private|protected)?\s*(class|interface|record)\s+(\w+)(?:<[^>]+>)?') {
                        $modelType = $Matches[1]
                        $className = $Matches[2]
                        $properties = @()
                        $braceCount = 0
                        $inClass = $false
                        for ($j = $i; $j -lt [Math]::Min($i + 2000, $lines.Count); $j++) {
                            $currentLine = $lines[$j]
                            $braceCount += ($currentLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                            $braceCount -= ($currentLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                            if ($braceCount -gt 0) { $inClass = $true }
                            if ($inClass -and $braceCount -eq 0) { break }
                            if ($inClass -and $braceCount -eq 1) {
                                if ($currentLine -match '^\s*(public|protected|internal|private)\s+(virtual\s+)?([\w<>\[\]?]+)\s+(\w+)\s*\{\s*get') {
                                    $properties += "$($Matches[4]): $($Matches[3])"
                                }
                                elseif ($currentLine -match '^\s*(public|protected|internal)\s+([\w<>\[\]?]+)\s+(\w+)\s*;') {
                                    $properties += "$($Matches[3]): $($Matches[2])"
                                }
                            }
                        }
                        $workingModels += @{
                            type = $modelType
                            name = $className
                            file = $file.Name
                            filePath = $relativePath
                            lineNumber = ($i + 1)
                            properties = $properties
                            example = $null
                            sourceType = "regex"
                        }
                    }
                }
            }

            if ($file.Extension -eq '.py') {
                $pyClasses = [regex]::Matches($content, "class\s+(\w+)(?:\([^)]*\))?:\s*([\s\S]+?)(?=\nclass\s|\Z)")
                foreach ($match in $pyClasses) {
                    $classBody = $match.Groups[2].Value
                    $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                    $relativePath = Get-AppDocDataModelRelativePath -RootPath $RootPath -Path $file.FullName
                    $properties = @()
                    $propMatches = [regex]::Matches($classBody, "(\w+)\s*:\s*([\w\[\],\s]+)\s*=?")
                    foreach ($prop in $propMatches | Select-Object -First 20) {
                        $propName = $prop.Groups[1].Value
                        if ($propName -notin @('self', 'cls', 'return')) {
                            $properties += "${propName}: $($prop.Groups[2].Value.Trim())"
                        }
                    }
                    $workingModels += @{
                        type = 'class'
                        name = $match.Groups[1].Value
                        file = $file.Name
                        filePath = $relativePath
                        lineNumber = $lineNumber
                        properties = $properties
                        example = $null
                        sourceType = "regex"
                    }
                }
            }
        }

        $hbmFiles = Get-AppDocDataModelSourceFiles -RootPath $RootPath -Include @("*.hbm.xml")
        foreach ($file in $hbmFiles) {
            try {
                [xml]$xmlContent = Get-Content $file.FullName -Raw -ErrorAction Stop
                $ns = @{hbm='urn:nhibernate-mapping-2.2'}
                $classes = Select-Xml -Xml $xmlContent -XPath "//hbm:class" -Namespace $ns
                foreach ($class in $classes) {
                    $relativePath = Get-AppDocDataModelRelativePath -RootPath $RootPath -Path $file.FullName
                    $properties = @()
                    $propNodes = Select-Xml -Xml $class.Node -XPath ".//hbm:property" -Namespace $ns
                    foreach ($prop in $propNodes) {
                        $propType = if ($prop.Node.type) { $prop.Node.type } else { 'string' }
                        $properties += "$($prop.Node.name): ${propType}"
                    }
                    $workingModels += @{
                        type = 'entity'
                        name = $class.Node.name
                        file = $file.Name
                        filePath = $relativePath
                        lineNumber = 1
                        properties = $properties
                        example = if ($class.Node.table) { "Table: $($class.Node.table)" } else { $null }
                        sourceType = "mapping"
                    }
                }
            }
            catch {
                Write-Warning "Failed to parse NHibernate mapping $($file.Name): $_"
            }
        }

        $mapFiles = Get-AppDocDataModelSourceFiles -RootPath $RootPath -Include @("*Map.cs")
        foreach ($file in $mapFiles) {
            try {
                $content = Get-Content $file.FullName -Raw -ErrorAction Stop
                if ($content -match 'class\s+(\w*Map)\s*:\s*(?:ClassMap|EntityMap)<(\w+)>') {
                    $entityName = $Matches[2]
                    $relativePath = Get-AppDocDataModelRelativePath -RootPath $RootPath -Path $file.FullName
                    $properties = @()
                    # Enhanced regex: capture property name and look for .CustomType<YourType>() or .CustomType(typeof(YourType)) after Map(...)
                    $propMappings = [regex]::Matches($content, 'Map\(\w+\s*=>\s*\w+\.(\w+)\)(?:[^;]*?\.CustomType(?:<([\w\.]+)>|\(typeof\(([^\)]+)\)\)))?')
                    foreach ($prop in $propMappings) {
                        $propName = $prop.Groups[1].Value
                        $typeHint = $null
                        if ($prop.Groups[2].Success) {
                            $typeHint = $prop.Groups[2].Value
                        } elseif ($prop.Groups[3].Success) {
                            $typeHint = $prop.Groups[3].Value
                        }
                        if (-not $typeHint) {
                            # Fallback: scan for property declaration in class source
                            $declMatch = [regex]::Match($content, "public\\s+virtual\\s+([\\w<>\[\]?]+)\\s+${propName}\\s*{[^{]*get;[^{]*set;[^{]*}")
                            if ($declMatch.Success) {
                                $typeHint = $declMatch.Groups[1].Value
                            }
                        }
                        if (-not $typeHint) {
                            $typeHint = 'string' # Fallback if no type found
                        }
                        # Document fallback: type is inferred from CustomType, property declaration, or defaults to string
                        $properties += "$propName: $typeHint"
                    }
                    $workingModels += @{
                        type = 'entity'
                        name = $entityName
                        file = $file.Name
                        filePath = $relativePath
                        lineNumber = 1
                        properties = $properties
                        example = "FluentNHibernate entity"
                        sourceType = "mapping"
                    }
                }
            }
            catch {
                Write-Warning "Failed to parse FluentNHibernate mapping $($file.Name): $_"
            }
        }
    }

    return [ordered]@{
        models = @(Select-AppDocCanonicalDataModels -Models $workingModels -RootPath $RootPath)
        astModelCount = $astModelCount
        potentialModelFileCount = $potentialModelFileCount
    }
}

Export-ModuleMember -Function @(
    'Invoke-AppDocDataModelAstParserScript',
    'Add-AppDocAstModels',
    'Test-AppDocDataModelCandidate',
    'Get-AppDocDataModelSignalScore',
    'Select-AppDocCanonicalDataModels',
    'Get-AppDocDataModelData'
)
