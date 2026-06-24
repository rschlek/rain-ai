---
name: interview
description: >-
  Run the interview elicitation ritual over the user's second brain (brrain): a subagent
  sweeps the corpus for the highest-value knowledge gaps - subjects referenced but never defined (a
  name with no page) and `> needs:` markers refine left behind - ranks them by importance, and
  returns a gap map; the user picks from it, a short interview fills each, and the run is captured as
  one Agent digest through remember. interview is the brain's curiosity / pull path - it hunts what is
  missing and asks. Use when the user says "interview", "interview on <subject>", "interview me about my
  brain", "what's missing in my brain", or "what gaps do I have", or wants the brain to find its own
  thin spots. Explicit-only - it interviews, so never autonomous. Do not use to capture a dictated
  note (brrain:remember), answer a question (brrain:recall), or synthesize the inbox (brrain:refine). Requires an active
  brain in the registry; if none, point the user to brrain:setup.
---

## Procedure

interview is the brain's **elicitation / pull path** - the curiosity counterpart to `remember`'s push.
Where every other input arrives because the user decided to capture it, interview reads the corpus,
finds the highest-value **knowledge gaps**, and interviews the user to fill them - the brain
initiating its own growth. It hunts **absence**, and writes **nothing canonical**: it routes the
interview's answers through `remember`, so the `refine` gate stays the only place knowledge becomes
canonical. The brain's own `RULEBOOK.md` (in the active brain's repo) is the authoritative
rulebook - read its **"The interview operation"** section and follow it so this skill never drifts.

interview is **explicit-only** (unlike `recall`'s dual-invocation): it *interviews* the user, so it
must **never** fire autonomously - the user runs it deliberately when they have time to sit with it.

1. **Precondition.** Read the active brain's path from the engine registry at
   `~/.brrain/registry.json` (its `active` field). If the registry is missing or has no active
   brain, **stop** and tell the user to run `brrain:setup` first - do not guess a path. Otherwise `cd` into
   that path; if the brain has an upstream remote, `git pull --ff-only` first (freshness; a
   local-only brain has none, so skip), then read the brain's `RULEBOOK.md`.

2. **Fix the scope.** Bare `interview` is a **whole-corpus sweep**. `interview on <subject>` scopes to
   one page/subject and digs deeper there. Default to the sweep unless the user named a subject.

3. **Build the gap map in a subagent (clean context).** Hand the subagent the scope, the active
   brain's path, and the brain `RULEBOOK.md`. The subagent only detects and ranks gaps (the
   interview itself runs in the parent session), so a **capable mid-tier model suffices** - express
   that as **intent** and **by default inherit the session model** (name no specific model). The
   subagent must:
   1. **Read the corpus.** Load `index.md`, then read the pages in scope enough to find gaps - lean
      on the glosses; open a page fully only when a gap there is a real candidate.
   2. **Find Type-A gaps only** (answerable - things the user knows but the brain has not captured),
      from two sources:
      - **`> needs:` markers** - explicit holes `refine` planted on pages. Zero-inference, highest
        precision.
      - **Referenced-but-undefined/thin subjects** - via **both** detection signals: **(a) dangling
        `[[wikilinks]]`** (a link with no target page - precise) and **(b) repeated proper nouns with
        no page** (a name that recurs in prose, never linked - inferred, the subagent's judgment).
      Do **not** surface Type-B open-questions (things *nobody* has answered yet); they are deferred.
   3. **Suppress already-answered gaps.** **Slice `inbox.md` below the
      `<!-- synthesized through: ... -->` watermark** and check the pending tail - never ask about a
      subject a captured-but-unsynthesized note already defines. (Same watermark discipline as
      `recall`: slice first, never grep the whole file and post-filter.)
   4. **Rank by importance** - reference density (how many places point at the undefined/thin
      subject). Explicit-vs-inferred is a **confidence tag** and tiebreak, not the primary axis: a
      heavily-referenced inferred gap can outrank a trivial explicit `> needs:` on an orphan.
   5. **Return only the ranked gap map** - each gap one line (subject, source + confidence, a
      one-line "why it ranks"). Not page contents.

4. **Interview, map-first.** Present the **top ~6 with a "more below" note** (never a wall of gaps).
   The user picks which to dig into; each pick is a short **conversational** interview (2-3
   follow-ups, cuttable with "that's enough"). **Skipping carries no signal and persists nothing** -
   a skip may just mean "no time now", so a skipped-but-important gap is *meant* to resurface next
   run; importance ranking already buries the low-value ones. interview is **stateless** - the only
   thing it writes is the digest in step 5.

5. **Capture one digest through `remember`.** When the interview is done, hand the run's answers to
   `brrain:remember` as a **this-chat summary** (one `Agent` doc in `raw/sessions/` + one
   pointer; remember commits and pushes). interview itself writes and commits **nothing**. **No `Me`
   carve-out in v1** - the whole digest is `Agent` (interview framed the questions and synthesized the
   reply); the `refine` gate promotes the solid facts to ground truth when the user confirms them.
   Surface the one-line confirmation `remember` returns.

## The gap map format

A ranked list, one line per gap, top ~6 shown - subject, source + confidence, why it ranks:

```
interview - swept <N> pages + the tail. Top gaps by importance (more below):

  1. [[acme-framework]]                inferred · dangling [[link]], no page
       Linked from a load-bearing page, but never defined.
  2. <person> ("<alias>")              inferred · referenced in 4 places, no page
       Recurs across notes; nothing says who they are or how you work together.
  3. > needs: <fact>                   explicit · refine-flagged on <page>
       refine could not fill this at the gate; you may know it now.
```

`explicit` = a `> needs:` marker; `inferred` = a detected referenced-but-thin subject (dangling
link or repeated prose noun).

## Edge cases

- **No gaps found** (the corpus is dense and the tail covers the rest): say so and stop - there is
  nothing to interview about.
- **Cold / empty brain** (no `index.md` yet, before the first refine): there is no corpus to sweep,
  so interview degrades to **open-ended bootstrap elicitation** seeded by the tail (a few broad
  questions to start filling the brain). Low priority; do not over-build it.
- **`interview on <subject>` with no page yet**: treat the whole subject as one gap - interview to
  seed it from scratch.

## Notes

- The subagent does all the corpus reading so page contents never flood the user's session; the
  parent holds only the ranked gap map and runs the interview.
- **interview only captures; `refine` reconciles and clears.** interview harvests a `> needs:` marker
  and routes the answer back through `remember`; the **next `refine`** folds it in and clears the
  marker. Neither reaches into the other's job - this closed loop is what makes the two
  self-completing.
- **Explicit-only.** interview elicits, so it never fires autonomously - the opposite of
  `recall`, whose read-only safety licenses autonomous use.
- If interview notices a **contradiction** mid-read (a clash, not a gap), it flags it and recommends
  `refine` to reconcile; it does not absorb that consistency job (the same seam discipline
  `recall` keeps when it flags a possible-supersession).
