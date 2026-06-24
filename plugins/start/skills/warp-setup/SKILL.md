---
name: warp-setup
description: >-
  Set up the Warp terminal on the current device with the user's standard setup -
  first ask whether to set up for Claude Code or Codex, then install Warp if
  missing, apply BOTH agents' tab configs AND the visual setup (theme, fonts, zoom,
  sidebar via settings.toml) with the chosen agent as the default tab, then launch
  Warp and open a session for the chosen agent. It ships no bundled script: it
  reconciles the on-disk config toward shipped desired-state assets with the Write
  tool, then verifies the artifact. Use when the user is setting up Warp on a new or
  reinstalled machine, or says "set up warp", "install warp", "configure warp",
  "apply my warp settings", or "warp tab configs". Do NOT use to open a one-off
  throwaway chat tab in Warp.
---

# Warp Setup

Reach this **end state**: Warp installed, the **chosen scope's** tab configs
(Claude, Codex, or both) and the visual setup applied, the chosen default tab set in
Warp, Warp launched - and finished by opening a session for each chosen agent in
Warp from its tab config. The skill ships **no `.ps1`** and is fully model-driven:
you treat the bundled assets as *desired state*, reconcile the on-disk config toward
them with the Write tool, then **verify the artifact**. Make it genuinely converge -
the verification gate is what proves it stuck.

## Choose the scope (do this first)

Before anything else, **ask the user which agent(s) to set up** - present three
choices: **Claude Code**, **Codex**, or **Both**. Their answer is the **chosen
scope** for this run and it drives everything downstream - which tab configs get
written, which one is Warp's default tab, and which session(s) you open at the end:

| Choice      | Tab configs written                  | Default tab   | Session(s) opened in step E                      |
| ----------- | ------------------------------------ | ------------- | ------------------------------------------------ |
| Claude Code | `claude.toml`, `claude-resume.toml`  | `claude.toml` | `warp://tab_config/claude`                       |
| Codex       | `codex.toml`, `codex-resume.toml`    | `codex.toml`  | `warp://tab_config/codex`                        |
| Both        | all four                             | `claude.toml` | `warp://tab_config/claude` **and** `.../codex`   |

- You write **only** the tab configs for the chosen scope. Picking Claude Code does
  not write Codex tabs, and vice versa; "Both" writes all four. Any *other* agent's
  tabs already on disk from a prior run are **left untouched** (not removed) - you
  reconcile what you manage, you don't garbage-collect.
- `default_tab_config_path` takes a **single** value, so for **Both** Claude is the
  default new-tab (the primary); the Codex tab is still one click away in Warp's `+`
  menu.
- Carry the chosen scope through reconcile (the `{{DEFAULT_TAB_CONFIG_PATH}}` value
  and which tabs you write), the verification gate, and step E.

## The desired-state assets (data, not payload)

```
warp-setup/assets/
  settings.toml              # visual setup; carries the {{TAB_CONFIG_DIR}}
                             #   and {{DEFAULT_TAB_CONFIG}} tokens
  tab_configs/
    claude.toml
    claude-resume.toml
    codex.toml
    codex-resume.toml
```

These are the **source of truth** for the target state - you read them and make
the on-disk files match. Reference them as
`${CLAUDE_PLUGIN_ROOT}/skills/warp-setup/assets/...`. The four tab
configs are the named entries in Warp's `+` (new-tab) menu:

| Tab name        | Command it runs                                              |
| --------------- | ----------------------------------------------------------- |
| `claude`        | `claude --chrome --dangerously-skip-permissions`            |
| `claude-resume` | `claude --chrome --dangerously-skip-permissions --resume`   |
| `codex`         | `codex --yolo`                                              |
| `codex-resume`  | `codex resume --yolo`                                       |

(`--yolo` is Codex's auto-approve / sandbox-bypass flag - the counterpart to
Claude's `--dangerously-skip-permissions`. Codex has no `--chrome` equivalent, so
its tabs omit it.)

### Replace-vs-merge semantics (read carefully - they differ per file)

- **`tab_configs/*.toml` -> REPLACE verbatim.** Write each one byte-for-byte from
  the asset. These live in a directory Warp's settings-flush **never touches**, so
  there is no clobber risk and no merge needed.
- **`settings.toml` -> MERGE.** Ensure **our** keys/sections are present at **our**
  values **and preserve any other keys/sections the user already had**. Don't blow
  away settings we don't manage.
  **On conflict, our value WINS.** If a key we manage already exists on disk with a
  different value - most importantly `default_tab_config_path`, which a
  previously-configured Warp will already have pointing at some other tab -
  **overwrite it with our value**. "Preserve" applies *only* to keys we do **not**
  manage; the keys we manage are exactly those present in the asset. Getting this
  wrong is the difference between Warp's default tab auto-running `claude` and it
  opening a plain shell (see the verification gate).

### The substituted value

