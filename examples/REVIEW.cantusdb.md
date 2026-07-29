# Example: CantusDB review rubric

This is a **seed example** of a repo-local review rubric. `/ddmal:review-pr` looks for
`REVIEW.md` at the root of the repo being reviewed and layers its checks on top of the
generic review. Drop a file like this into each repo that has recurring, project-specific
gotchas; the generic review already covers scope creep, tests, security, and "does it fix
the issue".

`REVIEW.md` is also the file Anthropic's managed Code Review service reads, so one rubric
serves both `/ddmal:review-pr` and the GitHub-side reviewer. Keep it to rules that change
review behaviour; general project context belongs in `CLAUDE.md`.

To use it in CantusDB: copy this to `CantusDB/REVIEW.md` and flesh out the "Known traps"
section with the specifics (see the note at the bottom).

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

> This file is a **trimmed seed** kept as a format reference. The fully-worked version — with the
> `image_link` retirement (#1839) and reversion-in-mapping-commands (#1659) traps inlined as
> concrete, checkable rules, plus the permission tiers and local verification commands — lives in
> `CantusDB/REVIEW.md`. A rubric's specifics should be inlined like that (not
> referenced by name) so the knowledge is portable to anyone reviewing the repo.
