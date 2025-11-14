# Quality scoring framework and criteria

function Get-DocQualityScore {
    param(
        [string]$Content,
        [string]$Type
    )
    
    $score = 0
    $maxScore = 10
    
    # Code snippets (2 points)
    if ($Content -match '```') { $score += 2 }
    
    # Diagrams (2 points)
    if ($Content -match 'classDiagram|sequenceDiagram|flowchart|erDiagram') { $score += 2 }
    
    # Technical depth (2 points)
    $techTerms = @('interface', 'class', 'function', 'method', 'API', 'endpoint', 'schema')
    $techCount = 0
    foreach ($term in $techTerms) {
        if ($Content -match $term) { $techCount++ }
    }
    $score += [Math]::Min($techCount, 2)
    
    # Length and completeness (2 points)
    if ($Content.Length -gt 2000) { $score += 1 }
    if ($Content -match '## ' -and ($Content | Select-String -Pattern '## ' | Measure-Object).Count -gt 3) { $score += 1 }
    
    # Relationships and structure (2 points)
    if ($Content -match 'relates to|depends on|references') { $score += 1 }
    if ($Content -match '\|.*\|.*\|' -or $Content -match '- \[') { $score += 1 } # Tables or lists
    
    return [Math]::Min($score, $maxScore)
}

function Get-QualityCriteria {
    return @(
        @{ Name = "Code Snippets"; Weight = 2; Description = "Includes runnable code examples" }
        @{ Name = "Visual Diagrams"; Weight = 2; Description = "Has Mermaid or other diagrams" }
        @{ Name = "Technical Depth"; Weight = 2; Description = "Uses technical terminology appropriately" }
        @{ Name = "Content Length"; Weight = 1; Description = "Sufficient detail (>2000 chars)" }
        @{ Name = "Structure"; Weight = 1; Description = "Well-organized with sections" }
        @{ Name = "Relationships"; Weight = 1; Description = "Shows component relationships" }
        @{ Name = "Formatting"; Weight = 1; Description = "Uses tables, lists, proper markdown" }
    )
}

Export-ModuleMember -Function Get-DocQualityScore, Get-QualityCriteria