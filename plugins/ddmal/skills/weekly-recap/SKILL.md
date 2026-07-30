---
name: weekly-recap
description: Write personal markdown work notes covering everything done since last Friday 9am Eastern (or a date you name). Use when the user wants a recap of the past week or a memory aid of recent work (e.g. "what have I been working on", "write my work notes", "/ddmal:weekly-recap", "/ddmal:weekly-recap 2026-07-20"). Reads commits, uncommitted changes, handoffs, and Claude Code sessions across all local repos.
argument-hint: "[since Monday | 2026-07-20 | 2026-07-20 14:00]"
allowed-tools: Bash(date:*) Bash(git rev-parse:*) Bash(mkdir:*) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/worklog.sh *)
---

# Write personal work notes

These notes are a **memory aid for the user, weeks from now** — after the details are gone.
They are not a status report and nobody else reads them. Write for a reader who has forgotten
everything: name the thing, say what changed, say why it mattered, say where it stands.

This is the opposite of `/ddmal:daily-recap`. Nothing is compressed for space. Clarity wins.

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

Group by project. Within a project, run roughly chronologically, but merge related commits
into one bullet — one bullet per *piece of work*, never one per commit.

```markdown
# Work notes: <Fri 24 Jul, 9:00am> to <Wed 29 Jul, 1:40pm>

## <Project>

- <What was done, what it fixes or adds, and why it was needed.>
- <Decisions made, and the reasoning — especially where an obvious approach was rejected.>

## <Next project>

- ...

## Where things stand

- <Unfinished work, and the next concrete step.>
- <PRs waiting on review, branches with uncommitted changes, open questions.>
```

Writing rules:

- **Full, plain sentences.** Don't drop articles or compress into telegraph style. "Fixed the
  siglum in the concordances export, which was serving a stale cached value" — not "Fixed
  siglum cache concordances export".
- **One or two lines per bullet.** Short, but complete.
- **Keep the identifiers.** PR and issue numbers, branch names, and filenames are the point
  here — they're how the user finds the work again.
- **Record decisions and dead ends.** What was tried and rejected, and why, is the highest
  value thing in the file; it's also the only part nothing else captures.
- **Say what's unverified.** If something was written but never tested or run, say so.
- Skip trivia. Formatting-only commits and typo fixes don't earn a bullet.
- Don't pad. A quiet week is a short file.

**Only write what the record supports.** Where the evidence is thin (a session with prompts
but no commits), say what was worked on and mark it as unfinished — don't infer an outcome.

## Step 4 — Save and show

Write to `~/worknotes/<start>_to_<end>.md`, e.g. `~/worknotes/2026-07-24_to_2026-07-29.md`
(override with `$WORKNOTES_DIR`). Create the folder if it doesn't exist. These are personal
notes spanning every repo, so they never go inside a project — and never into git.

If that file already exists, this is a re-run over the same window: rewrite it from the
current record rather than appending.

Then print the notes in chat too, and give the path on the last line.
