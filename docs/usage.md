<!--
This file is part of Prescription Tracker
docs/usage.md
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: How to use the app: refills, medication lists, fills, pasted fills, prior
         authorizations, contacts and setup, and how to add a missing record from
         inside a form.
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
| **Setup** | People, the medication catalog, the reminder settings |

The bar underlines the section you are in. On pages that list records, a row of names
under the heading narrows the list to one person.

### Set up the app

1. Load the starter catalog, if you want it. Open the Privatium menu, choose
   **App settings**, find **Prescription Tracker** and choose **Load sample data**.
   Privatium offers the button only while the app holds no records.
2. Choose **Setup**, then **People**, and add the first person. A first name is enough.
   The birth date is optional.

The starter catalog holds about 2,278 medications: the 200 drugs most prescribed in the
United States at every strength, and common supplies such as glucose monitor sensors. It
adds no person and no record about anyone.

A product that comes by the carton has one catalog entry for each size of carton, such
as "2 Pack" and "6 Pack". Pick the one on your box, so a fill counts the right carton.

You do not have to add everyone and everything first. Every form lets you add what it
needs. The next section shows how.

### Add what is missing without leaving a form

A form often needs a record that is not in the app yet, such as a new pharmacy. You add
it in the same form.

**A person, a pharmacy or a prescriber.** Open the drop-down and choose
**-- Add new --**. A box for the name appears. Type the name. Saving the form adds the
pharmacy too. You can fill in its phone number and address later, under **Contacts**.

The route, the form and the other choices of a form work the same way.

If your browser runs no scripts, the box is always there, under the drop-down.

If you type a name that is already in the app, the app uses that record. It never adds
a name twice.

**A medication.** The medication box has three parts. Use one of them.

| Part | Use it when |
|---|---|
| **Choose one that is already in use** | Someone in the household takes it, or has filled it. Choose **-- Find another or add new --** to see the two other parts. |
| **Type a name to search the catalog** | It is in the catalog. Type a few letters of any of its names, then pick it from the suggestions. |
| **Add a new medication** | It is not in the catalog. Look it up, or type the brand name, the generic name, or both, and the strength. For a product that comes by the carton, type the package too, such as 2 and Pack. |

The catalog is the list of products the app knows. It says nothing about who takes them.

When the name you typed fits several medications, the form comes back and asks which one
you mean. When the name is close to one the app knows, the form offers that medication,
and you decide.

**Look up a medication.** Inside **Add a new medication**, type a name under
**Look it up in a drug reference** and choose **Look up**. The app looks in its own
catalog first. It asks the public drug references of the United States government only
when the catalog holds nothing under the name, or when you choose
**None of these. Search the drug references.** Pick a result, and the app fills in the
brand name, the generic name and the strength. Check them, then save the form.

The lookup needs a connection to the internet. It sends the name you typed and nothing
else. Without a connection, fill in the fields yourself.

**Text that repeats.** Some text boxes suggest what you typed before: the insurance plan,
the clinic, the instructions, what a medication is for, and the names and strengths in
the catalog. Pick a suggestion, or type something new.

### See what needs a refill

Choose **Refills**. The page lists what needs attention, most urgent first.

| Group | Meaning |
|---|---|
| Overdue | The next fill date has passed |
| Due | The next fill date is today or up to 3 days away |
| Due soon | The next fill date is 4 to 7 days away |
| New prescriptions to ask for | No refill is left, and the next fill is overdue, due or due soon |
| Prior authorizations | A prior authorization has expired, is due or is due soon |
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

**New prescriptions to ask for** lists every medication with no refill left whose next
fill is near. It covers the medications taken regularly and the ones taken as needed.
Some prescribers take a request for refills from the patient only, never from the
pharmacy, so the page reminds you to ask.

**Prior authorizations** shows three levels:

| Level | Meaning | What to do |
|---|---|---|
| Expired | The expiration date has passed | Ask for a new authorization before the next fill |
| Due | It expires within 14 days | Ask for a new authorization now |
| Due soon | It expires within 30 days | Plan to ask |

### Record a fill

1. On the Refills page, choose **Record fill** in the row of the medication.
2. Check the values. The form starts with the pharmacy, the days supply, the quantity,
   the prescription number and the insurance plan of the last fill.
3. Type the amount you paid. A currency sign is fine.
4. Check **Refills left after this fill**. The form starts with one fewer than before.
   If you leave it empty, the app lowers the count by one.
5. Choose **Save the fill**.

For a medication that is not on the page, choose **Record a fill** at the top. The form
then starts with the medication box. If the medication is not on the person's list,
saving the fill adds it, with the status Taking regularly.

### Paste fills from a portal

The portal of an insurer or a pharmacy lists the fills it paid for. You can copy that
list and let the app read it.

1. In the portal, open the details of each fill.
2. Select the list, from the first date to the end of the last fill, and copy it.
3. In the app, choose **Refills**, then **Paste fills from a portal**.
4. Choose the person the portal page belongs to, paste the text and choose
   **Read the text**.
