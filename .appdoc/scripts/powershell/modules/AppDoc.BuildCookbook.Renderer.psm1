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
        $rows += "| $index | ``$([string]$command.invocation)`` | $desc | N/A |"
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

    $prereqContent = if ($Prerequisites -and $Prerequisites.Count -gt 0) {
        ($Prerequisites | ForEach-Object { "- $_" }) -join "`r`n"
    } else {
        "No deterministic evidence found in this section for the current scan."
    }
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Prerequisites\s*\r?\n\r?\n).*?(?=\r?\n##\s+Build Steps\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $prereqContent + "`r`n")
        }
    )

    $cicdContent = "No deterministic evidence found in this section for the current scan."
    if ($CicdInfo -and $CicdInfo.Count -gt 0) {
        $cicdContent = "**Detected CI/CD Platforms:**`r`n`r`n"
        foreach ($ci in $CicdInfo) {
            $cicdContent += "- **$([string]$ci.platform)**: ``$([string]$ci.path)`` - $([string]$ci.details)`r`n"
        }
    }
    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+CI/CD Integration\s*\r?\n\r?\n).*?(?=\r?\n##\s+Troubleshooting\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $cicdContent + "`r`n")
        }
    )

    $buildSectionPattern = '(?s)(##\s+Build Steps\s*\r?\n\r?\n).*?(?=##\s+Dependencies\b)'
    $updated = [regex]::Replace(
        $updated,
        $buildSectionPattern,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + $buildStepsContent + "`r`n")
        }
    )

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocBuildStepsMarkdown',
    'Get-AppDocBuildCookbookMarkdown',
    'Update-AppDocBuildCookbookContent'
)
