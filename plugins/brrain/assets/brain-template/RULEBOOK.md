# RULEBOOK.md - maintainer rulebook for this second brain

You are the agent maintaining the user's personal second brain: a durable, git-backed,
plain-markdown knowledge base. This file is the rulebook. It tells you how the brain is structured
and how to run each operation correctly. Read it before you touch anything here. It is engine-neutral
- it names no specific agent platform, so it reads the same whichever agent is running it.

This rulebook documents the conventions that are **in force** - the capture model, the storage
tiers, and the synthesis and read operations (`refine`, `recall`, `audit`). It is the
authoritative reference; treat it as ground truth and do not invent detail beyond it.

## The model in one paragraph

Capture is **cheap and dumb**: every `remember` parks an immutable **source doc** in `raw/`
and appends one **pointer** to `inbox.md`. It does no extraction, linking, dedup, or
rewriting - those are the expensive, careful work, and they all belong to **`refine`**, the
later ritual that distills pending pointers into canonical wiki pages under the user's review.
So nothing capture writes is canonical; the inbox is untrusted staging, and `refine` is the
only trust gate.

## The three tiers

1. **`raw/`** - immutable source artifacts. **Every capture writes one here first.** A dictated
   fact becomes a tiny doc; a chat becomes a generated summary doc; a PDF or document is stored
   (verbatim, or by pointer - see cite-by-pointer); a scoped exhaust mine (git history,
   completed tasks, prior captures) becomes a digest doc. `raw/` **never mutates** - it is the
   permanent hard reference the brain can always return to. Subdirs are created lazily as the
   first artifact of each kind lands: `raw/sessions/`, `raw/docs/`, `raw/exhaust/`.
2. **`inbox.md`** - a **worklist of pointers**, not content. Each capture appends one dated,
   provenance-tagged line that **links to its raw doc** plus a one-line gist. Append-only and
   light. A `<!-- synthesized through: ... -->` watermark marks how far `refine` has gotten;
   everything below it is pending.
3. **Wiki pages + `index.md`** - the living, canonical, deduplicated knowledge, produced by
   `refine`. Cross-linked with `[[wikilinks]]`. Single-source-of-truth applies here only.
   Flat files (no page directories) with a `kind:` in frontmatter. `index.md` is the retrieval
   entry point. None of this exists until the first `refine`.

## The capture operation

Capture = write **one** immutable raw doc + append **one** inbox pointer. That is the whole
operation. It is additive and low-risk: it never edits an existing raw doc or pointer, never
touches a wiki page, never dedups. **There are zero exceptions** - every capture parks a raw
doc and a pointer, even a one-line dictated fact. No carve-outs; keep it clean.

"It's a PDF / a chat / a git log" is not a different verb - it is just **which kind of raw doc
gets written**. `remember` routes by the natural-language scope of the request:

- **A dictated fact** ("remember John likes cats") -> a tiny raw doc holding the fact +
  pointer, tagged `Me`.
- **This chat** ("remember this chat" / "log what we did") -> an Agent-written summary doc +
  pointer, tagged `Agent`.
- **A scope of past work** ("remember the work I've done on the website redesign") -> a scoped **exhaust mine**
  (git history, completed tasks, prior captures) distilled to a digest doc + pointer, `Agent`.
- **A document** ("remember this project summary" / a PDF) -> store the doc (verbatim or
  cite-by-pointer) + pointer, `Agent`.

### `raw/` doc conventions

- **Immutable.** Once written, a raw doc is never edited or reordered. A correction or update
  is a **new** capture (new doc + new pointer); the dates carry the history.
- **Loosened definition.** A raw doc is an immutable source artifact: a **verbatim** document
  **or** an **Agent-generated summary** of a source (a chat, a scope of exhaust). The summary
  is itself the permanent source of record for that capture - `refine` distills from it and can
  always return to it. (This deliberately widens the older "verbatim only" definition; the
  widening is honest and small, and keeps the brain close to the Karpathy substrate.)
- **Naming**, lazily binned by kind:
  - `raw/sessions/YYYY-MM-DD-<slug>.md` - chat / session summaries.
  - `raw/docs/<slug>.md` - stored documents (verbatim or cite-by-pointer stub).
  - `raw/exhaust/YYYY-MM-DD-<scope>.md` - exhaust-mine digests and dictated facts.
- **cite-by-pointer mode** - for big, re-fetchable, or sensitive external docs, do **not**
  vendor the body. Store a stub recording the source location + date + content hash, so the
  citation points outward rather than copying. For example:

  ```
  src: gdrive://abc123 "Q3 Planning" (not vendored, sha 4f2a..)
  captured: 2026-06-11
  gist: quarterly targets and the redesign scope decision.
  ```

### `inbox.md` pointer schema

No frontmatter. One heading line that points at the raw doc, plus a one-line gist:

```
## [2026-06-11] website (Agent) raw/exhaust/2026-06-11-website.md
Distilled the website redesign work so far: the launch timeline, the vendor choice, the over-budget finding.
```

The heading is: `## [YYYY-MM-DD] <optional project tag> (<provenance>) raw/<sub>/<doc>.md`.

- **Date-stamp** `[YYYY-MM-DD]` - required. Supersession runs on this; use today's date.
- **Project tag** - optional, lowercase-kebab (e.g. `website`, `billing`). Omit it when the
  note has no project home - preferences, goals, and life facts often arrive with no repo
  context, and a forced tag is worse than none. When present it makes a future `refine`'s
  group-by-project trivial.
- **Provenance tag** `(Me)` or `(Agent)` - required, and **first** inside the parens so existing
  reads still find it. See below.
- **Raw pointer** - the repo-relative path to the doc this capture just wrote. Required.
- **Gist** - one line, freeform. Just enough for `refine` to triage without opening the doc.

Append new pointers at the **bottom** - strictly **below the `<!-- synthesized through: ... -->`
watermark** (the watermark is positional; everything below it is pending). **Even when the watermark
is the last line** (the inbox was just refined to empty), the new pointer goes *below* it, never
above - never treat the watermark as a trailing footer. Append-only, ingestion order; never reorder
or rewrite existing pointers or the watermark.

### Provenance: `Me` vs `Agent`

The tag tells a future `refine` how hard to scrutinize. The test is **who authored the
content**, not who invoked the capture.

- **`Me`** - the user stated it: a fact the user dictated verbatim. The user is the source, so `refine`
  trusts it as ground truth.
- **`Agent`** - you authored or synthesized it, even when the user asked you to: session
  summaries, exhaust-mine digests, document extractions, bootstrap elicitation. Machine-authored
  content can confabulate or smuggle in a leading-question's framing, so `refine` scrutinizes it
  harder. Capture it anyway - the gate is `refine`, not the push.

When in doubt, tag `Agent`. Over-scrutiny at refine is cheap; a confabulation that slips in as
ground truth is not.

### The capture nudge (durable-moment + wrap-up, manual-but-nudged)

