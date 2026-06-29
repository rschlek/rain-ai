---
name: codex-cli-setup
disable-model-invocation: true
description: >-
  Set up the Codex CLI on the current device with the system-level Codex feature
  flags other plugins build on: enable the device-wide `hooks` feature in
  ~/.codex/config.toml (plugin hooks are OFF by default on Codex, so a plugin's
  SessionStart or other hooks never run until this is on), offer the opt-in to
  disable Codex's built-in `memories` (for users who keep a dedicated or external
  memory system and do not want two parallel auto-captured memory stores), then walk
  the user through the one-time, per-device `/hooks` trust each hook needs. It
  detects whether Codex is present, edits config.toml additively (touches only the
  `[features]` flags it manages, preserves everything else byte-for-byte, keeps the
  file valid TOML), backs the file up first, verifies the artifact, then removes the
  backup. Use when the user is setting up Codex on a new or reinstalled machine,
  says "set up codex", "configure codex", "codex-cli-setup", "enable codex hooks",
  "disable codex memories", or "my plugin hooks aren't firing in codex". Do NOT use
  to configure a specific plugin's own hook or settings (that capability's setup owns
  its hook file and its trust reminder), to register marketplaces, to edit Claude
  Code's ~/.claude/settings.json (that is claude-code-setup), or to set any env vars.
---

# Codex CLI Setup

Reach this **end state**: the user's `~/.codex/config.toml` has the Codex
`[features]` flags this skill manages set correctly - `hooks = true` always, and
`memories = false` if the user opted to disable Codex's built-in memory - the file
is **still valid TOML** (a malformed `config.toml` breaks Codex on next launch, so
this is load-bearing), every other setting is preserved byte-for-byte, and the user
has been told the one **manual, per-device** step that cannot be automated -
granting `/hooks` trust.

Why this is system-level, not a per-plugin concern: on Codex, **plugin hooks do
not run at all until the `hooks` feature is enabled** - and a *disabled* feature
surfaces nothing, so no trust prompt ever appears and the failure is silent. The
flag is device-wide: it gates **every** plugin's hooks, not any one plugin's. That
is the litmus test for living in `start` - it would still be needed if the user
only ever used one *other* hooked plugin. (The default Claude Code host wires
plugin hooks automatically and needs none of this; this skill is Codex-only.)

Like `warp-setup` and `claude-code-setup`, this skill ships **no script** and is
fully model-driven. There is no bundled asset - the managed state is a small set of
`[features]` flags, described inline below. You edit the on-disk TOML, then
**verify the artifact**.

## The managed state (the `[features]` flags)

| Table / key | Value | When | Why |
| ----------- | ----- | ---- | --- |
| `[features]` -> `hooks` | `true` | **Always** | Allows installed plugins' hooks (e.g. a SessionStart hook) to run on Codex. Off by default; silently suppresses all plugin hooks until set. |
| `[features]` -> `memories` | `false` | **Opt-in (ask)** | Turns off Codex's built-in memory, which auto-captures notes to `~/.codex/memories/` and recalls them across sessions. Offer it to users who keep a dedicated or external memory system: two auto-capturing stores at once can diverge and surface conflicting context. Leave it untouched if they decline. |

Everything else in `config.toml` is **out of scope** - never add, drop, reorder, or
rewrite any other table or key. This skill manages exactly these two `[features]`
flags, and `memories` only when the user opts in.

## Merge semantics (additive, idempotent)

`config.toml` is **personal and pre-existing**, so touch only the flags above:

- **`hooks`** (always): already `true` -> no-op; `[features]` exists without it ->
  add `hooks = true`; no `[features]` table -> append one carrying `hooks = true`;
  set to `false` (the user deliberately disabled it) -> **STOP and ask** before
  flipping, do not silently override a deliberate off.
- **`memories`** (only if the user opted to disable it): set or replace it to
  `false` in `[features]`. If it is already `false` or absent, no change is needed.
  Never flip `memories` without the user opting in - the default is to leave it alone.
- **Every other table/key** -> preserve byte-for-byte.

## Procedure

1. **Detect Codex.** Check for `~/.codex/config.toml`, and for the `~/.codex/`
   directory.
   - **`config.toml` exists** -> Codex is present; proceed.
   - **`~/.codex/` exists but no `config.toml`** -> Codex is present but
     unconfigured; treat the starting point as an empty file and you will write a
     new `config.toml`.
   - **Neither exists** -> Codex is likely **not installed** on this device. Say so
     and **ask** whether to create `~/.codex/config.toml` anyway (e.g. they are
     about to install Codex) or skip. Do not silently create config for a host that
     is not there.
