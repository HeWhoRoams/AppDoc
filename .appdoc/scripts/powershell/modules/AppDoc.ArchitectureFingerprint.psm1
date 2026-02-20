# AppDoc.ArchitectureFingerprint Module
# Purpose: Classify architecture/API styles from deterministic repository signals.

$script:AppDocArchitectureFingerprintVersion = "1.0.0"

function Get-AppDocArchitectureFingerprint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $allFiles = @(
        Get-ChildItem -Path (Join-Path $RootPath "*") -Recurse -File -ErrorAction SilentlyContinue |
            Where-Object {
                $_.FullName -notmatch '(?i)([\\/]\.git[\\/]|[\\/]node_modules[\\/]|[\\/]bin[\\/]|[\\/]obj[\\/]|[\\/]dist[\\/]|[\\/]build[\\/]|[\\/]docs?[\\/]|[\\/](test|tests|spec|specs)[\\/]|[\\/]__tests__[\\/]|[\\/](fixture|fixtures|mock|mocks|sample|samples|example|examples)[\\/])'
            }
    )

    $csFiles = @($allFiles | Where-Object { $_.Extension -eq ".cs" })
    $svcFiles = @($allFiles | Where-Object { $_.Extension -eq ".svc" })
    $asmxFiles = @($allFiles | Where-Object { $_.Extension -eq ".asmx" })
    $wsdlFiles = @($allFiles | Where-Object { $_.Extension -eq ".wsdl" })
    $svcMapFiles = @($allFiles | Where-Object { $_.Extension -eq ".svcmap" })
    $svcInfoFiles = @($allFiles | Where-Object { $_.Extension -eq ".svcinfo" })

    $serviceReferenceFiles = @(
        $csFiles | Where-Object {
            $_.FullName -match '(?i)([\\/])(Service References|Connected Services)([\\/])' -or
            ($_.Name -eq "Reference.cs" -and $_.FullName -match '(?i)([\\/])(Service References|Connected Services)([\\/])')
        }
    )

    $sampleFiles = @($allFiles | Where-Object { $_.Extension -in @(".cs", ".js", ".ts", ".java", ".py") } | Select-Object -First 800)
    $restSignalCount = 0
    $wcfServerSignalCount = 0
    $asmxServerSignalCount = 0

    foreach ($file in $sampleFiles) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if (-not $content) { continue }

        $restSignalCount += ([regex]::Matches(
            $content,
            '\[ApiController\]|\[Route\(|\[(HttpGet|HttpPost|HttpPut|HttpDelete|HttpPatch)|Map(Get|Post|Put|Delete|Patch)\(|MapControllers\(|app\.(get|post|put|delete|patch)\s*\(',
            'IgnoreCase'
        )).Count

        if ($file.Extension -eq ".cs" -and $file.FullName -notmatch '(?i)(Service References|Connected Services|Reference\.cs$)') {
            $wcfServerSignalCount += ([regex]::Matches(
                $content,
                '\[ServiceContract(?:Attribute)?\]|\[OperationContract(?:Attribute)?\]|System\.ServiceModel',
                'IgnoreCase'
            )).Count

            $asmxServerSignalCount += ([regex]::Matches(
                $content,
                '\[WebMethod(?:Attribute)?\]|System\.Web\.Services|:\s*WebService\b',
                'IgnoreCase'
            )).Count
        }
    }

    $soapClientSignalCount = $serviceReferenceFiles.Count + $wsdlFiles.Count + $svcMapFiles.Count + $svcInfoFiles.Count

    $scores = [ordered]@{
        restHttp = [int]$restSignalCount
        wcfService = [int](($wcfServerSignalCount * 2) + $svcFiles.Count)
        asmxService = [int](($asmxServerSignalCount * 2) + $asmxFiles.Count)
        soapClient = [int]$soapClientSignalCount
    }

    $styles = New-Object System.Collections.ArrayList
    if ($scores.restHttp -gt 0) { [void]$styles.Add("rest-http") }
    if ($scores.wcfService -gt 0) { [void]$styles.Add("wcf-service") }
    if ($scores.asmxService -gt 0) { [void]$styles.Add("asmx-service") }
    if ($scores.soapClient -gt 0) { [void]$styles.Add("soap-client") }
    if ($styles.Count -eq 0) { [void]$styles.Add("no-api-surface") }

    $primaryStyle = "no-api-surface"
    $topScore = 0
    foreach ($pair in $scores.GetEnumerator()) {
        if ([int]$pair.Value -gt $topScore) {
            $topScore = [int]$pair.Value
            $primaryStyle = switch ([string]$pair.Key) {
                "restHttp" { "rest-http" }
                "wcfService" { "wcf-service" }
                "asmxService" { "asmx-service" }
                "soapClient" { "soap-client" }
                default { "no-api-surface" }
            }
        }
    }

    $serverSignals = [int]($scores.restHttp + $scores.wcfService + $scores.asmxService)
    $apiSurfaceExpected = ($serverSignals -gt 0)
    if (-not $apiSurfaceExpected -and $styles.Count -eq 1 -and $styles[0] -eq "soap-client") {
        $apiSurfaceExpected = $false
    }

    $confidence = if ($topScore -le 0) { 0.55 } else { [Math]::Min(0.99, (0.65 + ([Math]::Min($topScore, 80) / 200.0))) }

    return [ordered]@{
        version = $script:AppDocArchitectureFingerprintVersion
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        primaryStyle = $primaryStyle
        styles = @($styles)
        apiSurfaceExpected = [bool]$apiSurfaceExpected
        confidence = [Math]::Round($confidence, 3)
        scores = $scores
        evidence = [ordered]@{
            csFileCount = $csFiles.Count
            svcFileCount = $svcFiles.Count
            asmxFileCount = $asmxFiles.Count
            wsdlFileCount = $wsdlFiles.Count
            svcMapFileCount = $svcMapFiles.Count
            svcInfoFileCount = $svcInfoFiles.Count
            serviceReferenceFileCount = $serviceReferenceFiles.Count
            sampledCodeFileCount = $sampleFiles.Count
        }
    }
}

function Test-AppDocApiSurfaceExpected {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $fingerprint = Get-AppDocArchitectureFingerprint -RootPath $RootPath
    return [bool]$fingerprint.apiSurfaceExpected
}

Export-ModuleMember -Function @(
    'Get-AppDocArchitectureFingerprint',
    'Test-AppDocApiSurfaceExpected'
)
