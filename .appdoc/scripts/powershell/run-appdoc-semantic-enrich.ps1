param(
    [Parameter(Mandatory=$true)]
    [string]$RootPath,
    [Parameter(Mandatory=$false)]
    [switch]$DryRun,
    # Operator-supplied secret literals / regexes (the config redactionPatterns).
    # The FAIL-CLOSED gate scans for these (as exact literals + regexes) IN ADDITION
    # to the built-in known-secrets hard bar. This makes the gate STRICTER than the
    # deterministic redaction (which redacts only the built-in known secrets + the
    # generic credential patterns), so an operator-listed secret the redaction did not
    # neutralize is caught and the stage is BLOCKED (fail-closed).
    [string[]]$RedactionPatterns = @(),
    # When $true (default), the secret-redaction hard gate is enforced before any
    # LLM-facing input is written. Set $false only for debugging a suspected gate hit.
    [switch]$DisableRedactionGate
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

$semRedactionModule = Join-Path $PSScriptRoot "modules\AppDoc.SemanticRedaction.psm1"
if (-not (Test-Path $semRedactionModule)) {
    throw "Required module not found: $semRedactionModule"
}
Import-Module $semRedactionModule -Force -ErrorAction Stop

if (-not (Test-Path $RootPath)) {
    throw "Root path does not exist: $RootPath"
}

$docsPath = Join-Path $RootPath "docs"
$evidenceDir = Join-Path $docsPath "evidence"
if (-not (Test-Path $evidenceDir)) {
    throw "Evidence directory not found: $evidenceDir"
}

$semanticDir = Join-Path $evidenceDir "semantic"
$inputDir = Join-Path $semanticDir "input"
$outputDir = Join-Path $semanticDir "output"
$appliedDir = Join-Path $semanticDir "applied"
$pendingPath = Join-Path $semanticDir "semantic-pending.json"
$cachePath = Join-Path $semanticDir "enrichment-cache.json"
$refusalPath = Join-Path $semanticDir "quarantine-refusals.json"

if (-not $DryRun) {
    New-Item -ItemType Directory -Force -Path $inputDir | Out-Null
    New-Item -ItemType Directory -Force -Path $outputDir | Out-Null
    New-Item -ItemType Directory -Force -Path $appliedDir | Out-Null
}

# --- Load the operator redactionPatterns from the target config (additive) -------
# The apply-merge is self-contained: it reads <target>/.appdoc/config.json for any
# operator-supplied secret literals (redactionPatterns) so the FAIL-CLOSED gate is
# aware of them even when invoked standalone (not via run-appdoc-build.ps1). A no-
# config target behaves exactly as today (no operator patterns).
$operatorPatterns = @()
$configModule = Join-Path $PSScriptRoot "modules\AppDoc.Config.psm1"
if (Test-Path $configModule) {
    try {
        Import-Module $configModule -Force -ErrorAction SilentlyContinue
        $cfg = Get-AppDocConfig -RootPath $RootPath
        if ($cfg) { $operatorPatterns = @($cfg.values.redactionPatterns | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) }) }
    } catch { /* config load is additive; a failure falls back to the built-in gate */ }
}
# Any patterns passed on the command line take precedence / are additive.
$gateExtraKnownSecrets = @($operatorPatterns + @($RedactionPatterns) | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)

function Get-FieldValue {
    param(
        [AllowNull()]
        [object]$Record,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Default = $null
    )

    if ($null -eq $Record) { return $Default }

    if ($Record -is [System.Collections.IDictionary]) {
        if ($Record.Contains($Name)) { return $Record[$Name] }
        return $Default
    }

    $prop = $Record.PSObject.Properties[$Name]
    if ($prop) { return $prop.Value }
    return $Default
}

function Set-FieldValue {
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Record,
        [Parameter(Mandatory=$true)]
        [string]$Name,
        $Value
    )

    $Record[$Name] = $Value
}

