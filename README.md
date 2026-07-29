# DDMAL devtools

Lab-internal developer tooling for [Claude Code](https://code.claude.com), distributed as a
plugin through a marketplace hosted in this repo. Install once and it works in **every** repo you
open — no per-repo setup, and everyone pulls updates from one place.

The `ddmal` plugin ships eight skills. `/ddmal:review-pr` needs the bundled GitHub MCP server;
the recaps use it when it's there and skip it when it isn't; the rest are pure local git.

| Skill | What it does |
| --- | --- |
| `/ddmal:review-pr` | Critical, human-assist PR review (a second pass on top of CodeRabbit/Copilot). |
| `/ddmal:handoff` | Write a session handoff to disk so a fresh session can resume cleanly. |
| `/ddmal:resume` | Pick up from the most recent handoff. |
| `/ddmal:commit` | Draft a Conventional Commits message (you commit and push). |
| `/ddmal:draft-pr` | Draft a PR and emit a pre-filled GitHub compare link (you click _Create_). |
| `/ddmal:draft-issue` | Draft a bug/feature issue and emit a pre-filled new-issue link (you click _Submit_). |
| `/ddmal:daily-recap` | Summarize today's work as 3–4 one-line bullets to paste into Workday. |
| `/ddmal:weekly-recap` | Personal markdown notes on everything done since last Friday 9am. |

**Nothing here writes to GitHub.** The MCP server is pinned read-only (see
[Why it can't write](#why-it-cant-write)), and the three drafting skills hand you a link or a
command instead of acting: you click _Create_, _Submit_, or run `git commit`/`git push`
yourself.

---

## Setup (once per person)

Install once from a terminal; the skills then work in every repo. Requires Claude Code ≥ 2.1.218
(`/ddmal:review-pr` runs in its own context and waits for the result, which needs that version;
on 2.1.207–2.1.217 everything else works and the review comes back in the background instead).

> Use the terminal, **not** the `/plugin` panel — the panel can't collect your token, and you get
> skills that load fine but fail on every review.

### 1. Create a read-only GitHub token

A **fine-grained PAT** at
[github.com/settings/personal-access-tokens/new](https://github.com/settings/personal-access-tokens/new):

- **Resource owner:** your own GitHub account
- **Repository access:** _Public repositories (read-only)_

<sub>Private repo instead? Set the resource owner to that org, select the repo, and grant
**Issues, Pull requests, Contents, Metadata → Read**.</sub>

#### Why it can't write

Two independent limits, so neither one alone has to hold:

1. **The token** is read-scoped, per the settings above.
2. **The server** is pinned read-only in
   [`.mcp.json`](plugins/ddmal/.mcp.json) with `X-MCP-Readonly: true`, so GitHub's MCP server
   never even offers a write tool — no `create_pull_request`, no `merge_pull_request`, no
   `issue_write`. `X-MCP-Toolsets` trims it further to the four toolsets the skills use.

So a broader token pasted by mistake still can't push, merge, or file anything. The only write
paths in the whole plugin are your own `git push` and your own click on GitHub's forms.

### 2. Install

Run this line **by itself**. It prints `Paste token:` and waits — your typing stays hidden:

```bash
printf 'Paste token: '; read -rs GITHUB_PAT; echo
```

Then paste the rest:

```bash
claude plugin marketplace add DDMAL/devtools
claude plugin install ddmal@devtools --config github_pat="$GITHUB_PAT" --scope user
unset GITHUB_PAT
```

`--scope user` is what makes it work everywhere. The token goes to your OS keychain.

### 3. Verify

Reload Claude Code first — in VS Code, `Cmd+Shift+P` → **Developer: Reload Window**. Sessions that
were already open won't have the plugin.

In a terminal, check the server is authenticated:

```bash
claude mcp list
```

You want `plugin:ddmal:github … ✔ Connected`. Then, **in Claude Code** (not your shell):

```text
/ddmal:review-pr DDMAL/CantusDB#2123
```

### If something goes wrong

| Symptom | Fix |
| --- | --- |
| `claude: command not found` | The VS Code extension doesn't add `claude` to your `PATH`. Install the CLI with `curl -fsSL https://claude.ai/install.sh \| bash`, then open a new terminal. |
| Skills load but every review fails | Installed from the `/plugin` panel, so there's no token. `claude plugin uninstall ddmal@devtools`, then redo step 2. |
| Skills don't appear at all | Relaunch Claude Code — open windows don't load a new plugin. |
| Connected, but repos 404 | Token resource owner must be **your own account**, not the DDMAL org. |
| `/plugin isn't available in this environment` | You don't need it. Step 2 is the terminal. |

---

## Using the skills

```text
/ddmal:review-pr DDMAL/CantusDB#2123   # explicit owner/repo#number
/ddmal:review-pr 2123                   # infers owner/repo from the current git remote
/ddmal:handoff                          # write a handoff before you run low on context
/ddmal:resume                           # start a fresh session here to continue
/ddmal:commit                           # draft a commit message for your staged changes
/ddmal:draft-pr                         # draft a PR + get a pre-filled compare link to click
/ddmal:draft-issue                      # draft a bug/feature + get a pre-filled new-issue link
/ddmal:daily-recap                      # 3–4 lines for Workday, covering today
/ddmal:daily-recap since 9am            # …or from a time or day you name
/ddmal:weekly-recap                     # personal notes since last Friday 9am ET
/ddmal:weekly-recap 2026-07-20          # …or since a date you name
```

You don't have to type the command. Every skill also triggers from plain language — "what did
I work on today", "hand this off and note what's left", "review 2123" — so the slash form is
just the explicit way to ask.

`/ddmal:draft-pr` needs your branch already on the remote, because GitHub computes the compare
diff server-side. If it isn't, the skill stops and hands you the `git push -u origin <branch>`
command rather than pushing for you.

### Where the work summaries come from

`/ddmal:daily-recap` and `/ddmal:weekly-recap` both run
[`plugins/ddmal/scripts/worklog.sh`](plugins/ddmal/scripts/worklog.sh), which scans **every
clone in the folder holding this repo** — your commits, files you changed but haven't
committed, `.handoffs/` notes, and your Claude Code session history — over a time window. It
reads only; it prints a plain-text record and the skill does the interpreting.

- **`/ddmal:daily-recap` runs 4am → 4am in your computer's timezone**, so a session that goes
  past midnight still lands on the day you were working. Name a start yourself to override it.
- `/ddmal:weekly-recap` anchors to **Eastern** instead, so a week means the same span for
  everyone. Set `WORKLOG_TZ` to change that.
- Repos somewhere else? Set `WORKLOG_ROOTS` (colon-separated) or pass `--roots DIR`.
- `/ddmal:weekly-recap` writes to `~/worknotes/` (override with `$WORKNOTES_DIR`) — outside
  every repo, since the notes are personal and span all of them.

> **What it reads.** Commits and dirty files come only from the clones above, but **Claude Code
> session history is read for every project on your machine** — that's what catches work which
> never reached a commit. Unrelated or personal sessions can therefore surface in a recap, and
> `/ddmal:weekly-recap` saves its output to a file. Narrow the scan with `WORKLOG_ROOTS` or
> `--roots DIR` if that matters to you, and skim the file before sharing it.

### How review-pr adapts per repo

The review engine is stack-agnostic; it picks up each repo's own gotchas from the repo being
reviewed, in two places:

- **`CLAUDE.md`** (repo root) — the primary source. `/ddmal:review-pr` treats its
  "never / always / must / don't" statements as review gates. Most repos already have one, so
  there's usually nothing to set up.
- **`REVIEW.md`** (repo root, optional) — a short list of extra review-time gates. See
  [`examples/REVIEW.cantusdb.md`](examples/REVIEW.cantusdb.md) for the shape. This is the same
  filename Anthropic's managed Code Review reads, so one rubric serves both reviewers.

A repo with neither still gets a solid generic review.

---

## Recommended VS Code extensions

Opening this repo prompts VS Code to install these (see
[`.vscode/extensions.json`](.vscode/extensions.json)):

- **Claude Code** (`anthropic.claude-code`) — the extension itself.

Stack-specific extensions belong in each project's own `.vscode/extensions.json`, not here.

---

## Updating

`version` is intentionally omitted from the manifest, so **every push to this repo is a new
version** — members get the latest on their next `/plugin marketplace update` (or the background
refresh). No release step to remember.

## Developing the plugin

You only need to clone to work _on_ the plugin — using it is handled by `marketplace add` above.

```text
claude --plugin-dir ./plugins/ddmal      # load the plugin from a local clone
/reload-plugins                          # after editing non-skill files (mcp, manifest)
claude plugin validate .                 # before pushing
```

Skills are portable engines; project-specific rules come from the repo being reviewed — its
`CLAUDE.md` first, plus an optional `REVIEW.md`. Keep it that way.
