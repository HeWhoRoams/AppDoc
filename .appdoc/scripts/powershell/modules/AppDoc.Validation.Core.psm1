function Get-AppDocValidationArtifacts {
    [CmdletBinding()]
    param()

    return @(
        "overview.md",
        "api-inventory.md",
        "data-model.md",
        "config-catalog.md",
        "build-cookbook.md",
        "test-catalog.md",
        "debt-register.md",
        "dependencies-catalog.md"
    )
}

function Get-AppDocValidationEvidenceArtifacts {
    [CmdletBinding()]
    param()

    return @(
        "overview",
        "api-inventory",
        "data-model",
        "config-catalog",
        "build-cookbook",
        "test-catalog",
        "debt-register",
        "dependencies-catalog"
    )
}

function Get-AppDocValidatorScripts {
    [CmdletBinding()]
    param()

    return @(
        @{ script = "validate-overview.ps1"; artifact = "overview.md" },
        @{ script = "validate-api-inventory.ps1"; artifact = "api-inventory.md" },
        @{ script = "validate-data-model.ps1"; artifact = "data-model.md" },
        @{ script = "validate-config-catalog.ps1"; artifact = "config-catalog.md" },
        @{ script = "validate-build-cookbook.ps1"; artifact = "build-cookbook.md" },
        @{ script = "validate-test-catalog.ps1"; artifact = "test-catalog.md" },
        @{ script = "validate-debt-register.ps1"; artifact = "debt-register.md" },
        @{ script = "validate-dependencies-catalog.ps1"; artifact = "dependencies-catalog.md" }
    )
}

Export-ModuleMember -Function @(
    'Get-AppDocValidationArtifacts',
    'Get-AppDocValidationEvidenceArtifacts',
    'Get-AppDocValidatorScripts'
)
