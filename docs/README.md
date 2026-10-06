<!--
This file is part of Medication Tracker
Copyright © 2026 Gabriel Mongefranco
Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Medication Tracker

## Documentation

[Back to project README](../README.md)

This folder holds the guides for Medication Tracker. The first group is for families
who use the app. The second is for developers who change it. The project README shows
how to install the app.

### For families

- [User guide](usage.md): how to use every screen, with pictures.
- [Words to know](glossary.md): the pharmacy, insurance and app words, in plain language.
- [How the app works](how-it-works.md): how the app picks refill dates, why it keeps a
  backup supply, how it estimates insurance rules, and what stays private.
- [Compliance](compliance.md): the security and accessibility checks, what they found,
  and what a person still has to check.

### For developers

- [Architecture](architecture.md): the parts of the app, page navigation, the rules for
  browser scripts, the product box, the portal reader and the drug references.
- [Data model](data-model.md): every table, its grain, the meaning of each column, which
  fields hold personal or health information, and the exact refill date rules.
- [How to set up a development copy](how-to/set-up-a-development-copy.md): run the app
  from a clone while you change it.
- [How to run the tests](how-to/run-the-tests.md): the lint, the unit tests, the supply
  tests and the smoke test.
- [How to build the starter catalog](how-to/build-the-starter-catalog.md): the script
  that writes the catalog the app ships, its sources and their licenses.
- [How to update the screenshots](how-to/update-the-screenshots.md): the invented
  household and the script that takes the pictures in these guides.
- [Documentation template](doc-template.md): a starting structure for a new page.
- [Skill authoring examples](skill-examples.md): optional recipes for AI assistant skills.

### Conclusion

If you use the app, start with the user guide. If you are about to change the app, start
with the architecture page and the data model.

### Additional resources

- [Project instructions](../AGENTS.md)
- [Skills index](../SKILLS.md)
- [The app folder](../apps/meds/README.md)
- [Privatium](https://github.com/gabrielmongefranco/privatium), the framework this app runs on.

[Back to project README](../README.md)
