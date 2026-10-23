#
# AppDoc.SemanticRedaction.psm1
#
# Phase 2a: the DETERMINISTIC, FAIL-CLOSED SECRET-REDACTION HARD GATE + the
# deterministic helpers the quarantine (provenance tagging / Verified-fact lock /
# no-fabrication / input-hash cache) needs.
#
# WHY A SEPARATE LAYER: the config extractor (AppDoc.ConfigCatalog.Extractor.psm1)
# redacts secret/credential VALUES at evidence-extraction time (Protect-AppDocConfigValue
# -> [REDACTED]). But the semantic input envelope passes the record `metadata` (which
# carries `value`, `file`, `source`, etc.) VERBATIM from the evidence records. The hard
# gate is an INDEPENDENT, fail-closed second layer applied at the moment any
# LLM-facing input is about to be written to <docs>/evidence/semantic/input/:
#
#   (1) Redact-AppDocSemanticEnvelope : sweep every string in the would-be envelope with
#       the SAME redaction the security/source-docs + config extractor use (the known-
#       secrets list + the generic credential regexes). Config KEYS/names are KEPT; only
#       secret VALUES become [REDACTED].
#   (2) Test-AppDocSemanticRedactionGate : scan the redacted envelope for any known
#       secret that SURVIVED. If one is present -> FAIL CLOSED (the caller MUST block the
#       LLM stage and must NOT write the record un-redacted). It does NOT silently drop
#       the record.
#
# DETERMINISM + PROVIDER-AGNOSTIC: this module does NO wall-clock, NO network, NO LLM.
# It is pure functions over data, so the stage it guards is reproducible.
#
# Exported:
#   $script:AppDocKnownSecrets
#   Get-AppDocSemanticKnownSecrets
#   Get-AppDocSemanticRedactionPatterns   (raw-credential regex list; order-indep. scan)
#   Redact-AppDocSemanticString
#   Redact-AppDocSemanticEnvelope
#   Test-AppDocSemanticRedactionGate
#   Get-AppDocCanonicalJson
#   Get-AppDocSemanticInputHash
#   Remove-AppDocVolatileFields
#   Test-AppDocValueIsOpen
#

# $script:AppDocKnownSecrets is intentionally EMPTY. AppDoc is a reusable, shareable
# tool: it ships SHAPE-PATTERNS only, never the live credential VALUES of any specific
# test target. Per-target live secrets are operator-supplied through the existing
# operator channel (the enrichment gate's -ExtraKnownSecrets / the config
# `redactionPatterns` key), merged additively with this list at the consumers below
# (the Redact-AppDocSemanticString verbatim step + the Test-AppDocSemanticRedactionGate
# known-secret scan). The variable + consumers are kept so that additive merge still
# works when an operator supplies values.
$script:AppDocKnownSecrets = @()

# Shared operator-redaction compiler (literal values + regexes; invalid regex = error).
Import-Module (Join-Path $PSScriptRoot 'AppDoc.SecretPolicy.psm1') -ErrorAction Stop

