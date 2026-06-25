---
name: breakout
description: >-
  Open a fresh chat in a new Warp tab running the SAME CLI as the current session -
  Claude Code if you are in Claude, Codex if you are in Codex (auto-detected from
  the environment) - optionally seeded with a starting prompt, while the current
  session keeps running untouched. Use when the user wants to "break out" into a new
  chat - to start a clean session, or to continue work in a fresh context with a
  seed prompt ("breakout", "open a new chat", "start a fresh chat in a new tab",
  "move this into a new tab", "/handoff then breakout"). Do NOT use to delegate
  background work you need a result back from (that is a subagent), or to capture a
  task.
---

# Breakout

Open a new, independent chat in a fresh **Warp tab**, running **whichever CLI the
current session is in** (Claude Code or Codex, auto-detected), optionally seeded
with a starting prompt. The current session is never paused. Use it directly to
start a clean chat, or after a handoff to continue work in a fresh context.

This skill is **Warp-only**. On **macOS / Linux** it is fully **model-driven**:
you detect the OS, write a throwaway Warp tab config with the Write tool, and fire
Warp's tab-config URI. On **Windows** it delegates the launch to one small bundled
helper, `scripts/breakout.ps1`, because PowerShell 5.1's native-exe argument
quoting is too fragile to assemble inline reliably - a seed with a literal `"`
splits and the prompt truncates (see *Seed quoting* below). The helper owns that
escaping in code so it cannot regress; everything else is the same Warp
tab-config mechanism `warp-setup` uses.

## Why a new session, not a subagent

A subagent runs autonomously and returns a result to the orchestrator - the user
cannot converse with it. A real, talk-to-it chat only exists as a new `claude` (or
`codex`) session. Breakout launches one.

## Why Warp

A new tab *in the current terminal* is only reachable through that terminal's own
mechanism. Warp exposes one: the `warp://tab_config/<name>` URI opens a new tab
running a config file you drop in Warp's `tab_configs` dir. That URI behaves the
same on every OS Warp supports - only the config directory and the "open a URI"
command differ, which you resolve at run time. So breakout is a few inline steps
(the harness + the Write tool) on macOS / Linux, and the bundled
`scripts/breakout.ps1` on Windows. If the user is not on Warp, this skill does not
apply - say so and stop.

## Steps

**1. Resolve the OS specifics.** Detect the OS and use the matching row (the
paths are the same ones `warp-setup` writes to):

| OS      | tab_configs dir                        | open-URI command                              | new tab's shell      |
| ------- | -------------------------------------- | --------------------------------------------- | -------------------- |
| Windows | `%APPDATA%\warp\Warp\data\tab_configs` | `Start-Process "warp://tab_config/breakout"`  | PowerShell           |
| macOS   | `~/.warp/tab_configs`                  | `open "warp://tab_config/breakout"`           | login shell (zsh)    |
| Linux   | verify Warp's data dir (e.g. under `~/.local/state/warp-terminal/` or `~/.config/warp-terminal/`) | `xdg-open "warp://tab_config/breakout"` | login shell |

Create the tab_configs dir if it is missing. If Warp clearly is not installed,
stop and tell the user - this skill is Warp-only.

**2. Detect the current CLI.** The new session must run **the same CLI you are
running in now** - Claude Code if this session is Claude, Codex if it is Codex.
Read the environment to decide, in priority order:

- **Warp's `AI_AGENT`** (Warp sets it per pane to the active agent): a value
  starting `claude` -> **Claude Code**; starting `codex` -> **Codex**. This is the
  terminal's own agent marker and the most CLI-neutral signal - prefer it.
- **CLI-specific env** as corroboration: `CLAUDECODE=1` / `CLAUDE_CODE_*` ->
  Claude Code; Codex's own `CODEX_*` markers -> Codex.
- **If still ambiguous**, ask the user which CLI to open - do not guess.

Carry the detected CLI into steps 3-5.

**3. Resolve the CLI's launch command + args.** Use the row for the detected CLI;
the defaults match the user's standing `warp-setup` tab configs:

| CLI         | launch   | default args                              | drop / adjust on request                                                          |
| ----------- | -------- | ----------------------------------------- | --------------------------------------------------------------------------------- |
| Claude Code | `claude` | `--chrome --dangerously-skip-permissions` | drop `--dangerously-skip-permissions` to keep permission prompts; drop `--chrome` to skip Chrome |
| Codex       | `codex`  | `--yolo`                                  | drop `--yolo` to keep Codex's approval prompts (Codex has no `--chrome` equivalent) |

Or set the args wholesale on request.

**4. Prepare the seed (if any).** Collapse the seed to a single line. For
anything beyond a trivial one-liner, write it to a temp file with the Write tool
and have the new tab read it - the seed then never transits a command line, so
quotes / `$` / backticks survive regardless of shell.

