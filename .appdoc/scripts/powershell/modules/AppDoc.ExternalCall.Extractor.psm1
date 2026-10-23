#
# AppDoc.ExternalCall.Extractor.psm1
#
# Purpose: GENERIC, framework-agnostic OUTBOUND-HTTP extractor. Mirrors the
#          architecture of AppDoc.ApiInventory.Extractor.psm1 (generic extractor
#          that scans *.ts/*.js/*.cs/*.py/*.java with per-language regex patterns).
#          Unlike the api-inventory extractor (INBOUND endpoints), this one detects
#          OUTBOUND HTTP CALL SITES the application makes to external systems:
#
#             TS/JS  : fetch(, axios.(get|post|put|delete|patch)(,
#                      new XMLHttpRequest(, http(s).request(, got(
#             Python : requests.(get|post|put|delete|patch)(,
#                      httpx.(get|post|put|delete|patch)(, urllib.request.urlopen(,
#                      aiohttp session.request(, http.client.HTTP(S)?Request
#             Java   : <restTemplate>.(getForObject|postForObject|postForEntity|
#                      getForEntity|put|exchange|delete|head)(,
#                      webClient.(get|post|put|delete|patch)(,
#                      HttpURLConnection / openConnection,
#                      java.net.http HttpClient .send(/.sendAsync(,
#                      OkHttp (Request.Builder / .newCall() / .execute()/.enqueue())
#             C#     : <client>.(GetAsync|PostAsync|GetStringAsync|PutAsync|
#                      DeleteAsync|SendAsync)(, WebClient (DownloadString/
#                      UploadString/DownloadData/UploadData/DownloadFile),
#                      HttpWebRequest.Create, RestSharp RestClient (Execute/
#                      Get/Post/Put/Delete/ExecuteAsync)
#
# For every outbound call site it captures:
#   - the call EXPRESSION (mechanism): e.g. `fetch()`, `requests.put`,
#     `restTemplate.postForObject`, `client.PostAsync`
#   - the METHOD (GET/POST/PUT/DELETE/PATCH when determinable from the verb /
#     options; "—" otherwise)
#   - the URL/ENDPOINT: a STRING LITERAL when it is one; otherwise the value is
#     recorded as "from <variable>/config <name>" tagged Inferred (the base
#     literal is cited when a real http(s):// literal is present in the same
#     file) — a URL is NEVER fabricated
#   - the SOURCE file:line citation
#
# Every record is emitted with the SAME shape the classic-ASP external-call
# register (generate-classic-asp-extcalls.ps1) emits, so the §9.4 composer
# (generate-unified-master.ps1) picks it up unchanged:
#   { id, endpoint, mechanism, evidence(=<file> line <n>), behavior, status }
#   (+ the machine evidence fields: method, file, line, urlKind, sourceType)
#
# DETERMINISTIC: no LLM, no network, no randomness. Scoped files are sorted;
# records are deduped by (file,line) and sorted for a byte-stable output.
#
# HONESTY: if no outbound call is detectable, the extractor returns 0 records and
# the generator emits an honest "none detected" table (no fabricated rows).
#
# REDACTION: any real secret in a URL (token / apikey / password / :user:pass@)
# is redacted to [REDACTED] before output (defense-in-depth, mirrors the
# classic-ASP register's ConvertTo-SafeText).
#

function Get-AppDocExternalCallRelativePath {
    # Thin wrapper: the single implementation is Get-AppDocRelativePath (AppDoc.Scope),
    # which delegates to ConvertTo-AppDocRelativePath (AppDoc.Determinism).
    param([string]$RootPath, [string]$Path)
    if (-not (Get-Command Get-AppDocRelativePath -ErrorAction SilentlyContinue)) { Import-Module (Join-Path $PSScriptRoot 'AppDoc.Scope.psm1') -ErrorAction Stop }
    return (Get-AppDocRelativePath -RootPath $RootPath -Path $Path)
}