# Credential patterns are split into two groups on purpose (the precision fix):
#
#   (a) SPECIFIC named-credential patterns (below). These are shape-specific (a literal
#       token prefix / a `Password=` key / a JWT / the known real credentials). They do
#       NOT false-positive on legitimate path / namespace / identifier runs, so they may
#       be applied to EVERY string in the envelope (the fail-closed backstop).
#
#   (b) GENERIC high-entropy patterns (the base64 + hex blobs). These are SHAPE-AMBIGUOUS:
#       a legitimate identifier run that is >=32 alnum chars (e.g. the file/namespace path
#       a 39-char file/namespace path such as `connectionStrings/
#       AcademicSessionData`) matches `[A-Za-z0-9+/]{32,}` exactly as a base64 secret does.
#       Applying them to the JOIN-KEY fields (source / name / kind) or to path/identifier
#       metadata clobbers those runs to `[REDACTED]`, which breaks the apply-merge join
#       (the LLM copies the redacted source verbatim, so `source|name|kind` no longer
#       matches the RAW evidence key -> the record's enrichment is silently dropped).
#
#   THE FIX: real secrets in this pipeline live in CONFIG VALUES (the record's
#   `metadata.value`), NOT in structural/identifier fields. So the generic high-entropy
#   patterns are applied ONLY to the secret-VALUE field (`metadata.value`), never to
#   source/name/kind or path/identifier metadata. The specific named patterns (a) stay
#   whole-envelope. This is the invariant: a legitimate path/identifier source/name is
#   UNCHANGED by redaction (redacted == raw -> the join works) AND a real secret value in
#   metadata.value is STILL redacted (fail-closed).
#
$script:AppDocSpecificCredentialPatterns = @(
    # GitHub personal / OAuth tokens
    '(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}',
    # Connection-string password tokens
    '(?i)\b(Password|Pwd|PWD)\s*=\s*[^\s",;]{4,}',
    # FIX B (cross-framework, whole-envelope): delimiter-tolerant NAMED-KEY credential.
    # Catches `DB_PASSWORD=*** `SECRET_KEY=*** `aws.accessKeySecret=***
    # `spring.datasource.password=*** The existing (Password|Pwd|PWD)= pattern above MISSES
    # `_SUFFIX`/`.suffix`-prefixed keys because its `\b` sits immediately before the keyword
    # and cannot anchor there (both `_` and `.` are word chars, so no boundary exists). This
    # pattern puts the `\b` at the START of the match (before the `[A-Za-z0-9_.]*` prefix run)
    # and anchors on the credential-keyword alternation + `=` + a >=4 value, so the prefix run
    # backtracks to absorb the `_`/`.` and it fires on the underscore/dot-prefixed forms. The
    # value class EXCLUDES `[`/`]` so the gate's surviving-secret scan of the (already-redacted)
    # envelope does NOT re-trip on the `[REDACTED]` placeholder (a real surviving secret value
    # never starts with `[`; step (b2) preserves the key name -> `DB_PASSWORD=[REDACTED]`).
    # Scope-safe for whole-envelope: a legitimate join-key NAME has no `=value` and a source
    # path has no `KEYWORD=value`, so it never clobbers a join key / path.
    '(?i)\b[A-Za-z0-9_.]*(?:Secret|Password|Passwd|Pwd|Token|ApiKey|ApiSecret|AccessKey|AccessSecret|PrivateKey|ConnStr|Cipher)[A-Za-z0-9_.]*\s*=\s*["'']?[^;\s"''\[\]]{4,}',
    # Bearer tokens
    '(?i)\bBearer\s+[A-Za-z0-9._\-]{20,}',
    # Long JWT / token blobs (header.payload...)
    'eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9._\-]{5,}'
)

# FIX A / FIX A2 (cross-framework, value-scope): URI-credential shapes. These are the
# SINGLE SOURCE OF TRUTH for the `user:pass@` / `://:pass@` redaction. They live in their
# OWN named array so the LAYER-1 deterministic config-catalog path (AppDoc.ConfigCatalog.
# Extractor's Protect-AppDocConfigValue + the run-appdoc-build final [Redaction] sweep) can
# IMPORT them and stay in sync with the LAYER-2 semantic gate (no regex drift between the
# two layers). They are VALUE-SCOPED ON PURPOSE (never applied to a join-key / source path /
# config KEY NAME): a legit source path has no `user:pass@` and a connection-string that is
# itself a SOURCE/KEY value is not clobbered, so they only redact a real
# `postgres://user:***@host` / `redis://:pass@host` credential that lands in a config VALUE
# (preserving the host/DB). Exported via Get-AppDocSemanticUriCredentialPatterns.
$script:AppDocUriCredentialPatterns = @(
    # FIX A: URI with embedded credentials  user:pass@  (postgres://, mysql://, jdbc:...,
    # amqp://, generic user:pass@). Value-scoped. User is >=2 alnum chars, password >=4.
    '(?i)\b[A-Za-z0-9._%-]{2,}:[^@\s/]{4,}@',
    # FIX A2: URI with an EMPTY user  //:pass@  (redis://:pass@host, mongodb://:pass@host).
    # Value-scoped. Complements FIX A for the empty-username form FIX A cannot see.
    '(?i)://:[^@\s]{4,}@[^/\s]*'
)

