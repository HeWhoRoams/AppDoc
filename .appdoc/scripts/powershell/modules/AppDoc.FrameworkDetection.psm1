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
        @{ language = "ASP (VBScript/JScript)"; framework = "Classic ASP"; supportLevel = "partial"; coveragePercent = 55; versionRange = "IIS / .NET Framework"; detectionSignals = @("*.asp", "*.aspx", "global.asa", "<!-- #include", "ADODB.Connection", "Provider=SQLOLEDB") },
        @{ language = "C#"; framework = "ASP.NET Web Forms"; supportLevel = "partial"; coveragePercent = 60; versionRange = ".NET Framework"; detectionSignals = @("*.aspx", "*.aspx.cs", "System.Web.UI.Page") },
        @{ language = "JavaScript/TypeScript"; framework = "Express.js"; supportLevel = "partial"; coveragePercent = 60; versionRange = "4.x"; detectionSignals = @("package.json:express", "app.get(", "router.") },
        @{ language = "Python"; framework = "Flask"; supportLevel = "partial"; coveragePercent = 65; versionRange = "2.x+"; detectionSignals = @("requirements.txt:flask", "@app.route", "app = Flask(", "create_app") },
        @{ language = "Python"; framework = "FastAPI"; supportLevel = "partial"; coveragePercent = 70; versionRange = "0.9+"; detectionSignals = @("requirements.txt:fastapi", "@router.get", "@app.get") },
        @{ language = "Python"; framework = "Python"; supportLevel = "partial"; coveragePercent = 40; versionRange = "3.x+"; detectionSignals = @("*.py", "requirements.txt", "pyproject.toml") },
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

    # Classic ASP / ASP.NET Web Forms detection (no .cs/.csproj gate -- these apps are
    # server-script .asp/.aspx pages, not C# projects). Probe file presence first (cheap),
    # then bound the content scan so a large tree stays fast.
    $aspExcl = '([\\/](fixtures|node_modules|bin|obj|dist|build|__pycache__|\.venv|target)[\\/])'
    $aspFiles = @(Get-ChildItem -Path $RootPath -Recurse -Filter "*.asp" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $aspExcl })
    $aspxFiles = @(Get-ChildItem -Path $RootPath -Recurse -Filter "*.aspx" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $aspExcl })
    $aspxCsFiles = @(Get-ChildItem -Path $RootPath -Recurse -Filter "*.aspx.cs" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $aspExcl })
    $hasGlobalAsa = $null -ne (Get-ChildItem -Path $RootPath -Recurse -Filter "global.asa" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $aspExcl } | Select-Object -First 1)
    $hasWebConfig = $null -ne (Get-ChildItem -Path $RootPath -Recurse -Filter "web.config" -File -ErrorAction SilentlyContinue | Where-Object { $_.FullName -notmatch $aspExcl } | Select-Object -First 1)

    if ($aspFiles.Count -gt 0 -or $aspxFiles.Count -gt 0 -or $hasGlobalAsa -or $aspxCsFiles.Count -gt 0) {
        # Classic ASP content signal: server-side VBScript/JScript + ADO + #include pages.
        $hasClassicAspContent = $false
        $classicSample = @($aspFiles | Select-Object -First 40)
        if ($classicSample.Count -eq 0 -and $aspxFiles.Count -gt 0) { $classicSample = @($aspxFiles | Select-Object -First 40) }
        foreach ($file in $classicSample) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match 'Server\.CreateObject|ADODB\.(Connection|Recordset)|<!--\s*#include|Provider\s*=\s*SQLOLEDB|Data Source\s*=|LANGUAGE\s*=\s*VBSCRIPT') {
                $hasClassicAspContent = $true
                break
            }
        }
        if (($aspFiles.Count -gt 0 -or $aspxFiles.Count -gt 0) -and ($hasClassicAspContent -or $hasGlobalAsa -or $hasWebConfig)) {
            $record = $matrix | Where-Object { $_.framework -eq "Classic ASP" } | Select-Object -First 1
            if ($record) { [void]$detections.Add($record) }
        }

        # ASP.NET Web Forms: .aspx with code-behind (.aspx.cs) or Page directive, and NOT
        # classic server-script (the single .aspx here is VBScript/ADODB classic ASP, so this
        # must stay false for it).
        $hasWebFormsContent = $false
        $webFormsSample = @($aspxFiles | Select-Object -First 40)
        foreach ($file in $webFormsSample) {
            $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
            if ($content -match 'System\.Web\.UI\.Page|Inherits\s*=|CodeBehind\s*=') {
                $hasWebFormsContent = $true
                break
            }
        }
        if ($aspxCsFiles.Count -gt 0 -or (($hasWebFormsContent) -and (-not $hasClassicAspContent))) {
            $record = $matrix | Where-Object { $_.framework -eq "ASP.NET Web Forms" } | Select-Object -First 1
            if ($record) { [void]$detections.Add($record) }
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
        # Flask: requirements.txt lists flask, OR a .py file carries a Flask web-app
        # signal -- @app.route / @<blueprint>.route (any blueprint name), a Flask
        # instance (app = Flask(...) / app = Flask()), or a create_app() application
        # factory. (Flask apps routinely use blueprints, so @app.route alone misses
        # real apps like FlaskCrud that route via @app_bp.route.)
        $hasFlaskSignal = ($pyFiles | Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match '@\w+\.route|=\s*Flask\(|\bcreate_app\b' } | Select-Object -First 1)
        if ($reqText -match '(?im)^\s*flask' -or $hasFlaskSignal) {
            $record = $matrix | Where-Object { $_.framework -eq "Flask" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
        # FastAPI: requirements.txt lists fastapi, OR a .py file carries a FastAPI
        # signal -- @app.get/post/... or @router.get/post/... route handlers.
        $hasFastApiSignal = ($pyFiles | Where-Object { (Get-Content $_.FullName -Raw -ErrorAction SilentlyContinue) -match '@(app|router)\.(get|post|put|delete|patch|options|head|trace)\b' } | Select-Object -First 1)
        if ($reqText -match '(?im)^\s*fastapi' -or $hasFastApiSignal) {
            $record = $matrix | Where-Object { $_.framework -eq "FastAPI" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
        # Check for Django: recursively search for urls.py or check requirements
        $hasDjangoUrls = $null -ne (Get-ChildItem -Path $RootPath -Recurse -Filter "urls.py" -File -ErrorAction SilentlyContinue | Select-Object -First 1)
        if ($reqText -match '(?im)^\s*django' -or $hasDjangoUrls) {
            $record = $matrix | Where-Object { $_.framework -eq "Django" } | Select-Object -First 1
            [void]$detections.Add($record)
        }
        # Generic Python fallback (ADDITIVE): if the target is a Python codebase (it
        # has .py files) but NO specific web framework was recognized above, emit a
        # generic "Python" record so the report is never left at "Unknown / not
        # detected" for a real Python app. It never fires on a non-Python target
        # (pyFiles is empty), so C# / classic-ASP / Node / Java targets are unchanged.
        if ($detections.Count -eq 0 -and $pyFiles.Count -gt 0) {
            $record = $matrix | Where-Object { $_.framework -eq "Python" } | Select-Object -First 1
            if ($record) { [void]$detections.Add($record) }
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
