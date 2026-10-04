<!--
This file is part of Prescription Tracker
docs/plans/standard-chrome.md
Author(s): Gabriel Mongefranco
Created: 2026-10-04
Last Modified: 2026-10-04
Summary: Plan for moving the app onto Privatium's standard top bar and footer, its single menu,
         and in-document navigation between pages, including what each browser script must
         change to keep working when pages are swapped instead of reloaded.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.

-->

# Prescription Tracker: Plan — the standard bar, footer and in-app navigation
[← Back to README](../../README.md)


## Summary
Privatium is gaining a standard top bar and footer for every app, one menu that apps can
add items to, a live status line, and a way for a Lua app to change pages without reloading
the document. This plan says what the Prescription Tracker changes to use all of that: one
new table in `app.toml`, a handful of template lines, and a careful pass over its five
browser scripts. It is written for whoever makes the change, person or assistant, and it
assumes the framework work has shipped first.


## What you get when this is done
- The same top bar as every other app: the Privatium mark on the left linking to the
  launcher, "Prescription Tracker" in the middle, and the Apps and Menu buttons on the
  right. The bar and the footer stay still while pages change beneath them.
- No flash between pages on a phone. Moving from Medications to Refills swaps the page
  content inside the open document instead of loading a new one.
- A menu that holds the app's secondary actions, such as printing a person's list,
  above Privatium's own settings pages.
- A footer status line that says when the phone is offline and when its changes have been
  sent, with no code in this app.


## Before you start

### The framework release this depends on
The manifest parser in Privatium refuses any key it does not know. The `[ui]` table this
plan adds therefore needs a Privatium release that carries all three framework milestones
of its chrome plan: the bar and menu, chrome for app-owned documents, and swap navigation.
That plan lives at `docs/plans/chrome-and-navigation.md` in the Privatium repository, and
the contract sections it changes are `spec/app-contract.md §3` (the `[ui]` table),
`spec/lua-api.md §4.1` (the page frame, `menu()`, where scripts load) and
`spec/protocol.md §8.3.1` (what a swap may and may not do).

Do not start until a tagged release carries those sections. Read them from the release's
tree, not from memory, and follow the spec where this plan and the spec disagree; this
plan is the older document.

### Pin the release
The lint workflow in `.github/workflows/lint.yml` downloads a pinned Privatium release
through `PRIVATIUM_VERSION`. Point it at the release above before touching the manifest,
or the lint fails on an unknown table. `docs/how-to/run-the-tests.md` names the version a
person needs locally; update it in the same change.

### Read first
`AGENTS.md` in this repository in full, then `apps/meds/SKILL.md`, then the three spec
sections above, then the tier 1 skill shipped with that release
(`app-skills/privatium-tier1-lua/SKILL.md`), which carries the worked pattern for a script
that survives a swap.


## The changes

### 1. The manifest
Add to `apps/meds/app.toml`, after `[nav]`:

```toml
[ui]
navigation = "swap"
styles     = ["static/meds.css"]
scripts    = [
  "static/forms.js",
  "static/filter.js",
  "static/person_tab.js",
  "static/drug_references.js",
  "static/product_search.js",
]
```

The chrome itself needs no key: the standard bar is the default. Every script now loads
on every page, once, in the document head. The two large scripts, the drug references and
the product search, were only loaded on form pages before. That is the price of a page
swap never needing a script it does not have, and the framework caches the files for a
day, so a phone downloads them once.

Raise `version` to `0.6.0`. Pages behave differently, so this is a minor version.

### 2. The templates
Remove every stylesheet and script element from the views. Under swap navigation the lint
rule `PV111` refuses them, and the framework strips scripts from swapped content anyway.

| File | Remove |
|---|---|
| `views/_nav.lsp` | the `meds.css` link and the `forms.js` script |
| `views/medications.lsp` | the `filter.js` script |
| `views/_medication_names.lsp` | the `drug_references.js` and `product_search.js` scripts |
| `views/_people_filter.lsp` | the `person_tab.js` script |

Keep the section navigation in `views/_nav.lsp` exactly where it is. It is the app's own
tab row inside the page, it swaps with the page, and `aria-current` keeps marking the
right section. Keep the one `<h1>` per page.

Move one secondary action into the menu with the `menu()` template helper, which adds a
page-specific item above the separator: in `views/medications.lsp`, the "Print list" link
that appears when one person is selected. Remove the button from the page so the action is
not offered twice. Leave "Copy refill history from patient portal" where it is; it is a
primary task, not a menu item. Add no app-wide `[[ui.menu]]` items: the section tabs
already carry Setup.

### 3. The scripts
Three things change for a script when pages swap instead of reload. It runs once, when the
first page loads, and never again. `DOMContentLoaded` fires once, for that first page.
Elements it bound to disappear when the page swaps, and the new page's elements are
unbound. The rule from the tier 1 skill: bind by delegation on `document`, or re-run on
`htmx:load`, and never bind the same element twice. The checks below are per file.

**`forms.js`.** Already right in shape: a `change` listener on `document`, and
`arrangeAll` runs on load and on `htmx:afterSwap`. Confirm `arrangeAll` is harmless when
run twice on the same form, which it should be, since it only sets values and hides parts.
No change expected beyond that check.

**`filter.js`.** `start` runs once and binds an `input` listener to the search box of the
page it found. After a swap to another Medications page the new box is unbound. Change it
to bind by delegation: one `input` listener on `document` that acts when the event target
matches `[data-filter-input]`, with the debounce timer kept per box, and an `htmx:load`
handler that applies a non-empty box's value to the freshly swapped rows. Remove the
one-time `start`.