# Generic high-entropy shapes: applied ONLY to the secret-VALUE field (metadata.value).
# The URI-credential shapes (FIX A / A2) are folded in from the named array above so the
# gate's generic scan is unchanged (same 4 patterns, same order: base64, hex, A, A2) while
# the URI-cred pair has a single named home the LAYER-1 config-catalog path can reuse.
$script:AppDocGenericHighEntropyPatterns = @(
    # High-entropy base64 secrets (>=32)
    '[A-Za-z0-9+/]{32,}={0,2}',
    # High-entropy hex secrets (>=32)
    '[A-Fa-f0-9]{32,}'
) + $script:AppDocUriCredentialPatterns

# The full raw-credential pattern list (specific + generic). Kept for the exported
# Get-AppDocSemanticRedactionPatterns and any operator-facing description. The redaction
# node walker + the fail-closed gate each apply the two sub-lists to the fields they are
# safe for (see the module header note + the function docs below).
$script:AppDocRawCredentialPatterns = @($script:AppDocSpecificCredentialPatterns + $script:AppDocGenericHighEntropyPatterns)

function Get-AppDocSemanticKnownSecrets {
    [CmdletBinding()]
    param()
    return @($script:AppDocKnownSecrets)
}

function Get-AppDocSemanticRedactionPatterns {
    [CmdletBinding()]
    param()
    return @($script:AppDocRawCredentialPatterns)
}

function Get-AppDocSemanticUriCredentialPatterns {
    <#
    .SYNOPSIS
        Returns the URI-credential redaction patterns (FIX A + FIX A2) as a single named
        array -- the single source of truth shared by the LAYER-2 semantic gate and the
        LAYER-1 deterministic config-catalog path (Protect-AppDocConfigValue + the
        run-appdoc-build final [Redaction] sweep). The two layers import from this array so
        the `user:pass@` / `://:pass@` regexes cannot drift between them.
        These are VALUE-SCOPED: a caller must apply them only to a secret VALUE, never to a
        config KEY NAME, source path, or join-key (a legit path / key name must pass through
        unchanged -- the no-over-redaction invariant).
    #>
    [CmdletBinding()]
    param()
    return @($script:AppDocUriCredentialPatterns)
}

