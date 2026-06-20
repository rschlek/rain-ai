---
name: warp-setup
description: >-
  Set up the Warp terminal on the current device with the user's standard setup:
  install Warp if it is missing (you drive the install directly - direct download
  on Windows, brew on macOS), apply the Claude tab configs AND the visual setup
  (theme, fonts, zoom, sidebar - settings.toml via a script), then launch Warp.
  Use when the user is setting up Warp on a new or reinstalled machine, or says
  "set up warp", "install warp", "configure warp", "warp tab configs", "apply my
  warp settings", or "warp-setup". Do NOT use to open a one-off throwaway chat
  tab in Warp, or for unrelated terminal config.
---

# Warp Setup

Set up the user's standard Warp on whatever device the session is running on, in
one pass. Parts, **run in this order**
(install -> launch -> onboarding gate -> config):

0. **Install** (you drive it - see "Install" below) - if Warp is missing, install
   it. This step is **model-driven, not scripted**: you run the commands yourself
   so you own the harness timeout, can run the download in the background, and can
   recover or pick a different method when one stalls on a given machine.
1. **Launch Warp** - the single deliberate launch; it initializes the profile and
   must come before config (config written before the profile exists gets
   clobbered - see step 4 in Procedure).
2. **Onboarding gate** (fresh installs only) - after launch, the user clicks
   through Warp's onboarding windows to reach the main view. **Completing
   onboarding makes Warp flush its own in-memory settings to `settings.toml`**,
   overwriting any config written earlier. So on a fresh install you **pause and
   wait for the user to finish onboarding** before writing config. Already-onboarded
   machines skip this (see step 3 in Procedure).
3. **Config** (`apply-warp-config.ps1`) - written with Warp **stopped**, then a
   relaunch reads it (quit -> write -> relaunch; see step 4):
   - **Tab configs** - the named entries in Warp's `+` (new-tab) menu; each opens
     a tab that auto-runs a command. Ships two (below). (These live in a separate
     dir Warp's settings-flush never touches, so they are not at clobber risk.)
   - **Visual setup** - `settings.toml`: theme, vertical-tabs sidebar, fonts,
     zoom, editor toggles, default session mode.

**Why install is model-driven but config is scripted.** Config is deterministic
file-writing with footguns (UTF-8 *without* BOM - Warp rejects TOML with a BOM -
plus a path-token substitution); a script does that reliably and a model should
not improvise it. Install is the opposite: it varies across machines and needs
recovery. In particular `winget install Warp.Warp` reliably **wedges at the
download step** on at least one of the user's Windows machines (winget finds the
package, prints "Downloading...", and hangs indefinitely - 25+ min, never lands).
So the proven path below avoids `winget install` and downloads the installer
directly. You have latitude to adapt per machine, but lead with the proven path.

Warp does **not** require a sign-in - on a fresh install the user just clicks
through a couple of onboarding windows to reach the main view. Warp **hot-reloads**
`settings.toml`, so an edit shows up live - but do **not** rely on hot-reload to
*persist* config: a running Warp also flushes its own in-memory settings back to
`settings.toml` (notably the moment onboarding completes, and on exit), which
overwrites a hot-reloaded write. The durable method is therefore to write config
while Warp is **stopped** and let a fresh launch read it - see the Procedure.

## The two tab configs

| Tab name        | Command it runs                                              |
| --------------- | ----------------------------------------------------------- |
| `claude`        | `claude --chrome --dangerously-skip-permissions`            |
| `claude-resume` | `claude --chrome --dangerously-skip-permissions --resume`   |

## Assets (the source of truth)

```
warp-setup/assets/
  settings.toml              # visual setup; carries the {{TAB_CONFIG_DIR}} token
  tab_configs/
    claude.toml
    claude-resume.toml
```

To change a command, theme, or any setting, edit the file in `assets/` -
`apply-warp-config.ps1` copies/substitutes whatever is there. To add a tab
config, drop another `.toml` into `assets/tab_configs/`.

### The one machine-specific value

`settings.toml` is portable except `default_tab_config_path`, whose directory is
the literal token `{{TAB_CONFIG_DIR}}`. At apply time the script does a plain
string replace of that token with this machine's OS-correct tab_configs directory
(no TOML parsing). Every other value ships as-is.

## Procedure

You drive step 1 (install) with your own tool calls; step 2 launches Warp, step 3
is a human gate on fresh installs, and step 4 writes config with Warp stopped then
relaunches. **Order matters** - the profile must exist before config is written,
and config must be the *last* write before a read-launch (see the clobber notes on
steps 3 and 4). `-ExecutionPolicy Bypass` is needed on machines at the default
`Restricted` policy (a bare `powershell -File ...` refuses to run the `.ps1`); it
scopes only to that child process.

