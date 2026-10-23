# Output folder resolution (config outputDir).
Import-Module (Join-Path $PSScriptRoot 'AppDoc.Paths.psm1') -ErrorAction Stop

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
    $cachePath = Join-Path (Get-AppDocDocsPath -RootPath $RootPath) $cacheFile
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
        [ref]$Models,
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    if (-not $AstPayload -or -not $AstPayload.records) {
        return 0
    }

    $added = 0
    foreach ($record in $AstPayload.records) {
        if ($record.kind -ne "model") { continue }

        $filePath = [string]$record.file
        if ($filePath) {
            if (Get-Command Test-AppDocGeneratedProxyPath -ErrorAction SilentlyContinue) {
                if (Test-AppDocGeneratedProxyPath -Path $filePath -RootPath $RootPath) {
                    continue
                }
            }

            if (Get-Command Test-AppDocPathIncluded -ErrorAction SilentlyContinue) {
                $pathFilterArgs = @{
                    Path = $filePath
                    RootPath = $RootPath
                    Artifact = "data-model"
                    AdditionalExcludePatterns = @(Get-AppDocDataModelAdditionalExcludePatterns)
                }
                if (-not (Test-AppDocPathIncluded @pathFilterArgs)) {
                    continue
                }
            }
        }

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

function Get-AppDocDataModelAdditionalExcludePatterns {
    [CmdletBinding()]
    param()

    if (Get-Command Get-AppDocGeneratedProxyExcludePatterns -ErrorAction SilentlyContinue) {
        return @(Get-AppDocGeneratedProxyExcludePatterns)
    }

    return @(
        '(?i)(?:^|[\\/])(Service References|Connected Services|Web References)(?:[\\/]|$)',
        '(?i)(?:^|[\\/])Reference\.cs$',
        '(?i)\.(svcmap|svcinfo|wsdl|disco)$'
    )
}

function Get-AppDocDataModelSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string[]]$Include
    )

    $additionalExcludePatterns = @(Get-AppDocDataModelAdditionalExcludePatterns)

    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "data-model" -Include $Include -AdditionalExcludePatterns $additionalExcludePatterns)
    }

    return @(
        Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include $Include -ErrorAction SilentlyContinue |
            Where-Object {
                $normalized = $_.FullName -replace '/', '\'
                foreach ($pattern in $additionalExcludePatterns) {
                    if ($normalized -match $pattern) { return $false }
                }
                return $true
            }
    )
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
        if ($path -and -not (Test-AppDocPathIncluded -Path $path -RootPath $RootPath -Artifact "data-model" -AdditionalExcludePatterns (Get-AppDocDataModelAdditionalExcludePatterns))) { return $false }
    }

    if (Get-Command Test-AppDocGeneratedProxyPath -ErrorAction SilentlyContinue) {
        if ($path -and (Test-AppDocGeneratedProxyPath -Path $path -RootPath $RootPath)) { return $false }
    }

    if ($name -match '(?i)^(test|mock|fake|stub|sample|fixture)') { return $false }
    if ($name -match '(?i)(test|mock|fake|stub|sample|fixture)$') { return $false }
    if ($name -match '(?i)(controller|service|repository|helper|startup|program)$') { return $false }
    if ($path -match '(?i)(^|[\\/])(migrations?|seed|seeds|scripts?)([\\/]|$)') { return $false }
    if ($path -match '(?i)(^|[\\/])(Service References|Connected Services|Web References)([\\/]|$)') { return $false }
    if ($path -match '(?i)(^|[\\/])Reference\.cs$') { return $false }
    if ($path -match '(?i)(^|[\\/])(ui|views?|components?|pages?)([\\/]|$)' -and $propertyCount -eq 0) { return $false }
    # Zero-property rejection (ADDITIVE, ORM-scoped): a C#/TS `class`/`record`/`entity`
    # /`interface` with no properties is still rejected (unchanged). A Python ORM-mapped
    # class (db.Model / __tablename__ / db.Column / new Schema) is a real model even with
    # zero extracted properties, because its columns are bare `name = db.Column(...)`
    # declarations with no PEP-484 annotation. Only the .py branch sets `ormMapped`,
    # so C#/.NET and TS models are unaffected by this relaxation.
    if ($propertyCount -eq 0 -and $type -in @("class","record","entity")) {
        $isOrmMapped = ($Model -is [System.Collections.IDictionary] -and $Model.Contains('ormMapped') -and [bool]$Model.ormMapped)
        if (-not $isOrmMapped) { return $false }
    }

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
        $astModelCount += Add-AppDocAstModels -AstPayload $astCSharp -Models ([ref]$workingModels) -RootPath $RootPath
        $astModelCount += Add-AppDocAstModels -AstPayload $astTs -Models ([ref]$workingModels) -RootPath $RootPath

        # NOTE: .java files are detected by CONTENT (class + field scan below), NOT by
        # the filename heuristic that gates the ts/js/cs/py branches -- Java has no
        # filename convention for entities and no AST parser in the cache map, so an
        # entity in Ticket.java would be silently dropped by the name filter. The
        # class-level + candidate filters (Test-AppDocDataModelCandidate) keep the
        # result to real models (controllers/services/repositories and empty classes
        # are still excluded there).
        # .py is likewise gated by CONTENT (the ORM/class scan below), NOT by filename:
        # SQLAlchemy models are routinely named user.py / person.py / natural_person.py
        # (no "model/entity/schema/type" token), so the name filter alone would drop
        # them. The class-level + candidate filters keep the result to real models.
        $modelFiles = Get-AppDocDataModelSourceFiles -RootPath $RootPath -Include @("*.ts","*.js","*.cs","*.py","*.java") |
            Where-Object { $_.Name -match "model|entity|schema|type" -or $_.Extension -eq ".java" -or $_.Extension -eq ".py" }
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
                        $properties += "${propName}: $propType"
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
                # Python / SQLAlchemy ORM extraction (ADDITIVE -- .py branch only).
                # A Python class is a data model when it has >= 1 top-level (class-member-
                # indented) data field: a PEP-484 annotated field (name: Type -- dataclass /
                # Pydantic / fixture case) OR a SQLAlchemy ORM declaration
                # (name = db.Column(...) / db.relationship(...)). Fields sit at the class's
                # member indent; method bodies and their params/locals are deeper (or are
                # `def` lines), so they are not counted -- this is what keeps plain helper
                # classes (Config / DTO / Service / Format / Factory) OUT of the result.
                # The class is flagged `ormMapped` when it declares __tablename__ / db.Model /
                # db.Column, so a zero-property ORM class still passes the candidate filter
                # (an ORM class with __tablename__ is a real model even when its columns carry
                # no PEP-484 annotation).
                $pyLines = $content -split "`n"
                $relativePath = Get-AppDocDataModelRelativePath -RootPath $RootPath -Path $file.FullName
                $pyLineCount = $pyLines.Count
                for ($i = 0; $i -lt $pyLineCount; $i++) {
                    $line = $pyLines[$i]
                    if ($line -notmatch '^(\s*)class\s+(\w+)\s*(\([^)]*\))?\s*:') { continue }
                    $clsName = $Matches[2]
                    $clsIndent = $Matches[1].Length
                    # Class body: lines after the header until the next non-blank line whose
                    # indentation is <= the class header's indentation.
                    $bodyLines = @()
                    $j = $i + 1
                    while ($j -lt $pyLineCount) {
                        $bl = $pyLines[$j]
                        if ($bl -match '^(\s*)') { $bLead = $Matches[1].Length } else { $bLead = 0 }
                        if ($bl.Trim() -and $bLead -le $clsIndent) { break }
                        $bodyLines += ,@($bLead, $bl)
                        $j++
                    }
                    # Member (field) indent = minimum indent among non-blank body lines.
                    $memberIndent = -1
                    foreach ($bl in $bodyLines) {
                        if ($bl[1].Trim()) { if ($memberIndent -lt 0 -or $bl[0] -lt $memberIndent) { $memberIndent = $bl[0] } }
                    }
                    $properties = @()
                    $ormMapped = $false
                    $seenProp = @{}
                    foreach ($bl in $bodyLines) {
                        $bLead = $bl[0]; $bText = $bl[1].Trim()
                        if (-not $bText) { continue }
                        if ($bLead -ne $memberIndent) { continue }
                        if ($bText -match '^@') { continue }
                        if ($bText -match '^def\s') { continue }
                        if ($bText -match '^\s*(\w+)\s*=\s*db\.Column\s*\((.*)\)\s*$') {
                            $fname = $Matches[1]; $inner = $Matches[2]
                            if (-not $seenProp.ContainsKey($fname)) {
                                $seenProp[$fname] = $true
                                $ormMapped = $true
                                $first = $inner
                                $depth = 0; $cut = -1
                                for ($k = 0; $k -lt $inner.Length; $k++) {
                                    $c = $inner[$k]
                                    if ($c -eq '(') { $depth++ } elseif ($c -eq ')') { $depth-- }
                                    elseif ($c -eq ',' -and $depth -eq 0) { $cut = $k; break }
                                }
                                if ($cut -ge 0) { $first = $inner.Substring(0, $cut) }
                                $first = $first.Trim() -replace '^db\.', ''
                                $meta = @()
                                if ($inner -match 'primary_key\s*=\s*True') { $meta += 'primary_key' }
                                if ($inner -match "ForeignKey\(\s*['`"]([^'`"]+)['`"]\s*\)") { $meta += ("FK: " + $Matches[1]) }
                                $typeStr = $first
                                if ($meta.Count -gt 0) { $typeStr += (" (" + ($meta -join ', ') + ")") }
                                $properties += ("${fname}: $typeStr".Trim())
                            }
                            continue
                        }
                        if ($bText -match '^\s*(\w+)\s*=\s*db\.relationship\s*\((.*)\)\s*$') {
                            $fname = $Matches[1]; $inner = $Matches[2].Trim()
                            if (-not $seenProp.ContainsKey($fname)) {
                                $seenProp[$fname] = $true
                                $ormMapped = $true
                                $target = $inner
                                if ($inner -match "^['`"]([^'`"]+)['`"]") { $target = $Matches[1] } else { $target = (($inner -split ',')[0]).Trim() }
                                $properties += ("${fname}: relationship($target)".Trim())
                            }
                            continue
                        }
                        if ($bText -match '^__tablename__\s*=') { $ormMapped = $true; continue }
                        if ($bText -match '^(\w+)\s*:\s*([\w\[\],\.)]+)') {
                            $fname = $Matches[1]
                            if ($fname -in @('self', 'cls', 'return')) { continue }
                            $ftype = $Matches[2].Trim()
                            if (-not $seenProp.ContainsKey($fname)) {
                                $seenProp[$fname] = $true
                                $properties += ("${fname}: $ftype".Trim())
                            }
                        }
                    }
                    if ($properties.Count -gt 0 -or $ormMapped) {
                        $workingModels += @{
                            type = 'class'
                            name = $clsName
                            file = $file.Name
                            filePath = $relativePath
                            lineNumber = ($i + 1)
                            properties = $properties
                            example = $null
                            sourceType = "regex"
                            ormMapped = $ormMapped
                        }
                    }
                    $i = $j - 1
                }
            }

            if ($file.Extension -eq '.java') {
                $lines = $content -split "`n"
                $relativePath = Get-AppDocDataModelRelativePath -RootPath $RootPath -Path $file.FullName
                for ($i = 0; $i -lt $lines.Count; $i++) {
                    $line = $lines[$i]
                    if ($line -match '^(\s*)(?:public|protected|private|abstract|final|static)\s+(class|interface|enum)\s+(\w+)(?:\s+extends\s.*)?') {
                        $declKind = $Matches[2]
                        $className = $Matches[3]
                        $properties = @()
                        $seenFields = @{}
                        $annotationStack = @()
                        $inClass = $false
                        $depth = 0
                        for ($j = $i; $j -lt [Math]::Min($i + 2000, $lines.Count); $j++) {
                            $cl = $lines[$j]
                            $depth += ($cl.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                            $depth -= ($cl.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                            if ($depth -gt 0) { $inClass = $true }
                            if ($inClass -and $depth -eq 0) { break }
                            if ($inClass -and $depth -eq 1) {
                                $trimmed = $cl.Trim()
                                if ($trimmed -match '^@') {
                                    $annotationStack += $trimmed
                                    continue
                                }
                                if ($trimmed -match '^((?:public|private|protected|static|final|transient|volatile)\s+)+([\w<>[\]]+(?:\s*<[^;]*?>)?(?:\[\s*\])*)\s+(\w+)\s*(=.*)?;') {
                                    $fieldType = $Matches[2].Trim()
                                    $fieldName = $Matches[3]
                                    if (-not $seenFields.ContainsKey($fieldName)) {
                                        $colName = $null
                                        $stack = @($annotationStack)
                                        $annotationStack = @()
                                        foreach ($ann in $stack) {
                                            $colMatch = [regex]::Match($ann, '@Column\s*\(\s*(?:name\s*=\s*)?["'']([^"'']+)["'']')
                                            if ($colMatch.Success) { $colName = $colMatch.Groups[1].Value; break }
                                        }
                                        $displayName = if ($colName) { $colName } else { $fieldName }
                                        $properties += "${displayName}: $fieldType"
                                        $seenFields[$fieldName] = $true
                                    }
                                } else {
                                    $annotationStack = @()
                                }
                            }
                        }
                        $workingModels += @{
                            type = if ($declKind -eq 'interface') { 'interface' } elseif ($declKind -eq 'enum') { 'enum' } else { 'class' }
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
                    $propMappings = [regex]::Matches($content, 'Map\(\w+\s*=>\s*\w+\.(\w+)\)(?:[^;]*?\.CustomType(?:<([\w\.]+)>|\(typeof\(([^")]+)\)\)))?')
                    # Hoist entity class file and content lookup
                    $entityClassFile = Get-AppDocDataModelSourceFiles -RootPath $RootPath -Include @("$entityName.cs") | Select-Object -First 1
                    $classContent = if ($entityClassFile) { Get-Content $entityClassFile.FullName -Raw -ErrorAction SilentlyContinue } else { $null }
                    foreach ($prop in $propMappings) {
                        $propName = $prop.Groups[1].Value
                        $typeHint = $null
                        if ($prop.Groups[2].Success) {
                            $typeHint = $prop.Groups[2].Value
                        } elseif ($prop.Groups[3].Success) {
                            $typeHint = $prop.Groups[3].Value
                        }
                        if (-not $typeHint -and $classContent) {
                            # Fallback: scan for property declaration in entity class source (virtual optional)
                            $declMatch = [regex]::Match($classContent, "public\\s+(?:virtual\\s+)?([\\w<>\[\]?]+)\\s+${propName}\\s*{[^{]*get;[^{]*set;[^{]*}")
                            if ($declMatch.Success) {
                                $typeHint = $declMatch.Groups[1].Value
                            }
                        }
                        if (-not $typeHint) {
                            $typeHint = 'string' # Fallback if no type found
                        }
                        # Document fallback: type is inferred from CustomType, property declaration, or defaults to string
                        $properties += "${propName}: $typeHint"
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
    'Get-AppDocDataModelData',
    'Get-AppDocDataModelAdditionalExcludePatterns'
)
