#!/usr/bin/env bash
# This file is part of Prescription Tracker
# tests/smoke.sh
# Author(s): Gabriel Mongefranco
# Created: 2026-09-27
# Last Modified: 2026-09-27
# Summary: Starts a Privatium node on a temporary data directory, loads the sample data,
#          and checks the app's screens over HTTP: normal use, empty and invalid input,
#          boundaries, and requests that must be refused. Uses invented data only.
# Notes: See README file for documentation and full license information.
#
# Copyright © 2026 Gabriel Mongefranco
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, either version 3 of the License, or (at your option) any later version.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with this program. If not, see <https://www.gnu.org/licenses/>.
#
# Usage, from the root of the repository:
#   PRIVATIUM=/path/to/privatium tests/smoke.sh
# Exit codes: 0 every check passed, 1 a check failed, 2 the test could not start.

set -u

### Load Configuration ###
PRIVATIUM="${PRIVATIUM:-privatium}"        # The Privatium program to test with
PORT="${MEDS_TEST_PORT:-18490}"            # A port on this computer that nothing else uses
START_TIMEOUT_SECONDS=20                   # How long to wait for the node to answer
REPOSITORY="$(cd "$(dirname "$0")/.." && pwd)"
BASE="http://127.0.0.1:${PORT}"
APP="${BASE}/a/meds"

### Validate Inputs ###
for tool in curl mktemp grep sed; do
  command -v "$tool" >/dev/null 2>&1 || { echo "smoke: $tool is needed and was not found"; exit 2; }
done
command -v "$PRIVATIUM" >/dev/null 2>&1 || {
  echo "smoke: the Privatium program was not found. Set PRIVATIUM to its path."; exit 2; }
[ -f "$REPOSITORY/apps/meds/app.toml" ] || { echo "smoke: apps/meds was not found"; exit 2; }

### Start The Node ###
# The app is copied, not linked, so the test never writes inside the repository.
ROOT="$(mktemp -d "${TMPDIR:-/tmp}/meds-smoke.XXXXXX")" || { echo "smoke: no temporary folder"; exit 2; }
mkdir -p "$ROOT/apps" && cp -R "$REPOSITORY/apps/meds" "$ROOT/apps/meds"
BODY="$ROOT/body.html"
NODE_PID=""

stop_node() {
  if [ -n "$NODE_PID" ]; then
    kill "$NODE_PID" 2>/dev/null
    wait "$NODE_PID" 2>/dev/null
  fi
  # Only the folder this script made is removed.
  case "$ROOT" in
    */meds-smoke.*) rm -rf "$ROOT" ;;
  esac
}
trap stop_node EXIT

"$PRIVATIUM" --data-dir "$ROOT" --port "$PORT" --no-discovery >"$ROOT/node.log" 2>&1 &
NODE_PID=$!

waited=0
until curl -s -o /dev/null -m 2 "$APP/"; do
  waited=$((waited + 1))
  if [ "$waited" -ge "$START_TIMEOUT_SECONDS" ] || ! kill -0 "$NODE_PID" 2>/dev/null; then
    echo "smoke: the node did not start. Its log follows."
    cat "$ROOT/node.log"
    exit 2
  fi
  sleep 1
done

### Helpers ###
passed=0
failed=0

pass() { passed=$((passed + 1)); }
fail() { failed=$((failed + 1)); echo "FAIL  $1"; }

# get <path>: fetches a page of the app into $BODY and prints the status code.
get() { curl -s -m 10 -o "$BODY" -w '%{http_code}' "$APP$1"; }

# token <path>: prints the csrf token of the form on a page of the app.
token() {
  curl -s -m 10 "$APP$1" | grep -o 'name="_csrf" value="[^"]*"' | head -1 | sed 's/.*value="//; s/"$//'
}

# post <form page> <path> [field=value ...]: posts a form with the token of its page.
# Prints the status code and leaves the answer in $BODY.
post() {
  local form_page="$1" path="$2"; shift 2
  local arguments=(--data-urlencode "_csrf=$(token "$form_page")")
  local field
  for field in "$@"; do arguments+=(--data-urlencode "$field"); done
  curl -s -m 10 -o "$BODY" -w '%{http_code}' -X POST "${arguments[@]}" "$APP$path"
}

# expect_status <name> <expected> <actual>
expect_status() { if [ "$3" = "$2" ]; then pass; else fail "$1: expected status $2, got $3"; fi; }

# expect_text <name> <text>: the last answer holds the text.
expect_text() { if grep -qF -- "$2" "$BODY"; then pass; else fail "$1: the page lacks: $2"; fi; }

# expect_no_text <name> <text>: the last answer does not hold the text.
expect_no_text() { if grep -qF -- "$2" "$BODY"; then fail "$1: the page holds: $2"; else pass; fi; }

# expect_flat_text <name> <text>, expect_no_flat_text <name> <text>: the same, for a
# text that the page breaks over several lines. Every run of spaces and line breaks of
# the page counts as one space.
flat_body() { tr -s ' \n\r\t' ' ' <"$BODY"; }
expect_flat_text() { if flat_body | grep -qF -- "$2"; then pass; else fail "$1: the page lacks: $2"; fi; }
expect_no_flat_text() { if flat_body | grep -qF -- "$2"; then fail "$1: the page holds: $2"; else pass; fi; }

# count_of <table>: prints how many rows a table holds, read through the data API.
count_of() {
  curl -s -m 10 "$APP/api/q/v_row_count" \
    | grep -o "\"row_count\":[0-9]*,\"table_name\":\"$1\"" | grep -o '[0-9]*' | head -1
}

# id_after <text>: prints the record id in the first link of $BODY that follows a path.
id_in_link() { grep -o "$1/[0-9A-Z]\{26\}" "$BODY" | head -1 | sed 's|.*/||'; }

### Home And Navigation ###
expect_status "home page" 200 "$(get /)"
expect_text "home page invites a household with no name" "Welcome to your prescription tracker."
expect_text "home page has the navigation bar" 'aria-label="Prescription Tracker"'
expect_text "home page marks the current section" 'aria-current="page"'

