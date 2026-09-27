<!--
This file is part of Prescription Tracker
docs/usage.md
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: How to use the screens the app has today: the home page, Contacts and Setup.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## Using the app

[Back to project README](../README.md)

This page shows how to use the screens that the app has today. It is for anyone who runs
the app for a household. The screens for medication lists, fills and refills are not
built yet. The [app design](design/README.md) describes them.

All names on this page are invented.

### Find your way around

Every page has the same bar at the top, with three links:

- **Home** greets your household.
- **Contacts** holds your pharmacies and prescribers.
- **Setup** holds the things you set up once: people, the medication catalog, the
  reminder settings and the household name.

The bar underlines the section you are in.

### Load the starter catalog

The app comes with a starter catalog of 41 common medications. Loading it saves you from
typing them. It adds no person and no record about anyone.

1. Open the Privatium menu and choose **App settings**.
2. Find **Prescription Tracker** and choose **Load sample data**.

Privatium offers the button only while the app holds no records. Load the catalog first
if you want it.

The sample data also names the household "The Example Family". Change it under
**Setup**, then **Household name**.

### Add a person

1. Choose **Setup**, then **People**.
2. Choose **Add a person**.
3. Type the name. A first name is enough.
4. Add the birth date if you want it. It is optional.
5. Choose **Save**.

The app refuses a name that is already in use. It treats "Alex Example" and
"alex example" as the same name.

### Add a pharmacy or a prescriber

1. Choose **Contacts**.
2. Choose **Add a pharmacy** or **Add a prescriber**.
3. Type the name. Every other field is optional.
4. Choose **Save**.

| Field | What to type |
|---|---|
| Phone, Mobile phone, Fax | The number as you would write it, such as (555) 555-0100 |
| Website | The full address, starting with `https://` |
| National Provider Identifier | Ten digits. Insurance statements often call it the pharmacy ID. |

On the Contacts page, a phone number is a link. On a phone, choosing it starts a call.

### Add a medication to the catalog

The catalog lists products. It does not say who takes them.

1. Choose **Setup**, then **Medication catalog**.
2. Use the search box to check that the medication is not there yet. The search looks
   through every name of a medication, so "apap" finds the entries for acetaminophen.
3. Choose **Add a medication**.
4. Type the brand name, the generic name, or both.
5. Type the strength as the label prints it, with the unit. Examples are "10 mg",
   "100 units/mL", and "875-125 mg" for a product with two drugs.
6. For the route, the form and the package type, pick from the list or type a new choice
   in the box under it. A choice that you type appears in the list from then on.
7. Tick **This is a specialty medication** if it is one. A specialty medication takes
   longer to arrive, so the app will call its refill due earlier.
8. Leave the short name empty. The app builds it, such as "Examplol (Exampline) 10 mg".
   Type a short name only if you want a different one.
9. Choose **Save**.

### Change the reminder settings

The reminder settings are five counts of days. They decide how early a refill counts as
due. The refill screens that use them are not built yet.

1. Choose **Setup**, then **Reminder settings**.
2. Type a number from 0 to 365, or leave a field empty to use the number the app starts
   with.
3. Choose **Save**.

| Setting | The app starts with |
|---|---|
| Due | 3 days |
| Due soon | 7 days |
| Due, for a specialty medication | 5 days |
| Due soon, for a specialty medication | 10 days |
| Notice before a prior authorization ends | 30 days |

A prior authorization is an insurer's approval to cover a medication for a set period.

### Remove a record

Every **Remove** button opens a page that asks first. Choose **Remove** to go on, or
**Keep it** to go back.

Removing hides the record in the app. Privatium keeps the original line in its log, so
the record stays on the disk.

The app does not remove a record that other records still use. For example, it keeps a
pharmacy that a fill names. The page says what uses the record.

### When a form comes back

If something in a form is not right, the form comes back with a list of problems at the
top. Each entry in the list links to its field. Everything you typed is still there.

### Times and dates

The greeting and every date the app compares with today use the clock of the computer
that runs Privatium. If you open the app from another time zone, you see that computer's
time of day.

### Conclusion

You can now set up the people, the contacts and the catalog of your household. The next
screens will use them to track what each person takes.

### Additional resources

- [App design](design/README.md), the planned screens.
- [Data model](data-model.md), what the app stores.
- [The app folder](../apps/meds/README.md)
- [Privatium](https://github.com/gabrielmongefranco/privatium), the framework this app runs on.

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
