function Get-AppDocDependenciesCatalogMarkdown {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Dependencies,
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Projects
    )

    $summaryTablePlaceholder = @"
| Package Manager | Total Dependencies | Direct | Transitive |
|-----------------|-------------------|--------|------------|

_No dependencies detected. System may be self-contained or use alternative dependency management._
"@

    $nugetPlaceholder = "_No NuGet packages detected._"
    $projectRefsPlaceholder = "_No project references detected._"
    $versionConflictsPlaceholder = "_No version conflicts detected._"

    $nugetCount = (@($Dependencies | Where-Object { $_.type -eq 'NuGet Package' })).Count
    $projectRefCount = (@($Dependencies | Where-Object { $_.type -eq 'Project Reference' })).Count
    $assemblyRefCount = (@($Dependencies | Where-Object { $_.type -in @('GAC Assembly', 'Assembly Reference') })).Count

    $summaryContent = if ($Dependencies.Count -gt 0) {
@"
| Package Manager | Total Dependencies | Direct | Transitive |
|-----------------|-------------------|--------|------------|
| NuGet | $nugetCount | $nugetCount | 0 |
| Project References | $projectRefCount | $projectRefCount | 0 |
| Assembly References | $assemblyRefCount | $assemblyRefCount | 0 |

**Projects**: $($Projects.Count)
"@
    } else {
        $summaryTablePlaceholder
    }

    $nugetPackages = @($Dependencies | Where-Object { $_.type -eq 'NuGet Package' })
    $nugetContent = if ($nugetPackages.Count -gt 0) {
        $rows = $nugetPackages | Group-Object -Property name | Sort-Object Name | ForEach-Object {
            $versions = ($_.Group.version | Sort-Object -Unique) -join ', '
            $uniqueProjects = @($_.Group.project | Sort-Object -Unique)
            $projCount = $uniqueProjects.Count
            $usedBy = ($uniqueProjects | Select-Object -First 3) -join ', '
            if ($projCount -gt 3) {
                $usedBy += " +$($projCount - 3) more"
            }
            "| ``$($_.Name)`` | $versions | $usedBy | NuGet package |"
        }
@"
| Package | Version | Used By | Purpose |
|---------|---------|---------|---------|
$($rows -join "`n")

**Total NuGet Packages**: $(($nugetPackages | Group-Object name).Count)
"@
    } else {
        $nugetPlaceholder
    }

    $projectRefs = @($Dependencies | Where-Object { $_.type -eq 'Project Reference' })
    $projectRefsContent = if ($projectRefs.Count -gt 0) {
        $rows = $projectRefs | Group-Object -Property name | Sort-Object Name | ForEach-Object {
            $usedBy = ($_.Group.project | Sort-Object -Unique) -join ', '
            "- **``$($_.Name)``** referenced by: $usedBy"
        }
@"
Internal project dependencies:

$($rows -join "`n")

**Total Project References**: $(($projectRefs | Group-Object name).Count)
"@
    } else {
        $projectRefsPlaceholder
    }

    $versionConflicts = @(
        $Dependencies | Where-Object { $_.type -eq 'NuGet Package' } | Group-Object -Property name |
            Where-Object { ($_.Group.version | Sort-Object -Unique).Count -gt 1 }
    )
    $versionConflictsContent = if ($versionConflicts.Count -gt 0) {
        $conflicts = $versionConflicts | ForEach-Object {
            $versions = $_.Group | ForEach-Object { "  - **$($_.project)**: $($_.version)" }
            "- **``$($_.Name)``**:`n$($versions -join "`n")"
        }
@"
⚠️ **$($versionConflicts.Count) package(s) with version conflicts detected:**

$($conflicts -join "`n`n")
"@
    } else {
        $versionConflictsPlaceholder
    }

    return [ordered]@{
        summaryContent = $summaryContent
        nugetContent = $nugetContent
        projectRefsContent = $projectRefsContent
        versionConflictsContent = $versionConflictsContent
        summaryTablePlaceholder = $summaryTablePlaceholder
        nugetPlaceholder = $nugetPlaceholder
        projectRefsPlaceholder = $projectRefsPlaceholder
        versionConflictsPlaceholder = $versionConflictsPlaceholder
    }
}

function Update-AppDocDependenciesCatalogContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Content,
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Dependencies,
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$Projects
    )

    $sections = Get-AppDocDependenciesCatalogMarkdown -Dependencies $Dependencies -Projects $Projects
    $updated = $Content
    if (Get-Command Update-TemplateSection -ErrorAction SilentlyContinue) {
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.summaryTablePlaceholder -NewContent $sections.summaryContent
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.nugetPlaceholder -NewContent $sections.nugetContent
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.projectRefsPlaceholder -NewContent $sections.projectRefsContent
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.versionConflictsPlaceholder -NewContent $sections.versionConflictsContent
    } else {
        $updated = $updated.Replace($sections.summaryTablePlaceholder, $sections.summaryContent)
        $updated = $updated.Replace($sections.nugetPlaceholder, $sections.nugetContent)
        $updated = $updated.Replace($sections.projectRefsPlaceholder, $sections.projectRefsContent)
        $updated = $updated.Replace($sections.versionConflictsPlaceholder, $sections.versionConflictsContent)

        # Regex replacements only if Update-TemplateSection is not available
        $patterns = @(
            @{ Pattern = '(?s)(##\s+Dependency Summary\s*\r?\n\r?\n)(.*?)(\r?\n)(?=##\s+Dependencies by Type\b)'; Header = '##\s+Dependency Summary' ; Content = $sections.summaryContent },
            @{ Pattern = '(?s)(###\s+NuGet Packages\s*\r?\n\r?\n)(.*?)(\r?\n)(?=###\s+NPM Packages\b)'; Header = '###\s+NuGet Packages' ; Content = $sections.nugetContent },
            @{ Pattern = '(?s)(##\s+Project References\s*\r?\n\r?\n)(.*?)(\r?\n)(?=##\s+Version Conflicts\b)'; Header = '##\s+Project References' ; Content = $sections.projectRefsContent },
            @{ Pattern = '(?s)(##\s+Version Conflicts\s*\r?\n\r?\n)(.*?)(\r?\n)(?=##\s+Security Considerations\b)'; Header = '##\s+Version Conflicts' ; Content = $sections.versionConflictsContent }
        )
        foreach ($pat in $patterns) {
            if ([regex]::IsMatch($updated, $pat.Header)) {
                $updated = [regex]::Replace(
                    $updated,
                    $pat.Pattern,
                    [System.Text.RegularExpressions.MatchEvaluator]{
                        param($m)
                        # $m.Groups[1] = section header, $m.Groups[3] = original trailing newline
                        return ($m.Groups[1].Value + $pat.Content + $m.Groups[3].Value)
                    }
                )
            } else {
                Write-Warning ("Section header not found for pattern: {0}" -f $pat.Header)
            }
        }
    }

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocDependenciesCatalogMarkdown',
    'Update-AppDocDependenciesCatalogContent'
)
