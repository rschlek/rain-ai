<!-- rain-ai:baseline start -->
<!-- Managed by cli-environment:claude-code-setup. Edit the baseline in the rain-ai plugin, not here; this block is replaced on the next apply. -->

## Git commits

Do not add a `Co-Authored-By: Claude ...` trailer (or any Claude/Anthropic
attribution) to git commits or PR bodies. (Also enforced natively via
`attribution` in `settings.json`; this prose is the backstop.)

## Chrome browser automation

1. **Self-reconnect.** If Chrome or the extension is closed/unreachable, launch
   Chrome yourself (e.g. start `chrome.exe` via the terminal) and reconnect with
   `switch_browser` / `tabs_context_mcp` *before* asking the user to open it.
   Only ask if the self-launch fails.
2. **Clean up.** Always close the tab(s)/window opened for a task once the
   browser work is done, to reduce screen clutter.
<!-- rain-ai:baseline end -->
