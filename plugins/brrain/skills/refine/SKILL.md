---
name: refine
description: >-
  Run the refine synthesis ritual over the user's second brain (brrain): a subagent
  distills the pending inbox.md pointers and their raw/ docs into canonical wiki pages + index.md,
  then returns for the user's review and approval before anything is committed. This is the trust
  gate - nothing becomes canonical knowledge without their yes. Use when the user says "refine the
  brain", "run refine", "synthesize my brain", "process the inbox", "drain the pending notes", or
  when a remember confirmation's "(N pending, M substantive)" count has grown and they want to act on it.
  Do not use to capture a note (that is brrain:remember) or to answer a question from the
  brain (that is brrain:recall). Requires an active brain in the registry; if none, point the user to
  brrain:setup.
---

## Procedure

refine reads the pending inbox pointers (everything below the watermark), opens their immutable
`raw/` docs, and distills them into canonical wiki pages + `index.md`. It is the brain's **trust
gate**: the heavy drafting runs in a subagent with clean context, but **nothing is committed until
the user approves**. The brain's own `RULEBOOK.md` (in the active brain's repo) is the
authoritative rulebook for the conventions below (**page layering**, routing, supersession,
`index.md`/`log.md` format, provenance, the watermark) - read its **"Page layering"**, **"The refine
operation"**, **"Supersession (graded)"**, and **"`index.md`"** sections and follow them so this skill
never drifts.

1. **Precondition.** Read the active brain's path from the engine registry at
   `~/.brrain/registry.json` (its `active` field). If the registry is missing or has no active
   brain, **stop** and tell the user to run `brrain:setup` first - do not guess a path. Otherwise `cd` into
   that path; if the brain has an upstream remote, `git pull --ff-only` first (freshness; a
   local-only brain has none, so skip), then read the brain's `RULEBOOK.md`.

2. **Gather the pending tail.** Read `inbox.md`. The pending entries are the `##`-headed pointers
   **below** the `<!-- synthesized through: ... -->` watermark. Collect their raw-doc paths. If
   there are zero pending entries, tell the user the tail is empty and stop. Read the current
   `index.md` if it exists (it will not on the first refine).

