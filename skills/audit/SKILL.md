---
name: audit
description: >-
  Run the audit over the user's second brain (brrain): a subagent
  sweeps the canonical wiki pages for inconsistency - index/page desync, orphan pages, clean dated
  supersession the pages missed, cross-page contradictions, and stale claims - drafts the
  unambiguous fixes into the working tree, flags the ambiguous ones, and returns for the user's
  review and approval before anything is committed. audit is the brain's consistency lint and
  hunts inconsistency, the complement to interview's hunt for absence. It reuses refine's trust gate -
  nothing canonical changes without their yes, and it is never auto-pushed. Use when the user says
  "audit", "audit the brain", "check the brain for contradictions /
  consistency / rot", "lint the brain", or "audit on <subject>", or when a refine-end nudge
  says an audit is due. Do not use to capture a note (brrain:remember), answer a question (brrain:recall),
  synthesize the inbox (brrain:refine), or hunt knowledge gaps (brrain:interview). Requires an active brain in the
  registry; if none, point the user to brrain:setup.
---

## Procedure

audit is the brain's **consistency auditor**: it reads the canonical wiki pages and `index.md`,
finds where they have drifted **inconsistent** (the LongMemEval knowledge-rot failure mode), drafts
the unambiguous fixes, and flags the rest. It hunts **inconsistency** - the complement to `interview`,
which hunts **absence**. It is **introspection** (pages -> pages), where `refine` is **intake**
(inbox -> pages); it audits the **already-canonical** layer, so it never reads the pending inbox tail
(that is refine's job). It **reuses refine's trust gate**: the heavy reading runs in a clean-context
subagent, but **nothing is committed until the user approves**, and it is **not auto-pushed**. The
brain's own `RULEBOOK.md` (in the active brain's repo) is the authoritative rulebook - read its
**"The audit operation"**, **"The trust gate"**, and **"Page layering"** sections, and follow them so
this skill never drifts.

1. **Precondition.** Read the active brain's path from the engine registry at
   `~/.brrain/registry.json` (its `active` field). If the registry is missing or has no active
   brain, **stop** and tell the user to run `brrain:setup` first - do not guess a path. Otherwise `cd` into
   that path. **Freshness pull:** run `bash ${CLAUDE_PLUGIN_ROOT}/scripts/brain-pull.sh <brain-path>`
   (it does the `git pull --ff-only` and is a no-op for a local-only brain); a **non-zero exit means
   the brain is behind the remote and could not fast-forward** - surface the helper's message and
   **stop** rather than audit a stale base (no lock is held yet at this step). Then read the brain's
   `RULEBOOK.md`. Also resolve the shared lock helper
   `${CLAUDE_PLUGIN_ROOT}/scripts/brain-lock.sh` - audit takes that mutex **once, briefly, around the
   land-commit** (step 5), so its git write cannot race another tab's. The read-only detection (step
   3) and the human gate (step 4) hold **no lock**.

2. **Fix the scope.** Bare `audit` is a **whole-corpus sweep**. `audit on <subject>`
   scopes to one page/subject and its backlinkers. Default to the sweep unless the user named a
   subject. (If there is no `index.md` yet - a cold brain before the first refine - there is nothing
   canonical to audit; say so and stop.)

