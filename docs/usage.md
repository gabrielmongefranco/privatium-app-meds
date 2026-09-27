<!--
This file is part of Prescription Tracker
docs/usage.md
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: How to use the app: refills, medication lists, fills, pasted fills, prior
         authorizations, contacts and setup.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## Using the app

[Back to project README](../README.md)

This page shows how to use every screen of the app. It is for anyone who runs the app for
a household. Start with the first three sections if the app is new to you.

All names on this page are invented.

### Find your way around

Every page has the same bar at the top, with six links:

| Link | What it holds |
|---|---|
| **Refills** | What needs a refill now. This is the home page. |
| **Medications** | What each person takes |
| **History** | Every fill, and what you paid |
| **Authorizations** | Prior authorizations and when they end |
| **Contacts** | Pharmacies and prescribers |
| **Setup** | People, the medication catalog, the reminder settings, the household name |

The bar underlines the section you are in. On pages that list records, a row of names
under the heading narrows the list to one person.

### Set up the app

Do these steps once, in this order.

1. Load the starter catalog, if you want it. Open the Privatium menu, choose
   **App settings**, find **Prescription Tracker** and choose **Load sample data**.
   Privatium offers the button only while the app holds no records.
2. Choose **Setup**, then **Household name**, and type the name of your household.
3. Choose **Setup**, then **People**, and add each person. A first name is enough. The
   birth date is optional.
4. Choose **Contacts** and add your pharmacies and prescribers. Only the name is
   required.

The starter catalog holds 41 common medications. It adds no person and no record about
anyone.

### See what needs a refill

Choose **Refills**. The page lists what needs attention, most urgent first.

| Group | Meaning |
|---|---|
| Overdue | The next fill date has passed |
| Due | The next fill date is today or up to 3 days away |
| Due soon | The next fill date is 4 to 7 days away |
| Authorizations ending | A prior authorization ends within 30 days, or has ended |
| As needed | Taken as needed. The dates are shown and raise no alert. |
| Missing information | No fill yet, or a last fill with no days supply |
| Not due yet | Everything else in use. Open the group to see it. |
| Paused | On hold or not started. The dates are shown and raise no alert. |

A specialty medication is due earlier: due at up to 5 days, due soon at 6 to 10 days.
Only a medication with the status Taking regularly raises an alert.

Each row shows two dates:

- The **next fill date** is the date of the last fill plus its days supply.
- The **recommended** date also counts the supply that earlier fills built up.

When no refill is left, the row names the prescriber to ask for a new prescription.

### Record a fill

1. On the Refills page, choose **Record fill** in the row of the medication.
2. Check the values. The form starts with the pharmacy, the days supply, the quantity,
   the prescription number and the insurance plan of the last fill.
3. Type the amount you paid. A currency sign is fine.
4. Check **Refills left after this fill**. The form starts with one fewer than before.
5. Choose **Save the fill**.

For a medication that is not on the page, choose **Record a fill** at the top and find
the medication by name. If the medication is not on the person's list, saving the fill
adds it, with the status Taking regularly.

### Paste fills from a portal

The portal of an insurer or a pharmacy lists the fills it paid for. You can copy that
list and let the app read it.

1. In the portal, open the details of each fill.
2. Select the list, from the first date to the end of the last fill, and copy it.
3. In the app, choose **Refills**, then **Paste fills from a portal**.
4. Choose the person the portal page belongs to, paste the text and choose
   **Read the text**.
5. Check each fill. Choose a medication or a pharmacy where the app asks for one.
6. Tick **Add this fill** for the fills you want, then choose **Add fills**.

| Result | Meaning |
|---|---|
| Ready | Every value was read and matched. The fill is ticked for you. |
| Choose a medication | The app does not know the portal's name yet. Pick the medication. The app remembers the name for next time. |
| Choose a pharmacy | No pharmacy matches. Pick one, or add it from the pasted details. |
| Not paid | The claim status is not Paid. Add the fill only if it took place. |
| Already recorded | The person has a fill with the same prescription number and date. It is left out. |
| Not in the catalog | No medication is close to the name. Add it to the catalog, then read the text again. |
| Details missing | The details were not open in the portal. Open them and copy again. |
| Could not read | A value is not a date or a number. The row says which. |

Adding a pasted fill lowers the refills left of its medication by one. What the plan
paid and the deductible are shown and not stored.

Pasting the same page twice adds nothing the second time.

The app reads one layout of portal page today. The
[app design](design/README.md) shows that layout.

### Keep the medication lists

Choose **Medications** to see what each person takes, grouped by status.

To add a medication to a list:

