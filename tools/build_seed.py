#!/usr/bin/env python3
"""
Summary: Builds apps/meds/lib/starter_catalog.lua, the starter catalog. It reads lists of
         drugs by ingredient, asks RxTerms for every strength of each drug, asks RxNorm
         for the brand names, and adds the entries that were written by hand and the
         syringes and needles.

This file is part of Prescription Tracker
tools/build_seed.py

Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-10-03
Notes: See README file for documentation and full license information.

Usage, from the root of the repository:
    python3 tools/build_seed.py [--cache FOLDER]
The script sends drug names and RxNorm identifiers to two services of the United States
National Library of Medicine and to openFDA, and nothing else. It keeps their answers in the cache
folder, so a second run asks for nothing it already has.
Exit codes: 0 the seed was written, 1 a service did not answer, 2 an input is missing.
"""

# Copyright © 2026 Gabriel Mongefranco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.

__author__ = "Gabriel Mongefranco"
__copyright__ = "Copyright (C) 2026 Gabriel Mongefranco"
__license__ = "GPLv3 or later"
__date__ = "2026-09-27"

import argparse
import concurrent.futures
import decimal
import hashlib
import json
import os
import re
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import starter_lua  # noqa: E402  The module writer, beside this script

### Load Configuration ###
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = os.path.join(ROOT, "tools", "seed")

RXTERMS_SEARCH = "https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search"
RXNAV = "https://rxnav.nlm.nih.gov/REST"
OPENFDA_NDC = "https://api.fda.gov/drug/ndc.json"
LABELS_MAX = 100                   # Products of openFDA read for the unit of one strength
MICROGRAMS_IN_A_MILLIGRAM = 1000
REQUEST_TIMEOUT_SECONDS = 30
REQUESTS_AT_ONCE = 6               # Requests that wait for an answer at the same time
SECONDS_BETWEEN_REQUESTS = 0.4     # For each of them. RxNav asks for 20 requests a second or fewer.
SEARCH_RESULTS_MAX = 500           # The most results one RxTerms search returns
SOURCE_NAME = "rxterms"            # The value of medication.source for a copied entry
ALIASES_MAX = 5                    # A drug with more brands than this gets none as other names
ID_PREFIX_MEDICATION = "01J8MEDS0000RX"   # 14 characters; the RxNorm identifier fills the rest
ID_PREFIX_PACK = "01J8MEDS0000RP"         # For an entry of one package; the identifier and the count follow
ID_PREFIX_ALIAS = "01J8MEDS0000AK"
ID_PREFIX_SUPPLY = "01J8MEDS0000SP"       # The family, volume, gauge and length follow
SUPPLY_FORM = "Supplies"           # The value of medication.form for a syringe or a needle
SUPPLY_PARTS = 5                   # The parts of one line of the list of supplies
NONE_OF_IT = "-"                   # In the list of supplies: the family has no such part
MILLIMETRES_IN_AN_INCH = decimal.Decimal("25.4")
RXCUI_DIGITS_IN_PACK_ID = 9        # The rest of the id of a package holds the count
PACK_MAX = 12                      # A carton of more units than this is made for clinics
PACK_TYPE = "Pack"                 # The package type of an entry of one package
NEAR = decimal.Decimal("0.03")     # Two amounts this close are the same; labels round
ID_LENGTH = 26                     # A ULID

# The units a strength is written in. A number followed by one of these opens the text
# that RxTerms prints for a product, as in '10 mcg/ml Cartridge 1 ml'.
STRENGTH = re.compile(
    r"^\s*([\d.,]+(?:-[\d.,]+)*\s?(?:%|(?:mg|mcg|g|ml|unt|meq|mmol)\b(?:/[\d.,]*\s?[a-z]+)?))\s*(.*)$",
    re.IGNORECASE)

# A strength below 1 mg, alone or for each unit of volume: '0.05 mg', '0.01 mg/mL'.
# Only such a strength may be printed in micrograms on the label.
SMALL_STRENGTH = re.compile(r"^(0?\.\d+) mg((?:/.*)?)$")

# The same, up to 1 mg, for a drug that is always labeled in micrograms.
LISTED_STRENGTH = re.compile(r"^(0?\.\d+|1(?:\.0+)?) mg((?:/.*)?)$")

# The amount and the unit that open a strength of openFDA: '50 ug/1', '.05 mg/1'.
LABEL_STRENGTH = re.compile(r"^\s*([\d.]+)\s*(mg|ug|mcg)\b", re.IGNORECASE)

# A strength of openFDA: '20 ug/.5mL', '3 mg/1', '100 [iU]/mL'. The amount, its unit, and
# what it is in: a volume in mL, or 1 for one tablet or one device.
FDA_STRENGTH = re.compile(
    r"^\s*([\d.]+)\s*(mg|ug|mcg|g|meq|\[iu\])\s*/\s*([\d.]*)\s*(ml|1)?\s*$", re.IGNORECASE)
FDA_UNITS = {"ug": "mcg", "mcg": "mcg", "mg": "mg", "g": "g", "meq": "meq", "[iu]": "units"}

# A strength of the catalog that is an amount in each mL: '5 mg/mL', '100 units/mL'.
PER_ML = re.compile(r"^([\d.,]+) (mg|mcg|g|meq|units)/mL$")
# A strength of the catalog that is an amount alone: '3 mg'.
AMOUNT = re.compile(r"^([\d.,]+) (mg|mcg|g|meq|units)$")
# The volume that ends the text RxTerms prints for a device: 'Auto-Injector 0.2 mL'.
VOLUME = re.compile(r"\s*([\d.]+) mL$")
# The first level of a package of openFDA: '2 SYRINGE in 1 CARTON'.
OUTER_PACKAGE = re.compile(r"^(\d+) [A-Z][A-Z ,\-]* in 1 (?:CARTON|PACKAGE|BOX|KIT)\b")
# Words that RxTerms shortens in the text it prints for a product.
PACKAGE_WORDS = {"Pwdr": "Powder", "Sol": "Solution", "Susp": "Suspension"}

