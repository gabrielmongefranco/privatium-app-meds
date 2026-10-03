<!--
This file is part of Prescription Tracker
docs/design/import.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-10-03
Summary: The owner's one-time import of the legacy SQLite database:
         table mapping, the review of medication names, cleaning rules, new ids, safety
         rules and checks.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## Import of the legacy database

[Back to project README](../../README.md)

This page describes how the records of the owner's legacy SQLite database reach the
planned app. The import runs once, for one household. The page covers what moves where,
how medication names are reviewed, what gets cleaned, and how to check the result.

The import script exists and was tried on a scratch node. It is not part of this
repository, because it serves one household and works on health information.

### Why the app cannot open the legacy file

Privatium keeps every record as one line of text in an append-only log. Its SQLite file
is a cache that it rebuilds from that log. Syncing and backups work on the log.

The legacy file has tables and no log. Privatium has nothing to sync or to rebuild from
it. So the import reads each legacy row once and writes it to the app as one event.

### What you keep

- **The legacy file.** The import opens it read-only and never changes it. Keep it as an
  archive.
- **The two dates.** The app calculates refill eligibility and physical supply exhaustion from
  recorded fills and payer rules. The [data model](../data-model.md) lists them.
- **Read access with SQL.** The cache at `cache/meds.sqlite` in the data directory is an
  ordinary SQLite file. In a test, the `sqlite3` command-line shell read every table and
  view from it. Python's SQLite library, which lacks SQLite's decimal
  extension, read every table and every view except the spending view. It could not sort
  or filter by an amount.

Open the cache read-only. Privatium rebuilds it from the log, so a change made in it is
lost.

### How the import works

The import is one Python script that uses the standard library only. It is written for
one legacy database, so it lives in a private folder next to that file. It is not part of
this repository.

The script has three commands.

1. **Review** reads the legacy file and writes a review file of the medications. It
   sends nothing to the app.
2. **Load** reads the legacy file and the review file, and sends the events to your node.
3. **Verify** compares what the app now holds with the legacy file.

Load uses Privatium's data API, the same write path that the app's forms use. So every
event passes the same type checks and the same constraints as a form entry.

### The review file

The legacy catalog can hold the same product under several names. The review file is
where you settle the names before anything is loaded. It is a file named `review.csv`
that a spreadsheet program opens, with one row per legacy medication.

| Column | Filled in by the script | What you do |
|---|---|---|
| Legacy name | The name in the legacy catalog | Nothing |
| Short name | The brand name, the generic name in brackets, then the strength | Change it only if you want another name in the catalog |
| Specialty | yes when the legacy column `IsSpecialty` says so, or the earlier review file did | Change it as needed |
| Controlled | yes when the legacy column `IsControlled` says so, when the earlier review file did, or when the name holds a common controlled ingredient | Change it as needed |
| Same product as | The legacy name of another row, when both share a name, a strength and a form. For an entry of the starter catalog, the word `catalog:` and its short name. | Keep it, clear it, or write another legacy name |
| Track with | Empty | Write the legacy name of another medication of the same drug when both belong on one tracked medication, such as a carton of 2 and a carton of 6. Each stays a product of its own. |
| Looks like | Rows whose names are close but not equal | Read it. Fill in **Same product as** only when you are sure. |

The script fills in **Same product as** only for rows that share a generic or brand name
and have the same strength and form. It never fills it in from names that merely look
alike, because different drugs can have similar names.

Load applies the file this way:

- A row with **Same product as** becomes another name of that medication. Its fills, its
  tracked medications and its prior authorizations move to that medication.
- Every legacy name that differs from the short name, the generic name and the brand
  name becomes another name.
- A row with **Track with** keeps its own catalog product, and a person who tracks both
  rows gets one tracked medication with both products. The fills keep the product that
  was dispensed.
- When a person has a tracking row under both rows, load keeps the one in use and gives
  it both products. When both are in use, load stops and names the two legacy tracking
  numbers.

### Table mapping

| Legacy table | New table | Legacy key that the new id comes from |
|---|---|---|
| `Patients` | `person` | `PatientName` |
| `Medications` | `medication` and `medication_alias` | `MedicationName` |
| `Pharmacies` | `pharmacy` | `PharmacyName` |
| `Prescribers` | `prescriber` | `PrescriberName` |
| `MedicationTracking` | `person_medication` and `person_medication_product` | `MedicationTrackingID` |
| Distinct `PrescriptionFills.InsurancePlan` values | `plan` | Trimmed name, ignoring case |
| `PrescriptionFills` | `fill` | `PrescriptionFillID` |
| `PriorAuthorizations` | `prior_authorization` | `PriorAuthorizationID` |
| `MedicationStatuses` | None. The five values are fixed in the schema. | Not applicable |
| Six other lookup tables | None. The values arrive inside the records that use them. | Not applicable |

The legacy tables point to each other by name. The new tables point by id. The script
looks up each name and writes the matching id.