### Sample Data ###
seed_token="$(curl -s -m 10 "$BASE/settings/apps" \
  | grep -o 'action="/settings/apps/meds/seed"[^>]*>.\{0,300\}' \
  | grep -o 'name="_csrf" value="[^"]*"' | head -1 | sed 's/.*value="//; s/"$//')"
expect_status "sample data loads" 303 "$(curl -s -m 20 -o /dev/null -w '%{http_code}' -X POST \
  --data-urlencode "_csrf=$seed_token" "$BASE/settings/apps/meds/seed")"
# The expected counts are read from the sample data, so a rebuilt catalog needs no change here.
SEED="$REPOSITORY/apps/meds/sample/seed.jsonl"
seed_medications="$(grep -c '"tbl": *"medication"' "$SEED")"
seed_names="$(grep -c '"tbl": *"medication_alias"' "$SEED")"
expect_status "catalog rows after the sample data" "$seed_medications" "$(count_of medication)"
expect_status "other names after the sample data" "$seed_names" "$(count_of medication_alias)"
expect_status "no person in the sample data" 0 "$(count_of person)"

### Greeting ###
# The greeting follows the local hour, so the expected words come from the local clock.
hour="$(date +%H | sed 's/^0//')"
if [ "$hour" -lt 12 ]; then greeting="Good morning"
elif [ "$hour" -lt 18 ]; then greeting="Good afternoon"
else greeting="Good evening"; fi
expect_status "home page after the sample data" 200 "$(get /)"
expect_text "greeting follows the local hour" "$greeting."
expect_status "no page asks for a household name" 404 "$(get /edit)"

### Reminder Settings ###
expect_status "reminder settings page" 200 "$(get /setup/reminders)"
expect_text "reminder settings show the default" "Empty means 3."
expect_status "due soon below due is refused" 200 "$(post /setup/reminders /setup/reminders \
  'due_within_days=5' 'due_soon_within_days=2')"
expect_text "due soon below due says why" "Make the days for due soon the same as the days for due, or more."
expect_text "a refused form keeps what was typed" 'value="5"'
expect_status "due soon below the default for due is refused" 200 "$(post /setup/reminders /setup/reminders \
  'due_soon_within_days=2')"
expect_status "a day count above the limit is refused" 200 "$(post /setup/reminders /setup/reminders \
  'due_within_days=366')"
expect_text "a day count above the limit says why" "whole number from 0 to 365"
expect_status "a day count with letters is refused" 200 "$(post /setup/reminders /setup/reminders \
  'due_within_days=ten')"
expect_status "reminder settings are saved" 303 "$(post /setup/reminders /setup/reminders \
  'due_within_days=4' 'due_soon_within_days=8')"
curl -s -m 10 "$APP/api/q/v_reminder_setting" >"$BODY"
expect_text "saved count is in force" '"due_within_days":4'
expect_text "empty count takes its default" '"specialty_due_within_days":5'
expect_status "reminder settings are saved a second time" 303 "$(post /setup/reminders /setup/reminders \
  'due_within_days=4' 'due_soon_within_days=8' 'authorization_notice_days=30')"
expect_status "the settings stay one record" 1 "$(count_of profile)"

### People ###
expect_status "people page" 200 "$(get /setup/people)"
expect_text "people page with no one" "No one is in the app yet."
expect_status "person is added" 303 "$(post /setup/people/new /setup/people/new \
  'display_name=Alex Example' 'birth_date=1980-01-31')"
expect_status "people page after adding" 200 "$(get '/setup/people?notice=saved')"
expect_text "people page lists the person" "Alex Example"
expect_text "people page confirms the save" "Saved."
alex="$(id_in_link /setup/people)"

expect_status "empty name is refused" 200 "$(post /setup/people/new /setup/people/new 'display_name=')"
expect_text "empty name says why" "Enter the name."
expect_text "problems are listed at the top" "Check these fields"
expect_status "a date the calendar lacks is refused" 200 "$(post /setup/people/new /setup/people/new \
  'display_name=Sam Example' 'birth_date=2026-02-30')"
expect_text "a date the calendar lacks says why" "year-month-day"
expect_text "a refused form keeps the name" 'value="Sam Example"'
expect_status "a birth date in the future is refused" 200 "$(post /setup/people/new /setup/people/new \
  'display_name=Sam Example' 'birth_date=2999-01-01')"
expect_text "a birth date in the future says why" "not in the future"
expect_status "the same name in other letters is refused" 200 "$(post /setup/people/new /setup/people/new \
  'display_name=  alex   EXAMPLE ')"
expect_text "the same name says why" "already in the app"
expect_status "a name of 121 characters is refused" 200 "$(post /setup/people/new /setup/people/new \
  "display_name=$(printf 'a%.0s' $(seq 1 121))")"
expect_text "a name too long says why" "120 characters or fewer"
expect_status "a name of 120 characters is saved" 303 "$(post /setup/people/new /setup/people/new \
  "display_name=$(printf 'b%.0s' $(seq 1 120))")"

### Requests That Must Be Refused ###
expect_status "a post without the token is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -X POST --data-urlencode 'display_name=No Token' "$APP/setup/people/new")"
expect_status "a post with a wrong token is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -X POST --data-urlencode '_csrf=0000' --data-urlencode 'display_name=Wrong Token' "$APP/setup/people/new")"
expect_status "markup in a name is saved as text" 303 "$(post /setup/people/new /setup/people/new \
  'display_name=<script>alert(1)</script>')"
expect_status "SQL in a name is saved as text" 303 "$(post /setup/people/new /setup/people/new \
  "display_name=Robert'); DROP TABLE person;--")"
expect_status "people page after hostile names" 200 "$(get /setup/people)"
expect_text "markup in a name is shown escaped" "&lt;script&gt;alert(1)&lt;/script&gt;"
expect_no_text "markup in a name is never sent as markup" "<script>alert(1)</script>"
expect_text "SQL in a name is shown as text" "DROP TABLE person"
expect_status "the person table still holds every person" 4 "$(count_of person)"
expect_status "a notice code that is not known" 200 "$(get '/setup/people?notice=%3Cscript%3Ealert(2)%3C/script%3E')"
expect_no_text "a notice code is never shown" "alert(2)"
expect_status "an id that is not in the app" 303 "$(get /setup/people/01J8MEDS0000000000N0NE0001/edit)"
expect_status "an id that is not an id" 303 "$(get "/setup/people/x'%20OR%201=1/edit")"

### Changing And Removing A Person ###
expect_status "person form shows the stored values" 200 "$(get "/setup/people/$alex/edit")"
expect_text "person form holds the name" 'value="Alex Example"'
expect_text "person form holds the birth date" 'value="1980-01-31"'
expect_status "person is changed" 303 "$(post "/setup/people/$alex/edit" "/setup/people/$alex/edit" \
  'display_name=Alex Example' 'birth_date=')"
curl -s -m 10 "$APP/api/row/person/$alex" >"$BODY"
expect_no_text "an emptied field is cleared" "birth_date"
expect_text "a change keeps the id" "\"id\":\"$alex\""

expect_status "removal asks first" 200 "$(get "/setup/people/$alex/remove")"
expect_text "removal page names the record" "Alex Example"
expect_text "removal page says the log keeps the record" "Privatium keeps the original line in its log"
expect_status "a fill for the person is recorded" 200 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"events\":[{\"op\":\"put\",\"tbl\":\"pharmacy\",\"id\":\"01J8MEDS0000000000TEST0001\",\"d\":{\"name\":\"Example Pharmacy\",\"phone\":\"(555) 555-0100\"}},{\"op\":\"put\",\"tbl\":\"fill\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"01J8MEDS0000000000MED00001\",\"pharmacy_id\":\"01J8MEDS0000000000TEST0001\",\"filled_on\":\"2026-09-01\",\"days_supply\":30}}]}" \
  "$APP/api/events")"
expect_status "removal page for a person with a fill" 200 "$(get "/setup/people/$alex/remove")"
expect_text "a person with a fill cannot be removed" "cannot be removed yet"
expect_text "the page says what uses the person" "1 fill"
# The removal page of a record in use has no form, so the token comes from another form.
# The token is valid for the whole app, which is what a hand-built request would use.
expect_status "removing a person with a fill is refused" 303 "$(post /setup/people/new "/setup/people/$alex/remove")"
expect_status "the person is still there" 4 "$(count_of person)"

get /setup/people >/dev/null
other="$(grep -o '/setup/people/[0-9A-Z]\{26\}/remove' "$BODY" | sed 's|/remove||; s|.*/||' | grep -v "$alex" | head -1)"
expect_status "a person with no records is removed" 303 "$(post "/setup/people/$other/remove" "/setup/people/$other/remove")"
expect_status "one person fewer" 3 "$(count_of person)"

### Contacts ###
expect_status "contacts page" 200 "$(get /contacts)"
expect_text "contacts page lists the pharmacy" "Example Pharmacy"
expect_text "a phone number is a link a phone can dial" 'href="tel:5555550100"'
expect_text "a pharmacy that fills use cannot be removed" "Remove"
expect_status "a script address as a website is refused" 200 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=Sample Pharmacy' 'website=javascript:alert(3)')"
expect_text "a script address says why" "Start the website with https://"
expect_status "a short identifier is refused" 200 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=Sample Pharmacy' 'npi=12345')"
expect_text "a short identifier says why" "10 digits"
expect_status "an email address with no @ is refused" 200 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=Sample Pharmacy' 'email=sample.example.com')"
expect_status "pharmacy is added" 303 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=Sample Pharmacy' 'phone=+1 555 555 0142 x9' 'website=https://pharmacy.example.com' \
  'npi=1234567893' 'email=sample@example.com' 'address=1 Example Street, Anytown')"
expect_status "prescriber is added" 303 "$(post /contacts/prescribers/new /contacts/prescribers/new \
  'name=Dr. Sample' 'clinic=Example Clinic' 'mobile_phone=555-555-0177')"