# The last level of a package of openFDA: '3 mL in 1 SYRINGE'.
INNER_PACKAGE = re.compile(r"([\d.]+) mL in 1 ([A-Z][A-Z ,\-]*?)\s*(?:\(|$)")
# A package that holds these is counted in tablets, not in devices.
LOOSE_UNITS = ("TABLET", "CAPSULE")
# In micrograms, so that 'mg' and 'mcg' compare.
IN_MICROGRAMS = {"mcg": 1, "mg": 1000, "g": 1000000}

# The salts that end an ingredient in RxNorm. A generic name of the catalog leaves
# them out, as the ClinCalc list does.
SALT_WORDS = {"phosphate", "hydrochloride", "sodium", "potassium", "sulfate", "calcium",
              "succinate", "tartrate", "fumarate", "maleate", "mesylate", "acetate",
              "furoate", "propionate", "bromide"}
# An ingredient that is nothing without its salt: 'Ferrous fumarate' stays whole.
SALT_IS_THE_NAME = {"ferrous", "ferric"}

# Words RxTerms adds to a drug name for a release form. They are not part of the name.
RELEASE_WORDS = {"xr", "dr", "ec"}
# The release form in the text RxTerms prints for a product: '24 HR XR', '12 HR XR',
# 'DR' or 'EC'. A tablet that lets its drug go over a day is another product than one
# that lets it go at once, and another than one that lets it go after the stomach, so
# the release form is part of every name.
RELEASE_FORM = re.compile(r"\b((?:\d+ HR )?(?:XR|DR|EC))\b")
# The route that ends a display name of RxTerms: 'Lidocaine (Topical)'.
DISPLAY_ROUTE = re.compile(r"\s*\(([^()]+)\)\s*$")
# Words RxNorm adds to a product name for something that is not the drug, such as the
# excipient that tells one insulin from another. A label does not print them.
EXCIPIENT_WORDS = {"Niacinamide"}
# The term types of a pack: a carton of tablets taken in a set order, such as a cycle of
# birth control or a course of an antiviral. RxTerms prints 'mixed' as its strength.
PACK_TERMS = {"BPCK", "GPCK"}
PACK_ROUTE = "Pack"                # The route RxTerms prints for a pack
# The parts of a pack in its full name: '{20 (nirmatrelvir 150 MG Oral Tablet) / ...}'.
PACK_PART = re.compile(r"(\d+) \(([^()]*)\)")
# The words of a pack brand that count its days or doses: 'Yasmin 28 Day',
# 'Paxlovid 5-Day'. The brand is the words before the first number.
PACK_BRAND_COUNT = re.compile(r"\s+\d.*$")
INERT = "inert ingredients"        # The placebo tablets of a pack, which are no drug

# The route of RxTerms, by its first word, and the route the catalog shows.
ROUTES = {
    "oral": "Oral", "chewable": "Oral", "sublingual": "Oral", "buccal": "Oral",
    "inhalant": "Inhalation", "nasal": "Nasal", "ophthalmic": "Eye", "otic": "Ear",
    "topical": "Topical", "transdermal": "Topical", "rectal": "Rectal",
    "vaginal": "Vaginal", "injectable": "Injection",
}

# A word of the RxNorm dose form, and the form the catalog shows. The first word that
# is found decides, so the order matters: an "Injectable Suspension" is an injection.
FORMS = [
    ("inject", "Injection"), ("syringe", "Injection"), ("cartridge", "Injection"),
    ("inhaler", "Inhaler"), ("aerosol", "Inhaler"), ("nebuliz", "Nebulizer Solution"),
    ("gummy", "Gummy"), ("tablet", "Tablet"), ("capsule", "Capsule"),
    ("suspension", "Suspension"),
    ("cream", "Cream"), ("ointment", "Ointment"), ("gel", "Gel"), ("patch", "Patch"),
    ("transdermal", "Patch"), ("spray", "Spray"), ("powder", "Powder"),
    ("suppository", "Suppository"), ("solution", "Liquid"), ("liquid", "Liquid"),
]
DROPS_ROUTES = {"Eye", "Ear"}      # A solution for the eye or the ear is drops


### Read The Lists ###
def read_list(name):
    """Reads one list of tools/seed. Returns the lines that are not empty or comments."""
    path = os.path.join(SOURCES, name)
    if not os.path.isfile(path):
        print("build_seed: missing input:", path)
        sys.exit(2)
    with open(path, encoding="utf-8") as handle:
        return [line.strip() for line in handle
                if line.strip() and not line.startswith("#")]


