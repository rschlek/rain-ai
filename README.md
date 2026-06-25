# rain-ai

A small, **shareable** plugin marketplace for getting a machine *set up* and
working faster on it. Every plugin ships for **both Claude Code and Codex** -
each carries a manifest for each harness, so the same skills run whichever CLI
you drive.

## What this is

rain-ai is the **front door** to a harness-as-an-operating-system workflow: the
device bootstrapping every other plugin builds on, plus a small, curated set of
portable capability plugins. It is the public "shelf" - skills are authored and
proven in a private dev marketplace, then deliberately *promoted* here once they
are ready and stripped of anything personal or work-specific. **Nothing private
lives in this repo.**

## Quick start

Two ways to install, and both work in **Claude Code or Codex**: let the agent
drive it, or run the CLI yourself.

**Let the agent drive it.** Paste this into a fresh Claude Code or Codex session:

> Onboard me to the rain-ai setup. (1) Add the public marketplace
> `rschlek/rain-ai` from GitHub (use the HTTPS URL if SSH isn't configured).
> (2) Install and enable the `start` plugin. (3) Newly installed plugins only
> load in a new session, so once it's installed, relaunch into a fresh session -
> a new Warp tab is ideal - and there run the `start:warp-setup` skill, then the
> settings-baseline skill for your harness (`start:claude-code-setup` for Claude
> Code, `start:codex-cli-setup` for Codex). Use your harness's plugin CLI
> (`claude plugin` or `codex plugin`) for the install steps.

**Or run it by hand.** The two install steps, per harness:

```sh
# Claude Code
claude plugin marketplace add rschlek/rain-ai
claude plugin install start@rain-ai

# Codex
codex plugin marketplace add rschlek/rain-ai
codex plugin add start@rain-ai
```

Then relaunch into a fresh session and run `start:warp-setup`, followed by
`start:claude-code-setup` (Claude Code) or `start:codex-cli-setup` (Codex).

What the bootstrap does:

- **Adds + installs** the marketplace and the `start` plugin (install
  auto-enables, and is idempotent - safe to re-run).
- **Relaunches** into a fresh session, because newly installed skills only load
  on the next launch - this restart is inherent, not a bug.
- **`start:warp-setup`** applies your Warp terminal configuration (Warp must
  already be installed - it hands you install instructions if it's missing), then
  lands you in a fresh session in a new Warp tab.
- **`start:claude-code-setup`** (Claude Code) or **`start:codex-cli-setup`**
  (Codex) applies your global settings baseline for that harness in the new tab.

## The mental model

- **The harness (Claude Code or Codex) is the OS** - it runs the session and
  dispatches work.
- **Plugins are the apps** - self-contained, liftable units of capability.
- **Skills are the commands** - invoked as `<plugin>:<skill>`, matched to intent.
- **Marketplaces are the app stores** - a git repo with a catalog of plugins.

## Plugins

| Plugin         | What it's for |
| -------------- | ------------- |
| `start`        | System-level device setup: configuring the terminal (`warp-setup`), the global Claude Code settings baseline (`claude-code-setup`), and the Codex CLI device settings (`codex-cli-setup`) that every other plugin builds on. |
| `productivity` | Portable, general-purpose productivity skills: `breakout` (open a fresh chat in a new tab), `handoff` (compact the conversation for a new agent), and `grill-me` (stress-test a plan by interview). |
| `brrain`       | A local-first second-brain loop: device `setup`, provenance-tagged `remember`, trust-gated `refine` into canonical wiki pages, plus `recall`, `interview`, and `audit`. |

A capability plugin brings its own setup (e.g. `brrain:setup`); on Codex,
`brrain`'s background reflexes also want the hooks feature that
`start:codex-cli-setup` enables.

## Two kinds of setup

The `start` plugin exists because **system setup and capability setup are
different concerns**:

- **System / device setup** - true for the whole machine regardless of which
  plugins you use (terminal, harness, global settings). Lives in the `start`
  plugin.
- **Capability setup** - only matters if you use that capability (e.g. cloning a
  knowledge base). Lives in *that* capability's own plugin (`brrain:setup`).

Litmus test: *"Would this setup step still be needed if the user only ever used
one other plugin?"* Yes -> it belongs in `start`. No -> it belongs to the
capability.

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
