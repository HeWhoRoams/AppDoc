param(
    [Parameter(Mandatory = $false)]
    [string]$RootPath = (Get-Location).Path,
    [Parameter(Mandatory = $false)]
    [string[]]$Include = @(".appdoc/scripts/powershell"),
    [switch]$Json
)

$errors = @()

function Add-GateError {
    param(
        [string]$Path,
        [string]$Message,
        [int]$Line = 1,
        [int]$Column = 1
    )

    $script:errors += [ordered]@{
        path = $Path
        line = $Line
        column = $Column
        message = $Message
    }
}

$resolvedTargets = @()
foreach ($target in $Include) {
    $candidate = if ([System.IO.Path]::IsPathRooted($target)) { $target } else { Join-Path $RootPath $target }
    if (Test-Path $candidate) {
        $resolvedTargets += $candidate
    }
}

if ($resolvedTargets.Count -eq 0) {
    Add-GateError -Path $RootPath -Message "No syntax gate targets were found."
}

$files = @()
foreach ($target in $resolvedTargets) {
    if (Test-Path $target -PathType Container) {
        $files += Get-ChildItem -Path $target -Recurse -File -Include *.ps1,*.psm1 -ErrorAction SilentlyContinue
    }
    elseif (Test-Path $target -PathType Leaf) {
        $files += Get-Item -Path $target
    }
}

$files = @($files | Sort-Object FullName -Unique)

foreach ($file in $files) {
    $content = Get-Content $file.FullName -Raw -ErrorAction SilentlyContinue
    if ($null -eq $content) {
        Add-GateError -Path $file.FullName -Message "Unable to read file."
        continue
    }

    $conflicts = [regex]::Matches($content, '(?m)^(<<<<<<<|=======|>>>>>>>).*$')
    foreach ($match in $conflicts) {
        $line = ($content.Substring(0, $match.Index) -split "`n").Count
        Add-GateError -Path $file.FullName -Line $line -Message "Merge conflict marker detected."
    }

    $tokens = $null
    $parseErrors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$parseErrors) | Out-Null
    foreach ($err in @($parseErrors)) {
        Add-GateError -Path $file.FullName -Line $err.Extent.StartLineNumber -Column $err.Extent.StartColumnNumber -Message $err.Message
    }
}

$result = [ordered]@{
    checkedFiles = $files.Count
    errorCount = $errors.Count
    errors = $errors
    passed = ($errors.Count -eq 0)
}

if ($Json) {
    $result | ConvertTo-Json -Depth 20
}
else {
    if ($result.passed) {
        Write-Host "Syntax gate passed. Checked $($result.checkedFiles) PowerShell files." -ForegroundColor Green
    }
    else {
        Write-Host "Syntax gate failed with $($result.errorCount) issue(s)." -ForegroundColor Red
        foreach ($err in $errors) {
            Write-Host (" - {0}:{1}:{2} {3}" -f $err.path, $err.line, $err.column, $err.message) -ForegroundColor Yellow
        }
    }
}

if (-not $result.passed) {
    exit 1
}
