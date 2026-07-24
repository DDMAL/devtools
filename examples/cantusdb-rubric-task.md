# Task brief: create CantusDB's review rubric

**Give this to a Claude Code session rooted in the CantusDB repo.** It has the local
auto-memories that hold the gotchas we need; this devtools session does not.

## Background

DDMAL now has a shared Claude Code plugin (`ddmal`, from the `DDMAL/devtools` marketplace).
Its `/ddmal:review-pr` skill does a rigorous but **stack-agnostic** review. Project-specific
knowledge is federated: the skill looks for **`.claude/review-rubric.md`** in the repo being
reviewed and layers those checks on top of its generic pass. Your job is to write that file
for CantusDB, so CantusDB reviews keep their Django/migration edge without that knowledge
living in the shared plugin.

## Goal

Create **`CantusDB/.claude/review-rubric.md`**, self-contained (no references to any
machine-local memory — inline the actual content).

## Steps

1. **Start from this rubric** (already extracted from the old `review-pr` skill):

   ```markdown
   # CantusDB review rubric

   Project-specific checks for /ddmal:review-pr, layered on top of the generic review.

   ## Django & ORM
   - Migrations: reversible? Does `migrate <app> <prev>` work? Data migrations must finish in
     reasonable time on a prod-sized table. Any irreversibly destructive op (column drop, data
     delete) without a backup plan is a blocker.
   - N+1 queries: loops over querysets touching related objects; missing select_related /
     prefetch_related.
   - Transactions: multi-write paths need transaction.atomic.
   - Raw SQL: no string interpolation of untrusted input.

   ## Permissions
   - New views need the right LoginRequiredMixin / PermissionRequiredMixin /
     UserPassesTestMixin / decorator, plus object-level checks. Know the permission tiers; a
     change that widens access is a blocker until justified.

   ## Public URLs & templates
   - Source / chant URL patterns are linked from outside the app — changing them needs a
     redirect. No |safe on user-controlled data; no inline JS interpolating user data unescaped.

   ## Ripple effects
   - Ansible (ansible.cantus-db): env var / settings / service-config changes needed to deploy?
   - Wiki (CantusDB.wiki): does behaviour now contradict the docs? Grep the wiki for the feature.

   ## Known traps
   - Do not reintroduce the `visible` field (removed deliberately).
   - <FILL FROM MEMORIES — see step 2>
   ```

2. **Inline the migration/reversion gotchas.** Read these local auto-memories and translate
   their content into concrete, checkable rules under "Known traps":
   - `project_image_link_retirement`
   - `project_reversion_for_mapping_commands`

   For each: what went wrong, and what a reviewer should now check on any migration/reversion
   PR so it doesn't recur. Write the *rule*, not "see the memory" — this file must stand alone
   for teammates who don't have your memories.

3. **Add any other durable CantusDB gotchas** you can corroborate from `CLAUDE.md`,
   `CLAUDE.local.md`, or recurring themes in recent migration/permissions PRs. Keep it to
   things that generalise across PRs — not one-off notes.

4. **Save** the result to `CantusDB/.claude/review-rubric.md` and confirm it contains no
   pointers to machine-local memory.

## While you're here (related, separate)

CantusDB's `CLAUDE.local.md` reportedly still instructs "read the mirror, never call
GitHub / always read `Issue-N.md` / `PR-N.md`." That directly conflicts with the new
MCP-based `/ddmal:review-pr` (which reads live GitHub data) and will confuse the skill.
Flag it to Liam, or rewrite it to: use the `github` MCP tools for issue/PR data; the mirror
is retired. (Don't do this silently if it's a big change — confirm with Liam first.)
