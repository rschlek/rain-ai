---
name: remember
description: >-
  Capture a note into the user's second brain (brrain) with the park-and-link model:
  write one immutable source doc to raw/ and append one provenance-tagged pointer to inbox.md,
  commit both, push when the brain has a remote, and return a one-line confirmation. Routes by
  source kind - a dictated fact, a "key things from this chat" summary, a scoped mine of past work
  (git history / completed tasks), or a document (stored verbatim or cited by pointer). Use when the
  user says "remember that", "log this", "add to my brain", "capture this", "log what we did",
  "remember the work I did on X", or "note this for the brain". Do not use for actionable tasks or
  to-dos (those belong in your task manager), for the host agent's own working-memory file, or to
  synthesize the brain into wiki pages (that is brrain:refine). Requires an active brain in the registry;
  if none, point the user to brrain:setup.
---

## Procedure

Capture is **park-and-link** and deliberately dumb: write **one** immutable source doc to `raw/`
and append **one** pointer to `inbox.md`, then commit both and push when the brain has a remote. It
does no extraction, linking, or dedup - that is `refine`'s job, behind the user's review. The inbox
is untrusted
staging, so capture cannot corrupt knowledge. Capture is **unbounded** - there is **no cap**; every
capture always lands and none is ever refused (the old hard 5-cap is **dropped**, now that `refine` is
incremental and a large pending pile is no longer expensive). Backpressure toward synthesis is a
**soft periodic-review nudge at wrap-up**, never a block. The append-plus-commit still runs behind a
**local mutex** so concurrent writes across the user's several open tabs (all writing the one local
repo) stay serialized - it protects inbox integrity and refine's watermark rewrite, not any count; the
helpers in `scripts/` carry that machinery. The brain's own `RULEBOOK.md` (in the active brain's
repo) is the authoritative rulebook - read its capture sections (the
three tiers, the raw-doc conventions, the pointer schema, brain-worthy criteria)
and follow them so this skill never drifts. **Zero exceptions:** every capture parks a raw doc + a
pointer, even a one-line dictated fact.

1. **Precondition.** Read the active brain's path from the engine registry at
   `~/.brrain/registry.json` (its `active` field). If the registry is missing or has no active
   brain, **stop** and tell the user to run `brrain:setup` - do not guess a path. Read the brain's
   `RULEBOOK.md` for the conventions below.

2. **Decide the source kind** - this is the only branching, and it just picks which raw doc gets
   written:
   - **Dictated fact** - the user stated a specific fact. Provenance `Me`. -> a tiny doc in
     `raw/exhaust/`.
   - **This-chat summary** - "log what we did" / "key things from this chat". You synthesize the
     brain-worthy points from the conversation. Provenance `Agent`. -> a doc in `raw/sessions/`.
   - **Scoped exhaust mine** - "remember the work I did on X". Mine git history, completed tasks,
     and prior captures for that scope and distill a digest. Provenance `Agent`. -> a doc in
     `raw/exhaust/`.
   - **Document** - a PDF or source doc. Provenance `Agent`. -> `raw/docs/`, **vendored verbatim**
     if small / local / durable, or **cite-by-pointer** if big, re-fetchable, or sensitive.

3. **Apply the brain-worthy filter.** Privilege durable judgment over re-derivable inventory:
   capture decisions, open questions, reframes, hard-won facts; skip what a repo / calendar / task
   list already records. For a summary or a mine this is your selection criterion; for a borderline
   tidbit, park only the judgment ("we chose X over Y because Z"), not the inventory.