function Get-AppDocExternalCallScopedFiles {
    [CmdletBinding()]
    param(
        [string]$RootPath,
        [string[]]$Include
    )

    if (Get-Command Get-AppDocSourceFiles -ErrorAction SilentlyContinue) {
        return @(Get-AppDocSourceFiles -RootPath $RootPath -Artifact "external-call" -Include $Include)
    }

    return @(
        (Get-ChildItem -Path $RootPath -Recurse -Include $Include -File -ErrorAction SilentlyContinue) | Where-Object {
            $normalized = $_.FullName -replace '/', '\\'
            $normalized -notmatch '(?i)(\\node_modules\\|\\bin\\|\\obj\\|\\dist\\|\\build\\|\\docs\\|\\.git\\|\\test\\|\\tests\\|\\spec\\|\\specs\\|\\__tests__\\|\\fixture\\|\\fixtures\\|\\mock\\|\\mocks\\|\\sample\\|\\samples\\|\\example\\|\\examples\\|\\__pycache__\\|\\.venv\\|\\.tox\\)'
        }
    )
}

# Redact any real secret value inside a URL / endpoint string. Defense-in-depth:
# even if a credential-bearing URL literal is captured, it is redacted here.
function ConvertTo-AppDocSafeExternalCallUrl {
    param([string]$t)
    if ($null -eq $t) { return '' }
    # userinfo credentials :user:pass@ -> :[REDACTED]@
    $t = [regex]::Replace($t, '(?i)(://[^:/@]+):([^@/]+)@', '$1:[REDACTED]@')
    # query-string / header secrets -> redact the value
    $t = [regex]::Replace($t, '(?i)((?:[?&])(?:token|api[-_]?key|apikey|secret|password|pwd|pass|access[-_]?token|authorization|client[-_]?secret|signature)=)[^&\s]+', '$1[REDACTED]')
    $t = [regex]::Replace($t, '(?i)((?:token|api[-_]?key|apikey|secret|password|pwd|pass|access[-_]?token|authorization|client[-_]?secret|signature)\s*[:=]\s*["'']?)[A-Za-z0-9][A-Za-z0-9\-_.]{5,}', '$1[REDACTED]')
    return $t
}

# Extract the FIRST top-level argument of the call whose opening paren starts at
# $OpenParenIndex. Returns the trimmed raw argument text (may be empty). Bounded so
# a huge argument cannot be captured; stops at the first top-level comma or the
# matching close paren.
function Get-AppDocExternalCallFirstArg {
    param(
        [string]$Content,
        [int]$OpenParenIndex
    )

    if ($OpenParenIndex -lt 0 -or $OpenParenIndex -ge $Content.Length) { return '' }
    $depth = 0
    $start = -1
    for ($i = $OpenParenIndex; $i -lt $Content.Length; $i++) {
        $c = $Content[$i]
        if ($c -eq '(') { $depth++; if ($depth -eq 1) { $start = $i + 1 } }
        elseif ($c -eq ')') { $depth--; if ($depth -eq 0) { if ($start -lt 0) { return '' }; $arg = $Content.Substring($start, $i - $start); return $arg.Trim() } }
        elseif ($c -eq ',' -and $depth -eq 1) { $arg = $Content.Substring($start, $i - $start); return $arg.Trim() }
    }
    if ($start -lt 0) { return '' }
    return $Content.Substring($start).Trim()
}

