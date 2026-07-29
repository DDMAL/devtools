---
name: workday
description: Summarize today's work as 3-4 one-line bullets to paste into Workday. Use when the user asks what they worked on today or wants their Workday entry (e.g. "what did I work on today", "workday summary", "/ddmal:workday", "/ddmal:workday since 9am"). The day runs 4am to 4am in local time, so late-night work counts toward the session it belongs to; the user can name a different start time or day. Reads commits, uncommitted changes, and Claude Code sessions across all local repos, then writes the shortest honest summary that fits.
---

# Write today's Workday entry

Workday has room for **3-4 short lines and nothing else**. Your job is to compress a whole
day across several repos into that. Everything below serves the compression.

Target shape:

```
- Fixed visual bug on source search page
- Worked on chant clustering
- Refining ddmal/devtools plugin
```

## Step 1 — Pick the window

A workday runs from **04:00 to 04:00, in this computer's timezone** — never a hardcoded zone.
Work done at 1am belongs to the day you were still working, so before 4am the window opens at
04:00 *yesterday*, not on an empty new day.

```bash
CUT=04
if [ "$(date +%H)" -lt "$CUT" ]; then
  DAY=$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d yesterday +%Y-%m-%d)   # still last night
else
  DAY=$(date +%Y-%m-%d)
fi
echo "$DAY $CUT:00"
```

**Never assume the date or the hour** — the command above derives both.

The user can override the start, and may give a time, a day, or both:

| They say | Window starts |
| --- | --- |
| *(nothing)* | `$DAY 04:00` from above |
| `9am`, `14:00`, `since lunch` | that time, on `$DAY` |
| `yesterday`, `Monday`, `2026-07-27` | 04:00 on that day |
| `yesterday 2pm`, `2026-07-27 14:00` | exactly that |

If a bare time hasn't happened yet on `$DAY`, they mean last night — step the date back a day.

## Step 2 — Collect the record

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/worklog.sh" --tz local --since 'YYYY-MM-DD HH:MM'
```

`--tz local` is what keeps this on the user's own clock.

If `$CLAUDE_PLUGIN_ROOT` is unset, the script is two levels up from this skill's base
directory: `<skill base dir>/../../scripts/worklog.sh`.

It reports, for every repo in the folder holding your clones: your commits, files you changed
but haven't committed, handoff notes, and the prompts from your Claude Code sessions. Sessions
matter most — they capture work that never reached a commit.

## Step 3 — Add what GitHub knows (optional)

Reviews and issue comments leave no local trace. If this plugin's `github` MCP tools are
connected, call `get_me`, then search with `updated:>=<window date>`:

- `search_pull_requests` — `author:@me`, then `reviewed-by:@me`
- `search_issues` — `commenter:@me`

**If the tools aren't available, skip this step silently.** The local record alone is enough.
Don't tell the user about missing tools unless they ask why something is absent.

## Step 4 — Compress to 3-4 lines

Group by **project or theme, never by commit.** Six commits in one repo are one bullet.

Rules for each line:

- **Start with a verb.** Past tense for finished work (`Fixed`, `Added`, `Reviewed`),
  present participle for work still in flight (`Refining`, `Working on`). The tense is the
  signal — don't flatten it for consistency.
- **Roughly 5-9 words.** It must not wrap.
- **Say what changed, not how.** "Fixed visual bug on source search page", not "patched CSS
  specificity in style.css".
- **No** file paths, branch names, SHAs, or repo slugs — except a project's plain name when
  that's what the work *was* (`ddmal/devtools plugin`).
- **No** issue or PR numbers, unless the user asks for them.
- No trailing periods, no sub-bullets, no headings, no preamble.

Order by significance, biggest first. Cap at 4 lines — if the day had more threads than that,
fold the small ones into the nearest bullet or drop them; a fifth line is not an option.

**Only claim what the record supports.** If nothing landed in a repo, "Working on X" is honest
and "Fixed X" is not.

## Step 5 — Hand it over

Print **only the bullets** in a plain code block, ready to select and paste — nothing inside
it but the lines. Above it, put one short line naming the window you used (`Wed 29 Jul, 4am →
now`) so a wrong default gets caught immediately.

If you dropped or merged real work to fit, add one short sentence *after* the block saying
what you left out, so the user can swap it in if they'd rather.