def requests_of():
    """The drugs to look up.

    Returns a list of dicts: generic (the name the catalog shows), match (the name
    RxTerms uses), keep_salt, and routes (the routes of RxTerms to keep, or an empty
    set for every route). Grain: one entry per drug, in the order of the lists, with no
    drug twice.
    """
    renamed = {}
    for line in read_list("clincalc_names_in_rxterms.txt"):
        parts = [part.strip() for part in line.split(" = ")]
        renamed[parts[0]] = {"match": parts[1], "generic": parts[2] if len(parts) > 2 else None}

    wanted = []
    for name in read_list("clincalc_top200.txt"):
        other = renamed.get(name, {"match": name.replace("; ", "/"), "generic": None})
        if other["match"] == "skip":
            continue
        generic = other["generic"] or " / ".join(as_name(part) for part in name.split("; "))
        wanted.append({"generic": generic, "match": other["match"], "keep_salt": False, "routes": set()})
    for line in read_list("more_ingredients.txt"):
        line, _, routes = [part.strip() for part in line.partition(" @ ")]
        keep_salt = line.endswith(" +salt")
        line = line[:-len(" +salt")] if keep_salt else line
        name, _, match = [part.strip() for part in line.partition(" = ")]
        wanted.append({"generic": name.replace("; ", " / "),
                       "match": match or name.replace("; ", "/"), "keep_salt": keep_salt,
                       "routes": {plain(route) for route in routes.split(",") if route.strip()}})

    distinct, by_key = [], {}
    for request in wanted:
        key = ingredients_key(request["match"])
        if key in by_key:
            # A drug of both lists is looked up once, keeps its salt if either asks, and
            # keeps every route if either asks for every route.
            by_key[key]["keep_salt"] = by_key[key]["keep_salt"] or request["keep_salt"]
            if by_key[key]["routes"] and request["routes"]:
                by_key[key]["routes"] |= request["routes"]
            else:
                by_key[key]["routes"] = set()
        else:
            by_key[key] = request
            distinct.append(request)
    return distinct


def numbers_of(text):
    """The gauges of one line of the list of supplies: one number, or a range like 27-34."""
    if text == NONE_OF_IT:
        return [None]
    first, _, last = text.partition("-")
    return list(range(int(first), int(last or first) + 1))


def listed(text):
    """The parts between the commas of one line of the list of supplies."""
    if text == NONE_OF_IT:
        return [None]
    return [part.strip() for part in text.split(",")]


def millimetres(length):
    """A length of the list of supplies in millimetres: '4 mm', '1/2' or '1 1/2' inches."""
    if length.endswith(" mm"):
        return decimal.Decimal(length[:-len(" mm")])
    inches = decimal.Decimal(0)
    for part in length.split():
        above, _, below = part.partition("/")
        inches += decimal.Decimal(above) / decimal.Decimal(below or 1)
    return inches * MILLIMETRES_IN_AN_INCH


def supplies_of():
    """The syringes and needles of the catalog.

    Returns a list of rows of the seed. Grain: one row per family, volume, gauge and
    length, in the order of the list. The id holds those four, so it stays the same when
    the list grows: two digits of the family, four of the volume in hundredths of a
    millilitre, two of the gauge, and four of the length in hundredths of a millimetre.
    """
    rows, seen = [], set()
    for line in read_list("supplies.txt"):
        parts = [part.strip() for part in line.split(" | ")]
        if len(parts) != SUPPLY_PARTS or not re.fullmatch(r"\d\d", parts[0]):
            print("build_seed: cannot read this line of supplies.txt:", line)
            sys.exit(2)
        code, name = parts[0], parts[1]
        for volume in listed(parts[2]):
            for gauge in numbers_of(parts[3]):
                for length in listed(parts[4]):
                    size = []
                    if volume:
                        size.append(volume + " mL")
                    if gauge:
                        inch = "" if length.endswith(" mm") else '"'
                        size.append("%dG x %s%s" % (gauge, length, inch))
                    number = "%s%04d%02d%04d" % (
                        code,
                        decimal.Decimal(volume or 0) * 100,
                        gauge or 0,
                        (millimetres(length) * 100).to_integral_value() if length else 0)
                    if number in seen:
                        print("build_seed: supplies.txt lists this size twice:", line)
                        sys.exit(2)
                    seen.add(number)
                    strength = ", ".join(size)
                    if not gauge:
                        strength += " (without needle)"
                    rows.append({
                        "op": "put", "tbl": "medication",
                        "id": ID_PREFIX_SUPPLY + number,
                        "d": {"short_name": name + ", " + strength, "generic_name": name,
                              "strength": strength, "form": SUPPLY_FORM,
                              "is_specialty": False}})
    return rows


### Compare Names ###
def plain(value):
    """Lower case, with every run of characters that is not a letter or a digit as one space."""
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


def split_display_name(display_name):
    """'Lidocaine (Topical)' gives the drug 'Lidocaine' and the route 'Topical'."""
    found = DISPLAY_ROUTE.search(display_name)
    if not found:
        return display_name.strip(), ""
    return display_name[:found.start()].strip(), found.group(1).strip()


def is_pack(details):
    return (details.get("termType") or "") in PACK_TERMS


def pack_brand(name):
    """'Yasmin 28 Day' and 'Paxlovid 5-Day' give 'Yasmin' and 'Paxlovid'."""
    return PACK_BRAND_COUNT.sub("", name).strip()


def ingredients_key(name):
    """The ingredients of a drug name, in one order, without release words.

    'amLODIPine/Atorvastatin' and 'Atorvastatin/Amlodipine XR' give the same key.
    """
    parts = []
    for part in name.split("/"):
        words = [word for word in plain(part).split() if word not in RELEASE_WORDS]
        parts.append(" ".join(words))
    return "/".join(sorted(parts))


