---
name: draft-pr
description: Draft a pull request and emit a ready-to-click, pre-filled GitHub compare URL. Use when the user wants to open a PR for the current branch (e.g. "draft a PR", "open a pull request", "/ddmal:draft-pr"). Writes the title/body from the branch's commits and diff and hands over a link that lands on GitHub's Create-PR form with everything filled in — it does NOT create the PR; the human clicks *Create*.
---

# Draft a pull request

Turn the current branch into a PR the user can create with one click. You draft the title and body from the branch's commits and diff, then hand over a **pre-filled GitHub compare URL** — the link opens GitHub's Create-pull-request form with the title, body, and options already populated, and the human reviews and clicks **Create pull request**.

**You do not create the PR.** This skill is read-only against GitHub — it never uses the plugin's GitHub PAT to write. It mirrors `/ddmal:commit`: it drafts and hands over, the human executes. The one thing it *does* do is push the branch to the remote (via the user's own git credentials, after confirming), because GitHub can't compute the compare diff for a branch it hasn't seen.

## Step 1 — Work out the branches and the repo

```
git branch --show-current          # head = the branch you're PR-ing
git remote get-url origin          # to parse owner/repo
git symbolic-ref --short refs/remotes/origin/HEAD   # e.g. origin/main → base = main
```

- **head** = the current branch. **If head is the default branch itself** (`main`/`master`), stop — there's nothing to PR. Ask the user to switch to (or create) a feature branch first.
- **base** = the repo's default branch (strip the `origin/` prefix from the `symbolic-ref` output; fall back to `main` if it isn't set).
- **owner/repo** — parse from the origin URL. Both forms appear: `git@github.com:DDMAL/CantusDB.git` (SSH) and `https://github.com/DDMAL/CantusDB.git` (HTTPS). Strip the host prefix and the trailing `.git` → `DDMAL/CantusDB`. If origin isn't a GitHub remote (or there's no remote), ask the user for `owner/repo`.

> ⚠️ **SESEMMI (and any auto-deploy-on-merge repo):** a merge to `main` auto-deploys. This skill never pushes `main` — it pushes your *feature* branch — so drafting is safe. Just never run it while sitting on `main`, and remember the human's click-to-merge is the deploy trigger.

## Step 2 — Make sure the head branch is on the remote

GitHub computes the compare diff server-side, so the head branch **must exist on origin** and be current, or the pre-filled form comes up empty.

```
git log origin/<head>..<head> --oneline   # commits not yet pushed (fails if origin/<head> doesn't exist → not pushed at all)
```

- **Already pushed and up to date** → nothing to do; go to Step 3.
- **Not pushed, or local is ahead** → show the user exactly which commits will go up, then **confirm before pushing**. On confirmation:

  ```
  git push -u origin <head>
  ```

  This uses **the user's own git credentials** — not the plugin's read-only PAT (git push doesn't touch the MCP token at all). If the push is declined, stop and hand the user the command to run themselves; the URL is useless until the branch is on origin.

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

The target form is GitHub's compare view with query params:

```
https://github.com/<owner>/<repo>/compare/<base>...<head>?expand=1&title=<url-encoded-title>&body=<url-encoded-body>
```

`expand=1` opens the form directly. Optional extra params: `&labels=a,b`, `&assignees=user`, `&reviewers=user` — add them only if the user asked. **Title and body must be URL-encoded.** Don't hand-encode; write the two fields to files and let a tool do it. A reliable recipe (works on macOS):

```
# after writing the title to .git/PR_TITLE and the body to .git/PR_BODY
python3 - <<'PY'
import urllib.parse, pathlib
base, head, owner_repo = "<base>", "<head>", "<owner>/<repo>"
title = pathlib.Path(".git/PR_TITLE").read_text().strip()
body  = pathlib.Path(".git/PR_BODY").read_text()
q = urllib.parse.urlencode({"expand": "1", "title": title, "body": body}, quote_via=urllib.parse.quote)
url = f"https://github.com/{owner_repo}/compare/{base}...{head}?{q}"
print(f"len={len(url)}")
print(url)
PY
```

> **Length caveat (~8k chars).** Browsers and GitHub choke on URLs past roughly 8,000 characters. If the printed `len=` is near or over that, keep the *linked* body tight — a short summary plus "full description below" — and hand the full body to the user separately (see Step 5) to paste into the form. A long body is the only thing that blows the budget; the rest of the URL is tiny.

## Step 5 — Hand it over

- Write the final title and body to **`.git/PR_DRAFT`** (inside `.git/`, so it's never tracked), same as `/ddmal:commit` writes `.git/COMMIT_DRAFT`.
- In chat: print the **compare URL** as a clickable link, and print the **title + body** in a code block so the user can read (and, if the URL was trimmed for length, paste) it.
- Tell the user plainly: **click the link, review the pre-filled form on GitHub, and click _Create pull request_.** You have not created it.

## Operating notes

- **Read-only against GitHub.** The plugin's PAT is never used to write. The only mutation is the branch push in Step 2, with the user's own credentials and only after they confirm.
- **Don't guess owner/repo or base** — derive them from git; ask if git can't tell you.
- **Scope boundary.** PR *creation* and *new issues* both have pre-fill URLs, which is why this skill can exist. PR *inline review comments* do not — that's why `/ddmal:review-pr` stays chat-only.
