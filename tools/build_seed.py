#!/usr/bin/env python3
"""
Summary: Builds apps/meds/sample/seed.jsonl, the starter catalog. It reads lists of
         drugs by ingredient, asks RxTerms for every strength of each drug, asks RxNorm
         for the brand names, and adds the entries that were written by hand.

This file is part of Prescription Tracker
tools/build_seed.py

Author(s): Gabriel Mongefranco
Created: 2026-09-27
Last Modified: 2026-09-27
Notes: See README file for documentation and full license information.

Usage, from the root of the repository:
    python3 tools/build_seed.py [--cache FOLDER]
The script sends drug names and RxNorm identifiers to two services of the United States
National Library of Medicine, and nothing else. It keeps their answers in the cache
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

### Load Configuration ###
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SOURCES = os.path.join(ROOT, "tools", "seed")
SEED = os.path.join(ROOT, "apps", "meds", "sample", "seed.jsonl")

RXTERMS_SEARCH = "https://clinicaltables.nlm.nih.gov/api/rxterms/v3/search"
RXNAV = "https://rxnav.nlm.nih.gov/REST"
REQUEST_TIMEOUT_SECONDS = 30
REQUESTS_AT_ONCE = 6               # Requests that wait for an answer at the same time
SECONDS_BETWEEN_REQUESTS = 0.4     # For each of them. RxNav asks for 20 requests a second or fewer.
SEARCH_RESULTS_MAX = 500           # The most results one RxTerms search returns
SOURCE_NAME = "rxterms"            # The value of medication.source for a copied entry
ALIASES_MAX = 5                    # A drug with more brands than this gets none as other names
ID_PREFIX_MEDICATION = "01J8MEDS0000RX"   # 14 characters; the RxNorm identifier fills the rest
ID_PREFIX_ALIAS = "01J8MEDS0000AK"
ID_LENGTH = 26                     # A ULID

# The units a strength is written in. A number followed by one of these opens the text
# that RxTerms prints for a product, as in '10 mcg/ml Cartridge 1 ml'.
STRENGTH = re.compile(
    r"^\s*([\d.,]+(?:-[\d.,]+)*\s?(?:%|(?:mg|mcg|g|ml|unt|meq|mmol)\b(?:/[\d.,]*\s?[a-z]+)?))\s*(.*)$",
    re.IGNORECASE)

# Words RxTerms adds to a drug name for a release form. They are not part of the name.
RELEASE_WORDS = {"xr", "dr", "ec"}

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
    ("tablet", "Tablet"), ("capsule", "Capsule"), ("suspension", "Suspension"),
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
    RxTerms uses) and keep_salt. Grain: one entry per drug, in the order of the lists,
    with no drug twice.
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
        wanted.append({"generic": generic, "match": other["match"], "keep_salt": False})
    for line in read_list("more_ingredients.txt"):
        keep_salt = line.endswith(" +salt")
        line = line[:-len(" +salt")] if keep_salt else line
        name, _, match = [part.strip() for part in line.partition(" = ")]
        wanted.append({"generic": name.replace("; ", " / "),
                       "match": match or name.replace("; ", "/"), "keep_salt": keep_salt})

    distinct, by_key = [], {}
    for request in wanted:
        key = ingredients_key(request["match"])
        if key in by_key:
            # A drug of both lists is looked up once, and keeps its salt if either asks.
            by_key[key]["keep_salt"] = by_key[key]["keep_salt"] or request["keep_salt"]
        else:
            by_key[key] = request
            distinct.append(request)
    return distinct


### Compare Names ###
def plain(value):
    """Lower case, with every run of characters that is not a letter or a digit as one space."""
    return re.sub(r"[^a-z0-9]+", " ", value.lower()).strip()


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

    def get(self, url):
        """Returns the answer to a request as parsed JSON, from the cache when it is there."""
        name = hashlib.sha256(url.encode("utf-8")).hexdigest() + ".json"
        path = os.path.join(self.cache, name)
        if os.path.isfile(path):
            with open(path, encoding="utf-8") as handle:
                return json.load(handle)
        time.sleep(SECONDS_BETWEEN_REQUESTS)
        try:
            with urllib.request.urlopen(url, timeout=REQUEST_TIMEOUT_SECONDS) as answer:
                body = json.load(answer)
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
            drug = display_name.rsplit(" (", 1)[0]
            if ingredients_key(drug) == wanted:
                found.extend(zip(answer[2]["RXCUIS"][position],
                                 answer[2]["STRENGTHS_AND_FORMS"][position]))
        return found

    def details_of(self, rxcui):
        """What RxTerms says about one product, or None when it says nothing."""
        answer = self.get(RXNAV + "/RxTerms/rxcui/" + rxcui + "/allinfo.json")
        return answer.get("rxtermsProperties")

    def brands_of(self, rxcui):
        """The brand names of one product, in the order of the alphabet."""
        answer = self.get(RXNAV + "/rxcui/" + rxcui + "/related.json?tty=SBD")
        brands = set()
        for group in answer.get("relatedGroup", {}).get("conceptGroup", []):
            for concept in group.get("conceptProperties", []):
                # The name of a branded product ends with its brand: '... [Lipitor]'.
                brand = re.search(r"\[([^\]]+)\]\s*$", concept.get("name", ""))
                if brand and concept.get("suppress") == "N":
                    brands.add(brand.group(1))
        return sorted(brands, key=str.lower)


### Transform Records ###
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


def short_name(brand, generic, strength):
    name = brand + " (" + generic + ")" if brand else generic
    return name + " " + strength if strength else name


def entry_of(request, details, printed, brands, preferred):
    """One catalog entry from one product of RxTerms."""
    generic = request["generic"]
    if request["keep_salt"]:
        generic = generic_with_salt(details, generic)
    strength, package = strength_and_package(printed, details)
    route = route_of(details)

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
        "form": form_of(details, route),
        "package": package,
        "reference_route": details.get("route") or "",
        "aliases": others if len(others) <= ALIASES_MAX else [],
    }


def same_product(entry, row):
    """Whether an entry from RxTerms is an entry that was written by hand."""
    written = row["d"]
    return (plain(written.get("generic_name") or "") == plain(entry["generic_name"])
            and plain(written.get("strength") or "").replace(" ", "")
                == plain(entry["strength"] or "").replace(" ", "")
            and written.get("form") == entry["form"])


def name_entries(entries, taken):
    """Gives every entry a short name that no other entry has.

    Two products with one name and one strength differ in their form or their package,
    so the rest of the text that RxTerms prints is added, and then its route, as in
    'Chewable Tab'. The RxNorm identifier is added to the few that are still the same.
    """
    for detail in (None, "package", "route", "rxcui"):
        groups = {}
        for entry in entries:
            if detail == "package":
                entry["short_name"] = (entry["base_name"] + " " + entry["package"]).strip()
            elif detail == "route":
                entry["short_name"] = " ".join(
                    part for part in (entry["base_name"], entry["reference_route"], entry["package"])
                    if part)
            elif detail == "rxcui":
                entry["short_name"] += ", RxNorm " + entry["rxcui"]
            else:
                entry["base_name"] = short_name(
                    entry["brand_name"], entry["generic_name"], entry["strength"])
                entry["short_name"] = entry["base_name"]
            groups.setdefault(plain(entry["short_name"]), []).append(entry)
        entries = [entry for key, group in groups.items()
                   if len(group) > 1 or key in taken for entry in group]
        if not entries:
            return


### Save Results ###
def padded_id(prefix, number):
    return prefix + str(number).zfill(ID_LENGTH - len(prefix))


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

    requests = requests_of()
    products_by_drug = [reference.products_of(request) for request in requests]

    # The answers about each product are asked for side by side, which fills the cache.
    # The loop below then reads them in order, so the seed comes out the same every time.
    every_product = sorted({rxcui for products in products_by_drug for rxcui, _ in products})
    with concurrent.futures.ThreadPoolExecutor(max_workers=REQUESTS_AT_ONCE) as pool:
        list(pool.map(reference.details_of, every_product))
        list(pool.map(reference.brands_of, every_product))

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
            entry = entry_of(request, details, printed, reference.brands_of(rxcui), preferred)
            match = next((row for row in hand_medications
                          if "rxcui" not in row["d"] and same_product(entry, row)), None)
            if match:
                # The entry written by hand stays, and gains the identifier.
                match["d"]["rxcui"] = entry["rxcui"]
                match["d"]["source"] = SOURCE_NAME
            else:
                entries.append(entry)

    name_entries(entries, {plain(row["d"]["short_name"]) for row in hand_medications})
    entries.sort(key=lambda entry: (entry["short_name"].lower(), int(entry["rxcui"])))

    lines = [json.dumps(row, ensure_ascii=False) for row in by_hand]
    alias_number = 0
    for entry in entries:
        medication_id = padded_id(ID_PREFIX_MEDICATION, entry["rxcui"])
        row = {"short_name": entry["short_name"], "generic_name": entry["generic_name"]}
        if entry["brand_name"]:
            row["brand_name"] = entry["brand_name"]
        for column in ("strength", "route", "form"):
            if entry[column]:
                row[column] = entry[column]
        row.update({"is_specialty": False, "rxcui": entry["rxcui"], "source": SOURCE_NAME})
        lines.append(json.dumps(
            {"op": "put", "tbl": "medication", "id": medication_id, "d": row}, ensure_ascii=False))
        for alias in entry["aliases"]:
            alias_number += 1
            lines.append(json.dumps(
                {"op": "put", "tbl": "medication_alias",
                 "id": padded_id(ID_PREFIX_ALIAS, alias_number),
                 "d": {"medication_id": medication_id, "alias": alias}}, ensure_ascii=False))

    with open(SEED, "w", encoding="utf-8") as handle:
        handle.write("\n".join(lines) + "\n")

    print("build_seed: asked the services", reference.asked, "times")
    print("build_seed:", len(hand_medications), "entries written by hand,",
          len(entries), "entries from RxTerms,", alias_number, "brand names as other names")
    if not_found:
        print("build_seed: RxTerms has nothing under:", "; ".join(not_found))


if __name__ == "__main__":
    main()
