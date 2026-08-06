#!/usr/bin/env bash
# SessionStart hook dispatcher for the brrain plugin.
#
# Both hosts now inject the SAME brain context the SAME way: inject-index.sh
# emits hookSpecificOutput.additionalContext JSON, which each host loads into
# the model context silently. (Codex gained silent additionalContext injection
# in 0.145 - verified 2026-08-05; before that, openai/codex#16933 forced an
# AGENTS.md workaround on Codex.)
#
# The only Codex-specific step left is the one-time MIGRATION: strip the
# legacy brrain block from ~/.codex/AGENTS.md (inject-agents-md.sh, now
# removal-only) before injecting, so upgraded devices never carry double
# context.
#
# Host detection: Codex sets a bare PLUGIN_ROOT env var in the hook process;
# Claude Code sets only CLAUDE_PLUGIN_ROOT. So PLUGIN_ROOT being set means Codex.

set -u

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" && pwd)"

if [ -n "${PLUGIN_ROOT:-}" ]; then
  bash "$script_dir/inject-agents-md.sh"   # legacy AGENTS.md block cleanup (no-op once clean)
fi

exec bash "$script_dir/inject-index.sh"
