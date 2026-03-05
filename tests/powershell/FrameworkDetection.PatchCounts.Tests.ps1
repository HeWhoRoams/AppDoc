# Test: Framework detection should patch counts in truth pack
# This test simulates a scenario where ASP.NET Core is detected but no code files are found.
# It validates that counts.codeFiles and counts.dependencyRecords are patched, and detectionWarning is set.

param(
    [string]$RootPath = (Resolve-Path (Join-Path $PSScriptRoot '..\..'))
)

$truthPackModule = Join-Path $RootPath ".appdoc\scripts\powershell\modules\AppDoc.Overview.TruthPack.psm1"
Import-Module $truthPackModule -Force

function Remove-DirectoryRobust {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [int]$MaxRetries = 5
    )

    if (-not (Test-Path $Path)) { return }

    $lastError = $null
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    if ($_.Attributes -band [IO.FileAttributes]::ReadOnly) {
                        $_.Attributes = ($_.Attributes -bxor [IO.FileAttributes]::ReadOnly)
                    }
                }
                catch {}
            }

            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            if (-not (Test-Path $Path)) { return }
        }
        catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds (150 * $attempt)
        }
    }

    Write-Warning ("Failed to remove test directory after {0} attempts: {1}. Last error: {2}" -f $MaxRetries, $Path, $lastError)
}

# Simulate overview data with no code files
$overviewData = [ordered]@{
    codeFiles = @()
    codeFileCount = 0
    languageCount = @{}
}

# Build minimal fixture docs so framework detection is available to the function
$tempRoot = Join-Path $PSScriptRoot "test-output\framework-detection-patch"
$docsPath = Join-Path $tempRoot "docs"
Remove-DirectoryRobust -Path $tempRoot
New-Item -ItemType Directory -Path $docsPath -Force | Out-Null

@{
    framework = 'ASP.NET Core'
    supportLevel = 'full'
} | ConvertTo-Json -Depth 8 | Out-File -FilePath (Join-Path $docsPath "framework-detection.json") -Encoding UTF8

@{
    primaryStyle = 'no-api-surface'
    styles = @('no-api-surface')
} | ConvertTo-Json -Depth 8 | Out-File -FilePath (Join-Path $docsPath "architecture-fingerprint.json") -Encoding UTF8

# Patch Get-AppDocOverviewObjectValue to return test data
function global:Get-AppDocOverviewObjectValue {
    param([object]$Object, [string]$Name, [object]$Default = $null)
    if ($null -eq $Object) { return $Default }
    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }
    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $Default
}

# Call the function under test
$truthPack = Get-AppDocOverviewTruthPackData -RootPath $tempRoot -OverviewData $overviewData

# Assert patched counts
if ($truthPack.counts.codeFiles -ne 1) { throw "FAIL: codeFiles should be patched to 1" }
if ($truthPack.counts.dependencyRecords -ne 1) { throw "FAIL: dependencyRecords should be patched to 1" }
if (-not $truthPack.architecture.detectionWarning) { throw "FAIL: detectionWarning should be set" }
Write-Host "PASS: Framework detection patch logic works as expected." -ForegroundColor Green

Remove-DirectoryRobust -Path $tempRoot
