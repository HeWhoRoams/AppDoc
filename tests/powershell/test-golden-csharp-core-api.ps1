# Golden-file structural regression test for the ASP.NET Core Web API path.
#
# Purpose: prove the FRAMEWORK-AGNOSTIC AppDoc pipeline generalizes end-to-end to a
# realistic ASP.NET Core Web API target (the canonical modern .NET shape: Program.cs
# minimal hosting + [ApiController] controllers + ADO + appsettings.json + csproj).
# This is the CORE analog of test-golden-csharp-webforms.ps1 (which covers the
# Web Forms shape). It runs the real run-all-generators pipeline on a small,
# deterministic fixture (tests/fixtures/csharp-core-api-sample) and asserts the
# framework-agnostic INVARIANTS -- structure, NOT a magic score (the C# regex path
# scores differently than classic ASP, so structure is asserted, not a number):
#
#   * pipeline exits 0 and produces docs/
#   * the target is classified as ASP.NET Core (a real C# framework)
#   * the C# AST path FIRED: ast-csharp-cache.json (regex-fallback, no .NET SDK in CI)
#     parsed the [ApiController] controllers and produced >=1 /api/ endpoint record
#   * the composed unified master carries the SAME 20-section spine as the siblings
#   * NO banned empty-artifact placeholder residue, NO residual PowerShell garbage
#   * HONEST FLOOR: no truly-empty H2 section; an explicit honest-Unknown marker present
#   * REDACTION: the fixture's fake DB credential is redacted (ABSENT from every
#     artifact; [REDACTED] present) and a real non-secret config key is still surfaced
#   * NO-CLOBBER (honest, evidence-based): the Core endpoints SURVIVE the pipeline in
#     the api-inventory APPENDIX + the evidence record (Record Count). The full
#     endpoint catalog is the C#-path appendix, NOT an empty classic-ASP .asp/SQLOLEDB
#     table.
#   * a runnable gate (validation-report.json with a status)
#
# KNOWN CORE-PATH GAP (asserted honestly, NOT gamed):
#   The main api-inventory.md's "API Endpoints" section + its
#   [API Inventory Appendix] link are CLOBBERED by generate-classic-asp-endpoints.ps1
#   on a non-classic-ASP target (its "framework not applicable" branch writes a
#   placeholder unconditionally; the source-presence yield-guard only covers the
#   framework-applicable branch). That is a Core-path gap in the (protected) classic-ASP
#   extractors, so the gate reports status=fail at overallScore ~90 via the policy
#   blocks api-endpoints-table-empty + api-appendix-link-missing. We therefore assert
#   the endpoints are preserved in the APPENDIX + evidence (the real C# content) and
#   that the gate RAN, mirroring the sibling tests -- we do NOT assert a gate pass.
#
# Convention matches the sibling Pester tests (copy fixture -> temp workRoot -> run ->
# assert). Run with:
#   pwsh -c 'Invoke-Pester -Path test-golden-csharp-core-api.ps1'
#
# PESTER v6.2.0 NOTES (hard-won): file-scope $script: vars are NOT visible inside
# Describe/Context/It blocks -- compute every shared constant INSIDE BeforeAll and
# store it as $script: there. $PSScriptRoot IS available. Use the dash assertion form.

