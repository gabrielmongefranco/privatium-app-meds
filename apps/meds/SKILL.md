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

Tier 1, Lua. A personal prescription tracker for families with chronic conditions.
[The architecture page](../../docs/architecture.md) describes how its parts fit together.

### Schema

| Table | Grain |
|---|---|
| `profile` | One row per node, at most one row ever. Holds reminder counts and early refill defaults. No row means every default. |
| `plan` | One row per payer, with optional percent and frame overrides |
| `person` | One row per household member |
| `medication` | One row per product in the catalog |
| `medication_alias` | One row per medication per other name |
| `pharmacy` | One row per pharmacy |
| `prescriber` | One row per prescriber |
| `person_medication` | One row per medication a person tracks, under the name the person prefers |
| `person_medication_product` | One row per tracked medication per catalog product; at least one each |
| `fill` | One row per fill of one tracked medication, with the product dispensed when known |
| `prior_authorization` | One row per approval window for one tracked medication |

The views start with `v_`. `v_active_medication` is the readable one: every tracked
medication in use with its refill status, refill eligibility, physical supply exhaustion,
payer and early allowance. `v_tracked_product` lists the products of each tracked
medication, and `v_entry_mark` their specialty and controlled marks as 1 or 0.
[The data model page](../../docs/data-model.md) is the reference for every table and
view, and must change in the same commit as `schema.sql`.

### Layout

| Path | Holds |
|---|---|
| `app.lua` | The entry point. It loads the route modules, in the order paths are tried. |
| `lib/routes/` | One module for each part of the app. Loading a module registers its routes. |
| `lib/text.lua`, `validate.lua`, `choices.lua`, `medication_name.lua`, `page.lua`, `clock.lua`, `form_icon.lua` | Pure Lua with no framework calls, so plain Lua 5.4 can test them |
| `lib/match.lua` | Pure Lua: how well a typed name matches a name of a medication |
| `lib/medication_search.lua` | The search that every screen uses to find a medication |
| `lib/written_name.lua` | Pure Lua: takes apart a name as a portal wrote it, and compares it with a name and a strength |
| `lib/medication_pick.lua` | Reads the medication box of a form: a typed name, a choice, a carried id, a checked result, or a new medication |
| `lib/product_pick.lua` | The products of a tracked medication while its form is open: carried in hidden fields, searched for, added or removed per round trip |
| `lib/catalog_entry.lua` | The checks of a catalog entry, shared by the catalog form and the medication box |
| `lib/reference_words.lua` | Pure Lua: turns the route and the dose form of a drug reference into words of the catalog |
| `lib/authorization_words.lua` | Pure Lua: the levels of a prior authorization that needs attention, and their words |
| `static/meds.css`, `static/*.js` | The one stylesheet and the five scripts. `[ui]` in `app.toml` names them all, and the frame loads them once, deferred, in the head of every page; no view carries a `<script>` or a stylesheet link. |
| `static/forms.js` | Shows the fields of a new record when **-- Add new --** is chosen. Every form works without it. |
| `static/filter.js` | Narrows the Medications page as a person types. The server filters the same way on submit. |
| `static/person_tab.js` | Remembers the person tab chosen last, by id, in local storage, and opens it by following the tab's own link. Issue 10 tracks replacing it with Privatium person profiles. |
| `static/drug_references.js` | Asks RxTerms, then the openFDA NDC Directory, then RxNorm about a name, in the browser; the search script uses it, so it is listed first |
| `static/product_search.js` | The product search of every form that needs a product: asks `/medications/search` for JSON, pages the results, falls back to the drug references, and suggests similar products while a new medication is typed |
| `lib/quick_add.lua` | A person, a pharmacy, a prescriber or a plan that a form adds by name beside its own record |
| `lib/suggestions.lua` | The values in use that text boxes offer while a person types |
| `lib/merge.lua` | The plan and the batch of a merge |
| `lib/entries.lua` | Reads the tracked medications with their products, refill dates, words, groups and search text |
| `lib/refill.lua` | Pure Lua: the group and the words of a refill status |
| `lib/fills.lua` | Checks a fill and writes it, with the tracked medication that goes with it |
| `lib/portal_reader.lua` | Pure Lua: takes the pasted text of a portal page apart into claims |
| `lib/authorization_watch.lua` | Finds the prior authorizations that end soon or have ended |
| `lib/people_filter.lua` | The person filter that list pages share |
| `lib/store.lua` | The one place that writes and removes records |
| `views/` | One template for each page. A name that starts with `_` is a partial. |

### Routes

