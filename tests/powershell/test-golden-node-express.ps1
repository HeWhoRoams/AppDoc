# Golden-file structural regression test for the Node/Express (TypeScript) path.
#
# Purpose: prove the FRAMEWORK-AGNOSTIC AppDoc pipeline generalizes to a REALISTIC
# Node/Express + TypeScript target end-to-end. It runs the real run-all-generators
# pipeline on a small, deterministic Express fixture (tests/fixtures/node-express-sample)
# and asserts the framework-agnostic INVARIANTS (NOT a specific quality score -- the
# Node/Express regex path scores differently than classic ASP/C#, so structure is
# asserted, not a magic number):
#
#   * the pipeline exits 0 and produces docs/
#   * the target is classified as Express.js (a real Node/TS framework)
#   * the TypeScript AST path actually FIRED: ast-typescript-cache.json
#     (regex-fallback provider) parsed the TS and produced >=1 endpoint AND >=1 model
#     (the real evidence the generic api-inventory/data-model extractors generalize,
#     independent of the classic-ASP generator layer that runs later)
#   * the composed unified master carries the SAME 20-section spine as classic ASP
#   * the composed master + api-inventory appendix carry the REAL Express /api/tickets
#     routes (proving the extractor fired and content reaches the user-facing docs --
#     NOT an empty classic-ASP table)
#   * NO banned empty-artifact placeholder residue
#   * NO residual PowerShell garbage (0x `$(`, 0x `Format-AppDocCell`, 0x literal `$var`)
#   * REDACTION: the fixture's fake DB password is redacted -- ABSENT from every
#     generated artifact and `[REDACTED]` present in config-catalog.md
#   * HONEST FLOOR: no section is a truly-empty header; the doc carries an explicit
#     honest-uncertainty marker (Unknown status), not fabricated content
#   * a runnable gate (validation-report.json with a status)
#
# KNOWN GAP (documented, not asserted as pass): the per-artifact api-inventory.md
# PRIMARY table and data-model.md PRIMARY table are CLOBBERED empty by the classic-ASP
# generators (their framework gate short-circuits to a placeholder for non-ASP
# frameworks before the source-presence guard, which was designed for the C# Web Forms
# case). The Express routes still reach the appendix + composed master (both read the
# generic extractor's evidence). Fixing the clobber is in the 7 classic-ASP extractors
# (a separate concern). So this test asserts the routes where they ACTUALLY survive and
# asserts the gate RAN (status present), not that it passes.
#
# Convention matches the sibling Pester tests (copy fixture -> temp workRoot -> run ->
# assert). Run with:
#   pwsh -c 'Invoke-Pester -Path test-golden-node-express.ps1'
#
# PESTER v6.2.0 NOTES (hard-won, same as the siblings):
#   - File-scope $script: vars are NOT visible inside Describe/Context/It in v6. Every
#     shared constant (spine, banned patterns, paths, secret) is computed INSIDE
#     BeforeAll and stored as $script: there.
#   - $PSScriptRoot IS available in blocks. Use the dash form: `Should -Be`, `-Match`.

