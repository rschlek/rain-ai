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

Breakout owns **which CLI to open and what the seed says**. The tab itself is
opened by the sibling **`new-warp-chat`** skill - the shared seeded-tab launcher
that owns the whole Warp mechanism (the self-deleting tab config, TOML escaping,
the PowerShell 5.1 seed-quoting, the `warp://` URI). Breakout is therefore
**Warp-only**: if the user is not on Warp, say so and stop - a different terminal
needs its own mechanism, the seam where support could be added later.

## Why a new session, not a subagent

A subagent runs autonomously and returns a result to the orchestrator - the user
cannot converse with it. A real, talk-to-it chat only exists as a new `claude` (or
`codex`) session. Breakout launches one.

## Steps

**1. Detect the current CLI.** The new session must run **the same CLI you are
running in now** - Claude Code if this session is Claude, Codex if it is Codex.
Read the environment to decide, in priority order:

- **Warp's `AI_AGENT`** (Warp sets it per pane to the active agent): a value
  starting `claude` -> **Claude Code**; starting `codex` -> **Codex**. This is the
  terminal's own agent marker and the most CLI-neutral signal - prefer it.
- **CLI-specific env** as corroboration: `CLAUDECODE=1` / `CLAUDE_CODE_*` ->
  Claude Code; Codex's own `CODEX_*` markers -> Codex.
- **If still ambiguous**, ask the user which CLI to open - do not guess.

**2. Resolve the CLI's launch command + args.** Use the row for the detected CLI;
the defaults match the user's standing `warp-setup` tab configs:

| CLI         | launch   | default args                              | drop / adjust on request                                                          |
| ----------- | -------- | ----------------------------------------- | --------------------------------------------------------------------------------- |
| Claude Code | `claude` | `--chrome --dangerously-skip-permissions` | drop `--dangerously-skip-permissions` to keep permission prompts; drop `--chrome` to skip Chrome |
| Codex       | `codex`  | `--yolo`                                  | drop `--yolo` to keep Codex's approval prompts (Codex has no `--chrome` equivalent) |

Or set the args wholesale on request.

**3. Prepare the seed (if any).** Write it to a temp file with the Write tool -
per the launcher's contract the seed never transits a command line, so quotes /
`$` / backticks survive regardless of shell. When breakout continues a workflow
(e.g. after a handoff), the seed must be a **self-contained kickoff prompt**:
what the new chat is, the goal, and the immediate next step - everything the
fresh context needs, since it inherits none of the current conversation. Keep it
tight; it is a launch prompt, not a transcript.

**4. Launch via `new-warp-chat`.** Follow the sibling skill's SKILL.md with tab
name `breakout`, the step-1 CLI as the command, the step-2 args, and the step-3
seed file. On Windows that is one call to its bundled helper:

```powershell
& "${CLAUDE_PLUGIN_ROOT}/skills/new-warp-chat/scripts/new-warp-chat.ps1" `
    -TabName breakout -LaunchCmd <cli> -LaunchArgs '<args>' -SeedFile '<seed>'
```

(**Omit `-SeedFile` entirely** for an empty chat.) On macOS / Linux follow
new-warp-chat's model-driven inline path (compose the self-deleting tab command,
write the config, fire the URI). **Never hand-assemble the Windows command line**
- PowerShell 5.1 truncates a seed at its first `"`; the escaping lives in the
launcher precisely so that bug cannot regress.

**5. Confirm.** You cannot see the new tab - report what you launched and ask the
user what opened.

## Notes

- The launcher's throwaway `breakout.toml` is distinct from warp-setup's standing
  `claude.toml` / `claude-resume.toml` / `codex.toml` / `codex-resume.toml` in the
  same dir. It self-deletes, so no `breakout` entry lingers in the Warp `+` menu
  (it only flickers in for the moment between launch and the tab starting).
- New Warp tabs inherit the current tab's working directory, so a handoff that
  continues work lands in the same project for free.
- The new session matches the **current** CLI (step 1), so a breakout from Claude
  opens Claude and a breakout from Codex opens Codex - context follows the tool you
  are already in. The Codex branch (`AI_AGENT` starting `codex`, `codex --yolo`,
  seed as a positional prompt) mirrors the Claude path; verify it once against a
  real Codex session, since Codex's exact env markers and prompt-arg handling were
  not confirmed at authoring time.
- This skill assumes the user's Warp setup (see `warp-setup`). It does not detect
  or support other terminals.
