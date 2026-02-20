# AppDoc.Overview.Narrative Module
# Purpose: Build grounded overview narrative from deterministic truth data.

$script:AppDocOverviewNarrativeVersion = "1.0.0"

function Get-AppDocOverviewNarrativeValue {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Object,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        [AllowNull()]
        [object]$Default = $null
    )

    if ($null -eq $Object) { return $Default }

    if ($Object -is [System.Collections.IDictionary]) {
        if ($Object.Contains($Name)) {
            return $Object[$Name]
        }
        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($null -ne $prop) {
        return $prop.Value
    }

    return $Default
}

function Get-AppDocOverviewRequiredNarrativeKeys {
    [CmdletBinding()]
    param()

    return @(
        "what_it_does",
        "inputs",
        "processing_steps",
        "outputs",
        "external_systems",
        "confidence_notes",
        "evidence_refs"
    )
}

function Get-AppDocOverviewEvidenceRefMap {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$TruthPack
    )

    $map = @{}
    $refs = @(Get-AppDocOverviewNarrativeValue -Object $TruthPack -Name "evidence_refs" -Default @())
    foreach ($ref in $refs) {
        $id = [string](Get-AppDocOverviewNarrativeValue -Object $ref -Name "id" -Default "")
        if ([string]::IsNullOrWhiteSpace($id)) { continue }
        if (-not $map.ContainsKey($id)) {
            $map[$id] = $ref
        }
    }
    return $map
}

function ConvertFrom-AppDocOverviewJson {
    [CmdletBinding()]
    param(
        [string]$RawText
    )

    if ([string]::IsNullOrWhiteSpace($RawText)) {
        return $null
    }

    $text = $RawText.Trim()
    $text = [regex]::Replace($text, '^\s*```(?:json)?\s*', '', 'IgnoreCase')
    $text = [regex]::Replace($text, '\s*```\s*$', '', 'IgnoreCase')
    $text = $text.Trim()

    try {
        return ($text | ConvertFrom-Json -Depth 50)
    }
    catch {
        return $null
    }
}

function Get-AppDocOverviewDeterministicWelcomeNarrative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$TruthPack
    )

    $facts = Get-AppDocOverviewNarrativeValue -Object $TruthPack -Name "facts" -Default @{}
    $requiredKeys = Get-AppDocOverviewRequiredNarrativeKeys
    $narrative = [ordered]@{}

    foreach ($key in $requiredKeys) {
        if ($key -eq "evidence_refs") { continue }
        $items = @(Get-AppDocOverviewNarrativeValue -Object $facts -Name $key -Default @())
        $normalized = @()
        foreach ($item in $items) {
            $text = [string](Get-AppDocOverviewNarrativeValue -Object $item -Name "text" -Default "")
            if ([string]::IsNullOrWhiteSpace($text)) { continue }
            $refs = @(
                Get-AppDocOverviewNarrativeValue -Object $item -Name "evidence_refs" -Default @() |
                    ForEach-Object { [string]$_ } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )
            $normalized += [ordered]@{
                text = $text.Trim()
                evidence_refs = $refs
            }
        }

        if ($normalized.Count -eq 0) {
            $fallbackRef = @()
            $truthRefs = @(Get-AppDocOverviewNarrativeValue -Object $TruthPack -Name "evidence_refs" -Default @())
            if ($truthRefs.Count -gt 0) {
                $fallbackRef = @([string](Get-AppDocOverviewNarrativeValue -Object $truthRefs[0] -Name "id" -Default ""))
            }
            $normalized += [ordered]@{
                text = "Deterministic evidence for this section is limited in the current scan."
                evidence_refs = @($fallbackRef | Where-Object { -not [string]::IsNullOrWhiteSpace($_) })
            }
        }

        $narrative[$key] = @($normalized)
    }

    $usedIds = New-Object System.Collections.Generic.HashSet[string]
    foreach ($key in @($narrative.Keys)) {
        foreach ($item in @($narrative[$key])) {
            foreach ($id in @($item.evidence_refs)) {
                if (-not [string]::IsNullOrWhiteSpace([string]$id)) {
                    [void]$usedIds.Add([string]$id)
                }
            }
        }
    }

    $truthRefMap = Get-AppDocOverviewEvidenceRefMap -TruthPack $TruthPack
    $resolvedRefs = @()
    foreach ($id in @($usedIds | Sort-Object)) {
        if ($truthRefMap.ContainsKey($id)) {
            $resolvedRefs += $truthRefMap[$id]
        }
    }

    $narrative["evidence_refs"] = @($resolvedRefs)
    return $narrative
}

