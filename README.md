# DDMAL devtools

Lab-internal developer tooling for [Claude Code](https://code.claude.com), distributed as a
plugin through a private marketplace hosted in this repo. Install once and it works in
**every** repo you open — no per-repo setup, and everyone pulls updates from one place.

The `ddmal` plugin ships four skills, all backed by the official GitHub MCP server:

| Skill | What it does |
| --- | --- |
| `/ddmal:review-pr` | Critical, human-assist PR review (a second pass on top of CodeRabbit/Copilot). |
| `/ddmal:handoff` | Write a session handoff to disk so a fresh session can resume cleanly. |
| `/ddmal:resume` | Pick up from the most recent handoff. |
| `/ddmal:commit` | Draft a Conventional Commits message (you commit and push). |

---

## One-time setup (per person)

### 1. Create a read-only GitHub token

Create a **fine-grained personal access token** with **Read** access to the DDMAL repos you
work with. Scopes: **Issues, Pull requests, Contents, Discussions, Metadata — all Read.**
(Read-only is deliberate: reviews are posted in chat, never written back to GitHub.)

### 2. Add the marketplace and install the plugin

```text
/plugin marketplace add DDMAL/devtools
/plugin install ddmal@devtools
```

When the plugin enables, Claude Code **prompts you for the token** and stores it in your OS
keychain (macOS) or `~/.claude/.credentials.json` (Windows/Linux) — never in a repo, never in
your shell profile.

### 3. Verify

Run `/mcp` — the `github` server should show **connected**. Then try a real review:

```text
/ddmal:review-pr DDMAL/CantusDB#2118
```

> **Private-repo notes.** `DDMAL/devtools` shorthand clones over SSH by default. If you use
> HTTPS + keychain and have no SSH key loaded, set `CLAUDE_CODE_PLUGIN_PREFER_HTTPS=1` in your
> environment. Background auto-update of a private marketplace can be flaky; set
> `CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE=1` so a failed refresh keeps your working
> copy, and refresh manually any time with `/plugin marketplace update`.
>
> **Version floor.** The token prompt (`userConfig`) needs Claude Code **≥ 2.1.207**. If
> `/mcp` shows the token unresolved on an older build, either update Claude Code or use the
> fallback below.
>
> **Fallback if the bundled server won't connect:** add the server yourself at user scope —
> `claude mcp add --transport http github https://api.githubcopilot.com/mcp/ --header "Authorization: Bearer <your-token>" --scope user`.

---

## Using the skills

```text
/ddmal:review-pr DDMAL/CantusDB#2118   # explicit owner/repo#number
/ddmal:review-pr 2118                   # infers owner/repo from the current git remote
/ddmal:handoff                          # write a handoff before you run low on context
/ddmal:resume                           # start a fresh session here to continue
/ddmal:commit                           # draft a commit message for your staged changes
```

### Per-repo review rubrics (how review-pr stays sharp across different stacks)

The plugin ships a **stack-agnostic review engine**. Project-specific knowledge lives in each
repo: `/ddmal:review-pr` looks for **`.claude/review-rubric.md`** in the repo being reviewed
and layers its checks on top of the generic pass. That keeps Django/migration checks on
CantusDB, ML/repro checks on the model repos, and data-quality checks on the datalake — each
owned by the people who work there, without bloating the shared plugin.

See [`examples/review-rubric.cantusdb.md`](examples/review-rubric.cantusdb.md) for the format.
A repo with no rubric still gets a solid generic review.

---

## Recommended: always-visible context & usage

`/context`, `/usage`, and `/stats` give on-demand numbers. For an **always-on** view there are
two levels, because context and usage come from different places:

- **Context % — zero setup:** install the *Claude Context Bar* extension (below). It reads
  Claude Code's own session files and shows a live context % in the status bar with no
  configuration. This is the "install once and always see it" option.
- **Context % + 5-hour + weekly usage:** the quota numbers are **not** exposed to VS Code
  extensions — they live only in the status-line payload and `/usage`. Seeing them always-on
  therefore requires a **status line**, which renders in a terminal:

1. Copy [`scripts/statusline.sh`](scripts/statusline.sh) to `~/.claude/statusline.sh` and
   `chmod +x` it.
2. Add to `~/.claude/settings.json`:

   ```json
   { "statusLine": { "type": "command", "command": "bash ~/.claude/statusline.sh" } }
   ```

3. **Run Claude Code in a terminal** (VS Code's integrated terminal is fine). The status line
   does **not** render in the VS Code side-panel extension yet, so panel users should rely on
   `/usage` on demand plus a context-indicator extension (below). For a zero-maintenance
   option with reset countdowns and colour, `npx ccusage statusline` works too.

## Recommended VS Code extensions

Opening this repo prompts VS Code to install these (see
[`.vscode/extensions.json`](.vscode/extensions.json)):

- **Claude Code** (`anthropic.claude-code`) — the extension itself.
- **GitLens** (`eamodio.gitlens`) — inline blame, history, and PR context.
- **Claude Context Bar** (`ezoosk.claude-context-bar`) — a live context-window % in the status
  bar, read from Claude Code's own session files (no hook or script to configure). Shows
  context only, not usage quotas. (~4.8k installs; note it is not open-source.)

Stack-specific extensions (Python, Django, notebooks, etc.) belong in each project's own
`.vscode/extensions.json`, not here.

---

## Updating

`version` is intentionally omitted from the plugin manifest, so **every push to this repo is a
new version** — members get the latest on their next `/plugin marketplace update` (or the
background refresh). No release step to remember while the tooling is actively evolving.

## Developing the plugin

Work on the plugin locally without publishing:

```text
claude --plugin-dir ./plugins/ddmal      # load the plugin from disk
# after edits to non-skill files (mcp, manifest):
/reload-plugins
# validate before pushing:
claude plugin validate .
```

Skills are portable engines (no project-specific knowledge); project-specific rules go in each
repo's `.claude/review-rubric.md`. Keep it that way.
