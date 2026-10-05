<!--
This file is part of Prescription Tracker
docs/how-to/run-the-tests.md
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-05
Summary: How to run the lint, the unit tests and the smoke test, and what each one covers.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## How to run the tests

[Back to project README](../../README.md)

This page shows how to check the app before you commit a change. It is for developers.
There are four checks: the lint, the unit tests, the supply tests and the smoke test.
Run them all from the root of the repository.

### What you need

| Tool | Used by | Note |
|---|---|---|
| Privatium | The lint and the smoke test | Version 0.3.2 or later. The app declares a `[ui]` table in its manifest, which an older Privatium refuses as an unknown table. The project README names the same version. |
| Lua 5.4 | The unit tests | On many systems the command is `lua5.4`. Plain `lua` may be an older version. |
| Python 3 | The supply and catalog tests | Standard library only |
| Bash and curl | The smoke test | |

### Steps

1. Lint the app:

   ```sh
   privatium lint apps/meds
   ```

   The command exits with code 3 while any finding remains.

2. Run the unit tests:

   ```sh
   lua5.4 tests/lua/run.lua
   ```

   The last line gives the counts, such as "290 passed, 0 failed". The command
   exits with code 1 when a test fails, and with code 2 when Lua is older than 5.4.

3. Run the supply and catalog tests:

   ```sh
   python3 tests/test_supply.py
   python3 tests/test_catalog.py
   ```

   The supply test checks the refill date views against a simple day-by-day simulation
   of 3,000 invented fill histories, in an in-memory SQLite database. It covers plan
   changes, gaps, the edges of the supply frame, controlled medicines, missing days
   supply and row counts. The catalog test uses invented answers from the drug
   references and makes no network calls.

4. Run the smoke test:

   ```sh
   PRIVATIUM=/path/to/privatium tests/smoke.sh
   ```

   Leave `PRIVATIUM` out when the program is on your path. The test uses port 18490. Set
   `MEDS_TEST_PORT` to use another port.

### What each check covers

| Check | Covers |
|---|---|
| Lint | The rules of Privatium for an app: bound SQL parameters, the `csrf()` token in every form, labels on every field, heading order, and more |
| Unit tests | The Lua modules with no framework calls: cleaning text, checking dates, numbers, amounts, phone numbers, email and website addresses, building a short name, merging choices, matching names, refill words, reading a pasted portal page, taking apart a name as a portal wrote it, the words of a drug reference, and the icon of a dose form |
| Supply and catalog tests | The refill dates against a day-by-day simulation, date edges, the special frame values, invalid rules and view grain; the catalog builder against invented reference answers |
| Smoke test | The screens over HTTP, on a real node: adding, changing and removing records, empty and invalid input, the longest values, and requests that must be refused |

The smoke test includes these checks of requests that must be refused:

- A form post without the token, or with a wrong one, gets status 403.
- Markup typed into a name is shown as text and never sent as markup.
- SQL typed into a name or into the search box is treated as text.
- A website address that starts with `javascript:` is refused.
- A record that other records use is not removed, even by a hand-built request.
- Markup in pasted portal text is shown as text.
- A pasted fill that the review refused is not added, even when a hand-built request asks for it.
- A medication, a person or a pharmacy id that names nothing is refused.
- A form that is refused adds none of the new records it named.

When a check fails, set `MEDS_SMOKE_KEEP` to a folder and run the test again. The page of
each failed check is written there, named after the check, so you can read what the app
answered.

### How the smoke test keeps your data safe

The smoke test starts its own node on a temporary data directory. It copies the app into
that directory, so it writes nothing inside the repository and nothing in your own data
directory. It uses invented names only. When it ends, it stops the node and removes the
temporary directory.

### What no test covers

No committed test drives a browser, so none runs the online lookup of a new medication
as a person would. The smoke test checks what the server does with the fields the lookup
fills in. The screenshot script in
[How to update the screenshots](update-the-screenshots.md) does drive Firefox, but it
only takes pictures and checks no behavior. Keyboard use, a screen reader, zoom and small
screens need a person. [The compliance page](../compliance.md) lists those checks.

The smoke test works out its dates from today with `date -d`, which is the GNU form of
the command. On macOS, install GNU coreutils first.

### Conclusion

You can now run all checks. A change is ready to commit when they all pass and the
documentation matches the change.

### Additional resources

- [Architecture](../architecture.md)
- [How to update the screenshots](update-the-screenshots.md)
- [Compliance](../compliance.md)
- [Data model](../data-model.md)
- [Project preferences](../../skills/project-preferences/SKILL.md)
- [Privatium's command-line interface](https://github.com/gabrielmongefranco/privatium/blob/main/spec/cli.md), which lists the lint rules.

[Back to project README](../../README.md)

----

Copyright © 2026 Gabriel Mongefranco
