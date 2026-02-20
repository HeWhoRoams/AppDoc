# AppDoc.FrameworkDetection Module
# Purpose: Detect language/framework signals and map to support levels

$script:AppDocFrameworkDetectionVersion = "1.0.0"

function Get-AppDocFrameworkMatrix {
    [CmdletBinding()]
    param()

    return @(
        @{ language = "C#"; framework = "ASP.NET Core"; supportLevel = "full"; coveragePercent = 90; versionRange = "2.1+"; detectionSignals = @("*.csproj", "[ApiController]", "MapControllers") },
        @{ language = "C#"; framework = "ASP.NET MVC 5"; supportLevel = "partial"; coveragePercent = 75; versionRange = "5.x"; detectionSignals = @("System.Web.Mvc", "*Controller.cs") },
        @{ language = "C#"; framework = "WCF Services"; supportLevel = "partial"; coveragePercent = 70; versionRange = ".NET Framework"; detectionSignals = @("[ServiceContract]", "[OperationContract]", "*.svc") },
        @{ language = "C#"; framework = "ASMX Web Services"; supportLevel = "partial"; coveragePercent = 65; versionRange = ".NET Framework"; detectionSignals = @("[WebMethod]", "*.asmx") },
        @{ language = "C#"; framework = "SOAP Client Integrations"; supportLevel = "partial"; coveragePercent = 60; versionRange = ".NET Framework"; detectionSignals = @("Service References", "*.svcmap", "*.wsdl") },
        @{ language = "JavaScript/TypeScript"; framework = "Express.js"; supportLevel = "partial"; coveragePercent = 60; versionRange = "4.x"; detectionSignals = @("package.json:express", "app.get(", "router.") },
        @{ language = "Python"; framework = "Flask"; supportLevel = "partial"; coveragePercent = 65; versionRange = "2.x+"; detectionSignals = @("requirements.txt:flask", "@app.route") },
        @{ language = "Python"; framework = "FastAPI"; supportLevel = "partial"; coveragePercent = 70; versionRange = "0.9+"; detectionSignals = @("requirements.txt:fastapi", "@router.get") },
        @{ language = "Python"; framework = "Django"; supportLevel = "partial"; coveragePercent = 55; versionRange = "3.x+"; detectionSignals = @("requirements.txt:django", "urls.py", "path(") },
        @{ language = "Java"; framework = "Spring Boot"; supportLevel = "partial"; coveragePercent = 60; versionRange = "2.x+"; detectionSignals = @("pom.xml:spring-boot", "@RestController") }
    )
}