expect_status "contacts page after adding" 200 "$(get /contacts)"
expect_text "contacts page lists the new pharmacy" "Sample Pharmacy"
expect_text "an extension is left out of the link" 'href="tel:+15555550142"'
expect_text "a website with https is a link" 'href="https://pharmacy.example.com"'
expect_text "contacts page lists the prescriber" "Dr. Sample"
expect_text "contacts page shows the clinic" "Example Clinic"
expect_status "removal page for a pharmacy with a fill" 200 "$(get /contacts/pharmacies/01J8MEDS0000000000TEST0001/remove)"
expect_text "a pharmacy with a fill cannot be removed" "cannot be removed yet"
expect_status "the same pharmacy name is refused" 200 "$(post /contacts/pharmacies/new /contacts/pharmacies/new \
  'name=sample pharmacy')"
expect_text "the same pharmacy name says why" "already in the app"

### Medication Catalog ###
expect_status "catalog page" 200 "$(get /setup/catalog)"
expect_text "catalog page counts the medications" "The catalog holds $seed_medications medications."
expect_text "a long catalog shows its first page" "This page shows the first 100"
expect_status "catalog filtered by another name" 200 "$(get '/setup/catalog?q=apap')"
expect_text "two medications answer to the other name" "2 medications"
expect_status "catalog filtered by a percent sign" 200 "$(get '/setup/catalog?q=%25')"
expect_text "a percent sign alone finds nothing" "No medication answers"
expect_status "catalog filtered by an underscore" 200 "$(get '/setup/catalog?q=_')"
expect_text "an underscore alone finds nothing" "No medication answers"
expect_status "catalog filtered by SQL" 200 "$(get "/setup/catalog?q=%27%20OR%201%3D1%20--")"
expect_no_text "SQL in the filter is compared as text and lists no catalog" "The catalog holds"
expect_status "catalog filtered by markup" 200 "$(get '/setup/catalog?q=%3Cimg%20src%3Dx%3E')"
expect_no_text "markup in the filter is never sent as markup" "<img src=x>"

expect_status "a medication with no name is refused" 200 "$(post /setup/catalog/new /setup/catalog/new 'strength=10 mg')"
expect_text "a medication with no name says why" "Enter a brand name or a generic name."
expect_status "medication is added" 303 "$(post /setup/catalog/new /setup/catalog/new \
  'brand_name=Examplol' 'generic_name=Exampline' 'strength=10 mg' 'route_new=oral' \
  'dose_form=Tablet' 'is_specialty=yes')"
expect_status "catalog filtered by the new medication" 200 "$(get '/setup/catalog?q=examplol')"
expect_text "the short name is built from the parts" "Examplol (Exampline) 10 mg"
expect_text "the full name is built from the parts" "Exampline (Examplol) 10 mg Oral Tablet"
expect_text "a specialty medication says so in words" "Specialty"
examplol="$(id_in_link /setup/catalog)"
expect_status "medication page" 200 "$(get "/setup/catalog/$examplol")"
expect_text "a typed choice takes the spelling of the list" "<dd>Oral</dd>"
expect_status "the same short name is refused" 200 "$(post /setup/catalog/new /setup/catalog/new \
  'brand_name=examplol' 'generic_name=exampline' 'strength=10 MG')"
expect_text "the same short name says why" "already in the catalog"
expect_status "medication is changed" 303 "$(post "/setup/catalog/$examplol/edit" "/setup/catalog/$examplol/edit" \
  'brand_name=Examplol' 'generic_name=Exampline' 'strength=20 mg' 'route=Oral' 'dose_form=Tablet' \
  'short_name=Examplol (Exampline) 10 mg')"
expect_status "medication page after the change" 200 "$(get "/setup/catalog/$examplol")"
expect_text "a built short name follows the strength" "Examplol (Exampline) 20 mg"
expect_no_text "a cleared check box is saved as cleared" "takes longer to arrive"
expect_status "a typed short name is kept" 303 "$(post "/setup/catalog/$examplol/edit" "/setup/catalog/$examplol/edit" \
  'brand_name=Examplol' 'generic_name=Exampline' 'strength=20 mg' 'short_name=exm')"
expect_status "medication page after the typed name" 200 "$(get "/setup/catalog/$examplol")"
expect_text "the typed short name is the heading" "<h1>exm</h1>"
expect_status "a medication with no records is removed" 303 "$(post "/setup/catalog/$examplol/remove" "/setup/catalog/$examplol/remove")"
expect_status "the catalog is back to the sample data" "$seed_medications" "$(count_of medication)"

expect_status "medication page of the sample data" 200 "$(get /setup/catalog/01J8MEDS0000000000MED00003)"
expect_text "a medication shows its other names" "Z-Pak"
expect_status "removal page for a medication with a fill" 200 "$(get /setup/catalog/01J8MEDS0000000000MED00001/remove)"
expect_text "a medication with a fill cannot be removed" "cannot be removed yet"
expect_status "a medication goes with its other names" 303 "$(post /setup/catalog/01J8MEDS0000000000MED00003/remove \
  /setup/catalog/01J8MEDS0000000000MED00003/remove)"
expect_status "one medication fewer" "$((seed_medications - 1))" "$(count_of medication)"
names_of_removed="$(grep -c '"medication_id": *"01J8MEDS0000000000MED00003"' "$SEED")"
expect_status "its other names are gone with it" "$((seed_names - names_of_removed))" "$(count_of medication_alias)"

### Medication Search, Other Names And Merge ###
expect_status "search by a misspelled name" 200 "$(get '/setup/catalog?q=Lipitro')"
expect_text "a close name is offered as a question" "Did you mean one of these?"
expect_text "the close medication is named" "Lipitor (Atorvastatin) 20 mg"
expect_text "a close name says to check it" "names that look alike"
expect_status "search by the start of a generic name" 200 "$(get '/setup/catalog?q=atorva')"
expect_text "the start of a name finds the medication" "Lipitor (Atorvastatin) 40 mg"
expect_no_text "a contained name is not a question" "Did you mean one of these?"
expect_text "an unknown name can be taught" "Teach the app this name"
expect_status "search by an exact other name" 200 "$(get '/setup/catalog?q=PEG%203350')"
expect_no_text "a known name is not taught again" "Teach the app this name"

lipitor=01J8MEDS0000000000MED00015
expect_status "a name is taught" 303 "$(post /setup/catalog/new "/setup/catalog/$lipitor/names" 'alias=atorva 20')"
expect_status "search by the taught name" 200 "$(get '/setup/catalog?q=ATORVA-20')"
expect_text "the taught name finds the medication" "Lipitor (Atorvastatin) 20 mg"
expect_no_text "the taught name is now known" "Teach the app this name"
expect_status "a name the medication has is refused" 200 "$(post /setup/catalog/new "/setup/catalog/$lipitor/names" 'alias=LIPITOR')"
expect_text "a name the medication has says why" "already answers to that one"
expect_status "an empty other name is refused" 200 "$(post /setup/catalog/new "/setup/catalog/$lipitor/names" 'alias= ')"
expect_status "markup as another name is saved as text" 303 "$(post /setup/catalog/new "/setup/catalog/$lipitor/names" 'alias=<b>bold</b>')"
expect_status "medication page with other names" 200 "$(get "/setup/catalog/$lipitor")"
expect_text "markup in another name is shown escaped" "&lt;b&gt;bold&lt;/b&gt;"
name_id="$(grep -o "/names/[0-9A-Z]\{26\}/remove" "$BODY" | head -1 | sed 's|/names/||; s|/remove||')"
expect_status "removing another name asks first" 200 "$(get "/setup/catalog/$lipitor/names/$name_id/remove")"
expect_status "another name of a different medication is not removed" 303 "$(post /setup/catalog/new \
  "/setup/catalog/01J8MEDS0000000000MED00016/names/$name_id/remove")"
names_before="$(count_of medication_alias)"
expect_status "another name is removed" 303 "$(post "/setup/catalog/$lipitor/names/$name_id/remove" \
  "/setup/catalog/$lipitor/names/$name_id/remove")"
expect_status "one other name fewer after the removal" "$((names_before - 1))" "$(count_of medication_alias)"

# Two entries for one product, as two sources would name it. The second has a fill, a
# list entry and a prior authorization; the person also has the first on their list.
expect_status "the same product under a second name is added" 303 "$(post /setup/catalog/new /setup/catalog/new \
  'generic_name=Atorvastatin calcium' 'strength=20 mg' 'route=Oral' 'dose_form=Tablet')"
