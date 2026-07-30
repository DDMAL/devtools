---
name: daily-recap
description: Summarize today's work as 3-4 one-line bullets to paste into Workday. Use when the user asks what they worked on today or wants their Workday entry (e.g. "what did I work on today", "workday summary", "/ddmal:daily-recap", "/ddmal:daily-recap since 9am"). The day runs 4am to 4am in local time, so late-night work counts toward the session it belongs to; the user can name a different start time or day. Reads commits, uncommitted changes, and Claude Code sessions across all local repos, then writes the shortest honest summary that fits.
argument-hint: "[since 9am | yesterday | 2026-07-27 14:00]"
allowed-tools: Bash(date:*) Bash(git rev-parse:*) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/worklog.sh *)
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

## The window

- Now: !`date '+%Y-%m-%d %H:%M %Z (%A)'`
- Default start date (04:00 → 04:00, local): !`date -v-4H +%Y-%m-%d 2>/dev/null || date -d '4 hours ago' +%Y-%m-%d`

A workday runs from **04:00 to 04:00, in this computer's timezone** — never a hardcoded zone.
Work done at 1am belongs to the day you were still working, so before 4am the default start
date above is *yesterday*, not an empty new day. **Never assume the date or the hour** — both
are resolved above.

The user can override the start via `$ARGUMENTS`, and may give a time, a day, or both:

| They say | Window starts |
| --- | --- |
| *(nothing)* | the default start date above, at `04:00` |
| `9am`, `14:00`, `since lunch` | that time, on the default start date |
| `yesterday`, `Monday`, `2026-07-27` | 04:00 on that day |
| `yesterday 2pm`, `2026-07-27 14:00` | exactly that |

If a bare time hasn't happened yet today, they mean last night — step the date back a day.

## Step 1 — Collect the record

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/worklog.sh" --tz local --since 'YYYY-MM-DD HH:MM'
```

`--tz local` is what keeps this on the user's own clock.

It reports, for every repo in the folder holding your clones: your commits, files you changed
but haven't committed, handoff notes, and the prompts from your Claude Code sessions. Sessions
matter most — they capture work that never reached a commit.

## Step 2 — Add what GitHub knows (optional)

Reviews and issue comments leave no local trace. If this plugin's `github` MCP tools are
connected, call `mcp__plugin_ddmal_github__get_me`, then search with `updated:>=<window date>`:

- `mcp__plugin_ddmal_github__search_pull_requests` — `author:@me`, then `reviewed-by:@me`
- `mcp__plugin_ddmal_github__search_issues` — `commenter:@me`

**If the tools aren't available, skip this step silently.** The local record alone is enough.
Don't tell the user about missing tools unless they ask why something is absent.

## Step 3 — Compress to 3-4 lines

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

## Step 4 — Hand it over

Print **only the bullets** in a plain code block, ready to select and paste — nothing inside
it but the lines. Above it, put one short line naming the window you used (`Wed 29 Jul, 4am →
now`) so a wrong default gets caught immediately.

If you dropped or merged real work to fit, add one short sentence *after* the block saying
what you left out, so the user can swap it in if they'd rather.

## Related

`/ddmal:weekly-recap` is the opposite skill: a full-detail markdown file covering the week,
written for the user to read weeks later rather than to paste into a form.
