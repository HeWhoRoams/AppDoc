$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path '.tmp-logs' | Out-Null

$log = '.tmp-logs/pester-full.log'
$resultFile = '.tmp-logs/pester-full.result.json'

try {
    # Pester only auto-discovers *.Tests.ps1; golden/pristine suites are named test-*.ps1, so list them explicitly.
    $files = @(Get-ChildItem (Join-Path $PSScriptRoot 'powershell') -File -Filter *.ps1 |
        Where-Object { $_.Name -like '*.Tests.ps1' -or $_.Name -like 'test-golden-*.ps1' -or $_.Name -eq 'test-pristine-gate.ps1' } |
        Select-Object -ExpandProperty FullName)
    $cfg = New-PesterConfiguration
    $cfg.Run.Path = $files
    $cfg.Run.PassThru = $true
    $cfg.Output.Verbosity = 'Detailed'
    $res = Invoke-Pester -Configuration $cfg
    $res | Out-String | Tee-Object -FilePath $log | Out-Null
    if (-not $res) {
        Write-Output 'FAILED {"reason":"No Pester result"}'
        exit 1
    }

    $result = [string]$res.Result
    if ([string]::IsNullOrWhiteSpace($result)) {
        if ($res.FailedCount -gt 0) {
            $result = 'Failed'
        }
        elseif ($res.TotalCount -gt 0) {
            $result = 'Passed'
        }
        else {
            $result = 'Unknown'
        }
    }

    $summary = [ordered]@{
        Passed  = $res.PassedCount
        Failed  = $res.FailedCount
        Skipped = $res.SkippedCount
        Total   = $res.TotalCount
        Result  = $result
    }

    $summary | ConvertTo-Json | Out-File -FilePath $resultFile -Encoding utf8

    if ($res.FailedCount -gt 0) {
        Write-Output ('FAILED ' + ($summary | ConvertTo-Json -Compress))
        exit 1
    }

    Write-Output ('PASSED ' + ($summary | ConvertTo-Json -Compress))
    exit 0
}
catch {
    $_ | Out-String | Out-File -FilePath $log -Append -Encoding utf8
    $errorObj = @{ reason = $_.Exception.Message }
    Write-Output ('FAILED ' + ($errorObj | ConvertTo-Json -Compress))
    exit 1
}
