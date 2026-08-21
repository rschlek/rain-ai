# rain-ai

The public install door for **brrain** — a local-first second brain for
**Claude Code and Codex**. One plugin, shipped with a manifest for each harness,
so the same skills run whichever CLI you drive.

## Quick start

```sh
# Claude Code
claude plugin marketplace add rschlek/rain-ai
claude plugin install brrain@rain-ai

# Codex
codex plugin marketplace add rschlek/rain-ai
codex plugin add brrain@rain-ai
```

Newly installed plugins only load on the next launch, so relaunch into a fresh
session afterwards, then run `brrain:setup` to create or connect a brain on the
device.

## What brrain is

A park-and-link knowledge loop over a plain-markdown knowledge base you own:

| Skill | What it does |
| ----- | ------------ |
| `setup` | Create or connect a brain on this device. |
| `remember` | Capture a provenance-tagged note into the inbox. |
| `refine` | Synthesize the inbox into canonical wiki pages at the trust gate. |
| `remember-gateless` | Capture straight into canonical pages, no gate. |
| `recall` | Read the brain back. |
| `interview` | Hunt knowledge gaps and elicit answers to fill them. |
| `audit` | Lint the canonical pages for inconsistency. |

## Where the code lives

brrain's home — source, issues, README — is
[**rschlek/brrain**](https://github.com/rschlek/brrain). This repo carries a
mirror of it under `plugins/brrain/` so that existing installs keep updating
from the marketplace URL they already have. Contribute and file issues at
`rschlek/brrain`; see [CLAUDE.md](./CLAUDE.md) for how the mirror is synced.

## The mental model

- **The harness (Claude Code or Codex) is the OS** — it runs the session and
  dispatches work.
- **Plugins are the apps** — self-contained, liftable units of capability.
- **Skills are the commands** — invoked as `<plugin>:<skill>`, matched to intent.
- **Marketplaces are the app stores** — a git repo with a catalog of plugins.

> **Public repo.** No private, personal-identifying, or work-specific content.
