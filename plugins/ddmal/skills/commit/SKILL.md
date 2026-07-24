---
name: commit
description: Draft a Conventional Commits message for the current changes. Use when the user asks to commit or wants a commit message (e.g. "commit this", "write a commit message", "/ddmal:commit"). Analyses the diff and writes the message to a draft file — it does NOT run commit or push; the user does that.
---

# Draft a commit message

Write a clean [Conventional Commits](https://www.conventionalcommits.org) message for the current changes. **Do not run `git commit` or `git push`** — produce the message and hand the user the exact command to run.

## Step 1 — Inspect the changes

- Run `git status --short` and `git diff --staged` (staged) or `git diff HEAD` (everything). If nothing is staged, review the unstaged changes and note that the user will need to `git add` first — suggest the logical grouping.
- If the changes span **multiple unrelated concerns**, say so and propose splitting them into separate commits, one message per logical unit. Don't force unrelated changes into one commit.

## Step 2 — Write the message

Format: `type(scope): subject`

- **type** — one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`.
- **scope** — optional; the area touched, e.g. `fix(auth):`.
- **subject** — imperative mood, lowercase, no trailing period, ≤ ~72 chars ("add", not "added"/"adds").
- **body** (optional, after a blank line) — explain the *why* when it isn't obvious from the subject: the constraint, the root cause, the reason for the chosen approach. Wrap at ~72 chars. Skip the body for trivial changes.
- Reference issues in the footer where relevant (`Refs #123`, `Closes #123`).
- **Do NOT add a `Co-Authored-By` trailer.**

## Step 3 — Hand it over

Write the message to `.git/COMMIT_DRAFT` (inside `.git/`, so it is never tracked) and also print it in a code block. Then give the user the exact command to run and push:

```
git commit -F .git/COMMIT_DRAFT && git push
```

For multiple commits, give the full `git add …` + `git commit -F …` sequence, one per logical unit. The user reviews and runs it — **you do not commit or push.**
