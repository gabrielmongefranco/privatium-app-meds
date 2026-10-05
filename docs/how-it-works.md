<!--
This file is part of Prescription Tracker
docs/how-it-works.md
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: How the app works, in plain words: how it picks the refill dates and the backup
         supply, how it estimates insurance rules, how it matches medicine names, where
         the catalog comes from, and what it keeps private.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## How the app works

[Back to project README](../README.md)

This page explains the thinking behind what the app shows you: how it picks a refill
date, why it keeps a small backup, how it guesses what your insurance will allow, and
what it keeps private. It is for families who want to trust the dates they see, and for
anyone curious about the rules. The [user guide](usage.md) shows the screens, and
[Words to know](glossary.md) explains the terms.

### What the app is for

Families who manage several long-term medicines face the same problems again and again.
Medicines run out at awkward times. The insurance plan refuses a refill that is "too
soon". A prescription runs out of refills right when you need it. And an insurance
approval ends without warning.

Prescription Tracker keeps a record of every fill and works out what comes next. It aims
for a middle path: refill early enough to keep a few days of medicine on hand, but not
so early that the plan refuses to pay or the medicine piles up at home.

### The two dates on every medicine

For each medicine, the app works out two dates from the fills you recorded.

**Lasts until** is the day your recorded medicine would run out. Each fill adds its days
supply. If you refill early, the new supply starts when the old one ends, so early fills
add up. If you refill late, the days in between are lost. The app doesn't assume you had
medicine you never recorded.

**Next fill date** is the day the app suggests you refill. It is worked out in two
steps:

1. **Keep a backup.** The app counts back from "lasts until" to leave a backup supply.
   The backup is 15 percent of the last fill's days supply, but never less than 7 days,
   or 10 days for a specialty medicine. Specialty medicines often come by mail and take
   longer.
2. **Wait for the plan.** If your plan wouldn't pay yet on that day, the app moves the
   date later, to the first day it expects the plan to pay.

So the next fill date is never before your plan will pay, and it never asks you to
refill while you still have much more than the backup.

#### An example

Say you picked up a 90-day supply on August 25, and you still had some medicine left from
earlier fills. Your recorded medicine now lasts until December 28.

- The backup is 15 percent of 90 days, which is 13 days.
- 13 days before December 28 is December 15.
- With a 25 percent early-fill rule, the plan would pay from December 6.
- December 15 is later, so the next fill date is **December 15**.

From December 12 the refill shows as due, 3 days ahead. Once December 15 has passed, the
row reads "Fill now. Runs out in 12 days", and it counts down. It only becomes overdue
after December 28, when the medicine is gone.

### How the app estimates your insurance rules

Most plans pay for a refill only once most of the last fill is used. The app copies the
way plans usually count:

- It looks at the fills paid by the same plan as the last fill, plus fills with no plan
  recorded. Fills paid by another plan, or in cash, still count as medicine on hand, but
  not toward this plan's count.
- It looks back over a set window of days, usually 180. Older fills drop out of the
  count.
- It allows a refill when what is left of the plan's fills is no more than a share of the
  last fill. Usually that share is 25 percent. For a 30-day fill that is 7 days early,
  and for a 90-day fill it is 22.

You can change these numbers for each plan, or for the whole household, in Setup. Set the
early fill percent to 0 for cash or over-the-counter purchases. The app then waits until
the medicine runs out.

These dates are estimates. Your plan's real rules may differ, and a pharmacy may still
refuse a claim. When a refill is refused, write down the date your pharmacy gives you,
and adjust the plan's numbers if it keeps happening.

**Controlled medicines** follow stricter rules, because the law limits how early they can
be filled. The app counts every fill, whoever paid, with no time window. By default it
allows no days early.

There is no reset on January 1. The time window carries the history from one year into
the next.

### Reminders and the Refills page

Only medicines with the status **Taking regularly** raise refill reminders. Medicines
taken as needed, on hold or not started still show their dates, but quietly, further
down the page.

| Status on the Refills page | When |
|---|---|
| Overdue | The recorded medicine has run out. |
| Due | The next fill date is 3 days away or fewer, or has passed. For a specialty medicine, 5 days. |
| Due soon | The next fill date is 4 to 7 days away. For a specialty medicine, 6 to 10. |
| Not due | The next fill date is further away. |

The page also lists two kinds of paperwork that take time:

