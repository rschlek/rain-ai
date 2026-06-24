# Your second brain (brrain)

A durable, git-backed, plain-markdown knowledge base of your projects, areas, and people - the
memory layer of your AI setup. You talk to it through the `brrain` skills; an agent does the
reading and writing, so the knowledge compounds over time instead of being re-explained every
conversation.

This README is the human manual: what the brain is, how information flows through it, and what
each tool is for. It is a reference, not a script - you do not need to read it end to end to use
the brain. The full operating rulebook the agent follows lives in `RULEBOOK.md`.

## The idea

Synthesize once, then update - instead of recomputing from scratch every time. Raw material is
kept separate from synthesized knowledge: capture is cheap and dumb (it just parks a source and a
pointer), and a deliberate later pass (`refine`) distills those into clean, cross-linked wiki
pages that you approve. The model then reasons over the pre-digested pages. At personal scale this
beats search-over-everything: the maintenance burden that kills human wikis is handed to the
agent, which does not get bored or forget to update a cross-reference. (Pattern: Karpathy's LLM
Wiki.)

The one rule that makes it trustworthy: **nothing becomes canonical knowledge without your yes.**
Capture parks freely into untrusted staging; only `refine` (and `audit`) change the canonical
pages, and both stop for your review before anything lands.

## How information flows

```
  you ── remember ──>  raw/  +  inbox.md            capture: cheap, immutable, untrusted staging
                            |
                         refine                      the trust gate - you review and approve
                            |
                            v
                  wiki pages  +  index.md            canonical, deduplicated knowledge
                            |
  you <── recall ───────────+                        reads the pages back to answer questions

  interview   hunts what is MISSING and asks you to fill it      (growth)
  audit       lints the pages for CONTRADICTIONS and stale facts (consistency)
```

A capture writes one immutable source doc to `raw/` and one pointer line to `inbox.md` - that is
all. The pointers pile up until you run `refine`, which reads them, drafts canonical pages, and
asks for your approval before committing. `recall` reads the finished pages (and also peeks at the
not-yet-refined tail). `interview` and `audit` keep the brain healthy over time.

## The tools

Each is a skill you invoke (e.g. `remember`, `recall`). Six in all:

- **setup** - one-time per device. Creates a new brain or connects this device to an existing one,
  and records where it lives so every session can reach it. Run this first.
- **remember** - capture a note. A dictated fact, a summary of this chat, a mine of past work, or a
  document. It parks the source and a pointer; it never edits canonical pages. Low-stakes by design.
- **recall** - ask the brain a question. It reads the canonical pages first, also checks the
  un-refined capture tail, and gives a distilled, cited answer. Read-only.
- **refine** - the synthesis pass. Distills the pending captures into canonical wiki pages and
  `index.md`, then stops for your review. This is the trust gate: nothing canonical changes without
  your approval. Run it when captures have piled up.
- **interview** - the brain hunting its own gaps. It finds subjects referenced but never defined and
  interviews you to fill them, then captures the answers. You run it deliberately.
- **audit** - the consistency check. It sweeps the canonical pages for contradictions, stale claims,
  and index drift, drafts the safe fixes, and flags the rest for your call.

## What lives where

- **`RULEBOOK.md`** - the agent's operating rulebook (how every operation works). The source of truth
  for behavior. (`AGENTS.md` and `CLAUDE.md` are thin entry files that orient an agent opening the
  repo and point here.)
- **`inbox.md`** - the append-only capture stream. Untrusted staging; a watermark marks how far
  `refine` has synthesized.
- **`raw/`** - immutable source docs, one per capture. The permanent record the brain can always
  return to. Created on the first capture.
- **wiki pages** (flat `*.md` files) - the canonical, cross-linked knowledge, produced by `refine`.
- **`index.md`** - the retrieval entry point: one router line per page. Created on the first refine.
- **`log.md`** - the operations journal: what `refine` and `audit` did and why, and the home for
  history that the pages deliberately do not narrate.

A brand-new brain has only `RULEBOOK.md`, the `AGENTS.md` / `CLAUDE.md` entry files, `inbox.md`,
`log.md`, this README, and the Obsidian view config. `raw/`, the pages, and `index.md` appear the
first time you capture and refine.

## Local or synced

The brain is a git repo and works fully **local-only** - every operation just commits locally. If
you give it a remote, the skills pull before and push after each operation, so the same brain
follows you across devices. Either way the local commit history is your durable, reviewable record.

## Viewing it

The brain doubles as an Obsidian vault (open this folder as a vault). The bundled `.obsidian`
config sets a read-only-friendly reading view and hides `raw/` from the graph. Treat Obsidian as a
**viewer** - editing is the brrain skills' job, never a manual edit, so the agent stays the single
writer and history stays clean.