1. Choose **Add a medication**.
2. Find the medication by any of its names and choose it.
3. Choose who takes it and its status. Add the instructions, when to take it, what it is
   for, the prescriber and the pharmacy.
4. Choose **Save**.

Choose a medication in the list to open its page. The page shows how to take it, its
refills, who to call, its prior authorizations and its fills. You can change the status
there without opening the whole form.

| Status | Use it when |
|---|---|
| Taking regularly | The person takes it on a schedule. It raises refill alerts. |
| Taking as needed | The person takes it now and then |
| On hold | The person paused it |
| Not started | It is prescribed and not begun |
| No longer taking | The person stopped. The history stays. |

### Print a medication list

1. Choose **Medications** and choose one person.
2. Choose **Print list**.
3. Use the print command of your browser.

The list shows what the person takes now, how, when, what for, and who prescribed it.
The printed page leaves out the navigation and the buttons.

### Track prior authorizations

A prior authorization is an insurer's approval to cover a medication for a set period.

1. Choose **Authorizations**, then **Add an authorization**.
2. Choose the medication and the person.
3. Type the first day and the last day from the insurer's letter.
4. Choose **Save**.

The Refills page warns you 30 days before the latest authorization of a medication in
use ends. After a renewal, add the new authorization and the warning goes away.

### Look at the history

Choose **History** to see every fill, newest first. Narrow the list by person,
medication, pharmacy or year. Under the filters, the page shows the number of fills and
the total you paid. The table **Paid by year** shows the total for each person in each
year.

Choose **Change** in a row to correct a fill or to remove it.

### Find a medication by any name

Every search box for medications looks through the short name, the brand name, the
generic name and the other names. Capital letters and punctuation do not matter.

| You type | The app shows |
|---|---|
| A name or the start of one, such as "apap" or "atorva" | The medications that answer to it |
| A name with a typing mistake, such as "Lipitro" | The closest names, under **Did you mean one of these?** |

A close name is only a suggestion. Different medications can have names that look alike,
so read the name before you choose.

### Teach the app another name

A label, a statement and a person may each use a different name for one medication. Teach
the app a name once, and the search finds the medication by it from then on.

1. Choose **Setup**, then **Medication catalog**, and search for the name as it is
   written.
2. Under **Teach the app this name**, choose the medication that the name belongs to.

You can also open a medication in the catalog and type the name under
**Add another name**.

### Add a medication to the catalog

The catalog lists products. It does not say who takes them.

1. Choose **Setup**, then **Medication catalog**.
2. Use the search box to check that the medication is not there yet.
3. Choose **Add a medication**.
4. Type the brand name, the generic name, or both.
5. Type the strength as the label prints it, with the unit. Examples are "10 mg",
   "100 units/mL", and "875-125 mg" for a product with two drugs.
6. For the route, the form and the package type, pick from the list or type a new choice
   in the box under it. A choice that you type appears in the list from then on.
7. Tick **This is a specialty medication** if it is one.
8. Leave the short name empty. The app builds it, such as "Examplol (Exampline) 10 mg".
   Type a short name only if you want a different one.
9. Choose **Save**.

### Merge two entries for one product

If the catalog holds one product twice, under two names, merge the two entries.

1. Open the entry that should go away.
2. Choose **Merge into another medication**.
3. Find the entry that stays and choose **Keep this one**.
4. Read what will happen, then choose **Merge**.

The fills, the list entries and the prior authorizations move to the entry that stays.
The names of the entry that goes away become other names of the entry that stays. A merge
cannot be undone in the app, so merge only entries with the same strength.

### Change the reminder settings

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

### Remove a record

Every **Remove** button opens a page that asks first. Choose **Remove** to go on, or
**Keep it** to go back.

Removing hides the record in the app. Privatium keeps the original line in its log, so
the record stays on the disk.

The app does not remove a person, a medication, a pharmacy or a prescriber that other
records still use. The page says what uses the record.

### When a form comes back

If something in a form is not right, the form comes back with a list of problems at the
top. Each entry in the list links to its field. Everything you typed is still there.

### Times and dates

The greeting and every date the app compares with today use the clock of the computer
that runs Privatium. If you open the app from another time zone, you see that computer's
time of day.

### Conclusion

You can now set up a household, keep its medication lists, record fills by hand or from
a portal, and see what needs a refill.

### Additional resources

- [App design](design/README.md), with the rules behind the refill dates.
- [Data model](data-model.md), what the app stores.
- [The app folder](../apps/meds/README.md)
- [Privatium](https://github.com/gabrielmongefranco/privatium), the framework this app runs on.

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
