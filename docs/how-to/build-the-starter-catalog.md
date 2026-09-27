<!--
This file is part of Prescription Tracker
docs/how-to/build-the-starter-catalog.md
Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Summary: How to build the starter catalog of the sample data, what it is built from, and
         the licenses of its sources.
Notes: See README file for documentation and full license information.

Copyright © 2026 Gabriel Mongefranco

Licensed under the GNU Free Documentation License v1.3 or later.
See <https://www.gnu.org/licenses/fdl-1.3.html>. See README for full license information.
-->

# Prescription Tracker

## How to build the starter catalog

[Back to project README](../../README.md)

This page shows how to rebuild `apps/meds/sample/seed.jsonl`, the starter catalog that an
owner can load into an empty app. It is for developers. You need it when you add a drug
to the lists, or when you want newer strengths from the drug reference.

Nobody who only uses the app has to do this. The file is part of the repository.

### What the catalog is built from

| File in `tools/seed/` | Holds |
|---|---|
| `clincalc_top200.txt` | The 200 drugs most prescribed in the United States in 2024, by ingredient |
| `clincalc_names_in_rxterms.txt` | The few drugs of that list that RxTerms files under another name |
| `more_ingredients.txt` | More drugs, by ingredient |
| `preferred_brands.txt` | The brand a short name shows when a drug has several brands. A brand of this list that no entry names is added with its own products. |
| `labeled_in_micrograms.txt` | Drugs whose labels print every strength up to 1 mg in micrograms |
| `supplies.txt` | Syringes and needles, by family. The script makes one entry for each volume, gauge and length. |
| `by_hand.jsonl` | Entries written by hand: the first catalog of the project, and products that no drug reference holds, such as continuous glucose monitors |

RxTerms is a drug vocabulary of the United States National Library of Medicine. RxNorm is
its drug list, which gives every product a number.

### What you need

| Tool | Note |
|---|---|
| Python 3.8 or newer | The script uses the standard library only |
| A connection to the internet | The script asks two services of the National Library of Medicine, and openFDA |

### Steps

1. Change the lists in `tools/seed/`, if you want another drug in the catalog. Add one
   line with the name of the ingredient to `more_ingredients.txt`. For another size of
   syringe or needle, change `supplies.txt`. The top of that file explains its format.
2. Run the script from the root of the repository:

   ```sh
   python3 tools/build_seed.py
   ```

   The first run asks the services about 4,500 times and takes a few minutes. The script
   keeps every answer in a folder for temporary files. A second run asks only for what
   is new.

3. Read the last lines. They count the entries, and they name every drug that RxTerms
   does not hold:

   ```text
   build_seed: 61 entries written by hand, 229 syringes and needles, 2217 entries from RxTerms, 454 brand names as other names
   ```

4. Run the three checks in [How to run the tests](run-the-tests.md). The smoke test loads
   the new file and reads its counts from it.
5. Update the counts in [the data model](../data-model.md) and
   [the usage page](../usage.md), if they changed.

### What the script does

1. It reads the lists and drops a drug that is on two of them.
2. It asks RxTerms for every product of each drug: one for each strength and form.
3. It asks RxNorm for the brand names of each product.
4. It puts a strength below 1 mg into the unit of the label. It reads the labels that
   makers filed with openFDA for the same product and the same amount, and uses
   micrograms when most of them print micrograms. A drug on the list of drugs labeled in
   micrograms needs no count.
5. It adds the products of every preferred brand that no entry names yet.
6. For an injection or a nasal product, it reads the cartons on the labels of openFDA.
   It makes one entry for each size of carton, and shows the strength of one device
   where the label prints it so.
7. It builds one catalog entry for each product and package. The short name is the brand name, the
   generic name in brackets, and the strength.
8. It leaves out a product that an entry written by hand already covers, and gives that
   entry the number of the product.
9. It makes every short name different. Two products with one name and one strength get
   their form or their device added, such as "Pen Injector 3 mL".
10. It makes the syringes and needles from `supplies.txt`. It asks no service for them.
11. It writes the entries written by hand first, then the syringes and needles, then
    the others by name.

The same lists and the same answers always give the same file.

### What the script sends

The script sends names of drugs and numbers of products to the three services. It sends
nothing about any person, and it reads no record of the app.

### Sources and licenses

| Source | Used for | Terms |
|---|---|---|
| ClinCalc DrugStats, The Top 200 of 2024 | The names of the 200 drugs | Creative Commons Attribution-ShareAlike 4.0 International (CC BY-SA 4.0) |
| RxTerms and RxNorm, National Library of Medicine | Strengths, forms, brand names and product numbers | Public data. The terms ask for a notice. |
| openFDA NDC Directory, Food and Drug Administration | The unit and the strength that labels print, and the sizes of the cartons | Public data |

The Credits section of the project README names these sources. The file
`tools/seed/clincalc_top200.txt` holds the full citation of the ClinCalc list.

Recommended: ask someone who knows licenses whether a file that mixes a CC BY-SA list
with the project's own license needs anything more. This page makes no claim about that.

### Known limits

- openFDA answers 1,000 requests a day from one address without a key. A first run asks
  it about 700 times. The answers are kept, so a later run asks for little.
- The cartons come from the labels that makers filed. A carton that no label lists has
  no entry. Add it in the app, or write it into `by_hand.jsonl`.

- A strength below 1 mg stays in milligrams when openFDA holds no label for the product,
  or when as many labels print milligrams as micrograms.
- The syringes and needles name sizes, not brands. Some sizes on the list are rare, and
  a maker may not sell them. The list was not checked against the boxes of any maker.
- The strengths of compounded mixes differ from pharmacy to pharmacy. The two entries
  written by hand hold one strength each. Check them against your own label.
- ClinCalc groups several magnesium products under one name. The catalog leaves that
  group out.

### Conclusion

You can now rebuild the starter catalog and say where each of its entries came from.

### Additional resources

- [App design](../design/README.md#the-catalog-and-the-drug-references)
- [Data model](../data-model.md)
- [How to run the tests](run-the-tests.md)
- [RxTerms search, National Library of Medicine](https://clinicaltables.nlm.nih.gov/apidoc/rxterms/v3/doc.html)
- [ClinCalc DrugStats, The Top 200](https://clincalc.com/DrugStats/Top200Drugs.aspx)

[Back to project README](../../README.md)

----

Copyright © 2026 Gabriel Mongefranco