# Classify the first argument into an endpoint value + an epistemic urlKind.
# Never fabricates: a literal URL wins; a relative path literal is tagged
# Relative; a base-var + path-literal is tagged Inferred (base cited); a bare
# variable is tagged Inferred and, when a real http(s):// base literal exists in
# the same file, that base is cited.
function Resolve-AppDocExternalCallEndpoint {
    param(
        [string]$Arg,
        [string]$FileContent
    )

    $argTrim = [string]($Arg).Trim()
    if ($argTrim) {
        # (1) a full quoted URL literal
        if ($argTrim -match '^[''"]((?:https?://)[^''"]*)[''"]$') {
            return @{ url = ([string]$Matches[1]); urlKind = 'Literal' }
        }
        # (2) a relative quoted path literal (no scheme)
        if ($argTrim -match '^[''"](/[^''"]*)[''"]$') {
            return @{ url = ([string]$Matches[1]); urlKind = 'Relative path (base from client config)' }
        }
        # (3) an expression with a quoted literal component (e.g. `baseVar + "/path"`
        #     or `template ${VAR}/path`) — cite the real path literal, tag the base Inferred
        $quotedPath = $null
        if ($argTrim -match '[''"](/[^''"]+)[''"]') { $quotedPath = [string]$Matches[1] }
        $baseVar = $null
        if ($argTrim -match '\b([A-Za-z_]\w*)\s*[+`]') { $baseVar = [string]$Matches[1] }
        elseif ($argTrim -match '\$\{\s*([A-Za-z_]\w*)') { $baseVar = [string]$Matches[1] }
        elseif ($argTrim -match '^[A-Za-z_][A-Za-z0-9_.]*\s*[+]') { $baseVar = [string]($Matches[0].Trim()) }
        if ($quotedPath) {
            $baseNote = if ($baseVar) { "from $baseVar (Inferred base)" } else { "Inferred base" }
            return @{ url = ("{0} + {1}" -f $baseNote, $quotedPath); urlKind = 'Inferred' }
        }
    }

    # (4) a bare variable / config reference
    $varName = $null
    if ($argTrim -match '^[A-Za-z_][A-Za-z0-9_.]*$') { $varName = [string]$argTrim }
    elseif ($argTrim -match '\b([A-Za-z_]\w*)\b') { $varName = [string]$Matches[1] }

    # Cite a real http(s):// base literal from the same file when present (grounding).
    # Char class excludes whitespace / double-quote / semicolon; a trailing quote or
    # paren the class may have swallowed is trimmed off afterwards.
    $baseLiteral = $null
    if ($FileContent -match '(?m)(https?://[^\s";]+)') {
        $baseLiteral = [string]$Matches[1]
        # strip a trailing paren / comma / semicolon / quote the class may have swallowed
        $trimChars = [char[]]@([char]40, [char]41, [char]59, [char]44, [char]34, [char]39)
        $baseLiteral = $baseLiteral.Trim($trimChars).Trim()
    }

    if ($varName) {
        $endpoint = "from $varName"
        if ($baseLiteral) { $endpoint = ("{0} (base: {1})" -f $endpoint, $baseLiteral) }
        return @{ url = $endpoint; urlKind = 'Inferred' }
    }

    if ($baseLiteral) {
        return @{ url = ("{0} (base from config)" -f $baseLiteral); urlKind = 'Inferred' }
    }

    if ($argTrim) {
        return @{ url = "from <arg>"; urlKind = 'Inferred' }
    }
    return @{ url = 'unknown'; urlKind = 'Unknown' }
}

# Determine the HTTP method from the call verb / a nearby `method:` option within
# a bounded lookahead window of the call. Returns "" when not determinable.
function Get-AppDocExternalCallMethod {
    param(
        [string]$Verb,        # e.g. 'put', 'post', 'get', 'postForObject', 'GetAsync'
        [string]$Lookahead    # bounded raw text after the call (for `method:` option)
    )

    $v = if ($Verb) { $Verb.Trim() } else { '' }
    switch -Regex ($v) {
        '^(get|getobject|getforobject|getforentity|getstring)$' { return 'GET' }
        '^(post|postobject|postforentity|post$)' { return 'POST' }
        '^post' { return 'POST' }
        '^put$' { return 'PUT' }
        '^delete$' { return 'DELETE' }
        '^patch$' { return 'PATCH' }
        '^(head)$' { return 'HEAD' }
    }
    # method: 'GET' / method: "POST" in the options window
    if ($Lookahead -and $Lookahead -match '(?i)\bmethod\s*[:=]\s*[''"]?(?<m>GET|POST|PUT|DELETE|PATCH|HEAD)') {
        return $Matches['m'].ToUpperInvariant()
    }
    return ''
}

