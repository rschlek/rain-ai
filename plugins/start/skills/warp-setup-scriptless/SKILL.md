---
name: warp-setup-scriptless
description: >-
  Set up the Warp terminal on the current device with the user's standard setup -
  install Warp if missing, apply the Claude tab configs AND the visual setup
  (theme, fonts, zoom, sidebar via settings.toml), then launch Warp. This is the
  SCRIPTLESS / EXPERIMENTAL variant: it ships NO bundled scripts and reaches the
  end state entirely model-driven (you reconcile the on-disk config toward shipped
  desired-state assets with the Write tool, then verify the artifact). Reaches the
  same end state as the scripted `warp-setup` skill - prefer this one only when
  deliberately running the scriptless A/B variant or when the user says
  "warp-setup-scriptless" / "scriptless warp" / "no-script warp setup". Otherwise
  use `warp-setup`. Triggers like the scripted one: "set up warp", "configure
  warp", "apply my warp settings", "warp tab configs" - but only route here for
  the scriptless variant. Do NOT use to open a one-off throwaway chat tab in Warp.
---

# Warp Setup (scriptless)

Reach the **same end state** as the scripted `warp-setup`: Warp installed, the
Claude tab configs and visual setup applied, Warp launched. The difference is
**how**: this variant ships **no `.ps1`** and is fully model-driven. You treat the
bundled assets as *desired state*, reconcile the on-disk config toward them with
the Write tool, then **verify the artifact**. It is an A/B experiment against the
scripted original - make it genuinely converge, not a toy.

## The desired-state assets (data, not payload)

```
warp-setup-scriptless/assets/
  settings.toml              # visual setup; carries the {{TAB_CONFIG_DIR}} token
  tab_configs/
    claude.toml
    claude-resume.toml
```

These are the **source of truth** for the target state - you read them and make
the on-disk files match. Reference them as
`${CLAUDE_PLUGIN_ROOT}/skills/warp-setup-scriptless/assets/...`. The two tab
configs are the named entries in Warp's `+` (new-tab) menu:

| Tab name        | Command it runs                                              |
| --------------- | ----------------------------------------------------------- |
| `claude`        | `claude --chrome --dangerously-skip-permissions`            |
| `claude-resume` | `claude --chrome --dangerously-skip-permissions --resume`   |

### Replace-vs-merge semantics (read carefully - they differ per file)

- **`tab_configs/*.toml` -> REPLACE verbatim.** Write each one byte-for-byte from
  the asset. These live in a directory Warp's settings-flush **never touches**, so
  there is no clobber risk and no merge needed.
- **`settings.toml` -> MERGE.** This is a **deliberate divergence** from the
  scripted original, which clobbers the file wholesale. Here you ensure **our**
  keys/sections are present at **our** values **and preserve any other
  keys/sections the user already had**. Don't blow away settings we don't manage.

### The one machine-specific value

`settings.toml` ships with `default_tab_config_path` pointing at the literal token
`{{TAB_CONFIG_DIR}}`. At write time, do a **plain string replace** of that token
with this machine's resolved `tab_configs` directory (below). No TOML parsing of
our own values - just the string substitution. Every other value ships as-is.

## Order of operations

Run in this order; **order is load-bearing** (see the clobber windows in
[REFERENCE.md](REFERENCE.md)):

**A. Install if missing** (model-driven, inline harness commands - **no script**).
Detect by the known install path (Warp is not on PATH); install only if missing;
warn-and-continue if you can't. Full proven commands - the Windows direct-download
path with the winget-wedge workaround and `winget show` version discovery, plus
macOS `brew install --cask warp` - are in [REFERENCE.md](REFERENCE.md). Remember
whether this was a **fresh** install (onboarding pending -> gate C applies) or an
**already-present** Warp (skip gate C).

**B. Launch Warp** - the single deliberate launch; it must come **before** config
so the profile exists (config written before the profile exists gets clobbered).
Command in [REFERENCE.md](REFERENCE.md). Wait ~5 s for Warp to initialize.

**C. Onboarding gate (fresh installs only).** If A just installed Warp, it is
showing onboarding windows. **Tell the user to click through onboarding to the
main terminal view, and wait for their explicit confirmation before continuing.**
Completing onboarding makes Warp flush its in-memory settings to `settings.toml`,
which would overwrite a config written earlier - waiting moves the write past that
flush. If Warp was already installed, it is already onboarded - **skip this gate**.

**D. Quit -> reconcile -> relaunch.** Quit Warp so nothing can flush over your
write, reconcile the config (next section) while Warp is stopped, then relaunch so
a fresh start reads it. Quit/launch commands in [REFERENCE.md](REFERENCE.md).

