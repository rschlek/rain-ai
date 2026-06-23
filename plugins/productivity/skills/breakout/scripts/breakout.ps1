<#
.SYNOPSIS
  breakout - open a fresh Claude Code chat in a new terminal tab (or window),
  optionally seeded with a starting prompt. The current session is left untouched.

.DESCRIPTION
  Mechanism used by the `breakout` / `explore` / `handoff` skills, or run directly.
  Default path opens a new Warp tab in the CURRENT window via the proven
  `warp://tab_config` URI; falls back to a new PowerShell window where Warp is
  absent. Claude args default to `--chrome --dangerously-skip-permissions`.

  The Warp tab config is self-deleting: the launched tab removes the config file
  as its first command, so no persistent `breakout` entry lingers in the Warp
  `+` (new-tab) menu. Warp opens new tabs in PowerShell, so the seed is quoted as
  a PowerShell single-quoted literal - `$`, backticks, and backslashes in the
  seed pass through to claude verbatim instead of being interpreted by the shell.
  Embedded double quotes are additionally escaped (CommandLineToArgvW rules) so
  the whole prompt reaches `claude.exe` as a single argument; PowerShell 5.1 does
  not escape interior `"` when invoking a native exe, which would otherwise split
  the seed and make claude reject a stray token (e.g. `unknown option '->'`).

.EXAMPLE
  breakout.ps1 -Seed "Explain what an agentic harness is"
.EXAMPLE
  breakout.ps1 -SeedFile C:\temp\seed.txt  # robust for rich prompts (see note below)
.EXAMPLE
  breakout.ps1                      # empty fresh chat in a new tab
.EXAMPLE
  breakout.ps1 -Seed "..." -Normal  # keep tool-permission prompts in the new chat

.NOTES
  Two ways to pass the seed. -Seed takes it inline; fine for a trivial one-liner,
  but an inline string with embedded double quotes can be re-tokenized by
  `powershell -File ... -Seed "..."` BEFORE this script's parameter binder runs
  (a seed fragment then binds to -Method and the launch fails, or the seed
  silently truncates). -SeedFile sidesteps that entirely: the caller writes the
  prompt to a file and passes only the path, so the content never transits a
  command line and any quotes / newlines / $ / backticks survive regardless of
  the caller's shell. Prefer -SeedFile for anything beyond a simple one-liner.
#>
[CmdletBinding()]
param(
    [string]$Seed = "",
    [string]$SeedFile = "",  # path to a file holding the seed; robust for rich prompts (no shell re-tokenization). Wins over -Seed.
    [ValidateSet("auto", "warp", "window")][string]$Method = "auto",
    [switch]$Normal,        # drop --dangerously-skip-permissions (default: skip is ON)
    [switch]$NoChrome,      # drop --chrome (default: chrome is ON)
    [string]$ClaudeArgs     # full override of claude args; ignores -Normal/-NoChrome when set
)

$ErrorActionPreference = "Stop"

# --- Seed source: a file (-SeedFile) wins over inline (-Seed). Reading the seed
# from a file is the robust path for rich prompts - the content never transits a
# command line, so embedded quotes / newlines / $ / backticks cannot be
# re-tokenized by the shell before they reach this script.
if ($SeedFile) {
    if (-not (Test-Path -LiteralPath $SeedFile)) { throw "breakout: -SeedFile not found: $SeedFile" }
    $Seed = [System.IO.File]::ReadAllText($SeedFile)
}

# --- Resolve claude args (defaults: --chrome --dangerously-skip-permissions) ---
if ($PSBoundParameters.ContainsKey('ClaudeArgs')) {
    $argStr = $ClaudeArgs
}
else {
    $parts = @()
    if (-not $NoChrome) { $parts += '--chrome' }
    if (-not $Normal)   { $parts += '--dangerously-skip-permissions' }
    $argStr = ($parts -join ' ')
}

# --- Build the command line the new chat will run (target shell: PowerShell) ---
# The seed becomes a PowerShell single-quoted literal so $, backticks, and
# backslashes survive verbatim; embedded apostrophes are doubled ('' = literal ').
$safeSeed = ($Seed -replace "[\r\n]+", " ").Trim()
# Embedded double quotes also need escaping for Windows CommandLineToArgvW:
# `claude` is a native .exe, and PowerShell 5.1 does NOT escape interior " when
# it builds the native command line, so a raw " in the seed ends the argument
# early and the rest of the prompt splits into separate args (claude then trips
# on a stray token like "->": `error: unknown option '->'`). Apply the
# CommandLineToArgvW rule - double any run of backslashes preceding a " and add
# one more backslash - so each embedded " survives as a literal quote.
$safeSeed = $safeSeed -replace '(\\*)"', '$1$1\"'
$claudeCmd = "claude"
if ($argStr)   { $claudeCmd += " $argStr" }
if ($safeSeed) { $claudeCmd += " '" + ($safeSeed -replace "'", "''") + "'" }

# --- Resolve launch method (auto = Warp if present, else a new window) ---
$warpTabDir = Join-Path $env:APPDATA "warp\Warp\data\tab_configs"
if ($Method -eq "auto") {
    if (Test-Path $warpTabDir) { $Method = "warp" } else { $Method = "window" }
}

if ($Method -eq "warp") {
    if (-not (Test-Path $warpTabDir)) { New-Item -ItemType Directory -Path $warpTabDir -Force | Out-Null }
    $cfgName = "breakout"
    $cfgPath = Join-Path $warpTabDir "$cfgName.toml"

    # The tab deletes its own config first (Warp has already read it -> race-free),
    # then launches claude. Result: no lingering entry in the Warp `+` menu.
    $qCfg   = "'" + ($cfgPath -replace "'", "''") + "'"
    $tabCmd = "Remove-Item -LiteralPath $qCfg -ErrorAction SilentlyContinue; $claudeCmd"

    # Embed as a TOML basic string: escape backslashes first, then double quotes.
    # (Basic strings make the apostrophes from the PowerShell quoting above safe.)
    $tabCmdToml = ($tabCmd -replace '\\', '\\') -replace '"', '\"'

    $toml = @"
# Warp Tab Config - generated by the breakout skill (self-deleting; overwritten each run).
# The launched tab removes this file as its first command, so no persistent
# breakout entry is left in the Warp + (new-tab) menu.
name = "$cfgName"

[[panes]]
id = "main"
type = "terminal"
commands = ["$tabCmdToml"]
"@
    # Write UTF-8 without BOM so Warp parses the TOML cleanly.
    [System.IO.File]::WriteAllText($cfgPath, $toml, (New-Object System.Text.UTF8Encoding($false)))
    Start-Process "warp://tab_config/$cfgName"
    Write-Output "breakout: opened a new Warp tab -> $claudeCmd"
}
else {
    Start-Process powershell -ArgumentList @('-NoExit', '-Command', $claudeCmd)
    Write-Output "breakout: opened a new PowerShell window -> $claudeCmd"
}