**5. Launch.** This step differs by OS. Both paths produce the same result: a
self-deleting `breakout.toml` whose one command deletes the config (Warp has
already read it - race-free, no lingering `+`-menu entry), then runs the detected
CLI with its args and the seed as the initial-prompt positional arg.

- **Windows - call the bundled helper.** Do **not** hand-assemble the command or
  TOML here; PowerShell 5.1's quoting will truncate the seed (see *Seed quoting*).
  The helper owns the seed-escaping, writes the config, deletes the seed file, and
  fires the URI:
  ```powershell
  & "${CLAUDE_PLUGIN_ROOT}/skills/breakout/scripts/breakout.ps1" -LaunchCmd <cli> -LaunchArgs '<args>' -SeedFile '<seed>'
  ```
  `<cli>` = `claude` or `codex` (step 2/3), `<args>` = its args (step 3, may be
  empty), `<seed>` = the temp file from step 4. **Omit `-SeedFile` entirely** for
  an empty chat. The helper prints what it launched; you are done - skip steps 6-7.

- **macOS / Linux - model-driven inline.** bash/zsh's `"$(cat file)"` passes the
  seed verbatim, so no helper is needed. Compose the tab command (`<cfg>` = the tab
  config from step 6, `<seed>` = the temp file from step 4):
  ```
  rm -f '<cfg>'; S="$(cat '<seed>')"; rm -f '<seed>'; <cli> <args> "$S"
  ```
  With no seed, drop the `$S` / `S=` parts and just delete `<cfg>` then run
  `<cli> <args>`. Then do steps 6-7.

**6. Write the tab config** (macOS / Linux only - the Windows helper already did
this) with the Write tool (UTF-8, **no BOM** - Warp's TOML parser chokes on a BOM;
the Write tool emits no BOM, so just use it). Write `<tab_configs>/breakout.toml`:

```toml
name = "breakout"

[[panes]]
id = "main"
type = "terminal"
commands = ["<the step-5 command>"]
```

The `commands` entry is a TOML basic string: escape `\` as `\\` and `"` as `\"`
inside it. Writing the file directly (not through a shell) means that is the only
escaping you do.

**7. Fire the URI** (macOS / Linux only) with the row's open command. Warp opens
the new tab, which deletes its own config and starts the detected CLI.

**8. Confirm.** You cannot see the new tab - ask the user what opened.

## Seed quoting

This is the whole reason the Windows path is a script, not inline steps.

- **bash / zsh** `"$(cat file)"` passes the file content as one argument verbatim -
  robust for any characters. That is why macOS / Linux stays model-driven.
- **PowerShell 5.1** does **not** escape interior `"` when calling a native exe, so
  a seed containing a literal `"` splits into extra args and the prompt truncates
  at the first `"` (claude then trips on a stray token like `unknown option`). The
  fix is the CommandLineToArgvW rule - double each run of backslashes before a `"`
  and add one more - plus single-quote-wrapping the literal. That escaping is
  fiddly and easy to get wrong inline (it has regressed before), so it lives in
  `scripts/breakout.ps1`, which the Windows path calls. **Do not** reimplement it
  inline; pass the seed to the helper via `-SeedFile` and let it handle the rest.

## Composing the seed (when continuing work)

When breakout continues a workflow (e.g. after a handoff), the seed must be a
**self-contained kickoff prompt**: what the new chat is, the goal, and the
immediate next step - everything the fresh context needs, since it inherits none
of the current conversation. Keep it tight; it is a launch prompt, not a
transcript.

## For other skills

Sibling skills compose their own seed and run these same steps - on Windows, write
the seed file and call `scripts/breakout.ps1`; on macOS / Linux, write the seed
file, the tab config, and fire the URI. Breakout owns only the mechanism (a new
Warp tab) and the seed-escaping; the caller owns what the prompt says.

## Notes

- The throwaway `breakout.toml` is distinct from warp-setup's standing
  `claude.toml` / `claude-resume.toml` / `codex.toml` / `codex-resume.toml` in the
  same dir. It self-deletes, so no `breakout` entry lingers in the Warp `+` menu (it
  only flickers in for the moment between launch and the tab starting).
- New Warp tabs inherit the current tab's working directory, so a handoff that
  continues work lands in the same project for free.
- The new session matches the **current** CLI (step 2), so a breakout from Claude
  opens Claude and a breakout from Codex opens Codex - context follows the tool you
  are already in. The Codex branch (`AI_AGENT` starting `codex`, `codex --yolo`,
  seed as a positional prompt) mirrors the Claude path; verify it once against a
  real Codex session, since Codex's exact env markers and prompt-arg handling were
  not confirmed at authoring time.
- This skill assumes the user's Warp setup (see `warp-setup`). It does not detect
  or support other terminals - a different terminal needs its own mechanism, the
  seam where support could be added later.
