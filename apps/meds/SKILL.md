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
version has screens for the household name, the people, the contacts, the medication
catalog and the reminder settings. The tables and views for what people take, fills and
prior authorizations exist. Their screens are planned in
[the app design](../../docs/design/README.md), which also gives the build order.

### Schema

| Table | Grain |
|---|---|
| `profile` | One row per node, at most one row ever. Holds the household name and the five reminder day counts. |
| `person` | One row per household member |
| `medication` | One row per product in the catalog |
| `medication_alias` | One row per medication per other name |
| `pharmacy` | One row per pharmacy |
| `prescriber` | One row per prescriber |
| `person_medication` | One row per person per medication they take or took |
| `fill` | One row per fill |
| `prior_authorization` | One row per approval window for one person and one medication |

The views start with `v_`. `v_active_medication` is the readable one: every medication
in use with its refill status, next fill date and recommended next fill date.
[The data model page](../../docs/data-model.md) is the reference for every table and
view, and must change in the same commit as `schema.sql`.

### Layout

| Path | Holds |
|---|---|
| `app.lua` | The entry point. It loads the route modules, in the order paths are tried. |
| `lib/routes/` | One module for each part of the app. Loading a module registers its routes. |
| `lib/text.lua`, `validate.lua`, `choices.lua`, `medication_name.lua`, `page.lua`, `clock.lua` | Pure Lua with no framework calls, so plain Lua 5.4 can test them |
| `lib/store.lua` | The one place that writes and removes records |
| `views/` | One template for each page. A name that starts with `_` is a partial. |

### Routes

| Route | Module | Handler |
|---|---|---|
| `GET /` | `home` | Greeting by the local hour, or an invitation when no profile exists |
| `GET /edit`, `POST /name` | `home` | The household name |
| `GET /setup` | `home` | Links to the parts of Setup |
| `GET`, `POST /setup/reminders` | `home` | The five day counts |
| `GET /setup/people` | `people` | The list |
| `GET`, `POST /setup/people/new`, `/:id/edit`, `/:id/remove` | `people` | Add, change, remove |
| `GET /contacts` | `contacts` | Pharmacies and prescribers |
| `GET`, `POST /contacts/pharmacies/new`, `/:id/edit`, `/:id/remove` | `contacts` | Add, change, remove |
| `GET`, `POST /contacts/prescribers/new`, `/:id/edit`, `/:id/remove` | `contacts` | Add, change, remove |
| `GET /setup/catalog` | `catalog` | The catalog, narrowed by `?q=` |
| `GET /setup/catalog/:id` | `catalog` | One medication with its other names |
| `GET`, `POST /setup/catalog/new`, `/:id/edit`, `/:id/remove` | `catalog` | Add, change, remove |

### Conventions to preserve

- `pv.append('profile', me.id, ...)` reuses the existing id. That makes an edit an
  amendment rather than a second household. Do not mint a new ULID on save.
- An amendment replaces the whole row. Read the row, change what the form changed, and
  append every column. A column left out of the append is cleared.
- Privatium does not apply a column `DEFAULT` on write. Supply every required value in
  Lua.
- The two refill dates follow the rules in the data model page. Explain any change to
  those rules to the owner before coding it.
- A medication's short name is `Brand (Generic) strength` unless the owner typed another.
  A second spelling of a product is a `medication_alias` row, never a second medication.
- A view that must run in any SQLite tool leaves out the `DECIMAL` columns.
- Every link goes through `url()`, so the app works unchanged in solo mode.
- SQL is a literal with bound parameters. The linter refuses SQL built by joining
  strings, so each table has its own statements.
- A form check lives in `lib/validate.lua` and returns a value, or nil and a sentence
  for the person. A form that is refused comes back with what was typed.
- A page address carries record ids and notice codes only. `lib/page.lua` turns a known
  code into a sentence and ignores any other.
- A record that other records point to is not removed. The removal page says what uses
  it.
- Every time and date on a screen is local. Read them from `lib/clock.lua`, and use
  `date('now', 'localtime')` in SQL.
- A diagnostic message holds no field value. `page.masked` strips quoted values.
- Templates use `<?= ?>` only. There is no `<?raw ?>` here and there should not be.
- `static/meds.css` uses the shell's color tokens. Inherit form controls and focus rings
  rather than duplicating the shell stylesheet.
- Every source file carries the project header from `AGENTS.md`, not Privatium's.
- Health information will live in this app. Keep real names, dates of birth and
  medication records out of `sample/seed.jsonl`, tests and documentation.
- `sample/seed.jsonl` holds the household name and the starter catalog only. It never
  holds a person or a record about one, so an owner can load it into a real household.

### Extending it

Adding a field means one column in `schema.sql`, one input in the form, and one key in
every `pv.append` call that writes the table. The schema change rematerializes from the
logs; existing events lack the key and the column is NULL for them. Adding a table means
a `CREATE TABLE` with a grain comment and a section in the data model page.

Run the three checks in [the test how-to](../../docs/how-to/run-the-tests.md) before
finishing: `privatium lint apps/meds`, `lua5.4 tests/lua/run.lua` and `tests/smoke.sh`.
A new check in `lib/validate.lua` gets unit tests, and a new screen gets smoke tests,
with at least one request that must be refused.
