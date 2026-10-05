<!--
This file is part of Prescription Tracker
docs/how-to/set-up-a-development-copy.md
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: How to run the app from a clone of the repository while you change it, and how
         to lint it before you commit.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## How to set up a development copy

[Back to project README](../../README.md)

This page shows how to run the app straight from a clone of the repository, so a change
you save shows up when you refresh the browser. It is for developers. To simply use the
app, follow the Quick Start Guide in the project README instead.

### What you need

| Tool | Note |
|---|---|
| Privatium 0.3.2 or later | The app's manifest uses a `[ui]` table that older versions refuse. |
| Git | To clone the repository |

You need Python only to rebuild the starter catalog and to run some of the tests. The
app itself is Lua, SQL and HTML templates that Privatium runs.

### Steps

1. Run Privatium once so it creates its data folder. Every start prints the folder on a
   line that starts with `privatium: data in`. On Linux it is `~/.local/share/privatium`.
2. Clone the repository and link the app folder into the `apps` folder of that data
   folder, with the name `meds`:

   ```sh
   git clone https://github.com/gabrielmongefranco/privatium-app-meds.git ~/git/privatium-app-meds
   ln -s ~/git/privatium-app-meds/apps/meds ~/.local/share/privatium/apps/meds
   ```

   On Windows without permission to create symbolic links, copy the folder instead, and
   copy it again after each change.
3. Start the development loop:

   ```sh
   privatium dev --app meds
   ```

   The command prints the app's address. Save a file, refresh the browser, and the
   change is there.
4. Before you commit, lint the app from the root of the repository and fix every
   finding:

   ```sh
   privatium lint apps/meds
   ```

   The command exits with code 3 while any finding remains. Then run the other checks in
   [How to run the tests](run-the-tests.md).

Link the app folder; never use the repository itself as Privatium's data folder. That
keeps private keys and real records out of the working tree.

### Try it with invented data

A new data folder starts empty. To see the app filled in, use the invented household in
`tests/fixtures/sample-household.json` through the screenshot script, which loads it into
a temporary node. [How to update the screenshots](update-the-screenshots.md) explains it.
Never load that file into a real household's node.

### Conclusion

You can now run the app from your clone, see each change at once, and lint it before you
commit.

### Additional resources

- [How to run the tests](run-the-tests.md)
- [How to update the screenshots](update-the-screenshots.md)
- [Architecture](../architecture.md)
- [Privatium's guide to an app in its own repository](https://github.com/gabrielmongefranco/privatium/blob/main/docs/app-repository.md)
- [Privatium's backup and restore guide](https://github.com/gabrielmongefranco/privatium/blob/main/docs/backup-and-restore.md), which names the data folder on each platform

[Back to project README](../../README.md)

----

Copyright © 2026 Gabriel Mongefranco
