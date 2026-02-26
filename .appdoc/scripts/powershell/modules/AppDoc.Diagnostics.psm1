# AppDoc.Diagnostics Module
# Purpose: Structured diagnostics, error taxonomy, and quality gate evaluation

$script:AppDocDiagnosticsVersion = "1.0.0"
$script:AppDocDiagnosticEvents = New-Object System.Collections.ArrayList

function ConvertTo-AppDocDiagnosticsPortablePath {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [string]$PathValue,
        [string]$RootPath = "",
        [string]$OutputPath = ""
    )

    if ([string]::IsNullOrWhiteSpace($PathValue)) { return "" }
    $candidate = [string]$PathValue

    if (-not [string]::IsNullOrWhiteSpace($RootPath)) {
        try {
            $resolvedRoot = [System.IO.Path]::GetFullPath($RootPath)
            $resolvedCandidate = [System.IO.Path]::GetFullPath($candidate)
            if ($resolvedCandidate -eq $resolvedRoot) {
                return "./"
            }
            if ($resolvedCandidate.StartsWith($resolvedRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
                $relative = [System.IO.Path]::GetRelativePath($resolvedRoot, $resolvedCandidate)
                if ([string]::IsNullOrWhiteSpace($relative) -or $relative -eq ".") { return "./" }
                return ("./" + ($relative -replace '\\', '/'))
            }
        }
        catch {
            # Fall through to normalized original candidate.
        }
    }

    if (-not [string]::IsNullOrWhiteSpace($OutputPath)) {
        try {
            $resolvedOutput = [System.IO.Path]::GetFullPath($OutputPath)
            $resolvedCandidate = [System.IO.Path]::GetFullPath($candidate)
            if ($resolvedCandidate -eq $resolvedOutput) {
                $dirName = [System.IO.Path]::GetFileName($resolvedOutput)
                if ([string]::IsNullOrWhiteSpace($dirName)) { $dirName = "output" }
                return "./$dirName"
            }
        }
        catch {
            # Ignore and continue with normalized candidate.
        }
    }

    $normalized = $candidate -replace '\\', '/'
        if ($normalized -match '^[A-Za-z]:') {
            $normalizedPath = $normalized -replace '\\', '/'
            $normalizedPath = $normalizedPath -replace '^[A-Za-z]:', '${ROOT_PATH}'
            return $normalizedPath
    }
    return $normalized
}

function ConvertTo-AppDocDiagnosticsPortableValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value,
        [string]$PropertyName = "",
        [string]$RootPath = "",
        [string]$OutputPath = ""
    )

    if ($null -eq $Value) { return $null }

    if ($Value -is [System.Collections.IDictionary]) {
        $result = [ordered]@{}
        foreach ($key in @($Value.Keys)) {
            $keyName = [string]$key
            $result[$keyName] = ConvertTo-AppDocDiagnosticsPortableValue -Value $Value[$key] -PropertyName $keyName -RootPath $RootPath -OutputPath $OutputPath
        }
        return $result
    }

    if (($Value -is [System.Collections.IEnumerable]) -and -not ($Value -is [string])) {
        return $Value | ForEach-Object { ConvertTo-AppDocDiagnosticsPortableValue -Value $_ -PropertyName $PropertyName -RootPath $RootPath -OutputPath $OutputPath }
    }

    if ($Value -is [string]) {
        $name = if ($PropertyName) { $PropertyName.ToLowerInvariant() } else { "" }
        if ($name -eq "profile") {
            return [string]$Value
        }
        if ($name -in @("path","filepath","file","rootpath","outputpath") -or $name -match 'path$' -or $name -match 'filepath$') {
            return ConvertTo-AppDocDiagnosticsPortablePath -PathValue ([string]$Value) -RootPath $RootPath -OutputPath $OutputPath
        }
        return [string]$Value
    }

    return $Value
}

function Initialize-AppDocDiagnostics {
    [CmdletBinding()]
    param(
        [string]$RootPath = "",
        [string]$OutputPath = "",
        [switch]$Reset
    )

    if ($Reset) {
        $script:AppDocDiagnosticEvents = New-Object System.Collections.ArrayList
    }

    if ($RootPath) {
            Write-AppDocDiagnostic -Category "INITIALIZATION" -Severity "Info" `
            -Message "Diagnostics initialized" -Component "orchestrator" `
            -Details @{ rootPath = $RootPath; outputPath = $OutputPath }
    }
}

function Write-AppDocDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("NOT_FOUND", "DETECTION_PATTERN_MISMATCH", "UNSUPPORTED_FRAMEWORK", "ENVIRONMENT_ERROR", "PARSING_ERROR", "TEMPLATE_ERROR", "IO_ERROR", "INTERNAL_ERROR", "INITIALIZATION")]
        [string]$Category,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Severity,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Component = "orchestrator",
        [string]$FilePath = "",
        [hashtable]$Details = @{}
    )

    $event = [ordered]@{
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        category = $Category
        severity = $Severity
        component = $Component
        message = $Message
        filePath = $FilePath
        details = $Details
    }

    [void]$script:AppDocDiagnosticEvents.Add($event)

    switch ($Severity) {
        "Error" { Write-Error "[$Category] $Message" }
        "Warning" { Write-Warning "[$Category] $Message" }
        default { Write-Verbose "[$Category] $Message" }
    }

    return $event
}

