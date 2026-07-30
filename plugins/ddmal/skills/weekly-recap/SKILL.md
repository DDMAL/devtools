---
name: weekly-recap
description: Write brief personal markdown work notes — one line per task — covering everything done since last Friday 9am Eastern (or a date you name). Use when the user wants a recap of the past week or a memory aid of recent work (e.g. "what have I been working on", "write my work notes", "/ddmal:weekly-recap", "/ddmal:weekly-recap 2026-07-20"). Reads commits, uncommitted changes, handoffs, and Claude Code sessions across all local repos.
argument-hint: "[since Monday | 2026-07-20 | 2026-07-20 14:00]"
allowed-tools: Bash(date:*) Bash(git rev-parse:*) Bash(mkdir:*) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/worklog.sh *)
---

# Write personal work notes

These notes are a **memory aid for the user, weeks from now** — a jog to the memory, not an
account of the work. Nobody else reads them. The user did the work; all they need back is the
hook: what the thing was, and where it stands.

**One line per task.** Think of this as `/ddmal:daily-recap` stretched over a week — a few more
lines, and the issue and PR numbers kept, but the same brevity. A whole week should fit on one
screen. If a bullet needs a second sentence to make sense, the first sentence was the wrong one.

## The window

- Now: !`date '+%Y-%m-%d %H:%M %Z (%A)'`
- Today, Eastern: !`TZ=America/New_York date '+%Y-%m-%d %A (ISO weekday %u)'`
- This repo: !`git rev-parse --show-toplevel`

The default start is **the most recent Friday at 09:00 America/New_York**. Get it from the
Eastern date above — go back `(weekday + 2) mod 7` days, or a full 7 if that lands on 0 —
and **never guess the current date.** Run on a Friday, it goes back a full week rather than a
few hours, because the point is to cover the week just worked. Repos are scanned in the parent
folder of the repo shown above.

If the user gave a date or a phrase in `$ARGUMENTS` ("since Monday", "since the 20th",
"since 2026-07-20 14:00"), use that instead, at 09:00 unless they named a time.

Unlike `/ddmal:daily-recap`, this window is anchored to **Eastern**, not the local clock, so a
week's notes cover the same span for everyone in the lab. Set `WORKLOG_TZ` to change that.

State the window you settled on before you write anything, so a wrong default is caught early.

## Step 1 — Collect the record

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/worklog.sh" --since 'YYYY-MM-DD 09:00'
```

It reports, for every repo in that parent folder: your commits, files changed but not
committed, handoff notes written in the window, and the prompts from your Claude Code
sessions — including the work that never reached a commit.

Read the session prompts closely. Questions the user asked, decisions they pushed back on, and
things they abandoned are exactly what they won't remember, and commits never record them.

> **Scope note.** The script reads Claude Code session history for *every* project on this
> machine, not just the clones listed above — so unrelated or personal work can surface here
> and end up in the saved file. Two ways to narrow it: pass `--roots DIR` (or set
> `WORKLOG_ROOTS`, colon-separated) to limit which clones are scanned, and drop anything from
> an unrelated project rather than writing it up. If the user seems surprised by what appeared,
> tell them where it came from.

## Step 2 — Add what GitHub knows

Reviews, issue discussion, and PRs that others moved leave no local trace. If this plugin's
`github` MCP tools are connected, call `mcp__plugin_ddmal_github__get_me`, then search with
`updated:>=<window start>`:

- `mcp__plugin_ddmal_github__search_pull_requests` — `author:@me`, then `reviewed-by:@me`
- `mcp__plugin_ddmal_github__search_issues` — `commenter:@me`

If the tools aren't connected, carry on with the local record and note at the bottom of the
file that GitHub activity isn't included.

## Step 3 — Write the notes

One section per project, and **within a section order by size, never by date.** The biggest
piece of work in a project goes first, the leftovers batch onto shared lines at the bottom.
Order the projects the same way, so the repo that took the week leads the file. A heavy week is
15-20 bullets in total; past that, the batch lines aren't working hard enough.

```markdown
# Work notes: <Fri 24 Jul, 9:00am> to <Wed 29 Jul, 1:40pm>

## <Biggest project>

- <The thread that took the week — one line> (#1234, draft)
- <The next biggest> (#1235, in review)
- Reviewed: #1240 <three words>, #1241, #1242 — and <decision taken, one clause> (#1243)
- Merged: <thing> (#1236), <thing> (#1237); filed #1244 <three words>, #1245 <three words>

## <Next project>

- ...

## Next up

- <The three or four things to pick up first, most urgent first>
```

Size means how much of the week it took, not how many commits it produced — a two-commit fix
that ate three days of investigation is a big thread. Where two threads are close, the one with
a priority-high label, a colleague waiting, or users actively hitting it goes first.

Those batch lines are where length goes to die: group by state and let one line carry five
numbers. Reviews and filed issues get a few words at most, never a bullet of their own, and a
decision can ride the end of the line it came from.

Writing rules:

- **One line per task, and one task per line.** A bullet covers a piece of work, never a
  commit, and never runs to a second sentence. How it was implemented, which files changed,
  what the tests do, and why each choice was made all stay out — the user remembers those once
  the name is in front of them.
- **Lead with the thing, not the story.** "Stale sigla in the concordances export — the legacy
  `Source.siglum` column is frozen (#2169, draft)" is the shape. A sentence explaining how the
  export works is not.
- **Fragments are fine.** An em dash beats a subordinate clause. Don't pad a line into prose.
- **Keep the identifiers.** PR and issue numbers, plus the one branch or filename that is the
  way back to the work. They're the whole reason the file beats a daily recap.
- **Tense tells the truth.** Past tense only for work that merged, deployed, or landed on the
  default branch. Draft PRs, live branches, and anything awaiting review are in flight — mark
  them, in the same line, as `draft` or `in review`. Never write up a draft as done.
- **A real fork in the road earns a line.** What was decided, and the one fact it turned on.
  Not the argument, not the alternatives considered.
- Skip trivia entirely — formatting commits, typo fixes, routine chores.
- A quiet week is three bullets. Don't pad.

**Only write what the record supports.** Where the evidence is thin (a session with prompts
but no commits), say what was worked on and mark it as unfinished — don't infer an outcome.

## Step 4 — Save and show

Write to `~/worknotes/<start>_to_<end>.md`, e.g. `~/worknotes/2026-07-24_to_2026-07-29.md`
(override with `$WORKNOTES_DIR`). Create the folder if it doesn't exist. These are personal
notes spanning every repo, so they never go inside a project — and never into git.

If that file already exists, this is a re-run over the same window: rewrite it from the
current record rather than appending.

Then print the notes in chat too, and give the path on the last line.
