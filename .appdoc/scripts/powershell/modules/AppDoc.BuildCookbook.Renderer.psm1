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

    # Prerequisites section
    $prereqContent = $null
    if ($Prerequisites -and $Prerequisites.Count -gt 0) {
        $prereqContent = ($Prerequisites | ForEach-Object { "- $_" }) -join "`r`n"
    } else {
        $prereqContent = "_Add any required tools, packages, or environment setup steps here. Remove this section if not needed._"
    }
    if ($prereqContent -and $prereqContent -notmatch 'No deterministic evidence found') {
        $updated = [regex]::Replace(
            $updated,
            '(?s)(##\s+Prerequisites\s*\r?\n\r?\n).*?(?=\r?\n##\s+Build Steps\b)',
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Groups[1].Value + $prereqContent + "`r`n")
            }
        )
    } else {
        $updated = $updated -replace '(?s)##\s+Prerequisites\s*\r?\n\r?\n.*?(?=\r?\n##\s+Build Steps\b)', ''
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
        $cicdContent = "_Add CI/CD configuration details or workflow file references here. Remove this section if not needed._"
    }
    if ($cicdContent -and $cicdContent -notmatch 'No deterministic evidence found') {
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
            '(?s)(##\s+Build Steps\s*\r?\n\r?\n).*?(?=\r?\n##\s+Dependencies\b)',
            [System.Text.RegularExpressions.MatchEvaluator]{
                param($m)
                return ($m.Groups[1].Value + $manualBuildSteps + "`r`n")
            }
        )
    }

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocBuildStepsMarkdown',
    'Get-AppDocBuildCookbookMarkdown',
    'Update-AppDocBuildCookbookContent'
)