1. **Ensure Warp is installed** (model-driven - see the per-OS "Install" section
   below for the exact, proven commands). In short:

   - **Detect first.** Warp is installed iff its exe/app exists at the known path
     (Warp is not on PATH): Windows `%LOCALAPPDATA%\Programs\Warp\warp.exe`; macOS
     `/Applications/Warp.app`. If present, install nothing - go to step 2.
   - **If missing, install it yourself** (do not shell out to a script for this):
     Windows = direct download + silent install; macOS = `brew install --cask warp`.
     The Windows install **auto-launches Warp and you close it** (install step 6) -
     so after step 1 Warp is installed but not running.
   - **Warn-and-continue.** If the install can't complete (no winget for version
     discovery, no brew, download fails), say so clearly and still go to step 2 -
     the config is worth writing regardless. Do not abort the run.
   - **Remember which case you're in.** If Warp was *missing* and you just
     installed it, this is a **fresh** profile - onboarding is pending, so the
     step-3 gate applies. If Warp was *already present*, treat it as
     already-onboarded and skip that gate.

2. **Launch Warp** - the single deliberate launch, and it must come *before*
   config:

   ```
   powershell -ExecutionPolicy Bypass -Command "Start-Process \"$env:LOCALAPPDATA\Programs\Warp\warp.exe\""
   ```

   (macOS: `open -a Warp`.) Then **wait ~5 seconds** for Warp to initialize its
   profile. If launch fails - e.g. the exe is not at the path because step 1 could
   not install it - investigate rather than silently succeeding.

3. **Onboarding gate - fresh installs only.** If step 1 just installed Warp, the
   profile is fresh and Warp is showing its onboarding windows. **Tell the user to
   click through onboarding until they reach the main terminal view, and wait for
   their explicit confirmation before continuing.** This step is load-bearing:
   completing onboarding makes Warp flush its in-memory settings to `settings.toml`,
   so any config written before the user finishes is silently overwritten. Waiting
   moves the config write *past* that flush. If Warp was already installed (you
   skipped the install in step 1), it is already onboarded - **skip this gate** and
   go to step 4. (There is no reliable programmatic "onboarding done" signal - we
   deliberately never read `warp.sqlite` - so asking the user is the honest check.)

4. **Apply config with Warp stopped, then relaunch** (tab configs + visual setup -
   this part stays scripted). Three moves, in order:

   a. **Quit Warp** so nothing can flush over your write
      (macOS: `osascript -e 'quit app "Warp"'`):

      ```
      powershell -ExecutionPolicy Bypass -Command "Get-Process Warp -ErrorAction SilentlyContinue | Stop-Process -Force"
      ```

   b. **Run the config script** while Warp is *not* running - your write is now the
      last write to disk. It prints each file + target path:

      ```
      powershell -ExecutionPolicy Bypass -File ${CLAUDE_PLUGIN_ROOT}/skills/warp-setup/scripts/apply-warp-config.ps1
      ```

   c. **Relaunch Warp** - the profile is initialized, so Warp *reads* `settings.toml`
      on startup instead of regenerating defaults (macOS: `open -a Warp`):

      ```
      powershell -ExecutionPolicy Bypass -Command "Start-Process \"$env:LOCALAPPDATA\Programs\Warp\warp.exe\""
      ```

   **Why stopped, not hot-reloaded:** a fresh profile has *two* clobber windows -
   the first launch initializing the internal store, and onboarding completion
   flushing in-memory settings - and beyond those a running Warp can flush over a
   hot-reloaded write at any time (including on exit). Writing while Warp is stopped
   and letting a fresh launch read the file beats every one of those races. **Verify
   it stuck:** re-read `settings.toml` and confirm known values landed (e.g.
   `default_session_mode = "tab_config"`, `is_any_ai_enabled = false`,
   `theme = "adeberry"`). If somehow clobbered, repeat a/b/c - it sticks once
   onboarding is done.

5. Report what happened across all steps: whether Warp was installed or already
   present (and by which method), whether you waited on the onboarding gate, the
   files written and that they stuck (the re-read confirms it), and that Warp is
   running. Mention that new tabs come from Warp's `+` menu, and that - because you
   wrote config with Warp stopped - the visual setup is already applied on this
   launch with no further reload needed.

## Install (model-driven, per OS)

Run these yourself, step by step, reading output between calls. The download is
~125 MB - give it a long timeout (or run it in the background and poll) rather
than letting a 2-minute default kill it mid-download.

### Windows (proven path - avoids the winget download wedge)

1. **Detect** - skip everything if it already exists:
   `Test-Path "$env:LOCALAPPDATA\Programs\Warp\warp.exe"`.
