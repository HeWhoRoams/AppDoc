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

    $getField = {
        param($record, [string]$fieldName, $defaultValue = $null)

        if ($null -eq $record) { return $defaultValue }

        if ($record -is [System.Collections.IDictionary] -and $record.Contains($fieldName)) {
            return $record[$fieldName]
        }

        $prop = $record.PSObject.Properties[$fieldName]
        if ($prop) { return $prop.Value }

        $metadata = $null
        if ($record -is [System.Collections.IDictionary] -and $record.Contains('metadata')) {
            $metadata = $record['metadata']
        } elseif ($record.PSObject.Properties['metadata']) {
            $metadata = $record.metadata
        }

        if ($null -ne $metadata) {
            if ($metadata -is [System.Collections.IDictionary] -and $metadata.Contains($fieldName)) {
                return $metadata[$fieldName]
            }
            $metadataProp = $metadata.PSObject.Properties[$fieldName]
            if ($metadataProp) { return $metadataProp.Value }
        }

        return $defaultValue
    }

    $resolveDependencyKind = {
        param($dependency)

        $kind = [string](& $getField $dependency 'dependencyKind' '')
        if (-not [string]::IsNullOrWhiteSpace($kind)) { return $kind.ToLowerInvariant() }

        $type = [string](& $getField $dependency 'type' '')
        if ($type -match '(?i)^nuget') { return 'nuget' }
        if ($type -match '(?i)assembly|gac') { return 'assembly-reference' }
        if ($type -match '(?i)npm') { return 'npm' }
        if ($type -match '(?i)python|pip') { return 'python' }
        if ($type -match '(?i)maven|gradle|java') { return 'maven' }
        if ($type -match '(?i)project reference') { return 'project-reference' }
        return 'system'
    }

    $normalizedDependencies = @(
        $Dependencies | ForEach-Object {
            $name = [string](& $getField $_ 'name' '')
            $version = [string](& $getField $_ 'version' '')
            $type = [string](& $getField $_ 'type' '')
            $project = [string](& $getField $_ 'project' '')
            $source = [string](& $getField $_ 'source' '')
            $criticalPathRaw = & $getField $_ 'criticalPath' $null
            $businessPurpose = [string](& $getField $_ 'businessPurpose' '')

            [ordered]@{
                name = $name
                version = if ([string]::IsNullOrWhiteSpace($version)) { "Unspecified" } else { $version }
                type = $type
                project = $project
                source = $source
                dependencyKind = (& $resolveDependencyKind $_)
                criticalPath = $criticalPathRaw
                businessPurpose = $businessPurpose
            }
        }
    )

    $nugetCount = (@($normalizedDependencies | Where-Object { $_.dependencyKind -eq 'nuget' })).Count
    $projectRefCount = (@($normalizedDependencies | Where-Object { $_.dependencyKind -eq 'project-reference' })).Count
    $assemblyRefCount = (@($normalizedDependencies | Where-Object { $_.dependencyKind -eq 'assembly-reference' })).Count

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

    $nugetPackages = @($normalizedDependencies | Where-Object { $_.dependencyKind -eq 'nuget' })
    $assemblyPackages = @($normalizedDependencies | Where-Object { $_.dependencyKind -eq 'assembly-reference' })
    $npmPackages = @($normalizedDependencies | Where-Object { $_.dependencyKind -eq 'npm' })
    $pythonPackages = @($normalizedDependencies | Where-Object { $_.dependencyKind -eq 'python' })
    $mavenPackages = @($normalizedDependencies | Where-Object { $_.dependencyKind -eq 'maven' })

    $resolveCriticalPath = {
        param($name, $uniqueProjects, $explicitCriticalPath)

        if ($null -ne $explicitCriticalPath -and -not [string]::IsNullOrWhiteSpace([string]$explicitCriticalPath)) {
            return (if ([bool]$explicitCriticalPath) { "Yes" } else { "No" })
        }

        if (($name -match '(?i)(microsoft\.extensions|system|newtonsoft|entityframework|auth|spring|jackson|http|security|django|flask|fastapi|requests|sqlalchemy|react|angular|vue|express|axios|routing)') -or ($uniqueProjects.Count -ge 3)) {
            return "Yes"
        }
        return "No"
    }

    $nugetContent = if ($nugetPackages.Count -gt 0) {
        $rows = $nugetPackages | Group-Object -Property name | Sort-Object Name | ForEach-Object {
            $versions = ($_.Group.version | Sort-Object -Unique) -join ', '
            $uniqueProjects = @($_.Group.project | Sort-Object -Unique)
            $usedBy = $uniqueProjects -join ', '
            $explicitCriticalPath = ($_.Group | Select-Object -First 1).criticalPath
            $criticalPath = & $resolveCriticalPath $_.Name $uniqueProjects $explicitCriticalPath
            $purpose = ($_.Group | Select-Object -First 1).businessPurpose
            if ([string]::IsNullOrWhiteSpace([string]$purpose)) { $purpose = "NuGet package" }
            "| ``$($_.Name)`` | $versions | $usedBy | $purpose | $criticalPath |"
        }

        $assemblyRows = $assemblyPackages | Group-Object -Property name | Sort-Object Name | ForEach-Object {
            $versions = ($_.Group.version | Sort-Object -Unique) -join ', '
            $uniqueProjects = @($_.Group.project | Sort-Object -Unique)
            $usedBy = $uniqueProjects -join ', '
            $explicitCriticalPath = ($_.Group | Select-Object -First 1).criticalPath
            $criticalPath = & $resolveCriticalPath $_.Name $uniqueProjects $explicitCriticalPath
            $purpose = ($_.Group | Select-Object -First 1).businessPurpose
            if ([string]::IsNullOrWhiteSpace([string]$purpose)) { $purpose = "Assembly reference" }
            "| ``$($_.Name)`` | $versions | $usedBy | $purpose | $criticalPath |"
        }
@"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
$($rows -join "`n")

#### Assembly References

| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
$(if ($assemblyRows.Count -gt 0) { $assemblyRows -join "`n" } else { "| N/A | N/A | N/A | Assembly references in scope: none in this scan. | N/A |" })

**Total NuGet Packages**: $(($nugetPackages | Group-Object name).Count)
"@
    } else {
        $nugetPlaceholder
    }

    $npmContent = if ($npmPackages.Count -gt 0) {
        $rows = $npmPackages | Group-Object -Property name | Sort-Object Name | ForEach-Object {
            $versions = ($_.Group.version | Sort-Object -Unique) -join ', '
            $usedBy = ($_.Group.project | Sort-Object -Unique) -join ', '
            $uniqueProjects = @($_.Group.project | Sort-Object -Unique)
            $explicitCriticalPath = ($_.Group | Select-Object -First 1).criticalPath
            $criticalPath = & $resolveCriticalPath $_.Name $uniqueProjects $explicitCriticalPath
            $purpose = ($_.Group | Select-Object -First 1).businessPurpose
            if ([string]::IsNullOrWhiteSpace([string]$purpose)) { $purpose = "NPM package" }
            "| ``$($_.Name)`` | $versions | $usedBy | $purpose | $criticalPath |"
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
            $uniqueProjects = ($_.Group.project | Sort-Object -Unique)
            $usedBy = $uniqueProjects -join ', '
            $explicitCriticalPath = ($_.Group | Select-Object -First 1).criticalPath
            $criticalPath = & $resolveCriticalPath $_.Name $uniqueProjects $explicitCriticalPath
            $purpose = ($_.Group | Select-Object -First 1).businessPurpose
            if ([string]::IsNullOrWhiteSpace([string]$purpose)) { $purpose = "Python package" }
            "| ``$($_.Name)`` | $versions | $usedBy | $purpose | $criticalPath |"
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
            $uniqueProjects = @($_.Group.project | Sort-Object -Unique)
            $usedBy = $uniqueProjects -join ', '
            $explicitCriticalPath = ($_.Group | Select-Object -First 1).criticalPath
            $criticalPath = & $resolveCriticalPath $_.Name $uniqueProjects $explicitCriticalPath
            $purpose = ($_.Group | Select-Object -First 1).businessPurpose
            if ([string]::IsNullOrWhiteSpace([string]$purpose)) { $purpose = "Maven/Gradle dependency" }
            "| ``$($_.Name)`` | $versions | $usedBy | $purpose | $criticalPath |"
        }
@"
| Package | Version | Used By | Purpose | Critical Path |
|---------|---------|---------|---------|---------------|
$($rows -join "`n")
"@

    } else {
        $mavenPlaceholder
    }

    $projectRefs = @($normalizedDependencies | Where-Object { $_.dependencyKind -eq 'project-reference' })
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
        $normalizedDependencies | Where-Object { $_.dependencyKind -eq 'nuget' } | Group-Object -Property name |
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