function Redact-AppDocSemanticString {
    [CmdletBinding()]
    param([AllowNull()][string]$Text)

    if ($null -eq $Text) { return '' }
    $t = [string]$Text

    # (a) Known real credentials -> redact verbatim (the hard bar). Same list the
    # security extractor + config extractor use.
    foreach ($s in $script:AppDocKnownSecrets) {
        if ($s) { $t = [regex]::Replace($t, [regex]::Escape($s), '[REDACTED]') }
    }

    # (b) Connection-string password tokens.
    $t = [regex]::Replace($t, '(?i)((Password|Pwd)\s*=\s*)([^;\s",;]{4,})', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m) $m.Groups[1].Value + '[REDACTED]'
    })

    # (b2) FIX B (cross-framework, WHOLE-ENVELOPE): delimiter-tolerant NAMED-KEY credential.
    # Catches `DB_PASSWORD=*** `SECRET_KEY=*** `aws.accessKeySecret=***
    # `spring.datasource.password=*** (underscore/dot-prefixed keys the (Password|Pwd)=
    # pattern above misses because its leading \b cannot anchor between a _ / . and the
    # keyword). This is the REDACTION twin of the FIX B entry in
    # $script:AppDocSpecificCredentialPatterns — the two MUST stay in sync (same keyword
    # alternation, same `=`, same value class excluding [ ] so the gate's surviving-secret
    # scan of the already-redacted envelope does not re-trip on the [REDACTED] placeholder).
    # It PRESERVES the key name and redacts only the value, mirroring step (b):
    # `DB_PASSWORD=*** -> `DB_PASSWORD=[REDACTED]`. Scope-safe for whole-envelope: a
    # legitimate join-key NAME has no `=value` and a source path has no `KEYWORD=value`, so
    # it never clobbers a join key / path. Value class mirrors the FIX B gate entry (excludes
    # `;`/whitespace/quotes and `[`/`]`) so the gate's surviving-secret scan of this
    # already-redacted result does not re-trip on the `[REDACTED]` placeholder.
    $t = [regex]::Replace($t, '(?i)\b([A-Za-z0-9_.]*(?:Secret|Password|Passwd|Pwd|Token|ApiKey|ApiSecret|AccessKey|AccessSecret|PrivateKey|ConnStr|Cipher)[A-Za-z0-9_.]*\s*=\s*)(["'']?)([^;\s"''\[\]]{4,})', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m) $m.Groups[1].Value + $m.Groups[2].Value + '[REDACTED]'
    })

    # (c) Bearer tokens.
    $t = [regex]::Replace($t, '(?i)\b(Bearer\s+)[A-Za-z0-9._\-]{20,}', [System.Text.RegularExpressions.MatchEvaluator]{
        param($m) $m.Groups[1].Value + '[REDACTED]'
    })

    # (d) Specific named-credential blobs (the generic high-entropy base64/hex shapes are
    # DELIBERATELY NOT applied here: this function is the whole-envelope redactor used for
    # the JOIN-KEY / path / identifier fields, where a >=32-char legitimate run (a file or
    # namespace path) would be clobbered. The generic shapes are applied only to the
    # secret-VALUE field via Redact-AppDocSemanticSecretValue.)
    $t = [regex]::Replace($t, 'eyJ[A-Za-z0-9_\-]{10,}\.[A-Za-z0-9._\-]{5,}', '[REDACTED]')
    $t = [regex]::Replace($t, '(?:ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{20,}', '[REDACTED]')

    # Collapse repeated [REDACTED] runs created by overlapping matches.
    $t = [regex]::Replace($t, '\[REDACTED\](?:\s*\[REDACTED\])+', '[REDACTED]')

    return $t
}

function Redact-AppDocSemanticSecretValue {
    [CmdletBinding()]
    param([AllowNull()][string]$Text)

    # The secret-VALUE redactor: used ONLY for the field where raw secret VALUES live
    # (the config-catalog `metadata.value`). It applies EVERYTHING Redact-AppDocSemanticString
    # does PLUS the generic high-entropy base64/hex shapes, so a real secret value
    # (e.g. a connection string or a long token) is STILL caught + redacted (fail-closed),
    # while the whole-envelope redactor keeps the JOIN-KEY / path fields untouched.
    if ($null -eq $Text) { return '' }
    $t = Redact-AppDocSemanticString -Text $Text
    foreach ($pat in $script:AppDocGenericHighEntropyPatterns) {
        $t = [regex]::Replace($t, $pat, '[REDACTED]')
    }
    # Collapse repeated [REDACTED] runs created by overlapping matches.
    $t = [regex]::Replace($t, '\[REDACTED\](?:\s*\[REDACTED\])+', '[REDACTED]')
    return $t
}

function Redact-AppDocSemanticEnvelope {
    [CmdletBinding()]
    param([AllowNull()][object]$Envelope)

    # Deep-copy via a JSON round-trip so the caller's envelope is not mutated in place.
    $json = $Envelope | ConvertTo-Json -Depth 100
    $obj = $json | ConvertFrom-Json -AsHashtable -Depth 100
    return (Redact-AppDocSemanticNode -Node $obj -InMetadata $false)
}