get '/setup/catalog?q=atorvastatin%20calcium%2020' >/dev/null
duplicate="$(grep -o '/setup/catalog/[0-9A-Z]\{26\}"' "$BODY" | sed 's|.*/||; s|"||' | grep -v "$lipitor" | head -1)"
expect_status "records for both entries are recorded" 200 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' \
  -H 'Content-Type: application/json' \
  -d "{\"events\":[{\"op\":\"put\",\"tbl\":\"fill\",\"id\":\"01J8MEDS0000000000TEST0002\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"$duplicate\",\"pharmacy_id\":\"01J8MEDS0000000000TEST0001\",\"filled_on\":\"2026-09-02\",\"days_supply\":30,\"quantity\":\"30\",\"amount_paid\":\"4.50\"}},{\"op\":\"put\",\"tbl\":\"person_medication\",\"id\":\"01J8MEDS0000000000TEST0003\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"$duplicate\",\"status\":\"taking_regularly\",\"refills_left\":2}},{\"op\":\"put\",\"tbl\":\"person_medication\",\"id\":\"01J8MEDS0000000000TEST0004\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"$lipitor\",\"status\":\"not_taking\",\"refills_left\":0}},{\"op\":\"put\",\"tbl\":\"prior_authorization\",\"id\":\"01J8MEDS0000000000TEST0005\",\"d\":{\"person_id\":\"$alex\",\"medication_id\":\"$duplicate\",\"valid_from\":\"2026-01-01\",\"valid_to\":\"2026-12-31\"}}]}" \
  "$APP/api/events")"
expect_status "merge page offers the other entry" 200 "$(get "/setup/catalog/$duplicate/merge")"
expect_text "merge page names the entry that stays" "Lipitor (Atorvastatin) 20 mg"
expect_status "merge asks first" 200 "$(get "/setup/catalog/$duplicate/merge/$lipitor")"
expect_text "merge says how many fills move" "1 fill will move."
expect_text "merge says which list entry is kept" "The entry in use is kept."
expect_text "merge says it cannot be undone" "cannot be undone in the app"
expect_status "a medication is not merged into itself" 303 "$(get "/setup/catalog/$lipitor/merge/$lipitor")"
fills_before="$(count_of fill)"; entries_before="$(count_of person_medication)"
expect_status "merge without the token is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST "$APP/setup/catalog/$duplicate/merge/$lipitor")"
expect_status "merge is done" 303 "$(post "/setup/catalog/$duplicate/merge/$lipitor" "/setup/catalog/$duplicate/merge/$lipitor")"
expect_status "no fill is lost in a merge" "$fills_before" "$(count_of fill)"
expect_status "the list entry not in use is dropped" "$((entries_before - 1))" "$(count_of person_medication)"
curl -s -m 10 "$APP/api/row/fill/01J8MEDS0000000000TEST0002" >"$BODY"
expect_text "the fill points to the entry that stays" "\"medication_id\":\"$lipitor\""
expect_text "the fill keeps its amount" '"amount_paid":"4.50"'
expect_text "the fill keeps its quantity" '"quantity":"30.000"'
curl -s -m 10 "$APP/api/row/person_medication/01J8MEDS0000000000TEST0003" >"$BODY"
expect_text "the list entry in use points to the entry that stays" "\"medication_id\":\"$lipitor\""
expect_text "the list entry keeps its refills" '"refills_left":"2"'
expect_status "the dropped list entry is gone" 404 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' "$APP/api/row/person_medication/01J8MEDS0000000000TEST0004")"
curl -s -m 10 "$APP/api/row/prior_authorization/01J8MEDS0000000000TEST0005" >"$BODY"
expect_text "the prior authorization points to the entry that stays" "\"medication_id\":\"$lipitor\""
expect_status "the merged entry is gone" 303 "$(get "/setup/catalog/$duplicate")"
expect_status "medication page after the merge" 200 "$(get "/setup/catalog/$lipitor?notice=merged")"
expect_text "the page confirms the merge" "Merged."
expect_status "search by the name of the merged entry" 200 "$(get '/setup/catalog?q=atorvastatin%20calcium%2020%20mg')"
expect_text "the old name finds the entry that stays" "Lipitor (Atorvastatin) 20 mg"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
expect_text "the view shows the medication under the name that stays" '"medication_name":"Lipitor (Atorvastatin) 20 mg"'
expect_text "the view counts the fill of the merged entry" '"last_filled_on":"2026-09-02"'

### Medication Lists ###
# Dates are worked out from today, so the refill statuses stay the same on any day.
day() { date -d "$1" +%F; }
entry_of() {   # entry_of <start of a medication name>: prints the id of its list entry
  curl -s -m 10 "$APP/api/q/v_active_medication" \
    | grep -o "\"medication_name\":\"$1[^}]*\"person_medication_id\":\"[0-9A-Z]*\"" \
    | head -1 | sed 's/.*"person_medication_id":"//; s/"$//'
}
pharmacy=01J8MEDS0000000000TEST0001
prinivil=01J8MEDS0000000000MED00016
glucophage=01J8MEDS0000000000MED00017

expect_status "medications page" 200 "$(get "/medications?person=$alex")"
expect_text "medications page lists an entry" "Lipitor (Atorvastatin) 20 mg"
expect_status "the form that adds to a list" 200 "$(get "/medications/new?person=$alex")"
expect_text "the form suggests names while a person types" 'list="medication-names"'
expect_text "the suggestions hold the short names" 'value="Prinivil (Lisinopril) 10 mg"'
expect_text "the suggestions hold the other names" 'value="Albuterol inhaler"'
expect_text "the form can add a new medication" "Add a new medication"
expect_text "the form can add a new prescriber" "Name of the new prescriber"
expect_text "a drop-down offers to add a new record" '<option value="new">-- Add new --</option>'
expect_text "the fields of a new record wait for that choice" 'data-show-when="prescriber_id=new"'
expect_text "the page loads the script that shows them" '/static/forms.js'
expect_status "the script is served" 200 "$(get /static/forms.js)"
expect_status "the choice to add with no name is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "medication_id=$glucophage" 'status=taking_regularly' 'refills_left=1' 'pharmacy_id=new')"
expect_text "the choice to add with no name says why" "Type the name of the new pharmacy."
expect_status "the choice to find a medication with no name is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_id=new' 'status=taking_regularly' 'refills_left=1')"
expect_text "the choice to find a medication with no name says why" "Type the name of the medication to find it"
expect_status "the form after the two refusals" 200 "$(get "/medications/new?person=$alex")"
expect_status "an entry with no medication is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'status=taking_regularly' 'refills_left=1')"
expect_text "an entry with no medication says why" "Choose a medication: pick one from the list, type its name, or add a new one."
expect_status "a medication id that names nothing is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_id=01J8MEDS0000000000N0NE0001' 'status=taking_regularly' 'refills_left=1')"
expect_text "a medication id that names nothing says why" "Choose a medication from the list."
expect_status "a name that fits two medications asks which one" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_name=albuterol' 'status=taking_regularly' 'refills_left=1')"
expect_text "a name that fits two medications says so" "Choose the medication you mean"
expect_text "a name that fits two medications offers the first" "Ventolin HFA (Albuterol) 90 mcg/actuation"
expect_text "a name that fits two medications offers the second" "Albuterol 2.5 mg/3 mL (0.083%)"
expect_text "the form keeps the typed name" 'value="albuterol"'
expect_status "a misspelled name picks nothing" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_name=Prinivl' 'status=taking_regularly' 'refills_left=1')"
expect_text "a misspelled name offers the close medication" "Prinivil (Lisinopril) 10 mg"
expect_status "a name nobody knows is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_name=zzzqqq' 'status=taking_regularly' 'refills_left=1')"
expect_text "a name nobody knows says what to do" "No medication answers to this name."
expect_status "markup as a name is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_name=<script>alert(7)</script>' 'status=taking_regularly' 'refills_left=1')"
expect_no_text "markup as a name is never sent as markup" "<script>alert(7)</script>"
expect_status "an entry with no status is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "medication_id=$prinivil" 'status=' 'refills_left=1')"
expect_text "an entry with no status says why" "Choose a status."
expect_status "an entry with a status that does not exist is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "medication_id=$prinivil" 'status=cured' 'refills_left=1')"
expect_status "an entry for a person who does not exist is refused" 200 "$(post /setup/people/new /medications/new \
  'person_id=01J8MEDS0000000000N0NE0001' "medication_id=$prinivil" 'status=taking_regularly' 'refills_left=1')"
