#requires -Version 7.2
#
# generate-git-ownership.ps1
#
# Purpose: run the deterministic git-ownership extractor (AppDoc.GitOwnership) over
#          the target and emit:
#            docs/evidence/git-ownership.evidence.json   (machine per-file owner /
#                                                          last-change / churn + top-level)
#            docs/git-ownership.md                       (readable ownership appendix)
#
# HONEST-UNKNOWN (the hard bar):
#   - NON-GIT dir (no .git)      -> owner=Unknown, git is NEVER invoked.
#   - SHALLOW history (< min)    -> owner=Unknown (a 1-commit / squashed author is NOT
#                                    meaningful ownership).
#   - SUFFICIENT history (>= min)-> real per-file owner (last-change author) + churn.
#
# Reads:   <target>/.appdoc/config.json (minCommitsForOwnership; default 2) + git history.
# Writes:  docs/evidence/git-ownership.evidence.json + docs/git-ownership.md
#
# Determinism: pure function of (git history, CODEOWNERS, config). No wall-clock
# timestamp (dates are the git-committed dates, stable for a fixed repo state), no
# network, no LLM, no randomness. Two runs over the same target produce byte-identical
# output (excl. the provenance stamp applied later by the orchestrator).
#
# Wiring: run by run-appdoc-build.ps1 in the Generation phase, BEFORE the composer
#          (generate-unified-master.ps1) so the composer can surface a git-derived
#          ownership sub-block in section 13 when the history is real. Additive: it
#          never changes status/overallScore or the pristine sub-score (section 13 is
#          an owner-pending cell that scores 100 whether PASS or OWNER_REQUIRED).
#
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath
)


# Output folder resolution (config outputDir).
Import-Module (Join-Path (Join-Path $PSScriptRoot 'modules') 'AppDoc.Paths.psm1') -ErrorAction Stop

$ErrorActionPreference = "Stop"

if (-not (Test-Path $RootPath)) { Write-Error "Root path does not exist: $RootPath"; exit 1 }
$docsPath = (Get-AppDocDocsPath -RootPath $RootPath)
if (-not (Test-Path $docsPath)) { Write-Error "docs directory not found: $docsPath"; exit 1 }

# --- import modules -----------------------------------------------------------
$modulePath = Join-Path $PSScriptRoot "modules/AppDoc.GitOwnership.psm1"
if (-not (Test-Path $modulePath)) { Write-Error "Required module not found: $modulePath"; exit 1 }
Import-Module $modulePath -Force -ErrorAction Stop

# --- read config (minCommitsForOwnership) ------------------------------------
$configModule = Join-Path $PSScriptRoot "modules/AppDoc.Config.psm1"
$minCommits = 2
$showEmails = $false
if (Test-Path $configModule) {
    Import-Module $configModule -Force -ErrorAction SilentlyContinue
    $cfg = Get-AppDocConfig -RootPath $RootPath
    if ($cfg -and $cfg.values.minCommitsForOwnership -and ($cfg.values.minCommitsForOwnership -gt 0)) {
        $minCommits = [int]$cfg.values.minCommitsForOwnership
    }
    if ($cfg) { $showEmails = [bool]$cfg.values.ownershipShowEmails }
}
# The scope policy (fixtures/tests/docs/... exclusions) also applies to ownership rows.
$scopeModule = Join-Path $PSScriptRoot "modules/AppDoc.Scope.psm1"
if (Test-Path $scopeModule) { Import-Module $scopeModule -Force -ErrorAction Stop }

# --- extract (deterministic) --------------------------------------------------
$result = Get-AppDocGitOwnership -RootPath $RootPath -MinCommitsForOwnership $minCommits -MaxFiles 400 -ShowEmails $showEmails
$fileCount = @($result.files).Count

# Deterministic evidence date (no wall-clock): the git last-committed date when the
# target is a git repo (stable for a fixed repo state), else 'n/a'. This keeps the
# evidence byte-identical across two runs (the per-file lastChange values are the
# git-committed dates; there is no Get-Date anywhere in this generator).
$reportDate = if ($result.isGitRepo -and $result.lastDate) { [string]$result.lastDate } else { 'n/a' }

