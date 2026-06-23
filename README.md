# rain-ai

A small, **shareable** Claude plugin marketplace for getting a machine *set up*.
It is the front door to running Claude as a kind of operating system: device
bootstrapping and the global setup every other plugin builds on, separate from
any particular capability.

## The mental model

- **Claude (the harness) is the OS** - it runs the session and dispatches work.
- **Plugins are the apps** - self-contained, liftable units of capability.
- **Skills are the commands** - invoked as `<plugin>:<skill>`, matched to intent.
- **Marketplaces are the app stores** - a git repo with a catalog of plugins.

## Two kinds of setup

This marketplace exists because **system setup and capability setup are
different concerns**:

- **System / device setup** - true for the whole machine regardless of which
  plugins you use (terminal, harness, global settings). Lives here, in the
  `start` plugin.
- **Capability setup** - only matters if you use that capability (e.g. cloning a
  knowledge base). Lives in *that* capability's own plugin.

Litmus test: *"Would this setup step still be needed if the user only ever used
one other plugin?"* Yes -> it belongs in `start`. No -> it belongs to the
capability.

## Plugins

| Plugin  | What it's for |
| ------- | ------------- |
| `start` | System-level device setup: bootstrapping the terminal (`warp-setup`) and the global Claude Code settings baseline (`claude-code-setup`) that every other plugin builds on. |

## Quick start

Paste this into a fresh Claude Code session - it drives the install itself with
the `claude plugin` CLI, then sets up your device:

> Onboard me to the rain-ai setup. (1) Add the public marketplace
> `rschlek/rain-ai` from GitHub (use the HTTPS URL if SSH isn't configured).
> (2) Install and enable the `start` plugin. (3) Newly installed plugins only
> load in a new session, so once it's installed, relaunch into a fresh Claude
> session - a new Warp tab is ideal - and there run `start:warp-setup`, then
> `start:claude-code-setup`. Use the `claude plugin` CLI for the install steps.

What it does:

- **Adds + installs** the marketplace and the `start` plugin (install
  auto-enables, and is idempotent - safe to re-run).
- **Relaunches** into a fresh session, because newly installed skills only load
  on the next launch - this restart is inherent, not a bug.
- **`start:warp-setup`** installs and configures the Warp terminal, then lands
  you in a fresh Claude session in a new Warp tab.
- **`start:claude-code-setup`** applies your global `~/.claude/settings.json`
  baseline in that tab.

Prefer to drive the install by hand? The two steps are:

```
claude plugin marketplace add rschlek/rain-ai
claude plugin install start@rain-ai
```

Then relaunch into a fresh session and run `start:warp-setup` followed by
`start:claude-code-setup`.

## Develop

See [CLAUDE.md](./CLAUDE.md) for layout, the add/update/remove flow, and the
publishing model (commit-SHA versioning - no version field to bump; a push is a
release). Run `python scripts/validate.py` before every commit.

> **Public repo.** No private, personal-identifying, or work-specific content.
> Keep skills portable.
