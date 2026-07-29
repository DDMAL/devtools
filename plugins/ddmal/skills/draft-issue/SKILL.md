---
name: draft-issue
description: Draft a GitHub issue and emit a ready-to-click, pre-filled new-issue URL. Use when the user wants to file a bug or feature request (e.g. "draft an issue", "file a bug", "open an issue", "/ddmal:draft-issue"). Turns the user's description into a clear title and body and hands over a link that lands on GitHub's New-issue form with everything filled in — it does NOT create the issue; the human clicks *Submit*.
---

# Draft a GitHub issue

Turn a rough bug report or feature request into an issue the user can file with one click. You write the title and body from the user's description (and any code they point you at), then hand over a **pre-filled GitHub new-issue URL** — the link opens GitHub's New-issue form with the title and body already populated, and the human reviews and clicks **Submit new issue**.

**You do not create the issue.** This skill is fully read-only against GitHub — it never uses the plugin's GitHub PAT to write, and unlike `/ddmal:draft-pr` it makes **no mutation at all** (no branch push — an issue isn't tied to a branch). It mirrors `/ddmal:commit` and `/ddmal:draft-pr`: it drafts and hands over, the human executes.

## Step 1 — Work out the target repo

An issue can target the repo you're in, or a different one the user names.

- **Explicit** — if the user gave an `owner/repo` (e.g. "file it on DDMAL/CantusDB"), use that.
- **Otherwise infer from git:**

  ```
  git remote get-url origin
  ```

  Parse `owner/repo` from the URL. Both forms appear: `git@github.com:DDMAL/CantusDB.git` (SSH) and `https://github.com/DDMAL/CantusDB.git` (HTTPS). Strip the host prefix and the trailing `.git` → `DDMAL/CantusDB`. If origin isn't a GitHub remote (or there's no remote), ask the user for `owner/repo`.

## Step 2 — Gather the issue, and check for a template

Unlike `/ddmal:draft-pr`, there's **no diff to summarize** — the raw material is what the user tells you.

- **Draft from the user's description** of the bug or feature. If they point at code, files, or an error, **read those** — concrete file paths, function names, and error text make the issue actionable. Ground the issue in what's real; **don't invent** repro steps, versions, or behaviour. If something essential is missing (repro steps for a bug, the motivation for a feature), **ask** rather than fabricating.
- **Check for the repo's issue template(s)** so you can honour them. When drafting for the current repo, look on disk:

  ```
  ls .github/ISSUE_TEMPLATE/ .github/ISSUE_TEMPLATE.md .github/issue_template.md 2>/dev/null
  ```

  (`.github/ISSUE_TEMPLATE/config.yml` is config, not a template — skip it.) If you're drafting for a **different** repo than the one you're in, you can't read its templates from disk; either skip templating or fetch the file read-only via the GitHub MCP `get_file_contents`.
- **Markdown templates** (`.github/ISSUE_TEMPLATE/*.md`, `.github/ISSUE_TEMPLATE.md`) — read the one that fits (bug vs. feature) and structure your body to match its sections in Step 3.
- **Issue *forms* (YAML, `.github/ISSUE_TEMPLATE/*.yml`)** behave differently: GitHub renders fields, and query params pre-fill by **field `id`**, not by a single `body`. A raw `body=` will **not** populate a form. If the fitting template is a form, either read its `id:` keys and pre-fill those fields in Step 4, or produce the plain link and **tell the user they'll fill the form fields themselves** — don't hand over a link that silently won't pre-fill.

## Step 3 — Draft the title and body