if ($result.isGitRepo) {
    Write-Host ("  Git ownership: repo present; {0} commit(s), {1} author(s); history {2} (min {3})." -f $result.commitCount, $result.authorCount, $(if ($result.historySufficient) { 'sufficient -> real attribution' } else { 'INSUFFICIENT (shallow) -> honest-Unknown' }), $minCommits) -ForegroundColor Cyan
} else {
    Write-Host "  Git ownership: no .git directory -> owner=Unknown (honest; git not invoked)." -ForegroundColor Cyan
}

# --- build the machine evidence record ---------------------------------------
$fileRecords = @()
foreach ($f in @($result.files)) {
    $fileRecords += [ordered]@{
        path        = [string]$f.path
        owner       = [string]$f.owner
        lastChange  = [string]$f.lastChange
        churn       = [int]$f.churn
    }
}
$authorRecords = @()
foreach ($a in @($result.authors)) {
    $authorRecords += [ordered]@{
        email   = [string]$a.email
        name    = [string]$a.name
        commits = [int]$a.commits
    }
}
$codeownerRecords = @()
foreach ($co in @($result.codeowners)) {
    $codeownerRecords += [ordered]@{
        pattern = [string]$co.pattern
        owners  = @($co.owners)
    }
}

$evOut = [ordered]@{
    artifact             = 'git-ownership'
    generator            = 'generate-git-ownership.ps1'
    module               = 'AppDoc.GitOwnership.psm1'
    version              = '1.0.0'
    reportDate           = $reportDate
    isGitRepo            = [bool]$result.isGitRepo
    commitCount          = [int]$result.commitCount
    minCommitsForOwnership = [int]$minCommits
    historySufficient    = [bool]$result.historySufficient
    status               = [string]$result.status
    owner                = [string]$result.owner
    codeownersPresent    = [bool]$result.codeownersPresent
    codeownersDefault    = [string]$result.codeownersDefault
    codeowners           = $codeownerRecords
    authorCount          = [int]$result.authorCount
    firstDate            = [string]$result.firstDate
    lastDate             = [string]$result.lastDate
    topAuthorEmail       = [string]$result.topAuthorEmail
    topAuthorName        = [string]$result.topAuthorName
    topAuthorCommits     = [int]$result.topAuthorCommits
    authors              = $authorRecords
    fileCount            = [int]$fileCount
    files                = $fileRecords
}
$evDir = Join-Path $docsPath 'evidence'
if (-not (Test-Path $evDir)) { New-Item -Path $evDir -ItemType Directory -Force | Out-Null }
$evPath = Join-Path $evDir 'git-ownership.evidence.json'
$evOut | ConvertTo-Json -Depth 20 | Out-File -FilePath $evPath -Encoding UTF8

# --- build the readable appendix ----------------------------------------------
$md = New-Object System.Collections.Generic.List[string]
$md.Add('# Git Ownership & Change History (Deterministic)')
$md.Add('')
$md.Add("**Report date**: $reportDate  ")
$md.Add('')
$md.Add("> **What this is:** per-file ownership (last-change author), last-change date, and churn (instability = distinct commit count) derived deterministically from the target's `git log` + `CODEOWNERS` (when present). This backs the §13 Ownership cell with git-derived owner data **only when the git history is real and sufficient**.  ")
$md.Add('')
$md.Add("> **Honest-Unknown guarantee:** a **non-git** directory (no `.git`) and **shallow** history (fewer than $minCommits commits — e.g. a single squashed commit) are **NOT** meaningful ownership, so every owner field degrades to `Unknown` rather than passing a single commit's author off as ownership. Git is never invoked on a non-git directory.")
$md.Add('')