function To-Hashtable {
    param(
        [Parameter(Mandatory=$true)]
        $InputObject
    )

    if ($InputObject -is [hashtable]) { return $InputObject }
    if ($InputObject -is [System.Collections.IDictionary]) { return $InputObject }
    return ($InputObject | ConvertTo-Json -Depth 100 | ConvertFrom-Json -AsHashtable -Depth 100)
}

function New-SemanticKey {
    param(
        [string]$Source,
        [string]$Name,
        [string]$Kind
    )

    return (("{0}|{1}|{2}" -f ($Source ?? ""), ($Name ?? ""), ($Kind ?? "")).ToLowerInvariant())
}

function Infer-Tier {
    param(
        [string]$Source,
        [string]$Name
    )

    $s = ($Source ?? "").ToLowerInvariant()
    $n = ($Name ?? "").ToLowerInvariant()

    if ($s -match '(\.vscode|\.csproj|packages\.config|tasks\.json|launch\.json)' -or $n -match '(copilot|autoapprove|build|test|targetframework|outputtype)') {
        return 'build-tooling'
    }

    if ($s -match '(workflow|github/workflows|ci|pipeline|\.ya?ml|appsettings\.[^.]+\.json|\.env\.[^.]+|transform)' -or $n -match '(connection|string|smtp|host|server|apiurl|baseurl|environment)') {
        return 'deployment'
    }

    return 'runtime'
}

function Infer-RequiredForDeployment {
    param(
        [string]$Name,
        [object]$Metadata
    )

    $n = ($Name ?? "").ToLowerInvariant()
    if ($n -match '(connection|string|smtp|host|server|apiurl|baseurl|token|secret|key)') { return $true }

    if ($null -ne $Metadata) {
        $required = Get-FieldValue -Record $Metadata -Name 'required' -Default $null
        if ($null -ne $required) { return [bool]$required }
    }

    return $false
}

function Infer-DependencyKind {
    param([string]$Type)

    $t = ($Type ?? "").ToLowerInvariant()
    if ($t -match '^nuget') { return 'nuget' }
    if ($t -match 'assembly|gac') { return 'assembly-reference' }
    if ($t -match 'npm') { return 'npm' }
    if ($t -match 'python|pip') { return 'system' }
    if ($t -match 'maven|gradle|java') { return 'system' }
    return 'system'
}

function Infer-CriticalPath {
    param(
        [string]$Name,
        [string]$Project,
        [string]$Kind
    )

    $n = ($Name ?? "").ToLowerInvariant()
    if ($Kind -eq 'dependency') {
        if ($n -match '(microsoft\.extensions|newtonsoft|entityframework|system\.data|sqlclient|auth|security)') { return $true }
    }

    return $false
}

function Infer-ModelRole {
    param(
        [string]$Source,
        [string]$Name,
        [object]$Metadata
    )

    $s = ($Source ?? '').ToLowerInvariant()
    $n = ($Name ?? '').ToLowerInvariant()
    $modelType = [string](Get-FieldValue -Record $Metadata -Name 'modelType' -Default '')
    $t = $modelType.ToLowerInvariant()

    if ($s -match '(?i)(?:^|[\\\/])(generated|service references|connected services|reference\.cs|proxy|proxies)(?:[\\\/]|$)' -or $n -match '(proxy|generated|reference)') {
        return 'GeneratedProxy'
    }

    if ($s -match '(?i)(?:^|[\\\/])viewmodels?(?:[\\\/]|$)' -or $n -match 'viewmodel$') {
        return 'ViewModel'
    }

    if ($s -match '(?i)(?:^|[\\\/])entities?(?:[\\\/]|$)' -or $n -match '(entity|record)$') {
        return 'Entity'
    }

    if ($s -match '(?i)(?:^|[\\\/])(dto|dtos|contracts|models[\\/]api)(?:[\\\/]|$)' -or $t -match 'dto' -or $n -match 'dto$') {
        return 'DTO'
    }

    if ($s -match '(?i)(?:^|[\\\/])(aggregates?|domain)(?:[\\\/]|$)' -or $n -match 'aggregate$') {
        return 'Aggregate'
    }

    return 'Unknown'
}

