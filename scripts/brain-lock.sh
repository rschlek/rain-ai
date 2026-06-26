#!/usr/bin/env bash
# brain-lock.sh - one OS-flat local mutex for brrain write operations.
#
# WHY THIS EXISTS. Rainier runs ~6 Claude tabs against ONE local brain repo at
# once. remember/refine/audit each read-modify-write shared files (inbox.md, the
# canonical pages) and run git in that one repo. Without serialization two tabs
# can both read "4 pending" and both append (breaking the hard cap of 5), or
# collide on .git/index.lock, or clobber refine's whole-file watermark rewrite.
# This mutex serializes the small critical sections that need it. Scope is ONE
# device: cross-device push races are explicitly out of scope.
#
# WHY mkdir, NOT flock. Portability is the decider. macOS ships no `flock`
# binary at all and Git Bash's is flaky; `mkdir` is atomic create-or-fail and
# behaves identically on Windows (Git Bash), macOS, and Linux. The lock IS the
# directory: `mkdir LOCKDIR` (no -p) succeeds for exactly one racer and fails for
# the rest - that failure is the contention signal.
#
# WHY OUTSIDE the repo. The lock lives under $HOME/.brrain/locks/<key>/, never
# in the brain repo, so it can never be accidentally `git add`ed or pushed. $HOME
# resolves on all three OSes.
#
# STALENESS - TTL ONLY. The critical sections are seconds long, so a lock older
# than the TTL (~120s) is a crashed/killed tab, not a slow one. TTL (epoch-second
# compare via `date +%s`, portable on GNU and BSD) is the SOLE staleness signal.
# We deliberately do NOT use `kill -0 <pid>`: in this CLI model the process that
# runs `acquire` EXITS as soon as it prints the nonce (the lock is then held
# "logically" by the subagent across separate, stateless Bash-tool calls, with no
# live process behind it). So the recorded pid is dead the instant it is written -
# a pid-liveness check would intermittently break a perfectly live lock (and pid
# reuse makes it worse). The recorded pid/host/tab are kept ONLY as debugging
# breadcrumbs in the info file; they never drive a break decision. Worst case: a
# tab that crashes mid-section leaves the lock until the TTL expires (~120s), then
# a waiter breaks it. That bounded wait is the accepted cost of an OS-flat,
# process-independent lock.
#
# INVOCATION (subcommand CLI, not a sourced library - each Bash tool call is a
# fresh shell, so sourced functions would not survive between acquire and a later
# release):
#   nonce=$(bash brain-lock.sh acquire <brain-repo-path>)   # exit 0 = held; prints an ownership nonce
#   ... do the short critical section ...
#   bash brain-lock.sh release <brain-repo-path> "$nonce"   # nonce optional but recommended
# On contention-timeout, acquire exits non-zero and prints a loud message to
# stderr (fail loud, never hang the tab). release is safe without the nonce
# (unconditional remove); with the nonce it refuses to remove a lock that a TTL
# break already handed to someone else.
#
# All numbers below (TTL, timeout, backoff) are post-ship-tunable knobs.

set -u

TTL_SECONDS=120          # a lock older than this is stale (crashed holder)
ACQUIRE_TIMEOUT=30       # give up acquiring after this many seconds, then fail loud
BACKOFF_START_MS=50      # first retry wait
BACKOFF_MAX_MS=1000      # backoff caps here

# --- helpers ---------------------------------------------------------------

die() { printf 'brain-lock: %s\n' "$*" >&2; exit 1; }

# Canonicalize a brain repo path to ONE stable lock key by PURE STRING
# normalization - deterministic and filesystem-independent. (We deliberately do
# NOT `cd`+`pwd`: in Git Bash that resolves the Windows Temp dir through its /tmp
# mount alias, so the same physical dir can yield two different keys depending on
# how it was entered.) All realistic spellings of one repo collapse to one key:
#   C:/Users/rschleke/brain   (registry form, forward slashes)
#   C:\Users\rschleke\brain   (backslashes)
#   /c/Users/rschleke/brain   (Git Bash drive form)
# all -> key "c_Users_rschleke_brain". mac/linux paths (/Users/..., /home/...)
# have no drive and pass through unchanged. In practice remember/refine/audit all
# read the brain path from the SAME registry `active` field, so they pass an
# identical string regardless; this normalization is the belt-and-suspenders.
lock_dir_for() {
  local p="$1"
  p="${p//\\//}"                       # backslashes -> forward slashes
  while [ "${p%/}" != "$p" ]; do p="${p%/}"; done   # strip trailing slash(es)
  # Git Bash drive form /c/rest -> c:/rest (so it unifies with the C:/ form)
  if [[ "$p" =~ ^/([a-zA-Z])(/.*)?$ ]]; then
    p="${BASH_REMATCH[1]}:${BASH_REMATCH[2]}"
  fi
  # lowercase a leading drive letter (C: and c: are the same volume)
  if [[ "$p" =~ ^([a-zA-Z]):(.*)$ ]]; then
    local d; d="$(printf '%s' "${BASH_REMATCH[1]}" | tr 'A-Z' 'a-z')"
    p="${d}${BASH_REMATCH[2]}"         # drop the colon: c/Users/...
  fi
  local key="${p#/}"                   # mac/linux: strip the leading slash
  key="${key//\//_}"; key="${key//:/_}"; key="${key// /_}"
  printf '%s/.brrain/locks/%s' "$HOME" "$key"
}