| Route | Module | Handler |
|---|---|---|
| `GET /refills` | `home` | The Refills page, or a welcome while the household has no people |
| `GET /` | `medications` | The Medications page, which is the home page, or a welcome while the household has no people |
| `GET /setup` | `home` | Links to the parts of Setup |
| `GET`, `POST /setup/reminders` | `home` | Reminder and early refill settings |
| `GET`, `POST /setup/plans/new`, `/:id/edit`, `/:id/remove`; `GET /setup/plans` | `plans` | Payers and their rules, with removal refused while referenced |
| `GET /setup/people` | `people` | The family |
| `GET`, `POST /setup/people/new`, `/:id/edit`, `/:id/remove` | `people` | Add, change, remove |
| `GET /setup/pharmacies`, `GET /setup/prescribers` | `contacts` | The Pharmacies page and the Prescribers page |
| `GET`, `POST /setup/pharmacies/new`, `/:id/edit`, `/:id/remove` | `contacts` | Add, change, remove |
| `GET`, `POST /setup/prescribers/new`, `/:id/edit`, `/:id/remove` | `contacts` | Add, change, remove |
| `GET /setup/catalog` | `catalog` | The catalog, narrowed by `?q=` |
| `GET /setup/catalog/:id` | `catalog` | One medication with its other names |
| `GET`, `POST /setup/catalog/new`, `/:id/edit`, `/:id/remove` | `catalog` | Add, change, remove |
| `GET /medications`, `/medications/:id` | `medications` | The lists, narrowed by `?q=`, and the page of one tracked medication |
| `GET`, `POST /medications/new`, `/:id/edit`, `/:id/remove`, `POST /:id/status` | `medications` | Add, change, remove, change the status (also the Restart button) |
| `GET`, `POST /medications/:id/products/:link_id/remove` | `medications` | Remove a product from a tracked medication |
| `GET /people/:id/medication-list` | `medications` | The list made for paper |
| `GET`, `POST /fills/paste`, `/fills/paste/read`, `/fills/paste/add` | `paste` | Pasted fills: paste, review, add |
| `GET /fills` | `fills` | Fill history, with search, filters and the total paid |
| `GET /fills/reports` | `reports` | Reports tab: paid by year as a chart and a table, under the same filters |
| `GET /fills/reports/print` | `reports` | The printable spending report under the same filters |
| `GET`, `POST /fills/new`, `/:id/edit`, `/:id/remove` | `fills` | Record, change, remove |
| `GET /authorizations`, `GET`, `POST /authorizations/new`, `/:id/edit`, `/:id/remove` | `authorizations` | Prior authorizations |
| `POST /setup/catalog/:id/names`, `GET`, `POST /:id/names/:name_id/remove` | `catalog` | Other names |
| `GET /setup/catalog/:id/merge`, `GET`, `POST /:id/merge/:target_id` | `catalog` | Merge two entries |

### Conventions to preserve

- Saving the reminder settings reuses the id of the stored `profile` row. That makes
  the save an amendment rather than a second row. Do not mint a new ULID on save.
- A form never sends a person to another page to add a record it needs. A drop-down of
  people, pharmacies or prescribers is the partial `_select_or_new`, read with
  `quick_add.read`. A catalog product is the partial `_medication_picker`, read with
  `medication_pick.read`. The products of a tracked medication are the partial
  `_product_picker`, read with `product_pick.handle`; they travel in hidden fields and
  the form comes back after each add or remove. The new records and the record of the
  form land in one batch.
- What a person takes is a tracked medication, not a catalog product. Fills and prior
  authorizations name `person_medication_id`. A product belongs to one tracked
  medication of a person, and a preferred name is unique within a person; the forms
  check both, through `entries.with_product` and `entries.named`.
- A fill, an authorization or a pasted fill for a product on no list of the person adds
  a tracked medication through `entries.add`, named after the product's full name.
- The marks of a tracked medication come from its products through `v_entry_mark`, as 1
  or 0. Lua treats 0 as true, so `entries.lua` turns them into booleans before a
  template reads them.
- The person tab chosen last lives in the browser, in `static/person_tab.js`. The server
  never stores it.
- The top bar and the footer are the page frame's. The app draws its section tabs in
  `views/_nav.lsp` and nothing else around a page. `[ui] navigation = "swap"` in
  `app.toml` makes a link or a form inside the page replace only the main region, so a
  script runs once for the whole visit and never sees a fresh page. A script therefore
  listens on `document`, or sets up each new page on `htmx:load` and marks what it set
  up so it is never bound twice; it never calls `location.replace` to change the page,
  because that brings back the full reload. Lint rule PV111 refuses a `<script>` or a
  `<link rel="stylesheet">` in a view; name the file in `[ui]` instead.
- A page-specific action, such as **Print list**, goes in the frame's menu through
  `menu(label, path, icon)` at the top of the view that `pv.render` names, before its
  markup, never in a partial. An action every page needs would be an `[[ui.menu]]` entry
  in the manifest; the section tabs carry Setup, so the app declares none.
