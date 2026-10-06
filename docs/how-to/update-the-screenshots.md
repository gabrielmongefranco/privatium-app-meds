<!--
This file is part of Medication Tracker
docs/how-to/update-the-screenshots.md
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: How to retake the screenshots in the documentation with the invented household
         and a headless browser, and how to reuse that household in other tests.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Medication Tracker

## How to update the screenshots

[Back to project README](../../README.md)

This page shows how to retake the pictures in the user guide after a screen changes. It
is for developers. One command starts a temporary node, fills it with an invented
family, and saves a picture of each main screen into `docs/images/`. It also saves the
two repository preview pictures into `images/`.

### The invented household

`tests/fixtures/sample-household.json` describes three invented people, their
prescribers, pharmacies and insurance plans, eleven medicines, their fills and two
prior authorizations. Every name and number in it is made up. The medicines are common
products from the starter catalog, named by their fixed catalog ids.

Dates in the file are written as days from today, such as `{"days_from_today": -30}`.
They are turned into real dates when the file is loaded, so the Refills page shows
every group on any day you run it. The file also holds a short invented patient-portal
text for the paste screens.

The file is test data. It lives outside `apps/meds`, so Privatium never offers it as
sample data, and it must never be loaded into a real household's node. Other tests may
reuse it the same way: load the starter catalog first, then post the records to the
node's data API.

### What you need

| Tool | Note |
|---|---|
| Privatium 0.3.2 or later | Set `PRIVATIUM` to its path when it is not on your path. |
| Firefox 128 or later | It runs headless. Set `FIREFOX` to use another copy. |
| Node.js 20 or later | Set `NODE` to use another copy. |
| Bash and curl | |

### Steps

1. From the root of the repository, run:

   ```sh
   PRIVATIUM=/path/to/privatium tests/screenshots/take-screenshots.sh
   ```

   To save the pictures somewhere else, add a folder as the first argument. The preview
   pictures then go to the same folder, unless you add a second folder for them. The node uses
   port 18491 and Firefox port 9222; set `MEDS_SHOT_PORT` or `MEDS_BIDI_PORT` to change
   them.
2. Open each new PNG and check it. It must show only the invented family.
3. If a screen changed its words, update the picture's alt text in the
   [user guide](../usage.md) so it still describes what the picture shows.

### What the script does

1. It copies the app into a temporary data folder and starts a node there, so nothing
   touches your own data or the repository.
2. It starts a headless Firefox with a fresh profile.
3. It opens the catalog page, so the starter catalog loads.
4. It loads the invented household through the node's data API.
5. It drives Firefox over WebDriver BiDi to each screen, fills in the product search
   and the portal paste, and saves a picture 1200 pixels wide, cut at 2000 pixels tall.
   The Refills page is also saved at phone width.
6. It saves the top of the Refills page as `Repo-preview.png` (912 by 512 pixels) and
   `Repo-preview-thumb.png` (360 by 202 pixels). It draws the page smaller instead of
   stretching the picture, so the words stay sharp.
7. It stops the node and Firefox and removes the temporary folder.

The script exits with code 1 when a page does not load or the household is refused, and
with code 2 when the node or Firefox does not start.

### Conclusion

You can now retake every screenshot in one step and reuse the invented household in
other tests.

### Additional resources

- [User guide](../usage.md), where the pictures appear
- [How to run the tests](run-the-tests.md)
- [How to set up a development copy](set-up-a-development-copy.md)
- [WebDriver BiDi specification](https://w3c.github.io/webdriver-bidi/)

[Back to project README](../../README.md)

----

Copyright © 2026 Gabriel Mongefranco
