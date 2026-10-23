# Golden-file structural regression test for the Java / Spring Boot path.
#
# Purpose: prove the FRAMEWORK-AGNOSTIC AppDoc pipeline generalizes end-to-end to a
# REALISTIC Java / Spring Boot REST target. It runs the real run-all-generators
# pipeline on a small, deterministic Spring Boot fixture (tests/fixtures/
# java-spring-sample) and asserts the framework-agnostic INVARIANTS (NOT a specific
# quality score -- the Java regex path scores differently than classic ASP/C#, so
# structure is asserted, not a magic number):
#
#   * the pipeline exits 0 and produces docs/
#   * the target is classified as Spring Boot (a real Java framework) via
#     pom.xml:spring-boot + @RestController signals
#   * the generic API extractor FIRED on Java: the @GetMapping/@PostMapping/
#     @PutMapping/@DeleteMapping routes reach the composed master + the
#     api-inventory main table AND the appendix (the real Java endpoint content,
#     NOT an empty classic-ASP table and NOT a clobber). This is the key
#     generalization proof for the Java path.
#   * the architecture fingerprint classifies the target as rest-http (a Java
#     Spring controller is a REST surface -- it must NOT be mislabeled
#     no-api-surface, which would contradict the api-inventory endpoint rows).
#   * the composed unified master carries the SAME 20-section spine as the siblings
#   * NO banned empty-artifact placeholder residue, NO residual PowerShell garbage
#   * HONEST FLOOR: no truly-empty H2 section; an explicit honest-Unknown marker
#     present (the tiny fixture cannot ground every claim)
#   * REDACTION: the fixture's fake DB password is redacted -- ABSENT from every
#     generated artifact. NOTE the Java/YAML/properties config path masks the
#     secret as `***masked***` (AppDoc.ConfigCatalog.Renderer); the `[REDACTED]`
#     token is the .env/JSON path used by the node/csharp siblings. We therefore
#     assert the secret is ABSENT everywhere + the password row is masked.
#   * a runnable, PASSING gate: validation-report.json with a status and NO
#     blocking policy issues (the fingerprint fix is what makes a real Spring
#     target clear the architecture-contradiction + config gates).
#
# Convention matches the sibling Pester tests (copy fixture -> temp workRoot -> run
# -> assert). Run with:
#   pwsh -c 'Invoke-Pester -Path test-golden-java-spring.ps1'
#
# PESTER v6.2.0 NOTES (hard-won, same as the siblings):
#   - File-scope $script: vars are NOT visible inside Describe/Context/It in v6.
#     Every shared constant is computed INSIDE BeforeAll and stored as $script:.
#   - $PSScriptRoot IS available in blocks. Use the dash form: `Should -Be`, `-Match`.