# Add one outbound record to the accumulator. $Match is a [regex.Match];
# $mech is the normalized mechanism string; $verb the method verb.
function Add-AppDocExternalCallHit {
    param(
        [System.Collections.Generic.List[object]]$Hits,
        [System.Text.RegularExpressions.Match]$Match,
        [string]$Content,
        [string]$RelPath,
        [string]$Mechanism,
        [string]$Verb,
        [string]$DefaultVerbHint
    )

    # line number (1-indexed) of the match
    $prefix = $Content.Substring(0, $Match.Index)
    $lineNumber = ($prefix -split "`n").Count

    # the opening paren of the call: the first '(' at/after the match end that is
    # not part of the method-name token
    $parenIndex = $Content.IndexOf('(', $Match.Index + $Match.Length - 1)
    if ($parenIndex -lt 0 -or $parenIndex -gt ($Match.Index + $Match.Length + 8)) { $parenIndex = -1 }
    $firstArg = if ($parenIndex -ge 0) { Get-AppDocExternalCallFirstArg -Content $Content -OpenParenIndex $parenIndex } else { '' }
    $endpoint = Resolve-AppDocExternalCallEndpoint -Arg $firstArg -FileContent $Content
    # bounded lookahead for the method option
    $lookStart = $Match.Index + $Match.Length
    $lookEnd = [Math]::Min($Content.Length, $lookStart + 300)
    $lookahead = if ($lookEnd -gt $lookStart) { $Content.Substring($lookStart, $lookEnd - $lookStart) } else { '' }
    $method = Get-AppDocExternalCallMethod -Verb $Verb -Lookahead $lookahead
    if (-not $method -and $DefaultVerbHint) { $method = $DefaultVerbHint }

    $url = ConvertTo-AppDocSafeExternalCallUrl -t ([string]$endpoint.url)

    $Hits.Add([pscustomobject]@{
        mechanism  = $Mechanism
        method     = if ($method) { $method } else { '—' }
        endpoint   = $url
        urlKind    = [string]$endpoint.urlKind
        file       = $RelPath
        line       = [int]$lineNumber
        firstArg   = $firstArg
    })
}

