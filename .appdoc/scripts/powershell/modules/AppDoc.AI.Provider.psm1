# AppDoc.AI.Provider Module
# Purpose: Resolve AI execution mode and invoke AI passes via agent bridge (primary) or API key (secondary).

$script:AppDocAIProviderVersion = "1.0.0"

function ConvertFrom-AppDocAIProviderJson {
    [CmdletBinding()]
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
        return ($text | ConvertFrom-Json -Depth 80)
    }
    catch {
        return $null
    }
}

function Get-AppDocAIProviderBoolean {
    [CmdletBinding()]
    param(
        [AllowNull()]
        [object]$Value
    )

    if ($null -eq $Value) { return $false }
    $text = [string]$Value
    if ([string]::IsNullOrWhiteSpace($text)) { return $false }

    switch ($text.Trim().ToLowerInvariant()) {
        "1" { return $true }
        "true" { return $true }
        "yes" { return $true }
        "on" { return $true }
        "enabled" { return $true }
        "agent" { return $true }
        default { return $false }
    }
}

function Resolve-AppDocAIMode {
    [CmdletBinding()]
    param(
        [ValidateSet("Auto","Agent","ApiKey","Deterministic")]
        [string]$RequestedMode = "Auto",
        [switch]$RequireAI
    )

    $normalizedRequest = $RequestedMode
    $envAIMode = ([string]$env:APPDOC_AI_MODE).Trim()
    if ($normalizedRequest -eq "Auto" -and -not [string]::IsNullOrWhiteSpace($envAIMode)) {
        switch ($envAIMode.ToLowerInvariant()) {
            "auto" { $normalizedRequest = "Auto" }
            "agent" { $normalizedRequest = "Agent" }
            "apikey" { $normalizedRequest = "ApiKey" }
            "api_key" { $normalizedRequest = "ApiKey" }
            "deterministic" { $normalizedRequest = "Deterministic" }
        }
    }

    $apiKey = if ($env:APPDOC_OPENAI_API_KEY) { [string]$env:APPDOC_OPENAI_API_KEY } else { [string]$env:OPENAI_API_KEY }
    $apiKeyAvailable = -not [string]::IsNullOrWhiteSpace($apiKey)

    $agentEnabled = $false
    if (Get-AppDocAIProviderBoolean -Value $env:APPDOC_AI_AGENT) { $agentEnabled = $true }
    if (Get-AppDocAIProviderBoolean -Value $env:APPDOC_AGENT_BRIDGE_ENABLED) { $agentEnabled = $true }
    if (([string]$env:APPDOC_AGENT_MODE).Trim().ToLowerInvariant() -eq "agent") { $agentEnabled = $true }
    if (-not [string]::IsNullOrWhiteSpace(([string]$env:APPDOC_AGENT_BRIDGE_DIR))) { $agentEnabled = $true }

    $resolvedMode = "Deterministic"
    $provider = "deterministic"
    $reason = ""

    switch ($normalizedRequest) {
        "Deterministic" {
            $resolvedMode = "Deterministic"
            $provider = "deterministic"
            $reason = "Requested deterministic mode."
        }
        "ApiKey" {
            if ($apiKeyAvailable) {
                $resolvedMode = "ApiKey"
                $provider = "openai"
                $reason = "API key available."
            }
            else {
                $resolvedMode = "Deterministic"
                $provider = "deterministic"
                $reason = "API key unavailable."
            }
        }
        "Agent" {
            if ($agentEnabled) {
                $resolvedMode = "Agent"
                $provider = "agentbridge"
                $reason = "Agent bridge enabled."
            }
            elseif ($apiKeyAvailable) {
                $resolvedMode = "ApiKey"
                $provider = "openai"
                $reason = "Agent bridge unavailable; API key fallback selected."
            }
            else {
                $resolvedMode = "Deterministic"
                $provider = "deterministic"
                $reason = "Agent bridge and API key unavailable."
            }
        }
        default {
            if ($agentEnabled) {
                $resolvedMode = "Agent"
                $provider = "agentbridge"
                $reason = "Auto mode preferred agent bridge."
            }
            elseif ($apiKeyAvailable) {
                $resolvedMode = "ApiKey"
                $provider = "openai"
                $reason = "Auto mode selected API key fallback."
            }
            else {
                $resolvedMode = "Deterministic"
                $provider = "deterministic"
                $reason = "Auto mode found no AI provider."
            }
        }
    }

    if ($RequireAI -and $resolvedMode -eq "Deterministic") {
        throw "AI mode resolution failed. Requested '$normalizedRequest' with RequireAI enabled, but no AI provider is available."
    }

    return [ordered]@{
        requestedMode = $normalizedRequest
        resolvedMode = $resolvedMode
        provider = $provider
        reason = $reason
        apiKeyAvailable = $apiKeyAvailable
        agentEnabled = $agentEnabled
        providerVersion = $script:AppDocAIProviderVersion
    }
}

