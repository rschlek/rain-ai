---
name: breakout
description: >-
  Open a fresh Claude Code chat in a new terminal tab (or window), optionally
  seeded with a starting prompt, while the current session keeps running
  untouched. Use when the user wants to "break out" into a new chat - to start a
  clean session, or to continue work in a fresh context with a seed prompt
  ("breakout", "open a new chat", "start a fresh chat in a new tab", "move this
  into a new tab", "/handoff then breakout"). Do NOT use to delegate background
  work you need a result back from (that is a subagent), or to capture a task.
---

# Breakout

Open a new, independent Claude Code chat in a fresh terminal tab, optionally
seeded with a starting prompt. The current session is never paused. Use it
directly to start a fresh chat, or after a handoff to continue work in a clean
context.

## Why a new session, not a subagent

A subagent runs autonomously and returns a result to the orchestrator - the user
cannot converse with it. A real, talk-to-it chat only exists as a new `claude`
session. Breakout launches one.

## Quick start

- "breakout" (no prompt) -> a fresh `claude` chat opens in a new tab.
- "/handoff then breakout" -> compose the continuation prompt, pass it as the
  seed; the new chat opens already primed to continue the work.

## How to launch

Run the bundled launcher (it handles the downstream quoting and the Warp/window
choice). **How you pass the seed matters** - pick by the seed:

**Rich seed (anything beyond a trivial one-liner) -> `-SeedFile`.** Write the
prompt to a temp file and pass only the path. The content never transits a
command line, so embedded `"` quotes, newlines, `$`, and backticks all survive
regardless of caller shell. This is the robust default for a real kickoff prompt:

```
# 1. Write the composed seed to a temp file (use the Write tool, no escaping needed).
# 2. Launch with its path:
powershell -ExecutionPolicy Bypass -File ${CLAUDE_PLUGIN_ROOT}/skills/breakout/scripts/breakout.ps1 -SeedFile <path-to-seed.txt>
```

**Already in a PowerShell session -> here-string + a direct call.** A here-string
assigned to a variable passes as one native argument (no re-tokenization):

```
$seed = @'
<prompt - any quotes / newlines are safe>
'@
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
& ${CLAUDE_PLUGIN_ROOT}/skills/breakout/scripts/breakout.ps1 -Seed $seed
```

**Trivial one-liner with no embedded quotes -> inline `-Seed` is fine:**

```
powershell -ExecutionPolicy Bypass -File ${CLAUDE_PLUGIN_ROOT}/skills/breakout/scripts/breakout.ps1 -Seed "<short prompt, or omit for an empty fresh chat>"
```

> Avoid inline `-Seed "..."` for a prompt that contains double quotes: `powershell
> -File ... -Seed "..."` re-tokenizes the command line *before* the launcher's
> parameter binder runs, so a seed fragment can bind to `-Method` (the launch
> fails loudly) or the seed silently truncates. Use `-SeedFile` or the here-string
> form instead.

`-ExecutionPolicy Bypass` is required: on a machine whose PowerShell execution
policy is the default `Restricted` (common on personal/non-managed Windows), a
bare `powershell -File ...` refuses to run the `.ps1`. The flag scopes only to
this one child process - it changes nothing persistently.

- **Default (auto):** opens a new **Warp tab** in the current window if Warp is
  present (writes a tab config and fires `warp://tab_config/breakout`); otherwise
  falls back to a new terminal **window**. Force one with `-Method warp|window`.
- **Claude args default to `--chrome --dangerously-skip-permissions`.** Pass
  `-Normal` to keep tool-permission prompts in the new chat, `-NoChrome` to drop
  Chrome, or `-ClaudeArgs "..."` to set them wholesale.
- New Warp tabs inherit the current tab's working directory, so a handoff that
  continues work lands in the same project for free.

## Composing the seed (when continuing work)

When breakout continues a workflow (e.g. after a handoff), the seed must be a
**self-contained kickoff prompt**: what the new chat is, the goal, and the
immediate next step - everything the fresh context needs, since it inherits none
of the current conversation. Keep it tight; it is a launch prompt, not a
transcript.

## For other skills

Sibling skills compose their own seed and call the same launcher. For a real
kickoff prompt, pass it via `-SeedFile` (write the seed to a temp file, hand over
the path) - robust against any quotes or newlines in the prompt; reserve inline
`-Seed` for trivial one-liners. Breakout owns only the mechanism (where/how the
new chat opens); the caller owns what the prompt says.

## Notes

- The launch method is the single knob: Warp tab by default, new window on
  request. No per-terminal detection - that is the seam where other terminals
  get added later.
- A new tab in the *current* terminal is only reachable through that terminal's
  own mechanism (here, Warp's `tab_config` URI). A generic spawn yields a new
  window; that is the fallback, by design.
- The generated Warp tab config is self-deleting: the new tab removes it as its
  first command, so no `breakout` entry lingers in the Warp `+` menu (it only
  flickers in for the moment between launch and the tab starting). The launcher
  cannot see the new tab, so confirm with the user what opened.
