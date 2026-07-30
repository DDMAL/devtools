---
name: review-pr
description: Critically review a GitHub pull request from any DDMAL repo. Use when the user asks to review a PR or passes an `owner/repo#number` or a bare PR number (e.g. "review PR 2118", "/ddmal:review-pr DDMAL/CantusDB#2118", "review 2118"). Fetches the PR, its linked issues, and its review state via the GitHub MCP server, reads the diff, layers in any repo-local review rubric, and produces a structured critical review in chat.
argument-hint: "[owner/repo#number | number]"
context: fork
background: false
allowed-tools: Bash(git fetch:*) Bash(git diff:*) Bash(git log:*) Bash(git remote:*) Bash(git rev-parse:*) Bash(git branch:*)
---

# Review a pull request

You are reviewing a pull request critically and honestly. The goal is a clean codebase with no tech debt. This is a **second, human-assist pass** on top of any automated bot review (CodeRabbit, Copilot) — your job is the judgment call, not the first automated sweep. **Do not approve a PR you have concerns about** — call them out, with reasoning. You are expected to push back on the approach itself, not just the surface code, if you think it is wrong.

This skill runs in its own forked context, so reading the full diff and the surrounding code costs the main session nothing. Read as widely as you need to.

## Input

`$ARGUMENTS` is one of:

- `owner/repo#N` (e.g. `DDMAL/CantusDB#2118`) — explicit.
- a bare number `N` — infer `owner`/`repo` from `git remote get-url origin`. If there is no remote, or you are not in a repo, ask for the full `owner/repo#N`.

## Step 0 — Confirm the GitHub tools are live

This review needs the `github` MCP server bundled with this plugin. The diff alone is **not** a review — you need PR metadata, linked issues, review threads, and CI, and only the MCP tools provide those (`gh` is not on `PATH` in the VS Code extension environment). The tools arrive *deferred*: listed by name, schemas loaded on demand. Load what you need with `ToolSearch`, using fully qualified names:

```
select:mcp__plugin_ddmal_github__get_me,mcp__plugin_ddmal_github__pull_request_read,mcp__plugin_ddmal_github__issue_read
```

Then call `mcp__plugin_ddmal_github__get_me` once, both to confirm the server answers and for context on who is reviewing.

If those names aren't in scope at all, the plugin isn't active in this Claude Code window — stop and tell the user to relaunch Claude Code, then retry. Do **not** silently downgrade to a diff-only "review", and do **not** report it as the server "needing authentication". The README's troubleshooting table covers the rest.

The server is pinned **read-only**, so no write tool exists to reach for even by accident.

## Step 1 — Load the PR

- `mcp__plugin_ddmal_github__pull_request_read` method `get` → title, body, state, head/base branches, mergeable status.
- same tool, method `get_files` → changed files.
- same tool, method `get_check_runs` → CI status.

Note the base and head branches, CI status, and the changed-file list.

## Step 2 — Understand the issue(s) it claims to fix

From the PR body and comments, extract every `#NNN` reference and every `closes/fixes/resolves #N`. For each:

- `mcp__plugin_ddmal_github__issue_read` method `get` + `get_comments` → what is actually being asked for, the stated acceptance criteria, any discussion that constrains the fix.
- `mcp__plugin_ddmal_github__search_issues` for related or duplicate context when useful.

**You must understand the issue before you can judge the fix.** If the issue is ambiguous, say so — that itself is a finding.

## Step 3 — Check review state

- `mcp__plugin_ddmal_github__pull_request_read` methods `get_reviews` + `get_review_comments` (inline threads, each with a resolved/unresolved state) + `get_comments` (the conversation).
- **Bot / human comments addressed?** For each substantive comment, look for (a) an author reply with reasoning, (b) a subsequent commit that addresses it, or (c) an explicit "won't fix" with justification. A comment dismissed without any of these is a finding. Unresolved threads with substantive concerns are blockers.
- **CI.** Red CI without an explanation in the PR body is a blocker.

## Step 4 — Read the diff

Prefer **local git** when you are inside the target repo (best for reading surrounding code in the working tree):

```
git fetch origin pull/<N>/head
git diff <base>...FETCH_HEAD
```

If the repo is not checked out, fall back to `mcp__plugin_ddmal_github__pull_request_read` method `get_diff` plus `mcp__plugin_ddmal_github__get_file_contents` for surrounding code.

**Never review a diff in isolation** — read enough of the surrounding code to judge each change in context.

## Step 5 — Load the repo's project context

A repo's own docs carry the project-specific gotchas a generic review would miss. Read whichever of these exist in the repo the PR belongs to and layer their checks on top of the generic rubric below:

- **`CLAUDE.md`** (repo root) — the primary source. Architecture, conventions, framework quirks, migration/permission rules, deployment and ripple effects. Treat its "never / always / must / don't" statements as review gates.
- **`REVIEW.md`** (repo root, optional) — review-only gates layered on top of `CLAUDE.md`. This is the same file Anthropic's managed Code Review reads, so a repo maintains one rubric for both.

If **neither** exists, run the generic rubric alone — do not invent project-specific rules.

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

- Anything outside the diff this breaks: config / deployment, docs / wiki, public URLs or APIs, other open PRs or branches. (`REVIEW.md` may name specific places to check.)

## Step 7 — Respond in chat

Reply directly in chat — **do not** write a file, and **do not** post inline PR comments (the server is read-only). Use these headings (so the user can skim), conversational underneath, as thorough as the PR warrants:

- **What this PR does** — 2–3 sentences in your own words, not the author's.
- **Linked issues** — one line each on what was actually asked.
- **Does it fix the issue?** — yes / partially / no, with reasoning; criteria → hunks.
- **Review state** — bot comments addressed (y/partial/n + detail), human comments addressed, CI status.
- **Blockers** — must-fix before merge, each with `file:line` and reasoning.
- **Scope creep** — split out or drop, each with `file:line`.
- **Concerns** — non-blocking but worth discussing.
- **Nits** — tiny stuff; include if found, don't hunt for them.
- **Recommendation** — Approve / Approve with nits / Request changes / Needs discussion, with a paragraph explaining the call.

## Operating notes

- **Honest, not polite.** Approving bad code is worse than bluntness.
- **Cite specifics.** A finding without `file:line` is not actionable.
- **Don't repeat the bot** unless you disagree or are elevating a point to a blocker.
- **Match scope to evidence.** No speculative performance or security claims without a named suspect line. Verbose is welcome; manufactured concerns are not.
