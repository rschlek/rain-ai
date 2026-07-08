---
name: setup
disable-model-invocation: true
description: >-
  Per-device setup and brain management for the user's second brain (brrain): a menu to CREATE a
  new local brain from the bundled template, MANAGE / SELECT brains (register an existing local
  directory, switch which brain is active, list them, or clone an existing brain from a remote
  URL), or show STATUS. It keeps a small per-device registry at ~/.brrain/registry.json whose
  active entry every session and every brrain skill reads to find the brain. Use when the user
  sets up the brain on a new machine, creates a brain, switches or lists brains, when another
  brrain skill reports no active brain and points here, or when the user says "set up the brain",
  "create a brain", "new brain", "switch brain", "which brain is active", or "clone my brain". Do
  not use to capture notes (that is brrain:remember) or for cloning unrelated repos.
---

## What this skill does

The brain is a **second-brain engine** (the brrain plugin) pointed at **brain content that lives
in its own git repo**. The engine ships in the plugin; the knowledge lives in the repo. Setup is
the seam between them: it makes a brain reachable from any session by recording its path in a small
per-device **registry**. Every brrain skill and the session-start hook read that registry's
`active` entry to find the brain. There is no environment variable - the registry is the single
source of truth, so the engine works on any platform whose hook and skill processes do not reliably
inherit the session environment.

This skill is a small **menu** with three actions:

1. **Create a new brain** (local-only) - stand up a brand-new empty brain from the bundled template.
2. **Manage / select brain** - register an existing local brain, switch which one is active, list
   them, or clone an existing brain from a remote URL (a safe join that preserves multi-device sync).
3. **Show status** - the active brain, the registry, and its path.

Local-only is fully supported: a brain with no remote simply keeps its commits local, and every
brrain skill no-ops its pull/push. A remote is optional and only adds cross-device sync.

## The registry

A device can hold more than one brain (e.g. a personal one and a work one). The registry is a
minimal, additive per-device file at **`~/.brrain/registry.json`** - the engine's neutral,
per-device state directory (`~/.brrain/` holds engine bookkeeping only; brain **knowledge** always
lives in the brain repo, never here):

```json
{
  "version": 1,
  "active": "/abs/path/to/the/active/brain",
  "brains": [
    { "name": "my-brain", "path": "/abs/path/to/the/active/brain" },
    { "name": "work-brain", "path": "/abs/path/to/another/brain" }
  ]
}
```

- `active` is the absolute path of the brain in use. It is the **single source of truth** for which
  brain is live: the hook and every skill read `active` directly from this file. Switching a brain
  is just rewriting `active` - nothing else on the device changes.
- The file is **additive**: read it, merge, write it back. Never drop an existing entry.
- It is per-device config (paths differ per machine), so it lives under `~/.brrain`, never in a
  brain repo or this plugin. You read/write this JSON file directly (it is not a settings file and
  needs no settings-editing skill).

### Migration from the legacy env-var setup

Earlier versions recorded the active brain in an environment variable (`BRRAIN_PATH`) and kept the
registry under `~/.claude/`. On any device that still carries that legacy state, migrate it on the
first run of this skill, additively and once:

1. If **`~/.brrain/registry.json` does not exist** but **`~/.claude/brrain-registry.json` does**,
   copy the latter to the new location (create `~/.brrain/` first).
2. If neither registry exists but a legacy **`BRRAIN_PATH`** value is present in the environment,
   seed a fresh `~/.brrain/registry.json` with that path as the sole, active brain.
3. The legacy `BRRAIN_PATH` env var is no longer read by anything. Leave removing it to the user (or
   offer to point them at the settings-editing skill); the registry alone now drives the engine.

## Pick the action

If the user's request already names the action ("create a brain", "switch to my work brain",
"what brain is active"), go straight to it. Otherwise present the three actions above through a
structured-choice prompt and route on the choice.

Before any action, read the current state once: the registry at `~/.brrain/registry.json` if it
exists (running the migration above first if the new file is absent).

---

## Action: Create a new brain (local-only)

An agent-driven procedure - no bundled script, so it stays portable.

