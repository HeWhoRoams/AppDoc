# AppDoc.Diagnostics Module
# Purpose: Structured diagnostics, error taxonomy, and quality gate evaluation

$script:AppDocDiagnosticsVersion = "1.0.0"
$script:AppDocDiagnosticEvents = New-Object System.Collections.ArrayList

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
        Write-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" `
            -Message "Diagnostics initialized" -Component "orchestrator" `
            -Details @{ rootPath = $RootPath; outputPath = $OutputPath }
    }}

function Write-AppDocDiagnostic {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("NOT_FOUND", "DETECTION_PATTERN_MISMATCH", "UNSUPPORTED_FRAMEWORK", "ENVIRONMENT_ERROR", "PARSING_ERROR", "TEMPLATE_ERROR", "IO_ERROR", "INTERNAL_ERROR")]
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

    $payload = [ordered]@{
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        summary = Get-AppDocDiagnosticsSummary
        events = @($script:AppDocDiagnosticEvents)
        metadata = $AdditionalData
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
        [switch]$Strict
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

    $passes = if ($Strict) {
        ($below -eq 0)
    }
    else {
        $true
    }

    $passes = if ($Strict) {
        ($below -eq 0)
    }
    else {
        ($average -ge $QualityThreshold)
    }

    return [ordered]@{
        passed = $passes
        reason = if ($passes) { "Validation gate passed" } else { "Strict validation gate failed" }
        averageScore = $average
        belowThreshold = $below
        strict = $Strict.IsPresent
        qualityThreshold = $QualityThreshold
        evaluatedDocuments = $scored.Count
    }
}

Export-ModuleMember -Function 'Export-AppDocDiagnostics','Test-AppDocValidationGate'
