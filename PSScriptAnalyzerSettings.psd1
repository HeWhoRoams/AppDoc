# PSScriptAnalyzer settings for AppDoc (used by the CI "lint" job and editors).
# Rules listed under Enforced fail CI; everything else in IncludeRules is reported only.
@{
    IncludeRules = @(
        'PSUseApprovedVerbs',
        'PSAvoidTrailingWhitespace',
        'PSAvoidUsingEmptyCatchBlock',
        'PSAvoidUsingCmdletAliases',
        'PSUseConsistentIndentation',
        'PSUseConsistentWhitespace',
        'PSAvoidGlobalVars',
        'PSAvoidUsingPlainTextForPassword',
        'PSAvoidUsingInvokeExpression'
    )
    Rules = @{
        PSUseConsistentIndentation = @{ Enable = $true; IndentationSize = 4; Kind = 'space' }
        PSUseConsistentWhitespace  = @{ Enable = $true; CheckOpenBrace = $true; CheckInnerBrace = $false; CheckPipe = $false; CheckOperator = $false; CheckSeparator = $false }
    }
}