function Get-AppDocDiagnostics {
    [CmdletBinding()]
    param()

    return @($script:AppDocDiagnosticEvents)
}

function Get-AppDocDiagnosticsSummary {
    [CmdletBinding()]
    param()

    $events = @($script:AppDocDiagnosticEvents)
    $byCategory = @{}
    $bySeverity = @{}

    foreach ($event in $events) {
        if (-not $byCategory.ContainsKey($event.category)) {
            $byCategory[$event.category] = 0
        }
        $byCategory[$event.category]++

        if (-not $bySeverity.ContainsKey($event.severity)) {
            $bySeverity[$event.severity] = 0
        }
        $bySeverity[$event.severity]++
    }

    return [ordered]@{
        total = $events.Count
        byCategory = $byCategory
        bySeverity = $bySeverity
        hasErrors = (($bySeverity.ContainsKey("Error") -and $bySeverity["Error"] -gt 0))
        hasWarnings = (($bySeverity.ContainsKey("Warning") -and $bySeverity["Warning"] -gt 0))
    }
}

function Export-AppDocDiagnostics {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [hashtable]$AdditionalData = @{}
    )

    $directory = Split-Path -Parent $Path
    if ($directory -and -not (Test-Path $directory)) {
        New-Item -Path $directory -ItemType Directory -Force | Out-Null
    }

    $rootPath = ""
    if ($AdditionalData -and $AdditionalData.ContainsKey("rootPath")) {
        $rootPath = [string]$AdditionalData["rootPath"]
    }
    if ([string]::IsNullOrWhiteSpace($rootPath)) {
        $rootPath = [string](
            Get-AppDocDiagnostics |
                ForEach-Object { $_.details.rootPath } |
                Where-Object { $_ } |
                Select-Object -First 1
        )
    }

    $outputPath = ""
    if ($AdditionalData -and $AdditionalData.ContainsKey("outputPath")) {
        $outputPath = [string]$AdditionalData["outputPath"]
    }
    if ([string]::IsNullOrWhiteSpace($outputPath)) {
        $outputPath = [string](
            Get-AppDocDiagnostics |
                ForEach-Object { $_.details.outputPath } |
                Where-Object { $_ } |
                Select-Object -First 1
        )
    }

    $portableEvents = @()
    foreach ($event in @($script:AppDocDiagnosticEvents)) {
        $portableEvents += [ordered]@{
            timestamp = [string]$event.timestamp
            category = [string]$event.category
            severity = [string]$event.severity
            component = [string]$event.component
            message = [string]$event.message
            filePath = ConvertTo-AppDocDiagnosticsPortablePath -PathValue ([string]$event.filePath) -RootPath $rootPath -OutputPath $outputPath
            details = ConvertTo-AppDocDiagnosticsPortableValue -Value $event.details -RootPath $rootPath -OutputPath $outputPath
        }
    }

    $portableMetadata = ConvertTo-AppDocDiagnosticsPortableValue -Value $AdditionalData -RootPath $rootPath -OutputPath $outputPath

    $payload = [ordered]@{
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        summary = Get-AppDocDiagnosticsSummary
        events = $portableEvents
        metadata = $portableMetadata
    }

    $payload | ConvertTo-Json -Depth 20 | Out-File -FilePath $Path -Encoding UTF8
    return $Path
}

function Test-AppDocValidationGate {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [array]$ValidationResults,
        [int]$QualityThreshold = 80,
        [switch]$Strict,
        [bool]$PolicyGatePassed = $true
    )

    if (-not $ValidationResults -or $ValidationResults.Count -eq 0) {
        return [ordered]@{
            passed = $false
            reason = "No validation results provided"
            averageScore = 0
            belowThreshold = 0
            strict = $Strict.IsPresent
        }
    }

    $scored = @($ValidationResults | Where-Object { $_.exists -eq $true })
    if ($scored.Count -eq 0) {
        return [ordered]@{
            passed = $false
            reason = "No existing documents to validate"
            averageScore = 0
            belowThreshold = $ValidationResults.Count
            strict = $Strict.IsPresent
        }
    }

    $average = [Math]::Round((($scored | Measure-Object -Property score -Average).Average), 1)
    $below = @($scored | Where-Object { $_.score -lt $QualityThreshold }).Count

    if ($Strict) {
        $passes = ($below -eq 0 -and $average -ge $QualityThreshold -and $PolicyGatePassed)
    } else {
        $passes = ($average -ge $QualityThreshold -and $PolicyGatePassed)
    }

    return [ordered]@{
        passed = $passes
        reason = if ($passes) { "Validation gate passed" } else { "Validation gate failed" }
        averageScore = $average
        belowThreshold = $below
        strict = $Strict.IsPresent
        qualityThreshold = $QualityThreshold
        evaluatedDocuments = $scored.Count
    }
}

Export-ModuleMember -Function @(
    'Initialize-AppDocDiagnostics',
    'Write-AppDocDiagnostic',
    'Get-AppDocDiagnostics',
    'Get-AppDocDiagnosticsSummary',
    'Export-AppDocDiagnostics',
    'Test-AppDocValidationGate'
)
