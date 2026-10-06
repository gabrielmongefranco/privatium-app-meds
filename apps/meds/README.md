<!--
This file is part of Medication Tracker
apps/meds/README.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-10-05
Summary: What the meds app folder holds and how to run it.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco
Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See the project README for full license information.
-->

# Medication Tracker

## The `meds` app folder

[Back to the project README](../../README.md)

This folder is the app itself. Privatium loads it from the `apps/` folder of its data
directory, and nothing outside this folder is needed to run it. The rest of the
repository holds the documentation, the license and the assistant guides.

### What it does

The app shows which refills are due, keeps each person's medication list with the
catalog products behind each medicine, records fills by hand or from text copied from a
patient portal, and tracks prior authorizations.
[The user guide](../../docs/usage.md) shows how to use every screen.

[The data model page](../../docs/data-model.md) describes each table, and
[the architecture page](../../docs/architecture.md) explains how the parts fit together.

### Files

| File | Job |
|---|---|
| `app.toml` | Manifest: slug, title, tier, icon, the permission to call the drug references, and the `[ui]` table that names the stylesheet and the scripts and turns on in-document page changes |
| `app.lua` | The entry point, which loads the route modules |
| `lib/routes/` | The routes, one module for each part of the app |
| `lib/` | Shared Lua: checks for form values, choices, names, and the one module that writes records |
| `schema.sql` | Tables and views, rebuilt from the event log on every start |
| `views/` | One template for each page. A name that starts with `_` is a part that pages share. |
| `static/meds.css` | Styles, using the shell's color tokens. The manifest loads it on every page. |
| `lib/starter_catalog.lua` | The starter catalog of common medications, as a Lua table. `tools/build_seed.py` writes it. |
| `lib/starter.lua` | Loads the starter catalog the first time a page finds the catalog empty |
| `static/forms.js` | Shows the fields of a new record when **-- Add new --** is chosen. Every form works without it. |
| `static/filter.js` | Narrows the Medications page as a person types. The server does the same when the form is sent. |
| `static/person_tab.js` | Remembers the person tab chosen last, by id, in the browser |
| `static/drug_references.js` | Asks the public drug references about a name. The product search uses it. |
| `static/product_search.js` | The product search of every form that needs a product: catalog first, then the drug references, with paged results. The server searches without it. |
| `SKILL.md` | Context an AI assistant loads before extending this app |

The top bar and the footer of every page belong to Privatium, not to this app. The app
draws only its row of five section tabs, in `views/_nav.lsp`, and the page under it.
Moving between pages swaps the page content inside the open document, so the bar never
moves. Because of that, every script and the stylesheet are named once in `app.toml` and
load in the head of every page; no view carries a script or a stylesheet of its own. A
new script must work on a page it did not start with: listen on the document, or set up
each new page on the `htmx:load` event and mark what it has set up, so nothing is bound
twice. The Privatium guide `skills/privatium-tier1-lua/SKILL.md` shows the pattern.

### Run it

To use the app, unzip `meds.zip` from the latest release into the `apps/` folder of your
Privatium data directory and start Privatium, as the project README shows. The zip holds
this folder and nothing else. To work on it, link the folder instead
and start the development loop. Every node start prints its data directory on a line
beginning `privatium: data in`.

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
[The test how-to](../../docs/how-to/run-the-tests.md) covers the unit tests, the supply
tests and the smoke test.

[Back to the project README](../../README.md)
