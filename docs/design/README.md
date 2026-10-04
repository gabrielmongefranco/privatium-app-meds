<!--
This file is part of Prescription Tracker
docs/design/README.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-10-03
Summary: Design of the app's screens: tasks, the medication box, adding records from
         inside a form, pasting fills from a portal, the catalog as a copy of a drug
         reference, refill status rules, accessibility and privacy plans, what was
         checked, and the design decisions.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## App design

[Back to project README](../../README.md)

This page describes the design of the Prescription Tracker app: the tasks it serves,
what each screen does, and how the app decides that a refill is due. It is for the household
and for developers who change the app. [The usage page](../usage.md) shows how to use the
screens. The [data model](../data-model.md) describes the tables and views.

Every screen on this page is built, except where a note marked **Planned** says
otherwise.

### Goals

- Replace hand edits in a database tool with forms that check what you type.
- Show what needs a refill first, in plain words.
- Estimate refill eligibility and supply exhaustion from recorded fills and payer rules.
- Work with a keyboard, a screen reader and a phone.
- Keep every record on the household's node. The node calls no network service. The browser
  asks a public drug reference only when you look up a medication to add.

### Tasks and the screens that serve them

| Task | Screen |
|---|---|
| See what needs a refill or a new prescription | Refills |
| Record a fill after a pickup or a delivery | Record a fill |
| Add the fills listed on an insurer's or a pharmacy's portal | Paste fills |
| Find a medication under any of its names | The medication box, in every form that needs a medication |
| Add a pharmacy, a prescriber, a person or a medication while filling in another form | The same form |
| Change a status, the refills left, the pharmacy or the prescriber | Medication page |
| Bring a current medication list to an appointment | Printable medication list |
| See when a prior authorization ends | Refills, Authorizations |
| Look up what the household paid | History |
| Find a pharmacy or prescriber phone number | Contacts |
| Add a person or a medication, or merge two catalog entries | Setup |

A prior authorization is an insurer's approval to cover a medication for a set period.

### Navigation

The app has six sections. One navigation bar lists them on every page, in this order:
**Medications**, **Refills**, **History**, **Authorizations**, **Contacts**, **Setup**.
The bar marks the current section with `aria-current="page"` and an underline.

