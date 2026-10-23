# AppDoc.GitOwnership Module
# Purpose: Deterministic, git-derived per-file ownership metadata (owner / last-change
#          date / churn=instability) from `git log` + CODEOWNERS (when present).
#
#          HONEST-UNKNOWN GUARANTEE (the hard bar):
#            - NON-GIT DIR (no .git): isGitRepo=$false. Git is NEVER invoked. Every
#              owner field degrades to 'Unknown'. (A scratch copy without .git is the usual case.)
#            - SHALLOW HISTORY (commitCount < $MinCommitsForOwnership, default 2):
#              historySufficient=$false. A single / squashed commit's author is NOT
#              meaningful ownership, so every owner field degrades to 'Unknown'.
#              (a repo with exactly 1 commit -> owner=Unknown, NOT the 1-commit author.)
#            - SUFFICIENT HISTORY (commitCount >= $MinCommitsForOwnership): real
#              per-file owner (last-change author), last-change date, and churn
#              (distinct commit count touching the file) are reported.
#
#          Deterministic: sorted, no timestamps-in-output beyond git's own committed
#          dates (stable for a fixed repo state), no LLM, no network. Git is only called
#          when a .git exists (guarded), and every git call is wrapped so a failure
#          degrades to Unknown rather than crashing the build.
$script:AppDocGitOwnershipVersion = "1.0.0"

# Source file extensions considered "code" (used to bound per-file records and to map
# endpoints to source files). Kept conservative; ownership of config/doc files is still
# computed but code files are surfaced first (deterministic).
$script:AppDocGitOwnershipCodeExts = @('.cs', '.cshtml', '.aspx', '.aspx.cs', '.asax', '.ashx',
    '.ts', '.tsx', '.js', '.jsx', '.py', '.java', '.vb', '.asp', '.inc', '.scala', '.go',
    '.php', '.rb', '.sql', '.config', '.csproj', '.sln')

# --- git presence (GUARDED: never invoke git on a non-git dir) ---------------
# Returns $true only if the target actually looks like a git work-tree: a .git dir/file
# exists AND `git rev-parse --is-inside-work-tree` confirms it. A non-git dir
# short-circuits to $false WITHOUT calling git at all.
function Test-AppDocGitRepo {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$RootPath)

    if (-not (Test-Path -LiteralPath $RootPath)) { return $false }
    $dotGit = Join-Path $RootPath '.git'
    # .git may be a directory (normal clone) or a file (work-tree / submodule pointer).
    if (-not (Test-Path -LiteralPath $dotGit)) { return $false }
    try {
        $r = (& git -C $RootPath rev-parse --is-inside-work-tree 2>$null | Out-String).Trim()
        return ($r -eq 'true')
    }
    catch { return $false }
}

# --- history stats (ONLY call after Test-AppDocGitRepo returned $true) --------
# commitCount, top authors (by commit count), first/last committed date.
function Get-AppDocGitHistoryStats {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$RootPath)

    $null = [string]$RootPath
    $commitCount = 0
    $authorCommitCounts = @{}
    $firstDate = ''
    $lastDate = ''
    try {
        # %H commit, %ae email, %an name, %ad short date (chronological via --reverse)
        $lines = @(& git -C $RootPath log --pretty=format:'%H|%ae|%an|%ad' --date=short 2>$null)
        foreach ($ln in $lines) {
            if ([string]::IsNullOrWhiteSpace($ln)) { continue }
            $p = $ln.Split('|')
            if ($p.Count -lt 4) { continue }
            $commitCount++
            $ae = $p[1]; $an = $p[2]; $ad = $p[3]
            if (-not $authorCommitCounts.ContainsKey($ae)) { $authorCommitCounts[$ae] = 0 }
            $authorCommitCounts[$ae]++
            # Track dates (git log is newest-first; the FIRST line is the latest date).
            if ($firstDate -eq '') { $lastDate = $ad }
            $firstDate = $ad
        }
    }
    catch { }

    # Resolve top-author display name + build the author summary in one pass.
    $authorList = @()
    $nameByEmail = @{}
    try {
        foreach ($ln in @(& git -C $RootPath log --pretty=format:'%ae|%an' --date=short 2>$null)) {
            $q = $ln.Split('|')
            if ($q.Count -ge 2 -and -not $nameByEmail.ContainsKey($q[0])) { $nameByEmail[$q[0]] = $q[1] }
        }
    }
    catch { }
    foreach ($k in ($authorCommitCounts.Keys | Sort-Object)) {
        $disp = if ($nameByEmail.ContainsKey($k) -and $nameByEmail[$k]) { $nameByEmail[$k] } else { $k }
        $authorList += [pscustomobject]@{ email = [string]$k; name = $disp; commits = [int]$authorCommitCounts[$k] }
    }
    $authorList = @($authorList | Sort-Object @{Expression={ [int]$_.commits }; Descending=$true }, @{Expression={ [string]$_.email }})
    $topAuthorEmail = ''
    $topAuthorName = ''
    $topAuthorCommits = 0
    if ($authorList.Count -gt 0) {
        $topAuthorEmail = [string]$authorList[0].email
        $topAuthorName = [string]$authorList[0].name
        $topAuthorCommits = [int]$authorList[0].commits
    }

    return [pscustomobject]@{
        commitCount       = [int]$commitCount
        firstDate         = $firstDate
        lastDate          = $lastDate
        authorCount       = $authorList.Count
        authors           = $authorList
        topAuthorEmail    = $topAuthorEmail
        topAuthorName     = $topAuthorName
        topAuthorCommits  = [int]$topAuthorCommits
    }
}

