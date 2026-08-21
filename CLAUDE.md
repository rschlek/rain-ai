# CLAUDE.md

Guidance for any Claude session working in this repo. **rain-ai** is the
**public** install door for the `brrain` plugin — a marketplace with exactly one
entry. People (including colleagues at work) installed brrain from
`rschlek/rain-ai`, so this repo's name, its marketplace name, and the
`brrain@rain-ai` plugin scope must never change. Nothing else lives here.

**Public repo.** Nothing private, personal-identifying, or work-specific belongs
here. Rainier's personal plugins and agents live in his private marketplace.

## Where brrain actually lives

The source of truth is the standalone repo **`rschlek/brrain`** (its root is the
plugin root: `.claude-plugin/`, `.codex-plugin/`, `skills/`, `hooks/`,
`scripts/`, `assets/`). `plugins/brrain/` in this repo is a **git subtree
mirror** of it, kept as a local-path marketplace source so both Claude Code and
Codex resolve it without any external-source support.

Develop brrain in `rschlek/brrain`, not here. Edits made directly under
`plugins/brrain/` will be overwritten by the next sync.

## Publish a brrain release (sync the mirror)

1. Land the change in `rschlek/brrain` (`main`).
2. Here: `git pull`, then
   `git subtree pull --prefix plugins/brrain git@github.com:rschlek/brrain.git main --squash -m "brrain: sync <short-sha>"`.
3. `python scripts/validate.py`.
4. Push. That push *is* the release.

## How publishing works

This marketplace is consumed from GitHub, not from a local folder: only a
`git push` makes a change live. Claude Code resolves a plugin's version from the
first of `plugin.json` `version`, the marketplace entry `version`, or the **git
commit SHA**. brrain deliberately has no `version` field, so every push is a new
version — there is nothing to bump.

## Layout

- `.claude-plugin/marketplace.json` — the one-entry catalog.
- `plugins/brrain/` — subtree mirror of `rschlek/brrain` (see above).
- `scripts/validate.py` — sanity check (valid JSON + frontmatter). Run before
  every commit.
- `wip/` — gitignored scratch, never committed.

## Hard rules

- Commit by path, never `git add -A`.
- `git pull` before touching anything; this repo is edited from multiple machines.
- Never rename the repo or the marketplace, and never remove or rename the
  `brrain` entry — that is the no-repoint guarantee to everyone who installed it.
- Public repo: keep it free of anything personal or work-specific.

## Consume changes after pushing

`/plugin update brrain` (Claude Code); `autoUpdate` normally pulls each push on
its own.