Describe "Golden-file structural regression: C# / ASP.NET Core Web API pipeline" {
    BeforeAll {
        # --- resolve paths from $PSScriptRoot (available in Pester blocks) -------
        $script:testsDir       = $PSScriptRoot
        $script:testsParent    = Split-Path $PSScriptRoot -Parent                    # AppDoc/tests
        $script:repoRoot       = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent # AppDoc
        $script:orchestrator   = Join-Path $script:repoRoot ".appdoc/scripts/powershell/run-all-generators.ps1"
        $script:fixtureRoot    = Join-Path $script:testsParent "fixtures/csharp-core-api-sample"
        $script:testOutputRoot = Join-Path $script:testsDir "test-output"

        # The fixture's single fake DB credential. It MUST never survive redaction
        # into any generated artifact (the config extractor emits [REDACTED]).
        $script:FixtureSecret = "FakeP@ss123"

        # The benchmark's 20-section spine. MUST stay in sync with
        # Get-SectionSpineCoverageScore in validate-documentation.ps1; the assertion
        # below counts headings exactly the way that function does.
        $script:Spine = @(
            "Application Index"
            "Coverage and Executive Overview"
            "Architecture"
            "Functional Inventory"
            "Roles and Access Model"
            "UI Catalog"
            "Operational Workflows"
            "Data and Integrations"
            "External Call Register"
            "Stored-procedure data dictionary"
            "Troubleshooting Matrix"
            "Security and Operational Risks"
            "Ownership and Maintenance"
            "Architecture and Data-Flow Diagrams"
            "Glossary"
            "Evidence Register"
            "Open Questions and Documentation Gaps"
            "Recommendations"
            "Operations Runbook"
            "Verification Appendix"
        )

        # The gate's banned empty-artifact placeholder patterns.
        $script:BannedPatterns = @(
            '(?im)^##\s+Population Guide'
            '(?im)Describe the purpose and scope'
            '(?im)Provide example'
            '(?im)Refer to .* documentation\.'
        )

        # --- copy the fixture and run the real orchestrator on it ----------------
        # The temp copy always starts without docs/, so every run regenerates from
        # scratch. Scope exclusions (fixtures/samples/tests) are RELATIVE to -RootPath,
        # so fixture files sit at the root here and are NOT excluded (exactly how the
        # sibling golden tests exercise their fixtures).
        $script:workRoot = Join-Path $script:testOutputRoot ("csharp-core-golden-" + [Guid]::NewGuid().ToString("N"))
        Copy-Item -Path $script:fixtureRoot -Destination $script:workRoot -Recurse -Force
        & $script:orchestrator -RootPath $script:workRoot *> $null
        $script:lastRunExit = $LASTEXITCODE
        $script:docs = Join-Path $script:workRoot "docs"
    }

    AfterAll {
        if ($script:workRoot -and (Test-Path $script:workRoot)) {
            try { Remove-Item -Path $script:workRoot -Recurse -Force -ErrorAction Stop } catch {}
        }
    }

    Context "Pipeline execution" {
        It "exits 0 and produces a docs/ directory" {
            $script:lastRunExit | Should -Be 0 -Because "the pipeline must complete on an ASP.NET Core target"
            (Test-Path $script:docs) | Should -Be $true
        }
        It "classifies the target as ASP.NET Core" {
            $fwPath = Join-Path $script:docs "framework-detection.json"
            (Test-Path $fwPath) | Should -Be $true
            (Get-Content $fwPath -Raw) | Should -Match "ASP\.NET Core" -Because "the fixture is a [ApiController] Core Web API; the pipeline must classify it as such"
        }
    }

    Context "The C# AST path actually fired (regex fallback)" {
        It "produces ast-csharp-cache.json in regex-fallback mode with records" {
            $cachePath = Join-Path $script:docs "ast-csharp-cache.json"
            (Test-Path $cachePath) | Should -Be $true
            $cache = Get-Content $cachePath -Raw | ConvertFrom-Json
            ($cache.provider) | Should -Be "regex-fallback" -Because "no .NET SDK in CI; the C# path must fall back to regex"
            @($cache.records).Count | Should -BeGreaterThan 0
        }
        It "extracted >=1 C# endpoint record with an /api/ controller path" {
            $cache = Get-Content (Join-Path $script:docs "ast-csharp-cache.json") -Raw | ConvertFrom-Json
            $endpoints = @($cache.records | Where-Object { $_ -and [string]$_.kind -eq "endpoint" })
            $endpoints.Count | Should -BeGreaterThan 0
            $apiEps = @($endpoints | Where-Object { [string]$_.metadata.path -match '/api/' })
            $apiEps.Count | Should -BeGreaterThan 0 -Because "the [HttpGet]/[HttpPost] [ApiController] endpoints must be found by the C# AST path"
        }
    }

    Context "Modern ASP.NET Core idioms are extracted (the 4 pinned gaps)" {
        # These pin the four shapes the C# Core extractor historically DROPPED. Each
        # asserts the composed REAL HTTP path (controller [Route("api/v1/[controller]")]
        # composed with the method path) and the class-level [Authorize] auth boundary.
        # All come from the new OrdersController fixture ([ApiController] + class
        # [Authorize] + class [Route("api/v1/[controller]")]).
        BeforeAll {
            $script:ordersCache = Get-Content (Join-Path $script:docs "ast-csharp-cache.json") -Raw | ConvertFrom-Json
            $script:ordersEps = @(
                $script:ordersCache.records |
                Where-Object { $_ -and [string]$_.kind -eq "endpoint" -and [string]$_.file -match 'Orders' }
            )
        }
        It "extracts a named route [HttpGet(Name = nameof(...))] (Gap 1) as a real composed path" {
            # [HttpGet(Name = nameof(ListOrders))] has NO explicit path -> the composed
            # path is the controller route + the method name: /api/v1/Orders/ListOrders.
            $hit = @($script:ordersEps | Where-Object { ([string]$_.metadata.method) -eq "GET" -and ([string]$_.metadata.path) -match '/api/v1/Orders/ListOrders' })
            $hit.Count | Should -BeGreaterThan 0 -Because "a [HttpGet(Name = nameof(...))] named route (no explicit path) must be extracted at its composed /api/v1/Orders/ListOrders"
        }
        It "extracts [HttpGet(`"{id}`", Name = nameof(...))] (Gap 1 + Gap 3) preserving the {id} segment" {
            # [HttpGet("{id}", Name = nameof(GetOrder))] composes to /api/v1/Orders/{id}
            # (the [controller] template resolved + the {id} segment kept).
            $hit = @($script:ordersEps | Where-Object { ([string]$_.metadata.method) -eq "GET" -and ([string]$_.metadata.path) -match '/api/v1/Orders/\{id\}' })
            $hit.Count | Should -BeGreaterThan 0 -Because "[HttpGet(`"{id}`", Name=...)] must extract at /api/v1/Orders/{id} (segment preserved, template composed)"
        }
        It "extracts a bare [HttpPost] (Gap 2) with a conventional composed path" {
            # [HttpPost] with NO explicit path -> conventional /api/v1/Orders/CreateOrder.
            $hit = @($script:ordersEps | Where-Object { ([string]$_.metadata.method) -eq "POST" -and ([string]$_.metadata.path) -match '/api/v1/Orders/CreateOrder' })
            $hit.Count | Should -BeGreaterThan 0 -Because "a bare [HttpPost] (no explicit path) must synthesize the conventional /api/v1/Orders/CreateOrder path instead of being dropped"
        }
        It "composes the controller-level [Route(`"api/v1/[controller]`")] template into every Orders path (Gap 3)" {
            # Every Orders endpoint must carry the /api/v1/Orders prefix (the resolved
            # [controller] template); none may render a raw method-relative path.
            $raw = @($script:ordersEps | Where-Object { ([string]$_.metadata.path) -notmatch '^/api/v1/Orders' })
            $raw.Count | Should -Be 0 -Because "every [Route(`"api/v1/[controller]`")] controller endpoint must carry the composed /api/v1/Orders prefix (no raw /{id}, /login, /me)"
        }
        It "propagates the class-level [Authorize] to the Orders endpoints' auth (Gap 4)" {
            # OrdersController has a class-level [Authorize] (no [AllowAnonymous] on the
            # three methods) -> every Orders endpoint's auth boundary must be non-None.
            $nonAuthed = @($script:ordersEps | Where-Object { ([string]$_.metadata.auth) -match '^(None|Public)' })
            $nonAuthed.Count | Should -Be 0 -Because "a class-level [Authorize] controller must have its endpoints' auth boundary propagated (not None/Public)"
        }
    }

    Context "application-documentation.md (unified master)" {
        It "exists" {
            (Test-Path (Join-Path $script:docs "application-documentation.md")) | Should -Be $true
        }
        It "contains all 20 spine headings, counted the way the gate does" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $missing = @()
            foreach ($title in $script:Spine) {
                $pattern = ('(?im)^#{1,6}\s+(?:\d{1,2}[A-Za-z]?\s*[.:]\s*)?' + [regex]::Escape($title) + '\b')
                if ($content -notmatch $pattern) { $missing += $title }
            }
            if ($missing.Count -gt 0) {
                throw "Missing $($missing.Count)/20 spine headings: $($missing -join ', ')"
            }
            $true | Should -Be $true
        }
        It "has no banned empty-artifact placeholder residue" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $hits = @($script:BannedPatterns | Where-Object { [regex]::IsMatch($content, $_) })
            $hits.Count | Should -Be 0
        }
        It "has no residual PowerShell garbage (dollar-paren, Clean-Cell, literal dollar-var)" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $dollarParens = ([regex]::Matches($content, '\$\(')).Count
            $cleanCell    = ([regex]::Matches($content, 'Clean-Cell')).Count
            $literalVar   = ([regex]::Matches($content, '\$[A-Za-z_]\w*')).Count
            if ($dollarParens -gt 0 -or $cleanCell -gt 0 -or $literalVar -gt 0) {
                throw "PowerShell garbage leaked: dollar-paren=$dollarParens, Clean-Cell=$cleanCell, dollar-var=$literalVar"
            }
            $true | Should -Be $true
        }
    }

    Context "Honest floor (no fabricated content, no truly-empty sections)" {
        It "has no H2 section that is completely empty" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $chunks = [regex]::Split($content, "(?m)^##\s+")
            $empty = @()
            foreach ($chunk in @($chunks | Select-Object -Skip 1)) {
                $lines = @($chunk -split "`n")
                $hasContent = $false
                foreach ($ln in $lines) { if ($ln.Trim()) { $hasContent = $true; break } }
                if (-not $hasContent) { $empty += ($lines | Select-Object -First 1 | ForEach-Object { $_.Trim() }) }
            }
            if ($empty.Count -gt 0) { throw "Empty H2 section(s): $($empty -join ', ')" }
            $true | Should -Be $true
        }
        It "carries an explicit honest-uncertainty marker (Unknown), not fabricated certainty" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            ($content -match '(?i)\bUnknown\b') | Should -Be $true
        }
    }

    Context "Redaction (the C# credential must be redacted)" {
        It "does not leak the fixture secret into ANY generated artifact (md/html/json)" {
            $leaks = @()
            $files = @(Get-ChildItem -Path $script:docs -Recurse -File -Include "*.md","*.html","*.json" -ErrorAction SilentlyContinue)
            foreach ($f in $files) {
                $raw = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($raw -and $raw.Contains($script:FixtureSecret)) { $leaks += $f.Name }
            }
            if ($leaks.Count -gt 0) { throw "Secret '$($script:FixtureSecret)' leaked into: $($leaks -join ', ')" }
            $true | Should -Be $true
        }
        It "emits [REDACTED] in config-catalog.md (the connection string is redacted, not dropped)" {
            (Get-Content (Join-Path $script:docs "config-catalog.md") -Raw) | Should -Match '\[REDACTED\]'
        }
        It "still surfaces the real, non-secret appsettings key (HelpDesk.LogLevel)" {
            (Get-Content (Join-Path $script:docs "config-catalog.md") -Raw) | Should -Match 'HelpDesk[.]LogLevel'
        }
    }

    Context "No-clobber: the Core endpoints survive the pipeline (evidence-based)" {
        It "produces api-inventory.md and api-inventory.appendix.md without crashing" {
            (Test-Path (Join-Path $script:docs "api-inventory.md")) | Should -Be $true
            (Test-Path (Join-Path $script:docs "api-inventory.appendix.md")) | Should -Be $true
        }
        It "preserves the Core endpoints in the C# appendix (not an empty classic-ASP table)" {
            # The full C# endpoint catalog lives in api-inventory.appendix.md. Assert the
            # fixture's /api/tickets + /api/status endpoints are actually there, which
            # proves the C# extractor's output was NOT replaced by a classic-ASP .asp/
            # SQLOLEDB table (the clobber the framework-agnostic layer must avoid).
            $appendix = Get-Content (Join-Path $script:docs "api-inventory.appendix.md") -Raw
            ($appendix -match '/api/tickets') | Should -Be $true -Because "GET /api/tickets must be in the C# appendix"
            ($appendix -match '/api/status') | Should -Be $true -Because "GET /api/status (the HttpClient controller) must be in the C# appendix"
        }
        It "the main api-inventory.md is NOT a classic-ASP clobber table" {
            $main = Get-Content (Join-Path $script:docs "api-inventory.md") -Raw
            # The classic-ASP generator must NOT have written an .asp/SQLOLEDB endpoint
            # table into the shared artifact.
            ($main -notmatch 'SQLOLEDB|ADODB\.Connection|\.asp\b') | Should -Be $true -Because "no classic-ASP source on a Core target, so no classic-ASP endpoint table may clobber the C# artifact"
        }
    }

    Context "C#-derivable artifacts + a runnable gate" {
        It "produces data-model.md and config-catalog.md without crashing" {
            (Test-Path (Join-Path $script:docs "data-model.md")) | Should -Be $true
            (Test-Path (Join-Path $script:docs "config-catalog.md")) | Should -Be $true
        }
        It "produces a runnable gate (validation-report.json with a status)" {
            $repPath = Join-Path $script:docs "validation-report.json"
            (Test-Path $repPath) | Should -Be $true
            $rep = Get-Content $repPath -Raw | ConvertFrom-Json
            $rep.status | Should -Not -BeNullOrEmpty -Because "the gate must have RAN on the Core target; the tiny fixture + the known main-artifact clobber gap intentionally score below a full-app pass, so we assert it ran (not that it passes)"
        }
    }
}