### Retrieve Source Data ###
class Reference:
    """Asks the two services, and keeps every answer in a folder."""

    def __init__(self, cache):
        self.cache = cache
        os.makedirs(cache, exist_ok=True)
        self.asked = 0

    def get(self, url, empty_status=None):
        """Returns the answer to a request as parsed JSON, from the cache when it is there.

        A service that answers with `empty_status` has nothing to say, which is an
        answer too. It is kept as an empty answer.
        """
        name = hashlib.sha256(url.encode("utf-8")).hexdigest() + ".json"
        path = os.path.join(self.cache, name)
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as handle:
                return json.load(handle)
        time.sleep(SECONDS_BETWEEN_REQUESTS)
        try:
            with urllib.request.urlopen(url, timeout=REQUEST_TIMEOUT_SECONDS) as answer:
                body = json.load(answer)
        except urllib.error.HTTPError as problem:
            if problem.code != empty_status:
                print("build_seed: no answer from", urllib.parse.urlsplit(url).netloc, "-", problem)
                sys.exit(1)
            body = {}
        except (urllib.error.URLError, TimeoutError, ValueError) as problem:
            print("build_seed: no answer from", urllib.parse.urlsplit(url).netloc, "-", problem)
            sys.exit(1)
        self.asked += 1
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(body, handle)
        return body

    def products_of(self, request):
        """Every strength and form of one drug.

        Returns a list of pairs: the RxNorm identifier of a product, and the text that
        RxTerms prints for it, such as '20 mg Tab'. Grain: one pair per product of the
        drug in RxTerms.
        """
        first = request["match"].split("/")[0]
        query = urllib.parse.urlencode({
            "terms": first, "ef": "STRENGTHS_AND_FORMS,RXCUIS", "maxList": SEARCH_RESULTS_MAX})
        answer = self.get(RXTERMS_SEARCH + "?" + query)
        wanted = ingredients_key(request["match"])
        found = []
        for position, display_name in enumerate(answer[1]):
            # A display name is the drug and its route: 'Atorvastatin (Oral Pill)'.
            drug, route = split_display_name(display_name)
            if request["routes"] and plain(route) not in request["routes"]:
                continue
            if ingredients_key(drug) == wanted:
                found.extend(zip(answer[2]["RXCUIS"][position],
                                 answer[2]["STRENGTHS_AND_FORMS"][position]))
        return found

    def products_named(self, brand):
        """Every strength and form that RxTerms files under a brand name.

        RxTerms adds the release form to the name of a brand, as in 'Depakote XR', and
        the days of a pack, as in 'Yasmin 28 Day'. Both count as the brand.
        Returns pairs like products_of. Grain: one pair per product of the brand.
        """
        query = urllib.parse.urlencode({
            "terms": brand, "ef": "STRENGTHS_AND_FORMS,RXCUIS", "maxList": SEARCH_RESULTS_MAX})
        answer = self.get(RXTERMS_SEARCH + "?" + query)
        found = []
        for position, display_name in enumerate(answer[1]):
            name, route = split_display_name(display_name)
            mine, found_name = plain(brand), plain(name)
            if found_name != mine:
                if not found_name.startswith(mine + " "):
                    continue
                rest = found_name[len(mine):].split()
                if not (all(word in RELEASE_WORDS for word in rest) or route == PACK_ROUTE):
                    continue
            found.extend(zip(answer[2]["RXCUIS"][position],
                             answer[2]["STRENGTHS_AND_FORMS"][position]))
        return found

    def labels_of(self, rxcui):
        """The products of openFDA that name an RxNorm identifier.

        One product of openFDA names the identifiers of every strength of its label, so
        the caller still has to pick the products of the strength it means.
        Grain: one row per product and maker.
        """
        query = urllib.parse.urlencode({
            "search": 'openfda.rxcui:"' + rxcui + '"', "limit": LABELS_MAX})
        return self.get(OPENFDA_NDC + "?" + query, empty_status=404).get("results", [])

    def controlled_products(self, ingredient):
        """Return scheduled product identifiers for one ingredient, using cached public data.

        Reads at most 100 NDC products. Missing records leave products unmarked.
        No credentials or household data are sent. Network failures stop the build.
        """
        query = urllib.parse.urlencode({
            "search": 'generic_name:"' + ingredient.replace('"', '') + '"', "limit": LABELS_MAX})
        products = self.get(OPENFDA_NDC + "?" + query, empty_status=404).get("results", [])
        return {str(code) for product in products if product.get("dea_schedule") in {"CI", "CII", "CIII", "CIV", "CV"}
                for code in product.get("openfda", {}).get("rxcui", [])}

    def details_of(self, rxcui):
        """What RxTerms says about one product, or None when it says nothing."""
        answer = self.get(RXNAV + "/RxTerms/rxcui/" + rxcui + "/allinfo.json")
        return answer.get("rxtermsProperties")

    def brands_of(self, rxcui, pack=False):
        """The brand names of one product, in the order of the alphabet.

        A pack has branded packs, not branded drugs, and the brand of a pack ends with
        its days or doses, which are not part of the brand.
        """
        answer = self.get(RXNAV + "/rxcui/" + rxcui + "/related.json?tty=" + ("BPCK" if pack else "SBD"))
        brands = set()
        for group in answer.get("relatedGroup", {}).get("conceptGroup", []):
            for concept in group.get("conceptProperties", []):
                # The name of a branded product ends with its brand: '... [Lipitor]'.
                brand = re.search(r"\[([^\]]+)\]\s*$", concept.get("name", ""))
                if brand and concept.get("suppress") == "N":
                    brands.add(pack_brand(brand.group(1)) if pack else brand.group(1))
        return sorted(brands, key=str.lower)


    def label_unit_of(self, rxcui, milligrams):
        """The unit that most labels print for one strength of one product.

        openFDA holds the labels that makers file. The products that name the RxNorm
        identifier and hold the same amount are counted by their unit.
        Returns 'mcg', 'mg', or None when no label holds the amount or the count is a tie.
        """
        counts = {"mg": 0, "mcg": 0}
        for product in self.labels_of(rxcui):
            for ingredient in product.get("active_ingredients", []):
                found = LABEL_STRENGTH.match(ingredient.get("strength") or "")
                if not found:
                    continue
                amount = decimal.Decimal(found.group(1))
                unit = "mg" if found.group(2).lower() == "mg" else "mcg"
                in_milligrams = amount if unit == "mg" else amount / MICROGRAMS_IN_A_MILLIGRAM
                if in_milligrams == milligrams:
                    counts[unit] += 1
        if counts["mcg"] == counts["mg"]:
            return None
        return "mcg" if counts["mcg"] > counts["mg"] else "mg"


