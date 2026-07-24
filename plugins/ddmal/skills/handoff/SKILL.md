---
name: handoff
description: Write a session handoff document to disk so a fresh session (or a teammate) can resume this work without re-reading the transcript. Use when the user is wrapping up, running low on context, or asks for a handoff (e.g. "write a handoff", "/ddmal:handoff"). Captures goal, state, decisions, verification, git state, and next steps into a `.handoffs/` file.
---

# Write a session handoff

Produce a **distilled briefing** — not a transcript dump, not a vague summary. The next reader has none of this session's context; give them exactly what they need to continue, and nothing they don't.

## Step 1 — Gather ground truth (in parallel)

Don't rely on memory alone. Gather:
- `git branch --show-current`, `git log --oneline -5`, `git status -sb` (branch + ahead/behind + uncommitted).
- The active todo list, if any.
- Which files actually changed this session.

## Step 2 — Detect the chain

Look in `.handoffs/` for a prior handoff on the same workstream (matching slug). If one exists, this handoff continues the chain: increment its sequence number and reference the prior file so the trail stays walkable.

## Step 3 — Write the file

Write to `.handoffs/HANDOFF_<slug>_<YYYY-MM-DD>.md`, where `<slug>` is a short kebab-case name for the workstream. Create `.handoffs/` if needed (it should be gitignored — add it to the repo's `.gitignore` if it isn't already). Use this skeleton; keep each section tight:

```
# Handoff: <workstream> (<date>, seq N)

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

Print the path you wrote, and tell the user a fresh session can pick it up with `/ddmal:resume`.

## Notes
- **Distill.** If a detail wouldn't change what the next session does, leave it out.
- **Preserve decisions and dead ends** — those are exactly what a fresh session cannot reconstruct on its own.
- Write this *before* context degrades (well before you are forced to compact), not after — a handoff written from a degraded context inherits the degradation.
