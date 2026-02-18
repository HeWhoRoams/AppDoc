function Invoke-AppDocApiAstParserScript {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ScriptsRoot,
        [Parameter(Mandatory = $true)]
        [string]$ScriptName,
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $scriptPath = Join-Path $ScriptsRoot $ScriptName
    if (-not (Test-Path $scriptPath)) {
        return $null
    }

    try {
        & $scriptPath -RootPath $RootPath -Json | Out-Null
    }
    catch {
        Write-Verbose "AST parser execution failed ($ScriptName): $($_.Exception.Message)"
        return $null
    }

    $cacheFile = if ($ScriptName -eq "parse-csharp-ast.ps1") { "ast-csharp-cache.json" } else { "ast-typescript-cache.json" }
    $cachePath = Join-Path $RootPath (Join-Path "docs" $cacheFile)
    if (-not (Test-Path $cachePath)) {
        return $null
    }

    try {
        return (Get-Content $cachePath -Raw | ConvertFrom-Json)
    }
    catch {
        Write-Verbose "Unable to parse AST cache ($cacheFile): $($_.Exception.Message)"
        return $null
    }
}

function Add-AppDocAstEndpointsToInventory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)]
        [object]$AstPayload,
        [Parameter(Mandatory = $true)]
        [hashtable]$Inventory
    )

    if (-not $AstPayload -or -not $AstPayload.records) {
        return 0
    }

    $added = 0
    foreach ($record in $AstPayload.records) {
        if ($record.kind -ne "endpoint") { continue }
        if (-not $record.metadata) { continue }

        $method = [string]$record.metadata.method
        $path = [string]$record.metadata.path
        if (-not $method -or -not $path) { continue }

        $parameters = "None"
        if ($record.metadata.parameters) {
            if ($record.metadata.parameters -is [System.Array]) {
                $parameters = (($record.metadata.parameters | ForEach-Object { [string]$_ }) -join ', ')
            }
            else {
                $parameters = [string]$record.metadata.parameters
            }
        }

        $filePath = [string]$record.file
        $fileName = if ($filePath) { [System.IO.Path]::GetFileName($filePath) } else { "unknown" }

        $Inventory.endpoints += @{
            method = $method.ToUpper()
            path = $path
            file = $fileName
            filePath = $filePath
            lineNumber = if ($record.lineNumber) { [int]$record.lineNumber } else { 1 }
            parameters = if ($parameters) { $parameters } else { "None" }
            returnType = if ($record.metadata.returnType) { [string]$record.metadata.returnType } else { "unknown" }
            auth = if ($record.metadata.auth) { [string]$record.metadata.auth } else { "None" }
            description = if ($record.metadata.description) { [string]$record.metadata.description } else { "AST extracted endpoint" }
            example = $null
            controller = if ($record.metadata.controller) { [string]$record.metadata.controller } else { "Other" }
            schema = if ($parameters -and $parameters -ne "None") { "See parameters" } else { "N/A" }
        }
        $added++
    }

    return $added
}

Export-ModuleMember -Function @(
    'Invoke-AppDocApiAstParserScript',
    'Add-AppDocAstEndpointsToInventory'
)
