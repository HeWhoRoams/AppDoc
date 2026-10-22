# Unit test: the PRISTINE GATE decision function (Deliverable B).
#
# Purpose: prove the gate's BLOCK/NO-BLOCK decision is a PURE FUNCTION of its
# inputs, in AppDoc.Pristine.psm1 (Test-AppDocPristineGate). This is the single
# decision point that validate-documentation.ps1 calls, so unit-testing it proves
# the blocking logic WITHOUT degrading a real target. The five mandated cases:
#
#   (1) emptyCount=0 + subScore>=floor + enabled  -> NOT blocked
#   (2) emptyCount>0 + enabled                     -> blocked
#   (3) subScore<floor + enabled                   -> blocked
#   (4) enabled=false (report-only, the DEFAULT)   -> NEVER blocked, even if
#       emptyCount>0 / subScore<floor
#   (5) OWNER_REQUIRED>0                           -> NEVER blocks (excluded —
#       they are pending /appdoc.enhance, not failures), even with enabled=true
#
# The report-only invariants hold too: enabled=false sets blocked=false and leaves
# blockingIssues empty in EVERY case.
#
# NOTE on It descriptions: Pester v6's FormatNicelyForTemplate builds a scriptblock
# from the description text, so it must NOT contain the chars < > = (or the combos
# -> >= <=). The descriptions below use words ("under floor", "meets floor",
# "zero EMPTY", "present") instead of comparison symbols for that reason.
#
# Run with:
#   pwsh -c 'Invoke-Pester -Path test-pristine-gate.ps1'
#   or:      Invoke-Pester -FullNameFilter *PristineGate*
#
# PESTER v6.2.0 NOTES (match the sibling golden tests): file-scope $script: vars are
# NOT visible inside Describe/Context/It in v6, so shared constants are computed inside
# BeforeAll and stored on $script:. Module functions (Test-AppDocPristineGate) are
# exported and therefore available in It blocks after Import-Module.

