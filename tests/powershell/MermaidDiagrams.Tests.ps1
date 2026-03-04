# Pester Tests for Mermaid C4 Diagram Generation
# Purpose: Validate Mermaid-based C4 generation workflow

$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$generatorPath = Join-Path $repoRoot ".appdoc\scripts\powershell\generate-c4-mermaid-diagrams.ps1"
$fixtureRoot = Join-Path $PSScriptRoot "fixtures\sample-dotnet-app"
$tempRoot = Join-Path $PSScriptRoot "test-output"

function Remove-DirectoryRobust {
    param(
        [Parameter(Mandatory=$true)]
        [string]$Path,
        [int]$MaxRetries = 5
    )

    if (-not (Test-Path $Path)) { return }

    $lastError = $null
    for ($attempt = 1; $attempt -le $MaxRetries; $attempt++) {
        try {
            Get-ChildItem -Path $Path -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
                try {
                    if ($_.Attributes -band [IO.FileAttributes]::ReadOnly) {
                        $_.Attributes = ($_.Attributes -bxor [IO.FileAttributes]::ReadOnly)
                    }
                }
                catch {}
            }

            Remove-Item -Path $Path -Recurse -Force -ErrorAction Stop
            if (-not (Test-Path $Path)) { return }
        }
        catch {
            $lastError = $_.Exception.Message
            Start-Sleep -Milliseconds (150 * $attempt)
        }
    }

    Write-Warning ("Failed to remove test directory after {0} attempts: {1}. Last error: {2}" -f $MaxRetries, $Path, $lastError)
}

Describe "Mermaid C4 Diagram Generation" {
    BeforeAll {
        Remove-DirectoryRobust -Path $tempRoot
        New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
    }

    BeforeEach {
        $script:workRoot = Join-Path $tempRoot ("sample-dotnet-app-" + [Guid]::NewGuid().ToString("N"))
        Copy-Item -Path $fixtureRoot -Destination $script:workRoot -Recurse -Force
    }

    It "Generates C4 Mermaid markdown files" {
        $workRoot = $script:workRoot
        & $generatorPath -CodebasePath $workRoot -OutputPath (Join-Path $workRoot "docs") -DiagramLevels All -Force

        $contextPath = Join-Path (Join-Path (Join-Path (Join-Path $workRoot "docs") "diagrams") "c4-context.md")
        $containerPath = Join-Path (Join-Path (Join-Path (Join-Path $workRoot "docs") "diagrams") "c4-container.md")

        (Test-Path $contextPath) | Should Be $true
        (Test-Path $containerPath) | Should Be $true

        $contextContent = Get-Content $contextPath -Raw
        $containerContent = Get-Content $containerPath -Raw

        ($contextContent -match '```mermaid') | Should Be $true
        ($containerContent -match '```mermaid') | Should Be $true
    }

    It "Updates overview architecture section with Mermaid references" {
        $workRoot = $script:workRoot
        & $generatorPath -CodebasePath $workRoot -OutputPath (Join-Path $workRoot "docs") -DiagramLevels All -Force

        $overviewPath = Join-Path $workRoot "docs\overview.md"
        $overviewContent = Get-Content $overviewPath -Raw

        ($overviewContent -match '## Architecture') | Should Be $true
        ($overviewContent -match 'C4 Context') | Should Be $true
        ($overviewContent -match 'C4 Container') | Should Be $true
    }

    AfterEach {
        if ($script:workRoot) {
            Remove-DirectoryRobust -Path $script:workRoot
        }
    }

    AfterAll {
        Remove-DirectoryRobust -Path $tempRoot
    }
}
