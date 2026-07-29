#!/usr/bin/env bash
# Build a pre-filled GitHub URL for /ddmal:draft-pr and /ddmal:draft-issue.
# Prints the URL on stdout and a length report on stderr; nothing is created on
# GitHub — the human opens the link and clicks the button.
#
#   prefill-url.sh pr    --repo owner/repo --base main --head feat \
#                        --title-file F --body-file F
#   prefill-url.sh issue --repo owner/repo --title-file F --body-file F \
#                        [--template bug.md]
#
# Title and body are read from files so no quoting or escaping is needed.
# Repeat --param k=v for extra query params (assignees, reviewers, milestone).

set -uo pipefail

KIND="${1:-}"; shift || true
case "$KIND" in
  pr|issue) ;;
  *) echo "prefill-url.sh: first argument must be 'pr' or 'issue'" >&2; exit 2 ;;
esac

REPO="" BASE="" HEAD="" TITLE_FILE="" BODY_FILE="" TEMPLATE=""
PARAMS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --repo)       REPO="${2:-}"; shift 2 ;;
    --base)       BASE="${2:-}"; shift 2 ;;
    --head)       HEAD="${2:-}"; shift 2 ;;
    --title-file) TITLE_FILE="${2:-}"; shift 2 ;;
    --body-file)  BODY_FILE="${2:-}"; shift 2 ;;
    --template)   TEMPLATE="${2:-}"; shift 2 ;;
    --param)      PARAMS+=("${2:-}"); shift 2 ;;
    -h|--help)    sed -n '2,13p' "$0"; exit 0 ;;
    *) echo "prefill-url.sh: unknown argument: $1" >&2; exit 2 ;;
  esac
done

[ -n "$REPO" ]       || { echo "prefill-url.sh: --repo owner/repo is required" >&2; exit 2; }
[ -n "$TITLE_FILE" ] || { echo "prefill-url.sh: --title-file is required" >&2; exit 2; }
[ -n "$BODY_FILE" ]  || { echo "prefill-url.sh: --body-file is required" >&2; exit 2; }
[ -r "$TITLE_FILE" ] || { echo "prefill-url.sh: cannot read $TITLE_FILE" >&2; exit 2; }
[ -r "$BODY_FILE" ]  || { echo "prefill-url.sh: cannot read $BODY_FILE" >&2; exit 2; }
if [ "$KIND" = pr ]; then
  [ -n "$BASE" ] && [ -n "$HEAD" ] || {
    echo "prefill-url.sh: pr needs --base and --head" >&2; exit 2; }
fi

command -v python3 >/dev/null 2>&1 || {
  echo "prefill-url.sh: python3 not found; it does the URL encoding." >&2
  echo "  On macOS: xcode-select --install" >&2
  exit 3
}

KIND="$KIND" REPO="$REPO" BASE="$BASE" HEAD="$HEAD" \
TITLE_FILE="$TITLE_FILE" BODY_FILE="$BODY_FILE" TEMPLATE="$TEMPLATE" \
PARAMS="$(printf '%s\n' ${PARAMS[@]+"${PARAMS[@]}"})" \
python3 -c '
import os, pathlib, sys, urllib.parse

kind = os.environ["KIND"]
repo = os.environ["REPO"].strip().strip("/")
title = pathlib.Path(os.environ["TITLE_FILE"]).read_text().strip()
body = pathlib.Path(os.environ["BODY_FILE"]).read_text()

if not title:
    sys.exit("prefill-url.sh: the title file is empty")

params = {}
if kind == "pr":
    params["expand"] = "1"
params["title"] = title
params["body"] = body
if os.environ.get("TEMPLATE"):
    params["template"] = os.environ["TEMPLATE"]

for pair in os.environ.get("PARAMS", "").splitlines():
    if not pair.strip():
        continue
    if "=" not in pair:
        sys.exit(f"prefill-url.sh: --param needs key=value, got {pair!r}")
    k, v = pair.split("=", 1)
    params[k.strip()] = v

query = urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
if kind == "pr":
    base, head = os.environ["BASE"], os.environ["HEAD"]
    url = f"https://github.com/{repo}/compare/{base}...{head}?{query}"
else:
    url = f"https://github.com/{repo}/issues/new?{query}"

# Browsers and GitHub start failing past roughly 8k characters; 414 is the
# usual symptom. Warn well before the cliff so the body can be trimmed.
LIMIT = 8000
n = len(url)
print(url)
if n > LIMIT:
    print(f"OVER LIMIT: {n} chars (max ~{LIMIT}). Trim the linked body and give "
          "the full text to the user to paste instead.", file=sys.stderr)
    sys.exit(1)
print(f"ok: {n} chars (limit ~{LIMIT})", file=sys.stderr)
'