Capture is **manual** - but not unaided. An earlier design auto-captured *every* finished session
through a SessionEnd-enqueue / SessionStart-drain pipeline; it was **reverted** because it
solved a problem that did not exist and actively *cannibalized the deliberate-capture habit* (knowing
the machine would grab everything, the user stopped invoking `remember` even when the user felt the pull),
while flooding the `refine` gate with low-quality volume. The deliberate act of capturing **is** the
signal filter; that is the point.

The successor is **manual-but-nudged**: the agent **offers** `remember` when the session produces
something durable, firing at the **first of two moments - the durable moment (mid-session, the instant
that durable thing crystallizes) or a natural wrap-up (the backstop)**. On yes it flows through the
**normal** capture -> `refine` path - normal provenance, **no separate tier**, no special capture flag.
It is an ordinary manual capture that the agent happened to suggest.

- **The judgment gates the OFFER, not the capture.** The agent decides "is this durable?" to decide
  whether to *speak up* - never to decide what may be parked. A misjudged offer costs one "no thanks"
  and never touches canonical knowledge; it cannot pollute the `refine` gate the way auto-capture did.
- **"Durable" = the brain-worthy test below.** Offer when the session produced a real decision and its
  reasoning, a strategic reframe, an open question worth tracking, or a hard-won finding - something
  that lives nowhere else queryable. Stay silent for routine lookups, mechanical edits, status checks,
  and anything a repo / calendar / task list already records.
- **High precision, not timidity.** Silence is the *common* case only because most sessions are
  routine - not because the offer should be shy. When the durable signal is genuinely real, offer with
  confidence: that is what rebuilds the habit the auto-pipeline eroded. Lean strict on the
  durable-vs-routine line; do not lean quiet on a real finding.
- **Fire at the durable moment, not only at wrap-up.** A single wrap-up trigger misses the sessions
  that end **abruptly** or **switch devices** - exactly when the source chat is stranded on a machine
  the user no longer has, the costliest miss (a missed capture, not just a delayed one). So raise the
  offer **the instant a durable thing crystallizes mid-session**; the wrap-up firing stays as the
  backstop for whatever was not already offered. (The auto-push remote already syncs every capture, so
  cross-device is not a separate problem - the only real failure is not capturing at all.)
- **Discipline.** At most **one** offer per session - the durable-moment and wrap-up triggers **share
  the single offer** (fire whichever comes first; never offer twice); never re-offer once the user has
  captured this session; if the user declines, drop it. Name the thing in a single line so the offer is
  concrete.

A SessionEnd hook cannot converse, so the offer can only be **the agent's own in-context behavior**. The
brrain engine primes it from `inject-index.sh` (the kept SessionStart preamble): whenever a brain
exists on the device - **even a cold, empty one** - the preamble instructs the agent to run this nudge
**both at the durable moment (mid-session) and at wrap-up**. Reviving auto-capture itself needs a
named, concrete pain, never the automation impulse alone.

### Wrap-up maintenance nudges (refine-due, audit-due)

Capture is **unbounded** - there is **no hard cap**; a capture is never refused. Backpressure toward
synthesis is instead two **soft** nudges the agent raises at a natural **wrap-up** (never blocking, at
most alongside the capture offer):

- **refine-due (depth/age).** If the pending inbox tail below the watermark looks deep or stale, nudge
  *"N pending, oldest D days - refine?"* (rough trigger: **>~7 pending, or the oldest >~10 days**;
  tunable). refine is incremental (`O(new)`), so a large pile is cheap - the nudge is about keeping the
  canonical layer current, not about relieving a bound.
- **audit-due (age/change).** If it has been a while since the last `audit`, or many pages changed
  since, nudge *"N days / M pages changed since the last audit - run audit?"* (rough trigger:
  **>~14 days, or >~10 pages changed**). See "The audit operation -> Invocation".

Both are computed on demand at wrap-up (from `inbox.md`, `log.md`, and `git log`); neither is a gate or
a scheduled autonomous run.

## What is worth capturing (brain-worthy criteria)

**Privilege durable judgment over re-derivable inventory.** Capture what exists nowhere but
the user's head or this conversation - decisions and the reasons behind them, open questions,
strategic reframes, hard-won facts (the kind of over-budget finding you cannot reconstruct
later). Do **not** capture what is already, and better, recorded somewhere queryable: a repo's
file list, a calendar's schedule, a task list's contents, a scaffold's component inventory.
That material is re-derivable from its source on demand; parking a snapshot of it just creates
stale duplication for `refine` to wade through. This is the same instinct a native agent-memory
feature uses, pointed at the brain. When a capture is borderline inventory, lean toward not parking it,
or park only the judgment wrapped around it ("we chose X over Y because Z"), not the inventory.

## Sensitive content

Capture is park-and-go, and the real review is `refine`, so the only pre-push gate at capture
time is a **named deny-list**: **medical, therapy, health**. `remember` refuses to park content
on these topics without an explicit override from the user in the moment. Everything else parks
freely. (cite-by-pointer is the right tool when a sensitive doc must be referenced at all -
point outward, do not vendor the body.)

## Supersession discipline

Plain markdown has no temporal model, and "what changed since" is a known failure mode for LLM
memory. The cheap mitigation, which you follow at capture time:

- **Date-stamp every pointer** (the schema enforces this).
- **Never silently overwrite a changed fact.** `raw/` and `inbox.md` are append-only, so you do
  not edit the old doc or pointer at all - you write a **new** raw doc and append a **new** dated
  pointer stating the new truth. The old artifacts stay as the record of what was true before;
  the new date establishes the order. `refine` and audit are where the old fact gets
  marked superseded on the canonical page (reconciled via backlink-by-grep - grep the
  `[[wikilink]]` to find and update every page that referenced it).

So a preference reversal or a moved deadline is a **new capture**, not an edit. The append-only
stream is the audit trail of what was true when.

## Cold-start bootstrap

The brain starts empty, and capture alone fills it slowly - the write-only-swamp risk. Bootstrap
fills it actively, two ways, both flowing through the normal park-and-link path:

- **Mine exhaust** - existing records that already encode the user's life: git history, past
  performance reviews, resume, completed-task history, existing skill conventions. A scoped mine
  produces a digest doc in `raw/exhaust/` + a pointer.
- **LLM-guided elicitation** - an interview loop that asks the user questions to generate the
  corpus the user would never think to dictate unprompted. The session's answers become a summary doc
  + pointer.

Both produce **machine-authored** content: tag every bootstrapped pointer `(Agent)`. Elicitation
especially risks confabulation and leading-question errors, so it is scrutinized hard at the
`refine` gate before it can become canonical. Do not treat bootstrapped content as ground truth
just because there is a lot of it.

## Page-kind vocabulary (for `refine`, named lightly)

When `refine` builds wiki pages, they are **flat files** (no page directories - only `raw/` gets
subdirs) carrying a `kind:` in frontmatter. This keeps the load-bearing backlink-by-grep dead
simple: a link is always `[[john]]`, never a path. The starter vocabulary is open:
**entity**, **concept**, **project**, **people**, **overview**. Pages emerge the first time a
signal warrants one; no taxonomy is pre-built and no empty files are created. You do not create
any wiki page during capture.

## The trust gate

`refine` and `audit` both change **canonical** knowledge, so both run behind one shared
trust gate - the discipline that nothing canonical changes without the user's yes:

