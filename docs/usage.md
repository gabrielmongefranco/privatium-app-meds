<!--
This file is part of Prescription Tracker
docs/usage.md
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-03
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
| **Medications** | What each person tracks: their medications, with the catalog products behind each |
| **Refills** | What needs a refill now. This is the home page. |
| **History** | Every fill, and what you paid |
| **Authorizations** | Prior authorizations and when they end |
| **Contacts** | Prescribers and pharmacies |
| **Setup** | Insurance plans, the family, the medication catalog, the reminder settings |

The bar underlines the section you are in. On pages that list records, a row of names
under the heading narrows the list to one person. The app remembers the person you chose
last, in your browser, and opens the next page on that person until you choose another
or **Everyone**. The memory holds the person's id only, and clearing the site data of
the browser forgets it. When Privatium offers person profiles, this memory goes away
and the profile takes over; [the issue that tracks it](https://github.com/gabrielmongefranco/privatium-app-meds/issues/10) is in the
repository.

Every medication name carries a small icon for its dose form: a tablet, a capsule, a
drop, an inhaler, a syringe and so on. A screen reader hears the form instead. A tracked
medication shows the icon of its first product.

### Set up the app

1. Load the starter catalog, if you want it. Open the Privatium menu, choose
   **App settings**, find **Prescription Tracker** and choose **Load sample data**.
   Privatium offers the button only while the app holds no records.
2. Choose **Setup**, then **Family**, and add the first person. A first name is enough.
   The birth date is optional.

The starter catalog holds about 2,507 medications: the 200 drugs most prescribed in the
United States at every strength, and common supplies such as glucose monitor sensors, syringes and needles. It
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

**A product of the catalog.** The medication box finds a product of the catalog, or adds
one. It has two parts. Use one of them.

| Part | Use it when |
|---|---|
| **Type a name to search the catalog** | It is in the catalog. Type a few letters of any of its names, then pick it from the suggestions. |
| **Add a new medication** | It is not in the catalog. Look it up, or type the brand name, the generic name, or both, and the strength. For a product that comes by the carton, type the package too, such as 2 and Pack. Tick **controlled** or **specialty** when the label says so. |

The catalog is the list of products the app knows. It says nothing about who takes them.
A fill or a prior authorization form offers the medications a person tracks in a
drop-down first, and shows the box when you choose **-- Find another or add new --**. A
product that is on no list of the person is then added to the list with the fill, named
after the product.

When the name you typed fits several medications, the form comes back and asks which one
you mean. When the name is close to one the app knows, the form offers that medication,
and you decide.

**Look up a medication.** Inside **Add a new medication**, type a name under
**Look it up in a drug reference** and choose **Look up**. The app looks in its own
catalog first. It asks the public drug references of the United States government only
when the catalog holds nothing under the name, or when you choose
**None of these. Search the drug references.** Pick a result, and the app fills in the
brand name, the generic name and the strength. Check them, then save the form.

The lookup needs a connection to the internet. It sends public drug names and product identifiers, with no household records. Without a connection, fill in the fields yourself.

**Text that repeats.** Some text boxes suggest previous values: the clinic, instructions,
what a medication is for, and catalog names and strengths. Pick a suggestion, or type something new.

### See what needs a refill

Choose **Refills**. The page lists what needs attention, most urgent first.

| Group | Meaning |
|---|---|
| Overdue | Recorded physical supply has run out |
| Due | Eligibility has passed, is today, or is up to 3 days away |
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

- The **next fill date** estimates when the payer will allow another fill.
- **Lasts until** shows when all recorded supply runs out, whoever paid.

Early fills add supply, while gaps do not. After eligibility passes, the row reads
"Fill now. Runs out in N days" until supply runs out. Only then does it become overdue.
The [data model](data-model.md#how-the-dates-are-worked-out) explains the calculation.

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
   the prescription number of the last fill. The plan starts with the person's current
   plan, then the last fill's plan, then no plan.
3. When the medication comes in more than one package, choose the **Product** that
   was dispensed. The form starts with the product of the last fill.
4. Type the amount you paid. A currency sign is fine.
5. Check **Refills left after this fill**. The form starts with one fewer than before.
   If you leave it empty, the app lowers the count by one.
6. Choose **Save the fill**.

For a medication that is not on the page, choose **Record a fill** at the top. The form
then offers every tracked medication in a drop-down, by person. Choose
**-- Find another or add new --** for a product that nobody tracks yet: pick the person
and find the product, and saving the fill adds the medication to the person's list,
with the status Taking regularly.

### Copy refill history from a patient portal

The portal of an insurer or a pharmacy lists the fills it paid for. You can copy that
list and let the app read it. Medications are matched to your medication list and fills
you have already are skipped, and you check everything before anything is added.

1. In the portal, open the details of each fill.
2. Select the list, from the first date to the end of the last fill, and copy it.
3. In the app, choose **Refills**, then **Copy refill history from patient portal**.
4. Under **This refill history belongs to:**, choose the person, paste the text and
   choose **Read the text**.
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
| Already recorded | The person has a fill with the same prescription number and date, or the tracked medication has a fill on the same date. It is left out. |
| Details missing | The details were not open in the portal. Open them and copy again. |
| Could not read | A value is not a date or a number. The row says which. |

If a choice is still open when you choose **Add fills**, the page comes back and marks
it. Nothing is added until every fill you ticked has a medication and a pharmacy.

The app also looks at the prescription number. When an earlier fill of the person has
the same number, the app knows its medication. If the portal's name fits that medication
too, it is chosen for you. If the name does not fit, the medication comes first in the
list and you decide. Hyphens and spaces in a number do not matter.

Each added fill uses the person's current plan. The review names it, or says there is
no plan. Set the person's plan under **Setup**, **Family** before pasting.

Adding a pasted fill lowers the refills left of its medication by one. A product that is
on no list of the person is added to the list, named after the product. What the plan
paid and the deductible are shown and not stored.

Pasting the same page twice adds nothing the second time. A fill that you typed by hand
without a prescription number is found by its medication and its date.

The app reads one layout of portal page today. The
[app design](design/README.md) shows that layout.

### Keep the medication lists

Choose **Medications** to see what each person tracks, grouped by status.

A tracked medication is yours: it has the name you prefer, and it stands for one or more
products of the catalog. Most medications stand for one product. A medication that comes
in two carton sizes stands for two, and every fill of either counts under the one
medication. One product can be on one tracked medication of a person only, so the app
refuses to put it on a second one and names the first.

To track a medication:

1. Choose **Track a new medication**.
2. Choose who takes it.
3. Under **Catalog products**, type the name of the product and choose
   **Add to this entry**, or open **Add a new medication** for a product the catalog
   lacks. Repeat for a second carton size. Each product shows with a **Remove** button.
   Pressing Enter in the name box adds the product too.
4. Check the **Preferred name**. It starts as the full name of the first product. Type
   the name you use, such as the brand name alone. Two of your medications cannot share
   a name; another person's can.
5. Choose the status. Add the instructions, when to take it, what it is for, the refills
   left, the prescriber and the pharmacy.
6. Choose **Save**.

To find a medication in the list, type into the search box at the right of the buttons.
The list narrows as you type, by the preferred name, every name of the products, the
prescriber and the person. A match under **No longer taking** opens that section. Without
scripts, press Enter and the page does the same.

Choose a medication in the list to open its page. The page shows how to take it, its
refills, who to call, its prior authorizations, its fills and its products. You can change
the status there without opening the whole form, and **Change** lets you rename it and
add or remove products. A product with fills stays, and so does the last product.

Under **No longer taking**, each row has a **Restart** button that sets the status back
to Taking regularly.

| Status | Use it when |
|---|---|
| Taking regularly | The person takes it on a schedule. It raises refill alerts. |
| Taking as needed | The person takes it now and then |
| On hold | The person paused it |
| Not started | It is prescribed and not begun |
| No longer taking | The person stopped. The history stays, and **Restart** brings it back. |

### Print a medication list

1. Choose **Medications** and choose one person.
2. Choose **Print list**.
3. Use the print command of your browser.

The list shows what the person takes now, how, when, what for, and who prescribed it.
The printed page leaves out the navigation and the buttons.

### Track prior authorizations

A prior authorization is an insurer's approval to cover a medication for a set period.

1. Choose **Authorizations**, then **Add an authorization**.
2. Choose the tracked medication from the drop-down, by person. For a product that
   nobody tracks yet, choose **-- Find another or add new --**, pick the person and find
   the product.
4. Check the first day. The form starts with the first day of this month. Clear the
   field if you do not know the first day.
5. Check the expiration date. The form starts with one year after the first day of this
   month. The insurer's letter shows the date.
6. Choose **Save**.

A product that is on no list of the person is added to the list, named after the
product, with the status Not started. The Refills page can then warn you when the
authorization ends.

The Refills page shows the latest authorization of a medication in use from 30 days
before it expires. From 14 days before, it is due. After a renewal, add the new
authorization and the reminder goes away.

### Look at the history

Choose **History** to see every fill, newest first. The quantity and the days supply
have a column each. A quantity shows decimals only when it has them, such as 2.5. Narrow the list by person,
tracked medication, pharmacy or year. When a fill names a product with another name than
the medication, the product shows under the name. Under the filters, the page shows the number of fills and
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
7. Check **Specialty** and **Controlled**. The starter catalog and lookup suggest these
   marks from public references. Specialty lists vary, and missing products stay unmarked.
   You can change either mark before saving. Controlled medications count every fill
   across payers, and by default wait until supply runs out.
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

The fills and the tracked medications that hold the entry move to the entry that stays.
The names of the entry that goes away become other names of the entry that stays. When a
person would end up with the entry that stays on two tracked medications, the page says
so; take it off one of them afterwards. A merge cannot be undone in the app, so merge
only entries with the same strength.

### Set insurance plans

1. Choose **Setup**, then **Insurance plans**, then **Add an insurance plan**.
2. Enter a name you recognize, without member numbers or personal details.
3. Enter its early fill percent and supply frame days, or leave them empty for household defaults.
4. Choose **Save**. Open each person's form under **Setup**, **Family** and choose their current plan.

At 25 percent, a 30-day fill allows 7 days early, and 90 days allows 22. Use 0 percent
for cash or over-the-counter purchases to wait for physical supply to run out.
The frame starts at the proposed next fill date and looks back, initially 180 days.
Use 0 for the last fill only, or 3650 for every fill. Controlled medications ignore
plan overrides and count every fill, with their household days early setting.

A plan drop-down can add a new plan by name in the same form. It starts with household
rules. Set overrides under **Insurance plans** afterward. An existing fill keeps its payer
when you change the person's current plan. History shows the payer of each fill.

### Change the reminder settings

1. Choose **Setup**, then **Reminder settings**.
2. Enter day counts from 0 to 365, a percent from 0 to 100, or a frame from 0 to 3650.
   Leave a field empty to use the default.
3. Choose **Save**.

| Setting | The app starts with |
|---|---|
| Due | 3 days |
| Due soon | 7 days |
| Due, for a specialty medication | 5 days |
| Due soon, for a specialty medication | 10 days |
| Due, for a prior authorization | 14 days |
| Due soon, for a prior authorization | 30 days |
| Early fill percent | 25 percent |
| Supply frame | 180 days |
| Days early for controlled medications | 0 days |

### Remove a record

Every **Remove** button opens a page that asks first. Choose **Remove** to go on, or
**Keep it** to go back.

Removing hides the record in the app. Privatium keeps the original line in its log, so
the record stays on the disk.

The app does not remove a person, a catalog product, a tracked medication, a pharmacy, a
prescriber or a plan that other records still use. The page says what uses the record.
To keep a medication on the list as one no longer taken, change its status instead.

### When a form comes back

If something in a form is not right, the form comes back with a list of problems at the
top. Each entry in the list links to its field. Everything you typed is still there.

### Times and dates

Every date the app compares with today uses the clock of the computer that runs
Privatium. If you open the app from another time zone, you see that computer's date.

### Conclusion

You can now keep the medication lists of a household, with the products behind each
medication, add what is missing from inside any form, record fills by hand or from a
portal, and see what needs a refill.

### Additional resources

- [App design](design/README.md), with the rules behind the refill dates.
- [Data model](data-model.md), what the app stores.
- [The app folder](../apps/meds/README.md)
- [Privatium](https://github.com/gabrielmongefranco/privatium), the framework this app runs on.

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