2. **Discover the latest version** with winget *metadata* (this does NOT wedge -
   only `winget install`'s download does):

   ```
   winget show --id Warp.Warp --exact --disable-interactivity
   ```

   Parse the `Version:` line (e.g. `v0.2026.06.03.09.49.stable_02`). If winget is
   absent, fall back to the warp.dev download page or ask the user for the build.
3. **Pick arch:** `$env:PROCESSOR_ARCHITECTURE` -> `ARM64` = `aarch64`, else
   `x86_64`.
4. **Download the installer directly** (this is what winget can't reliably do).
   The versioned endpoint 302s to `releases.warp.dev/.../WarpSetup.exe` and serves
   a real `application/octet-stream`:

   ```
   curl.exe -sSL --max-time 600 -o "$env:LOCALAPPDATA\Temp\WarpSetup.exe" `
     "https://app.warp.dev/download/windows?version=<VERSION>&arch=<ARCH>"
   ```

   Sanity-check the size (>50 MB). A tiny file means you got an HTML page, not the
   installer (e.g. the version param was missing - the bare URL returns HTTP 400).
5. **Silent install** - it's an Inno Setup installer, per-user, no elevation:

   ```
   Start-Process "$env:LOCALAPPDATA\Temp\WarpSetup.exe" `
     -ArgumentList "/VERYSILENT","/SUPPRESSMSGBOXES","/NORESTART"
   ```

   Do **not** rely on `-Wait` to tell you it's done - this installer sometimes
   blocks `-Wait` indefinitely even after the app is in place. Instead **poll for
   `warp.exe` to appear** at the detect path (up to ~2 min), and treat that as
   "installed."
6. **Close the auto-launched Warp.** This installer's post-install `[Run]` entry
   **auto-launches Warp even under `/VERYSILENT`** (it isn't flagged
   `skipifsilent`, and there's no switch to suppress it). If you don't close it,
   Warp pops open mid-setup while you're still working - confusing for the user.
   So once `warp.exe` exists, wait a couple seconds and kill any running instance,
   leaving the single deliberate launch for step 3:

   ```
   Get-Process Warp -ErrorAction SilentlyContinue | Stop-Process -Force
   ```

   (Killing it does **not** harm the install - verified.)
7. **Verify** `warp.exe` exists at the detect path and no `Warp`/`WarpSetup`
   process is left running. (Warp declares a `Microsoft.VCRedist.2015+.x64`
   dependency; it is present on essentially all modern Windows machines - check
   `HKLM:\SOFTWARE\Microsoft\VisualStudio\14.0\VC\Runtimes\x64` if Warp won't
   launch, and install it via winget/direct download only if genuinely missing.)

You *may* try `winget install --id Warp.Warp --exact` if you want, but bound it
(background + a few minutes) and fall back to the direct download above the moment
it stalls at "Downloading..." - don't repeat the 25-minute wedge.

### macOS

If `/Applications/Warp.app` is missing and Homebrew is available:
`brew install --cask warp`. If brew is absent, tell the user to install Warp from
https://www.warp.dev/ (or `brew install --cask warp`) and continue to config.

## Notes

- **Install (step 1) - model-driven, see the "Install" section above.**
  - Detection is by the known install path, not PATH (Warp does not add itself to
    PATH): Windows `%LOCALAPPDATA%\Programs\Warp\warp.exe`; macOS
    `/Applications/Warp.app`. Install runs only when that path is missing.
  - There is intentionally **no install script** - you run the commands so you own
    the timeout/background behavior and can recover when a method stalls. This
    flow - including the onboarding gate and the quit -> write -> relaunch config -
    was last validated on a fresh Windows machine on 2026-06-19.
  - `--id Warp.Warp --exact` (when using winget for metadata) is deliberate - a
    bare `warp` can match `Cloudflare.Warp` (moniker "warp") or other warp*
    packages. The Warp installer is per-user, so no elevation is needed.
  - Known issue this design works around: `winget install Warp.Warp` wedges at its
    download step on at least one of the user's Windows machines. The proven path
    discovers the version via `winget show` but downloads the installer with
    `curl` and runs it silently - which does not wedge.
- **Where config files go.**
  - Tab configs: Windows `%APPDATA%\warp\Warp\data\tab_configs\`; macOS
    `~/.warp/tab_configs/`.
  - settings.toml: Windows `%LOCALAPPDATA%\warp\Warp\config\`; macOS `~/.warp/`.
  - `apply-warp-config.ps1` detects the OS and creates the directories if they do
    not exist. (Linux paths differ - `~/.config/warp-terminal/` - and are not
    separately handled.)
- **Idempotent.** Re-running installs nothing if Warp is present (detection skips
  it), skips the onboarding gate (an already-installed Warp is already onboarded),
  and overwrites the on-disk config with the bundled versions via the same
  quit -> write -> relaunch - safe on every new device or after a Warp reinstall.
- **Encoding matters.** All config files are written as UTF-8 without BOM; Warp
  fails to parse TOML that carries a BOM. `apply-warp-config.ps1` handles this -
  which is exactly why config stays scripted rather than model-driven.
- **Privacy.** `warp.sqlite` (account email, command history, session) is never
  read or written. Nothing sensitive lives in the shipped assets once the path
  token is substituted.
- These are the *standing* tab configs, distinct from any throwaway,
  self-deleting tab config a separate skill might use to spawn a one-off new chat.