# The main driver: scan the scoped source files, detect outbound HTTP call sites
# per language, and return a stable, deduped, sorted record list.
function Get-AppDocExternalCallData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RootPath
    )

    $hits = New-Object System.Collections.Generic.List[object]
    $files = @(Get-AppDocExternalCallScopedFiles -RootPath $RootPath -Include @("*.ts", "*.js", "*.cs", "*.py", "*.java"))

    $q = '[' + "'" + '"' + ']'   # a class of both quote chars: ['"']

    foreach ($file in ($files | Sort-Object FullName)) {
        $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
        if ([string]::IsNullOrWhiteSpace($content)) { continue }
        $rel = Get-AppDocExternalCallRelativePath -RootPath $RootPath -Path $file.FullName
        $ext = [System.IO.Path]::GetExtension($file.Name).TrimStart('.')

        switch ($ext) {
            { $ext -in @('ts', 'js') } {
                # fetch(
                foreach ($m in [regex]::Matches($content, '(?<![A-Za-z0-9_.])fetch\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'fetch()' -Verb '' -DefaultVerbHint ''
                }
                # axios.<verb>(
                foreach ($m in [regex]::Matches($content, '(?<![A-Za-z0-9_.])axios\s*\.\s*(?<verb>get|post|put|delete|patch)\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism ("axios.{0}" -f $m.Groups['verb'].Value) -Verb $m.Groups['verb'].Value -DefaultVerbHint ''
                }
                # new XMLHttpRequest(
                foreach ($m in [regex]::Matches($content, '(?i)new\s+XMLHttpRequest\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'new XMLHttpRequest()' -Verb '' -DefaultVerbHint ''
                }
                # http(s).request( / http(s).get(
                foreach ($m in [regex]::Matches($content, '(?<![A-Za-z0-9_.])(?:https?)\s*\.\s*(?:request|get)\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'http(s).request()' -Verb '' -DefaultVerbHint ''
                }
                # got(
                foreach ($m in [regex]::Matches($content, '(?<![A-Za-z0-9_.])got\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'got()' -Verb '' -DefaultVerbHint ''
                }
            }

            { $ext -eq 'py' } {
                # requests.<verb>( / httpx.<verb>(
                foreach ($m in [regex]::Matches($content, '(?<![A-Za-z0-9_.])(?:requests|httpx)\s*\.\s*(?<verb>get|post|put|delete|patch)\s*\(')) {
                    $lib = if ($content.Substring($m.Index, [Math]::Min(8, $content.Length - $m.Index)) -match '^requests') { 'requests' } else { 'httpx' }
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism ("{0}.{1}" -f $lib, $m.Groups['verb'].Value) -Verb $m.Groups['verb'].Value -DefaultVerbHint ''
                }
                # urllib.request.urlopen(
                foreach ($m in [regex]::Matches($content, '(?i)(?:urllib\.request|urllib2|urllib)\s*\.\s*(?:urlopen|Request)\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'urllib.request.urlopen()' -Verb '' -DefaultVerbHint ''
                }
                # aiohttp session.request( / aiohttp.ClientRequest(
                foreach ($m in [regex]::Matches($content, '(?i)(?:session|aiohttp)\s*\.\s*(?:request|ClientRequest)\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'aiohttp.session.request()' -Verb '' -DefaultVerbHint ''
                }
                # http.client.HTTP(S)?Request(
                foreach ($m in [regex]::Matches($content, '(?i)(?:http\.client|http)\s*\.\s*(?:HTTPRequest|HTTPSConnection)\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'http.client.HTTPRequest()' -Verb '' -DefaultVerbHint ''
                }
            }

            { $ext -eq 'java' } {
                # RestTemplate-specific method names (unique enough to match directly)
                foreach ($m in [regex]::Matches($content, '(?i)(?<id>[A-Za-z_]\w*)\s*\.\s*(?<verb>getForObject|postForObject|postForEntity|getForEntity|deleteForObject|headForHeaders)\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism ("{0}.{1}" -f $m.Groups['id'].Value, $m.Groups['verb'].Value) -Verb $m.Groups['verb'].Value -DefaultVerbHint ''
                }
                # RestTemplate.exchange(
                foreach ($m in [regex]::Matches($content, '(?i)(?<id>[A-Za-z_]\w*)\s*\.\s*exchange\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism ("{0}.exchange" -f $m.Groups['id'].Value) -Verb 'exchange' -DefaultVerbHint ''
                }
                # Spring WebClient fluent: webClient.get/post/put/delete/patch(
                foreach ($m in [regex]::Matches($content, '(?i)(?<id>[A-Za-z_]\w*[Ww]ebClient|[Ww]ebClient)\s*\.\s*(?<verb>get|post|put|delete|patch)\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism ("{0}.{1}" -f $m.Groups['id'].Value, $m.Groups['verb'].Value) -Verb $m.Groups['verb'].Value -DefaultVerbHint ''
                }
                # HttpURLConnection / openConnection
                foreach ($m in [regex]::Matches($content, '(?i)(?:HttpURLConnection|openConnection)\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'HttpURLConnection.openConnection()' -Verb '' -DefaultVerbHint ''
                }
                # java.net.http HttpClient .send( / .sendAsync(
                if ($content -match '(?i)java\.net\.http|HttpClient') {
                    foreach ($m in [regex]::Matches($content, '(?i)(?<id>[A-Za-z_]\w*Client|[A-Za-z_]\w*)\s*\.\s*(?:send|sendAsync)\s*\(')) {
                        Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism ("{0}.send" -f $m.Groups['id'].Value) -Verb '' -DefaultVerbHint ''
                    }
                }
                # OkHttp
                if ($content -match '(?i)okhttp3|OkHttpClient') {
                    foreach ($m in [regex]::Matches($content, '(?i)(?:Request\.Builder|newCall|\.execute\s*\(|\.enqueue\s*\()')) {
                        Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'OkHttp' -Verb '' -DefaultVerbHint ''
                    }
                }
            }

            { $ext -eq 'cs' } {
                # HttpClient / IHttpClientFactory fluent verbs
                foreach ($m in [regex]::Matches($content, '(?<![A-Za-z0-9_.])(?<id>[A-Za-z_]\w*)\s*\.\s*(?<verb>GetAsync|PostAsync|GetStringAsync|PutAsync|DeleteAsync|SendAsync|Send)\s*\(')) {
                    # keep SendAsync/Send only when an HttpClient surface is present
                    $verb = [string]$m.Groups['verb'].Value
                    if (($verb -eq 'Send' -or $verb -eq 'SendAsync') -and ($content -notmatch '(?i)HttpClient|IHttpClientFactory|HttpWebRequest')) { continue }
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism ("{0}.{1}" -f $m.Groups['id'].Value, $verb) -Verb $verb -DefaultVerbHint ''
                }
                # WebClient
                foreach ($m in [regex]::Matches($content, '(?i)(?<id>[A-Za-z_]\w*WebClient|[Ww]ebClient)\s*\.\s*(?<verb>DownloadString|DownloadData|DownloadFile|UploadString|UploadData|UploadFile|OpenRead)\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism ("WebClient.{0}" -f $m.Groups['verb'].Value) -Verb '' -DefaultVerbHint ''
                }
                # HttpWebRequest.Create
                foreach ($m in [regex]::Matches($content, '(?i)HttpWebRequest\s*\.\s*Create\s*\(')) {
                    Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism 'HttpWebRequest.Create()' -Verb '' -DefaultVerbHint ''
                }
                # RestSharp RestClient
                if ($content -match '(?i)RestClient|RestSharp') {
                    foreach ($m in [regex]::Matches($content, '(?i)(?<id>[A-Za-z_]\w*Client|[A-Za-z_]\w*)\s*\.\s*(?<verb>Execute|ExecuteAsync|Get|Post|Put|Delete|Patch)\s*\(')) {
                        $verb = [string]$m.Groups['verb'].Value
                        if ($verb -in @('Get', 'Post', 'Put', 'Delete', 'Patch', 'Execute', 'ExecuteAsync')) {
                            Add-AppDocExternalCallHit -Hits $hits -Match $m -Content $content -RelPath $rel -Mechanism ("RestClient.{0}" -f $verb) -Verb $verb -DefaultVerbHint ''
                        }
                    }
                }
            }
        }
    }

    # Dedupe by (file, line) keeping the FIRST (deterministic; files are sorted).
    $seen = @{}
    $unique = New-Object System.Collections.Generic.List[object]
    foreach ($h in $hits) {
        $key = "$($h.file)|$($h.line)|$($h.mechanism)"
        if ($seen.ContainsKey($key)) { continue }
        $seen[$key] = $true
        $unique.Add($h)
    }

    $sorted = @($unique | Sort-Object @{ Expression = { [string]$_.file } }, @{ Expression = { [int]$_.line } }, @{ Expression = { [string]$_.mechanism } })

    return [ordered]@{
        records = @($sorted)
        scannedFileCount = $files.Count
    }
}

Export-ModuleMember -Function @(
    'Get-AppDocExternalCallData',
    'Get-AppDocExternalCallRelativePath',
    'Get-AppDocExternalCallScopedFiles',
    'ConvertTo-AppDocSafeExternalCallUrl',
    'Resolve-AppDocExternalCallEndpoint',
    'Get-AppDocExternalCallMethod',
    'Get-AppDocExternalCallFirstArg'
)

# Deprecated names (unapproved verbs), kept as aliases until AppDoc 1.2.0.
Set-Alias -Name 'Sanitize-AppDocExternalCallUrl' -Value 'ConvertTo-AppDocSafeExternalCallUrl'
Export-ModuleMember -Alias @('Sanitize-AppDocExternalCallUrl')
