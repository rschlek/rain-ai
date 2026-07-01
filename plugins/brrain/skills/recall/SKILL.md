---
name: recall
description: >-
  Answer a question from the user's second brain (brrain): a subagent loads index.md,
  opens the few pages it names, and returns a distilled two-block answer - the canonical answer
  (from gated wiki pages, with [[page]] citations) plus, fenced off, any unrefined staging hits
  from the un-synthesized inbox/raw tail (each tagged with its date and Me/Agent provenance), and
  flags any staging note that conflicts with canonical as a possible supersession. Use when the user
  says "what do I know about X", "recall ...", "look up in my brain", "what's in my brain about
  ...", or "have I captured anything on ...". Also reach for it autonomously, unprompted, whenever
  brain context would help answer the user better - it is read-only and low-risk. Do not use it to
  capture a note (that is brrain:remember) or to synthesize the inbox into pages (that is brrain:refine). Requires
  an active brain in the registry; if none, point the user to brrain:setup.
---

## Procedure

recall is the brain's **read path**. It answers a question by retrieving from the canonical wiki
**index-first** (load `index.md`, open the few pages it names, distill - never dump pages), and
**always** also greps the **un-synthesized tail** (the `inbox.md` pointers below the watermark and
their `raw/` docs) so a recent capture the index cannot see yet is never missed. It returns a
**two-block answer**: the trusted canonical answer, then - fenced off - any staging hits, never
blended. It is **read-only**: the one write it can cause is an optional save-nudge, which it
delegates to `remember`. The brain's own `RULEBOOK.md` (in the active brain's repo) is the
authoritative rulebook - read its **"The recall operation"** and **"Page layering"** sections and
follow them so this skill never drifts.

recall is **dual-invocation**: the user calls it explicitly, and the agent may call it autonomously
whenever brain context would help (read-only and low-risk - worst case is a cheap unneeded read).
Its autonomous value grows once the `SessionStart` index-injection hook is installed (the index is
then already in context, so the agent can see which pages exist); build and use it dual-ready now.

1. **Precondition.** Read the active brain's path from the engine registry at
   `~/.brrain/registry.json` (its `active` field). If the registry is missing or has no active
   brain, **stop** and tell the user to run `brrain:setup` first - do not guess a path. Otherwise `cd` into
   that path; if the brain has an upstream remote, `git pull --ff-only` first (freshness - a capture
   from another device may be waiting; a local-only brain has none, so skip the pull). **Throttle the
   pull on autonomous calls:** when the agent invoked recall on its own and the repo fetched recently
   (`.git/FETCH_HEAD` modified within ~10 minutes), skip the pull - recall is read-only, so the worst
   case is a slightly stale read that the tail-grep discipline already tolerates; an explicit user
   invocation may always pull. Then read **only** the rulebook sections recall runs on - **"The
   recall operation"** and **"Page layering"** in the brain's `RULEBOOK.md`, never the whole file
   (a measured ~-24% token cut at unchanged accuracy; locate the `##` headings and read those
   sections).

2. **Fix the question.** From the user's phrasing (or, on an autonomous call, the context that
   triggered the read) state the concrete question recall is answering. If it is genuinely
   ambiguous what they are asking, ask one clarifying question rather than guessing - but bias toward
   just answering with what you find.