### Transform Records ###
def as_label_prints(entry, reference, in_micrograms, in_units):
    """The strength of an entry in the unit of the label.

    RxTerms prints '0.05 mg' for a tablet that its label calls '50 mcg'. A strength
    below 1 mg becomes micrograms when the drug is on the list of drugs labeled in
    micrograms, or when most labels of the product print micrograms. A drug on the list
    of drugs labeled in units, such as a vitamin, has its milligrams or micrograms
    turned into units. Any other strength, and one whose labels cannot be read, stays as
    RxTerms prints it.
    """
    strength = entry["strength"]
    units_in_a_milligram = in_units.get(plain(entry["generic_name"]))
    if units_in_a_milligram:
        return in_label_units(strength, units_in_a_milligram)
    listed = plain(entry["generic_name"]) in in_micrograms
    # The label of a listed drug prints 1 mg as 1000 mcg too.
    small = (LISTED_STRENGTH if listed else SMALL_STRENGTH).match(strength or "")
    if not small:
        return strength
    milligrams = decimal.Decimal(small.group(1))
    if not listed and reference.label_unit_of(entry["rxcui"], milligrams) != "mcg":
        return strength
    micrograms = (milligrams * MICROGRAMS_IN_A_MILLIGRAM).normalize()
    return format(micrograms, "f") + " mcg" + small.group(2)


def in_label_units(strength, units_in_a_milligram):
    """'0.01 mg' gives '400 units' when a milligram is 40,000 units, and '25 mcg/spray'
    gives '1000 units/spray'. A strength that opens with another unit stays."""
    found = re.match(r"^([\d.,]+) (mg|mcg)((?:/.*)?)$", strength or "")
    if not found:
        return strength
    milligrams = number(found.group(1)) / IN_MICROGRAMS["mg"] * IN_MICROGRAMS[found.group(2)]
    units = (milligrams * units_in_a_milligram).normalize()
    return format(units, "f") + " units" + found.group(3)


def as_strength(value):
    """A strength as a label prints it: '100 unt/ml' becomes '100 units/mL'."""
    strength = re.sub(r"\s+", " ", value.strip())
    strength = re.sub(r"\bunt\b", "units", strength)
    strength = re.sub(r"\bactuat\b", "actuation", strength)
    strength = re.sub(r"(\d)ml\b", r"\1 mL", strength)
    strength = re.sub(r"ml\b", "mL", strength)
    return strength


def as_name(value):
    """'testosterone cypionate' and 'Insulin Lispro' become 'Testosterone cypionate'
    and 'Insulin lispro'. A word in capitals, such as 'HFA', stays as it is."""
    words = [word if word.isupper() and len(word) > 1 else word.lower() for word in value.split()]
    name = " ".join(words)
    return name[:1].upper() + name[1:]


def strength_and_package(printed, details):
    """Takes the text that RxTerms prints for a product apart.

    '10 mcg/ml Cartridge 1 ml' gives the strength '10 mcg/mL' and the rest,
    'Cartridge 1 mL', which tells two products with one strength apart. A text that
    does not open with a strength gives the strength of the details, and itself.
    """
    # RxTerms tells two products with one name apart by the number of their approval or
    # by their rating. Neither is printed on a label, so neither goes into a name.
    printed = re.sub(r"\b(?:A?NDA\d+|BX Rating)\s*", "", printed)
    for word in EXCIPIENT_WORDS:
        printed = re.sub(r"\b%s\b\s*" % word, "", printed)
    for short, whole in PACKAGE_WORDS.items():
        printed = re.sub(r"\b%s\b" % short, whole, printed)
    found = STRENGTH.match(printed)
    if found:
        return as_strength(found.group(1)), as_strength(found.group(2))
    return as_strength(details.get("strength") or ""), as_strength(printed)


def route_of(details):
    words = (details.get("route") or "").lower().split()
    return ROUTES.get(words[0]) if words else None


def form_of(details, route):
    dose_form = (details.get("rxnormDoseForm") or "").lower()
    if route == "Inhalation":
        # A liquid to inhale goes into a nebulizer. Anything else to inhale is an inhaler.
        liquid = "solution" in dose_form or "suspension" in dose_form
        return "Nebulizer Solution" if liquid else "Inhaler"
    for word, form in FORMS:
        if word in dose_form:
            if form == "Liquid" and route in DROPS_ROUTES:
                return "Drops"
            return form
    return "Other"


def generic_with_salt(details, fallback):
    """The ingredient as RxNorm names it: the words before the strength."""
    # A name can open with the size of the package: '3 ML testosterone undecanoate ...'.
    full = re.sub(r"^\d[\d.]*\s+\S+\s+", "", details.get("fullGenericName") or "")
    words = []
    for word in full.split():
        if re.match(r"\d", word):
            break
        words.append(word)
    return as_name(" ".join(words)) if words else fallback


def short_name(brand, generic, strength, release=""):
    name = brand + " (" + generic + ")" if brand else generic
    return " ".join(part for part in (name, strength, release) if part)


def release_of(package):
    """The release form named in the rest of the text RxTerms prints, or ''."""
    found = RELEASE_FORM.search(package or "")
    return found.group(1) if found else ""


def rest_of(package):
    """The rest of the text RxTerms prints without its release form, which the name
    holds already: '24 HR XR Tab' gives 'Tab'."""
    return " ".join(RELEASE_FORM.sub("", package or "").split())


def pack_words(entry):
    """' 2 Pack' for an entry of one package, '' for any other."""
    if not entry.get("package_size"):
        return ""
    return " " + entry["package_size"] + " " + entry["package_type"]


