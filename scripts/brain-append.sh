#!/usr/bin/env bash
# brain-append.sh - append one inbox pointer block with a true OS-level append.
#
# WHY THIS EXISTS (the clobber fix, failure class 1). The inbox pointer must be
# tacked onto the END of inbox.md by the OS, NOT written by the model's Edit/Write
# tool. A model-driven rewrite can drop or reorder existing pointers (it happened:
# the lightest write subagent clobbered the pending tail, 2026-06-23 and
# 2026-06-25). A shell `>>` physically appends bytes at EOF, so by construction it
# cannot touch a single existing byte above it. As a bonus, concurrent O_APPEND
# writes are atomic per write at the OS level, so two tabs appending at once
# cannot interleave-garble each other either.
#
# SCOPE. This is ONLY the safe-write primitive. It does NOT take the lock - the
# caller (remember) holds brain-lock around the append-plus-commit critical
# section. This helper just guarantees the append itself is byte-safe and
# newline-clean. (Capture is unbounded; there is no pending cap to count.)
#
# USAGE - pointer block is read from stdin (multi-line, no quoting headaches):
#   printf '## [2026-06-25] tag (Me) raw/exhaust/foo.md\nthe one-line gist\n' \
#     | bash brain-append.sh /path/to/brain/inbox.md
# A leading newline is always emitted before the block so the new `## ` header can
# never glue onto a previous line that lacked a trailing newline - the watermark
# and pointers stay greppable as line-anchored `^## ` headers. An explicit \n
# terminates the block, avoiding Windows CRLF creep.

set -u

inbox="${1:-}"
[ -n "$inbox" ] || { printf 'brain-append: usage: brain-append.sh <inbox-path>  (block on stdin)\n' >&2; exit 1; }
[ -f "$inbox" ] || { printf 'brain-append: inbox not found: %s\n' "$inbox" >&2; exit 1; }

block="$(cat)"
[ -n "$block" ] || { printf 'brain-append: empty pointer block on stdin - nothing appended\n' >&2; exit 1; }

# The append. Leading \n guarantees a line boundary regardless of how the file
# currently ends; trailing \n keeps the next append clean.
printf '\n%s\n' "$block" >> "$inbox" || { printf 'brain-append: append failed: %s\n' "$inbox" >&2; exit 1; }