The view `ActiveMedicationsView` and the generated column `MedicationLongName` are not
imported. The app works both out again.

The import also adds tracked medications. For every person and product that have a fill
and no tracking row, it adds one with the status No longer taking and no refills left,
named after the legacy medication.

### Column mapping

A legacy column that is not listed keeps its meaning under the new name in the
[data model](../data-model.md). These are the ones that change.

| Legacy column | New column | Change |
|---|---|---|
| `Medications.MedicationName` | `medication_alias.alias` | Becomes another name, when it differs from the generic and brand names |
| `Medications.Strength` and `StrengthUnits` | `medication.strength` | Joined by a space |
| `Medications.MedicationLongName` | None | The view `v_medication` builds the full name |
| None | `medication.short_name` | Built from the brand name, the generic name and the strength |
| `Medications.IsSpecialty` | `medication.is_specialty` | Through the review file, where you can change it |
| `Medications.IsControlled` | `medication.is_controlled` | Through the review file, where you can change it; a common controlled ingredient is suggested too |
| `MedicationTracking.Medication` | `person_medication.display_name` and `person_medication_product.medication_id` | The legacy name becomes the preferred name; the catalog product becomes a product of the tracked medication |
| `PrescriptionFills.InsurancePlan` | `fill.plan_id` | A normalized name becomes a plan id |
| Latest non-cash fill's plan | `person.plan_id` | Starts new fills; the owner can change it |
| `MedicationTracking.MedicationType` | `person_medication.medication_type` | Spelling corrected |
| `MedicationTracking.MedicationStatus` | `person_medication.status` | One of five fixed values |
| `MedicationTracking.ConditionsPrescribedFor` | `person_medication.prescribed_for` | Renamed |
| `MedicationTracking.MedicationDailyTime` | `person_medication.when_to_take` | Renamed |
| `MedicationTracking.CurrentPharmacy` and `CurrentPrescriber` | `pharmacy_id` and `prescriber_id` | A name becomes an id |
| `PrescriptionFills.DateFilled` | `fill.filled_on` | Renamed |
| `PrescriptionFills.Patient` and `Medication` | `fill.person_medication_id` and `fill.medication_id` | The person and the product name the tracked medication; the product stays on the fill |
| `PrescriptionFills.Pharmacy` | `pharmacy_id` | A name becomes an id |
| `PriorAuthorizations.PatientName` and `Medication` | `prior_authorization.person_medication_id` | The person and the product name the tracked medication. With no patient name, the one person who has the medication is used. |

### Cleaning rules

The legacy columns accept any text, so some values need cleaning. The examples are
invented.

| Legacy value | Becomes | Reason |
|---|---|---|
| Empty text, in any column | No value | An empty field holds nothing |
| An amount such as `$12.50` | `12.50` | The new column holds a number |
| An amount such as `12.5` | `12.50` | Money has two decimal places |
| A number stored as text, such as `'30'` | `30` | The new column is typed |
| A phone number stored as a number | The same digits as text | A phone number is not a quantity |
| A strength `10` with the unit `mg` | `10 mg` | The strength is one text field |
| A status such as `Taking Regularly` | `taking_regularly` | The schema fixes the five status values |
| `Other-the-Counter`, in three medication types | `Over-the-Counter` | Spelling |
| `Alternative Meidince - Long Term` | `Alternative Medicine - Long Term` | Spelling |
| The form `Absorbible Pad` | `Absorbable Pad` | Spelling |

A legacy prior authorization names its person in `PatientName`. When that column is
empty, the script looks for the people who have a fill or a tracking row for that
medication. With exactly one such person, it writes that person. With none or several,
the row is a reject, because the new table requires a tracked medication.

A row that fails a check is a reject. The script writes rejects to their own file in the
private folder, with the legacy key and the reason. It never drops a row silently.

### New ids

Every new record needs a ULID, a 26-character identifier that sorts by time. The script
works each id out from the legacy key, so the same legacy row gets the same id on every
run.

- The first 10 characters hold a time. A fill uses midnight UTC on its fill date, plus
  its legacy fill number in milliseconds. Every other record uses one fixed instant.
- The last 16 characters come from a keyed hash of the table name and the legacy key.
  The hash is HMAC-SHA-256 from Python's standard library.
- The key is 32 random bytes. The script makes it once from the operating system's
  random source and keeps it in the private folder.

The time part keeps the legacy order of two fills on one day, which decides the last
fill. The keyed hash means that nobody can work out a name from an id without the key.

### Safety rules

- The script opens the legacy file read-only.
- The script sends data to the node's own address only, such as `127.0.0.1`. It refuses
  any other address, because the records would cross the network.
- The script refuses to write inside a Git working tree. Real records stay out of this
  repository.
