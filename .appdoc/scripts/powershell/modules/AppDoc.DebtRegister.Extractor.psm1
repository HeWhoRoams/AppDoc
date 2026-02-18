function Get-AppDocDebtRelativePath {
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

    $normalizedRoot = $RootPath.TrimEnd([char[]]@(92, 47)) + [IO.Path]::DirectorySeparatorChar
    if ($Path.StartsWith($normalizedRoot, [StringComparison]::OrdinalIgnoreCase)) {
        return $Path.Substring($normalizedRoot.Length)
    }
    return $Path.Replace($RootPath, "").TrimStart([char[]]@(92, 47))
}

function Get-AppDocDebtSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "debt-register" -Include @("*.js","*.ts","*.cs","*.py","*.java"))
    }

    return @(Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -Include @("*.js","*.ts","*.cs","*.py","*.java") -ErrorAction SilentlyContinue)
}

function Get-AppDocDebtPriority {
    [CmdletBinding()]
    param([string]$DebtType)

    if ($DebtType -in @('FIXME', 'BUG')) { return "High" }
    if ($DebtType -eq 'TODO') { return "Medium" }
    return "Low"
}

function Add-AppDocDebtMarkers {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$RelativePath,
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )

    $results = @()
    $lines = $Content -split "`r?`n"
    $markers = [regex]::Matches($Content, "(?://|#|/\*)\s*(TODO|FIXME|HACK|XXX|DEPRECATED|BUG|REFACTOR)[:;\s]*([^\r\n]{0,150})")
    foreach ($match in $markers) {
        $lineNum = ($Content.Substring(0, $match.Index) -split "`r?`n").Count
        $description = $match.Groups[2].Value.Trim() -replace '\*/', '' -replace '\s+', ' '

        if ([string]::IsNullOrWhiteSpace($description) -or $description.Length -lt 5) {
            $line = $lines[$lineNum - 1]
            if ($line -match "(TODO|FIXME|HACK|XXX|DEPRECATED|BUG|REFACTOR)\s*[:;\-]?\s*(.+)") {
                $description = $Matches[2].Trim()
            }
            if ([string]::IsNullOrWhiteSpace($description) -and $lineNum -lt $lines.Count) {
                $nextLine = $lines[$lineNum].Trim() -replace '^(//|#|/\*|\*)\s*', ''
                if ($nextLine.Length -gt 0) {
                    $description = $nextLine.Substring(0, [Math]::Min(100, $nextLine.Length))
                }
            }
        }

        if ([string]::IsNullOrWhiteSpace($description)) {
            $description = "Review needed - no description provided"
        }

        $debtType = [string]$match.Groups[1].Value
        $results += @{
            type = $debtType
            description = $description
            file = $FileName
            filePath = $RelativePath
            line = $lineNum
            priority = Get-AppDocDebtPriority -DebtType $debtType
        }
    }

    return $results
}

function Add-AppDocCSharpDebtSignals {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$RelativePath,
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )

    $results = @()

    $obsolete = [regex]::Matches($Content, '\[Obsolete(?:\("([^"]+)"\))?\]')
    foreach ($match in $obsolete) {
        $lineNum = ($Content.Substring(0, $match.Index) -split "`n").Count
        $message = if ($match.Groups[1].Success) { $match.Groups[1].Value } else { "No migration path specified" }
        $results += @{
            type = "Obsolete Code"
            description = "Obsolete API: $message"
            file = $FileName
            filePath = $RelativePath
            line = $lineNum
    $magicNumbers = [regex]::Matches($Content, '(?<![.\w])\d{2,}(?!\w)')
        }
    }

    $classMatches = [regex]::Matches($Content, 'class\s+(\w+)')
    foreach ($classMatch in $classMatches) {
        $start = $classMatch.Index
        $afterClass = $Content.Substring($start)
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

        if ($classEnd -le $start) { continue }
        $classContent = $Content.Substring($start, $classEnd - $start)
        $classLines = ($classContent -split "`n").Count
        if ($classLines -le 500) { continue }

        $lineNum = ($Content.Substring(0, $start) -split "`n").Count
        $className = $classMatch.Groups[1].Value
        $results += @{
            type = "Large Class"
            description = "Class '$className' has $classLines lines (>500 line threshold) - consider splitting"
            file = $FileName
            filePath = $RelativePath
            line = $lineNum
            priority = "Medium"
        }
    }

    $magicNumbers = [regex]::Matches($Content, '(?<!\w)[2-9]\d+(?!\w)')
    if ($magicNumbers.Count -gt 10) {
        $results += @{
            type = "Magic Numbers"
            description = "File contains $($magicNumbers.Count) potential magic numbers - consider using named constants"
            file = $FileName
            filePath = $RelativePath
            line = 1
            priority = "Low"
        }
    }

    return $results
}