- The heavy work runs in a **clean-context subagent** that drafts every change **into the working
  tree and commits nothing**.
- The skill returns a **structured summary** (never page contents); the user reviews it, answers any
  questions, and may request edits, applied directly to the working-tree pages.
- The **landing decision goes through a structured-choice prompt** (the irreversible
  publish moment): **Approve and push** / **Request edits** / **Reject and discard**. A clear
  unprompted "approve and push it" also counts.
- **Approve** -> fold in final answers, write the `log.md` entry, then **one** `git add` of the
  touched files, **one** commit, and `git push` (when the brain has a remote).
- **Reject** -> `git checkout .` (and delete any new untracked pages); the brain is untouched, no
  trace in history.

Both are therefore **gated, not immediate**: landing (a commit, and a push when the brain has a
remote) follows approval, never precedes it - the opposite of capture, which lands immediately
because the inbox is untrusted staging.

## Page layering (settled head, open threads, history off-page)

A canonical page is structured by **settledness, not chronology**, so a reader - human or `recall` -
can tell *what is true now* from *how we got here* without parsing dates out of prose. This is the
structural complement to graded supersession (below): supersession decides what a changed fact reads
as; page-layering decides **where on the page** each class of content lives. `refine` writes pages
this way on intake; `audit` lints conformance.

Three layers, in fixed top-to-bottom order:

