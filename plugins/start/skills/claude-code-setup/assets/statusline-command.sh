#!/usr/bin/env bash
# Claude Code statusline (shipped by the claude-code-setup skill)
# Shows model, dir basename, git branch, and a color-coded context-usage
# percentage aligned with the managed auto-compact threshold of 70%
# (green < 50%, yellow 50-69%, bold red >= 70%).

# Read stdin JSON and flatten to a single line so field:value pairs can't be
# split across lines by pretty-printing. No jq dependency (fresh Git Bash
# installs don't have it) -- extraction is done with plain grep/sed instead.
input=$(cat | tr -d '\r\n')

# extract_string <key>: pulls the value of the first "<key>":"..." occurrence,
# independent of field order/nesting and tolerant of extra whitespace.
extract_string() {
  local key="$1"
  printf '%s' "$input" \
    | grep -o "\"$key\"[[:space:]]*:[[:space:]]*\"[^\"]*\"" \
    | head -n 1 \
    | sed -E "s/\"$key\"[[:space:]]*:[[:space:]]*\"([^\"]*)\"/\1/"
}

# extract_number <key>: pulls the numeric value of the first "<key>":N
# occurrence (handles ints, floats, negatives). Empty if key absent or null.
extract_number() {
  local key="$1"
  printf '%s' "$input" \
    | grep -o "\"$key\"[[:space:]]*:[[:space:]]*[-0-9.eE]\{1,\}" \
    | head -n 1 \
    | sed -E "s/\"$key\"[[:space:]]*:[[:space:]]*//"
}

model=$(extract_string "display_name")
[ -z "$model" ] && model="Claude"

dir=$(extract_string "current_dir")
[ -z "$dir" ] && dir=$(extract_string "cwd")

# basename, tolerant of both / and \ separators and trailing slashes
dir_clean="${dir%/}"
dir_clean="${dir_clean%\\}"
base="${dir_clean##*/}"
base="${base##*\\}"

used=$(extract_number "used_percentage")

# Git branch, if cwd is inside a repo (skip optional locks to avoid contention)
branch=""
if [ -n "$dir" ]; then
  branch=$(git --no-optional-locks -C "$dir" branch --show-current 2>/dev/null)
fi

# ANSI colors (ANSI-C quoting so escapes are real ESC bytes)
RESET=$'\033[0m'
CYAN=$'\033[36m'
BLUE=$'\033[34m'
MAGENTA=$'\033[35m'
GREEN=$'\033[32m'
YELLOW=$'\033[33m'
BOLD_RED=$'\033[1;31m'

ctx_str=""
if [ -n "$used" ]; then
  pct=$(printf '%.0f' "$used" 2>/dev/null)
  if [ -n "$pct" ]; then
    if [ "$pct" -ge 70 ]; then
      color=$BOLD_RED
    elif [ "$pct" -ge 50 ]; then
      color=$YELLOW
    else
      color=$GREEN
    fi
    ctx_str="${color}Ctx ${pct}%${RESET}"
  fi
fi

out="${CYAN}${model}${RESET} ${BLUE}${base}${RESET}"
[ -n "$branch" ] && out="${out} ${MAGENTA}(${branch})${RESET}"
[ -n "$ctx_str" ] && out="${out}  ${ctx_str}"

printf "%s" "$out"
