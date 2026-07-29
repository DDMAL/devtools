# DDMAL devtools

Lab-internal developer tooling for [Claude Code](https://code.claude.com), distributed as a
plugin through a marketplace hosted in this repo. Install once and it works in **every** repo you
open — no per-repo setup, and everyone pulls updates from one place.

The `ddmal` plugin ships six skills, all backed by the official GitHub MCP server:

| Skill | What it does |
| --- | --- |
| `/ddmal:review-pr` | Critical, human-assist PR review (a second pass on top of CodeRabbit/Copilot). |
| `/ddmal:handoff` | Write a session handoff to disk so a fresh session can resume cleanly. |
| `/ddmal:resume` | Pick up from the most recent handoff. |
| `/ddmal:commit` | Draft a Conventional Commits message (you commit and push). |
| `/ddmal:draft-pr` | Draft a PR and emit a pre-filled GitHub compare link (you click _Create_). |
| `/ddmal:draft-issue` | Draft a bug/feature issue and emit a pre-filled new-issue link (you click _Submit_). |

---

## Setup (once per person)

You don't need to clone this repo — `marketplace add` below fetches it for you. **Requires Claude
Code ≥ 2.1.207** (check with `claude --version`; update if older).

### 1. Create a read-only GitHub token

The skills read PRs, issues, and code through the GitHub MCP server, which needs a token. Create a
**fine-grained personal access token** at
**[github.com/settings/personal-access-tokens/new](https://github.com/settings/personal-access-tokens/new)**
with **Read-only** access:

- **Resource owner:** DDMAL — an org owner may need to approve the token before it works.
- **Repository access:** the repos you review (or all DDMAL repos).
- **Permissions (all Read):** Issues, Pull requests, Contents, Discussions, Metadata.

Read-only is deliberate — reviews are posted in chat, never written back to GitHub.

### 2. Install

Add the marketplace, then install the plugin. Claude Code stores your token in your OS keychain
(or `~/.claude/.credentials.json`), never in the repo — but **avoid typing the raw token as a
command-line argument**, since that lands in your shell history. Two clean ways to hand it over:

**Recommended — let it prompt you.** In a Claude Code session (VS Code chat panel or an interactive
`claude`), run:

```text
/plugin marketplace add DDMAL/devtools
/plugin install ddmal@devtools
```

`/plugin install` prompts you to paste the token, so it never touches your shell history.

**Or from the terminal,** passing the token via an **env var** (not the literal token) so history
only records the variable name:

```bash
export GITHUB_PAT=github_pat_xxx        # or keep it in ~/.bash_profile / ~/.zshrc
claude plugin marketplace add DDMAL/devtools
claude plugin install ddmal@devtools --config github_pat="$GITHUB_PAT" --scope user
```

**Set the token on the _first_ install** — `install` silently ignores `--config` if the plugin is
already present, so if the server won't connect later, run `claude plugin uninstall ddmal@devtools`
and install again.

### 3. Verify

```bash
claude mcp list      # plugin:ddmal:github → ✔ Connected
```

Then try a real review in any session (the VS Code extension is fine):

```text
/ddmal:review-pr DDMAL/CantusDB#2118
```

> **If the bundled server won't connect,** add it yourself at user scope:
> `claude mcp add --transport http github https://api.githubcopilot.com/mcp/ --header "Authorization: Bearer <your-token>" --scope user`

---

## Using the skills

```text
/ddmal:review-pr DDMAL/CantusDB#2118   # explicit owner/repo#number
/ddmal:review-pr 2118                   # infers owner/repo from the current git remote
/ddmal:handoff                          # write a handoff before you run low on context
/ddmal:resume                           # start a fresh session here to continue
/ddmal:commit                           # draft a commit message for your staged changes
/ddmal:draft-pr                         # draft a PR + get a pre-filled compare link to click
/ddmal:draft-issue                      # draft a bug/feature + get a pre-filled new-issue link
```

### How review-pr adapts per repo

The review engine is stack-agnostic; it picks up each repo's own gotchas from the repo being
reviewed, in two places:

- **`CLAUDE.md`** (repo root) — the primary source. `/ddmal:review-pr` treats its
  "never / always / must / don't" statements as review gates. Most repos already have one, so
  there's usually nothing to set up.
- **`.claude/review-rubric.md`** (optional) — a short list of extra review-time gates. See
  [`examples/review-rubric.cantusdb.md`](examples/review-rubric.cantusdb.md) for the shape.

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
`CLAUDE.md` first, plus an optional `.claude/review-rubric.md`. Keep it that way.