- The private folder and its files are readable by their owner only.
- The script prints counts and table names. It never prints a field value.
- Load refuses an app that already holds records. Two kinds of record are allowed: the
  ones from an earlier run of the same import, and the starter catalog of the sample
  data.
- Load never writes over a record that changed in the app. Privatium refuses the batch
  and names the record.

Running load a second time adds nothing. If a load stops part way, run it again to
finish it.

### Checks after loading

Verify compares three things and reports each as a match or a difference.

| Check | Legacy side | App side |
|---|---|---|
| Row counts | One count per legacy table, less the merged medications, plus the added tracked medications and the product links | The view `v_row_count` |
| Total amount paid | The sum over `PrescriptionFills`, after cleaning | The view `v_spending_by_year` |
| The two dates | Fill history simulated with current rules | Eligibility and exhaustion from `v_supply` |

Verify checks the new dates against a daily simulation. It reports legacy date differences
as expected rather than failed checks. Merged medication histories count together.

### Steps for the owner

The paths are examples. Give `--app-url` to the review command too, and the review file
also suggests entries of the starter catalog.

1. Stop changing the legacy database. Copy the file to a backup.
2. Install the app and start the node. The app must be empty, or hold the sample data
   only.
3. Write the review file:

   ```sh
   python3 /path/to/import_legacy.py review --source /path/to/legacy.db --app-url http://127.0.0.1:8420/a/meds
   ```

4. Open `review.csv` in the private folder. Set the short names, check the specialty
   and controlled marks, settle the rows that are the same product, and fill in
   **Track with** for the carton sizes that belong together. The private folder is
   named `meds-import` and sits beside the legacy file, unless you name another with
   `--folder`.
5. Load the records into the node:

   ```sh
   python3 /path/to/import_legacy.py load --source /path/to/legacy.db --app-url http://127.0.0.1:8420/a/meds
   ```

6. Verify the result:

   ```sh
   python3 /path/to/import_legacy.py verify --source /path/to/legacy.db --app-url http://127.0.0.1:8420/a/meds
   ```

7. Open **Setup**, **Insurance plans** and set the percent and frame of each plan.
   Check each person's current plan, then look at the Refills and Medications pages.
8. Keep the legacy file and the private folder somewhere safe. Both hold health
   information.

### Reload after a schema change

Keep the source database and migration folder outside the Git checkout. Back up the
node's data directory before replacing existing app data. Stop the node, move its data
directory aside, and restart with an empty directory. Load the starter catalog from Setup.

Run `review --again` with the existing private review folder and the new app address.
It keeps settled choices and adds the columns the file lacks, such as **Track with**.
Fill in **Track with** for the carton sizes that belong together. Run `load`, `verify`,
then `load` again to check that nothing is appended. Check plan settings and person
defaults. Fills entered after the source database was archived need to be recorded
again; pasting the recent portal history is the quickest way.

### What was checked

On 2026-09-27 the script ran against the owner's database and a scratch node that held
the sample data. The scratch node and its folder were removed afterward.

| Check | Result |
|---|---|
| An app address on another computer | Refused |
| A private folder inside a Git working tree | Refused |
| Load with no review file | Refused |
| Review | One row for each legacy medication, in a folder that only its owner can read |
| Load | Every table accepted, with no reject |
| Load a second time | Nothing appended |
| Verify: row counts, total amount paid | Match |
| Legacy dates on September 27, 2026 | Matched the earlier app rules before eligibility and exhaustion were separated |
| Every section of the app with the imported records | Opened |

The review file of that run kept the suggestions of the script and was not settled by
the owner. The owner's own run may merge other rows.

### Refill-rule rehearsal, October 1, 2026

An isolated node loaded a copy of the source records. Existing review choices stayed,
and the controlled column was added. Row counts and total paid matched, and 187 date
pairs matched an independent daily simulation. A repeated load appended zero records.
The source database and the owner's review file were unchanged.

### Tracked medication rehearsal, October 3, 2026

An isolated node loaded a copy of the source records into the model with tracked
medications and products. `review --again` kept every settled choice and added the
`track_with` column. Every row count matched, the new table included; the total paid
matched; 185 date pairs matched the daily simulation; no row was rejected; a repeated
load appended zero records; and every section of the app opened with the records. The
source database and the owner's review file were unchanged, and the copy was removed.

### Conclusion

You now know how the legacy records will reach the app, how the medication names get
settled, and how to check the result. The decisions behind this plan are listed in the
[app design](README.md).

### Additional resources

- [App design](README.md)
- [Data model](../data-model.md)
- [The schema, as SQL](../../apps/meds/schema.sql)
- [Privatium's data API](https://github.com/gabrielmongefranco/privatium/blob/main/spec/data-api.md), the write path the import uses.
- [Privatium's backup and restore guide](https://github.com/gabrielmongefranco/privatium/blob/main/docs/backup-and-restore.md), which names the data directory on each platform.

[Back to project README](../../README.md)

----

Copyright © 2026 Gabriel Mongefranco
