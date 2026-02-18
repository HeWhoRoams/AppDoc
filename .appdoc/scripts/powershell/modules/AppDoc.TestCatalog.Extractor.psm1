function Get-AppDocTestCatalogSourceFiles {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $patterns = @("*.test.js", "*.test.ts", "*.spec.js", "*.spec.ts", "*Test.cs", "*Tests.cs", "test_*.py")
    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "test-catalog" -Include $patterns)
    }

    return @(Get-ChildItem -Path "$RootPath\*" -Recurse -File -Include $patterns -ErrorAction SilentlyContinue)
}

function Get-AppDocTestCatalogRelativePath {
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

function Get-AppDocTestCatalogData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $tests = @()
    $testFiles = @(Get-AppDocTestCatalogSourceFiles -RootPath $RootPath)

    foreach ($file in $testFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $relativePath = Get-AppDocTestCatalogRelativePath -RootPath $RootPath -Path $file.FullName

        $jsPattern = '(it|test|describe)\([' + "'" + '"' + ']([^' + "'" + '"' + ']+)[' + "'" + '"' + ']'
        $jsCases = [regex]::Matches($content, $jsPattern)
        foreach ($match in $jsCases) {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $tests += @{
                type = $match.Groups[1].Value
                name = $match.Groups[2].Value
                file = $file.Name
                framework = "JavaScript"
                source = "${relativePath}:$lineNumber"
            }
        }

        if ($file.Name -match "Tests?\.cs$") {
            $testAttributes = @(
                @{ Pattern = '\[Fact\]'; Framework = 'xUnit' },
                @{ Pattern = '\[Theory\]'; Framework = 'xUnit' },
                @{ Pattern = '\[Test\]'; Framework = 'NUnit' },
                @{ Pattern = '\[TestMethod\]'; Framework = 'MSTest' },
                @{ Pattern = '\[TestCase'; Framework = 'NUnit' }
            )

            foreach ($attr in $testAttributes) {
                $matches = [regex]::Matches($content, $attr.Pattern)
                foreach ($match in $matches) {
                    $afterAttr = $content.Substring($match.Index)
                    if ($afterAttr -match 'public\s+(?:async\s+)?(?:Task<?\w*>?\s+)?(?:void\s+)?(\w+)\s*\(') {
                        $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
                        $tests += @{
                            type = if ($attr.Pattern -match 'Theory|TestCase') { 'parameterized test' } else { 'test' }
                            name = $Matches[1]
                            file = $file.Name
                            framework = "C# ($($attr.Framework))"
                            source = "${relativePath}:$lineNumber"
                        }
                    }
                }
            }
        }

        $pythonCases = [regex]::Matches($content, "def\s+(test_\w+)\(")
        foreach ($match in $pythonCases) {
            $lineNumber = ($content.Substring(0, $match.Index) -split "`n").Count
            $tests += @{
                type = "test"
                name = $match.Groups[1].Value
                file = $file.Name
                framework = "Python"
                source = "${relativePath}:$lineNumber"
            }
        }
    }

    $dedupedTests = @(
        $tests |
            Group-Object { "{0}|{1}|{2}" -f [string]$_.source, [string]$_.name, [string]$_.framework } |
            ForEach-Object { $_.Group | Select-Object -First 1 } |
            Sort-Object @{ Expression = { [string]$_.file } }, @{ Expression = { [string]$_.name } }, @{ Expression = { [string]$_.source } }
    )

    return [ordered]@{
        tests = $dedupedTests
        testFileCount = $testFiles.Count
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocTestCatalogData'
)