function Infer-IsGeneratedModel {
    param(
        [string]$Source,
        [string]$Name
    )

    $s = ($Source ?? '').ToLowerInvariant()
    $n = ($Name ?? '').ToLowerInvariant()
    return ($s -match '(?i)(?:reference\.cs|\.designer\.cs|\.g\.cs|[\\\/](generated|service references|connected services|proxy|proxies)[\\\/])' -or $n -match '(proxy|generated|reference)')
}

function Build-TestDiagnosis {
    param(
        [string]$Status,
        [string]$Kind,
        [object]$Metadata
    )

    $coverageLevel = 'none'
    $zeroReason = 'unknown'

    if (($Status ?? '') -eq 'Detected') {
        $coverageLevel = 'medium'
        $zeroReason = $null
    }
    elseif ($Kind -in @('summary','task-guide')) {
        $coverageLevel = 'none'
        $zeroReason = 'scope-failure'
    }

    return [ordered]@{
        coverageLevel = $coverageLevel
        discoveryMethod = 'deterministic-scan'
        zeroTestReason = $zeroReason
        underservedAreas = @('core-domain')
    }
}

function Ensure-ConfidenceNote {
    param(
        [hashtable]$Record
    )

    $confidenceRaw = Get-FieldValue -Record $Record -Name 'confidence' -Default $null
    if ($null -eq $confidenceRaw) { return }

    [double]$confidence = 0.0
    if (-not [double]::TryParse([string]$confidenceRaw, [ref]$confidence)) { return }

    if ($confidence -lt 0.8) {
        $note = [string](Get-FieldValue -Record $Record -Name 'confidenceNote' -Default '')
        if ([string]::IsNullOrWhiteSpace($note)) {
            $source = [string](Get-FieldValue -Record $Record -Name 'source' -Default 'source file')
            Set-FieldValue -Record $Record -Name 'confidenceNote' -Value ("Low-confidence signal from deterministic scan; review {0}." -f $source)
        }
    }
}

$requiredSemanticFields = @(
    'confidenceNote','role','businessPurpose','isGenerated','tier','dependencyKind','criticalPath',
    'upgradeUrgency','requiredForDeployment','schemaSource','integrationTargets','relationships',
    'operationalProfile','projectRole','usageFrequency','testDiagnosis'
)

# Load the deterministic enrichment input-hash cache (empty when absent). The cache is
# keyed by each record's deterministic input hash and stores the prior LLM result, so
# a re-run with UNCHANGED inputs skips the LLM stage (cost-safe + idempotent).
$cache = @{}
if (Test-Path $cachePath) {
    try {
        $cacheObj = Get-Content -Path $cachePath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
        $cacheEntries = Get-FieldValue -Record $cacheObj -Name 'entries' -Default $null
        if ($null -ne $cacheEntries -and $cacheEntries -is [System.Collections.IDictionary]) {
            # Defensive: only accept SHA256-shaped keys (64 hex chars). This ignores any
            # stray metadata keys (generatedAt/entryCount/entries) so a partially-poisoned
            # cache file can never re-contaminate the hash map.
            foreach ($h in $cacheEntries.Keys) {
                $hk = [string]$h
                if ($hk -match '^[0-9a-f]{64}$') { $cache[$hk] = $cacheEntries[$h] }
            }
        }
    } catch { Write-Warning "Could not read enrichment cache; starting fresh: $($_.Exception.Message)" }
}

$enrichedFiles = @(Get-ChildItem -Path $evidenceDir -Filter '*.evidence.enriched.json' -File -ErrorAction SilentlyContinue | Sort-Object Name)
$pending = @()
$updatedFiles = 0
$globalRefusals = @()
$cacheHitCount = 0
$cacheMissCount = 0
$gateBlockedFiles = @()

