# DDMAL devtools

Lab-internal developer tooling for [Claude Code](https://code.claude.com), distributed as a plugin through a marketplace hosted in this repo.

There are eight skills in this plugin. `/ddmal:review-pr` needs the bundled GitHub MCP server.

| Skill | What it does |
| --- | --- |
| `/ddmal:review-pr` | Critical, human-assisted PR review. |
| `/ddmal:handoff` | Write a session handoff to disk so a fresh session can resume cleanly. |
| `/ddmal:resume` | Pick up from the most recent handoff. |
| `/ddmal:commit` | Draft a Conventional Commits message (you commit and push). |
| `/ddmal:draft-pr` | Draft a PR and emit a pre-filled GitHub compare link (you click _Create_). |
| `/ddmal:draft-issue` | Draft a bug/feature issue and emit a pre-filled new-issue link (you click _Submit_). |
| `/ddmal:daily-recap` | Summarize today's work as 3–4 one-line bullets to paste into Workday. |
| `/ddmal:weekly-recap` | Personal markdown notes on everything done since last Friday 9am. |

**Nothing here writes to GitHub.** The MCP server is pinned read-only, and the three drafting skills hand you a link or a command.

---

## Setup (once per person)

Install once from a terminal. Requires Claude Code ≥ 2.1.218
(`/ddmal:review-pr` runs in its own context and waits for the result, which needs that version;
on 2.1.207–2.1.217 everything else works and the review comes back in the background instead).

### 1. Create a read-only GitHub token

A **fine-grained PAT** at
[github.com/settings/personal-access-tokens/new](https://github.com/settings/personal-access-tokens/new):

- **Resource owner:** your own GitHub account
- **Repository access:** _Public repositories (read-only)_

<sub>Private repo instead? Set the resource owner to that org, select the repo, and grant
**Issues, Pull requests, Contents, Metadata → Read**.</sub>

### 2. Install

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

Reload Claude Code first (`Cmd+Shift+P` → **Developer: Reload Window**) — open sessions won't have the plugin. Then:

```bash
claude mcp list   # want: plugin:ddmal:github … ✔ Connected
```

Then, in Claude Code: `/ddmal:review-pr DDMAL/CantusDB#2123`.

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

Every skill also triggers from plain language — "what did I work on today", "review 2123" — so the slash form is just the explicit way to ask.

`/ddmal:draft-pr` needs your branch pushed first (GitHub computes the diff server-side); if not, it hands you the `git push` command instead of pushing.

### Where the recaps come from

Both recaps run [`worklog.sh`](plugins/ddmal/scripts/worklog.sh), which reads — never writes — every clone beside this repo: commits, uncommitted changes, `.handoffs/`, and Claude Code session history over a window.

- **`daily-recap`** runs 4am → 4am **local**, so past-midnight work lands on the right day.
- **`weekly-recap`** anchors to **Eastern** (`WORKLOG_TZ` to change) and saves to `~/worknotes/` (`$WORKNOTES_DIR`), outside every repo.
- Repos elsewhere? `WORKLOG_ROOTS` (colon-separated) or `--roots DIR`.

> **Heads up:** session history is read for _every_ project on your machine, not just these clones — that's what catches uncommitted work, but unrelated sessions can surface in a recap (and `weekly-recap` saves to a file). Narrow with `--roots` and skim before sharing.

### How review-pr adapts per repo

The engine is stack-agnostic; per-repo rules come from the repo being reviewed:

- **`CLAUDE.md`** — its "never / always / must" lines become review gates. Most repos already have one.
- **`REVIEW.md`** (optional) — extra review-time gates; see [`examples/REVIEW.cantusdb.md`](examples/REVIEW.cantusdb.md). Same file Anthropic's managed Code Review reads, so one rubric serves both.

Neither? You still get a solid generic review.

---

## VS Code extensions

Opening this repo prompts you to install the **Claude Code** extension (`anthropic.claude-code`); see [`.vscode/extensions.json`](.vscode/extensions.json). Stack-specific extensions belong in each project's own file, not here.

---

## Updating

No version in the manifest, so **every push is a new version**. No release step — just:

```bash
claude plugin update ddmal@devtools
```

One command does both halves: it re-fetches the marketplace from GitHub _and_ reinstalls the plugin, so there's no separate `claude plugin marketplace update` beforehand. Then **restart Claude Code** — open windows keep running the copy they started with. Your token isn't touched.

<sub>`claude plugin marketplace update devtools` is for a different job: refreshing the catalog so newly published plugins show up. It won't move a plugin you already have installed.</sub>

## Developing the plugin

Clone only to work _on_ the plugin — using it is handled by `marketplace add` above.

```text
claude --plugin-dir ./plugins/ddmal      # load from a local clone
/reload-plugins                          # after editing mcp/manifest (non-skill files)
claude plugin validate .                 # before pushing
```

Skills are portable engines; project rules come from the repo being reviewed. Keep it that way.
