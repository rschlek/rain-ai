#!/usr/bin/env bash
# SessionStart hook for the brrain plugin - the CODEX path (all OS).
#
# Why this exists instead of additionalContext: Codex renders any hook
# hookSpecificOutput.additionalContext into the VISIBLE transcript
# unconditionally (suppressOutput is parsed-but-discarded for SessionStart, and
# no config flag hides it - upstream bug openai/codex#16933, open). So the
# Claude additionalContext path would dump the whole ~7.7 KB index on screen
# every session. Codex DOES, however, load ~/.codex/AGENTS.md into the model
# context SILENTLY (not echoed to the transcript). So on Codex we maintain the
# brain context there: this hook prints NOTHING (no visible hook cell) and
# rewrites an idempotent delimited block at the BOTTOM of AGENTS.md, preserving
# all existing content above it.
#
# The block text is built by the shared brain-context.sh (the single source of
# truth both hosts inject). If there is no active brain, the block is removed.
#
# Codex home is resolved via CODEX_HOME if set, else ~/.codex. The file is
# written UTF-8 with NO BOM (a BOM trips Codex's strict parser - "expected value
# at line 1 column 1"); bash redirection writes raw bytes, so no BOM is added.
#
# A SessionStart hook must never break startup, so every path exits 0.

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

# Resolve HOME robustly (a hook may be spawned with a stripped environment):
# prefer `~` (expanded via the OS user database, env-independent), then vars.
home="${HOME:-}"
[ -n "$home" ] || home=~
[ -n "$home" ] || home="${USERPROFILE:-}"

codex_home="${CODEX_HOME:-$home/.codex}"
agents="$codex_home/AGENTS.md"

start_marker='<!-- brrain:start -->'
end_marker='<!-- brrain:end -->'

# Build the brain-context text. Exit non-zero from the builder means no active
# brain -> context stays empty and we simply strip any existing block.
context="$("$script_dir/brain-context.sh")" || context=""

# Nothing to do if there is no brain AND no file to clean up.
[ -n "$context" ] || [ -f "$agents" ] || exit 0

# Read existing content (if any). $(cat) strips trailing newlines.
existing=""
[ -f "$agents" ] && existing="$(cat "$agents")"

# Strip any existing brrain block (markers inclusive) to get the content to
# preserve. The start address is matched loosely (any line containing
# "brrain:start") so an older/hand-edited marker variant is also removed.
# $(...) strips trailing newlines, so any blank lines that preceded the block
# are dropped here too - we re-add exactly one blank-line separator below.
preserved="$(printf '%s\n' "$existing" | sed '/brrain:start/,/brrain:end/d')"

# Codex dir may not exist yet on a fresh install.
mkdir -p "$codex_home"

if [ -n "$context" ]; then
  {
    if [ -n "$preserved" ]; then
      printf '%s\n\n' "$preserved"
    fi
    printf '%s\n%s\n%s\n' "$start_marker" "$context" "$end_marker"
  } > "$agents"
else
  # No active brain -> remove our block, keep only the preserved content.
  if [ -n "$preserved" ]; then
    printf '%s\n' "$preserved" > "$agents"
  else
    # Nothing left to keep; leave an empty file rather than a stale block.
    : > "$agents"
  fi
fi

exit 0