2. **Read and parse** the existing file. If it is present but does **not** parse as
   valid TOML, **stop and ask** - do not overwrite a file you could not read (you
   would lose their config).
3. **Offer the `memories` opt-in.** Explain it in one line and ask - something like:
   *"Codex has a built-in memory feature that auto-captures notes to
   `~/.codex/memories/` and recalls them across sessions. If you keep a dedicated or
   external memory system, running both means two parallel stores that can diverge.
   Want to disable Codex's built-in memories? (Non-destructive - it stops capture
   and use; your existing `~/.codex/memories/` files stay, and you can re-enable
   anytime.)"* Record their answer; default to leaving `memories` untouched.
4. **Compute the merged result in memory:** `hooks = true` always (asking first on a
   deliberate `hooks = false`), plus `memories = false` **iff** the user opted in at
   step 3. Make the smallest change that lands these.
5. **No-op short-circuit.** If the computed result is **identical** to what is on
   disk (e.g. `hooks` already `true` and the user did not opt to change `memories`),
   there is nothing to write: say so, **skip the backup and the write**, and jump to
   the trust step (step 9). Never back up + rewrite a file you are not changing -
   that only risks reformatting it.
6. **Back up** -> copy the current `config.toml` to `config.toml.bak` before
   writing. (Skip if there was no file to begin with.)
7. **Write** the merged result with the **Write tool** (UTF-8, **no BOM**). Make the
   **smallest** change that lands the flags: keep existing tables, keys, ordering,
   comments, and formatting intact; only add or flip the `[features]` lines you
   manage.
8. **Verification gate** (re-read the file from disk and assert on the artifact):
   1. **Valid TOML.** The written file parses cleanly. This is the load-bearing
      check - a broken `config.toml` breaks Codex.
   2. **The flags landed** - `[features] hooks` is `true`, and `memories` is `false`
      iff the user opted in.
   3. **Nothing clobbered.** Every other table/key present before the write is still
      present and unchanged.
   - On **any** failure: **restore `config.toml.bak`**, leave it in place, and
     escalate (next section). Do not leave a half-written file.
   - On a clean verify, **delete `config.toml.bak`.**
9. **Walk the one manual step - `/hooks` trust.** Hook trust **cannot be granted
   programmatically**; each installed hook must be trusted once per device. Tell the
   user:

   > Hooks enabled. One manual step remains, once per device: open a Codex session
   > and run **`/hooks`**, then **trust** the hooks listed for the plugins you use
   > (for example, a plugin's `SessionStart` hook). After a hook is trusted it fires
   > every session; until then it stays silent even with the feature on.

   This skill enables the *capability*; it does not (and cannot) decide which
   plugins' hooks to trust - that is the user's call at the `/hooks` prompt.
10. **Report** what landed: whether `hooks` was added or already present, whether
    `memories` was disabled (or left as-is), that the file re-read as valid TOML and
    other config was preserved, that the backup was removed, and that the `/hooks`
    trust step is the remaining manual action.

## Contextual human escalation

If a verification check fails after the write, or the situation is
**ambiguous-and-destructive** (an existing `config.toml` that does not parse, or a
deliberate `hooks = false` you should not override), **STOP and ask** - never fail
with a bare error or a half-written file. Compose a precise ask:

- what you read and **where** (resolved path),
- the failing check and the **actual** value/bytes,
- your best-guess cause,
- the **specific** confirmation or value you need to proceed.

When you have already written and a check failed, say plainly that you restored
`config.toml.bak`, so the user knows their original is intact.

## Notes

- **Idempotent.** Re-running changes nothing once `hooks = true` and the user's
  `memories` choice is in place; re-trusting at `/hooks` is harmless. Safe on every
  new device or re-run. Disabling `memories` is **non-destructive** - it stops
  capture and use but leaves `~/.codex/memories/` intact, so it is reversible.
- **The seam.** This manages **device-wide** Codex feature flags. Each plugin still
  owns its own hook file *and* its own reminder to trust that specific hook - this
  skill never edits a plugin's config or reaches into a brain. A capability's setup
  points the user here for the feature flags; it does not flip them itself. The
  `memories` opt-in is framed generically (any external memory system), not tied to
  one plugin.
- **Privacy / portability.** Carries no personal, machine-specific, or work-specific
  values - it manages universal Codex feature flags (`hooks` required, `memories` an
  opt-in). Safe for the public marketplace.
- **Counterpart skills.** `claude-code-setup` does the equivalent for Claude Code's
  global settings; `warp-setup` does the terminal. This is the Codex-CLI member of
  the same device-bootstrap set.
