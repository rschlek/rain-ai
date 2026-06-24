# Warp setup - install & clobber reference

Operational detail for `warp-setup`. SKILL.md owns the desired-state /
reconcile / verify flow; this file holds the install commands and the
clobber-window rationale that you run inline as harness commands (there is **no
bundled script**).

## Why install is model-driven

Install varies across machines and needs recovery, so you run the commands
yourself: you own the harness timeout, can background a slow download and poll,
and can switch methods when one stalls. Lead with the proven path below; you have
latitude to adapt per machine.

## Detect first (install nothing if present)

Warp is **not** on PATH - detect by the known install path:

- Windows: `Test-Path "$env:LOCALAPPDATA\Programs\Warp\warp.exe"`
- macOS: `/Applications/Warp.app`

If present, install nothing. **Remember which case you are in:** if Warp was
*missing* and you just installed it, the profile is **fresh** - the onboarding
gate (SKILL.md step C) applies. If it was *already present*, treat it as
already-onboarded and skip that gate.

## Windows install (proven path - avoids the winget download wedge)

`winget install Warp.Warp` reliably **wedges at the download step** on at least
one of the user's Windows machines (finds the package, prints "Downloading...",
hangs 25+ min, never lands). So discover the version with winget *metadata* but
download the installer directly with `curl`.