3. **Audit in a subagent (clean context).** Hand the subagent the scope, the active brain's path,
   the current `index.md` contents, and the brain `RULEBOOK.md`. audit is consistency detection
   against a fixed checklist with the user as the gate backstop, so a **capable mid-tier model is the
   cost/quality fit** - the strongest tier is not needed. Express that as **intent** and **by default
   inherit the session model** (name no specific model). The subagent must:
   1. **Read index-first.** Load `index.md`; lean on the gloss lines and open a page fully only when
      a candidate inconsistency is actually there. Do **not** read the pending inbox tail - the tail
      is refine's domain, not the canonical layer.
   2. **Run the consistency checks** (per the rulebook's detection taxonomy):
      - **within-page** coherence (a page that contradicts itself);
      - **page vs its backlinkers** - grep each `[[slug]]` and check the linkers' claims agree with
        the page;
      - **page vs `index.md`** gloss (desync - a gloss that points at a missing page, a page missing
        from the index, or a gloss that misstates the page);
      - **page vs the rulebook** - `RULEBOOK.md` is **trusted reference** (there is no
        `requirements.md` - it is retired): when a page's claim contradicts the rulebook, the **page
        loses** (it is the stale one);
      - **orphan pages** (in the corpus, nothing links to them) and **rename-orphaned links** (a
        dangling `[[slug]]` whose target exists under a new slug - a rename that backlink-by-grep
        missed). A dangling link to a slug that **never** had a page is **interview's gap, not
        audit's** - leave it.
      - **existing `> contested:` markers** - re-evaluate each: still contested, or now resolvable?
        (audit owns clearing them.) Do **not** touch `> needs:` markers - those are refine's.
        - **`external:` reference lint (structural only)** - each `external:` frontmatter entry is
          well-formed (has a `system` + a `ref`); **flag** malformed entries (no auto-fix - the brain
          cannot guess the right value). Do **not** call any peer: *live* resolution-checking (does the
          `ref` still resolve) is **deferred to v1.1**. See the rulebook's "External references".
      - **layering conformance** (per the rulebook's "Page layering") - a `> needs:` / `> contested:`
        marker sitting **in the head** (above the first `##`) is **auto-fixable** (move it down to its
        section or `## Open threads`); **history narrated on a page** (a dates-of-change journey, a
        "was X then Y" sequence, a kept superseded state), **WIP that reads as settled** (in-flight
        prose in the head/a settled section instead of `## Open threads`), and an **`## Open threads`
        hoarding resolved items** are **flag-only** (settled-vs-history is judgment - a wrong auto-fix
        would delete real settled knowledge).
      - **index scaling-trigger** (detector, not a fix) - if the flat `index.md` is past **~16 KB or
        ~80 pages**, **nudge** a gated re-shard (an audit-class restructure - audit owns restructuring -
        never an auto-fix). See the rulebook's "`index.md` -> Scaling ladder".
      - **page-fatness trigger** (detector, not a fix) - check **every** page against the fatness
        threshold (**>~12 KB or >~8 `## H2` sections**). For each page over it, **flag** it with a
        proposed **split map**: the thin hub keeps its settled head + a `## Subpages` router-list, and
        each cluster of related sections becomes a hub-prefixed peer page (`<hub>-<facet>`) that lands
        the hub and every peer back under threshold. The map also proposes, per item, which
        `external:` refs migrate to a peer (facet-specific) vs stay on the hub (whole-subject). This is
        a **detector only** - draft nothing; the split is a gated fix-class executed on the user's yes
        (step 4). See the rulebook's "Page-fatness detector and the page-split fix-class".
   3. **Classify every finding** into two response classes:
      - **auto-fixable (draft it):** index/page desync, **clean dated supersession** (same subject,
        a newer-dated fact the page never folded in - apply the rulebook's graded-supersession rule),
        rename-orphaned link repoints, a **marker stranded in the head** (move it down), and any
        `> contested:` now cleanly resolvable.
      - **flag-only (ask, do not fix):** orphan pages (merge / link / retire is the user's call),
        **genuine contradictions** with no clear temporal winner, **stale claims**, **malformed
        `external:` entries** (the brain cannot guess the right value), and **layering violations**
        (history narrated on-page, WIP-as-settled, `## Open threads` hoarding resolved items). The
        **index scaling-trigger** is reported as a nudge, not a fix. **Fat pages** are flagged with
        their proposed **split map** - the split is a gated fix-class drafted only on the user's yes
        (step 4), never in this detection pass.
   4. **Draft the auto-fixable changes into the working tree. Commit nothing.** Leave flag-only
      findings undrafted (they need the gate).
   5. Return a **structured findings summary only** (not page contents):
      - **fixes drafted** - each with a one-line what-changed and which page;
      - **contradictions** - each as "page A says X vs page B says Y", for gate adjudication;
      - **orphans / stale claims** - flagged for the user's decision;
      - **fat pages** - each with its size / H2 count and its proposed **split map** (thin hub +
        named peers, which section-clusters go where, proposed `external:` migrations), for the
        per-page split decision at the gate;
      - **`> contested:` cleared** this pass;
      - **nudges** - index scaling-trigger and audit-due (age/change), if any;
      - the set of pages touched.
      If the sweep found **nothing**, return a clean bill of health.

4. **Review with the user (the gate).** Present the subagent's summary as the primary surface; offer
   the raw `git diff` on request. Then run the **adjudication loop**:
   - **Contradictions - gate-resolve first.** For each clash, the user usually knows which fact is
     stale: they pick the winner and you draft the resolution into the working-tree page this pass
     (gate-time curation, **not** a capture - no raw doc, no inbox pointer). When they **defer**,
     plant a **`> contested:`** marker (per the rulebook) once, on the canonical page for that fact,
     citing the dissenting page; the pass still commits with the marker in place.
   - **Orphans / stale claims.** Apply their decision (link, merge, retire, rewrite) directly to the
     working-tree pages.
   - **Fat pages - the page-split fix-class (drafted only on yes).** For each flagged fat page, show
     its **split map** and ask **per page**: split now / defer / leave as-is (a standing free-text
     escape too). Detection drafted nothing, so on **defer** or **leave** nothing changes for that
     page. On **split**:
     1. **Draft the split into the working tree** (re-invoke the subagent for the heavy move so page
        contents stay out of your context): create each hub-prefixed peer page (own frontmatter +
        layered head), move its section-clusters off the hub, thin the hub to its settled head + a new
        **`## Subpages`** router-list (`- [[peer]] - gloss` per peer), and add each peer's **`index.md`
        router line**. Peers are flat first-class pages (own index line), never a sub-tier.
     2. **`external:` refs follow their subject** - confirm each proposed migration (facet-specific ref
        -> its peer) one at a time; whole-subject refs stay on the hub. Judgment, so gate-confirmed,
        never auto-applied.
     3. **Inbound `[[hub]]` backlinks stay on the hub by default** (the hub routes onward via
        `## Subpages`, so nothing breaks). Offer per-link repoints to a specific peer only if the user
        asks - it is judgment with **no cheap undo**, so the default is no-op.
     4. A split is the **least-reversible** change here, so it takes its **own explicit approval** at
        the landing step - never fold it silently into a blanket "approve all". Record it in full in
        `log.md` (hub, peers created, section moves, ref migrations, any repoints, threshold crossed).
   - Apply small edits yourself; only re-invoke the subagent if a change genuinely needs a re-read
     (the page-split draft is exactly such a re-read). Re-present and loop. The review is per-batch,
     not finding-by-finding - **except** a page split, which is confirmed per-page before it is drafted.
   - **Put the final landing decision through a structured-choice prompt** (the
     irreversible landing moment - a commit, pushed/published when the brain has a remote), options along the lines of **Approve
     and land** / **Request edits** / **Reject and discard**. An unprompted clear "approve and land
     it" still counts - do not force the question if the user has said yes.

5. **On approve - land it atomically (locked).** Fold in any final adjudications, then take the lock
   just for the land and release it the moment the commit is done:
   0. **Acquire:** `nonce=$(bash <brain-lock.sh> acquire <brain-path>)`. A non-zero exit means it
      failed loud (another brrain op is mid-write or stuck) - surface it and stop. Release the lock
      before stopping if any step below fails.
   1. **Write the `log.md` entry** (one narrative entry per committed pass; format in the rulebook):
      pages touched (flat slugs), fixes applied, supersessions reconciled, contradictions resolved vs
      `> contested:` planted, `> contested:` cleared, and **any page split in full** (hub, peers
      created + their index lines, section-clusters moved, `external:` refs migrated, inbound backlinks
      repointed, and the threshold that fired it) - a split's off-page history has no other home.
   2. `git add` the changed pages, `index.md`, and `log.md`; **one commit** with a readable summary;
      then **`git push`** if the brain has an upstream remote (a local-only brain just keeps the
      commit local).
   3. **Release:** `bash <brain-lock.sh> release <brain-path> "$nonce"`.
   4. Report a one-line confirmation: `audit -> <F> fixes, <C> contested, <P> pages`.

6. **On reject - leave no trace.** Run `git checkout .` (and remove any newly-created untracked
   pages) so the working tree returns to clean. Nothing is committed. Tell the user the audit was
   discarded.

## Edge cases

- **Clean bill of health** (the sweep found nothing): say so and stop - no commit, no `log.md` entry,
  exactly like a rejected refine writes nothing.
- **Cold / empty brain** (no `index.md` yet, before the first refine): nothing canonical to audit;
  say so and stop. No error.
- **A finding that is really a gap** (a dangling `[[link]]` to a never-existed subject, a thin stub on
  a load-bearing subject): that is `interview`'s territory (absence), not audit's. Note it and
  recommend `interview`; do not draft it.

## Notes

- The subagent does the reading and drafting so page contents never flood the user's session; the
  parent holds only the findings summary and the (small) working-tree edits it makes during
  adjudication.
- **Not auto-pushed** - any push follows the user's approval, never precedes it. audit changes
  canonical knowledge, so it is gated exactly like `refine`; only capture pushes as soon as it
  commits (untrusted staging), and only when the brain has a remote.
- **Whole-corpus, never incremental.** A sweep cannot miss a cross-page contradiction the way an
  incremental "only what changed" audit would (the two clashing pages may have changed in different
  runs). Completeness is the whole value. If a sweep ever must cap coverage, **say so** - no silent caps.
- **The `> contested:` marker is audit's**, distinct from refine's `> needs:` (a hole, an
  absence). A contradiction is a clash of two present facts; audit plants the marker on defer
  and clears it on a later pass. `recall` surfaces a `> contested:` marker for free when it reads
  the page; `interview` does not harvest it (a clash is not an absence).
- **Invocation is manual and attended** on the fix side (like refine) - detection is read-only and
  safe, but the fix path stays gated and deliberate, never an autonomous run.
- **audit has its OWN age/change nudge, decoupled from the refine-end nudge.** Now that audit is the
  safety-critical >1-hop supersession backstop and owns restructuring, it can no longer depend on a
  refine happening to be nudged. The independent trigger fires at a **natural wrap-up**: when the brain
  is due - roughly **>~14 days since the last `## [date] audit` in `log.md`, or >~10 canonical pages
  changed since** (per `git log` over the wiki pages; tunable) - nudge *"N days / M pages changed since
  the last audit - run audit?"*. The `refine`-end nudge stays as a **secondary** trigger. See the
  rulebook's "The audit operation -> Invocation".