Describe "Golden-file structural regression: Node/Express (TypeScript) pipeline" {
    BeforeAll {
        # --- resolve paths from $PSScriptRoot (available in Pester blocks) -------
        $script:testsDir       = $PSScriptRoot
        $script:testsParent    = Split-Path $PSScriptRoot -Parent                    # AppDoc/tests
        $script:repoRoot       = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent # AppDoc
        $script:orchestrator   = Join-Path $script:repoRoot ".appdoc/scripts/powershell/run-all-generators.ps1"
        $script:fixtureRoot    = Join-Path $script:testsParent "fixtures/node-express-sample"
        $script:testOutputRoot = Join-Path $script:testsDir "test-output"

        # The fixture's single fake DB password. It MUST never survive redaction into
        # any generated artifact (the config-catalog extractor emits [REDACTED]).
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

        # The gate's banned empty-artifact placeholder patterns (from
        # AppDoc.Contracts.Get-AppDocBannedContentPatterns). A populated fixture must
        # contain NONE of these in its composed master.
        $script:BannedPatterns = @(
            '(?im)^##\s+Population Guide'
            '(?im)_No [^_]+ detected\.'
            '(?im)Describe the purpose and scope'
            '(?im)Provide example'
            '(?im)Refer to .* documentation\.'
        )

        # --- copy the fixture and run the real orchestrator on it ----------------
        # The temp copy always starts without docs/, so every run regenerates from
        # scratch. Scope exclusions (fixtures/samples/tests) are RELATIVE to
        # -RootPath, so the fixture files sit at the workRoot root and are NOT
        # excluded (this is exactly how the classic-ASP / C# goldens exercise theirs).
        $script:workRoot = Join-Path $script:testOutputRoot ("node-express-golden-" + [Guid]::NewGuid().ToString("N"))
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
            $script:lastRunExit | Should -Be 0 -Because "the pipeline must complete (report.html generation included) without crashing on a Node/TS target"
            (Test-Path $script:docs) | Should -Be $true
        }
        It "detects Express.js as the framework" {
            $fwPath = Join-Path $script:docs "framework-detection.json"
            (Test-Path $fwPath) | Should -Be $true
            (Get-Content $fwPath -Raw) | Should -Match "Express\.js" -Because "the fixture is an Express app (package.json has express); the pipeline must classify it as such"
        }
    }

    Context "The TypeScript AST path actually fired (regex fallback)" {
        It "produces ast-typescript-cache.json in regex-fallback mode with records" {
            $cachePath = Join-Path $script:docs "ast-typescript-cache.json"
            (Test-Path $cachePath) | Should -Be $true
            $cache = Get-Content $cachePath -Raw | ConvertFrom-Json
            ($cache.provider) | Should -Be "regex-fallback" -Because "no tsc/Node compiler bridge in CI; the TS path must fall back to regex"
            @($cache.records).Count | Should -BeGreaterThan 0 -Because "the regex TS parser must have extracted records from the fixture"
        }
        It "extracted at least one Express endpoint record" {
            $cache = Get-Content (Join-Path $script:docs "ast-typescript-cache.json") -Raw | ConvertFrom-Json
            $endpoints = @($cache.records | Where-Object { $_ -and [string]$_.kind -eq "endpoint" })
            $endpoints.Count | Should -BeGreaterThan 0 -Because "the router.get/post/delete routes in src/routes/tickets.ts must be found by the TS AST path"
        }
        It "extracts the CONTROLLER-IDIOM route (bare-identifier handler, not an inline function)" {
            # The fix under test: the shared Express endpoint regex must accept ANY handler
            # argument (an identifier / middleware call), not only an inline function literal.
            # The fixture's `router.get('/api/tickets/summary', requireAuth, getSummary)` uses a
            # bare-identifier handler (with leading middleware); before the fix it was missed.
            $cache = Get-Content (Join-Path $script:docs "ast-typescript-cache.json") -Raw | ConvertFrom-Json
            $summary = @($cache.records | Where-Object {
                $_ -and [string]$_.kind -eq "endpoint" -and
                ([string]$_.metadata.path -eq "/api/tickets/summary") -and
                ([string]$_.metadata.method -eq "GET")
            })
            $summary.Count | Should -Be 1 -Because "the controller-idiom route /api/tickets/summary must be extracted exactly once (the multi-middleware route is counted once)"
            $summary[0].metadata.controller | Should -Be "getSummary" -Because "the LAST argument of `requireAuth, getSummary` is the real controller function and must be captured (not the middleware)"
        }
        It "extracted at least one model (the exported Ticket interface)" {
            $cache = Get-Content (Join-Path $script:docs "ast-typescript-cache.json") -Raw | ConvertFrom-Json
            $models = @($cache.records | Where-Object { $_ -and [string]$_.kind -eq "model" })
            $models.Count | Should -BeGreaterThan 0 -Because "the `export interface Ticket` in src/models/Ticket.ts must be found by the TS AST path"
        }
    }

    Context "application-documentation.md (unified master) carries the real Express content" {
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
                throw "Missing $($missing.Count)/20 spine headings in application-documentation.md: $($missing -join ', ')"
            }
            $true | Should -Be $true
        }
        It "carries the real Express /api/tickets routes (proves no clobber of the user-facing doc)" {
            $master = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $master | Should -Match ([regex]::Escape("/api/tickets")) -Because "the generic extractor's Express routes must reach the composed master (evidence-driven), not an empty classic-ASP table"
            $master | Should -Match ([regex]::Escape("src/routes/tickets.ts")) -Because "the route must cite its real source file"
        }
        It "has no banned empty-artifact placeholder residue" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $hits = @($script:BannedPatterns | Where-Object { [regex]::IsMatch($content, $_) })
            $hits.Count | Should -Be 0 -Because "unified master must not carry banned/empty placeholders"
        }
        It "has no residual PowerShell garbage (dollar-paren, Format-AppDocCell, literal dollar-var)" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $dollarParens = ([regex]::Matches($content, '\$\(')).Count
            $cleanCell    = ([regex]::Matches($content, 'Format-AppDocCell')).Count
            $literalVar   = ([regex]::Matches($content, '\$[A-Za-z_]\w*')).Count
            if ($dollarParens -gt 0 -or $cleanCell -gt 0 -or $literalVar -gt 0) {
                throw "PowerShell garbage leaked into the composed doc: dollar-paren=$dollarParens, Format-AppDocCell=$cleanCell, dollar-var=$literalVar"
            }
            $true | Should -Be $true
        }
    }

    Context "External Call Register (§9.4) is populated with the real outbound ITSM call" {
        It "shows a real outbound call row in §9.4 (not the honest-NDA fallback)" {
            $master = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $s94 = ([regex]::Match($master, '(?s)### 9\.4 HTTP / XML endpoints.*?(?=### 9\.5)')).Value
            ($s94 -match 'fetch\(\)') | Should -Be $true -Because "the generic extractor must surface the src/services/itsm.ts fetch() outbound call site"
            ($s94 -match 'src/services/itsm\.ts') | Should -Be $true -Because "the §9.4 row must cite its real source file"
            ($s94 -match '(?m)^\|\s*HTTP-01\s*\|') | Should -Be $true -Because "§9.4 must carry a real outbound row (not the 'none detected' honest-NDA fallback)"
        }
        It "writes the external-call artifact (extcalls.md) with the real row at file:line" {
            $ext = Join-Path $script:docs "extcalls.md"
            (Test-Path $ext) | Should -Be $true
            $content = Get-Content $ext -Raw
            ($content -match 'src/services/itsm\.ts') | Should -Be $true -Because "extcalls.md must cite the real fetch call site file"
            ($content -match 'line 13') | Should -Be $true -Because "extcalls.md must cite the real fetch call site line (line 13)"
            ($content -match 'support\.internal/itsm/api') | Should -Be $true -Because "the real ITSM base URL is cited as Inferred (never fabricated)"
        }
    }

    Context "api-inventory appendix (the full Express endpoint catalog)" {
        It "lists the Express /api/tickets routes as endpoint rows" {
            $appendix = Join-Path $script:docs "api-inventory.appendix.md"
            (Test-Path $appendix) | Should -Be $true
            $content = Get-Content $appendix -Raw
            $content | Should -Match ([regex]::Escape("/api/tickets")) -Because "the appendix is the generic extractor's full endpoint catalog; it must carry the Express routes"
        }
    }

    Context "Honest floor (no fabricated content, no truly-empty sections)" {
        It "has no H2 section that is completely empty (a header implying rows but none)" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $chunks = [regex]::Split($content, "(?m)^##\s+")
            $empty = @()
            foreach ($chunk in @($chunks | Select-Object -Skip 1)) {
                $lines = @($chunk -split "`n")
                $hasContent = $false
                foreach ($ln in $lines) { if ($ln.Trim()) { $hasContent = $true; break } }
                if (-not $hasContent) { $empty += ($lines | Select-Object -First 1 | ForEach-Object { $_.Trim() }) }
            }
            if ($empty.Count -gt 0) {
                throw "Empty H2 section(s) (header implies content but has none): $($empty -join ', ')"
            }
            $true | Should -Be $true
        }
        It "carries an explicit honest-uncertainty marker (Unknown status), not fabricated certainty" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            ($content -match '(?i)\bUnknown\b') | Should -Be $true -Because "the tiny fixture cannot ground every claim; the doc must carry an honest Unknown floor rather than fabricate"
        }
    }

    Context "Redaction (the fixture's fake DB password must be redacted)" {
        It "does not leak the fixture secret into ANY generated artifact (md/html/json)" {
            $leaks = @()
            $files = @(Get-ChildItem -Path $script:docs -Recurse -File -Include "*.md","*.html","*.json" -ErrorAction SilentlyContinue)
            foreach ($f in $files) {
                $raw = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($raw -and $raw.Contains($script:FixtureSecret)) { $leaks += $f.Name }
            }
            if ($leaks.Count -gt 0) {
                throw "Fixture secret '$($script:FixtureSecret)' leaked into: $($leaks -join ', ')"
            }
            $true | Should -Be $true
        }
        It "emits [REDACTED] in config-catalog.md (the .env password is redacted, not dropped)" {
            $cc = Get-Content (Join-Path $script:docs "config-catalog.md") -Raw
            ($cc -match '\[REDACTED\]') | Should -Be $true -Because "the .env DB_PASSWORD must be redacted to [REDACTED]"
        }
        It "still surfaces a real, non-secret .env config key (DB_HOST)" {
            $cc = Get-Content (Join-Path $script:docs "config-catalog.md") -Raw
            ($cc -match 'DB_HOST') | Should -Be $true -Because "the non-secret config key proves the .env was genuinely parsed for the Node target"
        }
    }

    Context "Runnable gate (structural soundness, not a magic score)" {
        It "produces a runnable gate (validation-report.json with a status)" {
            $repPath = Join-Path $script:docs "validation-report.json"
            (Test-Path $repPath) | Should -Be $true
            $raw = Get-Content $repPath -Raw
            $rep = $raw | ConvertFrom-Json
            $rep.status | Should -Not -BeNullOrEmpty -Because "the gate must have RAN on the Node/Express target. The tiny fixture intentionally scores a policy block (api-endpoints-table-empty -- the classic-ASP clobber gap), so we assert the gate RAN, not that it passes."
        }
    }
}
