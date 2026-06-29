---
name: claude-code-setup
disable-model-invocation: true
description: >-
  Set up the user's GLOBAL Claude Code settings on the current device with a
  portable baseline: merge a small set of shared preferences (commit/PR
  attribution off, agent push notifications on) into ~/.claude/settings.json,
  then offer two opt-ins - skipping the dangerous-mode warning prompt, and
  enabling auto-update for the rain-ai marketplace. It backs up settings.json
  first, merges field-aware (sets only the keys it manages, preserves everything
  else, and ASKS before overwriting any existing conflicting value), verifies the
  result is still valid JSON, then removes the backup. Use when the user is
  setting up a new or reinstalled machine, or says "set up my claude settings",
  "configure claude", "claude-code-setup", "apply my global claude settings", or
  "bootstrap claude settings". Do NOT use to configure a specific plugin's
  settings, to register marketplaces (rain-ai is self-contained and already
  registered if this skill is running), to edit a project-level
  .claude/settings.json, or to set the BRRAIN_PATH / env vars (a capability's own
  setup owns those).
---

# Claude Code Setup

Reach this **end state**: the user's global `~/.claude/settings.json` carries a
small **portable baseline** of shared preferences, plus whichever of two opt-in
settings they chose - and the file is **still valid JSON** (a malformed
`settings.json` breaks Claude Code on next launch, so this is load-bearing). Like
`warp-setup`, this skill ships **no script** and is fully model-driven: you treat
the bundled asset as *desired state*, merge it into the on-disk file, then
**verify the artifact**.

## The desired-state asset

```
claude-code-setup/assets/
  settings.baseline.json     # the keys this skill manages, at their values
```

Reference it as `${CLAUDE_PLUGIN_ROOT}/skills/claude-code-setup/assets/settings.baseline.json`.
It is the **source of truth** for the keys we manage - read it and reconcile the
on-disk file toward it. The baseline is deliberately tiny and **universal** (true
for any user on any machine):

| Key | Value | Why |
| --- | ----- | --- |
| `attribution` | `{ "commit": "", "pr": "" }` | No Claude attribution text in commits/PRs. (Modern replacement for `includeCoAuthoredBy`, which is ignored when `attribution` is set - so we do not write the old key.) |
| `agentPushNotifEnabled` | `true` | Phone push when a long task finishes or input is needed (no-op unless Remote Control is connected - pure upside). |

Everything else is **out of scope on purpose** - we do NOT write `env`,
`enabledPlugins`, `extraKnownMarketplaces`, `autoUpdatesChannel`, or
`includeCoAuthoredBy`. `rain-ai` is self-contained, so this skill never touches
the keys that reference other marketplaces.

## Merge semantics (per-key, conservative - ASK on conflict)

`settings.json` is **personal and pre-existing**, so unlike `warp-setup`'s "our
value always wins", here you decide **per managed key**:

- **Absent on disk** -> set it to our value.
- **Present and already equal** -> no-op.
- **Present but DIFFERENT** -> **STOP and ask the user** before overwriting. Show
  the current value vs. our proposed value and let them choose. The user may have
  set it deliberately; do not silently clobber it.
- **Every key we do NOT manage** -> **preserve byte-for-byte.** Never drop or
  reorder a user's existing settings.

## Procedure

1. **Locate** `~/.claude/settings.json`. If it does not exist (truly fresh
   machine), treat the starting point as an empty object `{}` and you will write a
   new file.
2. **Read and parse** the existing file. If it is present but does **not** parse
   as valid JSON, **stop and ask** - do not overwrite a file you could not read
   (you would lose their settings).
3. **Compute the merged result in memory** by the per-key merge rules above
   (asking on any conflict before resolving it).
4. **Offer: skip the dangerous-mode prompt.** Explain it in one line - *"This
   skips the one-time warning Claude shows when you launch with
   `--dangerously-skip-permissions`. It grants no new power; it only silences that
   prompt. The warp tab configs in `start` use that flag, so the warning will
   otherwise appear on first launch."* If the user says **yes**, add
   `"skipDangerousModePermissionPrompt": true` to the in-memory result; if **no**,
   leave it out entirely.
5. **No-op short-circuit.** If the computed result is **identical** to what is
   already on disk, there is nothing to do: say settings already match the
   baseline, **skip the backup and the write entirely**, and jump to the
   auto-update offer (step 10). Never back up + rewrite a file you are not changing
   - that only risks reformatting it.
6. **Back up** -> copy the current `settings.json` to `settings.json.bak` before
   writing. (Skip if there was no file to begin with.)
7. **Write** the merged result with the **Write tool** (it emits UTF-8 **without
   BOM**; some readers choke on a BOM). Pretty-print with **2-space** indentation
   to match the user's existing style, and keep existing keys in place.
8. **Verification gate** (re-read the file from disk and assert on the artifact):
   1. **Valid JSON.** The written file parses cleanly. This is the load-bearing
      check - a broken `settings.json` breaks Claude Code.
   2. **Our keys landed** at our values (including the dangerous flag iff the user
      opted in).
   3. **Nothing clobbered.** Every key/section that was present before writing
      (and that we do not manage) is still present and unchanged.
   - On **any** failure: **restore `settings.json.bak`**, leave it in place, and
     escalate (next section). Do not leave a half-written file.
9. **On a clean verify, delete `settings.json.bak`.** It has done its job.
10. **Offer: rain-ai auto-update.** Ask *"Want to enable auto-update on rain-ai to
    automatically receive future updates?"* If yes, walk them through it: open
    `/plugin` -> **Marketplaces** -> select `rain-ai` -> enable auto-update. (There
    is **no** `settings.json` key for this at user scope - it is a harness toggle -
    so guide it; do not pretend to write it. If the harness later exposes a CLI or
    settings lever, prefer that.)
11. **Report** what landed: the baseline keys written (or confirmed already
    present), each conflict and how it was resolved, whether the dangerous-mode
    flag was added, that the file re-read as valid JSON and pre-existing settings
    were preserved, that the backup was removed, and whether they enabled
    auto-update.

## Contextual human escalation

If a verification check fails after the write, or the situation is
**ambiguous-and-destructive** (an existing `settings.json` that does not parse, or
a managed-key conflict you cannot safely resolve), **STOP and ask** - never fail
with a bare error or a half-written file. Compose a precise ask:

- what you read and **where** (resolved path),
- the failing check and the **actual** value/bytes,
- your best-guess cause,
- the **specific** confirmation or value you need to proceed.

When you have already written and a check failed, say plainly that you restored
`settings.json.bak`, so the user knows their original is intact.

## Notes

- **Idempotent.** Re-running changes nothing when the baseline is already present
  and equal; safe on every new device or re-run.
- **Privacy / portability.** The shipped baseline is universal and carries no
  personal, machine-specific, or work-specific values - nothing private lives in
  this skill. Per-machine and private values (e.g. `BRRAIN_PATH`, your
  marketplaces, enabled plugins) are owned by the capability that needs them, not
  here.
- **Why so small.** This is the system-settings counterpart to `warp-setup`'s
  terminal setup. Thin and focused is the point - it manages exactly the handful
  of universal preferences, and asks before touching anything the user already
  set.
