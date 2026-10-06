<!--
This file is part of Medication Tracker
docs/compliance.md
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-05
Summary: The security and accessibility controls the app has, the evidence for each, the
         known gaps, and the checks a person still has to make.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Medication Tracker

## Compliance

[Back to project README](../README.md)

This page lists what the app does to protect your records and to work for people with
disabilities, and the evidence for each control. It is for families deciding whether to
trust the app with their records, and for developers and auditors. It says plainly what
was checked and what was not. It makes no claim to meet any law or standard.

### Review status

| Subject | Status on 2026-10-05 |
|---|---|
| Automated checks | Passing. See [How to run the tests](how-to/run-the-tests.md). |
| Accessibility checks by a person | Partly done. A headless browser run on 2026-10-05 covered focus, reflow and the page changes; the screen reader and phone checks below are open. |
| Security review by a second person | Not done |
| Review against a health privacy law | Not done, and not claimed |

### What the app holds

The app holds health information about the members of a household: names, birth dates,
medications, the conditions they treat, prescription numbers, claim numbers and amounts
paid. The [data model](data-model.md) marks each such column.

### Security controls

| Control | Where it lives | Evidence |
|---|---|---|
| Every SQL statement binds its parameters | Every `pv.query` call uses a literal statement | Lint rule PV201 passes. The smoke test sends SQL in names, filters and ids. |
| Output is escaped | Templates use the escaping tag only. No template uses `<?raw ?>`. | Lint rule PV202 reports nothing. The smoke test sends markup in names, other names, fields and pasted text. |
| Every form that saves carries a token against cross-site request forgery | `csrf()` in every form | Lint rule PV204 passes. The smoke test posts without a token and with a wrong one, and gets status 403. |
| Plan rules have bounded percent and frame values; payer ids must exist | `schema.sql`, `lib/quick_add.lua`, `lib/routes/plans.lua` | Synthetic smoke tests check forged ids, out-of-range rules, escaping, CSRF and referenced removals. |
| Form values are checked on the server | `lib/validate.lua`, `lib/fills.lua` and the route modules | Unit tests cover empty, invalid and boundary values. |
| A status is one of five allowed values | `CHECK` in `schema.sql`, and `choices.status_label` | The smoke test sends a status that does not exist. |
| A record a form points to must exist | `read_id` in the route modules | The smoke test sends ids that name nothing. |
| A product belongs to one tracked medication of a person, and a fill names a product of its medication | `lib/routes/medications.lua`, `lib/fills.lua` | The smoke test adds a product a second time, and a fill with a product of another medication. Both are refused. |
| The browser keeps the person tab chosen last by id only | `static/person_tab.js` | Read in the code. No name reaches local storage. |
| A website becomes a link only with `http` or `https` | `validate.website` | Unit tests and the smoke test send a `javascript:` address. |
| A page address carries ids and codes only | `lib/page.lua` turns a known code into a sentence | The smoke test sends markup as a code and as an id. |
| Pasted portal text is untrusted | `lib/portal_reader.lua` and the page readers under `lib/portals/` only take the text apart. The add step reads the text again and checks every value again. | The smoke test asks to add rows that the review refused. Unit tests read invented copies of each page the app reads, and keep markup in a pasted name as text. |
| A pasted pharmacy is matched by phone number only when one pharmacy has it | `pharmacy_of` in `lib/routes/paste.lua` compares at least ten digits | The smoke test pastes a pharmacy whose name differs and whose phone number matches, and checks that no pharmacy is added. |
| A close match never picks a medication | `lib/medication_pick.lua`, `lib/medication_search.lua` | The smoke test types a misspelled name and a name that fits two medications. Both come back as a question. |
| A pasted name picks a medication only with the same name and the same strength | `lib/written_name.lua` | Unit tests check that "5 mg" is not found in "0.5 mg", "2.5 mg", "25 mg" or "875-5 mg". The review page marks the match before anything is added. |
| A record added from inside another form passes the same checks | `lib/quick_add.lua`, `lib/catalog_entry.lua` | The smoke test sends a name that is too long and a new medication with no name. |
| A refused form adds nothing | Every form writes its records in one batch | The smoke test counts the pharmacies after a refused fill that named a new one. |
| A record in use is not removed | `uses` in the route modules | The smoke test posts removals by hand. |
| Diagnostic messages hold no field values | `page.masked` in `lib/page.lua` | Unit tests |
| The node calls no network service | The Lua of the app has no function that does | Lint rule PV504 passes. |
| The browser calls three drug references, and nothing else | `permissions.remote` in `app.toml` lists them. `static/drug_references.js`, which the product search uses, names no other address. | Lint rule PV207 passes. |
| Every script and the stylesheet come from the manifest, with the hash of each file | `[ui]` in `app.toml`. No view carries a script or a stylesheet link. | Lint rules PV110 and PV111 pass. The headless browser run of 2026-10-05 counted each file once in the head and none inside the page. |
| The online search sends public drug names and product identifiers only | `static/drug_references.js` sends no cookie and no page address | Read in the code. Not measured in a browser. |
| What a drug reference answers is untrusted | The script writes it with `textContent`. The server checks every field it receives: `lib/catalog_entry.lua`, `lib/reference_words.lua`. | The smoke test sends markup as a source, a route and a dose form, and letters as an identifier. Unit tests cover the words of a reference. |

