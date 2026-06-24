#!/usr/bin/env bash
# SessionStart hook for the brrain plugin - the CLAUDE CODE path.
#
# Dispatch: hook.sh routes here on Claude Code (and to inject-agents-md.sh on
# Codex). The two hosts differ in HOW context is injected, not WHAT: the text is
# built once by the shared brain-context.sh, and this script wraps it for Claude.
#
# Claude Code injects SessionStart context ONLY via JSON with
# hookSpecificOutput.additionalContext (plain stdout is ignored), and renders it
# silently into the model context - so this script emits that JSON. Codex,
# by contrast, renders additionalContext into the VISIBLE transcript
# unconditionally (upstream bug openai/codex#16933), so it cannot use this path;
# inject-agents-md.sh maintains the same text silently in ~/.codex/AGENTS.md.
#
# A SessionStart hook must never break or slow startup, so the only no-op is "no
# brain on this device" (brain-context.sh exits non-zero); every other path
# emits the write nudge. The text's own gating (write nudge always, read/index
# block only once refine has built a non-empty index.md) lives in
# brain-context.sh.
#
# Windows invocation: on Windows, Codex does NOT run a hook command through a
# shell - it splits the string into program + args and spawns the first token
# directly, resolving it on PATH. So a bare `bash` resolves to the WSL launcher
# (C:\Windows\System32\bash.exe), which exits non-zero when no WSL distro
# provides /bin/bash (e.g. when WSL exists only for Docker Desktop) - and a
# quoted Git-bash program path with a space ("C:\Program Files\Git\...") gets
# mis-split on the space. So command_windows instead runs
#   cmd /c "<this dir>\inject-index.cmd"
# where `cmd` is a no-space token that resolves cleanly; the launcher then finds
# Git Bash and runs hook.sh, which dispatches by host. Claude Code and
# macOS/Linux read the plain `command` (bash hook.sh) and never see
# command_windows. JSON cannot hold comments, so this note lives here; the
# matching detail is in inject-index.cmd.

set -u

# 1. Resolve the active brain and build the context text via the shared builder
#    (brain-context.sh - the single source of truth for the text both hosts
#    inject). No registry / no active brain / missing brain dir -> the builder
#    exits non-zero with no output, and this is the one silent no-op.
script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"
framed="$("$script_dir/brain-context.sh")" || exit 0

# 2. JSON-escape the framed text. Order matters: backslash first (so the escapes
#    added below are not themselves re-escaped), then quote, then CR/TAB/newline.
#    The content is controlled markdown, so this finite set fully covers it.
esc="$framed"
esc="${esc//\\/\\\\}"
esc="${esc//\"/\\\"}"
esc="${esc//$'\r'/}"
esc="${esc//$'\t'/\\t}"
esc="${esc//$'\n'/\\n}"

# 3. Emit the SessionStart additionalContext payload.
printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":"%s"}}\n' "$esc"