function Redact-AppDocSemanticNode {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Node,
        [bool]$InMetadata = $false,
        [bool]$IsSecretValueLeaf = $false
    )

    if ($null -eq $Node) { return $null }

    if ($Node -is [System.Collections.IDictionary]) {
        $out = @{}
        # Flag propagation for the secret-VALUE leaf. `$InMetadata` marks that the
        # CURRENT node sits directly under a `metadata` key (so its `value` child is the
        # secret home). We set it when a child's key is `metadata`, and `$IsSecretValueLeaf`
        # is set when a child's key is `value` under such a node. The flag is STICKY
        # (carried into a `value` node's own nested containers) so a `value` that is an
        # object/array still gets its string leaves value-scoped.
        foreach ($k in $Node.Keys) {
            $childInMetadata = ($k -eq 'metadata')
            $isSecretValueLeaf = $IsSecretValueLeaf
            if ($InMetadata -and ($k -eq 'value')) { $isSecretValueLeaf = $true }
            $out[$k] = (Redact-AppDocSemanticNode -Node $Node[$k] -InMetadata $childInMetadata -IsSecretValueLeaf $isSecretValueLeaf)
        }
        return $out
    }

    if ($Node -is [System.Collections.IList] -and $Node -isnot [System.Array]) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Node) { $list.Add((Redact-AppDocSemanticNode -Node $item -InMetadata $InMetadata -IsSecretValueLeaf $IsSecretValueLeaf)) }
        return $list
    }

    if ($Node -is [System.Array]) {
        $arr = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Node) { $arr.Add((Redact-AppDocSemanticNode -Node $item -InMetadata $InMetadata -IsSecretValueLeaf $IsSecretValueLeaf)) }
        return $arr
    }

    # Leaf: strings are redacted; everything else (numbers/bools/null) passes through.
    if ($Node -is [string]) {
        # Precision rule: the GENERIC high-entropy (base64/hex) patterns are applied ONLY
        # to the secret-VALUE leaf (`metadata.value`, the real config-value secret home).
        # Every other string (the JOIN-KEY source/name/kind, path/identifier metadata such
        # as `file`/`type`, descriptive fields) gets the SPECIFIC named-credential
        # redaction only, so legitimate >=32-char path runs are NEVER clobbered
        # (redacted source == raw source -> the apply-merge join works).
        if ($IsSecretValueLeaf) {
            return (Redact-AppDocSemanticSecretValue -Text $Node)
        }
        return (Redact-AppDocSemanticString -Text $Node)
    }
    return $Node
}

function Get-AppDocSemanticValueBlobs {
    <#
    .SYNOPSIS
        Collects every STRING leaf that sits under a `metadata.value` key (the secret home).
        Used by Test-AppDocSemanticRedactionGate to scope the GENERIC high-entropy scan to
        the secret-VALUE field, mirroring exactly where Redact-AppDocSemanticEnvelope
        applies those patterns. Returns a flat list of those string leaves (one entry per
        `metadata.value` leaf, or per string nested inside a `metadata.value` object/array).
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Envelope)

    return @(Get-AppDocSemanticValueBlobsNode -Node $Envelope)
}

function Get-AppDocSemanticValueBlobsNode {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Node,
        [bool]$InMetadata = $false,
        [bool]$InValue = $false
    )

    if ($null -eq $Node) { return @() }

    if ($Node -is [System.Collections.IDictionary]) {
        $out = @()
        foreach ($k in $Node.Keys) {
            $childInMetadata = ($k -eq 'metadata')
            $childInValue = $InValue
            if ($InMetadata -and ($k -eq 'value')) { $childInValue = $true }
            $out += (Get-AppDocSemanticValueBlobsNode -Node $Node[$k] -InMetadata $childInMetadata -InValue $childInValue)
        }
        return @($out)
    }

    if (($Node -is [System.Collections.IList] -and $Node -isnot [System.Array]) -or ($Node -is [System.Array])) {
        $out = @()
        foreach ($item in $Node) {
            $out += (Get-AppDocSemanticValueBlobsNode -Node $item -InMetadata $InMetadata -InValue $InValue)
        }
        return @($out)
    }

    if ($Node -is [string]) {
        if ($InValue) { return @([string]$Node) }
        return @()
    }

    # numbers/bools/null: not string leaves -> nothing to collect.
    return @()
}

