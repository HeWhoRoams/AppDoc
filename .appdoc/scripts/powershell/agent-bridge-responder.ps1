param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [string]$BridgeDir = "",
    [Parameter(Mandatory=$false)]
    [ValidateRange(100,10000)]
    [int]$PollIntervalMs = 700,
    [Parameter(Mandatory=$false)]
    [switch]$Once,
    [Parameter(Mandatory=$false)]
    [switch]$NonInteractive,
    [Parameter(Mandatory=$false)]
    [switch]$CopyPromptToClipboard
)

<#
.SYNOPSIS
    Watches AppDoc agent-bridge prompts and writes response payloads.

.DESCRIPTION
    This script enables AppDoc Agent mode without API keys by acting as a
    local responder loop. It watches:
      docs/evidence/narrative/agent-bridge/prompts/*.json
    and writes responses to:
      docs/evidence/narrative/agent-bridge/responses/*.json

    Interactive mode (default) allows human-in-the-loop IDE AI usage:
      1) Copy prompt to your IDE AI.
      2) Paste returned JSON content here.
      3) Script writes response envelope AppDoc expects.

.PARAMETER RootPath
    Repository root where docs/evidence exists.

.PARAMETER BridgeDir
    Optional explicit bridge directory override.

.PARAMETER PollIntervalMs
    Prompt polling interval.

.PARAMETER Once
    Process available prompts once, then exit.

.PARAMETER NonInteractive
    Do not ask for JSON responses; only emit handoff artifacts.

.PARAMETER CopyPromptToClipboard
    Copy combined system/user prompt text to clipboard when available.

.EXAMPLE
    pwsh ./.appdoc/scripts/powershell/agent-bridge-responder.ps1 -RootPath C:\Repo -CopyPromptToClipboard
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Get-AppDocBridgeValue {
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

function ConvertFrom-AppDocBridgeJson {
    param(
        [AllowNull()]
        [string]$RawText
    )

    if ([string]::IsNullOrWhiteSpace($RawText)) { return $null }

    $text = $RawText.Trim()
    $text = [regex]::Replace($text, '^\s*```(?:json)?\s*', '', 'IgnoreCase')
    $text = [regex]::Replace($text, '\s*```\s*$', '', 'IgnoreCase')
    $text = $text.Trim()

    try {
        return ($text | ConvertFrom-Json -Depth 100)
    }
    catch {
        return $null
    }
}

function Read-AppDocBridgeJsonFile {
    param([Parameter(Mandatory=$true)][string]$Path)
    if (-not (Test-Path $Path)) { return $null }
    try {
        $raw = Get-Content -Path $Path -Raw
        return (ConvertFrom-AppDocBridgeJson -RawText $raw)
    }
    catch {
        return $null
    }
}

function New-AppDocBridgeDirectories {
    param([Parameter(Mandatory=$true)][string]$BaseDir)

    $promptsDir = Join-Path $BaseDir "prompts"
    $responsesDir = Join-Path $BaseDir "responses"
    $handoffDir = Join-Path $BaseDir "handoff"

    foreach ($dir in @($BaseDir, $promptsDir, $responsesDir, $handoffDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }

    return [ordered]@{
        base = $BaseDir
        prompts = $promptsDir
        responses = $responsesDir
        handoff = $handoffDir
    }
}

function Read-AppDocBridgeMultilineInput {
    param([string]$Sentinel = "END_JSON")

    Write-Host "Paste JSON response content. End input with a line containing '$Sentinel'." -ForegroundColor Gray
    $lines = New-Object System.Collections.Generic.List[string]
    while ($true) {
        $line = Read-Host
        if ($line -eq $Sentinel) { break }
        [void]$lines.Add($line)
    }

    return ($lines -join [Environment]::NewLine)
}

function Write-AppDocBridgeHandoff {
    param(
        [Parameter(Mandatory=$true)]
        [object]$PromptPayload,
        [Parameter(Mandatory=$true)]
        [string]$OutputPath
    )

    $requestId = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "requestId" -Default "")
    $passName = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "passName" -Default "")
    $model = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "model" -Default "")
    $generatedAt = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "generatedAt" -Default "")
    $systemPrompt = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "system" -Default "")
    $userPrompt = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "user" -Default "")

    $markdown = @"
# AppDoc Agent Bridge Prompt

- requestId: ``$requestId``
- passName: ``$passName``
- model: ``$model``
- generatedAt: ``$generatedAt``

## System Prompt

```text
$systemPrompt
```

## User Prompt

```text
$userPrompt
```

## Response Instructions

Return JSON content only for this pass (no markdown fences), then paste it back into the responder.
Do not include ``requestId`` unless you are returning a full envelope.
"@

    $markdown | Out-File -FilePath $OutputPath -Encoding UTF8
}

function Get-AppDocBridgePromptText {
    param([Parameter(Mandatory=$true)][object]$PromptPayload)
    $systemPrompt = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "system" -Default "")
    $userPrompt = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "user" -Default "")
    return ("System Prompt:`n{0}`n`nUser Prompt:`n{1}" -f $systemPrompt, $userPrompt)
}

function ConvertTo-AppDocBridgeResponseEnvelope {
    param(
        [Parameter(Mandatory=$true)]
        [object]$PromptPayload,
        [Parameter(Mandatory=$true)]
        [object]$InputPayload
    )

    $requestId = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "requestId" -Default "")
    $passName = [string](Get-AppDocBridgeValue -Object $PromptPayload -Name "passName" -Default "")
    $inputRequestId = [string](Get-AppDocBridgeValue -Object $InputPayload -Name "requestId" -Default "")
    $inputContent = Get-AppDocBridgeValue -Object $InputPayload -Name "content" -Default $null

    if (-not [string]::IsNullOrWhiteSpace($inputRequestId) -and $null -ne $inputContent) {
        if ($inputRequestId -ne $requestId) {
            throw "Response requestId '$inputRequestId' does not match prompt requestId '$requestId'."
        }

        return [ordered]@{
            requestId = $requestId
            passName = $passName
            respondedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
            content = $inputContent
        }
    }

    return [ordered]@{
        requestId = $requestId
        passName = $passName
        respondedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        content = $InputPayload
    }
}

function Invoke-AppDocBridgeInteractiveResponse {
    param(
        [Parameter(Mandatory=$true)]
        [object]$PromptPayload,
        [Parameter(Mandatory=$true)]
        [string]$ResponsePath
    )

    while ($true) {
        $action = Read-Host "[P]aste JSON, [F]ile JSON, [S]kip, [Q]uit"
        if ([string]::IsNullOrWhiteSpace($action)) { continue }

        switch ($action.Trim().ToUpperInvariant()) {
            "S" { return $false }
            "Q" { throw "Responder exited by user." }
            "F" {
                $path = Read-Host "Enter path to JSON file"
                if ([string]::IsNullOrWhiteSpace($path) -or -not (Test-Path $path)) {
                    Write-Warning "File not found: $path"
                    continue
                }
                $raw = Get-Content -Path $path -Raw
                $parsed = ConvertFrom-AppDocBridgeJson -RawText $raw
                if (-not $parsed) {
                    Write-Warning "Unable to parse JSON from: $path"
                    continue
                }

                $envelope = ConvertTo-AppDocBridgeResponseEnvelope -PromptPayload $PromptPayload -InputPayload $parsed
                $envelope | ConvertTo-Json -Depth 100 | Out-File -FilePath $ResponsePath -Encoding UTF8
                return $true
            }
            "P" {
                $raw = Read-AppDocBridgeMultilineInput -Sentinel "END_JSON"
                $parsed = ConvertFrom-AppDocBridgeJson -RawText $raw
                if (-not $parsed) {
                    Write-Warning "Unable to parse pasted JSON. Retry."
                    continue
                }

                $envelope = ConvertTo-AppDocBridgeResponseEnvelope -PromptPayload $PromptPayload -InputPayload $parsed
                $envelope | ConvertTo-Json -Depth 100 | Out-File -FilePath $ResponsePath -Encoding UTF8
                return $true
            }
            default {
                Write-Warning "Unknown action '$action'."
            }
        }
    }
}

if (-not (Test-Path $RootPath)) {
    throw "Root path does not exist: $RootPath"
}

$resolvedRoot = (Resolve-Path $RootPath).Path
$resolvedBridgeDir = if ([string]::IsNullOrWhiteSpace($BridgeDir)) {
    Join-Path $resolvedRoot "docs\evidence\narrative\agent-bridge"
}
else {
    $BridgeDir
}
$dirs = New-AppDocBridgeDirectories -BaseDir $resolvedBridgeDir
$interactive = -not $NonInteractive
$seenPromptPaths = @{}

Write-Host "AppDoc agent bridge responder started." -ForegroundColor Cyan
Write-Host "RootPath: $resolvedRoot" -ForegroundColor Gray
Write-Host "BridgeDir: $resolvedBridgeDir" -ForegroundColor Gray
Write-Host "Interactive: $interactive" -ForegroundColor Gray

if ($CopyPromptToClipboard -and -not (Get-Command Set-Clipboard -ErrorAction SilentlyContinue)) {
    Write-Warning "Set-Clipboard is unavailable in this shell. Clipboard copy disabled."
    $CopyPromptToClipboard = $false
}

if (-not $env:APPDOC_AI_AGENT -and -not $env:APPDOC_AGENT_BRIDGE_ENABLED) {
    Write-Host "Tip: set APPDOC_AI_AGENT=1 in the terminal running AppDoc workflow." -ForegroundColor Yellow
}

while ($true) {
    $promptFiles = @(Get-ChildItem -Path $dirs.prompts -Filter *.json -File -ErrorAction SilentlyContinue | Sort-Object LastWriteTime, Name)
    $processedAny = $false

    foreach ($promptFile in $promptFiles) {
        $safePass = [IO.Path]::GetFileNameWithoutExtension($promptFile.Name).ToLowerInvariant()
        $responsePath = Join-Path $dirs.responses ($safePass + ".json")
        if (Test-Path $responsePath) { continue }

        $promptPayload = Read-AppDocBridgeJsonFile -Path $promptFile.FullName
        if (-not $promptPayload) {
            Write-Warning "Skipping unreadable prompt file: $($promptFile.FullName)"
            continue
        }

        $passName = [string](Get-AppDocBridgeValue -Object $promptPayload -Name "passName" -Default $safePass)
        $requestId = [string](Get-AppDocBridgeValue -Object $promptPayload -Name "requestId" -Default "")
        $handoffPath = Join-Path $dirs.handoff ($safePass + ".prompt.md")
        Write-AppDocBridgeHandoff -PromptPayload $promptPayload -OutputPath $handoffPath

        if (-not $seenPromptPaths.ContainsKey($promptFile.FullName)) {
            Write-Host ""
            Write-Host "Pending prompt detected:" -ForegroundColor Cyan
            Write-Host "  Pass: $passName" -ForegroundColor White
            Write-Host "  RequestId: $requestId" -ForegroundColor White
            Write-Host "  Prompt: $($promptFile.FullName)" -ForegroundColor Gray
            Write-Host "  Handoff: $handoffPath" -ForegroundColor Gray

            if ($CopyPromptToClipboard) {
                $clipText = Get-AppDocBridgePromptText -PromptPayload $promptPayload
                Set-Clipboard -Value $clipText
                Write-Host "  Copied system+user prompt to clipboard." -ForegroundColor Gray
            }

            $seenPromptPaths[$promptFile.FullName] = $true
        }

        if ($interactive) {
            $written = Invoke-AppDocBridgeInteractiveResponse -PromptPayload $promptPayload -ResponsePath $responsePath
            if ($written) {
                Write-Host "  Wrote response: $responsePath" -ForegroundColor Green
            }
        }

        $processedAny = $true
    }

    if ($Once) { break }
    if (-not $processedAny) {
        Start-Sleep -Milliseconds $PollIntervalMs
    }
}

Write-Host "AppDoc agent bridge responder stopped." -ForegroundColor Cyan
