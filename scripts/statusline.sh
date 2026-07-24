#!/usr/bin/env bash
# DDMAL Claude Code status line: context % + 5-hour + weekly usage, always visible.
#
# Install:
#   1. Copy this to ~/.claude/statusline.sh and `chmod +x ~/.claude/statusline.sh`
#   2. Add to ~/.claude/settings.json:
#        { "statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh" } }
#   3. Run Claude Code in a terminal (statusLine does not render in the VS Code side-panel yet).
#
# Requires `jq`. The 5h/weekly figures appear only for Pro/Max plans, after the first
# response in a session; they are omitted gracefully until then.

input=$(cat)

ctx=$(jq -r '.context_window.used_percentage // empty' <<<"$input")
h5=$(jq -r '.rate_limits.five_hour.used_percentage // empty' <<<"$input")
wk=$(jq -r '.rate_limits.seven_day.used_percentage // empty' <<<"$input")
model=$(jq -r '.model.display_name // empty' <<<"$input")
branch=$(git branch --show-current 2>/dev/null)

parts=()
[ -n "$model" ]  && parts+=("$model")
[ -n "$ctx" ]    && parts+=("ctx $(printf '%.0f' "$ctx")%")
[ -n "$h5" ]     && parts+=("5h $(printf '%.0f' "$h5")%")
[ -n "$wk" ]     && parts+=("wk $(printf '%.0f' "$wk")%")
[ -n "$branch" ] && parts+=("⎇ $branch")

# Join with " | "
( IFS='|'; echo "${parts[*]}" ) | sed 's/|/ | /g'