5. Check the review page. It has three parts, described below.
6. Choose **Add fills**.

The review page asks about each medication name and each pharmacy once, however many
fills use it.

**Medications.** Each name the portal wrote is listed with what the app made of it.

| The page says | Meaning | What you do |
|---|---|---|
| Known name | The app has seen this name before | Nothing |
| Matched | One medication has the same name and the same strength. It is chosen for you. | Check it |
| Choose a medication | Some medications are close. The best match comes first. | Pick one |
| New name | The catalog holds nothing like it. The app filled in a new medication from the name. | Check the brand name, the generic name and the strength |

For every name you can also pick **Another medication** and type its name, or pick
**A new medication**. The app remembers the portal's name as another name of the
medication you choose. The next paste knows it.

**Pharmacies.** A pharmacy that the app knows is matched by its identifier or its name.
For a new one, the app offers to add it with the address and phone number that were
pasted. You can pick one of your pharmacies instead.

**Fills.** Each fill has a result and a box labeled **Add this fill**.

| Result | Meaning |
|---|---|
| Ready | Every value was read. The fill is ticked for you. |
| Not paid | The claim status is not Paid. Tick the fill only if it took place. |
| Already recorded | The person has a fill with the same prescription number and date. It is left out. |
| Details missing | The details were not open in the portal. Open them and copy again. |
| Could not read | A value is not a date or a number. The row says which. |

If a choice is still open when you choose **Add fills**, the page comes back and marks
it. Nothing is added until every fill you ticked has a medication and a pharmacy.

The app also looks at the prescription number. When an earlier fill of the person has
the same number, the app knows its medication. If the portal's name fits that medication
too, it is chosen for you. If the name does not fit, the medication comes first in the
list and you decide. Hyphens and spaces in a number do not matter.

Adding a pasted fill lowers the refills left of its medication by one. What the plan
paid and the deductible are shown and not stored.

Pasting the same page twice adds nothing the second time.

The app reads one layout of portal page today. The
[app design](design/README.md) shows that layout.

### Keep the medication lists

Choose **Medications** to see what each person takes, grouped by status.

To add a medication to a list:

1. Choose **Add a medication**.
2. In the medication box, pick the medication, type its name, or add a new one.
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
2. Choose the person.
3. Choose the medication.
4. Check the first day. The form starts with the first day of this month. Clear the
   field if you do not know the first day.
5. Check the expiration date. The form starts with one year after the first day of this
   month. The insurer's letter shows the date.
6. Choose **Save**.

If the medication is not on the person's list, saving adds it, with the status Not
started. The Refills page can then warn you when the authorization ends.

The Refills page shows the latest authorization of a medication in use from 30 days
before it expires. From 14 days before, it is due. After a renewal, add the new
authorization and the reminder goes away.

### Look at the history

Choose **History** to see every fill, newest first. The quantity and the days supply
have a column each. A quantity shows decimals only when it has them, such as 2.5. Narrow the list by person,
medication, pharmacy or year. Under the filters, the page shows the number of fills and
the total you paid. The table **Paid by year** shows the total for each person in each
year.

Choose **Change** in a row to correct a fill or to remove it.

### Find a medication by any name

Every medication box and the search box of the catalog look through the short name,
the brand name, the generic name and the other names. Capital letters and punctuation do
not matter.

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

The quickest way is inside any form, as **Add what is missing without leaving a form**
shows. The catalog page has the full form, with every field.

1. Choose **Setup**, then **Medication catalog**.
2. Use the search box to check that the medication is not there yet.
3. Choose **Add a medication**.
4. Type the brand name, the generic name, or both.
5. Type the strength as the label prints it, with the unit. Examples are "10 mg",
   "100 units/mL", and "875-125 mg" for a product with two drugs.
6. For the route, the form and the package type, pick from the list or type a new choice
   in the box under it. A choice that you type appears in the list from then on.
7. Tick **This is a specialty medication** if it is one.
8. Leave the short name empty. The app builds it, such as "Examplol (Exampline) 10 mg",
   or "Examplol (Exampline) 10 mg 2 Pack" when you gave a package.
   Type a short name only if you want a different one.
9. Choose **Save**.

Under **Reference codes** you can type the RxNorm identifier of the product. RxNorm is
the drug list of the United States National Library of Medicine. The field is optional,
and the app works the same without it.

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
| Due, for a prior authorization | 14 days |
| Due soon, for a prior authorization | 30 days |

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

You can now keep the medication lists of a household, add what is missing from inside
any form, record fills by hand or from a portal, and see what needs a refill.

### Additional resources

- [App design](design/README.md), with the rules behind the refill dates.
- [Data model](data-model.md), what the app stores.
- [The app folder](../apps/meds/README.md)
- [Privatium](https://github.com/gabrielmongefranco/privatium), the framework this app runs on.

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
