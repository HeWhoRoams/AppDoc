# AppDoc.Evidence Module
# Purpose: Write normalized deterministic evidence artifacts and manifest entries.

$script:AppDocEvidenceVersion = "1.0.0"

$determinismModulePath = Join-Path $PSScriptRoot "AppDoc.Determinism.psm1"
if (Test-Path $determinismModulePath) {
    try {
        Import-Module $determinismModulePath -Force -ErrorAction Stop | Out-Null
    } catch {
        Write-Warning "Failed to import AppDoc.Determinism.psm1 ($determinismModulePath): $_"
    }
}

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

    # Validate that Artifact is not null or empty
    if ([string]::IsNullOrWhiteSpace($Artifact)) {
        throw "Artifact parameter cannot be null or empty."
    }

    # Get invalid characters for filenames
    $invalidChars = [System.IO.Path]::GetInvalidFileNameChars()
    
    # Check for path traversal attempts (parent directory references)
    if ($Artifact -match '\.\.' -or $Artifact -match '[/\\]\.\.') {
        throw "Artifact parameter contains invalid path traversal sequence: $Artifact"
    }

    # Check for directory separators in the artifact name
    if ($Artifact -match '[/\\]') {
        throw "Artifact parameter contains directory separators: $Artifact"
    }

    # Check for invalid characters and normalize if needed
    $normalizedArtifact = $Artifact
    foreach ($char in $invalidChars) {
        if ($normalizedArtifact.Contains($char)) {
            $normalizedArtifact = $normalizedArtifact.Replace([string]$char, '_')
        }
    }

    # Ensure we don't have an empty artifact after normalization
    if ([string]::IsNullOrWhiteSpace($normalizedArtifact)) {
        throw "Artifact parameter resulted in invalid filename after sanitization: $Artifact"
    }

    $evidenceDir = Get-AppDocEvidenceDirectory -RootPath $RootPath
    return (Join-Path $evidenceDir ("{0}.evidence.json" -f $normalizedArtifact))
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
    if (Get-Command Sort-AppDocExtractionRecords -ErrorAction SilentlyContinue) {
        $normalizedRecords = @(Sort-AppDocExtractionRecords -Records $normalizedRecords)
    }

    $payload = [ordered]@{
        artifact = $Artifact
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        recordCount = $normalizedRecords.Count
        records = $normalizedRecords
        metadata = $Metadata
    }


    if (Get-Command Get-AppDocDeterministicHash -ErrorAction SilentlyContinue) {
        $excludeKeys = @("generatedAt", "updatedAt", "timestamp")
        $payload.determinism = [ordered]@{
            hashAlgorithm = "SHA256"
            excludeKeys = $excludeKeys
            contentHash = Get-AppDocDeterministicHash -InputObject $payload -ExcludeKeys $excludeKeys
        }
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
    $manifest.artifacts = @($filtered + $entry | Sort-Object { [string]$_.artifact })
    $manifest.generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")


    if (Get-Command Get-AppDocDeterministicHash -ErrorAction SilentlyContinue) {
        $excludeKeys = @("generatedAt", "updatedAt", "timestamp")
        $manifestForHash = $manifest.Clone()
        $deterministicHash = Get-AppDocDeterministicHash -InputObject $manifestForHash -ExcludeKeys $excludeKeys
        $manifest['determinism'] = [ordered]@{
            hashAlgorithm = "SHA256"
            excludeKeys = $excludeKeys
            contentHash = $deterministicHash
        }
    }

function Validate-ManifestDeterminism {
    param(
        [Parameter(Mandatory=$true)]
        [string]$ManifestPath
    )
    $manifest = Get-Content $ManifestPath -Raw | ConvertFrom-Json
    if ($manifest.determinism -and $manifest.determinism.contentHash) {
        $excludeKeys = $manifest.determinism.excludeKeys
        # Use PSObject.Copy() here because $manifest is a deserialized PSObject, not an ordered hashtable
        $manifestForHash = $manifest.PSObject.Copy()
        foreach ($key in $excludeKeys) { $null = $manifestForHash.PSObject.Properties.Remove($key) }
        $actualHash = Get-AppDocDeterministicHash -InputObject $manifestForHash -ExcludeKeys $excludeKeys
        if ($actualHash -ne $manifest.determinism.contentHash) {
            throw "Manifest contentHash validation failed: expected $($manifest.determinism.contentHash), got $actualHash."
        }
    }
}

    $manifest | ConvertTo-Json -Depth 20 | Out-File -FilePath $manifestPath -Encoding UTF8
    return $manifestPath
}

Export-ModuleMember -Function @(
    'Get-AppDocEvidenceDirectory',
    'Get-AppDocEvidenceFilePath',
    'Write-AppDocEvidenceArtifact',
    'Update-AppDocEvidenceManifest'
)
