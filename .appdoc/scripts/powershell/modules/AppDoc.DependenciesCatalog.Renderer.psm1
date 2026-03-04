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

Dependency records in scope: none in this scan. The repository may be self-contained or use unmanaged dependency sources.
"@

    $nugetPlaceholder = @"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
| N/A | N/A | N/A | NuGet package entries in scope: none in this scan. | N/A |
"@
    $npmPlaceholder = @"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
| N/A | N/A | N/A | NPM package manifests in scope: none in this scan. | N/A |
"@
    $pythonPlaceholder = @"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
| N/A | N/A | N/A | Python package manifests in scope: none in this scan. | N/A |
"@
    $mavenPlaceholder = @"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
| N/A | N/A | N/A | Java build manifests in scope: none in this scan. | N/A |
"@
    $projectRefsPlaceholder = "Project-reference edges in scope: none in this scan."
    $versionConflictsPlaceholder = "Version divergence signals in scope: none in this scan."

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
    $npmPackages = @($Dependencies | Where-Object { [string]$_.type -match '(?i)npm' })
    $pythonPackages = @($Dependencies | Where-Object { [string]$_.type -match '(?i)python|pip' })
    $mavenPackages = @($Dependencies | Where-Object { [string]$_.type -match '(?i)maven|gradle|java' })

    $nugetContent = if ($nugetPackages.Count -gt 0) {
        $rows = $nugetPackages | Group-Object -Property name | Sort-Object Name | ForEach-Object {
            $versions = ($_.Group.version | Sort-Object -Unique) -join ', '
            $uniqueProjects = @($_.Group.project | Sort-Object -Unique)
            $projCount = $uniqueProjects.Count
            $usedBy = ($uniqueProjects | Select-Object -First 3) -join ', '
            if ($projCount -gt 3) {
                $usedBy += " +$($projCount - 3) more"
            }
            $criticalPath = if ($projCount -ge 3 -or $_.Name -match '(?i)(logging|auth|identity|http|json|entityframework|grpc|swagger)') { "Yes" } else { "No" }
            "| ``$($_.Name)`` | $versions | $usedBy | NuGet package | $criticalPath |"
        }
@"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
$($rows -join "`n")

**Total NuGet Packages**: $(($nugetPackages | Group-Object name).Count)
"@
    } else {
        $nugetPlaceholder
    }

    $npmContent = if ($npmPackages.Count -gt 0) {
        $rows = $npmPackages | Group-Object -Property name | Sort-Object Name | ForEach-Object {
            $versions = ($_.Group.version | Sort-Object -Unique) -join ', '
            $usedBy = ($_.Group.project | Sort-Object -Unique) -join ', '
            $criticalPath = if (($_.Name -match '(?i)(react|angular|vue|express|axios|auth|routing)') -or (@($_.Group.project | Sort-Object -Unique).Count -ge 2)) { "Yes" } else { "No" }
            "| ``$($_.Name)`` | $versions | $usedBy | NPM package | $criticalPath |"
        }
@"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
$($rows -join "`n")
"@

    } else {
        $npmPlaceholder
    }

    $pythonContent = if ($pythonPackages.Count -gt 0) {
        $rows = $pythonPackages | Group-Object -Property name | Sort-Object Name | ForEach-Object {
            $versions = ($_.Group.version | Sort-Object -Unique) -join ', '
            $usedBy = ($_.Group.project | Sort-Object -Unique) -join ', '
            $criticalPath = if (($_.Name -match '(?i)(django|flask|fastapi|requests|sqlalchemy|auth)') -or (@($_.Group.project | Sort-Object -Unique).Count -ge 2)) { "Yes" } else { "No" }
            "| ``$($_.Name)`` | $versions | $usedBy | Python package | $criticalPath |"
        }
@"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
$($rows -join "`n")
"@

    } else {
        $pythonPlaceholder
    }

    $mavenContent = if ($mavenPackages.Count -gt 0) {
        $rows = $mavenPackages | Group-Object -Property name | Sort-Object Name | ForEach-Object {
            $versions = ($_.Group.version | Sort-Object -Unique) -join ', '
            $usedBy = ($_.Group.project | Sort-Object -Unique) -join ', '
            $criticalPath = if (($_.Name -match '(?i)(spring|jackson|http|security|hibernate)') -or (@($_.Group.project | Sort-Object -Unique).Count -ge 2)) { "Yes" } else { "No" }
            "| ``$($_.Name)`` | $versions | $usedBy | Maven/Gradle dependency | $criticalPath |"
        }
@"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
$($rows -join "`n")
"@

    } else {
        $mavenPlaceholder
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
⚠️ **$($versionConflicts.Count) packages with version conflicts detected:**

$($conflicts -join "`n`n")
"@
    } else {
        $versionConflictsPlaceholder
    }

    return [ordered]@{
        summaryContent = $summaryContent
        nugetContent = $nugetContent
        npmContent = $npmContent
        pythonContent = $pythonContent
        mavenContent = $mavenContent
        projectRefsContent = $projectRefsContent
        versionConflictsContent = $versionConflictsContent
        summaryTablePlaceholder = $summaryTablePlaceholder
        nugetPlaceholder = $nugetPlaceholder
        npmPlaceholder = $npmPlaceholder
        pythonPlaceholder = $pythonPlaceholder
        mavenPlaceholder = $mavenPlaceholder
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
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.npmPlaceholder -NewContent $sections.npmContent
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.pythonPlaceholder -NewContent $sections.pythonContent
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.mavenPlaceholder -NewContent $sections.mavenContent
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.projectRefsPlaceholder -NewContent $sections.projectRefsContent
        $updated = Update-TemplateSection -Content $updated -PlaceholderText $sections.versionConflictsPlaceholder -NewContent $sections.versionConflictsContent
    } else {
        $updated = $updated.Replace($sections.summaryTablePlaceholder, $sections.summaryContent)
        $updated = $updated.Replace($sections.nugetPlaceholder, $sections.nugetContent)
        $updated = $updated.Replace($sections.npmPlaceholder, $sections.npmContent)
        $updated = $updated.Replace($sections.pythonPlaceholder, $sections.pythonContent)
        $updated = $updated.Replace($sections.mavenPlaceholder, $sections.mavenContent)
        $updated = $updated.Replace($sections.projectRefsPlaceholder, $sections.projectRefsContent)
        $updated = $updated.Replace($sections.versionConflictsPlaceholder, $sections.versionConflictsContent)

        # Regex replacements only if Update-TemplateSection is not available
        $patterns = @(
            @{ Pattern = '(?s)(##\s+Dependency Summary\s*\r?\n\r?\n)(.*?)(\r?\n)(?=##\s+Dependencies by Type\b)'; Header = '##\s+Dependency Summary' ; Content = $sections.summaryContent },
            @{ Pattern = '(?s)(###\s+NuGet Packages\s*\r?\n\r?\n)(.*?)(\r?\n)(?=###\s+NPM Packages\b)'; Header = '###\s+NuGet Packages' ; Content = $sections.nugetContent },
            @{ Pattern = '(?s)(###\s+NPM Packages\s*\r?\n\r?\n)(.*?)(\r?\n)(?=###\s+Python Packages\b)'; Header = '###\s+NPM Packages' ; Content = $sections.npmContent },
            @{ Pattern = '(?s)(###\s+Python Packages\s*\r?\n\r?\n)(.*?)(\r?\n)(?=###\s+Maven/Gradle Dependencies\b)'; Header = '###\s+Python Packages' ; Content = $sections.pythonContent },
            @{ Pattern = '(?s)(###\s+Maven/Gradle Dependencies\s*\r?\n\r?\n)(.*?)(\r?\n)(?=##\s+Project References\b)'; Header = '###\s+Maven/Gradle Dependencies' ; Content = $sections.mavenContent },
            @{ Pattern = '(?s)(##\s+Project References\s*\r?\n\r?\n)(.*?)(\r?\n)(?=##\s+Version Conflicts\b)'; Header = '##\s+Project References' ; Content = $sections.projectRefsContent },
            @{ Pattern = '(?s)(##\s+Version Conflicts\s*\r?\n\r?\n)(.*?)(\r?\n)(?=##\s+Security Considerations\b)'; Header = '##\s+Version Conflicts' ; Content = $sections.versionConflictsContent }
        )
        foreach ($pat in $patterns) {
            if ([regex]::IsMatch($updated, $pat.Header)) {
                $content = $pat.Content
                $updated = [regex]::Replace(
                    $updated,
                    $pat.Pattern,
                    [System.Text.RegularExpressions.MatchEvaluator]{
                        param($m)
                        # $m.Groups[1] = section header, $m.Groups[3] = original trailing newline
                        return ($m.Groups[1].Value + $content + $m.Groups[3].Value)
                    }
                )
            } else {
                Write-Warning ("Section header not found for pattern: {0}" -f $pat.Header)
            }
        }
    }

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Overview\s*\r?\n\r?\n).*?(?=\r?\n##\s+Dependency Summary\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "This catalog aggregates dependencies discovered from package manifests, project references, and assembly references. Use it to identify version drift, runtime coupling, and upgrade planning priorities." + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Security Considerations\s*\r?\n\r?\n).*?(?=\r?\n##\s+Licensing\b)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "This artifact does not currently include automated CVE/advisory enrichment. Use dependency scanning tools in CI and prioritize packages with multiple versions or broad usage footprint for security review." + "`r`n")
        }
    )

    $updated = [regex]::Replace(
        $updated,
        '(?s)(##\s+Upgrade Recommendations\s*\r?\n\r?\n).*?(?=(\r?\n##\s+)|\z)',
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return ($m.Groups[1].Value + "Focus upgrades on packages that appear in many projects, show version divergence, or sit on critical execution paths. Roll upgrades in small batches and validate build/test outputs after each change set." + "`r`n")
        }
    )

    return $updated
}

Export-ModuleMember -Function @(
    'Get-AppDocDependenciesCatalogMarkdown',
    'Update-AppDocDependenciesCatalogContent'
)