function Get-AppDocDetectedFrameworks {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath
    )

    $detections = New-Object System.Collections.ArrayList
    $matrix = Get-AppDocFrameworkMatrix

    $packageJsonPath = Join-Path $RootPath "package.json"
    $requirementsPath = Join-Path $RootPath "requirements.txt"
    $pyprojectPath = Join-Path $RootPath "pyproject.toml"
    $pomPath = Join-Path $RootPath "pom.xml"

    $packageJson = $null
    if (Test-Path $packageJsonPath) {
        try { $packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json } catch { }
    }

    $requirements = @()
    if (Test-Path $requirementsPath) {
        $requirements = @(Get-Content $requirementsPath -ErrorAction SilentlyContinue)
    }
    elseif (Test-Path $pyprojectPath) {
        $requirements = @(Get-Content $pyprojectPath -ErrorAction SilentlyContinue)
    }

    $hasCsproj = @(Get-ChildItem -Path $RootPath -Recurse -Filter "*.csproj" -File -ErrorAction SilentlyContinue).Count -gt 0
    $hasSln = @(Get-ChildItem -Path $RootPath -Recurse -Filter "*.sln" -File -ErrorAction SilentlyContinue).Count -gt 0
    $csFiles = @(Get-ChildItem -Path $RootPath -Recurse -Filter "*.cs" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '([\\/]bin[\\/]|[\\/]obj[\\/])' })
    $tsJsFiles = @(Get-ChildItem -Path $RootPath -Recurse -Include "*.ts","*.js" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '([\\/]node_modules[\\/]|[\\/]dist[\\/]|[\\/]build[\\/])' })
    $pyFiles = @(Get-ChildItem -Path $RootPath -Recurse -Filter "*.py" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '([\\/]\.venv[\\/]|[\\/]__pycache__[\\/])' })
    $javaFiles = @(Get-ChildItem -Path $RootPath -Recurse -Filter "*.java" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch '([\\/]target[\\/]|[\\/]build[\\/])' })

    if ($hasCsproj -or $hasSln -or $csFiles.Count -gt 0) {
        $isCore = $false
        $isMvc5 = $false
        $hasWebSdk = $false

        # Check .csproj files for web SDK or ASP.NET Core packages
        $csprojFiles = Get-ChildItem -Path $RootPath -Recurse -Filter "*.csproj" -File -ErrorAction SilentlyContinue
        foreach ($csproj in $csprojFiles) {
            try {
                [xml]$csprojContent = Get-Content $csproj.FullName -Raw -ErrorAction SilentlyContinue
                if ($csprojContent -and $csprojContent.Project) {
                    $sdk = $csprojContent.Project.Sdk
                    if ($sdk -and $sdk -match 'Microsoft\.NET\.Sdk\.Web') {
                        $hasWebSdk = $true
                    }
                    # Check for PackageReference entries like Microsoft.AspNetCore.*
                    if ($csprojContent.Project.ItemGroup -and $csprojContent.Project.ItemGroup.PackageReference) {
                        foreach ($pkg in $csprojContent.Project.ItemGroup.PackageReference) {
                            if ($pkg.Include -and $pkg.Include -match '^Microsoft\.AspNetCore\.') {
                                $hasWebSdk = $true
                            }
                        }
                    }
                    # Check for AspNetCoreHostingModel
                    if ($csprojContent.Project.PropertyGroup -and $csprojContent.Project.PropertyGroup.AspNetCoreHostingModel) {
                        $hasWebSdk = $true
                    }
                }
            } catch { }
        }

        foreach ($file in ($csFiles | Select-Object -First 40)) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match '\[ApiController\]|MapControllers|WebApplication\.CreateBuilder') { $isCore = $true }
            if ($content -match 'System\.Web\.Mvc|Controller\s*:\s*Controller') { $isMvc5 = $true }
        }

        $hasCoreRouting = $false
        foreach ($file in ($csFiles | Select-Object -First 80)) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match '\[ApiController\]|MapControllers|WebApplication\.CreateBuilder|Map(Get|Post|Put|Delete|Patch)\(') {
                $hasCoreRouting = $true
                break
            }
        }

        if ($isCore -or ($hasWebSdk -and $hasCoreRouting)) {
            $record = $matrix | Where-Object { $_.framework -eq "ASP.NET Core" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
        if ($isMvc5) {
            $record = $matrix | Where-Object { $_.framework -eq "ASP.NET MVC 5" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
    }

    if (Get-Command Get-AppDocArchitectureFingerprint -ErrorAction SilentlyContinue) {
        $fingerprint = Get-AppDocArchitectureFingerprint -RootPath $RootPath
        $styles = @($fingerprint.styles)

        if ($styles -contains "wcf-service") {
            $record = $matrix | Where-Object { $_.framework -eq "WCF Services" } | Select-Object -First 1
            if ($record) { [void]$detections.Add($record) }
        }
        if ($styles -contains "asmx-service") {
            $record = $matrix | Where-Object { $_.framework -eq "ASMX Web Services" } | Select-Object -First 1
            if ($record) { [void]$detections.Add($record) }
        }
        if ($styles -contains "soap-client") {
            $record = $matrix | Where-Object { $_.framework -eq "SOAP Client Integrations" } | Select-Object -First 1
            if ($record) { [void]$detections.Add($record) }
        }
    }

    if ($packageJson) {
        $depNames = @()
        if ($packageJson.dependencies) { $depNames += @($packageJson.dependencies.PSObject.Properties.Name) }
        if ($packageJson.devDependencies) { $depNames += @($packageJson.devDependencies.PSObject.Properties.Name) }

        if ($depNames -contains "express" -or ($tsJsFiles | Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match 'app\.(get|post|put|delete)|router\.' } | Select-Object -First 1)) {
            $record = $matrix | Where-Object { $_.framework -eq "Express.js" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
    }

    if ($requirements.Count -gt 0 -or $pyFiles.Count -gt 0) {
        $reqText = ($requirements -join "`n")
        if ($reqText -match '(?im)^\s*flask' -or ($pyFiles | Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match '@app\.route' } | Select-Object -First 1)) {
            $record = $matrix | Where-Object { $_.framework -eq "Flask" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
        if ($reqText -match '(?im)^\s*fastapi' -or ($pyFiles | Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match '@router\.(get|post|put|delete|patch)' } | Select-Object -First 1)) {
            $record = $matrix | Where-Object { $_.framework -eq "FastAPI" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
        # Check for Django: recursively search for urls.py or check requirements
        $hasDjangoUrls = $null -ne (Get-ChildItem -Path $RootPath -Recurse -Filter "urls.py" -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($reqText -match '(?im)^\s*django' -or $hasDjangoUrls) {
            $record = $matrix | Where-Object { $_.framework -eq "Django" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
    }

    if ((Test-Path $pomPath) -or $javaFiles.Count -gt 0) {
        $pomContent = if (Test-Path $pomPath) { Get-Content $pomPath -Raw -ErrorAction SilentlyContinue } else { "" }
        $hasSpring = $pomContent -match 'spring-boot|spring-web' -or ($javaFiles | Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match '@RestController|@RequestMapping' } | Select-Object -First 1)
        if ($hasSpring) {
            $record = $matrix | Where-Object { $_.framework -eq "Spring Boot" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
    }

    $unique = $detections | Group-Object framework | ForEach-Object { $_.Group | Select-Object -First 1 }
    return @($unique)
}

Export-ModuleMember -Function @(
    'Get-AppDocFrameworkMatrix',
    'Get-AppDocDetectedFrameworks'
)