# --- CODEOWNERS parsing (when present) ---------------------------------------
# Returns ordered list of @{ pattern; owners } + the default (`*`) owner.
function Get-AppDocGitCodeowners {
    [CmdletBinding()]
    param([Parameter(Mandatory=$true)][string]$RootPath)

    $entries = @()
    $defaultOwner = ''
    $found = $false
    foreach ($name in @('CODEOWNERS', 'docs/CODEOWNERS', '.github/CODEOWNERS')) {
        $p = Join-Path $RootPath $name
        if (Test-Path -LiteralPath $p) { $found = $true; break }
    }
    if ($found) {
        try {
            foreach ($ln in (Get-Content -LiteralPath $p -ErrorAction SilentlyContinue)) {
                $t = ($ln -replace '\r', '').Trim()
                if ($t -eq '' -or $t.StartsWith('#')) { continue }
                $cols = $t -split '\s+'
                if ($cols.Count -lt 2) { continue }
                $pattern = $cols[0]
                $owners = @($cols[1..($cols.Count - 1)])
                $entries += [pscustomobject]@{ pattern = $pattern; owners = $owners }
                if ($pattern -eq '*') { $defaultOwner = ($owners -join ', ') }
            }
        }
        catch { }
    }
    return [pscustomobject]@{
        present      = [bool]$found
        defaultOwner = $defaultOwner
        entries      = $entries
    }
}

# --- per-file ownership (owner=last-change author, lastChange date, churn) ----
# Aggregates a single `git log --numstat` pass (newest-first) into per-file records:
#   owner          author of the LATEST commit that touched the file
#   lastChangeDate committed date of that latest commit
#   churn          distinct commit count that touched the file (instability)
# Deterministic order: churn (desc), then path (asc). Capped at $MaxFiles (default 400).
# SHALLOW-HISTORY GATE: if $HistorySufficient is $false, every owner is 'Unknown'
# (a single commit's author is NOT meaningful ownership).
function Get-AppDocGitFileOwnership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RootPath,
        [Parameter(Mandatory=$false)][bool]$HistorySufficient = $true,
        [Parameter(Mandatory=$false)][int]$MaxFiles = 400
    )

    $fileMap = @{}   # path -> @{ commits = <count>; ownerEmail; ownerName; lastDate }
    try {
        $raw = @(& git -C $RootPath log --pretty=format:'@@APPCOMMIT@@|%ae|%an|%ad' --date=short --numstat 2>$null)
        $curEmail = ''; $curName = ''; $curDate = ''
        foreach ($ln in $raw) {
            if ([string]::IsNullOrWhiteSpace($ln)) { continue }
            if ($ln.StartsWith('@@APPCOMMIT@@')) {
                $p = $ln.Substring(13).Split('|')
                if ($p.Count -ge 4) { $curEmail = $p[1]; $curName = $p[2]; $curDate = $p[3] }
                continue
            }
            # numstat row: <added>\t<deleted>\t<path> (renames: <path>{old => new}<path>)
            $tabParts = $ln -split "`t"
            if ($tabParts.Count -lt 3) { continue }
            $pathRaw = $tabParts[2]
            # Normalize a rename path "old{old => new}new" -> new path.
            if ($pathRaw -match '\{(.*) => (.*?)([^{}]*)\}$') { $pathRaw = $matches[2] + $matches[3] }
            if ([string]::IsNullOrWhiteSpace($pathRaw)) { continue }
            if (-not $fileMap.ContainsKey($pathRaw)) {
                $fileMap[$pathRaw] = @{ commits = 0; ownerEmail = ''; ownerName = ''; lastDate = '' }
            }
            # Newest-first: the FIRST commit that lists the file is its latest -> set owner/date once.
            if ($fileMap[$pathRaw].commits -eq 0) {
                $fileMap[$pathRaw].ownerEmail = $curEmail
                $fileMap[$pathRaw].ownerName  = $curName
                $fileMap[$pathRaw].lastDate   = $curDate
            }
            $fileMap[$pathRaw].commits++
        }
    }
    catch { }

    $sufficient = [bool]$HistorySufficient
    $records = @()
    foreach ($path in $fileMap.Keys) {
        $m = $fileMap[$path]
        $owner = 'Unknown'
        $lastChange = 'Unknown'
        if ($sufficient -and $m.ownerEmail) {
            $disp = if ($m.ownerName -and $m.ownerName -ne $m.ownerEmail) { "$($m.ownerName) <$($m.ownerEmail)>" } else { $m.ownerEmail }
            $owner = $disp
            if ($m.lastDate) { $lastChange = $m.lastDate }
        }
        $records += [pscustomobject]@{
            path         = $path
            owner        = $owner
            lastChange   = $lastChange
            churn        = [int]$m.commits
        }
    }
    # Deterministic: churn desc, then path asc. Cap.
    $records = @($records | Sort-Object @{Expression={ [int]$_.churn }; Descending=$true }, @{Expression={ [string]$_.path }})
    return @($records | Select-Object -First $MaxFiles)
}

