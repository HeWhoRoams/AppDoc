param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)

# Extract config options and feature flags
Write-Progress -Activity "Extracting Config" -Status "Scanning config files..." -PercentComplete 0

$config = @{
    options = @()
    flags = @()
}

# Common config files
$configFiles = @(".env", ".env.local", "config.js", "config.json", "app.config.js", "settings.json")

foreach ($fileName in $configFiles) {
    $filePath = Join-Path $RootPath $fileName
    if (Test-Path $filePath) {
        $content = Get-Content $filePath -Raw
        if ($fileName -match "\.env") {
            # Parse .env
            $lines = $content -split "`n"
            foreach ($line in $lines) {
                if ($line -match "^([^=]+)=(.*)$") {
                    $key = $matches[1].Trim()
                    $value = $matches[2].Trim()
                    $config.options += @{
                        key = $key
                        default = $value
                        source = $fileName
                        type = "env_var"
                    }
                }
            }
        } elseif ($fileName -match "\.json$") {
            # Parse JSON
            try {
                $json = $content | ConvertFrom-Json
                foreach ($prop in $json.PSObject.Properties) {
                    $config.options += @{
                        key = $prop.Name
                        default = $prop.Value
                        source = $fileName
                        type = "json_config"
                    }
                }
            } catch {}
        }
    }
}

# Feature flags (simple heuristic: look for flags in code)
$codeFiles = Get-ChildItem -Path $RootPath -Recurse -Include "*.js","*.ts" | Where-Object { $_.FullName -notmatch '\\node_modules\\' }
foreach ($file in $codeFiles) {
    $content = Get-Content $file.FullName -Raw
    $flags = [regex]::Matches($content, "feature.*flag|flag.*feature|FEATURE_FLAG") | ForEach-Object { $_.Value }
    foreach ($flag in $flags) {
        $config.flags += @{
            name = $flag
            file = $file.Name
            type = "code_flag"
        }
    }
}

Write-Progress -Activity "Extracting Config" -Status "Complete" -PercentComplete 100

# Output JSON
$config | ConvertTo-Json -Depth 10