Describe "Golden-file structural regression: Java / Spring Boot pipeline" {
    BeforeAll {
        # --- resolve paths from $PSScriptRoot (available in Pester blocks) -------
        $script:testsDir       = $PSScriptRoot
        $script:testsParent    = Split-Path $PSScriptRoot -Parent                    # AppDoc/tests
        $script:repoRoot       = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent # AppDoc
        $script:orchestrator   = Join-Path $script:repoRoot ".appdoc/scripts/powershell/run-all-generators.ps1"
        $script:fixtureRoot    = Join-Path $script:testsParent "fixtures/java-spring-sample"
        $script:testOutputRoot = Join-Path $script:testsDir "test-output"

        # The fixture's single fake DB password. It MUST never survive redaction
        # into any generated artifact (the config renderer masks it as ***masked***).
        $script:FixtureSecret = "FakeP@ss123"

        # The BUG A regression-pin fixture's .properties DB password. A DISTINCT value
        # from the YAML one so its redaction is proven independently: the
        # src/main/resources/application.properties datasource password. It must never
        # survive into any generated artifact. (BUG A: before the scope fix the
        # config-catalog scope excluded every *.properties file, so this value was
        # neither extracted nor redacted -- the assertion would be vacuous.)
        $script:PropsSecret = "PropsP@ss999"

        # The benchmark's 20-section spine. MUST stay in sync with
        # Get-SectionSpineCoverageScore in validate-documentation.ps1.
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
        # scratch. Scope exclusions (fixtures/samples/tests) are RELATIVE to
        # -RootPath, so the fixture files sit at the workRoot root and are NOT
        # excluded.
        #
        # The workRoot location has TWO hard constraints that pull in opposite
        # directions, so it must sit inside the git repo at a top level (NOT under
        # tests/ and NOT outside the repo):
        #   (a) NOT outside the git repo -- the git-ownership generator runs bare `git`
        #       commands; a non-repo workRoot makes git exit 128 (fatal: not a git
        #       repository), which poisons the orchestrator's $LASTEXITCODE so the
        #       pipeline reports exit 128 even though every artifact is generated.
        #   (b) NOT under a tests/ directory -- the architecture fingerprint
        #       (AppDoc.ArchitectureFingerprint.psm1) scans by ABSOLUTE FullName and
        #       excludes any path matching /(test|tests|spec|specs)/, so a workRoot
        #       under tests/test-output/ makes the fingerprint see zero files and
        #       mislabel the target no-api-surface (tripping the
        #       architecture-contradiction gate).
        # A top-level in-repo dir (here, .appdoc/tmp/) satisfies both: git resolves
        # to the repo (exit ok) and the fingerprint sees the real Java sources
        # (rest-http). It is cleaned up in AfterAll.
        $script:workRoot = Join-Path $script:repoRoot (".appdoc/tmp/java-spring-golden-" + [Guid]::NewGuid().ToString("N"))
        $script:workRootParent = Split-Path $script:workRoot -Parent
        if (-not (Test-Path $script:workRootParent)) { New-Item -ItemType Directory -Path $script:workRootParent -Force | Out-Null }
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
            $script:lastRunExit | Should -Be 0 -Because "the pipeline must complete on a Java/Spring Boot target"
            (Test-Path $script:docs) | Should -Be $true
        }
        It "classifies the target as Spring Boot" {
            $fwPath = Join-Path $script:docs "framework-detection.json"
            (Test-Path $fwPath) | Should -Be $true
            (Get-Content $fwPath -Raw) | Should -Match "Spring Boot" -Because "the fixture is a Spring Boot app (pom.xml has spring-boot-starter-web + @RestController); the pipeline must classify it as such"
        }
    }

    Context "The generic API extractor fired on Java (the key generalization proof)" {
        It "extracted the /api/tickets endpoints into the api-inventory main table" {
            $main = Get-Content (Join-Path $script:docs "api-inventory.md") -Raw
            ($main -match '/api/tickets') | Should -Be $true -Because "the @GetMapping/@PostMapping/@PutMapping/@DeleteMapping routes in TicketsController.java must be found by the generic Java/Spring regex extractor and reach the user-facing api-inventory.md (NOT an empty table)"
        }
        It "cites the real Java controller source file for the endpoints" {
            $main = Get-Content (Join-Path $script:docs "api-inventory.md") -Raw
            ($main -match 'TicketsController\.java') | Should -Be $true -Because "each endpoint row must cite its real source file:line"
        }
        It "is NOT a classic-ASP clobber table" {
            $main = Get-Content (Join-Path $script:docs "api-inventory.md") -Raw
            # The classic-ASP generator must NOT have written an .asp/SQLOLEDB
            # endpoint table into the shared artifact (framework-agnostic yield-guard).
            ($main -notmatch 'SQLOLEDB|ADODB\.Connection') | Should -Be $true -Because "no classic-ASP source on a Java target, so no classic-ASP endpoint table may clobber the Java artifact"
        }
        It "carries the real Java /api/tickets routes in the appendix too" {
            $appendix = Join-Path $script:docs "api-inventory.appendix.md"
            (Test-Path $appendix) | Should -Be $true
            $content = Get-Content $appendix -Raw
            ($content -match '/api/tickets') | Should -Be $true -Because "the full Java endpoint catalog must survive in the appendix as well"
        }
    }

    Context "Data model (the Java POJO is extracted, not honest-NDA)" {
        It "extracts the Ticket JPA entity into the data-model evidence with its @Column fields" {
            # The generic data-model extractor must now scan .java (added alongside
            # ts/js/cs/py) so the Ticket JPA entity (@Entity/@Column POJO) is listed
            # as a model with its fields -- NOT left as the honest-NDA empty table.
            # This asserts on the evidence artifact (kind=model records), the same
            # source of truth the gate's Get-DataModelCoverage reads.
            $modelEvidence = Join-Path $script:docs "evidence/data-model.evidence.json"
            (Test-Path $modelEvidence) | Should -Be $true
            $payload = Get-Content $modelEvidence -Raw | ConvertFrom-Json -Depth 50
            $models = @($payload.records | Where-Object { $_ -and [string]$_.kind -eq "model" })
            $ticket = $models | Where-Object { [string]$_.name -match 'Ticket' } | Select-Object -First 1
            $null -ne $ticket | Should -Be $true -Because "the `class Ticket` JPA entity in src/main/java/com/acme/Ticket.java must be found by the Java (.java) data-model regex branch"
            # All seven @Column fields must be present (id/subject/status/priority/
            # customer_name/created_at/updated_at) -- proves the field scan ran, not a stub.
            $fieldNames = @($ticket.metadata.properties | ForEach-Object { ($_ -split ':', 2)[0].Trim() })
            $fieldNames.Count | Should -BeGreaterOrEqual 7 -Because "the Ticket entity declares seven @Column-mapped fields; the Java field scan must capture them all"
        }
        It "documents the Ticket model (name + field count + source) in data-model.md" {
            $dm = Get-Content (Join-Path $script:docs "data-model.md") -Raw
            ($dm -match 'Ticket') | Should -Be $true -Because "data-model.md must show the Ticket model (NOT be the empty honest-NDA table)"
            # The table row carries the field count (7) and the real source file:line,
            # proving a real extraction rather than a fabricated or clobbered row.
            ($dm -match '(?im)^\|\s*`Ticket`\s*\|\s*7\s*\|') | Should -Be $true -Because "the Ticket row in the data-model table must carry the 7-field count the extractor found"
            ($dm -match 'src/main/java/com/acme/Ticket\.java:17') | Should -Be $true -Because "the Ticket row must cite its real source file and the line the class is declared on"
        }
        It "does NOT leak the fixture secret into data-model.md" {
            $dm = Get-Content (Join-Path $script:docs "data-model.md") -Raw
            ($dm -notmatch $script:FixtureSecret) | Should -Be $true -Because "the data-model artifact must not carry the fixture's fake DB password"
        }
    }

    Context "Architecture fingerprint is not mislabeled no-api-surface" {
        It "classifies the Java Spring target as a REST surface" {
            $fpPath = Join-Path $script:docs "architecture-fingerprint.json"
            (Test-Path $fpPath) | Should -Be $true
            $fp = Get-Content $fpPath -Raw | ConvertFrom-Json -Depth 50
            # A Spring Boot REST controller must be recognized as a REST surface.
            # (Pre-fix, Java Spring annotations were not counted, so the fingerprint
            # mislabeled real Spring apps no-api-surface and the gate raised
            # architecture-contradiction:no-api-primary-vs-api-inventory.)
            ($fp.primaryStyle -match 'rest-http') | Should -Be $true -Because "the @RestController/@GetMapping signals must count as a REST surface; the target is not a no-API surface"
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
                $pattern = ('(?im)^#{1,6}\s+(?:\d{1,2}[A-Za-z]?\s*[.:\s]\s*)?' + [regex]::Escape($title) + '\b')
                if ($content -notmatch $pattern) { $missing += $title }
            }
            if ($missing.Count -gt 0) {
                throw "Missing $($missing.Count)/20 spine headings in application-documentation.md: $($missing -join ', ')"
            }
            $true | Should -Be $true
        }
        It "carries the real Java /api/tickets routes (evidence-driven, not a clobber)" {
            $master = Get-Content (Join-Path $script:docs "application-documentation.md") -Raw
            $master | Should -Match ([regex]::Escape("/api/tickets")) -Because "the generic extractor's Java routes must reach the composed master (evidence-driven), not an empty classic-ASP table"
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
            ($s94 -match 'postForObject') | Should -Be $true -Because "the generic extractor must surface the TicketService.java restTemplate.postForObject outbound call site"
            ($s94 -match 'TicketService\.java') | Should -Be $true -Because "the §9.4 row must cite its real source file"
            ($s94 -match '(?m)^\|\s*HTTP-01\s*\|') | Should -Be $true -Because "§9.4 must carry a real outbound row (not the 'none detected' honest-NDA fallback)"
        }
        It "writes the external-call artifact (extcalls.md) with the real row at file:line" {
            $ext = Join-Path $script:docs "extcalls.md"
            (Test-Path $ext) | Should -Be $true
            $content = Get-Content $ext -Raw
            ($content -match 'TicketService\.java') | Should -Be $true -Because "extcalls.md must cite the real restTemplate.postForObject call site file"
            ($content -match 'line 42') | Should -Be $true -Because "extcalls.md must cite the real call site line (line 42)"
            ($content -match '/intake/tickets') | Should -Be $true -Because "the real ITSM intake path is cited as Inferred (never fabricated)"
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
            if ($empty.Count -gt 0) {
                throw "Empty H2 section(s) (header implies content but has none): $($empty -join ', ')"
            }
            $true | Should -Be $true
        }
        It "carries an explicit honest-uncertainty marker (Unknown), not fabricated certainty" {
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
        It "masks the DB password row in config-catalog.md (redacted, not dropped)" {
            $cc = Get-Content (Join-Path $script:docs "config-catalog.md") -Raw
            # The Java/YAML/properties config path masks secret keys as ***masked***
            # (AppDoc.ConfigCatalog.Renderer); the [REDACTED] token is the .env/JSON
            # path used by the node/csharp siblings. Assert the real token OR the
            # .env-style token, i.e. the password value is masked, not the raw value.
            ($cc -match '\*\*\*masked\*\*\*|\[REDACTED\]') | Should -Be $true -Because "the spring.datasource.password value must be masked/redacted, not printed"
        }
        It "still surfaces a real, non-secret config key (itsm.base-url)" {
            $cc = Get-Content (Join-Path $script:docs "config-catalog.md") -Raw
            ($cc -match 'itsm[.]base-url') | Should -Be $true -Because "the non-secret config key proves the application.yml was genuinely parsed for the Java target"
        }
    }

    Context "Runnable, passing gate (structural soundness, not a magic score)" {
        It "produces a validation-report.json with a status" {
            $repPath = Join-Path $script:docs "validation-report.json"
            (Test-Path $repPath) | Should -Be $true
            $rep = Get-Content $repPath -Raw | ConvertFrom-Json -Depth 40
            $rep.status | Should -Not -BeNullOrEmpty -Because "the gate must have RAN on the Java/Spring Boot target"
        }
        It "has no blocking policy issues (the Java path gate-passes)" {
            $rep = Get-Content (Join-Path $script:docs "validation-report.json") -Raw | ConvertFrom-Json -Depth 40
            $blocks = @($rep.policyGates.blockingIssues | Where-Object { $_ })
            if ($blocks.Count -gt 0) {
                throw "Blocking policy issues on the Java/Spring Boot target: $($blocks -join ', ')"
            }
            $true | Should -Be $true
        }
        It "does not report a classic-ASP clobber (the api-inventory is not empty)" {
            $rep = Get-Content (Join-Path $script:docs "validation-report.json") -Raw | ConvertFrom-Json -Depth 40
            $blocks = @($rep.policyGates.blockingIssues | Where-Object { $_ })
            ($blocks -notcontains 'api-endpoints-table-empty') | Should -Be $true -Because "the Java endpoints are real and present, so the api-inventory table must NOT be flagged empty"
        }
    }

    Context "BUG A regression pin: the application.properties datasource is extracted + redacted" {
        It "extracts the Spring Boot datasource from application.properties (not dropped by the scope)" {
            # BUG A: the config-catalog scope profile used to exclude every *.properties
            # file, so the application.properties datasource was silently dropped (empty
            # catalog -> config-options-table-empty gate block). The distinct DB name
            # `tickets_props` appears ONLY in src/main/resources/application.properties
            # (the sibling application.yml uses `tickets`), so its presence proves the
            # .properties file was genuinely scanned, not just parsed from the yml.
            $cc = Get-Content (Join-Path $script:docs "config-catalog.md") -Raw
            ($cc -match 'tickets_props') | Should -Be $true -Because "the application.properties datasource (spring.datasource.url = .../tickets_props) must reach config-catalog.md, proving the .properties file is in scope"
            # The datasource password row must be present AND masked/redacted (not raw).
            ($cc -match 'spring[.]datasource[.]password') | Should -Be $true -Because "the spring.datasource.password key must be surfaced from application.properties"
        }
        It "redacts the application.properties datasource password (0 leaks)" {
            # The .properties datasource password is a distinct fake secret; it must be
            # REDACTED (masked/[REDACTED]), never printed, into any generated artifact.
            $leaks = @()
            $files = @(Get-ChildItem -Path $script:docs -Recurse -File -Include "*.md","*.html","*.json" -ErrorAction SilentlyContinue)
            foreach ($f in $files) {
                $raw = Get-Content $f.FullName -Raw -ErrorAction SilentlyContinue
                if ($raw -and $raw.Contains($script:PropsSecret)) { $leaks += $f.Name }
            }
            if ($leaks.Count -gt 0) {
                throw "BUG A pin: application.properties password '$($script:PropsSecret)' leaked into: $($leaks -join ', ')"
            }
            $true | Should -Be $true
        }
    }

    Context "BUG B regression pin: a com.example source path is scanned (not wiped)" {
        It "extracts the /audit-log endpoint from the com.example package controller" {
            # BUG B: the api-inventory + data-model scans used to exclude any source dir
            # whose path segment matched sample|samples|example|examples, so every
            # @Controller / @Entity under a Spring Initializr default `com.example` path
            # (or a `samples/` package) was silently dropped. The /audit-log route is
            # declared ONLY in src/main/java/com/example/app/AuditLogController.java, so
            # its presence proves a `com.example` path is scanned, not wiped.
            $main = Get-Content (Join-Path $script:docs "api-inventory.md") -Raw
            ($main -match '/audit-log') | Should -Be $true -Because "the @GetMapping /audit-log route in com/example/app/AuditLogController.java must reach api-inventory.md (a com.example path must be scanned, not excluded)"
            ($main -match 'AuditLogController\.java') | Should -Be $true -Because "the endpoint row must cite its real com.example source file:line"
        }
        It "extracts the AuditLog @Entity from the com.example package into the data model" {
            # The com.example JPA entity must be listed as a model (real extraction),
            # proving the data-model scan also reads com.example paths (was wiped pre-fix).
            $modelEvidence = Join-Path $script:docs "evidence/data-model.evidence.json"
            $payload = Get-Content $modelEvidence -Raw | ConvertFrom-Json -Depth 50
            $models = @($payload.records | Where-Object { $_ -and [string]$_.kind -eq "model" })
            $audit = $models | Where-Object { [string]$_.name -match 'AuditLog' } | Select-Object -First 1
            $null -ne $audit | Should -Be $true -Because "the `class AuditLog` JPA entity in src/main/java/com/example/app/AuditLog.java must be found (a com.example path must not be scope-excluded from the data-model scan)"
        }
    }
}
