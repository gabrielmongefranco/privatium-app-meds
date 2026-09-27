<!--
This file is part of Prescription Tracker
apps/meds/README.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-09-26
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

The app greets your household by the name you give it and lets you change that name.
That is the whole behavior of this first version. The prescription, refill and
prior-authorization screens come next; [the data model page](../../docs/data-model.md)
records each table as it lands.

### Files

| File | Job |
|---|---|
| `app.toml` | Manifest: slug, title, tier, icon |
| `app.lua` | Routes: the home page, the form, and the save |
| `schema.sql` | Tables, rebuilt from the event log on every start |
| `views/index.lsp` | The home page |
| `views/edit.lsp` | The name form |
| `static/meds.css` | Styles, using the shell's color tokens |
| `sample/seed.jsonl` | Synthetic sample data an owner can load into an empty app |
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

[Back to the project README](../../README.md)
