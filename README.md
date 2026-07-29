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

```bash
claude plugin marketplace add DDMAL/devtools
claude plugin install ddmal@devtools --config github_pat=<YOUR_TOKEN> --scope user
```

`--config` stores the token in your OS keychain (or `~/.claude/.credentials.json`) — never in a
repo or your shell history; use `--config github_pat="$VAR"` if it's in an env var. **Set it on the
_first_ install** — `install` ignores `--config` if the plugin already exists, so if the server
won't connect, run `claude plugin uninstall ddmal@devtools` and install again. (Prefer a prompt?
Run `/plugin install ddmal@devtools` inside a session.)

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

## Recommended: always-on context & usage

`/context`, `/usage`, and `/stats` give numbers on demand. For an always-on view:

- **Context % (zero setup):** install the **Claude Context Bar** extension (below) — a live context
  % in the status bar, no configuration.
- **Context % + 5-hour + weekly usage:** these quotas live only in the status-line payload, so an
  always-on view needs a **status line** (terminal only):
  1. Copy [`scripts/statusline.sh`](scripts/statusline.sh) to `~/.claude/statusline.sh` and
     `chmod +x` it.
  2. Add to `~/.claude/settings.json`:
     `{ "statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh" } }`
  3. Run Claude Code in a terminal (VS Code's integrated terminal is fine). `npx ccusage statusline`
     is a zero-maintenance alternative.

The status line doesn't render in the VS Code side panel yet, so panel users should rely on `/usage`
plus the context extension.

## Recommended VS Code extensions

Opening this repo prompts VS Code to install these (see
[`.vscode/extensions.json`](.vscode/extensions.json)):

- **Claude Code** (`anthropic.claude-code`) — the extension itself.
- **GitLens** (`eamodio.gitlens`) — inline blame, history, and PR context.
- **Claude Context Bar** (`ezoosk.claude-context-bar`) — live context % in the status bar (context
  only, not usage quotas; not open-source).

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