1. **Choose a location and name.** Suggest an OS-appropriate default next to the user's other
   repos and ask them to confirm or override:
   - Windows: `C:\Code\brrain` (or `%USERPROFILE%\brrain`).
   - macOS / Linux: `~/brrain` (or `~/Code/brrain`).
   Resolve the target to an **absolute** path. Ask for a short **name** for the registry (default:
   the directory's basename).
   - If the target directory already exists and is **non-empty**, stop. Do not clobber it. If it
     is already a brain (has `inbox.md` and a `RULEBOOK.md` or `AGENTS.md`), offer to **register**
     it instead (see Manage / select). Otherwise ask for a different path.

2. **Create and initialize.** Make the directory and `git init` it.

3. **Seed from the template.** Copy the entire contents of
   `${CLAUDE_PLUGIN_ROOT}/assets/brain-template/` into the new directory, **including hidden
   files** (`.gitignore`, `.gitattributes`, and the `.obsidian/` config) and the entry / rulebook
   files (`AGENTS.md`, `CLAUDE.md`, `RULEBOOK.md`), `README.md`, `inbox.md`, `log.md`. Do **not**
   create `index.md`, `raw/`, or any wiki pages - those appear at the first capture and refine.

4. **Initial commit.** Inside the new repo: stage all the seeded files and commit, e.g.
   `git add -A && git commit -m "Seed brain from brrain template"`. (A plain `git add -A` is safe
   here - the repo is brand-new and contains only template files.) The brain is **local-only**:
   no remote, no push.

5. **Update the registry (additive).** Read `~/.brrain/registry.json` (if absent, start
   `{ "version": 1, "active": null, "brains": [] }`). Then, in order:
   - **Auto-register the current active brain first.** If `registry.active` is set and its path is
     **not** already in `brains[]`, add it now (name = its basename) - never orphan the active brain.
   - **Add the new brain** `{ name, path }` to `brains[]`.
   - Write the file back.

6. **Active brain decision (never silently repoint).**
   - If there was **no** active brain before (first brain on this device), make the new one active
     automatically: set `registry.active` to its path.
   - If a brain **was** already active, **ask** (via a structured-choice prompt)
     whether to **switch** to the new brain or **keep** the current one. On switch: update
     `registry.active`. On keep: leave it unchanged (the new brain is registered but inactive).

7. **Light handoff.** Close with the message in **Closing handoff** below.

---

## Action: Manage / select brain

Pick the sub-action from the user's request, or offer these:

- **Register an existing local brain.** Ask for the directory path. Verify it is a brain (has
  `inbox.md` and a `RULEBOOK.md` or `AGENTS.md`); if not, stop and say so. Add it to the registry
  (additive, auto-registering the current active brain first as above). Then run the **active brain
  decision** (step 6 above): auto-activate if none active, else ask switch-or-keep.

- **Switch the active brain.** Show the registry's brains and let the user pick one (via a
  structured-choice prompt). Set `registry.active` to its path and write the registry
  back. The change takes effect immediately - every skill and the next session-start hook read the
  new `active` from the file.

- **List brains.** Print the registry: each brain's name and path, with the active one marked.

- **Clone an existing brain from a remote URL** (the safe join - preserves multi-device sync of an
  already-existing private brain). Ask for the **remote URL** and a **target directory** (default
  as in Create, step 1). Then:
  1. `git clone <remote-url> <path>`. If the directory already exists and is a valid clone of that
     repo, reuse it (just register the path). If the clone fails on authentication, this device
     lacks access to that remote (for an SSH remote, its key is not registered with the host) -
     stop and tell the user to grant access, then re-run.
  2. Verify the clone has `inbox.md` and a `RULEBOOK.md` or `AGENTS.md`.
  3. **Ensure the Obsidian viewing config (idempotent, non-destructive).** If the clone has **no**
     `.obsidian/app.json`, copy `${CLAUDE_PLUGIN_ROOT}/assets/obsidian/app.json` and
     `graph.json` into `<path>/.obsidian/` (creating the dir). **Never overwrite** an existing
     `.obsidian` config - a brain that already carries one keeps its own. Leave the dropped files
     as an uncommitted working-tree change; whether the config travels is the brain repo's call.
  4. Register it (additive) and run the **active brain decision**.

  Cloning here only **connects to an already-existing** brain. Creating a remote for a brand-new
  brain, adding a remote to a local one, and any org/sharing flow are out of scope for this skill.

---

## Action: Show status

Read the registry, then report concisely:

