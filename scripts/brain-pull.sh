#!/usr/bin/env bash
# brain-pull.sh - the freshness pull, with the only failure that matters handled.
#
# WHY THIS EXISTS. Every write op (remember/refine/audit) does a `git pull
# --ff-only` for freshness before it writes. The naive form swallows failures:
# if the pull errors, the op proceeds to write/commit/push anyway, on a possibly
# stale base. But a `--ff-only` pull failure is only DANGEROUS when we are
# actually behind the remote (writing then would diverge or fail the push). A
# transient git hiccup while we are already up-to-date is harmless. This helper
# encodes exactly that distinction, in one audited place, so all three skills
# behave identically:
#   - no upstream remote (local-only brain)        -> nothing to do, succeed
#   - pull succeeds                                 -> succeed
#   - pull fails BUT we are not behind the remote   -> transient; succeed (proceed)
#   - pull fails AND we are behind the remote       -> FAIL LOUD (exit non-zero):
#       the caller must NOT write on a stale base; surface it and stop (releasing
#       any held lock first).
#
# USAGE (run from inside the brain repo, or pass its path):
#   bash brain-pull.sh <brain-repo-path>
# Exit 0 = safe to proceed with the write. Non-zero = stop, we are behind and the
# pull could not fast-forward.

set -u

brain="${1:-.}"
cd "$brain" 2>/dev/null || { printf 'brain-pull: cannot cd into %s\n' "$brain" >&2; exit 1; }

# No upstream tracking ref => local-only brain. Nothing to pull; succeed.
if ! git rev-parse --abbrev-ref --symbolic-full-name '@{u}' >/dev/null 2>&1; then
  exit 0
fi

# The freshness pull. If it fast-forwards (or is already up-to-date), done.
if git pull --ff-only >/dev/null 2>&1; then
  exit 0
fi

# Pull failed. The failure only matters if we are actually behind the remote.
# Refresh remote-tracking refs, then compare. (A bare `git fetch` failure here -
# offline, say - leaves the counts based on what we last knew; if that shows we
# are not behind, proceeding is still safe.)
git fetch >/dev/null 2>&1
behind="$(git rev-list --count 'HEAD..@{u}' 2>/dev/null || echo 0)"

if [ "${behind:-0}" -gt 0 ]; then
  printf 'brain-pull: behind upstream by %s commit(s) and --ff-only could not advance; refusing to write on a stale base. Resolve the pull (e.g. git pull --ff-only) by hand, then retry.\n' "$behind" >&2
  exit 1
fi

# Pull errored but we are not behind - a transient hiccup. Safe to proceed.
exit 0
