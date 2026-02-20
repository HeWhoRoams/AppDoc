param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [switch]$Strict,
    [Parameter(Mandatory=$false)]
    [switch]$Json
)

$contractModule = Join-Path $PSScriptRoot "modules\AppDoc.Diagrams.Contract.psm1"
if (-not (Test-Path $contractModule)) {
    Write-Error "Required module not found: $contractModule"
    exit 1
}
Import-Module $contractModule -Force -ErrorAction Stop

$contract = Get-AppDocDiagramContract
$diagramsPath = Join-Path $RootPath (Join-Path "docs" "diagrams")
$truthPackPath = Join-Path $RootPath (Join-Path "docs" (Join-Path "evidence" "diagram-truth-pack.json"))

$issues = @()
$details = @()
$requiredViews = @(if ($contract -and $contract.requiredViews) { $contract.requiredViews } else { @() })

foreach ($view in $requiredViews) {
    $file = [string]$view.file
    if ([string]::IsNullOrWhiteSpace($file)) { continue }
    $path = Join-Path $diagramsPath $file
    $exists = Test-Path $path
    $hasMermaidFence = $false
    $size = 0
    if ($exists) {
        $content = Get-Content $path -Raw
        $size = $content.Length
        $hasMermaidFence = ($content -match '(?ms)```mermaid\s+.+?```')
        if (-not $hasMermaidFence) {
            $issues += "missing-mermaid-fence:$file"
        }
        if ($content -match '(?i)no\s+.*\s+detected') {
            $issues += "placeholder-like-content:$file"
        }
        if ($size -lt 80) {
            $issues += "diagram-too-small:$file"
        }
    }
    else {
        $issues += "missing-diagram:$file"
    }

    $details += [ordered]@{
        file = $file
        path = $path
        exists = $exists
        hasMermaidFence = $hasMermaidFence
        length = $size
    }
}

if (-not (Test-Path $truthPackPath)) {
    $issues += "missing-truth-pack:diagram-truth-pack.json"
}

$result = [ordered]@{
    passed = ($issues.Count -eq 0)
    strict = $Strict.IsPresent
    diagramsPath = $diagramsPath
    truthPackPath = $truthPackPath
    issueCount = $issues.Count
    issues = @($issues | Select-Object -Unique)
    details = $details
}

if ($Json) {
    $result | ConvertTo-Json -Depth 20
}
else {
    if ($result.passed) {
        Write-Host "Diagram validation passed." -ForegroundColor Green
    }
    else {
        Write-Warning ("Diagram validation reported {0} issue(s)." -f $result.issueCount)
        foreach ($issue in $result.issues) {
            Write-Warning (" - {0}" -f $issue)
        }
    }
}

if ($Strict -and -not $result.passed) {
    exit 1
}
exit 0

