#
# generate-data-model.ps1
#
# Purpose: Scans the target codebase for data models, entities, classes, and interfaces.
#          Populates the data-model template with discovered data structures, properties,
#          types, and relationships.
#
# Usage: .\generate-data-model.ps1 -RootPath <target_codebase_path>
# Output: Populates docs/data-model.md from template
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

Write-Host "🗂️  Generating Data Model..." -ForegroundColor Cyan

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Initialize template
$outputPath = Join-Path $RootPath "docs\data-model.md"
$initialized = Initialize-TemplateFile -TemplateName "data-model-template.md" -OutputPath $outputPath -RootPath $RootPath

if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Data Model" -Status "Scanning for models..." -PercentComplete 0

$models = @()

# Scan for model files
try {
    $modelFiles = Get-ChildItem -Path $RootPath -Recurse -Include "*.ts","*.js","*.cs","*.py" -ErrorAction Stop | 
        Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\__pycache__)' -and 
                       ($_.Name -match "model|entity|schema|type") }

    Write-Host "  Found $($modelFiles.Count) potential model files" -ForegroundColor Gray

    foreach ($file in $modelFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        # TypeScript/JavaScript class/interface parsing with properties
        if ($file.Extension -in @('.ts', '.js')) {
            $tsClasses = [regex]::Matches($content, "(?:export\s+)?(?:class|interface)\s+(\w+)(?:\s+extends\s+\w+)?(?:\s+implements\s+[\w,\s]+)?\s*\{([^}]+)\}")
            foreach ($match in $tsClasses) {
                $className = $match.Groups[1].Value
                $classBody = $match.Groups[2].Value
                
                # Calculate line number from match index
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $relativePath = $file.FullName.Replace($RootPath, "").TrimStart('\', '/')
                
                # Extract properties with types
                $properties = @()
                $propMatches = [regex]::Matches($classBody, "(\w+)\s*[?:]\s*([\w<>\[\]|]+)")
                foreach ($prop in $propMatches) {
                    $propName = $prop.Groups[1].Value
                    $propType = $prop.Groups[2].Value
                    $properties += "${propName}: ${propType}"
                }
                
                # Extract example from JSDoc comments
                $example = $null
                $classContext = $content.Substring([Math]::Max(0, $match.Index - 300), [Math]::Min(600, $content.Length - [Math]::Max(0, $match.Index - 300)))
                if ($classContext -match '@example\s+([\s\S]{1,300}?)(?:\*/|@)') {
                    $example = $Matches[1].Trim()
                }
                
                $models += @{
                    type = if ($match.Value -match 'interface') { 'interface' } else { 'class' }
                    name = $className
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    properties = $properties
                    example = $example
                }
            }
        }
        
        # C# class parsing with properties - improved to handle large classes and nested braces
        if ($file.Extension -eq ".cs") {
            $lines = $content -split "`n"
            $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
            
            for ($i = 0; $i -lt $lines.Count; $i++) {
                $line = $lines[$i]
                
                # Match class/interface/record declarations
                if ($line -match '^\s*(?:public|internal|private|protected)?\s*(class|interface|record)\s+(\w+)(?:<[^>]+>)?') {
                    $modelType = $Matches[1]
                    $className = $Matches[2]
                    $lineNumber = $i + 1
                    
                    # Find properties by scanning forward until we hit another class or EOF
                    $properties = @()
                    $braceCount = 0
                    $inClass = $false
                    
                    for ($j = $i; $j -lt [Math]::Min($i + 2000, $lines.Count); $j++) {
                        $currentLine = $lines[$j]
                        
                        # Track brace depth
                        $braceCount += ($currentLine.ToCharArray() | Where-Object { $_ -eq '{' }).Count
                        $braceCount -= ($currentLine.ToCharArray() | Where-Object { $_ -eq '}' }).Count
                        
                        if ($braceCount -gt 0) { $inClass = $true }
                        if ($inClass -and $braceCount -eq 0) { break }  # End of class
                        
                        # Only extract properties when we're inside the class body
                        if ($inClass -and $braceCount -eq 1) {
                            # Match C# auto-properties: public/protected/internal Type PropertyName { get; set; }
                            if ($currentLine -match '^\s*(public|protected|internal|private)\s+(virtual\s+)?([\w<>\[\]?]+)\s+(\w+)\s*\{\s*get') {
                                $propType = $Matches[3]
                                $propName = $Matches[4]
                                
                                # Extract validation attributes from previous lines
                                $validations = @()
                                if ($j -gt 0 -and $lines[$j-1] -match '\[Required\]') { $validations += 'Required' }
                                if ($j -gt 0 -and $lines[$j-1] -match '\[StringLength\((\d+)') { $validations += "MaxLength:$($Matches[1])" }
                                if ($j -gt 0 -and $lines[$j-1] -match '\[Range\(([^)]+)\)') { $validations += "Range:$($Matches[1])" }
                                if ($j -gt 0 -and $lines[$j-1] -match '\[ForeignKey\(["']([^"']+)["']\)') { $validations += "FK:$($Matches[1])" }
                                
                                $propInfo = "${propName}: ${propType}"
                                if ($validations.Count -gt 0) {
                                    $propInfo += " [" + ($validations -join ', ') + "]"
                                }
                                $properties += $propInfo
                            }
                            # Match C# fields: public/protected/internal Type FieldName;
                            elseif ($currentLine -match '^\s*(public|protected|internal)\s+([\w<>\[\]?]+)\s+(\w+)\s*;') {
                                $propType = $Matches[2]
                                $propName = $Matches[3]
                                $properties += "${propName}: ${propType}"
                            }
                        }
                    }
                    
                    # Extract XML documentation example if present
                    $example = $null
                    if ($i -gt 0) {
                        $docLines = @()
                        for ($k = $i - 1; $k -ge [Math]::Max(0, $i - 20); $k--) {
                            if ($lines[$k] -match '^\s*///') {
                                $docLines = @($lines[$k]) + $docLines
                            } else {
                                break
                            }
                        }
                        $docString = $docLines -join "`n"
                        if ($docString -match '<example>([\s\S]+?)</example>') {
                            $example = $Matches[1].Trim() -replace '<[^>]+>', '' -replace '\s+', ' ' -replace '///', ''
                        }
                    }
                    
                    $models += @{
                        type = $modelType
                        name = $className
                        file = $file.Name
                        filePath = $relativePath
                        lineNumber = $lineNumber
                        properties = $properties
                        example = $example
                    }
                }
            }
        }
        
        # Python class parsing with type hints
        if ($file.Extension -eq '.py') {
            $pyClasses = [regex]::Matches($content, "class\s+(\w+)(?:\([^)]*\))?:\s*([\s\S]+?)(?=\nclass\s|\Z)")
            foreach ($match in $pyClasses) {
                $className = $match.Groups[1].Value
                $classBody = $match.Groups[2].Value
                
                # Calculate line number from match index
                $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                $relativePath = $file.FullName.Replace($RootPath, "").TrimStart('\', '/')
                
                # Extract properties with type hints
                $properties = @()
                $propMatches = [regex]::Matches($classBody, "(\w+)\s*:\s*([\w\[\],\s]+)\s*=?")
                foreach ($prop in $propMatches | Select-Object -First 20) {
                    $propName = $prop.Groups[1].Value
                    $propType = $prop.Groups[2].Value.Trim()
                    if ($propName -notin @('self', 'cls', 'return')) {
                        $properties += "${propName}: ${propType}"
                    }
                }
                
                # Extract example from Python docstring
                $example = $null
                if ($classBody -match '"""[\s\S]*?Example:[\s\S]*?([\s\S]{1,300}?)(?:"""|\n\n)') {
                    $example = $Matches[1].Trim()
                }
                
                $models += @{
                    type = 'class'
                    name = $className
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = $lineNumber
                    properties = $properties
                    example = $example
                }
            }
        }
    }
    
    # Scan NHibernate/FluentNHibernate mapping files
    Write-Progress -Activity "Generating Data Model" -Status "Scanning NHibernate mappings..." -PercentComplete 30
    
    # Look for .hbm.xml files (classical NHibernate)
    $hbmFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*.hbm.xml" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '(\\bin\\|\\obj\\|\\packages\\)' }
    
    foreach ($file in $hbmFiles) {
        try {
            [xml]$xmlContent = Get-Content $file.FullName -Raw -ErrorAction Stop
            $ns = @{hbm='urn:nhibernate-mapping-2.2'}
            
            $classes = Select-Xml -Xml $xmlContent -XPath "//hbm:class" -Namespace $ns
            foreach ($class in $classes) {
                $className = $class.Node.name
                $tableName = $class.Node.table
                $relativePath = $file.FullName.Replace($RootPath, "").TrimStart('\\', '/')
                
                # Extract properties
                $properties = @()
                $propNodes = Select-Xml -Xml $class.Node -XPath ".//hbm:property" -Namespace $ns
                foreach ($prop in $propNodes) {
                    $propName = $prop.Node.name
                    $propType = $prop.Node.type
                    if (-not $propType) { $propType = 'string' }
                    $properties += "${propName}: ${propType}"
                }
                
                # Extract many-to-one relationships
                $manyToOneNodes = Select-Xml -Xml $class.Node -XPath ".//hbm:many-to-one" -Namespace $ns
                foreach ($rel in $manyToOneNodes) {
                    $relName = $rel.Node.name
                    $relClass = $rel.Node.class
                    $properties += "${relName}: ${relClass} [FK]"
                }
                
                $models += @{
                    type = 'entity'
                    name = $className
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = 1
                    properties = $properties
                    example = "Table: $tableName"
                }
            }
        } catch {
            Write-Warning "Failed to parse NHibernate mapping $($file.Name): $_"
        }
    }
    
    # Look for FluentNHibernate mapping files (*Map.cs)
    $mapFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*Map.cs" -ErrorAction SilentlyContinue |
        Where-Object { $_.FullName -notmatch '(\\bin\\|\\obj\\|\\packages\\|\\node_modules\\)' }
    
    foreach ($file in $mapFiles) {
        try {
            $content = Get-Content $file.FullName -Raw -ErrorAction Stop
            $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
            
            # Match FluentNHibernate mapping: ClassMap<EntityName> or EntityMap<EntityName>
            if ($content -match 'class\s+(\w*Map)\s*:\s*(?:ClassMap|EntityMap)<(\w+)>') {
                $mapClass = $Matches[1]
                $entityName = $Matches[2]
                
                # Find the constructor or mapping method
                $mappingContext = $content
                
                # Extract property mappings: Map(x => x.PropertyName)
                $properties = @()
                $propMappings = [regex]::Matches($mappingContext, 'Map\(\w+\s*=>\s*\w+\.(\w+)\)')
                foreach ($prop in $propMappings) {
                    $propName = $prop.Groups[1].Value
                    $properties += "${propName}: string"
                }
                
                # Extract reference mappings: References(x => x.RelatedEntity)
                $refMappings = [regex]::Matches($mappingContext, 'References\(\w+\s*=>\s*\w+\.(\w+)\)')
                foreach ($ref in $refMappings) {
                    $refName = $ref.Groups[1].Value
                    $properties += "${refName}: Reference [FK]"
                }
                
                # Extract collection mappings: HasMany(x => x.Collection)
                $collMappings = [regex]::Matches($mappingContext, 'HasMany\(\w+\s*=>\s*\w+\.(\w+)\)')
                foreach ($coll in $collMappings) {
                    $collName = $coll.Groups[1].Value
                    $properties += "${collName}: Collection [1:N]"
                }
                
                # Extract table name: Table("TableName")
                $tableName = $null
                if ($mappingContext -match 'Table\(["\']([^"\' ]+)["\']\)') {
                    $tableName = $Matches[1]
                }
                
                $models += @{
                    type = 'entity'
                    name = $entityName
                    file = $file.Name
                    filePath = $relativePath
                    lineNumber = 1
                    properties = $properties
                    example = if ($tableName) { "Table: $tableName (FluentNHibernate)" } else { "FluentNHibernate entity" }
                }
            }
        } catch {
            Write-Warning "Failed to parse FluentNHibernate mapping $($file.Name): $_"
        }
    }
    
} catch {
    Write-Warning "Error scanning model files: $_"
}

Write-Progress -Activity "Generating Data Model" -Status "Creating model..." -PercentComplete 50

# Remove duplicates (same class name in same file at same line)
$uniqueModels = @()
$seen = @{}
foreach ($model in $models) {
    $key = "$($model.file):$($model.name):$($model.lineNumber)"
    if (-not $seen.ContainsKey($key)) {
        $uniqueModels += $model
        $seen[$key] = $true
    }
}
$models = $uniqueModels

# Add diagnostic information
if ($models.Count -eq 0) {
    Write-Host "⚠️  No data models detected!" -ForegroundColor Yellow
    Write-Host "   Searched in: $RootPath" -ForegroundColor Gray
    Write-Host "   File extensions: *.ts, *.js, *.cs, *.py" -ForegroundColor Gray
    Write-Host "   Patterns: TypeScript (interface/class), C# (class/record), Python (class)" -ForegroundColor Gray
}

Write-Progress -Activity "Generating Data Model" -Status "Populating template..." -PercentComplete 80

# Build model table + placeholder
$modelTablePlaceholder = @"
| Model Name | Fields | Types | Description | Constraints | Indexes |
|------------|--------|-------|-------------|-------------|---------|

_No data models detected. This codebase may use dynamic structures or patterns not yet recognized by the scanner._
"@

# Build model table content
if ($models.Count -gt 0) {
    $modelRows = @()
    foreach ($model in $models) {
        $fieldsCount = $model.properties.Count
        $typesSummary = if ($fieldsCount -gt 0) {
            ($model.properties[0..([Math]::Min(2, $fieldsCount - 1))] | ForEach-Object { 
                if ($_ -match ':') { $_.Split(':')[1].Trim() } else { 'unknown' }
            }) -join ', '
            if ($fieldsCount -gt 3) { $typesSummary += "..." }
        } else {
            'N/A'
        }
        
        $description = "$($model.type) from $($model.filePath):$($model.lineNumber)"
        $constraints = if ($model.example) { "See example" } else { "N/A" }
        $indexes = "N/A"
        
        $modelRows += "| ``$($model.name)`` | $fieldsCount | $typesSummary | $description | $constraints | $indexes |"
    }
    
    $modelContent = @"
| Model Name | Fields | Types | Description | Constraints | Indexes |
|------------|--------|-------|-------------|-------------|---------|
$($modelRows -join "`n")

**Statistics:**
- Total Models: $($models.Count)
- Total Properties: $(($models | ForEach-Object { $_.properties.Count } | Measure-Object -Sum).Sum)
- Average Properties per Model: $([Math]::Round($(($models | ForEach-Object { $_.properties.Count } | Measure-Object -Average).Average), 1))

**Type Distribution:**
$( ($models | Group-Object type | ForEach-Object { "- $($_.Name): $($_.Count)" }) -join "`n" )
"@
} else {
    $modelContent = $modelTablePlaceholder
}

# Update template sections
$content = Get-Content -Path $outputPath -Raw
$content = Update-TemplateSection -Content $content -PlaceholderText $modelTablePlaceholder -NewContent $modelContent
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Progress -Activity "Generating Data Model" -Status "Complete" -PercentComplete 100
Write-Host "✅ Data model generated: $outputPath" -ForegroundColor Green
Write-Host "   Models found: $($models.Count)" -ForegroundColor Gray
