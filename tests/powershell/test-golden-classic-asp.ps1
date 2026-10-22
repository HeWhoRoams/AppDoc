# Golden-file structural regression test for the classic-ASP pipeline.
#
# Purpose: verify the pipeline's STRUCTURAL invariants on a small, deterministic,
# fast classic-ASP fixture (AppDoc/tests/fixtures/classic-asp-sample). This is NOT
# an exact byte-match golden file (too brittle) and NOT a re-run of the 16k-file
# helpweb target (too slow for CI). It runs the real run-all-generators pipeline on
# the fixture in a fresh temp copy and asserts the expected docs land with the right
# structure: all 20 spine headings, the 5 .asp endpoints, the fixture DB/table/proc,
# the web.config appSettings key, the evidence/verification rows, the themed HTML,
# and a runnable gate -- with no empty-artifact placeholder residue.
#
# Convention matches the sibling Pester tests (copy fixture -> temp workRoot -> run ->
# assert). Run with:
#   pwsh -c 'Invoke-Pester -Path test-golden-classic-asp.ps1'
#   or:      Invoke-Pester -FullNameFilter *Golden*ClassicAsp*
#
# PESTER v6.2.0 NOTES (hard-won):
#   - File-scope $script: variables are NOT visible inside Describe/Context/It blocks
#     in v6 (v5 could see them). So every shared constant (spine, banned patterns,
#     paths) is computed INSIDE BeforeAll and stored as $script: there.
#   - $PSScriptRoot (automatic) IS available in blocks; $script: vars set in
#     BeforeAll ARE visible in It blocks.
#   - Use the dash assertion form: `Should -Be`, `Should -Match -Because`,
#     `Should -Not -BeNullOrEmpty`.

