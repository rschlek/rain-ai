#!/usr/bin/env bash
# Shared brain-context builder for the brrain SessionStart hook.
#
# Resolves the active brain from the engine registry and prints the brain
# context TEXT to stdout - the single source of truth for what both host paths
# inject:
#   - inject-index.sh  (Claude Code) JSON-escapes this into additionalContext.
#   - inject-agents-md.sh (Codex) writes it into a delimited ~/.codex/AGENTS.md
#     block, which Codex loads into the model context silently.
#
# The text is the same two-reflex preamble the plugin has always built:
#   - WRITE (always, whenever a brain exists on this device): the capture nudge.
#   - READ  (only once refine has produced a non-empty index.md): the canonical
#     index, so the agent can see which pages exist and reach for recall.
#
# CONTRACT for callers:
#   - exit 0, text on stdout (trailing newline): an active brain exists.
#   - exit 1, NOTHING on stdout: no registry / no active brain / brain dir
#     missing. Callers branch on this - Claude stays a silent no-op; Codex
#     removes its AGENTS.md block.
#
# The active brain is resolved REGISTRY-DIRECT from ~/.brrain/registry.json
# ("active" field); no environment variable is consulted. HOME is resolved
# robustly because a hook may be spawned with a stripped environment (Codex runs
# SessionStart hooks without HOME/USERPROFILE): prefer `~` (expanded via the OS
# user database, env-independent), then the usual vars, each defaulted so
# `set -u` is satisfied.

set -u

home="${HOME:-}"
[ -n "$home" ] || home=~
[ -n "$home" ] || home="${USERPROFILE:-}"
registry="$home/.brrain/registry.json"
[ -f "$registry" ] || exit 1

brain=$(sed -n 's/.*"active"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$registry" | head -n 1)
[ -n "$brain" ] || exit 1

# Normalize JSON-escaped Windows paths so POSIX file tests work under Git Bash:
# "C:\\Users\\me\\brain" -> "C:/Users/me/brain". Any stray single backslash too.
brain="${brain//\\\\//}"
brain="${brain//\\//}"
[ -d "$brain" ] || exit 1

# The WRITE reflex - always primed when a brain exists (index or not). The
# heredoc is quoted ('EOF') so nothing here is shell-expanded.
framed=$(cat <<'EOF'
# The user's second brain (brrain)

The user keeps a durable, git-backed second brain (brrain). It has two reflexes
you help run - one to write, one to read.

**Write at wrap-up (the capture nudge).** At a natural stopping point - when the
user signals the session is done, or the work that mattered is finished - judge
whether this session produced something durable that lives nowhere else
queryable: a real decision and *why* it was made, a strategic reframe, an open
question worth tracking, or a hard-won finding. If it did, offer ONCE to capture
it: name the thing in a single line and ask whether they want it remembered (the
remember skill). Default to silence - routine lookups, mechanical edits,
status checks, and anything already recorded in a repo / calendar / task list
get no offer. Most sessions are routine, so silence is the common case; but when
the durable signal is genuinely real, offer with confidence - that is what keeps
the deliberate-capture habit alive. The durable-vs-routine judgment gates the
OFFER, not the capture: offer at most once per session, never re-offer once they
have captured this session, and a misjudged offer costs only a "no thanks" (it
never reaches canonical knowledge). On yes, invoke the remember skill normally,
with normal provenance and no special tier - it parks the note and flows through
the refine trust gate like any other manual capture.
EOF
)

# The READ reflex - appended only once refine has produced a non-empty index.
index="$brain/index.md"
if [ -f "$index" ]; then
  body=$(cat "$index")
  if [ -n "$body" ]; then
    read_block=$(cat <<EOF


**Read on demand.** The lines below are the canonical wiki pages of the brain,
one page per line with its gloss. To read any page in depth, or to also search
the unrefined capture tail, invoke the recall skill (read-only and
low-risk - reach for it whenever brain context would help answer the user
better, even unprompted).

$body
EOF
)
    framed="$framed$read_block"
  fi
fi

# Emit. Callers capture via $(...), which strips the trailing newline, so the
# captured value equals $framed exactly.
printf '%s\n' "$framed"