def entry_of(request, details, printed, brands, preferred):
    """One catalog entry from one product of RxTerms."""
    generic = request["generic"]
    if request["keep_salt"]:
        generic = generic_with_salt(details, generic)
    strength, package = strength_and_package(printed, details)
    route = route_of(details)
    form = form_of(details, route)
    pack = is_pack(details)
    if pack:
        generic, strength, package, route, form = pack_of(details, generic)

    # A preferred brand wins, in the spelling of the list. A drug with one brand takes
    # it. A drug with several brands takes none, and answers to each of them as
    # another name.
    chosen = next((preferred[brand.lower()] for brand in brands if brand.lower() in preferred), None)
    if not chosen and len(brands) == 1:
        chosen = brands[0]
    others = [brand for brand in brands if brand.lower() != (chosen or "").lower()]
    return {
        "rxcui": details["rxcui"],
        "brand_name": chosen,
        "generic_name": generic,
        "strength": strength or None,
        "route": route,
        "form": form,
        "package": package,
        "pack": pack,
        "reference_route": details.get("route") or "",
        "aliases": others if len(others) <= ALIASES_MAX else [],
    }


def ingredient_names(text):
    """The ingredients of one RxNorm name, without the salt that ends each one.

    'formoterol fumarate 0.005 MG/ACTUAT / mometasone furoate 0.1 MG/ACTUAT ...' gives
    ['Formoterol', 'Mometasone'].
    """
    names = []
    for part in text.split(" / "):
        words = []
        for word in part.split():
            if re.match(r"\d", word):
                break
            words.append(word)
        while len(words) > 1 and words[-1].lower() in SALT_WORDS and words[0].lower() not in SALT_IS_THE_NAME:
            words.pop()
        if words:
            names.append(as_name(" ".join(words)))
    return names


def generic_without_salt(details, fallback):
    """The ingredients as RxNorm names them, joined with ' / ', or the fallback."""
    full = re.sub(r"^\d[\d.]*\s+\S+\s+", "", details.get("fullGenericName") or "")
    if is_pack(details):
        return pack_of(details, fallback)[0]
    names = ingredient_names(full)
    return " / ".join(names) if names else fallback


def pack_of(details, fallback):
    """What a pack holds, from its full name.

    '{21 (drospirenone 3 MG / ethinyl estradiol 0.03 MG Oral Tablet) / 7 (inert
    ingredients 1 MG Oral Tablet) } Pack' gives the generic name 'Drospirenone /
    Ethinyl estradiol', no strength, the package 'Pack of 28', the route 'Oral' and
    the form 'Tablet'. The placebo tablets count in the package and not in the name.
    Returns (generic, strength, package, route, form).
    """
    names, count, route, form = [], 0, None, "Other"
    for part in PACK_PART.finditer(details.get("fullGenericName") or ""):
        count += int(part.group(1))
        text = part.group(2)
        if text.lower().startswith(INERT):
            continue
        for name in ingredient_names(text):
            if name not in names:
                names.append(name)
        # The dose form ends each part, after the last number: 'ritonavir 100 MG Oral Tablet'.
        words = text.lower().split()
        last_number = max((position for position, word in enumerate(words) if word[:1].isdigit()), default=-1)
        dose_form = " ".join(words[last_number + 1:])
        route = route or next((ROUTES[word] for word in dose_form.split() if word in ROUTES), None)
        if form == "Other":
            form = next((found for word, found in FORMS if word in dose_form), "Other")
    generic = " / ".join(names) if names else fallback
    package = "%s of %d" % (PACK_TYPE, count) if count else PACK_TYPE
    return generic, None, package, route, form


def number(text):
    return decimal.Decimal(text.replace(",", ""))


def near(one, other):
    """Whether two amounts are the same, give or take what a label rounds."""
    return abs(one - other) <= NEAR * max(one, other)


def label_of(product, entry):
    """What the label of one product of openFDA says about an entry of the catalog.

    Returns None when the product is another brand or another strength. Otherwise
    returns the strength as the label prints it for one device, such as
    '20 mcg/0.5 mL', or '' when the label prints the strength the way the catalog
    already does.
    """
    brand, generic = plain(product.get("brand_name") or ""), plain(product.get("generic_name") or "")
    if entry["brand_name"]:
        if not brand.startswith(plain(entry["brand_name"])):
            return None
    elif brand != generic:
        return None
    ingredients = product.get("active_ingredients") or []
    if len(ingredients) != 1:
        return None
    found = FDA_STRENGTH.match(ingredients[0].get("strength") or "")
    if not found:
        return None
    amount, unit = decimal.Decimal(found.group(1)), FDA_UNITS[found.group(2).lower()]
    in_volume = (found.group(4) or "").lower() == "ml"
    volume = decimal.Decimal(found.group(3)) if found.group(3) else decimal.Decimal(1)

    per_ml, alone = PER_ML.match(entry["strength"] or ""), AMOUNT.match(entry["strength"] or "")
    mine = per_ml or alone
    if not mine:
        return None
    my_amount, my_unit = number(mine.group(1)), mine.group(2)
    if my_unit in IN_MICROGRAMS and unit in IN_MICROGRAMS:
        my_amount, amount = my_amount * IN_MICROGRAMS[my_unit], amount * IN_MICROGRAMS[unit]
    elif my_unit != unit:
        return None

    if alone:
        return "" if near(amount, my_amount) else None
    if not in_volume or not near(amount / volume, my_amount):
        return None
    device = VOLUME.search(entry["package"] or "")
    if volume == 1 or not device or not near(volume, number(device.group(1))):
        # The label prints the strength for each mL, as the catalog does.
        return "" if volume == 1 else None
    shown = decimal.Decimal(found.group(1)).normalize()
    return "%s %s/%s mL" % (format(shown, "f"), unit, format(volume.normalize(), "f"))


