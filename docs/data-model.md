<!--
This file is part of Prescription Tracker
docs/data-model.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-09-26
Summary: Every table the app stores: grain, columns, meaning, and which fields hold
         personal or health information.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## Data model

[Back to project README](../README.md)

This page lists every table in `apps/meds/schema.sql`, what one row means, and what each
column holds. It is for anyone who reads the app's data files or changes its schema. It
changes in the same commit as the schema, so what you read here matches the code.

### How the app stores data

Privatium keeps every record as one line of plain text in an append-only log under the
node's data directory, at `data/meds/log/<device>.jsonl`. The tables below are rebuilt
from that log on every start, so deleting the SQLite cache loses nothing. Saving a change
appends a new line that reuses the row's `id`; the latest line for an `id` wins. Nothing is
ever edited in place.

Every table has an `id` column holding a ULID that the framework mints. Dates and
timestamps are stored as ISO 8601 text in UTC. Money is stored as exact decimal text,
never as a floating-point number.

The log is not encrypted at rest. Anyone who can read the files can read every row.
[Privatium's security page](https://github.com/gabrielmongefranco/privatium/blob/main/docs/security.md)
explains what the design protects and what it leaves to the owner of the computer.

### Tables

#### `profile`

Grain: one row per node. At most one row ever exists; saving the name again amends that row.

| Column | Type | Meaning | Personal or health information |
|---|---|---|---|
| `id` | `VARCHAR`, primary key | ULID minted by the framework | No |
| `display_name` | `VARCHAR`, required | What the app calls the household on screen. A family name or a nickname. | Personal, if a real name is entered |

### Planned

The tracker will add tables for the people in the household, their prescriptions, each
refill, and each prior-authorization request. Those tables will hold health information,
and this page will say so column by column when they land. Until then, nothing in this
section exists in the code.

### Sample data

`apps/meds/sample/seed.jsonl` holds one invented `profile` row. A Privatium node offers to
load it from its settings page only while the app's log is empty. The file must never hold
a real name, date of birth or medication record.

### Conclusion

You now know that the app stores one household name today, where that record lives on
disk, and how the tables will grow. Change `schema.sql` and this page together.

### Additional resources

- [The app folder](../apps/meds/README.md)
- [Privatium's app contract](https://github.com/gabrielmongefranco/privatium/blob/main/spec/app-contract.md), the normative definition of an app and its data.
- [Privatium's security page](https://github.com/gabrielmongefranco/privatium/blob/main/docs/security.md)
- [Privatium's backup and restore guide](https://github.com/gabrielmongefranco/privatium/blob/main/docs/backup-and-restore.md), which names the data directory on each platform.

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