## Reconcile (OS-agnostic, idempotent, convergent)

Do this with Warp **stopped** (step D), using the **Write tool** (it emits UTF-8
**without BOM** - Warp's TOML parser chokes on a BOM, so this matters).

1. **Detect the OS** and **discover where Warp config actually lives by checking
   the candidate paths** - do not blindly hardcode; check, then use what exists
   (create dirs that are missing):

   | OS      | tab_configs dir                          | settings dir                      |
   | ------- | ---------------------------------------- | --------------------------------- |
   | Windows | `%APPDATA%\warp\Warp\data\tab_configs`   | `%LOCALAPPDATA%\warp\Warp\config` |
   | macOS   | `~/.warp/tab_configs`                    | `~/.warp`                         |

   (Linux differs - `~/.config/warp-terminal/` - and is **not** separately
   handled here, same as the original. If you detect Linux, say so and stop.)

2. **Tab configs (REPLACE):** Write `claude.toml` and `claude-resume.toml` into
   the tab_configs dir, byte-for-byte from the assets.

3. **settings.toml (MERGE):** **First read the existing on-disk `settings.toml`**
   (if any) and keep it - you'll need it both to merge into and to prove you
   didn't clobber. Produce a merged result where every key/section from our asset
   is present at our value, the `{{TAB_CONFIG_DIR}}` token is replaced with this
   machine's resolved tab_configs dir (plain string replace), **and** every
   pre-existing user key/section that we don't manage is preserved. Write the
   merged result.

**Bounded and convergent.** This is safe to re-run. If a check (below) fails,
adjust and retry - but **cap at ~2-3 attempts** so it can't thrash. Re-running
when already correct should change nothing.

## Verification gate (the load-bearing step)

After writing, **re-read the files from disk and assert on the ARTIFACT**, not the
visual effect. A shallow "file exists" check is worse than none - fold the known
gotchas in. Check all four:

1. **Our known settings landed.** Re-read `settings.toml`; confirm at least:
   `theme = "adeberry"`, `is_any_ai_enabled = false`,
   `default_session_mode = "tab_config"`, `[appearance.vertical_tabs] enabled =
   true`, `zoom_level = 125`.
2. **No BOM.** Warp's TOML parser chokes on a BOM. Read the first 3 bytes of
   `settings.toml` and assert they are **NOT** `239,187,191` (EF BB BF), e.g.:

   ```
   powershell -Command "[System.IO.File]::ReadAllBytes('<settings.toml>')[0..2]"
   ```

3. **Didn't clobber.** Compare against what you read **before** writing: every
   user key/section that isn't ours must still be present in the merged file.
4. **Tab configs match desired exactly.** Re-read both `.toml` files and confirm
   they equal the assets byte-for-byte.

On a failed check, adjust and retry within the 2-3 attempt bound.

## Contextual human escalation

If a check **still fails** after the bounded retries, OR the situation is
**ambiguous-and-destructive** (e.g. a conflicting existing `settings.toml` a merge
can't safely reconcile), **STOP and ask the user** - never fail with a bare error.
Compose a precise ask with full context:

- what you wrote and **where** (resolved paths),
- what the failing check shows (the actual bytes/values),
- your best-guess cause,
- the **specific** confirmation or command you need to proceed.

## Report

When done, report across all steps: whether Warp was installed or already present
(and by which method), whether you waited on the onboarding gate, the files
written and that they **stuck** (the re-read + four checks confirm it), that
pre-existing settings were preserved, and that Warp is running. Mention new tabs
come from Warp's `+` menu, and that because you wrote config with Warp stopped,
the visual setup is already applied on this launch - no further reload needed.

## Notes

- **Privacy.** `warp.sqlite` (account email, command history, session) is never
  read or written. Nothing sensitive lives in the shipped assets once the path
  token is substituted.
- **Idempotent.** Re-running installs nothing if Warp is present, skips the
  onboarding gate (already-installed Warp is already onboarded), and reconciles
  the on-disk config back to desired state - safe on every new device or after a
  Warp reinstall.
- These are the *standing* tab configs, distinct from any throwaway, self-deleting
  tab config a separate skill might use to spawn a one-off new chat.
- This variant exists to compare a scriptless, model-driven approach against the
  scripted `warp-setup`. The cost is a longer SKILL.md and more model work at run
  time; the install/clobber knowledge that lived in the script lives here as prose
  ([REFERENCE.md](REFERENCE.md)).
