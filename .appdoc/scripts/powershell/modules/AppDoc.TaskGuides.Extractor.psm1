function Get-AppDocTaskGuideEvidenceRecords {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$EvidenceRoot,
        [Parameter(Mandatory=$true)]
        [string]$Artifact
    )

    $path = Join-Path $EvidenceRoot ("{0}.evidence.json" -f $Artifact)
    if (-not (Test-Path $path)) { return @() }

    try {
        $payload = Get-Content $path -Raw | ConvertFrom-Json
        if ($null -eq $payload.records) { return @() }
        return @($payload.records)
    }
    catch {
        Write-Verbose ("Failed to load or parse evidence file: {0}. Error: {1}" -f $path, $_)
        return @()
    }
}

function Get-AppDocTaskGuidesData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $docsPath = Join-Path $RootPath "docs"
    $evidenceRoot = Join-Path $docsPath "evidence"

    $apiRecords = Get-AppDocTaskGuideEvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "api-inventory"
    $buildRecords = Get-AppDocTaskGuideEvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "build-cookbook"
    $dependencyRecords = Get-AppDocTaskGuideEvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "dependencies-catalog"
    $debtRecords = Get-AppDocTaskGuideEvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "debt-register"
    $testRecords = Get-AppDocTaskGuideEvidenceRecords -EvidenceRoot $evidenceRoot -Artifact "test-catalog"

    $endpointRows = @($apiRecords | Where-Object { [string]$_.kind -eq "endpoint" })
    $buildCommandRows = @($buildRecords | Where-Object { [string]$_.kind -in @("build-command", "command") })
    $dependencyRows = @($dependencyRecords | Where-Object { [string]$_.kind -eq "dependency" })
    $debtRows = @($debtRecords | Where-Object { [string]$_.kind -in @("technical-debt", "debt-item") })
    $testRows = @($testRecords | Where-Object { [string]$_.kind -in @("test-case", "test-suite") })

    $sampleEndpoints = @($endpointRows | Select-Object -First 5 | ForEach-Object {
        $method = if ($_.metadata -and $_.metadata.method) { [string]$_.metadata.method } else { "ANY" }
        $name = if ($_.name) { [string]$_.name } else { "endpoint" }
        "- ``$method`` ``$name``"
    })
    if ($sampleEndpoints.Count -eq 0) { $sampleEndpoints = @("- No endpoint evidence available") }

    $sampleBuildCommands = @($buildCommandRows | Select-Object -First 5 | ForEach-Object {
        $cmd = if ($_.metadata -and $_.metadata.invocation) { [string]$_.metadata.invocation } else { [string]$_.name }
        "- ``$cmd``"
    })
    if ($sampleBuildCommands.Count -eq 0) { $sampleBuildCommands = @("- No build command evidence available") }

    $sampleDependencies = @($dependencyRows | Group-Object -Property name | Sort-Object Count -Descending | Select-Object -First 5 | ForEach-Object {
        "- ``$($_.Name)`` used in $($_.Count) locations"
    })
    if ($sampleDependencies.Count -eq 0) { $sampleDependencies = @("- No dependency evidence available") }

    $sampleDebt = @($debtRows | Select-Object -First 5 | ForEach-Object {
        $desc = if ($_.metadata -and $_.metadata.description) { [string]$_.metadata.description } else { [string]$_.name }
        "- $desc"
    })
    if ($sampleDebt.Count -eq 0) { $sampleDebt = @("- No debt evidence available") }

    $sampleTests = @($testRows | Select-Object -First 5 | ForEach-Object {
        $name = if ($_.name) { [string]$_.name } else { "test" }
        $type = if ($_.kind) { [string]$_.kind } else { "test-case" }
        "- ``$type`` ``$name``"
    })
    if ($sampleTests.Count -eq 0) { $sampleTests = @("- No test evidence available") }

    return [ordered]@{
        endpointRows = $endpointRows
        buildCommandRows = $buildCommandRows
        dependencyRows = $dependencyRows
        debtRows = $debtRows
        testRows = $testRows
        sampleEndpoints = $sampleEndpoints
        sampleBuildCommands = $sampleBuildCommands
        sampleDependencies = $sampleDependencies
        sampleDebt = $sampleDebt
        sampleTests = $sampleTests
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocTaskGuidesData'
)
