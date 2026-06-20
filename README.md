# rain-ai

A small, **shareable** Claude plugin marketplace for getting *set up*. It is the
front door to running Claude as a kind of operating system: onboarding, system
orientation, and device bootstrapping — separate from any particular capability.

## The mental model

- **Claude (the harness) is the OS** — it runs the session and dispatches work.
- **Plugins are the apps** — self-contained, liftable units of capability.
- **Skills are the commands** — invoked as `<plugin>:<skill>`, matched to intent.
- **Marketplaces are the app stores** — a git repo with a catalog of plugins.

## Two kinds of setup

This marketplace exists because **system setup and capability setup are
different concerns**:

- **System / device setup** — true for the whole machine regardless of which
  plugins you use (terminal, harness, global settings, orientation). Lives here,
  in the `start` plugin.
- **Capability setup** — only matters if you use that capability (e.g. cloning a
  knowledge base). Lives in *that* capability's own plugin.

Litmus test: *"Would this setup step still be needed if the user only ever used
one other plugin?"* Yes → it belongs in `start`. No → it belongs to the
capability.

## Plugins

| Plugin  | What it's for |
| ------- | ------------- |
| `start` | System onboarding and device setup. Orientation to the harness and marketplace, the Claude-as-an-OS mental model, and global/device bootstrapping. |

## Install

Add this marketplace, then install the plugin:

```
/plugin marketplace add rschlek/rain-ai
/plugin install start@rain-ai
```

Then run `start:onboard` for the lay of the land.

## Develop

See [CLAUDE.md](./CLAUDE.md) for layout, the add/update/remove flow, and the
publishing model (commit-SHA versioning — no version field to bump; a push is a
release). Run `python scripts/validate.py` before every commit.

> **Public repo.** No private, personal-identifying, or work-specific content.
> Keep skills portable.
