#
# AppDoc.SecretPolicy.psm1
#
# Single source of truth for:
#   (1) the credential KEY-NAME vocabulary used to decide that a config key / table row
#       holds a secret (Get-AppDocCredentialKeywordPattern). The config extractor, the
#       source-docs redactor, the gate's redaction-safety check and the docs remediator
#       all build their regexes from this one list so they cannot drift apart.
#   (2) operator-supplied redaction (Get-AppDocOperatorRedactionMatchers,
#       Invoke-AppDocOperatorRedaction). A target's .appdoc/config.json may list
#         redactionPatterns : exact secret VALUES, matched literally (regex metacharacters
#                             in a value are NOT interpreted), and
#         redactionRegexes  : regular expressions; every match is redacted.
#       An invalid regex is an error (fail-closed): a typo must never silently weaken
#       redaction.
#
# Pure functions; no I/O, no wall-clock.
#

$script:AppDocCredentialKeywords = @(
    'password', 'passwd', 'pwd',
    'secret',
    'token',
    'api[_-]?key',
    'private[_-]?key',
    'connection[_\s-]?string',
    'credentials?',
    'sas(?:token)?',
    'thumbprint',
    'cert(?:ificate)?[_-]?key'
)

function Get-AppDocCredentialKeywordPattern {
    <#
    .SYNOPSIS
        Returns the credential key-name alternation, e.g. "password|passwd|pwd|...".
        It is a bare alternation (no group, no flags) so each caller can embed it in its
        own context, e.g. '(?i)(' + (Get-AppDocCredentialKeywordPattern) + ')'.
    #>
    [CmdletBinding()]
    param()
    return ($script:AppDocCredentialKeywords -join '|')
}

function Get-AppDocOperatorRedactionMatchers {
    <#
    .SYNOPSIS
        Compiles operator redaction into a list of [regex]. Literals are escaped; regexes are
        compiled case-insensitively with a 2 s match timeout. Throws on an invalid regex.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][AllowEmptyCollection()][string[]]$Literals = @(),
        [AllowNull()][AllowEmptyCollection()][string[]]$Regexes = @()
    )
    $matchers = [System.Collections.Generic.List[regex]]::new()
    $timeout = [timespan]::FromSeconds(2)
    foreach ($l in @($Literals | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)) {
        $matchers.Add([regex]::new([regex]::Escape([string]$l), [System.Text.RegularExpressions.RegexOptions]::None, $timeout))
    }
    foreach ($r in @($Regexes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)) {
        try {
            $matchers.Add([regex]::new([string]$r, ([System.Text.RegularExpressions.RegexOptions]::IgnoreCase -bor [System.Text.RegularExpressions.RegexOptions]::CultureInvariant), $timeout))
        }
        catch {
            throw "redactionRegexes: invalid regular expression '$r' - $($_.Exception.InnerException.Message ?? $_.Exception.Message)"
        }
    }
    return , $matchers
}

function Invoke-AppDocOperatorRedaction {
    <#
    .SYNOPSIS
        Replaces every operator match in Text with [REDACTED].
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Text,
        [AllowNull()][AllowEmptyCollection()][System.Collections.Generic.List[regex]]$Matchers
    )
    if ($null -eq $Text) { return '' }
    if ($null -eq $Matchers -or $Matchers.Count -eq 0) { return $Text }
    $t = $Text
    foreach ($m in $Matchers) { $t = $m.Replace($t, '[REDACTED]') }
    return $t
}

function Test-AppDocOperatorRedactionHit {
    <#
    .SYNOPSIS
        Returns the matchers (as pattern strings) that still match Text. Used by the
        fail-closed semantic gate to detect an operator secret that survived redaction.
    #>
    [CmdletBinding()]
    param(
        [AllowNull()][string]$Text,
        [AllowNull()][AllowEmptyCollection()][System.Collections.Generic.List[regex]]$Matchers
    )
    if ([string]::IsNullOrEmpty($Text) -or $null -eq $Matchers) { return @() }
    $hits = @()
    foreach ($m in $Matchers) {
        $c = $m.Matches($Text).Count
        if ($c -gt 0) { $hits += [pscustomobject]@{ pattern = $m.ToString(); count = $c } }
    }
    return $hits
}