function Get-AppDocSemanticStringLeaves {
    <#
    .SYNOPSIS
        Returns every string in the envelope - dictionary keys and string values - in its
        RAW form (not JSON-escaped). The gate scans these so a secret containing a quote or
        a backslash is still found (ConvertTo-Json would escape it to \" or \\).
    #>
    [CmdletBinding()]
    param([AllowNull()][object]$Node)
    $acc = [System.Collections.Generic.List[string]]::new()
    $stack = [System.Collections.Generic.Stack[object]]::new()
    if ($null -ne $Node) { $stack.Push($Node) }
    while ($stack.Count -gt 0) {
        $n = $stack.Pop()
        if ($null -eq $n) { continue }
        if ($n -is [string]) { $acc.Add($n); continue }
        if ($n -is [System.Collections.IDictionary]) {
            foreach ($k in $n.Keys) { $acc.Add([string]$k); $stack.Push($n[$k]) }
            continue
        }
        if ($n -is [System.Management.Automation.PSCustomObject]) {
            foreach ($prop in $n.PSObject.Properties) { $acc.Add([string]$prop.Name); $stack.Push($prop.Value) }
            continue
        }
        if ($n -is [System.Collections.IEnumerable]) {
            foreach ($item in $n) { $stack.Push($item) }
            continue
        }
    }
    return , $acc
}

function Test-AppDocSemanticRedactionGate {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Envelope,
        # Operator secret VALUES (config redactionPatterns), matched literally.
        [string[]]$ExtraKnownSecrets = @(),
        # Operator regular expressions (config redactionRegexes).
        [string[]]$ExtraRedactionRegexes = @()
    )

    # Scan the (already redacted) envelope for any known secret or raw-credential shape
    # that SURVIVED. Two views are scanned and a hit in EITHER blocks the stage:
    #   - the RAW string leaves (keys + values), joined by newlines. Secrets containing a
    #     quote or backslash are matched here; the JSON text would show them escaped.
    #   - the compact JSON text, as before (catches shapes that span key/value syntax).
    $known = @($script:AppDocKnownSecrets) + @($ExtraKnownSecrets | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)
    $regexes = @($ExtraRedactionRegexes | Where-Object { -not [string]::IsNullOrWhiteSpace([string]$_) } | Select-Object -Unique)

    $hits = [System.Collections.Generic.List[object]]::new()

    if ($null -ne $Envelope) {
        $blob = ($Envelope | ConvertTo-Json -Depth 100 -Compress)
        $leaves = (Get-AppDocSemanticStringLeaves -Node $Envelope) -join "`n"
    } else {
        $blob = ''
        $leaves = ''
    }

    # Operator literals + regexes (compiled by the shared secret policy; an invalid regex
    # throws, which blocks the stage - fail-closed).
    $operatorMatchers = Get-AppDocOperatorRedactionMatchers -Literals $known -Regexes $regexes
    # Hits name the operator entry by POSITION only, never by value: the hit list is
    # written into the run report, and the value is the secret itself.
    $mi = 0
    foreach ($m in $operatorMatchers) {
        $mi++
        $count = [Math]::Max($m.Matches($leaves).Count, $m.Matches($blob).Count)
        if ($count -gt 0) { $hits.Add([pscustomobject]@{ kind = 'known-secret'; operatorEntry = $mi; count = $count }) }
    }

    foreach ($pat in $script:AppDocSpecificCredentialPatterns) {
        $count = [Math]::Max(([regex]::Matches($leaves, $pat)).Count, ([regex]::Matches($blob, $pat)).Count)
        if ($count -gt 0) { $hits.Add([pscustomobject]@{ kind = 'raw-credential-pattern'; pattern = $pat; count = $count }) }
    }

    # Generic high-entropy shapes are scanned ONLY over the secret-VALUE blobs
    # (metadata.value), mirroring where the redaction applies them. Scanning the whole
    # blob here would flag LEGITIMATE >=32-char path/identifier runs (a surviving source
    # path) as a "survived secret" and block the stage, so the generic scan is scoped to
    # the secret home. The blobs are joined with a newline (NOT in the base64/hex char
    # class) so adjacent values can never merge into one longer run.
    $valueBlobs = (Get-AppDocSemanticValueBlobs -Envelope $Envelope) -join "`n"
    if ($valueBlobs) {
        foreach ($pat in $script:AppDocGenericHighEntropyPatterns) {
            $count = ([regex]::Matches($valueBlobs, $pat)).Count
            if ($count -gt 0) { $hits.Add([pscustomobject]@{ kind = 'raw-credential-pattern'; scope = 'metadata.value'; pattern = $pat; count = $count }) }
        }
    }

    $result = [pscustomobject]@{
        blocked      = $hits.Count -gt 0
        hitCount     = $hits.Count
        hits         = @($hits)
        knownScanned = $known.Count + $regexes.Count
    }
    return $result
}