Pages that list records for several people show a person filter under the heading. The
filter is a row of links: **Everyone**, then one link per person. The app hides the
filter when the household has one person. A small script, `static/person_tab.js`, keeps
the person chosen last in the local storage of the browser, as an id, and opens a page
that names no person on that tab. The **Everyone** link carries an empty `person`
parameter, so choosing it is remembered too. Without scripts, every page opens on
Everyone. The script is a stopgap until Privatium offers person profiles; [issue 10](https://github.com/gabrielmongefranco/privatium-app-meds/issues/10) tracks its removal.

Every medication name carries the icon of its dose form, chosen by `lib/form_icon.lua`
from the form, the route and the package of the product. The icon carries the form as
its label, so a screen reader hears "Tablet" rather than a picture. Every icon comes from
the Bootstrap Icons set that Privatium ships, except the syringe for an injection, which
`views/_form_icon.lsp` draws itself.

Every internal link goes through `url()`, so the app works in host mode and in solo mode.

### Screens

All names and numbers in the examples are invented.

#### Refills

It shows what needs attention now, most urgent first.

The page holds these parts, in reading order:

1. The heading **Refills** and a greeting.
2. The **Record a fill** button.
3. The person filter.
4. A summary list with one count per group. Each count links to its group on the page.
5. One section per group that has rows. The groups and their order are in
   [Refill status rules](#refill-status-rules).
6. A closed disclosure named **Not due yet**, holding everything else that is active.

Each row shows the medication, the person, the refill status in words, the last fill,
the refills left and a **Record fill** button. This example assumes that today is
2026-10-01. The third row is a specialty medication, which is due earlier.

| Medication | For | Refill | Last fill | Refills left | Action |
|---|---|---|---|---|---|
| Examplol (Exampline) 10 mg | Alex Example | Overdue by 4 days | 2026-08-24 at Example Pharmacy, 30 days | None. Ask Dr. Sample for a new prescription: (555) 555-0100 | Record fill |
| Samplex (Samplamide) 5 mg | Sam Example | Due in 3 days | 2026-08-31 at Example Pharmacy, 30 days | 2 | Record fill |
| Specimab (Specizumab) 150 mg, specialty | Alex Example | Due in 5 days | 2026-09-15 at Example Specialty Pharmacy, 28 days | 5 | Record fill |

Only a medication with the status Taking regularly raises an alert. The other active
medications appear further down the page. Each one shows its next fill date and its
supply exhaustion date, so you can look them up when you need them.

When nothing needs attention, the page says so and names the next date: "Nothing needs a
refill. The next one is Samplex (Samplamide) 5 mg on 2026-10-25."

When the app holds no people yet, the page shows a welcome message with a link that
adds a person.

#### Record a fill

The form opens from a row's **Record fill** button, or from the button at the top of the
Refills page. From a row, the person and the medication are already chosen. The form copies
five values from the last fill of that medication, so most fills need a date and an
amount only. From the button at the top, the form starts with
[the medication box](#the-medication-box).

| Field | Required | Starts as | Check |
|---|---|---|---|
| Person | Yes | The row's person | A person in the app, or the name of a new one |
| Medication | Yes | The row's medication, or the medication box | In the catalog, or a new medication |
| Date filled | Yes | Today | A real date that is not in the future |
| Pharmacy | Yes | Pharmacy of the last fill | A pharmacy in the app, or the name of a new one |
| Days supply | No | Days supply of the last fill | Whole number, zero or more |
| Quantity | No | Quantity of the last fill | Number with up to three decimal places |
| Amount you paid | No | Empty | Number with up to two decimal places |
| Refills left after this fill | No | One less than now, never below zero | Whole number, zero or more. Empty lowers the count by one. |
| Prescription number | No | Number of the last fill | Text |
| Insurance plan | No | Plan of the last fill | Text |
| Claim number | No | Empty | Text |
| Notes | No | Empty | Text |

The claim number and the notes sit in a closed disclosure named **More details**. Every
value the form copied stays visible, so you can see it before you save it.

The amount field accepts what people type. The app removes a leading currency sign and
thousands separators before it checks the number.

Saving writes the fill, the new refills left and any record the form added together, in
one batch. The app then
returns to the Refills page, which confirms the save in a status message: "Saved the fill
for Examplol (Exampline) 10 mg. The next fill date is October 24, 2026, and the supply lasts until October 31, 2026."

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
| DRUG NAME | The medication. The app matches it as the next part describes. |
| PHARMACY ID | The pharmacy, matched by its National Provider Identifier (NPI) |
| PHARMACY | The pharmacy, matched by name when no identifier matches |
| RX NUMBER | The prescription number |
| DAYS SUPPLY | The days supply |
| QUANTITY | The quantity |
| Patient Responsibility | The amount you paid |
| Plan Paid, Deductible, CLAIM STATUS | Shown in the review table. Not stored. |

The review page has three parts: the medications, the pharmacies and the fills. It asks
about each medication name and each pharmacy once, however many fills use it. It asks
only about fills that can be added.

**Medications.** For each name the portal wrote, the app looks for the medication in
this order:

| Step | The app finds | The page says | The choice starts as |
|---|---|---|---|
| 1 | One medication that answers to exactly this name | Known name | That medication, with nothing to choose |
| 2 | An earlier fill of the person with the same prescription number, whose medication has the drug of the name among its names | Matched | That medication, marked |
| 2 | The same, under a name that does not fit | Choose a medication | Nothing. That medication comes first. |
| 3 | One medication whose brand or generic name starts the portal's name, and whose strength the portal's name holds | Matched | That medication, marked |
| 4 | Medications that share words with the name | Choose a medication | Nothing. The best match comes first. |
| 5 | Nothing | New name | A new medication, filled in from the name |

A prescription number is compared without hyphens and spaces, and only with the fills
of the same person. Numbers that lead to two medications say nothing.

The step for name and strength compares whole words and whole strengths. "Exampline" does not start
"EXAMPLINE-SAMPLAMIDE", and "5 mg" is not found in "0.5 mg" or in "25 mg". When two
medications pass, the app picks neither.

In step 5, the app takes the name apart. "EXAMPLINE HCL 10 MG TABLET" becomes the generic
name "Exampline HCL" and the strength "10 mg". You correct both before you add anything,
because a portal does not say whether a name is a brand name.

Every name that is not known also offers two more choices: **Another medication**, with a
box to type its name, and **A new medication**. The app saves the portal's name as
another name of the medication you choose, so the next paste knows it.

**Pharmacies.** The app matches a pharmacy by its National Provider Identifier (NPI),
then by its name. For a pharmacy it does not know, the choice starts as **Add**, with the
name, the address, the phone number and the identifier that were pasted. You can pick
one of your pharmacies instead.

**Fills.** Each fill shows what was read, a result, and a check box.

| Result | Meaning | The check box starts |
|---|---|---|
| Ready | Every value was read | Ticked |
| Not paid | The claim status is not Paid | Not ticked. Tick it only if the fill took place. |
| Already recorded | The person has a fill with the same prescription number and date, or a fill of the same medication on the same date | The fill has no check box |
| Details missing | The fill was not opened in the portal before copying | The fill has no check box |
| Could not read | A value is not a date or a number | The fill has no check box |

A medication that is not on the person's list is added to it with the fill, with the
status Taking regularly.

When a fill you ticked has no medication or no pharmacy yet, **Add fills** adds nothing.
The page comes back with your choices and marks the ones that are open.

The prescription number and the date together tell the app that a fill is already
recorded. So pasting the same page twice adds nothing the second time. A fill that was
typed by hand or imported may have no prescription number. So the app also leaves out a
fill when the person has a fill of the same medication on the same date. This check
runs once the app knows which medication a name means. A medication that has no fill
left to add asks no question.

**Add fills** writes every included row in one batch. For each row, it also lowers the
refills left of that medication by one, never below zero.

The review form carries the pasted text with it. When you choose **Add fills**, the
server reads the text again and checks every value again. It keeps nothing between the
two steps.

One paste can hold about 64 kilobytes of text, which is roughly 100 fills with their
details. The page says so when a paste is too long, and asks you to paste it in parts.

#### Tracked medications and products

What a person takes is a tracked medication: a `person_medication` row with the name the
person prefers. It stands for one or more products of the catalog, through
`person_medication_product`. A medication that comes in a carton of 2 and a carton of 6
is one tracked medication with two products, because the insurer counts the fills of
both together. Fills and prior authorizations point at the tracked medication; a fill
also keeps the product that was dispensed.

Two rules keep the counts right, and the forms enforce them because the schema cannot:
a product belongs to at most one tracked medication of a person, and a preferred name is
unique within one person. Two people may track the same product and use the same name.

#### The medication box

A medication can be known by several names. A label may print the brand name, a
statement may print the generic name, and a person may use an abbreviation. The app keeps
one catalog entry for the product and any number of other names for it. The catalog is
the list of products the app knows. It does not say who takes them.

No form sends you to another page to find a product or to add one. Two boxes do the
work. The form that tracks a medication has the product picker; the fill and
authorization forms have the older medication box under a drop-down of the tracked
medications, for a product that nobody tracks yet.

**The product picker**, `views/_product_picker.lsp`, is one section:

| Part | What it does |
|---|---|
| **Search the catalog** | A search box with a **Find** button. Enter or the button searches the catalog, and a suggestion that is picked while typing searches at once with that product checked. The results come back as a list with a check box each, 25 at most, best first, with a **Close match** badge on a name that is only near. With a script, the list shows 10 results a page on a tablet or a desktop and 5 on a phone. When the catalog has nothing, the script asks the drug references at once. |
| **Search online databases** | A link under the search box that asks the drug references even when the catalog found something. Checking one of their results fills in the fields below. The link needs the script. |
| **Not in the list? Add a medication to the catalog** | A closed disclosure with the brand name, the generic name, the strength, the route, the form, the package and the controlled and specialty marks. The route, the form and the package type are drop-downs with a choice to type a new value. While the brand or the generic name is typed, the script searches the catalog and then the drug references for similar products and lists them the same way, with a turning ring and the words "Searching for similar products..." until the search ends. Checking a catalog product there empties the typed fields, so the product is not added twice. |
| **Add to this medication** | Adds every checked result, or the new medication, to the list of products. |

The products chosen so far travel in hidden fields. Each has a **Remove** button. The
Products list and the box swap places as the form fills: with no product yet, only the
box shows; once a product is on the list, the box folds into a disclosure named **Add
another product** with the note "(e.g. different pack size of the same medication)"
under it, and opens when it has something to say. Nothing is written to the catalog
until the form is saved. The preferred name starts as the full name of the first
product. A typed search with nothing checked never saves the form, whatever button was
pressed, so Enter in the search box searches.

The server answers `GET /medications/search?q=` with the same results as JSON for the
script, and searches itself when the form is sent without one.

**The medication box** of the other forms, `views/_medication_picker.lsp`, has two parts:

| Part | What it does |
|---|---|
| **Medication name** | A text box that suggests names while you type. It offers every short name and every other name. |
| **Not in the list? Add a medication to the catalog** | The same fields as the picker, with the lookup in the drug references above them. The app builds the short name. |

The typed name is compared with the short name, the generic name, the brand name and the
other names. Capital letters, punctuation and extra spaces do not matter.

| What you type | What the app does |
|---|---|
| A name that exactly one medication answers to, such as "exm" when it is another name of one product | Picks that medication |
| A name that several medications answer to, such as "exampline" | The form comes back and lists them, so you pick the strength you mean |
| A name close to one it knows, such as "Examplal" | The form comes back and offers the closest matches |
| A name it does not know | The form comes back and opens **Not in the list? Add a medication to the catalog** |

When both parts are filled in, the more deliberate act wins: the fields of a new
medication, then the typed name.

A new medication whose short name is already in the catalog picks the medication that
has it. The catalog never holds the same short name twice.

The app never picks a medication from a close match by itself. Some different drugs have
names that look alike, so a close match is always a question for you to answer.

The suggestions come from the `<datalist>` element of the browser. The box needs no
script.

Every page shows the short name. It has the brand name, the generic name in brackets,
the strength, and the package when there is one, such as "Examplol (Exampline) 10 mg" or
"Examplol (Exampline) 10 mcg/mL 2 Pack". You can type another short name
for a medication. The medication page also shows the full name and the other names.

#### Medications

This page lists what each person tracks. It groups the rows by status, in this order:
Taking regularly, Taking as needed, On hold, Not started. A closed disclosure holds the
rows with the status No longer taking, each with a **Restart** button that sets the
status back to Taking regularly.

Each row shows the medication with its form icon, its products when there are several,
the instructions, when to take it, what it is for, the prescriber, the refill status and
the next fill date. The page has two actions, **Track a new medication** and
**Print list**, and a search box at the right of them. The second button appears when one
person is selected. The search narrows the list by the preferred name, every name of the
products, the prescriber and the person; `static/filter.js` does it as you type and opens
the closed disclosure when a match is inside it, and the server does the same when the
form is sent. Each row carries its search text in `data-search`.

The form that tracks a medication is one page. It starts with the person, then
[the product picker](#the-medication-box) and the preferred name. It then asks for the
status, the instructions, when to take it, what the medication is for and the refills
left. It ends with the prescriber, the pharmacy and the type. The person, the prescriber
and the pharmacy can each be a new one, added by name. The same form changes a tracked
medication, products included; a product with fills and the last product stay.

#### Medication page

Each medication a person takes has its own page. It holds these parts, in reading order:

1. The medication name as the heading, the person, the status and a **Change status**
   control.
2. **How to take it**: the instructions, when to take it, and what it is for.
3. **Refills**: the refill status, the last fill, the next fill date, the supply exhaustion
   date, and the refills left.
4. **Who to call**: the prescriber and the pharmacy, with phone links.
5. **Prior authorizations**: each approval window with its state, and
   **Add an authorization**.
6. **Fill history**: a table, newest first, with the total paid, and the product of each
   fill when the medication has several.
7. **Products**: the catalog products the medication stands for, each linked to its
   catalog page, with a **Remove** button when there are several.

The page has three actions: **Record fill**, **Change** and **Remove**. A tracked
medication with fills or prior authorizations is not removed; its status changes instead.

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
the expiration date and a state. The states are Active, Due soon, Due, Expired, and Not
started. You can add, edit and remove an authorization here or on the medication page.

The form asks for the person and for the medication in two separate fields. The person
comes first, then [the medication box](#the-medication-box), then the first day, then
the expiration date. Only the expiration date is required. A household often knows when
an approval ends and not when it began, and only the expiration date drives the
reminders. A first day that is not known shows as "Not known".

A new authorization starts with two dates filled in: the first day of the current month,
and the same day one year later as the expiration date. Most approvals start with a
month and run for a year, so most need little typing.

An authorization for a medication that is not on the person's list adds the medication
to the list, with the status Not started. The Refills page warns about an authorization
only for a medication on a list.

#### Contacts

This page lists the prescribers, then the pharmacies. Each entry shows the name, the
clinic, the phone and fax numbers, the address, the email address, the website and the
National Provider Identifier (NPI). A phone number is a link that starts a call on a
phone. A website is a link only when it starts with `http://` or `https://`.

#### Setup

This page links to four places, each a box of the launcher list:

- **Insurance plans**: names, refill overrides and reference-safe removal.
- **Family**: the household members.
- **Medication catalog**: every product the household has used, with its other names.
  The starter catalog of common medications loads by itself when the catalog is empty.
- **Reminder settings**: six reminder day counts and three early refill settings.

The app asks for no household name.

A catalog entry has **Specialty** and **Controlled** checkboxes. Controlled supply counts
across payers and has no early allowance unless the household sets one. A specialty medication takes longer to
arrive, so its refill is due earlier.

Two catalog entries that are the same product can be merged. Merging points the fills
and the tracked medications that hold one entry at the other, moves the other names, and
hides the emptied entry. A tracked medication that held both keeps one link. The page
shows what will move, warns when a person would end up with the product on two tracked
medications, and asks you to confirm.

#### Choices in forms

Five fields offer choices: the route, the form, the package type, the medication type,
and when to take it. Each one is a drop-down. Its second choice is **-- Add new --**,
which shows a text box for the new choice.

The choices are a built-in starter list plus every value that your records already use.
A value that you type becomes a choice as soon as a record uses it. A misspelled choice
goes away once no record uses it. No separate screen manages the choices.

A field that points to a person, a pharmacy or a prescriber works the same way. Its
drop-down has the choice **-- Add new --**, which shows a text box for the name. The
drop-down of the medication box has **-- Another medication --**, which shows the
name to type and the fields of a new medication.

The script `static/forms.js` hides the boxes until that choice is made. It empties a box
when you choose another record, so nothing you did not mean is saved. Without the
script, the boxes are always there, and a typed name wins over the drop-down.

A name typed into the box adds the record when the form is saved, in the same batch as the
form's own record. A form that is refused adds nothing. A typed name that a record
already has picks that record.

A record added this way holds its name only. The rest, such as a phone number, is added
later under **Contacts** or **Setup**.

#### Suggestions in text boxes

A text box whose values repeat suggests the values that your records already hold. You
can pick one or type something new.

| Text box | Suggests |
|---|---|
| Insurance plan, in a fill | The plans of earlier fills |
| Clinic, of a prescriber | The clinics of other prescribers |
| How to take it, and what it is for | The values of other medications on the lists |
| Brand name, generic name, strength and package size, in the catalog | The values of other catalog entries |
| The medication box and the search of the catalog | Every short name and every other name |

A box offers up to 200 values. The suggestions use the `<datalist>` element, so they
need no script.

The strength is one text field. You type it as the label prints it, with the unit. That
covers "10 mg", a concentration such as "100 units/mL", and a product with three drugs
such as "100-62.5-25 mcg". The app never calculates with a strength, so it needs no list
of units.

#### Times and dates

Every time and date on a screen is local. The greeting and today's date come from the
clock of the computer that runs the node, never from Coordinated Universal Time (UTC).

#### The catalog and the drug references

The catalog gets its entries in three ways.

| Way | What it adds |
|---|---|
| The starter catalog | About 2,507 entries, loaded by the app into an empty catalog |
| The lookup in a form | One entry at a time, when you add a medication the catalog lacks |
| Your own typing | Anything else |

The app loads no catalog of a drug reference. The lookup is for adding a medication, and
it copies only the entry you pick.

**The starter catalog** holds three groups of entries:

- The 200 drugs most prescribed in the United States in 2024, from the ClinCalc DrugStats
  list, each at every strength and form that RxTerms lists.
- The drugs of a second list of common medications that ClinCalc does not rank, at every strength too.
- Entries written by hand for products that no drug reference holds, such as continuous
  glucose monitors, alcohol prep pads and compounded mixes.
- Syringes and needles, one entry for each volume, gauge and length.

RxTerms is a drug vocabulary of the United States National Library of Medicine, made for
entering prescriptions. [How to build the starter catalog](../how-to/build-the-starter-catalog.md)
describes the script that writes the file.

**The lookup** sits inside **Not in the list? Add a medication to the catalog**, in the
medication box of the fill and authorization forms. You type a name and choose **Look
up**. The app looks in its own catalog first, in the names that the page already holds.
It shows what it finds, with one more choice: **None of these. Search the drug
references.** It asks a reference only after that choice, or when the catalog holds
nothing under the name. The product picker of the form that tracks a medication asks
the same references through its search box and its **Search online databases** link.

The app asks the references in this order, and stops at the first one that finds
something:

| Order | Reference | Asked when |
|---|---|---|
| 1 | RxTerms | Always |
| 2 | The openFDA NDC Directory, the product list of the United States Food and Drug Administration | RxTerms finds nothing or does not answer. It lists many products sold without a prescription. |
| 3 | RxNorm, by its approximate search | The first two find nothing or do not answer |

A reference that limits requests, or takes longer than 8 seconds, counts as not
answering. You pick one result, and the app fills in the brand name, the generic name and
the strength. You check them and save the form. Nothing reaches the catalog before that.

The lookup runs in the browser, from `static/medication_lookup.js`, and the product
search from `static/product_search.js`; both ask the references through
`static/drug_references.js`. A Tier 1 app has no
function that calls a network service, so the node itself never calls one. `app.toml`
lists the three addresses under `permissions.remote`, and Privatium shows that
permission when the app is installed. Every form works without the script. The lookup
is hidden until the script shows it.

The lookup sends the name you typed into the lookup box to the reference. It sends no
other field, no name of a person and no record.

Three columns of the `medication` table record where an entry came from.

| Column | Holds |
|---|---|
| `rxcui` | The RxNorm concept unique identifier (RxCUI) of the product. RxNorm gives every product a number. |
| `source` | The reference the entry was copied from: `rxterms`, `rxnorm` or `openfda_ndc`. Empty for an entry that was typed. |
| `retrieved_on` | The date the entry was copied. Empty in the starter catalog and for an entry that was typed. |

These rules hold for every entry:

- Two catalog entries never share an RxCUI and a package. Picking a product and a
  package that the catalog already holds uses the entry that is there.
- One product in two packages is two entries. A carton of 2 is another thing to refill
  than a carton of 6.
- The three columns stay with the entry through every change. A merge keeps the columns
  of the entry that stays.
- A copied entry is an ordinary entry. You can change its short name, give it other
  names and mark it as specialty.
- An entry that a list, a fill or an authorization uses cannot be removed.
- What the browser sends is untrusted, like any field of a form. The server checks the
  identifier, accepts a source only from its own list of three, and turns the route and
  the dose form into words of the catalog or leaves them out.

This table shows where the fields of each reference go.

| Catalog field | RxTerms | openFDA NDC Directory | RxNorm |
|---|---|---|---|
| Brand name | The brand at the end of `fullName` | `brand_name`, unless it repeats the generic name | The same as RxTerms, when RxTerms knows the product |
| Generic name | `fullGenericName`, up to the strength | `generic_name` | The name, up to the strength |
| Strength | The start of `STRENGTHS_AND_FORMS`, such as "10 mcg/ml" | `active_ingredients.strength` | The strength in the name |
| Route | `route` | `route` | The same as RxTerms |
| Form | `rxnormDoseForm` | `dosage_form` | The same as RxTerms |
| RxCUI | `RXCUIS` | `openfda.rxcui`, when the product lists exactly one | `rxcui` |

**Packages and the strength of a device.** A product that comes in a device, such as a
pen, a prefilled syringe or a nasal spray, is dispensed by the carton. For the
injections and the nasal products of the starter catalog, the script reads the labels
that makers filed with openFDA:

- It makes one entry for each size of carton, such as "2 Pack" and "6 Pack". A product
  whose only carton holds one device gets no package.
- It counts only the cartons of the same device and the same volume, because one label
  covers the pens and the vials of a drug.
- It shows the strength of one device where the label prints it so. RxTerms prints a
  prefilled syringe of 20 mcg in 0.5 mL as "40 mcg/mL". The catalog shows
  "20 mcg/0.5 mL", as the box does.
- It leaves out samples, and cartons of more than 12, which are made for clinics.

**Brands filed under a salt.** RxTerms files some brands under the salt of the drug, which
the lists of ingredients do not reach. Every brand of `tools/seed/preferred_brands.txt`
that no entry names is added with its own products.

Three limits are known:

- **Units.** A reference can print a strength in another unit than the label. RxTerms
  prints "0.05 mg" for a tablet that the label calls "50 mcg". For a strength below
  1 mg, the app reads the labels that makers filed with openFDA for the same product and
  the same amount. It shows micrograms when most of them print micrograms. The starter
  catalog also has a short list of drugs that are always labeled in micrograms, and
  one of drugs that are labeled in international units, such as the vitamins D, whose
  milligrams the builder turns into units. A strength whose labels cannot be read stays
  as the reference prints it. You can correct the strength before you save.
- **Brand names in the starter catalog.** A generic product takes the brand of the
  preferred brands list when it has one, or its only brand. A product with several brands takes
  none and answers to each brand as another name.
- **Package codes.** The openFDA NDC Directory lists products by National Drug Code
  (NDC). One product has many codes, one for each package and maker. The app stores
  none. They would need a table of their own, with one row per medication per code.

What was checked on 2026-09-27: each of the three references was called from this
repository's tools, answered, and allows calls from a browser page on another address.
The script was run outside a browser, against the three references, with names that the
first, the second and the third reference answer. No check ran it inside a browser.

#### Removing a record

Every **Remove** button opens a confirmation page first. The page names the record. It
also explains that Privatium hides the record and keeps the original line in its log.

The app refuses to remove a person, a medication, a pharmacy or a prescriber that other
records still use. It says how many records use it.

### Refill status rules

`v_active_medication` calculates the status from refill eligibility, physical supply,
and the node computer's local date. The app stores none of these calculated values.

| Refill status | Ordinary medication | Specialty medication |
|---|---|---|
| No fill | No supply date | The same |
| Overdue | Physical supply ran out before today | The same |
| Due | Eligibility has passed, is today, or is up to 3 days away | Up to 5 days away |
| Due soon | Eligibility is 4 to 7 days away | 6 to 10 days away |
| Not due | Eligibility is more than 7 days away | More than 10 days away |

Six reminder day counts cover refills and prior authorizations. Three further settings
cover early refills. Plans can override the household percent and frame.

#### The two dates

The **next fill date** estimates the earliest day a payer permits another fill.
**Lasts until** is when physical supply runs out. Every fill adds physical supply,
and a late fill starts from its own date without credit for the gap.

The payer's count follows the plan of the latest fill, including unknown payers and
excluding other named plans. It uses a rolling frame on the proposed refill date and
an allowance rounded down from the last fill's days supply.
Controlled medications count every fill across payers, without a frame limit.
Their household days early setting replaces the percent, initially with zero.
Zero-percent payers for ordinary medications wait for physical supply to run out.

There is no January 1 reset. The [data model](../data-model.md) gives the full rules,
frame boundary cases, and two worked examples. After eligibility passes with supply
left, the row reads "Fill now. Runs out in N days".

#### Groups on the Refills page

| Order | Group | Holds | Shown as |
|---|---|---|---|
| 1 | Overdue | Taking regularly, refill status Overdue | "Overdue by 4 days" |
| 2 | Due | Taking regularly, refill status Due | "Due today", "Due in 3 days" |
| 3 | Due soon | Taking regularly, refill status Due soon | "Due in 6 days" |
| 4 | New prescriptions to ask for | Taking regularly or as needed, no refill left, refill status Overdue, Due or Due soon | "No refills left", with the prescriber and the phone number |
| 5 | Prior authorizations | The latest prior authorization of an active medication has expired, or expires within 30 days | "Expired", "Due" within 14 days, "Due soon" within 30 days |
| 6 | As needed | Taking as needed | Both dates and the refills left, with no alert |
| 7 | Missing information | Taking regularly, with no fill or with a last fill that has no days supply | "Add a days supply to get a refill date" |
| 8 | Not due yet | Taking regularly, refill status Not due | Both dates |
| 9 | Paused | On hold or Not started | The status and both dates, with no alert |

A medication with the status No longer taking appears in no group.

A row in groups 1 to 3 with no refills left also says so. It names the prescriber and
shows the phone number, because the next step is a new prescription.

A fill with no days supply counts as 1 day in every view, so a report always has a date.
The medication still appears under Missing information until someone adds the number.

#### The rules in short

- Physical supply stacks across every fill. Gaps earn no credit.
- Refill eligibility uses the last payer's count, a rolling frame, and an early allowance.
- Overdue begins after physical supply ends. Due follows eligibility.
- Today is the node's local date.
- Default reminder counts are 3 and 7 days, or 5 and 10 for specialty medications.
- Only medications taken regularly raise refill alerts. Missing days supply counts as one day.
- Merged entries share their fill history.

### Accessibility plan

The target is the Web Content Accessibility Guidelines (WCAG) 2.2, level AA.

| Need | Design response |
|---|---|
| Status without color | Every status has words and an icon. The badge color repeats the meaning and never carries it alone. |
| Form labels | Every field has a visible label. Help text is tied to the field with `aria-describedby`. |
| Choices | A drop-down and its **Or type a new one** box share a group with one legend, so a screen reader announces them together. The medication box is one group, and its choices are a group of radio buttons inside it. |
| Suggestions | A text box with suggestions is an ordinary text box. It accepts any text, so it works where a browser or a screen reader does not announce the suggestions. |
| Form errors | Each error is text next to its field, announced with `role="alert"`. The form keeps what you typed. |
| Tables | Real tables with a caption and header cells. On narrow screens the rows stack, with explicit table roles so a screen reader still reads a table. |
| Review of pasted fills | Each result is a word with an icon. Each medication name and each pharmacy has its own heading and its own labeled fields. A summary at the top counts the fills and the new names. A message at the top says how many choices are open when the page comes back. |
| Keyboard | Every control is a link, a button or a form field. Disclosures use the native `<details>` element. The shell supplies the focus ring. |
| Pointer targets | Buttons use the shell's height of 44 CSS pixels. |
| Zoom and small screens | Forms are one column. Nothing has a fixed width. The layout reflows at 320 CSS pixels. |
| Repeated buttons | Each **Record fill** button carries hidden text that names its medication. |
| Headings | One `<h1>` on every page, with heading levels in order. |
| No JavaScript | Every save and every search is a plain form. Suggestions while you type come from the browser. The app ships two scripts: one shows the fields of a new record when you choose to add one, and one looks up a new medication. Every form works without them. |
| Lookup results | Each result is a button, so the keyboard reaches it. A status message says how many results came, from which reference, and what was filled in. Focus moves to the first field that was filled in. |
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
- **Guesses.** A close match in the medication box is a suggestion. The app saves
  nothing until you choose. A pasted name picks a medication only when the name and the
  strength are the same, and the review page shows that choice before anything is added.
- **Records added inside a form.** A person, a pharmacy, a prescriber or a medication
  that a form adds passes the same checks as in its own form. It is written in the same
  batch as the form's record, so a refused form adds nothing.
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
- **Starter catalog.** `lib/starter_catalog.lua` holds a starter catalog only, and no person.
- **Lookup.** The browser sends the name typed into the lookup box to a public drug
  reference, without cookies and without the address of the page. What comes back is
  shown as text, never as markup, and is checked by the server like any typed value.
- **Real records.** No record of a real household is in this repository. Synthetic data only, in the tests and the pages.

This design makes no claim of compliance with any health privacy law.

### What was checked

These checks ran from 2026-09-26 to 2026-09-27 with Privatium 0.3.
[How to run the tests](../how-to/run-the-tests.md) covers the first three rows.

| Check | Result |
|---|---|
| `privatium lint apps/meds` | 0 findings |
| Unit tests of the Lua modules | All passed |
| Smoke test of every screen over HTTP | All passed |
| `date('now', 'localtime')` inside the node | Returned the local time |
| Loading invented rows through the data API on the node's own address | Accepted |
| Loading the same rows a second time | Nothing appended |
| Loading a row that had changed since the first load | Refused with status 409. Nothing appended. |
| Reading the views with a SQLite library that lacks the decimal extension | Every view ran except the spending view |

No check drove a browser. [The compliance page](../compliance.md) lists what a person
still has to check by hand.

### Decisions made

These design decisions date from 2026-09-27.

| Subject | Decision |
|---|---|
| Refill alerts | Taking regularly only. The dates of the other active medications stay visible. |
| Empty days supply | Shown under Missing information. Counted as 1 day in views and reports. |
| Days supply of zero | Stays zero. |
| The two dates | Refill eligibility and physical supply exhaustion, using stacked supply without gap credit. |
| Date that drives the refill status | Eligibility drives due; physical supply exhaustion drives overdue. |
| Prior authorization | Every one names a person. |
| Medication names | One catalog entry for each product, a short name shown everywhere, and other names that the search understands. |
| Short name | The brand name, the generic name in brackets, then the strength. |
| Birth date | Kept, optional. |
| Choices and strength | Choices are picked or typed in the form. Strength is text, as the label prints it. |
| Day counts | Due at 0 to 3 days and due soon at 4 to 7. For a specialty medication, 0 to 5 and 6 to 10. |
| Readable view | `v_active_medication`, with the new column names. |
| Starter catalog | Medications that are common in the United States. The app loads it by itself when the catalog is empty. There is no separate sample data file. |
| Fills from a portal | Pasted as text, read by the app, reviewed, then added. |
| Amounts from a portal | What the plan paid and the deductible are shown in the review and not stored. |
| Portal names | A reader is named after its layout. No company name appears in this repository. |
| Refills left after a pasted fill | Lowered by one, never below zero. |
| A pasted fill for a medication that is not on the person's list | The review says so. Confirming adds the medication with the status Taking regularly. |
| Times and dates on screen | Local time, from the clock of the computer that runs the node. |
| Records a form needs | Every drop-down of people, pharmacies, prescribers and medications can add a new one in the same form. |
| Finding a medication | One box in the form, with suggestions while typing. No separate search page. |
| Pasted fills | The app matches each name, offers to link it to a medication or to add a new one, and offers to add the pharmacy it read. |
| Prior authorization form | The person and the medication are two fields. The first day comes before the expiration date. Only the expiration date is required. The form starts with the first day of the month and one year later. |
| Reminders for prior authorizations | Due soon at 30 days, due at 14 days, so a request has time to be decided. |
| Reminder to ask for refills | For medications taken regularly or as needed with no refill left. It follows the days of the refill reminders. |
| Prescription numbers in pasted fills | A number that an earlier fill has names the medication. A name that fits too makes it the choice. Hyphens and spaces do not count. |
| Fields that add a record | Hidden until **-- Add new --** is chosen in the drop-down. |
| Strength units | Micrograms where the label prints micrograms. |
| Packages | The package is part of the short name. One product in two packages is two catalog entries. |
| Strength of a device | The strength that the box prints for one device, not the amount in each mL. |
| Lookup order | The catalog first. A drug reference only when the catalog lacks the name. |
| Text boxes | They suggest the values that records already hold. |
| Household name | Removed. |
| Starter catalog | The ClinCalc top 200 and a second list of common medications, one entry per strength, plus entries written by hand for glucose monitors and supplies. |
| Lookup of a new medication | Built, and on for everyone. RxTerms first. The openFDA NDC Directory and RxNorm are asked when RxTerms finds nothing or does not answer. |
| What the lookup is for | Adding a medication. The app loads no catalog of a reference. |

### Build order

Each step ended with a clean `privatium lint`, passing tests and updated documentation.

1. Tables, views and the starter catalog, with the data model page. Done.
2. Setup screens for people, pharmacies, prescribers and the catalog. Done.
3. The medication search, the other names and the merge. Done.
5. Medications and the medication page. Done.
6. Record a fill, and History. Done.
7. Paste fills. Done, for one layout of portal page.
8. Refills. Done.
9. Authorizations. Done.
10. The printable medication list and the spending table. Done.
11. Adding records from inside a form, the medication box, suggestions in text boxes,
    and the review of pasted fills by name. Done.
12. The manual accessibility checks. **Planned.** [The compliance page](../compliance.md)
    lists them.
13. The lookup of a new medication in the drug references, and the starter catalog
    built from them. Done. See
    [The catalog and the drug references](#the-catalog-and-the-drug-references).
14. A check of the lookup inside a browser. **Planned.**
15. Tracked medications with their products, the search and the Restart button of the
    Medications page, the remembered person tab, and the icons of the dose forms. Done.

#### Tracked medication decisions, October 3, 2026

| Subject | Decision |
|---|---|
| What a person takes | A tracked medication with a preferred name, standing for one or more catalog products. Fills and prior authorizations point at it. |
| Products per person | A product belongs to one tracked medication of a person. A preferred name is unique within a person. |
| Preferred name | Starts as the full name of the first product, and it can be changed in the form. |
| The product of a fill | Kept on the fill, so carton sizes stay apart in the history. |
| Navigation | Medications first, with the capsule icon; Refills second, with the bag icon. |
| Remembered person | The browser keeps the person tab chosen last, by id, until profiles arrive. |
| Form icons | One Bootstrap icon per dose form, labelled with the form; a hand-drawn syringe for injections. |
| Portal wording | "Copy refill history from patient portal", with a plain explanation of what to copy. |

#### Product picker decisions, October 3, 2026

| Subject | Decision |
|---|---|
| Finding a product | One search box with a Find button. Enter searches. Results are a paged list with a check box each: 10 a page on a wide screen, 5 on a phone, 25 at most. |
| Online databases | Asked at once when the catalog has nothing, and on request through a link under the search box. |
| Adding to the catalog | The disclosure reads "Not in the list? Add a medication to the catalog" and opens on the name fields. Similar products are searched while the name is typed, with a turning ring and the words "Searching for similar products...". |
| Drop-downs | Route, form and package type are drop-downs with a choice to type a new value. The browser's suggestion list is kept for free text only. |
| Products list | Hidden until a product is on the list. The box then folds into "Add another product" with the note "(e.g. different pack size of the same medication)". |
| Notes | A free-text notes field on a tracked medication and on a fill. |
| Dose forms | Gummy is a form of its own, with the cookie icon. |

#### Refill rule decisions, October 1, 2026

| Subject | Decision |
|---|---|
| Plans | Reusable records with optional percent and frame overrides; no member details. |
| Current payer | A person's default starts new fills; historical fills keep their payer. |
| Unknown payer | Counts toward the last payer's history, to avoid suggesting an unsafe early refill. |
| Controlled supply | Every fill counts across payers, with no frame limit and zero early days by default. |
| Cash and over-the-counter | Zero percent waits until physical supply runs out. |
| Frame special values | Zero counts the last fill only; 3650 counts every fill, even beyond ten years. |
| Catalog marks | Controlled comes from openFDA schedules; specialty is a name/list suggestion that can be corrected in the catalog. |

### Conclusion

You now know what the app shows, how it decides that a refill is due, and what is
still planned. Read the [data model](../data-model.md) next.

### Additional resources

- [Using the app](../usage.md)
- [Data model](../data-model.md)
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
