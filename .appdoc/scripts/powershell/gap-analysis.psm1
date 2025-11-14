# Gap analysis data structures

class AISample {
    [string]$Id
    [string]$Type
    [int]$QualityScore
    [bool]$HasCodeSnippets
    [bool]$HasDiagrams
    [string]$Content
}

class QualityGap {
    [string]$Id
    [string]$AISampleId
    [string]$GapType
    [string]$Severity
    [string]$Description
    [string]$CurrentState
    [string]$TargetState
}

class Improvement {
    [string]$Id
    [string]$QualityGapId
    [string]$Component
    [string]$Description
    [string]$ImplementationApproach
    [string]$EstimatedEffort
    [int]$Priority
}

function New-GapAnalysis {
    return @{
        Samples = [System.Collections.Generic.List[AISample]]::new()
        Gaps = [System.Collections.Generic.List[QualityGap]]::new()
        Improvements = [System.Collections.Generic.List[Improvement]]::new()
    }
}

function Add-AISample {
    param(
        [hashtable]$Analysis,
        [string]$Id,
        [string]$Type,
        [int]$QualityScore,
        [bool]$HasCodeSnippets,
        [bool]$HasDiagrams,
        [string]$Content
    )
    
    $sample = [AISample]@{
        Id = $Id
        Type = $Type
        QualityScore = $QualityScore
        HasCodeSnippets = $HasCodeSnippets
        HasDiagrams = $HasDiagrams
        Content = $Content
    }
    
    $Analysis.Samples.Add($sample)
}

function Add-QualityGap {
    param(
        [hashtable]$Analysis,
        [string]$AISampleId,
        [string]$GapType,
        [string]$Severity,
        [string]$Description,
        [string]$CurrentState,
        [string]$TargetState
    )
    
    $gap = [QualityGap]@{
        Id = [guid]::NewGuid().ToString()
        AISampleId = $AISampleId
        GapType = $GapType
        Severity = $Severity
        Description = $Description
        CurrentState = $CurrentState
        TargetState = $TargetState
    }
    
    $Analysis.Gaps.Add($gap)
}

Export-ModuleMember -Function New-GapAnalysis, Add-AISample, Add-QualityGap