**`person_tab.js`.** Two problems. The click listener binds to the one filter nav found at
load; make it a delegated `click` listener on `document` for `nav[data-person-filter] a`.
And on load it calls `window.location.replace` to open the remembered person's tab, which
under swap navigation would force a full reload and bring back the flash. Instead, on
`htmx:load` as well as on first load, find the remembered person's link in the current
filter nav and activate it with `link.click()`, so the frame's own navigation rules apply.
Guard against doing this more than once per page by marking the nav with a data attribute
after the first pass.

**`drug_references.js`.** A library with no element binding; it only exposes
`window.medsDrugReferences`. No change. It must simply be present on every page, which the
manifest now guarantees.

**`product_search.js`.** `dress` already runs on load and on `htmx:afterSwap`, and its
document-level `click` listener is delegation. Check `dress` for binding twice: it adds a
pager to a results container only when none exists, which is the right guard, so confirm
every other listener it attaches is either delegated or guarded the same way. Add
`htmx:load` beside `htmx:afterSwap` if the release's skill says `htmx:load` is the event
the frame guarantees.

For each script, remove the `document.readyState` branch only if the skill says the frame
loads `ui.scripts` with `defer`, which runs them after the document is parsed; otherwise
keep it. Keep every file's header current and its `Last Modified` date updated.

### 4. Documentation in this repository
- `apps/meds/README.md` and `apps/meds/SKILL.md`: the file tables say where each script
  loads now, that the bar and footer are the framework's, that pages swap, and the rule a
  new script must follow.
- `docs/usage.md`: the top bar, the menu, where "Print list" moved, and that the status
  line in the footer is Privatium's.
- `docs/design/README.md`: the bar and footer belong to the framework; the section tabs
  are the app's.
- `docs/compliance.md`: focus lands on the new page heading after a page change, the
  status line is a polite live region written by the framework, and the manual checks
  below with their date.
- `docs/how-to/run-the-tests.md`: the Privatium version required.
- `docs/README.md`: a line for this plan.
- `.github/copilot-instructions.md`, `CLAUDE.md`, `CODEX.md`, `GEMINI.md`: only if they
  repeat the script-loading rule; they should point at `AGENTS.md` and the skill instead.

Write all prose in plain English for someone who has never seen the app, and keep code
comments about the code as it is, never about this plan.


## Order of work
1. Bump `PRIVATIUM_VERSION` and the version in the how-to; run the lint to confirm the
   release is reachable and the app still passes as it is.
2. Scripts first, one file at a time, each still working under full-page navigation.
3. The manifest and the template removals together, since the lint checks them as a pair.
4. The menu item and the removal of the page button.
5. Documentation and the version bump.
6. One branch, one pull request, in plain English, with no co-author trailer and no tool or
   model name anywhere in the commit messages or the pull request text.


## Verification
Run from the repository root, with the pinned release's `privatium` on `PATH`:

```sh
privatium lint apps/meds
python3 tests/test_supply.py
python3 tests/test_catalog.py
PRIVATIUM=/path/to/privatium tests/smoke.sh
```

Then with `privatium dev --app meds`, on a desktop browser and on a phone over the LAN:

- Move between all five sections and into a medication, a fill form, and Setup pages. The
  bar never moves, there is no flash, and the address bar shows the right URL each time.
- The back button returns to the right page. It reloads, which is expected.
- Keyboard only: after each page change, focus is on the new page heading; the menu opens,
  lists "Print list" when one person is selected, then a separator, then the settings pages.
- Type in the Medications search box on a page reached by swapping; rows filter. Choose a
  person tab, go to another section, come back; the remembered person opens without a reload.
- Open a medication form reached by swapping; the product search pages its results and the
  drug references answer, which proves the scripts were present without a reload.
- Turn off the network on the phone; the footer says the app is offline. Turn it on; it
  says it is connected again.
- A screen reader announces the new heading after each page change and reads the footer
  status once per connection change.
- Both `ui.styles` and `ui.scripts` appear in the document head of every page, once.

Record the results in `docs/compliance.md` with the date. Never say a check passed without
having run it.


## Risks
- **A script bound twice.** Every re-run path must be guarded or delegated. The checks in
  "The scripts" name the spot in each file.
- **The remembered person tab.** `location.replace` is the one call that would reintroduce
  the flash; the plan replaces it with the link itself.
- **The lint pin.** A stale `PRIVATIUM_VERSION` fails the workflow on the `[ui]` table. It
  is the first step for that reason.
- **Discoverability of "Print list".** It moves into the menu. If people miss it, a button
  can return alongside the menu item; note the decision in `docs/usage.md`.


## Conclusion
After this change the Prescription Tracker looks and moves like every other Privatium app,
its scripts no longer depend on a page reload to start, and its documentation explains both
to the next person. The framework plan it depends on is in the Privatium repository.


## Additional resources
- [Project instructions](../../AGENTS.md)
- [The app's skill](../../apps/meds/SKILL.md)
- [Using the app](../usage.md)
- [How to run the tests](../how-to/run-the-tests.md)
- [Privatium](https://github.com/gabrielmongefranco/privatium), the framework this app runs
  on; its chrome and navigation plan is `docs/plans/chrome-and-navigation.md` there, and the
  binding text is `spec/app-contract.md §3`, `spec/lua-api.md §4.1` and
  `spec/protocol.md §8.3.1`.

[← Back to README](../../README.md)
