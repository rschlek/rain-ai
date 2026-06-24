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
staging, so capture cannot corrupt knowledge. The brain's own `RULEBOOK.md` (in the active brain's
repo) is the authoritative rulebook - read its capture sections (the
three tiers, the raw-doc conventions, the pointer schema, brain-worthy criteria, the deny-list)
and follow them so this skill never drifts. **Zero exceptions:** every capture parks a raw doc + a
pointer, even a one-line dictated fact.

1. **Precondition.** Read the active brain's path from the engine registry at
   `~/.brrain/registry.json` (its `active` field). If the registry is missing or has no active
   brain, **stop** and tell the user to run `brrain:setup` - do not guess a path. Read the brain's
   `RULEBOOK.md` for the conventions below.

2. **Deny-list gate.** If the content is about **medical, therapy, or health**, do **not** park it
   without an explicit in-the-moment override from the user ("yes, store it anyway"). If they want it
   referenced but not vendored, use cite-by-pointer (step 5). Everything else parks freely.

3. **Decide the source kind** - this is the only branching, and it just picks which raw doc gets
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

4. **Apply the brain-worthy filter.** Privilege durable judgment over re-derivable inventory:
   capture decisions, open questions, reframes, hard-won facts; skip what a repo / calendar / task
   list already records. For a summary or a mine this is your selection criterion; for a borderline
   tidbit, park only the judgment ("we chose X over Y because Z"), not the inventory.

5. **Compose the raw doc + the pointer.**
   - Compose the raw-doc body where the content already is. For the **exhaust-mine** kind, run the
     mining + drafting in a **subagent**. This is heavy reading over git/tasks plus distillation -
     **judgment-class** work a capable mid-tier model handles well; **by default inherit the session
     model** (express the tier as intent, name no specific model - cost-optimizing to a fixed tier
     is a later concern). The same subagent can carry through the write in step 7. For the other
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

6. **Supersession.** If this changes a fact captured before, it is a **new** raw doc + **new**
   pointer, never an edit to the old ones. The dates carry the history; `refine` reconciles the
   canonical page later.

7. **Write it in a subagent** (keep this session's context clean). Pass it the composed raw-doc
   body, the raw-doc path, the pointer block, and the active brain's path. This step is pure file
   I/O + git with **zero judgment** - the lightest available tier fits, the clearest cheap-tier case
   in the brain; **by default inherit the session model** (express the tier as intent, name no
   specific model). (Exception: on the exhaust-mine path the step-5 subagent already carries through
   this write - do not spin a second one.) The subagent must:
   1. `cd` into the active brain's path; if the brain has an upstream remote, `git pull --ff-only`
      first (a
      local-only brain has none, so skip the pull).
   2. Write the raw doc at its path, creating `raw/<sub>/` if needed. **Never overwrite** an
      existing raw doc - if the path collides, disambiguate the slug.
   3. Append the pointer block at the **bottom** of `inbox.md` (append-only; never reorder/rewrite).
   4. Count **pending** pointers below the `<!-- synthesized through: ... -->` watermark: **N** =
      all `##`-headed entries (includes the one just added); **M** = those of the N **not** tagged
      `substance:low` (manual captures are unflagged, so they count as substantive).
   5. `git add` the new raw doc + `inbox.md`, commit with a short readable summary, then `git push`
      if the brain has an upstream remote (a local-only brain just keeps the commit local).
   6. Return one line: `logged -> <tag or "inbox"> (<N> pending, <M> substantive)`.

8. **Report.** Surface the subagent's one-line confirmation and nothing more.

## Notes

- **The wrap-up nudge is this skill's front door.** Capture is manual-but-nudged: the brrain
  SessionStart preamble (`inject-index.sh`) tells the agent to *offer* `remember` at a natural
  wrap-up when a session produced something durable (a decision + why, a reframe, an open question, a
  hard-won finding). On yes it runs this skill normally - normal provenance, no special tier, no
  `auto-session`/`substance` flag. The durable judgment gates the **offer**, not the capture; see the
  brain `RULEBOOK.md` "The wrap-up capture nudge" section for the doctrine.
- One capture = one raw doc + one pointer + one commit. No fan-out.
- The backpressure count (`N pending, M substantive`) nudges that the inbox is filling and a
  `refine` pass is due - M shows how much of it is worth opening. It is not an error.
- The only thinking the parent does is selecting/synthesizing the brain-worthy content (the chat
  summary needs the conversation; the exhaust mine needs heavy reading). Everything else is just
  parking the source faithfully and linking to it.
