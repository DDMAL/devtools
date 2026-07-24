---
name: resume
description: Resume work from the most recent handoff document. Use at the start of a fresh session to pick up where a previous one left off (e.g. "resume", "/ddmal:resume", "continue from the handoff"). Reads the latest file in `.handoffs/`, verifies the state still matches, and confirms the plan before continuing.
---

# Resume from a handoff

## Step 1 — Find the handoff

- If the user passed a path, use it.
- Otherwise read `.handoffs/` and pick the most recent `HANDOFF_*.md` (by date, then sequence number). If several distinct workstreams exist, list them and ask which to resume.
- If `.handoffs/` is empty or absent, say so and ask what to work on.

## Step 2 — Orient and check for drift

Read the handoff. Then verify the ground truth still matches: check `git status -sb`, the current branch, and the last commit against the handoff's **Git state** section. Flag any drift out loud — new commits since the handoff, a different branch, or uncommitted changes that weren't noted.

If the handoff references a prior one in a chain, skim that for context, but don't re-read the whole chain unless something is unclear.

## Step 3 — Confirm, then continue

Summarize back to the user in 3–5 lines: the goal, where things stand, and the immediate next step. **Confirm this is still the plan before diving in** — the situation may have changed since the handoff was written. Then continue the work.