foreach ($file in $enrichedFiles) {
    $payload = Get-Content -Path $file.FullName -Raw | ConvertFrom-Json -AsHashtable -Depth 100
    $artifact = [string](Get-FieldValue -Record $payload -Name 'artifact' -Default '')
    $records = @((Get-FieldValue -Record $payload -Name 'records' -Default @()))

    # --- Build the semantic INPUT envelope (the LLM-facing contract) -----------
    # Each record carries ONLY the redaction-safe fields the external LLM session
    # needs: the join key (source|name|kind), the record's confidence, its (redacted)
    # metadata, and the list of fields it is asked to enrich. This is the EXACT shape
    # the Phase 2b LLM session reads. Records are collected into an ArrayList so the
    # serialized envelope ALWAYS has `records` as a JSON array (even with 0/1 record)
    # -- PowerShell's ConvertTo-Json otherwise collapses a 1-record array to an object.
    $inRecords = [System.Collections.ArrayList]::new()
    foreach ($rec in $records) {
        $recH = To-Hashtable -InputObject $rec
        $recIn = [ordered]@{
            source = [string](Get-FieldValue -Record $recH -Name 'source' -Default '')
            name = [string](Get-FieldValue -Record $recH -Name 'name' -Default '')
            kind = [string](Get-FieldValue -Record $recH -Name 'kind' -Default '')
            confidence = (Get-FieldValue -Record $recH -Name 'confidence' -Default $null)
            metadata = (Get-FieldValue -Record $recH -Name 'metadata' -Default $null)
            expectedFields = $requiredSemanticFields
        }
        # (4) redact this record's values (built-in known secrets + generic patterns)
        # BEFORE it is allowed to reach the LLM-facing envelope.
        $redRec = Redact-AppDocSemanticEnvelope -Envelope $recIn
        [void]$inRecords.Add($redRec)
    }
    $semanticInput = [ordered]@{
        artifact = $artifact
        generatedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
        source = $file.Name
        records = $inRecords
    }

    # --- (4) SECRET-REDACTION HARD GATE (fail-closed) --------------------------
    # Run the FAIL-CLOSED gate over the REDACTED envelope for any known secret that
    # SURVIVED redaction (built-in hard bar + operator redactionPatterns + broad
    # raw-credential patterns). If a secret survived, the stage for this file is
    # BLOCKED: the input is NOT written and the file does not proceed to the
    # LLM/apply step (it is not silently dropped -- it is skipped with a clear error
    # and reported in the gate block list).
    $gateResult = Test-AppDocSemanticRedactionGate -Envelope $semanticInput -ExtraKnownSecrets $gateExtraKnownSecrets

    $inputPath = Join-Path $inputDir ($file.Name.Replace('.evidence.enriched.json', '.semantic.input.json'))

    if ($gateResult.blocked) {
        # FAIL-CLOSED: do not write the (partially-)redacted input, do not proceed.
        $gateBlockedFiles += [ordered]@{
            artifact = $artifact
            file = $file.Name
            hitCount = $gateResult.hitCount
            hits = @($gateResult.hits)
        }
        $detail = @($gateResult.hits | ForEach-Object { "[$($_.kind)] count=$($_.count)" }) -join '; '
        if (-not $DisableRedactionGate) {
            throw "SECRET-REDACTION HARD GATE BLOCKED the semantic stage for '$($file.Name)'. A known secret survived redaction in the would-be LLM-facing input. Stage is BLOCKED (fail-closed); the input was NOT written and the file did not proceed. Hits: $detail"
        }
        else {
            Write-Warning "SECRET-REDACTION GATE hit on '$($file.Name)' but -DisableRedactionGate was set (debug); skipping file. Hits: $detail"
        }
        continue
    }

    if (-not $DryRun) {
        # Array-safe serializer: guarantees `records` is a JSON array in the LLM-facing
        # contract regardless of record count.
        (ConvertTo-AppDocSemanticJson -Obj $semanticInput) | Out-File -FilePath $inputPath -Encoding UTF8
    }

    # --- (3) INPUT-HASH CACHE --------------------------------------------------
    # Per-record deterministic input hash over the REDACTED input record (volatile
    # fields excluded). Used to decide cache HIT (skip the LLM call) vs MISS
    # (re-enrich) on re-runs.
    $outputPath = Join-Path $outputDir ($file.Name.Replace('.evidence.enriched.json', '.semantic.output.json'))
    $outputLookup = @{}
    $outputApplied = $false

    if (Test-Path $outputPath) {
        try {
            $semanticOutput = Get-Content -Path $outputPath -Raw | ConvertFrom-Json -AsHashtable -Depth 100
            foreach ($outRecord in @((Get-FieldValue -Record $semanticOutput -Name 'records' -Default @()))) {
                $outHash = To-Hashtable -InputObject $outRecord
                $okey = New-SemanticKey -Source ([string](Get-FieldValue -Record $outHash -Name 'source' -Default '')) -Name ([string](Get-FieldValue -Record $outHash -Name 'name' -Default '')) -Kind ([string](Get-FieldValue -Record $outHash -Name 'kind' -Default ''))
                $outputLookup[$okey] = $outHash
            }
            $outputApplied = $outputLookup.Count -gt 0
        }
        catch {
            Write-Warning "Invalid semantic output file skipped: $outputPath"
        }
    }

    # Load the per-record input hashes from the REDACTED input records (deterministic;
    # computed over the exact record as written to the LLM-facing envelope).
    $inputHashByKey = @{}
    foreach ($inRec in @($inRecords)) {
        $inH = To-Hashtable -InputObject $inRec
        $ihKey = New-SemanticKey -Source ([string](Get-FieldValue -Record $inH -Name 'source' -Default '')) -Name ([string](Get-FieldValue -Record $inH -Name 'name' -Default '')) -Kind ([string](Get-FieldValue -Record $inH -Name 'kind' -Default ''))
        $inputHashByKey[$ihKey] = (Get-AppDocSemanticInputHash -Obj $inH)
    }

    $updatedRecords = @(
        $records | ForEach-Object {
            $record = To-Hashtable -InputObject $_
            $source = [string](Get-FieldValue -Record $record -Name 'source' -Default '')
            $name = [string](Get-FieldValue -Record $record -Name 'name' -Default '')
            $kind = [string](Get-FieldValue -Record $record -Name 'kind' -Default '')
            $metadata = Get-FieldValue -Record $record -Name 'metadata' -Default $null
            $key = New-SemanticKey -Source $source -Name $name -Kind $kind

            # (3) cache state for this record (input-hash keyed; HIT -> skip LLM call)
            $recInputHash = if ($inputHashByKey.ContainsKey($key)) { $inputHashByKey[$key] } else { $null }
            $cacheState = 'none'
            $llmResult = $null
            if ($null -ne $recInputHash -and $cache.ContainsKey($recInputHash)) {
                $cacheState = 'hit'
                $cacheHitCount++
                $cached = $cache[$recInputHash]
                if ($null -ne (Get-FieldValue -Record $cached -Name 'llmResult' -Default $null)) {
                    $llmResult = To-Hashtable -InputObject (Get-FieldValue -Record $cached -Name 'llmResult' -Default $null)
                }
            }
            else {
                $cacheState = 'miss'
                $cacheMissCount++
                if ($outputLookup.ContainsKey($key)) { $llmResult = To-Hashtable -InputObject $outputLookup[$key] }
            }

            # --- (1)+(2) QUARANTINE: provenance tiering + the Verified-fact lock --
            # Three sets drive the quarantine:
            #   $detFilled : fields the DETERMINISTIC layer filled (Infer-* / source-
            #               grounded). Final provenance 'deterministic' when not LLM-set.
            #   $verified  : fields that are VERIFIED source-grounded facts (the real
            #               source, a real metadata value the deterministic layer
            #               established with provenance). These are LLM-IMMUTABLE: the
            #               Verified-fact lock REFUSES any LLM override (logged).
            #   $llmSet    : fields the external LLM filled / overrode. Final
            #               provenance 'llm'.
            # A field left null/Unknown by both is 'open' (no-fabrication: never invented).
            $detFilled = @{}
            $verified  = @{}
            $llmSet    = @{}

            # (a) Any enrichment field the RAW record already carries a non-open value
            #     for is a VERIFIED source-grounded fact -> LLM-IMMUTABLE + deterministic.
            foreach ($field in $requiredSemanticFields) {
                $rawVal = Get-FieldValue -Record $record -Name $field -Default $null
                if (-not (Test-AppDocValueIsOpen $rawVal)) {
                    $detFilled[$field] = $true
                    $verified[$field] = $true
                }
            }

            # --- (2) deterministic fills, tagged deterministic (+ verified when src-grounded)
            # businessPurpose: a heuristic default when open (NOT a real purpose).
            if ([string]::IsNullOrWhiteSpace([string](Get-FieldValue -Record $record -Name 'businessPurpose' -Default ''))) {
                Set-FieldValue -Record $record -Name 'businessPurpose' -Value ("Purpose unclear from available evidence — review {0}." -f $source)
                $detFilled['businessPurpose'] = $true
            }

            # schemaSource: a VERIFIED source-grounded fact = the record's real
            # extraction source (the real path/file the deterministic layer established).
            # The LLM may NOT override it (the Verified-fact lock).
            $schemaSourceOpen = Test-AppDocValueIsOpen (Get-FieldValue -Record $record -Name 'schemaSource' -Default $null)
            $sourceNonEmpty = -not [string]::IsNullOrWhiteSpace($source)
            if ($schemaSourceOpen -and $sourceNonEmpty) {
                Set-FieldValue -Record $record -Name 'schemaSource' -Value $source
                $detFilled['schemaSource'] = $true
                $verified['schemaSource'] = $true
            }

            if ($kind -eq 'configuration') {
                if ([string]::IsNullOrWhiteSpace([string](Get-FieldValue -Record $record -Name 'tier' -Default ''))) {
                    Set-FieldValue -Record $record -Name 'tier' -Value (Infer-Tier -Source $source -Name $name)
                    $detFilled['tier'] = $true
                }
                if ($null -eq (Get-FieldValue -Record $record -Name 'requiredForDeployment' -Default $null)) {
                    $req = Get-FieldValue -Record $metadata -Name 'required' -Default $null
                    Set-FieldValue -Record $record -Name 'requiredForDeployment' -Value (Infer-RequiredForDeployment -Name $name -Metadata $metadata)
                    $detFilled['requiredForDeployment'] = $true
                    # source-grounded (Verified) when an explicit real metadata.required
                    # was present; a low-confidence name guess otherwise (not verified).
                    if ($null -ne $req) { $verified['requiredForDeployment'] = $true }
                }
            }

            if ($kind -eq 'dependency') {
                if ([string]::IsNullOrWhiteSpace([string](Get-FieldValue -Record $record -Name 'dependencyKind' -Default ''))) {
                    $depType = [string](Get-FieldValue -Record $metadata -Name 'type' -Default '')
                    Set-FieldValue -Record $record -Name 'dependencyKind' -Value (Infer-DependencyKind -Type $depType)
                    $detFilled['dependencyKind'] = $true
                }
                if ($null -eq (Get-FieldValue -Record $record -Name 'criticalPath' -Default $null)) {
                    $project = [string](Get-FieldValue -Record $metadata -Name 'project' -Default '')
                    Set-FieldValue -Record $record -Name 'criticalPath' -Value (Infer-CriticalPath -Name $name -Project $project -Kind $kind)
                    $detFilled['criticalPath'] = $true
                }
            }

            if ($kind -eq 'model') {
                if ([string]::IsNullOrWhiteSpace([string](Get-FieldValue -Record $record -Name 'role' -Default ''))) {
                    Set-FieldValue -Record $record -Name 'role' -Value (Infer-ModelRole -Source $source -Name $name -Metadata $metadata)
                    $detFilled['role'] = $true
                }
                if ($null -eq (Get-FieldValue -Record $record -Name 'isGenerated' -Default $null)) {
                    Set-FieldValue -Record $record -Name 'isGenerated' -Value (Infer-IsGeneratedModel -Source $source -Name $name)
                    $detFilled['isGenerated'] = $true
                }
            }

            if ($kind -in @('test-case','test-suite') -or $artifact -eq 'task-guides') {
                if ($null -eq (Get-FieldValue -Record $record -Name 'testDiagnosis' -Default $null)) {
                    $status = [string](Get-FieldValue -Record $record -Name 'status' -Default '')
                    Set-FieldValue -Record $record -Name 'testDiagnosis' -Value (Build-TestDiagnosis -Status $status -Kind $kind -Metadata $metadata)
                    $detFilled['testDiagnosis'] = $true
                }
            }

            # --- TIERED LLM merge (the Verified-fact lock) ----------------------
            # The LLM may ONLY fill/override fields that are open (null/Unknown) or a
            # low-confidence deterministic (Infer-*) fill. A field that is a VERIFIED
            # source-grounded fact is LLM-IMMUTABLE: an attempted override is REFUSED
            # (logged) and the Verified value is kept. This inverts the prior "LLM wins
            # over any non-null field" to "LLM wins over HEURISTIC only, never over
            # VERIFIED." A null LLM field is a no-op (no-fabrication).
            if ($null -ne $llmResult) {
                foreach ($field in $requiredSemanticFields) {
                    $outValue = Get-FieldValue -Record $llmResult -Name $field -Default $null
                    if ($null -eq $outValue) { continue }   # LLM left it open -> no-fabrication
                    if ($verified.ContainsKey($field)) {
                        # VERIFIED-FACT LOCK: refuse the LLM override; keep the value.
                        $globalRefusals += [ordered]@{
                            artifact = $artifact
                            key = $key
                            field = $field
                            provenance = 'verified'
                            verifiedValue = (Get-FieldValue -Record $record -Name $field -Default $null)
                            llmAttemptedValue = $outValue
                            action = 'refused'
                        }
                        # provenance stays deterministic; the Verified value is untouched.
                    }
                    else {
                        # open or a low-confidence deterministic fill: the LLM may
                        # fill / override it -> tag the field 'llm'.
                        Set-FieldValue -Record $record -Name $field -Value $outValue
                        $llmSet[$field] = $true
                    }
                }
            }

            # (3) persist the cache for a MISS where a fresh LLM result was applied
            if (($cacheState -eq 'miss') -and ($null -ne $llmResult) -and ($null -ne $recInputHash)) {
                $cache[$recInputHash] = [ordered]@{
                    artifact = $artifact
                    key = $key
                    inputHash = $recInputHash
                    llmResult = $llmResult
                }
            }

            Ensure-ConfidenceNote -Record $record

            # (1) tag the final per-field provenance on the record (the observable
            # quarantine boundary). Precedence: LLM-set -> 'llm'; deterministic-fill
            # (incl. Verified) -> 'deterministic'; otherwise -> 'open' (un-provided,
            # never invented).
            $finalProv = [ordered]@{}
            foreach ($field in $requiredSemanticFields) {
                if ($llmSet.ContainsKey($field)) { $finalProv[$field] = 'llm' }
                elseif ($detFilled.ContainsKey($field)) { $finalProv[$field] = 'deterministic' }
                else { $finalProv[$field] = 'open' }
            }
            $record['provenance'] = $finalProv
            $record['inputHash'] = $recInputHash
            $record['cacheState'] = $cacheState
            $record
        }
    )

    $payload['records'] = $updatedRecords
    $meta = To-Hashtable -InputObject (Get-FieldValue -Record $payload -Name 'metadata' -Default @{})
    $meta['enriched'] = $true
    $meta['enrichmentMode'] = 'semantic-applied'
    $meta['semanticInputPath'] = $inputPath.Replace($RootPath, '.').TrimStart('\').Replace('\','/')
    $meta['semanticOutputPath'] = if (Test-Path $outputPath) { $outputPath.Replace($RootPath, '.').TrimStart('\').Replace('\','/') } else { '' }
    $meta['semanticOutputApplied'] = $outputApplied
    $meta['semanticAppliedAt'] = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
    $meta['redactionGate'] = [ordered]@{
        enforced = -not [bool]$DisableRedactionGate
        passed = $true
        operatorPatterns = $gateExtraKnownSecrets.Count
    }
    $meta['cache'] = [ordered]@{
        path = ($cachePath.Replace($RootPath, '.').TrimStart('\').Replace('\','/'))
        hitRecords = $cacheHitCount
        missRecords = $cacheMissCount
    }
    $meta['quarantine'] = [ordered]@{
        refusals = (@($globalRefusals | Where-Object { ([string](Get-FieldValue -Record $_ -Name 'artifact' -Default '') -eq $artifact) }).Count)
        verifiedFactLock = $true
        provenanceTagged = $true
    }
    $payload['metadata'] = $meta

    $missing = @()
    foreach ($rec in $updatedRecords) {
        foreach ($field in $requiredSemanticFields) {
            if ($null -eq (Get-FieldValue -Record $rec -Name $field -Default $null)) {
                $missing += [ordered]@{
                    artifact = $artifact
                    source = [string](Get-FieldValue -Record $rec -Name 'source' -Default '')
                    name = [string](Get-FieldValue -Record $rec -Name 'name' -Default '')
                    kind = [string](Get-FieldValue -Record $rec -Name 'kind' -Default '')
                    field = $field
                }
            }
        }
    }

    if (-not $DryRun) {
        $payload | ConvertTo-Json -Depth 100 | Out-File -FilePath $file.FullName -Encoding UTF8
        $appliedSnapshot = Join-Path $appliedDir ($file.Name.Replace('.evidence.enriched.json', '.semantic.applied.json'))
        $payload | ConvertTo-Json -Depth 100 | Out-File -FilePath $appliedSnapshot -Encoding UTF8
    }

    $pending += $missing
    $updatedFiles++
}

# Persist the input-hash cache (deterministic given the same inputs + same LLM results).
if (-not $DryRun -and $cache.Count -gt 0) {
    $cachePayload = [ordered]@{
        generatedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
        entryCount = $cache.Count
        entries = $cache
    }
    $cachePayload | ConvertTo-Json -Depth 100 | Out-File -FilePath $cachePath -Encoding UTF8
}

# Persist the Verified-fact-lock refusal log (the observable quarantine audit trail).
if (-not $DryRun -and $globalRefusals.Count -gt 0) {
    $refusalPayload = [ordered]@{
        generatedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
        refusalCount = $globalRefusals.Count
        refusals = $globalRefusals
    }
    $refusalPayload | ConvertTo-Json -Depth 100 | Out-File -FilePath $refusalPath -Encoding UTF8
}

$pendingPayload = [ordered]@{
    generatedAt = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ssK')
    rootPath = $RootPath
    enrichedFilesChecked = $enrichedFiles.Count
    enrichedFilesUpdated = $updatedFiles
    gateBlockedFiles = $gateBlockedFiles.Count
    pendingFieldCount = $pending.Count
    cacheHits = $cacheHitCount
    cacheMisses = $cacheMissCount
    verifiedFactLockRefusals = $globalRefusals.Count
    pending = $pending
}

if (-not $DryRun) {
    $pendingPayload | ConvertTo-Json -Depth 100 | Out-File -FilePath $pendingPath -Encoding UTF8
}

Write-Host "Semantic enrichment apply complete." -ForegroundColor Cyan
Write-Host ("Enriched files updated: {0}" -f $updatedFiles) -ForegroundColor Gray
Write-Host ("Pending semantic fields: {0}" -f $pending.Count) -ForegroundColor Gray
$gateColor = if ($gateBlockedFiles.Count -gt 0) { 'Red' } else { 'Gray' }
Write-Host ("Secret-redaction gate: {0} file(s) blocked" -f $gateBlockedFiles.Count) -ForegroundColor $gateColor
Write-Host ("Input-hash cache: {0} hit(s), {1} miss(es)" -f $cacheHitCount, $cacheMissCount) -ForegroundColor Gray
Write-Host ("Verified-fact-lock refusals: {0}" -f $globalRefusals.Count) -ForegroundColor Gray
if ($pending.Count -gt 0) {
    Write-Host ("Pending report: {0}" -f $pendingPath) -ForegroundColor Gray
}