1. **Detect** - skip everything if `warp.exe` already exists (path above).
2. **Discover the latest version** (this does NOT wedge - only `winget
   install`'s download does):

   ```
   winget show --id Warp.Warp --exact --disable-interactivity
   ```

   Parse the `Version:` line (e.g. `v0.2026.06.03.09.49.stable_02`). `--id
   Warp.Warp --exact` is deliberate - a bare `warp` can match `Cloudflare.Warp`
   (moniker "warp"). If winget is absent, fall back to the warp.dev download page
   or ask the user for the build.
3. **Pick arch:** `$env:PROCESSOR_ARCHITECTURE` -> `ARM64` = `aarch64`, else
   `x86_64`.
4. **Download the installer directly** (what winget can't reliably do). The
   versioned endpoint 302s to `releases.warp.dev/.../WarpSetup.exe` and serves a
   real `application/octet-stream`:

   ```
   curl.exe -sSL --max-time 600 -o "$env:LOCALAPPDATA\Temp\WarpSetup.exe" `
     "https://app.warp.dev/download/windows?version=<VERSION>&arch=<ARCH>"
   ```

   The download is ~125 MB - give it a long timeout (or background it and poll)
   rather than letting a 2-minute default kill it. **Sanity-check the size (>50
   MB).** A tiny file means you got an HTML page, not the installer (e.g. the
   version param was missing - the bare URL returns HTTP 400).
5. **Silent install** - Inno Setup, per-user, no elevation:

   ```
   Start-Process "$env:LOCALAPPDATA\Temp\WarpSetup.exe" `
     -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART"
   ```

   Do **not** rely on `-Wait` - this installer sometimes blocks `-Wait`
   indefinitely even after the app is in place. Instead **poll for `warp.exe`**
   at the detect path (up to ~2 min) and treat that as "installed."
6. **Close the auto-launched Warp.** The post-install `[Run]` entry
   **auto-launches Warp even under `/VERYSILENT`** (not flagged `skipifsilent`,
   no switch to suppress). Once `warp.exe` exists, wait a couple seconds and kill
   it, leaving the single deliberate launch for SKILL.md step B:

   ```
   Get-Process Warp -ErrorAction SilentlyContinue | Stop-Process -Force
   ```

   (Killing it does **not** harm the install - verified.)
7. **Verify** `warp.exe` exists and no `Warp`/`WarpSetup` process is left
   running. (Warp declares a `Microsoft.VCRedist.2015+.x64` dependency, present
   on essentially all modern Windows; check
   `HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64` only if Warp
   won't launch.)

You *may* try `winget install --id Warp.Warp --exact` if you want, but bound it
(background + a few minutes) and fall back to the direct download the moment it
stalls at "Downloading..." - don't repeat the 25-minute wedge.

## macOS install

If `/Applications/Warp.app` is missing and Homebrew is available:
`brew install --cask warp`. If brew is absent, tell the user to install Warp from
https://www.warp.dev/ and continue to config.

## Warn-and-continue

If the install can't complete (no winget for version discovery, no brew, download
fails), say so clearly and still proceed to launch + config - the config is worth
writing regardless. Do not abort the run.

## Launch, quit, relaunch commands

- **Launch (Windows):**
  `powershell -ExecutionPolicy Bypass -Command "Start-Process \"$env:LOCALAPPDATA\Programs\Warp\warp.exe\""`
  (macOS: `open -a Warp`.) Wait ~5 s after launch for Warp to initialize.
- **Quit (Windows) - ONLY after the self-host guard below clears:**
  `powershell -ExecutionPolicy Bypass -Command "Get-Process Warp -ErrorAction SilentlyContinue | Stop-Process -Force"`
  (macOS: `osascript -e 'quit app "Warp"'`.)

`-ExecutionPolicy Bypass` is needed on machines at the default `Restricted`
policy; it scopes only to that child process. (This skill ships no `.ps1`, but
you still run inline `powershell -Command` snippets.)

## Self-host guard (never quit the Warp you are running in)

The quit above is **forbidden when this session is hosted inside the very Warp it
would kill** - e.g. you re-ran this skill from a `claude` or `codex` Warp tab.
`Stop-Process -Force` on Warp tears down the terminal mid-skill. **Always check
self-host before quitting** (SKILL.md step D); treat *either* positive signal as
self-host:

- **Env signal (cheapest, verified):** Warp sets `TERM_PROGRAM=WarpTerminal` in the
  shell it spawns, inherited by the agent process. So
  `$env:TERM_PROGRAM -eq 'WarpTerminal'` -> you are inside Warp. (Do not rely on
  `TERM_PROGRAM_VERSION` - it can be empty.)
- **Process-chain signal (corroborating):** walk this process's ancestor chain; a
  `warp.exe` (Windows) / Warp (macOS) ancestor means you are inside Warp, e.g.

  ```
  powershell -Command "$p=Get-CimInstance Win32_Process -Filter \"ProcessId=$PID\"; for($i=0;$i -lt 8 -and $p;$i++){ if($p.Name -eq 'warp.exe'){'self-host'; break}; $p=Get-CimInstance Win32_Process -Filter \"ProcessId=$($p.ParentProcessId)\" -EA SilentlyContinue }"
  ```

When self-hosted, **do not run the quit** - take SKILL.md step D's self-host branch
(write tab configs live, reconcile `settings.toml` live with the durability caveat,
skip the quit/relaunch; step E still runs). The clean quit->write->relaunch path is
only for sessions that are NOT inside the target Warp.

## The clobber windows (why quit -> write -> relaunch)

Warp **hot-reloads** `settings.toml`, so an edit shows up live - but do **not**
rely on hot-reload to *persist* config. A running Warp also flushes its own
in-memory settings back to `settings.toml` and overwrites a hot-reloaded write. A
fresh profile has **two** clobber windows:

1. the first launch initializing the internal store, and
2. onboarding completion flushing in-memory settings to disk -

and beyond those a running Warp can flush over a hot-reloaded write at any time
(including on exit). So write config while Warp is **stopped** and let a fresh
launch read it - that beats every one of those races. This is why the order is
launch -> onboarding gate -> **quit** -> write -> relaunch.

**Self-host caveat.** This quit->write->relaunch assumes you *can* quit Warp. When
the session runs **inside** Warp you cannot (it would kill your terminal - see the
self-host guard above). There the tab-config writes still persist (that directory is
never flushed), but the `settings.toml` write only persists durably after a later
full quit+relaunch the user performs with no in-Warp agent session running (or a
re-run of this skill from a non-Warp terminal).

There is no reliable programmatic "onboarding done" signal - we deliberately
never read `warp.sqlite` (account email, command history, session) - so on a
fresh install you **ask the user** to confirm onboarding is finished. That is the
honest check.
