---
name: remember-gateless
description: >-
  Capture a note straight into the canonical corpus of the user's second brain (brrain) with no
  review gate: remember + a single-doc refine in one motion. Parks the same immutable raw doc +
  inbox pointer as brrain:remember, then immediately synthesizes that one capture into the
  canonical wiki pages per the refine conventions and commits - no approval step. For users or
  moments that do not want the refine ritual and just want the context in the corpus now. Use when
  the user says "remember this - skip the review", "add this straight to my brain", "no gate", or
  has standing instructions to skip the gate. Do not use for gated capture (that is
  brrain:remember), to drain the pending inbox tail (that is brrain:refine), or to answer a
  question from the brain (that is brrain:recall). Requires an active brain in the registry; if
  none, point the user to brrain:setup.
---

## Procedure

remember-gateless = `remember`'s park-and-link capture + an immediate, ungated single-doc
`refine` of **that one capture** into the canonical pages. It is the deliberate exception to the
trust gate: the user invoking it (or standing on it) IS the approval, so nothing pauses for
review. Everything else follows the established conventions - the brain's own `RULEBOOK.md`
remains authoritative for the capture schema, routing, page layering, graded supersession,
`index.md`, and `log.md`; read the relevant sections and follow them. This skill never touches
any other pending inbox entry: a pointer parked by `remember` stays pending for the next `refine`
- it is per-capture, never a tail drain.

**One ungated draft at a time.** Like `refine`'s draft-ahead rule: do not run this skill while a
`refine` or `audit` draft sits ungated in the brain's working tree (and vice versa) - two ungated
drafts would collide on shared pages. If a draft is pending, land or discard it first.

1. **Precondition.** Read the active brain's path from the engine registry at
   `~/.brrain/registry.json` (its `active` field). If the registry is missing or has no active
   brain, **stop** and point the user to `brrain:setup`. Read the brain's `RULEBOOK.md`. Resolve
   the shared helpers `brain-lock.sh` and `brain-pull.sh` from `${CLAUDE_PLUGIN_ROOT}/scripts/`.
   Check the working tree is clean of any ungated `refine`/`audit` draft (above).

2. **Compose the capture exactly as `remember` does.** Same source kinds (dictated fact /
   this-chat summary / scoped exhaust mine / document), same brain-worthy filter, same sensitive
   deny-list, same raw-doc naming and pointer schema, same `Me`/`Agent` provenance rules. Compose
   the raw-doc body and the pointer block. Supersession discipline is unchanged: a changed fact is
   a new raw doc + new pointer, and the graded-supersession rule decides what the page reads as.

3. **Snapshot (locked, brief).** `nonce=$(bash <brain-lock.sh> acquire <brain-path>)` - a non-zero
   exit failed loud; surface it and stop. Run `bash <brain-pull.sh> <brain-path>`; a non-zero exit
   means the brain is behind and could not fast-forward - release the lock, surface the message,
   and stop. Read `index.md` (if it exists) and route the capture's facts to their candidate
   page(s) per the RULEBOOK's "Routing a fact to a page"; note the touch-set (candidates + 1-hop
   backlinkers, per the bounded-touch-set rule). Release the lock.

4. **Draft lock-free, in one primed subagent.** Pass the subagent the composed raw-doc body, the
   pointer block, the routing and relevant page excerpts, the brain path, and the helper paths -
   and instruct it not to re-read what it was handed. It drafts into the working tree, per the
   RULEBOOK conventions:
   - Fold the capture's facts into the candidate pages (or create an earned page / overview line),
     honoring page layering and graded supersession; check the 1-hop backlinker heads for direct
     contradictions, fixing only directly.
   - Rewrite the affected `index.md` router lines.
   - Write one `log.md` entry: `## [YYYY-MM-DD] remember-gateless`, with the same duties as a
     refine entry - the before -> after and why for every supersession it folds, pages
     created/updated, and the raw doc parked.

5. **Land (locked, one commit).** The subagent carries straight through:
   1. Acquire the lock (release it before stopping if any step below fails).
   2. Write the raw doc at its path (never overwrite; disambiguate the slug on collision).
   3. **Insert the pointer ABOVE the watermark** - this is the one mechanical difference from
      `remember`. Locate the `<!-- synthesized through: ... -->` line in the **live** `inbox.md`
      as it exists now under the lock (never from an earlier snapshot - a refine may have moved it
      meanwhile) and insert the pointer block immediately **above** it, leaving every line below
      the watermark byte-identical - the pending tail must not change. Positionally, above the
      watermark means already-synthesized, which after this commit is true; the next `refine` will
      not re-consume it and `recall` will not misread it as staging. Template-created brains ship
      with a watermark from day one (seeded as `(nothing yet)`), so insert-above is the normal
      case even on a brand-new brain. Only if no watermark line exists at all (a hand-made brain
      that predates the template), insert the pointer and then a new
      `<!-- synthesized through: YYYY-MM-DD -->` line directly below it, both placed **above** any
      existing pending pointer headings (top of the pending list), so those stay below and pending.
      Either way there must be **exactly one** watermark line afterwards - never create a second.
      **Never rewrite the watermark's comment text** - the date it names is `refine`'s
      tail-consumption frontier, which this skill does not move; position, not the text, is the
      truth. (Writing this capture's newer date there would falsely imply the older pending
      entries below were synthesized.) Dates above the watermark may read non-monotonic once
      gateless entries mix with refine passes - expected and harmless; nothing orders on them.
   4. One path-scoped `git add` of everything this run touched (raw doc, `inbox.md`, pages,
      `index.md`, `log.md`), **one** commit with a readable summary, `git push` if the brain has an
      upstream remote.
   5. Release the lock.

6. **Report.** One line: `remembered (gateless) -> <page(s) touched>`. If a consequential,
   uncorroborated `Agent`-authored claim just became canonical (the case the gate would have
   scrutinized), say so in the same line - inform, never block.

## Notes

- **The gate is opted out, not abolished.** `remember` + `refine` remain the default loop; this
  skill exists because not every user wants the review ritual. Invoking it is the user's explicit
  acceptance that canonical pages change on the agent's judgment - that acceptance replaces the
  gate for this capture only.
- **Mixed use is safe by construction.** The pending tail below the watermark is never read,
  reordered, or consumed; a user who runs both `remember` and this skill keeps their gated
  captures gated.
- **Provenance still matters.** `Me`/`Agent` tags, dated pointers, and immutable raw docs are all
  kept, so the audit trail is identical to the gated path - only the review step is skipped.
  `audit` remains the backstop that catches what the skipped gate would have.
- Drafting runs lock-free between two brief locks (mirroring `refine`'s two-brief-locks rule);
  everything inside a lock is fast file I/O + git, never model judgment or a user turn.
