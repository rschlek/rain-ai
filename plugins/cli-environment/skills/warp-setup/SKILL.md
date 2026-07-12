---
name: warp-setup
disable-model-invocation: true
description: >-
  Apply the user's standard Warp terminal configuration on the current device - the
  visual setup (theme, fonts, zoom, vertical tabs via settings.toml) plus the agent
  tab configs for the chosen scope, with the chosen agent's tab set as Warp's default
  new-tab. Asks two things first: which agent(s) to configure (Claude Code, Codex, or
  Both), and whether the tabs should launch with the dangerous auto-approve flags on
  by default (Claude's --dangerously-skip-permissions / Codex's --yolo). This is a
  CONFIG APPLIER, not an installer - the sibling of claude-code-setup and
  codex-cli-setup: Warp must already be installed and onboarded; if it is missing the
  skill hands the user concise install instructions and waits, it does not install
  Warp itself. It ships no script: it reconciles the on-disk config toward shipped
  desired-state assets with the Write tool, then verifies the artifact. Use when the
  user says "set up warp", "configure warp", "apply my warp settings", or "warp tab
  configs". Do NOT use to install Warp for the user, or to open a one-off throwaway
  chat tab in Warp.
---

# Warp Setup (config applier)

Reach this **end state**: Warp's `settings.toml` (visual setup) and the **chosen
scope's** tab configs are applied to match the shipped desired-state assets, the
chosen default tab is set, Warp is running, and a session is open for each chosen
agent. This skill applies **config only** - it does **not** install Warp (see the
precondition). It ships **no `.ps1`** and is fully model-driven: treat the bundled
assets as *desired state*, reconcile the on-disk config toward them with the Write
tool, then **verify the artifact**. Make it genuinely converge - the verification
gate is what proves it stuck.

## Ask two things first

Before touching anything, ask the user **both**:

**1. Scope - which agent(s)?** Claude Code, Codex, or Both. This drives which tab
configs get written, which one is Warp's default tab, and which session(s) you open
at the end:

| Choice      | Tab configs written                  | Default tab   | Session(s) opened at the end                     |
| ----------- | ------------------------------------ | ------------- | ------------------------------------------------ |
| Claude Code | `claude.toml`, `claude-resume.toml`  | `claude.toml` | `warp://tab_config/claude`                       |
| Codex       | `codex.toml`, `codex-resume.toml`    | `codex.toml`  | `warp://tab_config/codex`                        |
| Both        | all four                             | `claude.toml` | `warp://tab_config/claude` **and** `.../codex`   |

- You write **only** the tab configs for the chosen scope. Any *other* agent's tabs
  already on disk from a prior run are **left untouched** (not removed).
- `default_tab_config_path` takes a **single** value, so for **Both** Claude is the
  default new-tab; the Codex tab is one click away in Warp's `+` menu.

