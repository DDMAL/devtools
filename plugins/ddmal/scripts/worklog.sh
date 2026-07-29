#!/usr/bin/env bash
# Collect a factual record of recent work for the /ddmal:workday and
# /ddmal:worknotes skills. Prints plain text; interprets nothing.
#
#   worklog.sh --since "2026-07-24 09:00" [--tz local] [--roots DIR]
#
# --since is read in --tz, which takes a zone name, or "local" for whatever this
# computer is set to; the default is America/New_York. --roots defaults to the
# parent of the current git repo, i.e. the folder your clones live in; repeat
# the flag or set WORKLOG_ROOTS (colon-separated) to scan more places.

set -uo pipefail

SINCE=""
TZ_NAME="${WORKLOG_TZ:-America/New_York}"
ROOTS=()
MAX_PROMPTS=14      # per Claude Code session
MAX_SESSIONS=40
PROMPT_WIDTH=160

while [ $# -gt 0 ]; do
  case "$1" in
    --since) SINCE="${2:-}"; shift 2 ;;
    --tz)    TZ_NAME="${2:-}"; shift 2 ;;
    --roots) ROOTS+=("${2:-}"); shift 2 ;;
    -h|--help) sed -n '2,10p' "$0"; exit 0 ;;
    *) echo "worklog.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$SINCE" ] || { echo "worklog.sh: --since is required" >&2; exit 2; }
# Accept "YYYY-MM-DD" as shorthand for 00:00 that day.
case "$SINCE" in *[0-9]:[0-9]*) : ;; *) SINCE="$SINCE 00:00" ;; esac

# --- window -----------------------------------------------------------------
# Resolve the zone once and export it, so every date and git call below inherits
# it. "local" means leave TZ alone and use this computer's setting.
if [ "$TZ_NAME" = local ] || [ -z "$TZ_NAME" ]; then
  # An exported TZ is what the user's own shell already shows them; fall back to
  # the system zone only when they haven't set one.
  TZ_NAME="${TZ:-$(readlink /etc/localtime 2>/dev/null | sed 's|.*/zoneinfo/||')}"
fi
if [ -n "$TZ_NAME" ]; then
  export TZ="$TZ_NAME"
else
  # No zone name to resolve to. Leave TZ untouched rather than exporting a bare
  # abbreviation like "EDT", which carries no daylight-saving rules.
  TZ_NAME="$(date +%Z), this computer's setting"
fi

# BSD date first, GNU date as the fallback, so this works on macOS and Linux.
EPOCH=$(date -j -f '%Y-%m-%d %H:%M:%S' "$SINCE:00" +%s 2>/dev/null \
     || date -d "$SINCE" +%s 2>/dev/null)
[ -n "$EPOCH" ] || { echo "worklog.sh: could not parse --since '$SINCE'" >&2; exit 2; }
SINCE_UTC=$(date -u -r "$EPOCH" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null \
         || date -u -d "@$EPOCH" +%Y-%m-%dT%H:%M:%SZ 2>/dev/null)

