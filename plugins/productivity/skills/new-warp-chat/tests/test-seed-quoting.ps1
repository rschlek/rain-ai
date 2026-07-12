<#
.SYNOPSIS
  Seed-quoting regression tests for new-warp-chat.ps1 - the CommandLineToArgvW
  escaping is the fiddly part that has regressed before, so it gets a test.

.DESCRIPTION
  For each edge-case seed, the harness runs the launcher with -NoLaunch, decodes
  the tab command out of the generated TOML, and EXECUTES it in this PowerShell
  5.1 session - exactly what a Warp pane does with commands[0] - with the CLI
  swapped for a probe script that records the argv it actually received. A case
  passes when the probe got the seed back as ONE argument, byte-identical to the
  original (after the launcher's documented newline-collapse + trim). The
  Remove-Item prefix runs too, so the config self-delete is exercised each case.

  MUST run under Windows PowerShell 5.1 - the quoting bug under test is 5.1's
  native-exe argument passing. Run: powershell -File test-seed-quoting.ps1
#>
[CmdletBinding()]
param(
    [string]$WorkDir = (Join-Path $env:TEMP ("nwc-tests-" + [guid]::NewGuid().ToString("N").Substring(0, 8)))
)
$ErrorActionPreference = "Stop"
if ($PSVersionTable.PSVersion.Major -ne 5) {
    throw "These tests must run under Windows PowerShell 5.1 (the quoting behavior under test); got $($PSVersionTable.PSVersion)"
}

$launcher = Join-Path $PSScriptRoot "..\scripts\new-warp-chat.ps1"
if ($WorkDir -match '\s') { throw "WorkDir must not contain spaces (keeps the probe invocation quote-free): $WorkDir" }
New-Item -ItemType Directory -Force -Path $WorkDir | Out-Null
$cfgDir = Join-Path $WorkDir "tab_configs"

# The probe stands in for the launched CLI: it records how many args it received
# and each arg verbatim, one per line (seeds are single-line by the time they are
# passed - the launcher collapses newlines - so lines are a safe delimiter).
$probe = Join-Path $WorkDir "probe.ps1"
@'
$out = $args[0]
$rest = @()
if ($args.Count -gt 1) { $rest = $args[1..($args.Count - 1)] }
$lines = @("COUNT=$($rest.Count)") + $rest
[System.IO.File]::WriteAllLines($out, $lines)
'@ | Set-Content -Path $probe -Encoding Ascii

$cases = @(
    @{ Name = "plain";              Seed = 'echo hello test tab, then you may exit' }
    @{ Name = "interior-dquotes";   Seed = 'say "hello world" twice' }
    @{ Name = "trailing-dquote";    Seed = 'end with a quote "' }
    @{ Name = "backslash-quote";    Seed = 'literal \" backslash-quote and \\" a doubled run' }
    @{ Name = "plain-backslashes";  Seed = 'path C:\temp\dir and a trailing one C:\' }
    @{ Name = "bare-trailing-bslash"; Seed = 'C:\temp\' }  # no whitespace -> PS passes it unquoted; must NOT be doubled
    @{ Name = "dollar-subexpr";     Seed = 'cost is $5, $HOME must survive, and so must $(Get-Date)' }
    @{ Name = "backticks";          Seed = 'back`tick, a `n escape, and `"' }
    @{ Name = "single-quotes";      Seed = "it's got 'single quotes' inside" }
    @{ Name = "kitchen-sink";       Seed = @'
mix "dq" 'sq' $var `bt` \" and a backslash tail\
'@ }
    @{ Name = "multiline-collapse"; Seed = "line one`r`nline two`nline three" }
    # PS 5.1 drops an empty '' native-exe argument, so the launcher treats an
    # empty seed as no seed at all - the probe must see zero arguments.
    @{ Name = "empty-seed";         Seed = ''; ExpectNoArg = $true }
)

function Decode-TomlCommand([string]$cfgPath) {
    $line = (Get-Content -LiteralPath $cfgPath) | Where-Object { $_ -match '^commands = \["(.*)"\]$' } | Select-Object -First 1
    if (-not $line) { throw "no commands line in $cfgPath" }
    # Invert the launcher's TOML escaping in one left-to-right pass:
    # encoded \\ -> \ and \" -> "
    ([regex]::Match($line, '^commands = \["(.*)"\]$').Groups[1].Value) -replace '\\(\\|")', '$1'
}

$failures = 0
$i = 0
foreach ($case in $cases) {
    $i++
    $seedFile = Join-Path $WorkDir "seed$i.txt"
    $outFile  = Join-Path $WorkDir "out$i.txt"
    [System.IO.File]::WriteAllText($seedFile, $case.Seed, (New-Object System.Text.UTF8Encoding($false)))

    & $launcher -TabName "nwc-test" -LaunchCmd powershell `
        -LaunchArgs "-NoProfile -ExecutionPolicy Bypass -File $probe $outFile" `
        -SeedFile $seedFile -TabConfigsDir $cfgDir -NoLaunch | Out-Null

    $cfgPath = Join-Path $cfgDir "nwc-test.toml"
    $tabCmd = Decode-TomlCommand $cfgPath

    # Execute the tab command exactly as the Warp pane would (PS 5.1 input line).
    Invoke-Expression $tabCmd

    $expected = ($case.Seed -replace "[\r\n]+", " ").Trim()
    $lines = [System.IO.File]::ReadAllLines($outFile)
    $got = if ($lines.Count -gt 1) { $lines[1] } else { $null }
    if ($case.ExpectNoArg) {
        $ok = ($lines[0] -eq "COUNT=0") -and (-not (Test-Path $cfgPath)) -and (-not (Test-Path $seedFile))
        $expected = "<no argument>"
    } else {
        $ok = ($lines[0] -eq "COUNT=1") -and ($got -ceq $expected) -and (-not (Test-Path $cfgPath)) -and (-not (Test-Path $seedFile))
    }

    if ($ok) {
        Write-Output ("PASS  {0}" -f $case.Name)
    } else {
        $failures++
        Write-Output ("FAIL  {0}" -f $case.Name)
        Write-Output ("      argv:     {0}" -f $lines[0])
        Write-Output ("      expected: <{0}>" -f $expected)
        Write-Output ("      got:      <{0}>" -f $got)
        if (Test-Path $cfgPath)  { Write-Output "      config was NOT self-deleted" }
        if (Test-Path $seedFile) { Write-Output "      seed file was NOT cleaned up" }
    }
}

# No-seed case: the tab command must carry no trailing argument at all.
$i++
$outFile = Join-Path $WorkDir "out$i.txt"
& $launcher -TabName "nwc-test" -LaunchCmd powershell `
    -LaunchArgs "-NoProfile -ExecutionPolicy Bypass -File $probe $outFile" `
    -TabConfigsDir $cfgDir -NoLaunch | Out-Null
$tabCmd = Decode-TomlCommand (Join-Path $cfgDir "nwc-test.toml")
Invoke-Expression $tabCmd
$lines = [System.IO.File]::ReadAllLines($outFile)
if ($lines[0] -eq "COUNT=0") { Write-Output "PASS  no-seed" } else { $failures++; Write-Output "FAIL  no-seed ($($lines[0]))" }

Remove-Item -Recurse -Force $WorkDir -ErrorAction SilentlyContinue
if ($failures -gt 0) { Write-Output "$failures FAILURE(S)"; exit 1 }
Write-Output "All $($cases.Count + 1) cases passed."