function Get-AppDocAgentBridgePaths {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$PassName
    )

    $basePath = if ($env:APPDOC_AGENT_BRIDGE_DIR) {
        [string]$env:APPDOC_AGENT_BRIDGE_DIR
    }
    else {
        Join-Path $RootPath "docs\evidence\narrative\agent-bridge"
    }

    $safePass = ($PassName -replace '[^A-Za-z0-9._-]', '-').ToLowerInvariant()
    $promptsDir = Join-Path $basePath "prompts"
    $responsesDir = Join-Path $basePath "responses"
    $promptPath = Join-Path $promptsDir ("{0}.json" -f $safePass)
    $responsePath = Join-Path $responsesDir ("{0}.json" -f $safePass)
    $sessionPath = Join-Path $basePath "agent-session.json"

    return [ordered]@{
        basePath = $basePath
        promptsDir = $promptsDir
        responsesDir = $responsesDir
        promptPath = $promptPath
        responsePath = $responsePath
        sessionPath = $sessionPath
    }
}

function Invoke-AppDocAgentBridgeJsonPass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$PassName,
        [Parameter(Mandatory=$true)]
        [string]$SystemPrompt,
        [Parameter(Mandatory=$true)]
        [string]$UserPrompt,
        [string]$Model = "gpt-4o-mini",
        [int]$TimeoutSeconds = 120
    )

    $paths = Get-AppDocAgentBridgePaths -RootPath $RootPath -PassName $PassName
    foreach ($dir in @($paths.basePath, $paths.promptsDir, $paths.responsesDir)) {
        if (-not (Test-Path $dir)) {
            New-Item -Path $dir -ItemType Directory -Force | Out-Null
        }
    }

    $requestId = [Guid]::NewGuid().ToString()
    $promptPayload = [ordered]@{
        requestId = $requestId
        passName = $PassName
        model = $Model
        generatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
        system = $SystemPrompt
        user = $UserPrompt
    }

    $promptPayload | ConvertTo-Json -Depth 20 | Out-File -FilePath $paths.promptPath -Encoding UTF8
    if (Test-Path $paths.responsePath) {
        Remove-Item $paths.responsePath -Force -ErrorAction SilentlyContinue
    }

    $session = [ordered]@{
        requestId = $requestId
        lastPromptPath = $paths.promptPath
        expectedResponsePath = $paths.responsePath
        passName = $PassName
        updatedAt = (Get-Date -Format "yyyy-MM-ddTHH:mm:ssK")
    }
    $session | ConvertTo-Json -Depth 10 | Out-File -FilePath $paths.sessionPath -Encoding UTF8

    $deadline = (Get-Date).AddSeconds([Math]::Max(5, $TimeoutSeconds))
    while ((Get-Date) -lt $deadline) {
        if (Test-Path $paths.responsePath) {
            try {
                $rawResponse = Get-Content -Path $paths.responsePath -Raw
                $responseObj = $rawResponse | ConvertFrom-Json -Depth 80
                $responseId = [string]($responseObj.requestId)
                if (-not [string]::IsNullOrWhiteSpace($responseId) -and $responseId -ne $requestId) {
                    Start-Sleep -Milliseconds 600
                    continue
                }

                $contentObj = $null
                if ($null -ne $responseObj.content) {
                    if ($responseObj.content -is [string]) {
                        $contentObj = ConvertFrom-AppDocAIProviderJson -RawText ([string]$responseObj.content)
                    }
                    else {
                        $contentObj = $responseObj.content
                    }
                }
                else {
                    $contentObj = $responseObj
                }

                if ($contentObj) {
                    return [ordered]@{
                        success = $true
                        result = $contentObj
                        provider = "agentbridge"
                        requestId = $requestId
                        promptPath = $paths.promptPath
                        responsePath = $paths.responsePath
                    }
                }
            }
            catch {
                Start-Sleep -Milliseconds 600
                continue
            }
        }
        Start-Sleep -Milliseconds 600
    }

    return [ordered]@{
        success = $false
        result = $null
        provider = "agentbridge"
        requestId = $requestId
        promptPath = $paths.promptPath
        responsePath = $paths.responsePath
        error = "Agent bridge timed out waiting for response."
    }
}

