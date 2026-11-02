# AppDoc.Values Module
# Purpose: One accessor for reading a field from the hashtables and PSObjects the generators exchange.
# Kept apart from AppDoc.Determinism on purpose: several modules ask "is Get-AppDocDeterministicHash
# available?" before they add a determinism block, so importing Determinism into a module changes
# what that module writes. This module exports only Get-AppDocValue and changes nothing else.

function Get-AppDocValue {
    <#
    .SYNOPSIS
        Reads a field from a hashtable or a PSObject and returns Default when the object is null or the field is missing.
    .DESCRIPTION
        The read side of Set-AppDocFieldValue. Works the same on the hashtables the generators build and on the
        PSCustomObjects that ConvertFrom-Json returns. A field that is present with a null value returns that null,
        not Default. -IgnoreCase also matches a hashtable key that differs only by case (used for config and policy
        data written by hand).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Position = 0)]
        [AllowNull()]
        [object]$Object,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$Name,
        [Parameter(Position = 2)]
        [AllowNull()]
        [object]$Default = $null,
        [switch]$IgnoreCase
    )

    if ($null -eq $Object) { return $Default }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) { return $Object[$Name] }
        if ($IgnoreCase) {
            foreach ($key in @($Object.Keys)) {
                if ([string]::Equals([string]$key, $Name, [System.StringComparison]::OrdinalIgnoreCase)) {
                    return $Object[$key]
                }
            }
        }
        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) { return $prop.Value }
    return $Default
}

Export-ModuleMember -Function @('Get-AppDocValue')
