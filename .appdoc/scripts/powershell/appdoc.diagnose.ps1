param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [switch]$Fix,
    [switch]$Json
)

$diagnosticsModule = Join-Path $PSScriptRoot "modules\AppDoc.Diagnostics.psm1"
$frameworkModule = Join-Path $PSScriptRoot "modules\AppDoc.FrameworkDetection.psm1"
$scopeModule = Join-Path $PSScriptRoot "modules\AppDoc.Scope.psm1"
if (Test-Path $diagnosticsModule) { Import-Module $diagnosticsModule -Force -ErrorAction Stop }
if (Test-Path $frameworkModule) { Import-Module $frameworkModule -Force -ErrorAction Stop }
if (Test-Path $scopeModule) { Import-Module $scopeModule -Force -ErrorAction Stop }

if (-not (Test-Path $RootPath)) {
    Write-Error "Root path does not exist: $RootPath"
    exit 1
}

$docsPath = Join-Path $RootPath "docs"
if ($Fix -and -not (Test-Path $docsPath)) {
    New-Item -Path $docsPath -ItemType Directory -Force | Out-Null
}

if (Get-Command Initialize-AppDocDiagnostics -ErrorAction SilentlyContinue) {
    Initialize-AppDocDiagnostics -RootPath $RootPath -OutputPath $docsPath -Reset
}

if ($PSVersionTable.PSVersion.Major -lt 7) {
    Write-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Error" -Message "PowerShell 7+ is required" -Component "diagnose" -Details @{ version = $PSVersionTable.PSVersion.ToString() } | Out-Null
}
else {
    Write-AppDocDiagnostic -Category "ENVIRONMENT_ERROR" -Severity "Info" -Message "PowerShell version check passed" -Component "diagnose" -Details @{ version = $PSVersionTable.PSVersion.ToString() } | Out-Null
}

$templateDirs = @(
    (Join-Path $RootPath ".appdoc\templates")
)

$templateOk = $false
foreach ($dir in $templateDirs) {
    if (Test-Path $dir) { $templateOk = $true }
}

if (-not $templateOk) {
    Write-AppDocDiagnostic -Category "TEMPLATE_ERROR" -Severity "Error" -Message "Template directory not found" -Component "diagnose" -Details @{ checked = $templateDirs } | Out-Null
}

$requiredScripts = @(
    "run-all-generators.ps1",
    "generate-overview.ps1",
    "generate-api-inventory.ps1",
    "generate-data-model.ps1",
    "generate-config-catalog.ps1",
    "generate-build-cookbook.ps1",
    "generate-test-catalog.ps1",
    "generate-debt-register.ps1",
    "generate-dependencies-catalog.ps1"
)

foreach ($scriptName in $requiredScripts) {
    $scriptPath = Join-Path $PSScriptRoot $scriptName
    if (-not (Test-Path $scriptPath)) {
        Write-AppDocDiagnostic -Category "IO_ERROR" -Severity "Error" -Message "Required script missing: $scriptName" -Component "diagnose" -FilePath $scriptPath | Out-Null
        continue
    }

    try {
        $parseErrors = $null
        [void][System.Management.Automation.Language.Parser]::ParseFile($scriptPath, [ref]$null, [ref]$parseErrors)
        if ($parseErrors -and $parseErrors.Count -gt 0) {
            Write-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Script has parse issues: $scriptName" -Component "diagnose" -FilePath $scriptPath -Details @{ count = $parseErrors.Count } | Out-Null
        }
    }
    catch {
        Write-AppDocDiagnostic -Category "PARSING_ERROR" -Severity "Warning" -Message "Unable to parse script: $scriptName" -Component "diagnose" -FilePath $scriptPath -Details @{ exception = $_.Exception.Message } | Out-Null
    }
}

if (-not (Test-Path $docsPath)) {
    Write-AppDocDiagnostic -Category "IO_ERROR" -Severity "Warning" -Message "Output docs directory does not exist" -Component "diagnose" -FilePath $docsPath | Out-Null
}
else {
    try {
        $testWrite = Join-Path $docsPath ".appdoc-write-test.tmp"
        "ok" | Out-File -FilePath $testWrite -Encoding UTF8
        Remove-Item $testWrite -Force -ErrorAction SilentlyContinue
    }
    catch {
        Write-AppDocDiagnostic -Category "IO_ERROR" -Severity "Error" -Message "Output docs directory is not writable" -Component "diagnose" -FilePath $docsPath -Details @{ exception = $_.Exception.Message } | Out-Null
    }
}

$sourceFiles = @(Get-AppDocSourceFiles -RootPath $RootPath -Include @("*.cs","*.js","*.ts","*.py","*.java"))
if ($sourceFiles.Count -eq 0) {
    Write-AppDocDiagnostic -Category "NOT_FOUND" -Severity "Warning" -Message "No supported source files detected" -Component "diagnose" | Out-Null
}

$frameworks = @()
if (Get-Command Get-AppDocDetectedFrameworks -ErrorAction SilentlyContinue) {
    $frameworks = Get-AppDocDetectedFrameworks -RootPath $RootPath
    if ($frameworks.Count -eq 0) {
        Write-AppDocDiagnostic -Category "UNSUPPORTED_FRAMEWORK" -Severity "Warning" -Message "No known framework signatures detected" -Component "diagnose" | Out-Null
    }
}

$summary = Get-AppDocDiagnosticsSummary
$reportPath = Join-Path $docsPath "diagnostics-report.json"
if (Get-Command Export-AppDocDiagnostics -ErrorAction SilentlyContinue) {
    Export-AppDocDiagnostics -Path $reportPath -AdditionalData @{ frameworks = $frameworks; sourceFileCount = $sourceFiles.Count; fixed = $Fix.IsPresent } | Out-Null
}

if ($Json) {
    $payload = @{
        summary = $summary
        frameworks = $frameworks
        sourceFileCount = $sourceFiles.Count
        reportPath = $reportPath
    }
    $payload | ConvertTo-Json -Depth 20
}
else {
    Write-Host "AppDoc Diagnose Summary" -ForegroundColor Cyan
    Write-Host "  Source files: $($sourceFiles.Count)"
    Write-Host "  Diagnostics total: $($summary.total)"
    Write-Host "  Errors present: $($summary.hasErrors)"
    Write-Host "  Warnings present: $($summary.hasWarnings)"
    Write-Host "  Report: $reportPath"
    if ($frameworks.Count -gt 0) {
        Write-Host "  Frameworks: $($frameworks.framework -join ', ')"
    }
}

if ($summary.hasErrors) { exit 1 }
