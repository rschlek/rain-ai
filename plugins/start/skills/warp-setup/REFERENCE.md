# Warp setup - config-applier reference

Operational detail for `warp-setup`. SKILL.md owns the ask -> precondition ->
reconcile -> verify -> open flow; this file holds the detect / onboarding
precondition, the manual-install handoff (the **user** installs, not the skill), the
OS config paths, the launch/quit commands, the self-host guard, and the clobber-window
rationale. You run these inline as harness commands - there is **no bundled script**.

## This skill does not install Warp

It is a **config applier**, the sibling of `claude-code-setup` and `codex-cli-setup`:
it assumes the tool exists and applies config. If Warp is missing, hand the user the
manual install instructions below and **wait** - do not install it yourself. (True
end-to-end install is impossible anyway: Warp's onboarding is a GUI gate only the user
can click through, so install + onboarding is always partly the user's job. Drawing the
line at "config only" keeps the seam clean.)

## Detect Warp (the precondition's first half)

Warp is **not** on PATH - detect by the known install path:

- Windows: `Test-Path "$env:LOCALAPPDATA\Programs\Warp\warp.exe"`
- macOS: `/Applications/Warp.app`

## Onboarded check (the precondition's second half)

Config written before Warp has flushed its first-run settings gets clobbered when
onboarding completes. So require that Warp has been **opened at least once and
onboarded** before you write. The honest signal: `settings.toml` exists at the config
dir (below) and is **non-trivial** - Warp writes it on the first-launch / onboarding
flush. If it is absent or empty, Warp has not been onboarded: ask the user to open Warp
once, click through onboarding to the terminal prompt, and reply. We deliberately never
read `warp.sqlite` (account email, command history), so this artifact check plus the
user's confirmation is the check.

## Installing Warp yourself (when missing - user-performed)

Hand these to the user; **they install, you wait.** After installing they must also
open Warp once and finish onboarding (above) before you reconcile.

- **macOS:** download from https://www.warp.dev/ (Apple Silicon `.dmg` on `arm64`,
  Intel on `x86_64`) and drag Warp into `/Applications`; or `brew install --cask warp`
  if they have Homebrew.
- **Windows:** download the installer from https://www.warp.dev/ and run it; or
  `winget install --id Warp.Warp --exact`. Caveat worth passing along: winget's
  download step has been observed to wedge for 25+ min on some machines - if it hangs
  at "Downloading...", cancel and use the direct download instead.
- **Linux:** packages at https://www.warp.dev/. Note its config lives under
  `~/.config/warp-terminal/`, which this skill does **not** reconcile (see below).

## Config paths (resolve per OS; create missing dirs)

| OS      | tab_configs dir                          | settings dir                      |
| ------- | ---------------------------------------- | --------------------------------- |
| Windows | `%APPDATA%\warp\Warp\data\tab_configs`   | `%LOCALAPPDATA%\warp\Warp\config` |
| macOS   | `~/.warp/tab_configs`                    | `~/.warp`                         |

Linux differs (`~/.config/warp-terminal/`) and is **not** separately handled - if you
detect Linux, say so and stop.

## Launch / quit commands

- **Launch (Windows):**
  `powershell -ExecutionPolicy Bypass -Command "Start-Process \"$env:LOCALAPPDATA\Programs\Warp\warp.exe\""`
  (macOS: `open -a Warp`.) Wait ~5 s after launch for Warp to initialize.
- **Quit (Windows) - ONLY after the self-host guard below clears:**
  `powershell -ExecutionPolicy Bypass -Command "Get-Process Warp -ErrorAction SilentlyContinue | Stop-Process -Force"`
  (macOS: `osascript -e 'quit app "Warp"'`.)

`-ExecutionPolicy Bypass` is needed on machines at the default `Restricted` policy; it
scopes only to that child process. (This skill ships no `.ps1`, but you still run inline
`powershell -Command` snippets.)

## Self-host guard (never quit the Warp you are running in)

The quit above is **forbidden when this session is hosted inside the very Warp it would
kill** - e.g. you re-ran this skill from a `claude` or `codex` Warp tab.
`Stop-Process -Force` on Warp tears down the terminal mid-skill. **Always check
self-host before quitting**; treat *either* positive signal as self-host:

- **Env signal (cheapest, verified):** Warp sets `TERM_PROGRAM=WarpTerminal` in the
  shell it spawns, inherited by the agent process. So `$env:TERM_PROGRAM -eq
  'WarpTerminal'` -> you are inside Warp. (Do not rely on `TERM_PROGRAM_VERSION` - it
  can be empty.)
- **Process-chain signal (corroborating):** walk this process's ancestor chain; a
  `warp.exe` (Windows) / Warp (macOS) ancestor means you are inside Warp, e.g.

  ```
  powershell -Command "$p=Get-CimInstance Win32_Process -Filter \"ProcessId=$PID\"; for($i=0;$i -lt 8 -and $p;$i++){ if($p.Name -eq 'warp.exe'){'self-host'; break}; $p=Get-CimInstance Win32_Process -Filter \"ProcessId=$($p.ParentProcessId)\" -EA SilentlyContinue }"
  ```

When self-hosted, **do not run the quit** - take the self-host branch (write tab
configs live, reconcile `settings.toml` live with the durability caveat, skip the
quit/relaunch; the open-session step still runs).

## The clobber windows (why quit -> write -> relaunch)

Warp **hot-reloads** `settings.toml`, so an edit shows up live - but do **not** rely on
hot-reload to *persist* config. A running Warp also flushes its own in-memory settings
back to `settings.toml` and overwrites a hot-reloaded write (including on exit). So
write config while Warp is **stopped** and let a fresh launch read it - that beats the
race. This is why the reconcile path is quit -> write -> relaunch.

The two **fresh-profile** clobber windows (first launch initializing the internal
store, and onboarding completion flushing in-memory settings to disk) are handled up
front by the **onboarded precondition** - you only reconcile a Warp that has already
passed them, which is the simplification the config-applier model buys.

**Self-host caveat.** This quit->write->relaunch assumes you *can* quit Warp. When the
session runs **inside** Warp you cannot (it would kill your terminal - see the self-host
guard). There the tab-config writes still persist (that directory is never flushed), but
the `settings.toml` write only persists durably after a later full quit+relaunch the
user performs with no in-Warp agent session running (or a re-run of this skill from a
non-Warp terminal).
