param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Generate dependency graph
Write-Progress -Activity "Generating Dependency Graph" -Status "Parsing manifests..." -PercentComplete 0

$graph = @{
    nodes = @()
    edges = @()
}

# Parse package.json if exists
$packageJsonPath = Join-Path $RootPath "package.json"
if (Test-Path $packageJsonPath) {
    $packageJson = Get-Content $packageJsonPath | ConvertFrom-Json
    if ($packageJson.dependencies) {
        $graph.nodes += @{
            id = "root"
            label = "Root Project"
            type = "project"
        }
        foreach ($dep in $packageJson.dependencies.PSObject.Properties) {
            $graph.nodes += @{
                id = $dep.Name
                label = $dep.Name
                type = "dependency"
            }
            $graph.edges += @{
                from = "root"
                to = $dep.Name
                type = "depends_on"
            }
        }
    }
}

# Parse imports from code files (simple regex)
$codeFiles = Get-ChildItem -Path $RootPath -Recurse -Include "*.js","*.ts","*.jsx","*.tsx" | Where-Object { $_.FullName -notmatch '\\node_modules\\' }
foreach ($file in $codeFiles) {
    $content = Get-Content $file.FullName -Raw
    $imports = [regex]::Matches($content, "import\s+.*?\s+from\s+['""]([^'""]+)['""]") | ForEach-Object { $_.Groups[1].Value }
    foreach ($import in $imports) {
        if ($import -match "^\./|^\.\./|^/") {
            # Local import
            try {
                $target = Resolve-Path (Join-Path $file.DirectoryName $import) -ErrorAction Stop
                if (Test-Path $target) {
                    $targetName = [System.IO.Path]::GetFileNameWithoutExtension($target)
                    $graph.edges += @{
                        from = [System.IO.Path]::GetFileNameWithoutExtension($file.Name)
                        to = $targetName
                        type = "imports"
                    }
                }
            } catch {
                # Ignore unresolvable imports
            }
        }
    }
}

Write-Progress -Activity "Generating Dependency Graph" -Status "Complete" -PercentComplete 100

# Output JSON
$graph | ConvertTo-Json -Depth 10