---
name: claude-code-setup
disable-model-invocation: true
description: >-
  Set up the user's GLOBAL Claude Code config on the current device with a
  portable baseline: merge a small set of shared preferences (commit/PR
  attribution off, agent push notifications on) into ~/.claude/settings.json AND
  insert/refresh a small block of whole-machine behavioral guidance in
  ~/.claude/CLAUDE.md, then offer two opt-ins - skipping the dangerous-mode
  warning prompt, and enabling auto-update for the rain-ai marketplace. It backs
  up each file first, merges field-aware for settings.json (sets only the keys it
  manages, preserves everything else, and ASKS before overwriting any existing
  conflicting value) and marker-scoped for CLAUDE.md (replaces only its own
  managed block, preserving the user's own guidance), verifies each result, then
  removes the backups. Use when the user is setting up a new or reinstalled
  machine, or says "set up my claude settings", "configure claude",
  "claude-code-setup", "apply my global claude settings", or "bootstrap claude
  settings". Do NOT use to configure a specific plugin's settings, to register
  marketplaces (rain-ai is self-contained and already registered if this skill is
  running), to edit a project-level .claude/settings.json or CLAUDE.md, or to set
  the BRRAIN_PATH / env vars (a capability's own setup owns those).
---

# Claude Code Setup

Reach this **end state**: the user's global `~/.claude/settings.json` carries a
small **portable baseline** of shared preferences (plus whichever of two opt-in
settings they chose, and still **valid JSON** - a malformed `settings.json`
breaks Claude Code on next launch, so this is load-bearing), and their global
`~/.claude/CLAUDE.md` carries a small **managed guidance block** of whole-machine
behavioral defaults. Like `warp-setup`, this skill ships **no script** and is
fully model-driven: you treat the bundled assets as *desired state*, reconcile
each on-disk file toward its asset, then **verify the artifact**.

## The desired-state assets

```
claude-code-setup/assets/
  settings.baseline.json     # the settings.json keys this skill manages, at their values
  claudemd.baseline.md        # the CLAUDE.md guidance block this skill manages (marker-wrapped)
```

Reference them under
`${CLAUDE_PLUGIN_ROOT}/skills/claude-code-setup/assets/`. Each is the **source of
truth** for what we manage - read it and reconcile the on-disk file toward it.

### settings.baseline.json

The settings baseline is deliberately tiny and **universal** (true for any user
on any machine):

| Key | Value | Why |
| --- | ----- | --- |
| `attribution` | `{ "commit": "", "pr": "" }` | No Claude attribution text in commits/PRs. (Modern replacement for `includeCoAuthoredBy`, which is ignored when `attribution` is set - so we do not write the old key.) |
| `agentPushNotifEnabled` | `true` | Phone push when a long task finishes or input is needed (no-op unless Remote Control is connected - pure upside). |

Everything else is **out of scope on purpose** - we do NOT write `env`,
`enabledPlugins`, `extraKnownMarketplaces`, `autoUpdatesChannel`, or
`includeCoAuthoredBy`. `rain-ai` is self-contained, so this skill never touches
the keys that reference other marketplaces.

### claudemd.baseline.md

Whole-machine **behavioral guidance** that can't be expressed as a setting -
portable defaults for how the agent should work (don't add a Co-Authored-By
trailer; self-reconnect and clean up after Chrome browser automation). It is a
single block bounded by `<!-- rain-ai:baseline start -->` /
`<!-- rain-ai:baseline end -->` markers so we can refresh it in place without
disturbing the user's own guidance. Same universality bar as the settings
baseline: nothing private, work-specific, or capability-specific goes in it.

## Merge semantics

Both files are **personal and pre-existing**, so unlike `warp-setup`'s "our value
always wins", you reconcile conservatively and never clobber the user's own
content.

**settings.json (per managed key, ASK on conflict):**

- **Absent on disk** -> set it to our value.
- **Present and already equal** -> no-op.
- **Present but DIFFERENT** -> **STOP and ask the user** before overwriting. Show
  the current value vs. our proposed value and let them choose. The user may have
  set it deliberately; do not silently clobber it.
- **Every key we do NOT manage** -> **preserve byte-for-byte.** Never drop or
  reorder a user's existing settings.

**CLAUDE.md (marker-scoped, no ASK needed):** the block is bounded by its
`rain-ai:baseline` markers, so unlike settings there is no per-key conflict to
resolve - we own exactly what is between the markers and nothing else.

- **Markers present** -> replace everything from the start marker through the end
  marker with the baseline block.
- **Markers absent, file non-empty** -> append the block after a blank line.
- **File absent or empty** -> create it containing just the block.
- **Everything outside the markers** -> **preserve byte-for-byte.** The user's own
  guidance above or below the block is never touched.

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

### Then: the CLAUDE.md guidance block

Apply `assets/claudemd.baseline.md` to `~/.claude/CLAUDE.md` by the marker-scoped
rules above. This is the same treat-asset-as-desired-state, verify-the-artifact
loop, just on prose instead of JSON:

   1. **Read** `~/.claude/CLAUDE.md` (treat a missing/empty file as `""`) and read
      the bundled `assets/claudemd.baseline.md`.
   2. **Compute the result in memory:** replace the existing `rain-ai:baseline`
      block if the markers are present, else append it (file non-empty) or create
      the file with just the block (absent/empty). Leave every other line exactly
      as-is.
   3. **No-op short-circuit.** If the computed result is identical to what is on
      disk, say the guidance block already matches and **write nothing** (do not
      back up or rewrite a file you are not changing).
   4. **Back up** -> copy the current `CLAUDE.md` to `CLAUDE.md.bak` (skip if there
      was no file). **Write** the result with the **Write tool** (UTF-8 without
      BOM).
   5. **Verify the artifact** (re-read from disk): exactly one baseline block, its
      start and end markers both present and in order, and every line outside the
      block unchanged from before. On any failure, **restore `CLAUDE.md.bak`** and
      escalate (see below). On a clean verify, **delete `CLAUDE.md.bak`**.

10. **Offer: rain-ai auto-update.** Ask *"Want to enable auto-update on rain-ai to
    automatically receive future updates?"* If yes, walk them through it: open
    `/plugin` -> **Marketplaces** -> select `rain-ai` -> enable auto-update. (There
    is **no** `settings.json` key for this at user scope - it is a harness toggle -
    so guide it; do not pretend to write it. If the harness later exposes a CLI or
    settings lever, prefer that.)
11. **Report** what landed: the baseline keys written (or confirmed already
    present), each conflict and how it was resolved, whether the dangerous-mode
    flag was added, that `settings.json` re-read as valid JSON and pre-existing
    settings were preserved, whether the `CLAUDE.md` guidance block was created /
    appended / refreshed / already current and that the user's own guidance was
    preserved, that the backups were removed, and whether they enabled
    auto-update.

## Contextual human escalation

If a verification check fails after either write, or the situation is
**ambiguous-and-destructive** (an existing `settings.json` that does not parse, a
managed-key conflict you cannot safely resolve, or a `CLAUDE.md` whose markers are
malformed/unbalanced so you cannot tell which region is ours), **STOP and ask** -
never fail with a bare error or a half-written file. Compose a precise ask:

- what you read and **where** (resolved path),
- the failing check and the **actual** value/bytes,
- your best-guess cause,
- the **specific** confirmation or value you need to proceed.

When you have already written and a check failed, say plainly that you restored
the relevant `.bak` (`settings.json.bak` or `CLAUDE.md.bak`), so the user knows
their original is intact.

## Notes

- **Idempotent.** Re-running changes nothing when both baselines are already
  present and equal (the settings keys match and the `CLAUDE.md` block is
  byte-identical); safe on every new device or re-run.
- **Two files, one seam.** `settings.json` holds what can be a *setting*;
  `CLAUDE.md` holds whole-machine *behavioral guidance* that cannot. Both are
  user-level and global; the skill never touches `settings.local.json`, project
  `CLAUDE.md` files, or `.claude.json` (harness state).
- **Privacy / portability.** Both shipped baselines are universal and carry no
  personal, machine-specific, or work-specific values - nothing private lives in
  this skill. Per-machine and private values (e.g. `BRRAIN_PATH`, your
  marketplaces, enabled plugins) are owned by the capability that needs them, not
  here.
- **Why so small.** This is the system-config counterpart to `warp-setup`'s
  terminal setup. Thin and focused is the point - it manages exactly the handful
  of universal preferences and the one small guidance block, and asks before
  touching anything the user already set.