expect_status "an entry with 100 refills is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "medication_id=$prinivil" 'status=taking_regularly' 'refills_left=100')"
expect_status "an entry is added" 303 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "medication_id=$prinivil" 'status=taking_regularly' 'refills_left=1' \
  'instructions=Take one tablet by mouth every day' 'when_to_take_new=with breakfast' \
  'prescribed_for=<i>blood pressure</i>' "pharmacy_id=$pharmacy")"
expect_status "the same medication twice on one list is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "medication_id=$prinivil" 'status=taking_regularly' 'refills_left=1')"
expect_text "the same medication twice says why" "already on the list"
entry="$(entry_of Prinivil)"
expect_status "page of a medication of a person" 200 "$(get "/medications/$entry")"
expect_text "the page shows the instructions" "Take one tablet by mouth every day"
expect_text "the page shows a typed choice" "with breakfast"
expect_text "markup in a field is shown escaped" "&lt;i&gt;blood pressure&lt;/i&gt;"
expect_text "a medication with no fill says so" "No fill recorded"
# One form adds the medication, the person, the prescriber and the pharmacy it names.
before="$(count_of medication) $(count_of person) $(count_of prescriber) $(count_of pharmacy) $(count_of person_medication)"
expect_status "an entry with everything new is added" 303 "$(post /setup/people/new /medications/new \
  'person_id_new=Robin Example' 'medication_brand=Quickadd' 'medication_generic=Quickaddine' \
  'medication_strength=15 mg' 'status=taking_regularly' 'refills_left=2' \
  'prescriber_id_new=Dr. Quick' 'pharmacy_id_new=Quick Pharmacy')"
after="$(count_of medication) $(count_of person) $(count_of prescriber) $(count_of pharmacy) $(count_of person_medication)"
expect_status "everything new is added once" "$(echo "$before" | awk '{print $1+1, $2+1, $3+1, $4+1, $5+1}')" "$after"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
expect_text "the new medication has its built short name" '"medication_name":"Quickadd (Quickaddine) 15 mg"'
expect_text "the new entry names the new prescriber" '"prescriber_name":"Dr. Quick"'
# A typed name that a record already has picks that record.
expect_status "typed names that exist pick the records they name" 200 "$(post /setup/people/new /medications/new \
  'person_id_new=robin  EXAMPLE' 'medication_generic=Quickaddine' 'medication_brand=quickadd' \
  'medication_strength=15 MG' 'status=on_hold' 'refills_left=2' 'pharmacy_id_new=quick pharmacy')"
expect_text "the same person and medication are found" "already on the list"
expect_status "typed names that exist add nothing" "$after" \
  "$(count_of medication) $(count_of person) $(count_of prescriber) $(count_of pharmacy) $(count_of person_medication)"
# The lookup in the browser fills in fields of the form. They are checked like any other.
expect_text "the form holds the lookup, hidden until a script shows it" 'data-lookup="medication" hidden'
expect_text "the page loads the lookup script" '/static/medication_lookup.js'
expect_status "the lookup script is served" 200 "$(get /static/medication_lookup.js)"
expect_status "a medication from a drug reference is added" 303 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_choice=new' 'medication_brand=Lookupol' 'medication_generic=Lookupine' \
  'medication_strength=5 mg' 'medication_rxcui=99999901' 'medication_source=rxterms' \
  'medication_route=Oral Pill' 'medication_dose_form=Extended Release Oral Tablet' \
  'status=on_hold' 'refills_left=0')"
get '/setup/catalog?q=lookupol' >/dev/null
lookupol="$(id_in_link /setup/catalog)"
expect_status "page of the medication from a drug reference" 200 "$(get "/setup/catalog/$lookupol")"
expect_text "the identifier of the reference is kept" "<dd>99999901</dd>"
expect_text "the reference is named" "RxTerms"
expect_text "the route takes the word of the catalog" "<dd>Oral</dd>"
expect_text "the form takes the word of the catalog" "<dd>Tablet</dd>"
medications_before="$(count_of medication)"
expect_status "the same identifier picks the medication that has it" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_choice=new' 'medication_generic=Another Name' \
  'medication_rxcui=99999901' 'medication_source=rxterms' 'status=on_hold' 'refills_left=0')"
expect_text "the medication that has the identifier is on the list already" "already on the list"
expect_status "an identifier with letters is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_choice=new' 'medication_generic=Badcode' 'medication_rxcui=12<x>' \
  'status=on_hold' 'refills_left=0')"
expect_text "an identifier with letters says why" "digits only"
expect_status "a reference that is not known is left out" 303 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_choice=new' 'medication_generic=Nosourcine' 'medication_source=<b>evil</b>' \
  'medication_route=<script>' 'medication_dose_form=<script>' 'status=on_hold' 'refills_left=0')"
get '/setup/catalog?q=nosourcine' >/dev/null
expect_status "page of the medication with no reference" 200 "$(get "/setup/catalog/$(id_in_link /setup/catalog)")"
expect_no_text "a reference that is not known is never shown" "evil"
expect_no_text "a route that is not known is never stored" "&lt;script&gt;"
expect_status "only the two medications were added" "$((medications_before + 1))" "$(count_of medication)"
expect_status "a new medication with no name is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id=$alex" 'medication_choice=new' 'medication_strength=15 mg' 'status=taking_regularly' 'refills_left=1')"
expect_text "a new medication with no name says why" "Enter a brand name or a generic name."
expect_status "a new person with a name that is too long is refused" 200 "$(post /setup/people/new /medications/new \
  "person_id_new=$(printf 'a%.0s' $(seq 1 121))" "medication_id=$glucophage" 'status=taking_regularly' 'refills_left=1')"
expect_text "a name that is too long says why" "120 characters or fewer"
expect_status "an entry for a second medication, taken as needed" 303 "$(post /setup/people/new /medications/new \
  "person_id=$alex" "medication_id=$glucophage" 'status=taking_as_needed' 'refills_left=0')"

### Fills ###
expect_status "the fill form opens from a list entry" 200 "$(get "/fills/new?entry=$entry")"
expect_text "the fill form starts with today" "value=\"$(day today)\""
expect_text "the fill form offers one refill fewer" 'name="refills_left" type="text" value="0"'
expect_status "a fill in the future is refused" 200 "$(post /setup/people/new /fills/new \
  "person_id=$alex" "medication_id=$prinivil" "pharmacy_id=$pharmacy" "filled_on=$(day tomorrow)" 'refills_left=0')"
expect_text "a fill in the future says why" "not in the future"
expect_status "an amount with three decimal places is refused" 200 "$(post /setup/people/new /fills/new \
  "person_id=$alex" "medication_id=$prinivil" "pharmacy_id=$pharmacy" "filled_on=$(day today)" \
  'amount_paid=12.505' 'refills_left=0')"
expect_text "an amount with three decimal places says why" "up to 2 decimal places"
expect_status "a days supply of 1000 is refused" 200 "$(post /setup/people/new /fills/new \
  "person_id=$alex" "medication_id=$prinivil" "pharmacy_id=$pharmacy" "filled_on=$(day today)" \
  'days_supply=1000' 'refills_left=0')"
expect_status "the fill form with no medication chosen" 200 "$(get "/fills/new?person=$alex")"
expect_text "the fill form holds the medication box" 'name="medication_name"'
expect_text "the fill form can add a pharmacy" "Name of the new pharmacy"
expect_status "a fill with no pharmacy is refused" 200 "$(post /setup/people/new /fills/new \
  "person_id=$alex" "medication_id=$prinivil" "filled_on=$(day today)" 'refills_left=0')"
expect_text "a fill with no pharmacy says why" "Choose a pharmacy, or type the name of a new one."
fills_before="$(count_of fill)"
expect_status "a fill is recorded" 303 "$(post /setup/people/new /fills/new \
  "person_id=$alex" "medication_id=$prinivil" "pharmacy_id=$pharmacy" "filled_on=$(day '-28 days')" \
  'days_supply=30' 'quantity=30' 'amount_paid=$1,012.50' 'refills_left=0' 'rx_number=700001')"