1. **The settled head** - everything between the `# H1` and the **first `## section`**. Present-tense
   **current truth only**: what the subject *is* now. No journey, no dates-of-change narrative, and
   **no markers** (a `> needs:` / `> contested:` is by definition not settled, so it never sits in the
   head). The head is length-unbounded - "settled" is the test, not "short"; a long head is fine as
   long as every line is current truth. Its boundary is machine-findable (the first `##`), and it is
   the one region `recall` and the `index.md` router treat as ground truth.
   - **A rejected option is a settled fact, not history** - it constrains the future ("we already
     decided against this"), so it stays in the head as a **one-line fence**, present tense:
     *"Not pursuing X - Y is the choice."* The moment a fence grows a "because back in <month> we
     tried..." clause it has become history and moves off-page. Name the rejected option and the
     current choice; nothing more.

2. **Settled `## sections`** - the deep current detail, under the same settled-now discipline as the head.

3. **`## Open threads`** (at the bottom, **omitted entirely when empty**) - the bounded zone for
   everything **not** settled: in-flight ideation and open questions, as prose. It is **self-limiting**:
   an item graduates **up** into the head/sections when it settles, or is dropped - it never
   accumulates resolved items. `> needs:` and `> contested:` markers stay **inline where they bite**
   (a hole next to the fact it punctures); a `>` marker already announces itself as unsettled and
   cannot masquerade as settled prose, so it keeps its locality. A marker with no natural section home
   lands here.

The page reads **most-settled -> least-settled**, top to bottom. That ordering is a machine-legible
**settledness signal**: `recall` trusts the head as current truth, treats `## Open threads` as
in-flight / lower-confidence, and reads `>` markers as known holes - all by structure, with no need to
infer settledness from dates scattered in prose (which is exactly where a stale fact gets returned as
current - the LongMemEval failure). The primary consumer is the **agent** (the user reads the pages only
occasionally), so the win is retrieval *correctness* and token economy, not readability.

**History lives off-page** - in `log.md` + git + `raw/` - and is **never re-narrated on the page**.
`refine` owns the handoff: when it drops a supersession contrast off a page, its `log.md` entry **must
carry that before -> after and the why** (see `log.md` below), because the page no longer does and git
holds the diff but not the reasoning. To trace a subject's journey, `grep <slug> log.md` + `git blame`
the page.

> **Splitting vs layering.** Layering de-narrates *within* a page; **splitting** de-overloads *across*
> pages when one page has grown into a **hub** carrying many durable sub-subjects. They are orthogonal -
> a page can be cleanly layered and still want splitting. Splitting is the page-tier analog of
> `index.md` sharding (the same "partition by natural cluster, route to the pieces" move). It is
> **size-bounded and audit-owned**: `audit`'s fatness detector flags a page over **~12 KB / ~8 H2** and
> proposes a split into a thin hub + peer pages, always gated - see **"Page-fatness detector and the
> page-split fix-class"** under *The audit operation*. (`refine` no longer splits; restructuring is
> audit's.)

## The refine operation

`refine` is the deliberate synthesis ritual and the first user of the **trust gate** (above): it
reads the pending inbox pointers, opens their raw docs, and distills them into canonical wiki pages
under the user's review. It is **manual** (the user invokes it) and **whole-tail** on the *inbox* (it
processes every pending pointer below the watermark in one pass) - but **incremental** on the *page
corpus* (it touches only a bounded neighborhood of pages, never sweeping the whole wiki; see "The
bounded touch-set" below). `refine` is pure **intake**; all restructuring and the deep cross-corpus
reconcile belong to `audit`. The orchestration - a clean-context subagent drafts, the parent runs the
review - lives in the `refine` skill; this section is the **conventions** that skill follows.

### The bounded touch-set (incremental)

`refine` never re-reads or re-reasons the whole page corpus. That whole-corpus cost is the mega-hub
tax (touching one fat hub pulls in its huge 1-hop closure); page-splitting (audit) shrinks each hub's
closure, and this rule makes intake **O(new facts)**, not **O(corpus)**.

- **Build the touch-set by routing, not sweeping.** For each fact distilled from the pending raw docs,
  route it via **`index.md`** (the thin routers) to its **candidate page(s)** - the page(s) the fact
  belongs on. The **touch-set** = those candidate pages **plus their 1-hop backlinkers** (the pages
  that link to a candidate via `[[slug]]`).
- **Read depth differs by role.** Open the **candidate pages in full** (they may be redrafted to fold
  the fact in). Read the **1-hop backlinkers settled-heads-only** - just enough to check the new fact
  does not contradict or supersede what their head asserts; do **not** redraft a backlinker beyond a
  direct fix, and do **not** open its deep sections.
- **Do not read outside the touch-set.** Every other page is **treated as settled** - the watermark
  already marks what has been synthesized, and untouched pages are assumed consistent. No new state is
  needed to track this.
- **Deliberately shallow - audit is the deep backstop.** The bounded read catches **direct 1-hop
  effects** at the gate. Deeper **>1-hop** supersession effects (a fact that invalidates a claim two or
  more hops away) are **`audit`'s** job - audit is the whole-corpus deep-reconcile backstop (see "The
  audit operation"). This accepts a slightly longer un-reconciled window between audits in exchange for
  fast, cheap intake; that trade is intentional.

### The gate

refine runs behind the shared **trust gate** (above), adding the gap Q&A and the watermark advance
below: the subagent drafts into the working tree, the parent runs the review, the landing decision
goes through a structured-choice prompt, and on approve the watermark moves (below) as part of the one commit.
At the end of a committed pass, **nudge `audit`** if the corpus looks due for an audit (it has
grown, or `log.md` shows no recent `audit`) - a soft nudge like the `(N pending refine)` count,
not a gate.

### The gate review - map first, then walk the questions one at a time

The gate review has two beats: an **orientation map** (the whole change-set, shown once) and then a
**one-at-a-time walk** of the open questions. Do **not** dump the map and ask for everything in one
prompt - it should feel like a step-by-step wizard, not a wall to react to.

**1. The map - self-orienting per-page blocks.** Shape the summary so the user can **judge each change
without first remembering what the page is about**. Present it as **one block per affected page**
(N pages -> N blocks), never one prose wall keyed by category. Each block:

- **Leads with the page's `index.md` gloss line** - the `- [[slug]] (kind) — <gloss>` line as it
  will read **after** this pass, tagged `NEW` (page created this pass) or `UPDATED`. That line is
  what orients: it states what the doc is about before any change is shown.
- **Shows each change concretely** beneath the gloss: a changed fact as **`before -> after`**; an
  added fact or a whole new page as **`NEW: <the line>`**. A supersession is just a `before ->
  after` whose contrast matters (preference/goal/decision reversals keep that contrast on-page
  too); a `> needs:` a distilled fact cleared is noted as a cleared change.
- **Flags its open questions under the page** - a gap question (a fact the page needs, e.g. "John's
  last name?") or an `Agent`-claim to confirm is marked in the block of the page it touches, so the
  map shows what is still pending and where. The block only **flags** them; the walk **asks** them.

After the blocks, a short **footer** holds only what is not page-scoped: the **watermark target**
(the last-consumed entry's date), and the `audit` nudge if one is due.

**2. The walk - one simple question at a time.** After the map, take the open items (gap questions,
`Agent`-claim confirmations) **one at a time** through a structured-choice prompt - each a single,
as-simple-as-possible structured question (a yes/no or a short pick), never one prompt that asks for
everything. For an **`Agent`-claim confirmation**, offer **`WIP / not-settled` as a first-class
option** (alongside confirm / drop), not something the user must reach for via the escape - a flagged
claim is often in-flight ideation, and `WIP` resolves to a `> needs:` marker on the page rather than
a canonical assertion. **Every question carries a standing free-text escape** so the user can give an
extended answer on any item, and when an item genuinely cannot be reduced to options (a nuanced
reversal, a "tell me the backstory" gap) **pose it directly as an open question** instead of forcing
a choice. Fold each answer into the drafted working-tree pages as you go (gate-time curation, not
capture; a gap the user cannot answer, or a claim the user marks `WIP`, stays as `> needs:`). The **final landing decision** is its own
structured-choice prompt (Approve and push / Request edits / Reject and discard) - the last step of the
walk; the decision is per-batch (one approve lands the pass) even though the questions were walked
singly.

### Routing a fact to a page ("earn it")

A wiki page is a stable subject (a person, project, concept, entity, or a broad `overview`). For
each fact distilled from a raw doc, route it - check `index.md` first:

1. a page for the subject already exists -> append / reconcile the fact there;
2. else the subject is stable / recurring / load-bearing enough to say something non-trivial ->
   create a flat page for it;
3. else -> attach the fact as a **line** on the most-related existing page; if none exists, seed
   or join a broad **`overview`** page for its domain (e.g. `acme.md`).

A passing one-off mention does **not** earn its own page - it stays a line and **graduates**
later once it accretes. The sizing doctrine is **size-bounded**: keep a subject dense on **one** page
until it grows into a **hub** carrying many durable sub-subjects, then `audit` splits it into a thin
hub + peers (see "Page layering -> Splitting vs layering"). Structure still must **earn its place** - a
new page, or a peer produced by a split, has to clear the stable-subject bar. A
multi-subject fact ("John owns the website's content migration") lives once, on its **primary
subject's** page (where you would look for it - here `website.md`), and the other subject gets a
`[[backlink]]`, never a restatement. Single source of truth: each fact has exactly one canonical
home; everything else links to it.

A **subject<->peer correspondence** ("the website redesign work is tracked in Todoist project X", "this lives in
GitHub repo Y") is **not** prose: route it into the page's `external:` frontmatter block per
**"External references"** below, not into the body.

There is **no special cold-start mode**. On the first refine the wiki is empty, so most facts
fall to rule 3 and a couple of `overview` pages get seeded; the first refine also creates
`index.md`. As the brain warms, facts graduate from overview lines into their own pages.

### Supersession (graded)

When a new fact conflicts with one already on a page, three tiers by what the reader needs - and in
every tier the **journey of the change goes to `log.md`, never onto the page** (see Page layering):

- **Routine factual update** (a cadence, a path, a number) -> state the **current** value, bump
  `updated:`, stop. Do **not** keep the old value on the page - it is preserved in the immutable dated
  inbox pointer + `raw/` doc + git, and on-page history is just clutter.
- **Reversal whose prior value still constrains the future** (a preference not to re-suggest the old
  option, a decision not to re-open it) -> state the current value in the **head**, plus a **single
  one-line parenthetical**, present tense: `Prefers Y (previously X).` This is the rejected-option
  fence (Page layering) in supersession form - the standing constraint, not the story. It is **one
  parenthetical**, never a narrative; the moment it wants a "because in <month>..." clause, that clause
  is history and belongs in `log.md`.
- **Everything else about how the change happened** (the sequence of attempts, the dates, the
  superseded intermediate states) is **history** -> it lives in this pass's `log.md` entry, and the
  page carries only the current truth.

Because the page no longer narrates the contrast, `refine`'s `log.md` entry **must** record the
before -> after and the why for every reversal it folds - the handoff that makes off-page history safe
(see `log.md`).

**Backlink-by-grep** (`grep '[[oldslug]]'`, repoint every linker) fires **only** when a *page* is
renamed, merged, or retired - never for fact-level updates, because other pages link to the page,
not to a fact inside it, so they pick up an in-place fact change for free.

### `index.md`

The retrieval entry point, loaded first by `recall` **and injected every session by the hook** - so
its cost is paid per session, per user, and thinness is load-bearing. A **flat** list, one line per page:

```
- [[website]] (project) — the company website redesign: launch timeline, vendor choice, the over-budget finding. Aka the site refresh.
- [[john]] (people) — John Smith, owns the website's content migration
```

Each line is `- [[slug]] (kind) — <one-line router>`. The line is a **router, not a summary**: it
states what the page **is** and carries enough keywords + alternate names to *match a query and route
to the page* (so "Smith" matches `john`, "site refresh" matches `website`) - it does **not**
recapitulate the page. This is the **two-tier** split: the index routes; the **detail lives in the
page head** (Page layering), one hop away. recall routes on the thin line, then opens the head - so a
near-miss at the index is caught at the head, and the index never needs to summarize a page to keep
recall from opening it. Discipline: **if you are tempted to add a second fact, you are summarizing -
stop.** Soft target ~150-250 chars per line. refine rewrites the affected lines every pass; the page
head having no history to pull in (Page layering) is what keeps the line from re-bloating.

**Scaling ladder (three rungs, each a distinct failure mode; climb only when a rung's trigger fires):**

1. **Thin two-tier index (now)** - fixes per-line bloat (above).
2. **Domain sharding (deferred; fixes total size / the per-session token tax).** When the flat index
   crosses **~16 KB or ~80 pages** (whichever first - about half the ~32 KiB cap some agents place on
   the merged session-context injection chain, e.g. Codex's `AGENTS.md`; size against the agent that
   enforces the smallest cap, leaving room for the static capture-offer block), shard into an
   **index-of-indexes**: top-level
   `index.md` = one router line per **area**, each `index/<area>.md` = the per-page routers for that
   area; recall loads only the area(s) it needs, and the hook injects only the top-level area routers.
   **Areas are derived dynamically at shard time** from the live `[[wikilink]]` topology (the dense
   subgraphs), named at the gate, and revisable like pages (split / merge / re-home; an area-index is
   an `overview` page one tier up) - **never a pre-declared taxonomy**. `audit` **auto-detects** the
   trigger and nudges; the shard itself is **gated** (it rewrites every index line - the largest
   canonical change there is) and its plumbing is built in that firing pass against the real areas. An
   *unattended* auto-sharder waits for a named pain (the shared multi-user brain, where no one owns
   the gate).
3. **Embedding router over the glosses (deferred; fixes routing *accuracy*, orthogonal to size).** A
   router **over** the index lines / heads with graceful fall-back to keyword + `[[wikilink]]` routing -
   **never RAG over `raw/`** (that would break the offline grep-fallback read path and the no-lock-in
   thesis). Justified **only** by repeated **confirmed** misses (recall failed to route to a page that
   *was* in the brain, from vocabulary mismatch), after rungs 1-2 are in place - distinct from a
   genuine absence (interview's) or a stale canonical fact (refine's).

### Provenance at refine (`Me` vs `Agent`)

`Me` facts are ground truth - canonicalize directly. `Agent` facts are **claims**. When an
`Agent`-sourced fact is **consequential**, **uncorroborated** by any `Me` note, and about to
become canonical, surface it in the gate summary for the user to confirm (reusing the gate's
confirm step - no special page syntax). Confirmed -> ground truth; not confirmed -> drop it or
mark `> needs:`.

### Gate-time curation is not capture

Answers the user gives at the gate (a gap filled, an `Agent` claim confirmed) fold into the
drafted pages **in this pass**. They do **not** create raw docs or inbox pointers - that is
capture, a different operation. Their provenance rides on the page's `updated:` date, the
`log.md` entry, and the commit. A gap the user cannot answer stays on the page as `> needs: <what>` and
the pass commits anyway. And the reverse: when a fact distilled this pass **answers** an existing
`> needs:` marker, **remove the marker** as you fold the fact in - the gap is filled. This is what
closes the `interview` loop (interview harvests the marker, interviews the user, routes the answer back
as a capture, and the next refine clears it); surface every clear in the gate summary.

### The watermark

The `<!-- synthesized through: ... -->` line in `inbox.md` is **positional**: everything below it
is pending. On the approved commit, move the line **down** past every entry this pass consumed,
and update its comment text to the last-consumed date for readability. A new capture always appends
its pointer **below** this line; when a refine drains every pending entry, leave one trailing blank
line after the watermark so it is never the literal last line of the file (which a capture could
misread as a footer and append above, where the next refine would never see it). There is no deferral - the
gate is binary (approve the whole batch, or reject and nothing lands); a "not ready" note is
still synthesized, just with a `> needs:` marker.

### `log.md`

Write **one** narrative entry per **committed** pass (a rejected pass writes nothing), as part of
the same atomic commit:

```
## [2026-06-11] refine
Synthesized 3 entries (watermark → 2026-06-11). Created website.md, john.md; updated index.md.
Superseded: website review cadence biweekly → weekly. Gate: confirmed John's last name (Smith) and the
over-budget finding as canonical. No gaps left open.
```

Because pages no longer narrate their own history (Page layering), `log.md` is the **sole on-system
narrative home for the journey**: git holds each diff but not the reasoning, so a thin entry loses the
why for good. An entry therefore **must** record, for every change it lands - the **before -> after of
each supersession / reversal and why** (the contrast the page dropped), each **rejected option** fenced
or removed - alongside the usual entries-synthesized / pages-touched / watermark move / gate curation.
This is the handoff that makes off-page history safe (Supersession, above).

## The recall operation

`recall` is the brain's **read path**: it answers a question by retrieving the canonical wiki
**index-first**, always cross-checks the **un-synthesized tail**, and returns a **distilled two-block
answer** - never a dump of pages. The orchestration (a clean-context subagent does the reading, the
parent presents) lives in the `recall` skill; this section is the **conventions**
that skill follows. recall is **read-only**: the only write it can trigger is a save-nudge, which
it routes through `remember` (and so through the refine gate) - it never writes a page or commits
anything itself.

### Index-first, with an always-on tail cross-check

Load `index.md` first. Its lines are **thin routers** (Page layering): use them to pick the few pages
that bear on the question, then **open those pages and read their settled heads** for the detail - the
detail lives in the head, not the index line, so routing on a thin line and opening the page is the
designed path (a near-miss at the index is caught at the head). Treat each page's **head as current
truth**, and weight its **`## Open threads` and `>` markers as in-flight / lower-confidence** - the
layering is a settledness signal, so never return an Open-thread item or a `> needs:` as a settled
fact. But the index can only see what `refine` has already synthesized, so recall **always** also greps
the **un-synthesized tail** even when the canonical answer looks complete. This is the supersession
safety net: a fact captured since the last refine is invisible to the index, and only the tail-grep
catches it.

**Slice `inbox.md` to below the `<!-- synthesized through: ... -->` watermark first**: those
pointers, and only the `raw/` docs *they* reference, are the entire tail - grep that slice and those
docs, never the whole file post-filtered. An above-watermark hit is already on a canonical page;
mislabeling it as staging would raise a **false supersession flag**, poisoning the one feature the
tail-grep exists for. The grep scope is the below-watermark tail **only** - never all of `raw/` or
all of `inbox.md`.

### The two-block answer (provenance at read time)

The answer keeps trusted and untrusted knowledge in separate blocks, never blended:

1. **Canonical answer** - distilled prose from gated pages, each claim citing its `[[slug]]`. Leads.
2. **Staging callout** - shown only when the tail-grep kept a hit; fenced off below, each hit tagged
   with its **date** and **`Me`/`Agent`** provenance. Staging is a different epistemic class
   (unverified, has not passed the gate) and must look different, not sit a footnote away.

When a staging hit **contradicts** canonical, recall names it a **possible supersession** and
recommends `refine` to reconcile - the canonical page has not caught up. recall is thus a
supersession **detector**, not just a lookup.

There is **no formal ranking or limiting** of tail hits: the tail is small by design (one refine's
worth). The subagent keeps the hits that genuinely bear on the question, never drops a conflict, and
**summarizes** instead of listing if the tail has grown large.

### Filing a good answer back

When an answer is **net-new synthesis** (it joined facts, or rests on a staging hit, into something
written nowhere yet), recall may **offer** to save it - a one-line nudge, never an automatic
write. On yes, it routes the answer through `remember` (parked as an `Agent` note, reviewed at the
next refine), the single capture path; recall never drafts a page straight into the gate. A plain
lookup that only restated a page has nothing to save, so no nudge fires.

### Invocation

recall is **dual-invocation**: the user calls it explicitly, and the agent may call it autonomously
whenever brain context would help answer better - licensed because it is read-only and low-risk. A
deferred `SessionStart` hook that injects `index.md` makes the autonomous path reliable (the agent can
then see which pages exist); recall is built dual-ready ahead of it.

### Cold and empty cases

Before the first refine there is no `index.md`, so recall runs **tail-only** (grep `inbox.md` +
`raw/`, return staging-labeled hits, note nothing is synthesized yet). When nothing matches at all, say
so honestly and stop - do not nudge a capture, there is no answer to save.

## The interview operation

`interview` is the brain's **elicitation / pull path**: it sweeps the corpus for the highest-value
**knowledge gaps**, interviews the user to fill them, and routes their answers through `remember` - the
brain initiating its own growth. It hunts **absence** (what is missing), the complement to
`audit`'s hunt for **inconsistency**. The orchestration (a clean-context subagent builds the
gap map, the parent interviews) lives in the `interview` skill; this section is the
**conventions** that skill follows. interview writes **nothing canonical** - it captures one digest via
`remember`, so the `refine` gate stays the only trust gate.

### What it hunts: Type-A (answerable) gaps only

interview asks only about gaps the user **can** answer - facts that live in their head but nowhere in the
brain (a person referenced everywhere with no page). It does **not** raise Type-B open questions
(things *nobody* has answered yet - parked design decisions, unresolved strategy); interviewing there
extracts no fact. v1 gap sources:

- **`> needs:` markers** - explicit holes `refine` planted at the gate. Zero-inference, highest precision.
- **Referenced-but-undefined/thin subjects** - found two ways: **dangling `[[wikilinks]]`** (a link
  with no target page - precise) and **repeated proper nouns with no page** (a name recurring in
  prose, never linked - inferred). Both run; the inferred ones carry a confidence tag.

### Sweep, rank by importance, map-first

Bare `interview` sweeps the whole corpus; `interview on <subject>` scopes to one subject. The subagent
**ranks by importance** - reference density (how load-bearing the undefined subject is) - with
explicit-vs-inferred as a confidence tiebreak, not the primary axis. It **slices the tail below the
watermark** (per recall's discipline) and suppresses any gap a pending capture already answers, so
it never asks about something captured-but-unsynthesized. the user sees the **top ~6 (with "more
below")** and picks; each pick is a short conversation. **Skipping carries no signal and persists
nothing** - interview is stateless; a skipped-but-important gap is meant to resurface (importance, not
skip history, buries the low-value ones).

### Capture and provenance

A interview run captures **one `Agent` session-digest** through `remember` (the this-chat-summary mode:
one `raw/sessions/` doc + pointer). **No `Me` carve-out** - interview framed the questions and
synthesized the reply, so the digest is `Agent`; the `refine` gate promotes the solid facts to ground
truth on the user's confirmation. interview commits nothing itself.

### The closed loop with refine

`refine` plants `> needs: X` when it cannot fill a gap at the gate; interview harvests the marker,
interviews the user, and routes the answer back through `remember`; the **next `refine`** folds it in
and **clears the marker**. interview only **captures**; `refine` **reconciles and clears** - neither
reaches into the other's job, which makes the two self-completing.

### Invocation

interview is **explicit-only** - unlike `recall`'s dual-invocation. It *interviews* the user, so it
must never fire autonomously; the user runs it deliberately when the user has time. (The "never build on the
model's unprompted salience" rule applies to anything intrusive, and an interview is intrusive.)

## The audit operation

`audit` is the brain's **consistency auditor** and the second user of the **trust gate**
(above): it sweeps the canonical wiki pages for **inconsistency** - the LongMemEval knowledge-rot
failure mode - drafts the unambiguous fixes, and flags the rest under the user's review. It hunts
**inconsistency**, the complement to `interview`'s hunt for **absence**. Where `refine` is **intake**
(inbox -> pages), audit is **introspection + restructuring** (pages -> pages): it audits the
**already-canonical** layer and therefore **never reads the pending inbox tail** (that is refine's
job). The orchestration - a clean-context subagent audits, the parent runs the gate - lives in the
`audit` skill; this section is the **conventions** that skill follows.

**audit OWNS all restructuring.** refine is now pure **intake** (distil the inbox into pages, shallow
and incremental); every operation that reshapes the *already-canonical* layer - **page splitting**,
index re-sharding, page merge/retire/rename, and the deep supersession reconcile - belongs to audit,
the one operation that sweeps the whole corpus. Two consequences make audit **safety-critical**, not
just hygiene: (1) it is the **deep >1-hop supersession backstop** - incremental refine only catches
direct 1-hop effects at the gate, so a newer fact that supersedes a claim two or more hops away is
audit's to catch; (2) it owns the **page-fatness detector + split fix-class** (below), the keystone of
the size-bounded page doctrine. Because audit is now more important **and** fired more often, it gets
its **own** age/change nudge, decoupled from the refine-end nudge (see **Invocation**).

### What it audits (scope)

- **Whole-corpus sweep by default**; `audit on <subject>` scopes to one page and its
  backlinkers (mirrors `interview on <subject>`). The subagent reads **index-first** and opens a page
  fully only when a candidate inconsistency is there.
- **Audit subject = the wiki pages + `index.md`.** `RULEBOOK.md` (this rulebook) is trusted
  **reference**, not an audit subject: when a page contradicts the rulebook, the **page loses** (it is
  the stale one).
- **No incremental** - a sweep cannot miss a cross-page contradiction the way an "only what changed"
  audit would (the two clashing pages may have changed in different runs). Completeness is the value.
  If a sweep ever must cap coverage, **say so** - no silent caps.
- **Out of scope:** the pending tail (refine's), the filesystem / plugin repo (audit covers
  the brain repo, not whether a skill file exists elsewhere), and Todoist (not the brain).

### Detection taxonomy and the two response classes

Each finding is either **auto-fixable** (drafted into the working tree) or **flag-only** (presented at
the gate for the user's call):

- **Mechanical.** index/page desync (gloss points at a missing page, a page missing from the index, a
  gloss that misstates its page) -> **auto-fix**. Orphan pages (in the corpus, nothing links to them)
  -> **flag**. **`external:` reference lint** - *structural* well-formedness (each `external:` entry
  has a `system` + a `ref`) -> **flag** malformed entries (no auto-fix: the brain cannot guess the
  right value). **Live** resolution-checking of `external:` refs and dead in-prose links (does the
  target still resolve in the peer) is **deferred to v1.1** (needs live network fetches; lowest value)
  and is **flag-not-fix** when built. See **"External references"**.
- **Semantic.** **Clean dated supersession** (same subject, a newer-dated fact a page never folded in)
  -> **auto-fix** per the graded-supersession rule. **Genuine contradictions** (no clear temporal
  winner) and **stale claims** -> **flag**.
- **Layering conformance** (page vs the Page-layering rule). A `> needs:` / `> contested:` marker
  sitting **in the head** (above the first `##`) -> **auto-fix**: move it down to its section or to
  `## Open threads`. **History narrated on a page** (a dates-of-change journey, a "was X then Y"
  sequence, a superseded intermediate state the page kept), **WIP that reads as settled** (in-flight
  prose in the head or a settled section rather than `## Open threads`), and an **`## Open threads`
  hoarding resolved items** -> **flag** (deciding settled-vs-history is judgment; a wrong auto-fix
  would delete real settled knowledge). Same page-vs-rulebook shape as the stale-claim check - the page
  loses.
- **Index scaling-trigger (detector, not a fix).** Check the flat `index.md` size / page count against
  the sharding trigger (**~16 KB or ~80 pages**). If crossed, **nudge** ("index past the shard
  threshold; consider a gated re-shard") - the shard is a gated **audit-class** restructure (audit owns
  restructuring), never an auto-fix. See **`index.md` -> Scaling ladder**.
- **Page-fatness trigger (detector, not a fix).** Check every page against the fatness threshold
  (**>~12 KB or >~8 `## H2` sections**). A page over it is **flagged** with a proposed **split map**
  (which section-clusters become which peers); the split itself is a **gated fix-class**, never an
  auto-fix, and is **drafted only on the user's yes** - see **"Page-fatness detector and the page-split
  fix-class"** below.
- **Seam with `interview` on links.** A dangling `[[wikilink]]` to a subject that **never had a page** is
  **interview's gap** (absence) - leave it. An **orphan page** (the inverse) is audit's. A
  **rename-orphaned** link - a dangling `[[slug]]` whose target exists under a **new** slug (a rename
  backlink-by-grep missed) - is audit's: **repoint it**.

### Page-fatness detector and the page-split fix-class

**The doctrine (reversed).** The old rule was "bias toward fewer, denser pages." The rule now is
**size-bounded: dense until a page becomes a hub, then split.** A page stays a single dense page for as
long as it is one subject; once it has grown to carry a cluster of durable sub-subjects, it is a **hub**
and audit splits it into a thin hub + one peer page per sub-subject. This is the page-tier analog of
`index.md` sharding (partition by natural cluster, route to the pieces), and audit owns it.

**The detector (read-only, every sweep).** Flag any page over the fatness threshold - **>~12 KB or
>~8 `## H2` sections** (whichever first; tunable, not sacred). A flag is **not** a fix: it carries a
proposed **split map** and nothing is drafted until the user says split.

**The split map** (what the flag proposes):
- The **thin hub** keeps its **settled head** (the current-truth paragraph about the subject as a
  whole) plus a new **`## Subpages`** router-list section - one `- [[peer]] - one-line gloss` line per
  peer, placed immediately after the head. It may also keep genuinely cross-cutting settled sections
  that belong to no single peer.
- Each **peer** gathers a **cluster of related `##` sections by durable sub-subject** - never 1:1 per
  section, and a peer must clear the same "stable subject" bar as any page. The target: **every**
  resulting page (hub and each peer) lands **back under the fatness threshold**.
- Peers are **flat, first-class pages**: each gets its **own `index.md` router line**, its own
  frontmatter (`kind:`, `updated:`, `external:`), and a layered head - reachable directly off the
  index like any page (not a hidden sub-tier). Splitting therefore **feeds the one flat index**, and
  the index scaling ladder (~16 KB / ~80 pages, rung 2) absorbs the resulting growth.
- **Peer naming is hub-prefixed:** a `website.md` hub yields `website-content`, `website-launch`. This
  is a naming *convention on a flat slug* for collision-resistance and discoverability - **never a
  path** (`[[website-launch]]`, not `[[website/launch]]`), so backlink-by-grep is unchanged. If a facet
  is genuinely an independent subject, it should be its own bare-named page reached by a normal
  `[[link]]`, not produced as a peer.

**Link and reference handling at the split:**
- **`external:` refs follow their subject.** A ref about the *whole* subject (e.g. the project's task
  list) **stays on the hub**; a ref specific to a *facet* (e.g. a task project tracking just that
  facet's work) **migrates to that facet's peer**. "Which subject does this ref serve" is judgment, so
  each migration is **confirmed at the gate** (like a backlink repoint), never auto-applied.
- **Inbound `[[hub]]` backlinks stay on the hub.** The hub still exists and now **routes onward** via
  `## Subpages`, so an existing `[[hub]]` link is never broken - at worst the reader takes one extra
  hop (exactly like index -> page). Repointing an inbound link to a specific peer is an **optional,
  per-link, gate-confirmed refinement** that **defaults to no-op**; it is judgment with **no cheap
  undo**, so it only ever fires when the user asks for it.
- **Outbound links inside a moved section travel with that section** to its peer (they live in the
  prose that moved); the hub does not retain them.

**Always gated, drafted-on-yes, per-page approval.** The split is the largest, least-reversible
canonical change audit makes, so:
1. The detector only **flags** fatness and shows the split map in the findings summary - cheap, every
   sweep. It drafts nothing.
2. The heavy drafting (create peers, move section-clusters, write `## Subpages`, add `index.md` lines,
   apply confirmed ref migrations / backlink repoints) happens **only after the user says "split this
   one"** at the gate - drafted into the working tree, committed only on approval.
3. A split gets its **own explicit approval**, never folded into a blanket "approve all" batch. It has
   **no cheap undo** once landed (the peers exist, sections have moved), so it is deliberate.

**Recursion is uniform.** The detector applies to **every** page, peers included. A peer that later
crosses the threshold is split exactly like any hub - it becomes a hub itself, its sub-peers prefixed
off *its* slug (`website-launch` -> `website-launch-marketing`). No special-casing and no nesting cap;
clustering + the size-bound keep chains shallow in practice.

> **Deferred: merge-back (un-split).** The *inverse* - automatically recombining a hub whose peers
> have over-shrunk, or folding a withered peer back in - is **not built**. Refers to: a hub + its peers
> collectively falling back under threshold, or a peer decaying to a near-empty stub, after
> supersession/removal has thinned them over time. **Why deferred:** it is not in the settled design;
> audit's existing **thin-page / orphan / stale-claim flags** already surface the symptoms for the user
> to fold back by hand at the gate; and merge is pure judgment with no cheap undo, so automating it
> earns nothing over a flag. **Named trigger to build it:** only if over-splitting proves to actually
> bite in practice.

### The `> contested:` marker

When audit finds a contradiction it cannot auto-resolve, the gate tries first: the user usually
knows which fact is stale, picks the winner, and the resolution is drafted that pass (gate-time
curation, not a capture). **On defer**, plant a **`> contested:`** marker - distinct from refine's
`> needs:` (which marks a *hole*, an absence). A contradiction is a *clash* of two present facts, so it
gets its own marker, placed **once** on the canonical page for that fact, citing the dissenting page:

```
> contested: launch scope - website.md: full-site (2026-03) vs marketing.md: homepage-only (2026-06). Unresolved.
```

The pass still commits with the marker in place. **Lifecycle:** audit **plants and clears** it
(a later pass, once the user resolves); `recall` surfaces it for free when it reads the page; `interview`
does **not** harvest it (a clash is not an absence). It is distinct from refine's graded-supersession
contrast (`Prefers Y as of <date> (previously X)`), which is *resolved-with-history*; `> contested:` is
*unresolved*. (It is also the single-brain seed of the parked multi-brain "attributed claims" idea -
two dated self-notes disagreeing is the same shape as two people disagreeing.)

### `log.md`

One narrative entry per **committed** pass (a clean bill of health or a rejected pass writes nothing):

```
## [2026-06-12] audit
Swept 8 pages. Fixed: index gloss for website.md; folded the weekly cadence into website.md (superseded
biweekly). Repointed 1 rename-orphaned link. Flagged: orphan page old-notes.md (retire?). Contested:
planted the launch-scope clash on website.md. Cleared: 1 prior contested on john.md.
```

**A page split is recorded in full** (it is the least-reversible change and off-page history is its
only home): the hub, each peer created with its `index.md` line, which section-clusters moved to which
peer, each `external:` ref migrated (from -> to) and each inbound backlink repointed (from -> to), and
why the split fired (which fatness threshold it crossed). Example: `Split website.md (over threshold)
into thin hub website.md + peers website-content, website-launch. Moved <sections>. Migrated external
ref X to website-launch. Left all inbound [[website]] backlinks on the hub (no repoints).`

### Invocation

**Manual and attended** on the fix side, like `refine` - it changes canonical knowledge, so it runs
behind the gate and is never autonomous. Detection is read-only and safe, but the fix path stays gated
and deliberate.

**audit has its OWN age/change nudge, decoupled from the refine-end nudge.** Audit used to be prompted
*only* at the end of a refine pass, which fails now that audit is the safety-critical >1-hop
supersession backstop: if refine runs rarely, audit would never be nudged, and rot would accumulate
unchecked. So audit gets an **independent** trigger computed from two signals:

- **Age** - days since the last `## [date] audit` entry in `log.md`.
- **Change** - canonical pages added or modified since that date (from `git log` over the wiki pages).

When the brain is **due** - roughly **>~14 days since the last audit, or >~10 pages changed since**
(tunable, not sacred) - nudge a run: *"N days / M pages changed since the last audit - run audit?"*
This fires at a **natural wrap-up** (the same attended moment the capture nudge uses), so it does not
depend on a refine happening. The **refine-end nudge stays** as a secondary trigger, but it is no
longer audit's only path to attention. Both are soft nudges, never a gate or a scheduled autonomous run.

## External references (peer pointers on canonical pages)

A canonical page may point outward at **live external sources** relevant to its subject - a Todoist
project, a GitHub repo, a CI pipeline - so the brain remembers *that the live source exists*,
not only the raw docs it once ingested. This breaks the "only ingested documents matter" limit while
changing **nothing** about the trust process: an external reference is just another canonical fact,
created at the `refine` gate like any other. (It is a deliberate extension of `cite-by-pointer` -
which points a *raw doc* at its mutable source - to the **canonical-page** layer: a page pointing at
a *live peer* for its subject going forward, not at the provenance of one capture.)

**The brain holds the pointer; the peer owns the meaning and every write.** The reference records only
the *shape* `{system, ref}` - which peer, and the id/uri inside it. The brain never resolves it, never
calls the peer, never writes anywhere outside this repo. Resolving a reference - reading the peer, or
using the brain **as the source of truth to update** the peer (the motivating case: "audit the website redesign
project" -> load `website.md` -> see its Todoist link -> push the brain's truth into Todoist) - is the job
of the **session model as joiner** plus the peer's own tooling (e.g. the `todoist` plugin's skills),
**not** of brrain. brrain stays strictly **read-only**; it imports no peer SDK.

**Schema - a page-level `external:` list in frontmatter:**

```
---
kind: project
updated: 2026-06-20
superseded_by: null
external:
  - system: todoist
    ref: "6gqQrm48FhhXJqf6"
    label: "website redesign tasks"
  - system: github
    ref: "https://github.com/acme/website"
    label: "website repo"
---
```

- **`system`** - the peer namespace, a lowercase convention string (`todoist`, `github`, ...). There
  is **no registry**: the joiner binds `system` to whatever peer tooling is installed at act-time. The
  brain knows the shape, never the meaning.
- **`ref`** - the id or uri the peer resolves (the `id|uri` of `{system, id|uri}`). Opaque to the brain.
- **`label`** - a one-line human gist so a reader knows what it points at without resolving.

**Page-level, not fact-level.** References belong to the page's *subject*, in frontmatter. There is no
inline / section-level link syntax: if one page accumulates a distinct cluster of peers, that is the
brain's standing signal to **split the page** (`audit`'s page-split fix-class - refs then follow their
subject to the peers), not to add sub-page anchors.

**One-directional (brain -> peer).** Only the brain stores the link; the peer stores no back-pointer.
The reverse direction ("I'm in this Todoist project, what does the brain know?") is already free via
subject `recall`, so persisting a back-link into every peer would only double the rot surface for no gain.

**Created at the gate, never by a side-door.** An external reference is a knowledge claim, so it rides
the **normal capture -> refine** path: you `remember` the correspondence (or a session surfaces it) and
`refine` distills it into the page's `external:` block under review - same as any prose change. There is
no "link this now" command that writes a canonical page outside the gate.

**Rot - structural lint now, at-use detection, live-check deferred.** A `ref` can go stale (a deleted
project, a moved repo). Three tiers, cheapest first:
1. **Structural lint (now, in `audit`)** - pure local parsing, no peer contact: each `external:` entry
   is well-formed (has `system` + `ref`). A malformed entry is **flagged** (no auto-fix - the brain
   cannot guess the right value).
2. **At-use detection** - the real safety net: when an act/sync flow resolves a reference to act on the
   peer and the peer says "gone", the rot surfaces *then*, in context, with the user present to fix it.
   No background machinery is needed to discover it.
3. **Live resolution-check (deferred to audit v1.1)** - periodically pinging each peer to confirm every
   `ref` still resolves. This is the same "dead external links need live network fetches" item audit
   already defers; **flag-not-fix**, lowest value, built only if rot proves to actually bite.

## Operating rules

- This brain is git-backed; every operation **commits locally**. **If the brain has a remote**,
  skills `git pull` before the operation and `git push` after; a **local-only** brain simply keeps
  its commits local (no remote, no push). After a capture: `git add` the new raw doc and
  `inbox.md`, `git commit`, and push if there is a remote - capture lands as soon as it is
  committed (it is untrusted staging; it cannot corrupt knowledge). `refine` and audit touch
  canonical knowledge, so they produce a reviewable diff and **never land without approval** -
  that is the trust gate.
- One commit per capture, covering the raw doc + its pointer together. The commit message is a
  readable summary of what was logged.
- Honor the sensitive deny-list and the brain-worthy criteria at capture time.
- Plain hyphens in all writing. Never em or en dashes.
- You reach this repo from inside other working sessions via the **active-brain entry in the engine
  registry** at `~/.brrain/registry.json` (its `active` field), maintained per device by the `setup`
  skill - there is no environment variable. If the registry is missing or has no active brain, stop
  and point the user to `setup` rather than guessing a path.
