---
name: commit
description: Draft a Conventional Commits message for the current changes. Use when the user asks to commit or wants a commit message (e.g. "commit this", "write a commit message", "/ddmal:commit"). Analyzes the diff and writes the message to a draft file — it does NOT run commit or push; the user does that.
allowed-tools: Bash(git status:*) Bash(git diff:*) Bash(git log:*) Bash(git rev-parse:*)
---

# Draft a commit message

Write a clean [Conventional Commits](https://www.conventionalcommits.org) message for the current changes. **Do not run `git commit` or `git push`** — produce the message and hand the user the exact command to run.

## The current changes

- Git dir: !`git rev-parse --path-format=absolute --git-dir`
- Status: !`git status --short`
- Staged: !`git diff --staged --stat`
- Unstaged: !`git diff --stat`

## Step 1 — Read the diff

The stats above tell you *what* changed; read the actual diff to learn *why*. Use `git diff --staged` if anything is staged, otherwise `git diff HEAD`.

- **Nothing staged?** Review the unstaged changes, note that the user will need to `git add` first, and suggest the logical grouping.
- **Multiple unrelated concerns?** Say so and propose splitting them into separate commits, one message per logical unit. Don't force unrelated changes into one commit.

## Step 2 — Write the message

Format: `type(scope): subject`

- **type** — one of `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `build`, `ci`, `chore`.
- **scope** — optional; the area touched, e.g. `fix(auth):`.
- **subject** — imperative mood, lowercase, no trailing period, ≤ ~72 chars ("add", not "added"/"adds").
- **body** (optional, after a blank line) — explain the *why* when it isn't obvious from the subject: the constraint, the root cause, the reason for the chosen approach. Wrap at ~72 chars. Skip the body for trivial changes.
- Reference issues in the footer where relevant (`Refs #123`, `Closes #123`).
- **Do NOT add a `Co-Authored-By` trailer.**

### What good looks like

**A fix whose cause needs explaining:**

```
fix(auth): stop token refresh racing logout

The refresh timer kept firing after logout cleared the session, so a
stale token could be written back seconds later. Cancel the timer in
the logout path rather than checking for a session inside the timer.

Closes #412
```

**A feature that speaks for itself — no body needed:**

```
feat(search): add sort-by-siglum to the source list
```

**A mixed chore, where the body earns its place as a list:**

```
chore: update dev dependencies

- pytest 7.4 → 8.0 (drops the deprecated yield_fixture)
- ruff 0.4 → 0.6; re-format two files the new rules caught
```

## Step 3 — Hand it over

Write the message to `<git-dir>/COMMIT_DRAFT`, using the **Git dir** path resolved above — not a literal `.git/`, which is a *file* rather than a directory in a worktree or submodule. Anything inside the git dir is never tracked.

Print the message in a code block too, then give the user the exact command:

```
git commit -F "<git-dir>/COMMIT_DRAFT" && git push
```

For multiple commits, give the full `git add …` + `git commit -F …` sequence, one per logical unit. The user reviews and runs it — **you do not commit or push.**
