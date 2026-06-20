<#
.SYNOPSIS
  Apply the user's standard Warp configuration on this device: the Claude tab
  configs AND the visual setup (settings.toml).
.DESCRIPTION
  Two parts, always applied together:
    1. Tab configs - copies every .toml in assets/tab_configs/ into Warp's
       tab_configs directory (the named entries in Warp's + new-tab menu).
    2. Visual setup - writes assets/settings.toml into Warp's config directory,
       with the {{TAB_CONFIG_DIR}} token replaced by this machine's OS-correct
       tab_configs directory (plain string replace, no TOML parsing).
  All files are written as UTF-8 WITHOUT BOM (Warp fails to parse TOML with a
  BOM). Warp hot-reloads settings.toml, so there is no need to close it.
  Idempotent: re-running overwrites the on-disk config with the bundled versions
  - safe on every new device or after a Warp reinstall.

  Scope: this script ONLY writes config. Installing Warp when missing is the
  sibling install-warp.ps1; launching Warp is orchestrated by the skill after
  this script runs. See SKILL.md for the full install -> config -> launch flow.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# --- Resolve Warp's directories for this OS ---
# $IsWindows exists on PowerShell 7+; on Windows PowerShell 5.1 it is absent, in
# which case we are always on Windows. Non-Windows assumes macOS paths (~/.warp),
# matching this skill's historical behavior.
$onWindows = $true
$iw = Get-Variable -Name IsWindows -ValueOnly -ErrorAction SilentlyContinue
if ($null -ne $iw) { $onWindows = $iw }

if ($onWindows) {
    $tabDir    = Join-Path $env:APPDATA      "warp\Warp\data\tab_configs"
    $configDir = Join-Path $env:LOCALAPPDATA "warp\Warp\config"
} else {
    $tabDir    = Join-Path $HOME ".warp/tab_configs"
    $configDir = Join-Path $HOME ".warp"
}

foreach ($d in @($tabDir, $configDir)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

$assetDir = Join-Path $PSScriptRoot "..\assets"
if (-not (Test-Path $assetDir)) { throw "warp-setup: assets directory not found at $assetDir" }

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
$written = @()

# --- Part 1: tab configs (verbatim) ---
$tabAssetDir = Join-Path $assetDir "tab_configs"
if (-not (Test-Path $tabAssetDir)) { throw "warp-setup: missing assets\tab_configs at $tabAssetDir" }
foreach ($src in Get-ChildItem -Path $tabAssetDir -Filter *.toml) {
    $dest = Join-Path $tabDir $src.Name
    $content = Get-Content -LiteralPath $src.FullName -Raw
    [System.IO.File]::WriteAllText($dest, $content, $utf8NoBom)
    $written += $dest
}

# --- Part 2: visual setup (settings.toml with the one path token substituted) ---
$settingsSrc = Join-Path $assetDir "settings.toml"
if (-not (Test-Path $settingsSrc)) { throw "warp-setup: missing assets\settings.toml at $settingsSrc" }
$settings = Get-Content -LiteralPath $settingsSrc -Raw
$settings = $settings.Replace("{{TAB_CONFIG_DIR}}", $tabDir)
$settingsDest = Join-Path $configDir "settings.toml"
[System.IO.File]::WriteAllText($settingsDest, $settings, $utf8NoBom)
$written += $settingsDest

Write-Output "warp-setup: wrote $($written.Count) file(s):"
foreach ($w in $written) { Write-Output "  - $w" }
Write-Output "settings.toml hot-reloads live. Open a tab from Warp's + menu (or restart Warp) to see the tab configs."
