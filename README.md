# rain-ai

The public install door for **brrain**, a local-first second brain for Claude
Code and Codex.

## Install

```sh
# Claude Code
claude plugin marketplace add rschlek/rain-ai
claude plugin install brrain@rain-ai

# Codex
codex plugin marketplace add rschlek/rain-ai
codex plugin add brrain@rain-ai
```

Newly installed plugins load in a fresh session. Run `brrain:setup` to create
or connect a brain on the device.

## What brrain provides

| Skill | What it does |
| ----- | ------------ |
| `setup` | Create or connect a brain on this device. |
| `remember` | Capture a provenance-tagged note into staging. |
| `refine` | Synthesize staged notes into canonical wiki pages behind a trust gate. |
| `remember-gateless` | Capture an explicitly approved note directly into canonical pages. |
| `recall` | Read the brain back. |
| `interview` | Find knowledge gaps and elicit answers. |
| `audit` | Check canonical pages for inconsistency and drift. |

## Source architecture

The plugin's canonical source, issue tracker, manifests, skills, hooks, scripts,
and assets live in [rschlek/brrain](https://github.com/rschlek/brrain).

This repository contains only the Rain AI marketplace catalogs. Both catalogs
reference the standalone brrain repository's `stable` branch directly, so a
brrain fix is authored and released once rather than copied between
marketplaces.

> **Public repository.** Nothing private, personally identifying, or
> work-specific belongs here.
