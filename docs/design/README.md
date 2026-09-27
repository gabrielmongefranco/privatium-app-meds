<!--
This file is part of Prescription Tracker
docs/design/README.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-09-27
Summary: Design of the app's screens: tasks, medication search, pasting fills from
         a portal, refill status rules, accessibility and privacy plans, what was checked,
         and the owner's decisions.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## App design

[Back to project README](../../README.md)

This page describes the design of the Prescription Tracker app: the tasks it serves,
what each screen does, and how the app decides that a refill is due. It is for the owner
and for developers who change the app. [The usage page](../usage.md) shows how to use the
screens. The [data model](../data-model.md) describes the tables and views.

Every screen on this page is built, except where a note marked **Planned** says
otherwise. The [import plan](import.md) for the owner's legacy database is planned.

### Goals

- Replace hand edits in a database tool with forms that check what you type.
- Show what needs a refill first, in plain words.
- Keep the refill dates that the legacy database calculates.
- Work with a keyboard, a screen reader and a phone.
- Keep every record on the owner's node. The app calls no network service.

### Tasks and the screens that serve them

| Task | Screen |
|---|---|
| See what needs a refill or a new prescription | Refills |
| Record a fill after a pickup or a delivery | Record a fill |
| Add the fills listed on an insurer's or a pharmacy's portal | Paste fills |
| Find a medication under any of its names | Medication search |
| Change a status, the refills left, the pharmacy or the prescriber | Medication page |
| Bring a current medication list to an appointment | Printable medication list |
| See when a prior authorization ends | Refills, Authorizations |
| Look up what the household paid | History |
| Find a pharmacy or prescriber phone number | Contacts |
| Add a person or a medication, or merge two catalog entries | Setup |

A prior authorization is an insurer's approval to cover a medication for a set period.

### Navigation

The app has six sections. One navigation bar lists them on every page, in this order:
**Refills**, **Medications**, **History**, **Authorizations**, **Contacts**, **Setup**.
The bar marks the current section with `aria-current="page"` and an underline.

Pages that list records for several people show a person filter under the heading. The
filter is a row of links: **Everyone**, then one link per person. The app hides the
filter when the household has one person.

Every internal link goes through `url()`, so the app works in host mode and in solo mode.

### Screens

All names and numbers in the examples are invented.

#### Refills

This is the home page. It shows what needs attention now, most urgent first.

The page holds these parts, in reading order:

1. The heading **Refills** and the household name.
2. The **Record a fill** button.
3. The person filter.
4. A summary list with one count per group. Each count links to its group on the page.
5. One section per group that has rows. The groups and their order are in
   [Refill status rules](#refill-status-rules).
6. A closed disclosure named **Not due yet**, holding everything else that is active.

Each row shows the medication, the person, the refill status in words, the last fill,
the refills left and a **Record fill** button. This example assumes that today is
2026-09-27. The third row is a specialty medication, which is due earlier.

| Medication | For | Refill | Last fill | Refills left | Action |
|---|---|---|---|---|---|
| Examplol (Exampline) 10 mg | Alex Example | Overdue by 4 days | 2026-08-24 at Example Pharmacy, 30 days | None. Ask Dr. Sample for a new prescription: (555) 555-0100 | Record fill |
| Samplex (Samplamide) 5 mg | Sam Example | Due in 3 days | 2026-08-31 at Example Pharmacy, 30 days | 2 | Record fill |
| Specimab (Specizumab) 150 mg, specialty | Alex Example | Due in 5 days | 2026-09-04 at Example Specialty Pharmacy, 28 days | 5 | Record fill |

Only a medication with the status Taking regularly raises an alert. The other active
medications appear further down the page. Each one shows its next fill date and its
recommended next fill date, so you can look them up when you need them.

When nothing needs attention, the page says so and names the next date: "Nothing needs a
refill. The next one is Samplex (Samplamide) 5 mg on 2026-10-25."

When the app holds no people yet, the page shows a welcome message with two links. One
adds a person. The other opens the import guide.

#### Record a fill

The form opens from a row's **Record fill** button, or from the button at the top of the
home page. From a row, the person and the medication are already chosen. The form copies
five values from the last fill of that medication, so most fills need a date and an
amount only.

| Field | Required | Starts as | Check |
|---|---|---|---|
| Who is it for | Yes | The row's person | Must be a person in the app |
| Medication | Yes | The row's medication, or the result of a medication search | Must be in the catalog |
| Date filled | Yes | Today | A real date that is not in the future |
| Pharmacy | Yes | Pharmacy of the last fill | Must be a pharmacy in the app |
| Days supply | No | Days supply of the last fill | Whole number, zero or more |
| Quantity | No | Quantity of the last fill | Number with up to three decimal places |
| Amount you paid | No | Empty | Number with up to two decimal places |
| Refills left after this fill | Yes | One less than now, never below zero | Whole number, zero or more |
| Prescription number | No | Number of the last fill | Text |
| Insurance plan | No | Plan of the last fill | Text |
| Claim number | No | Empty | Text |
| Notes | No | Empty | Text |

The claim number and the notes sit in a closed disclosure named **More details**. Every
value the form copied stays visible, so you can see it before you save it.

The amount field accepts what people type. The app removes a leading currency sign and
thousands separators before it checks the number.

Saving writes the fill and the new refills left together, in one batch. The app then
returns to the home page, which confirms the save in a status message: "Saved the fill
for Examplol (Exampline) 10 mg. The next fill date is 2026-10-27."

If a check fails, the form comes back with everything you typed still in place. Each
problem appears as text next to its field. A summary at the top links to each field that
has a problem.

#### Paste fills

An insurer's or a pharmacy's portal lists the fills it paid for. This screen turns a copy
of that list into fills, so you do not type them one by one.

1. Choose the person the portal page belongs to.
2. In the portal, open the details of each fill. Select the list and copy it.
3. Paste the text into the box and choose **Read the text**.
4. Check the review table and correct any row that needs it.
5. Choose **Add fills**.

Each portal lays out its page in its own way, so the app has one reader for each layout.
A reader looks for the labels that the portal prints, such as "RX NUMBER" and "DAYS
SUPPLY", and takes the value that follows each one. The readers are plain Lua in the
app's `lib/` folder. They call no network service.

This invented example shows the layout of the first reader, with one fill. The portal
runs the columns of a row together, as the second line shows.

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
| SERVICE DATE | The fill date. This layout writes month, day, year. |
| DRUG NAME | The medication. The app suggests the medications whose names share the most words with it. |
| PHARMACY ID | The pharmacy, matched by its National Provider Identifier (NPI) |
| PHARMACY | The pharmacy, matched by name when no identifier matches |
| RX NUMBER | The prescription number |
| DAYS SUPPLY | The days supply |
| QUANTITY | The quantity |
| Patient Responsibility | The amount you paid |
| Plan Paid, Deductible, CLAIM STATUS | Shown in the review table. Not stored. |

The review table has one row for each fill that the reader found. Each row shows what was
read, what it matched, and a result.

| Result | Meaning | What you do |
|---|---|---|
| Ready | Every value was read and matched | Nothing |
| Already recorded | The person has a fill with the same prescription number and date | Nothing. The row is left out. |
| Choose a medication | No medication answers to exactly the portal's name | Pick one of the suggested medications. The app saves the portal's name as another name. |
| Choose a pharmacy | No pharmacy matches | Pick one, or add the pharmacy from the pasted name, address and phone number |
| Not on the list | The person's list lacks the medication | Nothing. Adding the fill also adds the medication to the list, with the status Taking regularly. |
| Not paid | The claim status is not Paid | Include the row only if the fill took place |
| Not in the catalog | No medication is close to the portal's name | Add the medication to the catalog, then read the text again |
| Details missing | The fill was not opened in the portal before copying | Open the details in the portal and copy the page again |
| Could not read | A value is not a date or a number | Correct it in the portal's text and read it again |

The prescription number and the date together tell the app that a fill is already
recorded. So pasting the same page twice adds nothing the second time.

**Add fills** writes every included row in one batch. For each row, it also lowers the
refills left of that medication by one, never below zero.

The review form carries the pasted text with it. When you choose **Add fills**, the
server reads the text again and checks every value again. It keeps nothing between the
two steps.

One paste can hold about 64 kilobytes of text, which is roughly 100 fills with their
details. The page says so when a paste is too long, and asks you to paste it in parts.

#### Medication search

A medication can be known by several names. A label may print the brand name, a
statement may print the generic name, and a person may use an abbreviation. The app keeps
one catalog entry for the product and any number of other names for it.

Every place that asks for a medication has the same search box. It looks through the
short name, the generic name, the brand name and the other names. It ignores capital
letters, punctuation and extra spaces.

| What you type | What the app does |
|---|---|
| A name that one medication answers to, such as "exm" | Picks Examplol (Exampline) 10 mg and goes on |
| A name that several medications answer to, such as "exampline" | Lists them, so you pick the strength you mean |
| A name close to one it knows, such as "Examplal" | Asks "Did you mean Examplol (Exampline) 10 mg?" and lists the closest matches |
| A name it does not know | Offers two choices: link the name to a medication in the catalog, or add a new medication |

When you link a name to a medication, the app saves it as another name for that
medication. The next search finds it at once.

The app never picks a medication from a close match by itself. Some different drugs have
names that look alike, so a close match is always a question for you to answer.

The app has no drug dictionary, because it calls no network service. It learns that two
names mean the same product from the catalog and from you.

Every page shows the short name. It has the brand name, the generic name in brackets,
and the strength, such as "Examplol (Exampline) 10 mg". You can type another short name
for a medication. The medication page also shows the full name and the other names.

#### Medications

This page lists what each person takes. It groups the rows by status, in this order:
Taking regularly, Taking as needed, On hold, Not started. A closed disclosure holds the
rows with the status No longer taking.

Each row shows the medication, the instructions, when to take it, what it is for, the
prescriber, the refill status and the next fill date. The page has two actions: **Add a medication** and
**Print list**. The second appears when one person is selected.

The form that adds a medication asks for the person and the medication first. It then
asks for the type, the status, the pharmacy and the prescriber. It ends with what the
medication is for, the instructions, when to take it and the refills left.

You pick the medication with the medication search. A link next to it adds a new
catalog entry and then returns to the form.

#### Medication page

Each medication a person takes has its own page. It holds these parts, in reading order:

1. The medication name as the heading, the person, the status and a **Change status**
   control.
2. **How to take it**: the instructions, when to take it, and what it is for.
3. **Refills**: the refill status, the last fill, the next fill date, the recommended
   next fill date, and the refills left.
4. **Who to call**: the prescriber and the pharmacy, with phone links.
5. **Prior authorizations**: each approval window with its state, and
   **Add an authorization**.
6. **Fill history**: a table, newest first, with the total paid.
7. **About this medication**: the full name, the other names and the catalog details.

The page has three actions: **Record fill**, **Edit** and **Remove**.

#### Printable medication list

One page per person, made for paper. It shows the person's name, the birth date when one
is stored, and the date of printing. A table follows, with five columns: medication, how
to take it, when, what it is for, and prescriber. The table holds the medications with
the status Taking regularly or Taking as needed. A second table holds the ones on hold.

A print stylesheet hides the navigation and the buttons. The page tells you to use the
browser's own print command. A print button would need a script, and the app ships none
of its own.

#### History

This page lists every fill, newest first, 50 to a page. A filter form narrows the list by
person, medication, pharmacy and year. The table shows the date, the medication, the
person, the pharmacy, the quantity, the days supply, the amount paid and the prescription
number. Each row has an **Edit** link.

Under the table the page shows the number of fills and the total paid for the current
filter. A second table shows the total paid for each person in each year.

#### Authorizations

This page lists every prior authorization with the medication, the person, the first day,
the last day and a state. The states are Active, Ends in a number of days, Ended, and Not
started. You can add, edit and remove an authorization here or on the medication page.

#### Contacts

This page lists the pharmacies and the prescribers. Each entry shows the name, the
clinic, the phone and fax numbers, the address, the email address, the website and the
National Provider Identifier (NPI). A phone number is a link that starts a call on a
phone. A website is a link only when it starts with `http://` or `https://`.

#### Setup

This page links to four places:

- **People**: the household members.
- **Medication catalog**: every product the household has used, with its other names.
  The sample data adds a starter catalog of common medications.
- **Reminder settings**: the five day counts in the refill status rules.
- **Household name**: the name the app greets with.

A catalog entry has a **Specialty** checkbox. A specialty medication takes longer to
arrive, so its refill is due earlier.

Two catalog entries that are the same product can be merged. Merging moves the fills,
the list entries, the prior authorizations and the other names from one entry to the
other. It then hides the emptied entry. The page shows what will move and asks you to
confirm.

#### Choices in forms

Five fields offer choices: the route, the form, the package type, the medication type,
and when to take it. Each one is a drop-down with a text box under it, labeled
**Or type a new one**.

The choices are a built-in starter list plus every value that your records already use.
A value that you type becomes a choice as soon as a record uses it. A misspelled choice
goes away once no record uses it. No separate screen manages the choices.

The strength is one text field. You type it as the label prints it, with the unit. That
covers "10 mg", a concentration such as "100 units/mL", and a product with three drugs
such as "100-62.5-25 mcg". The app never calculates with a strength, so it needs no list
of units.

#### Times and dates

Every time and date on a screen is local. The greeting and today's date come from the
clock of the computer that runs the node, never from Coordinated Universal Time (UTC).

#### Removing a record

Every **Remove** button opens a confirmation page first. The page names the record. It
also explains that Privatium hides the record and keeps the original line in its log.

The app refuses to remove a person, a medication, a pharmacy or a prescriber that other
records still use. It says how many records use it.

### Refill status rules

The view `v_active_medication` works out the refill status of every medication in use.
The app stores none of it. The view uses the next fill date, the day counts and today's
date. Today is the local date of the computer that runs the node.

| Refill status | Ordinary medication | Specialty medication |
|---|---|---|
| Overdue | The next fill date is before today | The same |
| Due | The next fill date is today or up to 3 days away | Today or up to 5 days away |
| Due soon | The next fill date is 4 to 7 days away | 6 to 10 days away |
| Not due | The next fill date is more than 7 days away | More than 10 days away |
| No fill | No fill is recorded | The same |

The five day counts are defaults: 3, 7, 5, 10, and 30 for a prior authorization. You can
change them under **Reminder settings**.

#### The two dates

The app keeps both dates of the legacy view `ActiveMedicationsView`, worked out by the
same rules.

- The **next fill date** is the date of the last fill plus its days supply.
- The **recommended next fill date** also counts the supply that earlier fills built up,
  the way an insurer counts early refills. It is never earlier than the next fill date.

The refill status uses the next fill date, as the legacy view does. The
[data model](../data-model.md) gives the rules step by step, with a worked example.

#### Groups on the Refills page

| Order | Group | Holds | Shown as |
|---|---|---|---|
| 1 | Overdue | Taking regularly, refill status Overdue | "Overdue by 4 days" |
| 2 | Due | Taking regularly, refill status Due | "Due today", "Due in 3 days" |
| 3 | Due soon | Taking regularly, refill status Due soon | "Due in 6 days" |
| 4 | Authorization ending | An active medication's prior authorization ends within 30 days, or has ended with no later one | "Authorization ends in 12 days" |
| 5 | As needed | Taking as needed | Both dates and the refills left, with no alert |
| 6 | Missing information | Taking regularly, with no fill or with a last fill that has no days supply | "Add a days supply to get a refill date" |
| 7 | Not due yet | Taking regularly, refill status Not due | Both dates |
| 8 | Paused | On hold or Not started | The status and both dates, with no alert |

A medication with the status No longer taking appears in no group.

A row in groups 1 to 3 with no refills left also says so. It names the prescriber and
shows the phone number, because the next step is a new prescription.

A fill with no days supply counts as 1 day in every view, so a report always has a date.
The medication still appears under Missing information until someone adds the number.

#### Differences from the legacy view

The rules for the two dates are the same. On the owner's data, both dates matched the
legacy view for every row. Five things differ, each by a decision recorded below.

- **Today.** The legacy view uses the date in Coordinated Universal Time (UTC). In the
  evening in the Americas that date is already tomorrow. The app uses the local date.
- **Day counts.** The legacy view uses 7 and 12 days for every medication. The app uses
  3 and 7, or 5 and 10 for a specialty medication.
- **Alerts.** The legacy view gives every active medication a refill status and nothing
  else. The app raises an alert for Taking regularly only, and shows the dates of the
  others without one.
- **Empty days supply.** The legacy view counts it as zero. The app counts it as 1 day.
- **Merged entries.** When two catalog entries are merged, their fills count together.
  The dates of that medication can then differ from the legacy view.

### Accessibility plan

The target is the Web Content Accessibility Guidelines (WCAG) 2.2, level AA.

| Need | Design response |
|---|---|
| Status without color | Every status has words and an icon. The badge color repeats the meaning and never carries it alone. |
| Form labels | Every field has a visible label. Help text is tied to the field with `aria-describedby`. |
| Choices | A drop-down and its **Or type a new one** box share a group with one legend, so a screen reader announces them together. |
| Form errors | Each error is text next to its field, announced with `role="alert"`. The form keeps what you typed. |
| Tables | Real tables with a caption and header cells. On narrow screens the rows stack, with explicit table roles so a screen reader still reads a table. |
| Review of pasted fills | Each result is a word with an icon. A row that needs a choice holds its own labeled fields, and a summary above the table counts the rows by result. |
| Keyboard | Every control is a link, a button or a form field. Disclosures use the native `<details>` element. The shell supplies the focus ring. |
| Pointer targets | Buttons use the shell's height of 44 CSS pixels. |
| Zoom and small screens | Forms are one column. Nothing has a fixed width. The layout reflows at 320 CSS pixels. |
| Repeated buttons | Each **Record fill** button carries hidden text that names its medication. |
| Headings | One `<h1>` on every page, with heading levels in order. |
| No JavaScript | Every save and every search is a plain form. Scripts add convenience only, such as a search that narrows while you type. |
| Time limits | None. A status message stays until you leave the page. |
| Color schemes | The app uses the shell's color tokens only, so it follows light and dark mode. |
| Plain words | "Due in 3 days" rather than a bare date. Dates follow the node's date format setting. |

These checks need a person once the screens exist:

- Finish the main tasks with the keyboard only.
- Finish the main tasks with a screen reader.
- Zoom to 200% and look for overlap and cut-off text.
- Narrow the window to 320 pixels and look for sideways scrolling.
- Turn JavaScript off in the node's own browser and save a fill.
- Open a print preview of the medication list.

### Privacy and security plan

The app will hold health information about family members. That includes names, birth
dates, medications, the conditions they treat, prescription numbers and claim numbers.

- **Storage.** Privatium stores records as plain text and does not encrypt them on disk.
  Recommended: turn on disk encryption, lock the account with a password, and encrypt
  backups.
- **Input.** The server trims, length-limits and checks every form value. It checks a
  status against the five allowed values, and checks that every record a form points to
  exists. When a check fails, nothing is saved.
- **Guesses.** A close match in the medication search is a suggestion. The app saves
  nothing until you choose.
- **Pasted text.** Text from a portal is untrusted input. The app reads values by
  position and pattern, checks each one, and shows them escaped. It never runs any part
  of the text, and it saves nothing until you confirm the review table.
- **SQL.** Every query binds its parameters.
- **Output.** Templates use the escaping tag only. The app has no `<?raw ?>` tag.
- **Links made from data.** A website becomes a link only with an `http` or `https`
  scheme. A phone link holds digits and a plus sign only.
- **Forms.** Every form that saves carries the `csrf()` token. The token guards against
  cross-site request forgery, where another site submits a form in your name.
- **Addresses.** A page address holds record ids only. It never holds a name, a date or a
  medication.
- **Logs.** Diagnostic messages hold record ids and counts, never field values.
- **Sample data.** `sample/seed.jsonl` holds invented people and products only.
- **Import.** The [import plan](import.md) keeps real records out of this repository.

This design makes no claim of compliance with any health privacy law.

### What was checked

These checks ran from 2026-09-26 to 2026-09-27 with Privatium 0.3. The checks on the
owner's database opened it read-only, kept the converted rows in memory, and printed
counts only. [How to run the tests](../how-to/run-the-tests.md) covers the first three
rows.

| Check | Result |
|---|---|
| `privatium lint apps/meds` | 0 findings |
| Unit tests of the Lua modules | All passed |
| Smoke test of every screen over HTTP | All passed |
| Both dates against the legacy view, on the owner's data, with an empty days supply counted as zero | Every row matched |
| The same, with an empty days supply counted as 1 day | Every row matched |
| Conversion of every legacy row under the schema's constraints | Every row converted. The total amount paid was unchanged. |
| `date('now', 'localtime')` inside the node | Returned the local time |
| Loading invented rows through the data API on the node's own address | Accepted |
| Loading the same rows a second time | Nothing appended |
| Loading a row that had changed since the first load | Refused with status 409. Nothing appended. |
| Reading the views with a SQLite library that lacks the decimal extension | Every view ran except the spending view |

No check drove a browser. [The compliance page](../compliance.md) lists what a person
still has to check by hand. The import script does not exist yet.

### Decisions made

The owner made these decisions on 2026-09-27.

| Subject | Decision |
|---|---|
| Refill alerts | Taking regularly only. The dates of the other active medications stay visible. |
| Empty days supply | Shown under Missing information. Counted as 1 day in views and reports. |
| Days supply of zero | Stays zero. |
| The two dates | Same rules as the legacy view. Any difference is explained before it is built. |
| Date that drives the refill status | The next fill date, as in the legacy view. |
| Prior authorization | Every one names a person. |
| Medication names | One catalog entry for each product, a short name shown everywhere, and other names that the search understands. |
| Short name | The brand name, the generic name in brackets, then the strength. |
| Birth date | Kept, optional. |
| Choices and strength | Choices are picked or typed in the form. Strength is text, as the label prints it. |
| Import | A Python script for one use by the owner. |
| Fills for a medication on nobody's list | The import adds a list entry with the status No longer taking. |
| Day counts | Due at 0 to 3 days and due soon at 4 to 7. For a specialty medication, 0 to 5 and 6 to 10. |
| Readable view | `v_active_medication`, with the new column names. |
| Sample data | Holds a starter catalog of medications that are common in the United States. |
| Fills from a portal | Pasted as text, read by the app, reviewed, then added. |
| Amounts from a portal | What the plan paid and the deductible are shown in the review and not stored. |
| Portal names | A reader is named after its layout. No company name appears in this repository. |
| Refills left after a pasted fill | Lowered by one, never below zero. |
| A pasted fill for a medication that is not on the person's list | The review says so. Confirming adds the medication with the status Taking regularly. |
| Times and dates on screen | Local time, from the clock of the computer that runs the node. |

### Build order

Each step ended with a clean `privatium lint`, passing tests and updated documentation.

1. Tables, views and the starter catalog, with the data model page. Done.
2. Setup screens for people, pharmacies, prescribers and the catalog. Done.
3. The medication search, the other names and the merge. Done.
4. The one-time import. **Planned.** See the [import plan](import.md).
5. Medications and the medication page. Done.
6. Record a fill, and History. Done.
7. Paste fills. Done, for one layout of portal page.
8. Refills, as the home page. Done.
9. Authorizations. Done.
10. The printable medication list and the spending table. Done.
11. The manual accessibility checks. **Planned.** [The compliance page](../compliance.md)
    lists them.

### Conclusion

You now know what the app shows, how it decides that a refill is due, and what is
still planned. Read the [data model](../data-model.md) next, then the
[import plan](import.md).

### Additional resources

- [Using the app](../usage.md)
- [Data model](../data-model.md)
- [Import plan](import.md)
- [How to run the tests](../how-to/run-the-tests.md)
- [Compliance](../compliance.md)
- [The schema, as SQL](../../apps/meds/schema.sql)
- [Project instructions](../../AGENTS.md)
- [Privatium accessibility guide](../../skills/privatium-accessibility/SKILL.md)
- [Privatium security guide](../../skills/privatium-security/SKILL.md)
- [WCAG 2.2 quick reference](https://www.w3.org/WAI/WCAG22/quickref/)
- [Privatium](https://github.com/gabrielmongefranco/privatium), the framework this app runs on.

[Back to project README](../../README.md)

----

Copyright © 2026 Gabriel Mongefranco
