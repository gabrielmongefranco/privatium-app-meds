<!--
This file is part of Prescription Tracker
docs/architecture.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-10-05
Summary: How the app is built: its parts, the page frame and in-document navigation, the
         rules every browser script follows, the product box, the reader of pasted portal
         text, the catalog and the drug references, and the accessibility and security
         design.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## Architecture

[Back to project README](../README.md)

This page explains how the app is put together, for developers who change it. It covers
the parts of the app folder, how pages change inside Privatium's page frame, how forms
find and add records, how the History filters and reports work, how pasted portal text
becomes fills, and how the catalog uses the public drug references. The [data model](data-model.md) describes every table and the
exact date rules. [How the app works](how-it-works.md) gives the same rules in plain
words for families.

### Parts of the app

The app is a Privatium Tier 1 app: Lua 5.4 on the server, LSP templates for HTML, and a
SQL schema. Privatium stores each record as a line in an append-only log and rebuilds
the SQLite tables from the log on every start.

| Part | Where | What it does |
|---|---|---|
| Manifest | `apps/meds/app.toml` | Slug, title, tier, icon, the three drug reference addresses under `permissions.remote`, and the `[ui]` table with the stylesheet, the scripts and swap navigation |
| Routes | `apps/meds/lib/routes/` | One module per part of the app. `app.lua` requires them in the order paths are tried. |
| Shared Lua | `apps/meds/lib/` | Form checks, names, matching, refill words, the portal reader and the one module that writes records (`store.lua`). Modules with no framework calls are unit-tested with plain Lua. |
| Schema | `apps/meds/schema.sql` | Tables and views, including `v_supply` and `v_active_medication`, which work out the refill dates in SQL |
| Templates | `apps/meds/views/` | One template per page. A name starting with `_` is a partial. |
| Browser scripts | `apps/meds/static/*.js` | Five small scripts that improve forms. Every form works without them. |
| Starter catalog | `apps/meds/lib/starter_catalog.lua` | Written by `tools/build_seed.py`; `lib/starter.lua` loads it when a page finds the catalog empty |

The node itself never calls a network service. Tier 1 Lua has no function that could.
Only the browser asks the public drug references, and only from the product search.

### Page frame and navigation

The top bar and the footer belong to Privatium's page frame and are the same in every
app. The bar holds the Privatium mark, which opens the launcher, the app title, the
**Apps** link and the one **Menu**. The footer has a status line that Privatium writes
when the connection changes. The app adds nothing to either.

Below the bar, `views/_nav.lsp` draws the app's own row of five tabs: **Medications**
(the home page, at `/`), **Refills**, **History**, **Authorizations** and **Setup**. The
current tab carries `aria-current="page"` and an underline. The row is part of the page,
so it changes with the page.

`[ui] navigation = "swap"` in the manifest makes a link or a form inside the page fetch
the next page and replace only the main region. The frame keeps the bar still, takes the
new title, moves focus to the new heading (or to a field marked `autofocus`), and
refreshes the menu items for the page. The browser's back button reloads the page it
returns to, and a link to `/settings` leaves for a fresh document.

The menu holds secondary actions. The Medications page adds **Print list** for the chosen
person with `menu(label, path, icon)` at the top of the view that `pv.render` names. The
app declares no app-wide `[[ui.menu]]` item, because the tab row already carries Setup.

### Rules for browser scripts

Because pages are swapped rather than loaded, a script runs once for the whole visit and
never sees a fresh page. So every script follows these rules:

- The manifest names every stylesheet and script in `[ui]`. The frame loads them once,
  deferred, in the head of every page. Lint rule PV111 refuses a `<script>` or a
  stylesheet link inside a view.
- A script listens on `document`, or sets up each new page on the `htmx:load` event and
  marks what it has set up, so nothing is bound twice.
- A script never calls `location.replace` or reloads the page to move on, because that
  brings back the full reload.

| Script | Job |
|---|---|
| `forms.js` | Shows the box for a new record when **-- Add new --** is chosen, and empties it when another choice is made. Shows and runs the **Print** button of the printable report. |
| `filter.js` | Narrows the Medications page and the Fill history as you type, and opens the closed section when a match is inside it. A fill and its note row form one `tbody` and hide together. |
| `person_tab.js` | Remembers the last person tab, by id, in local storage, and opens it by following the tab's own link. On the History tabs, it drops the line between the two groups of tabs when the person tabs wrap underneath, which CSS cannot detect. |
| `drug_references.js` | Asks RxTerms, then the openFDA NDC Directory, then RxNorm about a name. It is listed first because the search script uses it. |
| `product_search.js` | The product search of every form: asks `/medications/search` for JSON, pages the results, falls back to the drug references, and suggests similar products while a new medication is typed |

