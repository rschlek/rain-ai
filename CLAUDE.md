# CLAUDE.md

Guidance for any Claude session working in this repo. **rain-ai** is a
**public, shareable** Claude plugin marketplace whose job is getting people and
machines *set up*: device bootstrapping and the global settings every other
plugin builds on. It is the front door to a Claude-as-an-OS workflow.

This repo is deliberately separate from any private/work marketplace. Keep it
that way: **nothing private, personal-identifying, or work-specific (e.g. an
employer's internal details) belongs here.** If a setup step needs private
config, the *portable* skill lives here and the private values live elsewhere.

## What goes here vs. elsewhere (the seam)

`start` owns **system-level** setup - whatever is true for the *whole machine
regardless of which plugins you use*: terminal, harness, global Claude settings.
**Capability-specific** setup lives in that capability's *own* plugin, in its
own marketplace.

Litmus test for a setup step: **"Would this still be needed if the user only
ever used one *other* plugin?"** Yes -> system-level -> it belongs in `start`.
No -> it belongs to the capability, not here.

Guard against `start` becoming a junk drawer: it is device bootstrapping, not a
home for general utilities.

## How publishing actually works (read this once)

This marketplace is consumed from **GitHub** (`rschlek/rain-ai`), not from a
local folder. The only thing that makes a change go live is a `git push`.
Editing a file here does nothing to an installed copy until you commit and push.

Claude Code decides a plugin "changed" by its **version**, resolved from the
first of these that is set: (1) `version` in `plugin.json`, (2) `version` in the
marketplace entry, (3) the **git commit SHA**. These plugins deliberately have
**no `version` field**, so the commit SHA is the version. Every push is a new
SHA, so every push is automatically a new version. **There is no version to
bump.** Just commit and push.

## Layout
- `.claude-plugin/marketplace.json` - catalog listing every plugin.
- `plugins/<plugin>/skills/` - LIVE skills (auto-discovered, one level deep).
  Each plugin is self-contained: its own `.claude-plugin/plugin.json`,
  `skills/`, and any `references/`.
  - `plugins/start/` - system-level device setup (default plugin): `warp-setup`
    (terminal) and `claude-code-setup` (global Claude Code settings baseline).
- `skill-template/` - starting point for a new skill (copy it).
- `wip/` - gitignored scratchpad for unfinished skills. Never shipped, never
  committed. Move a folder out to `plugins/<plugin>/skills/` when it is ready.
- `scripts/validate.py` - pre-commit sanity check (valid JSON + frontmatter).

Skills are discovered **one level deep** under a plugin's `skills/`; you cannot
nest skill folders. To group related skills with their own references as a
liftable unit, give them their own plugin. A skill's invocation name is
`<plugin>:<skill-dir>` - e.g. `start:warp-setup`.

## Add a NEW skill
1. `git pull`.
2. Copy `skill-template/` to `plugins/<plugin>/skills/<name>/` and write it.
   (Draft it under `wip/` first if you want it out of the tree until ready.)
3. `python scripts/validate.py`.
4. Commit **just that skill's paths** (not `git add -A`), then push.

## Update a skill that is ALREADY live
1. Edit it in place under `plugins/<plugin>/skills/<name>/`.
2. `python scripts/validate.py`.
3. Commit just that skill's paths, then push.

## Remove a skill
Delete its directory under the plugin's `skills/`, commit, push.

## Hard rules
- Commit by path, never `git add -A`. The tree may carry unrelated in-flight
  work; a publish commit must contain only what you are publishing.
- Run `validate.py` before every commit.
- `git pull` before authoring. This repo may be edited from multiple machines;
  git is how they stay in sync - pull first, push when done.
- **Public repo.** No private, personal-identifying, or work-specific content.
  Keep skills portable (no cross-plugin or absolute-path assumptions).

## Consume changes after pushing
`/plugin update <plugin>` (Claude Code), though `autoUpdate` normally pulls each
push on its own.