Describe "Pristine gate decision function (Test-AppDocPristineGate)" {
    BeforeAll {
        $script:repoRoot    = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent  # AppDoc
        $script:pristineMod = Join-Path $script:repoRoot ".appdoc/scripts/powershell/modules/AppDoc.Pristine.psm1"
        if (-not (Test-Path $script:pristineMod)) { throw "pristine module not found: $($script:pristineMod)" }
        Import-Module $script:pristineMod -Force -ErrorAction Stop
    }

    Context "report-only (enabled false) — the DEFAULT mode" {
        It "case 1: zero EMPTY, sub-score meets or exceeds floor, enabled — NOT blocked" {
            $r = Test-AppDocPristineGate -EmptyCount 0 -SubScore 95.8 -Floor 80 -OwnerRequiredCount 0 -Enabled $true
            $r.blocked | Should -BeFalse -Because "no EMPTY and sub-score at/above floor must not block"
            $r.floorMet | Should -BeTrue
            @($r.blockingIssues).Count | Should -Be 0
        }

        It "case 4: report-only (enabled false) NEVER blocks, even with violations" {
            # Even with BOTH an EMPTY section AND a sub-score below the floor, report-only
            # (the default) must never block.
            $r = Test-AppDocPristineGate -EmptyCount 3 -SubScore 50 -Floor 80 -OwnerRequiredCount 0 -Enabled $false
            $r.blocked | Should -BeFalse -Because "report-only mode must never block"
            @($r.blockingIssues).Count | Should -Be 0 -Because "report-only emits no blocking issues"
        }

        It "case 4b: report-only with sub-score under floor — floorMet false but NOT blocked" {
            $r = Test-AppDocPristineGate -EmptyCount 0 -SubScore 70 -Floor 80 -OwnerRequiredCount 0 -Enabled $false
            $r.blocked | Should -BeFalse
            $r.floorMet | Should -BeFalse -Because "floorMet is computed even in report-only (informational)"
        }
    }

    Context "blocking (enabled true) — OPT-IN mode" {
        It "case 2: EMPTY present, enabled — BLOCKED" {
            $r = Test-AppDocPristineGate -EmptyCount 1 -SubScore 95.8 -Floor 80 -OwnerRequiredCount 0 -Enabled $true
            $r.blocked | Should -BeTrue -Because "a source-derivable EMPTY section must block"
            $r.emptyViolation | Should -BeTrue
            ($r.blockingIssues -join " ") | Should -Match "empty-sections"
        }

        It "case 3: sub-score under floor, enabled — BLOCKED" {
            $r = Test-AppDocPristineGate -EmptyCount 0 -SubScore 70 -Floor 80 -OwnerRequiredCount 0 -Enabled $true
            $r.blocked | Should -BeTrue -Because "a sub-score below the floor must block"
            $r.floorMet | Should -BeFalse
            ($r.blockingIssues -join " ") | Should -Match "below-floor"
        }

        It "boundary: sub-score equals floor, enabled — NOT blocked (floor is inclusive)" {
            $r = Test-AppDocPristineGate -EmptyCount 0 -SubScore 80 -Floor 80 -OwnerRequiredCount 0 -Enabled $true
            $r.blocked | Should -BeFalse
            $r.floorMet | Should -BeTrue -Because "subScore at the floor meets the floor"
        }

        It "case 2+3: EMPTY present AND sub-score under floor — BLOCKED with both issues" {
            $r = Test-AppDocPristineGate -EmptyCount 2 -SubScore 60 -Floor 80 -OwnerRequiredCount 0 -Enabled $true
            $r.blocked | Should -BeTrue
            @($r.blockingIssues).Count | Should -Be 2 -Because "both the EMPTY and below-floor violations are reported"
        }

        It "custom floor: sub-score meets custom floor — not blocked; under it — blocked" {
            $ok  = Test-AppDocPristineGate -EmptyCount 0 -SubScore 95.8 -Floor 90 -OwnerRequiredCount 0 -Enabled $true
            $bad = Test-AppDocPristineGate -EmptyCount 0 -SubScore 95.8 -Floor 99 -OwnerRequiredCount 0 -Enabled $true
            $ok.blocked | Should -BeFalse
            $bad.blocked | Should -BeTrue -Because "95.8 is under the 99 floor — the -PristineFloor path"
        }
    }

    Context "OWNER_REQUIRED cells are EXCLUDED from the gate (never a failure)" {
        It "case 5: OWNER_REQUIRED present, enabled — NEVER blocks (excluded)" {
            $r = Test-AppDocPristineGate -EmptyCount 0 -SubScore 95.8 -Floor 80 -OwnerRequiredCount 5 -Enabled $true
            $r.blocked | Should -BeFalse -Because "OWNER_REQUIRED cells are pending /appdoc.enhance, not failures"
            @($r.blockingIssues).Count | Should -Be 0
        }

        It "case 5b: OWNER_REQUIRED present does not rescue a real EMPTY violation" {
            # OWNER_REQUIRED is excluded, so it neither blocks nor un-blocks: a real
            # EMPTY section still blocks even when 5 owner cells are also pending.
            $r = Test-AppDocPristineGate -EmptyCount 1 -SubScore 95.8 -Floor 80 -OwnerRequiredCount 5 -Enabled $true
            $r.blocked | Should -BeTrue -Because "OWNER_REQUIRED is ignored; the EMPTY violation still blocks"
        }

        It "case 5c: only correctly-pending OWNER cells, no EMPTY, above floor — never blocks" {
            # The real-world shape: 0 EMPTY, sub-score above floor, 5 owner-pending cells.
            $r = Test-AppDocPristineGate -EmptyCount 0 -SubScore 98 -Floor 80 -OwnerRequiredCount 5 -Enabled $true
            $r.blocked | Should -BeFalse -Because "a real classic-ASP / legacy-MVC5 shape (14P/1W/0E/5O) must not block"
        }
    }
}