Describe "Golden-file structural regression: classic-ASP pipeline" {
    BeforeAll {
        # --- resolve paths from $PSScriptRoot (available in Pester blocks) -------
        $script:testsDir       = $PSScriptRoot
        $script:testsParent    = Split-Path $PSScriptRoot -Parent                    # AppDoc/tests
        $script:repoRoot       = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent # AppDoc
        $script:orchestrator   = Join-Path $script:repoRoot ".appdoc/scripts/powershell/run-all-generators.ps1"
        $script:fixtureRoot    = Join-Path $script:testsParent "fixtures/classic-asp-sample"
        $script:testOutputRoot = Join-Path $script:testsDir "test-output"

        # The benchmark's 20-section spine. MUST stay in sync with
        # Get-SectionSpineCoverageScore in validate-documentation.ps1 (lines 955-976);
        # the test below counts headings exactly the way that function does.
        $script:Spine = @(
            "Application Index"
            "Coverage and Executive Overview"
            "Architecture"
            "Functional Inventory"
            "Roles and Access Model"
            "UI Catalog"
            "Help Desk Workflows"
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
        # scratch. The fresh copy IS the -Force semantics (nothing stale to wipe).
        $script:workRoot = Join-Path $script:testOutputRoot ("classic-asp-golden-" + [Guid]::NewGuid().ToString("N"))
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
            $script:lastRunExit | Should -Be 0
            (Test-Path $script:docs) | Should -Be $true
        }
        It "detects Classic ASP as the framework" {
            $fwPath = Join-Path $script:docs "framework-detection.json"
            (Test-Path $fwPath) | Should -Be $true
            (Get-Content $fwPath -Raw) | Should -Match "Classic ASP"
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
                # Same heading-tolerant regex as Get-SectionSpineCoverageScore.
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
    }

    Context "api-inventory.md" {
        It "exists" {
            (Test-Path (Join-Path $script:docs "api-inventory.md")) | Should -Be $true
        }
        It "lists all 5 fixture .asp files as endpoint rows" {
            $content = Get-Content (Join-Path $script:docs "api-inventory.md") -Raw
            foreach ($f in @("index.asp","new-ticket.asp","search-ticket.asp","audit-log.asp","admin-report.asp")) {
                $content | Should -Match ([regex]::Escape($f)) -Because "endpoint $f should be inventoried"
            }
        }
        It "has no banned empty-artifact placeholder residue" {
            $content = Get-Content (Join-Path $script:docs "api-inventory.md") -Raw
            $hits = @($script:BannedPatterns | Where-Object { [regex]::IsMatch($content, $_) })
            $hits.Count | Should -Be 0
        }
    }

    Context "data-model.md" {
        It "exists" {
            (Test-Path (Join-Path $script:docs "data-model.md")) | Should -Be $true
        }
        It "contains the fixture DB (FIXTURE_DB)" {
            (Get-Content (Join-Path $script:docs "data-model.md") -Raw) | Should -Match "FIXTURE_DB"
        }
        It "contains at least 1 table or stored procedure" {
            $c = Get-Content (Join-Path $script:docs "data-model.md") -Raw
            (($c -match 'HelpDesk[.](Tickets|AuditTrail)') -or ($c -match 'usp_')) | Should -Be $true
        }
        It "has no banned empty-artifact placeholder residue" {
            $content = Get-Content (Join-Path $script:docs "data-model.md") -Raw
            $hits = @($script:BannedPatterns | Where-Object { [regex]::IsMatch($content, $_) })
            $hits.Count | Should -Be 0
        }
    }

    Context "config-catalog.md" {
        It "exists" {
            (Test-Path (Join-Path $script:docs "config-catalog.md")) | Should -Be $true
        }
        It "contains the web.config appSettings key (HelpDesk.LogLevel)" {
            (Get-Content (Join-Path $script:docs "config-catalog.md") -Raw) | Should -Match "HelpDesk[.]LogLevel"
        }
        It "has no banned empty-artifact placeholder residue" {
            $content = Get-Content (Join-Path $script:docs "config-catalog.md") -Raw
            $hits = @($script:BannedPatterns | Where-Object { [regex]::IsMatch($content, $_) })
            $hits.Count | Should -Be 0
        }
    }

    Context "evidence-register.md" {
        It "exists" {
            (Test-Path (Join-Path $script:docs "evidence-register.md")) | Should -Be $true
        }
        It "has at least 1 table data row" {
            $rows = @(Get-Content (Join-Path $script:docs "evidence-register.md") |
                Where-Object { $_ -match '^\|' -and $_ -notmatch '^\|[\s:\-|]+\|' })
            $rows.Count | Should -BeGreaterThan 0
        }
    }

    Context "verification-appendix.md" {
        It "exists" {
            (Test-Path (Join-Path $script:docs "verification-appendix.md")) | Should -Be $true
        }
        It "has at least 1 re-runnable command" {
            (Get-Content (Join-Path $script:docs "verification-appendix.md") -Raw) |
                Should -Match "Select-String|pwsh|ConvertFrom|Get-Content"
        }
    }

    Context "report.html" {
        It "exists" {
            (Test-Path (Join-Path $script:docs "report.html")) | Should -Be $true
        }
        It "contains the CMU theme color (#6a0032)" {
            (Get-Content (Join-Path $script:docs "report.html") -Raw) | Should -Match "#6a0032"
        }
        It "contains a TOC nav element" {
            (Get-Content (Join-Path $script:docs "report.html") -Raw) | Should -Match '<nav[^>]*class="[^"]*toc[^"]*"'
        }
    }

    Context "validation-report.json" {
        It "exists" {
            (Test-Path (Join-Path $script:docs "validation-report.json")) | Should -Be $true
        }
        It "parses as JSON" {
            $raw = Get-Content (Join-Path $script:docs "validation-report.json") -Raw
            $null = $raw | ConvertFrom-Json
            $true | Should -Be $true
        }
        It "records a status (the gate ran without error)" {
            $rep = Get-Content (Join-Path $script:docs "validation-report.json") -Raw | ConvertFrom-Json
            $rep.status | Should -Not -BeNullOrEmpty -Because "the gate must produce a status; the tiny fixture intentionally scores below the full-app threshold, so we assert the gate RAN, not that it passes"
        }
    }
}