- A typed name that a record already has picks that record. No form adds a name twice.
- Every form that needs a product shows `views/_product_box.lsp`. The entry form wraps it
  in `_product_picker.lsp`: a search with `product_q` and `step=find_product`, and the
  results that come back checked as `pick_<medication id>=yes` are added together. The
  fill and authorization forms show the box with one radio button per result, named
  `medication_choice`, which `medication_pick.read` takes as the choice;
  `medication_pick.searched` says when the form must come back with results instead of
  saving. The review of pasted fills keeps the explicit `_medication_picker.lsp`. The
  browser asks `GET /medications/search?q=` for the same results as JSON. A typed search
  with nothing chosen never saves a form.
- Submit buttons are named `step`, never `action`: a control named `action` shadows
  `form.action` in WebKit, and the page frame's script reads that property to post the
  form (Privatium issue 68).
- The fields of a new medication carry the route and the form a drug reference gave as
  hints in `_route_ref` and `_dose_form_ref`. The route, form and package type
  drop-downs win over the hints when a person sets them.
- A part of a form that a script may hide carries `data-show-when="<field>=<value>"`.
  The server never relies on the script: the choice `new` with nothing typed is
  refused, and without the script a typed name wins over the drop-down.
- Prescription numbers are compared through `fills.rx_key`, without hyphens and spaces.
- A text box whose values repeat gets `suggestions` in `_field`, which renders a
  `<datalist>`. It needs no script.
- A row of `medication` that was copied from a drug reference keeps its `rxcui`,
  `source` and `retrieved_on` through every amendment. `catalog_entry.read` carries them.
- An amendment replaces the whole row. Read the row, change what the form changed, and
  append every column. A column left out of the append is cleared.
- Privatium does not apply a column `DEFAULT` on write. Supply every required value in
  Lua.
- Refill eligibility follows the latest fill's payer, its rolling frame and allowance.
  Physical supply stacks across every fill, with no credit for gaps. Overdue uses supply;
  due uses eligibility. Controlled fills count across payers without a frame limit.
  Zero percent waits for physical exhaustion. Frame 0 counts the last fill only, and
  3650 counts all history. Preserve the raw boolean in views because Lua treats 0 as true.
- A medication's short name is `Brand (Generic) strength release package` unless a
  person typed another; the release part (`24 HR XR`, `12 HR XR`, `DR`, `EC`) appears only
  when the product has one. A pack of tablets shows `Pack of N` in place of a strength.
  One product in two packages is two medications with one RxCUI.
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
- Pasted text is untrusted. `portal_reader` only takes it apart; `fills.read` checks every
  value, and the add step reads the text again instead of trusting the review form.
- A close match in a search is a suggestion. Code never picks a medication from one.
  Two things pick one: a name that exactly one medication answers to, and a pasted name
  that starts with the brand or generic name of exactly one medication and holds its
  strength. The review of pasted fills shows the second kind, marked, before anything
  is added.
- The catalog can hold thousands of entries. A search narrows in SQL first and compares
  the few that are left in Lua, or a request runs out of steps. A page never lists the
  whole catalog.
- What the lookup script puts into a form is untrusted. `medication_pick` and
  `catalog_entry` check it like typed text. The script writes answers of a reference
  with `textContent`, never as markup.
- `lib/starter_catalog.lua` is written by `tools/build_seed.py` from the lists in
  `tools/seed/`. Change the lists and run the script. Do not edit the module by hand.
  `lib/starter.lua` loads it when a page finds the catalog empty; there is no
  `sample/seed.jsonl`, so the catalog lives in one place.
- A diagnostic message holds no field value. `page.masked` strips quoted values.
- Templates use `<?= ?>` only. There is no `<?raw ?>` here and there should not be.
- `static/meds.css` uses the shell's color tokens. Inherit form controls and focus rings
  rather than duplicating the shell stylesheet.
- Every source file carries the project header from `AGENTS.md`, not Privatium's.
- Health information will live in this app. Keep real names, dates of birth and
  medication records out of `lib/starter_catalog.lua`, tests and documentation.
- `lib/starter_catalog.lua` holds the starter catalog only. It never
  holds a person or a record about one, so it is safe in a real household.
- The invented household for tests and screenshots is `tests/fixtures/sample-household.json`.
  It stays outside the app folder and is never a Privatium seed, so no household is ever
  offered it. Its products are fixed ids of the starter catalog.

### Extending it

Adding a field means one column in `schema.sql`, one input in the form, and one key in
every `pv.append` call that writes the table. A dose form that the starter list lacks
gets its icon in `lib/form_icon.lua`. The schema change rematerializes from the
logs; existing events lack the key and the column is NULL for them. Adding a table means
a `CREATE TABLE` with a grain comment and a section in the data model page.

Run the checks in [the test how-to](../../docs/how-to/run-the-tests.md) before
finishing: `privatium lint apps/meds`, `lua5.4 tests/lua/run.lua`, `python3 tests/test_supply.py`, `python3 tests/test_catalog.py` and `tests/smoke.sh`.
A new check in `lib/validate.lua` gets unit tests, and a new screen gets smoke tests,
with at least one request that must be refused.