3. **Draft in a subagent (clean context).** Hand the subagent: the list of pending raw-doc paths,
   the active brain's path, the current `index.md` contents, and the brain `RULEBOOK.md`.
   refine is the trust gate's heavy synthesis (routing facts, reconciling supersession, writing
   canonical prose), the one brrain op that earns the **strongest reasoning tier** - express that as
   **intent** and **by default inherit the session model** (name no specific model; whatever the
   session runs on is the top tier available). Do **not** deliberately downgrade it for cost. The
   subagent must:
   1. Open each raw doc and distill its facts.
   2. **Route** each fact per the rulebook's "earn it" rules (existing page -> append; stable
      subject -> new flat page; else a line on the most-related page, or a domain `overview`
      page). Keep one canonical home per fact; link from other subjects with `[[backlinks]]`.
      **If a distilled fact answers an existing `> needs:` marker on the page, remove that marker**
      as you add the fact - the gap is now filled. This closes the `interview` loop (interview harvests
      the marker and routes the answer back as a capture); surface every clear in the summary.
      A **subject<->peer correspondence** (any external system that tracks this subject - a task
      project, code repo, dashboard, doc, etc.) is routed into the page's **`external:` frontmatter block**, not the
      prose - per the rulebook's **"External references"** section (`{system, ref, label}`, page-level,
      read-only). Surface a new/changed `external:` entry in the summary like any other change.
      **Layer each fact onto the page by settledness** (rulebook "Page layering"): settled current
      truth -> the **head** (above the first `##`) or a settled `## section`; in-flight ideation /
      open questions -> a bounded **`## Open threads`** section at the bottom; a **rejected option** ->
      a one-line present-tense **fence** in the head ("Not pursuing X - Y is the choice"), never a
      narrative; **`> needs:` / `> contested:` markers stay inline where they bite, never in the head**.
      **Never narrate history on the page** - the journey goes to `log.md` (step 5).
   3. **Reconcile supersession** (graded, rulebook "Supersession (graded)"): a routine fact -> quiet
      overwrite (current value only); a reversal whose prior value still constrains the future ->
      current value in the head + a **single one-line `(previously X)` parenthetical**, never a
      narrative; **the journey of every change goes to the `log.md` entry, never onto the page**. Use
      backlink-by-grep only for page rename/merge/retire.
   4. Write all page changes + `index.md` updates **into the working tree**. **Commit nothing.**
   5. Return a **structured summary only** (not raw content), shaped as **self-orienting per-page
      blocks** - one block per affected page, N pages -> N blocks, never one prose wall keyed by
      category (follow the rulebook's "The gate summary" convention). Each block:
      - **leads with the page's `index.md` gloss line** as it will read **after** this pass, tagged
        **`NEW`** (page created) or **`UPDATED`**, so each change is judged against what the doc is
        about;
      - **then each change concretely**: a changed fact as **`before -> after`**, an added fact or
        a whole new page as **`NEW: <line>`** (a supersession is a before/after whose contrast
        matters; a **`> needs:` cleared** is noted as a cleared change);
      - **flags its open questions under the page**: any **gap question** (a fact the page needs,
        e.g. "John's last name?") or **`Agent`-claim to confirm** (consequential, uncorroborated
        `Agent` fact about to become canonical) for that page - flagged here, *asked* one at a time
        in the walk (step 4).

      Then a short **footer** for what is not page-scoped: `auto-session` duplicates killed, and the
      **watermark target** (the last-consumed entry's date).

4. **Review with the user (the gate) - map first, then walk.** First present the subagent's summary
   - the per-page blocks - as the **orientation map**, so the user sees the whole change-set with
   each change read against its page's gloss. Offer to show the raw `git diff` on request. Then
   **walk the open questions one at a time** (the rulebook's gate-review convention):
   - Take each open item (gap question, flagged `Agent` claim) **singly** through a
     structured-choice prompt - one as-simple-as-possible question at a time (a yes/no or a short pick), in the spirit of a
     step-by-step wizard, never one prompt that asks for everything. For an `Agent`-claim
     confirmation, make **`WIP / not-settled` a first-class option** (alongside confirm / drop) -
     flagged claims are often in-flight ideation, and `WIP` resolves to a `> needs:` marker, not a
     canonical assertion. **Every question carries a standing free-text escape** so the user can give
     an extended answer, and when an item cannot be reduced to options (a nuanced reversal, a "tell
     me the backstory" gap) **ask it directly as an open question**. Answers are **gate-time
     curation, not captures** - fold each into the drafted working-tree pages as you go; do **not**
     create raw docs or inbox pointers for them. A gap the user cannot answer, or a claim they mark
     `WIP`, stays on the page as `> needs: <what>`.
   - The user may request edits ("redraft acme-report.md to lead with the finding", "move that fact").
     Apply small edits **directly to the working-tree pages** yourself. Only re-invoke the
     subagent if a change genuinely needs the raw source again (keeps your context clean).
   - Re-present the (updated) map and loop until the gate decision. The landing decision is
     **per-batch** (one approve lands the whole pass), even though the questions were walked singly.
   - **Put the final landing decision through a structured-choice prompt, not a
     free-text "Approve?" prompt.** Landing is the irreversible trust-gate moment (drafts become canonical - committed,
     and pushed/published when the brain has a remote), so make it an explicit, structured choice -
     the same surface the flagged `Agent`-claim confirmations use. Offer options along the lines of
     **Approve and land** / **Request edits** / **Reject and discard**. On approve -> step 5; on
     edits -> apply them and re-present; on reject -> step 6. (An unprompted "approve and land it" in
     chat still counts as approval - do not force the question if they have already given a clear yes.)

5. **On approve - land it atomically.** Fold in any final gap answers, then:
   1. **Advance the watermark**: move the `<!-- synthesized through: ... -->` line in `inbox.md`
      down past every consumed entry; update its comment text to the last-consumed date. If this
      consumes every pending entry, leave a single trailing blank line after the watermark so it is
      never the literal last line of the file - that keeps the next capture's append-below-watermark
      unambiguous (a watermark left as the last line can be misread as a file-final footer, and the
      capture lands above it where the next refine never sees it).
   2. **Write the `log.md` entry** (one narrative entry per committed pass; format in the
      rulebook): entries synthesized + watermark move, pages touched (flat slugs), and the gate-time
      curation (gap answers given, `Agent` claims confirmed). **Because pages no longer narrate their
      own history, this entry is its sole on-system home: record the before -> after and the why for
      every supersession / reversal folded, and every rejected option fenced or removed** (rulebook
      "Page layering" / "Supersession").
   3. `git add` the changed pages, `index.md`, `inbox.md`, and `log.md`; **one commit** with a
      readable summary; then **`git push`** if the brain has an upstream remote (a local-only brain
      just keeps the commit local).
   4. Report a one-line confirmation: `synthesized -> <N> entries, <P> pages (watermark -> <date>)`.
   5. **Nudge `audit`** if the corpus looks due for an audit (it has grown, or `log.md` shows
      no recent `audit` pass): add a soft one-line "consider running audit". It is a
      nudge like the `(N pending, M substantive)` count, not a gate - skip it when an audit is clearly fresh.

6. **On reject - leave no trace.** Run `git checkout .` (and remove any newly-created untracked
   pages) so the working tree returns to clean. Nothing is committed, the watermark does not move,
   and the tail stays pending. Tell the user the refine pass was discarded.

## Notes

- The subagent does the reading and drafting so the raw-doc contents never flood the user's
  session. The parent holds only the summary and the (small) working-tree pages it edits during
  revisions.
- **Not auto-pushed** means any push follows the user's approval, never precedes it - the opposite
  of capture, which pushes as soon as it commits (when the brain has a remote) because the inbox is
  untrusted staging.
- No deferral in v1: the gate is binary. A "not ready" note is still synthesized this pass, just
  with a `> needs:` marker; it is not held back.
- First refine: the wiki is empty, so the subagent also creates `index.md` and seeds the first
  pages (mostly `overview` pages) emergently - no pre-built taxonomy.