function Get-AppDocCanonicalJson {
    [CmdletBinding()]
    param([AllowNull()][object]$Obj)

    # Deep-copy via JSON round-trip, recursively sort object keys, then serialize with
    # compact + invariant formatting. Deterministic: same input -> same bytes.
    $json = $Obj | ConvertTo-Json -Depth 100
    $obj = $json | ConvertFrom-Json -AsHashtable -Depth 100
    return (Get-AppDocCanonicalJsonNode -Node $obj)
}

function Get-AppDocCanonicalJsonNode {
    [CmdletBinding()]
    param([AllowNull()][object]$Node)

    if ($null -eq $Node) { return 'null' }
    if ($Node -is [System.Boolean]) { return $(if ($Node) { 'true' } else { 'false' }) }
    if ($Node -is [string]) {
        $s = $Node -replace '\\', '\\\\' -replace '"', '\"' -replace "`r", '\r' -replace "`n", '\n' -replace "`t", '\t'
        return ('"' + $s + '"')
    }
    if ($Node -is [System.Collections.IDictionary]) {
        $pairs = [System.Collections.Generic.List[string]]::new()
        $keys = @($Node.Keys | Sort-Object)
        foreach ($k in $keys) {
            $pairs.Add(('{0}:{1}' -f (Get-AppDocCanonicalJsonNode -Node $k), (Get-AppDocCanonicalJsonNode -Node $Node[$k])))
        }
        return ('{' + ($pairs -join ',') + '}')
    }
    if (($Node -is [System.Collections.IList] -and $Node -isnot [System.Array]) -or ($Node -is [System.Array])) {
        $items = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $Node) { $items.Add((Get-AppDocCanonicalJsonNode -Node $item)) }
        return ('[' + ($items -join ',') + ']')
    }
    # Numbers and anything else: normalize to invariant string.
    return ([string]($Node)).Replace(",", "")
}

function Get-AppDocSemanticInputHash {
    [CmdletBinding()]
    param([AllowNull()][object]$Obj)

    $canonical = Get-AppDocCanonicalJson -Obj $Obj
    $sha = [System.Security.Cryptography.SHA256]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($canonical)
        $hash = $sha.ComputeHash($bytes)
        return (([System.BitConverter]::ToString($hash) -replace '-', '').ToLowerInvariant())
    } finally {
        $sha.Dispose()
    }
}

function Remove-AppDocVolatileFields {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Obj,
        [string[]]$Fields = @('generatedAt', 'cacheState', 'inputHash', 'semanticAppliedAt')
    )

    $json = $Obj | ConvertTo-Json -Depth 100
    $obj = $json | ConvertFrom-Json -AsHashtable -Depth 100
    return (Remove-AppDocVolatileFieldsNode -Node $obj -Fields $Fields)
}

function Remove-AppDocVolatileFieldsNode {
    [CmdletBinding()]
    param(
        [AllowNull()][object]$Node,
        [AllowNull()][string[]]$Fields
    )

    if ($null -eq $Node) { return $null }
    if ($Node -is [System.Collections.IDictionary]) {
        $out = @{}
        foreach ($k in $Node.Keys) {
            if ($Fields -contains $k) { continue }
            $out[$k] = (Remove-AppDocVolatileFieldsNode -Node $Node[$k] -Fields $Fields)
        }
        return $out
    }
    if (($Node -is [System.Collections.IList] -and $Node -isnot [System.Array]) -or ($Node -is [System.Array])) {
        $list = [System.Collections.Generic.List[object]]::new()
        foreach ($item in $Node) { $list.Add((Remove-AppDocVolatileFieldsNode -Node $item -Fields $Fields)) }
        return $list
    }
    return $Node
}