# Read one key=value field from a lock's info file; empty if absent/unreadable.
info_field() {
  local lockdir="$1" field="$2"
  [ -f "$lockdir/info" ] || return 0
  sed -n "s/^${field}=//p" "$lockdir/info" 2>/dev/null | head -n1
}

now_epoch() { date +%s; }

# --- acquire ---------------------------------------------------------------

acquire() {
  local brain="$1"
  local lockdir; lockdir="$(lock_dir_for "$brain")"
  mkdir -p "$(dirname "$lockdir")" 2>/dev/null || die "cannot create lock root under $HOME/.brrain/locks"

  local start; start="$(now_epoch)"
  local nonce="$(now_epoch)-$$-${RANDOM:-0}${RANDOM:-0}"
  local ms="$BACKOFF_START_MS"
  local first_seen_infoless=""

  while :; do
    # The atomic acquire: plain mkdir (NO -p) succeeds for exactly one racer.
    if mkdir "$lockdir" 2>/dev/null; then
      {
        printf 'pid=%s\n' "$$"
        printf 'ts=%s\n' "$(now_epoch)"
        printf 'nonce=%s\n' "$nonce"
        printf 'host=%s\n' "${HOSTNAME:-$(hostname 2>/dev/null)}"
        printf 'tab=%s\n' "${CLAUDE_TAB_ID:-${BRRAIN_TAB_ID:-unknown}}"
      } > "$lockdir/info" 2>/dev/null
      printf '%s\n' "$nonce"
      return 0
    fi

    # Held by someone else. Decide whether it is stale and breakable - TTL only.
    local lts lpid
    lts="$(info_field "$lockdir" ts)"
    lpid="$(info_field "$lockdir" pid)"   # breadcrumb for the timeout message only

    local breakable=""
    if [ -z "$lts" ]; then
      # Dir exists but no readable timestamp yet. Almost always the microsecond
      # window between a competitor's mkdir and its info write - so wait. Only
      # break it if it STAYS info-less past the TTL (a crash in that window).
      local n; n="$(now_epoch)"
      [ -z "$first_seen_infoless" ] && first_seen_infoless="$n"
      [ $((n - first_seen_infoless)) -ge "$TTL_SECONDS" ] && breakable=1
    else
      first_seen_infoless=""
      local age=$(( $(now_epoch) - lts ))
      [ "$age" -ge "$TTL_SECONDS" ] && breakable=1   # the only break signal: TTL exceeded
    fi

    if [ -n "$breakable" ]; then
      # Race-safe break: rename (atomic) to a per-pid grave, THEN remove. Only one
      # waiter wins the rename; losers' rename fails (source already gone), so no
      # waiter can ever delete a fresh lock a third tab just created. The winner
      # does NOT thereby own the lock - it loops and competes via mkdir again.
      local grave="${lockdir}.dead.$$.${RANDOM:-0}"
      if mv "$lockdir" "$grave" 2>/dev/null; then
        rm -rf "$grave" 2>/dev/null
        continue                                      # retry mkdir immediately
      fi
      # lost the break race; fall through to backoff and retry
    fi

    # Timed out?
    if [ $(( $(now_epoch) - start )) -ge "$ACQUIRE_TIMEOUT" ]; then
      die "could not acquire lock at $lockdir within ${ACQUIRE_TIMEOUT}s (held by pid=${lpid:-?}, age=$( [ -n "$lts" ] && echo $(( $(now_epoch) - lts ))s || echo unknown )). Another brrain op may be stuck; if so remove that directory by hand."
    fi

    # Exponential backoff (ms), capped.
    sleep "$(awk "BEGIN{printf \"%.3f\", $ms/1000}")"
    ms=$((ms * 2)); [ "$ms" -gt "$BACKOFF_MAX_MS" ] && ms="$BACKOFF_MAX_MS"
  done
}

# --- release ---------------------------------------------------------------

release() {
  local brain="$1" nonce="${2:-}"
  local lockdir; lockdir="$(lock_dir_for "$brain")"
  [ -d "$lockdir" ] || return 0                       # already gone - nothing to do

  if [ -n "$nonce" ]; then
    local held; held="$(info_field "$lockdir" nonce)"
    if [ -n "$held" ] && [ "$held" != "$nonce" ]; then
      # A TTL break already reassigned this lock to another holder. Removing it
      # now would delete THEIR lock. Leave it; this is the rare crashed/hung case.
      printf 'brain-lock: not releasing %s - lock was reclaimed by another holder (TTL break)\n' "$lockdir" >&2
      return 0
    fi
  fi
  rm -rf "$lockdir" 2>/dev/null
  return 0
}

# --- dispatch --------------------------------------------------------------

cmd="${1:-}"; shift || true
case "$cmd" in
  acquire) [ $# -ge 1 ] || die "usage: brain-lock.sh acquire <brain-repo-path>"; acquire "$1" ;;
  release) [ $# -ge 1 ] || die "usage: brain-lock.sh release <brain-repo-path> [nonce]"; release "$1" "${2:-}" ;;
  *) die "usage: brain-lock.sh {acquire <path> | release <path> [nonce]}" ;;
esac