if [ ${#ROOTS[@]} -eq 0 ]; then
  if [ -n "${WORKLOG_ROOTS:-}" ]; then
    IFS=':' read -ra ROOTS <<< "$WORKLOG_ROOTS"
  elif TOP=$(git rev-parse --show-toplevel 2>/dev/null); then
    ROOTS=("$(dirname "$TOP")")
  else
    ROOTS=("$PWD")
  fi
fi

echo "=== WINDOW ==="
echo "since: $SINCE $TZ_NAME  ($SINCE_UTC)"
echo "now:   $(date '+%Y-%m-%d %H:%M %Z (%A)')"
echo "roots: ${ROOTS[*]}"
echo

# --- commits ----------------------------------------------------------------
# --exclude=refs/stash keeps `git stash` bookkeeping commits out of the record.
echo "=== COMMITS (yours, all branches) ==="
FOUND_COMMITS=0
REPOS=()
for root in "${ROOTS[@]}"; do
  for d in "$root"/*/; do
    [ -d "$d" ] || continue
    git -C "$d" rev-parse --git-dir >/dev/null 2>&1 || continue
    REPOS+=("$d")
    ME=$(git -C "$d" config user.email 2>/dev/null)
    [ -n "$ME" ] || continue
    log=$(git -C "$d" log --exclude=refs/stash --all --no-merges \
            --author="$ME" --since="$SINCE" \
            --pretty='  %ad  %h  %s' --date='format:%a %H:%M' 2>/dev/null)
    if [ -n "$log" ]; then
      FOUND_COMMITS=1
      printf -- '-- %s (branch: %s)\n%s\n' \
        "$(basename "$d")" \
        "$(git -C "$d" branch --show-current 2>/dev/null)" \
        "$log"
    fi
  done
done
[ "$FOUND_COMMITS" -eq 1 ] || echo "  (none)"
echo

# --- uncommitted work -------------------------------------------------------
# Only files touched inside the window, so months-old dirty trees stay quiet.
echo "=== UNCOMMITTED (files changed in window) ==="
FOUND_DIRTY=0
# ${REPOS[@]+...} guards the expansion: bash 3.2 (macOS /bin/bash) treats an
# empty array as unbound under `set -u`.
for d in ${REPOS[@]+"${REPOS[@]}"}; do
  dirty=""
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    f="${line:3}"
    f="${f##* -> }"                       # renames: keep the destination
    f="${f%\"}"; f="${f#\"}"
    path="$d${f%/}"
    mt=$(stat -f %m "$path" 2>/dev/null || stat -c %Y "$path" 2>/dev/null)
    [ -n "$mt" ] && [ "$mt" -ge "$EPOCH" ] && dirty="$dirty  $line"$'\n'
  done < <(git -C "$d" status --porcelain 2>/dev/null | head -60)
  if [ -n "$dirty" ]; then
    FOUND_DIRTY=1
    printf -- '-- %s\n%s' "$(basename "$d")" "$dirty"
  fi
done
[ "$FOUND_DIRTY" -eq 1 ] || echo "  (none)"
echo

# --- handoffs ---------------------------------------------------------------
echo "=== HANDOFF NOTES WRITTEN IN WINDOW ==="
FOUND_HANDOFF=0
for d in ${REPOS[@]+"${REPOS[@]}"}; do
  [ -d "$d.handoffs" ] || continue
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    FOUND_HANDOFF=1
    printf -- '-- %s/%s\n' "$(basename "$d")" "$(basename "$f")"
    sed -n '/^## Goal/,/^## /p' "$f" | sed -n '2,6p' | sed 's/^/     /'
  done < <(find "$d.handoffs" -maxdepth 1 -name '*.md' -newermt "$SINCE" 2>/dev/null)
done
[ "$FOUND_HANDOFF" -eq 1 ] || echo "  (none)"
echo

# --- Claude Code sessions ---------------------------------------------------
# What you asked Claude to do is often the clearest record of the day's intent,
# including work that never reached a commit.
echo "=== CLAUDE CODE SESSIONS (your prompts, in window) ==="
PROJECTS="$HOME/.claude/projects"
if [ -d "$PROJECTS" ] && command -v jq >/dev/null 2>&1; then
  FOUND_SESSION=0
  STAGE=$(mktemp -d) || STAGE=""
  while IFS= read -r f; do
    [ -n "$f" ] || continue
    # One line per message: gsub flattens each prompt, so grep drops whole
    # messages (tool results, slash-command echoes, injected skill bodies).
    prompts=$(jq -r --arg since "$SINCE_UTC" '
        select(.type == "user" and (.timestamp // "") >= $since)
        | (.message.content) as $c
        | (if ($c | type) == "string" then $c
           else ([$c[]? | select(.type? == "text") | .text] | join(" ")) end)
        | select(type == "string" and length > 0)
        | gsub("\\s+"; " ")
      ' "$f" 2>/dev/null \
      | grep -v -e '^ *<' -e '^ *\[Request interrupted' -e '^ *Caveat:' \
               -e '^ *Base directory for this skill' -e '^ *#' -e '^ *```' \
      | cut -c1-"$PROMPT_WIDTH" | head -"$MAX_PROMPTS")
    [ -n "$prompts" ] || continue
    FOUND_SESSION=1
    proj=$(jq -r 'select(.cwd) | .cwd' "$f" 2>/dev/null | head -1)
    # Time of the first in-window message, not the file's mtime.
    ts=$(jq -r --arg since "$SINCE_UTC" \
          'select((.timestamp // "") >= $since) | .timestamp' "$f" 2>/dev/null | head -1)
    ts_epoch=$(date -u -j -f '%Y-%m-%dT%H:%M:%S' "${ts%%.*}" +%s 2>/dev/null \
            || date -u -d "${ts%%.*}" +%s 2>/dev/null)
    [ -n "$ts_epoch" ] || ts_epoch="$EPOCH"
    when=$(date -r "$ts_epoch" '+%a %d %H:%M' 2>/dev/null \
        || date -d "@$ts_epoch" '+%a %d %H:%M' 2>/dev/null)
    block=$(printf -- '-- %s  [%s]\n%s\n' "$(basename "${proj:-unknown}")" "$when" \
              "$(printf '%s\n' "$prompts" | sed 's/^/     • /')")
    # Stage under the start time so sessions print in chronological order.
    if [ -n "$STAGE" ]; then
      printf '%s\n' "$block" > "$STAGE/${ts_epoch}-$(basename "$f")"
    else
      printf '%s\n' "$block"
    fi
  done < <(find "$PROJECTS" -name '*.jsonl' -newermt "$SINCE" 2>/dev/null | head -"$MAX_SESSIONS")
  if [ -n "$STAGE" ]; then
    for b in $(ls "$STAGE" 2>/dev/null | sort -n); do cat "$STAGE/$b"; done
    rm -rf "$STAGE"
  fi
  [ "$FOUND_SESSION" -eq 1 ] || echo "  (none)"
elif [ -d "$PROJECTS" ]; then
  echo "  (skipped: jq not installed)"
else
  echo "  (no session history at $PROJECTS)"
fi
