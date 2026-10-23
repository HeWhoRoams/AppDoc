# AppDoc.Config Module
# Purpose: Load a per-target AppDoc build configuration from <target>/.appdoc/config.json
#          and expose it with SENSIBLE DEFAULTS when the file is absent.
#
#          The single command (run-appdoc-build.ps1) reads this config to drive:
#            - theme            : HTML report theme (default: CMU Maroon & Gold #6a0032/#ffc82e)
#            - redactionPatterns: extra secret VALUES to redact, matched literally (additive)
#            - redactionRegexes : extra regular expressions to redact (additive; invalid = error)
#            - pristineFloor    : pristine gate floor (default 80)
#            - outputDir        : docs output dir (default 'docs')
#            - minCommitsForOwnership: git-history depth floor for real ownership
#                                      attribution (default 2). Below this, git-derived
#                                      owner/churn are honest-Unknown (a 1-commit / squashed
#                                      history is NOT meaningful ownership).
#            - enableSemanticEnrich : opt-in semantic (LLM) enrichment stage (Phase 2a,
#                                      default OFF). When OFF, the deterministic pipeline
#                                      produces exactly today's output (no LLM call, no
#                                      enrichment applied, the deterministic layer stays
#                                      the gate-able core). When ON the deterministic
#                                      apply-merge reads docs/evidence/semantic/output/
#                                      (written by the EXTERNAL LLM session) and applies it
#                                      under the quarantine (provenance + Verified-fact
#                                      lock). A provider-agnostic, deterministic substrate.
#
#          BACKWARD-COMPAT: when <target>/.appdoc/config.json is absent (the common case),
#          every field returns its default, so a target with NO config behaves EXACTLY as
#          today. Nothing here calls git or mutates the extractors — it only READS a config
#          file and resolves a theme path. Deterministic. No LLM. No network.
$script:AppDocConfigVersion = "1.0.0"

# Default CMU Maroon & Gold theme (matches .appdoc/templates/html/theme.json).
$script:AppDocConfigDefaults = [ordered]@{
    schemaVersion            = 'appdoc-config/v1'
    theme                    = 'cmu'              # name -> .appdoc/templates/html/<name>.json ; or an absolute path
    themeFile                = ''                # explicit theme .json path (overrides 'theme' when set)
    redactionPatterns        = @()               # extra secret VALUES, matched literally
    redactionRegexes         = @()               # extra regular expressions; every match is redacted
    opaqueTokenPattern       = ''                # regex for sanitized placeholder tokens kept verbatim (default: none)
    overlays                 = @{}               # section title -> overlay .md path (default: .appdoc/overlays/<slug>.md)
    ownershipShowEmails      = $false            # config "ownership": { "showEmails": true } -> include author emails
    pristineFloor            = 80                # pristine gate floor (1..100)
    outputDir                = 'docs'            # docs output dir name under the target root
    minCommitsForOwnership   = 2                 # git history depth floor for real ownership (default 2)
    enableSemanticEnrich     = $false            # opt-in semantic (LLM) enrichment stage (default OFF)
}

# Canonical default theme resolution (relative to this module's templates dir).
function Get-AppDocConfigTemplatesDir {
    [CmdletBinding()]
    param()
    # Cross-platform: climb out of <repo>/.appdoc/scripts/powershell/modules to <repo>/.appdoc/templates/html.
    # $PSScriptRoot = <repo>/.appdoc/scripts/powershell/modules
    $root = (Join-Path $PSScriptRoot '..')     # -> powershell
    $root = (Join-Path $root '..')             # -> scripts
    $root = (Join-Path $root '..')             # -> .appdoc
    $root = (Join-Path $root 'templates')      # -> .appdoc/templates
    $root = (Join-Path $root 'html')           # -> .appdoc/templates/html
    return $root
}

# Resolve a theme NAME or PATH to a concrete theme .json file.
#   - $ThemePath is a readable file path   -> use it directly.
#   - $ThemeName is a non-empty name        -> .appdoc/templates/html/<name>.json
#   - otherwise (both empty)                -> the default cmu theme.json.
# Returns an absolute path string (or $null when it cannot be resolved).
function Resolve-AppDocThemePath {
    [CmdletBinding()]
    param(
        [AllowEmptyString()][string]$ThemePath = '',
        [AllowEmptyString()][string]$ThemeName = '',
        # Relative theme paths resolve against the target root (falls back to the
        # current directory when not given).
        [AllowEmptyString()][string]$RootPath = ''
    )
    $templatesDir = Get-AppDocConfigTemplatesDir
    $resolveFile = {
        param([string]$p)
        if ([System.IO.Path]::IsPathRooted($p)) { $cand = $p }
        elseif ($RootPath) { $cand = Join-Path $RootPath $p }
        else { $cand = $p }
        if (Test-Path -LiteralPath $cand -PathType Leaf) { return (Resolve-Path -LiteralPath $cand).Path }
        return $null
    }

    # Explicit theme file wins. A file that does not exist is an error, not a silent
    # fallback: the operator asked for a specific look.
    if (-not [string]::IsNullOrWhiteSpace($ThemePath)) {
        $hit = & $resolveFile $ThemePath
        if ($hit) { return $hit }
        throw "Theme file not found: $ThemePath"
    }

    if (-not [string]::IsNullOrWhiteSpace($ThemeName)) {
        # A path given as the theme (absolute, or relative to the target, ending in .json).
        if ([System.IO.Path]::IsPathRooted($ThemeName) -or $ThemeName -match '[\\/]' -or $ThemeName -like '*.json') {
            $hit = & $resolveFile $ThemeName
            if ($hit) { return $hit }
            if (-not ($ThemeName -like '*.json' -and $ThemeName -notmatch '[\\/]')) { throw "Theme file not found: $ThemeName" }
        }
        # A bundled theme name: templates/html/<name>.json ('cmu' is the canonical theme.json).
        $bundledName = if ($ThemeName -ieq 'cmu') { 'theme' } else { $ThemeName -replace '\.json$', '' }
        $candidate = Join-Path $templatesDir "$bundledName.json"
        if (Test-Path -LiteralPath $candidate) { return (Resolve-Path -LiteralPath $candidate).Path }
        $available = @(Get-ChildItem -LiteralPath $templatesDir -Filter '*.json' -File -ErrorAction SilentlyContinue | ForEach-Object { if ($_.BaseName -eq 'theme') { 'cmu' } else { $_.BaseName } } | Sort-Object)
        Write-Warning ("[Theme] '{0}' not found; available: {1}. Using the default (cmu)." -f $ThemeName, ($available -join ', '))
    }
    # Default CMU theme.
    $default = Join-Path $templatesDir 'theme.json'
    if (Test-Path -LiteralPath $default) { return (Resolve-Path -LiteralPath $default).Path }
    return $null
}

