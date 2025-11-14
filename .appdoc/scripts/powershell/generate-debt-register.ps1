#
# generate-debt-register.ps1
#
# Purpose: Scans the target codebase for technical debt indicators and populates the
#          tech-debt-register template with discovered debt items and priorities.
#
# Usage: .\generate-debt-register.ps1 -RootPath <target_codebase_path>
# Output: Populates docs/debt-register.md from template
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

Write-Host "📋 Generating Technical Debt Register..." -ForegroundColor Cyan

# Validate root path
if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

# Initialize template
$outputPath = Join-Path $RootPath "docs\debt-register.md"
$initialized = Initialize-TemplateFile -TemplateName "tech-debt-register-template.md" -OutputPath $outputPath -RootPath $RootPath

if (-not $initialized) {
    Write-Error "Failed to initialize template"
    exit 1
}

Write-Progress -Activity "Generating Technical Debt Register" -Status "Scanning code..." -PercentComplete 0

$debts = @()

# Scan for code files
try {
    $codeFiles = Get-ChildItem -Path $RootPath -Recurse -Include "*.js","*.ts","*.cs","*.py","*.java" -ErrorAction Stop |
        Where-Object { $_.FullName -notmatch '(\\node_modules\\|\\bin\\|\\obj\\|\\__pycache__|\\dist\\)' }

    Write-Host "  Scanning $($codeFiles.Count) code files..." -ForegroundColor Gray

    foreach ($file in $codeFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }
        
        $lines = $content -split "`n"
        
        # Find TODO/FIXME/HACK markers with surrounding context
        # Match the marker and capture the rest of the line for context
        $markers = [regex]::Matches($content, "(?://|#|/\*)\s*(TODO|FIXME|HACK|XXX|DEPRECATED|BUG|REFACTOR)[:;\s]*([^\r\n]{0,150})")
        foreach ($match in $markers) {
            $lineNum = ($content.Substring(0, $match.Index) -split "`n").Count
            $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
            
            # Extract the description, removing extra whitespace and comment markers
            $description = $match.Groups[2].Value.Trim() -replace '\*/', '' -replace '\s+', ' '
            
            # If no description, try to get the full line for context
            if ([string]::IsNullOrWhiteSpace($description) -or $description.Length -lt 5) {
                $line = $lines[$lineNum - 1]
                # Extract everything after the marker on the same line
                if ($line -match "(TODO|FIXME|HACK|XXX|DEPRECATED|BUG|REFACTOR)\s*[:;\-]?\s*(.+)") {
                    $description = $Matches[2].Trim()
                }
                # If still empty, use the next line as context
                if ([string]::IsNullOrWhiteSpace($description) -and $lineNum -lt $lines.Count) {
                    $nextLine = $lines[$lineNum].Trim() -replace '^(//|#|/\*|\*)\s*', ''
                    if ($nextLine.Length -gt 0) {
                        $description = $nextLine.Substring(0, [Math]::Min(100, $nextLine.Length))
                    }
                }
            }
            
            # Fall back to generic description if still empty
            if ([string]::IsNullOrWhiteSpace($description)) {
                $description = "Review needed - no description provided"
            }
            
            $debts += @{
                type = $match.Groups[1].Value
                description = $description
                file = $file.Name
                filePath = $relativePath
                line = $lineNum
                priority = if ($match.Groups[1].Value -in @('FIXME','BUG')) { "High" } elseif ($match.Groups[1].Value -eq 'TODO') { "Medium" } else { "Low" }
            }
        }
        
        # C#-specific: Find [Obsolete] attributes
        if ($file.Extension -eq ".cs") {
            $obsolete = [regex]::Matches($content, '\[Obsolete(?:\("([^"]+)"\))?\]')
            foreach ($match in $obsolete) {
                $lineNum = ($content.Substring(0, $match.Index) -split "`n").Count
                $message = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { "No migration path specified" }
                $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
                $debts += @{
                    type = "Obsolete Code"
                    description = "Obsolete API: $message"
                    file = $file.Name
                    filePath = $relativePath
                    line = $lineNum
                    priority = "Medium"
                }
            }
            
            # Detect large classes (>500 lines)
            $classMatches = [regex]::Matches($content, 'class\s+(\w+)')
            foreach ($classMatch in $classMatches) {
                $start = $classMatch.Index
                $afterClass = $content.Substring($start)
                
                # Simple brace counting to find class end
                $braceCount = 0
                $inClass = $false
                $classEnd = $start
                
                for ($i = 0; $i -lt $afterClass.Length; $i++) {
                    if ($afterClass[$i] -eq '{') {
                        $braceCount++
                        $inClass = $true
                    }
                    elseif ($afterClass[$i] -eq '}') {
                        $braceCount--
                        if ($inClass -and $braceCount -eq 0) {
                            $classEnd = $start + $i
                            break
                        }
                    }
                }
                
                if ($classEnd -gt $start) {
                    $classContent = $content.Substring($start, $classEnd - $start)
                    $classLines = ($classContent -split "`n").Count
                    if ($classLines -gt 500) {
                        $lineNum = ($content.Substring(0, $start) -split "`n").Count
                        $className = $classMatch.Groups[1].Value
                        $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
                        $debts += @{
                            type = "Large Class"
                            description = "Class '$className' has $classLines lines (>500 line threshold) - consider splitting"
                            file = $file.Name
                            filePath = $relativePath
                            line = $lineNum
                            priority = "Medium"
                        }
                    }
                }
            }
            
            # Detect magic numbers (numbers not 0, 1, -1 in code)
            $magicNumbers = [regex]::Matches($content, '(?<!\w)[2-9]\d+(?!\w)')
            if ($magicNumbers.Count -gt 10) {  # Only report if there are many
                $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
                $debts += @{
                    type = "Magic Numbers"
                    description = "File contains $($magicNumbers.Count) potential magic numbers - consider using named constants"
                    file = $file.Name
                    filePath = $relativePath
                    line = 1
                    priority = "Low"
                }
            }
        }
        
        # Detect long functions (>50 lines heuristic)
        $functionPatterns = @(
            "function\s+(\w+)\s*\(",
            "const\s+(\w+)\s*=\s*\(",
            "def\s+(\w+)\s*\(",
            "public\s+\w+\s+(\w+)\s*\("
        )
        
        foreach ($pattern in $functionPatterns) {
            $functions = [regex]::Matches($content, $pattern)
            foreach ($func in $functions) {
                $start = $func.Index
                # Find the closing brace (simplified heuristic)
                $afterFunc = $content.Substring($start)
                $braceCount = 0
                $inFunc = $false
                $funcEnd = $start
                
                for ($i = 0; $i -lt $afterFunc.Length; $i++) {
                    if ($afterFunc[$i] -eq '{') {
                        $braceCount++
                        $inFunc = $true
                    }
                    elseif ($afterFunc[$i] -eq '}') {
                        $braceCount--
                        if ($inFunc -and $braceCount -eq 0) {
                            $funcEnd = $start + $i
                            break
                        }
                    }
                }
                
                if ($funcEnd -gt $start) {
                    $funcContent = $content.Substring($start, $funcEnd - $start)
                    $funcLines = ($funcContent -split "`n").Count
                    if ($funcLines -gt 50) {
                        $lineNum = ($content.Substring(0, $start) -split "`n").Count
                        $funcName = $func.Groups[1].Value
                        $relativePath = $file.FullName.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
                        $debts += @{
                            type = "Long Function"
                            description = "Function '$funcName' has $funcLines lines (>50 line threshold)"
                            file = $file.Name
                            filePath = $relativePath
                            line = $lineNum
                            priority = "Low"
                        }
                    }
                }
            }
        }
    }
} catch {
    Write-Warning "Error scanning code files: $_"
}

