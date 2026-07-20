# rain-ai

A small, **shareable** plugin marketplace for getting a machine *set up* and
working faster on it. Every plugin ships for **both Claude Code and Codex** -
each carries a manifest for each harness, so the same skills run whichever CLI
you drive.

## What this is

rain-ai is a small, curated set of **portable capability plugins** for a
harness-as-an-operating-system workflow. (System-level device setup - terminal,
global settings, device enrollment - lives in the private dev marketplace, since
it carries machine- and network-specific values that must not be public.) It is
the public "shelf" - skills are authored and
proven in a private dev marketplace, then deliberately *promoted* here once they
are ready and stripped of anything personal or work-specific. **Nothing private
lives in this repo.**

## Quick start

Add the marketplace and install the plugins you want, in **Claude Code or Codex**:

```sh
# Claude Code
claude plugin marketplace add rschlek/rain-ai
claude plugin install brrain@rain-ai
claude plugin install productivity@rain-ai

# Codex
codex plugin marketplace add rschlek/rain-ai
codex plugin add brrain@rain-ai
codex plugin add productivity@rain-ai
```

Newly installed plugins only load on the next launch, so relaunch into a fresh
session afterwards. `brrain` ships its own device setup - run `brrain:setup` to
get started with the second brain.

## The mental model

- **The harness (Claude Code or Codex) is the OS** - it runs the session and
  dispatches work.
- **Plugins are the apps** - self-contained, liftable units of capability.
- **Skills are the commands** - invoked as `<plugin>:<skill>`, matched to intent.
- **Marketplaces are the app stores** - a git repo with a catalog of plugins.

## Plugins

| Plugin         | What it's for |
| -------------- | ------------- |
| `productivity` | Portable, general-purpose productivity skills: `breakout` (open a fresh chat in a new tab), `new-warp-chat` (the shared seeded-Warp-tab launcher breakout builds on), `handoff` (compact the conversation for a new agent), and `grill-me` (stress-test a plan by interview). |
| `brrain`       | A local-first second-brain loop: device `setup`, provenance-tagged `remember`, trust-gated `refine` into canonical wiki pages, plus `recall`, `interview`, and `audit`. |

A capability plugin brings its own setup (e.g. `brrain:setup`).

## Develop

This is the **public production half** of a prod/dev pair: plugins are authored
in a private dev marketplace and promoted here when ready. Each plugin is
self-contained and ships two catalogs - a Claude `.claude-plugin/` manifest and
a Codex `.codex-plugin/` manifest - so it installs on either harness.

See [CLAUDE.md](./CLAUDE.md) for layout, the add/update/remove flow, and the
publishing model (commit-SHA versioning - no version field to bump; a push is a
release). Run `python scripts/validate.py` before every commit.

> **Public repo.** No private, personal-identifying, or work-specific content.
> Keep skills portable.