expect_status "one fill more" "$((fills_before + 1))" "$(count_of fill)"
curl -s -m 10 "$APP/api/row/person_medication/$entry" >"$BODY"
expect_text "the fill sets the refills left" '"refills_left":"0"'
expect_text "the fill keeps the rest of the list entry" 'Take one tablet by mouth every day'
expect_status "a fill for a medication taken as needed, long ago" 303 "$(post /setup/people/new /fills/new \
  "person_id=$alex" "medication_id=$glucophage" "pharmacy_id=$pharmacy" "filled_on=$(day '-200 days')" \
  'days_supply=30' 'refills_left=0')"
expect_status "a fill for a medication that is on no list" 303 "$(post /setup/people/new /fills/new \
  "person_id=$alex" "medication_id=01J8MEDS0000000000MED00018" "pharmacy_id=$pharmacy" \
  "filled_on=$(day '-25 days')" 'days_supply=30' 'refills_left=3')"
pharmacies_before="$(count_of pharmacy)"; fills_before="$(count_of fill)"
expect_status "a fill by a typed name, at a new pharmacy" 303 "$(post /setup/people/new /fills/new \
  "person_id=$alex" 'medication_name=quickadd (quickaddine) 15 mg' 'pharmacy_id_new=Corner Pharmacy' \
  "filled_on=$(day '-10 days')" 'days_supply=30' 'insurance_plan=Example Plan')"
expect_status "the fill is added" "$((fills_before + 1))" "$(count_of fill)"
expect_status "the pharmacy is added with it" "$((pharmacies_before + 1))" "$(count_of pharmacy)"
expect_status "a refused fill adds no pharmacy" 200 "$(post /setup/people/new /fills/new \
  "person_id=$alex" 'medication_name=quickadd (quickaddine) 15 mg' 'pharmacy_id_new=Never Pharmacy' \
  "filled_on=$(day tomorrow)")"
expect_status "no pharmacy from a refused fill" "$((pharmacies_before + 1))" "$(count_of pharmacy)"
expect_text "a refused fill keeps the typed pharmacy" 'value="Never Pharmacy"'
get "/fills/new?person=$alex" >/dev/null
expect_text "a plan that a fill names is suggested" '<option value="Example Plan">'
norvasc="$(entry_of Norvasc)"
curl -s -m 10 "$APP/api/row/person_medication/$norvasc" >"$BODY"
expect_text "the fill adds the medication to the list" '"status":"taking_regularly"'

### Refills ###
expect_status "refills page" 200 "$(get "/?person=$alex")"
expect_text "refills page has its heading" "<h1>Refills</h1>"
expect_text "a refill 2 days away is due" "Due in 2 days"
expect_text "a refill 5 days away is due soon" "Due in 5 days"
expect_text "the summary counts the group Due" "Due: 1"
expect_text "the summary counts the group Due soon" "Due soon: "
expect_text "no refills left asks for a new prescription" "for a new prescription"
expect_text "a medication taken as needed has its own group" '<h2 id="as_needed">As needed</h2>'
expect_no_text "a medication taken as needed is never overdue" "Overdue by 1"
expect_text "no refills left and a fill that is near asks for a new prescription" '<h2 id="asking">New prescriptions to ask for</h2>'
expect_text "the summary counts the new prescriptions" "New prescriptions to ask for: 2"
expect_text "a medication taken as needed is asked for too" "The last fill lasts until"
expect_status "a fill shows its confirmation" 200 "$(get '/?filled=01J8MEDS0000000000TEST0002')"
expect_text "the confirmation names the medication" "Saved the fill for Lipitor (Atorvastatin) 20 mg."
expect_status "a fill id that is not in the app shows nothing" 200 "$(get '/?filled=%3Cscript%3E')"
expect_no_text "a fill id is never shown" "<script>"

expect_status "a specialty medication is added" 303 "$(post /setup/catalog/new /setup/catalog/new \
  'brand_name=Specimab' 'generic_name=Specizumab' 'strength=150 mg' 'is_specialty=yes')"
get '/setup/catalog?q=specimab' >/dev/null
specimab="$(id_in_link /setup/catalog)"
expect_status "a fill for the specialty medication" 303 "$(post /setup/people/new /fills/new \
  "person_id=$alex" "medication_id=$specimab" "pharmacy_id=$pharmacy" "filled_on=$(day '-23 days')" \
  'days_supply=28' 'refills_left=5')"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
if grep -o '"medication_name":"Specimab[^}]*' "$BODY" | grep -q '"refill_status":"due"'; then pass; else fail "a specialty refill 5 days away is due"; fi
if grep -o '"medication_name":"Norvasc[^}]*' "$BODY" | grep -q '"refill_status":"due_soon"'; then pass; else fail "an ordinary refill 5 days away is due soon"; fi
if grep -o '{[^}]*"medication_name":"Prinivil[^}]*}' "$BODY" | grep -q '"days_until_next_fill":2'; then pass; else fail "the view counts the days to the next fill"; fi

expect_status "a status is changed from the page" 303 "$(post /setup/people/new "/medications/$norvasc/status" 'status=on_hold')"
expect_status "a status that does not exist is ignored" 303 "$(post /setup/people/new "/medications/$norvasc/status" 'status=cured')"
curl -s -m 10 "$APP/api/row/person_medication/$norvasc" >"$BODY"
expect_text "the status is saved" '"status":"on_hold"'
expect_text "a change of status keeps the refills left" '"refills_left":"3"'
expect_status "refills page after the change" 200 "$(get "/?person=$alex")"
expect_text "a medication on hold is in the group Paused" '<h2 id="paused">Paused</h2>'

### Prior Authorizations ###
expect_status "authorizations page" 200 "$(get /authorizations)"
expect_status "the authorization form" 200 "$(get "/authorizations/new?entry=$entry")"
expect_text "the form asks for the person by itself" 'id="f-person_id-list"'
expect_text "the first day starts with the first of this month" "name=\"valid_from\" type=\"date\" value=\"$(date +%Y-%m-01)\""
expect_text "the expiration date starts one year later" "name=\"valid_to\" type=\"date\" value=\"$(($(date +%Y) + 1))-$(date +%m)-01\""
if [ "$(grep -n 'name="valid_from"' "$BODY" | head -1 | cut -d: -f1)" -lt "$(grep -n 'name="valid_to"' "$BODY" | head -1 | cut -d: -f1)" ]; then pass; else fail "the first day comes before the expiration date"; fi
expect_text "the form asks for the medication by itself" 'id="f-medication-list"'
expect_text "the form starts with the person of the entry" "value=\"$alex\" selected"
expect_text "the form starts with the medication of the entry" "value=\"$prinivil\" selected"
expect_status "an authorization that ends before it starts is refused" 200 "$(post /setup/people/new /authorizations/new \
  "person_id=$alex" "medication_id=$prinivil" "valid_from=$(day today)" "valid_to=$(day yesterday)")"
expect_text "an authorization that ends before it starts says why" "the expiration date or earlier"
expect_status "an authorization for no medication is refused" 200 "$(post /setup/people/new /authorizations/new \
  "person_id=$alex" "valid_from=$(day today)" "valid_to=$(day tomorrow)")"
expect_status "an authorization for nobody is refused" 200 "$(post /setup/people/new /authorizations/new \
  "medication_id=$prinivil" "valid_to=$(day tomorrow)")"
expect_text "an authorization for nobody says why" "Choose a person, or type the name of a new one."
expect_status "an authorization with no last day is refused" 200 "$(post /setup/people/new /authorizations/new \
  "person_id=$alex" "medication_id=$prinivil" "valid_from=$(day today)")"
expect_text "an authorization with no last day says why" "Enter the expiration date."
expect_status "an authorization is added with no first day" 303 "$(post /setup/people/new /authorizations/new \
  "person_id=$alex" "medication_id=$prinivil" "valid_to=$(day '+10 days')")"
expect_status "authorizations page with no first day" 200 "$(get /authorizations)"
expect_text "a first day that is not known says so" "Not known"
entries_before="$(count_of person_medication)"
expect_status "an authorization for a medication that is on no list" 303 "$(post /setup/people/new /authorizations/new \
  'person_id_new=Jamie Example' 'medication_name=Ventolin HFA (Albuterol) 90 mcg/actuation' \
  "valid_from=$(day '-300 days')" "valid_to=$(day '+200 days')")"
