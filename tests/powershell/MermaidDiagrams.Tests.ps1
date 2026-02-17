# Pester Tests for Mermaid C4 Diagram Generation
# Purpose: Validate Mermaid-based C4 generation workflow

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$generatorPath = Join-Path $repoRoot ".appdoc\scripts\powershell\generate-c4-mermaid-diagrams.ps1"
$fixtureRoot = Join-Path $PSScriptRoot "fixtures\sample-dotnet-app"
$tempRoot = Join-Path $PSScriptRoot "test-output"

Describe "Mermaid C4 Diagram Generation" {
    BeforeEach {
        if (Test-Path $tempRoot) {
            Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
        Copy-Item -Path $fixtureRoot -Destination (Join-Path $tempRoot "sample-dotnet-app") -Recurse -Force
    }

    It "Generates C4 Mermaid markdown files" {
        $workRoot = Join-Path $tempRoot "sample-dotnet-app"
        & $generatorPath -CodebasePath $workRoot -OutputPath (Join-Path $workRoot "docs") -DiagramLevels All -Force

        $contextPath = Join-Path $workRoot "docs\diagrams\c4-context.md"
        $containerPath = Join-Path $workRoot "docs\diagrams\c4-container.md"

        (Test-Path $contextPath) | Should Be $true
        (Test-Path $containerPath) | Should Be $true

        $contextContent = Get-Content $contextPath -Raw
        $containerContent = Get-Content $containerPath -Raw

        ($contextContent -match '```mermaid') | Should Be $true
        ($containerContent -match '```mermaid') | Should Be $true
    }

    It "Updates overview architecture section with Mermaid references" {
        $workRoot = Join-Path $tempRoot "sample-dotnet-app"
        & $generatorPath -CodebasePath $workRoot -OutputPath (Join-Path $workRoot "docs") -DiagramLevels All -Force

        $overviewPath = Join-Path $workRoot "docs\overview.md"
        $overviewContent = Get-Content $overviewPath -Raw

        ($overviewContent -match '## Architecture') | Should Be $true
        ($overviewContent -match 'C4 Context') | Should Be $true
        ($overviewContent -match 'C4 Container') | Should Be $true
    }

    AfterEach {
        if (Test-Path $tempRoot) {
            Remove-Item $tempRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}