# Vendor secret SHAPES (never real values; ADR 0001). Value-scoped: each shape needs a literal
# prefix or a full header, so it cannot match a file path, a key name or an identifier.
$script:AppDocVendorSecretShapes = @(
    '\b(?:AKIA|ASIA)[0-9A-Z]{16}\b',                                        # AWS access key id
    '\b(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}\b',                         # GitHub tokens
    '\bgithub_pat_[A-Za-z0-9_]{22,}\b',                                     # GitHub fine-grained
    '\bxox[baprs]-[A-Za-z0-9-]{10,}\b',                                     # Slack
    '\bsk_live_[A-Za-z0-9]{16,}\b',                                         # Stripe
    '\bAIza[0-9A-Za-z_\-]{35}\b',                                           # Google API key
    '-----BEGIN (?:RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----[\s\S]*?-----END (?:RSA |EC |OPENSSH |DSA |)PRIVATE KEY-----',
    'eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9._\-]{5,}'                          # JWT
)
$script:AppDocVendorSecretRegexes = $null

function Get-AppDocVendorSecretRegexes {
    [CmdletBinding()]
    param()
    if ($null -eq $script:AppDocVendorSecretRegexes) {
        $timeout = [timespan]::FromSeconds(2)
        $script:AppDocVendorSecretRegexes = @($script:AppDocVendorSecretShapes | ForEach-Object {
            [regex]::new($_, [System.Text.RegularExpressions.RegexOptions]::CultureInvariant, $timeout)
        })
    }
    return $script:AppDocVendorSecretRegexes
}

function Get-AppDocVendorSecretShapes {
    [CmdletBinding()]
    param()
    return @($script:AppDocVendorSecretShapes)
}

function Test-AppDocVendorSecret {
    <#
    .SYNOPSIS
        True when Text still contains a vendor secret shape. Used by the build's post-sweep check.
    #>
    [CmdletBinding()]
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return $false }
    foreach ($rx in (Get-AppDocVendorSecretRegexes)) { if ($rx.IsMatch($Text)) { return $true } }
    return $false
}

function Protect-AppDocFreeText {
    <#
    .SYNOPSIS
        Redacts secrets in free text copied from a target (comments, README text, notes):
        vendor shapes, `key = value` for credential key names (key kept, value redacted),
        and Bearer tokens. Idempotent; pure.
    #>
    [CmdletBinding()]
    param([AllowNull()][string]$Text)
    if ([string]::IsNullOrEmpty($Text)) { return '' }
    $t = [string]$Text
    foreach ($rx in (Get-AppDocVendorSecretRegexes)) { $t = $rx.Replace($t, '[REDACTED]') }
    $keywords = 'Secret|Password|Passwd|Pwd|Token|ApiKey|ApiSecret|AccessKey|AccessSecret|PrivateKey|ConnStr|Cipher'
    $t = [regex]::Replace($t, '(?i)\b([A-Za-z0-9_.]*(?:' + $keywords + ')[A-Za-z0-9_.]*\s*=\s*)(["'']?)([^;\s"''\[\]]{4,})', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m) $m.Groups[1].Value + $m.Groups[2].Value + '[REDACTED]'
    })
    $t = [regex]::Replace($t, '(?i)\b(Bearer\s+)[A-Za-z0-9._\-]{20,}', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m) $m.Groups[1].Value + '[REDACTED]'
    })
    return [regex]::Replace($t, '\[REDACTED\](?:\s*\[REDACTED\])+', '[REDACTED]')
}

Export-ModuleMember -Function @(
    'Get-AppDocCredentialKeywordPattern',
    'Get-AppDocOperatorRedactionMatchers',
    'Invoke-AppDocOperatorRedaction',
    'Test-AppDocOperatorRedactionHit',
    'Get-AppDocVendorSecretShapes',
    'Test-AppDocVendorSecret',
    'Protect-AppDocFreeText'
)