- The **active brain**: its name and path, and whether it has a remote (`git -C <path> remote`).
  Note whether `index.md` exists yet (i.e. whether it has been refined).
- The **registry**: all brains, active one marked, and the registry file path.
- If there is no registry or no active brain, point the user to **Create a new brain**.

---

## Closing handoff

After creating (or first-activating) a brain, close with a short **orientation**: name the first
step, sketch how the engine works, list the tools, and cover Obsidian for viewing. Keep it a tour,
not a lecture - do **not** force a first capture, seed an elicitation, or walk through the rulebook.
Deliver it in the user's own OS terms (use the actual brain path, the right Obsidian download for
their platform). Something like:

> **Your brain is created and active** at `<brain path>`. Use **`remember`** to capture your first
> memory whenever something worth keeping comes up - that is the only habit you need to start.
>
> **What it is.** A durable, git-backed, plain-markdown knowledge base you talk to through skills.
> An agent does the reading and writing, so knowledge compounds instead of being re-explained every
> conversation.
>
> **How it works.** Capture is cheap and parks into untrusted staging; a later **`refine`** pass
> distills those into clean, cross-linked pages that you approve. The one rule that makes it
> trustworthy: **nothing becomes canonical knowledge without your yes.**
>
> ```
> you ── remember ──> raw/ + inbox.md      capture: cheap, immutable, staged
>                          │
>                       refine              the trust gate - you review and approve
>                          v
>                 wiki pages + index.md     canonical, deduplicated knowledge
>                          │
> you <── recall ──────────┘               reads the pages back to answer questions
> ```
>
> **The skills.**
> - **`remember`** - capture a note (fact, chat summary, a mine of past work, or a document). Never
>   edits canonical pages; low-stakes by design.
> - **`recall`** - ask the brain a question. Reads the canonical pages, peeks at the un-refined tail,
>   gives a cited answer. Read-only.
> - **`refine`** - the synthesis pass. Distills pending captures into pages + `index.md`, then stops
>   for your approval. Run it when captures pile up.
> - **`interview`** - the brain hunting its own gaps: finds subjects referenced but never defined and
>   interviews you to fill them.
> - **`audit`** - the consistency check: sweeps the pages for contradictions, stale claims, and index
>   drift, and flags what needs your call.
>
> **Viewing it in Obsidian (optional).** [Obsidian](https://obsidian.md) is a free local app for
> browsing markdown - your brain is already a valid Obsidian vault (a `.obsidian` view config ships
> inside it). To use it: download Obsidian from **https://obsidian.md/download**, install it, then
> choose **"Open folder as vault"** and select `<brain path>`. Treat Obsidian as a **read-only
> viewer** - editing is the skills' job, so the agent stays the single writer and the git history
> stays clean.
>
> The full manual is in the brain's `README.md`. Ask me to explain any part of how it works, anytime.

Trim to fit the moment - if the user is clearly experienced with the brain (e.g. this is a second
device via clone, not their first brain), lead with the path and the Obsidian note and keep the rest
brief. The full detail lives in the brain's `README.md`; this handoff points there rather than
reproducing it.

## Notes

- **Idempotent.** Safe to re-run. Creating into an existing brain offers to register instead;
  registering an already-registered path is a no-op; switching is always reversible.
- Setup only establishes **access and the registry** (plus, on clone, the local Obsidian viewing
  config). It never creates or edits brain **knowledge** - pages, `index.md`, `inbox.md` content,
  and `raw/` docs are the other skills' job.
- **Index-injection hook.** A session-start hook ships with this plugin (`hooks/hooks.json` +
  `scripts/inject-index.sh`). It reads the active brain from `~/.brrain/registry.json`: until setup
  has run it is a silent no-op, and on a brand-new empty brain it primes only the capture nudge
  (there is no `index.md` to inject until the first refine). On the **default host**, enabling
  `brrain` installs the hook automatically. **On Codex, plugin hooks are off until the device-wide
  `hooks` feature is enabled in `~/.codex/config.toml` and each hook is trusted once via `/hooks`** -
  a one-time Codex device setup, separate from brrain and outside this skill's job. Once that is
  done, trust the brrain `SessionStart` hook at the `/hooks` prompt; the same `hooks/hooks.json`
  works on both hosts unchanged.