expect_status "the medication is added to the list" "$((entries_before + 1))" "$(count_of person_medication)"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
if grep -o '"medication_name":"Ventolin[^}]*' "$BODY" | grep -q '"status":"not_started"'; then pass; else fail "the medication starts as not started"; fi
expect_status "authorizations page after adding" 200 "$(get /authorizations)"
expect_text "an authorization that expires in 10 days is due" "Due: expires in 10 days"
expect_status "refills page with an authorization ending" 200 "$(get /)"
expect_text "the refills page warns of the authorization" "Expires in 10 days"
expect_text "only one authorization is due" "Authorizations due: 1"
expect_no_text "no authorization is due soon yet" "Authorizations due soon"
expect_status "an authorization that expires in 20 days" 303 "$(post /setup/people/new /authorizations/new \
  "person_id=$alex" "medication_id=$glucophage" "valid_to=$(day '+20 days')")"
expect_status "an authorization that expired" 303 "$(post /setup/people/new /authorizations/new \
  "person_id=$alex" "medication_id=01J8MEDS0000000000MED00018" "valid_from=$(day '-400 days')" "valid_to=$(day '-3 days')")"
expect_status "an authorization that expires in 40 days" 303 "$(post /setup/people/new /authorizations/new \
  "person_id=$alex" "medication_id=$specimab" "valid_to=$(day '+40 days')")"
expect_status "refills page with authorizations of every level" 200 "$(get "/?person=$alex")"
expect_text "20 days away is due soon" "Authorizations due soon: 1"
expect_text "an expired authorization is counted" "Authorizations expired: 1"
expect_text "an expired authorization says since when" "Expired 3 days ago"
expect_no_text "40 days away raises nothing" "Expires in 40 days"
expect_status "due soon below due is refused for authorizations" 200 "$(post /setup/reminders /setup/reminders \
  'authorization_due_within_days=20' 'authorization_notice_days=10')"
expect_text "due soon below due says why for authorizations" "Make the days for due soon the same as the days for due, or more."
curl -s -m 10 "$APP/api/q/v_reminder_setting" >"$BODY"
expect_text "an authorization is due at 14 days unless changed" '"authorization_due_within_days":14'

### The List Made For Paper, And History ###
expect_status "medication list for paper" 200 "$(get "/people/$alex/medication-list")"
expect_text "the list names the person" "Medication list for Alex Example"
expect_text "the list holds a medication in use" "Prinivil (Lisinopril) 10 mg"
expect_text "the list marks a medication taken as needed" "(as needed)"
expect_status "the list of a person who does not exist" 303 "$(get /people/01J8MEDS0000000000N0NE0001/medication-list)"
expect_status "history page" 200 "$(get "/fills?person=$alex")"
expect_text "history shows an amount with its thousands" "1,012.50"
expect_text "history has a column for the quantity" '<th scope="col" role="columnheader">Quantity</th>'
expect_text "history has a column for the days supply" '<th scope="col" role="columnheader">Days supply</th>'
expect_text "a whole quantity has no decimals" 'aria-hidden="true">Quantity</span>30</td>'
expect_no_text "no quantity shows zeros that say nothing" "30.000"
expect_status "a fill with a part of a package" 303 "$(post /setup/people/new /fills/new \
  "person_id=$alex" "medication_id=$glucophage" "pharmacy_id=$pharmacy" "filled_on=$(day '-150 days')" \
  'days_supply=30' 'quantity=2.50')"
expect_status "history after the fill" 200 "$(get "/fills?person=$alex")"
expect_text "a part of a package keeps the decimals that count" 'aria-hidden="true">Quantity</span>2.5</td>'
expect_text "history totals the amounts exactly" "Total paid"
expect_text "history shows what was paid by year" "Paid by year"
expect_status "history for a year with no fill" 200 "$(get '/fills?year=1999')"
expect_text "a year with no fill says so" "No fill matches."
expect_status "history with a year that is not a year" 200 "$(get "/fills?year=%27%20OR%201=1")"
expect_status "history with a page that is not a number" 200 "$(get '/fills?page=abc')"

### Pasted Fills ###
us() { date -d "$1" +%m/%d/%Y; }
pasted="SERVICE DATEDRUG NAMEPHARMACYPLAN PAIDYOU PAIDCLAIM STATUS
$(us '-3 days')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

1 EXAMPLE STREET. ANYTOWN, MI 480000000

555-555-0100

PHARMACY ID
1234567893

RX NUMBER
700002

DAYS SUPPLY
30

QUANTITY
30

Plan Paid

\$12.00
Deductible

\$0.00
Patient Responsibility

\$5.00
$(us '-3 days')<script>alert(9)</script> 5 MGEXAMPLE PHARMACY\$ 1.00\$ 1.00PaidLess Infosort Icon
EXAMPLE PHARMACY

RX NUMBER
700003
$(us '-4 days')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidMore Infosort Icon
$(us '-5 days')ATORVASTATIN 20 MG TABLETSAMPLE DRUGS\$ 3.00\$ 2.25ReversedLess Infosort Icon
SAMPLE DRUGS

2 SAMPLE ROAD. ANYTOWN, MI 480000000

555-555-0133

PHARMACY ID
1245319599

RX NUMBER
700004

DAYS SUPPLY
90

QUANTITY
90

Patient Responsibility

\$2.25"
expect_status "paste page" 200 "$(get "/fills/paste?person=$alex")"
expect_status "text with no fill in it" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" 'pasted=Hello there')"
expect_text "text with no fill says what to do" "found no fills in that text"
expect_status "a paste for nobody is refused" 200 "$(post /fills/paste /fills/paste/read 'person_id=' "pasted=$pasted")"
expect_text "a paste for nobody says why" "Choose the person"
expect_status "a paste that is too long is refused" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" \
  "pasted=$(printf 'x%.0s' $(seq 1 60001))")"
expect_text "a paste that is too long says why" "Paste fewer fills at a time"
expect_status "the pasted text is read" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$pasted")"
expect_text "the review counts the fills" "4 fills found. 2 ready to add. 3 names are new to the app."
expect_text "a name with the same drug and strength is matched" "One medication has the same name and the same strength."
expect_text "the matched medication is marked" "value=\"$prinivil\" checked"
expect_text "a second name is matched too" "name=\"medication_4_choice\""
expect_text "a name the catalog lacks starts as a new medication" 'name="medication_2_choice" value="new" checked'
expect_text "the strength of a new medication is read from the name" 'name="medication_2_strength" data-lookup-field="strength" type="text" value="5 mg"'
expect_text "every name can be linked to another medication" 'name="medication_1_name"'
expect_no_text "a fill that cannot be added asks for no choice" 'name="medication_3_choice"'
expect_text "a fill with closed details says so" "Details missing"
expect_text "markup in the pasted text is shown escaped" "&lt;script&gt;alert(9)&lt;/script&gt;"
expect_no_text "markup in the pasted text is never sent as markup" "<script>alert(9)</script>"
expect_text "the amounts that are not stored say so" "not stored"
expect_text "a pharmacy that is known says so" "Known pharmacy"
expect_text "a pharmacy that is not known can be added" "Add SAMPLE DRUGS, with the address and phone number that were pasted"
expect_text "a fill that was not paid starts unmarked" 'name="include_4" type="checkbox" value="yes">'
expect_text "a fill that is ready starts marked" 'name="include_1" type="checkbox" value="yes" checked>'

fills_before="$(count_of fill)"; names_before="$(count_of medication_alias)"; pharmacies_before="$(count_of pharmacy)"
medications_before="$(count_of medication)"
expect_status "adding without the token is refused" 403 "$(curl -s -m 10 -o /dev/null -w '%{http_code}' -X POST \
  --data-urlencode "person_id=$alex" --data-urlencode "pasted=$pasted" --data-urlencode 'include_1=yes' "$APP/fills/paste/add")"
expect_status "a fill whose medication is not chosen is not added" 200 "$(post /fills/paste /fills/paste/add \
  "person_id=$alex" "pasted=$pasted" 'include_1=yes' 'include_4=yes' "medication_4_choice=$lipitor" 'pharmacy_4=new')"
