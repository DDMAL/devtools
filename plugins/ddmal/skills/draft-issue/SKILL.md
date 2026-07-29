---
name: draft-issue
description: Draft a GitHub issue and emit a ready-to-click, pre-filled new-issue URL. Use when the user wants to file a bug or feature request (e.g. "draft an issue", "file a bug", "open an issue", "/ddmal:draft-issue"). Turns the user's description into a clear title and body and hands over a link that lands on GitHub's New-issue form with everything filled in — it does NOT create the issue; the human clicks *Submit*.
allowed-tools: Bash(git remote:*) Bash(git rev-parse:*) Bash(ls:*) Bash(${CLAUDE_PLUGIN_ROOT}/scripts/prefill-url.sh *)
---

# Draft a GitHub issue

Turn a rough bug report or feature request into an issue the user can file with one click. You write the title and body from the user's description (and any code they point you at), then hand over a **pre-filled GitHub new-issue URL** — the link opens GitHub's New-issue form with the title and body already populated, and the human reviews and clicks **Submit new issue**.

**You mutate nothing.** No issue is created, nothing is pushed, and the GitHub MCP server is pinned read-only. The only file written is a scratch draft inside the git dir. It mirrors `/ddmal:commit` and `/ddmal:draft-pr`: it drafts and hands over, the human executes.

## Repo state

- Git dir: !`git rev-parse --path-format=absolute --git-dir`
- Origin: !`git remote get-url origin 2>/dev/null || echo "(no origin remote)"`
- Issue templates on disk: !`ls -1 .github/ISSUE_TEMPLATE/ .github/ISSUE_TEMPLATE.md .github/issue_template.md 2>/dev/null || echo "(none)"`

## Step 1 — Work out the target repo

An issue can target the repo you're in, or a different one the user names.

- **Explicit** — if the user gave an `owner/repo` (e.g. "file it on DDMAL/CantusDB"), use that.
- **Otherwise** parse `owner/repo` from the origin URL above. Both forms appear: `git@github.com:DDMAL/CantusDB.git` (SSH) and `https://github.com/DDMAL/CantusDB.git` (HTTPS). Strip the host prefix and the trailing `.git` → `DDMAL/CantusDB`. If origin isn't a GitHub remote (or there's no remote), ask the user for `owner/repo`.

## Step 2 — Gather the issue

Unlike `/ddmal:draft-pr`, there's **no diff to summarize** — the raw material is what the user tells you.

- **Draft from the user's description** of the bug or feature. If they point at code, files, or an error, **read those** — concrete file paths, function names, and error text make the issue actionable. Ground the issue in what's real; **don't invent** repro steps, versions, or behaviour. If something essential is missing (repro steps for a bug, the motivation for a feature), **ask** rather than fabricating.
- **Honour the repo's issue template** if one is listed above. `.github/ISSUE_TEMPLATE/config.yml` is config, not a template — skip it.
  - **Markdown templates** (`*.md`) — read the one that fits (bug vs. feature) and structure your body to match its sections.
  - **Issue *forms* (`*.yml`)** behave differently: GitHub renders fields, and query params pre-fill by **field `id`**, not by a single `body`. A raw `body=` will **not** populate a form. If the fitting template is a form, hand over the plain link and **tell the user they'll fill the form fields themselves** — don't hand over a link that silently won't pre-fill.
- **Drafting for a different repo than the one you're in?** The templates listed above belong to the *current* repo and are irrelevant. Either skip templating or fetch the target's template read-only with the GitHub MCP `get_file_contents`.

## Step 3 — Draft the title and body

- **Title** — one line, specific and searchable. For a bug, name the symptom ("Volpiano input crashes the chant editor on empty neume"); for a feature, the capability wanted. Avoid vague titles ("bug in the app").
- **Body — short by default.** Most issues need a sentence or two. For a **bug**: what happened vs. what you expected, plus the minimal steps to reproduce; add version/environment only when it's relevant. For a **feature**: the problem or motivation, then the proposed change. Reach for headings only when the issue is genuinely large or involved. Keep it plain, readable prose either way — never sacrifice clarity for brevity, and never drop into a cramped, keyword-only style.
- **Don't hard-wrap the body.** It's GitHub-rendered markdown, and GitHub turns a single newline inside a paragraph into a hard line break — so wrapping at ~72 chars produces ugly mid-sentence breaks. Write each paragraph or bullet as **one line** and separate blocks with a blank line; let the editor soft-wrap.
- **Do NOT add a `Co-Authored-By` trailer.**

## Step 4 — Build the pre-filled new-issue URL

Write the title and body to files inside the git dir, then let the bundled script do the URL encoding and the length check:

```bash
"${CLAUDE_PLUGIN_ROOT}/scripts/prefill-url.sh" issue \
  --repo <owner>/<repo> \
  --title-file "<git-dir>/ISSUE_TITLE" --body-file "<git-dir>/ISSUE_BODY"
```

Use the **Git dir** path resolved at the top — not a literal `.git/`, which is a *file* rather than a directory in a worktree or submodule. The script prints the URL on stdout and `ok: <n> chars` on stderr.

To load a specific markdown template file, add `--template <file.md>`. (`…/issues/new/choose` opens the template picker rather than a blank issue.)

**If the script reports `OVER LIMIT`** (past ~8,000 characters, where browsers and GitHub start returning 414), keep the *linked* body tight and give the full body to the user separately in Step 5 to paste in.

**Don't pre-set labels, assignees, milestones, or projects.** Every such value has to already exist and the clicker needs permission, or GitHub serves a 404 page instead of the form — and there's no reliable way to list a repo's real labels from here, so any value would be a guess. The user adds these in the form in two clicks, which is faster than getting it wrong. (Issue type and in-project fields like Status and Priority have no URL parameter at all.)

## Step 5 — Hand it over

- Write the final title and body to **`<git-dir>/ISSUE_DRAFT`**, same as `/ddmal:commit` writes `COMMIT_DRAFT`.
- In chat: print the **new-issue URL** as a clickable link, and print the **title + body** in a code block so the user can read (and, if the URL was trimmed for length, paste) it.
- Tell the user plainly: **click the link, review the pre-filled form on GitHub, add any labels you want, and click _Submit new issue_.** You have not created it.

## Operating notes

- **Zero mutations.** The human is the only one who creates the issue.
- **Don't guess owner/repo** — take it from the user or derive it from git; ask if neither is available.
- **Don't invent issue content** — draft only from what the user tells you and the code they point at; ask when key details are missing.
- **Scope boundary.** New issues and PR *creation* both have pre-fill URLs, which is why this skill and `/ddmal:draft-pr` can exist. PR *inline review comments* do not — that's why `/ddmal:review-pr` stays chat-only.
