---
name: privatium-app-meds
description: Context for extending the Prescription Tracker app (slug meds): its schema, routes and conventions. Load alongside privatium-tier1-lua when changing this app.
---

<!--
This file is part of Prescription Tracker
Copyright © 2026 Gabriel Mongefranco
Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## The `meds` app

Tier 1, Lua. A personal prescription tracker for families with chronic conditions. This
first version stores one household name and greets with it.

### Schema

`profile(id VARCHAR PK, display_name VARCHAR NOT NULL)`: at most one row, ever.
[The data model page](../../docs/data-model.md) is the reference for every table and
must change in the same commit as `schema.sql`.

### Routes

| Route | Handler |
|---|---|
| `GET /` | Greeting, or an invitation when no profile exists |
| `GET /edit` | The name form |
| `POST /name` | Trims, validates, appends |

### Conventions to preserve

- `pv.append('profile', me.id, ...)` reuses the existing id. That makes an edit an
  amendment rather than a second household. Do not mint a new ULID on save.
- Every link goes through `url()`, so the app works unchanged in solo mode.
- Templates use `<?= ?>` only. There is no `<?raw ?>` here and there should not be.
- `static/meds.css` uses the shell's color tokens. Inherit form controls and focus rings
  rather than duplicating the shell stylesheet.
- Every source file carries the project header from `AGENTS.md`, not Privatium's.
- Health information will live in this app. Keep real names, dates of birth and
  medication records out of `sample/seed.jsonl`, tests and documentation.

### Extending it

Adding a field means one column in `schema.sql`, one input in `views/edit.lsp`, and one
key in the `pv.append` call. The schema change rematerializes from the logs; existing
events lack the key and the column is NULL for them. Adding a table means a `CREATE
TABLE` with a grain comment, a section in the data model page, and synthetic rows in the
seed.

Run `privatium lint apps/meds` before finishing.