expect_text "an open choice says so" "Nothing was added yet. 1 choice is still open."
expect_text "an open choice keeps the marks" 'name="include_4" type="checkbox" value="yes" checked>'
expect_status "a choice that names nothing is not added" 200 "$(post /fills/paste /fills/paste/add \
  "person_id=$alex" "pasted=$pasted" 'include_1=yes' 'medication_1_choice=01J8MEDS0000000000N0NE0001')"
expect_status "a pharmacy that names nothing is not added" 200 "$(post /fills/paste /fills/paste/add \
  "person_id=$alex" "pasted=$pasted" 'include_4=yes' "medication_4_choice=$lipitor" \
  'pharmacy_4=01J8MEDS0000000000N0NE0001')"
expect_text "a pharmacy that names nothing says why" "Choose a pharmacy from the list."
expect_status "nothing was added by the refused requests" "$fills_before" "$(count_of fill)"
# Fill 3 cannot be added, so marking it changes nothing. Fill 2 is left out, so the
# medication that was filled in for it is not added.
expect_status "the fills are added" 303 "$(post /fills/paste /fills/paste/add "person_id=$alex" "pasted=$pasted" \
  'include_1=yes' "medication_1_choice=$prinivil" \
  'medication_2_choice=new' 'medication_2_generic=Never Added' \
  'include_3=yes' "medication_3_choice=$prinivil" \
  'include_4=yes' "medication_4_choice=$lipitor" 'pharmacy_4=new')"
expect_status "only the fills that can be added are added" "$((fills_before + 2))" "$(count_of fill)"
expect_status "the names of the portal are remembered" "$((names_before + 2))" "$(count_of medication_alias)"
expect_status "the new pharmacy is added once" "$((pharmacies_before + 1))" "$(count_of pharmacy)"
expect_status "a medication no fill uses is not added" "$medications_before" "$(count_of medication)"
expect_status "history after the paste" 200 "$(get "/fills?person=$alex&added=2")"
expect_text "history confirms the paste" "2 fills added."
expect_text "a pasted fill has its prescription number" "Rx 700002"
curl -s -m 10 "$APP/api/row/person_medication/$(entry_of Lipitor)" >"$BODY"
expect_text "a pasted fill lowers the refills left by one" '"refills_left":"1"'
expect_status "contacts after the paste" 200 "$(get /contacts)"
expect_text "the new pharmacy has its details" "2 SAMPLE ROAD. ANYTOWN, MI 480000000"
expect_text "the new pharmacy has its identifier" "1245319599"

expect_status "the same text is read again" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$pasted")"
expect_text "a fill that was added is already recorded" "Already recorded"
expect_text "only the fill that was left out is ready the second time" "4 fills found. 1 ready to add. 1 name is new to the app."
fills_before="$(count_of fill)"
expect_status "the same text is added again" 303 "$(post /fills/paste /fills/paste/add "person_id=$alex" "pasted=$pasted" \
  'include_1=yes' 'include_4=yes')"
expect_status "pasting the same page twice adds nothing" "$fills_before" "$(count_of fill)"

# The names of the portal are known now, so a later page needs no choices.
later="$(us '-1 day')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
700009

DAYS SUPPLY
30
$(us '-1 day')ATORVASTATIN 20 MG TABLETSAMPLE DRUGS\$ 3.00\$ 2.25ReversedLess Infosort Icon
SAMPLE DRUGS

PHARMACY ID
1245319599

RX NUMBER
700010
$(us '-2 days')PASTEDOL ER 7.5 MG CAPSULESAMPLE DRUGS\$ 3.00\$ 2.25PaidLess Infosort Icon
SAMPLE DRUGS

PHARMACY ID
1245319599

RX NUMBER
700011

DAYS SUPPLY
30"
expect_status "a later page is read" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$later")"
expect_text "a fill with a known name and pharmacy is ready" "3 fills found. 2 ready to add. 1 name is new to the app."
expect_text "a claim that was not paid says so" "Not paid"
expect_text "a claim that was not paid names its status" "Reversed"
expect_text "a name that was chosen once is known" "Known name"
expect_no_text "a known name asks for no choice" 'name="medication_1_choice"'
expect_text "the new name is taken apart" 'name="medication_3_generic" data-lookup-field="generic" type="text" value="Pastedol ER"'

# A medication that the catalog lacks is added from the review page, with its fill.
medications_before="$(count_of medication)"; names_before="$(count_of medication_alias)"
expect_status "a fill with a new medication is added" 303 "$(post /fills/paste /fills/paste/add \
  "person_id=$alex" "pasted=$later" 'include_1=yes' 'include_3=yes' 'medication_3_choice=new' \
  'medication_3_brand=Pastedol ER' 'medication_3_generic=Pastedoline' 'medication_3_strength=7.5 mg')"
expect_status "the new medication is in the catalog" "$((medications_before + 1))" "$(count_of medication)"
expect_status "the name of the portal belongs to it" "$((names_before + 1))" "$(count_of medication_alias)"
curl -s -m 10 "$APP/api/q/v_active_medication" >"$BODY"
expect_text "the new medication is on the list" '"medication_name":"Pastedol ER (Pastedoline) 7.5 mg"'

# A prescription number that an earlier fill has names the medication, however the
# portal writes the number and the name.
numbered="$(us '-1 day')LISINOPRIL (GENERIC) TABSEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
7000-02

DAYS SUPPLY
30
$(us '-2 days')BLOOD PRESSURE PILLEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
700 002

DAYS SUPPLY
30
$(us '-3 days')LISINOPRIL 10 MG TABLETEXAMPLE PHARMACY\$ 12.00\$ 5.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
70-0002

DAYS SUPPLY
30"
expect_status "a page with known prescription numbers is read" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$numbered")"
expect_text "a number and a name that agree pick the medication" "Same prescription number and name"
expect_flat_text "the medication that both name is marked" "name=\"medication_1_choice\" value=\"$prinivil\" checked"
expect_text "a number alone puts the medication first and leaves the choice open" "Same prescription number</span>"
expect_flat_text "a number alone offers the medication" "name=\"medication_2_choice\" value=\"$prinivil\""
expect_no_flat_text "a number alone marks nothing" "name=\"medication_2_choice\" value=\"$prinivil\" checked"
expect_text "a number written with a hyphen is the same number" "Already recorded"

# A long page with many names is read inside the limits of one request.
many="SERVICE DATEDRUG NAMEPHARMACYPLAN PAIDYOU PAIDCLAIM STATUS"
number=0
for drug in LISINOPRIL METFORMIN ATORVASTATIN ACETAMINOPHEN AMOXICILLIN LEVOTHYROXINE ALBUTEROL \
            FLUTICASONE OMEPRAZOLE SERTRALINE LOSARTAN GABAPENTIN AMLODIPINE SIMVASTATIN MONTELUKAST \
            ESCITALOPRAM ROSUVASTATIN BUPROPION FUROSEMIDE PANTOPRAZOLE TRAZODONE FLUOXETINE \
            TAMSULOSIN MELOXICAM PREDNISONE CITALOPRAM CARVEDILOL DULOXETINE CLONAZEPAM ZZQXOL; do
  for strength in '10 MG TABLET' '20 MG CAPSULE'; do
    number=$((number + 1))
    many="$many
$(us "-$number days")$drug $strength""EXAMPLE PHARMACY\$ 1.00\$ 1.00PaidLess Infosort Icon
EXAMPLE PHARMACY

PHARMACY ID
1234567893

RX NUMBER
80$number

DAYS SUPPLY
30"
  done
done
expect_status "a page with 60 names is read" 200 "$(post /fills/paste /fills/paste/read "person_id=$alex" "pasted=$many")"
expect_text "every fill of the long page is found" "60 fills found."

### Setup ###
expect_status "setup page" 200 "$(get /setup)"
expect_text "setup page counts the people" "The members of the household. 5 in the app"
expect_text "setup page counts the medications" "with its other names. $((seed_medications + 4)) in the app"
expect_no_text "setup page asks for no household name" "Household name"

### Report ###
echo "$passed passed, $failed failed"
[ "$failed" -eq 0 ]