Planned: `person_tab.js` keeps the chosen person in the browser because Privatium has no
person profiles yet. [Issue 10](https://github.com/gabrielmongefranco/privatium-app-meds/issues/10)
tracks replacing it once profiles exist.

Submit buttons are named `step`, never `action`. Privatium's frame script reads
`form.action` to post a form, and in WebKit a control named `action` shadows that
property, so the post would go to the wrong address.

### History, reports and the chart

The two History tabs, `/fills` and `/fills/reports`, and the printable report,
`/fills/reports/print`, share one set of filters in `lib/history_filter.lua`:

- `read` takes the person, medication, pharmacy, time period, search words and page from
  the address. A value that is not on offer counts as no filter. That is how a
  medication of one person goes back to "Every medication" when another person's tab is
  chosen.
- `fills` runs one fixed query for the fills under the person, medication, pharmacy and
  date filters. It then keeps the fills whose `text.key` holds every search word. The
  words are matched in Lua because Privatium's lint (PV201) refuses SQL built from
  pieces, and so the server and `filter.js` match the same text.
- `group` adds up fills by year, person or medication. It sums amounts with `pv.dec`,
  so money never passes through a floating-point number.
- `query`, `link` and `tabs` build addresses that keep the filters, for the page links,
  the person tabs and the two History tabs.

`lib/periods.lua` turns a time period into a first and last date. Weeks start on Sunday,
a constant at the top of the file.

`lib/spending_chart.lua` lays out the Paid by year bar chart: bars, axis lines, labels,
the average line and a sentence that describes the chart. It works in whole cents, so
the average is exact. `views/reports.lsp` draws it as inline SVG, with no chart library.
The page's Content Security Policy refuses inline styles, so the drawing uses classes
from `meds.css` and the shell's color variables, which also covers dark mode. The SVG
has `role="img"`, a title and a description. The table under it holds every number as
text.

The printable report is an ordinary page, like the printable medication list. A print
rule in `meds.css` hides the bar, the tabs and the buttons on paper. Its **Print** button
arrives hidden, and `forms.js` shows it and calls `window.print()`. The Reports tab links
to it with `target="_blank"`, so it opens in a new tab and the Reports page stays.

`lib/money.lua` and `views/_money.lsp` show every amount in US dollars, grouped by
Privatium's locale setting through `fmt.money`. There is no currency setting yet.

### Finding and adding records inside a form

No form sends a person to another page to find or add a record it needs.

**People, pharmacies, prescribers and plans.** A drop-down uses the partial
`_select_or_new`. Its second choice is **-- Add new --**, which shows a box for the name.
`quick_add.read` turns a typed name into a new record, or into the existing record with
that name. The new record and the form's own record are written in one batch, so a
refused form adds nothing. A record added this way holds only its name.

**Choices.** The route, the form, the package type, the medication type and when to take
it are drop-downs with the same **-- Add new --** choice. The choices are a starter list
plus every value that records already use. No table holds them; a typed value becomes a
choice once a record uses it.

**Suggestions.** A free-text box whose values repeat (the clinic, the instructions, what
a medication is for, catalog names) gets `suggestions` in `_field`, which renders a
`<datalist>` of up to 200 values. It needs no script.

#### The product box

Every form that needs a catalog product shows `views/_product_box.lsp`:

| Part | What it does |
|---|---|
| **Search the catalog** | A search box and a **Find** button. Enter or the button searches the catalog. Results come back as check boxes, best first, up to `RESULTS_MAX` (25), with a **Close match** badge on a name that is only near. With the script, the list pages 10 at a time on a wide screen and 5 on a phone. When the catalog has nothing, the script asks the drug references at once. |
| **Search online databases** | A link that asks the drug references even when the catalog found something. It needs the script. |
| **Not in the list? Add a medication to the catalog** | A closed section with the brand name, generic name, strength, route, form, package and the controlled and specialty marks. While a name is typed, the script searches for similar products with a spinner and the words "Searching for similar products...". Checking a catalog product there empties the typed fields. |
| **Add to this medication** | Adds every checked result, or the new medication, to the list of products. |

The form for a tracked medication wraps the box in `_product_picker.lsp`. The products
chosen so far travel in hidden fields, and the form comes back after each add or remove
(`product_pick.handle`). Once a product is on the list, the box folds into **Add another
product**. Nothing is written to the catalog until the form is saved. A typed search with
nothing checked never saves the form, so Enter in the search box searches.

The fill and authorization forms first offer a drop-down of the person's tracked
medications. **-- Another medication --** shows the box with one radio button per result,
read by `medication_pick.read`. A fill or authorization for a product on no list of the
person adds a tracked medication through `entries.add`, named after the product.

The server answers `GET /medications/search?q=` with the same results as JSON for the
script, and searches itself when the form is posted without the script. With a catalog of
thousands of entries, a search narrows in SQL first and compares the few rows left in
Lua, so a request never runs out of steps.

#### How a typed name picks a medication

The review of pasted fills uses the explicit picker `views/_medication_picker.lsp`. A
typed name is compared with the short name, the generic name, the brand name and the
other names, ignoring case, punctuation and extra spaces.

| What is typed | What happens |
|---|---|
| A name exactly one medication answers to | That medication is picked |
| A name several medications answer to | The form comes back and lists them |
| A name close to one the app knows | The form comes back and offers the closest |
| An unknown name | The form comes back and opens the new-medication fields |

When both the typed name and the new-medication fields are filled in, the new-medication
fields win. A new medication whose short name already exists picks that one, so the
catalog never holds the same short name twice. Code never picks a medication from a
close match.

### Pasted portal text

`lib/portal_reader.lua` takes the pasted text of a portal page apart into claims. It
looks for the labels the portal prints and takes the value after each one. This
invented example shows the layout it reads. The portal runs the columns of a row
together, as the second line shows.

```text
SERVICE DATEDRUG NAMEPHARMACYPLAN PAIDYOU PAIDCLAIM STATUS
09/20/2026EXAMPLINE 10 MG TABLETEXAMPLE PHARMACY$ 12.00$ 5.00PaidLess Info
EXAMPLE PHARMACY

1 EXAMPLE STREET. ANYTOWN, MI 480000000

555-555-0100

PHARMACY ID
1234567893

RX NUMBER
100001

DAYS SUPPLY
30

QUANTITY
30

Plan Paid

$12.00
Deductible

$0.00
Patient Responsibility

$5.00
```

| Portal label | Goes to |
|---|---|
| SERVICE DATE | The fill date, written month, day, year |
| DRUG NAME | The medication, matched as below |
| PHARMACY ID | The pharmacy, matched by its NPI |
| PHARMACY | The pharmacy, matched by name when no NPI matches |
| RX NUMBER | The prescription number |
| DAYS SUPPLY, QUANTITY | The days supply and the quantity |
| Patient Responsibility | The amount paid |
| Plan Paid, Deductible, CLAIM STATUS | Shown in the review, never stored |

For each drug name, the app looks for a medication in this order:

| Step | The app finds | The page says |
|---|---|---|
| 1 | One medication that answers to exactly this name | Known name |
| 2 | An earlier fill of the person with the same prescription number, whose medication has the drug of the name among its names | Matched |
| 2 | The same, under a name that does not fit | Choose a medication, with that one first |
| 3 | One medication whose brand or generic name starts the portal name, and whose strength the name holds | Matched |
| 4 | Medications that share words with the name | Choose a medication, best first |
| 5 | Nothing | New name, with the generic name and strength taken from the text |

Prescription numbers are compared without hyphens and spaces, through `fills.rx_key`,
and only within one person. Step 3 compares whole words and whole strengths, so "5 mg"
is not found in "0.5 mg" or "25 mg". When two medications pass a step, the app picks
neither. The portal's name is saved as another name of the medication chosen.

A fill is already recorded when the person has a fill with the same prescription number
and date, or a fill of the same tracked medication on the same date. The second rule
catches fills typed by hand without a number.

The review form carries the pasted text. On **Add fills**, the server reads and checks
the text again, keeping nothing between the two steps, and writes every included fill in
one batch, lowering each medication's refills left by one, never below zero. One paste
holds up to about 64 kilobytes, roughly 100 fills.

### The catalog and the drug references

The catalog gets its entries in three ways: the starter catalog, which the app loads
into an empty catalog; the online search, one entry at a time; and typing. The app never
loads a whole drug reference. [How to build the starter catalog](how-to/build-the-starter-catalog.md)
covers the builder.

The online search runs in the browser. It asks the references in this order and stops
at the first that finds something. A reference that limits requests, or takes longer
than 8 seconds, counts as not answering.

| Order | Reference | Asked when |
|---|---|---|
| 1 | RxTerms | Always |
| 2 | openFDA NDC Directory | RxTerms finds nothing or does not answer |
| 3 | RxNorm, approximate search | The first two find nothing or do not answer |

| Catalog field | RxTerms | openFDA NDC Directory | RxNorm |
|---|---|---|---|
| Brand name | The brand at the end of `fullName` | `brand_name`, unless it repeats the generic name | As RxTerms, when RxTerms knows the product |
| Generic name | `fullGenericName`, up to the strength | `generic_name` | The name, up to the strength |
| Strength | The start of `STRENGTHS_AND_FORMS` | `active_ingredients.strength` | The strength in the name |
| Route | `route` | `route` | As RxTerms |
| Form | `rxnormDoseForm` | `dosage_form` | As RxTerms |
| RxCUI | `RXCUIS` | `openfda.rxcui`, when exactly one | `rxcui` |

Three columns of `medication` record where an entry came from: `rxcui`, `source`
(`rxterms`, `rxnorm` or `openfda_ndc`) and `retrieved_on`. They stay with the entry
through every change, and a merge keeps those of the entry that stays.

These rules hold for every entry:

- Two entries never share an RxCUI and a package. Picking a product and package that the
  catalog holds uses the entry that is there.
- One product in two packages is two entries.
- What the browser sends is untrusted. The server checks the identifier, accepts a
  source only from its list of three, and turns the route and dose form into catalog
  words (`lib/reference_words.lua`) or leaves them out.
- An entry that a list, a fill or an authorization uses cannot be removed.

Known limits:

- **Units.** A reference can print a strength in another unit than the label. The
  builder reads openFDA labels to choose micrograms, and has lists of drugs labeled in
  micrograms or in international units. A strength it cannot settle stays as the
  reference prints it, and a person can correct it.
- **Brand names.** A generic product takes the preferred brand when it has one, or its
  only brand. A product with several brands takes none and answers to each as another
  name.
- **Package codes.** The app stores no National Drug Codes. One product has many, and
  they would need a table of their own.

### Accessibility design

The target is WCAG 2.2 level AA. [Compliance](compliance.md) records the evidence and the
checks still open.

| Need | Design response |
|---|---|
| Status without color | Every status has words and an icon. Color repeats the meaning and never carries it alone. |
| Form labels | Every field has a visible label. Help text is tied to its field with `aria-describedby`. |
| Choices | A drop-down and its **-- Add new --** box share a group with one legend. |
| Suggestions | A box with suggestions is an ordinary text box, so it works where suggestions are not announced. |
| Form errors | Each error is text next to its field, and a list at the top links to each field. The form keeps what was typed. |
| Tables | Real tables with captions and header cells. On narrow screens rows stack, with explicit table roles. |
| Keyboard | Every control is a link, a button or a field. Disclosures use `<details>`. The frame supplies the focus ring. |
| Page changes | The frame moves focus to the new heading after each swap. |
| Repeated buttons | Each **Record fill** button carries hidden text naming its medication. |
| Icons | Each dose form icon carries the form as its label, so a screen reader hears "Tablet". Icons come from the Bootstrap set Privatium ships, except a drawn syringe in `views/_form_icon.lsp`. The time-of-day icons from `lib/when_icon.lua` are hidden from screen readers, because the words beside them say the same. |
| No JavaScript | Every save and search is a plain form. |
| Color schemes | The app uses the frame's color tokens only, so it follows light and dark mode. |
| Time limits | None. A status message stays until you leave the page. |

### Security and privacy design

The app holds health information about a household: names, birth dates, medicines, the
conditions they treat, prescription and claim numbers, and amounts paid.

- **Input.** The server trims, length-limits and checks every form value
  (`lib/validate.lua`, `lib/fills.lua`), checks a status against its five values, and
  checks that every record a form points to exists. A refused form saves nothing.
- **SQL.** Every query is a literal with bound parameters.
- **Output.** Templates use the escaping tag only; there is no `<?raw ?>`.
- **Links from data.** A website becomes a link only with `http` or `https`. A phone link
  holds digits and a plus sign only.
- **Forms.** Every saving form carries the `csrf()` token.
- **Addresses.** A page address holds record ids and notice codes only. `lib/page.lua`
  turns a known code into a sentence and ignores any other.
- **Logs.** Diagnostic messages hold ids and counts, never field values (`page.masked`).
- **Pasted text.** Portal text is untrusted. It is read by position and pattern, shown
  escaped, never run, and read again on save.
- **Online search.** The browser sends the typed search text only, without cookies or the
  page address. Answers are written with `textContent` and checked by the server like any
  typed value.
- **Real records.** No real household's data is in the repository. Tests, screenshots and
  documentation use invented data, such as
  [the sample household](../tests/fixtures/sample-household.json).

### Conclusion

You now know how the app's parts fit together and the rules a change must keep. Read the
[data model](data-model.md) before changing the schema, and run the checks in
[How to run the tests](how-to/run-the-tests.md) before you commit.

### Additional resources

- [Data model](data-model.md)
- [How the app works](how-it-works.md)
- [Compliance](compliance.md)
- [How to run the tests](how-to/run-the-tests.md)
- [How to build the starter catalog](how-to/build-the-starter-catalog.md)
- [The app's own skill](../apps/meds/SKILL.md), with the routes and conventions
- [Privatium Tier 1 guide](../skills/privatium-tier1-lua/SKILL.md)
- [Privatium accessibility guide](../skills/privatium-accessibility/SKILL.md)
- [Privatium security guide](../skills/privatium-security/SKILL.md)
- [WCAG 2.2 quick reference](https://www.w3.org/WAI/WCAG22/quickref/)
- [Privatium](https://github.com/gabrielmongefranco/privatium), the framework this app runs on

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
