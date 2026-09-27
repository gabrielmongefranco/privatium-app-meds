<!--
This file is part of Prescription Tracker
docs/compliance.md
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: The security and accessibility controls the app has, the evidence for each, the
         known gaps, and the checks a person still has to make.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## Compliance

[Back to project README](../README.md)

This page lists the security and accessibility controls of the app and the evidence for
each one. It is for owners who decide whether to trust the app with their records, and
for developers and auditors. It states what was checked and what was not. It makes no
claim of compliance with any law or standard.

### Review status

| Subject | Status on 2026-09-27 |
|---|---|
| Automated checks | Passing. See [How to run the tests](how-to/run-the-tests.md). |
| Accessibility checks by a person | Not done |
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
| Form values are checked on the server | `lib/validate.lua`, `lib/fills.lua` and the route modules | Unit tests cover empty, invalid and boundary values. |
| A status is one of five allowed values | `CHECK` in `schema.sql`, and `choices.status_label` | The smoke test sends a status that does not exist. |
| A record a form points to must exist | `read_id` in the route modules | The smoke test sends ids that name nothing. |
| A website becomes a link only with `http` or `https` | `validate.website` | Unit tests and the smoke test send a `javascript:` address. |
| A page address carries ids and codes only | `lib/page.lua` turns a known code into a sentence | The smoke test sends markup as a code and as an id. |
| Pasted portal text is untrusted | `lib/portal_reader.lua` only takes the text apart. The add step reads the text again and checks every value again. | The smoke test asks to add rows that the review refused. |
| A close match never picks a medication | `lib/medication_search.lua` | The smoke test checks that a new name leaves the choice empty. |
| A record in use is not removed | `uses` in the route modules | The smoke test posts removals by hand. |
| Diagnostic messages hold no field values | `page.masked` in `lib/page.lua` | Unit tests |
| The app calls no network service | No `[permissions]` in `app.toml`, and no address outside the app in any template | Lint rules PV207 and PV504 pass. |

### Known gaps in security

- Privatium stores records as plain text and does not encrypt them on disk. Protect the
  computer and its backups. [Privatium's security page](https://github.com/gabrielmongefranco/privatium/blob/main/docs/security.md)
  explains what the framework protects.
- Removing a record hides it. The original line stays in the log.
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
| Every icon beside text is hidden from screen readers | Lint rule PV401 passes |
| Every save works without JavaScript | The smoke test uses plain form posts only |
| A refused form keeps what was typed and lists its problems | The smoke test checks both |
| Buttons are at least 44 CSS pixels high | The shell's button style. Not measured in a browser. |

### Checks a person still has to make

No automated check drives a browser, and automated tools find only part of the problems.
These checks are open:

1. Finish each main task with the keyboard only: see the refills, record a fill, paste
   fills, add a medication to a list.
2. Finish the same tasks with a screen reader.
3. Check that the list of problems takes the focus when a refused form comes back.
4. Zoom to 200% and look for overlap and cut-off text.
5. Narrow the window to 320 CSS pixels and look for sideways scrolling, above all in
   the tables.
6. Turn JavaScript off in the node's own browser and save a fill.
7. Open a print preview of the medication list.
8. Check both color schemes.

Record the date, the browser, the screen reader and the result of each check in this
section when it is done.

### Data retention

The app deletes nothing. Every record and every change stays in the log for as long as
the data directory exists. To destroy the records, destroy the data directory and every
copy of it.

### Conclusion

You now know which controls are in place, what supports each one, and what is still
open. Treat the open checks as work to do before relying on the app for a person who
uses assistive technology.

### Additional resources

- [How to run the tests](how-to/run-the-tests.md)
- [Data model](data-model.md)
- [App design](design/README.md)
- [WCAG 2.2 quick reference](https://www.w3.org/WAI/WCAG22/quickref/)
- [Privatium's security page](https://github.com/gabrielmongefranco/privatium/blob/main/docs/security.md)

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