# A field is OPEN (eligible for LLM enrichment) when it is null/whitespace or the
# honest-Unknown placeholder. Crucially, a VERIFIED/PROVENANCED value (including a
# [REDACTED] secret placeholder or a real source-grounded fact) is NOT open: the LLM
# must not override it (the Verified-fact lock).
function Test-AppDocValueIsOpen {
    [CmdletBinding()]
    param([AllowNull()][object]$Value)

    if ($null -eq $Value) { return $true }
    if ($Value -is [string]) {
        if ([string]::IsNullOrWhiteSpace($Value)) { return $true }
        if ($Value -eq 'Unknown') { return $true }
        return $false
    }
    # Non-string (number/bool/dict/array): only "empty" containers count as open.
    if ($Value -is [System.Collections.IDictionary]) { return (($Value.Keys | Measure-Object).Count -eq 0) }
    return $false
}

# Deterministic JSON serializer that PRESERVES array-ness: every list (array /
# IList, non-string) serializes as a JSON array, even when it has 0 or 1 element.
# PowerShell's ConvertTo-Json collapses a 1-element array into a bare object, which
# would break the semantic input/output CONTRACT (the external LLM session expects
# `records` to always be a JSON array, not a single object when there is 1 record).
# Output is compact (no insignificant whitespace); keys in object order.
function ConvertTo-AppDocSemanticJson {
    [CmdletBinding()]
    param([AllowNull()][object]$Obj)
    return (ConvertTo-AppDocSemanticJsonNode -Node $Obj)
}

function ConvertTo-AppDocSemanticJsonNode {
    [CmdletBinding()]
    param([AllowNull()][object]$Node)

    if ($null -eq $Node) { return 'null' }

    if ($Node -is [string]) {
        $s = $Node -replace '\\', '\\\\' -replace '"', '\"' -replace "`r", '\r' -replace "`n", '\n' -replace "`t", '\t'
        return ('"' + $s + '"')
    }

    if ($Node -is [bool]) { return $(if ($Node) { 'true' } else { 'false' }) }

    if ($Node -is [System.Collections.IDictionary]) {
        $pairs = [System.Collections.Generic.List[string]]::new()
        foreach ($k in $Node.Keys) {
            $pairs.Add(('{0}:{1}' -f (ConvertTo-AppDocSemanticJsonNode -Node $k), (ConvertTo-AppDocSemanticJsonNode -Node $Node[$k])))
        }
        return ('{' + ($pairs -join ',') + '}')
    }

    # Any non-string collection (array / IList) -> ALWAYS a JSON array.
    if ($Node -is [System.Collections.IList]) {
        $items = [System.Collections.Generic.List[string]]::new()
        foreach ($item in $Node) { $items.Add((ConvertTo-AppDocSemanticJsonNode -Node $item)) }
        return ('[' + ($items -join ',') + ']')
    }

    # Numbers and anything else: normalize to a plain string (invariant).
    $num = $Node
    if ($num -is [System.ValueType]) {
        # Use invariant formatting for numbers so there are no locale surprises.
        return ([System.Convert]::ToString($num, [System.Globalization.CultureInfo]::InvariantCulture))
    }
    return ([string]$num)
}

Export-ModuleMember -Function @(
    'Get-AppDocSemanticKnownSecrets',
    'Get-AppDocSemanticRedactionPatterns',
    'Get-AppDocSemanticUriCredentialPatterns',
    'Redact-AppDocSemanticString',
    'Redact-AppDocSemanticSecretValue',
    'Redact-AppDocSemanticEnvelope',
    'Get-AppDocSemanticValueBlobs',
    'Test-AppDocSemanticRedactionGate',
    'Get-AppDocCanonicalJson',
    'Get-AppDocSemanticInputHash',
    'Remove-AppDocVolatileFields',
    'Test-AppDocValueIsOpen',
    'ConvertTo-AppDocSemanticJson'
)