### Evidence from the refill rule tests

Checked on 2026-10-01. Tests with invented data check the limits of the percent and the
frame, plan references, the token against cross-site request forgery, escaped plan names,
and removal of a plan still in use. The supply test compares the refill dates of 3,000
invented histories with a separate day-by-day simulation, including the special frame
values and empty frames. No committed test uses real data.

### Evidence from the first build

Checked from 2026-09-26 to 2026-09-27 with Privatium 0.3:

| Check | Result |
|---|---|
| `privatium lint apps/meds` | No findings |
| Unit tests of the Lua modules | All passed |
| Smoke test of every screen over HTTP | All passed |
| `date('now', 'localtime')` inside the node | Returned the local date |
| Loading invented rows through the data API on the node's own address | Accepted |
| Loading the same rows a second time | Nothing added |
| Loading a row that had changed since the first load | Refused with status 409, nothing added |
| Reading the views with a SQLite library that lacks the decimal extension | Every view ran except the spending view |
| Each of the three drug references, called from the repository's tools | Answered, and allows calls from a browser page on another address |
| The lookup script, run outside a browser against the three references | Each reference answered a name meant for it |

The lookup script was not run inside a browser at that time.

### Known gaps in security

- Privatium stores records as plain text and does not encrypt them on disk. Protect the
  computer and its backups. [Privatium's security page](https://github.com/gabrielmongefranco/privatium/blob/main/docs/security.md)
  explains what the framework protects.
- Removing a record hides it. The original line stays in the log.
- Text boxes suggest values that other records hold, such as what a medication is for,
  and plan drop-downs show the recorded plans. Anyone who can open the app can already
  read those records.
- An online search tells the drug reference which name was typed, from which internet address.
  The reference learns nothing else. The online search is on for everyone.
- A browser may keep pages in its history and its cache. On a shared device, close the
  browser after use.
- A printed medication list is health information on paper.
- Two devices that change one record before they sync keep one of the two changes.

### Accessibility controls

The target is the Web Content Accessibility Guidelines (WCAG) 2.2, level AA.

| Control | Evidence |
|---|---|
| Every form field has a label | Lint rule PV402 passes |
| Groups of fields have a legend | Lint rule PV403 passes |
| One `<h1>` on every page, heading levels in order | Lint rule PV404 passes |
| A status is a word with an icon, never color alone | Lint rule PV405 passes |
| The app uses the shell's color tokens only | Lint rule PV406 passes. The tokens meet the contrast floors in both color schemes. |
| Tables are real tables with header cells | Lint rule PV407 passes |
| The chart has a text equivalent | The SVG has `role="img"`, a title and a description in words, and the table under it holds every number. The average line is dashed, so it never rests on color alone. |
| Every icon beside text is hidden from screen readers | Lint rule PV401 passes. The smoke test checks that the time-of-day icons carry `aria-hidden="true"`. |
| Every save works without JavaScript | The smoke test uses plain form posts only. The scripts of the app only show fields, filter rows, page results and fill fields in. |
| After a page change, focus lands on the new page heading | The page frame moves it after each swap, to the field marked `autofocus` or else the `<h1>`. The headless browser run of 2026-10-05 found the focus on the `<h1>` after each section change. |
| The footer status line is a polite live region | `<p id="pv-status" role="status">` in the page frame. Privatium writes it on a connection change; the app writes nothing to it. Not yet heard with a screen reader. |
| The bar, the footer and the pages reflow at 320 CSS pixels | The headless browser run of 2026-10-05 found no horizontal scrolling at 320 and 640 pixels on the Medications, Refills, new medication and Setup pages, with the bar's controls in view. |
| A refused form keeps what was typed and lists its problems | The smoke test checks both |
| Buttons are at least 44 CSS pixels high | The shell's button style. Not measured in a browser. |

### Evidence from browser checks

**Keyboard and zoom, 2026-10-01.** In Firefox, an insurance plan was saved with the
keyboard only. The Tab key reached each field and the Save button, and the focus outline
was visible. The plan, person, catalog, fill and reminder forms had labels and no
sideways scrolling at 320 pixels wide or at 200 percent zoom. A plan form at phone size
was also checked by eye. The smoke test covers the plain forms, including use without
scripts.

**Page changes and reflow, 2026-10-05.** A script drove headless Firefox over WebDriver
BiDi against a node on the same computer, with two invented people and the starter
catalog, at 1280 pixels wide. The script is not part of the committed tests. It found:

- Each of the five scripts and the stylesheet was in the head of the page once, and no
  script or stylesheet was inside the page.
- Moving through all five sections, into a person's tab, into the form for a new
  medication and back to Medications kept the same document; a marker set on the window
  survived every change. The title and the heading were the new page's, the row marked
  the new section, and focus was on the new `<h1>` after each change.
- The menu listed **Print list** only while one person was chosen, and the page had no
  second **Print list** button. The item left when the page changed to Refills.
- The person tab chosen last was remembered by id, and after a visit to Refills the
  Medications page opened on that person without a reload, with four requests in all.
- On a Medications page reached by a page change, typing in the search box wrote the
  count of matches. On a form reached the same way, the product search answered from the
  catalog with one pager, the pager moved to page 2, the drug references were present and
  the hidden parts of the form were hidden.
- The back button reloaded the page, and a link to `/settings` left for a fresh document.
- No horizontal scrolling at 320 and 640 CSS pixels on the Medications, Refills, new
  medication and Setup pages, with the bar's controls inside the viewport.

**History and reports, 2026-10-05.** The same kind of script, with the invented
household of `tests/fixtures/sample-household.json`, found:

- Typing "ice pack" in the Fill history search box left one fill on the page, with its
  note row, and the status line said "1 fill matches."
- **Find** changed the page without a new document, and the person tabs kept the search.
- The **Printable report** link opened a second tab and left the Reports page in place.
  The **Print** button showed once the page loaded.
- No horizontal scrolling at 320 CSS pixels on the Fill history and Reports tabs.

The pictures in the user guide also showed no button or number broken mid-word in the
fills table at 1200 pixels.

### The release zip and the documentation website

The release workflow and the website are outside the app, but people download one and
read the other, so their controls are listed here.

| Control | Where it lives | Evidence |
|---|---|---|
| The release zip holds the app folder only, from the tagged commit | `git archive` of `apps/meds` in `.github/workflows/release.yml` | On 2026-10-05 the same command made a zip of 111 files, all under `meds/`, with no test or fixture file. Privatium 0.3.2 loaded the app from it. |
| A release is lint-checked, and its tag must match the app version | The `lint` job and the version check in `release.yml` | The check passed `v0.9`, `v0.9.0` and `0.9.0` for version 0.9.0, and refused `v0.8`, `v0.9.1` and `v1`, on 2026-10-05. |
| Each zip comes with its SHA-256 checksum | `meds.zip.sha256` on the release | `sha256sum -c` reported `meds.zip: OK` on the test zip. |
| The release tag reaches the shell as an environment variable, never inside the command text | `env:` in `release.yml` | Read in the workflow. |
| Updating the app keeps the records | Privatium keeps them in its data folder, apart from `apps/meds` | On 2026-10-05 an invented person added on a test node was still listed after the `meds` folder was replaced with a fresh unzip and the node restarted. |
| The website loads no script except on a page with a diagram, and then only Mermaid 12.1.0 pinned by an integrity hash, in strict mode | `_layouts/default.html`, `assets/js/diagrams.js` | Read in the layout. The hash matched the file the browser loaded on the data model page. |
| The website's text meets the contrast floor | `assets/css/site.css`, with the Privatium website's colors | Computed ratios: text 16.5:1 on the page and in the header, gray footer text 6.5:1, the focus outline 5.9:1 on the page and 11.9:1 in the header. |
| The website reflows at 320 CSS pixels, and the skip link comes first | The layout and the stylesheet | A headless Firefox run on 2026-10-05 of a local build found no sideways scrolling at 320 and 1200 pixels on the home page, the documentation index, the user guide and the data model page. The first Tab reached **Skip to content**, and Enter moved the focus to the main content. The diagram drew on the data model page at both widths. |
| Every link inside the website leads somewhere | Jekyll turns links to `.md` files into page links | A script on 2026-10-05 followed every internal link and anchor of the local build: none was broken. |

### Checks a person still has to make

The committed tests don't drive a browser, and the headless runs above used no phone, no
screen reader and no lost connection. Automated checks find only part of the
accessibility problems. These checks are open:

1. Finish each main task with the keyboard only: see the refills, record a fill, copy
   fills from a portal, and add a medicine to a list. In the product box, pick a
   suggestion while typing and open **Not in the list? Add a medication to the catalog**.
2. Finish the same tasks with a screen reader.
3. With the keyboard only, open the menu after a page change. It must list **Print
   list** when one person is chosen, then a separator, then Privatium's settings pages.
4. With a screen reader, change pages and listen for the new heading.
5. Turn the network off and on. The footer must say the app is offline and then
   connected again, once per change, and a screen reader must announce it.
6. On a phone over the local network, move between the five tabs and into a form. The
   bar must not move and nothing must flash.
7. Check that the list of problems takes the focus when a refused form comes back.
8. Zoom to 200% and look for overlap and cut-off text.
9. Narrow the window to 320 CSS pixels and look for sideways scrolling, above all in the
   tables.
10. Turn JavaScript off and save a fill.
11. Open a print preview of the medication list.
12. Check both color schemes.
13. Check how a screen reader announces the suggestions of a text box. Browsers and
    screen readers differ in their support for the `<datalist>` element. The fields work
    as plain text boxes where the suggestions are not announced.
14. Search for a product and pick an online result in a browser, with the keyboard only
    and with a screen reader. Check that the status message is announced and that the
    results can be reached.
15. Check the specialty and controlled marks that the online search suggests against a
    real label before relying on them.
16. With a screen reader, open the Reports tab. The chart must be read as one image
    with its title and description, and the table under it must hold the same numbers.
17. Print the spending report on paper, or to a PDF, and check that the menus and
    buttons are gone and every column fits.
18. On the documentation website, read the home page and the user guide with a screen
    reader, zoom to 200%, and check that the header links and headings are announced in
    order.

Record the date, the browser, the screen reader and the result of each check here when
it is done.

### Data retention

The app deletes nothing. Every record and every change stays in the log for as long as
the data directory exists. To destroy the records, destroy the data directory and every
copy of it.

### Conclusion

You now know which controls are in place, what supports each one, and what is still
open. Finish the open checks before you rely on the app for someone who uses assistive
technology.

### Additional resources

- [How to run the tests](how-to/run-the-tests.md)
- [Data model](data-model.md)
- [Architecture](architecture.md)
- [How the app works](how-it-works.md)
- [WCAG 2.2 quick reference](https://www.w3.org/WAI/WCAG22/quickref/)
- [Privatium's security page](https://github.com/gabrielmongefranco/privatium/blob/main/docs/security.md)

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
