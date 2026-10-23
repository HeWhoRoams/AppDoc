# Golden-file structural regression test for the C# / ASP.NET Web Forms path.
#
# Purpose: prove the FRAMEWORK-AGNOSTIC AppDoc composer generalizes to a REALISTIC
# C# target end-to-end. It runs the real run-all-generators pipeline on a small,
# deterministic ASP.NET Web Forms fixture (tests/fixtures/csharp-webforms-sample)
# and asserts the framework-agnostic INVARIANTS (NOT a specific quality score --
# the C# regex path scores differently than classic ASP, so structure is asserted,
# not a magic number):
#
#   * the pipeline exits 0 and produces docs/
#   * the target is classified as ASP.NET Web Forms (a real C# framework)
#   * the composed unified master carries the SAME 20-section spine as classic ASP
#   * NO banned empty-artifact placeholder residue
#   * NO residual PowerShell garbage (0x `$(`, 0x `Format-AppDocCell`, 0x literal `$var`)
#   * REDACTION: the fixture's fake DB credential is redacted -- it is ABSENT from
#     every generated artifact and `[REDACTED]` is present in config-catalog.md
#   * HONEST FLOOR: no section is a truly-empty header; the doc carries an explicit
#     honest-uncertainty marker (Unknown status), not fabricated content
#   * the C# AST path actually FIRED: ast-csharp-cache.json shows the
#     regex-fallback provider parsed the C# and produced >=1 endpoint record
#     (this is the real evidence the C# extractor generalizes, independent of the
#     classic-ASP generator layer that runs later)
#
# Convention matches the sibling Pester test test-golden-classic-asp.ps1 (copy
# fixture -> temp workRoot -> run -> assert). Run with:
#   pwsh -c 'Invoke-Pester -Path test-golden-csharp-webforms.ps1'
#   or:      Invoke-Pester -FullNameFilter *Golden*CSharp*WebForms*
#
# PESTER v6.2.0 NOTES (hard-won):
#   - File-scope $script: variables are NOT visible inside Describe/Context/It
#     blocks in v6. Every shared constant (spine, banned patterns, paths, secret)
#     is computed INSIDE BeforeAll and stored as $script: there.
#   - $PSScriptRoot (automatic) IS available in blocks.
#   - Use the dash assertion form: `Should -Be`, `Should -Match -Because`.

Describe "Golden-file structural regression: C# / ASP.NET Web Forms pipeline" {
    BeforeAll {
        # --- resolve paths from $PSScriptRoot (available in Pester blocks) -------
        $script:testsDir       = $PSScriptRoot
        $script:testsParent    = Split-Path $PSScriptRoot -Parent                    # AppDoc/tests
        $script:repoRoot       = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent # AppDoc
        $script:orchestrator   = Join-Path $script:repoRoot ".appdoc/scripts/powershell/run-all-generators.ps1"
        $script:fixtureRoot    = Join-Path $script:testsParent "fixtures/csharp-webforms-sample"
        $script:testOutputRoot = Join-Path $script:testsDir "test-output"

        # The fixture's single fake DB credential. It MUST never survive redaction
        # into any generated artifact (the config extractor emits [REDACTED]).
        $script:FixtureSecret = "FakeP@ss123"

        # The benchmark's 20-section spine. MUST stay in sync with
        # Get-SectionSpineCoverageScore in validate-documentation.ps1 (lines 955-976);
        # the assertion below counts headings exactly the way that function does.
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
        # AppDoc.Contracts.Get-AppDocBannedContentPatterns). A populated fixture
        # must contain NONE of these in its artifacts.
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
        # -RootPath, so fixture files sit at the root here and are NOT excluded
        # (this is exactly how the classic-ASP golden test exercises its fixture).
        $script:workRoot = Join-Path $script:testOutputRoot ("csharp-webforms-golden-" + [Guid]::NewGuid().ToString("N"))
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
            $script:lastRunExit | Should -Be 0 -Because "the composer must not crash on a C# target"
            (Test-Path $script:docs) | Should -Be $true
        }
        It "detects ASP.NET Web Forms as the framework" {
            $fwPath = Join-Path $script:docs "framework-detection.json"
            (Test-Path $fwPath) | Should -Be $true
            (Get-Content $fwPath -Raw) | Should -Match "ASP\.NET Web Forms" -Because "the fixture is a C# Web Forms app; the pipeline must classify it as such"
        }
    }

    Context "The C# AST path actually fired (regex fallback)" {
        It "produces ast-csharp-cache.json in regex-fallback mode with records" {
            $cachePath = Join-Path $script:docs "ast-csharp-cache.json"
            (Test-Path $cachePath) | Should -Be $true
            $cache = Get-Content $cachePath -Raw | ConvertFrom-Json
            ($cache.provider) | Should -Be "regex-fallback" -Because "no .NET SDK in CI; the C# path must fall back to regex"
            @($cache.records).Count | Should -BeGreaterThan 0 -Because "the regex C# parser must have extracted records from the fixture"
        }
        It "extracted at least one C# endpoint record" {
            $cache = Get-Content (Join-Path $script:docs "ast-csharp-cache.json") -Raw | ConvertFrom-Json
            $endpoints = @($cache.records | Where-Object { $_ -and [string]$_.kind -eq "endpoint" })
            $endpoints.Count | Should -BeGreaterThan 0 -Because "the [HttpGet]/[HttpPost] C# endpoints in the fixture must be found by the C# AST path"
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
                throw "Missing $($missing.Count)/20 spine headings in application-documentation.md: $($missing -join ', ')"
            }
            $true | Should -Be $true
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

    Context "Honest floor (no fabricated content, no truly-empty sections)" {
        It "has no H2 section that is completely empty (a header implying rows but none)" {
            $content = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            # Split on each H2 (##) heading; each chunk (from one heading to the next)
            # must contain at least one non-whitespace content line.
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

    Context "Redaction (the C# credential must be redacted)" {
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
        It "emits [REDACTED] in config-catalog.md (the connection string is redacted, not dropped)" {
            $cc = Get-Content (Join-Path $script:docs "config-catalog.md") -Raw
            ($cc -match '\[REDACTED\]') | Should -Be $true -Because "the web.config connection string must be redacted to [REDACTED]"
        }
        It "still surfaces the real, non-secret web.config appSettings key (HelpDesk.LogLevel)" {
            $cc = Get-Content (Join-Path $script:docs "config-catalog.md") -Raw
            ($cc -match 'HelpDesk[.]LogLevel') | Should -Be $true -Because "the non-secret config key proves web.config was genuinely parsed for the C# target"
        }
    }

    Context "C#-derivable artifacts exist (no crash, structure present)" {
        It "produces api-inventory.md and data-model.md without crashing" {
            (Test-Path (Join-Path $script:docs "api-inventory.md")) | Should -Be $true
            (Test-Path (Join-Path $script:docs "data-model.md")) | Should -Be $true
        }
        It "produces a runnable gate (validation-report.json with a status)" {
            $repPath = Join-Path $script:docs "validation-report.json"
            (Test-Path $repPath) | Should -Be $true
            $raw = Get-Content $repPath -Raw
            $rep = $raw | ConvertFrom-Json
            $rep.status | Should -Not -BeNullOrEmpty -Because "the gate must have RAN on the C# target; the tiny fixture intentionally scores below the full-app threshold, so we assert it ran, not that it passes"
        }
    }
}
