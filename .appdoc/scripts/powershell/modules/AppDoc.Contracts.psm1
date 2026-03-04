# AppDoc.Contracts Module
# Purpose: Shared record contracts for extraction, diagnostics, validation, and framework support

$script:AppDocContractsVersion = "2.0.0"

function Get-AppDocArtifactContract {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("start-here","overview","api-inventory","data-model","config-catalog","build-cookbook","test-catalog","debt-register","dependencies-catalog","task-guides")]
        [string]$Artifact
    )

    $contracts = @{
        "start-here" = @{
            requiredSections = @("Who This Is For","First 30 Minutes","First 3 Files","Expected Outputs","Role-Based Paths","System Signals","Evidence Traceability")
            requiredEvidenceKeys = @("summary","endpoints","models")
        }
        "overview" = @{
            requiredSections = @("System Boundary","Runtime Path","Inputs-Processing-Outputs","External Systems","Confidence Notes")
            requiredEvidenceKeys = @("summary","technologies")
        }
        function Normalize-AppDocSectionName {
            param([string]$Name)
            $norm = $Name
            $norm = $norm -replace '\s+', ''
            $norm = $norm -replace '[→\-]+', '-'
            $norm = $norm -replace '->', '-'
            $norm = $norm.ToLowerInvariant()
            return $norm
        }
        "api-inventory" = @{
            requiredSections = @("Executive Summary","API Endpoints")
            requiredEvidenceKeys = @("endpoints")
        }
        "data-model" = @{
            requiredSections = @("Executive Summary","Data Models")
            requiredEvidenceKeys = @("models")
        }
        "config-catalog" = @{
            requiredSections = @("Executive Summary","Configuration Options")
            requiredEvidenceKeys = @("configurations")
        }
        "build-cookbook" = @{
            requiredSections = @("Executive Summary","Build Steps")
            requiredEvidenceKeys = @("commands")
        }
        "test-catalog" = @{
            requiredSections = @("Executive Summary","Test Suites")
            requiredEvidenceKeys = @("testSuites")
        }
        "debt-register" = @{
            requiredSections = @("Executive Summary","Debt Items")
            requiredEvidenceKeys = @("debtItems")
        }
        "dependencies-catalog" = @{
            requiredSections = @("Executive Summary","Dependency Summary")
            requiredEvidenceKeys = @("dependencies")
        }
        "task-guides" = @{
            requiredSections = @("Executive Summary","Task Guides","Operational Checklist")
            requiredEvidenceKeys = @("tasks","summary")
        }
    }

    return $contracts[$Artifact]
}

function Get-AppDocBannedContentPatterns {
    [CmdletBinding()]
    param()

    return @(
        '(?im)^##\s+Population Guide',
        '(?im)_No [^_]+ detected\.',
        '(?im)Describe the purpose and scope',
        '(?im)Provide example',
        '(?im)Refer to .* documentation\.'
    )
}

function New-AppDocExtractionRecord {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Artifact,
        [Parameter(Mandatory=$true)]
        [string]$Source,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [Parameter(Mandatory=$true)]
        [string]$Kind,
        [double]$Confidence = 1.0,
        [hashtable]$Metadata = @{},
        [string]$Provider = "unknown",
        [string]$ProviderType = "regex",
        [string]$Status = "Detected"
    )

    return [ordered]@{
        artifact = $Artifact
        source = $Source
        name = $Name
        kind = $Kind
        confidence = [Math]::Round([Math]::Max(0, [Math]::Min(1, $Confidence)), 4)
        metadata = $Metadata
        provider = $Provider
        providerType = $ProviderType
        status = $Status
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    }
}

function New-AppDocValidationResult {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Artifact,
        [Parameter(Mandatory=$true)]
        [bool]$Passed,
        [int]$Score = 0,
        [string[]]$Issues = @(),
        [string]$RuleSet = "default",
        [string]$Mode = "soft"
    )

    return [ordered]@{
        artifact = $Artifact
        passed = $Passed
        score = [Math]::Max(0, [Math]::Min(100, $Score))
        issues = @($Issues)
        ruleSet = $RuleSet
        mode = $Mode
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    }
}

function New-AppDocDiagnosticEvent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet("NOT_FOUND", "DETECTION_PATTERN_MISMATCH", "UNSUPPORTED_FRAMEWORK", "ENVIRONMENT_ERROR", "PARSING_ERROR", "TEMPLATE_ERROR", "IO_ERROR", "INTERNAL_ERROR")]
        [string]$Category,
        [Parameter(Mandatory=$true)]
        [ValidateSet("Info", "Warning", "Error")]
        [string]$Severity,
        [Parameter(Mandatory=$true)]
        [string]$Message,
        [string]$Component = "orchestrator",
        [string]$FilePath = "",
        [hashtable]$Details = @{}
    )

    return [ordered]@{
        timestamp = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        category = $Category
        severity = $Severity
        component = $Component
        message = $Message
        filePath = $FilePath
        details = $Details
    }
}

function New-AppDocFrameworkCapability {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Language,
        [Parameter(Mandatory=$true)]
        [string]$Framework,
        [Parameter(Mandatory=$true)]
        [ValidateSet("full", "partial", "none", "experimental")]
        [string]$SupportLevel,
        [string]$VersionRange = "",
        [int]$CoveragePercent = 0,
        [string[]]$Limitations = @(),
        [string[]]$DetectionSignals = @()
    )

    return [ordered]@{
        language = $Language
        framework = $Framework
        supportLevel = $SupportLevel
        versionRange = $VersionRange
        coveragePercent = [Math]::Max(0, [Math]::Min(100, $CoveragePercent))
        limitations = @($Limitations)
        detectionSignals = @($DetectionSignals)
    }
}

function ConvertTo-AppDocJson {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$InputObject,
        [int]$Depth = 20
    )

    return ($InputObject | ConvertTo-Json -Depth $Depth)
}

Export-ModuleMember -Function @(
    'New-AppDocExtractionRecord',
    'New-AppDocValidationResult',
    'New-AppDocDiagnosticEvent',
    'New-AppDocFrameworkCapability',
    'ConvertTo-AppDocJson',
    'Get-AppDocArtifactContract',
    'Get-AppDocBannedContentPatterns'
)
