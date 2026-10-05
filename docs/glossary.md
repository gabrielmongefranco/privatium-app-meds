<!--
This file is part of Prescription Tracker
docs/glossary.md
Author(s): Gabriel Mongefranco
Created: 2026-10-05
Last Modified: 2026-10-05
Summary: Plain explanations of the pharmacy, insurance and app words that the app and
         its documentation use.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## Words to know

[Back to project README](../README.md)

Pharmacies and insurance companies use a lot of special words. This page explains the
ones you will see in Prescription Tracker, in everyday language. You don't need to learn
them all before you start. Come back here when a word on a screen is new to you.

### Prescriptions and the pharmacy

| Word | What it means |
|---|---|
| **Prescription** | A doctor's order for a medicine. It says what to take, how much, and how many times the pharmacy may fill it. |
| **Prescriber** | The doctor, nurse practitioner or other clinician who wrote the prescription. |
| **Fill** | One time the pharmacy gives you a medicine, whether you pick it up or it comes by mail. |
| **Refill** | Another fill of the same prescription. |
| **Refills left** | How many more times the pharmacy may fill the prescription. The label usually prints it. When it reaches zero, you need a new prescription. |
| **Prescription number** or **Rx number** | The number the pharmacy gives a prescription. It is printed on the label. A new prescription gets a new number. |
| **Days supply** | How many days one fill should last if you take it as directed. The pharmacy label or receipt shows it. |
| **Quantity** | How much medicine was in the fill, such as 30 tablets or 2 pens. |
| **Pharmacy** | The store, mail-order service or supplier that gives you the medicine. |
| **Specialty pharmacy** | A pharmacy that handles medicines that are hard to make, store or ship, such as many injections. These often take several days to arrive. |
| **NPI** | National Provider Identifier. A 10-digit number that every prescriber and pharmacy in the United States has. Patient portals often show it. |
| **Over the counter (OTC)** | A medicine you can buy without a prescription. |

### Insurance

| Word | What it means |
|---|---|
| **Insurance plan** or **payer** | Whoever pays for a fill. Usually your insurance plan. When you pay the whole price yourself, the app calls it **Cash**. |
| **Claim** | The request the pharmacy sends to your plan to get paid for a fill. Each claim has a claim number. |
| **Deductible** | The amount you must pay yourself each year before your plan starts to pay. |
| **Patient portal** | Your plan's or your pharmacy's website, where you can see the fills it paid for. |
| **Early refill** | Most plans won't pay for a refill until most of the last fill is used up. Pharmacies call an early request "refill too soon". The app estimates the first day your plan will pay. |
| **Early fill percent** | How much of the last fill may be left when the plan pays for the next one. Many plans allow about 25 percent. For a 30-day fill, that is about 7 days early. |
| **Supply frame** | The number of past days the plan looks at when it adds up your fills. Many plans look back about 180 days. |
| **Prior authorization** | An approval your plan gives before it will pay for some medicines. It lasts for a set time, often a year, and then you need a new one. Your prescriber asks for it. |
| **FSA** | A flexible spending account. Money set aside from your pay, before taxes, for health costs such as medicines. You usually send proof of what you paid to get it back. |
| **HSA** | A health savings account. Like an FSA, but it goes with some high-deductible plans and the money carries over from year to year. |

### Kinds of medicines

| Word | What it means |
|---|---|
| **Brand name** | The name a company sells a medicine under, such as Lipitor. |
| **Generic name** | The name of the drug itself, such as atorvastatin. Many companies can sell the same generic. |
| **Strength** | How much drug is in one tablet, capsule, puff or milliliter, such as 10 mg or 90 mcg/puff. |
| **Dose form** | What the medicine looks like: a tablet, capsule, liquid, inhaler, injection and so on. |
| **Route** | How the medicine goes into the body, such as by mouth or by injection. |
| **Package** or **carton** | Some medicines come in boxes of a set size, such as a 2 Pack of pens. A 2 Pack and a 6 Pack are different products to a pharmacy. |
| **Specialty medication** | A medicine that is costly or hard to handle, often from a specialty pharmacy. The app reminds you earlier for these, because they take longer to arrive. |
| **Controlled medication** | A medicine with extra legal limits, such as some pain or sleep medicines. Pharmacies usually won't fill it early, even if your plan would pay. |
| **Release form** | Some tablets let the drug out slowly, marked XR, ER or 24 HR, or after the stomach, marked DR. These are different products from the plain tablet. |

### Words the app uses

| Word | What it means |
|---|---|
| **Catalog** | The list of medicine products the app knows about. It comes with about 2,850 common products. The catalog doesn't say who takes what. |
| **Product** | One entry in the catalog: one medicine at one strength, form and package. |
| **Tracked medication** | A medicine that a person in your family takes, shown on the Medications page. It points to one or more catalog products. |
| **Preferred name** | The name you want to see for a tracked medication, such as "Metformin 1,000 mg". You can change it any time. |
| **Short name** | The name the catalog gives a product, in the form "Brand (Generic) strength", such as "Lipitor (Atorvastatin) 40 mg". |
| **Other names** | Extra names a product answers to, such as an abbreviation or the way a pharmacy spells it. |
| **Status** | Whether a person is taking a medicine: Taking regularly, Taking as needed, On hold, Not started or No longer taking. |
| **Next fill date** | The day the app suggests you refill, so a small backup is still on hand. It is never before your plan will pay. |
| **Lasts until** | The day all the medicine you have recorded would run out. |
| **Backup supply** | A few days of medicine kept on hand in case a refill is late. The app keeps about 15 percent of a fill, and at least 7 days (10 for a specialty medication). |
| **Due** and **Due soon** | How close a refill is. By default, a refill is due when its next fill date is 3 days away or fewer, and due soon at 4 to 7 days. |
| **Overdue** | The recorded supply has run out. |
| **Time period** | A filter on the History page, such as last month or one whole year. Weeks start on Sunday. |
| **Year so far** | This year's total on the Reports chart. The year isn't over, so its bar has an outline and the average leaves it out. |
| **Spending report** | The printable report on the Reports tab. It lists what you paid for each fill and adds it up by person, year and medicine. |

### Words about the computer side

| Word | What it means |
|---|---|
| **Privatium** | The free program that runs this app on your own computer. It keeps your records there instead of on a company's servers. |
| **Node** | One copy of Privatium running on one computer. |
| **RxTerms** and **RxNorm** | Public lists of medicines kept by the United States National Library of Medicine. The app uses them to look up a medicine that isn't in its catalog. |
| **openFDA** | A public database of the United States Food and Drug Administration. The app uses its product list for the same kind of lookup. |

### Conclusion

You now know the words that the screens use. The [user guide](usage.md) shows how to do
each task, and [How the app works](how-it-works.md) explains how the app picks the
dates it shows.

### Additional resources

- [User guide](usage.md)
- [How the app works](how-it-works.md)
- [Documentation index](README.md)

[Back to project README](../README.md)

----

Copyright © 2026 Gabriel Mongefranco
