#!/usr/bin/env pwsh
<#
.SYNOPSIS
    Legacy compatibility wrapper for diagram generation.

.DESCRIPTION
    Kept only to preserve older local/CI invocations. The canonical
    implementation is generate-mermaid-architecture-suite.ps1.
#>

param(
    [Parameter(Mandatory=$false)]
    [string]$RootPath = ".",
    [Parameter(Mandatory=$false)]
    [switch]$SkipC4,
    [string]$Type = $null,
    [string]$Output = $null
)

# Deprecation warnings for legacy parameters
if ($PSBoundParameters.ContainsKey('Type') -and $Type) {
    Write-Warning "[DEPRECATED] The -Type parameter is deprecated and will be ignored. Please update your invocation to omit this argument."
}
if ($PSBoundParameters.ContainsKey('Output') -and $Output) {
    Write-Warning "[DEPRECATED] The -Output parameter is deprecated. Use the new output path conventions. Mapping to default behavior."
    # Optionally, map $Output to a new variable or use as needed for backward compatibility
    # $OutputPath = $Output  # Uncomment if you want to support legacy output path
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$suiteScript = Join-Path $PSScriptRoot "generate-mermaid-architecture-suite.ps1"
if (-not (Test-Path $suiteScript)) {
    Write-Error "Required script not found: $suiteScript"
    exit 1
}

Write-Host "generate-diagrams.ps1 is deprecated. Delegating to generate-mermaid-architecture-suite.ps1." -ForegroundColor Yellow
& $suiteScript -RootPath $RootPath -SkipC4:$SkipC4

# Exit with the delegated script's exit code, defaulting to 0 if unset
exit ([int]($LASTEXITCODE ?? 0))
