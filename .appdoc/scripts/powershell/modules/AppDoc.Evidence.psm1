# AppDoc.Evidence Module
# Purpose: Write normalized deterministic evidence artifacts and manifest entries.

$script:AppDocEvidenceVersion = "1.0.0"

function Get-AppDocEvidenceDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    return (Join-Path (Join-Path $RootPath "docs") "evidence")
}

function Get-AppDocEvidenceFilePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Artifact
    )

    $evidenceDir = Get-AppDocEvidenceDirectory -RootPath $RootPath
    return (Join-Path $evidenceDir ("{0}.evidence.json" -f $Artifact))
}

function Write-AppDocEvidenceArtifact {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Artifact,
        [AllowEmptyCollection()]
        [array]$Records = @(),
        [hashtable]$Metadata = @{}
    )

    $evidenceDir = Get-AppDocEvidenceDirectory -RootPath $RootPath
    if (-not (Test-Path $evidenceDir)) {
        New-Item -Path $evidenceDir -ItemType Directory -Force | Out-Null
    }

    $path = Get-AppDocEvidenceFilePath -RootPath $RootPath -Artifact $Artifact
    $normalizedRecords = @($Records)

    $payload = [ordered]@{
        artifact = $Artifact
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        recordCount = $normalizedRecords.Count
        records = $normalizedRecords
        metadata = $Metadata
    }

    $payload | ConvertTo-Json -Depth 30 | Out-File -FilePath $path -Encoding UTF8
    return $path
}

function Update-AppDocEvidenceManifest {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$Artifact,
        [Parameter(Mandatory=$true)]
        [string]$EvidencePath,
        [int]$RecordCount = 0,
        [hashtable]$Metadata = @{}
    )

    $evidenceDir = Get-AppDocEvidenceDirectory -RootPath $RootPath
    if (-not (Test-Path $evidenceDir)) {
        New-Item -Path $evidenceDir -ItemType Directory -Force | Out-Null
    }

    $manifestPath = Join-Path $evidenceDir "manifest.json"
    $manifest = [ordered]@{
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        artifacts = @()
    }

    if (Test-Path $manifestPath) {
        try {
            $existing = Get-Content -Path $manifestPath -Raw | ConvertFrom-Json
            if ($existing -and $existing.artifacts) {
                $manifest.generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
                $manifest.artifacts = @($existing.artifacts)
            }
        }
        catch {
            $manifest = [ordered]@{
                generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
                artifacts = @()
            }
        }
    }

    $entry = [ordered]@{
        artifact = $Artifact
        path = $EvidencePath
        recordCount = $RecordCount
        updatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        metadata = $Metadata
    }

    $filtered = @($manifest.artifacts | Where-Object { $_.artifact -ne $Artifact })
    $manifest.artifacts = @($filtered + $entry)
    $manifest.generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")

    $manifest | ConvertTo-Json -Depth 20 | Out-File -FilePath $manifestPath -Encoding UTF8
    return $manifestPath
}

Export-ModuleMember -Function @(
    'Get-AppDocEvidenceDirectory',
    'Get-AppDocEvidenceFilePath',
    'Write-AppDocEvidenceArtifact',
    'Update-AppDocEvidenceManifest'
)