# Load and normalize the AppDoc config for a target root.
# Returns an [ordered] dictionary with EVERY default key present (missing keys filled
# from $script:AppDocConfigDefaults). When the config file is absent/invalid, the
# defaults are returned unchanged (backward-compat: a no-config target == today's behavior).
function Get-AppDocConfig {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$RootPath
    )

    $config = @{}
    foreach ($k in $script:AppDocConfigDefaults.Keys) { $config[$k] = $script:AppDocConfigDefaults[$k] }

    $configPath = Join-Path (Join-Path $RootPath ".appdoc") "config.json"
    $loaded = $false
    $loadError = ''
    if (Test-Path -LiteralPath $configPath) {
        try {
            $raw = Get-Content -LiteralPath $configPath -Raw | ConvertFrom-Json -Depth 30
            $loaded = $true
            # themeFile (explicit path) takes precedence over theme (name).
            if ($raw.PSObject.Properties['themeFile'] -and $raw.themeFile) { $config['themeFile'] = [string]$raw.themeFile }
            if ($raw.PSObject.Properties['theme'] -and $raw.theme) { $config['theme'] = [string]$raw.theme }
            if ($raw.PSObject.Properties['redactionPatterns']) {
                $config['redactionPatterns'] = @($raw.redactionPatterns | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
            if ($raw.PSObject.Properties['redactionRegexes']) {
                $config['redactionRegexes'] = @($raw.redactionRegexes | ForEach-Object { [string]$_ } | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
            if ($raw.PSObject.Properties['opaqueTokenPattern'] -and $raw.opaqueTokenPattern) {
                $otp = [string]$raw.opaqueTokenPattern
                try { [void][regex]::new($otp) } catch { throw "opaqueTokenPattern is not a valid regular expression: $otp" }
                $config['opaqueTokenPattern'] = $otp
            }
            if ($raw.PSObject.Properties['overlays'] -and $raw.overlays) {
                $ov = @{}
                foreach ($prop in $raw.overlays.PSObject.Properties) { $ov[[string]$prop.Name] = [string]$prop.Value }
                $config['overlays'] = $ov
            }
            if ($raw.PSObject.Properties['ownership'] -and $raw.ownership -and $raw.ownership.PSObject.Properties['showEmails']) {
                $config['ownershipShowEmails'] = [bool]$raw.ownership.showEmails
            }
            if ($raw.PSObject.Properties['pristineFloor'] -and $raw.pristineFloor) { $config['pristineFloor'] = [int]$raw.pristineFloor }
            if ($raw.PSObject.Properties['outputDir'] -and $raw.outputDir) { $config['outputDir'] = [string]$raw.outputDir }
            if ($raw.PSObject.Properties['minCommitsForOwnership'] -and $raw.minCommitsForOwnership) { $config['minCommitsForOwnership'] = [int]$raw.minCommitsForOwnership }
            if ($null -ne $raw.PSObject.Properties['enableSemanticEnrich'] -and $null -ne $raw.enableSemanticEnrich) { $config['enableSemanticEnrich'] = [bool]$raw.enableSemanticEnrich }
        }
        catch {
            # Invalid JSON: report it. The build treats this as an error (fail-closed),
            # because silently using defaults would drop the operator's redaction lists.
            $loaded = $false
            $loadError = "invalid config file ${configPath}: $($_.Exception.Message)"
        }
    }

    # Theme problems (a missing theme file) are reported through .error so the build can
    # stop with a clear message instead of silently using another theme.
    $themeResolved = $null
    try { $themeResolved = Resolve-AppDocThemePath -ThemePath $config['themeFile'] -ThemeName $config['theme'] -RootPath $RootPath }
    catch { if (-not $loadError) { $loadError = $_.Exception.Message } }

    return [pscustomobject]@{
        configPath     = $configPath
        loaded         = [bool]$loaded
        # Non-empty when the config file exists but could not be parsed.
        error          = [string]$loadError
        # $config is a plain hashtable with every default key present.
        values         = $config
        # Resolved theme file path (default cmu when absent). $null if unresolvable.
        themePath      = $themeResolved
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocConfig',
    'Resolve-AppDocThemePath',
    'Get-AppDocConfigTemplatesDir'
)