function Add-AppDocLongFunctionDebtSignals {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [string]$RelativePath,
        [Parameter(Mandatory=$true)]
        [string]$FileName
    )

    $results = @()

    $functionPatterns = @(
        # JS/TS: function declarations
        "function\s+(\w+)\s*\(",
        # JS/TS: const/let/var <name> = (...) => or = function
        "(?:const|let|var)\s+(\w+)\s*=\s*(?:\([^)]*\)\s*=>|function)",
        # C#/TS: method with modifiers (public/private/protected/internal/static/async)
        "\b(?:public|private|protected|internal|static|async)\b\s+\w+\s+(\w+)\s*\(",
        # Python: def <name>(
        "def\s+(\w+)\s*\("
    )

    foreach ($pattern in $functionPatterns) {
        $functions = [regex]::Matches($Content, $pattern)
        foreach ($func in $functions) {
            $start = $func.Index
            $funcName = $func.Groups[1].Value
            $funcEnd = $start

            # Determine file extension for language-specific handling
            $ext = [System.IO.Path]::GetExtension($FileName).ToLowerInvariant()

            if ($ext -eq ".py") {
                # Python: use indentation-based end detection
                $lines = $Content -split "`n"
                $startLine = ($Content.Substring(0, $start) -split "`n").Count
                $defLine = $lines[$startLine - 1]
                $defIndent = ($defLine -match "^(\s*)" | Out-Null; $Matches[1].Length)
                $funcEndLine = $startLine
                for ($i = $startLine; $i -lt $lines.Count; $i++) {
                    $line = $lines[$i]
                    if ($line.Trim() -eq "") { continue }
                    $currIndent = ($line -match "^(\s*)" | Out-Null; $Matches[1].Length)
                    if ($currIndent -le $defIndent -and $line.Trim() -notmatch "^#") {
                        break
                    }
                    $funcEndLine = $i + 1
                }
                $funcLines = $funcEndLine - $startLine + 1
                if ($funcLines -le 50) { continue }
                $results += @{
                    type = "Long Function"
                    description = "Function '$funcName' has $funcLines lines (>50 line threshold)"
                    file = $FileName
                    filePath = $RelativePath
                    line = $startLine
                    priority = "Low"
                }
            } else {
                # Brace-based: JS/TS/C#/Java
                $afterFunc = $Content.Substring($start)
                $braceCount = 0
                $inFunc = $false
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
                if ($funcEnd -le $start) { continue }
                $funcContent = $Content.Substring($start, $funcEnd - $start)
                $funcLines = ($funcContent -split "`n").Count
                if ($funcLines -le 50) { continue }
                $lineNum = ($Content.Substring(0, $start) -split "`n").Count
                $results += @{
                    type = "Long Function"
                    description = "Function '$funcName' has $funcLines lines (>50 line threshold)"
                    file = $FileName
                    filePath = $RelativePath
                    line = $lineNum
                    priority = "Low"
                }
            }
        }
    }

    return $results
}

function Get-AppDocDebtRegisterData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $debts = @()
    $codeFiles = Get-AppDocDebtSourceFiles -RootPath $RootPath | Where-Object { $_.Name -notmatch '\.min\.' }

    foreach ($file in $codeFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $relativePath = Get-AppDocDebtRelativePath -RootPath $RootPath -Path $file.FullName
        $debts += Add-AppDocDebtMarkers -Content $content -RelativePath $relativePath -FileName $file.Name

        if ($file.Extension -eq ".cs") {
            $debts += Add-AppDocCSharpDebtSignals -Content $content -RelativePath $relativePath -FileName $file.Name
        }

        $debts += Add-AppDocLongFunctionDebtSignals -Content $content -RelativePath $relativePath -FileName $file.Name
    }

    $priorityOrder = @{ High = 0; Medium = 1; Low = 2 }
    $dedupedDebts = @(
        $debts |
            Group-Object { "{0}|{1}|{2}|{3}" -f [string]$_.filePath, [string]$_.line, [string]$_.type, [string]$_.description } |
            ForEach-Object { $_.Group | Select-Object -First 1 } |
            Sort-Object `
                @{ Expression = { if ($priorityOrder.ContainsKey([string]$_.priority)) { $priorityOrder[[string]$_.priority] } else { 9 } } }, `
                @{ Expression = { [string]$_.type } }, `
                @{ Expression = { [string]$_.filePath } }, `
                @{ Expression = { [int]$_.line } }
    )

    return [ordered]@{
        debts = $dedupedDebts
        scannedFileCount = $codeFiles.Count
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocDebtRegisterData'
)