`settings.toml` ships with `default_tab_config_path` carrying one literal token:
`{{DEFAULT_TAB_CONFIG_PATH}}`. At write time, do a **plain string replace** of it
with the **full, OS-native path** to the chosen scope's default tab config - this
machine's resolved `tab_configs` directory (below) joined to the chosen filename
**using the OS's own separator** (`\` on Windows, `/` on macOS):

- Claude Code -> `<tab_configs>\claude.toml` (Windows) or `<tab_configs>/claude.toml` (macOS)
- Codex -> `<tab_configs>\codex.toml` or `<tab_configs>/codex.toml`
- Both -> the Claude path (Claude is the default new-tab)

Build it with the native separator so the path matches what Warp itself writes
(Warp normalizes to the OS separator on flush; emitting it that way up front avoids
a mixed-separator path). No TOML parsing of our own values - just the one string
substitution. Every other value ships as-is.

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

**E. Open the chosen scope's session(s).** A launched Warp does **not** reliably
honor `default_tab_config_path` for the window it opens - on a fresh install it
opens Warp's built-in default (PowerShell), not the chosen tab. So **do not rely on
the settings file to produce a running session.** After the step-D relaunch (give
Warp ~3-5 s to be ready), explicitly open the chosen scope's tab config(s) via
Warp's URI handler - the reliable mechanism (it opens a new tab in the running
Warp). Open the URI for **each** agent in scope - one for Claude Code, one for
Codex, **both** for Both:

```
# Claude Code:
Start-Process "warp://tab_config/claude"          # macOS: open "warp://tab_config/claude"
# Codex:
Start-Process "warp://tab_config/codex"           # macOS: open "warp://tab_config/codex"
# Both: run both lines (give the first a beat before the second so each lands its own tab)
```

This auto-runs each chosen tab's command (`claude --chrome
--dangerously-skip-permissions`, or `codex --yolo`) from the `.toml` you wrote in
step D, leaving a running session for each chosen agent at the end of setup. (The
`default_*` settings keys still ship as the user's standing preference for *new*
windows; this step is what guarantees the session(s) are actually up now.)

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
   handled here. If you detect Linux, say so and stop.)

2. **Tab configs (REPLACE):** Write the tab configs **for the chosen scope** into
   the tab_configs dir, byte-for-byte from the assets - the `claude.toml` +
   `claude-resume.toml` pair for Claude Code, the `codex.toml` + `codex-resume.toml`
   pair for Codex, or all four for Both. Any *other* agent's tabs already on disk
   are left untouched, not deleted.

3. **settings.toml (MERGE):** **First read the existing on-disk `settings.toml`**
   (if any) and keep it - you'll need it both to merge into and to prove you
   didn't clobber. Produce a merged result where every key/section from our asset
   is present at our value, the `{{DEFAULT_TAB_CONFIG_PATH}}` token is replaced with
   the chosen scope's full OS-native default-tab path (the section above, built with
   the native separator), **and** every pre-existing user key/section that we don't
   manage is preserved. Write the merged result.

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
   true`, `zoom_level = 125`, and that `default_tab_config_path` resolves to **this
   machine's tab_configs dir + the chosen scope's default filename** (`claude.toml`
   for Claude Code, `codex.toml` for Codex, `claude.toml` for Both), joined with the
   OS-native separator - the token substituted to a real path, our value, **not** a
   pre-existing user path the merge failed to overwrite. This is the user's standing *preference* for new windows; do
   **not** rely on Warp honoring it to auto-open the agent (a fresh launch opens
   Warp's built-in default instead) - the running session(s) are delivered by step
   E's explicit tab-config open, not by this value.
2. **No BOM.** Warp's TOML parser chokes on a BOM. Read the first 3 bytes of
   `settings.toml` and assert they are **NOT** `239,187,191` (EF BB BF), e.g.:

   ```
   powershell -Command "[System.IO.File]::ReadAllBytes('<settings.toml>')[0..2]"
   ```

3. **Didn't clobber.** Compare against what you read **before** writing: every
   user key/section that isn't ours must still be present in the merged file.
4. **Tab configs match desired exactly.** Re-read the `.toml` files you wrote **for
   the chosen scope** (the `claude` pair, the `codex` pair, or all four for Both)
   and confirm they equal the assets byte-for-byte.

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

When done, report across all steps: the **chosen scope** (Claude Code, Codex, or
Both), whether Warp was installed or already present (and by which method), whether
you waited on the onboarding gate, the files written and that they **stuck** (the
re-read + four checks confirm it), that pre-existing settings were preserved, that
Warp is running, and that you opened a **session for each chosen agent** via its tab
config (step E) - ask the user to confirm those tabs appeared. Mention the
scope's tab configs are available from Warp's `+` menu, and that because you wrote
config with Warp stopped, the visual setup is already applied on this launch - no
further reload needed.

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
- The install and clobber-window knowledge lives as prose in
  [REFERENCE.md](REFERENCE.md), which you run inline as harness commands - there is
  no bundled script.
