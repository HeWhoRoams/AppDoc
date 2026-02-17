# Pester Tests for C4ModelBuilder Module
# Purpose: Test C4 model extraction from .NET codebases
# Author: AppDoc
# Date: 2025-11-14

# Import the module under test
$repoRoot = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$modulePath = Join-Path $repoRoot ".appdoc\scripts\powershell\modules\C4ModelBuilder.psm1"
Import-Module $modulePath -Force

# Setup test fixtures
$script:FixturesPath = Join-Path $PSScriptRoot "fixtures\sample-dotnet-app"
$script:SolutionPath = Join-Path $FixturesPath "SampleApp.sln"

Describe "C4ModelBuilder Module" {
    
    Context "Get-ProjectFiles" {
        It "Should find projects from solution file" {
            $projects = Get-ProjectFiles -Path $script:SolutionPath
            $projects.Count | Should BeGreaterThan 0
        }

        It "Should find .csproj files when given directory" {
            $projects = Get-ProjectFiles -Path $script:FixturesPath
            $projects.Count | Should Be 3
        }
    }

    Context "Read-CsprojFile" {
        It "Should parse project file and extract metadata" {
            $webProjectPath = Join-Path $script:FixturesPath "SampleApp.Web\SampleApp.Web.csproj"
            $projectData = Read-CsprojFile -ProjectPath $webProjectPath
            
            $projectData | Should Not BeNullOrEmpty
            $projectData.Name | Should Be "SampleApp.Web"
            $projectData.Packages.Count | Should BeGreaterThan 0
        }

        It "Should extract NuGet package references" {
            $webProjectPath = Join-Path $script:FixturesPath "SampleApp.Web\SampleApp.Web.csproj"
            $projectData = Read-CsprojFile -ProjectPath $webProjectPath
            
            $projectData.Packages.Count | Should BeGreaterThan 0
            $httpPackage = $projectData.Packages | Where-Object { $_.Name -like "*Http*" }
            $httpPackage | Should Not BeNullOrEmpty
        }

        It "Should extract project references" {
            $webProjectPath = Join-Path $script:FixturesPath "SampleApp.Web\SampleApp.Web.csproj"
            $projectData = Read-CsprojFile -ProjectPath $webProjectPath
            
            $projectData.ProjectReferences.Count | Should BeGreaterThan 0
            $projectData.ProjectReferences -contains "..\SampleApp.Common\SampleApp.Common.csproj" | Should Be $true
        }

        It "Should return null for non-existent project" {
            $projectData = Read-CsprojFile -ProjectPath "C:\NonExistent\Project.csproj"
            $projectData | Should BeNullOrEmpty
        }
    }

    Context "Get-SolutionInfo" {
        It "Should extract system name from .sln file" {
            $systemInfo = Get-SolutionInfo -SolutionPath $script:SolutionPath
            
            $systemInfo | Should Not BeNullOrEmpty
            $systemInfo.Name | Should Be "SampleApp"
            $systemInfo.Path | Should Be $script:SolutionPath
        }

        It "Should return null for non-existent solution" {
            $systemInfo = Get-SolutionInfo -SolutionPath "C:\NonExistent\Solution.sln"
            $systemInfo | Should BeNullOrEmpty
        }
    }

    Context "Find-ExternalSystems" {
        It "Should detect external systems from NuGet packages" -Pending {
            # This test will be implemented when Find-ExternalSystems function is added
        }

        It "Should detect external systems from HttpClient usages" -Pending {
            # This test will be implemented when Find-ExternalSystems function is added
        }

        It "Should detect database systems from connection string packages" -Pending {
            # This test will be implemented when Find-ExternalSystems function is added
        }
    }

    Context "Build-SystemContextModel" {
        It "Should build complete C4System model" -Pending {
            # This test will be implemented when Build-SystemContextModel function is added
        }
    }

    # ==============================
    # User Story 2: Container Diagrams
    # ==============================

    Context "Get-ContainerType" {
        It "Should detect Web App container from .csproj with Microsoft.AspNetCore" {
            $webProjectPath = Join-Path $script:FixturesPath "SampleApp.Web\SampleApp.Web.csproj"
            $containerType = Get-ContainerType -ProjectPath $webProjectPath
            
            $containerType | Should Be "WebApp"
        }

        It "Should detect Background Service container from Windows Service project" {
            $serviceProjectPath = Join-Path $script:FixturesPath "SampleApp.Service\SampleApp.Service.csproj"
            $containerType = Get-ContainerType -ProjectPath $serviceProjectPath
            
            $containerType | Should Be "Service"
        }

        It "Should detect Database container from Entity Framework references" {
            $commonProjectPath = Join-Path $script:FixturesPath "SampleApp.Common\SampleApp.Common.csproj"
            $containerType = Get-ContainerType -ProjectPath $commonProjectPath
            
            # Common project should be detected as Library (no EF, no ASP.NET)
            $containerType | Should Be "Library"
        }

        It "Should default to Library for unrecognized project types" {
            $commonProjectPath = Join-Path $script:FixturesPath "SampleApp.Common\SampleApp.Common.csproj"
            $containerType = Get-ContainerType -ProjectPath $commonProjectPath
            
            $containerType | Should Be "Library"
        }
    }

    Context "Find-ProjectDependencies" {
        It "Should extract project references as container relationships" {
            $webProjectPath = Join-Path $script:FixturesPath "SampleApp.Web\SampleApp.Web.csproj"
            $dependencies = Find-ProjectDependencies -ProjectPath $webProjectPath
            
            $dependencies | Should Not BeNullOrEmpty
            $dependencies.Count | Should BeGreaterThan 0
            $dependencies -contains "SampleApp.Common" | Should Be $true
        }

        It "Should return empty array for project with no dependencies" {
            $commonProjectPath = Join-Path $script:FixturesPath "SampleApp.Common\SampleApp.Common.csproj"
            $dependencies = Find-ProjectDependencies -ProjectPath $commonProjectPath
            
            $dependencies.Count | Should Be 0
        }

        It "Should handle multiple project references" {
            $serviceProjectPath = Join-Path $script:FixturesPath "SampleApp.Service\SampleApp.Service.csproj"
            $dependencies = Find-ProjectDependencies -ProjectPath $serviceProjectPath
            
            $dependencies | Should Not BeNullOrEmpty
            $dependencies.Count | Should Be 1
        }
    }

    Context "Build-ContainerModel" {
        It "Should create C4Container objects from project files" -Pending {
            # This test will be implemented when Build-ContainerModel function is added
        }

        It "Should include container name, type, and technology" -Pending {
            # This test will be implemented when Build-ContainerModel function is added
        }

        It "Should exclude test projects from container model" -Pending {
            # This test will be implemented when Build-ContainerModel function is added
        }
    }

    Context "Build-ContainerRelationships" {
        It "Should map project references to C4Relationship objects" -Pending {
            # This test will be implemented when Build-ContainerRelationships function is added
        }

        It "Should infer relationship descriptions based on container types" -Pending {
            # This test will be implemented when Build-ContainerRelationships function is added
        }
    }
}

# Cleanup
Remove-Module C4ModelBuilder -Force -ErrorAction SilentlyContinue
