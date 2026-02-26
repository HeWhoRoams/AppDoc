param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [AllowEmptyCollection()]
    [string[]]$MatrixRoots = @(),
    [Parameter(Mandatory=$false)]
    [ValidateRange(2,5)]
    [int]$Iterations = 2,
    [Parameter(Mandatory=$false)]
    [switch]$SkipGeneration,
    [Parameter(Mandatory=$false)]
    [switch]$SkipC4,
    [Parameter(Mandatory=$false)]
    [switch]$Json
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-StabilitySha256 {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Text
    )

    $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $hash = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

function Get-NormalizedDiagramContent {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path
    )

    $content = Get-Content -Path $Path -Raw
    if ($null -eq $content) { $content = "" }

    # Remove volatile generation timestamps while preserving diagram semantics.
    $content = [regex]::Replace($content, '(?im)^\*\*Generated\*\:\s*.+$', '**Generated**: {{timestamp}}')
    $content = [regex]::Replace($content, '(?im)^_Generated:\s*.+_$', '_Generated: {{timestamp}}_')
    $content = [regex]::Replace($content, '(?im)^Generated:\s*.+$', 'Generated: {{timestamp}}')

    # Normalize newlines for platform-invariant hashing.
    $content = $content -replace "`r`n", "`n"
    return $content
}

function Get-DiagramTruthPackHash {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TruthPackPath
    )

    $raw = Get-Content -Path $TruthPackPath -Raw
    if ([string]::IsNullOrWhiteSpace($raw)) {
        return [ordered]@{
            hash = ""
            source = "empty"
        }
    }

    try {
        $payload = $raw | ConvertFrom-Json -Depth 120
        $determinism = $null
        if ($payload -and $payload.PSObject.Properties["determinism"]) {
            $determinism = $payload.determinism
        }
        if ($determinism -and $determinism.PSObject.Properties["contentHash"] -and $determinism.contentHash) {
            return [ordered]@{
                hash = [string]$determinism.contentHash
                source = "determinism.contentHash"
            }
        }
    }
    catch {
        # Fall through to normalized raw hashing.
    }

    $normalized = $raw -replace "`r`n", "`n"
    $normalized = [regex]::Replace($normalized, '(?im)"generatedAt"\s*:\s*"[^"]*"', '"generatedAt":"{{timestamp}}"')
    return [ordered]@{
        hash = (Get-StabilitySha256 -Text $normalized)
        source = "normalized-json"
    }
}

function Get-DiagramSnapshot {
    param(
        [Parameter(Mandatory=$true)]
        [string]$TargetRoot,
        [Parameter(Mandatory=$true)]
        [string]$ScriptsRoot,
        [int]$Iteration = 1,
        [switch]$SkipGeneration,
        [switch]$SkipC4
    )

    $suiteScript = Join-Path $ScriptsRoot "generate-mermaid-architecture-suite.ps1"
    if (-not (Test-Path $suiteScript)) {
        throw "Required script not found: $suiteScript"
    }

    if (-not $SkipGeneration) {
        $null = & $suiteScript -RootPath $TargetRoot -SkipC4:$SkipC4
        $exitCode = [int]$LASTEXITCODE
        if ($exitCode -ne 0) {
            throw "Diagram suite generation failed for '$TargetRoot' on iteration $Iteration (exit=$exitCode)."
        }
    }

    $truthPackPath = Join-Path $TargetRoot (Join-Path "docs" (Join-Path "evidence" "diagram-truth-pack.json"))
    if (-not (Test-Path $truthPackPath)) {
        throw "Missing diagram truth pack after generation: $truthPackPath"
    }

    $diagramsPath = Join-Path $TargetRoot (Join-Path "docs" "diagrams")
    if (-not (Test-Path $diagramsPath)) {
        throw "Missing diagrams directory after generation: $diagramsPath"
    }

    $truthHashInfo = Get-DiagramTruthPackHash -TruthPackPath $truthPackPath
    $diagramFiles = @(
        Get-ChildItem -Path $diagramsPath -File -Filter *.md -ErrorAction SilentlyContinue |
            Sort-Object @{ Expression = { [string]$_.Name } }
    )

    $diagramHashes = [ordered]@{}
    foreach ($file in $diagramFiles) {
        $normalized = Get-NormalizedDiagramContent -Path $file.FullName
        $diagramHashes[$file.Name] = (Get-StabilitySha256 -Text $normalized)
    }

    return [ordered]@{
        iteration = $Iteration
        targetRoot = $TargetRoot
        truthPackPath = $truthPackPath
        truthHash = [string]$truthHashInfo.hash
        truthHashSource = [string]$truthHashInfo.source
        diagramCount = $diagramHashes.Count
        diagramHashes = $diagramHashes
    }
}

