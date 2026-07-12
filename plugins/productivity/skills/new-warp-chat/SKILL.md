---
name: new-warp-chat
description: >-
  Open a new tab in the user's running Warp terminal that auto-runs a given
  command - optionally with a seed prompt baked in as the command's final
  argument - via a throwaway, self-deleting warp://tab_config, leaving the
  current session untouched. This is the shared low-level launcher other skills
  build on: it owns the TOML escaping, the UTF-8 no-BOM config write, the
  race-free self-delete, the PowerShell 5.1 seed-quoting, and the warp:// URI
  launch. Use when a skill or the user needs a fresh Warp tab running a command
  (a new CLI chat, a seeded onboarding tab, a one-off tool). Do NOT use to
  delegate background work you need a result back from (that is a subagent), or
  on terminals other than Warp.
---

# New Warp Chat (the shared seeded-tab launcher)

Open a new, independent **Warp tab** that auto-runs a command - e.g. a fresh CLI
chat seeded with a starting prompt - while the current session keeps running
untouched. This skill owns only the **mechanism**; the caller (a user request or
a higher-level skill such as the sibling `breakout`) owns *what* to launch and
*what the seed says*.

## The mechanism

Warp exposes exactly one way to open a tab in the current window from a script:
the `warp://tab_config/<name>` URI opens a new tab running a config file you
drop in Warp's `tab_configs` dir. The launcher writes a throwaway config whose
one command **deletes the config itself, then runs your command**:

- **Self-deleting, race-free.** Warp has already read the config by the time the
  tab runs its first command, so the delete never races the read - and no
  `<name>` entry lingers in Warp's `+` menu.
- **Never relaunch `warp.exe`.** The URI opens a tab in the *running* Warp;
  launching the exe instead trips Warp's session restore. If Warp is not
  running, stop and ask the user to open it.
- **UTF-8, no BOM.** Warp's TOML parser chokes on a BOM.

## Inputs (every caller decides these)

| Input | Meaning |
| ----- | ------- |
| tab name | Names the config file and the URI (`[A-Za-z0-9._-]+`). Use your skill's name so a stray failure is attributable. |
| command + args | What the tab runs, e.g. `claude --chrome` or `codex --yolo`. |
| seed (optional) | Text appended as the command's **final single argument** - e.g. a CLI's initial prompt. Multi-line seeds are collapsed to one line. |

Prepare any seed in a **file** (Write tool), never inline on a command line -
quotes, `$`, and backticks then survive regardless of shell. The launcher
deletes the seed file once it is baked in.

## Resolve the OS specifics

| OS      | tab_configs dir                        | open-URI command                     |
| ------- | -------------------------------------- | ------------------------------------ |
| Windows | `%APPDATA%\warp\Warp\data\tab_configs` | `Start-Process "warp://tab_config/<name>"` |
| macOS   | `~/.warp/tab_configs`                  | `open "warp://tab_config/<name>"`    |
| Linux   | verify Warp's data dir (e.g. under `~/.local/state/warp-terminal/` or `~/.config/warp-terminal/`) | `xdg-open "warp://tab_config/<name>"` |

Create the tab_configs dir if missing. If Warp is not installed, say so and stop.

## Windows - call the bundled helper (do not hand-assemble)

PowerShell 5.1 does **not** escape interior `"` when invoking a native exe, so a
hand-assembled seed splits at the first `"` and silently truncates - the exact
regression this script exists to kill. Call it; never reimplement its escaping
inline:

```powershell
& "${CLAUDE_PLUGIN_ROOT}/skills/new-warp-chat/scripts/new-warp-chat.ps1" `
    -TabName <name> -LaunchCmd <cmd> -LaunchArgs '<args>' -SeedFile '<seed-file>'
```

Omit `-SeedFile` entirely for no seed; `-LaunchArgs` may be empty. The script
escapes the seed (single-quoted literal + the CommandLineToArgvW rules: double
each backslash run before a `"` and add one more, and double a trailing
backslash run when the argument will be quoted), writes the self-deleting
config, deletes the seed file, and fires the URI. It prints what it launched.

## macOS / Linux - model-driven inline

`"$(cat file)"` passes a seed verbatim in bash/zsh, so no helper is needed.
Compose the tab command (drop the `$S` parts when there is no seed):

```
rm -f '<cfg>'; S="$(cat '<seed-file>')"; rm -f '<seed-file>'; <cmd> <args> "$S"
```

Then write `<tab_configs>/<name>.toml` with the Write tool (UTF-8, no BOM):

```toml
name = "<name>"

[[panes]]
id = "main"
type = "terminal"
commands = ["<the command above, TOML-escaped: \ as \\ and \" for quotes>"]
```

Fire the URI from the OS table. The new tab inherits the current tab's working
directory on every OS.

## For calling skills

The contract: **you** compose the seed and pick the command; **this skill** gets
it into a new tab intact. On Windows call the script; on macOS/Linux follow the
inline steps. Current consumers: the sibling `breakout` skill (fresh CLI chat);
a device-setup onboarding handoff (a seeded getting-started tab) is the intended
next one. You cannot see the launched tab - report what you launched and let the
user confirm it appeared.

## Testing

`tests/test-seed-quoting.ps1` (Windows PowerShell 5.1) regression-tests the
escaping end-to-end without opening tabs: it decodes the generated TOML and
executes the tab command against an argv-recording probe. Run it after ANY
change to the script's quoting - that logic has regressed before.
