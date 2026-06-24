@echo off
rem Windows launcher for the brrain SessionStart hook (Codex only).
rem
rem Codex on Windows does NOT run hook commands through a shell: it splits the
rem command string into program + args and spawns the first token directly,
rem resolving it on PATH. A bare `bash` therefore resolves to the WSL launcher
rem (System32\bash.exe), and a quoted Git-bash path with a space in it
rem ("C:\Program Files\Git\...") gets mis-split. The robust shape is to spawn
rem `cmd` (a no-space token that resolves cleanly) on THIS launcher, and let cmd
rem - where quoting is well behaved - locate Git Bash and run the real hook.
rem
rem This launcher is wired to command_windows, which only Codex reads (Claude
rem Code and macOS/Linux read the plain `command`: bash hook.sh). So it hands off
rem to hook.sh, which detects the host (PLUGIN_ROOT => Codex) and dispatches to
rem inject-agents-md.sh - the silent ~/.codex/AGENTS.md writer. That path prints
rem NOTHING, so on any failure here we also stay silent (never break startup).
setlocal
set "BASH=%ProgramFiles%\Git\bin\bash.exe"
if not exist "%BASH%" (
  rem Fall back to deriving Git Bash from git.exe on PATH (Git\cmd -> Git\bin).
  for /f "delims=" %%i in ('where git 2^>nul') do (
    for %%g in ("%%i") do set "BASH=%%~dpg..\bin\bash.exe"
    goto :run
  )
)
:run
if not exist "%BASH%" (
  rem No Git Bash found - stay silent, never break startup.
  exit /b 0
)
"%BASH%" "%~dp0hook.sh"
exit /b %errorlevel%