3. **Read in a subagent (clean context) - unless the fast-path applies.** First check the **inline
   fast-path** (validated - it skips the whole spawn cost when the spawn buys nothing): if the
   `inbox.md` tail **below the watermark is empty** AND the answer is already in context or one hop
   away (the injected index routes the question to at most ~2 pages whose settled heads answer it),
   skip the subagent - read those heads directly, answer **canonical-only** (an empty tail is a
   confirmed staging no-op), and continue at step 4. When in doubt (non-empty tail, broad question,
   fat pages), spawn. Otherwise hand the subagent: the question, the active brain's path, and the
   instruction to read **only** the `RULEBOOK.md` sections named in step 1 (never the whole file).
   recall is **retrieval plus one real judgment** (the
   supersession-conflict check in 3.3) - a capable mid-tier model handles it well at a large
   cost/latency cut from the strongest tier. Express that as **intent**, name no specific model;
   **by default inherit the session model** so the choice never goes stale as the model lineup
   changes (cost-optimizing to a fixed tier is a later concern). The subagent must:
   1. **Index-first (two-tier).** Read `index.md` (if it exists). Its lines are **thin routers** - use
      them to pick the few pages that bear on the question, then **open those pages and read their
      settled heads** for the detail (it lives in the head, not the index line). Treat each page's
      **head as current truth** and weight its **`## Open threads` and `>` markers as in-flight /
      lower-confidence** - never return an Open-thread item or a `> needs:` as settled. Distill a
      **canonical answer** in prose, citing each claim's source page inline as `[[slug]]`. Never dump
      whole pages.
   2. **Always grep the tail.** Independently of how good the canonical answer looks, cross-check
      the **un-synthesized tail**. **Slice `inbox.md` to the region below the
      `<!-- synthesized through: ... -->` watermark first** - those pointers, and only the `raw/`
      docs *they* reference, are the entire tail. Grep that slice and those raw docs for the
      question's terms. **Never grep all of `inbox.md` and post-filter** - an above-watermark hit is
      already synthesized into a canonical page, and mislabeling it as staging would raise a **false
      supersession flag**, poisoning the one feature the tail-grep exists for. Read the hits and keep
      the ones that genuinely bear on the question (relevance is the subagent's judgment, not a raw
      word match). This is the only way to catch a fact captured since the last refine. (If the tail
      below the watermark is empty, the cross-check is a confirmed no-op - canonical block only.)
   3. **Detect conflicts.** If a staging hit **contradicts** the canonical answer (a changed
      cadence, a moved date, a reversed preference), that is a **possible supersession** - the
      canonical page has not caught up. Surface it explicitly and recommend `refine` to reconcile.
   4. **Assemble the two-block answer** (format below). Mark whether the answer is **net-new
      synthesis** (it joined facts, or rests on a staging hit, into something written nowhere yet)
      so the parent can offer the save-nudge.
   5. **Return only** the assembled answer + the net-new flag - not the page or raw contents (they
      stay in the subagent's context, not the user's session).

4. **Present the answer.** Surface the subagent's two-block answer as-is. If it was flagged
   **net-new synthesis**, append a one-line **save-nudge**:
   `(this isn't written down as one fact yet - want me to remember it?)`. Offer the nudge **only**
   for net-new synthesis; a plain lookup that just restated a canonical page has nothing to save, so
   stay silent.

5. **On a "yes" to the nudge** - hand the synthesized answer to `brrain:remember` (it parks
   an `Agent` raw doc + pointer and flows through the refine gate like any capture). recall
   itself writes nothing. On no answer, nothing is written.

## The two-block answer format

1. **Canonical answer** - distilled prose from gated wiki pages, citing the `[[slug]]` each claim
   comes from. Cite per **source**, not per sentence: a whole answer drawn from one page is cited
   once or twice, not on every line. This is the trusted answer and leads.
2. **Staging callout** - shown **only** when the tail-grep kept a hit. Fenced off below the
   canonical answer, never blended into it. Each hit tagged with its **date** and **`Me`/`Agent`**
   provenance:

   ```
   ----------------------------------------------
   !! Unrefined staging (captured, not yet gated):
      [2026-06-10] (Me) - cadence note: weekly
   ```

   When a hit conflicts with canonical, name it and point at the fix:

   ```
   !! Possible supersession - canonical may be stale:
      [[acme-report]] says biweekly, but a newer staging note [2026-06-10] (Me) says weekly.
      Not yet gated. Run refine to reconcile.
   ```

The hard rule: **canonical and staging never share prose.** Staging is a different epistemic class
(unverified, has not passed the gate) and must look different, not sit one footnote away from a
trusted claim.

## Edge cases

- **Nothing found** (no canonical page and no tail hit): say so honestly ("nothing in your brain
  about X") and stop. Do **not** nudge to capture - there is no answer to save.
- **Cold / empty brain** (no `index.md` yet, before the first refine): there is no canonical layer,
  so recall runs **tail-only** - grep `inbox.md` + `raw/` and return staging-labeled hits with a
  note that nothing has been synthesized yet. No error.
- **Large tail** (the un-synthesized tail has grown big): the subagent **summarizes** rather than lists
  - "7 staging notes mention the acme report; none appear to change the cadence" - so the read stays useful
  without a wall of hits. Formal ranking/limiting is deliberately not built: the tail is small by
  design. A routinely huge tail is the signal to add ranking - and to refine more often.

## Notes

- The subagent does all the reading so page and raw contents never flood the user's session; the
  parent holds only the distilled answer it presents.
- **Always-on tail-grep is the supersession safety net.** Index-first alone would confidently
  return a stale canonical fact after a newer capture changed it; the tail-grep is what catches the
  change. This makes recall a supersession *detector*, not merely a lookup.
- **Read-only.** recall never commits or pushes. The save-nudge delegates entirely to
  `remember`, which does its own commit and push.
- The grep scope is the **un-synthesized tail only** (below-watermark pointers + their raw docs), never
  all of `raw/`: everything above the watermark is already synthesized into the canonical pages that
  index-first covers, so grepping it would re-surface canonical material mislabeled as "staging."
