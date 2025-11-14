param(
    [Parameter(Mandatory=$true)]
    [string]$DocsDir,
    [string]$SamplesDir
)

# Calculate quality metrics
Write-Host "Calculating quality metrics..."

Import-Module ".\quality-framework.psm1"

$metrics = @{
    currentDocs = @()
    aiSamples = @()
    comparison = @{}
}

# Analyze current docs
$currentDocs = Get-ChildItem -Path $DocsDir -File -Recurse | Where-Object { $_.Extension -eq ".md" }
foreach ($doc in $currentDocs) {
    $content = Get-Content $doc.FullName -Raw
    $score = Get-DocQualityScore -Content $content -Type "current"
    $metrics.currentDocs += @{
        name = $doc.Name
        score = $score
        length = $content.Length
        hasCode = [bool]($content -match '```')
        hasDiagrams = [bool]($content -match 'classDiagram|sequenceDiagram|flowchart')
    }
}

# Analyze AI samples
$samples = Get-ChildItem -Path $SamplesDir -File -Recurse | Where-Object { $_.Extension -in ".md",".txt" }
foreach ($sample in $samples) {
    $content = Get-Content $sample.FullName -Raw
    $score = Get-DocQualityScore -Content $content -Type "sample"
    $metrics.aiSamples += @{
        name = $sample.Name
        score = $score
        length = $content.Length
        hasCode = [bool]($content -match '```')
        hasDiagrams = [bool]($content -match 'classDiagram|sequenceDiagram|flowchart')
    }
}

# Calculate comparison metrics
$currentAvg = if ($metrics.currentDocs.Count -gt 0) { ($metrics.currentDocs | Measure-Object -Property score -Average).Average } else { 0 }
$sampleAvg = if ($metrics.aiSamples.Count -gt 0) { ($metrics.aiSamples | Measure-Object -Property score -Average).Average } else { 0 }

$metrics.comparison = @{
    currentAverageScore = $currentAvg
    aiSampleAverageScore = $sampleAvg
    scoreGap = $sampleAvg - $currentAvg
    currentDocCount = $metrics.currentDocs.Count
    aiSampleCount = $metrics.aiSamples.Count
    codeSnippetCoverage = @{
        current = ($metrics.currentDocs | Where-Object { $_.hasCode }).Count / $metrics.currentDocs.Count
        ai = ($metrics.aiSamples | Where-Object { $_.hasCode }).Count / $metrics.aiSamples.Count
    }
    diagramCoverage = @{
        current = ($metrics.currentDocs | Where-Object { $_.hasDiagrams }).Count / $metrics.currentDocs.Count
        ai = ($metrics.aiSamples | Where-Object { $_.hasDiagrams }).Count / $metrics.aiSamples.Count
    }
}

$metrics | ConvertTo-Json -Depth 4 | Out-File -FilePath "specs/001-review-ai-samples/quality-metrics.json" -Encoding UTF8

Write-Host "Quality metrics calculated and saved"