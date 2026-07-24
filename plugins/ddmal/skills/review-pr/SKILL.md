---
name: review-pr
description: Critically review a GitHub pull request from any DDMAL repo. Use when the user asks to review a PR or passes an `owner/repo#number` or a bare PR number (e.g. "review PR 2118", "/ddmal:review-pr DDMAL/CantusDB#2118", "review 2118"). Fetches the PR, its linked issues, and its review state via the GitHub MCP server, reads the diff, layers in any repo-local review rubric, and produces a structured critical review in chat.
---

# Review a pull request

You are reviewing a pull request critically and honestly. The goal is a clean codebase with no tech debt. This is a **second, human-assist pass** on top of any automated bot review (CodeRabbit, Copilot) — your job is the judgment call, not the first automated sweep. **Do not approve a PR you have concerns about** — call them out, with reasoning. You are expected to push back on the approach itself, not just the surface code, if you think it is wrong.

## Input

The user passes one of:
- `owner/repo#N` (e.g. `DDMAL/CantusDB#2118`) — explicit.
- a bare number `N` — infer `owner`/`repo` from the current git remote (`git remote get-url origin`). If there is no remote, or you are not in a repo, ask for the full `owner/repo#N`.

Call `get_me` once for context on who is reviewing.

## Step 1 — Load the PR

Use the GitHub MCP tools (from the `github` server bundled with this plugin):
- `pull_request_read` method `get` → title, body, state, head/base branches, mergeable status.
- `pull_request_read` method `get_files` → changed files.
- `pull_request_read` method `get_check_runs` → CI status.

Note the base and head branches, CI status, and the changed-file list.

## Step 2 — Understand the issue(s) it claims to fix

From the PR body and comments, extract every `#NNN` reference and every `closes/fixes/resolves #N`. For each:
- `issue_read` method `get` + `get_comments` → what is actually being asked for, the stated acceptance criteria, any discussion that constrains the fix.
- Use `search_issues` for related or duplicate context when useful.

**You must understand the issue before you can judge the fix.** If the issue is ambiguous, say so — that itself is a finding.

## Step 3 — Check review state

- `pull_request_read` methods `get_reviews` + `get_review_comments` (inline threads, each with a resolved/unresolved state) + `get_comments` (the conversation).
- **Automated reviewer present?** Flag if neither CodeRabbit nor Copilot has reviewed. (CodeRabbit is the active bot on CantusDB.)
- **Bot / human comments addressed?** For each substantive comment, look for (a) an author reply with reasoning, (b) a subsequent commit that addresses it, or (c) an explicit "won't fix" with justification. A comment dismissed without any of these is a finding. Unresolved threads with substantive concerns are blockers.
- **CI.** Red CI without an explanation in the PR body is a blocker.

## Step 4 — Read the diff

Prefer **local git** when you are inside the target repo (best for reading surrounding code in the working tree):

```
git fetch origin pull/<N>/head
git diff <base>...FETCH_HEAD
```

If the repo is not checked out, fall back to `pull_request_read` method `get_diff` plus `get_file_contents` for surrounding code.

**Never review a diff in isolation** — read enough of the surrounding code to judge each change in context.

## Step 5 — Load the target repo's review rubric (if any)

Load `.claude/review-rubric.md` from the **target** repo (the one the PR belongs to, not necessarily the one you're sitting in):

- If you are inside the target repo, read it from disk.
- If you are reviewing a repo you are not checked out in, fetch it via `get_file_contents` (path `.claude/review-rubric.md`) so cross-repo reviews still pick it up.

If present, **apply its checks on top of the generic rubric below** — it holds this project's specific gotchas (framework quirks, migration rules, naming traps, deployment ripple effects) that a generic review would miss.

If absent, proceed with the generic rubric, and at the end of your review add a one-line note suggesting the team capture recurring gotchas in `.claude/review-rubric.md` so future reviews inherit them.

## Step 6 — Evaluate (generic rubric)

Be specific: cite `path/to/file:line` for every finding.

### Does it actually fix the issue?
- Map each acceptance criterion → diff hunk.
- Root cause, or a symptom patch?
- Is the same bug elsewhere in the codebase that this PR misses? (Grep for the pattern.)

### Scope creep — default position: less is more
- Flag anything not required for the stated issue: unrelated refactors, drive-by renames, formatting churn, "while I'm here" cleanups. Recommend splitting into a separate PR or dropping.
- Exception: a trivial fix adjacent to the real change (a typo in a neighbouring comment) is fine — don't be pedantic.

### Code quality & tech debt
- Type hints / types on new code, per the repo's conventions; untyped code touched here should gain them.
- Naming and readability consistent with the surrounding file's style.
- No dead code, commented-out blocks, or `TODO` left without a tracking issue.
- No premature abstraction (a helper used in one place is usually wrong); no defensive checks for impossible cases.
- Comments only where the *why* is non-obvious.
- No backwards-compat shims for code paths that no longer exist.

### Tests
- Present at all? If not, why — genuinely untestable, or just untested?
- Do they assert meaningful behaviour, or just exercise the happy path?
- Edge cases: empty input, missing optional relations, unauthenticated users, permission boundaries.
- For bug fixes: a regression test that fails without the fix.

### Security
- Auth / permission checks on new endpoints.
- No secrets, keys, or credentials in the diff.
- No raw SQL, shell, or templates interpolating untrusted input.
- File uploads and redirects validated.

### Ripple effects
- Anything outside the diff this breaks: config / deployment, docs / wiki, public URLs or APIs, other open PRs or branches. (The repo rubric may name specific places to check.)

## Step 7 — Respond in chat

Reply directly in chat — **do not** write a file, and **do not** post inline PR comments (the PAT is read-only). Use these headings (so the user can skim), conversational underneath, as thorough as the PR warrants:

- **What this PR does** — 2–3 sentences in your own words, not the author's.
- **Linked issues** — one line each on what was actually asked.
- **Does it fix the issue?** — yes / partially / no, with reasoning; criteria → hunks.
- **Review state** — automated reviewer (y/n), bot comments addressed (y/partial/n + detail), human comments addressed, CI status.
- **Blockers** — must-fix before merge, each with `file:line` and reasoning.
- **Scope creep** — split out or drop, each with `file:line`.
- **Concerns** — non-blocking but worth discussing.
- **Nits** — tiny stuff; include if found, don't hunt for them.
- **What's good** — explicit callouts; don't skip this, it calibrates the rest.
- **Recommendation** — Approve / Approve with nits / Request changes / Needs discussion, with a paragraph explaining the call.

## Operating notes
- **Honest, not polite.** Approving bad code is worse than bluntness.
- **Cite specifics.** A finding without `file:line` is not actionable.
- **Don't repeat the bot** unless you disagree or are elevating a point to a blocker.
- **Match scope to evidence.** No speculative performance or security claims without a named suspect line. Verbose is welcome; manufactured concerns are not.
- You may need to read code outside the diff to judge a change in context. Use the Explore subagent for broad "what else depends on this" sweeps to keep the main context clean.