- **Title** — one line, specific and searchable. For a bug, name the symptom ("Volpiano input crashes the chant editor on empty neume"); for a feature, the capability wanted. Avoid vague titles ("bug in the app").
- **Body — short by default.** Most issues need a sentence or two. For a **bug**: what happened vs. what you expected, plus the minimal steps to reproduce; add version/environment only when it's relevant. For a **feature**: the problem or motivation, then the proposed change. Reach for headings only when the issue is genuinely large or involved. Keep it plain, readable prose either way — never sacrifice clarity for brevity, and never drop into a cramped, keyword-only style.
- **Don't hard-wrap the body.** It's GitHub-rendered markdown, and GitHub turns a single newline inside a paragraph into a hard line break — so wrapping at ~72 chars produces ugly mid-sentence breaks. Write each paragraph or bullet as **one line** and separate blocks with a blank line; let the editor soft-wrap.
- **Repo template** — if Step 2 found a markdown template that fits, **structure the body to match its sections** (the pre-fill overrides GitHub's auto-loaded template, so honour it yourself).
- **Do NOT add a `Co-Authored-By` trailer.**

## Step 4 — Add metadata (labels, assignees, milestone, project), validated

The URL can also pre-set repository metadata — but **every value must already exist and the person clicking must have permission**, or GitHub returns a **404 page instead of the form** (an over-long URL → **414**). Never add these blind: check them read-only against the repo first — the plugin's GitHub MCP is read-only and made for exactly this.

- **Labels** — the one worth adding automatically. Read the repo's real labels (`list_issue_fields`, `get_label`), pick the ones that fit the issue you drafted, include the matches, and tell the user which you added. Param: `labels=bug,ui` (comma-separated, existing labels only).
- **Assignees** — `assignees=user1,user2`; only people with repo access. Add when the user names them or asks to self-assign.
- **Milestone** — `milestone=<number>` (the milestone's number, not its title).
- **Project** — `projects=<owner>/<number>` (e.g. `DDMAL/5`) drops the issue onto that Project board. Add only when the user names a project; the MCP can't always read Project boards to validate, so double-check the number — a wrong reference 404s the whole link.

**Issue type and in-project fields (Status, Priority, board tags) have no URL parameter** — leave them out; the user sets those in GitHub afterward if they want them.

## Step 5 — Build the pre-filled new-issue URL

The target form is GitHub's new-issue view with query params:

```
https://github.com/<owner>/<repo>/issues/new?title=<url-encoded-title>&body=<url-encoded-body>
```

To load a specific markdown template file, add `&template=<file.md>`; `…/issues/new/choose` opens the template picker rather than a blank issue.

**Title and body must be URL-encoded.** Don't hand-encode; write the two fields to files and let a tool do it. A reliable recipe (works on macOS):

```
# after writing the title to .git/ISSUE_TITLE and the body to .git/ISSUE_BODY
python3 - <<'PY'
import urllib.parse, pathlib
owner_repo = "<owner>/<repo>"
title = pathlib.Path(".git/ISSUE_TITLE").read_text().strip()
body  = pathlib.Path(".git/ISSUE_BODY").read_text()
params = {"title": title, "body": body}
# add only the metadata you validated in Step 4, e.g.:
# params["labels"] = "bug,ui"
# params["assignees"] = "octocat"
# params["milestone"] = "3"
# params["projects"] = "DDMAL/5"
q = urllib.parse.urlencode(params, quote_via=urllib.parse.quote)
url = f"https://github.com/{owner_repo}/issues/new?{q}"
print(f"len={len(url)}")
print(url)
PY
```

> **Length caveat (~8k chars).** Browsers and GitHub choke on URLs past roughly 8,000 characters. If the printed `len=` is near or over that, keep the *linked* body tight and hand the full body to the user separately (see Step 5) to paste into the form. A long body is the only thing that blows the budget; the rest of the URL is tiny.

## Step 6 — Hand it over

- Write the final title and body to **`.git/ISSUE_DRAFT`** (inside `.git/`, so it's never tracked), same as `/ddmal:commit` writes `.git/COMMIT_DRAFT`.
- In chat: print the **new-issue URL** as a clickable link, and print the **title + body** in a code block so the user can read (and, if the URL was trimmed for length, paste) it.
- Tell the user plainly: **click the link, review the pre-filled form on GitHub, and click _Submit new issue_.** You have not created it.

## Operating notes

- **Fully read-only against GitHub.** The plugin's PAT is never used to write, and this skill mutates nothing locally either — it only writes the `.git/ISSUE_DRAFT` scratch file. The human is the only one who creates the issue.
- **Don't guess owner/repo** — take it from the user or derive it from git; ask if neither is available.
- **Don't invent issue content** — draft only from what the user tells you and the code they point at; ask when key details are missing.
- **Validate metadata before adding it** — a non-existent or no-permission label / assignee / milestone / project makes GitHub 404 the *whole* link, so read the repo's real values first and never pass a guessed one.
- **Scope boundary.** New issues and PR *creation* both have pre-fill URLs, which is why this skill and `/ddmal:draft-pr` can exist. PR *inline review comments* do not — that's why `/ddmal:review-pr` stays chat-only.
