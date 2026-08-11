---
name: resume
description: Resume work from the most recent handoff document. Use at the start of a fresh session to pick up where a previous one left off (e.g. "resume", "/ddmal:resume", "continue from the handoff"). Reads the latest live file in `.handoffs/`, verifies the state still matches, and confirms the plan before continuing.
argument-hint: "[path to a specific handoff]"
allowed-tools: Bash(git branch:*) Bash(git log:*) Bash(git status:*) Bash(git rev-parse:*) Bash(date:*) Bash(ls:*) Bash(grep:*)
---

# Resume from a handoff

## Ground truth

- Now: !`date '+%Y-%m-%d %H:%M'`
- Branch + tracking: !`git status -sb | head -1`
- Last commit: !`git log --oneline -1`
- Working tree: !`git status --short`
- Handoffs: !`ls -1 "$(git rev-parse --show-toplevel)/.handoffs" 2>/dev/null || echo "(no .handoffs directory)"`
- Their supersede state: !`grep -rH --include='*.md' 'Superseded by:' "$(git rev-parse --show-toplevel)/.handoffs" 2>/dev/null || echo "(none)"`

## Step 1 — Find the handoff

- If the user passed a path (`$ARGUMENTS`), use it.
- Otherwise pick from the listing above. **Skip any file whose `Superseded by:` line names another file** — those are retired. Among what's left, the most recent is the last one alphabetically: filenames carry a `YYYY-MM-DD_HHMM` stamp, so alphabetical order is chronological order.
- If several distinct workstreams (slugs) are still live, list them and ask which to resume.
- If `.handoffs/` is empty or absent, say so and ask what to work on.

## Step 2 — Orient and check for drift

Read the handoff, then compare it against the ground truth above. Flag any drift out loud before proposing to continue:

- New commits since the handoff was written.
- A different branch than the handoff expects.
- Uncommitted changes the handoff didn't note.
- **The handoff's branch is gone or already merged** — the work may be done. Say so rather than resuming it.
- **The handoff is more than a few days old** — treat its claims as suspect and re-verify rather than assuming.

If the handoff names a prior one in its `Continues:` line, skim that for context, but don't re-read the whole chain unless something is unclear.

## Step 3 — Confirm, then continue

Summarize back to the user in 3–5 lines: the goal, where things stand, and the immediate next step. **Confirm this is still the plan before diving in** — the situation may have changed since the handoff was written. Then continue the work.

## Step 4 — Mark it resumed

Once the user confirms, add a `Resumed: <YYYY-MM-DD HH:MM>` line to the handoff, under its `Superseded by:` line.

**Do not delete the file.** It stays as the record of what was decided and why; `/ddmal:handoff` retires it properly when the next handoff supersedes it.
