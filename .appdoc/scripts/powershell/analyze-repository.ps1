param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Analyze repository for inventory
Write-Progress -Activity "Analyzing Repository" -Status "Scanning files..." -PercentComplete 0

$files = Get-ChildItem -Path $RootPath -Recurse -File | Where-Object { $_.FullName -notmatch '\\\.git\\' -and $_.FullName -notmatch '\\node_modules\\' }

$inventory = @{
    totalFiles = $files.Count
    languages = @{}
    services = @()
    directories = @()
}

# Detect languages by file extensions
foreach ($file in $files) {
    $ext = $file.Extension.ToLower()
    if ($inventory.languages.ContainsKey($ext)) {
        $inventory.languages[$ext]++
    } else {
        $inventory.languages[$ext] = 1
    }
}

# Detect services (simple heuristic: directories with main files)
$dirs = Get-ChildItem -Path $RootPath -Directory | Where-Object { $_.Name -notmatch '^\.' -and $_.Name -ne 'node_modules' }
foreach ($dir in $dirs) {
    $inventory.directories += $dir.Name
    # Simple service detection
    if ((Get-ChildItem -Path $dir.FullName -File | Where-Object { $_.Name -match 'main|index|app' }).Count -gt 0) {
        $inventory.services += $dir.Name
    }
}

Write-Progress -Activity "Analyzing Repository" -Status "Complete" -PercentComplete 100

# Output JSON
$inventory | ConvertTo-Json -Depth 10