$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Force -Path '.tmp-logs' | Out-Null

$log = '.tmp-logs/pester-full.log'
$resultFile = '.tmp-logs/pester-full.result.json'

try {
    $res = Invoke-Pester -Path 'tests/powershell' -PassThru -Output Detailed | Tee-Object -FilePath $log
    if (-not $res) {
        Write-Output 'FAILED {"reason":"No Pester result"}'
        exit 1
    }

    $summary = [ordered]@{
        Passed  = $res.PassedCount
        Failed  = $res.FailedCount
        Skipped = $res.SkippedCount
        Total   = $res.TotalCount
        Result  = $res.Result
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