function Invoke-AppDocOpenAIJsonPass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$SystemPrompt,
        [Parameter(Mandatory=$true)]
        [string]$UserPrompt,
        [string]$Model = "",
        [string]$ApiKey = ""
    )

    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        $ApiKey = if ($env:APPDOC_OPENAI_API_KEY) { [string]$env:APPDOC_OPENAI_API_KEY } else { [string]$env:OPENAI_API_KEY }
    }
    if ([string]::IsNullOrWhiteSpace($ApiKey)) {
        return [ordered]@{
            success = $false
            result = $null
            provider = "openai"
            error = "API key unavailable."
        }
    }
    if ([string]::IsNullOrWhiteSpace($Model)) {
        $Model = if ($env:APPDOC_OPENAI_MODEL) { [string]$env:APPDOC_OPENAI_MODEL } else { "gpt-4o-mini" }
    }

    $body = [ordered]@{
        model = $Model
        temperature = 0.1
        response_format = @{ type = "json_object" }
        messages = @(
            @{ role = "system"; content = $SystemPrompt },
            @{ role = "user"; content = $UserPrompt }
        )
    }

    try {
        $response = Invoke-RestMethod -Method Post -Uri "https://api.openai.com/v1/chat/completions" -Headers @{
            "Authorization" = "Bearer $ApiKey"
            "Content-Type" = "application/json"
        } -Body ($body | ConvertTo-Json -Depth 80)

        $content = [string]$response.choices[0].message.content
        $parsed = ConvertFrom-AppDocAIProviderJson -RawText $content
        return [ordered]@{
            success = ($null -ne $parsed)
            result = $parsed
            provider = "openai"
            model = $Model
            error = if ($null -eq $parsed) { "Unable to parse OpenAI JSON response." } else { "" }
        }
    }
    catch {
        return [ordered]@{
            success = $false
            result = $null
            provider = "openai"
            model = $Model
            error = $_.Exception.Message
        }
    }
}

function Invoke-AppDocAIJsonPass {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$RootPath,
        [Parameter(Mandatory=$true)]
        [string]$PassName,
        [Parameter(Mandatory=$true)]
        [string]$SystemPrompt,
        [Parameter(Mandatory=$true)]
        [string]$UserPrompt,
        [ValidateSet("Auto","Agent","ApiKey","Deterministic")]
        [string]$AIMode = "Auto",
        [string]$Model = "",
        [int]$TimeoutSeconds = 120,
        [switch]$RequireAI
    )

    if ($TimeoutSeconds -le 0) {
        $TimeoutSeconds = 120
    }

    $resolution = Resolve-AppDocAIMode -RequestedMode $AIMode -RequireAI:$RequireAI
    $provider = [string]$resolution.provider

    if ($provider -eq "agentbridge") {
        $agentResult = Invoke-AppDocAgentBridgeJsonPass -RootPath $RootPath -PassName $PassName -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Model $Model -TimeoutSeconds $TimeoutSeconds
        if ($agentResult.success) {
            $agentResult.aiModeRequested = $AIMode
            $agentResult.aiModeResolved = $resolution.resolvedMode
            $agentResult.resolution = $resolution
            return $agentResult
        }

        if ($resolution.apiKeyAvailable -and $AIMode -in @("Auto","Agent")) {
            $openAiFallback = Invoke-AppDocOpenAIJsonPass -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Model $Model
            $openAiFallback.aiModeRequested = $AIMode
            $openAiFallback.aiModeResolved = "ApiKey"
            $openAiFallback.resolution = $resolution
            $openAiFallback.fallbackFrom = "agentbridge"
            return $openAiFallback
        }

        $agentResult.aiModeRequested = $AIMode
        $agentResult.aiModeResolved = $resolution.resolvedMode
        $agentResult.resolution = $resolution
        return $agentResult
    }

    if ($provider -eq "openai") {
        $openAiResult = Invoke-AppDocOpenAIJsonPass -SystemPrompt $SystemPrompt -UserPrompt $UserPrompt -Model $Model
        $openAiResult.aiModeRequested = $AIMode
        $openAiResult.aiModeResolved = $resolution.resolvedMode
        $openAiResult.resolution = $resolution
        return $openAiResult
    }

    return [ordered]@{
        success = $false
        result = $null
        provider = "deterministic"
        aiModeRequested = $AIMode
        aiModeResolved = "Deterministic"
        resolution = $resolution
        error = "Deterministic mode selected; no AI pass executed."
    }
}

Export-ModuleMember -Function @(
    'Resolve-AppDocAIMode',
    'Invoke-AppDocAIJsonPass'
)