def container_of(text):
    """The kind of device that a text names: 'cartridge', 'vial', 'device' or ''."""
    text = text.lower()
    if "cartridge" in text:
        return "cartridge"
    if "vial" in text or text.strip() in ("solution", "suspension"):
        return "vial"
    if any(word in text for word in ("syringe", "pen", "injector")):
        return "device"
    return ""


def packs_of(product, entry):
    """How many devices the cartons of one product of openFDA hold: {2, 6}.

    One label covers the pens and the vials of a drug, so only the cartons of the
    device that the entry names are counted: the same kind, and the same volume.
    """
    mine = container_of(entry["package"] or "")
    volume = VOLUME.search(entry["package"] or "")
    counts = set()
    for package in product.get("packaging") or []:
        description = package.get("description") or ""
        outer = OUTER_PACKAGE.match(description)
        if package.get("sample") or not outer or any(word in description for word in LOOSE_UNITS):
            continue
        inner = INNER_PACKAGE.search(description)
        if mine and inner and container_of(inner.group(2)) not in ("", mine):
            continue
        if volume and inner and not near(decimal.Decimal(inner.group(1)), number(volume.group(1))):
            continue
        if int(outer.group(1)) <= PACK_MAX:
            counts.add(int(outer.group(1)))
    return counts


def by_package(entry, reference):
    """The entries of one product, one for each size of carton.

    A product that comes in a device, such as a pen or a nasal spray, is dispensed by
    the carton, and a carton of 2 is another thing to refill than a carton of 6. The
    labels of openFDA say which cartons there are. The strength becomes the strength of
    one device where the label prints it so. A product with one size of carton that
    holds one device stays as it is.
    """
    if entry["form"] != "Injection" and entry["route"] != "Nasal":
        return [entry]
    strengths, packs = {}, set()
    for product in reference.labels_of(entry["rxcui"]):
        label = label_of(product, entry)
        if label is None:
            continue
        packs |= packs_of(product, entry)
        if label:
            strengths[label] = strengths.get(label, 0) + 1
    if strengths:
        entry["strength"] = max(sorted(strengths), key=strengths.get)
        # The strength names the volume now, so the package does not repeat it.
        entry["package"] = VOLUME.sub("", entry["package"] or "")
    if not packs or packs == {1}:
        return [entry]
    variants = []
    for count in sorted(packs):
        variant = dict(entry, package_size=str(count), package_type=PACK_TYPE)
        variant["aliases"] = entry["aliases"] if count == min(packs) else []
        variants.append(variant)
    return variants


def same_product(entry, row):
    """Whether an entry from RxTerms is an entry that was written by hand.

    The release form counts: a hand-written tablet with no release form in its name
    is the plain tablet, not the delayed-release one of the same strength.
    """
    written = row["d"]
    return (plain(written.get("generic_name") or "") == plain(entry["generic_name"])
            and plain(written.get("strength") or "").replace(" ", "")
                == plain(entry["strength"] or "").replace(" ", "")
            and written.get("form") == entry["form"]
            and release_of(written.get("short_name")) == release_of(entry["package"]))


def name_entries(entries, taken):
    """Gives every entry a short name that no other entry has.

    A name holds the brand, the generic name, the strength and the release form. A pack
    holds its count instead of a strength, as in 'Pack of 28'. Two products with one
    such name differ in their form or their package, so the rest of the text that
    RxTerms prints is added, and then its route, as in 'Chewable Tab'. The RxNorm
    identifier is added to the few that are still the same.
    """
    for detail in (None, "package", "route", "rxcui"):
        groups = {}
        for entry in entries:
            if detail == "package":
                entry["short_name"] = (entry["base_name"] + " " + rest_of(entry["package"])).strip() \
                    + pack_words(entry)
            elif detail == "route":
                entry["short_name"] = " ".join(
                    part for part in (entry["base_name"], entry["reference_route"], rest_of(entry["package"]))
                    if part) + pack_words(entry)
            elif detail == "rxcui":
                entry["short_name"] += ", RxNorm " + entry["rxcui"]
            else:
                entry["base_name"] = short_name(
                    entry["brand_name"], entry["generic_name"], entry["strength"],
                    release_of(entry["package"]))
                # A carton is a carton of something, so its entry names the device. A pack
                # has no strength of its own, so its entry names what the pack holds.
                device = " " + entry["package"] if (entry.get("package_size") or entry.get("pack")) and entry["package"] else ""
                entry["short_name"] = entry["base_name"] + device + pack_words(entry)
            groups.setdefault(plain(entry["short_name"]), []).append(entry)
        entries = [entry for key, group in groups.items()
                   if len(group) > 1 or key in taken for entry in group]
        if not entries:
            return


### Save Results ###
def padded_id(prefix, number):
    return prefix + str(number).zfill(ID_LENGTH - len(prefix))


def specialty_mark(generic, listed_ingredients):
    """Suggest a specialty mark by ingredient name; plan coverage must be checked by hand.

    The supplied set contains lowercase ingredient names. Returns a boolean without
    network access or side effects. Salts and combination ingredients are accepted.
    """
    for part in generic.split("/"):
        words = plain(part).split()
        if any(word.endswith(("mab", "cept")) for word in words):
            return True
        if any(ingredient in words for ingredient in listed_ingredients):
            return True
    return False


