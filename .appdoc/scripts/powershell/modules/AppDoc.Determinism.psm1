# AppDoc.Determinism Module
# Purpose: Canonical ordering and hash generation for deterministic AppDoc outputs.

$script:AppDocDeterminismVersion = "1.0.0"

function ConvertTo-AppDocDeterministicValue {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]$Value,
        [string[]]$ExcludeKeys = @()
    )

    if ($null -eq $Value) {
        return $null
    }

    if ($Value -is [string] -or $Value.GetType().IsPrimitive -or $Value -is [decimal] -or $Value -is [datetime]) {
        return $Value
    }

    if ($Value -is [System.Collections.IDictionary]) {
        $ordered = [ordered]@{}
        foreach ($key in @($Value.Keys | ForEach-Object { [string]$_ } | Sort-Object)) {
            if ($ExcludeKeys -contains $key) { continue }
            $ordered[$key] = ConvertTo-AppDocDeterministicValue -Value $Value[$key] -ExcludeKeys $ExcludeKeys
        }
        return $ordered
    }

    if ($Value -is [psobject]) {
        if ($Value.PSObject.Properties.Count -eq 0) {
            return [ordered]@{}
        }
        $ordered = [ordered]@{}
        foreach ($prop in @($Value.PSObject.Properties | Sort-Object Name)) {
            if ($ExcludeKeys -contains [string]$prop.Name) { continue }
            $ordered[[string]$prop.Name] = ConvertTo-AppDocDeterministicValue -Value $prop.Value -ExcludeKeys $ExcludeKeys
        }
        return $ordered
    }

    if ($Value -is [System.Collections.IEnumerable] -and -not ($Value -is [string])) {
        $arrayList = [System.Collections.ArrayList]::new()
        foreach ($item in $Value) {
            $result = ConvertTo-AppDocDeterministicValue -Value $item -ExcludeKeys $ExcludeKeys
            [void]$arrayList.Add($result)
        }
        return $arrayList.ToArray()
    }

    return [string]$Value
}

function Sort-AppDocExtractionRecords {
    [CmdletBinding()]
    param(
        [AllowEmptyCollection()]
        [array]$Records = @()
    )

    if (-not $Records -or $Records.Count -eq 0) {
        return @()
    }

    $normalized = @(
        $Records | ForEach-Object {
            $sourceValue = if ($_.source) { ([string]$_.source).Replace('\', '/').Trim() } else { "" }
            $nameValue = if ($_.name) { ([string]$_.name).Trim() } else { "" }
            $kindValue = if ($_.kind) { ([string]$_.kind).Trim().ToLowerInvariant() } else { "" }
            [ordered]@{
                artifact = if ($_.artifact) { [string]$_.artifact } else { "" }
                source = $sourceValue
                name = $nameValue
                kind = $kindValue
                confidence = if ($_.confidence -ne $null) { [double]$_.confidence } else { 0.0 }
                metadata = if ($_.metadata) { $_.metadata } else { @{} }
                provider = if ($_.provider) { [string]$_.provider } else { "" }
                providerType = if ($_.providerType) { [string]$_.providerType } else { "" }
                status = if ($_.status) { [string]$_.status } else { "Detected" }
                timestamp = if ($_.timestamp) { [string]$_.timestamp } else { "" }
            }
        }
    )

    return @(
        $normalized | Sort-Object `
            @{ Expression = { [string]$_.artifact } }, `
            @{ Expression = { [string]$_.kind } }, `
            @{ Expression = { [string]$_.name } }, `
            @{ Expression = { [string]$_.source } }, `
            @{ Expression = { "{0:N4}" -f [double]$_.confidence } }, `
            @{ Expression = { [string]$_.provider } }, `
            @{ Expression = { [string]$_.providerType } }
    )
}

function Get-AppDocDeterministicHash {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [AllowNull()]
        [object]$InputObject,
        [string[]]$ExcludeKeys = @("generatedAt", "updatedAt", "timestamp")
    )

    $normalized = ConvertTo-AppDocDeterministicValue -Value $InputObject -ExcludeKeys $ExcludeKeys
    $json = $normalized | ConvertTo-Json -Depth 50 -Compress

    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($json)
        $hashBytes = $sha.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($hashBytes) -replace '-', '').ToLowerInvariant()
    }
    finally {
        $sha.Dispose()
    }
}

Export-ModuleMember -Function @(
    'Sort-AppDocExtractionRecords',
    'Get-AppDocDeterministicHash'
)