**2. Dangerous auto-approve flags on by default?** **Default yes.** The standard tabs
launch each agent with its auto-approve / sandbox-bypass flag on (Claude's
`--dangerously-skip-permissions`, Codex's `--yolo`). Ask whether to keep that. If the
user says **no**, write the tabs **without** those flags - everything else is
identical:

| Tab             | flags ON (default)                                | flags OFF                  |
| --------------- | ------------------------------------------------- | -------------------------- |
| `claude`        | `claude --chrome --dangerously-skip-permissions`  | `claude --chrome`          |
| `claude-resume` | `claude --chrome --dangerously-skip-permissions --resume` | `claude --chrome --resume` |
| `codex`         | `codex --yolo`                                    | `codex`                    |
| `codex-resume`  | `codex resume --yolo`                             | `codex resume`             |

The assets ship with the flags **on** (the default). When the user chose **no**,
strip ` --dangerously-skip-permissions` from the `claude` pair and ` --yolo` from the
`codex` pair at write time - a plain substring removal, nothing else changes.

Carry **both** answers through reconcile (which tabs, which default, flags-on-or-off),
the verification gate, and the open-session step.

## Precondition: Warp installed AND onboarded

This skill configures an **existing** Warp - it is the sibling of `claude-code-setup`
and `codex-cli-setup`, which assume their tool exists and only apply config. Before
reconciling, confirm Warp is **installed** and has been **opened at least once with
onboarding finished**. The onboarding half matters: completing onboarding makes Warp
flush its in-memory settings to `settings.toml`, which would clobber a config you
wrote earlier. Requiring it up front (instead of orchestrating install + a fresh
launch + onboarding) is the whole point of the config-applier model - the install
fragility and the onboarding-clobber race both move out of scope.

- **Detect Warp** by its known install path ([REFERENCE.md](REFERENCE.md)).
- **If Warp is missing:** hand the user concise, OS-appropriate install instructions
  ([REFERENCE.md](REFERENCE.md), "Installing Warp yourself") and ask them to install
  it, open it once, and click through onboarding to the terminal prompt, then reply.
  **Stop and wait - do not install it yourself.**
- **If Warp is present but looks un-onboarded** (no `settings.toml` on disk yet, or it
  is empty - [REFERENCE.md](REFERENCE.md)): ask the user to open Warp once and finish
  onboarding to the terminal prompt, then reply.
- Only proceed once Warp is installed **and** onboarded (`settings.toml` exists and is
  populated). That confirmation is what closes the clobber window.

## The desired-state assets (data, not payload)

```
warp-setup/assets/
  settings.toml              # visual setup; carries the {{DEFAULT_TAB_CONFIG_PATH}} token
  tab_configs/
    claude.toml              # ships with --dangerously-skip-permissions on
    claude-resume.toml
    codex.toml               # ships with --yolo on
    codex-resume.toml
```

These are the **source of truth** for the target state - read them and make the
on-disk files match. Reference them as
`${CLAUDE_PLUGIN_ROOT}/skills/warp-setup/assets/...`. The four tab configs are the
named entries in Warp's `+` (new-tab) menu.

### Replace-vs-merge semantics (they differ per file)

- **`tab_configs/*.toml` -> REPLACE.** Write each one from the asset, applying the
  dangerous-flag choice (above): verbatim when flags are on; with the flag substring
  removed when the user chose off. These live in a directory Warp's settings-flush
  **never touches**, so there is no clobber risk.
- **`settings.toml` -> MERGE.** Ensure **our** keys/sections are present at **our**
  values **and preserve any other keys/sections the user already had.** **On conflict,
  our value WINS** - most importantly `default_tab_config_path`, which an
  already-configured Warp will already have pointing at some other tab; overwrite it
  with our value. "Preserve" applies only to keys we do **not** manage (the keys we
  manage are exactly those present in the asset). Getting this wrong is the difference
  between Warp's default tab auto-running the agent and it opening a plain shell.

### The substituted value

`settings.toml` ships with `default_tab_config_path` carrying one literal token:
`{{DEFAULT_TAB_CONFIG_PATH}}`. At write time, do a **plain string replace** of it with
the **full, OS-native path** to the chosen scope's default tab config - this machine's
resolved `tab_configs` directory joined to the chosen filename **using the OS's own
separator** (`\` on Windows, `/` on macOS):

- Claude Code -> `<tab_configs>\claude.toml` (Windows) or `<tab_configs>/claude.toml` (macOS)
- Codex -> `<tab_configs>\codex.toml` or `<tab_configs>/codex.toml`
- Both -> the Claude path (Claude is the default new-tab)

Build it with the native separator so the path matches what Warp itself writes. No
TOML parsing of our own values - just the one string substitution. Every other value
ships as-is.

## Order of operations

1. **Ask scope + dangerous flags** (above).
2. **Precondition** (above) - Warp installed and onboarded; hand off the manual
   install and wait if it is missing.
3. **Reconcile** (below) - self-host guard, then quit-or-not, then write.
4. **Verify gate** (below).
5. **Open the chosen scope's session(s)** (below).
6. **Report** (below).

## Reconcile (OS-agnostic, idempotent, convergent)

**Self-host guard first.** The clean path is quit Warp -> write while stopped ->
relaunch, so a running Warp can't flush over your write. But **before quitting, check
whether THIS session is running inside the very Warp you would quit** (the self-host
case - common when you re-run this skill from a `claude`/`codex` Warp tab;
`Stop-Process` would tear down the terminal you are in). Detect it
([REFERENCE.md](REFERENCE.md) - the `TERM_PROGRAM=WarpTerminal` signal plus the Warp
parent-process chain), then branch:

- **Not inside Warp** -> clean path: quit Warp, write (below) while stopped, relaunch.
  Quit/launch commands in [REFERENCE.md](REFERENCE.md).
- **Inside Warp (self-host)** -> **do NOT quit.** Write the tab configs live (zero
  clobber risk - Warp never flushes that directory). Write `settings.toml` live too
  (Warp hot-reloads it, so the visual setup applies now), but **tell the user plainly**
  that to make it durable they must fully quit and relaunch Warp once when no agent
  session is hosted inside it, or re-run this skill from a non-Warp terminal.

**The write** (use the **Write tool** - it emits UTF-8 **without BOM**; Warp's TOML
parser chokes on a BOM):

1. **Detect the OS** and **resolve where Warp config lives** by checking the candidate
   paths ([REFERENCE.md](REFERENCE.md)); create dirs that are missing. (Linux differs
   and is **not** handled - if you detect Linux, say so and stop.)
2. **Tab configs (REPLACE):** Write the tab configs **for the chosen scope** into the
   tab_configs dir from the assets, applying the **dangerous-flag choice** (strip the
   flag substring if the user chose off). Any *other* agent's tabs already on disk are
   left untouched.
3. **settings.toml (MERGE):** **First read the existing on-disk `settings.toml`** and
   keep it (to merge into and to prove you didn't clobber). Produce a merged result
   where every key/section from our asset is present at our value, the
   `{{DEFAULT_TAB_CONFIG_PATH}}` token is replaced with the chosen scope's full
   OS-native default-tab path, **and** every pre-existing user key/section we don't
   manage is preserved. Write the merged result.

**Bounded and convergent.** Safe to re-run. If a check below fails, adjust and retry -
but **cap at ~2-3 attempts** so it can't thrash. Re-running when already correct
should change nothing.

## Verification gate (the load-bearing step)

After writing, **re-read the files from disk and assert on the ARTIFACT**. Check all
four:

1. **Our known settings landed.** Re-read `settings.toml`; confirm at least:
   `theme = "adeberry"`, `is_any_ai_enabled = false`,
   `default_session_mode = "tab_config"`, `[appearance.vertical_tabs] enabled = true`,
   `zoom_level = 125`, and that `default_tab_config_path` resolves to **this machine's
   tab_configs dir + the chosen scope's default filename** (`claude.toml` for Claude
   Code or Both, `codex.toml` for Codex), joined with the OS-native separator - our
   value, **not** a pre-existing user path the merge failed to overwrite.
2. **No BOM.** Read the first 3 bytes of `settings.toml` and assert they are **NOT**
   `239,187,191` (EF BB BF), e.g.
   `powershell -Command "[System.IO.File]::ReadAllBytes('<settings.toml>')[0..2]"`.
3. **Didn't clobber.** Compare against what you read **before** writing: every user
   key/section that isn't ours must still be present in the merged file.
4. **Tab configs match desired - flag-aware.** Re-read the `.toml` files you wrote for
   the chosen scope and confirm they equal the assets **with the dangerous flag
   present iff the user chose yes** - i.e. the `claude` pair carries (or omits)
   `--dangerously-skip-permissions` and the `codex` pair carries (or omits) `--yolo`
   exactly per the choice; everything else byte-for-byte from the asset.

On a failed check, adjust and retry within the 2-3 attempt bound.

## Open the chosen scope's session(s)

A launched Warp does **not** reliably honor `default_tab_config_path` for the window it
opens, so **don't rely on the settings file to produce a running session.** After the
reconcile relaunch (give Warp ~3-5 s), explicitly open the chosen scope's tab
config(s) via Warp's URI handler - one for each agent in scope:

```
# Claude Code:
Start-Process "warp://tab_config/claude"          # macOS: open "warp://tab_config/claude"
# Codex:
Start-Process "warp://tab_config/codex"           # macOS: open "warp://tab_config/codex"
# Both: run both lines (give the first a beat before the second so each lands its own tab)
```

This auto-runs each chosen tab's command from the `.toml` you wrote, leaving a running
session for each chosen agent. (The `default_*` settings keys still ship as the user's
standing preference for *new* windows; this step guarantees the session(s) are up now.)

## Contextual human escalation

If a check **still fails** after the bounded retries, OR the situation is
**ambiguous-and-destructive** (e.g. a conflicting existing `settings.toml` a merge
can't safely reconcile), **STOP and ask the user** - never fail with a bare error.
Compose a precise ask: what you wrote and **where** (resolved paths), what the failing
check shows (actual bytes/values), your best-guess cause, and the **specific**
confirmation or command you need to proceed.

## Report

When done, report: the **chosen scope** (Claude Code, Codex, or Both), the
**dangerous-flag choice** (on/off) and that the tabs reflect it, whether Warp was
already present or the user installed it on your instruction, the files written and
that they **stuck** (the re-read + four checks confirm it), that pre-existing settings
were preserved, that Warp is running, and that you opened a **session for each chosen
agent** via its tab config - ask the user to confirm those tabs appeared. Mention the
scope's tab configs are available from Warp's `+` menu. State which reconcile path you
took: on the **clean path** (wrote with Warp stopped) the visual setup is already
applied on this launch; on the **self-host branch** (wrote live because this session
runs inside Warp) say so - the tab configs persisted and the visual setup shows via
hot-reload, but a one-time full quit+relaunch with no agent session inside Warp (or a
re-run from a non-Warp terminal) is what makes the visual settings durable.

## Notes

- **Not an installer.** Warp's install (and onboarding, a GUI gate only the user can
  click through) is the user's to do; this skill only applies config - same shape as
  `claude-code-setup` and `codex-cli-setup`.
- **Privacy.** `warp.sqlite` (account email, command history, session) is never read
  or written. Nothing sensitive lives in the shipped assets once the path token is
  substituted.
- **Idempotent.** Re-running reconciles the on-disk config back to desired state -
  safe on every device once Warp is installed and onboarded.
- These are the *standing* tab configs, distinct from any throwaway, self-deleting tab
  config a separate skill might use to spawn a one-off new chat.
