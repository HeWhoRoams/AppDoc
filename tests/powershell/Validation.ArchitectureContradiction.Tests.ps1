# Pester tests for architecture contradiction validation

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$validatorPath = Join-Path $repoRoot ".appdoc\scripts\powershell\validate-documentation.ps1"

function Remove-DirectoryRobust {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [int]$MaxRetries = 5
    )

    if (-not (Test-Path $Path)) { return }

    $lastError = $null
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    if ($_.Attributes -band [IO.FileAttributes]::ReadOnly) {
                        $_.Attributes = ($_.Attributes -bxor [IO.FileAttributes]::ReadOnly)
                    }
                }
                catch {}
            }

            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            if (-not (Test-Path $Path)) { return }
        }
        catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds (150 * $attempt)
        }
    }

    Write-Warning ("Failed to remove test directory after {0} attempts: {1}. Last error: {2}" -f $MaxRetries, $Path, $lastError)
}

Describe "validate-documentation architecture contradiction" {
    It "emits architecture-contradiction issues and applies contradiction penalties" {
        $tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("appdoc-arch-contradiction-" + [Guid]::NewGuid().ToString("N"))
        $docsPath = Join-Path $tempRoot "docs"
        $evidencePath = Join-Path $docsPath "evidence"

        New-Item -Path $evidencePath -ItemType Directory -Force | Out-Null

        @{
            primaryStyle = "WCF-first"
            styles = @("wcf-service", "SOAP-first")
            apiSurfaceExpected = $true
            confidence = 0.95
        } | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $docsPath "architecture-fingerprint.json") -Encoding UTF8

        @(
            @{ framework = "ASP.NET Core" }
        ) | ConvertTo-Json -Depth 10 | Out-File -FilePath (Join-Path $docsPath "framework-detection.json") -Encoding UTF8

        @"
# API Inventory

## API Endpoints
| Name | Path | Method | Component | Purpose |
| --- | --- | --- | --- | --- |
| `GetOrders` | `/orders` | GET | `OrdersController` | List orders |
"@ | Out-File -FilePath (Join-Path $docsPath "api-inventory.md") -Encoding UTF8

        @"
# Overview

## Welcome
### what_it_does
REST API for order operations.
### inputs
- orderId
### processing_steps
- route request
### outputs
- json payload
### external_systems
- none
### confidence_notes
- deterministic
### evidence_refs
- ev-0001
"@ | Out-File -FilePath (Join-Path $docsPath "overview.md") -Encoding UTF8

        # Minimal placeholders to keep validator flow deterministic
        "# Start Here`n`n**Generated**: 2026-03-04T00:00:00Z" | Out-File -FilePath (Join-Path $docsPath "start-here.md") -Encoding UTF8
        "# Data Model`n`n**Generated**: 2026-03-04T00:00:00Z" | Out-File -FilePath (Join-Path $docsPath "data-model.md") -Encoding UTF8
        "# Config Catalog`n`n**Generated**: 2026-03-04T00:00:00Z" | Out-File -FilePath (Join-Path $docsPath "config-catalog.md") -Encoding UTF8
        "# Build Cookbook`n`n**Generated**: 2026-03-04T00:00:00Z" | Out-File -FilePath (Join-Path $docsPath "build-cookbook.md") -Encoding UTF8
        "# Test Catalog`n`n**Generated**: 2026-03-04T00:00:00Z" | Out-File -FilePath (Join-Path $docsPath "test-catalog.md") -Encoding UTF8
        "# Task Guides`n`n**Generated**: 2026-03-04T00:00:00Z" | Out-File -FilePath (Join-Path $docsPath "task-guides.md") -Encoding UTF8
        "# Debt Register`n`n**Generated**: 2026-03-04T00:00:00Z" | Out-File -FilePath (Join-Path $docsPath "debt-register.md") -Encoding UTF8
        "# Dependencies Catalog`n`n**Generated**: 2026-03-04T00:00:00Z" | Out-File -FilePath (Join-Path $docsPath "dependencies-catalog.md") -Encoding UTF8

        try {
            $warningPreferenceBefore = $WarningPreference
            $progressPreferenceBefore = $ProgressPreference
            $WarningPreference = 'SilentlyContinue'
            $ProgressPreference = 'SilentlyContinue'

            $stdoutPath = Join-Path $tempRoot "validator.stdout.log"
            $stderrPath = Join-Path $tempRoot "validator.stderr.log"
            $shellPath = (Get-Command pwsh -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Source)
            if ([string]::IsNullOrWhiteSpace($shellPath)) {
                $shellPath = (Get-Command powershell -ErrorAction Stop | Select-Object -First 1 -ExpandProperty Source)
            }

            $process = Start-Process -FilePath $shellPath -ArgumentList @(
                '-NoProfile',
                '-ExecutionPolicy', 'Bypass',
                '-File', $validatorPath,
                '-RootPath', $tempRoot,
                '-Threshold', '1',
                '-Json'
            ) -NoNewWindow -Wait -PassThru -RedirectStandardOutput $stdoutPath -RedirectStandardError $stderrPath

            if ($process.ExitCode -ne 0 -and -not (Test-Path $stdoutPath)) {
                $stderrText = if (Test-Path $stderrPath) { Get-Content $stderrPath -Raw } else { '' }
                throw ("Validator process failed with exit code {0}. {1}" -f $process.ExitCode, $stderrText)
            }

            $jsonText = if (Test-Path $stdoutPath) { (Get-Content $stdoutPath -Raw).Trim() } else { '' }
            $jsonStarts = [regex]::Matches($jsonText, '(?m)^\{\s*')
            $jsonStartIndex = if ($jsonStarts.Count -gt 0) { $jsonStarts[$jsonStarts.Count - 1].Index } else { $jsonText.LastIndexOf('{') }
            if ($jsonStartIndex -lt 0) {
                throw "No JSON payload found in validator output."
            }

            $depth = 0
            $found = $false
            for ($i = $jsonStartIndex; $i -lt $jsonText.Length; $i++) {
                $char = $jsonText[$i]
                if ($char -eq '{') { $depth++ }
                elseif ($char -eq '}') { $depth-- }
                if ($depth -eq 0 -and $i -gt $jsonStartIndex) {
                    $jsonPayload = $jsonText.Substring($jsonStartIndex, $i - $jsonStartIndex + 1)
                    $found = $true
                    break
                }
            }

            if (-not $found) {
                throw "Could not extract complete JSON payload from validator output."
            }

            $result = $jsonPayload | ConvertFrom-Json -Depth 30

            @($result.contradictions | Where-Object { [string]$_ -like "architecture-contradiction:*" }).Count | Should BeGreaterThan 0
            [int]$result.qualityPenaltyBreakdown.categoryTotals.contradiction | Should BeGreaterThan 0
            [string]$result.status | Should Be "fail"
        }
        finally {
            $WarningPreference = $warningPreferenceBefore
            $ProgressPreference = $progressPreferenceBefore
            Remove-DirectoryRobust -Path $tempRoot
        }
    }
}
