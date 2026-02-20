# AppDoc.Overview.PromptCompiler Module
# Purpose: Compile audience/style-aware prompts for multi-pass overview narrative generation.

$script:AppDocOverviewPromptCompilerVersion = "1.1.0"

function Get-AppDocOverviewPromptCompilerValue {
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
        if ($Object.Contains($Name)) { return $Object[$Name] }
        return $Default
    }

    $prop = $Object.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Get-AppDocOverviewAudienceDescription {
    [CmdletBinding()]
    param(
        [ValidateSet("new_dev","senior_dev","sre")]
        [string]$Audience
    )

    switch ($Audience) {
        "senior_dev" { return "Assume reader is a senior engineer reviewing architecture and operational risks." }
        "sre" { return "Assume reader is an SRE/operator focusing on runtime behavior and integration dependencies." }
        default { return "Assume reader is an experienced developer who is new to this codebase." }
    }
}

function Get-AppDocOverviewStyleDescription {
    [CmdletBinding()]
    param(
        [ValidateSet("concise","standard","pedagogical")]
        [string]$StyleProfile
    )

    switch ($StyleProfile) {
        "concise" { return "Keep prose compact and direct. Prefer short paragraphs and avoid redundant explanation." }
        "pedagogical" { return "Use explanatory prose that clarifies intent, flow, and practical implications for maintainers." }
        default { return "Use clear, professional prose that balances conceptual understanding and practical guidance." }
    }
}

function Get-AppDocOverviewPromptSet {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [object]$ContextPack,
        [ValidateSet("new_dev","senior_dev","sre")]
        [string]$Audience = "new_dev",
        [ValidateSet("concise","standard","pedagogical")]
        [string]$StyleProfile = "standard"
    )

    $project = Get-AppDocOverviewPromptCompilerValue -Object $ContextPack -Name "project" -Default @{}
    $projectName = [string](Get-AppDocOverviewPromptCompilerValue -Object $project -Name "name" -Default "application")
    $audienceText = Get-AppDocOverviewAudienceDescription -Audience $Audience
    $styleText = Get-AppDocOverviewStyleDescription -StyleProfile $StyleProfile

    $baseRules = @"
Core requirements:
- Use only supplied context/evidence.
- Do not invent behavior, architecture, integrations, or intent.
- If evidence is weak or missing, explicitly state uncertainty and what evidence is missing.
- Prefer narrative paragraphs over inventories.
- Short supporting lists/tables are allowed only where readability clearly improves.
- In `what_it_does`, start with plain-language purpose and user/business outcome.
- Do not open `what_it_does` with endpoint/model/configuration counts.
- Keep raw counts mostly in `confidence_notes` unless a count is required for understanding behavior.
- Before finalizing, ensure each major claim has at least one evidence reference ID; drop ungrounded claims.
"@

    $sections = @(
        "what_it_does",
        "inputs",
        "processing_steps",
        "outputs",
        "external_systems",
        "confidence_notes",
        "evidence_refs"
    )

    $pass1Schema = @"
Return strict JSON with shape:
{
  "section_evidence_map": {
    "what_it_does": ["ev-0001"],
    "inputs": [],
    "processing_steps": [],
    "outputs": [],
    "external_systems": [],
    "confidence_notes": []
  },
  "outline": {
    "overview": "<1-2 sentence orientation paragraph>",
    "what_it_does": "<one-line purpose>",
    "inputs": "<one-line summary>",
    "processing_steps": "<one-line summary>",
    "outputs": "<one-line summary>",
    "external_systems": "<one-line summary>",
    "confidence_notes": "<one-line summary>"
  },
  "missing_evidence": ["<gaps if any>"]
}
"@

    $pass2Schema = @"
Return strict JSON with shape:
{
  "what_it_does": [{ "text": "<paragraph sentence>", "evidence_refs": ["ev-0001"] }],
  "inputs": [{ "text": "...", "evidence_refs": ["ev-0002"] }],
  "processing_steps": [{ "text": "...", "evidence_refs": ["ev-0003"] }],
  "outputs": [{ "text": "...", "evidence_refs": ["ev-0004"] }],
  "external_systems": [{ "text": "...", "evidence_refs": ["ev-0005"] }],
  "confidence_notes": [{ "text": "...", "evidence_refs": ["ev-0006"] }],
  "evidence_refs": [{ "id":"ev-0001", "artifact":"...", "kind":"...", "name":"...", "source":"..." }]
}
"@

    $pass3Schema = @"
Return strict JSON with shape:
{
  "review_notes": [
    { "severity":"info|warning", "message":"<concise note>" }
  ],
  "narrative": { ...same shape as pass2 output... }
}
"@

    $contextJson = $ContextPack | ConvertTo-Json -Depth 60
    $basePrompt = @"
Project: $projectName
$audienceText
$styleText

$baseRules
"@

    $pass1User = @"
$basePrompt

Task (Pass 1 - Outline and Evidence Map):
- Create an outline-first interpretation using only provided context.
- Provide section->evidence mapping for each narrative section.
- Keep outline concise and business-meaningful.
- The `what_it_does` outline line must describe business purpose in plain language (not metrics).

$pass1Schema

Context pack:
$contextJson
"@

    $pass2User = @"
$basePrompt

Task (Pass 2 - Draft Narrative):
- Write readable developer-facing narrative in paragraph-style sentences.
- Explain what the application does, how data flows, and why components interact as they do.
- Avoid inventory-like output unless needed for clarity.
- Write `what_it_does` so a new developer can quickly explain the application's purpose after reading it.
- Avoid metric-led opening sentences such as "The application exposes X..." or "It contains Y...".
- Use concrete action verbs (for example: process, validate, calculate, assign, integrate, report).

$pass2Schema

Context pack:
$contextJson
"@

    $pass3User = @"
$basePrompt

Task (Pass 3 - Critique and Revise):
- Critique the draft for clarity, repetition, and grounding.
- Revise narrative for readability and practical usefulness.
- Preserve grounding; remove unsupported claims.
- Ensure the first `what_it_does` sentence explains purpose and workflow in plain language, not counts.
- Move count-heavy phrasing into `confidence_notes` when needed.

$pass3Schema

Context pack:
$contextJson
"@

    return [ordered]@{
        compiler_version = $script:AppDocOverviewPromptCompilerVersion
        audience = $Audience
        style_profile = $StyleProfile
        required_sections = $sections
        pass1 = [ordered]@{
            system = "You are a grounded software documentation analyst. Produce strict JSON only."
            user = $pass1User
        }
        pass2 = [ordered]@{
            system = "You are a grounded technical writer. Produce strict JSON only."
            user = $pass2User
        }
        pass3 = [ordered]@{
            system = "You are a rigorous technical editor focused on grounded clarity. Produce strict JSON only."
            user = $pass3User
        }
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocOverviewPromptSet'
)
