---
name: handoff
description: Write a session handoff document to disk so a fresh session or another agent can resume this work without re-reading the transcript. Use when the user is wrapping up, running low on context, or asks for a handoff (e.g. "write a handoff", "hand this off and note what's left", "/ddmal:handoff"). Captures goal, state, decisions, verification, git state, and next steps into a `.handoffs/` file.
allowed-tools: Bash(git branch:*) Bash(git log:*) Bash(git status:*) Bash(git rev-parse:*) Bash(git diff:*) Bash(date:*) Bash(mkdir:*) Bash(ls:*) Bash(grep:*)
---

# Write a session handoff

Produce a **distilled briefing** — not a transcript dump, not a vague summary. The next reader has none of this session's context; give them exactly what they need to continue, and nothing they don't.

## Ground truth

- Now: !`date '+%Y-%m-%d %H:%M'`
- Repo root: !`git rev-parse --show-toplevel`
- Branch + tracking: !`git status -sb | head -1`
- Recent commits: !`git log --oneline -5`
- Working tree: !`git status --short`
- Existing handoffs: !`ls -1 "$(git rev-parse --show-toplevel)/.handoffs" 2>/dev/null || echo "(none yet)"`
- Their supersede state: !`grep -H 'Superseded by:' "$(git rev-parse --show-toplevel)"/.handoffs/*.md 2>/dev/null || echo "(none)"`

**Never guess the date** — the filename and the resume ordering both depend on it, and it is resolved above. Add to this only what the facts above don't cover: which files you actually changed this session, and the active todo list if there is one.

## Step 1 — Make sure `.handoffs/` exists and is excluded

Handoffs live in `.handoffs/` at the repo root and are **local to this clone** — notes to the next session, not something to commit.

Keep them out of git via `.git/info/exclude`, **not `.gitignore`**. `.gitignore` is tracked, so editing it drops your personal setup into everyone else's diff; `.git/info/exclude` does the same job for this clone only. Run:

```bash
cd "$(git rev-parse --show-toplevel)" && mkdir -p .handoffs
EXCLUDE="$(git rev-parse --path-format=absolute --git-common-dir)/info/exclude"
grep -qxF '.handoffs/' "$EXCLUDE" 2>/dev/null || echo '.handoffs/' >> "$EXCLUDE"
```

**Never edit the repo's `.gitignore` for this.** (If the repo already ignores `.handoffs/` itself, this is a no-op — leave its `.gitignore` alone either way.)

## Step 2 — Retire the previous handoff

From the supersede state above, look for an earlier handoff on the same workstream (matching slug) whose `Superseded by:` line is still `—`. If one exists, this handoff continues that chain:

- Increment its sequence number for the new file.
- In that prior file, replace `Superseded by: —` with `Superseded by: <new filename>`. This is what stops `/ddmal:resume` from picking up a retired handoff.
- Name it in the new file's `Continues:` line so the trail stays walkable.

If no live handoff exists for this slug, this is seq 1 and `Continues:` is `—`.

**Don't delete old handoffs.** They are the record of what was decided and why; superseding is enough.

## Step 3 — Write the file

Write to `.handoffs/HANDOFF_<slug>_<YYYY-MM-DD>_<HHMM>.md`, using the timestamp above and a short kebab-case `<slug>` for the workstream. The time in the filename means two handoffs on one day never collide, and sorting filenames alphabetically sorts them chronologically.

Use this skeleton; keep each section tight:

```
# Handoff: <workstream> (seq N)

Written: <YYYY-MM-DD HH:MM>
Continues: <prior filename, or —>
Superseded by: —

## Goal
<One short paragraph: what we're actually trying to accomplish, and why.>

## Current state
<Bullets: where things stand right now.>

## What we tried & decided
<Approaches taken — including dead ends — and key decisions WITH their reasoning,
so the next session doesn't re-litigate settled calls.>

## Verification
<What was tested and passed. AND — explicitly — what was NOT tested or verified.
This is the most valuable section; be honest about the gaps.>

## Git state
Branch: <branch> · Last commit: <short sha + subject> · Pushed: <yes/no> · Uncommitted: <summary>

## Next steps
1. <ordered, specific>
2. ...

## Quick start
<Exact commands to resume, and the files to open first.>
```

## Step 4 — Report

Print the path you wrote, note which prior handoff you superseded (if any), and tell the user a fresh session can pick it up with `/ddmal:resume`.

## Notes

- **Distill.** If a detail wouldn't change what the next session does, leave it out.
- **Preserve decisions and dead ends** — those are exactly what a fresh session cannot reconstruct on its own.
- Write this *before* context degrades (well before you are forced to compact), not after — a handoff written from a degraded context inherits the degradation.
