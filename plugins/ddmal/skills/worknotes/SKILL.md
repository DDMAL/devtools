---
name: worknotes
description: Write personal markdown work notes covering everything done since last Friday 9am Eastern (or a date you name). Use when the user wants a recap of the past week or a memory aid of recent work (e.g. "what have I been working on", "write my work notes", "/ddmal:worknotes", "/ddmal:worknotes 2026-07-20"). Reads commits, uncommitted changes, handoffs, and Claude Code sessions across all local repos.
---

# Write personal work notes

These notes are a **memory aid for the user, weeks from now** — after the details are gone.
They are not a status report and nobody else reads them. Write for a reader who has forgotten
everything: name the thing, say what changed, say why it mattered, say where it stands.

This is the opposite of `/ddmal:workday`. Nothing is compressed for space. Clarity wins.

## Step 1 — Work out the window

Default start: **the most recent Friday at 09:00 America/New_York**. Run on a Friday, it goes
back a full week rather than a few hours — the point is to cover the week just worked.

```bash
back=$(( ( $(TZ=America/New_York date +%u) + 2 ) % 7 )); [ "$back" -eq 0 ] && back=7
TZ=America/New_York date -v-"${back}"d +%Y-%m-%d 2>/dev/null \
  || TZ=America/New_York date -d "$back days ago" +%Y-%m-%d
```

If the user gave a date or a phrase ("since Monday", "since the 20th", "since 2026-07-20 14:00"),
use that instead, at 09:00 unless they named a time. **Never guess the current date** — the
command above derives it.

Unlike `/ddmal:workday`, this window is anchored to **Eastern**, not the local clock, so a
week's notes cover the same span for everyone in the lab. Set `WORKLOG_TZ` to change that.

State the window you settled on before you write anything, so a wrong default is caught early.

## Step 2 — Collect the record

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/worklog.sh" --since 'YYYY-MM-DD 09:00'
```

If `$CLAUDE_PLUGIN_ROOT` is unset, the script is two levels up from this skill's base
directory: `<skill base dir>/../../scripts/worklog.sh`.

It reports, for every repo in the folder holding your clones: your commits, files changed but
not committed, handoff notes written in the window, and the prompts from your Claude Code
sessions — including the work that never reached a commit.

Read the session prompts closely. Questions the user asked, decisions they pushed back on, and
things they abandoned are exactly what they won't remember, and commits never record them.

## Step 3 — Add what GitHub knows

Reviews, issue discussion, and PRs that others moved leave no local trace. If this plugin's
`github` MCP tools are connected, call `get_me`, then search with `updated:>=<window start>`:

- `search_pull_requests` — `author:@me`, then `reviewed-by:@me`
- `search_issues` — `commenter:@me`

If the tools aren't connected, carry on with the local record and note at the bottom of the
file that GitHub activity isn't included.

## Step 4 — Write the notes

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

## Step 5 — Save and show

Write to `~/worknotes/<start>_to_<end>.md`, e.g. `~/worknotes/2026-07-24_to_2026-07-29.md`
(override with `$WORKNOTES_DIR`). Create the folder if it doesn't exist. These are personal
notes spanning every repo, so they never go inside a project — and never into git.

If that file already exists, this is a re-run over the same window: rewrite it from the
current record rather than appending.

Then print the notes in chat too, and give the path on the last line.
