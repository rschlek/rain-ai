# CLAUDE.md - orientation for Claude in this repo

This repository is a **brrain second brain**: a durable, git-backed, plain-markdown personal
knowledge base, maintained by the brrain engine (a portable set of agent skills). This file is a
thin orientation for Claude when it opens the repo directly. It is the neutral `AGENTS.md`
orientation plus a short Claude-specific appendix; the baseline below is kept in sync with
`AGENTS.md` by hand (there is no generator). The real detail is read on demand from `RULEBOOK.md`,
never inlined here.

## What lives here

- `RULEBOOK.md` - **the operating manual.** How the brain is structured and how to run every
  operation (capture, refine, recall, interview, audit) correctly. **Read it before you touch
  anything in this repo.** It is engine-neutral and is the authoritative rulebook; treat it as
  ground truth.
- `README.md` - the human manual: what the brain is and how information flows through it.
- `inbox.md` - the append-only capture worklist (pointers to `raw/` docs, below a synthesis
  watermark). `index.md` - the retrieval entry point (appears after the first refine).
- `raw/` - immutable source docs. The canonical wiki pages are the flat `*.md` files at the repo
  root, cross-linked with `[[wikilinks]]`.

## The two reflexes you help run

- **Write at wrap-up (capture nudge).** When a session produces something durable that lives nowhere
  else queryable - a decision and *why*, a strategic reframe, an open question, a hard-won finding -
  offer once to capture it (the `remember` operation). Default to silence for routine work. The
  judgment gates the *offer*, not the capture.
- **Read on demand.** To answer a question from the brain, retrieve index-first and always
  cross-check the un-synthesized tail (the `recall` operation). Reach for it whenever brain context
  would help - it is read-only and low-risk.

## How operations run

Each operation is a brrain skill. Capture (`remember`) lands immediately (the inbox is untrusted
staging). Synthesis and consistency operations (`refine`, `audit`) change **canonical** knowledge
and therefore run behind a **trust gate** - they draft into the working tree and commit **nothing**
until the user approves. Never edit canonical pages by hand outside that gate; let the skills do it
so provenance and the log stay intact. Follow `RULEBOOK.md` for the conventions of each.

## Claude Code specifics

- The brrain engine ships as a Claude Code plugin. Its operations are invocable skills, namespaced
  `brrain:` - `brrain:remember`, `brrain:recall`, `brrain:refine`, `brrain:interview`,
  `brrain:audit`, and `brrain:setup`. Prefer invoking the skill over hand-editing brain files.
- A `SessionStart` hook ships with the plugin: when a brain is active on this device it injects the
  capture nudge into every session, and once the brain has been refined it also injects `index.md`
  so you can see which pages exist and reach for `brrain:recall` autonomously. If you are reading
  this file, the hook context may already be present - this file is the fallback when it is not.
- The active brain is resolved from the engine registry at `~/.brrain/registry.json` (its `active`
  field), maintained by `brrain:setup`. There is no `BRRAIN_PATH` environment variable.
