---
name: onboard
description: >-
  Orient a new person or a fresh machine to this Claude-as-an-OS setup: explain
  what the system is, how the harness and plugins fit together, the mental model
  to hold ("Claude is the OS, plugins are the apps, skills are the commands"),
  what is available in the marketplace, and where to go next for device setup.
  Use when the user is setting up on a new machine, says "onboard me", "where do
  I start", "what is this system", "how does this all fit together", "give me the
  lay of the land", or is otherwise new and needs orientation before doing real
  work. Do NOT use to install/configure a specific tool (that is the dedicated
  device-setup skill for that tool) or to set up a specific capability — each
  capability plugin owns its own setup skill (e.g. a knowledge-base plugin's own
  setup skill clones the knowledge base).
---

# Onboard

The goal is a working **mental model**, not a wall of facts. By the end the user
should be able to predict where a given capability lives and how to invoke it,
and know the one or two device-setup steps left to run. Be conversational; lead
with the model, check understanding, and only go as deep as they push.

## The mental model (lead with this)

Frame the whole system as an operating system:

- **Claude (the harness) is the OS.** It runs the session, holds context,
  executes tools, and dispatches work.
- **Plugins are the apps.** Each plugin is a self-contained, liftable unit of
  capability with its own `skills/` and any `references/`.
- **Skills are the commands the apps expose.** A skill's invocation name is
  `<plugin>:<skill>` — e.g. a plugin named `start` exposing an `onboard` skill
  is `start:onboard`. Claude matches the user's intent to a skill's description.
- **Marketplaces are the app stores.** A marketplace is just a git repo with a
  catalog (`.claude-plugin/marketplace.json`) listing its plugins. You add a
  marketplace, then install plugins from it; `autoUpdate` pulls each push.

Check the model lands before moving on: "what's the difference between a plugin
and a skill, in this framing?" Adjust if it didn't.

## The two kinds of setup (the load-bearing distinction)

This is the seam that keeps the system clean — make sure the user holds it:

- **System / device setup** is whatever is true for the *whole machine
  regardless of which plugins you use*: the terminal, the harness, global
  Claude settings, this orientation. It runs roughly once per machine and lives
  **here, in `start`**.
- **Capability setup** is whatever only matters *if you use that capability*. It
  lives in that capability's *own* plugin's setup skill — not here.

The litmus test, when unsure where a setup step belongs: **"Would this step
still be needed if the user only ever used one *other* plugin?"** Yes →
system-level → `start`. No → it belongs to the capability.

## Procedure

1. **Read the room.** New person, or a returning person on a fresh machine?
   That decides how much of the mental model to spend time on vs. jumping
   straight to the remaining device-setup steps.
2. **Teach the model** (the two sections above), checking understanding.
3. **Show what's installed and what's available.** List the marketplaces the
   user has added and the plugins from each (the harness's plugin/marketplace
   listing is the source of truth). For each plugin, give the one-line "what
   it's for" so they know what door to knock on later.
4. **Point at remaining device setup.** Name the system-level setup skills in
   `start` that haven't been run on this machine (e.g. terminal, shared Claude
   settings) and offer to run them. Then note that each capability plugin has
   its *own* setup skill to run only if/when they want that capability.
5. **Land the next concrete action**, not a summary. One thing to do now.

## Notes

- Keep this skill portable and **shareable** — no work-specific or private
  details. Anything personal/private belongs in a private marketplace, not here.
- This skill orients and points; it does not itself install tools. Hand off to
  the dedicated device-setup skill for each tool.
- Reference any bundled files with `${CLAUDE_PLUGIN_ROOT}/path/to/file` rather
  than absolute paths, so the skill stays portable across clones.
