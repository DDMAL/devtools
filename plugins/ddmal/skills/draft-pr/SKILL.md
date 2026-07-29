---
name: draft-pr
description: Draft a pull request and emit a ready-to-click, pre-filled GitHub compare URL. Use when the user wants to open a PR for the current branch (e.g. "draft a PR", "open a pull request", "/ddmal:draft-pr"). Writes the title/body from the branch's commits and diff and hands over a link that lands on GitHub's Create-PR form with everything filled in — it does NOT create the PR or push; the human does both.
allowed-tools: Bash(git branch:*) Bash(git log:*) Bash(git diff:*) Bash(git remote:*) Bash(git rev-parse:*) Bash(git symbolic-ref:*) Bash(git status:*) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/prefill-url.sh *)
---

# Draft a pull request

Turn the current branch into a PR the user can create with one click. You draft the title and body from the branch's commits and diff, then hand over a **pre-filled GitHub compare URL** — the link opens GitHub's Create-pull-request form with the title, body, and options already populated, and the human reviews and clicks **Create pull request**.

**You mutate nothing.** You don't create the PR, and you don't push. This skill only reads git, writes a scratch file inside the git dir, and prints a link. It mirrors `/ddmal:commit`: it drafts and hands over, the human executes.

## Branch state

- Git dir: !`git rev-parse --path-format=absolute --git-dir`
- Head branch: !`git branch --show-current`
- Origin: !`git remote get-url origin`
- Default branch: !`git symbolic-ref --short refs/remotes/origin/HEAD 2>/dev/null || echo "(unset — assume main)"`
- Upstream: !`git rev-parse --abbrev-ref --symbolic-full-name '@{u}' 2>/dev/null || echo "(none — this branch has never been pushed)"`
- Commits not yet pushed: !`git log --oneline '@{u}..HEAD' 2>/dev/null || echo "(no upstream to compare against)"`
- Commits vs. default branch: !`git log --oneline origin/HEAD..HEAD 2>/dev/null || echo "(cannot resolve origin/HEAD)"`

## Step 1 — Check the branch is PR-able

From the state above:

- **head** = the current branch. **If head is the default branch** (`main`/`master`), stop — there's nothing to PR. Ask the user to switch to (or create) a feature branch first.
- **base** = the default branch, with the `origin/` prefix stripped; fall back to `main` if it's unset.
- **owner/repo** — parse from the origin URL. Both forms appear: `git@github.com:DDMAL/CantusDB.git` (SSH) and `https://github.com/DDMAL/CantusDB.git` (HTTPS). Strip the host prefix and the trailing `.git` → `DDMAL/CantusDB`. If origin isn't a GitHub remote (or there's no remote), ask the user for `owner/repo`.

## Step 2 — Require the branch to be on the remote

GitHub computes the compare diff server-side, so the head branch **must exist on origin** and be current, or the pre-filled form comes up empty. **You never push** — pushing is the human's call, and on an auto-deploy repo it's the first step of a chain that ends in production.

- **Upstream exists and there are no unpushed commits** → good, continue to Step 3.
- **No upstream, or commits listed as not yet pushed** → stop. Show the user which commits are missing from the remote and hand them the command:

  ```
  git push -u origin <head>
  ```

  Tell them to run it and then re-run `/ddmal:draft-pr`. Do not build the URL — it is useless until the remote has the branch, and a stale link produces an empty or wrong diff on GitHub.

> ⚠️ **SESEMMI (and any auto-deploy-on-merge repo):** a merge to `main` auto-deploys. This skill touches nothing, so drafting is always safe. Remember that the human's click-to-merge is the deploy trigger.

## Step 3 — Draft the title and body

Read the branch's history and changes to write the PR — don't just echo the commit subjects:

```
git log <base>..<head> --oneline
git diff <base>...<head>
```

- **Title** — one line, imperative mood, describing the change as a whole (not a list of commits). If the branch is a single logical change, the lead commit's subject is often a good start; if it spans several, summarize the theme.
- **Body — short by default.** Most PRs need only a sentence or two on what changed and why; the reviewer reads the diff for the rest. Don't pad with headings or a "Testing" section a small change doesn't need. Reach for a `## Summary` / `## What changed` / `## Testing` structure **only** when the PR is genuinely large, risky, or non-obvious. Keep it plain and readable either way — never sacrifice clarity for brevity, and never drop into a cramped, keyword-only style.
- **Don't hard-wrap the body.** Unlike a commit message, a PR body is GitHub-rendered markdown, and GitHub turns a single newline inside a paragraph into a hard line break — so wrapping at ~72 chars produces ugly mid-sentence breaks. Write each paragraph or bullet as **one line** and separate blocks with a blank line; let the editor soft-wrap.
- **Linked issues** — scan the commits and branch name for issue numbers; add `Closes #N` / `Refs #N` where they genuinely apply.
- **Repo PR template** — if the repo has one (`.github/pull_request_template.md`, `.github/PULL_REQUEST_TEMPLATE.md`, or a file under `.github/PULL_REQUEST_TEMPLATE/`), read it and **structure the body to match its sections** (the pre-fill overrides GitHub's auto-loaded template, so honour it yourself).
- **Do NOT add a `Co-Authored-By` trailer.**

## Step 4 — Build the pre-filled compare URL

Write the title and body to files inside the git dir, then let the bundled script do the URL encoding and the length check:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/prefill-url.sh" pr \
  --repo <owner>/<repo> --base <base> --head <head> \
  --title-file "<git-dir>/PR_TITLE" --body-file "<git-dir>/PR_BODY"
```

Use the **Git dir** path resolved at the top — not a literal `.git/`, which is a *file* rather than a directory in a worktree or submodule. The script prints the URL on stdout and `ok: <n> chars` on stderr.

Add `--param labels=a,b`, `--param assignees=user`, or `--param reviewers=user` only if the user asked for them.

**If the script reports `OVER LIMIT`** (past ~8,000 characters, where browsers and GitHub start returning 414), shorten the *linked* body to a summary plus "full description below", rebuild, and give the full body to the user separately in Step 5 to paste in.

## Step 5 — Hand it over

- Write the final title and body to **`<git-dir>/PR_DRAFT`**, same as `/ddmal:commit` writes `COMMIT_DRAFT`.
- In chat: print the **compare URL** as a clickable link, and print the **title + body** in a code block so the user can read (and, if the URL was trimmed for length, paste) it.
- Tell the user plainly: **click the link, review the pre-filled form on GitHub, and click _Create pull request_.** You have not created it.

## Operating notes

- **Zero mutations.** No PR is created, nothing is pushed, and the GitHub MCP server is pinned read-only, so no write tool exists to reach for. The only file written is a scratch draft inside the git dir.
- **Don't guess owner/repo or base** — derive them from git; ask if git can't tell you.
- **Scope boundary.** PR *creation* and *new issues* both have pre-fill URLs, which is why this skill can exist. PR *inline review comments* do not — that's why `/ddmal:review-pr` stays chat-only.
