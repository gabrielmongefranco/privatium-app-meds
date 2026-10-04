<!--
This file is part of Prescription Tracker
apps/meds/README.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-10-04
Summary: What the meds app folder holds and how to run it.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco
Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See the project README for full license information.
-->

# Prescription Tracker

## The `meds` app folder

[Back to the project README](../../README.md)

This folder is the app itself. Privatium loads it from the `apps/` folder of its data
directory, and nothing outside this folder is needed to run it. The rest of the
repository holds the documentation, the license and the assistant guides.

### What it does today

The app shows which refills are due, keeps the medication list of each person with the
catalog products behind each medication, records fills by hand or from the pasted text
of a portal, and tracks prior authorizations.
[The usage page](../../docs/usage.md) shows how to use every screen.

[The data model page](../../docs/data-model.md) describes each table, and
[the app design](../../docs/design/README.md) explains the rules behind the screens.

### Files

| File | Job |
|---|---|
| `app.toml` | Manifest: slug, title, tier, icon |
| `app.lua` | The entry point, which loads the route modules |
| `lib/routes/` | The routes, one module for each part of the app |
| `lib/` | Shared Lua: checks for form values, choices, names, and the one module that writes records |
| `schema.sql` | Tables and views, rebuilt from the event log on every start |
| `views/` | One template for each page. A name that starts with `_` is a part that pages share. |
| `static/meds.css` | Styles, using the shell's color tokens |
| `lib/starter_catalog.lua` | The starter catalog of common medications, as a Lua table. `tools/build_seed.py` writes it. |
| `lib/starter.lua` | Loads the starter catalog the first time a page finds the catalog empty |
| `static/drug_references.js` | Asks the public drug references about a name. The two scripts below use it. |
| `static/product_search.js` | The product search of every form that needs a product: catalog first, then the drug references, with paged results. The server searches without it. |
| `static/filter.js` | Narrows the Medications page as a person types. The server does the same when the form is sent. |
| `static/person_tab.js` | Remembers the person tab chosen last, in the browser, until Privatium offers person profiles. |
| `SKILL.md` | Context an AI assistant loads before extending this app |

### Run it

Link this folder into the `apps/` folder of your Privatium data directory, then start the
development loop. Every node start prints its data directory on a line beginning
`privatium: data in`.

```sh
ln -s ~/git/privatium-app-meds/apps/meds ~/.local/share/privatium/apps/meds
privatium dev --app meds
```

Save a file and refresh the browser. There is nothing to restart.

### Check it

```sh
privatium lint apps/meds
```

The command exits with code 3 while any finding remains.
[The test how-to](../../docs/how-to/run-the-tests.md) covers the unit tests and the smoke
test.

[Back to the project README](../../README.md)