# --- top-level ownership record (feeds §13 + the 'ownership' source-doc category)
# owner = CODEOWNERS default (`*`) when present; else 'Unknown' (honest — a last-change
# author is NOT declared application ownership). historySufficient gates real attribution.
function Get-AppDocGitOwnership {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RootPath,
        [Parameter(Mandatory=$false)][int]$MinCommitsForOwnership = 2,
        [Parameter(Mandatory=$false)][int]$MaxFiles = 400
    )

    $isGit = Test-AppDocGitRepo -RootPath $RootPath
    $commitCount = 0
    $historySufficient = $false
    $authors = @()
    $topAuthorEmail = ''; $topAuthorName = ''; $topAuthorCommits = 0
    $firstDate = ''; $lastDate = ''; $authorCount = 0

    if ($isGit) {
        $stats = Get-AppDocGitHistoryStats -RootPath $RootPath
        $commitCount = [int]$stats.commitCount
        $authors = @($stats.authors)
        $topAuthorEmail = [string]$stats.topAuthorEmail
        $topAuthorName = [string]$stats.topAuthorName
        $topAuthorCommits = [int]$stats.topAuthorCommits
        $firstDate = [string]$stats.firstDate
        $lastDate = [string]$stats.lastDate
        $authorCount = [int]$stats.authorCount
        $historySufficient = ($commitCount -ge $MinCommitsForOwnership)
    }

    $codeowners = Get-AppDocGitCodeowners -RootPath $RootPath
    $files = @()
    if ($isGit) {
        $files = @(Get-AppDocGitFileOwnership -RootPath $RootPath -HistorySufficient $historySufficient -MaxFiles $MaxFiles)
    }

    # Overall owner: declared CODEOWNERS default wins (that IS declared ownership).
    # Otherwise 'Unknown' (honest) — even on a multi-commit repo, the last-change author
    # is a per-file attribution signal, not the application owner.
    $overallOwner = 'Unknown'
    if ($codeowners.present -and $codeowners.defaultOwner) { $overallOwner = $codeowners.defaultOwner }

    # status: 'Derived' only when git history is real AND sufficient; 'Unknown' otherwise.
    $status = if ($historySufficient) { 'Derived' } else { 'Unknown' }
    if (-not $isGit) { $status = 'Unknown' }

    return [pscustomobject]@{
        isGitRepo             = [bool]$isGit
        commitCount           = [int]$commitCount
        minCommitsForOwnership= [int]$MinCommitsForOwnership
        historySufficient     = [bool]$historySufficient
        status                = $status
        owner                 = $overallOwner
        codeownersPresent     = [bool]$codeowners.present
        codeownersDefault     = $codeowners.defaultOwner
        codeowners            = @($codeowners.entries)
        authorCount           = [int]$authorCount
        firstDate             = $firstDate
        lastDate              = $lastDate
        topAuthorEmail        = $topAuthorEmail
        topAuthorName         = $topAuthorName
        topAuthorCommits      = [int]$topAuthorCommits
        authors               = $authors
        files                 = $files
    }
}

Export-ModuleMember -Function @(
    'Test-AppDocGitRepo',
    'Get-AppDocGitHistoryStats',
    'Get-AppDocGitCodeowners',
    'Get-AppDocGitFileOwnership',
    'Get-AppDocGitOwnership'
)
