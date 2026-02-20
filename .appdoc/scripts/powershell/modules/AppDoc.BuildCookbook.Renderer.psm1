function Escape-Markdown {
    param(
        [Parameter(Mandatory)]
        [string]$Text
    )
    # Escape backticks (for code), and Markdown special chars: *, _, `, ~, |
    $escaped = $Text -replace '`', '&#96;'
    $escaped = $escaped -replace '\*', '\*'
    $escaped = $escaped -replace '_', '\_'
    $escaped = $escaped -replace '~', '\~'
    $escaped = $escaped -replace '\|', '&#124;'
    return $escaped
}
function Get-AppDocBuildStepsMarkdown {
    [CmdletBinding()]
    param(
        [array]$Commands
    )

    $buildTablePlaceholder = @"
| Step | Command | Description | Estimated Time |
|------|---------|-------------|----------------|

_No build steps detected. Check for package.json scripts, Makefile, or build configuration files._
"@

    if (-not $Commands -or $Commands.Count -eq 0) {
        return $buildTablePlaceholder
    }

    $tableHeader = "| Step | Command | Description | Estimated Time |`r`n|------|---------|-------------|----------------|"
    $rows = @()
    $index = 1
    foreach ($command in $Commands) {
        $desc = if ($command.command -and $command.command -ne "No description") { [string]$command.command } else { "{0} command" -f [string]$command.type }
        $invocationEscaped = Escape-Markdown -Text ([string]$command.invocation)
        $descEscaped = Escape-Markdown -Text $desc
        $rows += "| $index | ``$invocationEscaped`` | $descEscaped | N/A |"
        $index++
    }

    return ($tableHeader + "`r`n" + ($rows -join "`r`n"))
}

function Get-AppDocBuildCookbookMarkdown {
    [CmdletBinding()]
    param(
        [array]$Commands
    )

    return [ordered]@{
        buildStepsContent = (Get-AppDocBuildStepsMarkdown -Commands $Commands)
    }
}

function Update-AppDocBuildCookbookContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [array]$Commands,
        [array]$Prerequisites,
        [array]$CicdInfo
    )

    $updated = $Content
    $buildStepsContent = Get-AppDocBuildStepsMarkdown -Commands $Commands

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Overview\s*\r?\n(?:\r?\n)?).*?(?=\r?\n##\s+Prerequisites\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "This cookbook is assembled from detected build commands and CI hints so teams can reproduce, troubleshoot, and standardize build execution." + "`r`n")
        }
    )

    # Prerequisites section
    $prereqContent = $null
    if ($Prerequisites -and $Prerequisites.Count -gt 0) {
        $prereqContent = ($Prerequisites | ForEach-Object { "- $_" }) -join "`r`n"
    } else {
        $prereqContent = "Use a Windows development environment with dotnet, msbuild, and nuget available on PATH. Align SDK/toolchain versions with solution and CI expectations before running full builds."
    }
    if ($prereqContent -and $prereqContent -notmatch 'No deterministic evidence found' -and $prereqContent -notmatch 'No evidence found for this section') {
        $updated = [regex]::Replace(
            $updated,
            '(?s)(##\s+Prerequisites\s*\r?\n(?:\r?\n)?).*?(?=\r?\n##\s+Build Steps\b)',
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Groups[1].Value + $prereqContent + "`r`n")
            }
        )
    } else {
        $updated = $updated -replace '(?s)##\s+Prerequisites\s*\r?\n(?:\r?\n)?.*?(?=\r?\n##\s+Build Steps\b)', ''
    }

    # CI/CD section
    $cicdContent = $null
    if ($CicdInfo -and $CicdInfo.Count -gt 0) {
        $cicdContent = "**Detected CI/CD Platforms:**`r`n`r`n"
        foreach ($ci in $CicdInfo) {
            $pathEscaped = Escape-Markdown -Text ([string]$ci.path)
            $detailsEscaped = Escape-Markdown -Text ([string]$ci.details)
            $platformEscaped = Escape-Markdown -Text ([string]$ci.platform)
            $cicdContent += "- **$platformEscaped**: ``$pathEscaped`` - $detailsEscaped`r`n"
        }
    } else {
        $cicdContent = "No CI/CD manifest was detected in this scan. If builds are automated externally, document that pipeline entrypoint before release changes."
    }
    if ($cicdContent -and $cicdContent -notmatch 'No deterministic evidence found' -and $cicdContent -notmatch 'No evidence found for this section') {
        $updated = [regex]::Replace(
            $updated,
            '(?s)(##\s+CI/CD Integration\s*\r?\n\r?\n).*?(?=\r?\n##\s+Troubleshooting\b)',
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Groups[1].Value + $cicdContent + "`r`n")
            }
        )
    } else {
        $updated = $updated -replace '(?s)##\s+CI/CD Integration\s*\r?\n\r?\n.*?(?=\r?\n##\s+Troubleshooting\b)', ''
    }

    # Build Steps section
    $buildStepsContent = Get-AppDocBuildStepsMarkdown -Commands $Commands
    if ($buildStepsContent -and $buildStepsContent -notmatch 'No build steps detected') {
        $buildSectionPattern = '(?s)(##\s+Build Steps\s*\r?\n\r?\n).*?(?=\r?\n##\s+Dependencies\b)'
        $updated = [regex]::Replace(
            $updated,
            $buildSectionPattern,
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Groups[1].Value + $buildStepsContent + "`r`n")
            }
        )
    } else {
        $manualBuildSteps = "_Add step-by-step build instructions or reference build scripts here. Remove this section if not needed._"
        $updated = [regex]::Replace(
            $updated,
            '(?s)(##\s+Build Steps\s*\r?\n(?:\r?\n)?).*?(?=\r?\n##\s+Dependencies\b)',
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Groups[1].Value + $manualBuildSteps + "`r`n")
            }
        )
    }

    $dependenciesContent = @"
| Dependency | Version | Purpose | Installation |
|------------|---------|---------|--------------|
| dotnet CLI | Environment-dependent | Build, restore, test, and publish commands | Install the SDK version required by the solution |
| MSBuild | Environment-dependent | Legacy solution build/rebuild workflows | Install via Visual Studio Build Tools or Visual Studio |
| NuGet CLI | Environment-dependent | Package restore for legacy flows | Install NuGet CLI and ensure PATH availability |
"@
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Dependencies\s*\r?\n(?:\r?\n)?).*?(?=\r?\n##\s+CI/CD Integration\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $dependenciesContent + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Troubleshooting\s*\r?\n(?:\r?\n)?).*?(?=\r?\n##\s+Example Build Scripts\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Start with restore (dotnet restore or nuget restore) and then run the narrowest failing build command from this artifact. If failures persist, compare local toolchain versions with CI and check dependency/version drift in [Dependencies Catalog](dependencies-catalog.md)." + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Example Build Scripts\s*\r?\n(?:\r?\n)?).*?(?=(\r?\n##\s+)|\z)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "A curated script was not extracted in this run. For repeatable local execution, chain restore -> build -> test commands from the Build Steps table into a repo-specific helper script." + "`r`n")
        }
    )

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocBuildStepsMarkdown',
    'Get-AppDocBuildCookbookMarkdown',
    'Update-AppDocBuildCookbookContent'
)