- **New prescriptions to ask for.** When no refills are left and the next fill is near,
  the page names the prescriber and shows their phone number. Some prescribers only take
  this request from the patient, not from the pharmacy.
- **Prior authorizations.** The page warns you 30 days before an insurance approval ends,
  and marks it due at 14 days. That leaves time for the prescriber to ask and the plan to
  decide.

If a fill has no days supply, the app counts it as one day so it can still show a date.
The medicine stays under **Missing information** until you add the number.

### Medicines and their names

One medicine can have many names. A label may print the brand, a bill the generic name,
and your family may use a nickname. The app keeps one catalog entry for each product,
with any number of other names.

- **The catalog** is the list of products the app knows. Each product is one medicine at
  one strength, form and package. A 2-pen box and a 6-pen box are two products, because a
  pharmacy fills and bills them separately.
- **A tracked medication** is a medicine a person takes. It has the name you prefer, and
  it points to one or more products. When the same medicine comes in two box sizes, both
  products belong to one tracked medication, so every fill counts together.

When you search, the app compares what you typed with every name, ignoring capital
letters and punctuation. If nothing matches exactly, it offers close names under **Did
you mean one of these?** It never picks a close match by itself. Some different medicines
have names that look alike, and a wrong guess could be dangerous.

When you copy fills from a portal, the app picks a medicine for you only in two cases. It
picks one when it has seen that exact name before. It also picks one when the portal's
name starts with the brand or generic name of exactly one product and includes its exact
strength. Even then, the review page shows the choice before anything is saved.

### Where the catalog comes from

The app comes with about 2,850 common products, plus 619 other names for them. They
include:

- the 200 medicines most prescribed in the United States, at every strength, from the
  ClinCalc DrugStats list;
- a second list of common medicines that aren't in the top 200;
- glucose monitor sensors and other supplies that drug lists don't include;
- syringes and needles in many sizes.

The strengths, forms and brand names come from RxTerms, a public list of the United
States National Library of Medicine. The catalog also suggests which products are
**specialty** or **controlled**. Plans differ, so check these marks and change them if
your plan says otherwise.

The catalog names products. It is not medical advice, and it says nothing about doses.
Some brand names in it are no longer sold. They stay because older labels still use
them. Always check the label in your hand.

When a medicine isn't in the catalog, the app can look it up online, in your browser. It
asks three public references in turn and stops at the first that answers: RxTerms, the
openFDA product list of the Food and Drug Administration, and RxNorm. You pick one
result, check what it filled in, and save. Nothing is added until you save.

### Your privacy

**Where your records live.** Everything you type stays on the computer that runs
Privatium, as plain text files. There is no account and no cloud service. To back up the
app, you copy a folder.

**What leaves your computer.** Only one thing: when you search the online drug
references, your browser sends the name you typed in the search box to those public
services. It sends no person's name, no record and no cookie. The services may see your
internet address. If you never use the online search, nothing leaves your computer.

**What you should protect.** Privatium doesn't encrypt its files. Anyone who can open
them can read your family's medicines. So:

- turn on disk encryption and use a password on the computer;
- keep backups somewhere safe, and encrypt them if you can;
- on a shared device, close the browser when you are done;
- treat a printed medication list like any paper with health details.

**What removing does.** Removing a record hides it in the app. Privatium keeps the
original line in its history on your computer. To destroy the records for good, delete
Privatium's data folder and every copy of it.

**Using more than one device.** If two devices change the same record before they
connect, one of the two changes is kept.

This app makes no claim to meet any health privacy law. The
[compliance page](compliance.md) lists what has been checked and what hasn't.

### Conclusion

You now know how the app picks its dates, why it keeps a backup, how it treats insurance
rules as estimates, and what stays private. The [user guide](usage.md) puts this to work,
screen by screen.

### Additional resources

- [User guide](usage.md)
- [Words to know](glossary.md)
- [Compliance](compliance.md)
- [Data model](data-model.md), with the exact rules for developers
- [ClinCalc DrugStats, The Top 200](https://clincalc.com/DrugStats/Top200Drugs.aspx)
- [RxTerms, National Library of Medicine](https://clinicaltables.nlm.nih.gov/apidoc/rxterms/v3/doc.html)
- [openFDA NDC Directory](https://open.fda.gov/apis/drug/ndc/)
- [Privatium's security page](https://github.com/gabrielmongefranco/privatium/blob/main/docs/security.md)

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
