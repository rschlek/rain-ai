#!/usr/bin/env bash
# AGENTS.md migration cleanup for the brrain plugin (Codex path).
#
# HISTORY. Until Codex 0.145, hook additionalContext was rendered into the
# VISIBLE transcript (openai/codex#16933), so brrain maintained its session
# context as a delimited block at the bottom of ~/.codex/AGENTS.md instead.
# Codex 0.145 injects additionalContext silently (verified 2026-08-05: hook
# fires on exec and resume, model sees the context, transcript shows only a
# one-line "hook: SessionStart" marker), hooks are enabled by default, and
# SessionStart fires on startup/resume/clear/compact. So the Codex path now
# injects per-session via the hook exactly like the default host, and NOTHING
# brrain-owned lives in AGENTS.md anymore - the user's AGENTS.md budget is
# entirely their own.
#
# THIS SCRIPT is the one-time migration: it REMOVES any legacy brrain block
# from ~/.codex/AGENTS.md. The Codex hook branch runs it before injecting, so
# a device that upgrades the plugin self-cleans on its next trusted session.
# It never writes a block.
#
# SAFETY: only a block with BOTH markers is stripped. A start marker with no
# end marker means a hand-edit or interrupted write; the sed range would
# delete from the start marker to END OF FILE and eat user content - so in
# that case the file is left entirely untouched. A device with no Codex dir
# is a silent no-op. Every path exits 0 (a hook must never break startup).

set -u

home="${HOME:-}"
[ -n "$home" ] || home=~
[ -n "$home" ] || home="${USERPROFILE:-}"

codex_home="${CODEX_HOME:-$home/.codex}"
agents="$codex_home/AGENTS.md"

[ -f "$agents" ] || exit 0

existing="$(cat "$agents")"

printf '%s' "$existing" | grep -q 'brrain:start' || exit 0

# Unbalanced markers -> do not touch the file (see SAFETY above).
printf '%s' "$existing" | grep -q 'brrain:end' || exit 0

preserved="$(printf '%s\n' "$existing" | sed '/brrain:start/,/brrain:end/d')"

if [ -n "$preserved" ]; then
  printf '%s\n' "$preserved" > "$agents"
else
  : > "$agents"
fi

exit 0