def main():
    parser = argparse.ArgumentParser(description="Build the starter catalog.")
    parser.add_argument("--cache", default=os.path.join(tempfile.gettempdir(), "meds-seed-cache"),
                        help="folder that keeps the answers of the services")
    arguments = parser.parse_args()
    reference = Reference(arguments.cache)

    by_hand = [json.loads(line) for line in read_list("by_hand.jsonl")]
    hand_medications = [row for row in by_hand if row["tbl"] == "medication"]
    preferred = {row["d"]["brand_name"].lower(): row["d"]["brand_name"]
                 for row in hand_medications if row["d"].get("brand_name")}
    preferred.update({line.lower(): line for line in read_list("preferred_brands.txt")})

    in_micrograms = {plain(line) for line in read_list("labeled_in_micrograms.txt")}
    in_units = {}
    for line in read_list("labeled_in_units.txt"):
        name, _, units = [part.strip() for part in line.partition(" = ")]
        in_units[plain(name)] = int(units.replace(",", ""))
    requests = requests_of()
    specialty_ingredients = {plain(line) for line in read_list("specialty.txt")}
    with concurrent.futures.ThreadPoolExecutor(max_workers=REQUESTS_AT_ONCE) as pool:
        controlled_codes = set().union(*pool.map(
            reference.controlled_products, [request["match"] for request in requests]))
    products_by_drug = [reference.products_of(request) for request in requests]

    # The answers about each product are asked for side by side, which fills the cache.
    # The loop below then reads them in order, so the seed comes out the same every time.
    every_product = sorted({rxcui for products in products_by_drug for rxcui, _ in products})
    with concurrent.futures.ThreadPoolExecutor(max_workers=REQUESTS_AT_ONCE) as pool:
        list(pool.map(reference.details_of, every_product))
        list(pool.map(lambda rxcui: reference.brands_of(rxcui, is_pack(reference.details_of(rxcui) or {})),
                      every_product))

    entries, not_found, seen = [], [], set()
    for request, products in zip(requests, products_by_drug):
        if not products:
            not_found.append(request["generic"])
        for rxcui, printed in products:
            details = reference.details_of(rxcui)
            # A product that RxTerms holds back is retired or not sold in the United States.
            if rxcui in seen or not details or details.get("suppress"):
                continue
            seen.add(rxcui)
            entry = entry_of(request, details, printed, reference.brands_of(rxcui, is_pack(details)), preferred)
            entry["strength"] = as_label_prints(entry, reference, in_micrograms, in_units)
            match = next((row for row in hand_medications
                          if "rxcui" not in row["d"] and same_product(entry, row)), None)
            if match:
                # The entry written by hand stays, and gains the identifier.
                match["d"]["rxcui"] = entry["rxcui"]
                match["d"]["source"] = SOURCE_NAME
            else:
                entries.append(entry)

    # A preferred brand can have products of its own in RxTerms that the lists above do
    # not reach: a brand filed under a salt, a strength that only the brand comes in,
    # or a pack. A branded product whose generic product is in already is the same
    # entry, and is left out. A brand that an entry written by hand names is left to
    # that entry.
    hand_brands = {(row["d"].get("brand_name") or "").lower() for row in hand_medications}
    added_brands = []
    for brand in sorted(preferred.values(), key=str.lower):
        if brand.lower() in hand_brands:
            continue
        for rxcui, printed in reference.products_named(brand):
            details = reference.details_of(rxcui)
            if rxcui in seen or not details or details.get("suppress"):
                continue
            if details.get("genericRxcui") in seen:
                continue
            seen.add(rxcui)
            request = {"generic": generic_without_salt(details, brand), "keep_salt": False, "routes": set()}
            entry = entry_of(request, details, printed, [brand], preferred)
            entry["strength"] = as_label_prints(entry, reference, in_micrograms, in_units)
            entries.append(entry)
            if brand not in added_brands:
                added_brands.append(brand)

    entries = [variant for entry in entries for variant in by_package(entry, reference)]
    name_entries(entries, {plain(row["d"]["short_name"]) for row in hand_medications})
    entries.sort(key=lambda entry: (entry["short_name"].lower(), int(entry["rxcui"])))

    for event in hand_medications:
        row = event["d"]
        row["is_controlled"] = bool(row.get("is_controlled") or row.get("rxcui") in controlled_codes)
        row["is_specialty"] = bool(row.get("is_specialty") or specialty_mark(
            row.get("generic_name", ""), specialty_ingredients))
    supplies = supplies_of()
    events = list(by_hand + supplies)
    alias_number = 0
    for entry in entries:
        medication_id = padded_id(ID_PREFIX_MEDICATION, entry["rxcui"])
        if entry.get("package_size"):
            medication_id = padded_id(
                ID_PREFIX_PACK + entry["rxcui"].zfill(RXCUI_DIGITS_IN_PACK_ID), entry["package_size"])
        row = {"short_name": entry["short_name"], "generic_name": entry["generic_name"]}
        if entry["brand_name"]:
            row["brand_name"] = entry["brand_name"]
        for column in ("strength", "route", "form", "package_size", "package_type"):
            if entry.get(column):
                row[column] = entry[column]
        row.update({"is_specialty": specialty_mark(entry["generic_name"], specialty_ingredients),
                    "is_controlled": entry["rxcui"] in controlled_codes,
                    "rxcui": entry["rxcui"], "source": SOURCE_NAME})
        events.append({"op": "put", "tbl": "medication", "id": medication_id, "d": row})
        for alias in entry["aliases"]:
            alias_number += 1
            events.append({"op": "put", "tbl": "medication_alias",
                           "id": padded_id(ID_PREFIX_ALIAS, alias_number),
                           "d": {"medication_id": medication_id, "alias": alias}})

    starter_lua.write_module(events, starter_lua.MODULE, time.strftime("%Y-%m-%d"))

    print("build_seed: asked the services", reference.asked, "times")
    print("build_seed:", len(hand_medications), "entries written by hand,",
          len(supplies), "syringes and needles,",
          len(entries), "entries from RxTerms,", alias_number, "brand names as other names")
    if added_brands:
        print("build_seed: brands added from their own products:",
              "; ".join(sorted(set(added_brands), key=str.lower)))
    if not_found:
        print("build_seed: RxTerms has nothing under:", "; ".join(not_found))


if __name__ == "__main__":
    main()
