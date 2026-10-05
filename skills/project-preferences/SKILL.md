---
name: project-preferences
description: Apply repository-specific preferences when planning, implementing, or reviewing changes in this project.
---

<!--
This file is part of Prescription Tracker
Copyright © 2026 Gabriel Mongefranco
Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## Project preferences

Use this skill when planning, implementing, or reviewing changes in this repository.
Keep all project-specific preferences and workflows in this single file. This skill
supplements `AGENTS.md` and cannot weaken its security, privacy, accessibility,
licensing, testing, or authorization rules.

### Purpose and scope

This repository is one Privatium app, `apps/meds/`, the Prescription Tracker: a personal
prescription tracker for families with chronic conditions. It is a Tier 1 app, written in
Lua 5.4 with LSP templates and a SQL schema, and it runs on a Privatium node the household
controls. Everything outside `apps/meds/` is documentation, tests, licensing and
assistant guides.

### Environment and structure

- `apps/meds/` is the app folder. Its name and the `slug` in `app.toml` must stay `meds`.
- `tests/` holds the unit tests and the smoke test. They stay outside the app folder, so
  an installed app carries no test code.
- `docs/data-model.md` describes every table. It changes in the same commit as
  `apps/meds/schema.sql`.
- `apps/meds/lib/starter_catalog.lua` is the starter catalog. It holds products only and
  must never hold a real name, date of birth or medication record.
- `tests/fixtures/sample-household.json` is an invented household for tests and the
  documentation screenshots. It stays outside `apps/meds/`, so Privatium never offers it
  as sample data. `tests/screenshots/take-screenshots.sh` loads it into a temporary node.
- `skills/privatium-*` are exported by the Privatium program and match the version the
  README names. Regenerate them with `privatium skill export`; never edit `reference/`.
- Every source file, including `.lua`, `.sql`, `.lsp`, `.css`, `.toml` and `.yml`, carries
  this project's header from `AGENTS.md` section 3, not Privatium's.

Follow the repository’s existing file and folder naming conventions when adding new files.

### Setup and verification

Run the app from a link in the Privatium data directory, never with the checkout as the
data root, so private keys and real records stay out of the working tree:

    ln -s ~/git/privatium-app-meds/apps/meds ~/.local/share/privatium/apps/meds
    privatium dev --app meds

Before finishing any change to the app, lint it and fix every finding:

    privatium lint apps/meds

The command exits with code 3 while findings remain. The GitHub Actions workflow
`.github/workflows/lint.yml` runs the same lint with the pinned Privatium release.

Then run the tests from the root of the repository, and fix every failure:

    lua5.4 tests/lua/run.lua
    python3 tests/test_supply.py
    python3 tests/test_catalog.py
    PRIVATIUM=/path/to/privatium tests/smoke.sh

The unit tests need Lua 5.4, the version Privatium runs. The smoke test starts its own
node on a temporary data directory and uses invented data only.

### Project constraints

- The app will hold health information. Treat every field as sensitive until the data
  model page says otherwise, keep identifiers out of logs, URLs and filenames, and use
  invented examples everywhere.
- Writes go through `pv.append`, `pv.delete` and `pv.batch`; reads are parameterized SQL.
  There is no `INSERT`, `UPDATE` or `DELETE` in this repository.
- Money is `DECIMAL`, dates are `DATE`, and both are handled the way the Tier 1 guide
  describes. Never do arithmetic on them as floats or by adding days to a number.
- Every internal link goes through `url()` so the app works unchanged in solo mode.
- The node calls no network service. The product search in the browser, including the
  lookup of a new medication, calls three public drug references, and every form works
  without it. Add no other outside address.
- Documentation in `docs/` has two audiences. Pages for families (`usage.md`,
  `glossary.md`, `how-it-works.md`) use plain words and explain every pharmacy or
  insurance term; developer pages may be technical. After a screen changes, retake the
  screenshots as `docs/how-to/update-the-screenshots.md` shows.
- Every stylesheet and script is named in `[ui]` of `app.toml`, never in a view. Pages
  change by swapping the main region, so a script listens on the document or sets up each
  new page on `htmx:load` with a guard, and never assumes a fresh page.

### Project skills

Load `privatium-tier1-lua`, `privatium-security` and `privatium-accessibility` from
`skills/` before changing the app, and `apps/meds/SKILL.md` for the app's own schema and
conventions. Load `privatium-overview` only when a change might belong in another tier.

### Conclusion

Keep the app small, lint clean, and documented table by table.

### Additional resources

- [Project instructions](../../AGENTS.md)
- [Skills index](../../SKILLS.md)
- [The app's own skill](../../apps/meds/SKILL.md)
- [Data model](../../docs/data-model.md)
- [Privatium's guide to an app in its own repository](https://github.com/gabrielmongefranco/privatium/blob/main/docs/app-repository.md)