function Invoke-AppDocOverviewOpenAINarrative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$TruthPack,
        [string]$ApiKey = "",
        [string]$Model = ""
    )

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        $ApiKey = if ($env:APPDOC_OPENAI_API_KEY) { $env:APPDOC_OPENAI_API_KEY } else { $env:OPENAI_API_KEY }
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        return $null
    }

    if ([string]::IsNullOrWhiteSpace($Model)) {
        $Model = if ($env:APPDOC_OPENAI_MODEL) { $env:APPDOC_OPENAI_MODEL } else { "gpt-4o-mini" }
    }

    $requiredKeys = Get-AppDocOverviewRequiredNarrativeKeys
    $facts = Get-AppDocOverviewNarrativeValue -Object $TruthPack -Name "facts" -Default @{}
    $evidenceRefs = @(Get-AppDocOverviewNarrativeValue -Object $TruthPack -Name "evidence_refs" -Default @())

    $promptPayload = [ordered]@{
        projectName = (Get-AppDocOverviewNarrativeValue -Object $TruthPack -Name "projectName" -Default "")
        architecture = (Get-AppDocOverviewNarrativeValue -Object $TruthPack -Name "architecture" -Default @{})
        counts = (Get-AppDocOverviewNarrativeValue -Object $TruthPack -Name "counts" -Default @{})
        facts = $facts
        evidence_refs = @(
            $evidenceRefs |
                Select-Object -First 300 |
                ForEach-Object {
                    [ordered]@{
                        id = [string](Get-AppDocOverviewNarrativeValue -Object $_ -Name "id" -Default "")
                        artifact = [string](Get-AppDocOverviewNarrativeValue -Object $_ -Name "artifact" -Default "")
                        kind = [string](Get-AppDocOverviewNarrativeValue -Object $_ -Name "kind" -Default "")
                        name = [string](Get-AppDocOverviewNarrativeValue -Object $_ -Name "name" -Default "")
                        source = [string](Get-AppDocOverviewNarrativeValue -Object $_ -Name "source" -Default "")
                    }
                }
        )
    }

    $schemaHelp = @"
Return a strict JSON object only. Required top-level keys:
- what_it_does
- inputs
- processing_steps
- outputs
- external_systems
- confidence_notes
- evidence_refs

For keys except evidence_refs: value must be an array of objects:
{ "text": "<plain-English sentence>", "evidence_refs": ["ev-0001","ev-0002"] }

For evidence_refs: value must be an array of objects selected from input evidence_refs:
{ "id":"ev-0001", "artifact":"...", "kind":"...", "name":"...", "source":"..." }

Rules:
- Do not invent facts.
- Every sentence must include at least one valid evidence ref.
- Keep language plain and concise.
- Keep each section to 1-4 bullets.
"@

    $systemPrompt = "You produce grounded software documentation narrative from deterministic evidence."
    $userPrompt = @"
$schemaHelp

Input truth data:
$(($promptPayload | ConvertTo-Json -Depth 50))
"@

    $body = [ordered]@{
        model = $Model
        temperature = 0.1
        response_format = @{ type = "json_object" }
        messages = @(
            @{ role = "system"; content = $systemPrompt },
            @{ role = "user"; content = $userPrompt }
        )
    }

    try {
        $response = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers @{
            "Authorization" = "Bearer $ApiKey"
            "Content-Type" = "application/json"
        } -Body ($body | ConvertTo-Json -Depth 50)

        $content = [string](Get-AppDocOverviewNarrativeValue -Object (@($response.choices)[0].message) -Name "content" -Default "")
        return (ConvertFrom-AppDocOverviewJson -RawText $content)
    }
    catch {
        Write-Verbose "OpenAI narrative generation failed: $($_.Exception.Message)"
        return $null
    }
}

