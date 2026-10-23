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

Export-ModuleMember -Function @(
    'Get-AppDocCredentialKeywordPattern',
    'Get-AppDocOperatorRedactionMatchers',
    'Invoke-AppDocOperatorRedaction',
    'Test-AppDocOperatorRedactionHit'
)