4. **Compose the raw doc + the pointer.**
   - Compose the raw-doc body where the content already is. For the **exhaust-mine** kind, run the
     mining + drafting in a **subagent**. This is heavy reading over git/tasks plus distillation -
     **judgment-class** work a capable mid-tier model handles well; **by default inherit the session
     model** (express the tier as intent, name no specific model - cost-optimizing to a fixed tier
     is a later concern). The same subagent can carry through the write in step 6. For the other
     kinds the material is already in this session, so compose it here.
   - For **cite-by-pointer**, the raw doc is a stub: source location + capture date + a content hash
     when you have the bytes (e.g. sha256 of a local file); otherwise record source + date and mark
     "not vendored".
   - Pick an optional **project tag** (lowercase-kebab) and set **provenance** per the kind above.
   - Name the raw doc: `raw/sessions/YYYY-MM-DD-<slug>.md`, `raw/docs/<slug>.md`, or
     `raw/exhaust/YYYY-MM-DD-<slug>.md` (today's date).
   - Compose the pointer block:
     ```
     ## [YYYY-MM-DD] <optional tag> (<Me|Agent>) raw/<sub>/<doc>.md
     <one-line gist>
     ```

5. **Supersession.** If this changes a fact captured before, it is a **new** raw doc + **new**
   pointer, never an edit to the old ones. The dates carry the history; `refine` reconciles the
   canonical page later.

6. **Write it in a subagent, behind the lock** (keep this session's context clean). Pass the
   subagent: the composed raw-doc body, the raw-doc path, the pointer block, the active brain's
   path, **and the absolute paths to the three shared helpers** - resolve `brain-lock.sh`,
   `brain-append.sh`, and `brain-pull.sh` from `${CLAUDE_PLUGIN_ROOT}/scripts/` and pass them in, so
   the subagent needs no plugin env of its own. This step is file I/O + git with **zero judgment** - the lightest
   available tier fits; **by default inherit the session model** (express the tier as intent, name
   no specific model). (Exception: on the exhaust-mine path the step-4 subagent already carries
   through this write - do not spin a second one.)

   The **append-plus-commit is a locked critical section** - it must be serialized against the other
   open tabs, which all write the same one local repo (there is **no count and no cap** - a capture is
   never refused). Everything between acquire and release must stay fast file I/O + git - **never**
   model judgment or a user turn. The subagent must:
   1. **Acquire the lock.** Run `bash <brain-lock.sh> acquire <brain-path>` and capture its stdout
      as the **nonce**. A non-zero exit means it already failed loud (another brrain op is mid-write
      or a stale lock could not be broken) - surface that message and stop, writing nothing. **If
      any later step in this section fails, release the lock before stopping** (otherwise it sits
      until the ~120s TTL).
   2. **Freshness pull.** Run `bash <brain-pull.sh> <brain-path>` (the `git pull --ff-only`, a no-op
      for a local-only brain). A **non-zero exit means the brain is behind the remote and could not
      fast-forward** - do **not** write on a stale base: **release the lock**, surface the helper's
      message so the user can resolve the pull by hand, and stop. (A transient pull hiccup while
      already up-to-date exits 0, so it never needlessly blocks a capture.)
   3. **Write the raw doc** at its path, creating `raw/<sub>/` if needed. **Never overwrite** an
      existing raw doc - if the path collides, disambiguate the slug.
   4. **Append the pointer with the helper, never a tool edit.** Pipe the pointer block into
      `bash <brain-append.sh> "<brain>/inbox.md"` (e.g. `printf '%s\n' "<block>" | bash
      <brain-append.sh> ...`). The helper does a real OS-level `>>` below the watermark, which by
      construction cannot rewrite or drop existing pointers - that is the clobber fix. Do **not**
      touch `inbox.md` with Edit/Write. The watermark is positional: the append lands below it even
      when it is the last line of the file; never treat the watermark as a trailing footer.
   5. `git add` **only** the new raw doc + `inbox.md` (path-scoped, so it never sweeps up another
      op's uncommitted drafts), commit with a short readable summary, then `git push` if the brain
      has an upstream remote (a local-only brain just keeps the commit local).
   6. **Release the lock** (`bash <brain-lock.sh> release <brain-path> "<nonce>"`).
   7. **Optionally count pending pointers** below the `<!-- synthesized through: ... -->` watermark
      (a cold brain before the first refine has no watermark - the whole file is pending) for the
      informational report, then return a **`LANDED`** result:
      `logged -> <tag or "inbox"> (<N> pending)`.

7. **Report.** Surface the one-line `LANDED` confirmation. The `(N pending)` count is
   **informational only** - a capture is **never blocked**. Do not prod per-capture; keeping the
   canonical layer current is the **wrap-up periodic-review nudge's** job (a soft *"N pending, oldest
   D days - refine?"* raised at a natural stopping point when the tail looks deep or stale), not a
   per-write gate. See the brain `RULEBOOK.md` "Backpressure toward refine (the periodic-review nudge)".

## Notes

- **The capture nudge is this skill's front door.** Capture is manual-but-nudged: the brrain
  SessionStart preamble (`inject-index.sh`) tells the agent to *offer* `remember` when a session
  produces something durable (a decision + why, a reframe, an open question, a hard-won finding),
  firing at the **first of two moments - the durable moment (mid-session) or a natural wrap-up
  (backstop)**, so an abrupt or device-switched ending does not lose the capture. On yes it runs this
  skill normally - normal provenance, no special tier, no `auto-session`/`substance` flag. The durable
  judgment gates the **offer**, not the capture; see the brain `RULEBOOK.md` "The capture nudge
  (durable-moment + wrap-up)" section for the doctrine.
- One capture = one raw doc + one pointer + one commit. No fan-out.
- **No cap - capture is unbounded.** The `(N pending)` count on a landed capture is informational
  only; it never blocks. Backpressure toward `refine` is the soft **wrap-up periodic-review nudge**
  (depth/age of the pending tail), which nags toward synthesis without ever refusing a capture. It
  replaced the old hard 5-cap, now that incremental refine makes a large pending pile cheap.
- **The append is an OS-level `>>` via `scripts/brain-append.sh`, never an Edit/Write** - that is the
  clobber fix: a real append physically cannot rewrite or drop the existing pending pointers. The
  append-plus-commit is serialized by `scripts/brain-lock.sh` (a portable `mkdir` mutex outside the
  repo) so concurrent tabs cannot interleave a commit or race `refine`'s whole-file watermark rewrite.
- The only thinking the parent does is selecting/synthesizing the brain-worthy content (the chat
  summary needs the conversation; the exhaust mine needs heavy reading). Everything else is just
  parking the source faithfully and linking to it.