function Test-AppDocOverviewNarrativeGrounding {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Narrative,
        [Parameter(Mandatory=$true)]
        [object]$TruthPack
    )

    $issues = @()
    if (-not $Narrative) {
        return [ordered]@{ passed = $false; issues = @("narrative-null") }
    }

    $requiredKeys = Get-AppDocOverviewRequiredNarrativeKeys
    foreach ($key in $requiredKeys) {
        $value = Get-AppDocOverviewNarrativeValue -Object $Narrative -Name $key -Default $null
        if ($null -eq $value) {
            $issues += "missing-key:$key"
            continue
        }
    }

    $truthRefMap = Get-AppDocOverviewEvidenceRefMap -TruthPack $TruthPack
    $narrativeRefs = @(Get-AppDocOverviewNarrativeValue -Object $Narrative -Name "evidence_refs" -Default @())
    $narrativeRefMap = @{}
    foreach ($ref in $narrativeRefs) {
        $id = [string](Get-AppDocOverviewNarrativeValue -Object $ref -Name "id" -Default "")
        if ([string]::IsNullOrWhiteSpace($id)) {
            $issues += "narrative-evidence-ref-missing-id"
            continue
        }
        if (-not $truthRefMap.ContainsKey($id)) {
            $issues += "narrative-evidence-ref-not-in-truthpack:$id"
            continue
        }
        if (-not $narrativeRefMap.ContainsKey($id)) {
            $narrativeRefMap[$id] = $true
        }
    }

    foreach ($key in @("what_it_does", "inputs", "processing_steps", "outputs", "external_systems", "confidence_notes")) {
        $items = @(Get-AppDocOverviewNarrativeValue -Object $Narrative -Name $key -Default @())
        if ($items.Count -eq 0) {
            $issues += "empty-section:$key"
            continue
        }

        $index = 0
        foreach ($item in $items) {
            $index++
            $text = [string](Get-AppDocOverviewNarrativeValue -Object $item -Name "text" -Default "")
            $refs = @(
                Get-AppDocOverviewNarrativeValue -Object $item -Name "evidence_refs" -Default @() |
                    ForEach-Object { [string]$_ } |
                    Where-Object { -not [string]::IsNullOrWhiteSpace($_) } |
                    Select-Object -Unique
            )

            if ([string]::IsNullOrWhiteSpace($text)) {
                $issues += "empty-text:${key}:${index}"
            }
            if ($refs.Count -eq 0) {
                $issues += "missing-refs:${key}:${index}"
                continue
            }

            foreach ($id in $refs) {
                if (-not $truthRefMap.ContainsKey($id)) {
                    $issues += "unknown-ref:${key}:${index}:${id}"
                }
                if (-not $narrativeRefMap.ContainsKey($id)) {
                    $issues += "ref-not-listed-in-evidence_refs:${key}:${index}:${id}"
                }
            }
        }
    }

    return [ordered]@{
        passed = ($issues.Count -eq 0)
        issues = @($issues | Select-Object -Unique)
    }
}

function Get-AppDocOverviewWelcomeNarrative {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$TruthPack,
        [string]$RootPath = "",
        [switch]$NoAI
    )

    $deterministicNarrative = Get-AppDocOverviewDeterministicWelcomeNarrative -TruthPack $TruthPack
    $deterministicVerification = Test-AppDocOverviewNarrativeGrounding -Narrative $deterministicNarrative -TruthPack $TruthPack

    $result = [ordered]@{
        narrative = $deterministicNarrative
        provider = "deterministic"
        usedAI = $false
        aiAttempted = $false
        verification = $deterministicVerification
    }

    if ($NoAI) {
        return $result
    }

    $apiKey = if ($env:APPDOC_OPENAI_API_KEY) { $env:APPDOC_OPENAI_API_KEY } else { $env:OPENAI_API_KEY }
    if ([string]::IsNullOrWhiteSpace($apiKey)) {
        return $result
    }

    $result.aiAttempted = $true
    $aiNarrative = Invoke-AppDocOverviewOpenAINarrative -TruthPack $TruthPack -ApiKey $apiKey
    if (-not $aiNarrative) {
        return $result
    }

    $aiVerification = Test-AppDocOverviewNarrativeGrounding -Narrative $aiNarrative -TruthPack $TruthPack
    if (-not $aiVerification.passed) {
        return $result
    }

    $result.narrative = $aiNarrative
    $result.provider = "openai"
    $result.usedAI = $true
    $result.verification = $aiVerification
    return $result
}

Export-ModuleMember -Function @(
    'Get-AppDocOverviewDeterministicWelcomeNarrative',
    'Test-AppDocOverviewNarrativeGrounding',
    'Get-AppDocOverviewWelcomeNarrative'
)
