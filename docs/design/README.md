<!--
This file is part of Prescription Tracker
docs/design/README.md
Author(s): Gabriel Mongefranco
Created: 2026-09-26
Last Modified: 2026-09-27
Summary: Design of the app's screens: tasks, the medication box, adding records from
         inside a form, pasting fills from a portal, the catalog as a copy of a drug
         reference, refill status rules, accessibility and privacy plans, what was
         checked, and the owner's decisions.
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
otherwise. The [import page](import.md) covers the owner's legacy database.

### Goals

- Replace hand edits in a database tool with forms that check what you type.
- Show what needs a refill first, in plain words.
- Keep the refill dates that the legacy database calculates.
- Work with a keyboard, a screen reader and a phone.
- Keep every record on the owner's node. The node calls no network service. The browser
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

1. The heading **Refills** and a greeting.
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

When the app holds no people yet, the page shows a welcome message with a link that
adds a person.

#### Record a fill

The form opens from a row's **Record fill** button, or from the button at the top of the
home page. From a row, the person and the medication are already chosen. The form copies
five values from the last fill of that medication, so most fills need a date and an
amount only. From the button at the top, the form starts with
[the medication box](#the-medication-box).

| Field | Required | Starts as | Check |
|---|---|---|---|
| Who is it for | Yes | The row's person | A person in the app, or the name of a new one |
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

#### The medication box

A medication can be known by several names. A label may print the brand name, a
statement may print the generic name, and a person may use an abbreviation. The app keeps
one catalog entry for the product and any number of other names for it. The catalog is
the list of products the app knows. It does not say who takes them.

Every form that needs a medication holds the same box. No form sends you to another page
to find a medication or to add one. The box has three parts:

| Part | What it does |
|---|---|
| **Choose one that is already in use** | A drop-down of the medications that are on a list or have a fill |
| **Type a name to search the catalog** | A text box that suggests names while you type. It offers every short name and every other name. |
| **Add a new medication** | Fields for the brand name, the generic name, the strength, the package and the specialty mark. The app builds the short name. |

The typed name is compared with the short name, the generic name, the brand name and the
other names. Capital letters, punctuation and extra spaces do not matter.

| What you type | What the app does |
|---|---|
| A name that exactly one medication answers to, such as "exm" when it is another name of one product | Picks that medication and saves the form |
| A name that several medications answer to, such as "exampline" | The form comes back and lists them, so you pick the strength you mean |
| A name close to one it knows, such as "Examplal" | The form comes back and offers the closest matches |
| A name it does not know | The form comes back and opens **Add a new medication** |

When more than one part is filled in, the more deliberate act wins: the fields of a new
medication, then the typed name, then the drop-down.

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

This page lists what each person takes. It groups the rows by status, in this order:
Taking regularly, Taking as needed, On hold, Not started. A closed disclosure holds the
rows with the status No longer taking.

Each row shows the medication, the instructions, when to take it, what it is for, the
prescriber, the refill status and the next fill date. The page has two actions: **Add a medication** and
**Print list**. The second appears when one person is selected.

The form that adds a medication is one page. It starts with
[the medication box](#the-medication-box) and the person. It then asks for the status,
the instructions, when to take it, what the medication is for and the refills left. It
ends with the prescriber, the pharmacy and the type. The person, the prescriber and the
pharmacy can each be a new one, added by name.

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

This page lists the pharmacies and the prescribers. Each entry shows the name, the
clinic, the phone and fax numbers, the address, the email address, the website and the
National Provider Identifier (NPI). A phone number is a link that starts a call on a
phone. A website is a link only when it starts with `http://` or `https://`.

#### Setup

This page links to three places:

- **People**: the household members.
- **Medication catalog**: every product the household has used, with its other names.
  The sample data adds a starter catalog of common medications.
- **Reminder settings**: the five day counts in the refill status rules.

The app asks for no household name.

A catalog entry has a **Specialty** checkbox. A specialty medication takes longer to
arrive, so its refill is due earlier.

Two catalog entries that are the same product can be merged. Merging moves the fills,
the list entries, the prior authorizations and the other names from one entry to the
other. It then hides the emptied entry. The page shows what will move and asks you to
confirm.

#### Choices in forms

Five fields offer choices: the route, the form, the package type, the medication type,
and when to take it. Each one is a drop-down. Its second choice is **-- Add new --**,
which shows a text box for the new choice.

The choices are a built-in starter list plus every value that your records already use.
A value that you type becomes a choice as soon as a record uses it. A misspelled choice
goes away once no record uses it. No separate screen manages the choices.

A field that points to a person, a pharmacy or a prescriber works the same way. Its
drop-down has the choice **-- Add new --**, which shows a text box for the name. The
drop-down of the medication box has **-- Find another or add new --**, which shows the
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
| The starter catalog | About 2,507 entries, loaded once into an empty app |
| The lookup in a form | One entry at a time, when you add a medication the catalog lacks |
| Your own typing | Anything else |

The app loads no catalog of a drug reference. The lookup is for adding a medication, and
it copies only the entry you pick.

**The starter catalog** holds three groups of entries:

- The 200 drugs most prescribed in the United States in 2024, from the ClinCalc DrugStats
  list, each at every strength and form that RxTerms lists.
- The drugs of the owner's list that ClinCalc does not rank, at every strength too.
- Entries written by hand for products that no drug reference holds, such as continuous
  glucose monitors, alcohol prep pads and compounded mixes.
- Syringes and needles, one entry for each volume, gauge and length.

RxTerms is a drug vocabulary of the United States National Library of Medicine, made for
entering prescriptions. [How to build the starter catalog](../how-to/build-the-starter-catalog.md)
describes the script that writes the file.

**The lookup** sits inside **Add a new medication**, in the medication box. You type a
name and choose **Look up**. The app looks in its own catalog first, in the names that
the page already holds. It shows what it finds, with one more choice:
**None of these. Search the drug references.** It asks a reference only after that
choice, or when the catalog holds nothing under the name.

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

The lookup runs in the browser, from `static/medication_lookup.js`. A Tier 1 app has no
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
  catalog also has a short list of drugs that are always labeled in micrograms. A
  strength whose labels cannot be read stays as the reference prints it. You can correct
  the strength before you save.
- **Brand names in the starter catalog.** A generic product takes the brand of the
  owner's list when it has one, or its only brand. A product with several brands takes
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
- **Sample data.** `sample/seed.jsonl` holds a starter catalog only, and no person.
- **Lookup.** The browser sends the name typed into the lookup box to a public drug
  reference, without cookies and without the address of the page. What comes back is
  shown as text, never as markup, and is checked by the server like any typed value.
- **Import.** The [import page](import.md) keeps real records out of this repository.

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
still has to check by hand.

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
| Starter catalog | The ClinCalc top 200 and the owner's list, one entry per strength, plus entries written by hand for glucose monitors and supplies. |
| Lookup of a new medication | Built, and on for everyone. RxTerms first. The openFDA NDC Directory and RxNorm are asked when RxTerms finds nothing or does not answer. |
| What the lookup is for | Adding a medication. The app loads no catalog of a reference. |

### Build order

Each step ended with a clean `privatium lint`, passing tests and updated documentation.

1. Tables, views and the starter catalog, with the data model page. Done.
2. Setup screens for people, pharmacies, prescribers and the catalog. Done.
3. The medication search, the other names and the merge. Done.
4. The one-time import. Done. The script is kept outside this repository. See the
   [import page](import.md).
5. Medications and the medication page. Done.
6. Record a fill, and History. Done.
7. Paste fills. Done, for one layout of portal page.
8. Refills, as the home page. Done.
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

### Conclusion

You now know what the app shows, how it decides that a refill is due, and what is
still planned. Read the [data model](../data-model.md) next, then the
[import page](import.md).

### Additional resources

- [Using the app](../usage.md)
- [Data model](../data-model.md)
- [Import of the legacy database](import.md)
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