if (-not $result.isGitRepo) {
    $md.Add("## Result: `Unknown` (no git history)")
    $md.Add('')
    $md.Add("_The target has no `.git` directory. Ownership, last-change, and churn are all `Unknown` (honest — no git history to derive from, and git was not invoked)._")
    $md.Add('')
    $md.Add("| Field | Value |")
    $md.Add("|-------|-------|")
    $md.Add("| isGitRepo | false |")
    $md.Add("| owner | Unknown |")
    $md.Add("| last-change | Unknown |")
    $md.Add("| churn | Unknown |")
} elseif (-not $result.historySufficient) {
    $md.Add("## Result: `Unknown` (history too shallow — $([int]$result.commitCount) commit(s) < $minCommits)")
    $md.Add('')
    $md.Add("_The git history is shallow ($([int]$result.commitCount) commit(s) for $([int]$result.authorCount) author(s)). A single/squashed commit's author is **not** meaningful ownership, so every owner field is `Unknown`. Churn is reported for reference (all files churn=1) but owner/last-change stay `Unknown`._")
    $md.Add('')
    $md.Add("| Field | Value |")
    $md.Add("|-------|-------|")
    $md.Add("| isGitRepo | true |")
    $md.Add("| commitCount | $([int]$result.commitCount) |")
    $md.Add("| authors | $([int]$result.authorCount) |")
    $md.Add("| status | Unknown (history insufficient; not fabricated) |")
    $md.Add("| owner | Unknown |")
    $md.Add("| last-change | Unknown |")
    $md.Add("")
    $md.Add("> Note: the observed author(s) are listed below for provenance, but they are **not** treated as ownership (honest-Unknown).")
    $md.Add("")
    $md.Add("| Author | Commits |")
    $md.Add("|--------|---------|")
    foreach ($a in @($result.authors)) { $md.Add("| $([string]$a.name)$(if ($a.email) { " <$([string]$a.email)>" }) | $([int]$a.commits) |") }
} else {
    $md.Add("## Result: `Derived` (real git history — $([int]$result.commitCount) commit(s), $([int]$result.authorCount) author(s))")
    $md.Add('')
    $md.Add("| Field | Value |")
    $md.Add("|-------|-------|")
    $md.Add("| isGitRepo | true |")
    $md.Add("| commitCount | $([int]$result.commitCount) |")
    $md.Add("| authors | $([int]$result.authorCount) |")
    $md.Add("| first date | $([string]$result.firstDate) |")
    $md.Add("| last date | $([string]$result.lastDate) |")
    $md.Add("| declared owner (CODEOWNERS `*`) | $([string]$result.owner) |")
    $md.Add("| top author | $([string]$result.topAuthorName)$(if ($result.topAuthorEmail) { " <$([string]$result.topAuthorEmail)>" }) ($([int]$result.topAuthorCommits) commits) |")
    $md.Add('')
    $md.Add("### Authors")
    $md.Add('')
    $md.Add("| Author | Commits |")
    $md.Add("|--------|---------|")
    foreach ($a in @($result.authors)) { $md.Add("| $([string]$a.name)$(if ($a.email) { " <$([string]$a.email)>" }) | $([int]$a.commits) |") }
    $md.Add('')
    if ($result.codeownersPresent) {
        $md.Add("### CODEOWNERS")
        $md.Add('')
        $md.Add("| Pattern | Owner(s) |")
        $md.Add("|---------|----------|")
        foreach ($co in @($result.codeowners)) {
            $patCell = '`' + [string]$co.pattern + '`'
            $md.Add("| $patCell | $((@($co.owners) -join ', ')) |")
        }
        $md.Add('')
    }
    $md.Add("### Per-file ownership (owner = last-change author; churn = commit count)")
    $md.Add('')
    $md.Add("| File | Owner (last-change) | Last change | Churn |")
    $md.Add("|------|---------------------|-------------|-------|")
    $shown = 0
    foreach ($f in @($result.files)) {
        $pathCell = '`' + [string]$f.path + '`'
        $ownerCell = [string]$f.owner
        $lastCell = [string]$f.lastChange
        $churnCell = [string][int]$f.churn
        $md.Add("| $pathCell | $ownerCell | $lastCell | $churnCell |")
        $shown++
    }
    if ($shown -eq 0) { $md.Add("| — | Unknown | Unknown | Unknown |") }
}

$md.Add('')
$md.Add('---')
$md.Add('')
$md.Add('*Generated by `generate-git-ownership.ps1` (module `AppDoc.GitOwnership.psm1`) — a deterministic function of git history + CODEOWNERS + config. No wall-clock timestamp, no network, no LLM, no randomness. Owner is `Unknown` on non-git and shallow-history targets (honest — a single commit''s author is not ownership); real attribution only when history is sufficient.*')
$md.Add('')

$mdPathOut = Join-Path $docsPath 'git-ownership.md'
($md -join "`n") | Out-File -FilePath $mdPathOut -Encoding UTF8 -NoNewline

Write-Host "   Wrote docs/git-ownership.md + docs/evidence/git-ownership.evidence.json ($fileCount file record(s); status=$([string]$result.status))" -ForegroundColor Gray