Write-Progress -Activity "Generating Technical Debt Register" -Status "Populating template..." -PercentComplete 50

# Build debt items table
$debtTablePlaceholder = @"
| Item | Location | Category | Impact | Priority | Effort | Description |
|------|----------|----------|--------|----------|--------|-------------|

_No technical debt items detected. Great job maintaining code quality! Continue monitoring for TODO/FIXME comments._
"@

$debtItemsContent = if ($debts.Count -gt 0) {
    $tableHeader = "| Item | Location | Category | Impact | Priority | Effort | Description |`n|------|----------|----------|--------|----------|--------|-------------|"  
    $tableRows = $debts | ForEach-Object {
        $location = if ($_.filePath) { "$($_.filePath):$($_.line)" } else { "$($_.file):$($_.line)" }
        $item = "$($_.type)"
        $category = "Code Quality"
        $impact = if ($_.priority -eq "High") { "High" } else { "Medium" }
        $effort = "TBD"
        "| $item | ``$location`` | $category | $impact | $($_.priority) | $effort | $($_.description) |"
    }
    $tableHeader + "`n" + ($tableRows -join "`n")
} else {
    $debtTablePlaceholder
}

# Update template
$content = Get-Content -Path $outputPath -Raw
$content = Update-TemplateSection -Content $content -PlaceholderText $debtTablePlaceholder -NewContent $debtItemsContent
$content = Add-GenerationMetadata -Content $content
$content | Out-File -FilePath $outputPath -Encoding UTF8 -NoNewline

Write-Progress -Activity "Generating Technical Debt Register" -Status "Complete" -PercentComplete 100
Write-Host "✅ Technical debt register generated: $outputPath" -ForegroundColor Green
Write-Host "   Debt items found: $($debts.Count)" -ForegroundColor Gray
