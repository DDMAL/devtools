# Example: CantusDB review rubric

This is a **seed example** of a repo-local review rubric. `/ddmal:review-pr` looks for
`.claude/review-rubric.md` in the repo being reviewed and layers its checks on top of the
generic review. Drop a file like this into each repo that has recurring, project-specific
gotchas; the generic review already covers scope creep, tests, security, and "does it fix
the issue".

To use it in CantusDB: copy this to `CantusDB/.claude/review-rubric.md` and flesh out the
"Known traps" section with the specifics (see the note at the bottom).

---

## Django & ORM

- **Migrations** — reversible? Does `migrate <app> <prev>` actually work? For data
  migrations, will it finish in reasonable time on a prod-sized table? Any irreversibly
  destructive operation (column drop, data delete) without a backup plan is a blocker.
- **N+1 queries** — loops over querysets that touch related objects; missing
  `select_related` / `prefetch_related`.
- **Transactions** — multi-write paths need `transaction.atomic`.
- **Raw SQL** — no string interpolation of untrusted input.

## Permissions

- New views must carry the right `LoginRequiredMixin` / `PermissionRequiredMixin` /
  `UserPassesTestMixin` / decorator, plus object-level checks where relevant.
- Know the project's permission tiers; a change that widens access is a blocker until
  justified.

## Public URLs & templates

- Source / chant URL patterns are linked from outside the app — changing them needs a
  redirect, not a silent break.
- No `|safe` on user-controlled data; keep auto-escaping intact.
- No inline JS that interpolates user-controlled data unescaped.

## Ripple effects

- **Ansible** (`ansible.cantus-db`) — does this need an env var / settings / service-config
  change to deploy?
- **Wiki** (`CantusDB.wiki`) — does observable behaviour now contradict the docs? Grep the
  wiki for affected feature names.

## Known traps

- **Do not reintroduce the `visible` field** (removed deliberately).
- Migration reversion has bitten this project before — scrutinise any migration PR against
  those past failures.

> TODO: "Known traps" still needs the specifics held in Liam's local auto-memories
> (`project_image_link_retirement`, `project_reversion_for_mapping_commands`), which aren't in
> the source skill — only referenced by name. A Claude Code session rooted **in CantusDB** has
> those memories available and should inline them here (see the task brief that ships with this
> example). Inlining is what makes the knowledge portable to the rest of the lab.
