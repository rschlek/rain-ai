# CLAUDE.md

Guidance for any Claude session working in this repo. **rain-ai** is the
**public** install door for the `brrain` plugin - a marketplace with exactly one
entry. People, including colleagues at work, installed brrain from
`rschlek/rain-ai`, so this repo's name, marketplace name, and
`brrain@rain-ai` plugin scope must never change. Nothing else lives here.

**Public repo.** Nothing private, personally identifying, or work-specific
belongs here. Personal plugins and agents live in a private marketplace.

## Where brrain lives

The source of truth is the standalone public repository `rschlek/brrain`. Its
root is the plugin root and contains `.claude-plugin/`, `.codex-plugin/`,
`skills/`, `hooks/`, `scripts/`, and `assets/`.

Both marketplace catalogs in this repository reference the upstream `stable`
branch directly. There is no embedded copy or subtree mirror. Develop, test,
version, tag, and release brrain in `rschlek/brrain`, never here.

## Publish a brrain release

1. Land and validate the change in `rschlek/brrain` on `main`.
2. Bump the version in both plugin manifests.
3. Tag the release and advance the upstream `stable` branch to that commit.
4. Verify a fresh `brrain@rain-ai` install resolves the new upstream version.

The rain-ai repository does not change for an ordinary brrain release. Change
its catalog only when the upstream location or release-channel contract changes.

## Layout

- `.claude-plugin/marketplace.json` - the one-entry Claude catalog.
- `.agents/plugins/marketplace.json` - the one-entry Codex catalog.
- `scripts/validate.py` - catalog sanity checks. Run before every commit.
- `wip/` - gitignored scratch, never committed.

## Hard rules

- Commit by path, never `git add -A`.
- Pull before touching anything; this repo is edited from multiple machines.
- Never rename the repo or marketplace, and never remove or rename the brrain
  entry - that is the no-repoint guarantee for existing installs.
- Never copy the brrain source back into this repository.
- Keep this public repository free of private, identifying, or work-specific
  content.

## Consume changes after release

Run `/plugin update brrain` in Claude Code or refresh the marketplace in Codex.
Configured automatic updates normally discover the new upstream version.