function Compare-DiagramSnapshots {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Baseline,
        [Parameter(Mandatory=$true)]
        [hashtable]$Candidate
    )

    $issues = New-Object 'System.Collections.Generic.List[string]'
    if ([string]$Baseline.truthHash -ne [string]$Candidate.truthHash) {
        $issues.Add(("truth-pack-hash-mismatch:{0}:{1}" -f $Baseline.truthHash, $Candidate.truthHash))
    }

    $baselineNames = @($Baseline.diagramHashes.Keys | Sort-Object)
    $candidateNames = @($Candidate.diagramHashes.Keys | Sort-Object)
    if (($baselineNames -join '|') -ne ($candidateNames -join '|')) {
        $issues.Add("diagram-file-set-mismatch")
    }

    foreach ($name in $baselineNames) {
        if (-not $Candidate.diagramHashes.Contains($name)) {
            $issues.Add(("diagram-missing:{0}" -f $name))
            continue
        }

        $baselineHash = [string]$Baseline.diagramHashes[$name]
        $candidateHash = [string]$Candidate.diagramHashes[$name]
        if ($baselineHash -ne $candidateHash) {
            $issues.Add(("diagram-hash-mismatch:{0}:{1}:{2}" -f $name, $baselineHash, $candidateHash))
        }
    }

    return @($issues)
}

if (-not (Test-Path $RootPath)) {
    throw "Root path does not exist: $RootPath"
}

$scriptsRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
$targets = @()
if ($MatrixRoots -and $MatrixRoots.Count -gt 0) {
    $targets = @($MatrixRoots)
}
else {
    $targets = @($RootPath)
}

$targetResults = @()
$allIssues = New-Object 'System.Collections.Generic.List[string]'

foreach ($target in $targets) {
    if ([string]::IsNullOrWhiteSpace([string]$target)) { continue }
    if (-not (Test-Path $target)) {
        $allIssues.Add(("target-missing:{0}" -f $target))
        continue
    }

    $snapshots = @()
    $targetIssues = New-Object 'System.Collections.Generic.List[string]'
    try {
        for ($i = 1; $i -le $Iterations; $i++) {
            $snapshot = Get-DiagramSnapshot -TargetRoot $target -ScriptsRoot $scriptsRoot -Iteration $i -SkipGeneration:$SkipGeneration -SkipC4:$SkipC4
            $snapshots += $snapshot
        }

        $baseline = $snapshots[0]
        for ($i = 1; $i -lt $snapshots.Count; $i++) {
            $deltaIssues = Compare-DiagramSnapshots -Baseline $baseline -Candidate $snapshots[$i]
            foreach ($issue in $deltaIssues) {
                $targetIssues.Add($issue)
                $allIssues.Add(("{0}:{1}" -f $target, $issue))
            }
        }
    }
    catch {
        $msg = "target-run-failed:{0}" -f $_.Exception.Message
        $targetIssues.Add($msg)
        $allIssues.Add(("{0}:{1}" -f $target, $msg))
    }

    $targetResults += [ordered]@{
        targetRoot = $target
        passed = ($targetIssues.Count -eq 0)
        iterationCount = $Iterations
        snapshots = $snapshots
        issues = @($targetIssues)
    }
}

$result = [ordered]@{
    passed = ($allIssues.Count -eq 0)
    issueCount = $allIssues.Count
    issues = @($allIssues)
    targetCount = $targetResults.Count
    targets = $targetResults
}

if ($Json) {
    Write-Output ($result | ConvertTo-Json -Depth 20)
}
else {
    if ($result.passed) {
        Write-Host ("Diagram stability gate passed across {0} target(s)." -f $result.targetCount) -ForegroundColor Green
    }
    else {
        Write-Host ("Diagram stability gate failed with {0} issue(s)." -f $result.issueCount) -ForegroundColor Red
        foreach ($issue in $result.issues) {
            Write-Host (" - {0}" -f $issue) -ForegroundColor Yellow
        }
    }
}

if (-not $result.passed) { exit 1 }
exit 0
