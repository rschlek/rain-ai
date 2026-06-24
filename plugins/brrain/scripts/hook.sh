#!/usr/bin/env bash
# SessionStart hook dispatcher for the brrain plugin.
#
# Both hosts inject the same brain context (built by brain-context.sh) but by
# different mechanisms, so this routes to the host-appropriate implementation:
#   - Codex  -> inject-agents-md.sh : maintains the context silently in
#               ~/.codex/AGENTS.md, because Codex renders additionalContext into
#               the VISIBLE transcript (openai/codex#16933).
#   - Claude -> inject-index.sh     : emits hookSpecificOutput.additionalContext
#               JSON, which Claude Code injects silently.
#
# Host detection: Codex sets a bare PLUGIN_ROOT env var in the hook process;
# Claude Code sets only CLAUDE_PLUGIN_ROOT. So PLUGIN_ROOT being set means Codex.

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

if [ -n "${PLUGIN_ROOT:-}" ]; then
  exec bash "$script_dir/inject-agents-md.sh"
else
  exec bash "$script_dir/inject-index.sh"
fi
